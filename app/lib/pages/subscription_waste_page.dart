import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/subscription_tracking_service.dart';
import '../providers/subscription_detection_provider.dart';

/// 订阅管理页面
///
/// 基于 AI 自动检测的周期性订阅数据展示
class SubscriptionWastePage extends ConsumerWidget {
  const SubscriptionWastePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubscriptions = ref.watch(detectedSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅管理'),
      ),
      body: asyncSubscriptions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('加载失败: $e',
                style: TextStyle(color: Colors.grey[600])),
          ),
        ),
        data: (subscriptions) {
          if (subscriptions.isEmpty) return _buildEmptyState();

          final wasted = subscriptions
              .where((s) => s.usageStatus.isWasted)
              .toList();
          final active = subscriptions
              .where((s) => !s.usageStatus.isWasted)
              .toList();

          final totalMonthly = subscriptions.fold(
              0.0, (sum, s) => sum + s.monthlyAmount);

          return ListView(
            children: [
              _OverviewCard(
                totalMonthly: totalMonthly,
                activeCount: subscriptions.length,
                wastedCount: wasted.length,
              ),
              if (wasted.isNotEmpty) ...[
                const _SectionHeader(title: '可能闲置', color: Colors.orange),
                ...wasted.map((s) => _SubscriptionCard(
                  subscription: s,
                  isWasted: true,
                )),
              ],
              if (active.isNotEmpty) ...[
                const _SectionHeader(title: '活跃订阅'),
                ...active.map((s) => _SubscriptionCard(
                  subscription: s,
                )),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
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
            Text('暂未检测到周期性订阅',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('需要至少6个月内同一商家2笔以上相同金额的支出',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
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
  final int wastedCount;
  const _OverviewCard({
    required this.totalMonthly,
    required this.activeCount,
    required this.wastedCount,
  });

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
              Text('每月订阅支出',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              Text('¥${totalMonthly.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$activeCount 项订阅',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              if (wastedCount > 0)
                Text('$wastedCount 项可能闲置',
                    style: const TextStyle(fontSize: 13, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionPattern subscription;
  final bool isWasted;

  const _SubscriptionCard({
    required this.subscription,
    this.isWasted = false,
  });

  @override
  Widget build(BuildContext context) {
    final daysAgo = DateTime.now()
        .difference(subscription.lastPaymentDate).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWasted
            ? Colors.orange.withValues(alpha: 0.05)
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
              color: (isWasted ? Colors.orange : Colors.blue)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isWasted ? Icons.warning_amber_rounded : Icons.autorenew,
              color: isWasted ? Colors.orange : Colors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subscription.merchantName, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 2),
                Text(
                  '${subscription.interval.displayName} · '
                  '¥${subscription.amount.toStringAsFixed(0)}/次 · '
                  '${subscription.usageStatus.displayName} · '
                  '上次: ${_formatDaysAgo(daysAgo)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '¥${subscription.monthlyAmount.toStringAsFixed(0)}/月',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: isWasted ? Colors.orange : null,
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
