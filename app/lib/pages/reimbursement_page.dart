import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import 'transaction_detail_page.dart';

class ReimbursementPage extends ConsumerStatefulWidget {
  const ReimbursementPage({super.key});

  @override
  ConsumerState<ReimbursementPage> createState() => _ReimbursementPageState();
}

class _ReimbursementPageState extends ConsumerState<ReimbursementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(reimbursementStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报销管理'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '待报销'),
            Tab(text: '已报销'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryCard(stats),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(stats.pendingTransactions, isPending: true),
                _buildTransactionList(stats.reimbursedTransactions, isPending: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ReimbursementStats stats) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha:0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha:0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('待报销', stats.pendingReimbursement, stats.pendingCount),
              Container(
                width: 1,
                height: 50,
                color: Colors.white24,
              ),
              _buildStatItem('已报销', stats.totalReimbursed, stats.reimbursedCount),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '报销进度',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '${(stats.reimbursementRate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.reimbursementRate,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, int count) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count 笔',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions, {required bool isPending}) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.receipt_long : Icons.check_circle_outline,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? '暂无待报销记录' : '暂无已报销记录',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // 按日期分组
    final grouped = <String, List<Transaction>>{};
    for (final t in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(t);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayTransactions = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);
        final dayTotal = dayTransactions.fold(0.0, (sum, t) => sum + t.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MM月dd日 EEEE', 'zh_CN').format(date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '¥${dayTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ...dayTransactions.map((t) => _buildTransactionItem(t, isPending)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(Transaction transaction, bool isPending) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(transaction: transaction),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.receipt,
            color: AppColors.expense,
            size: 24,
          ),
        ),
        title: Text(
          transaction.category,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          transaction.note ?? DateFormat('HH:mm').format(transaction.date),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.expense,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPending) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_circle, color: AppColors.income),
                onPressed: () => _markAsReimbursed(transaction),
                tooltip: '标记为已报销',
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _markAsReimbursed(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认报销'),
        content: Text('确定将 ¥${transaction.amount.toStringAsFixed(2)} 标记为已报销吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = transaction.copyWith(isReimbursed: true);
              ref.read(transactionProvider.notifier).updateTransaction(updated);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已标记为报销完成')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
