import 'dart:math';

import 'database_service.dart';
import '../models/transaction.dart';

/// 拿铁因子（高频小额消费）
class LatteFactor {
  final String category;
  final String description;
  final double weeklyFrequency;
  final double averageAmount;
  final double monthlyTotal;
  final double yearlyTotal;
  final double potentialSavings;
  final List<Transaction> transactions;
  final String? topMerchant;

  const LatteFactor({
    required this.category,
    required this.description,
    required this.weeklyFrequency,
    required this.averageAmount,
    required this.monthlyTotal,
    required this.yearlyTotal,
    required this.potentialSavings,
    required this.transactions,
    this.topMerchant,
  });

  /// 如果减少到每周N次，能节省多少
  double savingsIfReduceTo(double targetWeeklyFrequency) {
    if (targetWeeklyFrequency >= weeklyFrequency) return 0;
    final reduction = (weeklyFrequency - targetWeeklyFrequency) / weeklyFrequency;
    return yearlyTotal * reduction;
  }
}

/// 拿铁因子分析报告
class LatteFactorReport {
  final List<LatteFactor> factors;
  final double totalMonthlyImpact;
  final double totalYearlyImpact;
  final String topSuggestion;
  final double potentialYearlySavings;

  const LatteFactorReport({
    required this.factors,
    required this.totalMonthlyImpact,
    required this.totalYearlyImpact,
    required this.topSuggestion,
    required this.potentialYearlySavings,
  });

  bool get hasSignificantFactors => factors.isNotEmpty;
  int get factorCount => factors.length;
}

/// 消费聚类
class _ExpenseCluster {
  final String category;
  final String commonDescription;
  final List<Transaction> transactions;
  final double totalAmount;
  final double averageAmount;

  _ExpenseCluster({
    required this.category,
    required this.commonDescription,
    required this.transactions,
  })  : totalAmount = transactions.fold(0.0, (sum, tx) => sum + tx.amount),
        averageAmount = transactions.isEmpty
            ? 0
            : transactions.fold(0.0, (sum, tx) => sum + tx.amount) /
                transactions.length;
}

/// 高频小额消费分析服务（拿铁因子分析）
///
/// "拿铁因子"概念来源于《拿铁因子》一书，指那些看似微小
/// 但长期累积会造成巨大财务影响的日常小额消费。
///
/// 服务功能：
/// - 识别高频（每周≥2次）小额（<50元）消费
/// - 计算年度累积影响
/// - 提供减少建议和潜在节省预测
class LatteFactorAnalyzer {
  final DatabaseService _db;

  /// 小额消费阈值（默认50元）
  final double smallExpenseThreshold;

  /// 高频消费阈值（每周次数）
  final double weeklyFrequencyThreshold;

  /// 分析时间范围（月）
  final int analysisMonths;

  LatteFactorAnalyzer(
    this._db, {
    this.smallExpenseThreshold = 50,
    this.weeklyFrequencyThreshold = 2,
    this.analysisMonths = 3,
  });

  /// 分析拿铁因子
  Future<LatteFactorReport> analyzeLatteFactors({
    String? ledgerId,
    double? customThreshold,
    int? months,
  }) async {
    final threshold = customThreshold ?? smallExpenseThreshold;
    final period = months ?? analysisMonths;

    final transactions = await _getSmallExpenses(threshold, period, ledgerId);
    if (transactions.isEmpty) {
      return const LatteFactorReport(
        factors: [],
        totalMonthlyImpact: 0,
        totalYearlyImpact: 0,
        topSuggestion: '您的小额消费控制得很好！',
        potentialYearlySavings: 0,
      );
    }

    // 按描述/商家聚类
    final clusters = _clusterByPattern(transactions);

    // 计算每周频率并筛选高频消费
    final weeksInPeriod = period * 4.3; // 约4.3周/月
    final latteFactors = <LatteFactor>[];

    for (final cluster in clusters) {
      final weeklyFrequency = cluster.transactions.length / weeksInPeriod;

      if (weeklyFrequency >= weeklyFrequencyThreshold) {
        final monthlyTotal = cluster.totalAmount / period;
        final yearlyTotal = monthlyTotal * 12;

        latteFactors.add(LatteFactor(
          category: cluster.category,
          description: cluster.commonDescription,
          weeklyFrequency: weeklyFrequency,
          averageAmount: cluster.averageAmount,
          monthlyTotal: monthlyTotal,
          yearlyTotal: yearlyTotal,
          potentialSavings: yearlyTotal * 0.5, // 假设减少一半
          transactions: cluster.transactions,
          topMerchant: _findTopMerchant(cluster.transactions),
        ));
      }
    }

    // 按年度总额排序
    latteFactors.sort((a, b) => b.yearlyTotal.compareTo(a.yearlyTotal));

    final totalMonthly = latteFactors.fold(0.0, (sum, f) => sum + f.monthlyTotal);
    final totalYearly = latteFactors.fold(0.0, (sum, f) => sum + f.yearlyTotal);
    final potentialSavings = latteFactors.fold(0.0, (sum, f) => sum + f.potentialSavings);

    return LatteFactorReport(
      factors: latteFactors,
      totalMonthlyImpact: totalMonthly,
      totalYearlyImpact: totalYearly,
      topSuggestion: _generateTopSuggestion(latteFactors),
      potentialYearlySavings: potentialSavings,
    );
  }

  /// 获取单个类别的详细分析
  Future<LatteFactor?> analyzeCategoryDetail({
    required String category,
    String? ledgerId,
    int? months,
  }) async {
    final period = months ?? analysisMonths;
    final since = DateTime.now().subtract(Duration(days: period * 30));

    final transactions = await _db.getTransactions(
      startDate: since,
      endDate: DateTime.now(),
      categoryId: category,
      ledgerId: ledgerId,
    );

    final expenses = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .toList();

    if (expenses.isEmpty) return null;

    final totalAmount = expenses.fold(0.0, (sum, tx) => sum + tx.amount);
    final avgAmount = totalAmount / expenses.length;
    final weeksInPeriod = period * 4.3;
    final weeklyFrequency = expenses.length / weeksInPeriod;
    final monthlyTotal = totalAmount / period;
    final yearlyTotal = monthlyTotal * 12;

    return LatteFactor(
      category: category,
      description: expenses.first.categoryName,
      weeklyFrequency: weeklyFrequency,
      averageAmount: avgAmount,
      monthlyTotal: monthlyTotal,
      yearlyTotal: yearlyTotal,
      potentialSavings: yearlyTotal * 0.5,
      transactions: expenses,
      topMerchant: _findTopMerchant(expenses),
    );
  }

  /// 计算如果用户减少某类消费能节省多少
  Future<Map<String, double>> calculateSavingsScenarios({
    required LatteFactor factor,
  }) async {
    return {
      '减少25%': factor.yearlyTotal * 0.25,
      '减少50%': factor.yearlyTotal * 0.5,
      '每周减少1次': factor.averageAmount * 52,
      '每周减少2次': factor.averageAmount * 104,
      '完全停止': factor.yearlyTotal,
    };
  }

  /// 获取同类用户对比数据（模拟）
  Future<Map<String, dynamic>> getPeerComparison({
    required LatteFactorReport report,
  }) async {
    // 实际应用中应从服务器获取匿名统计数据
    // 这里返回模拟数据
    return {
      'userMonthlyAvg': report.totalMonthlyImpact,
      'peerMonthlyAvg': report.totalMonthlyImpact * 0.8, // 模拟同类用户平均值
      'percentile': min(100, (report.totalMonthlyImpact / 1000 * 100).round()),
      'betterThanPeers': report.totalMonthlyImpact < report.totalMonthlyImpact * 0.8,
    };
  }

  // ==================== Private Methods ====================

  Future<List<Transaction>> _getSmallExpenses(
    double threshold,
    int months,
    String? ledgerId,
  ) async {
    final since = DateTime.now().subtract(Duration(days: months * 30));

    final transactions = await _db.getTransactions(
      startDate: since,
      endDate: DateTime.now(),
      ledgerId: ledgerId,
    );

    return transactions
        .where((tx) =>
            tx.type == TransactionType.expense &&
            tx.amount < threshold &&
            tx.amount > 0)
        .toList();
  }

  List<_ExpenseCluster> _clusterByPattern(List<Transaction> transactions) {
    // 按类别+描述模式分组
    final grouped = <String, List<Transaction>>{};

    for (final tx in transactions) {
      // 生成聚类键：类别 + 简化的描述
      final key = '${tx.categoryId}:${_simplifyDescription(tx.description)}';
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return grouped.entries.map((entry) {
      final txList = entry.value;
      final firstTx = txList.first;

      return _ExpenseCluster(
        category: firstTx.categoryId,
        commonDescription: _findCommonDescription(txList),
        transactions: txList,
      );
    }).toList();
  }

  String _simplifyDescription(String description) {
    // 移除数字和特殊字符，保留主要关键词
    return description
        .replaceAll(RegExp(r'[0-9]'), '')
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z]'), '')
        .trim();
  }

  String _findCommonDescription(List<Transaction> transactions) {
    if (transactions.isEmpty) return '';
    if (transactions.length == 1) return transactions.first.description;

    // 找出最常见的描述词
    final descCounts = <String, int>{};
    for (final tx in transactions) {
      final simplified = _simplifyDescription(tx.description);
      if (simplified.isNotEmpty) {
        descCounts[simplified] = (descCounts[simplified] ?? 0) + 1;
      }
    }

    if (descCounts.isEmpty) return transactions.first.categoryName;

    final sorted = descCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key.isNotEmpty
        ? sorted.first.key
        : transactions.first.categoryName;
  }

  String? _findTopMerchant(List<Transaction> transactions) {
    final merchantCounts = <String, int>{};

    for (final tx in transactions) {
      if (tx.description.isNotEmpty) {
        merchantCounts[tx.description] =
            (merchantCounts[tx.description] ?? 0) + 1;
      }
    }

    if (merchantCounts.isEmpty) return null;

    final sorted = merchantCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  String _generateTopSuggestion(List<LatteFactor> factors) {
    if (factors.isEmpty) return '您的小额消费控制得很好！';

    final top = factors.first;
    final weeklyTimes = top.weeklyFrequency.round();
    final reducedTimes = max(1, (weeklyTimes / 2).ceil());
    final potentialSavings = top.savingsIfReduceTo(reducedTimes.toDouble());

    if (weeklyTimes <= 2) {
      return '${top.description}每周约$weeklyTimes次，'
          '年度累计¥${top.yearlyTotal.toStringAsFixed(0)}';
    }

    return '如果将${top.description}从每周$weeklyTimes次减少到$reducedTimes次，'
        '每年可以多存 ¥${potentialSavings.toStringAsFixed(0)}';
  }
}
