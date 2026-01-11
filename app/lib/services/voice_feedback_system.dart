import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tts_service.dart';
import 'voice/voice_intent_router.dart';
import 'voice_service_coordinator.dart' show VoiceIntentType;

/// 语音反馈系统
///
/// 负责为用户提供智能的、上下文感知的语音和视觉反馈
///
/// 功能包括：
/// - 智能语音提示
/// - 上下文感知的反馈消息
/// - 操作确认和错误提示
/// - 进度反馈和状态更新
/// - 多语言支持
/// - 情感化反馈
class VoiceFeedbackSystem extends ChangeNotifier {
  final TTSService _ttsService;

  /// 当前反馈状态
  VoiceFeedbackState _state = const VoiceFeedbackState();

  /// 反馈历史记录
  final List<VoiceFeedback> _feedbackHistory = [];

  /// 最大历史记录数
  static const int _maxHistorySize = 100;

  /// 反馈配置
  VoiceFeedbackConfig _config = VoiceFeedbackConfig.defaultConfig();

  VoiceFeedbackSystem({
    TTSService? ttsService,
  }) : _ttsService = ttsService ?? TTSService();

  /// 当前反馈状态
  VoiceFeedbackState get state => _state;

  /// 反馈历史
  List<VoiceFeedback> get feedbackHistory => List.unmodifiable(_feedbackHistory);

  /// 反馈配置
  VoiceFeedbackConfig get config => _config;

  /// 更新配置
  void updateConfig(VoiceFeedbackConfig newConfig) {
    _config = newConfig;
    _ttsService.setVolume(_config.volume);
    _ttsService.setSpeechRate(_config.speechRate);
    _ttsService.setPitch(_config.pitch);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // 核心反馈方法
  // ═══════════════════════════════════════════════════════════════

  /// 提供成功反馈
  Future<void> provideFeedback({
    required String message,
    VoiceFeedbackType type = VoiceFeedbackType.info,
    VoiceFeedbackPriority priority = VoiceFeedbackPriority.medium,
    Map<String, dynamic>? context,
    Duration? displayDuration,
    bool enableTts = true,
    bool enableHaptic = true,
  }) async {
    try {
      final feedback = VoiceFeedback(
        id: _generateId(),
        message: message,
        type: type,
        priority: priority,
        timestamp: DateTime.now(),
        context: context ?? {},
        displayDuration: displayDuration ?? _getDefaultDuration(type),
      );

      await _processFeedback(feedback, enableTts, enableHaptic);
    } catch (e) {
      debugPrint('Voice feedback error: $e');
    }
  }

  /// 提供上下文感知的智能反馈
  Future<void> provideContextualFeedback({
    required IntentAnalysisResult intentResult,
    String? customMessage,
    Map<String, dynamic>? additionalContext,
    bool enableTts = true,
    bool enableHaptic = true,
  }) async {
    final message = customMessage ?? _generateContextualMessage(intentResult);
    final type = _determineTypeFromIntent(intentResult);
    final priority = _determinePriorityFromIntent(intentResult);

    final context = <String, dynamic>{
      'intent': intentResult.intent.toString(),
      'confidence': intentResult.confidence,
      'entities': intentResult.entities,
      ...?additionalContext,
    };

    await provideFeedback(
      message: message,
      type: type,
      priority: priority,
      context: context,
      enableTts: enableTts,
      enableHaptic: enableHaptic,
    );
  }

  /// 提供操作结果反馈
  Future<void> provideOperationFeedback({
    required OperationResult result,
    bool enableTts = true,
    bool enableHaptic = true,
  }) async {
    final message = _generateOperationMessage(result);
    final type = result.isSuccess
        ? VoiceFeedbackType.success
        : VoiceFeedbackType.error;

    final priority = result.isSuccess
        ? VoiceFeedbackPriority.medium
        : VoiceFeedbackPriority.high;

    await provideFeedback(
      message: message,
      type: type,
      priority: priority,
      context: {'operation': result.operation, 'details': result.details},
      enableTts: enableTts,
      enableHaptic: enableHaptic,
    );
  }

  /// 提供进度反馈
  Future<void> provideProgressFeedback({
    required String operation,
    required double progress, // 0.0 - 1.0
    String? customMessage,
    bool enableTts = false, // 默认关闭TTS以避免过度打扰
    bool enableHaptic = false,
  }) async {
    final message = customMessage ?? _generateProgressMessage(operation, progress);

    await provideFeedback(
      message: message,
      type: VoiceFeedbackType.progress,
      priority: VoiceFeedbackPriority.low,
      context: {
        'operation': operation,
        'progress': progress,
      },
      displayDuration: const Duration(seconds: 2),
      enableTts: enableTts,
      enableHaptic: enableHaptic,
    );
  }

  /// 提供错误反馈
  Future<void> provideErrorFeedback({
    required String error,
    String? suggestion,
    Map<String, dynamic>? context,
    bool enableTts = true,
    bool enableHaptic = true,
  }) async {
    final message = suggestion != null
        ? '$error。$suggestion'
        : error;

    await provideFeedback(
      message: message,
      type: VoiceFeedbackType.error,
      priority: VoiceFeedbackPriority.high,
      context: context,
      enableTts: enableTts,
      enableHaptic: enableHaptic,
    );
  }

  /// 提供确认反馈
  Future<void> provideConfirmationFeedback({
    required String operation,
    String? details,
    bool enableTts = true,
    bool enableHaptic = true,
  }) async {
    final message = details != null
        ? '请确认：$operation。$details'
        : '请确认：$operation';

    await provideFeedback(
      message: message,
      type: VoiceFeedbackType.confirmation,
      priority: VoiceFeedbackPriority.high,
      context: {'operation': operation, 'details': details},
      enableTts: enableTts,
      enableHaptic: enableHaptic,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 智能反馈生成
  // ═══════════════════════════════════════════════════════════════

  /// 根据意图结果生成上下文消息
  String _generateContextualMessage(IntentAnalysisResult intentResult) {
    if (intentResult.confidence < 0.5) {
      return _generateLowConfidenceMessage(intentResult);
    }

    switch (intentResult.intent) {
      case VoiceIntentType.deleteTransaction:
        return _generateDeleteMessage(intentResult);
      case VoiceIntentType.modifyTransaction:
        return _generateModifyMessage(intentResult);
      case VoiceIntentType.addTransaction:
        return _generateAddMessage(intentResult);
      case VoiceIntentType.queryTransaction:
        return _generateQueryMessage(intentResult);
      case VoiceIntentType.navigateToPage:
        return _generateNavigationMessage(intentResult);
      case VoiceIntentType.confirmAction:
        return '好的，我来为您确认操作';
      case VoiceIntentType.cancelAction:
        return '已为您取消操作';
      case VoiceIntentType.clarifySelection:
        return '请选择您要操作的项目';
      default:
        return '我正在处理您的请求...';
    }
  }

  /// 生成低置信度消息
  String _generateLowConfidenceMessage(IntentAnalysisResult intentResult) {
    final suggestions = intentResult.candidateIntents
        .take(2)
        .map((c) => _getIntentDescription(c.intent))
        .join('或');

    if (suggestions.isNotEmpty) {
      return '我不太确定您的意图。您是想$suggestions吗？';
    } else {
      return '抱歉，我没有完全理解您的指令。请说得更清楚一些。';
    }
  }

  /// 生成删除消息
  String _generateDeleteMessage(IntentAnalysisResult intentResult) {
    final entities = intentResult.entities;

    if (entities.containsKey('timeRange')) {
      return '正在查找${entities['timeRange']}的交易记录...';
    } else if (entities.containsKey('category')) {
      return '正在查找${entities['category']}类别的交易记录...';
    } else if (entities.containsKey('amount')) {
      return '正在查找金额为${entities['amount']}元的交易记录...';
    } else {
      return '正在查找相关的交易记录...';
    }
  }

  /// 生成修改消息
  String _generateModifyMessage(IntentAnalysisResult intentResult) {
    final entities = intentResult.entities;

    if (entities.containsKey('field') && entities.containsKey('newValue')) {
      return '正在修改${entities['field']}为${entities['newValue']}...';
    } else {
      return '正在查找要修改的交易记录...';
    }
  }

  /// 生成添加消息
  String _generateAddMessage(IntentAnalysisResult intentResult) {
    final entities = intentResult.entities;

    if (entities.containsKey('amount') && entities.containsKey('category')) {
      return '正在为您添加${entities['category']}支出${entities['amount']}元...';
    } else if (entities.containsKey('amount')) {
      return '正在为您添加${entities['amount']}元的交易记录...';
    } else {
      return '正在为您创建新的交易记录...';
    }
  }

  /// 生成查询消息
  String _generateQueryMessage(IntentAnalysisResult intentResult) {
    final entities = intentResult.entities;

    if (entities.containsKey('timeRange')) {
      return '正在统计${entities['timeRange']}的消费情况...';
    } else if (entities.containsKey('category')) {
      return '正在统计${entities['category']}类别的消费情况...';
    } else {
      return '正在为您查询相关信息...';
    }
  }

  /// 生成导航消息
  String _generateNavigationMessage(IntentAnalysisResult intentResult) {
    final entities = intentResult.entities;

    if (entities.containsKey('targetPage')) {
      return '正在为您打开${entities['targetPage']}页面...';
    } else {
      return '正在为您跳转到相关页面...';
    }
  }

  /// 生成操作结果消息
  String _generateOperationMessage(OperationResult result) {
    if (result.isSuccess) {
      switch (result.operation) {
        case 'delete':
          return '删除操作已成功完成';
        case 'modify':
          return '修改操作已成功完成';
        case 'add':
          return '添加操作已成功完成';
        case 'query':
          return '查询操作已成功完成';
        default:
          return '操作已成功完成';
      }
    } else {
      final errorMsg = result.error ?? '未知错误';
      final suggestion = _generateErrorSuggestion(errorMsg);
      return '操作失败：$errorMsg${suggestion.isNotEmpty ? "。$suggestion" : ""}';
    }
  }

  /// 生成进度消息
  String _generateProgressMessage(String operation, double progress) {
    final percentage = (progress * 100).round();

    if (percentage == 0) {
      return '开始$operation...';
    } else if (percentage < 50) {
      return '$operation进行中...';
    } else if (percentage < 100) {
      return '$operation即将完成...';
    } else {
      return '$operation已完成';
    }
  }

  /// 生成错误建议
  String _generateErrorSuggestion(String error) {
    if (error.contains('网络')) {
      return '请检查网络连接';
    } else if (error.contains('权限')) {
      return '请检查应用权限设置';
    } else if (error.contains('数据')) {
      return '请重试或联系技术支持';
    } else {
      return '请稍后重试';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 反馈处理
  // ═══════════════════════════════════════════════════════════════

  /// 处理反馈
  Future<void> _processFeedback(
    VoiceFeedback feedback,
    bool enableTts,
    bool enableHaptic,
  ) async {
    // 添加到历史记录
    _addToHistory(feedback);

    // 更新状态
    _state = _state.copyWith(
      currentFeedback: feedback,
      isPlaying: enableTts,
      lastUpdate: DateTime.now(),
    );
    notifyListeners();

    // 执行反馈
    final futures = <Future>[];

    // 语音反馈
    if (enableTts && _config.enableTts) {
      futures.add(_provideTtsFeedback(feedback));
    }

    // 触觉反馈
    if (enableHaptic && _config.enableHaptic) {
      futures.add(_provideHapticFeedback(feedback));
    }

    // 视觉反馈（通过状态更新实现）
    if (_config.enableVisualFeedback) {
      _scheduleVisualFeedbackClear(feedback.displayDuration);
    }

    await Future.wait(futures);

    // 更新播放状态
    _state = _state.copyWith(isPlaying: false);
    notifyListeners();
  }

  /// 提供TTS反馈
  Future<void> _provideTtsFeedback(VoiceFeedback feedback) async {
    try {
      final enhancedMessage = _enhanceMessageForTts(feedback);
      await _ttsService.speak(enhancedMessage);
    } catch (e) {
      debugPrint('TTS feedback error: $e');
    }
  }

  /// 提供触觉反馈
  Future<void> _provideHapticFeedback(VoiceFeedback feedback) async {
    try {
      switch (feedback.type) {
        case VoiceFeedbackType.success:
          await HapticFeedback.lightImpact();
          break;
        case VoiceFeedbackType.error:
          await HapticFeedback.heavyImpact();
          break;
        case VoiceFeedbackType.warning:
          await HapticFeedback.mediumImpact();
          break;
        case VoiceFeedbackType.confirmation:
          await HapticFeedback.selectionClick();
          break;
        default:
          await HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Haptic feedback error: $e');
    }
  }

  /// 增强TTS消息
  String _enhanceMessageForTts(VoiceFeedback feedback) {
    var message = feedback.message;

    // 根据类型添加语调提示
    switch (feedback.type) {
      case VoiceFeedbackType.error:
        message = '<emphasis level="strong">$message</emphasis>';
        break;
      case VoiceFeedbackType.success:
        message = '<prosody rate="medium">$message</prosody>';
        break;
      case VoiceFeedbackType.confirmation:
        message = '<prosody pitch="high">$message</prosody>';
        break;
      default:
        break;
    }

    return message;
  }

  /// 安排视觉反馈清除
  void _scheduleVisualFeedbackClear(Duration duration) {
    Timer(duration, () {
      _state = _state.copyWith(currentFeedback: null);
      notifyListeners();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 辅助方法
  // ═══════════════════════════════════════════════════════════════

  /// 确定反馈类型
  VoiceFeedbackType _determineTypeFromIntent(IntentAnalysisResult intentResult) {
    if (intentResult.confidence < 0.5) {
      return VoiceFeedbackType.warning;
    }

    switch (intentResult.intent) {
      case VoiceIntentType.deleteTransaction:
      case VoiceIntentType.modifyTransaction:
        return VoiceFeedbackType.confirmation;
      case VoiceIntentType.addTransaction:
        return VoiceFeedbackType.success;
      case VoiceIntentType.queryTransaction:
      case VoiceIntentType.navigateToPage:
        return VoiceFeedbackType.info;
      default:
        return VoiceFeedbackType.info;
    }
  }

  /// 确定反馈优先级
  VoiceFeedbackPriority _determinePriorityFromIntent(IntentAnalysisResult intentResult) {
    if (intentResult.confidence < 0.5) {
      return VoiceFeedbackPriority.high;
    }

    switch (intentResult.intent) {
      case VoiceIntentType.deleteTransaction:
      case VoiceIntentType.modifyTransaction:
        return VoiceFeedbackPriority.high;
      case VoiceIntentType.confirmAction:
      case VoiceIntentType.cancelAction:
        return VoiceFeedbackPriority.medium;
      default:
        return VoiceFeedbackPriority.low;
    }
  }

  /// 获取默认持续时间
  Duration _getDefaultDuration(VoiceFeedbackType type) {
    switch (type) {
      case VoiceFeedbackType.error:
        return const Duration(seconds: 5);
      case VoiceFeedbackType.warning:
        return const Duration(seconds: 4);
      case VoiceFeedbackType.confirmation:
        return const Duration(seconds: 6);
      case VoiceFeedbackType.success:
        return const Duration(seconds: 3);
      case VoiceFeedbackType.progress:
        return const Duration(seconds: 2);
      default:
        return const Duration(seconds: 3);
    }
  }

  /// 获取意图描述
  String _getIntentDescription(VoiceIntentType intent) {
    switch (intent) {
      case VoiceIntentType.deleteTransaction:
        return '删除交易';
      case VoiceIntentType.modifyTransaction:
        return '修改交易';
      case VoiceIntentType.addTransaction:
        return '添加交易';
      case VoiceIntentType.queryTransaction:
        return '查询信息';
      case VoiceIntentType.navigateToPage:
        return '页面导航';
      default:
        return '其他操作';
    }
  }

  /// 生成ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           math.Random().nextInt(1000).toString();
  }

  /// 添加到历史记录
  void _addToHistory(VoiceFeedback feedback) {
    _feedbackHistory.add(feedback);
    if (_feedbackHistory.length > _maxHistorySize) {
      _feedbackHistory.removeAt(0);
    }
  }

  /// 停止当前反馈
  Future<void> stopCurrentFeedback() async {
    await _ttsService.stop();
    _state = _state.copyWith(
      isPlaying: false,
      currentFeedback: null,
    );
    notifyListeners();
  }

  /// 清除反馈历史
  void clearHistory() {
    _feedbackHistory.clear();
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据类型定义
// ═══════════════════════════════════════════════════════════════

/// 语音反馈状态
class VoiceFeedbackState {
  final VoiceFeedback? currentFeedback;
  final bool isPlaying;
  final DateTime? lastUpdate;

  const VoiceFeedbackState({
    this.currentFeedback,
    this.isPlaying = false,
    this.lastUpdate,
  });

  VoiceFeedbackState copyWith({
    VoiceFeedback? currentFeedback,
    bool? isPlaying,
    DateTime? lastUpdate,
  }) {
    return VoiceFeedbackState(
      currentFeedback: currentFeedback ?? this.currentFeedback,
      isPlaying: isPlaying ?? this.isPlaying,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// 语音反馈
class VoiceFeedback {
  final String id;
  final String message;
  final VoiceFeedbackType type;
  final VoiceFeedbackPriority priority;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  final Duration displayDuration;

  const VoiceFeedback({
    required this.id,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    required this.context,
    required this.displayDuration,
  });

  @override
  String toString() {
    return 'VoiceFeedback(id: $id, message: $message, type: $type)';
  }
}

/// 语音反馈类型
enum VoiceFeedbackType {
  info,
  success,
  warning,
  error,
  confirmation,
  progress,
}

/// 语音反馈优先级
enum VoiceFeedbackPriority {
  low,
  medium,
  high,
  critical,
}

/// 语音反馈配置
class VoiceFeedbackConfig {
  final bool enableTts;
  final bool enableHaptic;
  final bool enableVisualFeedback;
  final double volume;
  final double speechRate;
  final double pitch;
  final String language;
  final String voice;

  const VoiceFeedbackConfig({
    required this.enableTts,
    required this.enableHaptic,
    required this.enableVisualFeedback,
    required this.volume,
    required this.speechRate,
    required this.pitch,
    required this.language,
    required this.voice,
  });

  factory VoiceFeedbackConfig.defaultConfig() {
    return const VoiceFeedbackConfig(
      enableTts: true,
      enableHaptic: true,
      enableVisualFeedback: true,
      volume: 0.8,
      speechRate: 1.0,
      pitch: 1.0,
      language: 'zh-CN',
      voice: 'default',
    );
  }

  VoiceFeedbackConfig copyWith({
    bool? enableTts,
    bool? enableHaptic,
    bool? enableVisualFeedback,
    double? volume,
    double? speechRate,
    double? pitch,
    String? language,
    String? voice,
  }) {
    return VoiceFeedbackConfig(
      enableTts: enableTts ?? this.enableTts,
      enableHaptic: enableHaptic ?? this.enableHaptic,
      enableVisualFeedback: enableVisualFeedback ?? this.enableVisualFeedback,
      volume: volume ?? this.volume,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      language: language ?? this.language,
      voice: voice ?? this.voice,
    );
  }
}

/// 操作结果
class OperationResult {
  final String operation;
  final bool isSuccess;
  final String? error;
  final Map<String, dynamic>? details;

  const OperationResult({
    required this.operation,
    required this.isSuccess,
    this.error,
    this.details,
  });

  factory OperationResult.success(String operation, [Map<String, dynamic>? details]) {
    return OperationResult(
      operation: operation,
      isSuccess: true,
      details: details,
    );
  }

  factory OperationResult.failure(String operation, String error, [Map<String, dynamic>? details]) {
    return OperationResult(
      operation: operation,
      isSuccess: false,
      error: error,
      details: details,
    );
  }
}