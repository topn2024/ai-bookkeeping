import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/member_statistics_provider.dart';
import '../providers/ledger_context_provider.dart';

/// 15.10 家庭排行榜与激励页面
class FamilyLeaderboardPage extends ConsumerStatefulWidget {
  const FamilyLeaderboardPage({super.key});

  @override
  ConsumerState<FamilyLeaderboardPage> createState() => _FamilyLeaderboardPageState();
}

class _FamilyLeaderboardPageState extends ConsumerState<FamilyLeaderboardPage> {
  String _selectedPeriod = '本周';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerContext = ref.watch(ledgerContextProvider);
    final ledgerId = ledgerContext.currentLedger?.id;

    if (ledgerId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.familyLeaderboard)),
        body: const Center(child: Text('请先选择账本')),
      );
    }

    final rankings = ref.watch(memberSpendingRankProvider(ledgerId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.familyLeaderboard,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('奖杯功能开发中')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间周期选择
            _buildPeriodSelector(),
            // 记账排行榜
            _buildRecordRanking(l10n, rankings),
            // 预算执行排行榜
            _buildBudgetRanking(l10n, rankings),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['本周', '本月', '本年'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecordRanking(AppLocalizations l10n, List<MemberSpendingStats> rankings) {
    if (rankings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: Text('暂无数据')),
        ),
      );
    }

    final sortedByRecord = List<MemberSpendingStats>.from(rankings)
      ..sort((a, b) => b.transactionCount.compareTo(a.transactionCount));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 8),
              Text(
                l10n.recordLeaderboard,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 第一名
                _buildTopRanker(sortedByRecord[0], 1),
                if (sortedByRecord.length > 1) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  // 其他排名
                  ...sortedByRecord.skip(1).toList().asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildRanker(entry.value, entry.key + 2),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRanker(MemberSpendingStats member, int rank) {
    final medals = ['🥇', '🥈', '🥉'];
    final memberInitial = member.memberName.isNotEmpty ? member.memberName[0] : '?';

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFFFD700), width: 3),
              ),
              child: Center(
                child: Text(
                  memberInitial,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: Text(
                medals[rank - 1],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.memberName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_selectedPeriod记账 ${member.transactionCount} 笔',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${member.totalExpense.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF6B00),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRanker(MemberSpendingStats member, int rank) {
    final medals = ['🥇', '🥈', '🥉'];
    final memberInitial = member.memberName.isNotEmpty ? member.memberName[0] : '?';

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
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
                  memberInitial,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            if (rank <= 3)
              Positioned(
                top: -4,
                right: -4,
                child: Text(
                  medals[rank - 1],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.memberName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '记账 ${member.transactionCount} 笔',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          '¥${member.totalExpense.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF78909C),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetRanking(AppLocalizations l10n, List<MemberSpendingStats> rankings) {
    if (rankings.isEmpty) return const SizedBox.shrink();

    final sortedByBudget = rankings.where((m) => m.budgetLimit > 0).toList()
      ..sort((a, b) => a.budgetPercent.compareTo(b.budgetPercent));

    if (sortedByBudget.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: Text('暂无预算数据')),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.successColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                '预算执行排行',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: sortedByBudget.map((member) {
                final memberInitial = member.memberName.isNotEmpty ? member.memberName[0] : '?';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            memberInitial,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.memberName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '预算执行率 ${member.budgetPercent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '¥${member.budgetUsage.toStringAsFixed(0)}/¥${member.budgetLimit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: member.budgetPercent > 100 ? Colors.red : AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
