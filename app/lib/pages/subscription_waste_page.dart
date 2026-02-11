import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/recurring_provider.dart';

/// 订阅管理页面
///
/// 基于真实的周期性交易数据（recurringProvider）展示订阅/固定支出
class SubscriptionWastePage extends ConsumerWidget {
  const SubscriptionWastePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRecurring = ref.watch(recurringProvider);
    // 只看支出类的周期性交易
    final subscriptions = allRecurring
        .where((r) => r.type == TransactionType.expense)
        .toList();

    final active = subscriptions.where((r) => r.isEnabled).toList();
    final inactive = subscriptions.where((r) => !r.isEnabled).toList();

    final totalMonthly = active.fold(0.0, (sum, r) => sum + _toMonthly(r));

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅管理'),
      ),
      body: subscriptions.isEmpty
          ? _buildEmptyState()
          : ListView(
              children: [
                _OverviewCard(
                  totalMonthly: totalMonthly,
                  activeCount: active.length,
                ),
                if (active.isNotEmpty) ...[
                  const _SectionHeader(title: '活跃订阅'),
                  ...active.map((r) => _SubscriptionCard(
                    recurring: r,
                    monthlyFee: _toMonthly(r),
                  )),
                ],
                if (inactive.isNotEmpty) ...[
                  const _SectionHeader(title: '已停用', color: Colors.grey),
                  ...inactive.map((r) => _SubscriptionCard(
                    recurring: r,
                    monthlyFee: _toMonthly(r),
                    isInactive: true,
                  )),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.autorenew, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无周期性支出',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('添加周期性交易后，这里会自动展示',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  static double _toMonthly(RecurringTransaction r) {
    switch (r.frequency) {
      case RecurringFrequency.daily: return r.amount * 30;
      case RecurringFrequency.weekly: return r.amount * 4.33;
      case RecurringFrequency.monthly: return r.amount;
      case RecurringFrequency.yearly: return r.amount / 12;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;
  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      )),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final double totalMonthly;
  final int activeCount;
  const _OverviewCard({required this.totalMonthly, required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('每月固定支出',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              Text('¥${totalMonthly.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('活跃项目',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              Text('$activeCount个',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final RecurringTransaction recurring;
  final double monthlyFee;
  final bool isInactive;

  const _SubscriptionCard({
    required this.recurring,
    required this.monthlyFee,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cat = DefaultCategories.findById(recurring.category);
    final catName = cat?.name ?? recurring.category;
    final lastExec = recurring.lastExecutedAt;
    final daysAgo = lastExec != null
        ? DateTime.now().difference(lastExec).inDays : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInactive
            ? Colors.grey[100]
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: recurring.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(recurring.icon, color: recurring.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recurring.name, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: isInactive ? Colors.grey : null,
                )),
                const SizedBox(height: 2),
                Text(
                  '$catName · ${recurring.frequencyName}'
                  '${daysAgo != null ? " · 上次执行：${_formatDaysAgo(daysAgo)}" : ""}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '¥${monthlyFee.toStringAsFixed(0)}/月',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: isInactive ? Colors.grey : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDaysAgo(int days) {
    if (days == 0) return '今天';
    if (days == 1) return '昨天';
    if (days < 30) return '$days天前';
    return '${days ~/ 30}个月前';
  }
}
