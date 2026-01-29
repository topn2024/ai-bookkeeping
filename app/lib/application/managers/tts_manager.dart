/// TTS Manager
///
/// 负责文本转语音的管理器，从 GlobalVoiceAssistantManager 中提取。
/// 遵循单一职责原则，仅处理 TTS 相关逻辑。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// TTS 状态
enum TTSState {
  idle,
  preparing,
  playing,
  paused,
  completed,
  error,
}

/// TTS 事件类型
enum TTSEventType {
  started,
  progress,
  completed,
  cancelled,
  error,
}

/// TTS 事件
class TTSEvent {
  final TTSEventType type;
  final String? text;
  final double? progress;
  final String? errorMessage;

  const TTSEvent({
    required this.type,
    this.text,
    this.progress,
    this.errorMessage,
  });
}

/// TTS 配置
class TTSConfig {
  /// 音量 (0.0 - 1.0)
  final double volume;

  /// 语速 (0.5 - 2.0)
  final double speechRate;

  /// 音调 (0.5 - 2.0)
  final double pitch;

  /// 语言
  final String language;

  const TTSConfig({
    this.volume = 1.0,
    this.speechRate = 1.0,
    this.pitch = 1.0,
    this.language = 'zh-CN',
  });

  static const defaultConfig = TTSConfig();

  TTSConfig copyWith({
    double? volume,
    double? speechRate,
    double? pitch,
    String? language,
  }) {
    return TTSConfig(
      volume: volume ?? this.volume,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      language: language ?? this.language,
    );
  }
}

/// TTS 管理器
///
/// 职责：
/// - 管理 TTS 服务生命周期
/// - 控制语音播放
/// - 管理播放队列
/// - 提供播放状态
class TTSManager extends ChangeNotifier {
  /// TTS 服务接口
  final ITTSEngine _engine;

  /// 配置
  TTSConfig _config;

  /// 当前状态
  TTSState _state = TTSState.idle;

  /// 播放队列
  final List<String> _queue = [];

  /// 当前播放的文本
  String? _currentText;

  /// 事件流控制器
  final StreamController<TTSEvent> _eventController =
      StreamController<TTSEvent>.broadcast();

  TTSManager({
    required ITTSEngine engine,
    TTSConfig? config,
  })  : _engine = engine,
        _config = config ?? TTSConfig.defaultConfig {
    _applyConfig();
  }

  /// 当前状态
  TTSState get state => _state;

  /// 是否正在播放
  bool get isPlaying => _state == TTSState.playing;

  /// 是否空闲
  bool get isIdle => _state == TTSState.idle;

  /// 当前播放的文本
  String? get currentText => _currentText;

  /// 队列长度
  int get queueLength => _queue.length;

  /// 配置
  TTSConfig get config => _config;

  /// 事件流
  Stream<TTSEvent> get events => _eventController.stream;

  /// 更新配置
  void updateConfig(TTSConfig config) {
    _config = config;
    _applyConfig();
    notifyListeners();
  }

  // ==================== 播放控制 ====================

  /// 播放文本
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    _currentText = text;
    _updateState(TTSState.preparing);

    try {
      _emitEvent(TTSEvent(type: TTSEventType.started, text: text));
      _updateState(TTSState.playing);

      await _engine.speak(text);

      _emitEvent(TTSEvent(type: TTSEventType.completed, text: text));
      _updateState(TTSState.completed);

      // 播放队列中的下一个
      _playNext();
    } catch (e) {
      debugPrint('[TTSManager] 播放失败: $e');
      _emitEvent(TTSEvent(
        type: TTSEventType.error,
        text: text,
        errorMessage: e.toString(),
      ));
      _updateState(TTSState.error);
    }
  }

  /// 添加到队列并播放
  Future<void> speakQueued(String text) async {
    _queue.add(text);
    notifyListeners();

    if (isIdle || _state == TTSState.completed) {
      _playNext();
    }
  }

  /// 停止播放
  Future<void> stop() async {
    if (!isPlaying) return;

    try {
      await _engine.stop();
      _emitEvent(TTSEvent(type: TTSEventType.cancelled, text: _currentText));
      _currentText = null;
      _updateState(TTSState.idle);
      debugPrint('[TTSManager] 播放已停止');
    } catch (e) {
      debugPrint('[TTSManager] 停止失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    if (!isPlaying) return;

    try {
      await _engine.pause();
      _updateState(TTSState.paused);
      debugPrint('[TTSManager] 播放已暂停');
    } catch (e) {
      debugPrint('[TTSManager] 暂停失败: $e');
    }
  }

  /// 恢复播放
  Future<void> resume() async {
    if (_state != TTSState.paused) return;

    try {
      await _engine.resume();
      _updateState(TTSState.playing);
      debugPrint('[TTSManager] 播放已恢复');
    } catch (e) {
      debugPrint('[TTSManager] 恢复失败: $e');
    }
  }

  /// 清空队列
  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  /// 停止并清空队列
  Future<void> stopAndClear() async {
    await stop();
    clearQueue();
  }

  // ==================== 私有方法 ====================

  /// 播放队列中的下一个
  void _playNext() {
    if (_queue.isEmpty) {
      _currentText = null;
      _updateState(TTSState.idle);
      return;
    }

    final nextText = _queue.removeAt(0);
    speak(nextText);
  }

  /// 应用配置
  void _applyConfig() {
    _engine.setVolume(_config.volume);
    _engine.setSpeechRate(_config.speechRate);
    _engine.setPitch(_config.pitch);
  }

  /// 更新状态
  void _updateState(TTSState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// 发送事件
  void _emitEvent(TTSEvent event) {
    _eventController.add(event);
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}

/// TTS 引擎接口
abstract class ITTSEngine {
  /// 播放文本
  Future<void> speak(String text);

  /// 停止播放
  Future<void> stop();

  /// 暂停播放
  Future<void> pause();

  /// 恢复播放
  Future<void> resume();

  /// 设置音量
  void setVolume(double volume);

  /// 设置语速
  void setSpeechRate(double rate);

  /// 设置音调
  void setPitch(double pitch);

  /// 是否正在播放
  bool get isSpeaking;
}
