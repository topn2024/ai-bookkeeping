import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final expenseCategories = ref.watch(expenseCategoriesProvider);
    final incomeCategories = ref.watch(incomeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '支出分类'),
            Tab(text: '收入分类'),
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

    // 构建扁平化的列表，包含父分类和子分类
    final flatList = <_CategoryListItem>[];
    for (final item in categoryTree) {
      flatList.add(_CategoryListItem(category: item.category, isChild: false));
      for (final child in item.children) {
        flatList.add(_CategoryListItem(category: child, isChild: true));
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
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
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
                Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (category.isCustom) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '自定义',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                if (hasChildren) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '父分类',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
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
                    tooltip: '添加子分类',
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
    _showCategoryDialog(
      context,
      ref,
      null,
      parentCategory.isExpense,
      parentId: parentCategory.id,
    );
  }

  void _showAddCategoryDialog(
      BuildContext context, WidgetRef ref, bool isExpense) {
    _showCategoryDialog(context, ref, null, isExpense);
  }

  void _showEditCategoryDialog(
      BuildContext context, WidgetRef ref, Category category) {
    _showCategoryDialog(context, ref, category, category.isExpense);
  }

  void _showCategoryDialog(
      BuildContext context, WidgetRef ref, Category? category, bool isExpense,
      {String? parentId}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    Color selectedColor = category?.color ?? const Color(0xFF4CAF50);
    IconData selectedIcon = category?.icon ?? Icons.category;
    String? selectedParentId = parentId ?? category?.parentId;

    // 获取可选的父分类（顶级分类）
    final availableParents =
        ref.read(categoryProvider.notifier).getRootCategories(isExpense: isExpense);

    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFF44336),
      const Color(0xFF795548),
    ];

    final icons = [
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 如果当前分类有子分类，不能设置父分类（避免多级嵌套）
            final hasChildren = isEdit &&
                ref.read(categoryProvider.notifier).hasChildren(category.id);
            // 过滤掉自己，不能选自己作为父分类
            final filteredParents = isEdit
                ? availableParents.where((p) => p.id != category.id).toList()
                : availableParents;

            return AlertDialog(
              title: Text(isEdit
                  ? '编辑分类'
                  : (selectedParentId != null ? '添加子分类' : '添加分类')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '分类名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 父分类选择器
                    if (!hasChildren && filteredParents.isNotEmpty) ...[
                      const Text('父分类（可选）',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedParentId,
                            isExpanded: true,
                            hint: const Text('无（顶级分类）'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('无（顶级分类）'),
                              ),
                              ...filteredParents.map((parent) {
                                return DropdownMenuItem<String?>(
                                  value: parent.id,
                                  child: Row(
                                    children: [
                                      Icon(parent.icon,
                                          color: parent.color, size: 20),
                                      const SizedBox(width: 8),
                                      Text(parent.name),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() => selectedParentId = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (hasChildren) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.amber, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '此分类有子分类，不能设置为其他分类的子分类',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text('图标颜色',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((color) {
                        final isSelected = color == selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('图标',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: icons.length,
                        itemBuilder: (context, index) {
                          final icon = icons[index];
                          final isSelected = icon == selectedIcon;
                          return GestureDetector(
                            onTap: () => setState(() => selectedIcon = icon),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor.withOpacity(0.2)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: selectedColor, width: 2)
                                    : null,
                              ),
                              child: Icon(icon, color: selectedColor),
                            ),
                          );
                        },
                      ),
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
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入分类名称')),
                      );
                      return;
                    }

                    final newCategory = Category(
                      id: category?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      icon: selectedIcon,
                      color: selectedColor,
                      isExpense: isExpense,
                      parentId: selectedParentId,
                      sortOrder: category?.sortOrder ?? 50,
                      isCustom: true,
                    );

                    if (isEdit) {
                      ref
                          .read(categoryProvider.notifier)
                          .updateCategory(newCategory);
                    } else {
                      ref
                          .read(categoryProvider.notifier)
                          .addCategory(newCategory);
                    }

                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? '保存' : '添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, WidgetRef ref, Category category, bool hasChildren) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除"${category.name}"吗？此操作不可恢复。'),
              if (hasChildren) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '此分类包含子分类，删除后所有子分类也将被删除',
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
              child: const Text('取消'),
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
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}
