import 'dart:async';

import 'package:flutter/foundation.dart';

/// Barge-in（打断）检测器
///
/// 检测用户在AI说话时开始说话的行为，实现自然的打断交互
///
/// 检测策略：
/// 1. 能量阈值检测 - 检测音频能量是否超过TTS输出
/// 2. VAD检测 - 使用语音活动检测判断用户是否在说话
/// 3. 关键词检测 - 识别"停"、"等等"等打断关键词
class BargeInDetector {
  /// 配置
  final BargeInConfig _config;

  /// 是否启用
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  /// 当前TTS是否正在播放
  bool _isTTSPlaying = false;

  /// 打断检测状态
  BargeInState _state = BargeInState.idle;
  BargeInState get state => _state;

  /// 音频能量历史（用于计算平均值）
  final List<double> _energyHistory = [];
  static const int _energyHistorySize = 10;

  /// 当前TTS音量估计（用于对比）
  double _estimatedTTSVolume = 0.0;

  /// 打断事件流
  final _eventController = StreamController<BargeInEvent>.broadcast();
  Stream<BargeInEvent> get eventStream => _eventController.stream;

  /// 打断回调
  void Function()? onBargeInDetected;
  void Function(String keyword)? onKeywordDetected;

  BargeInDetector({BargeInConfig? config})
      : _config = config ?? BargeInConfig.defaultConfig;

  /// 启动检测
  void start() {
    _isEnabled = true;
    _state = BargeInState.monitoring;
    debugPrint('BargeInDetector: started');
  }

  /// 停止检测
  void stop() {
    _isEnabled = false;
    _state = BargeInState.idle;
    _energyHistory.clear();
    debugPrint('BargeInDetector: stopped');
  }

  /// 通知TTS开始播放
  void notifyTTSStarted({double estimatedVolume = 0.5}) {
    _isTTSPlaying = true;
    _estimatedTTSVolume = estimatedVolume;
    _state = BargeInState.monitoring;
    debugPrint('BargeInDetector: TTS started, monitoring for barge-in');
  }

  /// 通知TTS停止播放
  void notifyTTSStopped() {
    _isTTSPlaying = false;
    _estimatedTTSVolume = 0.0;
    _state = BargeInState.idle;
    debugPrint('BargeInDetector: TTS stopped');
  }

  /// 处理音频数据
  ///
  /// 在TTS播放期间持续接收麦克风音频数据进行分析
  void processAudioData(Float32List audioData) {
    if (!_isEnabled || !_isTTSPlaying) return;

    // 计算音频能量
    final energy = _calculateEnergy(audioData);

    // 更新能量历史
    _energyHistory.add(energy);
    if (_energyHistory.length > _energyHistorySize) {
      _energyHistory.removeAt(0);
    }

    // 检测打断
    if (_detectBargeIn(energy)) {
      _handleBargeInDetected(BargeInSource.energy);
    }
  }

  /// 处理VAD结果
  ///
  /// 接收VAD检测结果
  void processVADResult(bool isSpeaking) {
    if (!_isEnabled || !_isTTSPlaying) return;

    if (isSpeaking) {
      // VAD检测到用户在说话
      _state = BargeInState.userSpeaking;

      // 如果配置了VAD优先，直接触发打断
      if (_config.vadPriority) {
        _handleBargeInDetected(BargeInSource.vad);
      }
    } else {
      if (_state == BargeInState.userSpeaking) {
        _state = BargeInState.monitoring;
      }
    }
  }

  /// 处理ASR结果（用于关键词检测）
  ///
  /// 接收流式ASR结果，检测打断关键词
  void processASRResult(String text) {
    if (!_isEnabled || !_isTTSPlaying) return;

    // 检测打断关键词
    final keyword = _detectInterruptKeyword(text);
    if (keyword != null) {
      _handleKeywordDetected(keyword);
    }
  }

  /// 计算音频能量
  double _calculateEnergy(Float32List audioData) {
    if (audioData.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in audioData) {
      sum += sample * sample;
    }
    return sum / audioData.length;
  }

  /// 检测打断
  bool _detectBargeIn(double currentEnergy) {
    if (_energyHistory.isEmpty) return false;

    // 计算平均能量
    final avgEnergy = _energyHistory.reduce((a, b) => a + b) / _energyHistory.length;

    // 如果当前能量显著高于TTS估计值，可能是用户在说话
    final threshold = _estimatedTTSVolume * _config.energyThresholdMultiplier;

    // 使用相对变化检测（突然增加的能量）
    final energyIncrease = currentEnergy / (avgEnergy + 0.0001);

    return currentEnergy > threshold && energyIncrease > _config.energyIncreaseThreshold;
  }

  /// 检测打断关键词
  String? _detectInterruptKeyword(String text) {
    final lowerText = text.toLowerCase();

    for (final keyword in _config.interruptKeywords) {
      if (lowerText.contains(keyword)) {
        return keyword;
      }
    }

    return null;
  }

  /// 处理打断检测
  void _handleBargeInDetected(BargeInSource source) {
    if (_state == BargeInState.bargeInDetected) return;

    _state = BargeInState.bargeInDetected;

    final event = BargeInEvent(
      type: BargeInEventType.detected,
      source: source,
      timestamp: DateTime.now(),
    );

    _eventController.add(event);
    onBargeInDetected?.call();

    debugPrint('BargeInDetector: barge-in detected from $source');
  }

  /// 处理关键词检测
  void _handleKeywordDetected(String keyword) {
    _state = BargeInState.bargeInDetected;

    final event = BargeInEvent(
      type: BargeInEventType.keywordDetected,
      source: BargeInSource.keyword,
      keyword: keyword,
      timestamp: DateTime.now(),
    );

    _eventController.add(event);
    onKeywordDetected?.call(keyword);

    debugPrint('BargeInDetector: interrupt keyword detected: $keyword');
  }

  /// 重置状态
  void reset() {
    _state = BargeInState.idle;
    _energyHistory.clear();
    debugPrint('BargeInDetector: reset');
  }

  /// 释放资源
  void dispose() {
    stop();
    _eventController.close();
  }
}

// ==================== 状态和事件定义 ====================

/// 打断检测状态
enum BargeInState {
  idle,              // 空闲（TTS未播放）
  monitoring,        // 监控中（TTS播放中，等待打断）
  userSpeaking,      // 用户正在说话
  bargeInDetected,   // 检测到打断
}

/// 打断来源
enum BargeInSource {
  energy,   // 能量检测
  vad,      // VAD检测
  keyword,  // 关键词检测
}

/// 打断事件类型
enum BargeInEventType {
  detected,         // 检测到打断
  keywordDetected,  // 检测到打断关键词
  cancelled,        // 打断取消（误检）
}

/// 打断事件
class BargeInEvent {
  final BargeInEventType type;
  final BargeInSource source;
  final String? keyword;
  final DateTime timestamp;

  BargeInEvent({
    required this.type,
    required this.source,
    this.keyword,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'BargeInEvent(type: $type, source: $source, keyword: $keyword)';
  }
}

/// 打断检测配置
class BargeInConfig {
  /// 能量阈值倍数（相对于TTS音量）
  final double energyThresholdMultiplier;

  /// 能量增加阈值（相对于平均能量的倍数）
  final double energyIncreaseThreshold;

  /// 打断关键词列表
  final List<String> interruptKeywords;

  /// VAD是否优先（VAD检测到就触发打断）
  final bool vadPriority;

  /// 打断确认延迟（避免误检）
  final Duration confirmationDelay;

  /// 打断后的冷却时间
  final Duration cooldownDuration;

  const BargeInConfig({
    this.energyThresholdMultiplier = 1.5,
    this.energyIncreaseThreshold = 2.0,
    this.interruptKeywords = const [
      '停',
      '等等',
      '等一下',
      '算了',
      '不对',
      '不是',
      '停止',
      '打住',
    ],
    this.vadPriority = true,
    this.confirmationDelay = const Duration(milliseconds: 100),
    this.cooldownDuration = const Duration(milliseconds: 500),
  });

  static const defaultConfig = BargeInConfig();

  /// 高灵敏度配置
  static const highSensitivity = BargeInConfig(
    energyThresholdMultiplier: 1.2,
    energyIncreaseThreshold: 1.5,
    vadPriority: true,
  );

  /// 低灵敏度配置（减少误检）
  static const lowSensitivity = BargeInConfig(
    energyThresholdMultiplier: 2.0,
    energyIncreaseThreshold: 3.0,
    vadPriority: false,
    confirmationDelay: Duration(milliseconds: 200),
  );
}

/// 打断检测器工厂
class BargeInDetectorFactory {
  /// 创建标准检测器
  static BargeInDetector create({BargeInConfig? config}) {
    return BargeInDetector(config: config);
  }

  /// 创建高灵敏度检测器
  static BargeInDetector createHighSensitivity() {
    return BargeInDetector(config: BargeInConfig.highSensitivity);
  }

  /// 创建低灵敏度检测器
  static BargeInDetector createLowSensitivity() {
    return BargeInDetector(config: BargeInConfig.lowSensitivity);
  }
}
