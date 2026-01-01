import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';

/// 用于构建扁平化分类列表的辅助类
class _CategoryListItem {
  final Category category;
  final bool isChild;

  _CategoryListItem({required this.category, required this.isChild});
}

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends ConsumerState<CategoryManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // 记录展开的分类ID
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleExpand(String categoryId) {
    setState(() {
      if (_expandedCategories.contains(categoryId)) {
        _expandedCategories.remove(categoryId);
      } else {
        _expandedCategories.add(categoryId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = ref.watch(expenseCategoriesProvider);
    final incomeCategories = ref.watch(incomeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.categoryManagement),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: context.l10n.expenseCategories),
            Tab(text: context.l10n.incomeCategories),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategoryDialog(
              context,
              ref,
              _tabController.index == 0,
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(expenseCategories, true),
          _buildCategoryList(incomeCategories, false),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, bool isExpense) {
    // 获取分类树结构
    final categoryTree =
        ref.read(categoryProvider.notifier).getCategoryTree(isExpense: isExpense);

    // 构建扁平化的列表，只包含父分类和已展开的子分类
    final flatList = <_CategoryListItem>[];
    for (final item in categoryTree) {
      flatList.add(_CategoryListItem(category: item.category, isChild: false));
      // 只有展开的分类才显示子分类
      if (_expandedCategories.contains(item.category.id)) {
        for (final child in item.children) {
          flatList.add(_CategoryListItem(category: child, isChild: true));
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: flatList.length,
      itemBuilder: (context, index) {
        final item = flatList[index];
        final category = item.category;
        final hasChildren =
            ref.read(categoryProvider.notifier).hasChildren(category.id);
        final isExpanded = _expandedCategories.contains(category.id);

        return Card(
          key: ValueKey(category.id),
          margin: EdgeInsets.only(
            bottom: 8,
            left: item.isChild ? 24 : 0,  // 子分类缩进
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: hasChildren && !item.isChild
                ? () => _toggleExpand(category.id)
                : null,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, color: category.color),
            ),
            title: Row(
              children: [
                if (item.isChild) ...[
                  Icon(Icons.subdirectory_arrow_right,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                ],
                // 有子分类的父分类显示展开/收起图标
                if (hasChildren && !item.isChild) ...[
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: category.color,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    category.localizedName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (category.isCustom) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.l10n.customCategory,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                // 显示子分类数量
                if (hasChildren && !item.isChild) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.l10n.subcategoriesCount(ref.read(categoryProvider.notifier).getChildCategories(category.id).length),
                      style: TextStyle(
                        fontSize: 10,
                        color: category.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 添加子分类按钮（只有非子分类才显示）
                if (!item.isChild)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.primary),
                    tooltip: context.l10n.addCategory,
                    onPressed: () =>
                        _showAddSubcategoryDialog(context, ref, category),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.textSecondary),
                  onPressed: () =>
                      _showEditCategoryDialog(context, ref, category),
                ),
                if (category.isCustom)
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.expense),
                    onPressed: () =>
                        _showDeleteConfirmDialog(context, ref, category, hasChildren),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddSubcategoryDialog(
      BuildContext context, WidgetRef ref, Category parentCategory) {
    // 使用Navigator.push显示全屏对话框页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CategoryEditPage(
          category: null,
          isExpense: parentCategory.isExpense,
          parentId: parentCategory.id,
        ),
      ),
    );
  }

  void _showAddCategoryDialog(
      BuildContext context, WidgetRef ref, bool isExpense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CategoryEditPage(
          category: null,
          isExpense: isExpense,
          parentId: null,
        ),
      ),
    );
  }

  void _showEditCategoryDialog(
      BuildContext context, WidgetRef ref, Category category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CategoryEditPage(
          category: category,
          isExpense: category.isExpense,
          parentId: category.parentId,
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, WidgetRef ref, Category category, bool hasChildren) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.deleteCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.confirmDeleteCategoryMsg(category.localizedName)),
              if (hasChildren) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.deleteWithSubcategories,
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
              ),
              onPressed: () {
                if (hasChildren) {
                  ref
                      .read(categoryProvider.notifier)
                      .deleteCategoryWithChildren(category.id);
                } else {
                  ref.read(categoryProvider.notifier).deleteCategory(category.id);
                }
                Navigator.pop(context);
              },
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
  }
}

/// 分类编辑页面（全屏）
class _CategoryEditPage extends ConsumerStatefulWidget {
  final Category? category;
  final bool isExpense;
  final String? parentId;

  const _CategoryEditPage({
    this.category,
    required this.isExpense,
    this.parentId,
  });

  @override
  ConsumerState<_CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends ConsumerState<_CategoryEditPage> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  late IconData _selectedIcon;
  String? _selectedParentId;

  final List<Color> _colors = const [
    Color(0xFFE91E63),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFF44336),
    Color(0xFF795548),
  ];

  final List<IconData> _icons = const [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.movie,
    Icons.home,
    Icons.local_hospital,
    Icons.school,
    Icons.phone_android,
    Icons.checkroom,
    Icons.face,
    Icons.sports_esports,
    Icons.pets,
    Icons.flight,
    Icons.fitness_center,
    Icons.coffee,
    Icons.work,
    Icons.card_giftcard,
    Icons.trending_up,
    Icons.redeem,
    Icons.receipt_long,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? const Color(0xFF4CAF50);
    _selectedIcon = widget.category?.icon ?? Icons.category;
    _selectedParentId = widget.parentId ?? widget.category?.parentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    final title = isEdit
        ? context.l10n.editCategory
        : (_selectedParentId != null ? context.l10n.addCategory : context.l10n.addCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(context.l10n.save, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分类名称
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.categoryName,
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),

            // 图标颜色
            Text(context.l10n.iconColor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 图标选择
            Text(context.l10n.iconText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _icons.length,
              itemBuilder: (context, index) {
                final icon = _icons[index];
                final isSelected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withOpacity(0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: _selectedColor, width: 2)
                          : null,
                    ),
                    child: Icon(icon, color: _selectedColor, size: 28),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseEnter)),
      );
      return;
    }

    final newCategory = Category(
      id: widget.category?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      icon: _selectedIcon,
      color: _selectedColor,
      isExpense: widget.isExpense,
      parentId: _selectedParentId,
      sortOrder: widget.category?.sortOrder ?? 50,
      isCustom: true,
    );

    if (widget.category != null) {
      ref.read(categoryProvider.notifier).updateCategory(newCategory);
    } else {
      ref.read(categoryProvider.notifier).addCategory(newCategory);
    }

    Navigator.pop(context);
  }
}
