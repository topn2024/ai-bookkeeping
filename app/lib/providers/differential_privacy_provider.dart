import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/privacy/differential_privacy/privacy_budget_manager.dart';
import '../services/privacy/differential_privacy/differential_privacy_engine.dart';
import '../services/privacy/anomaly_detection/malicious_user_tracker.dart';
import '../services/privacy/anomaly_detection/anomaly_detector.dart';
import '../services/privacy/models/sensitivity_level.dart';

// ==================== 服务 Provider ====================

/// 隐私预算管理器 Provider
final privacyBudgetManagerProvider = Provider<PrivacyBudgetManager>((ref) {
  final manager = PrivacyBudgetManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// 差分隐私引擎 Provider
final differentialPrivacyEngineProvider =
    Provider<DifferentialPrivacyEngine>((ref) {
  final budgetManager = ref.watch(privacyBudgetManagerProvider);
  return DifferentialPrivacyEngine(budgetManager: budgetManager);
});

/// 恶意用户追踪器 Provider
final maliciousUserTrackerProvider = Provider<MaliciousUserTracker>((ref) {
  final tracker = MaliciousUserTracker();
  ref.onDispose(() => tracker.dispose());
  return tracker;
});

/// 异常检测器 Provider
final anomalyDetectorProvider = Provider<AnomalyDetector>((ref) {
  final userTracker = ref.watch(maliciousUserTrackerProvider);
  return AnomalyDetector(userTracker: userTracker);
});

// ==================== 状态 Provider ====================

/// 隐私预算状态
class PrivacyBudgetStatusState {
  /// 剩余预算百分比
  final double remainingPercent;

  /// 是否耗尽
  final bool isExhausted;

  /// 各级别消耗统计
  final Map<SensitivityLevel, BudgetLevelStats> levelStats;

  /// 最后更新时间
  final DateTime lastUpdated;

  const PrivacyBudgetStatusState({
    required this.remainingPercent,
    required this.isExhausted,
    required this.levelStats,
    required this.lastUpdated,
  });

  factory PrivacyBudgetStatusState.initial() {
    return PrivacyBudgetStatusState(
      remainingPercent: 100.0,
      isExhausted: false,
      levelStats: {},
      lastUpdated: DateTime.now(),
    );
  }
}

/// 隐私预算状态 Notifier
class PrivacyBudgetStatusNotifier extends Notifier<PrivacyBudgetStatusState> {
  @override
  PrivacyBudgetStatusState build() {
    final manager = ref.watch(privacyBudgetManagerProvider);

    // 监听预算管理器变化
    manager.addListener(_onBudgetChanged);
    ref.onDispose(() => manager.removeListener(_onBudgetChanged));

    return _createState(manager);
  }

  void _onBudgetChanged() {
    final manager = ref.read(privacyBudgetManagerProvider);
    state = _createState(manager);
  }

  PrivacyBudgetStatusState _createState(PrivacyBudgetManager manager) {
    return PrivacyBudgetStatusState(
      remainingPercent: manager.remainingBudgetPercent,
      isExhausted: manager.isExhausted,
      levelStats: manager.getLevelStats(),
      lastUpdated: DateTime.now(),
    );
  }

  /// 重置预算
  Future<void> resetBudget() async {
    final manager = ref.read(privacyBudgetManagerProvider);
    await manager.reset();
    state = _createState(manager);
  }
}

/// 隐私预算状态 Provider
final privacyBudgetStatusProvider =
    NotifierProvider<PrivacyBudgetStatusNotifier, PrivacyBudgetStatusState>(
        PrivacyBudgetStatusNotifier.new);

// ==================== 用户追踪状态 Provider ====================

/// 用户追踪状态
class UserTrackingState {
  /// 隔离用户数
  final int isolatedUserCount;

  /// 观察中用户数
  final int usersUnderReviewCount;

  /// 总异常数
  final int totalAnomalies;

  /// 总贡献数
  final int totalContributions;

  /// 异常率
  final double anomalyRate;

  const UserTrackingState({
    required this.isolatedUserCount,
    required this.usersUnderReviewCount,
    required this.totalAnomalies,
    required this.totalContributions,
    required this.anomalyRate,
  });

  factory UserTrackingState.initial() {
    return const UserTrackingState(
      isolatedUserCount: 0,
      usersUnderReviewCount: 0,
      totalAnomalies: 0,
      totalContributions: 0,
      anomalyRate: 0,
    );
  }
}

/// 用户追踪状态 Notifier
class UserTrackingNotifier extends Notifier<UserTrackingState> {
  @override
  UserTrackingState build() {
    final tracker = ref.watch(maliciousUserTrackerProvider);

    // 监听追踪器变化
    tracker.addListener(_onTrackerChanged);
    ref.onDispose(() => tracker.removeListener(_onTrackerChanged));

    return _createState(tracker);
  }

  void _onTrackerChanged() {
    final tracker = ref.read(maliciousUserTrackerProvider);
    state = _createState(tracker);
  }

  UserTrackingState _createState(MaliciousUserTracker tracker) {
    final stats = tracker.getStatistics();
    return UserTrackingState(
      isolatedUserCount: stats.isolatedUsers,
      usersUnderReviewCount: stats.usersUnderReview,
      totalAnomalies: stats.totalAnomalies,
      totalContributions: stats.totalContributions,
      anomalyRate: stats.anomalyRate,
    );
  }

  /// 清除所有追踪数据
  Future<void> clearAll() async {
    final tracker = ref.read(maliciousUserTrackerProvider);
    await tracker.clearAll();
    state = _createState(tracker);
  }
}

/// 用户追踪状态 Provider
final userTrackingProvider =
    NotifierProvider<UserTrackingNotifier, UserTrackingState>(
        UserTrackingNotifier.new);

// ==================== 便捷 Provider ====================

/// 预算是否耗尽 Provider
final isPrivacyBudgetExhaustedProvider = Provider<bool>((ref) {
  final status = ref.watch(privacyBudgetStatusProvider);
  return status.isExhausted;
});

/// 剩余预算百分比 Provider
final remainingBudgetPercentProvider = Provider<double>((ref) {
  final status = ref.watch(privacyBudgetStatusProvider);
  return status.remainingPercent;
});

/// 隔离用户列表 Provider
final isolatedUsersProvider = Provider<List<String>>((ref) {
  final tracker = ref.watch(maliciousUserTrackerProvider);
  return tracker.isolatedUsers;
});

/// 检查用户是否可以贡献 Provider
final canUserContributeProvider =
    Provider.family<bool, String>((ref, userId) {
  final tracker = ref.watch(maliciousUserTrackerProvider);
  return tracker.canContribute(userId);
});
