/// VAD Manager
///
/// 负责语音活动检测(Voice Activity Detection)的管理器。
/// 从 GlobalVoiceAssistantManager 中提取，遵循单一职责原则。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// VAD 事件类型
enum VADEventType {
  /// 检测到语音开始
  speechStart,

  /// 检测到语音结束
  speechEnd,

  /// 静默期间
  silence,

  /// 语音继续中
  speechContinue,
}

/// VAD 事件
class VADEvent {
  final VADEventType type;
  final DateTime timestamp;
  final double? energy;
  final Duration? speechDuration;

  const VADEvent({
    required this.type,
    required this.timestamp,
    this.energy,
    this.speechDuration,
  });
}

/// VAD 配置
class VADConfig {
  /// 能量阈值（0-1）
  final double energyThreshold;

  /// 静默超时（毫秒）
  final int silenceTimeoutMs;

  /// 最小语音时长（毫秒）
  final int minSpeechDurationMs;

  /// 预缓冲时长（毫秒）
  final int preBufferMs;

  const VADConfig({
    this.energyThreshold = 0.01,
    this.silenceTimeoutMs = 1500,
    this.minSpeechDurationMs = 300,
    this.preBufferMs = 300,
  });

  static const defaultConfig = VADConfig();
}

/// VAD 状态
enum VADState {
  idle,
  listening,
  speechDetected,
  silenceDetected,
  error,
}

/// 语音活动检测管理器
///
/// 职责：
/// - 实时分析音频能量
/// - 检测语音开始和结束
/// - 管理语音段落分割
/// - 提供 VAD 事件流
class VADManager extends ChangeNotifier {
  /// VAD 配置
  VADConfig _config;

  /// 当前状态
  VADState _state = VADState.idle;

  /// 音频流订阅
  StreamSubscription<Uint8List>? _audioSubscription;

  /// VAD 事件流控制器
  final StreamController<VADEvent> _eventController =
      StreamController<VADEvent>.broadcast();

  /// 静默计时器
  Timer? _silenceTimer;

  /// 语音开始时间
  DateTime? _speechStartTime;

  /// 是否检测到语音
  bool _isSpeaking = false;

  /// 最近的能量值
  double _currentEnergy = 0.0;

  /// 能量历史（用于平滑）
  final List<double> _energyHistory = [];
  static const int _energyHistorySize = 5;

  VADManager({VADConfig? config}) : _config = config ?? VADConfig.defaultConfig;

  /// 当前状态
  VADState get state => _state;

  /// 是否正在说话
  bool get isSpeaking => _isSpeaking;

  /// 当前能量值
  double get currentEnergy => _currentEnergy;

  /// VAD 事件流
  Stream<VADEvent> get events => _eventController.stream;

  /// 更新配置
  void updateConfig(VADConfig config) {
    _config = config;
    notifyListeners();
  }

  // ==================== 生命周期 ====================

  /// 开始监听音频流
  void startListening(Stream<Uint8List> audioStream) {
    if (_state == VADState.listening) return;

    _state = VADState.listening;
    _isSpeaking = false;
    _speechStartTime = null;
    _energyHistory.clear();

    _audioSubscription = audioStream.listen(
      _processAudioChunk,
      onError: (error) {
        debugPrint('[VADManager] 音频流错误: $error');
        _updateState(VADState.error);
      },
    );

    debugPrint('[VADManager] 开始监听');
    notifyListeners();
  }

  /// 停止监听
  Future<void> stopListening() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    _state = VADState.idle;
    _isSpeaking = false;
    _speechStartTime = null;

    debugPrint('[VADManager] 停止监听');
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    stopListening();
    _eventController.close();
    super.dispose();
  }

  // ==================== 音频处理 ====================

  /// 处理音频数据块
  void _processAudioChunk(Uint8List audioData) {
    // 计算能量
    final energy = _calculateEnergy(audioData);
    _currentEnergy = energy;

    // 添加到历史并平滑
    _energyHistory.add(energy);
    if (_energyHistory.length > _energyHistorySize) {
      _energyHistory.removeAt(0);
    }
    final smoothedEnergy = _energyHistory.reduce((a, b) => a + b) / _energyHistory.length;

    // 判断是否有语音
    final hasVoice = smoothedEnergy > _config.energyThreshold;

    if (hasVoice) {
      _onVoiceDetected();
    } else {
      _onSilenceDetected();
    }
  }

  /// 计算音频能量
  double _calculateEnergy(Uint8List audioData) {
    if (audioData.isEmpty) return 0.0;

    // 将字节转换为 16 位样本
    double sum = 0.0;
    for (int i = 0; i < audioData.length - 1; i += 2) {
      final sample = (audioData[i + 1] << 8) | audioData[i];
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      sum += signedSample * signedSample;
    }

    // 计算 RMS 能量并归一化
    final rms = (sum / (audioData.length / 2));
    return (rms / 32768 / 32768).clamp(0.0, 1.0);
  }

  /// 检测到语音
  void _onVoiceDetected() {
    // 取消静默计时器
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (!_isSpeaking) {
      // 语音开始
      _isSpeaking = true;
      _speechStartTime = DateTime.now();
      _updateState(VADState.speechDetected);

      _emitEvent(VADEvent(
        type: VADEventType.speechStart,
        timestamp: DateTime.now(),
        energy: _currentEnergy,
      ));

      debugPrint('[VADManager] 检测到语音开始');
    } else {
      // 语音继续
      _emitEvent(VADEvent(
        type: VADEventType.speechContinue,
        timestamp: DateTime.now(),
        energy: _currentEnergy,
        speechDuration: _speechStartTime != null
            ? DateTime.now().difference(_speechStartTime!)
            : null,
      ));
    }
  }

  /// 检测到静默
  void _onSilenceDetected() {
    if (!_isSpeaking) {
      // 持续静默
      _emitEvent(VADEvent(
        type: VADEventType.silence,
        timestamp: DateTime.now(),
        energy: _currentEnergy,
      ));
      return;
    }

    // 开始静默计时
    if (_silenceTimer == null) {
      _silenceTimer = Timer(
        Duration(milliseconds: _config.silenceTimeoutMs),
        _onSilenceTimeout,
      );
    }
  }

  /// 静默超时
  void _onSilenceTimeout() {
    if (!_isSpeaking) return;

    final speechDuration = _speechStartTime != null
        ? DateTime.now().difference(_speechStartTime!)
        : Duration.zero;

    // 检查是否达到最小语音时长
    if (speechDuration.inMilliseconds >= _config.minSpeechDurationMs) {
      _isSpeaking = false;
      _updateState(VADState.silenceDetected);

      _emitEvent(VADEvent(
        type: VADEventType.speechEnd,
        timestamp: DateTime.now(),
        energy: _currentEnergy,
        speechDuration: speechDuration,
      ));

      debugPrint('[VADManager] 检测到语音结束，时长: ${speechDuration.inMilliseconds}ms');
    } else {
      // 语音太短，视为噪音
      _isSpeaking = false;
      debugPrint('[VADManager] 语音太短，忽略');
    }

    _speechStartTime = null;
    _silenceTimer = null;
  }

  /// 发送事件
  void _emitEvent(VADEvent event) {
    _eventController.add(event);
  }

  /// 更新状态
  void _updateState(VADState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }
}
