import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// FIFO资源池页面
/// 原型设计 2.07：FIFO资源池
/// - 说明卡片：FIFO原则解释
/// - 资源池列表：已消耗完、部分消耗、当前消费中、待使用
/// - 总结卡片：可用资金、平均钱龄、活跃资源池数
class MoneyAgeResourcePoolPage extends ConsumerWidget {
  const MoneyAgeResourcePoolPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildInfoCard(context, theme),
                    _buildResourcePoolList(context, theme),
                    _buildSummaryCard(context, theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              '资金池状态',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _showHelpDialog(context),
            child: Icon(
              Icons.help_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('什么是FIFO资金池？'),
        content: const Text(
          'FIFO（先进先出）是一种资金追踪原则：\n\n'
          '• 每笔收入创建一个资金池\n'
          '• 支出时优先消耗最早的资金池\n'
          '• 这样可以准确追踪每笔支出的资金来源\n\n'
          '通过FIFO原则，您可以了解：\n'
          '1. 当前花的钱是什么时候赚的\n'
          '2. 哪些收入已经被花完\n'
          '3. 还有多少储备资金',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEBF3FF), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '资金池按先进先出(FIFO)原则消耗，越早的收入越先被花掉',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcePoolList(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // 已消耗完
          _buildPoolItem(
            context,
            theme,
            name: '11月工资',
            date: '11月15日',
            amount: 15000,
            remaining: 0,
            status: PoolStatus.consumed,
          ),
          const SizedBox(height: 8),
          // 部分消耗
          _buildPoolItem(
            context,
            theme,
            name: '12月工资',
            date: '12月15日',
            amount: 15000,
            remaining: 3200,
            status: PoolStatus.partial,
          ),
          const SizedBox(height: 8),
          // 当前消费中
          _buildPoolItem(
            context,
            theme,
            name: '1月工资',
            date: '1月5日',
            amount: 15000,
            remaining: 12800,
            status: PoolStatus.current,
          ),
          const SizedBox(height: 8),
          // 待使用
          _buildPoolItem(
            context,
            theme,
            name: '年终奖',
            date: '12月25日',
            amount: 8000,
            remaining: 8000,
            status: PoolStatus.pending,
          ),
        ],
      ),
    );
  }

  Widget _buildPoolItem(
    BuildContext context,
    ThemeData theme, {
    required String name,
    required String date,
    required double amount,
    required double remaining,
    required PoolStatus status,
  }) {
    Color borderColor;
    Color bgColor;
    Widget statusIcon;
    String statusText;
    Color? progressColor;

    switch (status) {
      case PoolStatus.consumed:
        borderColor = theme.colorScheme.outline;
        bgColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        );
        statusText = '已用完';
        progressColor = theme.colorScheme.outline;
        break;
      case PoolStatus.partial:
        borderColor = AppColors.warning;
        bgColor = theme.colorScheme.surface;
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_bottom, color: Colors.white, size: 16),
        );
        statusText = '剩余';
        progressColor = AppColors.warning;
        break;
      case PoolStatus.current:
        borderColor = AppColors.success;
        bgColor = const Color(0xFFE8F5E9);
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
        );
        statusText = '剩余';
        progressColor = AppColors.success;
        break;
      case PoolStatus.pending:
        borderColor = theme.colorScheme.primary;
        bgColor = theme.colorScheme.surface;
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.schedule, color: theme.colorScheme.primary, size: 16),
        );
        statusText = '待使用';
        progressColor = theme.colorScheme.primary;
        break;
    }

    final used = amount - remaining;
    final remainPercent = (remaining / amount * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: status != PoolStatus.consumed
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              statusIcon,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (status == PoolStatus.current) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '$date · ¥${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (status != PoolStatus.consumed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${remaining.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: progressColor,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: status == PoolStatus.consumed
                  ? theme.colorScheme.outline
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: remaining / amount,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          if (status != PoolStatus.consumed) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status == PoolStatus.pending
                      ? '100% 未使用'
                      : '已用 ¥${used.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (status != PoolStatus.pending)
                  Text(
                    '剩余 $remainPercent%',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            theme,
            value: '¥24,000',
            label: '可用资金',
            valueColor: theme.colorScheme.primary,
          ),
          Container(width: 1, height: 40, color: theme.dividerColor),
          _buildSummaryItem(
            theme,
            value: '42天',
            label: '平均钱龄',
            valueColor: AppColors.success,
          ),
          Container(width: 1, height: 40, color: theme.dividerColor),
          _buildSummaryItem(
            theme,
            value: '3',
            label: '活跃资源池',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    ThemeData theme, {
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

enum PoolStatus {
  consumed, // 已消耗完
  partial, // 部分消耗
  current, // 当前消费中
  pending, // 待使用
}
