import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'voice_token_service.dart';
import 'audio_stream_player.dart';

/// 流式TTS服务
///
/// 通过分句策略实现低延迟语音合成：
/// 1. 将长文本分割成短句
/// 2. 并行合成多个短句
/// 3. 边合成边播放，首句完成即开始播放
/// 4. 支持中途取消和打断
class StreamingTTSService {
  final VoiceTokenService _tokenService;
  final Dio _dio;
  final AudioStreamPlayer _streamPlayer;

  /// TTS设置
  String _voice = 'xiaoyun';
  double _rate = 0;
  double _volume = 50;
  double _pitch = 0;

  /// 状态
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isCancelled = false;

  /// 事件流
  final _stateController = StreamController<StreamingTTSState>.broadcast();
  Stream<StreamingTTSState> get stateStream => _stateController.stream;

  /// 首字延迟测量
  DateTime? _synthesisStartTime;
  Duration? _firstChunkLatency;
  Duration? get firstChunkLatency => _firstChunkLatency;

  StreamingTTSService({VoiceTokenService? tokenService})
      : _tokenService = tokenService ?? VoiceTokenService(),
        _dio = Dio(),
        _streamPlayer = AudioStreamPlayer() {
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _streamPlayer.initialize();
    _isInitialized = true;
    debugPrint('StreamingTTSService: initialized');
  }

  /// 流式朗读文本
  ///
  /// 将文本分割成句子，并行合成，边合成边播放
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.trim().isEmpty) return;

    if (interrupt && _isSpeaking) {
      await stop();
    }

    _isSpeaking = true;
    _isCancelled = false;
    _synthesisStartTime = DateTime.now();
    _firstChunkLatency = null;
    _stateController.add(StreamingTTSState.started);

    try {
      // 分割文本为句子
      final sentences = _splitIntoSentences(text);
      debugPrint('StreamingTTSService: split into ${sentences.length} sentences');

      if (sentences.isEmpty) {
        _isSpeaking = false;
        _stateController.add(StreamingTTSState.completed);
        return;
      }

      // 获取Token
      final tokenInfo = await _tokenService.getToken();

      // 并行合成前几个句子，边合成边播放
      await _synthesizeAndPlay(sentences, tokenInfo);

      if (!_isCancelled) {
        _stateController.add(StreamingTTSState.completed);
      }
    } catch (e) {
      debugPrint('StreamingTTSService: error - $e');
      _stateController.add(StreamingTTSState.error);
      rethrow;
    } finally {
      _isSpeaking = false;
    }
  }

  /// 分割文本为句子
  List<String> _splitIntoSentences(String text) {
    // 按标点符号分割
    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      // 中文标点和英文标点作为句子结束
      if (_isSentenceEnd(char)) {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        buffer.clear();
      }
    }

    // 处理剩余文本
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }

    // 合并过短的句子
    return _mergeTooShortSentences(sentences);
  }

  bool _isSentenceEnd(String char) {
    return char == '。' ||
        char == '！' ||
        char == '？' ||
        char == '；' ||
        char == '.' ||
        char == '!' ||
        char == '?' ||
        char == ';' ||
        char == '，' ||
        char == ',';
  }

  /// 合并过短的句子（少于5个字符）
  List<String> _mergeTooShortSentences(List<String> sentences) {
    if (sentences.length <= 1) return sentences;

    final merged = <String>[];
    var buffer = StringBuffer();

    for (final sentence in sentences) {
      buffer.write(sentence);

      // 如果当前缓冲区足够长，或者是最后一个句子
      if (buffer.length >= 10 || sentence == sentences.last) {
        merged.add(buffer.toString());
        buffer = StringBuffer();
      }
    }

    // 处理剩余
    if (buffer.isNotEmpty) {
      if (merged.isNotEmpty) {
        merged[merged.length - 1] += buffer.toString();
      } else {
        merged.add(buffer.toString());
      }
    }

    return merged;
  }

  /// 并行合成并播放
  Future<void> _synthesizeAndPlay(
    List<String> sentences,
    VoiceTokenInfo tokenInfo,
  ) async {
    // 预取配置
    const prefetchCount = 2;
    const maxQueueSize = 5; // 最大队列长度，防止内存溢出
    const synthesisTimeout = Duration(seconds: 15); // 单句合成超时

    // 使用Map存储Future，支持动态移除已完成的
    final audioFutures = <int, Future<File?>>{};
    final tempFiles = <File>[]; // 跟踪所有临时文件，确保清理

    try {
      // 启动预取
      for (var i = 0; i < sentences.length && i < prefetchCount; i++) {
        audioFutures[i] = _synthesizeToFileWithTimeout(
          sentences[i], tokenInfo, i, synthesisTimeout,
        );
      }

      // 边合成边播放
      for (var i = 0; i < sentences.length; i++) {
        if (_isCancelled) break;

        // 等待当前句子合成完成
        final future = audioFutures[i];
        if (future == null) {
          debugPrint('StreamingTTSService: missing future for sentence $i');
          continue;
        }

        final audioFile = await future;
        audioFutures.remove(i); // 移除已完成的Future

        if (audioFile == null || _isCancelled) continue;

        tempFiles.add(audioFile); // 跟踪临时文件

        // 记录首字延迟
        if (i == 0 && _synthesisStartTime != null) {
          _firstChunkLatency = DateTime.now().difference(_synthesisStartTime!);
          debugPrint('StreamingTTSService: first chunk latency = ${_firstChunkLatency!.inMilliseconds}ms');
          _stateController.add(StreamingTTSState.firstChunkReady);
        }

        // 启动下一个句子的预取（限制队列大小）
        final nextIndex = i + prefetchCount;
        if (nextIndex < sentences.length && audioFutures.length < maxQueueSize) {
          audioFutures[nextIndex] = _synthesizeToFileWithTimeout(
            sentences[nextIndex], tokenInfo, nextIndex, synthesisTimeout,
          );
        }

        // 播放当前句子
        await _playAudioFile(audioFile);

        // 立即删除已播放的临时文件
        _safeDeleteFile(audioFile);
        tempFiles.remove(audioFile);
      }
    } finally {
      // 确保清理所有临时文件（即使发生异常或取消）
      for (final file in tempFiles) {
        _safeDeleteFile(file);
      }
    }
  }

  /// 带超时保护的合成
  Future<File?> _synthesizeToFileWithTimeout(
    String text,
    VoiceTokenInfo tokenInfo,
    int index,
    Duration timeout,
  ) async {
    try {
      return await _synthesizeToFile(text, tokenInfo, index)
          .timeout(timeout, onTimeout: () {
        debugPrint('StreamingTTSService: synthesis timeout for sentence $index');
        return null;
      });
    } catch (e) {
      debugPrint('StreamingTTSService: synthesis failed for sentence $index - $e');
      return null;
    }
  }

  /// 安全删除文件
  void _safeDeleteFile(File file) {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('StreamingTTSService: failed to delete temp file - $e');
    }
  }

  /// 合成单个句子到文件
  Future<File?> _synthesizeToFile(
    String text,
    VoiceTokenInfo tokenInfo,
    int index,
  ) async {
    try {
      final uri = Uri.parse(tokenInfo.ttsUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
          'text': text,
          'format': 'mp3',
          'voice': _voice,
          'volume': _volume.round().toString(),
          'speech_rate': _rate.round().toString(),
          'pitch_rate': _pitch.round().toString(),
        },
      );

      final response = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          headers: {
            'X-NLS-Token': tokenInfo.token,
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/streaming_tts_${DateTime.now().millisecondsSinceEpoch}_$index.mp3',
        );
        await tempFile.writeAsBytes(response.data!);
        return tempFile;
      }
    } catch (e) {
      debugPrint('StreamingTTSService: synthesize error for sentence $index - $e');
    }
    return null;
  }

  /// 播放音频文件
  Future<void> _playAudioFile(File file) async {
    if (_isCancelled) return;

    try {
      await _streamPlayer.playFile(file.path);
    } catch (e) {
      debugPrint('StreamingTTSService: play error - $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    _isCancelled = true;
    await _streamPlayer.stop();
    _isSpeaking = false;
    _stateController.add(StreamingTTSState.stopped);
    debugPrint('StreamingTTSService: stopped');
  }

  /// 快速淡出停止（用于打断场景）
  Future<void> fadeOutAndStop({Duration duration = const Duration(milliseconds: 100)}) async {
    _isCancelled = true;
    await _streamPlayer.fadeOutAndStop(duration: duration);
    _isSpeaking = false;
    _stateController.add(StreamingTTSState.interrupted);
    debugPrint('StreamingTTSService: fade out stopped');
  }

  /// 设置音色
  void setVoice(String voice) {
    _voice = voice;
  }

  /// 设置语速 (0.5 - 2.0)
  void setRate(double rate) {
    _rate = ((rate - 1.0) * 500).clamp(-500, 500);
  }

  /// 设置音量 (0.0 - 1.0)
  void setVolume(double volume) {
    _volume = (volume * 100).clamp(0, 100);
  }

  /// 设置音调 (0.5 - 2.0)
  void setPitch(double pitch) {
    _pitch = ((pitch - 1.0) * 500).clamp(-500, 500);
  }

  /// 释放资源
  void dispose() {
    stop();
    _stateController.close();
    _streamPlayer.dispose();
    _dio.close();
  }
}

/// 流式TTS状态
enum StreamingTTSState {
  started,          // 开始合成
  firstChunkReady,  // 首块就绪（可开始播放）
  playing,          // 正在播放
  completed,        // 播放完成
  stopped,          // 已停止
  interrupted,      // 被打断（淡出）
  error,            // 错误
}

/// 流式TTS配置
class StreamingTTSConfig {
  /// 预取句子数量
  final int prefetchCount;

  /// 最小句子长度（合并短句）
  final int minSentenceLength;

  /// 是否启用淡出效果
  final bool enableFadeOut;

  /// 淡出时长
  final Duration fadeOutDuration;

  const StreamingTTSConfig({
    this.prefetchCount = 2,
    this.minSentenceLength = 10,
    this.enableFadeOut = true,
    this.fadeOutDuration = const Duration(milliseconds: 100),
  });

  static const defaultConfig = StreamingTTSConfig();
}
