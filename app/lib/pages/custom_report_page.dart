import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import '../models/category.dart';
import '../extensions/extensions.dart';

/// 报表维度
enum ReportDimension {
  category,  // 按分类
  account,   // 按账户
  time,      // 按时间
  tag,       // 按标签
}

/// 时间粒度
enum TimeGranularity {
  day,
  week,
  month,
  year,
}

/// 报表类型
enum ReportType {
  expense,
  income,
  both,
}

class CustomReportPage extends ConsumerStatefulWidget {
  const CustomReportPage({super.key});

  @override
  ConsumerState<CustomReportPage> createState() => _CustomReportPageState();
}

class _CustomReportPageState extends ConsumerState<CustomReportPage> {
  ReportDimension _dimension = ReportDimension.category;
  TimeGranularity _granularity = TimeGranularity.month;
  ReportType _reportType = ReportType.expense;
  DateTimeRange? _dateRange;
  String? _selectedCategory;
  String? _selectedAccount;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义报表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterSheet,
            tooltip: '筛选条件',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickFilters(),
          _buildDateRangeSelector(),
          Expanded(
            child: _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              label: '支出',
              selected: _reportType == ReportType.expense,
              onSelected: () => setState(() => _reportType = ReportType.expense),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              label: '收入',
              selected: _reportType == ReportType.income,
              onSelected: () => setState(() => _reportType = ReportType.income),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              label: '全部',
              selected: _reportType == ReportType.both,
              onSelected: () => setState(() => _reportType = ReportType.both),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _dateRange != null
                          ? '${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}'
                          : '选择日期范围',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<TimeGranularity>(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(_getGranularityLabel(_granularity)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
            onSelected: (value) => setState(() => _granularity = value),
            itemBuilder: (context) => TimeGranularity.values.map((g) {
              return PopupMenuItem(
                value: g,
                child: Text(_getGranularityLabel(g)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final transactions = ref.watch(transactionProvider);
    final filteredTransactions = _filterTransactions(transactions);

    if (filteredTransactions.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCard(filteredTransactions),
          const SizedBox(height: 16),
          _buildDimensionSelector(),
          const SizedBox(height: 16),
          _buildReportData(filteredTransactions),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<Transaction> transactions) {
    double totalExpense = 0;
    double totalIncome = 0;

    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
      } else if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha:0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('总支出', totalExpense, Colors.white70),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem('总收入', totalIncome, Colors.white70),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem('净收支', totalIncome - totalExpense, Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '共 ${transactions.length} 笔交易',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    final isPositive = amount >= 0;
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '${isPositive ? '' : '-'}¥${amount.abs().toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('统计维度', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: ReportDimension.values.map((d) {
              final isSelected = _dimension == d;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _dimension = d),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha:0.1) : null,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _getDimensionLabel(d),
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
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

  Widget _buildReportData(List<Transaction> transactions) {
    switch (_dimension) {
      case ReportDimension.category:
        return _buildCategoryReport(transactions);
      case ReportDimension.account:
        return _buildAccountReport(transactions);
      case ReportDimension.time:
        return _buildTimeReport(transactions);
      case ReportDimension.tag:
        return _buildTagReport(transactions);
    }
  }

  Widget _buildCategoryReport(List<Transaction> transactions) {
    final categoryMap = <String, double>{};
    for (final t in transactions) {
      categoryMap[t.category] = (categoryMap[t.category] ?? 0) + t.amount;
    }

    final sortedEntries = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedEntries.fold(0.0, (sum, e) => sum + e.value);

    return _buildReportCard(
      title: '按分类统计',
      children: sortedEntries.map((entry) {
        final category = DefaultCategories.findById(entry.key);
        final percentage = total > 0 ? entry.value / total : 0.0;
        return _buildReportItem(
          icon: category?.icon ?? Icons.help_outline,
          color: category?.color ?? Colors.grey,
          title: category?.localizedName ?? entry.key,
          amount: entry.value,
          percentage: percentage,
        );
      }).toList(),
    );
  }

  Widget _buildAccountReport(List<Transaction> transactions) {
    final accounts = ref.watch(accountProvider);
    final accountMap = <String, double>{};
    for (final t in transactions) {
      accountMap[t.accountId] = (accountMap[t.accountId] ?? 0) + t.amount;
    }

    final sortedEntries = accountMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedEntries.fold(0.0, (sum, e) => sum + e.value);

    return _buildReportCard(
      title: '按账户统计',
      children: sortedEntries.map((entry) {
        final account = accounts.where((a) => a.id == entry.key).firstOrNull;
        final percentage = total > 0 ? entry.value / total : 0.0;
        return _buildReportItem(
          icon: account?.icon ?? Icons.account_balance_wallet,
          color: account?.color ?? Colors.grey,
          title: account?.localizedName ?? entry.key,
          amount: entry.value,
          percentage: percentage,
        );
      }).toList(),
    );
  }

  Widget _buildTimeReport(List<Transaction> transactions) {
    final timeMap = <String, double>{};

    for (final t in transactions) {
      String key;
      switch (_granularity) {
        case TimeGranularity.day:
          key = DateFormat('MM/dd').format(t.date);
          break;
        case TimeGranularity.week:
          final weekNum = ((t.date.day - 1) ~/ 7) + 1;
          key = '${t.date.month}月第$weekNum周';
          break;
        case TimeGranularity.month:
          key = DateFormat('yyyy/MM').format(t.date);
          break;
        case TimeGranularity.year:
          key = '${t.date.year}年';
          break;
      }
      timeMap[key] = (timeMap[key] ?? 0) + t.amount;
    }

    final sortedEntries = timeMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final total = sortedEntries.fold(0.0, (sum, e) => sum + e.value);
    final avg = sortedEntries.isNotEmpty ? total / sortedEntries.length : 0.0;

    return _buildReportCard(
      title: '按时间统计 (平均: ¥${avg.toStringAsFixed(2)})',
      children: sortedEntries.map((entry) {
        final percentage = total > 0 ? entry.value / total : 0.0;
        return _buildReportItem(
          icon: Icons.calendar_today,
          color: AppColors.primary,
          title: entry.key,
          amount: entry.value,
          percentage: percentage,
        );
      }).toList(),
    );
  }

  Widget _buildTagReport(List<Transaction> transactions) {
    final tagMap = <String, double>{};

    for (final t in transactions) {
      if (t.tags != null && t.tags!.isNotEmpty) {
        for (final tag in t.tags!) {
          tagMap[tag] = (tagMap[tag] ?? 0) + t.amount;
        }
      } else {
        tagMap['无标签'] = (tagMap['无标签'] ?? 0) + t.amount;
      }
    }

    final sortedEntries = tagMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedEntries.fold(0.0, (sum, e) => sum + e.value);

    return _buildReportCard(
      title: '按标签统计',
      children: sortedEntries.map((entry) {
        final percentage = total > 0 ? entry.value / total : 0.0;
        return _buildReportItem(
          icon: Icons.label,
          color: entry.key == '无标签' ? Colors.grey : AppColors.primary,
          title: entry.key == '无标签' ? entry.key : '#${entry.key}',
          amount: entry.value,
          percentage: percentage,
        );
      }).toList(),
    );
  }

  Widget _buildReportCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReportItem({
    required IconData icon,
    required Color color,
    required String title,
    required double amount,
    required double percentage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
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
                    '¥${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('请调整筛选条件', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    return transactions.where((t) {
      // Filter by date range
      if (_dateRange != null) {
        if (t.date.isBefore(_dateRange!.start) || t.date.isAfter(_dateRange!.end)) {
          return false;
        }
      }

      // Filter by type
      if (_reportType == ReportType.expense && t.type != TransactionType.expense) {
        return false;
      }
      if (_reportType == ReportType.income && t.type != TransactionType.income) {
        return false;
      }
      if (_reportType == ReportType.both && t.type == TransactionType.transfer) {
        return false;
      }

      // Filter by category
      if (_selectedCategory != null && t.category != _selectedCategory) {
        return false;
      }

      // Filter by account
      if (_selectedAccount != null && t.accountId != _selectedAccount) {
        return false;
      }

      return true;
    }).toList();
  }

  void _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (result != null) {
      setState(() => _dateRange = result);
    }
  }

  void _showFilterSheet() {
    final accounts = ref.read(accountProvider);

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
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            const Text('高级筛选', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('账户筛选'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部账户'),
                  selected: _selectedAccount == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAccount = null);
                      Navigator.pop(context);
                    }
                  },
                ),
                ...accounts.map((account) => ChoiceChip(
                  label: Text(account.localizedName),
                  selected: _selectedAccount == account.id,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAccount = account.id);
                      Navigator.pop(context);
                    }
                  },
                )),
              ],
            ),
            const SizedBox(height: 20),
            const Text('分类筛选'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部分类'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = null);
                      Navigator.pop(context);
                    }
                  },
                ),
                ...DefaultCategories.expenseCategories.take(10).map((category) => ChoiceChip(
                  label: Text(category.localizedName),
                  selected: _selectedCategory == category.id,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = category.id);
                      Navigator.pop(context);
                    }
                  },
                )),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedAccount = null;
                  _selectedCategory = null;
                });
                Navigator.pop(context);
              },
              child: const Text('重置筛选'),
            ),
          ],
        ),
      ),
    );
  }

  String _getDimensionLabel(ReportDimension dimension) {
    switch (dimension) {
      case ReportDimension.category:
        return '分类';
      case ReportDimension.account:
        return '账户';
      case ReportDimension.time:
        return '时间';
      case ReportDimension.tag:
        return '标签';
    }
  }

  String _getGranularityLabel(TimeGranularity granularity) {
    switch (granularity) {
      case TimeGranularity.day:
        return '按天';
      case TimeGranularity.week:
        return '按周';
      case TimeGranularity.month:
        return '按月';
      case TimeGranularity.year:
        return '按年';
    }
  }
}
