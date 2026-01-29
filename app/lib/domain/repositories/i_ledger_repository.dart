/// Ledger Repository Interface
///
/// 定义账本实体的仓库接口
library;

import '../../models/ledger.dart';
import 'i_repository.dart';

/// 账本仓库接口
abstract class ILedgerRepository extends IRepository<Ledger, String> {
  /// 获取默认账本
  Future<Ledger?> findDefault();

  /// 设置默认账本
  Future<int> setDefault(String id);

  /// 按类型查询账本
  Future<List<Ledger>> findByType(LedgerType type);

  /// 获取当前用户有权限访问的账本
  Future<List<Ledger>> findAccessible(String userId);

  /// 获取当前用户创建的账本
  Future<List<Ledger>> findByOwner(String ownerId);

  /// 获取共享账本
  Future<List<Ledger>> findShared();

  /// 检查用户是否有账本权限
  Future<bool> hasAccess(String ledgerId, String userId);

  /// 获取账本成员数量
  Future<int> getMemberCount(String ledgerId);
}
