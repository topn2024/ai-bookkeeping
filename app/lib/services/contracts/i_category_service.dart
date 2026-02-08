import '../../models/category.dart';

/// 分类服务接口
///
/// 定义分类相关操作的抽象接口，包括 CRUD 操作、分类层级管理等。
abstract class ICategoryService {
  // ==================== CRUD 操作 ====================

  /// 获取所有分类
  Future<List<Category>> getAll({bool includeDeleted = false});

  /// 根据 ID 获取分类
  Future<Category?> getById(String id);

  /// 创建分类
  Future<void> create(Category category);

  /// 更新分类
  Future<void> update(Category category);

  /// 删除分类（硬删除）
  Future<void> delete(String id);

  /// 软删除分类
  Future<void> softDelete(String id);

  /// 恢复已删除的分类
  Future<void> restore(String id);

  // ==================== 查询操作 ====================

  /// 根据类型获取分类（收入/支出）
  /// [isExpense] 为 true 返回支出分类，为 false 返回收入分类
  Future<List<Category>> getByType({required bool isExpense});

  /// 获取顶级分类（无父分类）
  Future<List<Category>> getTopLevel();

  /// 获取子分类
  Future<List<Category>> getChildren(String parentId);

  /// 获取自定义分类
  Future<List<Category>> getCustomCategories();

  // ==================== 分类层级 ====================

  /// 获取分类的完整路径（从根到当前分类）
  Future<List<Category>> getPath(String categoryId);

  /// 获取分类树（包含所有层级）
  Future<List<CategoryNode>> getCategoryTree();

  /// 移动分类到新的父分类下
  Future<void> move(String categoryId, String? newParentId);

  // ==================== 分类统计 ====================

  /// 获取分类的交易数量
  Future<int> getTransactionCount(String categoryId);

  /// 获取分类的总支出
  Future<double> getTotalExpense(String categoryId, DateTime start, DateTime end);

  /// 获取分类的总收入
  Future<double> getTotalIncome(String categoryId, DateTime start, DateTime end);
}

/// 分类树节点
class CategoryNode {
  final Category category;
  final List<CategoryNode> children;

  const CategoryNode({
    required this.category,
    this.children = const [],
  });
}
