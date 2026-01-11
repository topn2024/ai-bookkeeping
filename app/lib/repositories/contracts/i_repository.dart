/// 基础 Repository 接口
///
/// 定义通用的数据访问操作，所有具体 Repository 接口都应该继承此接口。
///
/// 类型参数:
/// - [T]: 实体类型
/// - [ID]: 实体 ID 类型
abstract class IRepository<T, ID> {
  /// 获取所有实体
  Future<List<T>> findAll();

  /// 根据 ID 获取实体
  Future<T?> findById(ID id);

  /// 插入实体
  Future<void> insert(T entity);

  /// 更新实体
  Future<void> update(T entity);

  /// 删除实体
  Future<void> delete(ID id);

  /// 检查实体是否存在
  Future<bool> exists(ID id);

  /// 获取实体数量
  Future<int> count();
}

/// 支持软删除的 Repository 接口
abstract class ISoftDeleteRepository<T, ID> extends IRepository<T, ID> {
  /// 获取所有实体（包括已删除的）
  Future<List<T>> findAllIncludingDeleted();

  /// 软删除实体
  Future<void> softDelete(ID id);

  /// 恢复已删除的实体
  Future<void> restore(ID id);

  /// 永久删除已软删除的实体
  Future<void> purge(ID id);

  /// 获取所有已删除的实体
  Future<List<T>> findDeleted();
}

/// 支持批量操作的 Repository 接口
abstract class IBatchRepository<T, ID> extends IRepository<T, ID> {
  /// 批量插入实体
  Future<void> insertAll(List<T> entities);

  /// 批量更新实体
  Future<void> updateAll(List<T> entities);

  /// 批量删除实体
  Future<void> deleteAll(List<ID> ids);
}
