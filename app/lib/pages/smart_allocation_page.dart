import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/recurring_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';

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

  /// 根据历史交易数据生成智能分配方案
  void _generateSmartAllocations(
    List<RecurringTransaction> recurring,
    List<BudgetUsage> budgetUsages,
  ) {
    // 获取历史交易数据
    final transactions = ref.read(transactionProvider);
    final allocations = <AllocationItem>[];
    int priorityId = 1;

    // 分析最近3个月的消费模式
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
    final recentExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(threeMonthsAgo))
        .toList();

    // 按分类统计平均月支出
    final categorySpending = <String, double>{};
    for (final expense in recentExpenses) {
      categorySpending[expense.category] =
          (categorySpending[expense.category] ?? 0) + expense.amount;
    }

    // 转换为月平均值
    final monthsDiff = now.difference(threeMonthsAgo).inDays / 30;
    categorySpending.forEach((category, total) {
      categorySpending[category] = total / monthsDiff.clamp(1, 3);
    });

    // 检测是否有历史数据
    final hasHistoryData = categorySpending.isNotEmpty;

    // 如果没有历史数据，使用冷启动方案
    if (!hasHistoryData) {
      _generateColdStartAllocation(allocations, priorityId);
    } else {
      // 有历史数据，基于实际消费生成智能分配
      _generateDataDrivenAllocation(allocations, priorityId, categorySpending);
    }

    _allocations = allocations;
    final totalAllocated = _allocations.fold(0.0, (sum, item) => sum + item.amount);
    _unallocated = widget.incomeAmount - totalAllocated;
  }

  /// 冷启动方案 - 没有历史数据时使用
  void _generateColdStartAllocation(List<AllocationItem> allocations, int startPriority) {
    // 使用合理的默认比例，总和=100%
    final coldStartPlan = [
      {'name': '固定支出', 'icon': Icons.home, 'color': Colors.red, 'percentage': 0.33, 'reason': '房租、水电、物业等必要支出', 'type': AllocationPriorityType.fixed},
      {'name': '储蓄优先', 'icon': Icons.savings, 'color': Colors.green, 'percentage': 0.20, 'reason': '先存后花，养成储蓄习惯', 'type': AllocationPriorityType.savings},
      {'name': '餐饮', 'icon': Icons.restaurant, 'color': Colors.orange, 'percentage': 0.20, 'reason': '日常三餐、外卖等', 'type': AllocationPriorityType.flexible},
      {'name': '交通', 'icon': Icons.directions_car, 'color': Colors.blue, 'percentage': 0.10, 'reason': '通勤、出行费用', 'type': AllocationPriorityType.flexible},
      {'name': '购物', 'icon': Icons.shopping_bag, 'color': Colors.purple, 'percentage': 0.10, 'reason': '服饰、日用品等', 'type': AllocationPriorityType.flexible},
      {'name': '娱乐', 'icon': Icons.celebration, 'color': Colors.pink, 'percentage': 0.07, 'reason': '电影、运动、游戏等', 'type': AllocationPriorityType.flexible},
    ];

    var priority = startPriority;
    for (final plan in coldStartPlan) {
      allocations.add(AllocationItem(
        id: priority.toString(),
        name: plan['name'] as String,
        icon: plan['icon'] as IconData,
        color: plan['color'] as Color,
        priority: priority,
        priorityLabel: 'P$priority',
        amount: widget.incomeAmount * (plan['percentage'] as double),
        type: plan['type'] as AllocationPriorityType,
        reason: '${plan['name']} · ${plan['reason']}',
      ));
      priority++;
    }
  }

  /// 基于历史数据的智能分配
  void _generateDataDrivenAllocation(
    List<AllocationItem> allocations,
    int startPriority,
    Map<String, double> categorySpending,
  ) {
    var priorityId = startPriority;

    // P1: 固定支出 - 基于历史数据识别
    double totalFixed = 0;
    final fixedDetails = <String>[];

    for (final entry in categorySpending.entries) {
      if (_isFixedExpenseCategory(entry.key)) {
        totalFixed += entry.value;
        final cat = DefaultCategories.findById(entry.key);
        fixedDetails.add('${cat?.name ?? entry.key}: ¥${entry.value.toStringAsFixed(0)}');
      }
    }

    if (totalFixed > 0) {
      allocations.add(AllocationItem(
        id: priorityId.toString(),
        name: '固定支出',
        icon: Icons.home,
        color: Colors.red,
        priority: priorityId,
        priorityLabel: 'P$priorityId',
        amount: totalFixed.clamp(0, widget.incomeAmount * 0.5),
        type: AllocationPriorityType.fixed,
        reason: '固定支出 · 基于过去3个月平均',
        details: fixedDetails.take(5).toList(),
      ));
      priorityId++;
    }

    // P2: 储蓄优先 - 建议20%
    final suggestedSavings = widget.incomeAmount * 0.2;
    final allocatedSoFar = allocations.fold(0.0, (sum, item) => sum + item.amount);
    final remainingAfterFixed = widget.incomeAmount - allocatedSoFar;
    final actualSavings = suggestedSavings.clamp(0.0, remainingAfterFixed * 0.4);

    if (actualSavings > 0) {
      allocations.add(AllocationItem(
        id: priorityId.toString(),
        name: '储蓄优先',
        icon: Icons.savings,
        color: Colors.green,
        priority: priorityId,
        priorityLabel: 'P$priorityId',
        amount: actualSavings,
        type: AllocationPriorityType.savings,
        reason: '储蓄目标 · 建议储蓄20%收入',
      ));
      priorityId++;
    }

    // P3-P6: 细分日常消费 - 基于历史数据
    final flexibleCategories = {
      '餐饮': {'keywords': ['餐饮', '美食', '食品', '外卖', 'food', '早餐', '午餐', '晚餐'], 'icon': Icons.restaurant, 'color': Colors.orange},
      '交通': {'keywords': ['交通', '出行', '打车', '公交', '地铁', 'transport'], 'icon': Icons.directions_car, 'color': Colors.blue},
      '购物': {'keywords': ['购物', '服饰', '美容', 'shopping', '电商'], 'icon': Icons.shopping_bag, 'color': Colors.purple},
      '娱乐': {'keywords': ['娱乐', '电影', '游戏', '运动', '健身', 'entertainment'], 'icon': Icons.celebration, 'color': Colors.pink},
    };

    // 收集所有弹性支出分类的历史数据
    final flexibleCategoryData = <String, Map<String, dynamic>>{};
    for (final entry in flexibleCategories.entries) {
      double categoryTotal = 0;
      final details = <String>[];

      for (final spending in categorySpending.entries) {
        final keywords = entry.value['keywords'] as List<String>;
        if (keywords.any((k) => spending.key.toLowerCase().contains(k.toLowerCase()))) {
          categoryTotal += spending.value;
          final cat = DefaultCategories.findById(spending.key);
          if (details.length < 3) {
            details.add('${cat?.name ?? spending.key}: ¥${spending.value.toStringAsFixed(0)}');
          }
        }
      }

      // 只添加有消费记录的分类（至少100元）
      if (categoryTotal > 100) {
        flexibleCategoryData[entry.key] = {
          'amount': categoryTotal,
          'icon': entry.value['icon'],
          'color': entry.value['color'],
          'details': details.isEmpty ? null : details,
        };
      }
    }

    // 计算已分配金额和剩余可用金额
    final totalAllocatedSoFar = allocations.fold(0.0, (sum, item) => sum + item.amount);
    final remainingForFlexible = (widget.incomeAmount - totalAllocatedSoFar).clamp(0.0, double.infinity);

    // 如果有剩余金额，按比例分配给弹性支出分类
    if (remainingForFlexible > 0 && flexibleCategoryData.isNotEmpty) {
      final totalFlexibleFromHistory = flexibleCategoryData.values.fold(0.0, (sum, data) => sum + (data['amount'] as double));

      for (final entry in flexibleCategoryData.entries) {
        final historyAmount = entry.value['amount'] as double;
        // 按历史比例分配剩余金额
        final allocatedAmount = totalFlexibleFromHistory > 0
            ? (historyAmount / totalFlexibleFromHistory * remainingForFlexible)
            : (remainingForFlexible / flexibleCategoryData.length);

        allocations.add(AllocationItem(
          id: priorityId.toString(),
          name: entry.key,
          icon: entry.value['icon'] as IconData,
          color: entry.value['color'] as Color,
          priority: priorityId,
          priorityLabel: 'P$priorityId',
          amount: allocatedAmount,
          type: AllocationPriorityType.flexible,
          reason: '${entry.key} · 基于过去3个月平均',
          details: entry.value['details'] as List<String>?,
        ));
        priorityId++;
      }
    }

    // 检查是否还有剩余金额（由于精度问题可能会有小额剩余）
    final totalAllocated = allocations.fold(0.0, (sum, item) => sum + item.amount);
    final remaining = widget.incomeAmount - totalAllocated;

    // 如果剩余金额>10元，添加到"其他弹性支出"
    // （小于10元的差额可能是精度问题，忽略）
    if (remaining > 10) {
      allocations.add(AllocationItem(
        id: priorityId.toString(),
        name: '其他弹性支出',
        icon: Icons.more_horiz,
        color: Colors.grey,
        priority: priorityId,
        priorityLabel: 'P$priorityId',
        amount: remaining,
        type: AllocationPriorityType.flexible,
        reason: '剩余可支配金额',
      ));
    } else if (remaining > 1) {
      // 小额剩余分配到第一个弹性支出分类
      if (allocations.isNotEmpty) {
        for (final item in allocations.reversed) {
          if (item.type == AllocationPriorityType.flexible) {
            item.amount += remaining;
            break;
          }
        }
      }
    }
  }

  /// 判断是否为固定支出分类（房租、水电、物业等）
  bool _isFixedExpenseCategory(String category) {
    final fixedCategories = ['房租', '水电', '物业', '保险', '通讯', '网费', '话费', 'rent', 'utilities'];
    return fixedCategories.any((c) => category.toLowerCase().contains(c.toLowerCase()));
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
