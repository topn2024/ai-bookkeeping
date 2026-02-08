import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile_service.dart';

/// 用户画像调度器服务
///
/// 实现设计文档17.6.3中的画像构建触发条件：
/// - 首次构建：累计30笔交易
/// - 每日更新：增量更新（轻量级）
/// - 每周分析：性格特征/消费模式分析
/// - 月度深度分析：全量重建
/// - 事件触发：大额消费/异常消费时自动更新
///
/// 使用示例：
/// ```dart
/// final scheduler = UserProfileScheduler(
///   profileService: userProfileService,
///   transactionSource: transactionDataSource,
/// );
/// await scheduler.initialize(userId);
/// scheduler.start();
/// ```
class UserProfileScheduler {
  final UserProfileService _profileService;
  final TransactionDataSource _transactionSource;
  final ProfileUpdateConfig _config;

  Timer? _dailyTimer;
  Timer? _weeklyTimer;
  Timer? _monthlyTimer;
  StreamSubscription? _transactionSubscription;

  String? _currentUserId;
  bool _isRunning = false;

  // 持久化存储 key
  static const String _lastDailyUpdateKey = 'profile_last_daily_update';
  static const String _lastWeeklyUpdateKey = 'profile_last_weekly_update';
  static const String _lastMonthlyUpdateKey = 'profile_last_monthly_update';
  static const String _profileBuiltKey = 'profile_built';

  UserProfileScheduler({
    required UserProfileService profileService,
    required TransactionDataSource transactionSource,
    ProfileUpdateConfig? config,
  })  : _profileService = profileService,
        _transactionSource = transactionSource,
        _config = config ?? const ProfileUpdateConfig();

  /// 初始化调度器
  Future<void> initialize(String userId) async {
    _currentUserId = userId;

    // 检查是否需要首次构建
    await _checkInitialBuild(userId);

    // 检查是否需要补充执行
    await _checkMissedUpdates(userId);
  }

  /// 启动调度器
  void start() {
    if (_isRunning || _currentUserId == null) return;
    _isRunning = true;

    _startDailyScheduler();
    _startWeeklyScheduler();
    _startMonthlyScheduler();

    debugPrint('[UserProfileScheduler] Started for user: $_currentUserId');
  }

  /// 停止调度器
  void stop() {
    _isRunning = false;
    _dailyTimer?.cancel();
    _weeklyTimer?.cancel();
    _monthlyTimer?.cancel();
    _transactionSubscription?.cancel();

    _dailyTimer = null;
    _weeklyTimer = null;
    _monthlyTimer = null;
    _transactionSubscription = null;

    debugPrint('[UserProfileScheduler] Stopped');
  }

  /// 检查首次构建条件
  Future<void> _checkInitialBuild(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final isBuilt = prefs.getBool('${_profileBuiltKey}_$userId') ?? false;

    if (isBuilt) return;

    // 检查交易数量
    final transactions = await _transactionSource.getAll(userId);
    if (transactions.length >= _config.initialBuildThreshold) {
      debugPrint(
          '[UserProfileScheduler] Initial build triggered: ${transactions.length} transactions');
      await _performFullBuild(userId, ProfileUpdateReason.initialBuild);
      await prefs.setBool('${_profileBuiltKey}_$userId', true);
    }
  }

  /// 检查遗漏的更新
  Future<void> _checkMissedUpdates(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 检查每日更新
    final lastDailyStr = prefs.getString('${_lastDailyUpdateKey}_$userId');
    if (lastDailyStr != null) {
      final lastDaily = DateTime.parse(lastDailyStr);
      if (now.difference(lastDaily) > const Duration(days: 1)) {
        debugPrint('[UserProfileScheduler] Missed daily update, executing now');
        await _performDailyUpdate(userId);
      }
    }

    // 检查每周更新
    final lastWeeklyStr = prefs.getString('${_lastWeeklyUpdateKey}_$userId');
    if (lastWeeklyStr != null) {
      final lastWeekly = DateTime.parse(lastWeeklyStr);
      if (now.difference(lastWeekly) > const Duration(days: 7)) {
        debugPrint(
            '[UserProfileScheduler] Missed weekly update, executing now');
        await _performWeeklyAnalysis(userId);
      }
    }

    // 检查每月更新
    final lastMonthlyStr = prefs.getString('${_lastMonthlyUpdateKey}_$userId');
    if (lastMonthlyStr != null) {
      final lastMonthly = DateTime.parse(lastMonthlyStr);
      if (now.difference(lastMonthly) > const Duration(days: 30)) {
        debugPrint(
            '[UserProfileScheduler] Missed monthly update, executing now');
        await _performFullBuild(userId, ProfileUpdateReason.monthlyDeepAnalysis);
      }
    }
  }

  /// 启动每日调度器
  void _startDailyScheduler() {
    // 计算到明天凌晨2点的时间（选择用户不活跃时段）
    final now = DateTime.now();
    var nextRun = DateTime(now.year, now.month, now.day, 2, 0, 0);
    if (nextRun.isBefore(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }
    final initialDelay = nextRun.difference(now);

    // 先设置初始延迟，然后每24小时执行一次
    Future.delayed(initialDelay, () {
      if (!_isRunning) return;
      _executeDailyUpdate();
      _dailyTimer = Timer.periodic(const Duration(days: 1), (_) {
        _executeDailyUpdate();
      });
    });

    debugPrint(
        '[UserProfileScheduler] Daily scheduler: next run in ${initialDelay.inHours}h ${initialDelay.inMinutes % 60}m');
  }

  /// 启动每周调度器
  void _startWeeklyScheduler() {
    // 每周日凌晨3点执行
    final now = DateTime.now();
    var nextSunday = now;
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }
    nextSunday = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 3, 0, 0);
    if (nextSunday.isBefore(now)) {
      nextSunday = nextSunday.add(const Duration(days: 7));
    }
    final initialDelay = nextSunday.difference(now);

    Future.delayed(initialDelay, () {
      if (!_isRunning) return;
      _executeWeeklyAnalysis();
      _weeklyTimer = Timer.periodic(const Duration(days: 7), (_) {
        _executeWeeklyAnalysis();
      });
    });

    debugPrint(
        '[UserProfileScheduler] Weekly scheduler: next run in ${initialDelay.inDays}d');
  }

  /// 启动每月调度器
  void _startMonthlyScheduler() {
    // 每月1日凌晨4点执行
    final now = DateTime.now();
    var nextMonth = DateTime(now.year, now.month + 1, 1, 4, 0, 0);
    if (now.month == 12) {
      nextMonth = DateTime(now.year + 1, 1, 1, 4, 0, 0);
    }
    final initialDelay = nextMonth.difference(now);

    Future.delayed(initialDelay, () {
      if (!_isRunning) return;
      _executeMonthlyDeepAnalysis();
      // 每月执行需要重新计算下一个月1日
      _scheduleNextMonthlyRun();
    });

    debugPrint(
        '[UserProfileScheduler] Monthly scheduler: next run in ${initialDelay.inDays}d');
  }

  void _scheduleNextMonthlyRun() {
    final now = DateTime.now();
    var nextMonth = DateTime(now.year, now.month + 1, 1, 4, 0, 0);
    if (now.month == 12) {
      nextMonth = DateTime(now.year + 1, 1, 1, 4, 0, 0);
    }
    final delay = nextMonth.difference(now);

    _monthlyTimer = Timer(delay, () {
      if (!_isRunning) return;
      _executeMonthlyDeepAnalysis();
      _scheduleNextMonthlyRun();
    });
  }

  /// 执行每日更新
  void _executeDailyUpdate() {
    if (_currentUserId == null) return;
    _performDailyUpdate(_currentUserId!);
  }

  /// 执行每周分析
  void _executeWeeklyAnalysis() {
    if (_currentUserId == null) return;
    _performWeeklyAnalysis(_currentUserId!);
  }

  /// 执行每月深度分析
  void _executeMonthlyDeepAnalysis() {
    if (_currentUserId == null) return;
    _performFullBuild(_currentUserId!, ProfileUpdateReason.monthlyDeepAnalysis);
  }

  /// 每日增量更新（轻量级）
  Future<void> _performDailyUpdate(String userId) async {
    try {
      debugPrint('[UserProfileScheduler] Performing daily update for $userId');

      // 增量更新：只更新消费行为和财务特征
      final profile = await _profileService.getProfile(userId);
      if (profile == null) {
        // 如果没有画像，执行完整构建
        await _performFullBuild(userId, ProfileUpdateReason.initialBuild);
        return;
      }

      // 这里可以实现增量更新逻辑
      // 目前简化为检查是否需要完整更新
      if (profile.needsUpdate) {
        await _profileService.rebuildProfile(userId);
      }

      // 记录更新时间
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_lastDailyUpdateKey}_$userId', DateTime.now().toIso8601String());

      _notifyUpdate(ProfileUpdateEvent(
        userId: userId,
        reason: ProfileUpdateReason.dailyUpdate,
        timestamp: DateTime.now(),
        success: true,
      ));
    } catch (e) {
      debugPrint('[UserProfileScheduler] Daily update failed: $e');
      _notifyUpdate(ProfileUpdateEvent(
        userId: userId,
        reason: ProfileUpdateReason.dailyUpdate,
        timestamp: DateTime.now(),
        success: false,
        error: e.toString(),
      ));
    }
  }

  /// 每周分析（性格特征/消费模式）
  Future<void> _performWeeklyAnalysis(String userId) async {
    try {
      debugPrint('[UserProfileScheduler] Performing weekly analysis for $userId');

      // 每周分析：重新分析性格特征和消费模式
      await _profileService.rebuildProfile(userId);

      // 记录更新时间
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_lastWeeklyUpdateKey}_$userId', DateTime.now().toIso8601String());

      _notifyUpdate(ProfileUpdateEvent(
        userId: userId,
        reason: ProfileUpdateReason.weeklyAnalysis,
        timestamp: DateTime.now(),
        success: true,
      ));
    } catch (e) {
      debugPrint('[UserProfileScheduler] Weekly analysis failed: $e');
      _notifyUpdate(ProfileUpdateEvent(
        userId: userId,
        reason: ProfileUpdateReason.weeklyAnalysis,
        timestamp: DateTime.now(),
        success: false,
        error: e.toString(),
      ));
    }
  }

  /// 全量重建
  Future<void> _performFullBuild(
      String userId, ProfileUpdateReason reason) async {
    try {
      debugPrint(
          '[UserProfileScheduler] Performing full build for $userId, reason: $reason');

      await _profileService.rebuildProfile(userId);

      // 记录更新时间
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_lastMonthlyUpdateKey}_$userId', DateTime.now().toIso8601String());

      _notifyUpdate(ProfileUpdateEvent(
        userId: userId,
        reason: reason,
        timestamp: DateTime.now(),
        success: true,
      ));
    } catch (e) {
      debugPrint('[UserProfileScheduler] Full build failed: $e');
      _notifyUpdate(ProfileUpdateEvent(
        userId: userId,
        reason: reason,
        timestamp: DateTime.now(),
        success: false,
        error: e.toString(),
      ));
    }
  }

  // 事件监听器列表
  final List<void Function(ProfileUpdateEvent)> _listeners = [];

  /// 添加更新监听器
  void addListener(void Function(ProfileUpdateEvent) listener) {
    _listeners.add(listener);
  }

  /// 移除更新监听器
  void removeListener(void Function(ProfileUpdateEvent) listener) {
    _listeners.remove(listener);
  }

  void _notifyUpdate(ProfileUpdateEvent event) {
    for (final listener in _listeners) {
      listener(event);
    }
  }

  /// 获取下次更新时间
  ProfileNextUpdateInfo getNextUpdateInfo() {
    final now = DateTime.now();

    // 计算下次每日更新
    var nextDaily = DateTime(now.year, now.month, now.day, 2, 0, 0);
    if (nextDaily.isBefore(now)) {
      nextDaily = nextDaily.add(const Duration(days: 1));
    }

    // 计算下次每周更新
    var nextWeekly = now;
    while (nextWeekly.weekday != DateTime.sunday) {
      nextWeekly = nextWeekly.add(const Duration(days: 1));
    }
    nextWeekly = DateTime(nextWeekly.year, nextWeekly.month, nextWeekly.day, 3, 0, 0);
    if (nextWeekly.isBefore(now)) {
      nextWeekly = nextWeekly.add(const Duration(days: 7));
    }

    // 计算下次每月更新
    var nextMonthly = DateTime(now.year, now.month + 1, 1, 4, 0, 0);
    if (now.month == 12) {
      nextMonthly = DateTime(now.year + 1, 1, 1, 4, 0, 0);
    }

    return ProfileNextUpdateInfo(
      nextDaily: nextDaily,
      nextWeekly: nextWeekly,
      nextMonthly: nextMonthly,
    );
  }

  /// 手动触发更新
  Future<void> triggerUpdate(ProfileUpdateReason reason) async {
    if (_currentUserId == null) return;

    switch (reason) {
      case ProfileUpdateReason.dailyUpdate:
        await _performDailyUpdate(_currentUserId!);
        break;
      case ProfileUpdateReason.weeklyAnalysis:
        await _performWeeklyAnalysis(_currentUserId!);
        break;
      case ProfileUpdateReason.monthlyDeepAnalysis:
      case ProfileUpdateReason.initialBuild:
      case ProfileUpdateReason.eventTriggered:
      case ProfileUpdateReason.manualRefresh:
        await _performFullBuild(_currentUserId!, reason);
        break;
    }
  }

  /// 释放资源
  void dispose() {
    stop();
    _listeners.clear();
    debugPrint('[UserProfileScheduler] Disposed');
  }
}

/// 画像更新事件触发器
///
/// 监听交易事件，当满足特定条件时触发画像更新
class ProfileUpdateTrigger {
  final UserProfileScheduler _scheduler;
  final ProfileTriggerConfig _config;

  ProfileUpdateTrigger({
    required UserProfileScheduler scheduler,
    ProfileTriggerConfig? config,
  })  : _scheduler = scheduler,
        _config = config ?? const ProfileTriggerConfig();

  /// 处理新交易事件
  Future<void> onNewTransaction(TransactionEvent event) async {
    // 检查是否触发更新
    final triggers = <ProfileUpdateTriggerType>[];

    // 1. 大额消费触发
    if (_isLargeTransaction(event)) {
      triggers.add(ProfileUpdateTriggerType.largeTransaction);
    }

    // 2. 异常消费触发
    if (await _isAnomalousTransaction(event)) {
      triggers.add(ProfileUpdateTriggerType.anomalousTransaction);
    }

    // 3. 新类目触发
    if (await _isNewCategory(event)) {
      triggers.add(ProfileUpdateTriggerType.newCategory);
    }

    // 4. 首笔收入触发
    if (event.type == 'income' && await _isFirstIncome(event)) {
      triggers.add(ProfileUpdateTriggerType.firstIncome);
    }

    // 如果有触发条件，执行更新
    if (triggers.isNotEmpty) {
      debugPrint(
          '[ProfileUpdateTrigger] Triggered by: ${triggers.map((t) => t.name).join(', ')}');
      await _scheduler.triggerUpdate(ProfileUpdateReason.eventTriggered);
    }
  }

  /// 处理预算变更事件
  Future<void> onBudgetChange(BudgetChangeEvent event) async {
    if (event.changeType == BudgetChangeType.significantOverspend) {
      debugPrint('[ProfileUpdateTrigger] Significant overspend detected');
      await _scheduler.triggerUpdate(ProfileUpdateReason.eventTriggered);
    }
  }

  /// 处理用户行为事件
  Future<void> onUserBehavior(UserBehaviorEvent event) async {
    // 用户连续7天未记账后恢复
    if (event.type == UserBehaviorType.returnAfterInactive) {
      debugPrint('[ProfileUpdateTrigger] User returned after inactivity');
      await _scheduler.triggerUpdate(ProfileUpdateReason.eventTriggered);
    }
  }

  /// 检查是否为大额交易
  bool _isLargeTransaction(TransactionEvent event) {
    return event.amount >= _config.largeTransactionThreshold;
  }

  /// 检查是否为异常交易
  Future<bool> _isAnomalousTransaction(TransactionEvent event) async {
    // 简化实现：金额超过月均值的3倍视为异常
    // 实际实现应该使用 AnomalyDetectionService
    return event.amount >= _config.anomalyMultiplier * event.monthlyAverage;
  }

  /// 检查是否为新类目
  Future<bool> _isNewCategory(TransactionEvent event) async {
    // 检查该类目是否从未出现过
    return event.isFirstTimeCategory;
  }

  /// 检查是否为首笔收入
  Future<bool> _isFirstIncome(TransactionEvent event) async {
    return event.isFirstIncome;
  }
}

// ==================== 配置类 ====================

/// 调度器配置
class ProfileUpdateConfig {
  /// 首次构建所需的最少交易数
  final int initialBuildThreshold;

  /// 每日更新时间（小时，24小时制）
  final int dailyUpdateHour;

  /// 每周更新的星期几 (1=周一, 7=周日)
  final int weeklyUpdateDay;

  /// 每月更新的日期
  final int monthlyUpdateDay;

  const ProfileUpdateConfig({
    this.initialBuildThreshold = 30,
    this.dailyUpdateHour = 2,
    this.weeklyUpdateDay = 7,
    this.monthlyUpdateDay = 1,
  });
}

/// 事件触发配置
class ProfileTriggerConfig {
  /// 大额交易阈值
  final double largeTransactionThreshold;

  /// 异常倍数（超过月均值的倍数视为异常）
  final double anomalyMultiplier;

  const ProfileTriggerConfig({
    this.largeTransactionThreshold = 1000.0,
    this.anomalyMultiplier = 3.0,
  });
}

// ==================== 事件类 ====================

/// 画像更新原因
enum ProfileUpdateReason {
  /// 首次构建（累计30笔交易）
  initialBuild,

  /// 每日更新
  dailyUpdate,

  /// 每周分析
  weeklyAnalysis,

  /// 月度深度分析
  monthlyDeepAnalysis,

  /// 事件触发
  eventTriggered,

  /// 手动刷新
  manualRefresh,
}

extension ProfileUpdateReasonExtension on ProfileUpdateReason {
  String get label {
    switch (this) {
      case ProfileUpdateReason.initialBuild:
        return '首次构建';
      case ProfileUpdateReason.dailyUpdate:
        return '每日更新';
      case ProfileUpdateReason.weeklyAnalysis:
        return '每周分析';
      case ProfileUpdateReason.monthlyDeepAnalysis:
        return '月度深度分析';
      case ProfileUpdateReason.eventTriggered:
        return '事件触发';
      case ProfileUpdateReason.manualRefresh:
        return '手动刷新';
    }
  }
}

/// 画像更新事件
class ProfileUpdateEvent {
  final String userId;
  final ProfileUpdateReason reason;
  final DateTime timestamp;
  final bool success;
  final String? error;

  const ProfileUpdateEvent({
    required this.userId,
    required this.reason,
    required this.timestamp,
    required this.success,
    this.error,
  });
}

/// 下次更新信息
class ProfileNextUpdateInfo {
  final DateTime nextDaily;
  final DateTime nextWeekly;
  final DateTime nextMonthly;

  const ProfileNextUpdateInfo({
    required this.nextDaily,
    required this.nextWeekly,
    required this.nextMonthly,
  });

  /// 获取最近的下次更新
  DateTime get nextUpdate {
    if (nextDaily.isBefore(nextWeekly) && nextDaily.isBefore(nextMonthly)) {
      return nextDaily;
    } else if (nextWeekly.isBefore(nextMonthly)) {
      return nextWeekly;
    }
    return nextMonthly;
  }
}

/// 事件触发类型
enum ProfileUpdateTriggerType {
  /// 大额交易
  largeTransaction,

  /// 异常交易
  anomalousTransaction,

  /// 新消费类目
  newCategory,

  /// 首笔收入
  firstIncome,
}

/// 交易事件
class TransactionEvent {
  final String id;
  final String type;
  final double amount;
  final String category;
  final DateTime timestamp;
  final double monthlyAverage;
  final bool isFirstTimeCategory;
  final bool isFirstIncome;

  const TransactionEvent({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.timestamp,
    required this.monthlyAverage,
    this.isFirstTimeCategory = false,
    this.isFirstIncome = false,
  });
}

/// 预算变更事件
class BudgetChangeEvent {
  final String budgetId;
  final String category;
  final BudgetChangeType changeType;
  final double? overspendRatio;

  const BudgetChangeEvent({
    required this.budgetId,
    required this.category,
    required this.changeType,
    this.overspendRatio,
  });
}

/// 预算变更类型
enum BudgetChangeType {
  /// 预算调整
  adjusted,

  /// 显著超支（超过预算50%以上）
  significantOverspend,

  /// 预算完成
  completed,
}

/// 用户行为事件
class UserBehaviorEvent {
  final UserBehaviorType type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const UserBehaviorEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });
}

/// 用户行为类型
enum UserBehaviorType {
  /// 不活跃后回归
  returnAfterInactive,

  /// 完成首次记账
  firstRecord,

  /// 连续记账达成里程碑
  streakMilestone,
}
