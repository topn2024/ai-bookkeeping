import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 成员消费数据
class SimpleModeExpense {
  final String memberId;
  final String memberName;
  final String memberEmoji;
  final Color memberColor;
  final double amount;
  final double percentage;

  SimpleModeExpense({
    required this.memberId,
    required this.memberName,
    required this.memberEmoji,
    required this.memberColor,
    required this.amount,
    required this.percentage,
  });
}

/// 简单模式交易记录
class SimpleModeTransaction {
  final String id;
  final String category;
  final String categoryEmoji;
  final String description;
  final String memberName;
  final double amount;
  final DateTime time;

  SimpleModeTransaction({
    required this.id,
    required this.category,
    required this.categoryEmoji,
    required this.description,
    required this.memberName,
    required this.amount,
    required this.time,
  });
}

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
  late List<SimpleModeExpense> _expenses;
  late List<SimpleModeTransaction> _transactions;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    _expenses = [
      SimpleModeExpense(
        memberId: '1',
        memberName: '小明',
        memberEmoji: '👨',
        memberColor: const Color(0xFF42A5F5),
        amount: 4280,
        percentage: 0.5,
      ),
      SimpleModeExpense(
        memberId: '2',
        memberName: '小红',
        memberEmoji: '👩',
        memberColor: const Color(0xFFE91E63),
        amount: 4280,
        percentage: 0.5,
      ),
    ];

    _transactions = [
      SimpleModeTransaction(
        id: '1',
        category: '餐饮',
        categoryEmoji: '🍜',
        description: '晚餐-海底捞',
        memberName: '小明',
        amount: 286,
        time: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      SimpleModeTransaction(
        id: '2',
        category: '购物',
        categoryEmoji: '🛒',
        description: '超市采购',
        memberName: '小红',
        amount: 158,
        time: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalExpense = _expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final lastMonthDiff = -320.0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
              l10n?.simpleMode ?? '简单模式',
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
            _buildMemberContributions(l10n),
            // 温馨提示
            _buildWarmTip(),
            // 最近记录
            _buildRecentTransactions(l10n),
            // 升级提示
            _buildUpgradeHint(l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalExpenseCard(double total, double diff, AppLocalizations? l10n) {
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
            l10n?.monthlySharedExpense ?? '本月共同支出',
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

  Widget _buildMemberContributions(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.memberContribution ?? '成员贡献',
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
              children: _expenses.asMap().entries.map((entry) {
                final index = entry.key;
                final expense = entry.value;
                final isLast = index == _expenses.length - 1;

                return Column(
                  children: [
                    _buildMemberExpenseItem(expense),
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

  Widget _buildMemberExpenseItem(SimpleModeExpense expense) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [expense.memberColor, expense.memberColor.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              expense.memberEmoji,
              style: const TextStyle(fontSize: 20),
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
                    expense.memberName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '¥${expense.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: expense.memberColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: expense.percentage,
                  backgroundColor: AppTheme.surfaceVariantColor,
                  valueColor: AlwaysStoppedAnimation<Color>(expense.memberColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(expense.percentage * 100).toStringAsFixed(0)}%',
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

  Widget _buildRecentTransactions(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.recentRecords ?? '最近记录',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  l10n?.viewAll ?? '查看全部',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
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
              children: _transactions.asMap().entries.map((entry) {
                final index = entry.key;
                final tx = entry.value;
                final isLast = index == _transactions.length - 1;

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

  Widget _buildTransactionItem(SimpleModeTransaction tx) {
    final timeStr = _formatTime(tx.time);

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
                tx.categoryEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${tx.memberName} · $timeStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-¥${tx.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.expenseColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeHint(AppLocalizations? l10n) {
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
                  l10n?.upgradeToFullMode ?? '升级到完整模式，解锁更多功能',
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

  void _showUpgradeDialog(AppLocalizations? l10n) {
    Navigator.pushNamed(context, '/mode-upgrade');
  }
}
