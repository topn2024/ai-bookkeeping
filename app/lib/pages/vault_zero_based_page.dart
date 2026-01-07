import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// 零基预算分配页面
/// 原型设计 3.09：零基预算分配
/// - 本月可分配收入
/// - 零基预算原则说明
/// - 预算分配列表（储蓄优先、固定支出、生活消费、弹性支出）
/// - 收入 - 支出 - 储蓄 = 0 验证
class VaultZeroBasedPage extends ConsumerWidget {
  final double totalIncome;
  final double salary;
  final double sideIncome;

  const VaultZeroBasedPage({
    super.key,
    this.totalIncome = 15000,
    this.salary = 12000,
    this.sideIncome = 3000,
  });

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
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildIncomeCard(context, theme),
                    const SizedBox(height: 16),
                    _buildPrincipleHint(context, theme),
                    const SizedBox(height: 16),
                    _buildAllocationList(context, theme),
                    const SizedBox(height: 16),
                    _buildBalanceCard(context, theme),
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
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '零基预算分配',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 收入卡片
  Widget _buildIncomeCard(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6495ED), Color(0xFF87CEFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月可分配收入',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${totalIncome.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '= 工资¥${salary.toStringAsFixed(0)} + 副业¥${sideIncome.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// 零基预算原则说明
  Widget _buildPrincipleHint(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB3CFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: theme.colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                children: const [
                  TextSpan(
                    text: '零基预算原则：',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: '每分钱都有去处，收入 - 支出 - 储蓄 = 0'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 预算分配列表
  Widget _buildAllocationList(BuildContext context, ThemeData theme) {
    final allocations = [
      _ZeroBasedItem(
        icon: Icons.savings,
        iconColor: Colors.white,
        iconBgColor: const Color(0xFF66BB6A),
        name: '储蓄优先',
        subtitle: '推荐20%',
        amount: 3000,
        percent: 20,
        isHighlighted: true,
      ),
      _ZeroBasedItem(
        icon: Icons.home,
        iconColor: theme.colorScheme.primary,
        iconBgColor: theme.colorScheme.surfaceContainerHighest,
        name: '固定支出',
        subtitle: '房租、水电、通讯',
        amount: 5000,
        percent: 33,
      ),
      _ZeroBasedItem(
        icon: Icons.restaurant,
        iconColor: theme.colorScheme.primary,
        iconBgColor: theme.colorScheme.surfaceContainerHighest,
        name: '生活消费',
        subtitle: '餐饮、购物、交通',
        amount: 4000,
        percent: 27,
      ),
      _ZeroBasedItem(
        icon: Icons.celebration,
        iconColor: theme.colorScheme.primary,
        iconBgColor: theme.colorScheme.surfaceContainerHighest,
        name: '弹性支出',
        subtitle: '娱乐、社交',
        amount: 3000,
        percent: 20,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预算分配',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: allocations.map((item) {
              final isLast = item == allocations.last;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: item.isHighlighted
                      ? const Color(0xFFE8F5E9).withValues(alpha: 0.5)
                      : null,
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${item.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${item.percent}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isHighlighted
                                ? const Color(0xFF66BB6A)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 结余卡片
  Widget _buildBalanceCard(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '收入 - 支出 - 储蓄',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '= ¥0',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Text(
                '完美的零基预算',
                style: TextStyle(fontSize: 12, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZeroBasedItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String name;
  final String subtitle;
  final double amount;
  final int percent;
  final bool isHighlighted;

  _ZeroBasedItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.percent,
    this.isHighlighted = false,
  });
}
