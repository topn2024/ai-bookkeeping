import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/budget_vault.dart';

/// 小金库数据仓库
///
/// 提供小金库的 CRUD 操作和统计查询功能
class VaultRepository {
  final Database _db;

  VaultRepository(this._db);

  /// 数据库表名
  static const String tableName = 'budget_vaults';
  static const String allocationTableName = 'vault_allocations';
  static const String transferTableName = 'vault_transfers';

  /// 创建数据库表
  static Future<void> createTables(Database db) async {
    // 小金库表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        type INTEGER NOT NULL,
        targetAmount REAL NOT NULL,
        allocatedAmount REAL DEFAULT 0,
        spentAmount REAL DEFAULT 0,
        dueDate INTEGER,
        isRecurring INTEGER DEFAULT 0,
        recurrenceJson TEXT,
        linkedCategoryId TEXT,
        linkedCategoryIds TEXT,
        ledgerId TEXT NOT NULL,
        isEnabled INTEGER DEFAULT 1,
        sortOrder INTEGER DEFAULT 0,
        allocationType INTEGER DEFAULT 0,
        targetAllocation REAL,
        targetPercentage REAL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // 分配记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $allocationTableName (
        id TEXT PRIMARY KEY,
        vaultId TEXT NOT NULL,
        incomeTransactionId TEXT,
        amount REAL NOT NULL,
        note TEXT,
        allocatedAt INTEGER NOT NULL,
        FOREIGN KEY (vaultId) REFERENCES $tableName(id) ON DELETE CASCADE
      )
    ''');

    // 调拨记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $transferTableName (
        id TEXT PRIMARY KEY,
        fromVaultId TEXT NOT NULL,
        toVaultId TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        transferredAt INTEGER NOT NULL,
        FOREIGN KEY (fromVaultId) REFERENCES $tableName(id) ON DELETE CASCADE,
        FOREIGN KEY (toVaultId) REFERENCES $tableName(id) ON DELETE CASCADE
      )
    ''');

    // 索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_vaults_ledger ON $tableName(ledgerId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_vaults_type ON $tableName(type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_allocations_vault ON $allocationTableName(vaultId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transfers_from ON $transferTableName(fromVaultId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transfers_to ON $transferTableName(toVaultId)');
  }

  // ==================== CRUD 操作 ====================

  /// 创建小金库
  Future<BudgetVault> create(BudgetVault vault) async {
    await _db.insert(tableName, vault.toMap());
    return vault;
  }

  /// 批量创建小金库
  Future<List<BudgetVault>> createBatch(List<BudgetVault> vaults) async {
    final batch = _db.batch();
    for (final vault in vaults) {
      batch.insert(tableName, vault.toMap());
    }
    await batch.commit(noResult: true);
    return vaults;
  }

  /// 获取单个小金库
  Future<BudgetVault?> getById(String id) async {
    final results = await _db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return BudgetVault.fromMap(results.first);
  }

  /// 获取账本下所有小金库
  Future<List<BudgetVault>> getByLedgerId(String ledgerId) async {
    final results = await _db.query(
      tableName,
      where: 'ledgerId = ?',
      whereArgs: [ledgerId],
      orderBy: 'sortOrder ASC, createdAt ASC',
    );

    return results.map((map) => BudgetVault.fromMap(map)).toList();
  }

  /// 获取所有小金库
  Future<List<BudgetVault>> getAll() async {
    final results = await _db.query(
      tableName,
      orderBy: 'sortOrder ASC, createdAt ASC',
    );

    return results.map((map) => BudgetVault.fromMap(map)).toList();
  }

  /// 获取启用的小金库
  Future<List<BudgetVault>> getEnabled({String? ledgerId}) async {
    String where = 'isEnabled = 1';
    List<dynamic> whereArgs = [];

    if (ledgerId != null) {
      where += ' AND ledgerId = ?';
      whereArgs.add(ledgerId);
    }

    final results = await _db.query(
      tableName,
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'sortOrder ASC',
    );

    return results.map((map) => BudgetVault.fromMap(map)).toList();
  }

  /// 按类型获取小金库
  Future<List<BudgetVault>> getByType(VaultType type, {String? ledgerId}) async {
    String where = 'type = ?';
    List<dynamic> whereArgs = [type.index];

    if (ledgerId != null) {
      where += ' AND ledgerId = ?';
      whereArgs.add(ledgerId);
    }

    final results = await _db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sortOrder ASC',
    );

    return results.map((map) => BudgetVault.fromMap(map)).toList();
  }

  /// 更新小金库
  Future<BudgetVault> update(BudgetVault vault) async {
    final updatedVault = vault.copyWith(updatedAt: DateTime.now());
    await _db.update(
      tableName,
      updatedVault.toMap(),
      where: 'id = ?',
      whereArgs: [vault.id],
    );
    return updatedVault;
  }

  /// 更新分配金额
  Future<void> updateAllocatedAmount(String vaultId, double amount) async {
    await _db.rawUpdate('''
      UPDATE $tableName
      SET allocatedAmount = allocatedAmount + ?, updatedAt = ?
      WHERE id = ?
    ''', [amount, DateTime.now().millisecondsSinceEpoch, vaultId]);
  }

  /// 更新花费金额
  Future<void> updateSpentAmount(String vaultId, double amount) async {
    await _db.rawUpdate('''
      UPDATE $tableName
      SET spentAmount = spentAmount + ?, updatedAt = ?
      WHERE id = ?
    ''', [amount, DateTime.now().millisecondsSinceEpoch, vaultId]);
  }

  /// 重置分配和花费金额（用于周期结转）
  Future<void> resetAmounts(String vaultId, {
    double? newAllocatedAmount,
    double? newSpentAmount,
  }) async {
    await _db.update(
      tableName,
      {
        'allocatedAmount': newAllocatedAmount ?? 0,
        'spentAmount': newSpentAmount ?? 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [vaultId],
    );
  }

  /// 删除小金库
  Future<void> delete(String id) async {
    await _db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 批量删除小金库
  Future<void> deleteBatch(List<String> ids) async {
    if (ids.isEmpty) return;

    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.delete(
      tableName,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// 更新排序顺序
  Future<void> updateSortOrder(List<String> vaultIds) async {
    final batch = _db.batch();
    for (var i = 0; i < vaultIds.length; i++) {
      batch.update(
        tableName,
        {'sortOrder': i, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [vaultIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 切换启用状态
  Future<void> toggleEnabled(String vaultId, bool enabled) async {
    await _db.update(
      tableName,
      {
        'isEnabled': enabled ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [vaultId],
    );
  }

  // ==================== 分配记录操作 ====================

  /// 记录分配历史
  Future<VaultAllocation> recordAllocation(VaultAllocation allocation) async {
    await _db.insert(allocationTableName, allocation.toMap());
    return allocation;
  }

  /// 获取小金库的分配历史
  Future<List<VaultAllocation>> getAllocationHistory(
    String vaultId, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    String where = 'vaultId = ?';
    List<dynamic> whereArgs = [vaultId];

    if (startDate != null) {
      where += ' AND allocatedAt >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND allocatedAt <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final results = await _db.query(
      allocationTableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'allocatedAt DESC',
      limit: limit,
    );

    return results.map((map) => VaultAllocation.fromMap(map)).toList();
  }

  /// 删除分配记录（用于撤销分配）
  Future<void> deleteAllocation(String allocationId) async {
    await _db.delete(
      allocationTableName,
      where: 'id = ?',
      whereArgs: [allocationId],
    );
  }

  // ==================== 调拨记录操作 ====================

  /// 记录调拨
  Future<VaultTransfer> recordTransfer(VaultTransfer transfer) async {
    await _db.insert(transferTableName, transfer.toMap());

    // 更新源小金库（减少）
    await updateAllocatedAmount(transfer.fromVaultId, -transfer.amount);

    // 更新目标小金库（增加）
    await updateAllocatedAmount(transfer.toVaultId, transfer.amount);

    return transfer;
  }

  /// 获取调拨历史
  Future<List<VaultTransfer>> getTransferHistory({
    String? vaultId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    String? where;
    List<dynamic>? whereArgs;

    if (vaultId != null) {
      where = 'fromVaultId = ? OR toVaultId = ?';
      whereArgs = [vaultId, vaultId];
    }

    if (startDate != null) {
      final condition = 'transferredAt >= ?';
      where = where != null ? '$where AND $condition' : condition;
      whereArgs ??= [];
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      final condition = 'transferredAt <= ?';
      where = where != null ? '$where AND $condition' : condition;
      whereArgs ??= [];
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final results = await _db.query(
      transferTableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'transferredAt DESC',
      limit: limit,
    );

    return results.map((map) => VaultTransfer.fromMap(map)).toList();
  }

  // ==================== 统计查询 ====================

  /// 获取总分配金额
  Future<double> getTotalAllocated({String? ledgerId}) async {
    String sql = 'SELECT SUM(allocatedAmount) as total FROM $tableName WHERE isEnabled = 1';
    List<dynamic>? args;

    if (ledgerId != null) {
      sql += ' AND ledgerId = ?';
      args = [ledgerId];
    }

    final result = await _db.rawQuery(sql, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// 获取总花费金额
  Future<double> getTotalSpent({String? ledgerId}) async {
    String sql = 'SELECT SUM(spentAmount) as total FROM $tableName WHERE isEnabled = 1';
    List<dynamic>? args;

    if (ledgerId != null) {
      sql += ' AND ledgerId = ?';
      args = [ledgerId];
    }

    final result = await _db.rawQuery(sql, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// 获取总可用金额
  Future<double> getTotalAvailable({String? ledgerId}) async {
    String sql = '''
      SELECT SUM(allocatedAmount - spentAmount) as total
      FROM $tableName
      WHERE isEnabled = 1
    ''';
    List<dynamic>? args;

    if (ledgerId != null) {
      sql += ' AND ledgerId = ?';
      args = [ledgerId];
    }

    final result = await _db.rawQuery(sql, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// 获取小金库统计摘要
  Future<VaultSummary> getSummary({String? ledgerId}) async {
    final vaults = ledgerId != null
        ? await getByLedgerId(ledgerId)
        : await getAll();

    final enabledVaults = vaults.where((v) => v.isEnabled).toList();

    // 按类型统计
    final allocationByType = <VaultType, double>{};
    final spentByType = <VaultType, double>{};

    int healthyCount = 0;
    int underfundedCount = 0;
    int almostEmptyCount = 0;
    int overSpentCount = 0;

    for (final vault in enabledVaults) {
      // 类型统计
      allocationByType[vault.type] =
          (allocationByType[vault.type] ?? 0) + vault.allocatedAmount;
      spentByType[vault.type] =
          (spentByType[vault.type] ?? 0) + vault.spentAmount;

      // 状态统计
      switch (vault.status) {
        case VaultStatus.healthy:
          healthyCount++;
          break;
        case VaultStatus.underfunded:
          underfundedCount++;
          break;
        case VaultStatus.almostEmpty:
          almostEmptyCount++;
          break;
        case VaultStatus.overSpent:
          overSpentCount++;
          break;
      }
    }

    return VaultSummary(
      totalVaults: enabledVaults.length,
      totalAllocated: enabledVaults.fold(0, (sum, v) => sum + v.allocatedAmount),
      totalSpent: enabledVaults.fold(0, (sum, v) => sum + v.spentAmount),
      totalAvailable: enabledVaults.fold(0, (sum, v) => sum + v.available),
      healthyCount: healthyCount,
      underfundedCount: underfundedCount,
      almostEmptyCount: almostEmptyCount,
      overSpentCount: overSpentCount,
      allocationByType: allocationByType,
      spentByType: spentByType,
    );
  }

  /// 获取超支的小金库
  Future<List<BudgetVault>> getOverspentVaults({String? ledgerId}) async {
    final vaults = ledgerId != null
        ? await getByLedgerId(ledgerId)
        : await getAll();

    return vaults.where((v) => v.isEnabled && v.isOverSpent).toList();
  }

  /// 获取即将用完的小金库（使用率>80%）
  Future<List<BudgetVault>> getAlmostEmptyVaults({String? ledgerId}) async {
    final vaults = ledgerId != null
        ? await getByLedgerId(ledgerId)
        : await getAll();

    return vaults.where((v) => v.isEnabled && v.isAlmostEmpty).toList();
  }

  /// 获取即将到期的小金库
  Future<List<BudgetVault>> getDueSoonVaults({
    String? ledgerId,
    int daysThreshold = 3,
  }) async {
    final vaults = ledgerId != null
        ? await getByLedgerId(ledgerId)
        : await getAll();

    return vaults.where((v) {
      if (!v.isEnabled || v.dueDate == null) return false;
      final daysUntilDue = v.daysUntilDue;
      return daysUntilDue != null && daysUntilDue >= 0 && daysUntilDue <= daysThreshold;
    }).toList();
  }

  /// 获取关联指定分类的小金库
  Future<BudgetVault?> getByLinkedCategory(String categoryId) async {
    // 首先检查单一关联
    var results = await _db.query(
      tableName,
      where: 'linkedCategoryId = ? AND isEnabled = 1',
      whereArgs: [categoryId],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return BudgetVault.fromMap(results.first);
    }

    // 检查多重关联
    results = await _db.query(
      tableName,
      where: 'linkedCategoryIds LIKE ? AND isEnabled = 1',
      whereArgs: ['%$categoryId%'],
    );

    for (final map in results) {
      final vault = BudgetVault.fromMap(map);
      if (vault.linkedCategoryIds?.contains(categoryId) == true) {
        return vault;
      }
    }

    return null;
  }

  /// 搜索小金库
  Future<List<BudgetVault>> search(String query, {String? ledgerId}) async {
    String where = '(name LIKE ? OR description LIKE ?)';
    List<dynamic> whereArgs = ['%$query%', '%$query%'];

    if (ledgerId != null) {
      where += ' AND ledgerId = ?';
      whereArgs.add(ledgerId);
    }

    final results = await _db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sortOrder ASC',
    );

    return results.map((map) => BudgetVault.fromMap(map)).toList();
  }

  /// 获取本月分配总额
  Future<double> getMonthlyAllocationTotal({
    String? ledgerId,
    DateTime? month,
  }) async {
    final targetMonth = month ?? DateTime.now();
    final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

    String sql = '''
      SELECT SUM(amount) as total
      FROM $allocationTableName a
      JOIN $tableName v ON a.vaultId = v.id
      WHERE a.allocatedAt >= ? AND a.allocatedAt <= ?
    ''';
    List<dynamic> args = [
      startOfMonth.millisecondsSinceEpoch,
      endOfMonth.millisecondsSinceEpoch,
    ];

    if (ledgerId != null) {
      sql += ' AND v.ledgerId = ?';
      args.add(ledgerId);
    }

    final result = await _db.rawQuery(sql, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// 检查小金库名称是否重复
  Future<bool> isNameDuplicate(String name, String ledgerId, {String? excludeId}) async {
    String where = 'name = ? AND ledgerId = ?';
    List<dynamic> whereArgs = [name, ledgerId];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final count = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM $tableName WHERE $where',
      whereArgs,
    ));

    return (count ?? 0) > 0;
  }

  /// 从模板创建小金库
  Future<BudgetVault> createFromTemplate(
    Map<String, dynamic> template, {
    required String ledgerId,
    required double targetAmount,
    String? id,
  }) async {
    final vault = BudgetVault(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: template['name'] as String,
      description: template['description'] as String?,
      icon: template['icon'] as IconData,
      color: template['color'] as Color,
      type: template['type'] as VaultType,
      targetAmount: targetAmount,
      ledgerId: ledgerId,
    );

    return create(vault);
  }
}
