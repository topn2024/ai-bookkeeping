/// Feedback Coordinator
///
/// 负责用户反馈的协调器，从VoiceServiceCoordinator中提取。
/// 遵循单一职责原则，仅处理语音/视觉反馈和TTS播报。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 反馈类型
enum FeedbackType {
  /// 成功
  success,

  /// 信息
  info,

  /// 警告
  warning,

  /// 错误
  error,

  /// 确认请求
  confirmation,

  /// 进度
  progress,
}

/// 反馈优先级
enum FeedbackPriority {
  /// 低优先级（可被覆盖）
  low,

  /// 中等优先级
  medium,

  /// 高优先级（不可被覆盖）
  high,

  /// 紧急（立即播放）
  urgent,
}

/// 反馈项
class FeedbackItem {
  final String id;
  final String message;
  final FeedbackType type;
  final FeedbackPriority priority;
  final DateTime timestamp;
  final Duration? displayDuration;
  final Map<String, dynamic>? context;
  final bool enableTTS;
  final bool enableHaptic;

  const FeedbackItem({
    required this.id,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.displayDuration,
    this.context,
    this.enableTTS = true,
    this.enableHaptic = true,
  });

  FeedbackItem copyWith({
    String? id,
    String? message,
    FeedbackType? type,
    FeedbackPriority? priority,
    DateTime? timestamp,
    Duration? displayDuration,
    Map<String, dynamic>? context,
    bool? enableTTS,
    bool? enableHaptic,
  }) {
    return FeedbackItem(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      displayDuration: displayDuration ?? this.displayDuration,
      context: context ?? this.context,
      enableTTS: enableTTS ?? this.enableTTS,
      enableHaptic: enableHaptic ?? this.enableHaptic,
    );
  }
}

/// 反馈配置
class FeedbackConfig {
  /// 是否启用TTS
  final bool enableTTS;

  /// 是否启用触觉反馈
  final bool enableHaptic;

  /// TTS音量 (0.0-1.0)
  final double volume;

  /// TTS语速 (0.5-2.0)
  final double speechRate;

  /// TTS音调 (0.5-2.0)
  final double pitch;

  /// 默认显示时长
  final Duration defaultDisplayDuration;

  /// 错误显示时长
  final Duration errorDisplayDuration;

  const FeedbackConfig({
    this.enableTTS = true,
    this.enableHaptic = true,
    this.volume = 1.0,
    this.speechRate = 1.0,
    this.pitch = 1.0,
    this.defaultDisplayDuration = const Duration(seconds: 3),
    this.errorDisplayDuration = const Duration(seconds: 5),
  });

  static const defaultConfig = FeedbackConfig();

  FeedbackConfig copyWith({
    bool? enableTTS,
    bool? enableHaptic,
    double? volume,
    double? speechRate,
    double? pitch,
    Duration? defaultDisplayDuration,
    Duration? errorDisplayDuration,
  }) {
    return FeedbackConfig(
      enableTTS: enableTTS ?? this.enableTTS,
      enableHaptic: enableHaptic ?? this.enableHaptic,
      volume: volume ?? this.volume,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      defaultDisplayDuration:
          defaultDisplayDuration ?? this.defaultDisplayDuration,
      errorDisplayDuration: errorDisplayDuration ?? this.errorDisplayDuration,
    );
  }
}

/// 反馈协调器
///
/// 职责：
/// - 协调语音反馈（TTS）
/// - 提供触觉反馈
/// - 管理反馈队列
/// - 提供反馈历史
class FeedbackCoordinator extends ChangeNotifier {
  /// TTS服务接口
  final ITTSService _ttsService;

  /// 反馈配置
  FeedbackConfig _config;

  /// 反馈历史
  final List<FeedbackItem> _feedbackHistory = [];

  /// 最大历史记录数
  static const int _maxHistorySize = 100;

  /// 当前正在播放的反馈
  FeedbackItem? _currentFeedback;

  /// 反馈队列
  final List<FeedbackItem> _feedbackQueue = [];

  /// 是否正在处理反馈
  bool _isProcessing = false;

  /// 反馈流控制器
  final StreamController<FeedbackItem> _feedbackController =
      StreamController<FeedbackItem>.broadcast();

  FeedbackCoordinator({
    required ITTSService ttsService,
    FeedbackConfig? config,
  })  : _ttsService = ttsService,
        _config = config ?? FeedbackConfig.defaultConfig;

  /// 反馈配置
  FeedbackConfig get config => _config;

  /// 当前反馈
  FeedbackItem? get currentFeedback => _currentFeedback;

  /// 反馈历史
  List<FeedbackItem> get feedbackHistory => List.unmodifiable(_feedbackHistory);

  /// 反馈流
  Stream<FeedbackItem> get feedbackStream => _feedbackController.stream;

  /// 是否正在播放
  bool get isPlaying => _ttsService.isSpeaking;

  /// 更新配置
  void updateConfig(FeedbackConfig newConfig) {
    _config = newConfig;
    _applyConfig();
    notifyListeners();
  }

  // ==================== 核心反馈方法 ====================

  /// 提供反馈
  Future<void> provideFeedback({
    required String message,
    FeedbackType type = FeedbackType.info,
    FeedbackPriority priority = FeedbackPriority.medium,
    Map<String, dynamic>? context,
    Duration? displayDuration,
    bool? enableTTS,
    bool? enableHaptic,
  }) async {
    final feedback = FeedbackItem(
      id: _generateId(),
      message: message,
      type: type,
      priority: priority,
      timestamp: DateTime.now(),
      displayDuration: displayDuration ?? _getDefaultDuration(type),
      context: context,
      enableTTS: enableTTS ?? _config.enableTTS,
      enableHaptic: enableHaptic ?? _config.enableHaptic,
    );

    await _processFeedback(feedback);
  }

  /// 提供成功反馈
  Future<void> provideSuccessFeedback(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    await provideFeedback(
      message: message,
      type: FeedbackType.success,
      priority: FeedbackPriority.medium,
      context: context,
    );
  }

  /// 提供错误反馈
  Future<void> provideErrorFeedback(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    await provideFeedback(
      message: message,
      type: FeedbackType.error,
      priority: FeedbackPriority.high,
      context: context,
    );
  }

  /// 提供警告反馈
  Future<void> provideWarningFeedback(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    await provideFeedback(
      message: message,
      type: FeedbackType.warning,
      priority: FeedbackPriority.medium,
      context: context,
    );
  }

  /// 提供确认请求反馈
  Future<void> provideConfirmationFeedback(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    await provideFeedback(
      message: message,
      type: FeedbackType.confirmation,
      priority: FeedbackPriority.high,
      context: context,
    );
  }

  /// 提供进度反馈
  Future<void> provideProgressFeedback(
    String message, {
    double? progress,
    Map<String, dynamic>? context,
  }) async {
    final fullContext = {
      ...?context,
      if (progress != null) 'progress': progress,
    };

    await provideFeedback(
      message: message,
      type: FeedbackType.progress,
      priority: FeedbackPriority.low,
      context: fullContext,
      enableTTS: false, // 进度反馈默认不播放TTS
      enableHaptic: false,
    );
  }

  /// 停止当前反馈
  Future<void> stopFeedback() async {
    await _ttsService.stop();
    _currentFeedback = null;
    notifyListeners();
  }

  /// 清除反馈队列
  void clearQueue() {
    _feedbackQueue.clear();
    notifyListeners();
  }

  /// 清除历史
  void clearHistory() {
    _feedbackHistory.clear();
    notifyListeners();
  }

  // ==================== 私有方法 ====================

  /// 处理反馈
  Future<void> _processFeedback(FeedbackItem feedback) async {
    debugPrint(
        '[FeedbackCoordinator] 处理反馈: "${feedback.message}" (type: ${feedback.type})');

    // 添加到历史
    _addToHistory(feedback);

    // 发送到流
    _feedbackController.add(feedback);

    // 处理触觉反馈
    if (feedback.enableHaptic) {
      await _provideHapticFeedback(feedback.type);
    }

    // 处理TTS
    if (feedback.enableTTS && _config.enableTTS) {
      // 高优先级或紧急反馈立即播放，打断当前
      if (feedback.priority == FeedbackPriority.high ||
          feedback.priority == FeedbackPriority.urgent) {
        await _ttsService.stop();
        _currentFeedback = feedback;
        notifyListeners();
        await _ttsService.speak(feedback.message);
      } else {
        // 其他加入队列
        _feedbackQueue.add(feedback);
        await _processQueue();
      }
    }
  }

  /// 处理反馈队列
  Future<void> _processQueue() async {
    if (_isProcessing || _feedbackQueue.isEmpty) return;

    _isProcessing = true;

    while (_feedbackQueue.isNotEmpty) {
      final feedback = _feedbackQueue.removeAt(0);

      // 跳过已过期的低优先级反馈
      if (feedback.priority == FeedbackPriority.low) {
        final age = DateTime.now().difference(feedback.timestamp);
        if (age > const Duration(seconds: 10)) {
          continue;
        }
      }

      _currentFeedback = feedback;
      notifyListeners();

      await _ttsService.speak(feedback.message);
    }

    _currentFeedback = null;
    _isProcessing = false;
    notifyListeners();
  }

  /// 提供触觉反馈
  Future<void> _provideHapticFeedback(FeedbackType type) async {
    try {
      switch (type) {
        case FeedbackType.success:
          await HapticFeedback.mediumImpact();
          break;
        case FeedbackType.error:
          await HapticFeedback.heavyImpact();
          break;
        case FeedbackType.warning:
          await HapticFeedback.lightImpact();
          break;
        case FeedbackType.confirmation:
          await HapticFeedback.selectionClick();
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('[FeedbackCoordinator] 触觉反馈失败: $e');
    }
  }

  /// 添加到历史
  void _addToHistory(FeedbackItem feedback) {
    _feedbackHistory.add(feedback);

    // 保持历史记录数量在限制内
    while (_feedbackHistory.length > _maxHistorySize) {
      _feedbackHistory.removeAt(0);
    }
  }

  /// 生成ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_feedbackHistory.length}';
  }

  /// 获取默认显示时长
  Duration _getDefaultDuration(FeedbackType type) {
    switch (type) {
      case FeedbackType.error:
        return _config.errorDisplayDuration;
      case FeedbackType.warning:
        return const Duration(seconds: 4);
      default:
        return _config.defaultDisplayDuration;
    }
  }

  /// 应用配置
  void _applyConfig() {
    _ttsService.setVolume(_config.volume);
    _ttsService.setSpeechRate(_config.speechRate);
    _ttsService.setPitch(_config.pitch);
  }

  @override
  void dispose() {
    _feedbackController.close();
    super.dispose();
  }
}

/// TTS服务接口
///
/// 抽象TTS功能，支持依赖注入和测试
abstract class ITTSService {
  /// 是否正在播放
  bool get isSpeaking;

  /// 播放文本
  Future<void> speak(String text);

  /// 停止播放
  Future<void> stop();

  /// 设置音量
  void setVolume(double volume);

  /// 设置语速
  void setSpeechRate(double rate);

  /// 设置音调
  void setPitch(double pitch);
}
