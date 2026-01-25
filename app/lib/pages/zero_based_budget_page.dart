import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import 'smart_allocation_page.dart';

/// 零基预算分配页面
///
/// 对应原型设计 3.09 零基预算分配
/// 展示零基预算原则：收入 - 支出 - 储蓄 = 0
class ZeroBasedBudgetPage extends ConsumerStatefulWidget {
  const ZeroBasedBudgetPage({
    super.key,
  });

  @override
  ConsumerState<ZeroBasedBudgetPage> createState() => _ZeroBasedBudgetPageState();
}

class _ZeroBasedBudgetPageState extends ConsumerState<ZeroBasedBudgetPage> {
  late List<BudgetCategory> _categories;

  @override
  void initState() {
    super.initState();
    _initCategories();
  }

  /// 计算本月实际收入
  double _calculateMonthlyIncome() {
    final transactions = ref.read(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  void _initCategories() {
    // 初始分配为0，用户需要手动分配或使用智能分配
    _categories = [
      BudgetCategory(
        id: 'savings',
        name: '储蓄优先',
        icon: Icons.savings,
        color: Colors.green,
        amount: 0,
        percentage: 0.20,
        hint: '推荐20%',
        isHighlighted: true,
      ),
      BudgetCategory(
        id: 'fixed',
        name: '固定支出',
        icon: Icons.home,
        color: Colors.blue,
        amount: 0,
        percentage: 0.33,
        hint: '房租、水电、通讯',
      ),
      BudgetCategory(
        id: 'living',
        name: '生活消费',
        icon: Icons.restaurant,
        color: Colors.orange,
        amount: 0,
        percentage: 0.27,
        hint: '餐饮、购物、交通',
      ),
      BudgetCategory(
        id: 'flexible',
        name: '弹性支出',
        icon: Icons.celebration,
        color: Colors.purple,
        amount: 0,
        percentage: 0.20,
        hint: '娱乐、社交',
      ),
    ];
  }

  double get _totalAllocated =>
      _categories.fold(0.0, (sum, c) => sum + c.amount);

  double get _remaining => _calculateMonthlyIncome() - _totalAllocated;

  bool get _isBalanced => _remaining.abs() < 0.01;

  @override
  Widget build(BuildContext context) {
    final monthlyIncome = _calculateMonthlyIncome();

    return Scaffold(
      appBar: AppBar(
        title: const Text('零基预算分配'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 可分配收入卡片
          _IncomeCard(
            totalIncome: monthlyIncome,
            incomeDetails: monthlyIncome > 0 ? '本月实际收入' : '暂无收入记录',
          ),

          const SizedBox(height: 12),

          // 零基预算原则说明
          _PrincipleCard(),

          const SizedBox(height: 12),

          // 快速分配按钮组
          if (monthlyIncome > 0)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToSmartAllocation(monthlyIncome),
                    icon: const Icon(Icons.psychology, size: 18),
                    label: const Text('智能分配'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _allocateByRecommendation,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('推荐比例'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // 预算分配标题
          Text(
            '预算分配',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 12),

          // 预算分配列表
          _BudgetAllocationCard(
            categories: _categories,
            onAmountChanged: (id, amount) {
              setState(() {
                final category = _categories.firstWhere((c) => c.id == id);
                category.amount = amount;
                category.percentage = monthlyIncome > 0 ? amount / monthlyIncome : 0;
              });
            },
          ),

          const SizedBox(height: 16),

          // 零基预算结果
          _BalanceResultCard(
            remaining: _remaining,
            isBalanced: _isBalanced,
          ),

          const SizedBox(height: 80),
        ],
      ),
      bottomSheet: _BottomActionBar(
        isBalanced: _isBalanced,
        onConfirm: _confirmBudget,
      ),
    );
  }

  /// 跳转到智能分配页面
  void _navigateToSmartAllocation(double income) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartAllocationPage(
          incomeAmount: income,
          incomeSource: '本月收入',
        ),
      ),
    );

    // 如果智能分配返回了数据，应用到当前页面
    if (result != null && result is Map<String, double>) {
      setState(() {
        for (final category in _categories) {
          if (result.containsKey(category.id)) {
            category.amount = result[category.id]!;
            category.percentage = income > 0 ? category.amount / income : 0;
          }
        }
      });
    }
  }

  void _confirmBudget() {
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('还有 ¥${_remaining.toStringAsFixed(0)} 未分配'),
          action: SnackBarAction(
            label: '自动分配',
            onPressed: _autoAllocate,
          ),
        ),
      );
      return;
    }

    Navigator.pop(context, _categories);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('零基预算设置成功')),
    );
  }

  void _autoAllocate() {
    // 将剩余金额分配到弹性支出
    setState(() {
      final flexible = _categories.firstWhere((c) => c.id == 'flexible');
      flexible.amount += _remaining;
      final monthlyIncome = _calculateMonthlyIncome();
      flexible.percentage = monthlyIncome > 0 ? flexible.amount / monthlyIncome : 0;
    });
  }

  /// 按推荐比例自动分配
  void _allocateByRecommendation() {
    final monthlyIncome = _calculateMonthlyIncome();
    if (monthlyIncome <= 0) return;

    setState(() {
      for (final category in _categories) {
        category.amount = monthlyIncome * category.percentage;
      }
    });
  }
}

/// 收入卡片
class _IncomeCard extends StatelessWidget {
  final double totalIncome;
  final String incomeDetails;

  const _IncomeCard({
    required this.totalIncome,
    required this.incomeDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '本月可分配收入',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${totalIncome.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            incomeDetails,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// 零基预算原则说明
class _PrincipleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue[600], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: const [
                  TextSpan(
                    text: '零基预算原则：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '每分钱都有去处，收入 - 支出 - 储蓄 = 0'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 预算分配卡片
class _BudgetAllocationCard extends StatelessWidget {
  final List<BudgetCategory> categories;
  final Function(String id, double amount) onAmountChanged;

  const _BudgetAllocationCard({
    required this.categories,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isLast = index == categories.length - 1;

          return _CategoryItem(
            category: category,
            showDivider: !isLast,
            onAmountChanged: (amount) => onAmountChanged(category.id, amount),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final BudgetCategory category;
  final bool showDivider;
  final ValueChanged<double> onAmountChanged;

  const _CategoryItem({
    required this.category,
    required this.showDivider,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: category.isHighlighted ? Colors.green[50] : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        category.hint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${category.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(category.percentage * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: category.isHighlighted
                            ? Colors.green[600]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showDivider)
            Divider(height: 1, color: Colors.grey[200]),
        ],
      ),
    );
  }
}

/// 零基预算结果卡片
class _BalanceResultCard extends StatelessWidget {
  final double remaining;
  final bool isBalanced;

  const _BalanceResultCard({
    required this.remaining,
    required this.isBalanced,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '收入 - 支出 - 储蓄',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '= ¥${remaining.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isBalanced ? Colors.green[600] : Colors.orange[600],
            ),
          ),
          const SizedBox(height: 8),
          if (isBalanced)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                const SizedBox(width: 4),
                Text(
                  '完美的零基预算',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[600],
                  ),
                ),
              ],
            )
          else
            Text(
              '还有 ¥${remaining.toStringAsFixed(0)} 待分配',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange[600],
              ),
            ),
        ],
      ),
    );
  }
}

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  final bool isBalanced;
  final VoidCallback onConfirm;

  const _BottomActionBar({
    required this.isBalanced,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: isBalanced ? null : Colors.orange,
          ),
          child: Text(isBalanced ? '确认预算方案' : '完成分配'),
        ),
      ),
    );
  }
}

/// 预算分类数据模型
class BudgetCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  double amount;
  double percentage;
  final String hint;
  final bool isHighlighted;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.hint,
    this.isHighlighted = false,
  });
}
