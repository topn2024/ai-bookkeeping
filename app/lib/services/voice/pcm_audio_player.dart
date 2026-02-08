import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// PCM音频播放器
///
/// 使用 flutter_pcm_sound 实现低延迟PCM播放
/// 同时将播放数据传递给AEC作为参考信号
///
/// 使用方式：
/// ```dart
/// final player = PCMAudioPlayer();
/// await player.initialize();
///
/// // 设置AEC回调
/// player.onAudioPlayed = (pcmData) {
///   audioProcessor.feedTTSAudio(pcmData);
/// };
///
/// // 播放PCM数据
/// await player.playPCM(pcmData);
/// ```
class PCMAudioPlayer {
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// 采样率
  int _sampleRate = 16000;

  /// 声道数
  int _channelCount = 1;

  /// 音量 (0.0 - 1.0)
  double _volume = 1.0;

  /// AEC参考信号回调
  ///
  /// 每次播放PCM数据时会调用此回调，用于将音频数据传递给AEC
  void Function(Uint8List pcmData)? onAudioPlayed;

  /// 播放状态流
  final _stateController = StreamController<PCMPlayerState>.broadcast();
  Stream<PCMPlayerState> get stateStream => _stateController.stream;

  /// 播放完成的Completer
  Completer<void>? _playCompleter;

  /// 待播放的数据队列
  final List<Uint8List> _pendingData = [];

  /// 是否正在feed数据
  bool _isFeeding = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 设置音量 (0.0 - 1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    debugPrint('[PCMAudioPlayer] 设置音量: ${(_volume * 100).round()}%');
  }

  /// 对PCM数据应用音量
  Uint8List _applyVolume(Uint8List pcmData) {
    if (_volume >= 0.99) return pcmData; // 接近最大音量，无需处理

    // PCM16是小端格式，每个样本2字节
    final byteData = ByteData.view(pcmData.buffer, pcmData.offsetInBytes, pcmData.length);
    final result = Uint8List(pcmData.length);
    final resultData = ByteData.view(result.buffer);

    for (int i = 0; i < pcmData.length; i += 2) {
      final sample = byteData.getInt16(i, Endian.little);
      final adjusted = (sample * _volume).round().clamp(-32768, 32767);
      resultData.setInt16(i, adjusted, Endian.little);
    }

    return result;
  }

  /// 初始化播放器
  ///
  /// [sampleRate] 采样率，默认16000（与ASR一致）
  /// [channelCount] 声道数，默认1（单声道）
  Future<void> initialize({
    int sampleRate = 16000,
    int channelCount = 1,
  }) async {
    if (_isInitialized) {
      debugPrint('[PCMAudioPlayer] 已初始化');
      return;
    }

    _sampleRate = sampleRate;
    _channelCount = channelCount;

    try {
      // 设置日志级别
      await FlutterPcmSound.setLogLevel(LogLevel.error);

      // 初始化音频
      await FlutterPcmSound.setup(
        sampleRate: sampleRate,
        channelCount: channelCount,
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );

      // 设置缓冲阈值和回调
      await FlutterPcmSound.setFeedThreshold(sampleRate ~/ 10); // 100ms缓冲
      FlutterPcmSound.setFeedCallback(_onFeedCallback);

      _isInitialized = true;
      debugPrint('[PCMAudioPlayer] 初始化成功 (sampleRate=$sampleRate, channels=$channelCount)');
    } catch (e) {
      debugPrint('[PCMAudioPlayer] 初始化失败: $e');
      rethrow;
    }
  }

  /// 等待硬件播放完成的延迟（毫秒）
  /// 音频硬件有自己的缓冲区，需要额外等待以确保完全播放
  static const int _hardwareBufferDelayMs = 300;

  /// Feed回调 - 当缓冲区需要更多数据时调用
  void _onFeedCallback(int remainingFrames) {
    if (remainingFrames == 0) {
      // 缓冲区为空，但需要等待硬件播放完成
      _onBufferDrained();
    } else if (_pendingData.isNotEmpty && !_isFeeding) {
      // 还有待播放数据，继续feed
      _feedNextChunk();
    }
  }

  /// 缓冲区已排空，等待硬件播放完成
  void _onBufferDrained() {
    if (_pendingData.isEmpty && _isPlaying) {
      // 添加延迟等待硬件缓冲区播放完成
      Future.delayed(const Duration(milliseconds: _hardwareBufferDelayMs), () {
        _onPlaybackComplete();
      });
    }
  }

  /// 播放完成处理
  void _onPlaybackComplete() {
    if (_pendingData.isEmpty && _isPlaying) {
      _isPlaying = false;
      _stateController.add(PCMPlayerState.completed);
      _playCompleter?.complete();
      _playCompleter = null;
      debugPrint('[PCMAudioPlayer] 播放完成（含硬件缓冲延迟）');
    }
  }

  /// Feed下一块数据
  Future<void> _feedNextChunk() async {
    if (_pendingData.isEmpty || _isFeeding) return;

    _isFeeding = true;
    try {
      final chunk = _pendingData.removeAt(0);
      await _feedPCMData(chunk);
    } finally {
      _isFeeding = false;
    }
  }

  /// 播放PCM数据
  ///
  /// [pcmData] PCM16格式的音频数据（16kHz，单声道）
  /// 播放的同时会触发onAudioPlayed回调用于AEC
  Future<void> playPCM(Uint8List pcmData) async {
    if (!_isInitialized) {
      debugPrint('[PCMAudioPlayer] 未初始化，正在初始化...');
      await initialize(sampleRate: _sampleRate, channelCount: _channelCount);
    }

    if (pcmData.isEmpty) {
      debugPrint('[PCMAudioPlayer] 空数据，跳过');
      return;
    }

    debugPrint('[PCMAudioPlayer] 播放PCM数据: ${pcmData.length}字节');

    _isPlaying = true;
    _stateController.add(PCMPlayerState.playing);

    // 创建完成Completer并保存本地引用
    // 防止在异步等待期间被其他调用覆盖
    final completer = Completer<void>();
    _playCompleter = completer;

    // 触发AEC回调
    onAudioPlayed?.call(pcmData);

    // Feed数据到播放器
    await _feedPCMData(pcmData);

    // 启动播放
    FlutterPcmSound.start();

    // 等待播放完成（使用本地引用确保等待正确的Completer）
    await completer.future;
  }

  /// 将PCM数据添加到队列并播放
  ///
  /// 用于流式播放，可以连续添加多个数据块
  Future<void> queuePCM(Uint8List pcmData) async {
    if (!_isInitialized) {
      await initialize(sampleRate: _sampleRate, channelCount: _channelCount);
    }

    if (pcmData.isEmpty) return;

    // 触发AEC回调
    onAudioPlayed?.call(pcmData);

    // 添加到队列
    _pendingData.add(pcmData);

    // 如果没有在播放，开始播放
    if (!_isPlaying) {
      _isPlaying = true;
      _stateController.add(PCMPlayerState.playing);
      _playCompleter = Completer<void>();
      await _feedNextChunk();
      FlutterPcmSound.start();
    }
  }

  /// 等待当前播放完成
  Future<void> waitForCompletion() async {
    await _playCompleter?.future;
  }

  /// Feed PCM数据到播放器
  Future<void> _feedPCMData(Uint8List pcmData) async {
    try {
      // 应用音量调节
      final adjustedData = _applyVolume(pcmData);
      // 将Uint8List转换为PcmArrayInt16
      final pcmArray = _uint8ListToPcmArray(adjustedData);
      await FlutterPcmSound.feed(pcmArray);
    } catch (e) {
      debugPrint('[PCMAudioPlayer] Feed数据失败: $e');
      rethrow;
    }
  }

  /// 将Uint8List转换为PcmArrayInt16
  PcmArrayInt16 _uint8ListToPcmArray(Uint8List data) {
    // PCM16是小端格式，每个样本2字节
    final byteData = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    return PcmArrayInt16(bytes: byteData);
  }

  /// 停止播放
  Future<void> stop() async {
    if (!_isPlaying) return;

    debugPrint('[PCMAudioPlayer] 停止播放');

    _pendingData.clear();
    _isPlaying = false;
    _stateController.add(PCMPlayerState.stopped);

    // 完成等待
    _playCompleter?.complete();
    _playCompleter = null;

    // 释放并重新初始化以清空缓冲
    await FlutterPcmSound.release();
    _isInitialized = false;
  }

  /// 释放资源
  Future<void> dispose() async {
    debugPrint('[PCMAudioPlayer] 释放资源');

    await stop();
    await _stateController.close();

    try {
      await FlutterPcmSound.release();
    } catch (e) {
      debugPrint('[PCMAudioPlayer] 释放异常: $e');
    }

    _isInitialized = false;
  }
}

/// PCM播放器状态
enum PCMPlayerState {
  idle,
  playing,
  stopped,
  completed,
  error,
}
