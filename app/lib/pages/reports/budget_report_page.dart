import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../extensions/category_extensions.dart';
import '../../services/category_localization_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';
import '../budget_management_page.dart';
import '../category_detail_page.dart';

/// 预算报告页面
/// 原型设计 7.04：预算报告
/// - 周期选择器（本月、上月、近3月、全年）
/// - 总预算执行率进度条
/// - 分类执行情况列表
/// 数据来源：budgetProvider, transactionProvider
class BudgetReportPage extends ConsumerStatefulWidget {
  const BudgetReportPage({super.key});

  @override
  ConsumerState<BudgetReportPage> createState() => _BudgetReportPageState();
}

class _BudgetReportPageState extends ConsumerState<BudgetReportPage> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['本月', '上月', '近3月', '全年'];
  Map<String, double> _zeroBasedAllocations = {};
  bool _allocationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadZeroBasedAllocations();
  }

  /// 加载零基预算的当月分配金额
  Future<void> _loadZeroBasedAllocations() async {
    try {
      final db = sl<IDatabaseService>();
      final budgets = ref.read(budgetProvider);
      final now = DateTime.now();
      final allocations = <String, double>{};

      for (final budget in budgets.where((b) => b.budgetType == BudgetType.zeroBased && b.isEnabled)) {
        final allocation = await db.getZeroBasedAllocationForMonth(budget.id, now.year, now.month);
        if (allocation != null) {
          allocations[budget.id] = allocation.allocatedAmount;
        }
      }

      if (mounted) {
        setState(() {
          _zeroBasedAllocations = allocations;
          _allocationsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[BudgetReport] 加载零基预算分配失败: $e');
      if (mounted) {
        setState(() => _allocationsLoaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetUsages = ref.watch(allBudgetUsagesProvider);
    final transactions = ref.watch(transactionProvider);

    // 根据选择的周期过滤数据
    final filteredData = _getFilteredBudgetData(budgetUsages, transactions);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            _buildPeriodSelector(theme),
            Expanded(
              child: filteredData.categories.isEmpty
                  ? _buildEmptyState(context, theme)
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildOverallProgress(theme, filteredData),
                          _buildCategoryBreakdown(theme, filteredData.categories),
                          _buildAdjustBudgetButton(context, theme),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据选择的周期获取过滤后的预算数据
  _FilteredBudgetData _getFilteredBudgetData(
    List<BudgetUsage> budgetUsages,
    List<Transaction> transactions,
  ) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (_selectedPeriod) {
      case 0: // 本月
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 1: // 上月
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = lastMonth;
        endDate = DateTime(now.year, now.month, 0); // 上月最后一天
        break;
      case 2: // 近3月
        startDate = DateTime(now.year, now.month - 2, 1);
        break;
      case 3: // 全年
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    // 过滤当前周期内的交易
    final periodTransactions = transactions.where((t) =>
        t.type == TransactionType.expense &&
        !t.date.isBefore(startDate) &&
        !t.date.isAfter(endDate)).toList();

    // 按分类统计支出
    final categoryExpenses = <String, double>{};
    for (final t in periodTransactions) {
      categoryExpenses[t.category] = (categoryExpenses[t.category] ?? 0) + t.amount;
    }

    // 获取预算数据并匹配实际支出
    final categories = <_BudgetCategoryData>[];
    double totalBudget = 0;
    double totalUsed = 0;

    // 从预算中获取分类预算
    for (final usage in budgetUsages) {
      if (usage.budget.categoryId != null) {
        final categoryId = usage.budget.categoryId!;
        final spent = categoryExpenses[categoryId] ?? 0;

        // 零基预算使用当月分配金额，传统预算使用 budget.amount
        double budget;
        if (usage.budget.budgetType == BudgetType.zeroBased) {
          budget = _zeroBasedAllocations[usage.budget.id] ?? usage.budget.amount;
        } else {
          budget = usage.budget.amount;
        }

        // 获取分类颜色和名称
        final category = DefaultCategories.findById(categoryId);
        final color = category?.color ?? Colors.grey;
        final name = category?.localizedName ??
                     CategoryLocalizationService.instance.getCategoryName(categoryId);

        categories.add(_BudgetCategoryData(
          categoryId: categoryId,
          name: name,
          budget: budget,
          used: spent,
          color: color,
        ));

        totalBudget += budget;
        totalUsed += spent;
      }
    }

    // 如果没有分类预算，显示按分类的实际支出
    if (categories.isEmpty && categoryExpenses.isNotEmpty) {
      for (final entry in categoryExpenses.entries) {
        final category = DefaultCategories.findById(entry.key);
        final color = category?.color ?? Colors.grey;
        final name = category?.localizedName ??
                     CategoryLocalizationService.instance.getCategoryName(entry.key);

        categories.add(_BudgetCategoryData(
          categoryId: entry.key,
          name: name,
          budget: 0, // 无预算
          used: entry.value,
          color: color,
        ));
        totalUsed += entry.value;
      }
    }

    // 按支出金额排序
    categories.sort((a, b) => b.used.compareTo(a.used));

    return _FilteredBudgetData(
      totalBudget: totalBudget,
      totalUsed: totalUsed,
      categories: categories,
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无预算数据',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设置预算后可查看执行报告',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('设置预算'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '预算执行报告',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 周期选择器
  Widget _buildPeriodSelector(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _periods[index],
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 总预算执行率
  Widget _buildOverallProgress(ThemeData theme, _FilteredBudgetData data) {
    final executionRate = data.totalBudget > 0
        ? (data.totalUsed / data.totalBudget * 100)
        : 0.0;
    final isOverBudget = executionRate > 100;
    final progressColor = isOverBudget ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '总预算执行率',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                data.totalBudget > 0
                    ? '${executionRate.toStringAsFixed(1)}%'
                    : '未设置预算',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: data.totalBudget > 0 ? progressColor : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.totalBudget > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (executionRate / 100).clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已用 ¥${data.totalUsed.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                data.totalBudget > 0
                    ? '预算 ¥${data.totalBudget.toStringAsFixed(0)}'
                    : '总支出',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 分类执行情况
  Widget _buildCategoryBreakdown(ThemeData theme, List<_BudgetCategoryData> categories) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分类执行情况',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...categories.map((cat) => _buildCategoryItem(theme, cat)),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(ThemeData theme, _BudgetCategoryData category) {
    final rate = category.budget > 0 ? (category.used / category.budget * 100) : 0.0;
    final isOverBudget = rate > 100;
    final progressColor = isOverBudget ? Colors.red : category.color;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryDetailPage(
            categoryId: category.categoryId,
            isExpense: true,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: progressColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Text(
                  category.budget > 0 ? '${rate.toStringAsFixed(0)}%' : '-',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: category.budget > 0 ? progressColor : theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            if (category.budget > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (rate / 100).clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 4,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已用 ¥${category.used.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  category.budget > 0
                      ? '预算 ¥${category.budget.toStringAsFixed(0)}'
                      : '无预算',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustBudgetButton(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
          ),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('调整预算'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// 过滤后的预算数据
class _FilteredBudgetData {
  final double totalBudget;
  final double totalUsed;
  final List<_BudgetCategoryData> categories;

  _FilteredBudgetData({
    required this.totalBudget,
    required this.totalUsed,
    required this.categories,
  });
}

/// 分类预算数据
class _BudgetCategoryData {
  final String categoryId;
  final String name;
  final double budget;
  final double used;
  final Color color;

  _BudgetCategoryData({
    required this.categoryId,
    required this.name,
    required this.budget,
    required this.used,
    required this.color,
  });
}
