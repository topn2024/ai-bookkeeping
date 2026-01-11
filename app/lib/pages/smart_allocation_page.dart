import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/recurring_provider.dart';
import '../providers/budget_provider.dart';

/// 智能分配建议页面
///
/// 对应原型设计 3.05 智能分配建议
/// 展示AI智能规划的分配方案，按优先级排序
/// 数据来源：recurringProvider（周期性支出）、budgetProvider（预算）
class SmartAllocationPage extends ConsumerStatefulWidget {
  final double incomeAmount;
  final String incomeSource;

  const SmartAllocationPage({
    super.key,
    required this.incomeAmount,
    this.incomeSource = '本月工资',
  });

  @override
  ConsumerState<SmartAllocationPage> createState() => _SmartAllocationPageState();
}

class _SmartAllocationPageState extends ConsumerState<SmartAllocationPage> {
  List<AllocationItem> _allocations = [];
  double _unallocated = 0;

  @override
  void initState() {
    super.initState();
  }

  /// 根据周期性交易和预算数据生成智能分配方案
  void _generateSmartAllocations(
    List<RecurringTransaction> recurring,
    List<BudgetUsage> budgetUsages,
  ) {
    final allocations = <AllocationItem>[];
    int priorityId = 1;

    // P1: 固定支出 - 从启用的周期性支出交易获取
    final fixedExpenses = recurring
        .where((r) => r.isEnabled && r.type == TransactionType.expense)
        .where((r) => _isFixedExpenseCategory(r.category))
        .toList();

    double totalFixed = 0;
    for (final expense in fixedExpenses) {
      final monthlyAmount = _getMonthlyAmount(expense);
      if (monthlyAmount > 0) {
        totalFixed += monthlyAmount;
      }
    }

    if (totalFixed > 0) {
      allocations.add(AllocationItem(
        id: priorityId.toString(),
        name: '固定支出',
        icon: Icons.home,
        color: Colors.red,
        priority: 1,
        priorityLabel: 'P1',
        amount: totalFixed,
        type: AllocationPriorityType.fixed,
        reason: '固定支出 · 必须优先保障',
        details: fixedExpenses.map((e) => '${e.name}: ¥${_getMonthlyAmount(e).toStringAsFixed(0)}').toList(),
      ));
      priorityId++;
    }

    // P2: 债务还款 - 从包含债务相关分类的周期性交易获取
    final debtPayments = recurring
        .where((r) => r.isEnabled && r.type == TransactionType.expense)
        .where((r) => _isDebtCategory(r.category))
        .toList();

    double totalDebt = 0;
    for (final debt in debtPayments) {
      final monthlyAmount = _getMonthlyAmount(debt);
      if (monthlyAmount > 0) {
        totalDebt += monthlyAmount;
      }
    }

    if (totalDebt > 0) {
      allocations.add(AllocationItem(
        id: priorityId.toString(),
        name: '债务还款',
        icon: Icons.credit_card,
        color: Colors.orange,
        priority: 2,
        priorityLabel: 'P2',
        amount: totalDebt,
        type: AllocationPriorityType.debt,
        reason: '债务还款 · 避免利息和信用影响',
        details: debtPayments.map((e) => '${e.name}: ¥${_getMonthlyAmount(e).toStringAsFixed(0)}').toList(),
      ));
      priorityId++;
    }

    // P3: 储蓄目标 - 建议储蓄收入的20%
    final suggestedSavings = widget.incomeAmount * 0.2;
    final remainingAfterFixedAndDebt = widget.incomeAmount - totalFixed - totalDebt;
    final actualSavings = suggestedSavings.clamp(0.0, remainingAfterFixedAndDebt * 0.5);

    if (actualSavings > 0) {
      allocations.add(AllocationItem(
        id: priorityId.toString(),
        name: '储蓄目标',
        icon: Icons.savings,
        color: Colors.green,
        priority: 3,
        priorityLabel: 'P3',
        amount: actualSavings,
        type: AllocationPriorityType.savings,
        reason: '储蓄目标 · 建议储蓄20%收入',
      ));
      priorityId++;
    }

    // P4: 弹性支出 - 剩余金额用于日常消费
    final flexibleAmount = widget.incomeAmount - totalFixed - totalDebt - actualSavings;
    if (flexibleAmount > 0) {
      // 从预算中获取日常消费分类
      final flexibleCategories = budgetUsages
          .where((u) => _isFlexibleCategory(u.budget.categoryId))
          .map((u) => u.budget.categoryId)
          .whereType<String>()
          .toList();

      allocations.add(AllocationItem(
        id: priorityId.toString(),
        name: '日常消费',
        icon: Icons.restaurant,
        color: Colors.blue,
        priority: 4,
        priorityLabel: 'P4',
        amount: flexibleAmount,
        type: AllocationPriorityType.flexible,
        reason: '弹性支出 · 分配剩余金额',
        details: flexibleCategories.isEmpty
            ? null
            : flexibleCategories.map((c) {
                final cat = DefaultCategories.findById(c);
                return cat?.name ?? c;
              }).take(3).toList(),
      ));
    }

    // 如果没有任何周期性数据，显示默认的分配建议
    if (allocations.isEmpty) {
      // 使用标准50/30/20规则
      final needs = widget.incomeAmount * 0.5;  // 50% 必要支出
      final wants = widget.incomeAmount * 0.3;  // 30% 弹性支出
      final savings = widget.incomeAmount * 0.2; // 20% 储蓄

      allocations.addAll([
        AllocationItem(
          id: '1',
          name: '必要支出',
          icon: Icons.home,
          color: Colors.red,
          priority: 1,
          priorityLabel: 'P1',
          amount: needs,
          type: AllocationPriorityType.fixed,
          reason: '建议将50%用于必要支出（房租、水电等）',
        ),
        AllocationItem(
          id: '2',
          name: '弹性支出',
          icon: Icons.restaurant,
          color: Colors.blue,
          priority: 2,
          priorityLabel: 'P2',
          amount: wants,
          type: AllocationPriorityType.flexible,
          reason: '建议将30%用于日常消费（餐饮、娱乐等）',
        ),
        AllocationItem(
          id: '3',
          name: '储蓄目标',
          icon: Icons.savings,
          color: Colors.green,
          priority: 3,
          priorityLabel: 'P3',
          amount: savings,
          type: AllocationPriorityType.savings,
          reason: '建议将20%存入储蓄',
        ),
      ]);
    }

    _allocations = allocations;
    final totalAllocated = _allocations.fold(0.0, (sum, item) => sum + item.amount);
    _unallocated = widget.incomeAmount - totalAllocated;
  }

  /// 判断是否为固定支出分类（房租、水电、物业等）
  bool _isFixedExpenseCategory(String category) {
    final fixedCategories = ['房租', '水电', '物业', '保险', '通讯', '网费', '话费', 'rent', 'utilities'];
    return fixedCategories.any((c) => category.toLowerCase().contains(c.toLowerCase()));
  }

  /// 判断是否为债务分类（信用卡、贷款等）
  bool _isDebtCategory(String category) {
    final debtCategories = ['信用卡', '贷款', '还款', '花呗', '借呗', '白条', 'credit', 'loan', 'debt'];
    return debtCategories.any((c) => category.toLowerCase().contains(c.toLowerCase()));
  }

  /// 判断是否为弹性支出分类
  bool _isFlexibleCategory(String? category) {
    if (category == null) return false;
    final flexibleCategories = ['餐饮', '娱乐', '购物', '交通', '美容', '服饰', 'food', 'entertainment', 'shopping'];
    return flexibleCategories.any((c) => category.toLowerCase().contains(c.toLowerCase()));
  }

  /// 将周期性交易金额转换为月度金额
  double _getMonthlyAmount(RecurringTransaction recurring) {
    switch (recurring.frequency) {
      case RecurringFrequency.daily:
        return recurring.amount * 30;
      case RecurringFrequency.weekly:
        return recurring.amount * 4;
      case RecurringFrequency.monthly:
        return recurring.amount;
      case RecurringFrequency.yearly:
        return recurring.amount / 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取真实数据
    final recurring = ref.watch(recurringProvider);
    final budgetUsages = ref.watch(allBudgetUsagesProvider);

    // 如果分配列表为空，则生成分配方案
    if (_allocations.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _generateSmartAllocations(recurring, budgetUsages);
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能分配建议'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _allocations.clear();
                _generateSmartAllocations(recurring, budgetUsages);
              });
            },
            tooltip: '重新生成方案',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 待分配金额卡片
          _IncomeCard(
            amount: widget.incomeAmount,
            source: widget.incomeSource,
          ),

          // 分配优先级说明
          _PriorityHint(),

          // 分配建议列表
          Expanded(
            child: _allocations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ..._allocations.map((item) => _AllocationItemCard(
                        item: item,
                        onAmountChanged: (amount) {
                          setState(() {
                            item.amount = amount;
                            final total = _allocations.fold(0.0, (sum, i) => sum + i.amount);
                            _unallocated = widget.incomeAmount - total;
                          });
                        },
                      )),

                      // 未分配金额
                      if (_unallocated > 0)
                        _UnallocatedCard(amount: _unallocated),

                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
      bottomSheet: _BottomActionBar(
        onApply: _applyAllocation,
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('智能分配说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('系统根据您的消费习惯和财务目标，智能规划分配方案：'),
            SizedBox(height: 12),
            Text('P1 固定支出：房租、水电等必须支出'),
            Text('P2 债务还款：信用卡、贷款等'),
            Text('P3 储蓄目标：建议储蓄20%收入'),
            Text('P4 弹性支出：餐饮、娱乐等日常消费'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _applyAllocation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认应用'),
        content: Text('即将按智能方案分配 ¥${widget.incomeAmount.toStringAsFixed(0)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, _allocations);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分配方案已应用')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 收入卡片
class _IncomeCard extends StatelessWidget {
  final double amount;
  final String source;

  const _IncomeCard({
    required this.amount,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[400]!, Colors.purple[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$source待分配',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '系统已为您智能规划分配方案',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// 优先级提示
class _PriorityHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.orange[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '分配顺序：固定支出 → 债务还款 → 储蓄目标 → 弹性支出',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分配项卡片
class _AllocationItemCard extends StatelessWidget {
  final AllocationItem item;
  final ValueChanged<double> onAmountChanged;

  const _AllocationItemCard({
    required this.item,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _getPriorityColor(item.priority),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(item.priority).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.priorityLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getPriorityColor(item.priority),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '¥${item.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _getTypeIcon(item.type),
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.reason,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          // 显示详细分项（如果有）
          if (item.details != null && item.details!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: item.details!.map((detail) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(AllocationPriorityType type) {
    switch (type) {
      case AllocationPriorityType.fixed:
        return Icons.lock;
      case AllocationPriorityType.debt:
        return Icons.credit_card;
      case AllocationPriorityType.savings:
        return Icons.savings;
      case AllocationPriorityType.flexible:
        return Icons.tune;
    }
  }
}

/// 未分配金额卡片
class _UnallocatedCard extends StatelessWidget {
  final double amount;

  const _UnallocatedCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                '剩余未分配',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¥${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  final VoidCallback onApply;

  const _BottomActionBar({required this.onApply});

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
        child: ElevatedButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('一键应用智能方案'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ),
    );
  }
}

/// 分配项数据模型
class AllocationItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int priority;
  final String priorityLabel;
  double amount;
  final AllocationPriorityType type;
  final String reason;
  final List<String>? details;  // 分配详情（如具体的支出项）

  AllocationItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.priority,
    required this.priorityLabel,
    required this.amount,
    required this.type,
    required this.reason,
    this.details,
  });
}

enum AllocationPriorityType {
  fixed,
  debt,
  savings,
  flexible,
}
