import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import 'transaction_detail_page.dart';
import 'advanced_filter_page.dart';

/// 搜索结果页面
/// 显示搜索关键词匹配的交易结果，支持高亮显示匹配文字
class SearchResultPage extends ConsumerStatefulWidget {
  final String initialKeyword;

  const SearchResultPage({
    super.key,
    required this.initialKeyword,
  });

  @override
  ConsumerState<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends ConsumerState<SearchResultPage> {
  late ThemeColors _themeColors;
  late TextEditingController _searchController;
  String _keyword = '';
  FilterCriteria? _filterCriteria;

  // 防抖定时器
  DateTime? _lastSearchTime;

  @override
  void initState() {
    super.initState();
    _keyword = widget.initialKeyword;
    _searchController = TextEditingController(text: _keyword);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 搜索交易
  List<Transaction> _searchTransactions(List<Transaction> transactions) {
    if (_keyword.isEmpty && (_filterCriteria == null || !_filterCriteria!.hasAnyFilter)) {
      return [];
    }

    var results = transactions;

    // 先应用筛选条件
    if (_filterCriteria != null && _filterCriteria!.hasAnyFilter) {
      results = _filterCriteria!.apply(results);
    }

    // 再应用关键词搜索
    if (_keyword.isNotEmpty) {
      final lowerKeyword = _keyword.toLowerCase();
      results = results.where((t) {
        // 搜索备注
        if (t.note != null && t.note!.toLowerCase().contains(lowerKeyword)) {
          return true;
        }
        // 搜索分类名称
        final category = DefaultCategories.findById(t.category);
        if (category != null && category.localizedName.toLowerCase().contains(lowerKeyword)) {
          return true;
        }
        // 搜索标签
        if (t.tags != null && t.tags!.any((tag) => tag.toLowerCase().contains(lowerKeyword))) {
          return true;
        }
        // 搜索金额
        if (t.amount.toString().contains(_keyword)) {
          return true;
        }
        return false;
      }).toList();
    }

    // 按日期排序
    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  void _onSearchChanged(String value) {
    final now = DateTime.now();
    _lastSearchTime = now;

    // 防抖：300ms后执行搜索
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_lastSearchTime == now && mounted) {
        setState(() {
          _keyword = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionProvider);
    final searchResults = _searchTransactions(allTransactions);
    _themeColors = ref.themeColors;

    // 计算汇总
    final totalIncome = searchResults
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = searchResults
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filterCriteria?.hasAnyFilter ?? false,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showFilterSheet,
            tooltip: '筛选',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 搜索结果统计
          if (_keyword.isNotEmpty || (_filterCriteria?.hasAnyFilter ?? false))
            _buildResultSummary(searchResults.length, totalIncome, totalExpense),
          // 搜索结果列表
          Expanded(
            child: _keyword.isEmpty && !(_filterCriteria?.hasAnyFilter ?? false)
                ? _buildEmptyHint()
                : searchResults.isEmpty
                    ? _buildNoResults()
                    : _buildResultList(searchResults),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        autofocus: widget.initialKeyword.isEmpty,
        decoration: InputDecoration(
          hintText: '搜索备注、分类、标签...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _keyword = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          setState(() {
            _keyword = value;
          });
        },
      ),
    );
  }

  Widget _buildResultSummary(int count, double income, double expense) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              children: [
                const TextSpan(text: '找到 '),
                TextSpan(
                  text: '$count',
                  style: TextStyle(
                    color: _themeColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' 条结果'),
              ],
            ),
          ),
          const Spacer(),
          if (income > 0)
            Text(
              '+¥${income.toStringAsFixed(0)}',
              style: TextStyle(
                color: _themeColors.income,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (income > 0 && expense > 0) const SizedBox(width: 12),
          if (expense > 0)
            Text(
              '-¥${expense.toStringAsFixed(0)}',
              style: TextStyle(
                color: _themeColors.expense,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            '输入关键词开始搜索',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '支持搜索备注、分类名称、标签',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到"$_keyword"的相关结果',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '试试其他关键词或调整筛选条件',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
          if (_filterCriteria?.hasAnyFilter ?? false) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _filterCriteria = null;
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('清除筛选'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultList(List<Transaction> results) {
    // 按日期分组
    final grouped = <String, List<Transaction>>{};
    for (final t in results) {
      final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(t);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayTransactions = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期头
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.background,
              child: Text(
                _formatDateHeader(date),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // 当日交易
            ...dayTransactions.map((t) => _buildTransactionItem(t)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(transaction: transaction),
          ),
        ).then((_) => ref.read(transactionProvider.notifier).refresh());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            // 分类图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category?.icon ?? Icons.help_outline,
                color: category?.color ?? Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题（高亮搜索词）
                  _buildHighlightedText(
                    transaction.note ?? category?.localizedName ?? transaction.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 分类和时间
                  Row(
                    children: [
                      if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                        _buildHighlightedText(
                          category?.localizedName ?? transaction.category,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                      Text(
                        DateFormat('HH:mm').format(transaction.date),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // 标签
                  if (transaction.tags != null && transaction.tags!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: transaction.tags!.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _themeColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildHighlightedText(
                            '#$tag',
                            style: TextStyle(
                              color: _themeColors.primary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            // 金额
            Text(
              '${isExpense ? '-' : (isIncome ? '+' : '')}¥${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isExpense
                    ? _themeColors.expense
                    : (isIncome ? _themeColors.income : _themeColors.transfer),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建高亮文本
  Widget _buildHighlightedText(String text, {TextStyle? style}) {
    if (_keyword.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = _keyword.toLowerCase();
    final index = lowerText.indexOf(lowerKeyword);

    if (index == -1) {
      return Text(text, style: style);
    }

    return RichText(
      text: TextSpan(
        style: style ?? const TextStyle(color: AppColors.textPrimary),
        children: [
          if (index > 0) TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + _keyword.length),
            style: TextStyle(
              backgroundColor: _themeColors.primary.withValues(alpha: 0.2),
              color: _themeColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (index + _keyword.length < text.length)
            TextSpan(text: text.substring(index + _keyword.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '今天';
    } else if (targetDate == yesterday) {
      return '昨天';
    } else if (date.year == now.year) {
      return DateFormat('MM月dd日 E', 'zh_CN').format(date);
    } else {
      return DateFormat('yyyy年MM月dd日').format(date);
    }
  }

  Future<void> _showFilterSheet() async {
    final result = await AdvancedFilterPage.showAsBottomSheet(
      context,
      initialCriteria: _filterCriteria,
    );

    if (result != null) {
      setState(() {
        _filterCriteria = result;
      });
    }
  }
}
