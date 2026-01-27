import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/family_savings_goal.dart';
import '../providers/family_goal_provider.dart';
import '../providers/ledger_context_provider.dart';

/// 15.09 家庭共同储蓄目标页面
class FamilySavingsGoalPage extends ConsumerStatefulWidget {
  const FamilySavingsGoalPage({super.key});

  @override
  ConsumerState<FamilySavingsGoalPage> createState() => _FamilySavingsGoalPageState();
}

class _FamilySavingsGoalPageState extends ConsumerState<FamilySavingsGoalPage> {
  @override
  void initState() {
    super.initState();
    // 加载目标数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ledgerContext = ref.read(ledgerContextProvider);
      if (ledgerContext.currentLedger?.id != null) {
        ref.read(familyGoalListProvider.notifier).loadGoals(ledgerContext.currentLedger!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goalState = ref.watch(familyGoalListProvider);

    // 加载状态
    if (goalState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.familySavingsGoal)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 错误状态
    if (goalState.error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.familySavingsGoal)),
        body: Center(child: Text('加载失败: ${goalState.error}')),
      );
    }

    final goals = goalState.activeGoals;
    final mainGoal = goals.isNotEmpty ? (goalState.pinnedGoals.isNotEmpty ? goalState.pinnedGoals.first : goals.first) : null;

    return Scaffold(
      
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.familySavingsGoal,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddGoalDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mainGoal != null) ...[
                  // 主目标卡片
                  _buildMainGoalCard(mainGoal),
                  // 成员贡献进度
                  _buildContributionsSection(mainGoal, l10n),
                ],
                // 其他目标列表
                _buildOtherGoalsSection(l10n, goals, mainGoal),
                // 存钱记录
                if (mainGoal != null) _buildRecordsSection(l10n, mainGoal.id),
              ],
            ),
          ),
          // 底部存钱按钮
          if (mainGoal != null) _buildDepositButton(l10n, mainGoal),
        ],
      ),
    );
  }

  Widget _buildMainGoalCard(FamilySavingsGoal goal) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${goal.emoji} 进行中的目标',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (goal.daysRemaining != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '还剩 ${goal.daysRemaining} 天',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已存 ¥${goal.currentAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                '目标 ¥${goal.targetAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: goal.progressPercentage / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${goal.progressPercentage.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionsSection(FamilySavingsGoal goal, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.memberContribution,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...goal.contributors.map((c) => _buildContributionCard(c)),
        ],
      ),
    );
  }

  Widget _buildContributionCard(FamilyGoalContributor contributor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                contributor.memberName.isNotEmpty ? contributor.memberName[0] : '?',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      contributor.memberName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '¥${contributor.contribution.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: contributor.percentage / 100,
                          backgroundColor: AppTheme.surfaceVariantColor,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${contributor.percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '贡献次数: ${contributor.contributionCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherGoalsSection(AppLocalizations l10n, List<FamilySavingsGoal> goals, FamilySavingsGoal? mainGoal) {
    final otherGoals = goals.where((g) => g.id != mainGoal?.id).toList();
    if (otherGoals.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.otherSavingsGoals,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...otherGoals.map((goal) => _buildGoalCard(goal)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(FamilySavingsGoal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                goal.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '¥${goal.currentAmount.toStringAsFixed(0)} / ¥${goal.targetAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: goal.progressPercentage / 100,
                    backgroundColor: AppTheme.surfaceVariantColor,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${goal.progressPercentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsSection(AppLocalizations l10n, String goalId) {
    final contributionsAsync = ref.watch(goalContributionsProvider(goalId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recentDeposits,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          contributionsAsync.when(
            data: (contributions) {
              if (contributions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '暂无存入记录',
                      style: TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: contributions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    return Column(
                      children: [
                        _buildRecordItem(record),
                        if (index < contributions.length - 1)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: AppTheme.dividerColor,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('加载失败: $error'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(FamilyGoalContribution record) {
    final timeText = _formatTime(record.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0E0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                record.contributorName.isNotEmpty ? record.contributorName[0] : '?',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.contributorName}存入',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+¥${record.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppTheme.successColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositButton(AppLocalizations l10n, FamilySavingsGoal mainGoal) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () => _showDepositDialog(mainGoal),
          icon: const Icon(Icons.savings, size: 20),
          label: Text(l10n.depositNow),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inHours < 24) {
      return '今天 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${diff.inDays}天前';
    }
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建储蓄目标'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '目标名称',
                hintText: '如：家庭旅行、换新车',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: '目标金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
                const SnackBar(content: Text('储蓄目标已创建')),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog(FamilySavingsGoal mainGoal) {
    final goalState = ref.read(familyGoalListProvider);
    final goals = goalState.activeGoals;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '存入储蓄',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            const TextField(
              decoration: InputDecoration(
                labelText: '存入金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            if (goals.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '选择目标',
                  border: OutlineInputBorder(),
                ),
                initialValue: mainGoal.id,
                items: goals
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text('${g.emoji} ${g.name}'),
                        ))
                    .toList(),
                onChanged: (value) {},
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('存入成功！'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('确认存入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
