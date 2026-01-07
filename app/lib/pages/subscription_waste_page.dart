import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 订阅浪费识别页面
///
/// 对应原型设计 10.02 订阅浪费识别
/// 识别用户可能浪费的订阅服务
class SubscriptionWastePage extends ConsumerStatefulWidget {
  const SubscriptionWastePage({super.key});

  @override
  ConsumerState<SubscriptionWastePage> createState() =>
      _SubscriptionWastePageState();
}

class _SubscriptionWastePageState extends ConsumerState<SubscriptionWastePage> {
  final List<SubscriptionItem> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  void _loadSubscriptions() {
    _subscriptions.addAll([
      SubscriptionItem(
        id: '1',
        name: '网易云音乐会员',
        emoji: '🎵',
        monthlyFee: 15,
        lastUsed: DateTime.now().subtract(const Duration(days: 90)),
        status: SubscriptionStatus.wasted,
      ),
      SubscriptionItem(
        id: '2',
        name: '爱奇艺VIP',
        emoji: '📺',
        monthlyFee: 34,
        lastUsed: DateTime.now().subtract(const Duration(days: 45)),
        status: SubscriptionStatus.wasted,
      ),
      SubscriptionItem(
        id: '3',
        name: 'B站大会员',
        emoji: '📱',
        monthlyFee: 25,
        lastUsed: DateTime.now().subtract(const Duration(days: 3)),
        status: SubscriptionStatus.active,
      ),
      SubscriptionItem(
        id: '4',
        name: '微信读书会员',
        emoji: '📚',
        monthlyFee: 19,
        lastUsed: DateTime.now().subtract(const Duration(days: 1)),
        status: SubscriptionStatus.active,
      ),
      SubscriptionItem(
        id: '5',
        name: 'Keep会员',
        emoji: '💪',
        monthlyFee: 28,
        lastUsed: DateTime.now().subtract(const Duration(days: 14)),
        status: SubscriptionStatus.active,
      ),
      SubscriptionItem(
        id: '6',
        name: '百度网盘超级会员',
        emoji: '☁️',
        monthlyFee: 30,
        lastUsed: DateTime.now().subtract(const Duration(days: 7)),
        status: SubscriptionStatus.active,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final totalMonthly =
        _subscriptions.fold(0.0, (sum, s) => sum + s.monthlyFee);
    final activeCount =
        _subscriptions.where((s) => s.status != SubscriptionStatus.wasted).length;
    final wastedSubs =
        _subscriptions.where((s) => s.status == SubscriptionStatus.wasted).toList();
    final activeSubs =
        _subscriptions.where((s) => s.status != SubscriptionStatus.wasted).toList();
    final wastedYearly =
        wastedSubs.fold(0.0, (sum, s) => sum + s.monthlyFee * 12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
            onPressed: () => _showAddSubscriptionDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 订阅概览
          _OverviewCard(
            totalMonthly: totalMonthly,
            activeCount: activeCount,
          ),

          // 浪费预警
          if (wastedSubs.isNotEmpty)
            _WasteWarningCard(
              wastedCount: wastedSubs.length,
              yearlyWaste: wastedYearly,
            ),

          // 疑似浪费列表
          if (wastedSubs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '建议取消',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ),
            ...wastedSubs.map((s) => _SubscriptionCard(
                  subscription: s,
                  onCancel: () => _cancelSubscription(s),
                )),
          ],

          // 活跃订阅列表
          if (activeSubs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '活跃订阅',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...activeSubs.map((s) => _SubscriptionCard(
                  subscription: s,
                  onCancel: () => _cancelSubscription(s),
                )),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _cancelSubscription(SubscriptionItem subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消订阅'),
        content: Text('确定要取消「${subscription.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('再想想'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _subscriptions.remove(subscription);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已标记「${subscription.name}」为待取消')),
              );
            },
            child: const Text('确定取消'),
          ),
        ],
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final feeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '订阅名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '月费用',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('订阅已添加')),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

/// 概览卡片
class _OverviewCard extends StatelessWidget {
  final double totalMonthly;
  final int activeCount;

  const _OverviewCard({
    required this.totalMonthly,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '每月订阅总支出',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '¥${totalMonthly.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '活跃订阅',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '$activeCount个',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 浪费预警卡片
class _WasteWarningCard extends StatelessWidget {
  final int wastedCount;
  final double yearlyWaste;

  const _WasteWarningCard({
    required this.wastedCount,
    required this.yearlyWaste,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Colors.orange, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                '发现$wastedCount个可能不需要的订阅',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '取消后每年可节省 ¥${yearlyWaste.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// 订阅卡片
class _SubscriptionCard extends StatelessWidget {
  final SubscriptionItem subscription;
  final VoidCallback onCancel;

  const _SubscriptionCard({
    required this.subscription,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isWasted = subscription.status == SubscriptionStatus.wasted;
    final daysAgo = DateTime.now().difference(subscription.lastUsed).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWasted ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                subscription.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      subscription.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isWasted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCDD2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${daysAgo}天未使用',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFEF5350),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '¥${subscription.monthlyFee.toStringAsFixed(0)}/月 · 上次使用：${_formatLastUsed(daysAgo)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isWasted)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('取消'),
            )
          else
            Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  String _formatLastUsed(int daysAgo) {
    if (daysAgo == 0) return '今天';
    if (daysAgo == 1) return '昨天';
    if (daysAgo < 30) return '$daysAgo天前';
    final months = daysAgo ~/ 30;
    return '$months个月前';
  }
}

/// 订阅项数据模型
class SubscriptionItem {
  final String id;
  final String name;
  final String emoji;
  final double monthlyFee;
  final DateTime lastUsed;
  final SubscriptionStatus status;

  SubscriptionItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.monthlyFee,
    required this.lastUsed,
    required this.status,
  });
}

enum SubscriptionStatus {
  active,
  wasted,
  cancelled,
}
