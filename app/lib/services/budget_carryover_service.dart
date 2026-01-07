import 'package:sqflite/sqflite.dart';

import '../models/budget_vault.dart';
import 'vault_repository.dart';

/// 结转策略
enum CarryoverStrategy {
  /// 不结转（清零重置）
  reset,

  /// 全额结转（剩余金额全部带入下期）
  fullCarryover,

  /// 部分结转（按比例结转）
  partialCarryover,

  /// 归集到储蓄（剩余金额转入储蓄小金库）
  consolidateToSavings,
}

/// 结转配置
class CarryoverConfig {
  final CarryoverStrategy strategy;
  final double? carryoverPercentage; // 部分结转时的比例（0-1）
  final String? savingsVaultId; // 归集储蓄时的目标小金库ID
  final double maxCarryoverAmount; // 最大结转金额（防止积累过多）
  final bool autoExecute; // 是否自动执行
  final int executeDayOfMonth; // 每月几号执行（1-28）

  const CarryoverConfig({
    this.strategy = CarryoverStrategy.reset,
    this.carryoverPercentage,
    this.savingsVaultId,
    this.maxCarryoverAmount = double.infinity,
    this.autoExecute = false,
    this.executeDayOfMonth = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'strategy': strategy.index,
      'carryoverPercentage': carryoverPercentage,
      'savingsVaultId': savingsVaultId,
      'maxCarryoverAmount': maxCarryoverAmount,
      'autoExecute': autoExecute ? 1 : 0,
      'executeDayOfMonth': executeDayOfMonth,
    };
  }

  factory CarryoverConfig.fromMap(Map<String, dynamic> map) {
    return CarryoverConfig(
      strategy: CarryoverStrategy.values[map['strategy'] as int? ?? 0],
      carryoverPercentage: (map['carryoverPercentage'] as num?)?.toDouble(),
      savingsVaultId: map['savingsVaultId'] as String?,
      maxCarryoverAmount:
          (map['maxCarryoverAmount'] as num?)?.toDouble() ?? double.infinity,
      autoExecute: map['autoExecute'] == 1,
      executeDayOfMonth: map['executeDayOfMonth'] as int? ?? 1,
    );
  }
}

/// 单个小金库的结转结果
class VaultCarryoverResult {
  final String vaultId;
  final String vaultName;
  final double previousBalance; // 上期余额
  final double carryoverAmount; // 结转金额
  final double newBalance; // 新期初余额
  final double? transferToSavings; // 转入储蓄的金额
  final String? note;

  const VaultCarryoverResult({
    required this.vaultId,
    required this.vaultName,
    required this.previousBalance,
    required this.carryoverAmount,
    required this.newBalance,
    this.transferToSavings,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'vaultId': vaultId,
      'vaultName': vaultName,
      'previousBalance': previousBalance,
      'carryoverAmount': carryoverAmount,
      'newBalance': newBalance,
      'transferToSavings': transferToSavings,
      'note': note,
    };
  }
}

/// 结转执行结果
class CarryoverResult {
  final DateTime executedAt;
  final String periodFrom; // 如 "2024-01"
  final String periodTo; // 如 "2024-02"
  final List<VaultCarryoverResult> vaultResults;
  final double totalCarryover;
  final double totalTransferToSavings;
  final bool success;
  final String? errorMessage;

  const CarryoverResult({
    required this.executedAt,
    required this.periodFrom,
    required this.periodTo,
    required this.vaultResults,
    required this.totalCarryover,
    required this.totalTransferToSavings,
    this.success = true,
    this.errorMessage,
  });

  factory CarryoverResult.error(String message) {
    return CarryoverResult(
      executedAt: DateTime.now(),
      periodFrom: '',
      periodTo: '',
      vaultResults: const [],
      totalCarryover: 0,
      totalTransferToSavings: 0,
      success: false,
      errorMessage: message,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'executedAt': executedAt.millisecondsSinceEpoch,
      'periodFrom': periodFrom,
      'periodTo': periodTo,
      'vaultResults': vaultResults.map((r) => r.toMap()).toList(),
      'totalCarryover': totalCarryover,
      'totalTransferToSavings': totalTransferToSavings,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}

/// 结转历史记录
class CarryoverRecord {
  final String id;
  final String ledgerId;
  final DateTime executedAt;
  final String periodFrom;
  final String periodTo;
  final double totalCarryover;
  final double totalTransferToSavings;
  final String resultsJson; // 详细结果的JSON

  const CarryoverRecord({
    required this.id,
    required this.ledgerId,
    required this.executedAt,
    required this.periodFrom,
    required this.periodTo,
    required this.totalCarryover,
    required this.totalTransferToSavings,
    required this.resultsJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'executedAt': executedAt.millisecondsSinceEpoch,
      'periodFrom': periodFrom,
      'periodTo': periodTo,
      'totalCarryover': totalCarryover,
      'totalTransferToSavings': totalTransferToSavings,
      'resultsJson': resultsJson,
    };
  }

  factory CarryoverRecord.fromMap(Map<String, dynamic> map) {
    return CarryoverRecord(
      id: map['id'] as String,
      ledgerId: map['ledgerId'] as String,
      executedAt: DateTime.fromMillisecondsSinceEpoch(map['executedAt'] as int),
      periodFrom: map['periodFrom'] as String,
      periodTo: map['periodTo'] as String,
      totalCarryover: (map['totalCarryover'] as num).toDouble(),
      totalTransferToSavings: (map['totalTransferToSavings'] as num).toDouble(),
      resultsJson: map['resultsJson'] as String,
    );
  }
}

/// 预算结转与周期管理服务
///
/// 负责：
/// - 月度/周期结转处理
/// - 结转策略配置
/// - 结转历史记录
/// - 自动结转调度
class BudgetCarryoverService {
  final VaultRepository _vaultRepository;
  final Database _db;

  static const String configTableName = 'carryover_configs';
  static const String recordTableName = 'carryover_records';

  BudgetCarryoverService(this._vaultRepository, this._db);

  /// 创建数据库表
  static Future<void> createTables(Database db) async {
    // 结转配置表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $configTableName (
        id TEXT PRIMARY KEY,
        vaultId TEXT UNIQUE NOT NULL,
        strategy INTEGER DEFAULT 0,
        carryoverPercentage REAL,
        savingsVaultId TEXT,
        maxCarryoverAmount REAL,
        autoExecute INTEGER DEFAULT 0,
        executeDayOfMonth INTEGER DEFAULT 1,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (vaultId) REFERENCES budget_vaults(id) ON DELETE CASCADE
      )
    ''');

    // 结转记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $recordTableName (
        id TEXT PRIMARY KEY,
        ledgerId TEXT NOT NULL,
        executedAt INTEGER NOT NULL,
        periodFrom TEXT NOT NULL,
        periodTo TEXT NOT NULL,
        totalCarryover REAL NOT NULL,
        totalTransferToSavings REAL NOT NULL,
        resultsJson TEXT NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_carryover_ledger ON $recordTableName(ledgerId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_carryover_period ON $recordTableName(periodFrom)');
  }

  // ==================== 结转配置管理 ====================

  /// 获取小金库的结转配置
  Future<CarryoverConfig?> getConfig(String vaultId) async {
    final results = await _db.query(
      configTableName,
      where: 'vaultId = ?',
      whereArgs: [vaultId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CarryoverConfig.fromMap(results.first);
  }

  /// 设置小金库的结转配置
  Future<void> setConfig(String vaultId, CarryoverConfig config) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.insert(
      configTableName,
      {
        'id': 'config_$vaultId',
        'vaultId': vaultId,
        ...config.toMap(),
        'createdAt': now,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除小金库的结转配置
  Future<void> deleteConfig(String vaultId) async {
    await _db.delete(
      configTableName,
      where: 'vaultId = ?',
      whereArgs: [vaultId],
    );
  }

  /// 获取所有启用自动结转的配置
  Future<List<Map<String, dynamic>>> getAutoExecuteConfigs() async {
    return await _db.query(
      configTableName,
      where: 'autoExecute = 1',
    );
  }

  // ==================== 结转执行 ====================

  /// 执行单个小金库的结转
  Future<VaultCarryoverResult> executeVaultCarryover(
    BudgetVault vault, {
    CarryoverConfig? config,
  }) async {
    config ??= await getConfig(vault.id) ?? const CarryoverConfig();

    final previousBalance = vault.available;
    double carryoverAmount;
    double? transferToSavings;
    String? note;

    switch (config.strategy) {
      case CarryoverStrategy.reset:
        carryoverAmount = 0;
        note = '预算已清零重置';
        break;

      case CarryoverStrategy.fullCarryover:
        carryoverAmount = previousBalance.clamp(0, config.maxCarryoverAmount);
        note = previousBalance > config.maxCarryoverAmount
            ? '已达到最大结转限额'
            : '全额结转';
        break;

      case CarryoverStrategy.partialCarryover:
        final percentage = config.carryoverPercentage ?? 0.5;
        carryoverAmount =
            (previousBalance * percentage).clamp(0, config.maxCarryoverAmount);
        note = '按${(percentage * 100).toInt()}%比例结转';
        break;

      case CarryoverStrategy.consolidateToSavings:
        carryoverAmount = 0;
        if (previousBalance > 0 && config.savingsVaultId != null) {
          transferToSavings = previousBalance;
          note = '剩余金额已转入储蓄';
        } else {
          note = '无剩余金额或未设置储蓄目标';
        }
        break;
    }

    // 更新小金库金额
    await _vaultRepository.resetAmounts(
      vault.id,
      newAllocatedAmount: carryoverAmount,
      newSpentAmount: 0,
    );

    // 如果有转入储蓄
    if (transferToSavings != null &&
        transferToSavings > 0 &&
        config.savingsVaultId != null) {
      await _vaultRepository.updateAllocatedAmount(
        config.savingsVaultId!,
        transferToSavings,
      );
    }

    return VaultCarryoverResult(
      vaultId: vault.id,
      vaultName: vault.name,
      previousBalance: previousBalance,
      carryoverAmount: carryoverAmount,
      newBalance: carryoverAmount,
      transferToSavings: transferToSavings,
      note: note,
    );
  }

  /// 执行账本所有小金库的结转
  Future<CarryoverResult> executeCarryover({
    required String ledgerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final now = DateTime.now();
      fromDate ??= DateTime(now.year, now.month - 1, 1);
      toDate ??= DateTime(now.year, now.month, 1);

      final periodFrom = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}';
      final periodTo = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}';

      // 检查是否已执行过
      final existing = await _db.query(
        recordTableName,
        where: 'ledgerId = ? AND periodFrom = ? AND periodTo = ?',
        whereArgs: [ledgerId, periodFrom, periodTo],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return CarryoverResult.error('本期结转已执行过');
      }

      // 获取账本下所有小金库
      final vaults = await _vaultRepository.getByLedgerId(ledgerId);
      final enabledVaults = vaults.where((v) => v.isEnabled).toList();

      if (enabledVaults.isEmpty) {
        return CarryoverResult.error('没有需要结转的小金库');
      }

      // 执行每个小金库的结转
      final vaultResults = <VaultCarryoverResult>[];
      double totalCarryover = 0;
      double totalTransferToSavings = 0;

      for (final vault in enabledVaults) {
        // 储蓄类小金库默认全额结转
        CarryoverConfig? config = await getConfig(vault.id);
        if (config == null && vault.type == VaultType.savings) {
          config = const CarryoverConfig(strategy: CarryoverStrategy.fullCarryover);
        }

        final result = await executeVaultCarryover(vault, config: config);
        vaultResults.add(result);
        totalCarryover += result.carryoverAmount;
        totalTransferToSavings += result.transferToSavings ?? 0;
      }

      // 记录结转历史
      final record = CarryoverRecord(
        id: 'carryover_${DateTime.now().millisecondsSinceEpoch}',
        ledgerId: ledgerId,
        executedAt: DateTime.now(),
        periodFrom: periodFrom,
        periodTo: periodTo,
        totalCarryover: totalCarryover,
        totalTransferToSavings: totalTransferToSavings,
        resultsJson: vaultResults.map((r) => r.toMap()).toList().toString(),
      );

      await _db.insert(recordTableName, record.toMap());

      return CarryoverResult(
        executedAt: DateTime.now(),
        periodFrom: periodFrom,
        periodTo: periodTo,
        vaultResults: vaultResults,
        totalCarryover: totalCarryover,
        totalTransferToSavings: totalTransferToSavings,
      );
    } catch (e) {
      return CarryoverResult.error('结转执行失败: $e');
    }
  }

  /// 预览结转（不实际执行）
  Future<CarryoverResult> previewCarryover({
    required String ledgerId,
  }) async {
    final now = DateTime.now();
    final periodFrom = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final periodTo = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}';

    final vaults = await _vaultRepository.getByLedgerId(ledgerId);
    final enabledVaults = vaults.where((v) => v.isEnabled).toList();

    final vaultResults = <VaultCarryoverResult>[];
    double totalCarryover = 0;
    double totalTransferToSavings = 0;

    for (final vault in enabledVaults) {
      CarryoverConfig? config = await getConfig(vault.id);
      if (config == null && vault.type == VaultType.savings) {
        config = const CarryoverConfig(strategy: CarryoverStrategy.fullCarryover);
      }
      config ??= const CarryoverConfig();

      final previousBalance = vault.available;
      double carryoverAmount;
      double? transferToSavings;

      switch (config.strategy) {
        case CarryoverStrategy.reset:
          carryoverAmount = 0;
          break;
        case CarryoverStrategy.fullCarryover:
          carryoverAmount = previousBalance.clamp(0, config.maxCarryoverAmount);
          break;
        case CarryoverStrategy.partialCarryover:
          final percentage = config.carryoverPercentage ?? 0.5;
          carryoverAmount =
              (previousBalance * percentage).clamp(0, config.maxCarryoverAmount);
          break;
        case CarryoverStrategy.consolidateToSavings:
          carryoverAmount = 0;
          if (previousBalance > 0) {
            transferToSavings = previousBalance;
          }
          break;
      }

      vaultResults.add(VaultCarryoverResult(
        vaultId: vault.id,
        vaultName: vault.name,
        previousBalance: previousBalance,
        carryoverAmount: carryoverAmount,
        newBalance: carryoverAmount,
        transferToSavings: transferToSavings,
      ));

      totalCarryover += carryoverAmount;
      totalTransferToSavings += transferToSavings ?? 0;
    }

    return CarryoverResult(
      executedAt: DateTime.now(),
      periodFrom: periodFrom,
      periodTo: periodTo,
      vaultResults: vaultResults,
      totalCarryover: totalCarryover,
      totalTransferToSavings: totalTransferToSavings,
    );
  }

  // ==================== 结转历史 ====================

  /// 获取结转历史记录
  Future<List<CarryoverRecord>> getHistory({
    required String ledgerId,
    int? limit,
  }) async {
    final results = await _db.query(
      recordTableName,
      where: 'ledgerId = ?',
      whereArgs: [ledgerId],
      orderBy: 'executedAt DESC',
      limit: limit,
    );

    return results.map((m) => CarryoverRecord.fromMap(m)).toList();
  }

  /// 获取最近一次结转记录
  Future<CarryoverRecord?> getLastCarryover(String ledgerId) async {
    final results = await _db.query(
      recordTableName,
      where: 'ledgerId = ?',
      whereArgs: [ledgerId],
      orderBy: 'executedAt DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CarryoverRecord.fromMap(results.first);
  }

  /// 检查是否需要执行结转
  Future<bool> shouldExecuteCarryover(String ledgerId) async {
    final now = DateTime.now();
    final currentPeriod = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 检查本月是否已结转
    final existing = await _db.query(
      recordTableName,
      where: 'ledgerId = ? AND periodTo = ?',
      whereArgs: [ledgerId, currentPeriod],
      limit: 1,
    );

    if (existing.isNotEmpty) return false;

    // 检查是否有配置自动结转且到了执行日期
    final configs = await getAutoExecuteConfigs();
    for (final config in configs) {
      if (now.day >= (config['executeDayOfMonth'] as int? ?? 1)) {
        return true;
      }
    }

    return false;
  }

  // ==================== 周期管理 ====================

  /// 获取当前预算周期信息
  BudgetPeriod getCurrentPeriod() {
    final now = DateTime.now();
    return BudgetPeriod(
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
      label: '${now.year}年${now.month}月',
    );
  }

  /// 获取指定日期所在的预算周期
  BudgetPeriod getPeriodForDate(DateTime date) {
    return BudgetPeriod(
      startDate: DateTime(date.year, date.month, 1),
      endDate: DateTime(date.year, date.month + 1, 0),
      label: '${date.year}年${date.month}月',
    );
  }

  /// 获取剩余天数
  int getRemainingDays() {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    return endOfMonth.day - now.day;
  }

  /// 计算日均可用预算
  Future<double> getDailyBudget({required String ledgerId}) async {
    final summary = await _vaultRepository.getSummary(ledgerId: ledgerId);
    final remainingDays = getRemainingDays();

    if (remainingDays <= 0) return 0;
    return summary.totalAvailable / remainingDays;
  }

  /// 检查是否临近月末
  bool isNearMonthEnd({int daysThreshold = 5}) {
    return getRemainingDays() <= daysThreshold;
  }
}

/// 预算周期
class BudgetPeriod {
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const BudgetPeriod({
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  /// 周期天数
  int get totalDays => endDate.difference(startDate).inDays + 1;

  /// 已过去的天数
  int get elapsedDays {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0;
    if (now.isAfter(endDate)) return totalDays;
    return now.difference(startDate).inDays + 1;
  }

  /// 剩余天数
  int get remainingDays => totalDays - elapsedDays;

  /// 周期进度（0-1）
  double get progress => elapsedDays / totalDays;

  /// 是否是当前周期
  bool get isCurrent {
    final now = DateTime.now();
    return !now.isBefore(startDate) && !now.isAfter(endDate);
  }
}
