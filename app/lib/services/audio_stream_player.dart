import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// 音频流式播放器
///
/// 支持：
/// 1. 流式播放音频文件
/// 2. 即时停止
/// 3. 音量淡出效果
/// 4. 播放状态监听
class AudioStreamPlayer {
  final AudioPlayer _player;

  bool _isInitialized = false;
  bool _isPlaying = false;

  /// 播放状态流
  final _stateController = StreamController<AudioStreamState>.broadcast();
  Stream<AudioStreamState> get stateStream => _stateController.stream;

  /// 播放器状态订阅（用于正确释放资源）
  StreamSubscription<PlayerState>? _playerStateSubscription;

  /// 当前音量
  double _volume = 1.0;

  AudioStreamPlayer() : _player = AudioPlayer();

  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 配置音频会话，使用媒体播放类型
    // 这样音量键可以控制TTS播放音量
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media, // 使用媒体流，音量键可控制
          flags: AndroidAudioFlags.none,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
      debugPrint('AudioStreamPlayer: audio session configured for media playback');
    } catch (e) {
      debugPrint('AudioStreamPlayer: failed to configure audio session - $e');
    }

    // 监听播放状态（保存订阅以便释放）
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _stateController.add(AudioStreamState.completed);
      }
    });

    _isInitialized = true;
    debugPrint('AudioStreamPlayer: initialized');
  }

  /// 播放文件
  Future<void> playFile(String filePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _isPlaying = true;
      _stateController.add(AudioStreamState.playing);

      // 重置音量
      await _player.setVolume(_volume);

      // 设置音频源并播放
      await _player.setFilePath(filePath);
      await _player.play();

      // 等待播放完成
      await _player.playerStateStream.firstWhere(
        (state) =>
            state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle,
      );

      _isPlaying = false;
    } catch (e) {
      _isPlaying = false;
      _stateController.add(AudioStreamState.error);
      debugPrint('AudioStreamPlayer: play error - $e');
      rethrow;
    }
  }

  /// 播放音频数据
  Future<void> playBytes(List<int> bytes, {String format = 'mp3'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _isPlaying = true;
      _stateController.add(AudioStreamState.playing);

      await _player.setVolume(_volume);

      // 使用 StreamAudioSource 播放内存数据
      final source = _BytesAudioSource(bytes, format);
      await _player.setAudioSource(source);
      await _player.play();

      await _player.playerStateStream.firstWhere(
        (state) =>
            state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle,
      );

      _isPlaying = false;
    } catch (e) {
      _isPlaying = false;
      _stateController.add(AudioStreamState.error);
      debugPrint('AudioStreamPlayer: play bytes error - $e');
      rethrow;
    }
  }

  /// 停止播放
  Future<void> stop() async {
    if (!_isPlaying) return;

    try {
      await _player.stop();
      _isPlaying = false;
      _stateController.add(AudioStreamState.stopped);
    } catch (e) {
      debugPrint('AudioStreamPlayer: stop error - $e');
    }
  }

  /// 淡出并停止
  ///
  /// 平滑降低音量后停止，避免突兀的停止感
  Future<void> fadeOutAndStop({
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    if (!_isPlaying) return;

    try {
      final startVolume = _player.volume;
      final steps = 10;
      final stepDuration = duration ~/ steps;
      final volumeStep = startVolume / steps;

      // 逐步降低音量
      for (var i = 0; i < steps; i++) {
        if (!_isPlaying) break;

        final newVolume = startVolume - (volumeStep * (i + 1));
        await _player.setVolume(newVolume.clamp(0.0, 1.0));
        await Future.delayed(stepDuration);
      }

      // 停止播放
      await _player.stop();

      // 恢复音量设置
      await _player.setVolume(_volume);

      _isPlaying = false;
      _stateController.add(AudioStreamState.fadedOut);
    } catch (e) {
      debugPrint('AudioStreamPlayer: fadeOut error - $e');
      // 确保停止
      await stop();
    }
  }

  /// 暂停
  Future<void> pause() async {
    if (!_isPlaying) return;

    try {
      await _player.pause();
      _stateController.add(AudioStreamState.paused);
    } catch (e) {
      debugPrint('AudioStreamPlayer: pause error - $e');
    }
  }

  /// 恢复
  Future<void> resume() async {
    try {
      await _player.play();
      _isPlaying = true;
      _stateController.add(AudioStreamState.playing);
    } catch (e) {
      debugPrint('AudioStreamPlayer: resume error - $e');
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  /// 获取当前播放位置
  Duration? get position => _player.position;

  /// 获取音频时长
  Duration? get duration => _player.duration;

  /// 释放资源
  Future<void> dispose() async {
    _playerStateSubscription?.cancel();
    await stop();
    await _stateController.close();
    _player.dispose();
  }
}

/// 音频流状态
enum AudioStreamState {
  idle,
  playing,
  paused,
  stopped,
  completed,
  fadedOut,
  error,
}

/// 内存音频源
class _BytesAudioSource extends StreamAudioSource {
  final List<int> _bytes;
  final String _format;

  _BytesAudioSource(this._bytes, this._format);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;

    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: _format == 'mp3' ? 'audio/mpeg' : 'audio/$_format',
    );
  }
}

/// 音频队列播放器
///
/// 支持音频队列播放，用于流式TTS的连续播放
class AudioQueuePlayer {
  final AudioStreamPlayer _player;
  final _queue = <String>[];
  bool _isProcessing = false;

  AudioQueuePlayer() : _player = AudioStreamPlayer();

  /// 添加音频到队列
  void enqueue(String filePath) {
    _queue.add(filePath);
    _processQueue();
  }

  /// 处理队列
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final filePath = _queue.removeAt(0);
      try {
        await _player.playFile(filePath);
      } catch (e) {
        debugPrint('AudioQueuePlayer: play error - $e');
      }
    }

    _isProcessing = false;
  }

  /// 清空队列并停止
  Future<void> stop() async {
    _queue.clear();
    await _player.stop();
    _isProcessing = false;
  }

  /// 淡出停止
  Future<void> fadeOutAndStop({Duration duration = const Duration(milliseconds: 100)}) async {
    _queue.clear();
    await _player.fadeOutAndStop(duration: duration);
    _isProcessing = false;
  }

  /// 释放资源
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
