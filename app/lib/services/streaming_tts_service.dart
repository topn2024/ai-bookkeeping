import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'voice_token_service.dart';
import 'audio_stream_player.dart';
import 'voice/pcm_audio_player.dart';

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
  final PCMAudioPlayer _pcmPlayer;

  /// TTS设置
  /// 使用 zhitian_emo（知甜情感女声）- 更自然动听的年轻女性声音
  String _voice = 'zhitian_emo';
  double _rate = 0;
  double _volume = 90;  // 默认音量调高到90%
  double _pitch = 0;

  /// 是否使用PCM模式（用于AEC）
  bool _usePCMMode = true;

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

  /// AEC参考信号回调
  ///
  /// 当播放PCM音频时，会调用此回调将音频数据传递给AEC
  void Function(Uint8List pcmData)? onAudioPlayed;

  StreamingTTSService({VoiceTokenService? tokenService})
      : _tokenService = tokenService ?? VoiceTokenService(),
        _dio = Dio(),
        _streamPlayer = AudioStreamPlayer(),
        _pcmPlayer = PCMAudioPlayer() {
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _streamPlayer.initialize();

    // 初始化PCM播放器
    if (_usePCMMode) {
      await _pcmPlayer.initialize(sampleRate: 16000, channelCount: 1);
      // 设置AEC回调
      _pcmPlayer.onAudioPlayed = (pcmData) {
        onAudioPlayed?.call(pcmData);
      };
    }

    _isInitialized = true;
    debugPrint('StreamingTTSService: initialized (PCM mode: $_usePCMMode)');
  }

  /// 设置是否使用PCM模式（用于AEC）
  void setUsePCMMode(bool usePCM) {
    _usePCMMode = usePCM;
    debugPrint('StreamingTTSService: PCM mode = $usePCM');
  }

  /// 预热连接（提前建立HTTP连接，减少首次合成延迟）
  ///
  /// 通过发送一个静默请求来预热：
  /// - 获取并缓存Token
  /// - 建立TCP/SSL连接
  /// - 触发服务端缓存
  ///
  /// 建议在应用启动时调用，可节省200-500ms首次延迟
  Future<void> warmup() async {
    if (!_isInitialized) {
      await initialize();
    }

    final startTime = DateTime.now();
    debugPrint('StreamingTTSService: 开始预热连接...');

    try {
      // 1. 预获取Token（触发Token缓存）
      final tokenInfo = await _tokenService.getToken();

      // 2. 发送一个最小化请求预热连接（使用一个标点符号，不产生实际音频）
      String ttsRestUrl = tokenInfo.ttsUrl;
      if (ttsRestUrl.startsWith('wss://')) {
        ttsRestUrl = ttsRestUrl
            .replaceFirst('wss://', 'https://')
            .replaceFirst('/ws/v1', '/stream/v1/tts');
      } else if (ttsRestUrl.startsWith('ws://')) {
        ttsRestUrl = ttsRestUrl
            .replaceFirst('ws://', 'http://')
            .replaceFirst('/ws/v1', '/stream/v1/tts');
      }

      final uri = Uri.parse(ttsRestUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
          'text': '。',  // 最短文本，最小化服务端处理
          'format': 'pcm',
          'sample_rate': '16000',
          'voice': _voice,
        },
      );

      // 发送请求但不处理响应（仅预热连接）
      await _dio.getUri<List<int>>(
        uri,
        options: Options(
          headers: {'X-NLS-Token': tokenInfo.token},
          responseType: ResponseType.bytes,
        ),
      );

      final elapsed = DateTime.now().difference(startTime);
      debugPrint('StreamingTTSService: 预热完成 (${elapsed.inMilliseconds}ms)');
    } catch (e) {
      debugPrint('StreamingTTSService: 预热失败（不影响后续使用）: $e');
    }
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
    if (_usePCMMode) {
      await _synthesizeAndPlayPCM(sentences, tokenInfo);
    } else {
      await _synthesizeAndPlayMP3(sentences, tokenInfo);
    }
  }

  /// PCM模式：合成并播放（用于AEC）
  Future<void> _synthesizeAndPlayPCM(
    List<String> sentences,
    VoiceTokenInfo tokenInfo,
  ) async {
    const prefetchCount = 2;
    const maxQueueSize = 5;
    const synthesisTimeout = Duration(seconds: 15);

    final audioFutures = <int, Future<Uint8List?>>{};
    int successCount = 0;

    try {
      // 启动预取
      for (var i = 0; i < sentences.length && i < prefetchCount; i++) {
        audioFutures[i] = _synthesizeToPCMWithTimeout(
          sentences[i], tokenInfo, i, synthesisTimeout,
        );
      }

      // 边合成边播放
      for (var i = 0; i < sentences.length; i++) {
        if (_isCancelled) break;

        final future = audioFutures[i];
        if (future == null) {
          debugPrint('StreamingTTSService: missing future for sentence $i');
          continue;
        }

        final pcmData = await future;
        audioFutures.remove(i);

        if (pcmData == null || _isCancelled) continue;

        successCount++;

        // 记录首字延迟
        if (i == 0 && _synthesisStartTime != null) {
          _firstChunkLatency = DateTime.now().difference(_synthesisStartTime!);
          debugPrint('StreamingTTSService: first chunk latency = ${_firstChunkLatency!.inMilliseconds}ms (PCM)');
          _stateController.add(StreamingTTSState.firstChunkReady);
        }

        // 预取下一个
        final nextIndex = i + prefetchCount;
        if (nextIndex < sentences.length && audioFutures.length < maxQueueSize) {
          audioFutures[nextIndex] = _synthesizeToPCMWithTimeout(
            sentences[nextIndex], tokenInfo, nextIndex, synthesisTimeout,
          );
        }

        // 播放PCM（同时触发AEC回调）
        await _pcmPlayer.playPCM(pcmData);
      }

      if (successCount == 0 && sentences.isNotEmpty && !_isCancelled) {
        throw Exception('All sentences synthesis failed');
      }
    } catch (e) {
      debugPrint('StreamingTTSService: PCM playback error - $e');
      rethrow;
    }
  }

  /// MP3模式：合成并播放（原有逻辑）
  Future<void> _synthesizeAndPlayMP3(
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
    int successCount = 0; // 记录成功合成的句子数

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

        successCount++; // 记录成功

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
        await _safeDeleteFile(audioFile);
        tempFiles.remove(audioFile);
      }

      // 如果所有句子都合成失败，抛出异常以便降级到离线TTS
      if (successCount == 0 && sentences.isNotEmpty && !_isCancelled) {
        throw Exception('All sentences synthesis failed');
      }
    } finally {
      // 确保清理所有临时文件（即使发生异常或取消）
      for (final file in tempFiles) {
        await _safeDeleteFile(file);
      }
    }
  }

  /// 带超时保护的合成（MP3文件）
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

  /// 带超时保护的合成（PCM数据）
  Future<Uint8List?> _synthesizeToPCMWithTimeout(
    String text,
    VoiceTokenInfo tokenInfo,
    int index,
    Duration timeout,
  ) async {
    try {
      return await _synthesizeToPCM(text, tokenInfo, index)
          .timeout(timeout, onTimeout: () {
        debugPrint('StreamingTTSService: PCM synthesis timeout for sentence $index');
        return null;
      });
    } catch (e) {
      debugPrint('StreamingTTSService: PCM synthesis failed for sentence $index - $e');
      return null;
    }
  }

  /// 合成单个句子到PCM数据
  Future<Uint8List?> _synthesizeToPCM(
    String text,
    VoiceTokenInfo tokenInfo,
    int index,
  ) async {
    try {
      String ttsRestUrl = tokenInfo.ttsUrl;
      if (ttsRestUrl.startsWith('wss://')) {
        ttsRestUrl = ttsRestUrl
            .replaceFirst('wss://', 'https://')
            .replaceFirst('/ws/v1', '/stream/v1/tts');
      } else if (ttsRestUrl.startsWith('ws://')) {
        ttsRestUrl = ttsRestUrl
            .replaceFirst('ws://', 'http://')
            .replaceFirst('/ws/v1', '/stream/v1/tts');
      }

      final uri = Uri.parse(ttsRestUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
          'text': text,
          'format': 'pcm',  // 请求PCM格式
          'sample_rate': '16000',  // 16kHz采样率
          'voice': _voice,
          'volume': _volume.round().toString(),
          'speech_rate': _rate.round().toString(),
          'pitch_rate': _pitch.round().toString(),
        },
      );

      debugPrint('StreamingTTSService: requesting PCM for sentence $index');
      debugPrint('StreamingTTSService: URL = $uri');
      debugPrint('StreamingTTSService: Token = ${tokenInfo.token.substring(0, 8)}...');

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
        final pcmData = Uint8List.fromList(response.data!);
        debugPrint('StreamingTTSService: received ${pcmData.length} bytes PCM for sentence $index');
        return pcmData;
      }
    } catch (e) {
      debugPrint('StreamingTTSService: PCM synthesize error for sentence $index - $e');
    }
    return null;
  }

  /// 安全删除文件
  Future<void> _safeDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
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
      // TTS REST API URL（将 wss:// WebSocket URL 转换为 https:// REST URL）
      // wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1
      // -> https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/tts
      String ttsRestUrl = tokenInfo.ttsUrl;
      if (ttsRestUrl.startsWith('wss://')) {
        ttsRestUrl = ttsRestUrl
            .replaceFirst('wss://', 'https://')
            .replaceFirst('/ws/v1', '/stream/v1/tts');
      } else if (ttsRestUrl.startsWith('ws://')) {
        ttsRestUrl = ttsRestUrl
            .replaceFirst('ws://', 'http://')
            .replaceFirst('/ws/v1', '/stream/v1/tts');
      }

      final uri = Uri.parse(ttsRestUrl).replace(
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
    await _pcmPlayer.stop();
    _isSpeaking = false;
    _stateController.add(StreamingTTSState.stopped);
    debugPrint('StreamingTTSService: stopped');
  }

  /// 快速淡出停止（用于打断场景）
  Future<void> fadeOutAndStop({Duration duration = const Duration(milliseconds: 100)}) async {
    _isCancelled = true;
    await _streamPlayer.fadeOutAndStop(duration: duration);
    await _pcmPlayer.stop();  // PCM播放器不支持淡出，直接停止
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
    // 同时设置播放器音量
    _streamPlayer.setVolume(volume);
    _pcmPlayer.setVolume(volume);
  }

  /// 设置音调 (0.5 - 2.0)
  void setPitch(double pitch) {
    _pitch = ((pitch - 1.0) * 500).clamp(-500, 500);
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await stop();
    } catch (e) {
      debugPrint('[StreamingTTSService] dispose 中 stop 失败: $e');
    }
    await _stateController.close().catchError((e) {
      debugPrint('[StreamingTTSService] 关闭 StateController 异常: $e');
    });
    _streamPlayer.dispose();
    await _pcmPlayer.dispose();
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
