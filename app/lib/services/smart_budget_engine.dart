import 'dart:math';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';

/// 智能预算分配引擎
///
/// 综合多维度数据分析，生成符合用户实际生活习惯的预算方案：
/// 1. 固定支出预测（周期性交易 + 历史稳定支出识别）
/// 2. 历史消费趋势（不只看平均值，还看增长/下降趋势）
/// 3. 季节性因素（当前月份的消费特征）
/// 4. 收入稳定性（波动大则多留缓冲）
/// 5. 消费结构健康度（储蓄率、必要vs非必要支出比例）
/// 6. 基本生活成本底线保障
class SmartBudgetEngine {
  final double monthlyIncome;
  final List<Transaction> allTransactions;
  final List<RecurringTransaction> recurringTransactions;

  SmartBudgetEngine({
    required this.monthlyIncome,
    required this.allTransactions,
    required this.recurringTransactions,
  });

  /// 生成智能分配方案
  SmartAllocationResult generate() {
    if (monthlyIncome <= 0) {
      return SmartAllocationResult(items: [], insights: ['本月暂无收入记录']);
    }

    final now = DateTime.now();
    final insights = <String>[];

    // ===== 第一步：数据分析 =====
    final analysis = _analyzeSpendingPatterns(now);
    final incomeStability = _analyzeIncomeStability(now);
    final seasonalFactors = _getSeasonalFactors(now.month);

    // ===== 第二步：确定固定支出（刚性支出，必须优先保障）=====
    final fixedExpenses = _calculateFixedExpenses(analysis, now);

    // ===== 第三步：确定储蓄目标 =====
    final savingsTarget = _calculateSavingsTarget(
      incomeStability, analysis, fixedExpenses,
    );

    // ===== 第四步：分配弹性支出 =====
    final remainingAfterFixed = monthlyIncome - fixedExpenses.total - savingsTarget;
    final flexibleAllocations = _allocateFlexibleSpending(
      analysis, seasonalFactors, remainingAfterFixed, now,
    );

    // ===== 第五步：组装结果 =====
    final items = <SmartAllocationItem>[];
    int priority = 1;

    // P1: 固定支出
    if (fixedExpenses.total > 0) {
      items.add(SmartAllocationItem(
        id: '${priority}',
        name: '固定支出',
        icon: Icons.home,
        color: Colors.red,
        priority: priority,
        amount: fixedExpenses.total,
        type: AllocationCategory.fixed,
        reason: '基于周期性账单和历史稳定支出预测',
        details: fixedExpenses.details,
        confidence: fixedExpenses.confidence,
      ));
      priority++;
    }

    // P2: 储蓄
    if (savingsTarget > 0) {
      final savingsPercent = (savingsTarget / monthlyIncome * 100).round();
      items.add(SmartAllocationItem(
        id: '${priority}',
        name: '储蓄',
        icon: Icons.savings,
        color: Colors.green,
        priority: priority,
        amount: savingsTarget,
        type: AllocationCategory.savings,
        reason: _getSavingsReason(incomeStability, savingsPercent),
        confidence: 0.8,
      ));
      priority++;
    }

    // P3+: 弹性支出
    for (final flex in flexibleAllocations) {
      items.add(SmartAllocationItem(
        id: '${priority}',
        name: flex.name,
        icon: flex.icon,
        color: flex.color,
        priority: priority,
        amount: flex.amount,
        type: AllocationCategory.flexible,
        reason: flex.reason,
        details: flex.details,
        confidence: flex.confidence,
      ));
      priority++;
    }

    // ===== 第六步：合理性校验 =====
    _validateMinimums(items);

    // ===== 第七步：零基平衡（确保收入 = 总分配）=====
    _ensureZeroBasedBalance(items);

    // ===== 第八步：生成洞察 =====
    insights.addAll(_generateInsights(analysis, incomeStability, items));

    return SmartAllocationResult(items: items, insights: insights);
  }

  // ==========================================
  // 数据分析层
  // ==========================================

  /// 分析消费模式：按分类统计月均、趋势、稳定性
  _SpendingAnalysis _analyzeSpendingPatterns(DateTime now) {
    final categoryData = <String, _CategoryAnalysis>{};

    // 取最近6个月数据（数据越多趋势越准）
    for (int i = 0; i < 6; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);

      final monthExpenses = allTransactions.where((t) =>
          t.type == TransactionType.expense &&
          t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          t.date.isBefore(monthEnd.add(const Duration(days: 1))));

      for (final tx in monthExpenses) {
        categoryData.putIfAbsent(tx.category, () => _CategoryAnalysis(tx.category));
        categoryData[tx.category]!.monthlyAmounts.add(
          _MonthAmount(month: monthStart, amount: tx.amount),
        );
      }
    }

    // 计算每个分类的统计指标
    for (final entry in categoryData.values) {
      entry.calculate();
    }

    // 计算总月均支出
    final totalMonthlyAvg = categoryData.values
        .fold(0.0, (sum, c) => sum + c.monthlyAverage);

    return _SpendingAnalysis(
      categoryData: categoryData,
      totalMonthlyAverage: totalMonthlyAvg,
      monthsOfData: _countMonthsWithData(now),
    );
  }

  /// 统计有数据的月份数
  int _countMonthsWithData(DateTime now) {
    final months = <String>{};
    for (final tx in allTransactions) {
      if (tx.type == TransactionType.expense) {
        months.add('${tx.date.year}-${tx.date.month}');
      }
    }
    return months.length.clamp(0, 6);
  }

  /// 分析收入稳定性
  _IncomeStability _analyzeIncomeStability(DateTime now) {
    final monthlyIncomes = <double>[];

    for (int i = 0; i < 6; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);

      final income = allTransactions
          .where((t) =>
              t.type == TransactionType.income &&
              t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
              t.date.isBefore(monthEnd.add(const Duration(days: 1))))
          .fold(0.0, (sum, t) => sum + t.amount);

      if (income > 0) monthlyIncomes.add(income);
    }

    if (monthlyIncomes.length < 2) {
      return _IncomeStability(
        isStable: false,
        volatility: 1.0, // 数据不足，视为高波动
        averageIncome: monthlyIncome,
        monthsOfData: monthlyIncomes.length,
      );
    }

    final avg = monthlyIncomes.reduce((a, b) => a + b) / monthlyIncomes.length;
    final variance = monthlyIncomes
        .map((v) => (v - avg) * (v - avg))
        .reduce((a, b) => a + b) / monthlyIncomes.length;
    final stdDev = sqrt(variance);
    final cv = avg > 0 ? stdDev / avg : 1.0; // 变异系数

    return _IncomeStability(
      isStable: cv < 0.15, // 变异系数<15%视为稳定
      volatility: cv.clamp(0, 1),
      averageIncome: avg,
      monthsOfData: monthlyIncomes.length,
    );
  }

  /// 获取季节性因素
  Map<String, double> _getSeasonalFactors(int month) {
    // 基于常识的季节性调整系数（1.0=正常）
    final factors = <String, double>{};

    // 餐饮：夏天冷饮/外卖多，冬天火锅多，基本稳定
    factors['餐饮'] = 1.0;

    // 水电燃气：夏天空调、冬天取暖
    if (month >= 6 && month <= 8) {
      factors['水电燃气'] = 1.4; // 夏天电费高
    } else if (month >= 11 || month <= 2) {
      factors['水电燃气'] = 1.3; // 冬天取暖
    } else {
      factors['水电燃气'] = 1.0;
    }

    // 服饰：换季月份消费高
    if (month == 3 || month == 4 || month == 9 || month == 10) {
      factors['服饰'] = 1.5; // 换季
    } else if (month == 6 || month == 11) {
      factors['服饰'] = 1.8; // 618/双11
    } else {
      factors['服饰'] = 1.0;
    }

    // 购物：大促月份
    if (month == 6 || month == 11) {
      factors['购物'] = 1.6; // 618/双11
    } else if (month == 12) {
      factors['购物'] = 1.3; // 年末
    } else {
      factors['购物'] = 1.0;
    }

    // 人情往来：春节、中秋、国庆
    if (month == 1 || month == 2) {
      factors['人情往来'] = 2.0; // 春节
    } else if (month == 9 || month == 10) {
      factors['人情往来'] = 1.5; // 中秋国庆
    } else {
      factors['人情往来'] = 1.0;
    }

    // 教育：开学季
    if (month == 2 || month == 3 || month == 8 || month == 9) {
      factors['教育'] = 1.5;
    } else {
      factors['教育'] = 1.0;
    }

    // 娱乐：假期月份
    if (month == 7 || month == 8 || month == 10) {
      factors['娱乐'] = 1.3;
    } else {
      factors['娱乐'] = 1.0;
    }

    return factors;
  }

  // ==========================================
  // 分配计算层
  // ==========================================

  /// 计算固定支出：结合周期性交易 + 历史稳定支出
  _FixedExpenseResult _calculateFixedExpenses(
    _SpendingAnalysis analysis, DateTime now,
  ) {
    double total = 0;
    final details = <String>[];
    double confidence = 0.9;

    // 来源1：周期性交易（最可靠）
    final activeRecurring = recurringTransactions
        .where((r) => r.isEnabled && r.type == TransactionType.expense);

    for (final recurring in activeRecurring) {
      final monthlyAmount = _recurringToMonthly(recurring);
      if (monthlyAmount > 0) {
        total += monthlyAmount;
        final cat = DefaultCategories.findById(recurring.category);
        details.add('${cat?.localizedName ?? recurring.category}: ¥${monthlyAmount.toStringAsFixed(0)}/月（周期性）');
      }
    }

    // 来源2：历史数据中的稳定支出（变异系数低的分类）
    final fixedCategoryKeywords = ['房租', '水电', '物业', '保险', '通讯', '网费',
        '话费', '会员', '订阅', '贷款', '还款', 'rent', 'utilities'];

    for (final entry in analysis.categoryData.entries) {
      final cat = DefaultCategories.findById(entry.key);
      final catName = cat?.name ?? entry.key;
      final data = entry.value;

      // 已经在周期性交易中计算过的跳过
      final alreadyCounted = activeRecurring.any((r) => r.category == entry.key);
      if (alreadyCounted) continue;

      // 判断是否为固定支出：关键词匹配 或 变异系数低（稳定支出）
      final isFixedByKeyword = fixedCategoryKeywords
          .any((k) => catName.toLowerCase().contains(k.toLowerCase()));
      final isFixedByStability = data.variationCoefficient < 0.25 &&
          data.monthlyAverage > 50 &&
          data.monthsWithData >= 3;

      if (isFixedByKeyword || isFixedByStability) {
        total += data.monthlyAverage;
        final label = isFixedByKeyword ? '固定' : '稳定';
        details.add('$catName: ¥${data.monthlyAverage.toStringAsFixed(0)}/月（$label支出）');
      }
    }

    // 固定支出不应超过收入的60%（异常保护）
    if (total > monthlyIncome * 0.6) {
      confidence = 0.6;
      total = monthlyIncome * 0.6;
    }

    return _FixedExpenseResult(
      total: total,
      details: details,
      confidence: confidence,
    );
  }

  /// 周期性交易转换为月度金额
  double _recurringToMonthly(RecurringTransaction recurring) {
    switch (recurring.frequency) {
      case RecurringFrequency.daily:
        return recurring.amount * 30;
      case RecurringFrequency.weekly:
        return recurring.amount * 4.33;
      case RecurringFrequency.monthly:
        return recurring.amount;
      case RecurringFrequency.yearly:
        return recurring.amount / 12;
    }
  }

  /// 计算储蓄目标：根据收入稳定性和消费习惯动态调整
  double _calculateSavingsTarget(
    _IncomeStability incomeStability,
    _SpendingAnalysis analysis,
    _FixedExpenseResult fixedExpenses,
  ) {
    final afterFixed = monthlyIncome - fixedExpenses.total;
    if (afterFixed <= 0) return 0;

    // 基础储蓄率：20%（经典的50/30/20法则）
    double savingsRate = 0.20;

    // 调整1：收入不稳定 → 提高储蓄率（多留缓冲）
    if (!incomeStability.isStable) {
      savingsRate += incomeStability.volatility * 0.1; // 波动越大，多存越多
    }

    // 调整2：历史数据少 → 保守一点，多存一些
    if (analysis.monthsOfData < 3) {
      savingsRate += 0.05;
    }

    // 调整3：如果历史支出远低于收入，说明有储蓄习惯，维持
    if (analysis.totalMonthlyAverage > 0) {
      final historicalSavingsRate =
          1 - (analysis.totalMonthlyAverage / monthlyIncome);
      if (historicalSavingsRate > savingsRate) {
        // 用户本身储蓄率就高，尊重这个习惯
        savingsRate = (savingsRate + historicalSavingsRate) / 2;
      }
    }

    savingsRate = savingsRate.clamp(0.10, 0.50); // 储蓄率在10%-50%之间

    return (monthlyIncome * savingsRate).roundToDouble();
  }

  /// 分配弹性支出
  List<_FlexibleItem> _allocateFlexibleSpending(
    _SpendingAnalysis analysis,
    Map<String, double> seasonalFactors,
    double totalBudget,
    DateTime now,
  ) {
    if (totalBudget <= 0) return [];

    // 定义弹性支出分类组
    final flexGroups = {
      '餐饮': _FlexGroup(
        keywords: ['餐饮', '美食', '食品', '外卖', '早餐', '午餐', '晚餐'],
        icon: Icons.restaurant, color: Colors.orange,
        isEssential: true, // 必要支出
      ),
      '交通': _FlexGroup(
        keywords: ['交通', '出行', '打车', '公交', '地铁', '加油'],
        icon: Icons.directions_car, color: Colors.blue,
        isEssential: true,
      ),
      '购物': _FlexGroup(
        keywords: ['购物', '服饰', '美容', '电商', '日用'],
        icon: Icons.shopping_bag, color: Colors.purple,
        isEssential: false,
      ),
      '娱乐': _FlexGroup(
        keywords: ['娱乐', '电影', '游戏', '运动', '健身', '旅游'],
        icon: Icons.celebration, color: Colors.pink,
        isEssential: false,
      ),
      '人情往来': _FlexGroup(
        keywords: ['人情', '红包', '礼物', '份子'],
        icon: Icons.card_giftcard, color: Colors.teal,
        isEssential: false,
      ),
      '医疗健康': _FlexGroup(
        keywords: ['医疗', '健康', '药品', '体检'],
        icon: Icons.local_hospital, color: Colors.redAccent,
        isEssential: true,
      ),
    };

    // 匹配历史数据到分组
    final groupAmounts = <String, double>{};
    final groupDetails = <String, List<String>>{};
    final groupConfidence = <String, double>{};

    for (final group in flexGroups.entries) {
      double groupTotal = 0;
      final details = <String>[];
      int matchedCategories = 0;

      for (final catEntry in analysis.categoryData.entries) {
        final cat = DefaultCategories.findById(catEntry.key);
        final catName = cat?.name ?? catEntry.key;

        if (group.value.keywords.any(
            (k) => catName.toLowerCase().contains(k.toLowerCase()))) {
          // 应用季节性调整
          final seasonFactor = seasonalFactors[group.key] ?? 1.0;
          final adjusted = catEntry.value.monthlyAverage * seasonFactor;

          // 如果有趋势，考虑趋势方向
          final trendAdjusted = catEntry.value.trend > 0
              ? adjusted * (1 + catEntry.value.trend * 0.1).clamp(1.0, 1.3)
              : adjusted;

          groupTotal += trendAdjusted;
          matchedCategories++;
          if (details.length < 3) {
            details.add('$catName: ¥${catEntry.value.monthlyAverage.toStringAsFixed(0)}/月');
          }
        }
      }

      if (groupTotal > 0) {
        groupAmounts[group.key] = groupTotal;
        groupDetails[group.key] = details;
        // 匹配的分类越多、数据月份越多，置信度越高
        groupConfidence[group.key] = (matchedCategories > 0 && analysis.monthsOfData >= 3)
            ? 0.85 : 0.6;
      }
    }

    // 如果没有历史数据，使用经验比例
    if (groupAmounts.isEmpty) {
      return _coldStartFlexible(totalBudget, flexGroups);
    }

    // 按历史比例分配，但确保必要支出优先
    final totalHistorical = groupAmounts.values.fold(0.0, (s, v) => s + v);
    final result = <_FlexibleItem>[];

    // 先分配必要支出
    double allocated = 0;
    for (final group in flexGroups.entries) {
      if (!group.value.isEssential) continue;
      final historical = groupAmounts[group.key];
      if (historical == null || historical <= 0) continue;

      final ratio = historical / totalHistorical;
      var amount = (totalBudget * ratio).roundToDouble();

      // 必要支出至少给历史均值的80%
      final minAmount = historical * 0.8;
      if (amount < minAmount && totalBudget >= minAmount) {
        amount = minAmount.roundToDouble();
      }

      result.add(_FlexibleItem(
        name: group.key,
        icon: group.value.icon,
        color: group.value.color,
        amount: amount,
        reason: _buildFlexReason(group.key, analysis, seasonalFactors),
        details: groupDetails[group.key],
        confidence: groupConfidence[group.key] ?? 0.7,
      ));
      allocated += amount;
    }

    // 再分配非必要支出
    final remainingForOptional = totalBudget - allocated;
    if (remainingForOptional > 0) {
      final optionalTotal = flexGroups.entries
          .where((g) => !g.value.isEssential && groupAmounts.containsKey(g.key))
          .fold(0.0, (s, g) => s + (groupAmounts[g.key] ?? 0));

      for (final group in flexGroups.entries) {
        if (group.value.isEssential) continue;
        final historical = groupAmounts[group.key];
        if (historical == null || historical <= 0) continue;

        final ratio = optionalTotal > 0 ? historical / optionalTotal : 0.0;
        final amount = (remainingForOptional * ratio).roundToDouble();

        if (amount > 10) {
          result.add(_FlexibleItem(
            name: group.key,
            icon: group.value.icon,
            color: group.value.color,
            amount: amount,
            reason: _buildFlexReason(group.key, analysis, seasonalFactors),
            details: groupDetails[group.key],
            confidence: groupConfidence[group.key] ?? 0.7,
          ));
        }
      }
    }

    // 剩余未分配的归入"其他弹性支出"
    final totalFlexAllocated = result.fold(0.0, (s, item) => s + item.amount);
    final unmatched = totalBudget - totalFlexAllocated;
    if (unmatched > 1) {
      result.add(_FlexibleItem(
        name: '其他弹性支出',
        icon: Icons.more_horiz,
        color: Colors.grey,
        amount: unmatched.roundToDouble(),
        reason: '未归类的日常开支缓冲',
        confidence: 0.5,
      ));
    }

    return result;
  }

  /// 冷启动弹性分配（无历史数据）
  List<_FlexibleItem> _coldStartFlexible(
    double budget, Map<String, _FlexGroup> groups,
  ) {
    // 经验比例：餐饮40%、交通15%、购物20%、娱乐15%、其他10%
    final defaultRatios = {
      '餐饮': 0.40,
      '交通': 0.15,
      '购物': 0.20,
      '娱乐': 0.15,
      '医疗健康': 0.10,
    };

    return defaultRatios.entries.map((e) {
      final group = groups[e.key];
      return _FlexibleItem(
        name: e.key,
        icon: group?.icon ?? Icons.more_horiz,
        color: group?.color ?? Colors.grey,
        amount: (budget * e.value).roundToDouble(),
        reason: '${e.key} · 基于经验比例（暂无历史数据）',
        confidence: 0.4,
      );
    }).toList();
  }

  // ==========================================
  // 辅助方法
  // ==========================================

  String _buildFlexReason(
    String groupName,
    _SpendingAnalysis analysis,
    Map<String, double> seasonalFactors,
  ) {
    final parts = <String>[];
    parts.add(groupName);

    if (analysis.monthsOfData >= 3) {
      parts.add('基于${analysis.monthsOfData}个月消费数据');
    } else if (analysis.monthsOfData > 0) {
      parts.add('基于近期消费（数据较少，建议持续记账）');
    }

    final factor = seasonalFactors[groupName];
    if (factor != null && factor > 1.1) {
      parts.add('本月为消费高峰期');
    }

    return parts.join(' · ');
  }

  String _getSavingsReason(_IncomeStability stability, int percent) {
    if (!stability.isStable) {
      return '储蓄$percent% · 收入波动较大，建议多留缓冲';
    }
    if (stability.monthsOfData < 3) {
      return '储蓄$percent% · 数据积累中，建议保守储蓄';
    }
    return '储蓄$percent% · 先存后花，保障财务安全';
  }

  /// 最低生活成本底线校验
  void _validateMinimums(List<SmartAllocationItem> items) {
    final minimums = {'餐饮': 800.0, '交通': 150.0};

    for (final item in items) {
      final min = minimums[item.name];
      if (min != null && item.amount < min && item.amount > 0) {
        if (monthlyIncome >= min * 3) {
          final deficit = min - item.amount;
          item.amount = min;
          item.reason = '${item.reason}（已保障基本生活成本）';

          // 从"其他弹性支出"中扣减
          final other = items.where((i) => i.name == '其他弹性支出').firstOrNull;
          if (other != null && other.amount >= deficit) {
            other.amount -= deficit;
          }
        }
      }
    }
  }

  /// 零基平衡：确保总分配 = 收入，每一分钱都有去处
  void _ensureZeroBasedBalance(List<SmartAllocationItem> items) {
    final totalAllocated = items.fold(0.0, (s, i) => s + i.amount);
    final gap = monthlyIncome - totalAllocated;

    if (gap.abs() < 1) return; // 误差小于1元，忽略

    if (gap > 0) {
      // 还有剩余未分配 → 优先加到储蓄，没有储蓄则加到"其他弹性支出"
      final savings = items.where((i) => i.type == AllocationCategory.savings).firstOrNull;
      if (savings != null) {
        savings.amount += gap;
      } else {
        final other = items.where((i) => i.name == '其他弹性支出').firstOrNull;
        if (other != null) {
          other.amount += gap;
        } else {
          items.add(SmartAllocationItem(
            id: '${items.length + 1}',
            name: '储蓄',
            icon: Icons.savings,
            color: Colors.green,
            priority: items.length + 1,
            amount: gap,
            type: AllocationCategory.savings,
            reason: '剩余金额自动归入储蓄',
            confidence: 0.9,
          ));
        }
      }
    } else if (gap < 0) {
      // 超分配了 → 从低优先级的弹性支出中扣减
      var excess = -gap;
      final flexItems = items
          .where((i) => i.type == AllocationCategory.flexible)
          .toList()
        ..sort((a, b) => b.priority.compareTo(a.priority)); // 从低优先级开始扣

      for (final item in flexItems) {
        if (excess <= 0) break;
        final canReduce = (item.amount * 0.5).clamp(0, excess);
        item.amount -= canReduce;
        excess -= canReduce;
      }

      // 还不够就从储蓄扣
      if (excess > 0) {
        final savings = items.where((i) => i.type == AllocationCategory.savings).firstOrNull;
        if (savings != null) {
          final canReduce = savings.amount.clamp(0, excess);
          savings.amount -= canReduce;
        }
      }
    }
  }

  /// 生成财务洞察
  List<String> _generateInsights(
    _SpendingAnalysis analysis,
    _IncomeStability incomeStability,
    List<SmartAllocationItem> items,
  ) {
    final insights = <String>[];

    // 数据充分度
    if (analysis.monthsOfData < 2) {
      insights.add('💡 目前数据较少，建议持续记账2-3个月后重新生成，方案会更精准');
    } else if (analysis.monthsOfData >= 4) {
      insights.add('📊 基于${analysis.monthsOfData}个月的消费数据分析，方案置信度较高');
    }

    // 收入稳定性
    if (!incomeStability.isStable && incomeStability.monthsOfData >= 2) {
      insights.add('⚠️ 收入波动较大（波动率${(incomeStability.volatility * 100).round()}%），已适当提高储蓄比例');
    }

    // 储蓄率
    final savingsItem = items.where((i) => i.type == AllocationCategory.savings).firstOrNull;
    if (savingsItem != null) {
      final rate = (savingsItem.amount / monthlyIncome * 100).round();
      if (rate >= 30) {
        insights.add('🎯 储蓄率${rate}%，财务状况健康');
      } else if (rate < 10) {
        insights.add('📌 储蓄率偏低（${rate}%），建议逐步提高到20%以上');
      }
    }

    // 消费趋势警告
    for (final cat in analysis.categoryData.values) {
      if (cat.trend > 0.3 && cat.monthlyAverage > 200) {
        final catObj = DefaultCategories.findById(cat.categoryId);
        final name = catObj?.name ?? cat.categoryId;
        insights.add('📈 $name支出呈上升趋势，已在预算中预留空间');
      }
    }

    return insights;
  }
}

// ==========================================
// 数据模型
// ==========================================

class SmartAllocationResult {
  final List<SmartAllocationItem> items;
  final List<String> insights;

  SmartAllocationResult({required this.items, required this.insights});

  double get totalAllocated => items.fold(0.0, (s, i) => s + i.amount);
}

class SmartAllocationItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int priority;
  double amount;
  final AllocationCategory type;
  String reason;
  final List<String>? details;
  final double confidence; // 0-1，方案置信度

  SmartAllocationItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.priority,
    required this.amount,
    required this.type,
    required this.reason,
    this.details,
    this.confidence = 0.7,
  });
}

enum AllocationCategory { fixed, savings, flexible }

// ==========================================
// 内部分析模型
// ==========================================

class _SpendingAnalysis {
  final Map<String, _CategoryAnalysis> categoryData;
  final double totalMonthlyAverage;
  final int monthsOfData;

  _SpendingAnalysis({
    required this.categoryData,
    required this.totalMonthlyAverage,
    required this.monthsOfData,
  });
}

class _CategoryAnalysis {
  final String categoryId;
  final List<_MonthAmount> monthlyAmounts = [];

  double monthlyAverage = 0;
  double variationCoefficient = 0; // 变异系数，越小越稳定
  double trend = 0; // >0上升趋势，<0下降趋势
  int monthsWithData = 0;

  _CategoryAnalysis(this.categoryId);

  void calculate() {
    if (monthlyAmounts.isEmpty) return;

    // 按月聚合
    final monthTotals = <String, double>{};
    for (final ma in monthlyAmounts) {
      final key = '${ma.month.year}-${ma.month.month}';
      monthTotals[key] = (monthTotals[key] ?? 0) + ma.amount;
    }

    monthsWithData = monthTotals.length;
    final values = monthTotals.values.toList();

    // 月均
    monthlyAverage = values.reduce((a, b) => a + b) / values.length;

    // 变异系数
    if (values.length >= 2 && monthlyAverage > 0) {
      final variance = values
          .map((v) => (v - monthlyAverage) * (v - monthlyAverage))
          .reduce((a, b) => a + b) / values.length;
      variationCoefficient = sqrt(variance) / monthlyAverage;
    }

    // 趋势（简单线性：比较前半段和后半段的均值）
    if (values.length >= 3) {
      final sorted = monthTotals.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final mid = sorted.length ~/ 2;
      final firstHalf = sorted.sublist(0, mid).map((e) => e.value);
      final secondHalf = sorted.sublist(mid).map((e) => e.value);
      final avgFirst = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final avgSecond = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      trend = avgFirst > 0 ? (avgSecond - avgFirst) / avgFirst : 0;
    }
  }
}

class _MonthAmount {
  final DateTime month;
  final double amount;
  _MonthAmount({required this.month, required this.amount});
}

class _IncomeStability {
  final bool isStable;
  final double volatility; // 0-1
  final double averageIncome;
  final int monthsOfData;

  _IncomeStability({
    required this.isStable,
    required this.volatility,
    required this.averageIncome,
    required this.monthsOfData,
  });
}

class _FixedExpenseResult {
  final double total;
  final List<String> details;
  final double confidence;

  _FixedExpenseResult({
    required this.total,
    required this.details,
    required this.confidence,
  });
}

class _FlexibleItem {
  final String name;
  final IconData icon;
  final Color color;
  final double amount;
  final String reason;
  final List<String>? details;
  final double confidence;

  _FlexibleItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.reason,
    this.details,
    this.confidence = 0.7,
  });
}

class _FlexGroup {
  final List<String> keywords;
  final IconData icon;
  final Color color;
  final bool isEssential;

  _FlexGroup({
    required this.keywords,
    required this.icon,
    required this.color,
    required this.isEssential,
  });
}


