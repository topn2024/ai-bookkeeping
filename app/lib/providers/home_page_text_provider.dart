import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/home_page_text_service.dart';

/// 首页文案状态
class HomePageTextState {
  final HomeGreeting greeting;
  final String balanceGrowthText;
  final String streakCelebrationText;
  final String streakEncouragementText;
  final String moneyAgeTrendText;
  final DateTime lastRefreshedAt;
  final int refreshCount;

  const HomePageTextState({
    required this.greeting,
    required this.balanceGrowthText,
    required this.streakCelebrationText,
    required this.streakEncouragementText,
    required this.moneyAgeTrendText,
    required this.lastRefreshedAt,
    this.refreshCount = 0,
  });

  HomePageTextState copyWith({
    HomeGreeting? greeting,
    String? balanceGrowthText,
    String? streakCelebrationText,
    String? streakEncouragementText,
    String? moneyAgeTrendText,
    DateTime? lastRefreshedAt,
    int? refreshCount,
  }) {
    return HomePageTextState(
      greeting: greeting ?? this.greeting,
      balanceGrowthText: balanceGrowthText ?? this.balanceGrowthText,
      streakCelebrationText: streakCelebrationText ?? this.streakCelebrationText,
      streakEncouragementText: streakEncouragementText ?? this.streakEncouragementText,
      moneyAgeTrendText: moneyAgeTrendText ?? this.moneyAgeTrendText,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      refreshCount: refreshCount ?? this.refreshCount,
    );
  }
}

/// 首页文案 Notifier
/// 支持：
/// - 千人千面：基于用户ID生成个性化文案
/// - 定期刷新：每隔一定时间自动更新文案
/// - 手动刷新：下拉刷新等场景
class HomePageTextNotifier extends StateNotifier<HomePageTextState> {
  Timer? _refreshTimer;
  String? _userId;

  // 当前数据上下文（用于生成文案）
  double _currentGrowth = 0;
  int _currentStreakDays = 0;
  int _currentTrendDays = 0;
  String _currentTrend = 'stable';
  int _currentMoneyAgeDays = 0;

  /// 刷新间隔（默认5分钟）
  static const Duration refreshInterval = Duration(minutes: 5);

  HomePageTextNotifier()
      : super(HomePageTextState(
          greeting: HomePageTextService.getTimeGreeting(userId: null),
          balanceGrowthText: HomePageTextService.getNoGrowthDataText(userId: null),
          streakCelebrationText: '',
          streakEncouragementText: '',
          moneyAgeTrendText: '',
          lastRefreshedAt: DateTime.now(),
        )) {
    _startAutoRefresh();
  }

  /// 初始化用户ID（登录后调用）
  void setUserId(String? userId) {
    if (_userId != userId) {
      _userId = userId;
      // 用户变化时刷新所有文案
      _refreshAllTexts();
    }
  }

  /// 更新数据上下文并刷新相关文案
  void updateContext({
    double? growth,
    int? streakDays,
    int? trendDays,
    String? trend,
    int? moneyAgeDays,
  }) {
    bool needsRefresh = false;

    if (growth != null && growth != _currentGrowth) {
      _currentGrowth = growth;
      needsRefresh = true;
    }
    if (streakDays != null && streakDays != _currentStreakDays) {
      _currentStreakDays = streakDays;
      needsRefresh = true;
    }
    if (trendDays != null && trendDays != _currentTrendDays) {
      _currentTrendDays = trendDays;
      needsRefresh = true;
    }
    if (trend != null && trend != _currentTrend) {
      _currentTrend = trend;
      needsRefresh = true;
    }
    if (moneyAgeDays != null && moneyAgeDays != _currentMoneyAgeDays) {
      _currentMoneyAgeDays = moneyAgeDays;
      needsRefresh = true;
    }

    if (needsRefresh) {
      _refreshAllTexts();
    }
  }

  /// 手动刷新所有文案
  void refresh() {
    _refreshAllTexts();
  }

  /// 仅刷新问候语（时间变化时）
  void refreshGreeting() {
    state = state.copyWith(
      greeting: HomePageTextService.getTimeGreeting(userId: _userId),
      lastRefreshedAt: DateTime.now(),
    );
  }

  void _refreshAllTexts() {
    state = HomePageTextState(
      greeting: HomePageTextService.getTimeGreeting(userId: _userId),
      balanceGrowthText: _currentGrowth != 0
          ? HomePageTextService.getBalanceGrowthText(_currentGrowth, userId: _userId)
          : HomePageTextService.getNoGrowthDataText(userId: _userId),
      streakCelebrationText: _currentStreakDays > 0
          ? HomePageTextService.getStreakCelebrationText(_currentStreakDays, userId: _userId)
          : '',
      streakEncouragementText: _currentStreakDays > 0
          ? HomePageTextService.getStreakEncouragementText(_currentStreakDays, userId: _userId)
          : '',
      moneyAgeTrendText: HomePageTextService.getMoneyAgeTrendText(
        _currentTrendDays,
        _currentTrend,
        userId: _userId,
        moneyAgeDays: _currentMoneyAgeDays,
      ),
      lastRefreshedAt: DateTime.now(),
      refreshCount: state.refreshCount + 1,
    );
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      _refreshAllTexts();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// 首页文案 Provider
final homePageTextProvider =
    StateNotifierProvider<HomePageTextNotifier, HomePageTextState>((ref) {
  return HomePageTextNotifier();
});

/// 便捷 Provider：获取当前问候语
final homeGreetingProvider = Provider<HomeGreeting>((ref) {
  return ref.watch(homePageTextProvider).greeting;
});

/// 便捷 Provider：获取结余增长文案
final balanceGrowthTextProvider = Provider<String>((ref) {
  return ref.watch(homePageTextProvider).balanceGrowthText;
});

/// 便捷 Provider：获取连续记账庆祝文案
final streakCelebrationTextProvider = Provider<String>((ref) {
  return ref.watch(homePageTextProvider).streakCelebrationText;
});

/// 便捷 Provider：获取连续记账鼓励文案
final streakEncouragementTextProvider = Provider<String>((ref) {
  return ref.watch(homePageTextProvider).streakEncouragementText;
});

/// 便捷 Provider：获取钱龄趋势文案
final moneyAgeTrendTextProvider = Provider<String>((ref) {
  return ref.watch(homePageTextProvider).moneyAgeTrendText;
});
