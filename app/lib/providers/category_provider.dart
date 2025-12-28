import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/database_service.dart';

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

class CategoryNotifier extends Notifier<List<Category>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<Category> build() {
    _loadCategories();
    return [];
  }

  Future<void> _loadCategories() async {
    final categories = await _db.getCategories();
    if (categories.isEmpty) {
      // Initialize with default categories
      final defaults = [
        ...DefaultCategories.expenseCategories,
        ...DefaultCategories.incomeCategories,
      ];
      for (final category in defaults) {
        await _db.insertCategory(category);
      }
      state = defaults;
    } else {
      state = categories;
    }
  }

  Future<void> addCategory(Category category) async {
    await _db.insertCategory(category);
    state = [...state, category];
  }

  Future<void> updateCategory(Category category) async {
    await _db.updateCategory(category);
    state = state.map((c) => c.id == category.id ? category : c).toList();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    state = state.where((c) => c.id != id).toList();
  }

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
      await _db.deleteCategory(child.id);
    }
    // 然后删除分类本身
    await _db.deleteCategory(id);
    // 更新状态
    state = state.where((c) => c.id != id && c.parentId != id).toList();
  }

  Category? getCategoryById(String id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> reorderCategories(List<Category> categories) async {
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final updated = category.copyWith(sortOrder: i);
      await _db.updateCategory(updated);
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
  return ref.watch(categoryProvider.notifier).getExpenseCategories();
});

final incomeCategoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(categoryProvider.notifier).getIncomeCategories();
});
