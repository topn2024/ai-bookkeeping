import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/transaction_split.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../extensions/extensions.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';

class SplitTransactionPage extends ConsumerStatefulWidget {
  const SplitTransactionPage({super.key});

  @override
  ConsumerState<SplitTransactionPage> createState() => _SplitTransactionPageState();
}

class _SplitTransactionPageState extends ConsumerState<SplitTransactionPage> {
  final _totalAmountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedAccount = 'wechat';
  DateTime _selectedDate = DateTime.now();
  TransactionType _type = TransactionType.expense;

  // 拆分项列表
  final List<_SplitItem> _splits = [];

  double get _totalAmount {
    return double.tryParse(_totalAmountController.text) ?? 0;
  }

  double get _allocatedAmount {
    return _splits.fold(0.0, (sum, split) => sum + split.amount);
  }

  double get _remainingAmount {
    return _totalAmount - _allocatedAmount;
  }

  bool get _isBalanced {
    return (_remainingAmount.abs() < 0.01) && _splits.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    // 初始添加一个空的拆分项
    _addSplit();
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _noteController.dispose();
    for (final split in _splits) {
      split.amountController.dispose();
      split.noteController.dispose();
    }
    super.dispose();
  }

  void _addSplit() {
    setState(() {
      _splits.add(_SplitItem(
        amountController: TextEditingController(),
        noteController: TextEditingController(),
      ));
    });
  }

  void _removeSplit(int index) {
    if (_splits.length > 1) {
      setState(() {
        _splits[index].amountController.dispose();
        _splits[index].noteController.dispose();
        _splits.removeAt(index);
      });
    }
  }

  void _autoFillRemaining(int index) {
    if (_remainingAmount > 0) {
      setState(() {
        _splits[index].amountController.text = _remainingAmount.toStringAsFixed(2);
        _splits[index].amount = _remainingAmount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拆分记账'),
        actions: [
          TextButton(
            onPressed: _isBalanced ? _saveTransaction : null,
            child: Text(
              '保存',
              style: TextStyle(
                color: _isBalanced ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildTypeSelector(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSplitsList(),
                const SizedBox(height: 16),
                _buildAddSplitButton(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '总金额',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _type == TransactionType.expense ? AppColors.expense : AppColors.income,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _totalAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _type == TransactionType.expense ? AppColors.expense : AppColors.income,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 拆分进度
          _buildProgressIndicator(),
          const Divider(height: 24),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: '添加备注...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.edit_note, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _totalAmount > 0 ? (_allocatedAmount / _totalAmount).clamp(0.0, 1.0) : 0.0;
    final isOver = _allocatedAmount > _totalAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已分配: ¥${_allocatedAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                color: isOver ? AppColors.expense : AppColors.textSecondary,
              ),
            ),
            Text(
              isOver
                  ? '超出: ¥${(-_remainingAmount).toStringAsFixed(2)}'
                  : '剩余: ¥${_remainingAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                color: isOver ? AppColors.expense : (_isBalanced ? AppColors.income : AppColors.textSecondary),
                fontWeight: _isBalanced ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.divider,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOver ? AppColors.expense : (_isBalanced ? AppColors.income : AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.background,
      child: Row(
        children: [
          _buildTypeChip('支出', TransactionType.expense, AppColors.expense),
          const SizedBox(width: 12),
          _buildTypeChip('收入', TransactionType.income, AppColors.income),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, TransactionType type, Color color) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha:0.2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSplitsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '拆分项',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_splits.length}项',
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_splits.length, (index) => _buildSplitCard(index)),
      ],
    );
  }

  Widget _buildSplitCard(int index) {
    final split = _splits[index];
    final categories = _type == TransactionType.expense
        ? DefaultCategories.expenseCategories
        : DefaultCategories.incomeCategories;

    Category? selectedCat;
    if (split.categoryId != null) {
      selectedCat = categories.where((c) => c.id == split.categoryId).firstOrNull;
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_splits.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => _removeSplit(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 分类选择
          InkWell(
            onTap: () => _showCategoryPicker(index),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (selectedCat != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: selectedCat.color.withValues(alpha:0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(selectedCat.icon, color: selectedCat.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      selectedCat.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ] else ...[
                    const Icon(Icons.category, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    const Text(
                      '选择分类',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 金额输入
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: split.amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    hintText: '0.00',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      split.amount = double.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _remainingAmount > 0 ? () => _autoFillRemaining(index) : null,
                child: const Text('填充剩余'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 备注
          TextField(
            controller: split.noteController,
            decoration: InputDecoration(
              hintText: '添加备注 (可选)',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (value) {
              split.note = value.isEmpty ? null : value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddSplitButton() {
    return InkWell(
      onTap: _addSplit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              '添加拆分项',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    String accountName = '微信';
    final account = DefaultAccounts.accounts.where((a) => a.id == _selectedAccount).firstOrNull;
    if (account != null) {
      accountName = account.localizedName;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MM/dd').format(_selectedDate),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _showAccountPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(accountName, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!_isBalanced && _totalAmount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _remainingAmount > 0 ? '还需分配' : '已超出',
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(int splitIndex) {
    final isExpense = _type == TransactionType.expense;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _CategoryPickerSheet(
          isExpense: isExpense,
          selectedCategoryId: _splits[splitIndex].categoryId,
          onCategorySelected: (categoryId) {
            setState(() {
              _splits[splitIndex].categoryId = categoryId;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择账户',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...DefaultAccounts.accounts.map((account) {
                final isSelected = account.id == _selectedAccount;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: account.color.withValues(alpha:0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(account.icon, color: account.color),
                  ),
                  title: Text(account.localizedName),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedAccount = account.id;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _saveTransaction() {
    if (!_isBalanced) return;

    // 确保至少有一个拆分项
    if (_splits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个拆分项')),
      );
      return;
    }

    // 验证所有拆分项
    for (int i = 0; i < _splits.length; i++) {
      if (_splits[i].categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请选择第${i + 1}项的分类')),
        );
        return;
      }
      if (_splits[i].amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请输入第${i + 1}项的金额')),
        );
        return;
      }
    }

    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

    // 创建拆分项列表
    final splits = _splits.map((split) {
      return TransactionSplit(
        id: '${transactionId}_${_splits.indexOf(split)}',
        transactionId: transactionId,
        category: split.categoryId!,
        amount: split.amount,
        note: split.note,
      );
    }).toList();

    // 使用第一个分类作为主分类
    final primaryCategory = _splits.first.categoryId!;

    final transaction = Transaction(
      id: transactionId,
      type: _type,
      amount: _totalAmount,
      category: primaryCategory,
      note: _noteController.text.isEmpty ? '拆分交易' : _noteController.text,
      date: _selectedDate,
      accountId: _selectedAccount,
      isSplit: true,
      splits: splits,
    );

    ref.read(transactionProvider.notifier).addTransaction(transaction);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('拆分交易已保存 (${_splits.length}项)')),
    );
  }
}

/// 拆分项数据类
class _SplitItem {
  String? categoryId;
  double amount = 0;
  String? note;
  final TextEditingController amountController;
  final TextEditingController noteController;

  _SplitItem({
    required this.amountController,
    required this.noteController,
  });
}

/// 支持子分类的分类选择器
class _CategoryPickerSheet extends ConsumerStatefulWidget {
  final bool isExpense;
  final String? selectedCategoryId;
  final void Function(String categoryId) onCategorySelected;

  const _CategoryPickerSheet({
    required this.isExpense,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  ConsumerState<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  String? _expandedParentId;

  @override
  Widget build(BuildContext context) {
    final categoryTree = ref.watch(categoryProvider.notifier)
        .getCategoryTree(isExpense: widget.isExpense);

    // 获取展开的父分类的子分类
    List<Category> childCategories = [];
    if (_expandedParentId != null) {
      childCategories = ref.watch(categoryProvider.notifier)
          .getChildCategories(_expandedParentId!);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择分类',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // 子分类选择区域
          if (_expandedParentId != null && childCategories.isNotEmpty)
            _buildSubcategorySection(childCategories),
          // 主分类网格
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: categoryTree.length,
              itemBuilder: (context, index) {
                final item = categoryTree[index];
                final category = item.category;
                final hasChildren = item.hasChildren;
                final isSelected = widget.selectedCategoryId == category.id;
                final isExpanded = _expandedParentId == category.id;

                return InkWell(
                  onTap: () {
                    if (hasChildren) {
                      // 有子分类：展开/收起
                      setState(() {
                        if (_expandedParentId == category.id) {
                          // 再次点击：选择父分类
                          widget.onCategorySelected(category.id);
                        } else {
                          _expandedParentId = category.id;
                        }
                      });
                    } else {
                      // 没有子分类：直接选择
                      widget.onCategorySelected(category.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? category.color.withValues(alpha:0.2)
                              : isExpanded
                                  ? category.color.withValues(alpha:0.1)
                                  : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: category.color, width: 2)
                              : isExpanded
                                  ? Border.all(color: category.color.withValues(alpha:0.5), width: 2)
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha:0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(category.icon, color: category.color, size: 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category.localizedName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected || isExpanded ? category.color : AppColors.textPrimary,
                                fontWeight: isSelected || isExpanded ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 有子分类标识
                      if (hasChildren)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 14,
                            color: category.color,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategorySection(List<Category> childCategories) {
    final parentCategory = ref.watch(categoryProvider.notifier)
        .getCategoryById(_expandedParentId!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: parentCategory?.color.withValues(alpha:0.3) ?? Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subdirectory_arrow_right,
                  size: 16, color: parentCategory?.color ?? Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${parentCategory?.name ?? ""} 的子分类',
                style: TextStyle(
                  fontSize: 12,
                  color: parentCategory?.color ?? AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  widget.onCategorySelected(_expandedParentId!);
                },
                child: const Text(
                  '使用父分类',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: childCategories.map((child) {
              final isSelected = widget.selectedCategoryId == child.id;
              return InkWell(
                onTap: () {
                  widget.onCategorySelected(child.id);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? child.color.withValues(alpha:0.2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: child.color, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(child.icon, size: 16, color: child.color),
                      const SizedBox(width: 4),
                      Text(
                        child.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? child.color : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
