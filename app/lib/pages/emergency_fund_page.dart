import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/budget_vault_provider.dart';
import '../providers/transaction_provider.dart';

/// 应急金目标页面
///
/// 对应原型设计 10.05 应急金目标
/// 设置和追踪应急储备金目标
class EmergencyFundPage extends ConsumerWidget {
  const EmergencyFundPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyVault = ref.watch(emergencyFundVaultProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);

    // 从应急基金小金库获取数据，如果没有则显示默认值
    final currentAmount = emergencyVault?.allocatedAmount ?? 0.0;
    final targetMonths = 3;
    final targetAmount = monthlyExpense > 0 ? monthlyExpense * targetMonths : emergencyVault?.targetAmount ?? 0.0;
    final monthsCovered = monthlyExpense > 0 ? currentAmount / monthlyExpense : 0.0;
    final progress = targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

    // 计算存款建议
    final remaining = targetAmount - currentAmount;
    final monthlyTarget = remaining > 0 ? (remaining / 6).clamp(500.0, remaining) : 0.0;
    final daysToGoal = monthlyTarget > 0 ? ((remaining / monthlyTarget) * 30).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('应急金目标'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context, monthlyExpense),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 进度卡片
          _ProgressCard(
            currentAmount: currentAmount,
            targetAmount: targetAmount,
            progress: progress,
            monthsCovered: monthsCovered,
          ),

          // 目标说明
          _GoalExplanationCard(
            monthlyExpense: monthlyExpense,
            targetMonths: 3,
          ),

          // 里程碑进度
          _MilestoneSection(progress: progress),

          // 存款建议
          _SavingSuggestionCard(
            monthlyTarget: monthlyTarget,
            daysToGoal: daysToGoal,
          ),

          // 快速操作
          _QuickActionsSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, double monthlyExpense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('应急金设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('目标月数'),
              subtitle: const Text('覆盖几个月的支出'),
              trailing: const Text('3个月'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('月均支出'),
              subtitle: const Text('用于计算目标金额'),
              trailing: Text('¥${monthlyExpense.toStringAsFixed(0)}'),
              onTap: () {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 进度卡片
class _ProgressCard extends StatelessWidget {
  final double currentAmount;
  final double targetAmount;
  final double progress;
  final double monthsCovered;

  const _ProgressCard({
    required this.currentAmount,
    required this.targetAmount,
    required this.progress,
    required this.monthsCovered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[300]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // 进度环
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '已完成',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 金额信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '已存金额',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '¥${currentAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '目标金额',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '¥${targetAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 覆盖月数
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '已可覆盖 ${monthsCovered.toStringAsFixed(1)} 个月支出',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 目标说明卡片
class _GoalExplanationCard extends StatelessWidget {
  final double monthlyExpense;
  final int targetMonths;

  const _GoalExplanationCard({
    required this.monthlyExpense,
    required this.targetMonths,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '为什么是这个目标？',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '根据您的月均支出 ¥${monthlyExpense.toStringAsFixed(0)}，建议储备 $targetMonths 个月的应急资金，以应对突发情况。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 里程碑区域
class _MilestoneSection extends StatelessWidget {
  final double progress;

  const _MilestoneSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    final milestones = [
      _Milestone(label: '1个月', value: 0.33, icon: '🌱'),
      _Milestone(label: '2个月', value: 0.66, icon: '🌿'),
      _Milestone(label: '3个月', value: 1.0, icon: '🌳'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '里程碑',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: milestones.map((m) {
              final achieved = progress >= m.value;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: achieved ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: achieved ? Colors.green : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(m.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: achieved ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                      if (achieved)
                        Icon(Icons.check_circle,
                            size: 16, color: Colors.green[700]),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Milestone {
  final String label;
  final double value;
  final String icon;

  _Milestone({required this.label, required this.value, required this.icon});
}

/// 存款建议卡片
class _SavingSuggestionCard extends StatelessWidget {
  final double monthlyTarget;
  final int daysToGoal;

  const _SavingSuggestionCard({
    required this.monthlyTarget,
    required this.daysToGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                '存款建议',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SuggestionItem(
                  label: '建议每月存入',
                  value: '¥${monthlyTarget.toStringAsFixed(0)}',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _SuggestionItem(
                  label: '预计达成',
                  value: '$daysToGoal天后',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final String label;
  final String value;

  const _SuggestionItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// 快速操作区域
class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '快速操作',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已存入 ¥500')),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('存入'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已设置自动存入')),
                    );
                  },
                  icon: const Icon(Icons.autorenew),
                  label: const Text('自动存入'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
