import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';
import 'transaction_detail_page.dart';

/// 标签筛选页面
/// 管理和筛选标签，查看标签下的交易
class TagFilterPage extends ConsumerStatefulWidget {
  final String? initialTag;

  const TagFilterPage({
    super.key,
    this.initialTag,
  });

  @override
  ConsumerState<TagFilterPage> createState() => _TagFilterPageState();
}

class _TagFilterPageState extends ConsumerState<TagFilterPage> {
  late ThemeColors _themeColors;
  String? _selectedTag;
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.initialTag;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 获取所有标签及其统计
  Map<String, TagInfo> _getTagsWithStats(List<Transaction> transactions) {
    final map = <String, TagInfo>{};

    for (final t in transactions) {
      if (t.tags != null && t.tags!.isNotEmpty) {
        for (final tag in t.tags!) {
          if (!map.containsKey(tag)) {
            map[tag] = TagInfo(tag: tag);
          }
          map[tag]!.transactions.add(t);
          if (t.type == TransactionType.expense) {
            map[tag]!.expenseAmount += t.amount;
          } else if (t.type == TransactionType.income) {
            map[tag]!.incomeAmount += t.amount;
          }
        }
      }
    }

    return map;
  }

  /// 筛选标签
  List<TagInfo> _filterTags(Map<String, TagInfo> allTags) {
    var tags = allTags.values.toList();

    // 搜索筛选
    if (_searchKeyword.isNotEmpty) {
      final lower = _searchKeyword.toLowerCase();
      tags = tags.where((t) => t.tag.toLowerCase().contains(lower)).toList();
    }

    // 按交易数量排序
    tags.sort((a, b) => b.transactions.length.compareTo(a.transactions.length));

    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionProvider);
    _themeColors = ref.themeColors;

    final tagsWithStats = _getTagsWithStats(allTransactions);
    final filteredTags = _filterTags(tagsWithStats);
    final selectedTagInfo = _selectedTag != null ? tagsWithStats[_selectedTag] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTag != null ? '#$_selectedTag' : '标签筛选'),
        leading: _selectedTag != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedTag = null;
                  });
                },
              )
            : null,
      ),
      body: _selectedTag != null && selectedTagInfo != null
          ? _buildTagDetail(selectedTagInfo)
          : _buildTagList(filteredTags),
    );
  }

  Widget _buildTagList(List<TagInfo> tags) {
    return Column(
      children: [
        // 搜索栏
        _buildSearchBar(),
        // 标签云
        if (_searchKeyword.isEmpty && tags.isNotEmpty) _buildTagCloud(tags.take(15).toList()),
        // 标签列表
        Expanded(
          child: tags.isEmpty ? _buildEmptyState() : _buildTagListView(tags),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索标签...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchKeyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchKeyword = '';
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchKeyword = value;
          });
        },
      ),
    );
  }

  Widget _buildTagCloud(List<TagInfo> tags) {
    if (tags.isEmpty) return const SizedBox();

    // 计算大小范围
    final maxCount = tags.map((t) => t.transactions.length).reduce((a, b) => a > b ? a : b);
    final minCount = tags.map((t) => t.transactions.length).reduce((a, b) => a < b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: _themeColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
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
            spacing: 10,
            runSpacing: 10,
            children: tags.map((tagInfo) {
              // 根据数量计算大小
              final sizeRange = maxCount - minCount;
              final sizeRatio = sizeRange > 0
                  ? (tagInfo.transactions.length - minCount) / sizeRange
                  : 0.5;
              final fontSize = 12.0 + (sizeRatio * 10);
              final opacity = 0.5 + (sizeRatio * 0.5);

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTag = tagInfo.tag;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _themeColors.primary.withValues(alpha: opacity * 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _themeColors.primary.withValues(alpha: opacity * 0.4),
                    ),
                  ),
                  child: Text(
                    '#${tagInfo.tag}',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: _themeColors.primary.withValues(alpha: opacity),
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

  Widget _buildTagListView(List<TagInfo> tags) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tagInfo = tags[index];
        return _buildTagListItem(tagInfo, index + 1);
      },
    );
  }

  Widget _buildTagListItem(TagInfo tagInfo, int rank) {
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
          _selectedTag = tagInfo.tag;
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 排名
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.1),
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
            // 标签信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _themeColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${tagInfo.tag}',
                          style: TextStyle(
                            color: _themeColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tagInfo.transactions.length}笔',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 收支统计
                  Row(
                    children: [
                      if (tagInfo.expenseAmount > 0)
                        Text(
                          '支出 ¥${tagInfo.expenseAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _themeColors.expense,
                            fontSize: 12,
                          ),
                        ),
                      if (tagInfo.expenseAmount > 0 && tagInfo.incomeAmount > 0)
                        const Text(
                          ' | ',
                          style: TextStyle(color: AppColors.textHint, fontSize: 12),
                        ),
                      if (tagInfo.incomeAmount > 0)
                        Text(
                          '收入 ¥${tagInfo.incomeAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _themeColors.income,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildTagDetail(TagInfo tagInfo) {
    final transactions = tagInfo.transactions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // 按日期分组
    final grouped = <String, List<Transaction>>{};
    for (final t in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(t);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // 统计卡片
        _buildTagStatCard(tagInfo),
        // 交易列表
        Expanded(
          child: ListView.builder(
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final dayTransactions = grouped[dateKey]!;
              final date = DateTime.parse(dateKey);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  ...dayTransactions.map((t) => _buildTransactionItem(t)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTagStatCard(TagInfo tagInfo) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_themeColors.primary, _themeColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _themeColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.label, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '#${tagInfo.tag}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('总交易', '${tagInfo.transactions.length}笔'),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              _buildStatColumn('支出', '¥${tagInfo.expenseAmount.toStringAsFixed(0)}'),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              _buildStatColumn('收入', '¥${tagInfo.incomeAmount.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                category?.icon ?? Icons.help_outline,
                color: category?.color ?? Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note ?? category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(transaction.category),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(transaction.category),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        ' · ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        DateFormat('HH:mm').format(transaction.date),
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
          Text(
            _searchKeyword.isNotEmpty ? '没有找到相关标签' : '暂无标签',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '在记账时添加标签来分类管理',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
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
}

/// 标签信息模型
class TagInfo {
  final String tag;
  final List<Transaction> transactions = [];
  double expenseAmount = 0;
  double incomeAmount = 0;

  TagInfo({required this.tag});

  double get totalAmount => expenseAmount + incomeAmount;
}
