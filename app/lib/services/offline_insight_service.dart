import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

/// 离线洞察预生成服务
///
/// 在用户使用应用期间或后台，预先生成常用洞察内容
/// 确保离线时也能展示有意义的分析结果
class OfflineInsightService {
  static final OfflineInsightService _instance = OfflineInsightService._internal();
  factory OfflineInsightService() => _instance;
  OfflineInsightService._internal();

  /// 通过服务定位器获取数据库服务
  IDatabaseService get _db => sl<IDatabaseService>();
  Timer? _generateTimer;
  bool _isGenerating = false;

  /// 预生成洞察的缓存键
  static const String _insightCacheKey = 'offline_insights_cache';
  static const String _insightTimestampKey = 'offline_insights_timestamp';

  /// 洞察类型
  static const List<String> _insightTypes = [
    'spending_summary',      // 消费概览
    'category_analysis',     // 分类分析
    'trend_insight',         // 趋势洞察
    'budget_status',         // 预算状态
    'money_age_insight',     // 钱龄洞察
    'saving_opportunity',    // 省钱机会
    'weekly_comparison',     // 周对比
    'monthly_comparison',    // 月对比
  ];

  /// 初始化服务
  Future<void> initialize() async {
    // 检查是否需要更新洞察
    final needsUpdate = await _checkNeedsUpdate();
    if (needsUpdate) {
      await generateAllInsights();
    }

    // 设置定期更新（每小时检查一次）
    _generateTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _checkAndUpdate(),
    );
  }

  /// 检查是否需要更新
  Future<bool> _checkNeedsUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_insightTimestampKey);

      if (lastUpdate == null) return true;

      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final now = DateTime.now();

      // 超过6小时需要更新
      return now.difference(lastUpdateTime).inHours >= 6;
    } catch (e) {
      return true;
    }
  }

  /// 检查并更新
  Future<void> _checkAndUpdate() async {
    if (_isGenerating) return;

    final needsUpdate = await _checkNeedsUpdate();
    if (needsUpdate) {
      await generateAllInsights();
    }
  }

  /// 生成所有洞察
  Future<void> generateAllInsights() async {
    if (_isGenerating) return;
    _isGenerating = true;

    debugPrint('Starting offline insight generation...');

    try {
      final insights = <String, OfflineInsight>{};

      for (final type in _insightTypes) {
        final insight = await _generateInsight(type);
        if (insight != null) {
          insights[type] = insight;
        }
      }

      // 保存到本地
      await _saveInsights(insights);

      debugPrint('Offline insights generated: ${insights.length} items');
    } catch (e) {
      debugPrint('Failed to generate offline insights: $e');
    } finally {
      _isGenerating = false;
    }
  }

  /// 生成单个洞察
  Future<OfflineInsight?> _generateInsight(String type) async {
    try {
      switch (type) {
        case 'spending_summary':
          return await _generateSpendingSummary();
        case 'category_analysis':
          return await _generateCategoryAnalysis();
        case 'trend_insight':
          return await _generateTrendInsight();
        case 'budget_status':
          return await _generateBudgetStatus();
        case 'money_age_insight':
          return await _generateMoneyAgeInsight();
        case 'saving_opportunity':
          return await _generateSavingOpportunity();
        case 'weekly_comparison':
          return await _generateWeeklyComparison();
        case 'monthly_comparison':
          return await _generateMonthlyComparison();
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Failed to generate insight $type: $e');
      return null;
    }
  }

  /// 生成消费概览洞察
  Future<OfflineInsight> _generateSpendingSummary() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final db = await _db.database;

    // 本月支出总额
    final result = await db.rawQuery('''
      SELECT SUM(ABS(amount)) as total
      FROM transactions
      WHERE amount < 0 AND date >= ?
    ''', [startOfMonth.millisecondsSinceEpoch]);

    final totalSpending = (result.first['total'] as num?)?.toDouble() ?? 0;

    // 日均支出
    final daysInMonth = now.day;
    final dailyAvg = daysInMonth > 0 ? totalSpending / daysInMonth : 0;

    return OfflineInsight(
      type: 'spending_summary',
      title: '本月消费概览',
      content: '本月已支出 ¥${totalSpending.toStringAsFixed(2)}，日均 ¥${dailyAvg.toStringAsFixed(2)}',
      data: {
        'totalSpending': totalSpending,
        'dailyAvg': dailyAvg,
        'daysInMonth': daysInMonth,
      },
      generatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
    );
  }

  /// 生成分类分析洞察
  Future<OfflineInsight> _generateCategoryAnalysis() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final db = await _db.database;

    // 按分类统计支出
    final result = await db.rawQuery('''
      SELECT c.name, SUM(ABS(t.amount)) as total
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.amount < 0 AND t.date >= ?
      GROUP BY t.category_id
      ORDER BY total DESC
      LIMIT 5
    ''', [startOfMonth.millisecondsSinceEpoch]);

    final categories = result.map((r) => {
      'name': r['name'] ?? '未分类',
      'amount': r['total'],
    }).toList();

    String topCategory = '未分类';
    double topAmount = 0;
    if (categories.isNotEmpty) {
      topCategory = categories.first['name'] as String;
      topAmount = (categories.first['amount'] as num).toDouble();
    }

    return OfflineInsight(
      type: 'category_analysis',
      title: '消费结构分析',
      content: '本月「$topCategory」支出最多，共 ¥${topAmount.toStringAsFixed(2)}',
      data: {
        'categories': categories,
        'topCategory': topCategory,
        'topAmount': topAmount,
      },
      generatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
    );
  }

  /// 生成趋势洞察
  Future<OfflineInsight> _generateTrendInsight() async {
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final db = await _db.database;

    // 本周支出
    final thisWeekResult = await db.rawQuery('''
      SELECT SUM(ABS(amount)) as total
      FROM transactions
      WHERE amount < 0 AND date >= ?
    ''', [thisWeekStart.millisecondsSinceEpoch]);

    // 上周支出
    final lastWeekResult = await db.rawQuery('''
      SELECT SUM(ABS(amount)) as total
      FROM transactions
      WHERE amount < 0 AND date >= ? AND date < ?
    ''', [lastWeekStart.millisecondsSinceEpoch, thisWeekStart.millisecondsSinceEpoch]);

    final thisWeekTotal = (thisWeekResult.first['total'] as num?)?.toDouble() ?? 0;
    final lastWeekTotal = (lastWeekResult.first['total'] as num?)?.toDouble() ?? 0;

    final change = lastWeekTotal > 0
        ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal * 100)
        : 0;

    String trend;
    if (change > 10) {
      trend = '上升';
    } else if (change < -10) {
      trend = '下降';
    } else {
      trend = '持平';
    }

    return OfflineInsight(
      type: 'trend_insight',
      title: '消费趋势',
      content: '本周消费较上周$trend ${change.abs().toStringAsFixed(1)}%',
      data: {
        'thisWeekTotal': thisWeekTotal,
        'lastWeekTotal': lastWeekTotal,
        'changePercent': change,
        'trend': trend,
      },
      generatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
    );
  }

  /// 生成预算状态洞察
  Future<OfflineInsight> _generateBudgetStatus() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final db = await _db.database;

    // 获取当月预算
    final budgetResult = await db.rawQuery('''
      SELECT SUM(amount) as total FROM budgets
      WHERE year = ? AND month = ?
    ''', [now.year, now.month]);

    // 获取当月支出
    final spentResult = await db.rawQuery('''
      SELECT SUM(ABS(amount)) as total
      FROM transactions
      WHERE amount < 0 AND date >= ?
    ''', [startOfMonth.millisecondsSinceEpoch]);

    final budgetTotal = (budgetResult.first['total'] as num?)?.toDouble() ?? 0;
    final spentTotal = (spentResult.first['total'] as num?)?.toDouble() ?? 0;

    final remaining = budgetTotal - spentTotal;
    final usagePercent = budgetTotal > 0 ? (spentTotal / budgetTotal * 100) : 0;

    // 计算日均可用
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day;
    final dailyBudget = daysLeft > 0 ? remaining / daysLeft : 0;

    String status;
    if (usagePercent > 100) {
      status = '已超支';
    } else if (usagePercent > 80) {
      status = '接近预算上限';
    } else {
      status = '预算充足';
    }

    return OfflineInsight(
      type: 'budget_status',
      title: '预算执行情况',
      content: '$status，剩余 ¥${remaining.toStringAsFixed(2)}，日均可用 ¥${dailyBudget.toStringAsFixed(2)}',
      data: {
        'budgetTotal': budgetTotal,
        'spentTotal': spentTotal,
        'remaining': remaining,
        'usagePercent': usagePercent,
        'dailyBudget': dailyBudget,
        'daysLeft': daysLeft,
        'status': status,
      },
      generatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 3)),
    );
  }

  /// 生成钱龄洞察
  Future<OfflineInsight> _generateMoneyAgeInsight() async {
    final db = await _db.database;

    // 获取账户余额和钱龄数据
    final result = await db.rawQuery('''
      SELECT
        a.name,
        a.balance,
        COALESCE(ma.avg_age_days, 0) as avg_age
      FROM accounts a
      LEFT JOIN money_age ma ON a.id = ma.account_id
      WHERE a.balance > 0
      ORDER BY ma.avg_age_days DESC
      LIMIT 3
    ''');

    if (result.isEmpty) {
      return OfflineInsight(
        type: 'money_age_insight',
        title: '钱龄分析',
        content: '暂无钱龄数据',
        data: {},
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
      );
    }

    // 计算总体平均钱龄
    double totalBalance = 0;
    double weightedAge = 0;
    for (final row in result) {
      final balance = (row['balance'] as num).toDouble();
      final age = (row['avg_age'] as num).toDouble();
      totalBalance += balance;
      weightedAge += balance * age;
    }
    final avgAge = totalBalance > 0 ? weightedAge / totalBalance : 0;

    String healthStatus;
    if (avgAge > 60) {
      healthStatus = '非常健康';
    } else if (avgAge > 30) {
      healthStatus = '较为健康';
    } else if (avgAge > 14) {
      healthStatus = '一般';
    } else {
      healthStatus = '需要关注';
    }

    return OfflineInsight(
      type: 'money_age_insight',
      title: '钱龄健康度',
      content: '平均钱龄 ${avgAge.toStringAsFixed(1)} 天，财务状况$healthStatus',
      data: {
        'avgAge': avgAge,
        'healthStatus': healthStatus,
        'accounts': result,
      },
      generatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
    );
  }

  /// 生成省钱机会洞察
  Future<OfflineInsight> _generateSavingOpportunity() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final db = await _db.database;

    // 找出消费增长最快的分类
    final result = await db.rawQuery('''
      WITH this_month AS (
        SELECT category_id, SUM(ABS(amount)) as total
        FROM transactions
        WHERE amount < 0 AND date >= ?
        GROUP BY category_id
      ),
      last_month AS (
        SELECT category_id, SUM(ABS(amount)) as total
        FROM transactions
        WHERE amount < 0 AND date >= ? AND date < ?
        GROUP BY category_id
      )
      SELECT
        c.name,
        COALESCE(tm.total, 0) as this_month,
        COALESCE(lm.total, 0) as last_month,
        COALESCE(tm.total, 0) - COALESCE(lm.total, 0) as diff
      FROM categories c
      LEFT JOIN this_month tm ON c.id = tm.category_id
      LEFT JOIN last_month lm ON c.id = lm.category_id
      WHERE tm.total > 0 OR lm.total > 0
      ORDER BY diff DESC
      LIMIT 1
    ''', [startOfMonth.millisecondsSinceEpoch, lastMonthStart.millisecondsSinceEpoch, startOfMonth.millisecondsSinceEpoch]);

    if (result.isEmpty) {
      return OfflineInsight(
        type: 'saving_opportunity',
        title: '省钱机会',
        content: '数据不足，无法分析省钱机会',
        data: {},
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );
    }

    final category = result.first['name'] as String? ?? '未分类';
    final diff = (result.first['diff'] as num).toDouble();

    if (diff > 0) {
      return OfflineInsight(
        type: 'saving_opportunity',
        title: '省钱机会',
        content: '「$category」本月比上月多花了 ¥${diff.toStringAsFixed(2)}，可以关注一下',
        data: {
          'category': category,
          'diff': diff,
          'suggestion': '减少该分类支出',
        },
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );
    } else {
      return OfflineInsight(
        type: 'saving_opportunity',
        title: '省钱成果',
        content: '「$category」本月比上月少花了 ¥${diff.abs().toStringAsFixed(2)}，继续保持！',
        data: {
          'category': category,
          'diff': diff,
          'suggestion': '继续保持',
        },
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );
    }
  }

  /// 生成周对比洞察
  Future<OfflineInsight> _generateWeeklyComparison() async {
    // 简化实现，实际需要更详细的周度数据对比
    return OfflineInsight(
      type: 'weekly_comparison',
      title: '本周回顾',
      content: '本周消费数据正在统计中...',
      data: {},
      generatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
    );
  }

  /// 生成月对比洞察
  Future<OfflineInsight> _generateMonthlyComparison() async {
    // 简化实现，实际需要更详细的月度数据对比
    return OfflineInsight(
      type: 'monthly_comparison',
      title: '月度对比',
      content: '月度消费数据正在统计中...',
      data: {},
      generatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
  }

  /// 保存洞察到本地
  Future<void> _saveInsights(Map<String, OfflineInsight> insights) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = insights.map(
        (key, value) => MapEntry(key, value.toJson()),
      );

      await prefs.setString(_insightCacheKey, jsonEncode(data));
      await prefs.setInt(_insightTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Failed to save insights: $e');
    }
  }

  /// 获取缓存的洞察
  Future<OfflineInsight?> getInsight(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_insightCacheKey);

      if (cacheJson == null) return null;

      final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
      final insightData = cache[type];

      if (insightData == null) return null;

      final insight = OfflineInsight.fromJson(insightData);

      // 检查是否过期
      if (insight.isExpired) {
        return null;
      }

      return insight;
    } catch (e) {
      debugPrint('Failed to get insight: $e');
      return null;
    }
  }

  /// 获取所有缓存的洞察
  Future<List<OfflineInsight>> getAllInsights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_insightCacheKey);

      if (cacheJson == null) return [];

      final cache = jsonDecode(cacheJson) as Map<String, dynamic>;

      return cache.values
          .map((data) => OfflineInsight.fromJson(data))
          .where((insight) => !insight.isExpired)
          .toList();
    } catch (e) {
      debugPrint('Failed to get all insights: $e');
      return [];
    }
  }

  /// 清除过期洞察
  Future<void> clearExpiredInsights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_insightCacheKey);

      if (cacheJson == null) return;

      final cache = jsonDecode(cacheJson) as Map<String, dynamic>;

      final validInsights = <String, dynamic>{};
      for (final entry in cache.entries) {
        final insight = OfflineInsight.fromJson(entry.value);
        if (!insight.isExpired) {
          validInsights[entry.key] = entry.value;
        }
      }

      await prefs.setString(_insightCacheKey, jsonEncode(validInsights));
    } catch (e) {
      debugPrint('Failed to clear expired insights: $e');
    }
  }

  /// 强制更新指定类型的洞察
  Future<OfflineInsight?> refreshInsight(String type) async {
    final insight = await _generateInsight(type);

    if (insight != null) {
      // 更新缓存
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_insightCacheKey);

      final cache = cacheJson != null
          ? jsonDecode(cacheJson) as Map<String, dynamic>
          : <String, dynamic>{};

      cache[type] = insight.toJson();

      await prefs.setString(_insightCacheKey, jsonEncode(cache));
    }

    return insight;
  }

  /// 释放资源
  void dispose() {
    _generateTimer?.cancel();
  }
}

/// 离线洞察数据模型
class OfflineInsight {
  final String type;
  final String title;
  final String content;
  final Map<String, dynamic> data;
  final DateTime generatedAt;
  final DateTime expiresAt;

  const OfflineInsight({
    required this.type,
    required this.title,
    required this.content,
    required this.data,
    required this.generatedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'content': content,
    'data': data,
    'generatedAt': generatedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory OfflineInsight.fromJson(Map<String, dynamic> json) {
    return OfflineInsight(
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      data: json['data'] as Map<String, dynamic>,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
