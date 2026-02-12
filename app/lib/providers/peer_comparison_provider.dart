import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/social_comparison_service.dart';
import '../services/database_service.dart';

/// SocialComparisonService Provider
final socialComparisonServiceProvider = Provider<SocialComparisonService>((ref) {
  return SocialComparisonService(DatabaseService());
});

/// 同类用户对比数据状态
class PeerComparisonState {
  final bool isLoading;
  final String? error;
  final UserProfileTag? userProfile;
  final PeerBenchmark? benchmark;
  final List<UserRanking> rankings;
  final List<ComparisonInsight> insights;
  final SpendingLevel? spendingLevel;
  final Map<String, double>? categoryExpenses;
  final double? totalExpense;
  final double? totalIncome;
  final double? savingsRate;
  final double? moneyAge;
  final int? recordingDays;

  const PeerComparisonState({
    this.isLoading = true,
    this.error,
    this.userProfile,
    this.benchmark,
    this.rankings = const [],
    this.insights = const [],
    this.spendingLevel,
    this.categoryExpenses,
    this.totalExpense,
    this.totalIncome,
    this.savingsRate,
    this.moneyAge,
    this.recordingDays,
  });

  PeerComparisonState copyWith({
    bool? isLoading,
    String? error,
    UserProfileTag? userProfile,
    PeerBenchmark? benchmark,
    List<UserRanking>? rankings,
    List<ComparisonInsight>? insights,
    SpendingLevel? spendingLevel,
    Map<String, double>? categoryExpenses,
    double? totalExpense,
    double? totalIncome,
    double? savingsRate,
    double? moneyAge,
    int? recordingDays,
  }) {
    return PeerComparisonState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userProfile: userProfile ?? this.userProfile,
      benchmark: benchmark ?? this.benchmark,
      rankings: rankings ?? this.rankings,
      insights: insights ?? this.insights,
      spendingLevel: spendingLevel ?? this.spendingLevel,
      categoryExpenses: categoryExpenses ?? this.categoryExpenses,
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
      savingsRate: savingsRate ?? this.savingsRate,
      moneyAge: moneyAge ?? this.moneyAge,
      recordingDays: recordingDays ?? this.recordingDays,
    );
  }
}

/// 同类用户对比 Notifier
class PeerComparisonNotifier extends StateNotifier<PeerComparisonState> {
  final SocialComparisonService _service;
  final DatabaseService _db;

  PeerComparisonNotifier(this._service, this._db) : super(const PeerComparisonState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('[PeerComparison] 开始加载数据...');

      final userProfile = await _service.inferUserProfile();
      debugPrint('[PeerComparison] 用户画像: $userProfile');

      final benchmark = await _service.getPeerBenchmark();
      debugPrint('[PeerComparison] 基准数据: ${benchmark != null}');

      final rankings = await _service.getUserRankings();
      debugPrint('[PeerComparison] 排名: ${rankings.length}条');

      final insights = await _service.getComparisonInsights();
      debugPrint('[PeerComparison] 洞察: ${insights.length}条');

      final spendingLevel = await _service.getSpendingLevel();
      debugPrint('[PeerComparison] 消费水平: $spendingLevel');

      final monthlyStats = await _getMonthlyStats();
      debugPrint('[PeerComparison] 月度统计: $monthlyStats');

      state = state.copyWith(
        isLoading: false,
        userProfile: userProfile,
        benchmark: benchmark,
        rankings: rankings,
        insights: insights,
        spendingLevel: spendingLevel,
        totalExpense: (monthlyStats['totalExpense'] as num?)?.toDouble(),
        totalIncome: (monthlyStats['totalIncome'] as num?)?.toDouble(),
        savingsRate: (monthlyStats['savingsRate'] as num?)?.toDouble(),
        moneyAge: (monthlyStats['avgMoneyAge'] as num?)?.toDouble(),
        recordingDays: (monthlyStats['recordingDays'] as num?)?.toInt(),
        categoryExpenses: monthlyStats['categoryExpenses'] as Map<String, double>?,
      );
      debugPrint('[PeerComparison] 数据加载完成');
    } catch (e, stack) {
      debugPrint('[PeerComparison] 加载数据失败: $e');
      debugPrint('[PeerComparison] 堆栈: $stack');
      state = state.copyWith(
        isLoading: false,
        error: '加载数据失败: $e',
      );
    }
  }

  /// 获取本月统计数据
  Future<Map<String, dynamic>> _getMonthlyStats() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final db = await _db.database;

    // 获取本月支出
    final expenseResult = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE date >= ? AND date <= ? AND type = 1 AND isDeleted = 0
    ''', [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch]);
    final totalExpense = (expenseResult.first['total'] as num?)?.toDouble() ?? 0;

    // 获取本月收入
    final incomeResult = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE date >= ? AND date <= ? AND type = 0 AND isDeleted = 0
    ''', [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch]);
    final totalIncome = (incomeResult.first['total'] as num?)?.toDouble() ?? 0;

    // 获取各分类支出
    final categoryResult = await db.rawQuery('''
      SELECT category, SUM(amount) as total FROM transactions
      WHERE date >= ? AND date <= ? AND type = 1 AND isDeleted = 0
      GROUP BY category
    ''', [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch]);

    final categoryExpenses = <String, double>{};
    for (final row in categoryResult) {
      final category = row['category'] as String?;
      final amount = (row['total'] as num?)?.toDouble() ?? 0;
      if (category != null) {
        categoryExpenses[category] = amount;
      }
    }

    // 获取平均钱龄
    final moneyAgeResult = await db.rawQuery('''
      SELECT AVG(moneyAge) as avg FROM transactions
      WHERE date >= ? AND date <= ? AND type = 1 AND moneyAge > 0 AND isDeleted = 0
    ''', [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch]);
    final avgMoneyAge = (moneyAgeResult.first['avg'] as num?)?.toDouble() ?? 0;

    // 获取本月记账天数
    final recordingDaysResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT date(date/1000, 'unixepoch')) as days
      FROM transactions
      WHERE date >= ? AND date <= ? AND isDeleted = 0
    ''', [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch]);
    final recordingDays = (recordingDaysResult.first['days'] as num?)?.toInt() ?? 0;

    // 计算储蓄率
    final savingsRate = totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome : 0.0;

    return {
      'totalExpense': totalExpense,
      'totalIncome': totalIncome,
      'savingsRate': savingsRate.clamp(0.0, 1.0),
      'avgMoneyAge': avgMoneyAge,
      'recordingDays': recordingDays,
      'categoryExpenses': categoryExpenses,
    };
  }

  Future<void> refresh() async {
    await loadData();
  }
}

/// 同类用户对比 Provider
final peerComparisonProvider =
    StateNotifierProvider<PeerComparisonNotifier, PeerComparisonState>((ref) {
  final service = ref.watch(socialComparisonServiceProvider);
  return PeerComparisonNotifier(service, DatabaseService());
});
