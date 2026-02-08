import '../../models/transaction.dart';
import '../../models/transaction_split.dart';

/// 交易查询条件
class TransactionQuery {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? category;
  final String? accountId;
  final String? ledgerId;
  final TransactionType? type;
  final bool includeDeleted;
  final int? limit;
  final int? offset;

  const TransactionQuery({
    this.startDate,
    this.endDate,
    this.category,
    this.accountId,
    this.ledgerId,
    this.type,
    this.includeDeleted = false,
    this.limit,
    this.offset,
  });
}

/// 交易服务接口
///
/// 定义交易相关操作的抽象接口，包括 CRUD 操作、查询、统计等。
abstract class ITransactionService {
  // ==================== CRUD 操作 ====================

  /// 获取所有交易
  Future<List<Transaction>> getAll({bool includeDeleted = false});

  /// 根据 ID 获取交易
  Future<Transaction?> getById(String id);

  /// 创建交易
  Future<void> create(Transaction transaction);

  /// 更新交易
  Future<void> update(Transaction transaction);

  /// 删除交易（硬删除）
  Future<void> delete(String id);

  /// 软删除交易
  Future<void> softDelete(String id);

  /// 恢复已删除的交易
  Future<void> restore(String id);

  /// 批量创建交易
  Future<void> batchCreate(List<Transaction> transactions);

  // ==================== 查询操作 ====================

  /// 根据条件查询交易
  Future<List<Transaction>> query(TransactionQuery query);

  /// 根据日期范围查询交易
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);

  /// 根据账户 ID 查询交易
  Future<List<Transaction>> getByAccountId(String accountId);

  /// 根据分类查询交易
  Future<List<Transaction>> getByCategory(String category);

  /// 根据账本 ID 查询交易
  Future<List<Transaction>> getByLedgerId(String ledgerId);

  /// 根据导入批次 ID 查询交易
  Future<List<Transaction>> getByBatchId(String batchId);

  // ==================== 统计操作 ====================

  /// 获取交易总数
  Future<int> getCount();

  /// 获取第一笔交易
  Future<Transaction?> getFirst();

  /// 获取日期范围内的总支出
  Future<double> getTotalExpense(DateTime start, DateTime end);

  /// 获取日期范围内的总收入
  Future<double> getTotalIncome(DateTime start, DateTime end);

  // ==================== 拆分交易 ====================

  /// 创建交易拆分
  Future<void> createSplit(TransactionSplit split);

  /// 获取交易的所有拆分
  Future<List<TransactionSplit>> getSplits(String transactionId);

  /// 删除交易的所有拆分
  Future<void> deleteSplits(String transactionId);
}
