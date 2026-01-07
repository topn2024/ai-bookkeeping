import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 月度计划状态
enum MonthlyPlanStatus {
  /// 未开始
  notStarted,

  /// 进行中
  inProgress,

  /// 已完成
  completed,
}

/// 月度计划数据
class MonthlyPlanData {
  /// 计划月份
  final DateTime month;

  /// 预计收入
  final double plannedIncome;

  /// 实际收入
  final double actualIncome;

  /// 总预算
  final double totalBudget;

  /// 已分配预算
  final double allocatedBudget;

  /// 已花费
  final double spent;

  /// 储蓄目标
  final double savingsGoal;

  /// 实际储蓄
  final double actualSavings;

  /// 计划项列表
  final List<PlanItem> planItems;

  /// 计划状态
  final MonthlyPlanStatus status;

  const MonthlyPlanData({
    required this.month,
    required this.plannedIncome,
    this.actualIncome = 0,
    required this.totalBudget,
    this.allocatedBudget = 0,
    this.spent = 0,
    this.savingsGoal = 0,
    this.actualSavings = 0,
    this.planItems = const [],
    this.status = MonthlyPlanStatus.notStarted,
  });

  /// 预算分配进度
  double get allocationProgress =>
      totalBudget > 0 ? allocatedBudget / totalBudget : 0;

  /// 消费进度
  double get spendingProgress =>
      allocatedBudget > 0 ? spent / allocatedBudget : 0;

  /// 储蓄进度
  double get savingsProgress =>
      savingsGoal > 0 ? actualSavings / savingsGoal : 0;

  /// 剩余可分配
  double get remainingToAllocate => totalBudget - allocatedBudget;

  /// 剩余可花费
  double get remainingToSpend => allocatedBudget - spent;

  /// 是否超支
  bool get isOverBudget => spent > allocatedBudget;

  /// 本月剩余天数
  int get remainingDays {
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final today = DateTime.now();
    if (today.month != month.month || today.year != month.year) return 0;
    return lastDay.day - today.day;
  }
}

/// 计划项
class PlanItem {
  final String id;
  final String title;
  final double amount;
  final DateTime? plannedDate;
  final bool isCompleted;
  final PlanItemType type;

  const PlanItem({
    required this.id,
    required this.title,
    required this.amount,
    this.plannedDate,
    this.isCompleted = false,
    required this.type,
  });
}

/// 计划项类型
enum PlanItemType {
  /// 大额支出
  largeExpense,

  /// 订阅续费
  subscription,

  /// 还款
  repayment,

  /// 储蓄转账
  savings,

  /// 其他
  other,
}

extension PlanItemTypeExtension on PlanItemType {
  IconData get icon {
    switch (this) {
      case PlanItemType.largeExpense:
        return Icons.shopping_cart;
      case PlanItemType.subscription:
        return Icons.repeat;
      case PlanItemType.repayment:
        return Icons.payment;
      case PlanItemType.savings:
        return Icons.savings;
      case PlanItemType.other:
        return Icons.more_horiz;
    }
  }

  String get displayName {
    switch (this) {
      case PlanItemType.largeExpense:
        return '大额支出';
      case PlanItemType.subscription:
        return '订阅';
      case PlanItemType.repayment:
        return '还款';
      case PlanItemType.savings:
        return '储蓄';
      case PlanItemType.other:
        return '其他';
    }
  }
}

/// 月度规划卡片
///
/// 展示用户的月度财务规划和执行情况
class MonthlyPlanningCard extends StatelessWidget {
  /// 计划数据
  final MonthlyPlanData data;

  /// 是否显示详细计划项
  final bool showPlanItems;

  /// 创建/编辑计划回调
  final VoidCallback? onEditPlan;

  /// 查看详情回调
  final VoidCallback? onViewDetails;

  /// 添加计划项回调
  final VoidCallback? onAddItem;

  const MonthlyPlanningCard({
    super.key,
    required this.data,
    this.showPlanItems = true,
    this.onEditPlan,
    this.onViewDetails,
    this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 头部
                _buildHeader(theme),
                const SizedBox(height: 20),

                // 预算概览
                _buildBudgetOverview(theme),
                const SizedBox(height: 16),

                // 进度条
                _buildProgressBars(theme),

                // 储蓄目标
                if (data.savingsGoal > 0) ...[
                  const SizedBox(height: 16),
                  _buildSavingsGoal(theme),
                ],
              ],
            ),
          ),

          // 计划项列表
          if (showPlanItems && data.planItems.isNotEmpty) ...[
            Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
            _buildPlanItems(theme),
          ],

          // 底部操作
          Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final monthName = '${data.month.year}年${data.month.month}月';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.calendar_month,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$monthName规划',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '还剩${data.remainingDays}天',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 编辑按钮
        if (onEditPlan != null)
          IconButton(
            onPressed: onEditPlan,
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑计划',
          ),
      ],
    );
  }

  Widget _buildBudgetOverview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 预计收入
          Expanded(
            child: _buildOverviewItem(
              theme,
              label: '预计收入',
              value: '¥${_formatAmount(data.plannedIncome)}',
              icon: Icons.arrow_downward,
              iconColor: Colors.green,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
          // 总预算
          Expanded(
            child: _buildOverviewItem(
              theme,
              label: '总预算',
              value: '¥${_formatAmount(data.totalBudget)}',
              icon: Icons.account_balance_wallet,
              iconColor: theme.colorScheme.primary,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
          // 剩余可花
          Expanded(
            child: _buildOverviewItem(
              theme,
              label: '剩余可花',
              value: '¥${_formatAmount(data.remainingToSpend)}',
              icon: Icons.shopping_bag,
              iconColor: data.isOverBudget ? Colors.red : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBars(ThemeData theme) {
    return Column(
      children: [
        // 预算分配进度
        _buildProgressItem(
          theme,
          label: '预算分配',
          progress: data.allocationProgress,
          color: theme.colorScheme.primary,
          leftText: '已分配 ¥${_formatAmount(data.allocatedBudget)}',
          rightText: '待分配 ¥${_formatAmount(data.remainingToAllocate)}',
        ),
        const SizedBox(height: 12),

        // 消费进度
        _buildProgressItem(
          theme,
          label: '消费进度',
          progress: data.spendingProgress,
          color: data.isOverBudget ? Colors.red : Colors.green,
          leftText: '已花费 ¥${_formatAmount(data.spent)}',
          rightText: '${(data.spendingProgress * 100).toStringAsFixed(0)}%',
        ),
      ],
    );
  }

  Widget _buildProgressItem(
    ThemeData theme, {
    required String label,
    required double progress,
    required Color color,
    required String leftText,
    required String rightText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              rightText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          leftText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsGoal(ThemeData theme) {
    final progress = data.savingsProgress;
    final isAchieved = progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAchieved
            ? Colors.green.withOpacity(0.1)
            : theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAchieved
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAchieved ? Icons.check_circle : Icons.savings,
            color: isAchieved ? Colors.green : theme.colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAchieved ? '储蓄目标已达成! 🎉' : '本月储蓄目标',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAchieved ? Colors.green : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '已储蓄 ¥${_formatAmount(data.actualSavings)} / '
                  '目标 ¥${_formatAmount(data.savingsGoal)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          // 进度
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      isAchieved ? Colors.green : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItems(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '计划项',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onAddItem != null)
                TextButton.icon(
                  onPressed: onAddItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        ...data.planItems.take(5).map((item) => _buildPlanItem(theme, item)),
        if (data.planItems.length > 5)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              '还有${data.planItems.length - 5}项...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPlanItem(ThemeData theme, PlanItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // 完成状态
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: item.isCompleted
                  ? Colors.green
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: item.isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),

          // 图标
          Icon(
            item.type.icon,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),

          // 标题
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted ? theme.colorScheme.outline : null,
                  ),
                ),
                if (item.plannedDate != null)
                  Text(
                    '${item.plannedDate!.month}/${item.plannedDate!.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),

          // 金额
          Text(
            '¥${_formatAmount(item.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: item.isCompleted ? theme.colorScheme.outline : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.analytics, size: 18),
              label: const Text('查看详情'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

/// 月度规划创建器
class MonthlyPlanCreator extends StatelessWidget {
  /// 创建月份
  final DateTime month;

  /// 创建回调
  final VoidCallback? onCreate;

  const MonthlyPlanCreator({
    super.key,
    required this.month,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = '${month.year}年${month.month}月';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '$monthName还没有规划',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '提前规划，让财务更有方向',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('创建本月规划'),
          ),
        ],
      ),
    );
  }
}
