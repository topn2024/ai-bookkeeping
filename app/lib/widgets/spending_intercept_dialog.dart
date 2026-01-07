import 'package:flutter/material.dart';

/// 消费拦截弹窗
///
/// 对应原型设计 3.08 消费拦截
/// 当消费超出小金库余额时显示的警告弹窗
class SpendingInterceptDialog extends StatelessWidget {
  final String categoryName;
  final String merchantName;
  final double spendingAmount;
  final double availableBalance;
  final VoidCallback? onCancel;
  final VoidCallback? onProceed;
  final VoidCallback? onTransfer;
  final VoidCallback? onModify;
  final VoidCallback? onMarkUnplanned;

  const SpendingInterceptDialog({
    super.key,
    required this.categoryName,
    required this.merchantName,
    required this.spendingAmount,
    required this.availableBalance,
    this.onCancel,
    this.onProceed,
    this.onTransfer,
    this.onModify,
    this.onMarkUnplanned,
  });

  static Future<SpendingInterceptResult?> show(
    BuildContext context, {
    required String categoryName,
    required String merchantName,
    required double spendingAmount,
    required double availableBalance,
  }) {
    return showModalBottomSheet<SpendingInterceptResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpendingInterceptDialog(
        categoryName: categoryName,
        merchantName: merchantName,
        spendingAmount: spendingAmount,
        availableBalance: availableBalance,
        onCancel: () => Navigator.pop(context, SpendingInterceptResult.cancel),
        onProceed: () => Navigator.pop(context, SpendingInterceptResult.proceed),
        onTransfer: () => Navigator.pop(context, SpendingInterceptResult.transfer),
        onModify: () => Navigator.pop(context, SpendingInterceptResult.modify),
        onMarkUnplanned: () => Navigator.pop(context, SpendingInterceptResult.unplanned),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 头部警告
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red[50],
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red[400]),
                  onPressed: onCancel,
                ),
                Expanded(
                  child: Text(
                    '预算提醒',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[600],
                    ),
                  ),
                ),
                const SizedBox(width: 48), // 平衡布局
              ],
            ),
          ),

          // 警告卡片
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[50]!, Colors.red[100]!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning,
                    size: 36,
                    color: Colors.red[400],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '预算余额不足',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$categoryName"小金库可用余额不足',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[400],
                  ),
                ),
              ],
            ),
          ),

          // 金额对比
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _AmountCard(
                    label: '本次消费',
                    amount: spendingAmount,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AmountCard(
                    label: '可用余额',
                    amount: availableBalance,
                    color: Colors.grey[800]!,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 消费详情
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🍜', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchantName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$categoryName · 刚刚',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '¥${spendingAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 解决方案
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '解决方案',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                _SolutionOption(
                  icon: Icons.swap_horiz,
                  iconColor: Colors.blue,
                  title: '从其他小金库调拨',
                  subtitle: '交通剩余¥280可用',
                  onTap: onTransfer,
                ),
                _SolutionOption(
                  icon: Icons.edit,
                  iconColor: Colors.orange,
                  title: '修改消费金额',
                  subtitle: '调整为¥${availableBalance.toStringAsFixed(0)}以内',
                  onTap: onModify,
                ),
                _SolutionOption(
                  icon: Icons.report,
                  iconColor: Colors.red,
                  title: '标记为计划外支出',
                  subtitle: '不计入预算统计',
                  onTap: onMarkUnplanned,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 底部按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('取消消费'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onProceed,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('仍要记录'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AmountCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SolutionOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}

enum SpendingInterceptResult {
  cancel,
  proceed,
  transfer,
  modify,
  unplanned,
}
