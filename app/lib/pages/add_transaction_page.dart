import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../extensions/extensions.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import '../widgets/duplicate_transaction_dialog.dart';
import 'image_recognition_page.dart';
import 'voice_recognition_page.dart';
import 'split_transaction_page.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final Transaction? transaction; // 编辑时传入已有交易

  const AddTransactionPage({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _selectedCategory;
  String? _selectedParentCategory;  // 选中的父分类（用于子分类选择）
  String? _suggestedCategory; // AI建议的分类
  String _selectedAccount = 'wechat';
  String _toAccountId = 'cash';
  DateTime _selectedDate = DateTime.now();
  bool _isReimbursable = false;  // 是否可报销
  // 缓存 ScaffoldMessenger 用于安全清除 SnackBar
  ScaffoldMessengerState? _scaffoldMessenger;

  Color get _amountColor {
    switch (_type) {
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.transfer:
        return AppColors.transfer;
    }
  }

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _type = TransactionType.values[_tabController.index];
        _selectedCategory = null;
        _suggestedCategory = null;
      });
    });

    // 如果是编辑模式，预填充已有数据
    if (_isEditing) {
      final t = widget.transaction!;
      _type = t.type;
      _tabController.index = t.type.index;
      _amountController.text = t.amount.toString();
      _noteController.text = t.note ?? '';
      _selectedCategory = t.category;
      _selectedAccount = t.accountId;
      _toAccountId = t.toAccountId ?? 'cash';
      _selectedDate = t.date;
      _isReimbursable = t.isReimbursable;
    }

    // 监听备注输入，触发智能分类建议
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  void _onNoteChanged() {
    final note = _noteController.text;
    if (note.isNotEmpty && _selectedCategory == null) {
      // 使用本地智能分类
      final aiNotifier = ref.read(aiBookkeepingProvider.notifier);
      final suggested = aiNotifier.suggestCategoryLocal(note);
      if (suggested != _suggestedCategory) {
        setState(() {
          _suggestedCategory = suggested;
        });
      }
      // 自动判断是否是收入类型
      if (aiNotifier.isIncomeType(note) && _type == TransactionType.expense) {
        setState(() {
          _type = TransactionType.income;
          _tabController.animateTo(1);
        });
      }
    }
  }

  @override
  void dispose() {
    // 清除 SnackBar，避免返回首页后继续显示
    _scaffoldMessenger?.clearSnackBars();
    _noteController.removeListener(_onNoteChanged);
    _tabController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 打开图片识别页面
  Future<void> _openImageRecognition() async {
    final result = await Navigator.push<AIRecognitionResult>(
      context,
      MaterialPageRoute(builder: (context) => const ImageRecognitionPage()),
    );

    if (result != null && result.success) {
      _applyAIResult(result);
    }
  }

  /// 打开语音识别页面
  Future<void> _openVoiceRecognition() async {
    final result = await Navigator.push<AIRecognitionResult>(
      context,
      MaterialPageRoute(builder: (context) => const VoiceRecognitionPage()),
    );

    if (result != null && result.success) {
      _applyAIResult(result);
    }
  }

  /// 应用AI识别结果
  void _applyAIResult(AIRecognitionResult result) {
    setState(() {
      // 设置金额
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }

      // 设置类型
      if (result.type == 'income') {
        _type = TransactionType.income;
        _tabController.animateTo(1);
      } else {
        _type = TransactionType.expense;
        _tabController.animateTo(0);
      }

      // 设置分类
      if (result.category != null) {
        _selectedCategory = result.category;
      }

      // 设置备注
      if (result.description != null && result.description!.isNotEmpty) {
        _noteController.text = result.description!;
      } else if (result.merchant != null && result.merchant!.isNotEmpty) {
        _noteController.text = result.merchant!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.l10n.editTransactionTitle : context.l10n.addTransactionTitle),
        actions: [
          // 拆分记账入口
          IconButton(
            icon: const Icon(Icons.call_split),
            tooltip: context.l10n.splitTransaction,
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SplitTransactionPage()),
              );
            },
          ),
          // 语音记账入口
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: context.l10n.voiceRecord,
            onPressed: _openVoiceRecognition,
          ),
          // 图片识别入口
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: context.l10n.photoRecord,
            onPressed: _openImageRecognition,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: context.l10n.expense),
            Tab(text: context.l10n.income),
            Tab(text: context.l10n.transfer),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildAmountInput(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryGridWithSubcategories(isExpense: true),
                _buildCategoryGridWithSubcategories(isExpense: false),
                _buildTransferForm(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _amountColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _amountColor,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: context.l10n.addNoteHint,
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.edit_note, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          // 报销选项（仅支出）
          if (_type == TransactionType.expense) ...[
            const Divider(),
            _buildReimbursableToggle(),
          ],
        ],
      ),
    );
  }

  /// 构建报销开关
  Widget _buildReimbursableToggle() {
    return Row(
      children: [
        const Icon(Icons.receipt_long, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 8),
        Text(context.l10n.reimbursable, style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Switch(
          value: _isReimbursable,
          onChanged: (value) {
            setState(() {
              _isReimbursable = value;
            });
          },
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  /// 构建支持子分类的分类选择器
  Widget _buildCategoryGridWithSubcategories({required bool isExpense}) {
    final categoryTree = ref.read(categoryProvider.notifier).getCategoryTree(isExpense: isExpense);
    final allCategories = isExpense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    // 获取当前选中父分类的子分类
    List<Category> childCategories = [];
    if (_selectedParentCategory != null) {
      childCategories = ref.read(categoryProvider.notifier).getChildCategories(_selectedParentCategory!);
    }

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // AI智能分类建议提示
          if (_suggestedCategory != null && _selectedCategory == null)
            _buildAISuggestionBanner(allCategories),

          // 子分类选择区域（当选中了有子分类的父分类时显示）
          if (_selectedParentCategory != null && childCategories.isNotEmpty)
            _buildSubcategorySelector(childCategories),

          // 主分类网格
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: categoryTree.length,
              itemBuilder: (context, index) {
                final item = categoryTree[index];
                final category = item.category;
                final hasChildren = item.hasChildren;
                final isSelected = _selectedCategory == category.id;
                final isParentSelected = _selectedParentCategory == category.id;
                final isSuggested = _suggestedCategory == category.id && _selectedCategory == null;

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (hasChildren) {
                        // 有子分类：展开/收起子分类选择
                        if (_selectedParentCategory == category.id) {
                          // 再次点击：选择父分类作为最终分类
                          _selectedCategory = category.id;
                          _selectedParentCategory = null;
                        } else {
                          _selectedParentCategory = category.id;
                          _selectedCategory = null;
                        }
                      } else {
                        // 没有子分类：直接选中
                        _selectedCategory = category.id;
                        _selectedParentCategory = null;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? category.color.withValues(alpha:0.2)
                              : isParentSelected
                                  ? category.color.withValues(alpha:0.1)
                                  : isSuggested
                                      ? Colors.amber.withValues(alpha:0.15)
                                      : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: category.color, width: 2)
                              : isParentSelected
                                  ? Border.all(color: category.color.withValues(alpha:0.5), width: 2)
                                  : isSuggested
                                      ? Border.all(color: Colors.amber, width: 2)
                                      : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha:0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                category.icon,
                                color: category.color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category.localizedName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected || isParentSelected ? category.color : AppColors.textPrimary,
                                fontWeight: isSelected || isSuggested || isParentSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 有子分类标识
                      if (hasChildren)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            isParentSelected ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: category.color,
                          ),
                        ),
                      // AI推荐标识
                      if (isSuggested)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  /// 构建子分类选择器
  Widget _buildSubcategorySelector(List<Category> childCategories) {
    final parentCategory = ref.read(categoryProvider.notifier).getCategoryById(_selectedParentCategory!);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                context.l10n.subcategoryOf(parentCategory?.localizedName ?? ""),
                style: TextStyle(
                  fontSize: 12,
                  color: parentCategory?.color ?? AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = _selectedParentCategory;
                    _selectedParentCategory = null;
                  });
                },
                child: Text(
                  context.l10n.useParentCategory,
                  style: const TextStyle(
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
              final isSelected = _selectedCategory == child.id;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = child.id;
                  });
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
                        child.localizedName,
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

  /// 构建AI智能分类建议横幅
  Widget _buildAISuggestionBanner(List<Category> categories) {
    final suggestedCat = categories.where((c) => c.id == _suggestedCategory).firstOrNull;
    if (suggestedCat == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.aiRecommendedCategory(suggestedCat.localizedName),
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = _suggestedCategory;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.l10n.useCategory,
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferForm() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAccountSelector(context.l10n.fromAccount, _selectedAccount, (value) {
            setState(() {
              _selectedAccount = value;
              if (_toAccountId == value) {
                final accounts = DefaultAccounts.accounts;
                _toAccountId = accounts.firstWhere((a) => a.id != value).id;
              }
            });
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.transfer.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_downward, color: AppColors.transfer),
          ),
          const SizedBox(height: 16),
          _buildAccountSelector(context.l10n.toAccount, _toAccountId, (value) {
            setState(() {
              _toAccountId = value;
              if (_selectedAccount == value) {
                final accounts = DefaultAccounts.accounts;
                _selectedAccount = accounts.firstWhere((a) => a.id != value).id;
              }
            });
          }),
        ],
      ),
    );
  }

  Widget _buildAccountSelector(
      String label, String selectedId, Function(String) onChanged) {
    final accounts = DefaultAccounts.accounts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: accounts.map((account) {
              final isSelected = account.id == selectedId;
              return InkWell(
                onTap: () => onChanged(account.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? account.color.withValues(alpha:0.2) : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: account.color, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(account.icon, color: account.color, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        account.localizedName,
                        style: TextStyle(
                          color: isSelected ? account.color : AppColors.textPrimary,
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
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
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
              Text(
                context.l10n.selectAccount,
                style: const TextStyle(
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

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseEnterAmount)),
      );
      return;
    }

    if (_type != TransactionType.transfer && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseSelectCategory)),
      );
      return;
    }

    if (_type == TransactionType.transfer && _selectedAccount == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountsCannotBeSame)),
      );
      return;
    }

    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseEnterValidAmount)),
      );
      return;
    }

    final transaction = Transaction(
      id: _isEditing ? widget.transaction!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      amount: amount,
      category: _type == TransactionType.transfer ? 'transfer' : (_selectedCategory ?? 'other'),
      note: _noteController.text.isEmpty ? null : _noteController.text,
      date: _selectedDate,
      accountId: _selectedAccount,
      toAccountId: _type == TransactionType.transfer ? _toAccountId : null,
      isReimbursable: _isReimbursable,
    );

    if (_isEditing) {
      // 编辑模式直接更新，不检查重复
      ref.read(transactionProvider.notifier).updateTransaction(transaction);
      Navigator.of(context).pop();
    } else {
      // 新增模式使用重复检测
      final confirmed = await DuplicateTransactionHelper.checkAndConfirm(
        context: context,
        transaction: transaction,
        transactionNotifier: ref.read(transactionProvider.notifier),
        showSuccessMessage: false,
      );

      if (confirmed && mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
