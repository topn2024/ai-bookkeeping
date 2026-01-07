import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 债务健康等级
enum DebtHealthLevel {
  /// 健康 - 无债务或债务可控
  healthy,

  /// 注意 - 债务略高但可管理
  caution,

  /// 警告 - 债务负担较重
  warning,

  /// 危险 - 债务负担严重
  danger,
}

extension DebtHealthLevelExtension on DebtHealthLevel {
  String get displayName {
    switch (this) {
      case DebtHealthLevel.healthy:
        return '健康';
      case DebtHealthLevel.caution:
        return '注意';
      case DebtHealthLevel.warning:
        return '警告';
      case DebtHealthLevel.danger:
        return '危险';
    }
  }

  Color get color {
    switch (this) {
      case DebtHealthLevel.healthy:
        return Colors.green;
      case DebtHealthLevel.caution:
        return Colors.amber;
      case DebtHealthLevel.warning:
        return Colors.orange;
      case DebtHealthLevel.danger:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case DebtHealthLevel.healthy:
        return Icons.check_circle;
      case DebtHealthLevel.caution:
        return Icons.info;
      case DebtHealthLevel.warning:
        return Icons.warning;
      case DebtHealthLevel.danger:
        return Icons.error;
    }
  }
}

/// 债务项
class DebtItem {
  final String id;
  final String name;
  final double totalAmount;
  final double remainingAmount;
  final double monthlyPayment;
  final double interestRate;
  final DateTime? dueDate;
  final DebtType type;

  const DebtItem({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.remainingAmount,
    required this.monthlyPayment,
    required this.interestRate,
    this.dueDate,
    required this.type,
  });

  /// 已还百分比
  double get paidPercentage =>
      totalAmount > 0 ? (totalAmount - remainingAmount) / totalAmount : 0;

  /// 预计还清月数
  int get monthsToPayOff {
    if (monthlyPayment <= 0 || remainingAmount <= 0) return 0;
    return (remainingAmount / monthlyPayment).ceil();
  }
}

/// 债务类型
enum DebtType {
  /// 信用卡
  creditCard,

  /// 房贷
  mortgage,

  /// 车贷
  carLoan,

  /// 消费贷
  consumerLoan,

  /// 其他
  other,
}

extension DebtTypeExtension on DebtType {
  String get displayName {
    switch (this) {
      case DebtType.creditCard:
        return '信用卡';
      case DebtType.mortgage:
        return '房贷';
      case DebtType.carLoan:
        return '车贷';
      case DebtType.consumerLoan:
        return '消费贷';
      case DebtType.other:
        return '其他';
    }
  }

  IconData get icon {
    switch (this) {
      case DebtType.creditCard:
        return Icons.credit_card;
      case DebtType.mortgage:
        return Icons.home;
      case DebtType.carLoan:
        return Icons.directions_car;
      case DebtType.consumerLoan:
        return Icons.shopping_bag;
      case DebtType.other:
        return Icons.account_balance;
    }
  }
}

/// 债务健康数据
class DebtHealthData {
  /// 债务列表
  final List<DebtItem> debts;

  /// 月收入（用于计算负债收入比）
  final double monthlyIncome;

  const DebtHealthData({
    required this.debts,
    required this.monthlyIncome,
  });

  /// 总债务
  double get totalDebt => debts.fold(0.0, (sum, d) => sum + d.remainingAmount);

  /// 月还款总额
  double get monthlyPayment =>
      debts.fold(0.0, (sum, d) => sum + d.monthlyPayment);

  /// 负债收入比 (DTI)
  double get debtToIncomeRatio =>
      monthlyIncome > 0 ? monthlyPayment / monthlyIncome : 0;

  /// 健康等级
  DebtHealthLevel get healthLevel {
    final dti = debtToIncomeRatio;
    if (dti <= 0.2) return DebtHealthLevel.healthy;
    if (dti <= 0.36) return DebtHealthLevel.caution;
    if (dti <= 0.5) return DebtHealthLevel.warning;
    return DebtHealthLevel.danger;
  }

  /// 健康分数 (0-100)
  int get healthScore {
    final dti = debtToIncomeRatio;
    if (dti <= 0) return 100;
    if (dti >= 1) return 0;
    return ((1 - dti) * 100).round();
  }
}

/// 债务健康卡片
///
/// 展示用户的债务健康状况
class DebtHealthCard extends StatelessWidget {
  /// 债务健康数据
  final DebtHealthData data;

  /// 是否显示详细债务列表
  final bool showDetails;

  /// 查看还款计划回调
  final VoidCallback? onViewPlan;

  /// 点击单个债务回调
  final Function(DebtItem)? onDebtTap;

  const DebtHealthCard({
    super.key,
    required this.data,
    this.showDetails = false,
    this.onViewPlan,
    this.onDebtTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthLevel = data.healthLevel;

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
                _buildHeader(theme, healthLevel),
                const SizedBox(height: 20),

                // 健康评分
                _buildHealthScore(theme, healthLevel),
                const SizedBox(height: 20),

                // 关键指标
                _buildKeyMetrics(theme),
              ],
            ),
          ),

          // 债务列表
          if (showDetails && data.debts.isNotEmpty) ...[
            Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
            _buildDebtList(theme),
          ],

          // 底部操作
          if (onViewPlan != null) ...[
            Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
            _buildFooter(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, DebtHealthLevel level) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: level.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_balance_wallet,
            color: level.color,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '债务健康',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(level.icon, size: 14, color: level.color),
                  const SizedBox(width: 4),
                  Text(
                    level.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: level.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 总债务
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '总债务',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              '¥${_formatAmount(data.totalDebt)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: level.color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthScore(ThemeData theme, DebtHealthLevel level) {
    final score = data.healthScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 分数环
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                // 背景环
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 8,
                    backgroundColor: level.color.withOpacity(0.2),
                    valueColor:
                        AlwaysStoppedAnimation(level.color.withOpacity(0.2)),
                  ),
                ),
                // 进度环
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(level.color),
                  ),
                ),
                // 分数
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: level.color,
                        ),
                      ),
                      Text(
                        '分',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: level.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // 建议
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getAdvice(level),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getAdviceDetail(level),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(ThemeData theme) {
    return Row(
      children: [
        // 月还款额
        Expanded(
          child: _buildMetricItem(
            theme,
            icon: Icons.calendar_today,
            label: '月还款额',
            value: '¥${_formatAmount(data.monthlyPayment)}',
          ),
        ),
        Container(
          height: 40,
          width: 1,
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        // 负债收入比
        Expanded(
          child: _buildMetricItem(
            theme,
            icon: Icons.pie_chart,
            label: '负债收入比',
            value: '${(data.debtToIncomeRatio * 100).toStringAsFixed(0)}%',
            valueColor: data.healthLevel.color,
          ),
        ),
        Container(
          height: 40,
          width: 1,
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        // 债务笔数
        Expanded(
          child: _buildMetricItem(
            theme,
            icon: Icons.format_list_numbered,
            label: '债务笔数',
            value: '${data.debts.length}笔',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.outline),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
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

  Widget _buildDebtList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            '债务明细',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...data.debts.map((debt) => _buildDebtItem(theme, debt)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDebtItem(ThemeData theme, DebtItem debt) {
    return InkWell(
      onTap: () => onDebtTap?.call(debt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 类型图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                debt.type.icon,
                size: 20,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 12),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debt.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: debt.paidPercentage,
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '还剩 ¥${_formatAmount(debt.remainingAmount)} · '
                    '月供 ¥${_formatAmount(debt.monthlyPayment)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

            // 箭头
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onViewPlan,
          icon: const Icon(Icons.analytics),
          label: const Text('查看还款计划'),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }

  String _getAdvice(DebtHealthLevel level) {
    switch (level) {
      case DebtHealthLevel.healthy:
        return '债务健康良好 👍';
      case DebtHealthLevel.caution:
        return '注意债务管理';
      case DebtHealthLevel.warning:
        return '债务负担较重';
      case DebtHealthLevel.danger:
        return '需要立即关注!';
    }
  }

  String _getAdviceDetail(DebtHealthLevel level) {
    switch (level) {
      case DebtHealthLevel.healthy:
        return '继续保持良好的财务习惯';
      case DebtHealthLevel.caution:
        return '建议控制新增债务，优先偿还高息债务';
      case DebtHealthLevel.warning:
        return '建议制定还款计划，考虑增加收入或减少支出';
      case DebtHealthLevel.danger:
        return '建议寻求专业财务咨询，避免逾期';
    }
  }
}

/// 债务雪球/雪崩策略选择器
class DebtRepaymentStrategyCard extends StatelessWidget {
  /// 债务列表
  final List<DebtItem> debts;

  /// 当前策略
  final DebtRepaymentStrategy currentStrategy;

  /// 策略变更回调
  final Function(DebtRepaymentStrategy)? onStrategyChange;

  const DebtRepaymentStrategyCard({
    super.key,
    required this.debts,
    required this.currentStrategy,
    this.onStrategyChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还款策略',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStrategyOption(
                  theme,
                  strategy: DebtRepaymentStrategy.snowball,
                  title: '雪球法',
                  description: '先还最小债务，建立信心',
                  icon: Icons.ac_unit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStrategyOption(
                  theme,
                  strategy: DebtRepaymentStrategy.avalanche,
                  title: '雪崩法',
                  description: '先还最高利率，节省利息',
                  icon: Icons.landscape,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyOption(
    ThemeData theme, {
    required DebtRepaymentStrategy strategy,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = currentStrategy == strategy;

    return InkWell(
      onTap: () => onStrategyChange?.call(strategy),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 还款策略
enum DebtRepaymentStrategy {
  /// 雪球法 - 先还最小债务
  snowball,

  /// 雪崩法 - 先还最高利率
  avalanche,
}
