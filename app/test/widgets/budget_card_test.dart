import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 预算卡片 Widget 测试
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== Mock 预算模型 ====================

enum BudgetAlertLevel { safe, warning, danger, exceeded }

class Budget {
  final String id;
  final String categoryName;
  final IconData categoryIcon;
  final double amount;
  final double spent;
  final String period;
  final BudgetAlertLevel alertLevel;

  Budget({
    required this.id,
    required this.categoryName,
    required this.categoryIcon,
    required this.amount,
    required this.spent,
    this.period = 'monthly',
    BudgetAlertLevel? alertLevel,
  }) : alertLevel = alertLevel ?? _calculateAlertLevel(spent, amount);

  static BudgetAlertLevel _calculateAlertLevel(double spent, double amount) {
    final usage = amount > 0 ? spent / amount : 0;
    if (usage > 1) return BudgetAlertLevel.exceeded;
    if (usage >= 0.8) return BudgetAlertLevel.danger;
    if (usage >= 0.5) return BudgetAlertLevel.warning;
    return BudgetAlertLevel.safe;
  }

  double get remaining => amount - spent;
  double get usagePercentage => amount > 0 ? (spent / amount * 100) : 0;
  bool get isOverBudget => spent > amount;
}

// ==================== 预算卡片组件 ====================

/// 预算卡片组件
class BudgetCard extends StatelessWidget {
  final Budget budget;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool compact;

  const BudgetCard({
    super.key,
    required this.budget,
    this.onTap,
    this.showProgress = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：分类和金额
              Row(
                children: [
                  // 分类图标
                  Container(
                    width: compact ? 36 : 44,
                    height: compact ? 36 : 44,
                    decoration: BoxDecoration(
                      color: _getAlertColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      budget.categoryIcon,
                      color: _getAlertColor(),
                      size: compact ? 20 : 24,
                      key: const Key('category_icon'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 分类名称
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.categoryName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: compact ? 14 : 16,
                          ),
                          key: const Key('category_name'),
                        ),
                        Text(
                          _getPeriodText(),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          key: const Key('period_text'),
                        ),
                      ],
                    ),
                  ),
                  // 预算金额
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${budget.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 16 : 18,
                        ),
                        key: const Key('budget_amount'),
                      ),
                      Text(
                        '剩余 ¥${budget.remaining.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: _getAlertColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        key: const Key('remaining_amount'),
                      ),
                    ],
                  ),
                ],
              ),
              if (showProgress) ...[
                const SizedBox(height: 12),
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: const Key('progress_bar'),
                    value: (budget.usagePercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_getAlertColor()),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                // 使用详情
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已用 ¥${budget.spent.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      key: const Key('spent_amount'),
                    ),
                    Row(
                      children: [
                        if (budget.isOverBudget)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '超支',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              key: Key('over_budget_label'),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '${budget.usagePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: _getAlertColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          key: const Key('usage_percentage'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getAlertColor() {
    switch (budget.alertLevel) {
      case BudgetAlertLevel.safe:
        return Colors.green;
      case BudgetAlertLevel.warning:
        return Colors.orange;
      case BudgetAlertLevel.danger:
        return Colors.deepOrange;
      case BudgetAlertLevel.exceeded:
        return Colors.red;
    }
  }

  String _getPeriodText() {
    switch (budget.period) {
      case 'weekly':
        return '本周预算';
      case 'yearly':
        return '年度预算';
      case 'monthly':
      default:
        return '本月预算';
    }
  }
}

// ==================== 预算概览卡片 ====================

/// 预算概览卡片
class BudgetSummaryCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final int budgetCount;
  final int overBudgetCount;
  final VoidCallback? onViewDetails;

  const BudgetSummaryCard({
    super.key,
    required this.totalBudget,
    required this.totalSpent,
    required this.budgetCount,
    this.overBudgetCount = 0,
    this.onViewDetails,
  });

  double get remaining => totalBudget - totalSpent;
  double get usagePercentage => totalBudget > 0 ? totalSpent / totalBudget * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '预算概览',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  key: Key('summary_title'),
                ),
                if (onViewDetails != null)
                  TextButton(
                    onPressed: onViewDetails,
                    key: const Key('view_details_button'),
                    child: const Text('查看详情'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 总预算和剩余
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总预算',
                    '¥${totalBudget.toStringAsFixed(0)}',
                    Colors.grey[700]!,
                    'total_budget_value',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '已使用',
                    '¥${totalSpent.toStringAsFixed(0)}',
                    Colors.orange,
                    'total_spent_value',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '剩余',
                    '¥${remaining.toStringAsFixed(0)}',
                    remaining >= 0 ? Colors.green : Colors.red,
                    'remaining_value',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const Key('summary_progress_bar'),
                value: (usagePercentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  usagePercentage > 100
                      ? Colors.red
                      : usagePercentage > 80
                          ? Colors.orange
                          : Colors.green,
                ),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 12),
            // 底部信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$budgetCount 个预算',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  key: const Key('budget_count'),
                ),
                if (overBudgetCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$overBudgetCount 个超支',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      key: const Key('over_budget_count'),
                    ),
                  ),
                Text(
                  '使用 ${usagePercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  key: const Key('usage_percentage_text'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, String key) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          key: Key(key),
        ),
      ],
    );
  }
}

// ==================== 测试用例 ====================

void main() {
  group('BudgetCard Widget 测试', () {
    testWidgets('显示预算基本信息', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 1200,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('¥3000'), findsOneWidget);
      expect(find.text('剩余 ¥1800'), findsOneWidget);
      expect(find.text('已用 ¥1200'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('显示安全状态预算', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 900, // 30%
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      // 验证使用率显示
      expect(find.text('30.0%'), findsOneWidget);
      // 不应显示超支标签
      expect(find.byKey(const Key('over_budget_label')), findsNothing);
    });

    testWidgets('显示超支预算', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 3500, // 超支
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      // 验证超支标签显示
      expect(find.text('超支'), findsOneWidget);
      // 剩余应为负数
      expect(find.text('剩余 ¥-500'), findsOneWidget);
    });

    testWidgets('显示月度预算周期', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 1000,
        period: 'monthly',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      expect(find.text('本月预算'), findsOneWidget);
    });

    testWidgets('显示周度预算周期', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 500,
        spent: 200,
        period: 'weekly',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      expect(find.text('本周预算'), findsOneWidget);
    });

    testWidgets('显示年度预算周期', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '旅游',
        categoryIcon: Icons.flight,
        amount: 20000,
        spent: 5000,
        period: 'yearly',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      expect(find.text('年度预算'), findsOneWidget);
    });

    testWidgets('点击事件触发', (tester) async {
      bool tapped = false;
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 1000,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(
            budget: budget,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(BudgetCard));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('隐藏进度条', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 1000,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(
            budget: budget,
            showProgress: false,
          ),
        ),
      ));

      expect(find.byKey(const Key('progress_bar')), findsNothing);
      expect(find.byKey(const Key('spent_amount')), findsNothing);
    });

    testWidgets('紧凑模式显示', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 1000,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(
            budget: budget,
            compact: true,
          ),
        ),
      ));

      // 紧凑模式也应该显示所有基本信息
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('¥3000'), findsOneWidget);
    });
  });

  group('BudgetSummaryCard Widget 测试', () {
    testWidgets('显示预算概览', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BudgetSummaryCard(
            totalBudget: 10000,
            totalSpent: 6000,
            budgetCount: 5,
          ),
        ),
      ));

      expect(find.text('预算概览'), findsOneWidget);
      expect(find.byKey(const Key('total_budget_value')), findsOneWidget);
      expect(find.text('¥10000'), findsOneWidget);
      expect(find.text('¥6000'), findsOneWidget);
      expect(find.text('¥4000'), findsOneWidget);
      expect(find.text('5 个预算'), findsOneWidget);
      expect(find.text('使用 60.0%'), findsOneWidget);
    });

    testWidgets('显示超支数量', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BudgetSummaryCard(
            totalBudget: 10000,
            totalSpent: 8000,
            budgetCount: 5,
            overBudgetCount: 2,
          ),
        ),
      ));

      expect(find.text('2 个超支'), findsOneWidget);
    });

    testWidgets('无超支时不显示超支标签', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BudgetSummaryCard(
            totalBudget: 10000,
            totalSpent: 5000,
            budgetCount: 3,
            overBudgetCount: 0,
          ),
        ),
      ));

      expect(find.byKey(const Key('over_budget_count')), findsNothing);
    });

    testWidgets('查看详情按钮', (tester) async {
      bool buttonTapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetSummaryCard(
            totalBudget: 10000,
            totalSpent: 5000,
            budgetCount: 3,
            onViewDetails: () => buttonTapped = true,
          ),
        ),
      ));

      expect(find.text('查看详情'), findsOneWidget);

      await tester.tap(find.byKey(const Key('view_details_button')));
      await tester.pump();

      expect(buttonTapped, true);
    });

    testWidgets('无查看详情回调时不显示按钮', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BudgetSummaryCard(
            totalBudget: 10000,
            totalSpent: 5000,
            budgetCount: 3,
          ),
        ),
      ));

      expect(find.byKey(const Key('view_details_button')), findsNothing);
    });

    testWidgets('负剩余金额显示', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BudgetSummaryCard(
            totalBudget: 10000,
            totalSpent: 12000,
            budgetCount: 3,
            overBudgetCount: 2,
          ),
        ),
      ));

      // 剩余应为负数
      expect(find.text('¥-2000'), findsOneWidget);
    });

    testWidgets('零预算处理', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BudgetSummaryCard(
            totalBudget: 0,
            totalSpent: 0,
            budgetCount: 0,
          ),
        ),
      ));

      expect(find.text('¥0'), findsNWidgets(3)); // 总预算、已使用、剩余都是0
      expect(find.text('使用 0.0%'), findsOneWidget);
      expect(find.text('0 个预算'), findsOneWidget);
    });
  });

  group('预算警报级别颜色测试', () {
    testWidgets('安全级别显示绿色', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 900, // 30% - safe
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('progress_bar')),
      );
      expect(
        (progressBar.valueColor as AlwaysStoppedAnimation<Color>).value,
        Colors.green,
      );
    });

    testWidgets('警告级别显示橙色', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 1800, // 60% - warning
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('progress_bar')),
      );
      expect(
        (progressBar.valueColor as AlwaysStoppedAnimation<Color>).value,
        Colors.orange,
      );
    });

    testWidgets('危险级别显示深橙色', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 2700, // 90% - danger
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('progress_bar')),
      );
      expect(
        (progressBar.valueColor as AlwaysStoppedAnimation<Color>).value,
        Colors.deepOrange,
      );
    });

    testWidgets('超支级别显示红色', (tester) async {
      final budget = Budget(
        id: 'budget_1',
        categoryName: '餐饮',
        categoryIcon: Icons.restaurant,
        amount: 3000,
        spent: 3500, // 超支
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BudgetCard(budget: budget),
        ),
      ));

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('progress_bar')),
      );
      expect(
        (progressBar.valueColor as AlwaysStoppedAnimation<Color>).value,
        Colors.red,
      );
    });
  });
}
