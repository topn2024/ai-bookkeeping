import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_profile_service.dart';
import 'user_profile_scheduler.dart';
import 'database_service.dart';
import '../models/transaction.dart' as model;

/// 用户画像系统集成服务
///
/// 整合用户画像分析、定时调度和事件触发功能，
/// 提供统一的初始化和生命周期管理
class UserProfileIntegration {
  final UserProfileService _profileService;
  final UserProfileScheduler _scheduler;
  final ProfileUpdateTrigger _trigger;

  bool _isInitialized = false;
  String? _currentUserId;

  UserProfileIntegration({
    required UserProfileService profileService,
    required TransactionDataSource transactionSource,
    ProfileUpdateConfig? schedulerConfig,
    ProfileTriggerConfig? triggerConfig,
  })  : _profileService = profileService,
        _scheduler = UserProfileScheduler(
          profileService: profileService,
          transactionSource: transactionSource,
          config: schedulerConfig,
        ),
        _trigger = ProfileUpdateTrigger(
          scheduler: UserProfileScheduler(
            profileService: profileService,
            transactionSource: transactionSource,
            config: schedulerConfig,
          ),
          config: triggerConfig,
        );

  /// 初始化用户画像系统
  ///
  /// 在用户登录后调用，启动画像构建和调度
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      debugPrint('[UserProfileIntegration] Already initialized for user: $userId');
      return;
    }

    // 如果之前有其他用户，先停止
    if (_isInitialized) {
      await shutdown();
    }

    _currentUserId = userId;

    try {
      // 1. 初始化调度器（检查首次构建和遗漏更新）
      await _scheduler.initialize(userId);

      // 2. 启动定时调度
      _scheduler.start();

      // 3. 添加更新事件监听
      _scheduler.addListener(_onProfileUpdate);

      _isInitialized = true;
      debugPrint('[UserProfileIntegration] Initialized for user: $userId');
    } catch (e) {
      debugPrint('[UserProfileIntegration] Initialization failed: $e');
      rethrow;
    }
  }

  /// 关闭用户画像系统
  Future<void> shutdown() async {
    if (!_isInitialized) return;

    _scheduler.removeListener(_onProfileUpdate);
    _scheduler.dispose();

    _isInitialized = false;
    _currentUserId = null;

    debugPrint('[UserProfileIntegration] Shutdown complete');
  }

  /// 处理新交易事件
  ///
  /// 在记账完成后调用，检查是否触发画像更新
  Future<void> onNewTransaction(TransactionEvent event) async {
    if (!_isInitialized) return;
    await _trigger.onNewTransaction(event);
  }

  /// 处理预算变更事件
  Future<void> onBudgetChange(BudgetChangeEvent event) async {
    if (!_isInitialized) return;
    await _trigger.onBudgetChange(event);
  }

  /// 处理用户行为事件
  Future<void> onUserBehavior(UserBehaviorEvent event) async {
    if (!_isInitialized) return;
    await _trigger.onUserBehavior(event);
  }

  /// 手动触发画像更新
  Future<void> refreshProfile() async {
    if (!_isInitialized || _currentUserId == null) return;
    await _scheduler.triggerUpdate(ProfileUpdateReason.manualRefresh);
  }

  /// 获取当前用户画像
  Future<UserProfile?> getCurrentProfile() async {
    if (_currentUserId == null) return null;
    return _profileService.getProfile(_currentUserId!);
  }

  /// 获取下次更新信息
  ProfileNextUpdateInfo? getNextUpdateInfo() {
    if (!_isInitialized) return null;
    return _scheduler.getNextUpdateInfo();
  }

  /// 画像更新事件处理
  void _onProfileUpdate(ProfileUpdateEvent event) {
    debugPrint(
        '[UserProfileIntegration] Profile updated: ${event.reason.label}, success: ${event.success}');

    // 可以在这里添加额外的处理逻辑
    // 例如：通知UI更新、记录分析埋点等
  }

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 当前用户ID
  String? get currentUserId => _currentUserId;
}

// ==================== Riverpod Providers ====================

/// 数据库服务 Provider
final _databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// 交易数据源实现
class DatabaseTransactionDataSource implements TransactionDataSource {
  final DatabaseService _db;

  DatabaseTransactionDataSource(this._db);

  @override
  Future<List<TransactionData>> getAll(String userId) async {
    final transactions = await _db.getTransactions();
    return transactions.map((t) => TransactionData(
      id: t.id,
      type: t.type == model.TransactionType.income
          ? 'income'
          : t.type == model.TransactionType.expense
              ? 'expense'
              : 'transfer',
      amount: t.amount,
      category: t.category,
      merchant: t.rawMerchant,
      date: t.date,
    )).toList();
  }
}

/// 交易数据源 Provider
final transactionDataSourceProvider = Provider<TransactionDataSource>((ref) {
  final db = ref.watch(_databaseServiceProvider);
  return DatabaseTransactionDataSource(db);
});

/// 用户画像集成服务 Provider
final userProfileIntegrationProvider = Provider<UserProfileIntegration>((ref) {
  final profileService = ref.watch(userProfileServiceProvider);
  final transactionSource = ref.watch(transactionDataSourceProvider);

  return UserProfileIntegration(
    profileService: profileService,
    transactionSource: transactionSource,
  );
});

/// 用户画像调度器 Provider
final userProfileSchedulerProvider = Provider<UserProfileScheduler>((ref) {
  final profileService = ref.watch(userProfileServiceProvider);
  final transactionSource = ref.watch(transactionDataSourceProvider);

  return UserProfileScheduler(
    profileService: profileService,
    transactionSource: transactionSource,
  );
});

/// 画像更新触发器 Provider
final profileUpdateTriggerProvider = Provider<ProfileUpdateTrigger>((ref) {
  final scheduler = ref.watch(userProfileSchedulerProvider);

  return ProfileUpdateTrigger(scheduler: scheduler);
});

// ==================== 辅助扩展 ====================

/// 从交易记录创建交易事件的扩展方法
extension TransactionEventFactory on TransactionEvent {
  /// 从交易数据创建事件
  ///
  /// [transaction] 交易数据Map，需包含 id, type, amount, category, timestamp
  /// [monthlyAverage] 用户月均消费
  /// [isFirstTimeCategory] 是否首次使用该分类
  /// [isFirstIncome] 是否首笔收入
  static TransactionEvent fromTransaction({
    required Map<String, dynamic> transaction,
    required double monthlyAverage,
    bool isFirstTimeCategory = false,
    bool isFirstIncome = false,
  }) {
    return TransactionEvent(
      id: transaction['id'] as String,
      type: transaction['type'] as String,
      amount: (transaction['amount'] as num).toDouble(),
      category: transaction['category'] as String,
      timestamp: transaction['timestamp'] as DateTime,
      monthlyAverage: monthlyAverage,
      isFirstTimeCategory: isFirstTimeCategory,
      isFirstIncome: isFirstIncome,
    );
  }
}

/// 画像更新原因的描述扩展
extension ProfileUpdateReasonDescription on ProfileUpdateReason {
  String get description {
    switch (this) {
      case ProfileUpdateReason.initialBuild:
        return '首次构建用户画像（累计满30笔交易）';
      case ProfileUpdateReason.dailyUpdate:
        return '每日增量更新，轻量级刷新消费行为特征';
      case ProfileUpdateReason.weeklyAnalysis:
        return '每周深度分析，更新性格特征和消费模式';
      case ProfileUpdateReason.monthlyDeepAnalysis:
        return '月度全量重建，完整重新计算所有画像维度';
      case ProfileUpdateReason.eventTriggered:
        return '事件触发更新（大额消费/异常消费/新类目等）';
      case ProfileUpdateReason.manualRefresh:
        return '用户手动触发刷新';
    }
  }
}
