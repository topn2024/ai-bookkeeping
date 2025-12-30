import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/savings_goal.dart';
import '../models/category.dart';
import '../providers/savings_goal_provider.dart';
import '../providers/category_provider.dart';

class SavingsGoalPage extends ConsumerWidget {
  const SavingsGoalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalProvider);
    final summary = ref.watch(savingsGoalSummaryProvider);
    final activeGoals = goals.where((g) => !g.isArchived).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('储蓄目标'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: () => _showArchivedGoals(context, ref, goals),
            tooltip: '已归档',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddGoalDialog(context, ref),
          ),
        ],
      ),
      body: activeGoals.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(context, summary, theme),
                const SizedBox(height: 16),
                if (ref.read(savingsGoalProvider.notifier).inProgressGoals.isNotEmpty) ...[
                  _buildSectionHeader('进行中', ref.read(savingsGoalProvider.notifier).inProgressGoals.length),
                  ...ref.read(savingsGoalProvider.notifier).inProgressGoals
                      .map((goal) => _buildGoalCard(context, ref, goal, theme)),
                ],
                if (ref.read(savingsGoalProvider.notifier).completedGoals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('已完成', ref.read(savingsGoalProvider.notifier).completedGoals.length),
                  ...ref.read(savingsGoalProvider.notifier).completedGoals
                      .map((goal) => _buildGoalCard(context, ref, goal, theme)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建目标'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有储蓄目标',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '设定一个目标，开始你的储蓄之旅',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddGoalDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('创建第一个目标'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, SavingsGoalSummary summary, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '目标概览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '目标总额',
                    '¥${summary.totalTarget.toStringAsFixed(0)}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '已存金额',
                    '¥${summary.totalSaved.toStringAsFixed(0)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '还需存',
                    '¥${summary.remainingAmount.toStringAsFixed(0)}',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.overallProgress,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  summary.overallProgress >= 1 ? Colors.green : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '总体进度: ${(summary.overallProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Row(
                  children: [
                    _buildStatChip('进行中', summary.activeCount, Colors.blue),
                    const SizedBox(width: 8),
                    _buildStatChip('已完成', summary.completedCount, Colors.green),
                    if (summary.overdueCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildStatChip('已过期', summary.overdueCount, Colors.red),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, SavingsGoal goal, ThemeData theme) {
    // 根据目标类型显示不同的卡片
    if (goal.type == SavingsGoalType.expense) {
      return _buildExpenseGoalCard(context, ref, goal, theme);
    } else if (goal.isRecurring) {
      return _buildRecurringGoalCard(context, ref, goal, theme);
    }
    return _buildStandardGoalCard(context, ref, goal, theme);
  }

  /// 标准储蓄目标卡片
  Widget _buildStandardGoalCard(BuildContext context, WidgetRef ref, SavingsGoal goal, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showGoalDetail(context, ref, goal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(goal.icon, color: goal.color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (goal.isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '已达成',
                                      style: TextStyle(fontSize: 10, color: Colors.green[700]),
                                    ),
                                  ],
                                ),
                              ),
                            if (goal.isOverdue)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning, size: 12, color: Colors.red[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '已过期',
                                      style: TextStyle(fontSize: 10, color: Colors.red[700]),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Text(
                          goal.typeDisplayName,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, ref, goal, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'deposit', child: Text('存入金额')),
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      if (!goal.isCompleted)
                        const PopupMenuItem(value: 'complete', child: Text('标记完成')),
                      const PopupMenuItem(value: 'archive', child: Text('归档')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '¥${goal.currentAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: goal.color,
                    ),
                  ),
                  Text(
                    '/ ¥${goal.targetAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.isCompleted ? Colors.green : goal.color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    goal.progressPercent,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (goal.daysRemaining != null && !goal.isCompleted)
                    Text(
                      goal.daysRemaining! >= 0
                          ? '剩余 ${goal.daysRemaining} 天'
                          : '已超期 ${-goal.daysRemaining!} 天',
                      style: TextStyle(
                        fontSize: 12,
                        color: goal.isOverdue ? Colors.red : Colors.grey[600],
                      ),
                    ),
                ],
              ),
              if (goal.suggestedMonthlyAmount != null && !goal.isCompleted) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: goal.color),
                      const SizedBox(width: 8),
                      Text(
                        '建议每月存入 ¥${goal.suggestedMonthlyAmount!.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12, color: goal.color),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 月度开支目标卡片
  Widget _buildExpenseGoalCard(BuildContext context, WidgetRef ref, SavingsGoal goal, ThemeData theme) {
    final tracking = ref.watch(monthlyExpenseTrackingProvider(goal.id));
    final categories = ref.watch(categoryProvider);
    final linkedCategory = goal.linkedCategoryId != null
        ? categories.where((c) => c.id == goal.linkedCategoryId).firstOrNull
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showExpenseGoalDetail(context, ref, goal, tracking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(goal.icon, color: goal.color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_down, size: 12, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '开支控制',
                                    style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (linkedCategory != null)
                          Row(
                            children: [
                              Icon(linkedCategory.icon, size: 12, color: linkedCategory.color),
                              const SizedBox(width: 4),
                              Text(
                                linkedCategory.name,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          )
                        else
                          Text(
                            '全部开支',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, ref, goal, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(value: 'archive', child: Text('归档')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (tracking != null) ...[
                // 开支进度信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已花费 ¥${tracking.currentSpent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tracking.isOverBudget ? Colors.red : goal.color,
                      ),
                    ),
                    Text(
                      '/ ¥${tracking.monthlyLimit.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: tracking.percentage.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      tracking.isOverBudget
                          ? Colors.red
                          : tracking.isNearLimit
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tracking.isOverBudget
                          ? '超支 ¥${(tracking.currentSpent - tracking.monthlyLimit).toStringAsFixed(0)}'
                          : '剩余 ¥${tracking.remaining.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: tracking.isOverBudget ? Colors.red : Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${tracking.daysPassed}/${tracking.daysInMonth} 天',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tracking.isOnTrack
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tracking.isOnTrack ? Icons.check_circle : Icons.info,
                        size: 16,
                        color: tracking.isOnTrack ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tracking.isOnTrack
                              ? '进度良好，日均 ¥${tracking.dailyAverage.toStringAsFixed(0)}'
                              : '建议控制日均开支在 ¥${tracking.suggestedDaily.toStringAsFixed(0)} 以内',
                          style: TextStyle(
                            fontSize: 12,
                            color: tracking.isOnTrack ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 定期存款目标卡片
  Widget _buildRecurringGoalCard(BuildContext context, WidgetRef ref, SavingsGoal goal, ThemeData theme) {
    final progress = ref.watch(recurringDepositProgressProvider(goal.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showGoalDetail(context, ref, goal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(goal.icon, color: goal.color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat, size: 12, color: Colors.blue[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '定期存款',
                                    style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                                  ),
                                ],
                              ),
                            ),
                            if (goal.depositDueToday)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.notification_important, size: 12, color: Colors.red[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '今日存款',
                                      style: TextStyle(fontSize: 10, color: Colors.red[700]),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${goal.recurringFrequency?.displayName ?? ''} ¥${goal.recurringAmount?.toStringAsFixed(0) ?? 0}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, ref, goal, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'deposit', child: Text('存入金额')),
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      if (!goal.isCompleted)
                        const PopupMenuItem(value: 'complete', child: Text('标记完成')),
                      const PopupMenuItem(value: 'archive', child: Text('归档')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '¥${goal.currentAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: goal.color,
                    ),
                  ),
                  Text(
                    '/ ¥${goal.targetAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.isCompleted ? Colors.green : goal.color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    goal.progressPercent,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (progress != null)
                    Text(
                      '已存 ${progress.totalDeposits} 次',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
              if (progress != null && goal.nextDepositDate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: progress.isOnSchedule
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        progress.isOnSchedule ? Icons.schedule : Icons.warning,
                        size: 16,
                        color: progress.isOnSchedule ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          progress.depositDueToday
                              ? '今日需存入 ¥${goal.recurringAmount?.toStringAsFixed(0) ?? 0}'
                              : '下次存款: ${_formatDate(goal.nextDepositDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: progress.isOnSchedule ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  void _showExpenseGoalDetail(BuildContext context, WidgetRef ref, SavingsGoal goal, MonthlyExpenseTracking? tracking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ExpenseGoalDetailSheet(
        goal: goal,
        tracking: tracking,
        onEdit: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SavingsGoalFormPage(goal: goal),
            ),
          );
        },
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, SavingsGoal goal, String action) {
    switch (action) {
      case 'deposit':
        _showDepositDialog(context, ref, goal);
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavingsGoalFormPage(goal: goal),
          ),
        );
        break;
      case 'complete':
        ref.read(savingsGoalProvider.notifier).markAsCompleted(goal.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目标已标记为完成')),
        );
        break;
      case 'archive':
        ref.read(savingsGoalProvider.notifier).archiveGoal(goal.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目标已归档')),
        );
        break;
      case 'delete':
        _confirmDelete(context, ref, goal);
        break;
    }
  }

  void _showGoalDetail(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _GoalDetailSheet(
        goal: goal,
        onDeposit: () {
          Navigator.pop(context);
          _showDepositDialog(context, ref, goal);
        },
        onEdit: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SavingsGoalFormPage(goal: goal),
            ),
          );
        },
      ),
    );
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('存入 - ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前已存: ¥${goal.currentAmount.toStringAsFixed(2)}'),
            Text('目标金额: ¥${goal.targetAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: '存入金额',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注 (选填)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                amountController.text = goal.remainingAmount.toStringAsFixed(2);
              },
              child: const Text('存入剩余全部'),
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
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                ref.read(savingsGoalProvider.notifier).addDeposit(
                  goal.id,
                  amount,
                  note: noteController.text.isNotEmpty ? noteController.text : null,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('成功存入 ¥${amount.toStringAsFixed(2)}')),
                );
              }
            },
            child: const Text('确认存入'),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _TemplateSelectionSheet(
          scrollController: scrollController,
          onSelectTemplate: (template) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavingsGoalFormPage(template: template),
              ),
            );
          },
          onCustom: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SavingsGoalFormPage(),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showArchivedGoals(BuildContext context, WidgetRef ref, List<SavingsGoal> allGoals) {
    final archivedGoals = allGoals.where((g) => g.isArchived).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '已归档目标',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: archivedGoals.isEmpty
                    ? Center(
                        child: Text(
                          '没有已归档的目标',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: archivedGoals.length,
                        itemBuilder: (context, index) {
                          final goal = archivedGoals[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: goal.color.withValues(alpha:0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(goal.icon, color: goal.color, size: 24),
                            ),
                            title: Text(goal.name),
                            subtitle: Text('${goal.progressPercent} 完成'),
                            trailing: IconButton(
                              icon: const Icon(Icons.unarchive),
                              onPressed: () {
                                ref.read(savingsGoalProvider.notifier).unarchiveGoal(goal.id);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除目标 "${goal.name}" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(savingsGoalProvider.notifier).deleteGoal(goal.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _GoalDetailSheet extends StatelessWidget {
  final SavingsGoal goal;
  final VoidCallback onDeposit;
  final VoidCallback onEdit;

  const _GoalDetailSheet({
    required this.goal,
    required this.onDeposit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(goal.icon, color: goal.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      goal.typeDisplayName,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (goal.isCompleted)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, color: Colors.green[700]),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Progress card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [goal.color, goal.color.withValues(alpha:0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
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
                          '¥${goal.currentAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
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
                          '¥${goal.targetAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 8,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      goal.progressPercent,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      '还差 ¥${goal.remainingAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info items
          if (goal.description != null) ...[
            _buildInfoItem(Icons.description, '描述', goal.description!),
            const SizedBox(height: 8),
          ],
          if (goal.targetDate != null) ...[
            _buildInfoItem(
              Icons.calendar_today,
              '目标日期',
              '${goal.targetDate!.year}/${goal.targetDate!.month}/${goal.targetDate!.day}',
            ),
            const SizedBox(height: 8),
          ],
          if (goal.daysRemaining != null)
            _buildInfoItem(
              Icons.timer,
              '剩余时间',
              goal.daysRemaining! >= 0
                  ? '${goal.daysRemaining} 天'
                  : '已超期 ${-goal.daysRemaining!} 天',
            ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDeposit,
                  icon: const Icon(Icons.add),
                  label: const Text('存入'),
                  style: ElevatedButton.styleFrom(backgroundColor: goal.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600])),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// 月度开支目标详情页
class _ExpenseGoalDetailSheet extends StatelessWidget {
  final SavingsGoal goal;
  final MonthlyExpenseTracking? tracking;
  final VoidCallback onEdit;

  const _ExpenseGoalDetailSheet({
    required this.goal,
    this.tracking,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(goal.icon, color: goal.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text('月度开支控制', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (tracking != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [goal.color, goal.color.withValues(alpha:0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('本月已花费', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            '¥${tracking!.currentSpent.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('月度限额', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            '¥${tracking!.monthlyLimit.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: tracking!.percentage.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(tracking!.percentage * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        tracking!.isOverBudget
                            ? '超支 ¥${(tracking!.currentSpent - tracking!.monthlyLimit).toStringAsFixed(0)}'
                            : '剩余 ¥${tracking!.remaining.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, '本月进度', '${tracking!.daysPassed}/${tracking!.daysInMonth} 天'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.trending_down, '日均开支', '¥${tracking!.dailyAverage.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.lightbulb_outline, '建议日均', '¥${tracking!.suggestedDaily.toStringAsFixed(0)}'),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
              label: const Text('编辑目标'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600])),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TemplateSelectionSheet extends StatelessWidget {
  final ScrollController scrollController;
  final Function(Map<String, dynamic>) onSelectTemplate;
  final VoidCallback onCustom;

  const _TemplateSelectionSheet({
    required this.scrollController,
    required this.onSelectTemplate,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final templates = GoalTemplates.templates;
    final expenseTemplates = GoalTemplates.expenseTemplates;
    final recurringTemplates = GoalTemplates.recurringTemplates;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            '选择目标类型',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '选择一个模板快速创建，或自定义您的目标',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // Custom option
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.grey),
                    ),
                    title: const Text('自定义目标'),
                    subtitle: const Text('创建您自己的储蓄目标'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onCustom,
                  ),
                ),
                const SizedBox(height: 16),
                // 月度开支控制
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_down, size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text('月度开支控制', style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...expenseTemplates.map((template) {
                  final color = template['color'] as Color;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(template['icon'] as IconData, color: color),
                      ),
                      title: Text(template['name'] as String),
                      subtitle: Text(template['description'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelectTemplate(template),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // 定期存款
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text('定期存款计划', style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...recurringTemplates.map((template) {
                  final color = template['color'] as Color;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(template['icon'] as IconData, color: color),
                      ),
                      title: Text(template['name'] as String),
                      subtitle: Text(template['description'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelectTemplate(template),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // 储蓄目标
                const Text('储蓄目标', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...templates.map((template) {
                  final color = template['color'] as Color;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(template['icon'] as IconData, color: color),
                      ),
                      title: Text(template['name'] as String),
                      subtitle: Text(template['description'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelectTemplate(template),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SavingsGoalFormPage extends ConsumerStatefulWidget {
  final SavingsGoal? goal;
  final Map<String, dynamic>? template;

  const SavingsGoalFormPage({super.key, this.goal, this.template});

  @override
  ConsumerState<SavingsGoalFormPage> createState() => _SavingsGoalFormPageState();
}

class _SavingsGoalFormPageState extends ConsumerState<SavingsGoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _targetAmountController;
  late TextEditingController _currentAmountController;
  late TextEditingController _recurringAmountController;

  SavingsGoalType _selectedType = SavingsGoalType.savings;
  DateTime _startDate = DateTime.now();
  DateTime? _targetDate;
  IconData _selectedIcon = Icons.savings;
  Color _selectedColor = Colors.blue;

  // 月度开支目标相关
  String? _linkedCategoryId;
  bool _isExpenseControl = false;

  // 定期存款相关
  bool _isRecurring = false;
  SavingsFrequency _recurringFrequency = SavingsFrequency.monthly;
  bool _enableReminder = false;

  bool get isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();

    if (widget.goal != null) {
      _nameController = TextEditingController(text: widget.goal!.name);
      _descriptionController = TextEditingController(text: widget.goal!.description ?? '');
      _targetAmountController = TextEditingController(
        text: widget.goal!.targetAmount.toStringAsFixed(0),
      );
      _currentAmountController = TextEditingController(
        text: widget.goal!.currentAmount.toStringAsFixed(0),
      );
      _recurringAmountController = TextEditingController(
        text: widget.goal!.recurringAmount?.toStringAsFixed(0) ?? '',
      );
      _selectedType = widget.goal!.type;
      _startDate = widget.goal!.startDate;
      _targetDate = widget.goal!.targetDate;
      _selectedIcon = widget.goal!.icon;
      _selectedColor = widget.goal!.color;
      // 月度开支目标
      _linkedCategoryId = widget.goal!.linkedCategoryId;
      _isExpenseControl = widget.goal!.type == SavingsGoalType.expense;
      // 定期存款
      _isRecurring = widget.goal!.isRecurring;
      _recurringFrequency = widget.goal!.recurringFrequency ?? SavingsFrequency.monthly;
      _enableReminder = widget.goal!.enableReminder;
    } else if (widget.template != null) {
      _nameController = TextEditingController(text: widget.template!['name'] as String);
      _descriptionController = TextEditingController(
        text: widget.template!['description'] as String? ?? '',
      );
      _targetAmountController = TextEditingController();
      _currentAmountController = TextEditingController(text: '0');
      _recurringAmountController = TextEditingController();
      _selectedType = widget.template!['type'] as SavingsGoalType;
      _selectedIcon = widget.template!['icon'] as IconData;
      _selectedColor = widget.template!['color'] as Color;
      // 月度开支目标
      _isExpenseControl = widget.template!['isExpenseControl'] == true;
      // 定期存款
      _isRecurring = widget.template!['isRecurring'] == true;
      if (widget.template!['recurringFrequency'] != null) {
        _recurringFrequency = widget.template!['recurringFrequency'] as SavingsFrequency;
      }
    } else {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _targetAmountController = TextEditingController();
      _currentAmountController = TextEditingController(text: '0');
      _recurringAmountController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _recurringAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑目标' : '创建目标'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Goal type
            DropdownButtonFormField<SavingsGoalType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: '目标类型',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: SavingsGoalType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeDisplayName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
            ),
            const SizedBox(height: 16),
            // Goal name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '目标名称',
                prefixIcon: Icon(Icons.flag),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入目标名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述 (选填)',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Target amount
            TextFormField(
              controller: _targetAmountController,
              decoration: const InputDecoration(
                labelText: '目标金额',
                prefixIcon: Icon(Icons.monetization_on),
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入目标金额';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效金额';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Current amount (only for non-expense goals)
            if (_selectedType != SavingsGoalType.expense)
              TextFormField(
                controller: _currentAmountController,
                decoration: const InputDecoration(
                  labelText: '初始金额',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  prefixText: '¥',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            if (_selectedType != SavingsGoalType.expense)
              const SizedBox(height: 16),

            // 月度开支目标 - 分类选择
            if (_selectedType == SavingsGoalType.expense || _isExpenseControl) ...[
              const SizedBox(height: 8),
              _buildCategorySelector(),
              const SizedBox(height: 16),
            ],

            // 定期存款选项
            if (_selectedType != SavingsGoalType.expense) ...[
              SwitchListTile(
                title: const Text('启用定期存款'),
                subtitle: const Text('设置固定存款计划，养成储蓄习惯'),
                value: _isRecurring,
                onChanged: (value) {
                  setState(() => _isRecurring = value);
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 16),
                // 存款频率
                DropdownButtonFormField<SavingsFrequency>(
                  initialValue: _recurringFrequency,
                  decoration: const InputDecoration(
                    labelText: '存款频率',
                    prefixIcon: Icon(Icons.repeat),
                    border: OutlineInputBorder(),
                  ),
                  items: SavingsFrequency.values.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Text(freq.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _recurringFrequency = value!);
                  },
                ),
                const SizedBox(height: 16),
                // 每次存款金额
                TextFormField(
                  controller: _recurringAmountController,
                  decoration: const InputDecoration(
                    labelText: '每次存款金额',
                    prefixIcon: Icon(Icons.savings),
                    prefixText: '¥',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _isRecurring
                      ? (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入存款金额';
                          }
                          if (double.tryParse(value) == null) {
                            return '请输入有效金额';
                          }
                          return null;
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('启用存款提醒'),
                  subtitle: const Text('到期时提醒您存款'),
                  value: _enableReminder,
                  onChanged: (value) {
                    setState(() => _enableReminder = value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],

            const SizedBox(height: 24),
            // Target date
            Text(
              '目标日期 (选填)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectTargetDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(
                      _targetDate != null
                          ? '${_targetDate!.year}/${_targetDate!.month}/${_targetDate!.day}'
                          : '选择目标日期',
                      style: TextStyle(
                        color: _targetDate != null ? Colors.black : Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    if (_targetDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _targetDate = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Icon and color
            Text(
              '图标和颜色',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildIconColorSelector(),
            const SizedBox(height: 32),
            // Save button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saveGoal,
                child: Text(isEditing ? '保存修改' : '创建目标'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeDisplayName(SavingsGoalType type) {
    switch (type) {
      case SavingsGoalType.savings:
        return '存钱目标';
      case SavingsGoalType.expense:
        return '消费控制';
      case SavingsGoalType.debt:
        return '还债目标';
      case SavingsGoalType.investment:
        return '投资目标';
    }
  }

  Widget _buildIconColorSelector() {
    final icons = [
      Icons.savings,
      Icons.flag,
      Icons.flight,
      Icons.shopping_bag,
      Icons.home,
      Icons.directions_car,
      Icons.school,
      Icons.celebration,
      Icons.favorite,
      Icons.trending_up,
    ];

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.red,
      Colors.indigo,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择图标'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: icons.map((icon) {
              final isSelected = icon == _selectedIcon;
              return InkWell(
                onTap: () => setState(() => _selectedIcon = icon),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? _selectedColor.withValues(alpha:0.2) : Colors.white,
                    border: Border.all(
                      color: isSelected ? _selectedColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: isSelected ? _selectedColor : Colors.grey),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('选择颜色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              final isSelected = color == _selectedColor;
              return InkWell(
                onTap: () => setState(() => _selectedColor = color),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Widget _buildCategorySelector() {
    final categories = ref.watch(categoryProvider);
    final expenseCategories = categories.where((c) => c.isExpense).toList();
    final selectedCategory = _linkedCategoryId != null
        ? expenseCategories.where((c) => c.id == _linkedCategoryId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关联消费分类 (选填)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '选择一个分类来追踪该类别的月度开支',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _showCategoryPicker(expenseCategories),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (selectedCategory != null) ...[
                  Icon(selectedCategory.icon, color: selectedCategory.color, size: 24),
                  const SizedBox(width: 12),
                  Text(selectedCategory.name),
                ] else ...[
                  Icon(Icons.category, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text('全部开支', style: TextStyle(color: Colors.grey[600])),
                ],
                const Spacer(),
                if (_linkedCategoryId != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _linkedCategoryId = null),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择消费分类',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('全部开支'),
              subtitle: const Text('追踪所有消费'),
              selected: _linkedCategoryId == null,
              onTap: () {
                setState(() => _linkedCategoryId = null);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    leading: Icon(category.icon, color: category.color),
                    title: Text(category.localizedName),
                    selected: _linkedCategoryId == category.id,
                    onTap: () {
                      setState(() => _linkedCategoryId = category.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveGoal() {
    if (!_formKey.currentState!.validate()) return;

    final targetAmount = double.parse(_targetAmountController.text);
    final currentAmount = _selectedType == SavingsGoalType.expense
        ? 0.0
        : (double.tryParse(_currentAmountController.text) ?? 0);

    // 定期存款的下次存款日期
    DateTime? nextDepositDate;
    double? recurringAmount;
    if (_isRecurring && _selectedType != SavingsGoalType.expense) {
      recurringAmount = double.tryParse(_recurringAmountController.text);
      nextDepositDate = _recurringFrequency.getNextDate(DateTime.now());
    }

    final goal = SavingsGoal(
      id: widget.goal?.id ?? const Uuid().v4(),
      name: _nameController.text,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      type: _selectedType,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      startDate: _startDate,
      targetDate: _targetDate,
      icon: _selectedIcon,
      color: _selectedColor,
      isCompleted: currentAmount >= targetAmount,
      completedAt: currentAmount >= targetAmount ? DateTime.now() : null,
      isArchived: widget.goal?.isArchived ?? false,
      createdAt: widget.goal?.createdAt ?? DateTime.now(),
      // 月度开支目标
      linkedCategoryId: _selectedType == SavingsGoalType.expense ? _linkedCategoryId : null,
      monthlyExpenseLimit: _selectedType == SavingsGoalType.expense ? targetAmount : null,
      // 定期存款目标
      recurringFrequency: _isRecurring ? _recurringFrequency : null,
      recurringAmount: recurringAmount,
      nextDepositDate: nextDepositDate,
      enableReminder: _isRecurring ? _enableReminder : false,
    );

    if (isEditing) {
      ref.read(savingsGoalProvider.notifier).updateGoal(goal);
    } else {
      ref.read(savingsGoalProvider.notifier).addGoal(goal);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEditing ? '目标已更新' : '目标已创建')),
    );
  }
}
