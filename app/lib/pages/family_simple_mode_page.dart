import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/member_statistics_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/ledger_context_provider.dart';
import '../models/transaction.dart';

/// 15.13 家庭账本简单模式页面
/// 精简版家庭账本，适合双人记账场景
class FamilySimpleModePage extends ConsumerStatefulWidget {
  final String familyName;

  const FamilySimpleModePage({
    super.key,
    required this.familyName,
  });

  @override
  ConsumerState<FamilySimpleModePage> createState() => _FamilySimpleModePageState();
}

class _FamilySimpleModePageState extends ConsumerState<FamilySimpleModePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerContext = ref.watch(ledgerContextProvider);
    final ledgerId = ledgerContext.currentLedger?.id;

    if (ledgerId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.familyName)),
        body: const Center(child: Text('请先选择账本')),
      );
    }

    final memberStats = ref.watch(memberSpendingRankProvider(ledgerId));
    final allTransactions = ref.watch(transactionProvider);

    // 获取本月交易
    final now = DateTime.now();
    final monthTransactions = allTransactions.where((t) =>
      t.date.year == now.year && t.date.month == now.month
    ).toList();

    // 计算总支出
    final totalExpense = memberStats.fold<double>(0, (sum, m) => sum + m.totalExpense);

    // 获取最近的交易（最多5条）
    final recentTransactions = monthTransactions.take(5).toList();

    final lastMonthDiff = 0.0; // TODO: 计算与上月的差异

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.familyName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.simpleMode,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 共同支出总览
            _buildTotalExpenseCard(totalExpense, lastMonthDiff, l10n),
            // 成员贡献
            _buildMemberContributions(l10n, memberStats, totalExpense),
            // 温馨提示
            _buildWarmTip(),
            // 最近记录
            _buildRecentTransactions(l10n, recentTransactions),
            // 升级提示
            _buildUpgradeHint(l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalExpenseCard(double total, double diff, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            l10n.monthlySharedExpense,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Color(0xFFBF360C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diff < 0
                ? '比上月少花了¥${(-diff).toStringAsFixed(0)}'
                : '比上月多花了¥${diff.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              color: diff < 0 ? const Color(0xFF4CAF50) : const Color(0xFFF57C00),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberContributions(AppLocalizations l10n, List<MemberSpendingStats> memberStats, double totalExpense) {
    if (memberStats.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('暂无成员数据')),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.memberContribution,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
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
              children: memberStats.asMap().entries.map((entry) {
                final index = entry.key;
                final member = entry.value;
                final isLast = index == memberStats.length - 1;
                final percentage = totalExpense > 0 ? member.totalExpense / totalExpense : 0.0;

                return Column(
                  children: [
                    _buildMemberExpenseItem(member, percentage),
                    if (!isLast)
                      Divider(
                        height: 28,
                        color: AppTheme.dividerColor,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberExpenseItem(MemberSpendingStats member, double percentage) {
    final memberInitial = member.memberName.isNotEmpty ? member.memberName[0] : '?';

    return Row(
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
                fontSize: 20,
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
                    member.memberName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '¥${member.totalExpense.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: AppTheme.surfaceVariantColor,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(percentage * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarmTip() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFE082)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Text(
            '💕',
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '你们配合得真好，记账习惯很一致！',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFE65100),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(AppLocalizations l10n, List<Transaction> transactions) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentRecords,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('查看全部功能开发中')),
                  );
                },
                child: Text(
                  l10n.viewAll,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('暂无交易记录')),
            )
          else
            Container(
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
                children: transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tx = entry.value;
                  final isLast = index == transactions.length - 1;

                  return Column(
                    children: [
                      _buildTransactionItem(tx),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 60,
                          color: AppTheme.dividerColor,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction tx) {
    final timeStr = _formatTime(tx.date);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                tx.category.isNotEmpty ? tx.category[0] : '?',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note ?? tx.category,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            tx.type == TransactionType.expense
                ? '-¥${tx.amount.toStringAsFixed(0)}'
                : '+¥${tx.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tx.type == TransactionType.expense
                  ? AppTheme.expenseColor
                  : AppTheme.incomeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeHint(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUpgradeDialog(l10n),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upgrade, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  l10n.upgradeToFullMode,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day && time.month == now.month) {
      return '今天 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showUpgradeDialog(AppLocalizations l10n) {
    Navigator.pushNamed(context, '/mode-upgrade');
  }
}
