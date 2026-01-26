import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../extensions/extensions.dart';
import '../services/category_localization_service.dart';
import '../widgets/source_image_viewer.dart';
import '../widgets/source_audio_player.dart';
import '../widgets/swipeable_transaction_item.dart';
import 'add_transaction_page.dart';
import 'transaction_detail_page.dart';
import 'search_result_page.dart';
import 'advanced_filter_page.dart';

/// 流水查询页面
/// 支持按日期、类型、分类、金额筛选，支持关键词搜索
class TransactionListPage extends ConsumerStatefulWidget {
  /// 初始分类筛选（如 "餐饮"、"交通" 等）
  final String? initialCategory;

  /// 初始来源筛选（如 "支付宝"、"微信" 等）
  final String? initialSource;

  /// 初始日期范围筛选
  final DateTimeRange? initialDateRange;

  const TransactionListPage({
    super.key,
    this.initialCategory,
    this.initialSource,
    this.initialDateRange,
  });

  @override
  ConsumerState<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  // 主题颜色
  late ThemeColors _themeColors;

  // 当前展开操作按钮的条目ID
  String? _activeItemId;

  // 筛选条件
  TransactionType? _selectedType;
  String? _selectedCategory;
  String? _selectedSource;  // 来源筛选
  DateTimeRange? _dateRange;
  double? _minAmount;
  double? _maxAmount;
  String _searchKeyword = '';

  // 排序
  SortOption _sortOption = SortOption.dateDesc;

  // 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  // 是否显示筛选面板
  final bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    // 从构造函数参数初始化筛选条件
    if (widget.initialCategory != null) {
      _selectedCategory = _mapCategoryNameToId(widget.initialCategory!);
    }
    if (widget.initialSource != null) {
      _selectedSource = widget.initialSource;
    }
    if (widget.initialDateRange != null) {
      _dateRange = widget.initialDateRange;
    }
  }

  /// 将分类名称映射为分类ID
  String _mapCategoryNameToId(String categoryName) {
    // 常见分类名称到ID的映射
    const categoryMap = {
      '餐饮': 'food',
      '交通': 'transport',
      '购物': 'shopping',
      '娱乐': 'entertainment',
      '居住': 'housing',
      '医疗': 'medical',
      '其他': 'other',
    };
    return categoryMap[categoryName] ?? categoryName.toLowerCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _filterAndSortTransactions(List<Transaction> transactions) {
    var filtered = transactions.where((t) {
      // 类型筛选
      if (_selectedType != null && t.type != _selectedType) {
        return false;
      }

      // 分类筛选
      if (_selectedCategory != null && t.category != _selectedCategory) {
        return false;
      }

      // 来源筛选
      if (_selectedSource != null) {
        final sourceMatch = _matchSource(t, _selectedSource!);
        if (!sourceMatch) {
          return false;
        }
      }

      // 日期范围筛选
      if (_dateRange != null) {
        if (t.date.isBefore(_dateRange!.start) ||
            t.date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // 金额范围筛选
      if (_minAmount != null && t.amount < _minAmount!) {
        return false;
      }
      if (_maxAmount != null && t.amount > _maxAmount!) {
        return false;
      }

      // 关键词搜索（备注）
      if (_searchKeyword.isNotEmpty) {
        final keyword = _searchKeyword.toLowerCase();
        final note = (t.note ?? '').toLowerCase();
        final categoryName = DefaultCategories.findById(t.category)?.name.toLowerCase() ?? '';
        if (!note.contains(keyword) && !categoryName.contains(keyword)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 排序
    switch (_sortOption) {
      case SortOption.dateDesc:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortOption.dateAsc:
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortOption.amountDesc:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortOption.amountAsc:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return filtered;
  }

  /// 匹配交易来源
  bool _matchSource(Transaction t, String source) {
    final sourceLower = source.toLowerCase();
    // 检查 externalSource 字段（枚举类型，需要转换为字符串）
    if (t.externalSource != null && t.externalSource!.name.toLowerCase().contains(sourceLower)) {
      return true;
    }
    // 检查备注中是否包含来源关键词
    if (t.note != null && t.note!.toLowerCase().contains(sourceLower)) {
      return true;
    }
    // 检查 rawMerchant 字段
    if (t.rawMerchant != null && t.rawMerchant!.toLowerCase().contains(sourceLower)) {
      return true;
    }
    return false;
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedCategory = null;
      _selectedSource = null;
      _dateRange = null;
      _minAmount = null;
      _maxAmount = null;
      _searchKeyword = '';
      _searchController.clear();
    });
  }

  bool get _hasActiveFilters {
    return _selectedType != null ||
        _selectedCategory != null ||
        _selectedSource != null ||
        _dateRange != null ||
        _minAmount != null ||
        _maxAmount != null ||
        _searchKeyword.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionProvider);
    final filteredTransactions = _filterAndSortTransactions(transactions);
    // 获取主题颜色（监听变化）
    _themeColors = ref.themeColors;

    // 按日期分组
    final groupedTransactions = _groupByDate(filteredTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('流水查询'),
        actions: [
          // 排序按钮
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (option) {
              setState(() {
                _sortOption = option;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortOption.dateDesc,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      color: _sortOption == SortOption.dateDesc
                          ? _themeColors.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    const Text('时间从新到旧'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.dateAsc,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      color: _sortOption == SortOption.dateAsc
                          ? _themeColors.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    const Text('时间从旧到新'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.amountDesc,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      color: _sortOption == SortOption.amountDesc
                          ? _themeColors.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    const Text('金额从高到低'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.amountAsc,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      color: _sortOption == SortOption.amountAsc
                          ? _themeColors.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    const Text('金额从低到高'),
                  ],
                ),
              ),
            ],
          ),
          // 筛选按钮
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: '高级筛选',
            onPressed: () async {
              final result = await AdvancedFilterPage.showAsBottomSheet(context);
              if (result != null) {
                setState(() {
                  _dateRange = result.dateRange;
                  _minAmount = result.minAmount;
                  _maxAmount = result.maxAmount;
                  _selectedType = result.transactionType;
                  if (result.categoryIds != null && result.categoryIds!.isNotEmpty) {
                    _selectedCategory = result.categoryIds!.first;
                  } else {
                    _selectedCategory = null;
                  }
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),

          // 筛选面板
          if (_showFilters) _buildFilterPanel(),

          // 统计信息
          _buildSummary(filteredTransactions),

          // 交易列表
          Expanded(
            child: filteredTransactions.isEmpty
                ? _buildEmptyState()
                : _buildTransactionList(groupedTransactions),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionPage()),
          ).then((_) => ref.read(transactionProvider.notifier).refresh());
        },
        backgroundColor: _themeColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchResultPage(initialKeyword: _searchKeyword),
            ),
          ).then((_) => ref.read(transactionProvider.notifier).refresh());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                _searchKeyword.isEmpty ? '搜索备注或分类...' : _searchKeyword,
                style: TextStyle(
                  color: _searchKeyword.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型筛选
          Row(
            children: [
              const Text('类型:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              _buildFilterChip(
                label: '全部',
                selected: _selectedType == null,
                onSelected: () => setState(() => _selectedType = null),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '支出',
                selected: _selectedType == TransactionType.expense,
                onSelected: () => setState(() => _selectedType = TransactionType.expense),
                color: _themeColors.expense,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '收入',
                selected: _selectedType == TransactionType.income,
                onSelected: () => setState(() => _selectedType = TransactionType.income),
                color: _themeColors.income,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '转账',
                selected: _selectedType == TransactionType.transfer,
                onSelected: () => setState(() => _selectedType = TransactionType.transfer),
                color: _themeColors.transfer,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 日期范围
          Row(
            children: [
              const Text('日期:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateRange != null
                                ? '${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}'
                                : '选择日期范围',
                            style: TextStyle(
                              color: _dateRange != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (_dateRange != null)
                          GestureDetector(
                            onTap: () => setState(() => _dateRange = null),
                            child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 分类筛选
          Row(
            children: [
              const Text('分类:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectCategory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedCategory != null
                              ? DefaultCategories.findById(_selectedCategory!)?.icon ?? Icons.category
                              : Icons.category,
                          size: 16,
                          color: _selectedCategory != null
                              ? DefaultCategories.findById(_selectedCategory!)?.color ?? AppColors.textSecondary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedCategory != null
                                ? DefaultCategories.findById(_selectedCategory!)?.name ?? _selectedCategory!
                                : '选择分类',
                            style: TextStyle(
                              color: _selectedCategory != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (_selectedCategory != null)
                          GestureDetector(
                            onTap: () => setState(() => _selectedCategory = null),
                            child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 清除筛选按钮
          if (_hasActiveFilters)
            Center(
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('清除所有筛选'),
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
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: (color ?? _themeColors.primary).withValues(alpha:0.2),
      checkmarkColor: color ?? _themeColors.primary,
      labelStyle: TextStyle(
        color: selected ? (color ?? _themeColors.primary) : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSummary(List<Transaction> transactions) {
    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            '共 ${transactions.length} 笔',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            '收入 ¥${income.toStringAsFixed(2)}',
            style: TextStyle(color: _themeColors.income, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            '支出 ¥${expense.toStringAsFixed(2)}',
            style: TextStyle(color: _themeColors.expense, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(Map<String, List<Transaction>> groupedTransactions) {
    final sortedKeys = groupedTransactions.keys.toList();
    if (_sortOption == SortOption.dateAsc) {
      sortedKeys.sort();
    } else {
      sortedKeys.sort((a, b) => b.compareTo(a));
    }

    // 监听滚动，收起展开的操作按钮
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_activeItemId != null && notification is ScrollUpdateNotification) {
          setState(() => _activeItemId = null);
        }
        return false;
      },
      child: ListView.builder(
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedKeys[index];
          final dayTransactions = groupedTransactions[dateKey]!;
          final dayTotal = dayTransactions.fold(0.0, (sum, t) {
            if (t.type == TransactionType.income) return sum + t.amount;
            if (t.type == TransactionType.expense) return sum - t.amount;
            return sum;
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期头
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.background,
                child: Row(
                  children: [
                    Text(
                      _formatDateHeader(dateKey),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${dayTotal >= 0 ? '+' : ''}¥${dayTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: dayTotal >= 0 ? _themeColors.income : _themeColors.expense,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // 当日交易列表
              ...dayTransactions.map((t) => _buildTransactionItem(t)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return SwipeableTransactionItem(
      key: ValueKey(transaction.id),
      transaction: transaction,
      isActive: _activeItemId == transaction.id,
      themeColors: _themeColors,
      onLongPress: () {
        setState(() => _activeItemId = transaction.id);
      },
      onEdit: () => _handleEdit(transaction),
      onDelete: () => _confirmDelete(transaction),
      onTap: () => _showTransactionDetail(transaction),
      onDismiss: () => setState(() => _activeItemId = null),
      sourceIndicator: transaction.source != TransactionSource.manual
          ? _buildSourceIndicator(transaction.source)
          : null,
    );
  }

  /// 编辑交易
  void _handleEdit(Transaction transaction) {
    // 先收起按钮
    setState(() => _activeItemId = null);

    // 跳转到编辑页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(transaction: transaction),
      ),
    ).then((_) {
      // 返回后刷新列表
      ref.read(transactionProvider.notifier).refresh();
    });
  }

  /// 确认删除交易
  Future<void> _confirmDelete(Transaction transaction) async {
    // 先收起按钮
    setState(() => _activeItemId = null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: _themeColors.expense)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 删除交易
      ref.read(transactionProvider.notifier).deleteTransaction(transaction.id);

      // 获取交易名称用于撤销提示
      final category = DefaultCategories.findById(transaction.category);
      final transactionName = transaction.note ?? category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(transaction.category);

      // 显示带撤销功能的 SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除「$transactionName ¥${transaction.amount.toStringAsFixed(0)}」'),
          action: SnackBarAction(
            label: '撤销',
            textColor: Colors.white,
            onPressed: () {
              // 恢复交易
              ref.read(transactionProvider.notifier).addTransaction(transaction);
            },
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// Build source indicator icon for transaction list items
  Widget _buildSourceIndicator(TransactionSource source) {
    IconData icon;
    Color color;

    switch (source) {
      case TransactionSource.image:
        icon = Icons.camera_alt;
        color = Colors.blue;
        break;
      case TransactionSource.voice:
        icon = Icons.mic;
        color = Colors.green;
        break;
      case TransactionSource.email:
        icon = Icons.email;
        color = Colors.orange;
        break;
      case TransactionSource.import_:
        icon = Icons.upload_file;
        color = Colors.indigo;
        break;
      case TransactionSource.manual:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasActiveFilters ? Icons.search_off : Icons.receipt_long,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters ? '没有找到匹配的记录' : '暂无交易记录',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters ? '试试调整筛选条件' : '开始记录你的第一笔账目吧',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(
                onPressed: _clearFilters,
                child: const Text('清除筛选'),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final map = <String, List<Transaction>>{};
    for (final t in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(t.date);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateFormat('yyyy-MM-dd').parse(dateKey);
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _themeColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  Future<void> _selectCategory() async {
    final categories = [
      ...DefaultCategories.expenseCategories,
      ...DefaultCategories.incomeCategories,
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        '选择分类',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategory == category.id;
                      return InkWell(
                        onTap: () => Navigator.pop(context, category.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? category.color.withValues(alpha:0.2)
                                : Colors.grey.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: category.color, width: 2)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(category.icon, color: category.color),
                              const SizedBox(height: 4),
                              Text(
                                category.localizedName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? category.color : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedCategory = selected;
      });
    }
  }

  void _showTransactionDetail(Transaction transaction) {
    // 导航到详情页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailPage(transaction: transaction),
      ),
    ).then((_) => ref.read(transactionProvider.notifier).refresh());
  }

  /// 保留底部弹窗详情供长按使用
  // ignore: unused_element
  void _showTransactionQuickActions(Transaction transaction) {
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (category?.color ?? Colors.grey).withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            category?.icon ?? Icons.help_outline,
                            color: category?.color ?? Colors.grey,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(transaction.category),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (transaction.source != TransactionSource.manual) ...[
                                    const SizedBox(width: 8),
                                    _buildSourceBadge(transaction.source),
                                  ],
                                ],
                              ),
                              Text(
                                DateFormat('yyyy年MM月dd日 HH:mm').format(transaction.date),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isExpense ? '-' : (isIncome ? '+' : '')}¥${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isExpense ? _themeColors.expense : (isIncome ? _themeColors.income : _themeColors.transfer),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    // 详情信息
                    if (transaction.note != null && transaction.note!.isNotEmpty)
                      _buildDetailRow('备注', transaction.note!),
                    _buildDetailRow('类型', isExpense ? '支出' : (isIncome ? '收入' : '转账')),
                    _buildDetailRow('账户', _getAccountName(transaction.accountId)),
                    if (transaction.aiConfidence != null)
                      _buildDetailRow('AI置信度', '${(transaction.aiConfidence! * 100).toStringAsFixed(0)}%'),

                    // Source data section
                    if (transaction.source == TransactionSource.image &&
                        transaction.sourceFileLocalPath != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        '原始图片',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSourceImageSection(transaction),
                    ],

                    if (transaction.source == TransactionSource.voice &&
                        transaction.sourceFileLocalPath != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      SourceAudioPlayer(
                        audioPath: transaction.sourceFileLocalPath!,
                        expiresAt: transaction.sourceFileExpiresAt,
                        fileSize: transaction.sourceFileSize,
                      ),
                    ],

                    const SizedBox(height: 20),
                    // 删除按钮
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(transaction);
                        },
                        icon: Icon(Icons.delete_outline, color: _themeColors.expense),
                        label: Text('删除此记录', style: TextStyle(color: _themeColors.expense)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _themeColors.expense),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build source badge for transaction detail
  Widget _buildSourceBadge(TransactionSource source) {
    String label;
    IconData icon;
    Color color;

    switch (source) {
      case TransactionSource.image:
        label = '拍照';
        icon = Icons.camera_alt;
        color = Colors.blue;
        break;
      case TransactionSource.voice:
        label = '语音';
        icon = Icons.mic;
        color = Colors.green;
        break;
      case TransactionSource.email:
        label = '邮件';
        icon = Icons.email;
        color = Colors.orange;
        break;
      case TransactionSource.import_:
        label = '导入';
        icon = Icons.upload_file;
        color = Colors.indigo;
        break;
      case TransactionSource.manual:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Build source image section with thumbnail and view button
  Widget _buildSourceImageSection(Transaction transaction) {
    return Row(
      children: [
        SourceImageThumbnail(
          imagePath: transaction.sourceFileLocalPath!,
          size: 80,
          expiresAt: transaction.sourceFileExpiresAt,
          onTap: () {
            Navigator.pop(context); // Close the bottom sheet first
            SourceImageViewer.show(
              context,
              imagePath: transaction.sourceFileLocalPath!,
              expiresAt: transaction.sourceFileExpiresAt,
              fileSize: transaction.sourceFileSize,
            );
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (transaction.sourceFileSize != null)
                Text(
                  _formatFileSize(transaction.sourceFileSize!),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              if (transaction.sourceFileExpiresAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _getExpiryText(transaction.sourceFileExpiresAt!),
                  style: TextStyle(
                    color: transaction.isSourceFileExpired ? AppColors.expense : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (!transaction.isSourceFileExpired)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    SourceImageViewer.show(
                      context,
                      imagePath: transaction.sourceFileLocalPath!,
                      expiresAt: transaction.sourceFileExpiresAt,
                      fileSize: transaction.sourceFileSize,
                    );
                  },
                  icon: const Icon(Icons.fullscreen, size: 16),
                  label: const Text('查看原图'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getExpiryText(DateTime expiresAt) {
    if (DateTime.now().isAfter(expiresAt)) {
      return '已过期';
    }
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inDays > 0) {
      return '${remaining.inDays}天后过期';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}小时后过期';
    } else {
      return '即将过期';
    }
  }

  /// 根据账户ID获取账户名称（本地化）
  String _getAccountName(String accountId) {
    final accounts = ref.read(accountProvider);
    final account = accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => DefaultAccounts.accounts.firstWhere(
        (a) => a.id == accountId,
        orElse: () => Account(
          id: accountId,
          name: accountId,  // 如果找不到，显示ID
          type: AccountType.cash,
          balance: 0,
          icon: Icons.account_balance_wallet,
          color: Colors.grey,
          createdAt: DateTime.now(),
        ),
      ),
    );
    return account.localizedName;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

enum SortOption {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
}
