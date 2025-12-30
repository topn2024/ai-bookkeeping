import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../widgets/budget_alert_widget.dart';
import 'quick_entry_page.dart';
import 'image_recognition_page.dart';
import 'voice_recognition_page.dart';
import 'statistics_page.dart';
import 'transaction_list_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    // 获取主题颜色（监听主题变化）
    final colors = ref.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI智能记账'),
        actions: const [
          BudgetAlertIconButton(),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(context, monthlyIncome, monthlyExpense, colors),
            const BudgetAlertBanner(),
            _buildQuickActions(context, colors),
            _buildRecentTransactions(context, transactions, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, double income, double expense, ThemeColors colors) {
    final balance = income - expense;
    final now = DateTime.now();
    final monthName = DateFormat('yyyy年MM月').format(now);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, HSLColor.fromColor(colors.primary).withLightness(0.35).toColor()],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '本月',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '结余',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.arrow_downward,
                            color: Colors.white70, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '收入',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${income.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_upward,
                              color: Colors.white70, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '支出',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${expense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            context,
            icon: Icons.flash_on,
            label: '快速记账',
            color: colors.transfer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuickEntryPage()),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.camera_alt,
            label: '拍照记账',
            color: colors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImageRecognitionPage()),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.mic,
            label: '语音记账',
            color: colors.income,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VoiceRecognitionPage()),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.analytics,
            label: '报表分析',
            color: colors.expense,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context, List<Transaction> transactions, ThemeColors colors) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近交易',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TransactionListPage()),
                  );
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length > 5 ? 5 : transactions.length,
          itemBuilder: (context, index) {
            return _buildTransactionItem(context, transactions[index], colors);
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction, ThemeColors colors) {
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            category?.icon ?? Icons.help_outline,
            color: category?.color ?? Colors.grey,
            size: 24,
          ),
        ),
        title: Text(
          category?.localizedName ?? transaction.category,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          transaction.note ?? DateFormat('MM/dd HH:mm').format(transaction.date),
          style: TextStyle(
            color: theme.colorScheme.outline,
            fontSize: 12,
          ),
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isExpense ? colors.expense : colors.income,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
