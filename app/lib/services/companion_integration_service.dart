import 'dart:async';

import 'package:flutter/foundation.dart';

import 'companion_copywriting_service.dart';
import 'companion_event_bus.dart';
import 'companion_effect_tracker.dart';

/// 伙伴化系统集成服务
///
/// 功能：
/// 1. 与钱龄系统集成（钱龄变化触发）
/// 2. 与预算系统集成（超支预警）
/// 3. 与记账系统集成（记账完成鼓励）
/// 4. 与成就系统集成（成就解锁庆祝）
/// 5. 情感化交互反馈系统
class CompanionIntegrationService {
  final CompanionCopywritingService _copywritingService;
  final CompanionEventBus _eventBus;
  final CompanionEffectTracker _effectTracker;

  final _messageController = StreamController<CompanionMessage>.broadcast();
  final List<StreamSubscription> _subscriptions = [];

  CompanionIntegrationService({
    CompanionCopywritingService? copywritingService,
    CompanionEventBus? eventBus,
    CompanionEffectTracker? effectTracker,
  })  : _copywritingService = copywritingService ?? CompanionCopywritingService(),
        _eventBus = eventBus ?? CompanionEventBus(),
        _effectTracker = effectTracker ?? CompanionEffectTracker();

  /// 消息流（供UI订阅）
  Stream<CompanionMessage> get messageStream => _messageController.stream;

  /// 初始化集成服务
  void initialize() {
    // 注册事件处理器
    _eventBus.registerHandler(CompanionTrigger.appOpen, _handleAppOpen);
    _eventBus.registerHandler(CompanionTrigger.recordComplete, _handleRecordComplete);
    _eventBus.registerHandler(CompanionTrigger.budgetAlert, _handleBudgetAlert);
    _eventBus.registerHandler(CompanionTrigger.budgetAchieved, _handleBudgetAchieved);
    _eventBus.registerHandler(CompanionTrigger.moneyAgeChange, _handleMoneyAgeChange);
    _eventBus.registerHandler(CompanionTrigger.achievement, _handleAchievement);
    _eventBus.registerHandler(CompanionTrigger.streak, _handleStreak);
    _eventBus.registerHandler(CompanionTrigger.savingsGoal, _handleSavingsGoal);
    _eventBus.registerHandler(CompanionTrigger.specialDate, _handleSpecialDate);
    _eventBus.registerHandler(CompanionTrigger.insight, _handleInsight);
    _eventBus.registerHandler(CompanionTrigger.scheduled, _handleScheduled);

    // 订阅事件总线的消息流
    _subscriptions.add(
      _eventBus.messageStream.listen((message) {
        _effectTracker.trackImpression(message);
        _messageController.add(message);
      }),
    );

    debugPrint('CompanionIntegrationService initialized');
  }

  // ==================== 系统集成触发方法 ====================

  /// 触发应用打开事件
  Future<void> onAppOpen({
    String? userId,
    DateTime? lastActiveTime,
  }) async {
    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.appOpen,
      userId: userId,
      data: {'lastActiveTime': lastActiveTime?.toIso8601String()},
      priority: MessagePriority.low,
    ));
  }

  /// 触发记账完成事件
  Future<void> onRecordComplete({
    required double amount,
    required String category,
    String? merchantName,
    int? consecutiveDays,
    String? userId,
  }) async {
    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.recordComplete,
      userId: userId,
      data: {
        'amount': amount,
        'category': category,
        'merchantName': merchantName,
        'consecutiveDays': consecutiveDays,
      },
      priority: MessagePriority.medium,
    ));
  }

  /// 触发预算预警事件（与预算系统集成）
  Future<void> onBudgetAlert({
    required String vaultId,
    required String vaultName,
    required double remaining,
    required double total,
    required int daysLeft,
    String? userId,
  }) async {
    final usagePercent = (total - remaining) / total;

    MessagePriority priority;
    if (usagePercent >= 1.0) {
      priority = MessagePriority.high;
    } else if (usagePercent >= 0.9) {
      priority = MessagePriority.high;
    } else {
      priority = MessagePriority.medium;
    }

    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.budgetAlert,
      userId: userId,
      data: {
        'vaultId': vaultId,
        'vaultName': vaultName,
        'remaining': remaining,
        'total': total,
        'usagePercent': usagePercent,
        'daysLeft': daysLeft,
      },
      priority: priority,
    ));
  }

  /// 触发钱龄变化事件（与钱龄��统集成）
  Future<void> onMoneyAgeChange({
    required double previousAge,
    required double currentAge,
    required String healthLevel,
    String? userId,
  }) async {
    final change = currentAge - previousAge;

    // 只在显著变化时触发
    if (change.abs() < 1) return;

    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.moneyAgeChange,
      userId: userId,
      data: {
        'previousAge': previousAge,
        'currentAge': currentAge,
        'change': change,
        'healthLevel': healthLevel,
      },
      priority: change.abs() > 5 ? MessagePriority.medium : MessagePriority.low,
    ));
  }

  /// 触发成就解锁事件（与成就系统集成）
  Future<void> onAchievementUnlocked({
    required String achievementId,
    required String achievementName,
    required String description,
    String? userId,
  }) async {
    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.achievement,
      userId: userId,
      data: {
        'achievementId': achievementId,
        'achievementName': achievementName,
        'description': description,
      },
      priority: MessagePriority.high,
    ));
  }

  /// 触发连续记账事件
  Future<void> onStreakUpdate({
    required int days,
    String? userId,
  }) async {
    // 只在特定天数触发
    final milestones = [3, 7, 14, 21, 30, 60, 90, 100, 180, 365];
    if (!milestones.contains(days)) return;

    await _eventBus.publish(CompanionEvent(
      trigger: days >= 30 ? CompanionTrigger.milestone : CompanionTrigger.streak,
      userId: userId,
      data: {'days': days},
      priority: days >= 30 ? MessagePriority.high : MessagePriority.medium,
    ));
  }

  /// 触发储蓄目标事件（与储蓄目标系统集成）
  Future<void> onSavingsGoalUpdate({
    required String goalId,
    required String goalName,
    required double currentAmount,
    required double targetAmount,
    String? userId,
  }) async {
    final progress = currentAmount / targetAmount;

    // 只在关键节点触发
    if (progress < 0.5 && (progress * 100).round() % 10 != 0) return;

    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.savingsGoal,
      userId: userId,
      data: {
        'goalId': goalId,
        'goalName': goalName,
        'currentAmount': currentAmount,
        'targetAmount': targetAmount,
        'progress': progress,
      },
      priority: progress >= 1.0 ? MessagePriority.high : MessagePriority.medium,
    ));
  }

  /// 触发预算达成事件
  Future<void> onBudgetAchieved({
    required String vaultId,
    required String vaultName,
    required double budgetAmount,
    required double spentAmount,
    String? userId,
  }) async {
    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.budgetAchieved,
      userId: userId,
      data: {
        'vaultId': vaultId,
        'vaultName': vaultName,
        'budgetAmount': budgetAmount,
        'spentAmount': spentAmount,
        'savedAmount': budgetAmount - spentAmount,
      },
      priority: MessagePriority.high,
    ));
  }

  /// 触发特殊日期事件
  Future<void> onSpecialDate({
    required String dateType, // 'birthday', 'anniversary', 'holiday'
    required String dateName,
    String? userId,
  }) async {
    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.specialDate,
      userId: userId,
      data: {
        'dateType': dateType,
        'dateName': dateName,
      },
      priority: MessagePriority.medium,
    ));
  }

  /// 触发AI洞察事件（与智能化系统集成）
  Future<void> onInsightDiscovered({
    required String insightId,
    required String insightTitle,
    required String insightContent,
    String? userId,
  }) async {
    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.insight,
      userId: userId,
      data: {
        'insightId': insightId,
        'insightTitle': insightTitle,
        'insightContent': insightContent,
      },
      priority: MessagePriority.medium,
    ));
  }

  /// 触发晚间总结事件
  Future<void> onEveningSummary({
    required double todaySpent,
    required int todayTransactions,
    String? userId,
  }) async {
    await _eventBus.publish(CompanionEvent(
      trigger: CompanionTrigger.scheduled,
      userId: userId,
      data: {
        'scheduleType': 'evening',
        'todaySpent': todaySpent,
        'todayTransactions': todayTransactions,
      },
      priority: MessagePriority.low,
    ));
  }

  // ==================== 事件处理器 ====================

  Future<CompanionMessage?> _handleAppOpen(CompanionEvent event) async {
    final lastActiveStr = event.data?['lastActiveTime'] as String?;
    final lastActiveTime = lastActiveStr != null
        ? DateTime.tryParse(lastActiveStr)
        : null;

    return await _copywritingService.getWelcomeMessage(
      userId: event.userId,
      lastActiveTime: lastActiveTime,
    );
  }

  Future<CompanionMessage?> _handleRecordComplete(CompanionEvent event) async {
    return await _copywritingService.getRecordCompletionMessage(
      amount: event.data?['amount'] as double? ?? 0,
      category: event.data?['category'] as String? ?? '',
      consecutiveDays: event.data?['consecutiveDays'] as int?,
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleBudgetAlert(CompanionEvent event) async {
    return await _copywritingService.getBudgetAlertMessage(
      vaultName: event.data?['vaultName'] as String? ?? '',
      remaining: event.data?['remaining'] as double? ?? 0,
      total: event.data?['total'] as double? ?? 0,
      daysLeft: event.data?['daysLeft'] as int? ?? 0,
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleMoneyAgeChange(CompanionEvent event) async {
    return await _copywritingService.getMoneyAgeMessage(
      previousAge: event.data?['previousAge'] as double? ?? 0,
      currentAge: event.data?['currentAge'] as double? ?? 0,
      healthLevel: event.data?['healthLevel'] as String? ?? '',
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleAchievement(CompanionEvent event) async {
    return await _copywritingService.getAchievementMessage(
      achievementId: event.data?['achievementId'] as String? ?? '',
      achievementName: event.data?['achievementName'] as String? ?? '',
      description: event.data?['description'] as String? ?? '',
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleStreak(CompanionEvent event) async {
    final days = event.data?['days'] as int? ?? 0;

    return await _copywritingService.generateMessage(
      trigger: event.trigger,
      context: {'days': days},
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleBudgetAchieved(CompanionEvent event) async {
    return await _copywritingService.generateMessage(
      trigger: event.trigger,
      context: event.data,
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleSavingsGoal(CompanionEvent event) async {
    return await _copywritingService.generateMessage(
      trigger: event.trigger,
      context: event.data,
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleSpecialDate(CompanionEvent event) async {
    return await _copywritingService.generateMessage(
      trigger: event.trigger,
      context: event.data,
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleInsight(CompanionEvent event) async {
    return await _copywritingService.generateMessage(
      trigger: event.trigger,
      context: event.data,
      userId: event.userId,
    );
  }

  Future<CompanionMessage?> _handleScheduled(CompanionEvent event) async {
    return await _copywritingService.generateMessage(
      trigger: event.trigger,
      context: event.data,
      userId: event.userId,
    );
  }

  // ==================== 情感化交互反馈 ====================

  /// 用户点击消息
  void onMessageClicked(CompanionMessage message) {
    _effectTracker.trackClick(message);
  }

  /// 用户关闭消息
  void onMessageDismissed(CompanionMessage message, DismissReason reason) {
    _effectTracker.trackDismiss(message, reason);
  }

  /// 用户提交反馈
  void onUserFeedback(CompanionMessage message, UserFeedback feedback) {
    _effectTracker.trackFeedback(message, feedback);
  }

  /// 获取效果报告
  EffectReport getEffectReport() {
    final overall = _effectTracker.getOverallMetrics();
    final sceneMetrics = <SceneType, MessageMetrics>{};
    final emotionMetrics = <EmotionType, MessageMetrics>{};

    for (final scene in SceneType.values) {
      sceneMetrics[scene] = _effectTracker.getSceneMetrics(scene);
    }

    for (final emotion in EmotionType.values) {
      emotionMetrics[emotion] = _effectTracker.getEmotionMetrics(emotion);
    }

    return EffectReport(
      overall: overall,
      byScene: sceneMetrics,
      byEmotion: emotionMetrics,
      generatedAt: DateTime.now(),
    );
  }

  /// 释放资源
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _messageController.close();
  }
}

/// 效果报告
class EffectReport {
  final MessageMetrics overall;
  final Map<SceneType, MessageMetrics> byScene;
  final Map<EmotionType, MessageMetrics> byEmotion;
  final DateTime generatedAt;

  EffectReport({
    required this.overall,
    required this.byScene,
    required this.byEmotion,
    required this.generatedAt,
  });

  /// 获取最有效的场景
  List<MapEntry<SceneType, MessageMetrics>> getTopScenes({int limit = 3}) {
    final sorted = byScene.entries.toList()
      ..sort((a, b) => b.value.clickThroughRate.compareTo(a.value.clickThroughRate));
    return sorted.take(limit).toList();
  }

  /// 获取最有效的情感类型
  List<MapEntry<EmotionType, MessageMetrics>> getTopEmotions({int limit = 3}) {
    final sorted = byEmotion.entries.toList()
      ..sort((a, b) => b.value.averageRating.compareTo(a.value.averageRating));
    return sorted.take(limit).toList();
  }
}

// ==================== 伙伴化管理器（单例） ====================

/// 伙伴化管理器
class CompanionManager {
  static final CompanionManager _instance = CompanionManager._internal();
  factory CompanionManager() => _instance;
  CompanionManager._internal();

  late final CompanionIntegrationService _integrationService;
  bool _isInitialized = false;

  /// 消息流
  Stream<CompanionMessage> get messageStream => _integrationService.messageStream;

  /// 初始化
  void initialize() {
    if (_isInitialized) return;

    _integrationService = CompanionIntegrationService();
    _integrationService.initialize();
    _isInitialized = true;

    debugPrint('CompanionManager initialized');
  }

  /// 获取��成服务
  CompanionIntegrationService get integrationService {
    if (!_isInitialized) {
      throw StateError('CompanionManager not initialized. Call initialize() first.');
    }
    return _integrationService;
  }

  /// 便捷方法：应用打开
  Future<void> onAppOpen({String? userId, DateTime? lastActiveTime}) async {
    if (!_isInitialized) return;
    await _integrationService.onAppOpen(
      userId: userId,
      lastActiveTime: lastActiveTime,
    );
  }

  /// 便捷方法：记账完成
  Future<void> onRecordComplete({
    required double amount,
    required String category,
    String? merchantName,
    int? consecutiveDays,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onRecordComplete(
      amount: amount,
      category: category,
      merchantName: merchantName,
      consecutiveDays: consecutiveDays,
      userId: userId,
    );
  }

  /// 便捷方法：预算预警
  Future<void> onBudgetAlert({
    required String vaultId,
    required String vaultName,
    required double remaining,
    required double total,
    required int daysLeft,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onBudgetAlert(
      vaultId: vaultId,
      vaultName: vaultName,
      remaining: remaining,
      total: total,
      daysLeft: daysLeft,
      userId: userId,
    );
  }

  /// 便捷方法：钱龄变化
  Future<void> onMoneyAgeChange({
    required double previousAge,
    required double currentAge,
    required String healthLevel,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onMoneyAgeChange(
      previousAge: previousAge,
      currentAge: currentAge,
      healthLevel: healthLevel,
      userId: userId,
    );
  }

  /// 便捷方法：成就解锁
  Future<void> onAchievementUnlocked({
    required String achievementId,
    required String achievementName,
    required String description,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onAchievementUnlocked(
      achievementId: achievementId,
      achievementName: achievementName,
      description: description,
      userId: userId,
    );
  }

  /// 便捷方法：连续记账
  Future<void> onStreakUpdate({
    required int days,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onStreakUpdate(
      days: days,
      userId: userId,
    );
  }

  /// 便捷方法：储蓄目标更新
  Future<void> onSavingsGoalUpdate({
    required String goalId,
    required String goalName,
    required double currentAmount,
    required double targetAmount,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onSavingsGoalUpdate(
      goalId: goalId,
      goalName: goalName,
      currentAmount: currentAmount,
      targetAmount: targetAmount,
      userId: userId,
    );
  }

  /// 便捷方法：预算达成
  Future<void> onBudgetAchieved({
    required String vaultId,
    required String vaultName,
    required double budgetAmount,
    required double spentAmount,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onBudgetAchieved(
      vaultId: vaultId,
      vaultName: vaultName,
      budgetAmount: budgetAmount,
      spentAmount: spentAmount,
      userId: userId,
    );
  }

  /// 便捷方法：特殊日期
  Future<void> onSpecialDate({
    required String dateType,
    required String dateName,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onSpecialDate(
      dateType: dateType,
      dateName: dateName,
      userId: userId,
    );
  }

  /// 便捷方法：AI洞察发现
  Future<void> onInsightDiscovered({
    required String insightId,
    required String insightTitle,
    required String insightContent,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onInsightDiscovered(
      insightId: insightId,
      insightTitle: insightTitle,
      insightContent: insightContent,
      userId: userId,
    );
  }

  /// 便捷方法：晚间总结
  Future<void> onEveningSummary({
    required double todaySpent,
    required int todayTransactions,
    String? userId,
  }) async {
    if (!_isInitialized) return;
    await _integrationService.onEveningSummary(
      todaySpent: todaySpent,
      todayTransactions: todayTransactions,
      userId: userId,
    );
  }

  /// 释放资源
  void dispose() {
    if (_isInitialized) {
      _integrationService.dispose();
      _isInitialized = false;
    }
  }
}
