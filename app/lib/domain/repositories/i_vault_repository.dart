/// Vault Repository Interface
///
/// 定义小金库（预算信封）实体的仓库接口
library;

import '../../models/budget_vault.dart';
import 'i_repository.dart';

/// 小金库统计
class VaultStatistics {
  final double totalBalance;
  final double totalBudget;
  final double totalSpent;
  final int vaultCount;
  final double averageUsageRate;

  const VaultStatistics({
    required this.totalBalance,
    required this.totalBudget,
    required this.totalSpent,
    required this.vaultCount,
    required this.averageUsageRate,
  });
}

/// 小金库仓库接口
abstract class IVaultRepository extends IRepository<BudgetVault, String> {
  /// 获取所有活跃的小金库
  Future<List<BudgetVault>> findActive();

  /// 按分类查询小金库
  Future<List<BudgetVault>> findByCategory(String category);

  /// 获取指定账本的小金库
  Future<List<BudgetVault>> findByLedger(String ledgerId);

  /// 获取小金库统计
  Future<VaultStatistics> getStatistics();

  /// 向小金库存入金额
  Future<void> deposit(String vaultId, double amount, {String? note});

  /// 从小金库支出金额
  Future<void> spend(String vaultId, double amount, {String? note});

  /// 获取小金库余额
  Future<double> getBalance(String vaultId);

  /// 获取小金库使用率
  Future<double> getUsageRate(String vaultId);

  /// 获取即将超支的小金库
  Future<List<BudgetVault>> findNearingLimit({double threshold = 0.8});

  /// 获取已超支的小金库
  Future<List<BudgetVault>> findOverBudget();

  /// 重置小金库周期（月度/年度等）
  Future<void> resetPeriod(String vaultId);

  /// 获取小金库交易记录
  Future<List<VaultTransaction>> getTransactionHistory(
    String vaultId, {
    DateTime? start,
    DateTime? end,
  });
}

/// 小金库交易记录
class VaultTransaction {
  final String id;
  final String vaultId;
  final VaultTransactionType type;
  final double amount;
  final DateTime transactionDate;
  final String? note;
  final String? relatedTransactionId;

  const VaultTransaction({
    required this.id,
    required this.vaultId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    this.note,
    this.relatedTransactionId,
  });
}

/// 小金库交易类型
enum VaultTransactionType {
  deposit,
  spend,
  transfer,
  adjustment,
}
