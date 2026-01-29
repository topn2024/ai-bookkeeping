/// Repository Pattern - 基础仓库接口
///
/// 提供标准的 CRUD 操作接口，遵循依赖倒置原则。
/// 所有具体的 Repository 接口都应继承此基础接口。
///
/// 类型参数:
/// - T: 实体类型
/// - ID: 主键类型（通常为 String）
library;

/// 基础仓库接口
///
/// 定义了所有仓库共享的基本 CRUD 操作。
/// 具体的仓库接口应继承此接口并添加领域特定的查询方法。
abstract class IRepository<T, ID> {
  /// 根据 ID 获取单个实体
  ///
  /// 返回 null 表示未找到
  Future<T?> findById(ID id);

  /// 获取所有实体
  ///
  /// [includeDeleted] 是否包含软删除的记录
  Future<List<T>> findAll({bool includeDeleted = false});

  /// 插入新实体
  ///
  /// 返回受影响的行数
  Future<int> insert(T entity);

  /// 批量插入实体
  ///
  /// 在事务中执行，保证原子性
  Future<void> insertAll(List<T> entities);

  /// 更新实体
  ///
  /// 返回受影响的行数
  Future<int> update(T entity);

  /// 根据 ID 删除实体（硬删除）
  ///
  /// 返回受影响的行数
  Future<int> delete(ID id);

  /// 根据 ID 软删除实体
  ///
  /// 设置 deleted_at 字段，保留数据
  /// 返回受影响的行数
  Future<int> softDelete(ID id);

  /// 恢复软删除的实体
  ///
  /// 返回受影响的行数
  Future<int> restore(ID id);

  /// 检查实体是否存在
  Future<bool> exists(ID id);

  /// 获取实体数量
  Future<int> count();
}

/// 带分页的仓库接口
///
/// 用于支持分页查询的仓库
abstract class IPageableRepository<T, ID> extends IRepository<T, ID> {
  /// 分页查询
  ///
  /// [offset] 偏移量
  /// [limit] 每页数量
  Future<PageResult<T>> findPage({
    required int offset,
    required int limit,
  });
}

/// 分页结果
class PageResult<T> {
  /// 当前页数据
  final List<T> items;

  /// 总记录数
  final int total;

  /// 偏移量
  final int offset;

  /// 每页数量
  final int limit;

  const PageResult({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  /// 是否有下一页
  bool get hasNext => offset + items.length < total;

  /// 是否有上一页
  bool get hasPrevious => offset > 0;

  /// 当前页码（从1开始）
  int get currentPage => (offset ~/ limit) + 1;

  /// 总页数
  int get totalPages => (total / limit).ceil();
}

/// 带日期范围查询的仓库接口
///
/// 用于支持按日期筛选的仓库
abstract class IDateRangeRepository<T, ID> extends IRepository<T, ID> {
  /// 按日期范围查询
  ///
  /// [startDate] 开始日期（包含）
  /// [endDate] 结束日期（包含）
  Future<List<T>> findByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });
}

/// 带账本隔离的仓库接口
///
/// 用于多账本场景，确保数据隔离
abstract class ILedgerScopedRepository<T, ID> extends IRepository<T, ID> {
  /// 按账本 ID 查询
  Future<List<T>> findByLedgerId(String ledgerId);

  /// 获取当前账本的实体数量
  Future<int> countByLedgerId(String ledgerId);
}
