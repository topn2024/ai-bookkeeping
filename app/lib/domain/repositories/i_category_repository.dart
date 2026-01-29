/// Category Repository Interface
///
/// 定义分类实体的仓库接口
library;

import '../../models/category.dart';
import 'i_repository.dart';

/// 分类仓库接口
abstract class ICategoryRepository extends IRepository<Category, String> {
  /// 获取支出分类
  Future<List<Category>> findExpenseCategories();

  /// 获取收入分类
  Future<List<Category>> findIncomeCategories();

  /// 获取一级分类（无父分类）
  Future<List<Category>> findRootCategories({bool? isExpense});

  /// 获取子分类
  Future<List<Category>> findByParentId(String parentId);

  /// 获取用户自定义分类
  Future<List<Category>> findCustomCategories();

  /// 按名称查找分类
  Future<Category?> findByName(String name, {bool? isExpense});

  /// 更新分类排序
  Future<void> updateSortOrder(List<String> categoryIds);

  /// 合并分类（将一个分类的所有交易转移到另一个分类）
  Future<void> mergeInto(String sourceId, String targetId);

  /// 获取分类使用次数统计
  Future<Map<String, int>> getUsageCount();

  /// 获取最常用的分类
  Future<List<Category>> findMostUsed({int limit = 10});
}
