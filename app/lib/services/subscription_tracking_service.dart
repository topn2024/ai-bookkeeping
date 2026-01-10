import 'dart:math';

import 'database_service.dart';
import '../models/transaction.dart';

/// 订阅间隔类型
enum SubscriptionInterval {
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly,
  unknown,
}

extension SubscriptionIntervalExtension on SubscriptionInterval {
  String get displayName {
    switch (this) {
      case SubscriptionInterval.weekly:
        return '每周';
      case SubscriptionInterval.biweekly:
        return '每两周';
      case SubscriptionInterval.monthly:
        return '每月';
      case SubscriptionInterval.quarterly:
        return '每季度';
      case SubscriptionInterval.yearly:
        return '每年';
      case SubscriptionInterval.unknown:
        return '不定期';
    }
  }

  int get approximateDays {
    switch (this) {
      case SubscriptionInterval.weekly:
        return 7;
      case SubscriptionInterval.biweekly:
        return 14;
      case SubscriptionInterval.monthly:
        return 30;
      case SubscriptionInterval.quarterly:
        return 90;
      case SubscriptionInterval.yearly:
        return 365;
      case SubscriptionInterval.unknown:
        return 0;
    }
  }
}

/// 订阅使用状态
enum UsageStatus {
  /// 经常使用
  active,

  /// 偶尔使用
  occasional,

  /// 很少使用
  rarelyUsed,

  /// 完全未使用
  unused,
}

extension UsageStatusExtension on UsageStatus {
  String get displayName {
    switch (this) {
      case UsageStatus.active:
        return '经常使用';
      case UsageStatus.occasional:
        return '偶尔使用';
      case UsageStatus.rarelyUsed:
        return '很少使用';
      case UsageStatus.unused:
        return '未使用';
    }
  }

  bool get isWasted => this == UsageStatus.rarelyUsed || this == UsageStatus.unused;
}

/// 订阅模式
class SubscriptionPattern {
  final String merchantName;
  final double amount;
  final SubscriptionInterval interval;
  final double totalSpent;
  final DateTime lastPaymentDate;
  final DateTime? lastUsageDate;
  final UsageStatus usageStatus;
  final int paymentCount;
  final double confidence; // 检测置信度 0-1

  const SubscriptionPattern({
    required this.merchantName,
    required this.amount,
    required this.interval,
    required this.totalSpent,
    required this.lastPaymentDate,
    this.lastUsageDate,
    required this.usageStatus,
    required this.paymentCount,
    this.confidence = 1.0,
  });

  /// 年化花费
  double get yearlyAmount {
    switch (interval) {
      case SubscriptionInterval.weekly:
        return amount * 52;
      case SubscriptionInterval.biweekly:
        return amount * 26;
      case SubscriptionInterval.monthly:
        return amount * 12;
      case SubscriptionInterval.quarterly:
        return amount * 4;
      case SubscriptionInterval.yearly:
        return amount;
      case SubscriptionInterval.unknown:
        return amount * 12; // 假设月付
    }
  }

  /// 月化花费
  double get monthlyAmount => yearlyAmount / 12;

  /// 下次扣款预估日期
  DateTime get nextPaymentEstimate {
    return lastPaymentDate.add(Duration(days: interval.approximateDays));
  }
}

/// 浪费的订阅
class WastedSubscription {
  final SubscriptionPattern subscription;
  final double potentialSavings; // 年度节省
  final String suggestion;

  const WastedSubscription({
    required this.subscription,
    required this.potentialSavings,
    required this.suggestion,
  });
}

/// 订阅统计报告
class SubscriptionReport {
  final List<SubscriptionPattern> subscriptions;
  final double totalMonthly;
  final double totalYearly;
  final List<WastedSubscription> wastedSubscriptions;
  final double potentialSavings;

  const SubscriptionReport({
    required this.subscriptions,
    required this.totalMonthly,
    required this.totalYearly,
    required this.wastedSubscriptions,
    required this.potentialSavings,
  });

  int get totalCount => subscriptions.length;
  int get wastedCount => wastedSubscriptions.length;
  int get activeCount => subscriptions.where((s) => s.usageStatus == UsageStatus.active).length;
}

/// 商家金额组合键
class _MerchantAmountKey {
  final String merchant;
  final double amount;

  _MerchantAmountKey(this.merchant, this.amount);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _MerchantAmountKey &&
        other.merchant == merchant &&
        (other.amount - amount).abs() < 0.01;
  }

  @override
  int get hashCode => merchant.hashCode ^ amount.round().hashCode;
}

/// 订阅追踪服务
///
/// 自动识别周期性订阅消费，检测浪费的订阅，
/// 提供取消建议和年度节省预测
class SubscriptionTrackingService {
  final DatabaseService _db;

  // 常见订阅服务关键词
  static const Set<String> _subscriptionKeywords = {
    '会员', 'VIP', 'vip', '月卡', '年卡', '订阅', 'subscription',
    '爱奇艺', '优酷', '腾讯视频', 'B站', '哔哩哔哩', '芒果TV',
    '网易云音乐', 'QQ音乐', '酷狗', '喜马拉雅', '得到',
    'Netflix', 'Spotify', 'Apple Music', 'YouTube',
    '百度网盘', '阿里云盘', '坚果云', 'Dropbox', 'iCloud',
    'WPS', 'Office', 'Adobe',
    '健身', '游泳', '瑜伽',
    '保险', '话费', '宽带', '水电', '燃气',
  };

  SubscriptionTrackingService(this._db);

  /// 自动识别订阅类消费
  Future<List<SubscriptionPattern>> detectSubscriptions({
    int months = 6,
    String? ledgerId,
  }) async {
    final transactions = await _getRecentTransactions(months, ledgerId);
    final patterns = <SubscriptionPattern>[];

    // 按商家+金额分组
    final grouped = _groupByMerchantAndAmount(transactions);

    for (final entry in grouped.entries) {
      final txList = entry.value;

      // 至少需要2笔交易才能判断周期性
      if (txList.length < 2) continue;

      // 检测周期性
      final interval = _detectInterval(txList);
      if (interval == SubscriptionInterval.unknown && !_isLikelySubscription(entry.key.merchant)) {
        continue;
      }

      // 估算使用状态
      final usageStatus = await _estimateUsageStatus(entry.key.merchant, txList.last.date);

      patterns.add(SubscriptionPattern(
        merchantName: entry.key.merchant,
        amount: entry.key.amount,
        interval: interval,
        totalSpent: txList.fold(0.0, (sum, tx) => sum + tx.amount),
        lastPaymentDate: txList.last.date,
        lastUsageDate: await _detectLastUsage(entry.key.merchant),
        usageStatus: usageStatus,
        paymentCount: txList.length,
        confidence: _calculateConfidence(txList, interval),
      ));
    }

    // 按月度花费排序
    patterns.sort((a, b) => b.monthlyAmount.compareTo(a.monthlyAmount));

    return patterns;
  }

  /// 识别可能浪费的订阅
  Future<List<WastedSubscription>> findWastedSubscriptions({
    int months = 6,
    String? ledgerId,
  }) async {
    final subscriptions = await detectSubscriptions(months: months, ledgerId: ledgerId);

    return subscriptions
        .where((s) => s.usageStatus.isWasted)
        .map((s) => WastedSubscription(
              subscription: s,
              potentialSavings: s.yearlyAmount,
              suggestion: _generateCancelSuggestion(s),
            ))
        .toList();
  }

  /// 生成订阅报告
  Future<SubscriptionReport> generateReport({
    int months = 6,
    String? ledgerId,
  }) async {
    final subscriptions = await detectSubscriptions(months: months, ledgerId: ledgerId);
    final wasted = await findWastedSubscriptions(months: months, ledgerId: ledgerId);

    final totalMonthly = subscriptions.fold(0.0, (sum, s) => sum + s.monthlyAmount);
    final totalYearly = subscriptions.fold(0.0, (sum, s) => sum + s.yearlyAmount);
    final potentialSavings = wasted.fold(0.0, (sum, w) => sum + w.potentialSavings);

    return SubscriptionReport(
      subscriptions: subscriptions,
      totalMonthly: totalMonthly,
      totalYearly: totalYearly,
      wastedSubscriptions: wasted,
      potentialSavings: potentialSavings,
    );
  }

  /// 标记订阅为必要（用户反馈）
  Future<void> markAsNeeded(String merchantName) async {
    await _db.rawInsert('''
      INSERT OR REPLACE INTO subscription_feedback (merchant, needed, updated_at)
      VALUES (?, 1, ?)
    ''', [merchantName, DateTime.now().millisecondsSinceEpoch]);
  }

  /// 标记订阅为不需要
  Future<void> markAsUnneeded(String merchantName) async {
    await _db.rawInsert('''
      INSERT OR REPLACE INTO subscription_feedback (merchant, needed, updated_at)
      VALUES (?, 0, ?)
    ''', [merchantName, DateTime.now().millisecondsSinceEpoch]);
  }

  /// 获取即将到期的订阅（提醒用户考虑是否续费）
  Future<List<SubscriptionPattern>> getUpcomingRenewals({
    int daysAhead = 7,
    String? ledgerId,
  }) async {
    final subscriptions = await detectSubscriptions(ledgerId: ledgerId);
    final now = DateTime.now();
    final deadline = now.add(Duration(days: daysAhead));

    return subscriptions
        .where((s) =>
            s.nextPaymentEstimate.isAfter(now) &&
            s.nextPaymentEstimate.isBefore(deadline))
        .toList();
  }

  // ==================== Private Methods ====================

  Future<List<Transaction>> _getRecentTransactions(int months, String? ledgerId) async {
    final since = DateTime.now().subtract(Duration(days: months * 30));
    final now = DateTime.now();
    final allTransactions = await _db.getTransactions();

    // 过滤日期范围和支出类型
    return allTransactions
        .where((tx) =>
            tx.type == TransactionType.expense &&
            tx.date.isAfter(since) &&
            tx.date.isBefore(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Map<_MerchantAmountKey, List<Transaction>> _groupByMerchantAndAmount(
    List<Transaction> transactions,
  ) {
    final grouped = <_MerchantAmountKey, List<Transaction>>{};

    for (final tx in transactions) {
      final desc = tx.description;
      final merchant = (desc != null && desc.isNotEmpty) ? desc : tx.categoryName;
      final key = _MerchantAmountKey(merchant, tx.amount);

      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return grouped;
  }

  SubscriptionInterval _detectInterval(List<Transaction> transactions) {
    if (transactions.length < 2) return SubscriptionInterval.unknown;

    // 计算平均间隔
    final intervals = <int>[];
    for (int i = 1; i < transactions.length; i++) {
      final days = transactions[i].date.difference(transactions[i - 1].date).inDays;
      if (days > 0) intervals.add(days);
    }

    if (intervals.isEmpty) return SubscriptionInterval.unknown;

    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;

    // 计算标准差，判断是否稳定
    final variance = intervals
        .map((d) => pow(d - avgInterval, 2))
        .reduce((a, b) => a + b) / intervals.length;
    final stdDev = sqrt(variance);

    // 标准差过大说明不是稳定订阅
    if (stdDev > avgInterval * 0.3) return SubscriptionInterval.unknown;

    // 根据平均间隔判断周期
    if (avgInterval <= 10) return SubscriptionInterval.weekly;
    if (avgInterval <= 20) return SubscriptionInterval.biweekly;
    if (avgInterval <= 45) return SubscriptionInterval.monthly;
    if (avgInterval <= 120) return SubscriptionInterval.quarterly;
    if (avgInterval <= 400) return SubscriptionInterval.yearly;

    return SubscriptionInterval.unknown;
  }

  bool _isLikelySubscription(String merchant) {
    final lowerMerchant = merchant.toLowerCase();
    return _subscriptionKeywords.any((keyword) =>
        lowerMerchant.contains(keyword.toLowerCase()));
  }

  Future<UsageStatus> _estimateUsageStatus(String merchant, DateTime lastPayment) async {
    // 简化版：根据商家类型和最后支付时间估算
    // 实际应用中可以接入应用使用时长API或用户手动标记

    final daysSincePayment = DateTime.now().difference(lastPayment).inDays;

    // 检查用户反馈
    final feedback = await _db.rawQuery('''
      SELECT needed FROM subscription_feedback WHERE merchant = ?
    ''', [merchant]);

    if (feedback.isNotEmpty) {
      final needed = feedback.first['needed'] as int?;
      if (needed == 1) return UsageStatus.active;
      if (needed == 0) return UsageStatus.unused;
    }

    // 基于时间估算
    if (daysSincePayment <= 7) return UsageStatus.active;
    if (daysSincePayment <= 30) return UsageStatus.occasional;
    if (daysSincePayment <= 90) return UsageStatus.rarelyUsed;

    return UsageStatus.unused;
  }

  Future<DateTime?> _detectLastUsage(String merchant) async {
    // 实际应用中可以通过应用使用时长API获取
    // 这里返回null表示无法检测
    return null;
  }

  double _calculateConfidence(List<Transaction> transactions, SubscriptionInterval interval) {
    if (transactions.length < 2) return 0.0;
    if (interval == SubscriptionInterval.unknown) return 0.3;

    // 交易次数越多，置信度越高
    final countFactor = min(1.0, transactions.length / 6);

    // 金额稳定性
    final amounts = transactions.map((t) => t.amount).toList();
    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    final amountVariance = amounts
        .map((a) => pow(a - avgAmount, 2))
        .reduce((a, b) => a + b) / amounts.length;
    final amountStability = 1.0 / (1.0 + sqrt(amountVariance) / avgAmount);

    return countFactor * 0.5 + amountStability * 0.5;
  }

  String _generateCancelSuggestion(SubscriptionPattern subscription) {
    final monthlyStr = subscription.monthlyAmount.toStringAsFixed(0);
    final yearlyStr = subscription.yearlyAmount.toStringAsFixed(0);

    switch (subscription.usageStatus) {
      case UsageStatus.unused:
        return '您似乎从未使用过${subscription.merchantName}，'
            '取消后每年可节省¥$yearlyStr';
      case UsageStatus.rarelyUsed:
        return '${subscription.merchantName}使用频率很低，'
            '每月花费¥$monthlyStr，建议考虑取消';
      default:
        return '建议评估${subscription.merchantName}的使用价值';
    }
  }
}
