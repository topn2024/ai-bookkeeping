import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

class TagStatisticsPage extends ConsumerStatefulWidget {
  const TagStatisticsPage({super.key});

  @override
  ConsumerState<TagStatisticsPage> createState() => _TagStatisticsPageState();
}

class _TagStatisticsPageState extends ConsumerState<TagStatisticsPage> {
  String? _selectedTag;
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final allTags = ref.watch(allTagsProvider);
    final tagStats = ref.watch(tagStatisticsSortedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: '选择月份',
          ),
        ],
      ),
      body: allTags.isEmpty
          ? _buildEmptyState()
          : _selectedTag == null
              ? _buildTagOverview(tagStats)
              : _buildTagDetail(_selectedTag!),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label_off,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无标签数据',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '在记账时添加标签来分类你的支出',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagOverview(List<TagStats> tagStats) {
    // 计算总金额用于百分比
    final totalAmount = tagStats.fold(0.0, (sum, s) => sum + s.totalAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 标签云
        _buildTagCloud(tagStats),
        const SizedBox(height: 24),
        // 标签排行榜
        const Text(
          '标签排行',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...tagStats.asMap().entries.map((entry) {
          final index = entry.key;
          final stats = entry.value;
          final percentage = totalAmount > 0 ? stats.totalAmount / totalAmount : 0.0;

          return _buildTagRankItem(
            rank: index + 1,
            stats: stats,
            percentage: percentage,
          );
        }),
      ],
    );
  }

  Widget _buildTagCloud(List<TagStats> tagStats) {
    // 计算最大和最小金额用于字体大小缩放
    if (tagStats.isEmpty) return const SizedBox.shrink();

    final maxAmount = tagStats.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b);
    final minAmount = tagStats.map((s) => s.totalAmount).reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                '标签云',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: tagStats.map((stats) {
              // 根据金额计算字体大小 (14-28)
              final sizeRange = maxAmount - minAmount;
              final sizeRatio = sizeRange > 0
                  ? (stats.totalAmount - minAmount) / sizeRange
                  : 0.5;
              final fontSize = 14.0 + (sizeRatio * 14);

              // 根据金额计算颜色深度
              final colorOpacity = 0.4 + (sizeRatio * 0.6);

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTag = stats.tag;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:colorOpacity * 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha:colorOpacity * 0.5),
                    ),
                  ),
                  child: Text(
                    '#${stats.tag}',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: AppColors.primary.withValues(alpha:colorOpacity),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagRankItem({
    required int rank,
    required TagStats stats,
    required double percentage,
  }) {
    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        break;
      case 2:
        rankColor = Colors.grey;
        break;
      case 3:
        rankColor = Colors.brown;
        break;
      default:
        rankColor = AppColors.textSecondary;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTag = stats.tag;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
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
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${stats.tag}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${stats.transactionCount}笔',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        rank <= 3 ? rankColor : AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${stats.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagDetail(String tag) {
    final stats = ref.watch(tagStatisticsProvider)[tag];
    if (stats == null) {
      return const Center(child: Text('无数据'));
    }

    return Column(
      children: [
        // 返回按钮和标签信息
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedTag = null;
                  });
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.label, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '#$tag',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 统计信息
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('总交易', '${stats.transactionCount}笔', Icons.receipt_long),
              _buildStatColumn('总支出', '¥${stats.expenseAmount.toStringAsFixed(2)}', Icons.trending_down),
              _buildStatColumn('总收入', '¥${stats.incomeAmount.toStringAsFixed(2)}', Icons.trending_up),
            ],
          ),
        ),
        // 交易列表
        Expanded(
          child: _buildTransactionList(stats.transactions),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text('暂无交易记录'));
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayTransactions = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                DateFormat('MM月dd日 EEEE', 'zh_CN').format(date),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...dayTransactions.map((t) => _buildTransactionItem(t)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isExpense = transaction.type == TransactionType.expense;

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isExpense ? AppColors.expense : AppColors.income).withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isExpense ? Icons.remove : Icons.add,
            color: isExpense ? AppColors.expense : AppColors.income,
            size: 24,
          ),
        ),
        title: Text(
          transaction.category,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.note != null)
              Text(
                transaction.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            if (transaction.tags != null && transaction.tags!.isNotEmpty)
              Wrap(
                spacing: 4,
                children: transaction.tags!.map((tag) => Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                    ),
                  ),
                )).toList(),
              ),
          ],
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isExpense ? AppColors.expense : AppColors.income,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _selectMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (selected != null) {
      setState(() {
        _selectedMonth = selected;
      });
    }
  }
}
