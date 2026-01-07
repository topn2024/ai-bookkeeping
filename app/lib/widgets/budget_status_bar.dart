import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/budget_vault.dart';

/// 预算状态条
///
/// 实时显示预算使用情况的可视化组件
/// 支持多种展示模式和动画效果
class BudgetStatusBar extends StatefulWidget {
  /// 小金库数据
  final BudgetVault vault;

  /// 是否显示详细信息
  final bool showDetails;

  /// 是否紧凑模式
  final bool compact;

  /// 是否显示动画
  final bool animate;

  /// 点击回调
  final VoidCallback? onTap;

  const BudgetStatusBar({
    super.key,
    required this.vault,
    this.showDetails = true,
    this.compact = false,
    this.animate = true,
    this.onTap,
  });

  @override
  State<BudgetStatusBar> createState() => _BudgetStatusBarState();
}

class _BudgetStatusBarState extends State<BudgetStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.vault.usageRate,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(BudgetStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vault.usageRate != widget.vault.usageRate) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.vault.usageRate,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactView(context);
    }
    return _buildFullView(context);
  }

  Widget _buildCompactView(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Container(
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // 进度条
                Expanded(
                  child: Stack(
                    children: [
                      // 背景
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      // 进度
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      // 文字
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.vault.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '¥${widget.vault.remainingAmount.toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullView(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();
    final vault = widget.vault;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                // 图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getVaultIcon(vault.name),
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),

                // 名称和状态
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vault.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getStatusText(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // 剩余金额
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '剩余',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      '¥${vault.remainingAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 进度条
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return _buildProgressBar(theme, statusColor);
              },
            ),

            // 详细信息
            if (widget.showDetails) ...[
              const SizedBox(height: 12),
              _buildDetailsRow(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme, Color statusColor) {
    final progress = _progressAnimation.value.clamp(0.0, 1.0);
    final isOverspent = widget.vault.usageRate > 1.0;

    return Column(
      children: [
        // 主进度条
        Stack(
          children: [
            // 背景
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // 进度
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.6),
                      statusColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // 超支指示器
            if (isOverspent)
              Positioned(
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 4),

        // 百分比标签
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已使用 ${(progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (isOverspent)
              Text(
                '超支 ¥${(widget.vault.spentAmount - widget.vault.allocatedAmount).toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsRow(ThemeData theme) {
    final vault = widget.vault;

    return Row(
      children: [
        // 预算
        Expanded(
          child: _buildDetailItem(
            theme,
            label: '预算',
            value: '¥${vault.allocatedAmount.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
        // 分隔线
        Container(
          height: 30,
          width: 1,
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        // 已花
        Expanded(
          child: _buildDetailItem(
            theme,
            label: '已花',
            value: '¥${vault.spentAmount.toStringAsFixed(0)}',
            icon: Icons.shopping_cart_outlined,
          ),
        ),
        // 分隔线
        Container(
          height: 30,
          width: 1,
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        // 日均可用
        Expanded(
          child: _buildDetailItem(
            theme,
            label: '日均可用',
            value: '¥${_calculateDailyBudget().toStringAsFixed(0)}',
            icon: Icons.calendar_today_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    final usageRate = widget.vault.usageRate;
    if (usageRate > 1.0) return Colors.red;
    if (usageRate > 0.9) return Colors.orange;
    if (usageRate > 0.7) return Colors.amber;
    return Colors.green;
  }

  String _getStatusText() {
    final usageRate = widget.vault.usageRate;
    if (usageRate > 1.0) return '已超支';
    if (usageRate > 0.9) return '预算紧张';
    if (usageRate > 0.7) return '正常使用';
    return '预算充足';
  }

  IconData _getVaultIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('餐') || lowerName.contains('吃')) {
      return Icons.restaurant;
    }
    if (lowerName.contains('交通') || lowerName.contains('出行')) {
      return Icons.directions_car;
    }
    if (lowerName.contains('购物') || lowerName.contains('衣')) {
      return Icons.shopping_bag;
    }
    if (lowerName.contains('娱乐') || lowerName.contains('玩')) {
      return Icons.sports_esports;
    }
    if (lowerName.contains('生活') || lowerName.contains('日常')) {
      return Icons.home;
    }
    return Icons.account_balance_wallet;
  }

  double _calculateDailyBudget() {
    final remaining = widget.vault.remainingAmount;
    if (remaining <= 0) return 0;

    // 假设月度预算，计算剩余天数
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day + 1;

    return remaining / remainingDays;
  }
}

/// 多预算概览组件
class BudgetOverviewBar extends StatelessWidget {
  /// 小金库列表
  final List<BudgetVault> vaults;

  /// 是否显示总计
  final bool showTotal;

  /// 点击单个预算的回调
  final Function(BudgetVault)? onVaultTap;

  const BudgetOverviewBar({
    super.key,
    required this.vaults,
    this.showTotal = true,
    this.onVaultTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 计算总计
    final totalBudget = vaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final totalSpent = vaults.fold(0.0, (sum, v) => sum + v.spentAmount);
    final totalRemaining = totalBudget - totalSpent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总览
          if (showTotal) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '本月预算',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '剩余 ¥${totalRemaining.toStringAsFixed(0)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: totalRemaining > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStackedProgressBar(theme, totalBudget),
            const SizedBox(height: 16),
          ],

          // 各分类预算
          ...vaults.map((vault) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BudgetStatusBar(
                  vault: vault,
                  compact: true,
                  onTap: () => onVaultTap?.call(vault),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStackedProgressBar(ThemeData theme, double totalBudget) {
    if (totalBudget <= 0) return const SizedBox.shrink();

    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: vaults.map((vault) {
            final widthFactor = vault.allocatedAmount / totalBudget;
            final usageRate = vault.usageRate.clamp(0.0, 1.0);
            final color = _getVaultColor(vault);

            return Expanded(
              flex: (widthFactor * 100).round(),
              child: Stack(
                children: [
                  Container(
                    color: color.withOpacity(0.2),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: usageRate,
                    child: Container(
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getVaultColor(BudgetVault vault) {
    final usageRate = vault.usageRate;
    if (usageRate > 1.0) return Colors.red;
    if (usageRate > 0.9) return Colors.orange;
    if (usageRate > 0.7) return Colors.amber;
    return Colors.green;
  }
}
