import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 预算报告页面
/// 原型设计 7.04：预算报告
/// - 周期选择器（12月、11月、10月、Q4、全年）
/// - 总预算执行率进度条
/// - 分类执行情况列表
class BudgetReportPage extends ConsumerStatefulWidget {
  const BudgetReportPage({super.key});

  @override
  ConsumerState<BudgetReportPage> createState() => _BudgetReportPageState();
}

class _BudgetReportPageState extends ConsumerState<BudgetReportPage> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['12月', '11月', '10月', 'Q4', '全年'];

  // 模拟预算数据
  final double _totalBudget = 20000;
  final double _usedBudget = 15700;

  final List<_BudgetCategory> _categories = [
    _BudgetCategory('餐饮', 3000, 3450, Colors.red),
    _BudgetCategory('交通', 1500, 1200, Colors.blue),
    _BudgetCategory('购物', 2000, 1800, Colors.green),
    _BudgetCategory('娱乐', 1000, 750, Colors.purple),
    _BudgetCategory('居住', 8000, 7500, Colors.orange),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final executionRate = _totalBudget > 0 ? (_usedBudget / _totalBudget * 100) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            _buildPeriodSelector(theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildOverallProgress(theme, executionRate),
                    _buildCategoryBreakdown(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  Widget _buildOverallProgress(ThemeData theme, double executionRate) {
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
                '${executionRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                '已用 ¥${_usedBudget.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '预算 ¥${_totalBudget.toStringAsFixed(0)}',
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
  Widget _buildCategoryBreakdown(ThemeData theme) {
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
          ..._categories.map((cat) => _buildCategoryItem(theme, cat)),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(ThemeData theme, _BudgetCategory category) {
    final rate = category.budget > 0 ? (category.used / category.budget * 100) : 0.0;
    final isOverBudget = rate > 100;
    final progressColor = isOverBudget ? Colors.red : category.color;

    return Container(
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
                '${rate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: progressColor,
                ),
              ),
            ],
          ),
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
                '预算 ¥${category.budget.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCategory {
  final String name;
  final double budget;
  final double used;
  final Color color;

  _BudgetCategory(this.name, this.budget, this.used, this.color);
}
