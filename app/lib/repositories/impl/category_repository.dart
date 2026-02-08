import '../../models/category.dart';
import '../../core/contracts/i_database_service.dart';
import '../contracts/i_category_repository.dart';

/// 分类 Repository 实现
///
/// 封装所有分类相关的数据库操作。
class CategoryRepository implements ICategoryRepository {
  final IDatabaseService _db;

  CategoryRepository(this._db);

  // ==================== IRepository 基础操作 ====================

  @override
  Future<List<Category>> findAll() => _db.getCategories();

  @override
  Future<Category?> findById(String id) async {
    final categories = await _db.getCategories();
    try {
      return categories.firstWhere((c) => c.id == id);
    } on StateError {
      // firstWhere throws StateError when no element is found
      return null;
    }
  }

  @override
  Future<void> insert(Category entity) => _db.insertCategory(entity);

  @override
  Future<void> update(Category entity) => _db.updateCategory(entity);

  @override
  Future<void> delete(String id) => _db.deleteCategory(id);

  @override
  Future<bool> exists(String id) async {
    final category = await findById(id);
    return category != null;
  }

  @override
  Future<int> count() async {
    final categories = await _db.getCategories();
    return categories.length;
  }

  // ==================== ISoftDeleteRepository 操作 ====================

  @override
  Future<List<Category>> findAllIncludingDeleted() =>
      _db.getCategories(includeDeleted: true);

  @override
  Future<void> softDelete(String id) => _db.softDeleteCategory(id);

  @override
  Future<void> restore(String id) => _db.restoreCategory(id);

  @override
  Future<void> purge(String id) => _db.deleteCategory(id);

  @override
  Future<List<Category>> findDeleted() async {
    final all = await _db.getCategories(includeDeleted: true);
    final active = await _db.getCategories(includeDeleted: false);
    final activeIds = active.map((c) => c.id).toSet();
    return all.where((c) => !activeIds.contains(c.id)).toList();
  }

  // ==================== 查询操作 ====================

  @override
  Future<List<Category>> findByType({required bool isExpense}) async {
    final categories = await _db.getCategories();
    return categories.where((c) => c.isExpense == isExpense).toList();
  }

  @override
  Future<List<Category>> findTopLevel() async {
    final categories = await _db.getCategories();
    return categories.where((c) => c.parentId == null).toList();
  }

  @override
  Future<List<Category>> findByParentId(String parentId) async {
    final categories = await _db.getCategories();
    return categories.where((c) => c.parentId == parentId).toList();
  }

  @override
  Future<List<Category>> findCustomCategories() async {
    final customMaps = await _db.getCustomCategories();
    final categories = await _db.getCategories();
    final customIds = customMaps.map((m) => m['id'] as String).toSet();
    return categories.where((c) => customIds.contains(c.id)).toList();
  }

  // ==================== 层级操作 ====================

  @override
  Future<List<Category>> findAncestors(String categoryId) async {
    final ancestors = <Category>[];
    final visited = <String>{};
    var currentId = categoryId;

    while (true) {
      final category = await findById(currentId);
      if (category == null || category.parentId == null) break;

      // Cycle detection: if we've seen this parent before, break to avoid infinite loop
      if (visited.contains(category.parentId!)) break;

      final parent = await findById(category.parentId!);
      if (parent == null) break;

      ancestors.insert(0, parent);
      visited.add(category.parentId!);
      currentId = parent.id;
    }

    return ancestors;
  }

  @override
  Future<List<Category>> findDescendants(String categoryId) async {
    return _findDescendantsWithDepth(categoryId, 0);
  }

  /// Internal method to find descendants with depth limit
  Future<List<Category>> _findDescendantsWithDepth(String categoryId, int currentDepth) async {
    const maxDepth = 20; // Maximum depth to prevent infinite recursion

    if (currentDepth >= maxDepth) {
      return [];
    }

    final descendants = <Category>[];
    final children = await findByParentId(categoryId);

    for (final child in children) {
      descendants.add(child);
      final childDescendants = await _findDescendantsWithDepth(child.id, currentDepth + 1);
      descendants.addAll(childDescendants);
    }

    return descendants;
  }

  @override
  Future<void> move(String categoryId, String? newParentId) async {
    final category = await findById(categoryId);
    if (category != null) {
      final updated = category.copyWith(parentId: newParentId);
      await _db.updateCategory(updated);
    }
  }

  // ==================== 排序操作 ====================

  @override
  Future<void> updateSortOrder(String categoryId, int sortOrder) async {
    final category = await findById(categoryId);
    if (category != null) {
      final updated = category.copyWith(sortOrder: sortOrder);
      await _db.updateCategory(updated);
    }
  }

  @override
  Future<void> updateSortOrders(Map<String, int> sortOrders) async {
    for (final entry in sortOrders.entries) {
      await updateSortOrder(entry.key, entry.value);
    }
  }
}
