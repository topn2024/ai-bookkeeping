import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';
import '../providers/zero_based_budget_provider.dart';
import '../models/transaction.dart';
import 'smart_allocation_page.dart';

/// 零基预算分配页面
///
/// 对应原型设计 3.09 零基预算分配
/// 展示零基预算原则：收入 - 支出 - 储蓄 = 0
class ZeroBasedBudgetPage extends ConsumerStatefulWidget {
  const ZeroBasedBudgetPage({
    super.key,
  });

  @override
  ConsumerState<ZeroBasedBudgetPage> createState() => _ZeroBasedBudgetPageState();
}

class _ZeroBasedBudgetPageState extends ConsumerState<ZeroBasedBudgetPage> {
  late List<BudgetCategory> _categories;

  @override
  void initState() {
    super.initState();
    _loadSavedCategories();
  }

  /// 加载保存的预算分类
  void _loadSavedCategories() {
    // 从 provider 读取保存的数据
    final savedCategories = ref.read(zeroBasedBudgetProvider);

    if (savedCategories.isNotEmpty) {
      // 有保存的数据，使用保存的数据
      _categories = savedCategories.map((saved) {
        return BudgetCategory(
          id: saved.id,
          name: saved.name,
          icon: saved.icon,
          color: saved.color,
          amount: saved.amount,
          percentage: saved.percentage,
          hint: saved.hint,
          isHighlighted: saved.isHighlighted,
        );
      }).toList();
    } else {
      // 没有保存的数据，使用默认值
      _initCategories();
    }
  }

  /// 计算本月实际收入
  double _calculateMonthlyIncome() {
    final transactions = ref.read(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  void _initCategories() {
    // 初始分配为0，用户需要手动分配或使用智能分配
    _categories = [
      BudgetCategory(
        id: 'savings',
        name: '储蓄优先',
        icon: Icons.savings,
        color: Colors.green,
        amount: 0,
        percentage: 0.20,
        hint: '推荐20%',
        isHighlighted: true,
      ),
      BudgetCategory(
        id: 'fixed',
        name: '固定支出',
        icon: Icons.home,
        color: Colors.blue,
        amount: 0,
        percentage: 0.33,
        hint: '房租、水电、通讯',
      ),
      BudgetCategory(
        id: 'living',
        name: '生活消费',
        icon: Icons.restaurant,
        color: Colors.orange,
        amount: 0,
        percentage: 0.27,
        hint: '餐饮、购物、交通',
      ),
      BudgetCategory(
        id: 'flexible',
        name: '弹性支出',
        icon: Icons.celebration,
        color: Colors.purple,
        amount: 0,
        percentage: 0.20,
        hint: '娱乐、社交',
      ),
    ];
  }

  double get _totalAllocated =>
      _categories.fold(0.0, (sum, c) => sum + c.amount);

  double get _remaining => _calculateMonthlyIncome() - _totalAllocated;

  bool get _isBalanced => _remaining.abs() < 0.01;

  @override
  Widget build(BuildContext context) {
    final monthlyIncome = _calculateMonthlyIncome();

    return Scaffold(
      appBar: AppBar(
        title: const Text('零基预算分配'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 可分配收入 - 紧凑版
                _CompactIncomeCard(totalIncome: monthlyIncome),

                const SizedBox(height: 10),

                // 智能分配和管理分类按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToSmartAllocation(monthlyIncome),
                        icon: const Icon(Icons.psychology, size: 16),
                        label: const Text('智能分配', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _manageCategories,
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('管理', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 预算分配列表 - 紧凑版
                _CompactBudgetList(
                  categories: _categories,
                  onAmountChanged: (id, amount) {
                    setState(() {
                      final category = _categories.firstWhere((c) => c.id == id);
                      category.amount = amount;
                      category.percentage = monthlyIncome > 0 ? amount / monthlyIncome : 0;
                    });
                  },
                ),

                const SizedBox(height: 10),

                // 零基预算结果 - 紧凑版
                _CompactBalanceResult(
                  remaining: _remaining,
                  isBalanced: _isBalanced,
                ),
              ],
            ),
          ),
          // 底部操作栏
          _BottomActionBar(
            isBalanced: _isBalanced,
            onConfirm: _confirmBudget,
          ),
        ],
      ),
    );
  }

  /// 跳转到智能分配页面
  void _navigateToSmartAllocation(double income) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartAllocationPage(
          incomeAmount: income,
          incomeSource: '本月收入',
        ),
      ),
    );

    // 如果智能分配返回了数据，应用到当前页面
    if (result != null && result is List) {
      setState(() {
        // 将智能分配的AllocationItem转换为BudgetCategory
        _categories = result.map<BudgetCategory>((item) {
          return BudgetCategory(
            id: item.id,
            name: item.name,
            icon: item.icon,
            color: item.color,
            amount: item.amount,
            percentage: income > 0 ? item.amount / income : 0,
            hint: item.reason,
            isHighlighted: item.name == '储蓄优先',
          );
        }).toList();
      });
    }
  }

  void _confirmBudget() async {
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('还有 ¥${_remaining.toStringAsFixed(0)} 未分配'),
          action: SnackBarAction(
            label: '自动分配',
            onPressed: _autoAllocate,
          ),
        ),
      );
      return;
    }

    // 保存预算分配到本地存储
    final budgetNotifier = ref.read(zeroBasedBudgetProvider.notifier);
    final savedCategories = _categories.map((cat) {
      return ZeroBasedBudgetCategory(
        id: cat.id,
        name: cat.name,
        iconCodePoint: cat.icon.codePoint.toString(),
        colorValue: cat.color.toARGB32(),
        amount: cat.amount,
        percentage: cat.percentage,
        hint: cat.hint,
        isHighlighted: cat.isHighlighted,
      );
    }).toList();

    await budgetNotifier.saveCategories(savedCategories);

    if (!mounted) return;
    Navigator.pop(context, _categories);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('零基预算设置成功')),
    );
  }

  void _autoAllocate() {
    // 将剩余金额分配到弹性支出
    setState(() {
      final flexible = _categories.firstWhere((c) => c.id == 'flexible');
      flexible.amount += _remaining;
      final monthlyIncome = _calculateMonthlyIncome();
      flexible.percentage = monthlyIncome > 0 ? flexible.amount / monthlyIncome : 0;
    });
  }

  /// 管理分类（新增、编辑、删除）
  void _manageCategories() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryManagementSheet(
        categories: _categories,
        onCategoriesChanged: (updatedCategories) {
          setState(() {
            _categories = updatedCategories;
          });
        },
      ),
    );
  }
}

/// 紧凑版收入卡片
class _CompactIncomeCard extends StatelessWidget {
  final double totalIncome;

  const _CompactIncomeCard({required this.totalIncome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本月可分配',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '收入 - 支出 - 储蓄 = 0',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Text(
            '¥${totalIncome.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 紧凑版预算列表
class _CompactBudgetList extends StatelessWidget {
  final List<BudgetCategory> categories;
  final Function(String id, double amount) onAmountChanged;

  const _CompactBudgetList({
    required this.categories,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isLast = index == categories.length - 1;
          return _CompactCategoryItem(
            key: ValueKey(category.id),
            category: category,
            showDivider: !isLast,
            onAmountChanged: (amount) => onAmountChanged(category.id, amount),
          );
        }).toList(),
      ),
    );
  }
}

/// 紧凑版分类项
class _CompactCategoryItem extends StatefulWidget {
  final BudgetCategory category;
  final bool showDivider;
  final ValueChanged<double> onAmountChanged;

  const _CompactCategoryItem({
    super.key,
    required this.category,
    required this.showDivider,
    required this.onAmountChanged,
  });

  @override
  State<_CompactCategoryItem> createState() => _CompactCategoryItemState();
}

class _CompactCategoryItemState extends State<_CompactCategoryItem> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.category.amount > 0 ? widget.category.amount.toStringAsFixed(0) : '',
    );
  }

  @override
  void didUpdateWidget(_CompactCategoryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当category的amount变化时，更新controller的文本
    if (oldWidget.category.amount != widget.category.amount) {
      _controller.text = widget.category.amount > 0
          ? widget.category.amount.toStringAsFixed(0)
          : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.category.isHighlighted ? Colors.green[50] : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.category.icon,
                    color: widget.category.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                // 名称
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 金额输入
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '¥',
                      border: InputBorder.none,
                      hintText: '0',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final amount = double.tryParse(value) ?? 0;
                      widget.onAmountChanged(amount);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 百分比
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(widget.category.percentage * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.category.isHighlighted
                          ? Colors.green[600]
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.showDivider)
            Divider(height: 1, color: Colors.grey[200]),
        ],
      ),
    );
  }
}

/// 紧凑版预算结果
class _CompactBalanceResult extends StatelessWidget {
  final double remaining;
  final bool isBalanced;

  const _CompactBalanceResult({
    required this.remaining,
    required this.isBalanced,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isBalanced ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBalanced ? Colors.green[200]! : Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isBalanced ? Icons.check_circle : Icons.pending_actions,
                color: isBalanced ? Colors.green[700] : Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isBalanced ? '完美平衡' : '待分配',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isBalanced ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ],
          ),
          Text(
            '¥${remaining.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isBalanced ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  final bool isBalanced;
  final VoidCallback onConfirm;

  const _BottomActionBar({
    required this.isBalanced,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: isBalanced ? null : Colors.orange,
          ),
          child: Text(isBalanced ? '确认预算方案' : '完成分配'),
        ),
      ),
    );
  }
}

/// 分类管理底部弹窗
class _CategoryManagementSheet extends StatefulWidget {
  final List<BudgetCategory> categories;
  final ValueChanged<List<BudgetCategory>> onCategoriesChanged;

  const _CategoryManagementSheet({
    required this.categories,
    required this.onCategoriesChanged,
  });

  @override
  State<_CategoryManagementSheet> createState() => _CategoryManagementSheetState();
}

class _CategoryManagementSheetState extends State<_CategoryManagementSheet> {
  late List<BudgetCategory> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '管理预算分类',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () {
                  widget.onCategoriesChanged(_categories);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return ListTile(
                  leading: Icon(category.icon, color: category.color),
                  title: Text(category.name),
                  subtitle: Text(category.hint),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editCategory(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _deleteCategory(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('添加新分类'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _addCategory() {
    _showCategoryDialog();
  }

  void _editCategory(int index) {
    _showCategoryDialog(category: _categories[index], index: index);
  }

  void _deleteCategory(int index) {
    setState(() {
      _categories.removeAt(index);
    });
  }

  void _showCategoryDialog({BudgetCategory? category, int? index}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final hintController = TextEditingController(text: category?.hint ?? '');
    IconData selectedIcon = category?.icon ?? Icons.category;
    Color selectedColor = category?.color ?? Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? '添加分类' : '编辑分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '分类名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hintController,
                  decoration: const InputDecoration(
                    labelText: '分类说明',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('图标：'),
                    const SizedBox(width: 8),
                    Icon(selectedIcon, color: selectedColor),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _selectIcon((icon) {
                          setDialogState(() {
                            selectedIcon = icon;
                          });
                        });
                      },
                      child: const Text('选择图标'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('颜色：'),
                    const SizedBox(width: 8),
                    ...[ Colors.red, Colors.orange, Colors.green, Colors.blue, Colors.purple, Colors.pink]
                        .map((color) => GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedColor = color;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: selectedColor == color
                                      ? Border.all(color: Colors.black, width: 2)
                                      : null,
                                ),
                              ),
                            )),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final hint = hintController.text.trim();
                if (name.isEmpty) return;

                final newCategory = BudgetCategory(
                  id: category?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  icon: selectedIcon,
                  color: selectedColor,
                  amount: category?.amount ?? 0,
                  percentage: category?.percentage ?? 0,
                  hint: hint,
                  isHighlighted: category?.isHighlighted ?? false,
                );

                setState(() {
                  if (index != null) {
                    _categories[index] = newCategory;
                  } else {
                    _categories.add(newCategory);
                  }
                });

                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectIcon(ValueChanged<IconData> onIconSelected) {
    final icons = [
      Icons.home, Icons.restaurant, Icons.directions_car, Icons.shopping_bag,
      Icons.celebration, Icons.local_hospital, Icons.school, Icons.fitness_center,
      Icons.pets, Icons.phone, Icons.lightbulb, Icons.water_drop,
      Icons.local_gas_station, Icons.subway, Icons.flight, Icons.hotel,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图标'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: icons.length,
            itemBuilder: (context, index) {
              return IconButton(
                icon: Icon(icons[index], size: 32),
                onPressed: () {
                  onIconSelected(icons[index]);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 预算分类数据模型
class BudgetCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  double amount;
  double percentage;
  final String hint;
  final bool isHighlighted;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.hint,
    this.isHighlighted = false,
  });
}
