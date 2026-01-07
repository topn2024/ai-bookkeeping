import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

/// 筛选条件数据模型
class FilterCriteria {
  final DateTimeRange? dateRange;
  final double? minAmount;
  final double? maxAmount;
  final List<String>? categoryIds;
  final List<String>? accountIds;
  final TransactionType? transactionType;
  final List<String>? tags;

  const FilterCriteria({
    this.dateRange,
    this.minAmount,
    this.maxAmount,
    this.categoryIds,
    this.accountIds,
    this.transactionType,
    this.tags,
  });

  /// 是否有任何筛选条件
  bool get hasAnyFilter =>
      dateRange != null ||
      minAmount != null ||
      maxAmount != null ||
      (categoryIds != null && categoryIds!.isNotEmpty) ||
      (accountIds != null && accountIds!.isNotEmpty) ||
      transactionType != null ||
      (tags != null && tags!.isNotEmpty);

  /// 复制并修改
  FilterCriteria copyWith({
    DateTimeRange? dateRange,
    double? minAmount,
    double? maxAmount,
    List<String>? categoryIds,
    List<String>? accountIds,
    TransactionType? transactionType,
    List<String>? tags,
    bool clearDateRange = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
    bool clearCategoryIds = false,
    bool clearAccountIds = false,
    bool clearTransactionType = false,
    bool clearTags = false,
  }) {
    return FilterCriteria(
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      categoryIds: clearCategoryIds ? null : (categoryIds ?? this.categoryIds),
      accountIds: clearAccountIds ? null : (accountIds ?? this.accountIds),
      transactionType:
          clearTransactionType ? null : (transactionType ?? this.transactionType),
      tags: clearTags ? null : (tags ?? this.tags),
    );
  }

  /// 空筛选条件
  static const FilterCriteria empty = FilterCriteria();

  /// 应用筛选条件到交易列表
  List<Transaction> apply(List<Transaction> transactions) {
    return transactions.where((t) {
      // 日期范围筛选
      if (dateRange != null) {
        if (t.date.isBefore(dateRange!.start) ||
            t.date.isAfter(dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // 金额范围筛选
      if (minAmount != null && t.amount < minAmount!) {
        return false;
      }
      if (maxAmount != null && t.amount > maxAmount!) {
        return false;
      }

      // 分类筛选
      if (categoryIds != null && categoryIds!.isNotEmpty) {
        bool categoryMatch = categoryIds!.contains(t.category);
        // 也检查父分类
        if (!categoryMatch) {
          final category = DefaultCategories.findById(t.category);
          if (category?.parentId != null) {
            categoryMatch = categoryIds!.contains(category!.parentId);
          }
        }
        if (!categoryMatch) return false;
      }

      // 账户筛选
      if (accountIds != null && accountIds!.isNotEmpty) {
        if (!accountIds!.contains(t.accountId)) {
          return false;
        }
      }

      // 类型筛选
      if (transactionType != null && t.type != transactionType) {
        return false;
      }

      // 标签筛选
      if (tags != null && tags!.isNotEmpty) {
        if (t.tags == null || t.tags!.isEmpty) {
          return false;
        }
        final hasMatchingTag = tags!.any((tag) => t.tags!.contains(tag));
        if (!hasMatchingTag) return false;
      }

      return true;
    }).toList();
  }
}

/// 高级筛选页面/组件
/// 可作为底部弹窗或独立页面使用
class AdvancedFilterPage extends ConsumerStatefulWidget {
  final FilterCriteria? initialCriteria;
  final Function(FilterCriteria) onApply;
  final bool isBottomSheet;

  const AdvancedFilterPage({
    super.key,
    this.initialCriteria,
    required this.onApply,
    this.isBottomSheet = true,
  });

  /// 显示为底部弹窗
  static Future<FilterCriteria?> showAsBottomSheet(
    BuildContext context, {
    FilterCriteria? initialCriteria,
  }) async {
    return showModalBottomSheet<FilterCriteria>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdvancedFilterPage(
        initialCriteria: initialCriteria,
        isBottomSheet: true,
        onApply: (criteria) {
          Navigator.pop(context, criteria);
        },
      ),
    );
  }

  @override
  ConsumerState<AdvancedFilterPage> createState() => _AdvancedFilterPageState();
}

class _AdvancedFilterPageState extends ConsumerState<AdvancedFilterPage> {
  late ThemeColors _themeColors;

  // 筛选状态
  DateTimeRange? _dateRange;
  double? _minAmount;
  double? _maxAmount;
  Set<String> _selectedCategoryIds = {};
  Set<String> _selectedAccountIds = {};
  TransactionType? _transactionType;

  // 控制器
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  // 快捷日期选项
  String? _quickDateOption;

  @override
  void initState() {
    super.initState();
    _initFromCriteria(widget.initialCriteria);
  }

  void _initFromCriteria(FilterCriteria? criteria) {
    if (criteria != null) {
      _dateRange = criteria.dateRange;
      _minAmount = criteria.minAmount;
      _maxAmount = criteria.maxAmount;
      _selectedCategoryIds = Set.from(criteria.categoryIds ?? []);
      _selectedAccountIds = Set.from(criteria.accountIds ?? []);
      _transactionType = criteria.transactionType;

      if (_minAmount != null) {
        _minAmountController.text = _minAmount!.toStringAsFixed(0);
      }
      if (_maxAmount != null) {
        _maxAmountController.text = _maxAmount!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  FilterCriteria _buildCriteria() {
    return FilterCriteria(
      dateRange: _dateRange,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
      categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds.toList(),
      accountIds: _selectedAccountIds.isEmpty ? null : _selectedAccountIds.toList(),
      transactionType: _transactionType,
    );
  }

  void _reset() {
    setState(() {
      _dateRange = null;
      _minAmount = null;
      _maxAmount = null;
      _selectedCategoryIds.clear();
      _selectedAccountIds.clear();
      _transactionType = null;
      _quickDateOption = null;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    _themeColors = ref.themeColors;
    final accounts = ref.watch(accountProvider);

    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          _buildHeader(),
          const Divider(height: 1),
          // 筛选内容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSection(),
                  const SizedBox(height: 20),
                  _buildAmountSection(),
                  const SizedBox(height: 20),
                  _buildTypeSection(),
                  const SizedBox(height: 20),
                  _buildCategorySection(),
                  const SizedBox(height: 20),
                  _buildAccountSection(accounts),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // 底部按钮
          _buildBottomButtons(),
        ],
      ),
    );

    if (widget.isBottomSheet) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => content,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('高级筛选')),
      body: content,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (widget.isBottomSheet)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const Icon(Icons.filter_list),
          const SizedBox(width: 8),
          const Text(
            '高级筛选',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _reset,
            child: const Text('重置'),
          ),
          if (widget.isBottomSheet)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '时间范围',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        // 快捷选项
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickDateChip('今天', _getTodayRange),
            _buildQuickDateChip('本周', _getThisWeekRange),
            _buildQuickDateChip('本月', _getThisMonthRange),
            _buildQuickDateChip('本季度', _getThisQuarterRange),
            _buildQuickDateChip('本年', _getThisYearRange),
            _buildQuickDateChip('自定义', null),
          ],
        ),
        if (_dateRange != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_dateRange!.end)}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _dateRange = null;
                      _quickDateOption = null;
                    });
                  },
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickDateChip(String label, DateTimeRange Function()? getRange) {
    final isSelected = _quickDateOption == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) async {
        if (label == '自定义') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: _dateRange,
            locale: const Locale('zh', 'CN'),
          );
          if (picked != null) {
            setState(() {
              _dateRange = picked;
              _quickDateOption = '自定义';
            });
          }
        } else if (getRange != null) {
          setState(() {
            _dateRange = selected ? getRange() : null;
            _quickDateOption = selected ? label : null;
          });
        }
      },
      selectedColor: _themeColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? _themeColors.primary : AppColors.textPrimary,
      ),
    );
  }

  DateTimeRange _getTodayRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today, end: today);
  }

  DateTimeRange _getThisWeekRange() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(
      start: DateTime(weekStart.year, weekStart.month, weekStart.day),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  DateTimeRange _getThisMonthRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  DateTimeRange _getThisQuarterRange() {
    final now = DateTime.now();
    final quarter = ((now.month - 1) / 3).floor();
    final quarterStart = DateTime(now.year, quarter * 3 + 1, 1);
    return DateTimeRange(
      start: quarterStart,
      end: DateTime(now.year, now.month, now.day),
    );
  }

  DateTimeRange _getThisYearRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '金额范围',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '最小金额',
                  prefixText: '¥ ',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _minAmount = double.tryParse(value);
                  });
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('—', style: TextStyle(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: TextField(
                controller: _maxAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '最大金额',
                  prefixText: '¥ ',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _maxAmount = double.tryParse(value);
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 快捷金额
        Wrap(
          spacing: 8,
          children: [
            _buildQuickAmountChip('0-100', 0, 100),
            _buildQuickAmountChip('100-500', 100, 500),
            _buildQuickAmountChip('500-1000', 500, 1000),
            _buildQuickAmountChip('1000+', 1000, null),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAmountChip(String label, double? min, double? max) {
    final isSelected = _minAmount == min && _maxAmount == max;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected
          ? _themeColors.primary.withValues(alpha: 0.2)
          : AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? _themeColors.primary : AppColors.textPrimary,
        fontSize: 12,
      ),
      onPressed: () {
        setState(() {
          if (isSelected) {
            _minAmount = null;
            _maxAmount = null;
            _minAmountController.clear();
            _maxAmountController.clear();
          } else {
            _minAmount = min;
            _maxAmount = max;
            _minAmountController.text = min?.toStringAsFixed(0) ?? '';
            _maxAmountController.text = max?.toStringAsFixed(0) ?? '';
          }
        });
      },
    );
  }

  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '交易类型',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _buildTypeChip('全部', null),
            _buildTypeChip('支出', TransactionType.expense, color: _themeColors.expense),
            _buildTypeChip('收入', TransactionType.income, color: _themeColors.income),
            _buildTypeChip('转账', TransactionType.transfer, color: _themeColors.transfer),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label, TransactionType? type, {Color? color}) {
    final isSelected = _transactionType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _transactionType = selected ? type : null;
        });
      },
      selectedColor: (color ?? _themeColors.primary).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? (color ?? _themeColors.primary) : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCategorySection() {
    final categories = _transactionType == TransactionType.income
        ? DefaultCategories.incomeCategories
        : _transactionType == TransactionType.expense
            ? DefaultCategories.expenseCategories
            : [...DefaultCategories.expenseCategories, ...DefaultCategories.incomeCategories];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '分类',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (_selectedCategoryIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _themeColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '已选${_selectedCategoryIds.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _themeColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = _selectedCategoryIds.contains(category.id);
            return FilterChip(
              avatar: Icon(
                category.icon,
                size: 18,
                color: isSelected ? category.color : AppColors.textSecondary,
              ),
              label: Text(category.localizedName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategoryIds.add(category.id);
                  } else {
                    _selectedCategoryIds.remove(category.id);
                  }
                });
              },
              selectedColor: category.color.withValues(alpha: 0.2),
              checkmarkColor: category.color,
              labelStyle: TextStyle(
                color: isSelected ? category.color : AppColors.textPrimary,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAccountSection(List<Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '账户',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (_selectedAccountIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _themeColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '已选${_selectedAccountIds.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _themeColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: accounts.map((account) {
            final isSelected = _selectedAccountIds.contains(account.id);
            return FilterChip(
              avatar: Icon(
                account.icon,
                size: 18,
                color: isSelected ? account.color : AppColors.textSecondary,
              ),
              label: Text(account.localizedName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAccountIds.add(account.id);
                  } else {
                    _selectedAccountIds.remove(account.id);
                  }
                });
              },
              selectedColor: account.color.withValues(alpha: 0.2),
              checkmarkColor: account.color,
              labelStyle: TextStyle(
                color: isSelected ? account.color : AppColors.textPrimary,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    final criteria = _buildCriteria();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('重置'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(criteria);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _themeColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  criteria.hasAnyFilter ? '应用筛选' : '确定',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
