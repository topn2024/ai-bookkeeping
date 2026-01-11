import '../../models/transaction.dart';
import '../../models/transaction_split.dart';
import 'i_repository.dart';

/// 交易 Repository 接口
///
/// 定义交易数据访问操作，继承软删除和批量操作能力。
abstract class ITransactionRepository
    implements ISoftDeleteRepository<Transaction, String>, IBatchRepository<Transaction, String> {
  // ==================== 查询操作 ====================

  /// 根据日期范围查询交易
  Future<List<Transaction>> findByDateRange(DateTime start, DateTime end);

  /// 根据账户 ID 查询交易
  Future<List<Transaction>> findByAccountId(String accountId);

  /// 根据分类查询交易
  Future<List<Transaction>> findByCategory(String category);

  /// 根据账本 ID 查询交易
  Future<List<Transaction>> findByLedgerId(String ledgerId);

  /// 根据交易类型查询
  Future<List<Transaction>> findByType(TransactionType type);

  /// 根据导入批次 ID 查询交易
  Future<List<Transaction>> findByBatchId(String batchId);

  /// 获取第一笔交易
  Future<Transaction?> findFirst();

  // ==================== 统计操作 ====================

  /// 获取日期范围内的总支出
  Future<double> sumExpenseByDateRange(DateTime start, DateTime end);

  /// 获取日期范围内的总收入
  Future<double> sumIncomeByDateRange(DateTime start, DateTime end);

  /// 获取分类的总金额
  Future<double> sumByCategory(String category, DateTime start, DateTime end);

  // ==================== 拆分交易 ====================

  /// 插入交易拆分
  Future<void> insertSplit(TransactionSplit split);

  /// 获取交易的所有拆分
  Future<List<TransactionSplit>> findSplitsByTransactionId(String transactionId);

  /// 删除交易的所有拆分
  Future<void> deleteSplitsByTransactionId(String transactionId);
}
