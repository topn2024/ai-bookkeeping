import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_dashboard.dart';
import '../models/member.dart';
import '../services/family_dashboard_service.dart';

/// FamilyDashboardService Provider
final familyDashboardServiceProvider =
    Provider<FamilyDashboardService>((ref) {
  return FamilyDashboardService();
});

/// 家庭看板状态
class FamilyDashboardState {
  final FamilyDashboardData? data;
  final bool isLoading;
  final String? error;
  final String? ledgerId;
  final String? period;

  const FamilyDashboardState({
    this.data,
    this.isLoading = false,
    this.error,
    this.ledgerId,
    this.period,
  });

  FamilyDashboardState copyWith({
    FamilyDashboardData? data,
    bool? isLoading,
    String? error,
    String? ledgerId,
    String? period,
  }) {
    return FamilyDashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      ledgerId: ledgerId ?? this.ledgerId,
      period: period ?? this.period,
    );
  }
}

/// 家庭看板 Notifier
class FamilyDashboardNotifier extends Notifier<FamilyDashboardState> {
  @override
  FamilyDashboardState build() {
    return const FamilyDashboardState();
  }

  FamilyDashboardService get _dashboardService =>
      ref.read(familyDashboardServiceProvider);

  /// 加载看板数据
  Future<void> loadDashboard({
    required String ledgerId,
    required String period,
    required List<LedgerMember> members,
  }) async {
    state = state.copyWith(
      isLoading: true,
      ledgerId: ledgerId,
      period: period,
    );

    try {
      final data = await _dashboardService.getDashboardData(
        ledgerId: ledgerId,
        period: period,
        members: members,
      );
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 刷新数据
  Future<void> refresh(List<LedgerMember> members) async {
    if (state.ledgerId == null || state.period == null) return;

    await loadDashboard(
      ledgerId: state.ledgerId!,
      period: state.period!,
      members: members,
    );
  }

  /// 切换周期
  Future<void> changePeriod(String newPeriod, List<LedgerMember> members) async {
    if (state.ledgerId == null) return;

    await loadDashboard(
      ledgerId: state.ledgerId!,
      period: newPeriod,
      members: members,
    );
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 家庭看板 Provider
final familyDashboardProvider =
    NotifierProvider<FamilyDashboardNotifier, FamilyDashboardState>(
        FamilyDashboardNotifier.new);

/// 快速统计 Provider
final quickStatsProvider =
    FutureProvider.family<QuickStats, QuickStatsParams>((ref, params) async {
  final dashboardService = ref.watch(familyDashboardServiceProvider);
  return dashboardService.getQuickStats(
    ledgerId: params.ledgerId,
    period: params.period,
  );
});

/// 快速统计参数
class QuickStatsParams {
  final String ledgerId;
  final String period;

  const QuickStatsParams({
    required this.ledgerId,
    required this.period,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickStatsParams &&
        other.ledgerId == ledgerId &&
        other.period == period;
  }

  @override
  int get hashCode => ledgerId.hashCode ^ period.hashCode;
}

/// 成员贡献 Provider（单独提供以便局部刷新）
final memberContributionsProvider =
    FutureProvider.family<List<MemberContribution>, String>(
        (ref, ledgerId) async {
  final dashboardState = ref.watch(familyDashboardProvider);
  return dashboardState.data?.memberContributions ?? [];
});

/// 分类分布 Provider
final categoryBreakdownProvider =
    FutureProvider.family<List<CategoryBreakdown>, String>(
        (ref, ledgerId) async {
  final dashboardState = ref.watch(familyDashboardProvider);
  return dashboardState.data?.categoryBreakdown ?? [];
});

/// 支出趋势 Provider
final spendingTrendProvider =
    FutureProvider.family<List<TrendPoint>, String>((ref, ledgerId) async {
  final dashboardState = ref.watch(familyDashboardProvider);
  return dashboardState.data?.spendingTrend ?? [];
});

/// 预算状态 Provider
final budgetStatusesProvider =
    FutureProvider.family<List<BudgetStatus>, String>((ref, ledgerId) async {
  final dashboardState = ref.watch(familyDashboardProvider);
  return dashboardState.data?.budgetStatuses ?? [];
});

/// 待处理分摊 Provider
final pendingSplitsProvider =
    FutureProvider.family<List<PendingSplit>, String>((ref, ledgerId) async {
  final dashboardState = ref.watch(familyDashboardProvider);
  return dashboardState.data?.pendingSplits ?? [];
});

/// 目标进度 Provider
final goalProgressesProvider =
    FutureProvider.family<List<GoalProgress>, String>((ref, ledgerId) async {
  final dashboardState = ref.watch(familyDashboardProvider);
  return dashboardState.data?.goalProgresses ?? [];
});

/// 最近活动 Provider
final recentActivitiesProvider =
    FutureProvider.family<List<FamilyActivity>, String>((ref, ledgerId) async {
  final dashboardState = ref.watch(familyDashboardProvider);
  return dashboardState.data?.recentActivities ?? [];
});
