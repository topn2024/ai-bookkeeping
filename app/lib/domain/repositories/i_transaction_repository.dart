/// Transaction Repository Interface
///
/// 定义交易实体的仓库接口，继承基础仓库接口并添加交易特定的查询方法。
library;

import '../../models/transaction.dart';
import 'i_repository.dart';

/// 交易查询参数
class TransactionQueryParams {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? category;
  final String? subcategory;
  final String? accountId;
  final String? toAccountId;
  final TransactionType? type;
  final double? minAmount;
  final double? maxAmount;
  final String? note;
  final List<String>? tags;
  final TransactionSource? source;
  final String? vaultId;
  final String? resourcePoolId;
  final String? importBatchId;
  final String? externalId;
  final ExternalSource? externalSource;
  final bool? isReimbursable;
  final bool? isReimbursed;
  final int limit;
  final int offset;

  const TransactionQueryParams({
    this.startDate,
    this.endDate,
    this.category,
    this.subcategory,
    this.accountId,
    this.toAccountId,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.note,
    this.tags,
    this.source,
    this.vaultId,
    this.resourcePoolId,
    this.importBatchId,
    this.externalId,
    this.externalSource,
    this.isReimbursable,
    this.isReimbursed,
    this.limit = 50,
    this.offset = 0,
  });

  /// 创建仅包含日期范围的查询参数
  factory TransactionQueryParams.dateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 50,
  }) {
    return TransactionQueryParams(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// 创建仅包含分类的查询参数
  factory TransactionQueryParams.byCategory(String category, {int limit = 50}) {
    return TransactionQueryParams(category: category, limit: limit);
  }

  /// 创建仅包含账户的查询参数
  factory TransactionQueryParams.byAccount(String accountId, {int limit = 50}) {
    return TransactionQueryParams(accountId: accountId, limit: limit);
  }
}

/// 交易统计结果
class TransactionStatistics {
  /// 总支出
  final double totalExpense;

  /// 总收入
  final double totalIncome;

  /// 净额（收入 - 支出）
  final double netAmount;

  /// 交易数量
  final int count;

  /// 按分类的统计
  final Map<String, double> byCategory;

  /// 按账户的统计
  final Map<String, double> byAccount;

  const TransactionStatistics({
    required this.totalExpense,
    required this.totalIncome,
    required this.netAmount,
    required this.count,
    this.byCategory = const {},
    this.byAccount = const {},
  });

  factory TransactionStatistics.empty() {
    return const TransactionStatistics(
      totalExpense: 0,
      totalIncome: 0,
      netAmount: 0,
      count: 0,
    );
  }
}

/// 交易仓库接口
///
/// 提供交易实体的 CRUD 操作和特定查询方法。
/// 实现类应注入数据库服务来执行实际的数据库操作。
abstract class ITransactionRepository
    extends IRepository<Transaction, String>
    implements IDateRangeRepository<Transaction, String> {
  // ==================== 基础查询 ====================

  /// 根据条件查询交易
  Future<List<Transaction>> query(TransactionQueryParams params);

  /// 获取第一条交易记录
  Future<Transaction?> findFirst();

  // ==================== 按字段查询 ====================

  /// 根据账户 ID 查询交易
  Future<List<Transaction>> findByAccountId(String accountId);

  /// 根据分类查询交易
  Future<List<Transaction>> findByCategory(String category);

  /// 根据类型查询交易
  Future<List<Transaction>> findByType(TransactionType type);

  /// 根据来源查询交易
  Future<List<Transaction>> findBySource(TransactionSource source);

  /// 根据小金库 ID 查询交易
  Future<List<Transaction>> findByVaultId(String vaultId);

  /// 根据资源池 ID 查询交易
  Future<List<Transaction>> findByResourcePoolId(String resourcePoolId);

  // ==================== 导入相关 ====================

  /// 根据导入批次 ID 查询交易
  Future<List<Transaction>> findByImportBatchId(String batchId);

  /// 根据外部交易号查询
  ///
  /// 用于去重检测
  Future<Transaction?> findByExternalId(String externalId, ExternalSource source);

  /// 查找潜在重复交易
  ///
  /// 基于金额、日期、商户等信息查找可能重复的交易
  Future<List<Transaction>> findPotentialDuplicates({
    required double amount,
    required DateTime date,
    String? note,
    Duration tolerance = const Duration(days: 1),
  });

  // ==================== 统计查询 ====================

  /// 获取日期范围内的统计数据
  Future<TransactionStatistics> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
  });

  /// 按月统计
  Future<Map<String, TransactionStatistics>> getMonthlyStatistics({
    required int year,
    String? accountId,
  });

  // ==================== 报销相关 ====================

  /// 获取可报销的交易
  Future<List<Transaction>> findReimbursable();

  /// 获取已报销的交易
  Future<List<Transaction>> findReimbursed();

  /// 标记交易为已报销
  Future<int> markAsReimbursed(String id);

  // ==================== 成员相关（家庭账本） ====================

  /// 根据成员 ID 查询交易
  Future<List<Transaction>> findByMemberId(String memberId);
}
