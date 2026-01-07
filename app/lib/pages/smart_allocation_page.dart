import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 智能分配建议页面
///
/// 对应原型设计 3.05 智能分配建议
/// 展示AI智能规划的分配方案，按优先级排序
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
    _generateSmartAllocations();
  }

  void _generateSmartAllocations() {
    // 模拟智能分配方案
    _allocations = [
      AllocationItem(
        id: '1',
        name: '房租',
        icon: Icons.home,
        color: Colors.red,
        priority: 1,
        priorityLabel: 'P1',
        amount: 4000,
        type: AllocationPriorityType.fixed,
        reason: '固定支出 · 必须优先保障',
      ),
      AllocationItem(
        id: '2',
        name: '信用卡还款',
        icon: Icons.credit_card,
        color: Colors.orange,
        priority: 2,
        priorityLabel: 'P2',
        amount: 2500,
        type: AllocationPriorityType.debt,
        reason: '债务还款 · 避免利息和信用影响',
      ),
      AllocationItem(
        id: '3',
        name: '应急金储备',
        icon: Icons.savings,
        color: Colors.green,
        priority: 3,
        priorityLabel: 'P3',
        amount: 3000,
        type: AllocationPriorityType.savings,
        reason: '储蓄目标 · 建议储蓄20%收入',
      ),
      AllocationItem(
        id: '4',
        name: '餐饮 + 娱乐',
        icon: Icons.restaurant,
        color: Colors.blue,
        priority: 4,
        priorityLabel: 'P4',
        amount: 4500,
        type: AllocationPriorityType.flexible,
        reason: '弹性支出 · 分配剩余金额',
      ),
    ];

    final totalAllocated = _allocations.fold(0.0, (sum, item) => sum + item.amount);
    _unallocated = widget.incomeAmount - totalAllocated;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能分配建议'),
        actions: [
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
            child: ListView(
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
            color: Colors.black.withOpacity(0.05),
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
                  color: _getPriorityColor(item.priority).withOpacity(0.1),
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
              Text(
                item.reason,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
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
            color: Colors.black.withOpacity(0.1),
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
  });
}

enum AllocationPriorityType {
  fixed,
  debt,
  savings,
  flexible,
}
