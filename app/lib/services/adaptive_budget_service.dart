import 'dart:math' as math;
import 'database_service.dart';

/// 预算调整类型
enum BudgetAdjustmentType {
  /// 自动调整（基于消费模式）
  automatic,

  /// 季节性调整
  seasonal,

  /// 事件触发调整
  eventTriggered,

  /// 用户手动调整
  manual,

  /// 紧急调整
  emergency,
}

extension BudgetAdjustmentTypeExtension on BudgetAdjustmentType {
  String get displayName {
    switch (this) {
      case BudgetAdjustmentType.automatic:
        return '智能调整';
      case BudgetAdjustmentType.seasonal:
        return '季节调整';
      case BudgetAdjustmentType.eventTriggered:
        return '事件触发';
      case BudgetAdjustmentType.manual:
        return '手动调整';
      case BudgetAdjustmentType.emergency:
        return '紧急调整';
    }
  }
}

/// 预算弹性级别
enum BudgetFlexibility {
  /// 严格（波动≤5%）
  strict,

  /// 适中（波动≤15%）
  moderate,

  /// 宽松（波动≤30%）
  flexible,

  /// 自适应
  adaptive,
}

extension BudgetFlexibilityExtension on BudgetFlexibility {
  String get displayName {
    switch (this) {
      case BudgetFlexibility.strict:
        return '严格';
      case BudgetFlexibility.moderate:
        return '适中';
      case BudgetFlexibility.flexible:
        return '宽松';
      case BudgetFlexibility.adaptive:
        return '自适应';
    }
  }

  double get maxVariation {
    switch (this) {
      case BudgetFlexibility.strict:
        return 0.05;
      case BudgetFlexibility.moderate:
        return 0.15;
      case BudgetFlexibility.flexible:
        return 0.30;
      case BudgetFlexibility.adaptive:
        return 0.25; // 默认值，实际会根据历史动态调整
    }
  }
}

/// 预算调整记录
class BudgetAdjustment {
  final String id;
  final String vaultId;
  final double originalAmount;
  final double adjustedAmount;
  final BudgetAdjustmentType type;
  final String reason;
  final DateTime adjustedAt;
  final bool isApplied;

  const BudgetAdjustment({
    required this.id,
    required this.vaultId,
    required this.originalAmount,
    required this.adjustedAmount,
    required this.type,
    required this.reason,
    required this.adjustedAt,
    this.isApplied = false,
  });

  double get adjustmentAmount => adjustedAmount - originalAmount;
  double get adjustmentRatio =>
      originalAmount > 0 ? adjustmentAmount / originalAmount : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'vaultId': vaultId,
        'originalAmount': originalAmount,
        'adjustedAmount': adjustedAmount,
        'type': type.index,
        'reason': reason,
        'adjustedAt': adjustedAt.millisecondsSinceEpoch,
        'isApplied': isApplied ? 1 : 0,
      };

  factory BudgetAdjustment.fromMap(Map<String, dynamic> map) => BudgetAdjustment(
        id: map['id'] as String,
        vaultId: map['vaultId'] as String,
        originalAmount: (map['originalAmount'] as num).toDouble(),
        adjustedAmount: (map['adjustedAmount'] as num).toDouble(),
        type: BudgetAdjustmentType.values[map['type'] as int],
        reason: map['reason'] as String,
        adjustedAt:
            DateTime.fromMillisecondsSinceEpoch(map['adjustedAt'] as int),
        isApplied: (map['isApplied'] as int?) != 0,
      );
}

/// 预算调整建议
class BudgetAdjustmentSuggestion {
  final String vaultId;
  final String vaultName;
  final double currentBudget;
  final double suggestedBudget;
  final BudgetAdjustmentType type;
  final String reason;
  final double confidence;
  final List<String> factors;

  const BudgetAdjustmentSuggestion({
    required this.vaultId,
    required this.vaultName,
    required this.currentBudget,
    required this.suggestedBudget,
    required this.type,
    required this.reason,
    required this.confidence,
    required this.factors,
  });

  double get adjustmentAmount => suggestedBudget - currentBudget;
  bool get isIncrease => adjustmentAmount > 0;
}

/// 季节性模式
class SeasonalPattern {
  final int month;
  final double spendingMultiplier; // 相对于平均值的倍数
  final List<String> typicalExpenses;

  const SeasonalPattern({
    required this.month,
    required this.spendingMultiplier,
    required this.typicalExpenses,
  });
}

/// 弹性预算配置
class FlexibleBudgetConfig {
  final BudgetFlexibility flexibility;
  final bool allowAutoAdjust;
  final bool seasonalAdjustment;
  final double minBudget;
  final double maxBudget;
  final List<String> protectedVaults; // 不自动调整的小金库

  const FlexibleBudgetConfig({
    this.flexibility = BudgetFlexibility.moderate,
    this.allowAutoAdjust = true,
    this.seasonalAdjustment = true,
    this.minBudget = 0,
    this.maxBudget = double.infinity,
    this.protectedVaults = const [],
  });
}

/// 弹性预算调整服务
///
/// 基于消费模式和特殊事件动态调整预算：
/// - 季节性消费模式识别
/// - 消费趋势分析
/// - 预算超支/结余自动调整
/// - 特殊事件预算调整建议
class AdaptiveBudgetService {
  final DatabaseService _db;

  AdaptiveBudgetService(this._db);

  /// 预定义的季节性模式（中国市场）
  static const List<SeasonalPattern> _seasonalPatterns = [
    SeasonalPattern(
      month: 1,
      spendingMultiplier: 1.3,
      typicalExpenses: ['年货', '红包', '春节礼品'],
    ),
    SeasonalPattern(
      month: 2,
      spendingMultiplier: 1.2,
      typicalExpenses: ['春节', '情人节'],
    ),
    SeasonalPattern(
      month: 3,
      spendingMultiplier: 0.9,
      typicalExpenses: ['换季服装'],
    ),
    SeasonalPattern(
      month: 4,
      spendingMultiplier: 0.95,
      typicalExpenses: ['清明扫墓'],
    ),
    SeasonalPattern(
      month: 5,
      spendingMultiplier: 1.0,
      typicalExpenses: ['母亲节', '劳动节'],
    ),
    SeasonalPattern(
      month: 6,
      spendingMultiplier: 1.15,
      typicalExpenses: ['618购物节', '儿童节', '端午节'],
    ),
    SeasonalPattern(
      month: 7,
      spendingMultiplier: 1.1,
      typicalExpenses: ['暑期旅行', '夏季消费'],
    ),
    SeasonalPattern(
      month: 8,
      spendingMultiplier: 1.05,
      typicalExpenses: ['开学季'],
    ),
    SeasonalPattern(
      month: 9,
      spendingMultiplier: 1.0,
      typicalExpenses: ['中秋节'],
    ),
    SeasonalPattern(
      month: 10,
      spendingMultiplier: 1.1,
      typicalExpenses: ['国庆节', '秋季换装'],
    ),
    SeasonalPattern(
      month: 11,
      spendingMultiplier: 1.4,
      typicalExpenses: ['双11购物节', '感恩节'],
    ),
    SeasonalPattern(
      month: 12,
      spendingMultiplier: 1.25,
      typicalExpenses: ['双12', '圣诞节', '年终总结'],
    ),
  ];

  /// 分析预算并生成调整建议
  Future<List<BudgetAdjustmentSuggestion>> analyzeBudgets({
    FlexibleBudgetConfig? config,
  }) async {
    config ??= const FlexibleBudgetConfig();
    final suggestions = <BudgetAdjustmentSuggestion>[];

    // 获取所有小金库
    final vaults = await _db.rawQuery('''
      SELECT * FROM budget_vaults WHERE isActive = 1
    ''');

    for (final vault in vaults) {
      final vaultId = vault['id'] as String;
      final vaultName = vault['name'] as String;
      final currentBudget = (vault['amount'] as num).toDouble();

      // 跳过受保护的小金库
      if (config.protectedVaults.contains(vaultId)) continue;

      // 分析该小金库的消费模式
      final suggestion = await _analyzeVaultBudget(
        vaultId: vaultId,
        vaultName: vaultName,
        currentBudget: currentBudget,
        config: config,
      );

      if (suggestion != null) {
        suggestions.add(suggestion);
      }
    }

    // 按调整幅度排序
    suggestions.sort((a, b) =>
        b.adjustmentAmount.abs().compareTo(a.adjustmentAmount.abs()));

    return suggestions;
  }

  /// 分析单个小金库预算
  Future<BudgetAdjustmentSuggestion?> _analyzeVaultBudget({
    required String vaultId,
    required String vaultName,
    required double currentBudget,
    required FlexibleBudgetConfig config,
  }) async {
    final factors = <String>[];
    double suggestedBudget = currentBudget;
    BudgetAdjustmentType type = BudgetAdjustmentType.automatic;

    // 1. 获取历史消费数据
    final history = await _getSpendingHistory(vaultId, months: 6);
    if (history.isEmpty) return null;

    final avgSpending = history.reduce((a, b) => a + b) / history.length;

    // 2. 检查是否持续超支或结余
    final recentMonths = history.take(3).toList();
    final avgRecent = recentMonths.reduce((a, b) => a + b) / recentMonths.length;

    if (avgRecent > currentBudget * 1.1) {
      // 持续超支
      suggestedBudget = avgRecent * 1.05;
      factors.add('近3个月平均消费超出预算${((avgRecent / currentBudget - 1) * 100).toStringAsFixed(0)}%');
    } else if (avgRecent < currentBudget * 0.7) {
      // 持续结余过多
      suggestedBudget = avgRecent * 1.15;
      factors.add('近3个月平均消费仅使用预算的${(avgRecent / currentBudget * 100).toStringAsFixed(0)}%');
    }

    // 3. 季节性调整
    if (config.seasonalAdjustment) {
      final currentMonth = DateTime.now().month;
      final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
      final pattern = _seasonalPatterns.firstWhere((p) => p.month == nextMonth);

      if (pattern.spendingMultiplier > 1.1) {
        suggestedBudget *= pattern.spendingMultiplier;
        type = BudgetAdjustmentType.seasonal;
        factors.add('下月有${pattern.typicalExpenses.join("、")}等消费高峰');
      } else if (pattern.spendingMultiplier < 0.95) {
        suggestedBudget *= pattern.spendingMultiplier;
        type = BudgetAdjustmentType.seasonal;
        factors.add('下月为消费淡季');
      }
    }

    // 4. 检查是否在允许范围内
    final maxVariation = config.flexibility.maxVariation;
    final maxAdjustment = currentBudget * maxVariation;

    if ((suggestedBudget - currentBudget).abs() > maxAdjustment) {
      suggestedBudget = suggestedBudget > currentBudget
          ? currentBudget + maxAdjustment
          : currentBudget - maxAdjustment;
    }

    // 确保在最小/最大范围内
    suggestedBudget = suggestedBudget.clamp(config.minBudget, config.maxBudget);

    // 5. 如果调整幅度太小，不建议调整
    if ((suggestedBudget - currentBudget).abs() < currentBudget * 0.03) {
      return null;
    }

    // 计算置信度
    final confidence = _calculateConfidence(history, suggestedBudget);

    return BudgetAdjustmentSuggestion(
      vaultId: vaultId,
      vaultName: vaultName,
      currentBudget: currentBudget,
      suggestedBudget: suggestedBudget,
      type: type,
      reason: _generateReason(factors, suggestedBudget > currentBudget),
      confidence: confidence,
      factors: factors,
    );
  }

  /// 应用预算调整
  Future<BudgetAdjustment> applyAdjustment({
    required String vaultId,
    required double newAmount,
    required BudgetAdjustmentType type,
    required String reason,
  }) async {
    // 获取当前预算
    final vaultResult = await _db.rawQuery('''
      SELECT amount FROM budget_vaults WHERE id = ?
    ''', [vaultId]);

    if (vaultResult.isEmpty) {
      throw Exception('小金库不存在');
    }

    final originalAmount = (vaultResult.first['amount'] as num).toDouble();

    // 创建调整记录
    final adjustment = BudgetAdjustment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      vaultId: vaultId,
      originalAmount: originalAmount,
      adjustedAmount: newAmount,
      type: type,
      reason: reason,
      adjustedAt: DateTime.now(),
      isApplied: true,
    );

    // 保存调整记录
    await _db.rawInsert('''
      INSERT INTO budget_adjustments
      (id, vaultId, originalAmount, adjustedAmount, type, reason, adjustedAt, isApplied)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      adjustment.id,
      adjustment.vaultId,
      adjustment.originalAmount,
      adjustment.adjustedAmount,
      adjustment.type.index,
      adjustment.reason,
      adjustment.adjustedAt.millisecondsSinceEpoch,
      1,
    ]);

    // 更新小金库预算
    await _db.rawUpdate('''
      UPDATE budget_vaults SET amount = ? WHERE id = ?
    ''', [newAmount, vaultId]);

    return adjustment;
  }

  /// 获取调整历史
  Future<List<BudgetAdjustment>> getAdjustmentHistory({
    String? vaultId,
    int limit = 20,
  }) async {
    String query = 'SELECT * FROM budget_adjustments';
    final params = <dynamic>[];

    if (vaultId != null) {
      query += ' WHERE vaultId = ?';
      params.add(vaultId);
    }

    query += ' ORDER BY adjustedAt DESC LIMIT ?';
    params.add(limit);

    final results = await _db.rawQuery(query, params);
    return results.map((m) => BudgetAdjustment.fromMap(m)).toList();
  }

  /// 获取季节性预测
  Future<Map<String, dynamic>> getSeasonalForecast({int months = 3}) async {
    final forecasts = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 1; i <= months; i++) {
      final targetMonth = (now.month + i - 1) % 12 + 1;
      final pattern = _seasonalPatterns.firstWhere((p) => p.month == targetMonth);

      forecasts.add({
        'month': targetMonth,
        'multiplier': pattern.spendingMultiplier,
        'typicalExpenses': pattern.typicalExpenses,
        'isHighSpending': pattern.spendingMultiplier > 1.1,
      });
    }

    return {
      'forecasts': forecasts,
      'nextHighSpendingMonth': forecasts.firstWhere(
        (f) => f['isHighSpending'] == true,
        orElse: () => {'month': null},
      )['month'],
    };
  }

  /// 预算健康检查
  Future<Map<String, dynamic>> checkBudgetHealth() async {
    final vaults = await _db.rawQuery('''
      SELECT * FROM budget_vaults WHERE isActive = 1
    ''');

    int healthyCount = 0;
    int overspentCount = 0;
    int underutilizedCount = 0;
    final issues = <String>[];

    for (final vault in vaults) {
      final vaultId = vault['id'] as String;
      final vaultName = vault['name'] as String;
      final budget = (vault['amount'] as num).toDouble();

      // 获取本月消费
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final spentResult = await _db.rawQuery('''
        SELECT SUM(amount) as total FROM transactions
        WHERE vaultId = ? AND date >= ? AND type = 'expense'
      ''', [vaultId, startOfMonth.millisecondsSinceEpoch]);

      final spent = (spentResult.first['total'] as num?)?.toDouble() ?? 0;
      final ratio = budget > 0 ? spent / budget : 0;

      // 计算本月已过天数比例
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysPassed = now.day;
      final expectedRatio = daysPassed / daysInMonth;

      if (ratio > expectedRatio * 1.3) {
        overspentCount++;
        issues.add('$vaultName 消费进度超前，已使用${(ratio * 100).toStringAsFixed(0)}%');
      } else if (ratio < expectedRatio * 0.5 && daysPassed > 10) {
        underutilizedCount++;
      } else {
        healthyCount++;
      }
    }

    final total = vaults.length;
    final healthScore = total > 0 ? healthyCount / total * 100 : 100;

    return {
      'healthScore': healthScore,
      'totalVaults': total,
      'healthyCount': healthyCount,
      'overspentCount': overspentCount,
      'underutilizedCount': underutilizedCount,
      'issues': issues,
      'status': healthScore >= 80
          ? 'healthy'
          : healthScore >= 60
              ? 'warning'
              : 'critical',
    };
  }

  /// 智能再分配建议
  Future<List<Map<String, dynamic>>> suggestReallocation() async {
    final suggestions = <Map<String, dynamic>>[];

    // 找出结余过多的小金库
    final underutilized = await _db.rawQuery('''
      SELECT v.id, v.name, v.amount,
             COALESCE(SUM(t.amount), 0) as spent
      FROM budget_vaults v
      LEFT JOIN transactions t ON v.id = t.vaultId
        AND t.date >= ? AND t.type = 'expense'
      WHERE v.isActive = 1
      GROUP BY v.id
      HAVING spent < v.amount * 0.5
    ''', [
      DateTime(DateTime.now().year, DateTime.now().month, 1)
          .millisecondsSinceEpoch,
    ]);

    // 找出超支的小金库
    final overspent = await _db.rawQuery('''
      SELECT v.id, v.name, v.amount,
             COALESCE(SUM(t.amount), 0) as spent
      FROM budget_vaults v
      LEFT JOIN transactions t ON v.id = t.vaultId
        AND t.date >= ? AND t.type = 'expense'
      WHERE v.isActive = 1
      GROUP BY v.id
      HAVING spent > v.amount
    ''', [
      DateTime(DateTime.now().year, DateTime.now().month, 1)
          .millisecondsSinceEpoch,
    ]);

    // 生成再分配建议
    for (final over in overspent) {
      final overAmount =
          (over['spent'] as num).toDouble() - (over['amount'] as num).toDouble();

      for (final under in underutilized) {
        final underSurplus = (under['amount'] as num).toDouble() -
            (under['spent'] as num).toDouble();

        if (underSurplus > 0) {
          final transferAmount = math.min(overAmount, underSurplus * 0.5);

          if (transferAmount > 50) {
            suggestions.add({
              'from': {
                'id': under['id'],
                'name': under['name'],
              },
              'to': {
                'id': over['id'],
                'name': over['name'],
              },
              'amount': transferAmount,
              'reason': '${under['name']}结余较多，可支援${over['name']}',
            });
          }
        }
      }
    }

    return suggestions;
  }

  // 私有方法

  Future<List<double>> _getSpendingHistory(String vaultId,
      {int months = 6}) async {
    final history = <double>[];
    final now = DateTime.now();

    for (int i = 0; i < months; i++) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final result = await _db.rawQuery('''
        SELECT SUM(amount) as total FROM transactions
        WHERE vaultId = ? AND date >= ? AND date < ? AND type = 'expense'
      ''', [
        vaultId,
        targetMonth.millisecondsSinceEpoch,
        nextMonth.millisecondsSinceEpoch,
      ]);

      final total = (result.first['total'] as num?)?.toDouble() ?? 0;
      history.add(total);
    }

    return history;
  }

  double _calculateConfidence(List<double> history, double suggested) {
    if (history.isEmpty) return 0.5;

    // 基于历史数据的稳定性计算置信度
    final avg = history.reduce((a, b) => a + b) / history.length;
    final variance = history.map((x) => math.pow(x - avg, 2)).reduce((a, b) => a + b) / history.length;
    final stdDev = math.sqrt(variance);
    final cv = avg > 0 ? stdDev / avg : 1;

    // 变异系数越小，置信度越高
    double confidence = 1 - cv.clamp(0, 1);

    // 如果建议值接近历史平均，置信度更高
    final deviation = (suggested - avg).abs() / avg;
    if (deviation < 0.2) {
      confidence += 0.1;
    }

    return confidence.clamp(0.3, 0.95);
  }

  String _generateReason(List<String> factors, bool isIncrease) {
    if (factors.isEmpty) {
      return isIncrease ? '建议适当增加预算' : '建议适当减少预算';
    }

    return factors.join('；');
  }
}
