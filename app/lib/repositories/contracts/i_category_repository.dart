import '../../models/category.dart';
import 'i_repository.dart';

/// 分类 Repository 接口
///
/// 定义分类数据访问操作，继承软删除能力。
abstract class ICategoryRepository implements ISoftDeleteRepository<Category, String> {
  // ==================== 查询操作 ====================

  /// 根据类型查询分类（收入/支出）
  Future<List<Category>> findByType({required bool isExpense});

  /// 获取顶级分类（无父分类）
  Future<List<Category>> findTopLevel();

  /// 根据父分类 ID 获取子分类
  Future<List<Category>> findByParentId(String parentId);

  /// 获取自定义分类
  Future<List<Category>> findCustomCategories();

  // ==================== 层级操作 ====================

  /// 获取分类的所有祖先（从根到父）
  Future<List<Category>> findAncestors(String categoryId);

  /// 获取分类的所有后代
  Future<List<Category>> findDescendants(String categoryId);

  /// 移动分类到新的父分类下
  Future<void> move(String categoryId, String? newParentId);

  // ==================== 排序操作 ====================

  /// 更新分类排序
  Future<void> updateSortOrder(String categoryId, int sortOrder);

  /// 批量更新排序
  Future<void> updateSortOrders(Map<String, int> sortOrders);
}
