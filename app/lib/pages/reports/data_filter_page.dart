import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction.dart';
import '../../models/category.dart';

/// 数据筛选页面
/// 原型设计 7.09：数据筛选
/// - 时间范围选择
/// - 交易类型选择
/// - 分类多选
/// - 金额范围
/// - 账户选择
/// - 应用筛选按钮
class DataFilterPage extends ConsumerStatefulWidget {
  final FilterOptions? initialOptions;

  const DataFilterPage({super.key, this.initialOptions});

  @override
  ConsumerState<DataFilterPage> createState() => _DataFilterPageState();
}

class _DataFilterPageState extends ConsumerState<DataFilterPage> {
  int _selectedTimeRange = 0;
  TransactionType? _selectedType = TransactionType.expense;
  Set<String> _selectedCategories = {};
  String? _minAmount;
  String? _maxAmount;
  String? _selectedAccount;

  final List<String> _timeRanges = ['本月', '上月', '近3月', '本年', '自定义'];

  @override
  void initState() {
    super.initState();
    if (widget.initialOptions != null) {
      _selectedTimeRange = widget.initialOptions!.timeRangeIndex;
      _selectedType = widget.initialOptions!.type;
      _selectedCategories = widget.initialOptions!.categories.toSet();
      _minAmount = widget.initialOptions!.minAmount?.toString();
      _maxAmount = widget.initialOptions!.maxAmount?.toString();
      _selectedAccount = widget.initialOptions!.accountId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 模拟匹配记录数
    final matchCount = 45;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeRangeSection(theme),
                    const SizedBox(height: 20),
                    _buildTypeSection(theme),
                    const SizedBox(height: 20),
                    _buildCategorySection(theme),
                    const SizedBox(height: 20),
                    _buildAmountRangeSection(theme),
                    const SizedBox(height: 20),
                    _buildAccountSection(theme),
                  ],
                ),
              ),
            ),
            _buildBottomSection(context, theme, matchCount),
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
              child: const Icon(Icons.close),
            ),
          ),
          const Expanded(
            child: Text(
              '筛选条件',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _resetFilters,
            child: Text(
              '重置',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 时间范围
  Widget _buildTimeRangeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '时间范围',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_timeRanges.length, (index) {
            final isSelected = _selectedTimeRange == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedTimeRange = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6495ED)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _timeRanges[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 交易类型
  Widget _buildTypeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '交易类型',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTypeButton(theme, TransactionType.expense, Icons.arrow_downward, '支出', Colors.red),
            const SizedBox(width: 8),
            _buildTypeButton(theme, TransactionType.income, Icons.arrow_upward, '收入', Colors.green),
            const SizedBox(width: 8),
            _buildTypeButton(theme, TransactionType.transfer, Icons.swap_horiz, '转账', Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton(
    ThemeData theme,
    TransactionType type,
    IconData icon,
    String label,
    Color color,
  ) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分类选择
  Widget _buildCategorySection(ThemeData theme) {
    final categories = DefaultCategories.expenseCategories.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类（可多选）',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = _selectedCategories.contains(cat.id);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(cat.id);
                  } else {
                    _selectedCategories.add(cat.id);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 16, color: cat.color),
                    const SizedBox(width: 6),
                    Text(
                      cat.localizedName,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 金额范围
  Widget _buildAmountRangeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '金额范围',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: '最小金额',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _minAmount = v,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '至',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: '最大金额',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _maxAmount = v,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 账户选择
  Widget _buildAccountSection(ThemeData theme) {
    final accounts = ['全部账户', '微信', '支付宝', '银行卡'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账户',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: accounts.map((account) {
            final isSelected = _selectedAccount == account ||
                (_selectedAccount == null && account == '全部账户');
            return GestureDetector(
              onTap: () => setState(() {
                _selectedAccount = account == '全部账户' ? null : account;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Text(
                  account,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 底部操作区
  Widget _buildBottomSection(BuildContext context, ThemeData theme, int matchCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已选条件',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '符合 $matchCount 条记录',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _applyFilters(context),
              icon: const Icon(Icons.check),
              label: const Text('应用筛选', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedTimeRange = 0;
      _selectedType = TransactionType.expense;
      _selectedCategories.clear();
      _minAmount = null;
      _maxAmount = null;
      _selectedAccount = null;
    });
  }

  void _applyFilters(BuildContext context) {
    final options = FilterOptions(
      timeRangeIndex: _selectedTimeRange,
      type: _selectedType,
      categories: _selectedCategories.toList(),
      minAmount: _minAmount != null ? double.tryParse(_minAmount!) : null,
      maxAmount: _maxAmount != null ? double.tryParse(_maxAmount!) : null,
      accountId: _selectedAccount,
    );
    Navigator.pop(context, options);
  }
}

/// 筛选选项
class FilterOptions {
  final int timeRangeIndex;
  final TransactionType? type;
  final List<String> categories;
  final double? minAmount;
  final double? maxAmount;
  final String? accountId;

  FilterOptions({
    required this.timeRangeIndex,
    this.type,
    this.categories = const [],
    this.minAmount,
    this.maxAmount,
    this.accountId,
  });
}
