import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';

/// 年度总结页面
/// 原型设计 7.03：年度总结
/// - 年度净收入大卡片
/// - 总收入/总支出
/// - 年度亮点（储蓄率、储蓄目标、钱龄）
class AnnualSummaryPage extends ConsumerStatefulWidget {
  final int? year;

  const AnnualSummaryPage({super.key, this.year});

  @override
  ConsumerState<AnnualSummaryPage> createState() => _AnnualSummaryPageState();
}

class _AnnualSummaryPageState extends ConsumerState<AnnualSummaryPage> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.year ?? DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final yearTransactions = transactions.where(
      (t) => t.date.year == _selectedYear,
    ).toList();

    final totalIncome = yearTransactions
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpense = yearTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final netIncome = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netIncome / totalIncome * 100) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeroCard(theme, netIncome, totalIncome, totalExpense),
                    _buildHighlights(theme, savingsRate),
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
          Expanded(
            child: Text(
              '$_selectedYear年度总结',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _shareReport(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.share,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 主角卡片
  Widget _buildHeroCard(
    ThemeData theme,
    double netIncome,
    double totalIncome,
    double totalExpense,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4169E1), Color(0xFF5A85DD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '年度净收入',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${netIncome.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroItem('¥${totalIncome.toStringAsFixed(0)}', '总收入'),
              _buildHeroItem('¥${totalExpense.toStringAsFixed(0)}', '总支出'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  /// 年度亮点
  Widget _buildHighlights(ThemeData theme, double savingsRate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '年度亮点',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildHighlightCard(
            theme,
            icon: Icons.trending_up,
            iconColor: Colors.green,
            iconBgColor: Colors.green,
            title: '储蓄率 ${savingsRate.toStringAsFixed(1)}%',
            subtitle: '超越90%的用户',
          ),
          const SizedBox(height: 8),
          _buildHighlightCard(
            theme,
            icon: Icons.savings,
            iconColor: Colors.white,
            iconBgColor: AppTheme.primaryColor,
            title: '达成3个储蓄目标',
            subtitle: '日本旅行、新电脑、应急基金',
          ),
          const SizedBox(height: 8),
          _buildHighlightCard(
            theme,
            icon: Icons.access_time,
            iconColor: Colors.white,
            iconBgColor: Colors.orange,
            title: '平均钱龄 78天',
            subtitle: '财务健康度良好',
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareReport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享年度总结...')),
    );
  }
}
