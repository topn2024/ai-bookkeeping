import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import 'base/crud_notifier.dart';

/// 带子分类的分类结构
class CategoryWithChildren {
  final Category category;
  final List<Category> children;

  const CategoryWithChildren({
    required this.category,
    required this.children,
  });

  bool get hasChildren => children.isNotEmpty;
}

/// 分类管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class CategoryNotifier extends SimpleCrudNotifier<Category, String> {
  @override
  String get tableName => 'categories';

  @override
  String getId(Category entity) => entity.id;

  @override
  Future<List<Category>> fetchAll() async {
    final categories = await db.getCategories();
    if (categories.isEmpty) {
      // Initialize with all default categories (including subcategories)
      final defaults = [
        ...DefaultCategories.expenseCategories,
        ...DefaultCategories.expenseSubCategories,
        ...DefaultCategories.incomeCategories,
        ...DefaultCategories.incomeSubCategories,
      ];
      for (final category in defaults) {
        await db.insertCategory(category);
      }
      return defaults;
    }
    // Check if we need to add new subcategories (for existing users)
    final existingIds = categories.map((c) => c.id).toSet();
    final allDefaults = [
      ...DefaultCategories.expenseCategories,
      ...DefaultCategories.expenseSubCategories,
      ...DefaultCategories.incomeCategories,
      ...DefaultCategories.incomeSubCategories,
    ];
    final newCategories = allDefaults.where((c) => !existingIds.contains(c.id)).toList();
    if (newCategories.isNotEmpty) {
      for (final category in newCategories) {
        await db.insertCategory(category);
      }
      return [...categories, ...newCategories];
    }
    return categories;
  }

  @override
  Future<void> insertOne(Category entity) => db.insertCategory(entity);

  @override
  Future<void> updateOne(Category entity) => db.updateCategory(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteCategory(id);

  // ==================== 业务特有方法（保留原有接口）====================

  /// 添加分类（保持原有方法名兼容）
  Future<void> addCategory(Category category) => add(category);

  /// 更新分类（保持原有方法名兼容）
  Future<void> updateCategory(Category category) => update(category);

  /// 删除分类（保持原有方法名兼容）
  Future<void> deleteCategory(String id) => delete(id);

  List<Category> getExpenseCategories() {
    return state.where((c) => c.isExpense).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<Category> getIncomeCategories() {
    return state.where((c) => !c.isExpense).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 获取顶级分类（没有父分类的分类）
  List<Category> getRootCategories({required bool isExpense}) {
    return state
        .where((c) => c.isExpense == isExpense && c.parentId == null)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 获取指定父分类的子分类
  List<Category> getChildCategories(String parentId) {
    return state.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 检查分类是否有子分类
  bool hasChildren(String categoryId) {
    return state.any((c) => c.parentId == categoryId);
  }

  /// 获取分类的父分类
  Category? getParentCategory(String categoryId) {
    final category = getCategoryById(categoryId);
    if (category?.parentId == null) return null;
    return getCategoryById(category!.parentId!);
  }

  /// 获取分类树结构（包含子分类的列表）
  List<CategoryWithChildren> getCategoryTree({required bool isExpense}) {
    final roots = getRootCategories(isExpense: isExpense);
    return roots.map((root) {
      final children = getChildCategories(root.id);
      return CategoryWithChildren(category: root, children: children);
    }).toList();
  }

  /// 删除分类时，同时删除其所有子分类
  Future<void> deleteCategoryWithChildren(String id) async {
    // 首先删除所有子分类
    final children = getChildCategories(id);
    for (final child in children) {
      await db.deleteCategory(child.id);
    }
    // 然后删除分类本身
    await db.deleteCategory(id);
    // 更新状态
    state = state.where((c) => c.id != id && c.parentId != id).toList();
  }

  /// 根据ID获取分类（使用基类方法）
  Category? getCategoryById(String id) => getById(id);

  Future<void> reorderCategories(List<Category> categories) async {
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final updated = category.copyWith(sortOrder: i);
      await db.updateCategory(updated);
      state = state.map((c) {
        if (c.id == category.id) {
          return updated;
        }
        return c;
      }).toList();
    }
  }
}

final categoryProvider =
    NotifierProvider<CategoryNotifier, List<Category>>(CategoryNotifier.new);

final expenseCategoriesProvider = Provider<List<Category>>((ref) {
  // 监听状态变化，确保UI刷新
  ref.watch(categoryProvider);
  return ref.read(categoryProvider.notifier).getExpenseCategories();
});

final incomeCategoriesProvider = Provider<List<Category>>((ref) {
  // 监听状态变化，确保UI刷新
  ref.watch(categoryProvider);
  return ref.read(categoryProvider.notifier).getIncomeCategories();
});
