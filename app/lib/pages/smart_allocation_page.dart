import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/recurring_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/smart_budget_engine.dart';

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
  List<String> _insights = [];
  double _unallocated = 0;

  @override
  void initState() {
    super.initState();
  }

  /// 使用智能预算引擎生成分配方案
  void _generateSmartAllocations(
    List<RecurringTransaction> recurring,
    List<BudgetUsage> budgetUsages,
  ) {
    final transactions = ref.read(transactionProvider);

    final engine = SmartBudgetEngine(
      monthlyIncome: widget.incomeAmount,
      allTransactions: transactions,
      recurringTransactions: recurring,
    );

    final result = engine.generate();

    // 转换为页面使用的 AllocationItem 格式
    _allocations = result.items.map((item) => AllocationItem(
      id: item.id,
      name: item.name,
      icon: item.icon,
      color: item.color,
      priority: item.priority,
      priorityLabel: 'P${item.priority}',
      amount: item.amount,
      type: _mapCategory(item.type),
      reason: item.reason,
      details: item.details,
    )).toList();

    _insights = result.insights;
    _unallocated = widget.incomeAmount - result.totalAllocated;
  }

  AllocationPriorityType _mapCategory(AllocationCategory cat) {
    switch (cat) {
      case AllocationCategory.fixed:
        return AllocationPriorityType.fixed;
      case AllocationCategory.savings:
        return AllocationPriorityType.savings;
      case AllocationCategory.flexible:
        return AllocationPriorityType.flexible;
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

    // 收入为0时的提示状态
    final isZeroIncome = widget.incomeAmount <= 0;

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
            child: isZeroIncome
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            '本月暂无收入记录',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请先记录收入，智能分配将根据收入金额生成预算方案',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : _allocations.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // 智能洞察
                          if (_insights.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _insights.map((insight) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    insight,
                                    style: const TextStyle(fontSize: 12, height: 1.5),
                                  ),
                                )).toList(),
                              ),
                            ),

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
    final transactions = ref.read(transactionProvider);
    final hasData = transactions.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('智能分配说明'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hasData
              ? '系统分析了您过去3个月的消费记录，为您生成个性化分配方案：'
              : '由于暂无历史数据，系统使用合理的默认比例为您生成分配方案：'),
            const SizedBox(height: 12),
            const Text('P1 固定支出：房租、水电等必要支出'),
            const Text('P2 储蓄优先：建议储蓄20%收入'),
            const Text('P3+ 日常消费：餐饮、交通、购物、娱乐等'),
            const SizedBox(height: 12),
            Text(
              hasData
                ? '💡 基于您的消费习惯，分配金额会随消费变化而调整'
                : '💡 记录一段时间后，系统会根据您的消费习惯优化方案',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
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
    // 调试信息
    final totalAllocated = _allocations.fold(0.0, (sum, item) => sum + item.amount);
    print('🔍 [SmartAllocation] 收入: ${widget.incomeAmount}');
    print('🔍 [SmartAllocation] 分配总额: $totalAllocated');
    print('🔍 [SmartAllocation] 差额: ${widget.incomeAmount - totalAllocated}');
    print('🔍 [SmartAllocation] 分类数量: ${_allocations.length}');
    for (final item in _allocations) {
      print('  - ${item.name}: ¥${item.amount}');
    }

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
              '分配原则：固定支出优先 → 储蓄20% → 剩余按消费习惯分配',
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
  String reason;
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
