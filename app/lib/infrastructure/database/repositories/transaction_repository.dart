/// Transaction Repository Implementation
///
/// 实现 ITransactionRepository 接口，封装交易相关的数据库操作。
/// 依赖 sqflite Database 实例进行实际的数据访问。
library;

import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../../models/transaction.dart' as model;
import '../../../models/transaction_split.dart';
import '../../../models/transaction_location.dart';
import '../../../domain/repositories/i_transaction_repository.dart';

/// 交易仓库实现
///
/// 封装所有交易相关的数据库操作，遵循单一职责原则。
/// 使用依赖注入接收 Database 实例，便于测试和解耦。
class TransactionRepository implements ITransactionRepository {
  final Future<Database> Function() _databaseProvider;

  /// 创建交易仓库
  ///
  /// [databaseProvider] 提供 Database 实例的函数
  TransactionRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  // ==================== IRepository 基础实现 ====================

  @override
  Future<model.Transaction?> findById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _mapToTransaction(maps.first);
  }

  @override
  Future<List<model.Transaction>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'date DESC',
    );

    return Future.wait(maps.map(_mapToTransaction));
  }

  @override
  Future<int> insert(model.Transaction entity) async {
    debugPrint('[TransactionRepository] 插入交易: id=${entity.id}, amount=${entity.amount}');
    final db = await _db;
    final result = await db.insert('transactions', _transactionToMap(entity));

    // 插入拆分项
    if (entity.isSplit && entity.splits != null) {
      for (final split in entity.splits!) {
        await _insertSplit(split);
      }
    }

    return result;
  }

  @override
  Future<void> insertAll(List<model.Transaction> entities) async {
    final db = await _db;
    final batch = db.batch();

    for (final entity in entities) {
      batch.insert('transactions', _transactionToMap(entity));
      if (entity.isSplit && entity.splits != null) {
        for (final split in entity.splits!) {
          batch.insert('transaction_splits', _splitToMap(split));
        }
      }
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(model.Transaction entity) async {
    final db = await _db;
    final result = await db.update(
      'transactions',
      _transactionToMap(entity, isUpdate: true),
      where: 'id = ?',
      whereArgs: [entity.id],
    );

    // 更新拆分项：先删除旧的，再插入新的
    await _deleteSplits(entity.id);
    if (entity.isSplit && entity.splits != null) {
      for (final split in entity.splits!) {
        await _insertSplit(split);
      }
    }

    return result;
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    // 拆分项会通过 CASCADE 自动删除
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'transactions',
      {'isDeleted': 1, 'deletedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update(
      'transactions',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE id = ?',
      [id],
    );
    return (result.first['count'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE isDeleted = 0',
    );
    return result.first['count'] as int;
  }

  // ==================== IDateRangeRepository 实现 ====================

  @override
  Future<List<model.Transaction>> findByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ? AND isDeleted = 0',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );

    return Future.wait(maps.map(_mapToTransaction));
  }

  // ==================== ITransactionRepository 特定实现 ====================

  @override
  Future<List<model.Transaction>> query(TransactionQueryParams params) async {
    final db = await _db;
    final whereConditions = <String>['isDeleted = 0'];
    final whereArgs = <dynamic>[];

    if (params.startDate != null) {
      whereConditions.add('date >= ?');
      whereArgs.add(params.startDate!.millisecondsSinceEpoch);
    }
    if (params.endDate != null) {
      whereConditions.add('date <= ?');
      whereArgs.add(params.endDate!.millisecondsSinceEpoch);
    }
    if (params.category != null) {
      whereConditions.add('category = ?');
      whereArgs.add(params.category);
    }
    if (params.accountId != null) {
      whereConditions.add('accountId = ?');
      whereArgs.add(params.accountId);
    }
    if (params.type != null) {
      whereConditions.add('type = ?');
      whereArgs.add(params.type!.index);
    }
    if (params.minAmount != null) {
      whereConditions.add('amount >= ?');
      whereArgs.add(params.minAmount);
    }
    if (params.maxAmount != null) {
      whereConditions.add('amount <= ?');
      whereArgs.add(params.maxAmount);
    }
    if (params.source != null) {
      whereConditions.add('source = ?');
      whereArgs.add(params.source!.index);
    }
    if (params.vaultId != null) {
      whereConditions.add('vaultId = ?');
      whereArgs.add(params.vaultId);
    }
    if (params.importBatchId != null) {
      whereConditions.add('importBatchId = ?');
      whereArgs.add(params.importBatchId);
    }

    final maps = await db.query(
      'transactions',
      where: whereConditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: params.limit,
      offset: params.offset,
    );

    return Future.wait(maps.map(_mapToTransaction));
  }

  @override
  Future<model.Transaction?> findFirst() async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'isDeleted = 0',
      orderBy: 'date ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _mapToTransaction(maps.first);
  }

  @override
  Future<List<model.Transaction>> findByAccountId(String accountId) async {
    return query(TransactionQueryParams.byAccount(accountId));
  }

  @override
  Future<List<model.Transaction>> findByCategory(String category) async {
    return query(TransactionQueryParams.byCategory(category));
  }

  @override
  Future<List<model.Transaction>> findByType(model.TransactionType type) async {
    return query(TransactionQueryParams(type: type));
  }

  @override
  Future<List<model.Transaction>> findBySource(model.TransactionSource source) async {
    return query(TransactionQueryParams(source: source));
  }

  @override
  Future<List<model.Transaction>> findByVaultId(String vaultId) async {
    return query(TransactionQueryParams(vaultId: vaultId));
  }

  @override
  Future<List<model.Transaction>> findByResourcePoolId(String resourcePoolId) async {
    return query(TransactionQueryParams(resourcePoolId: resourcePoolId));
  }

  @override
  Future<List<model.Transaction>> findByImportBatchId(String batchId) async {
    return query(TransactionQueryParams(importBatchId: batchId));
  }

  @override
  Future<model.Transaction?> findByExternalId(
    String externalId,
    model.ExternalSource source,
  ) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'externalId = ? AND externalSource = ? AND isDeleted = 0',
      whereArgs: [externalId, source.index],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _mapToTransaction(maps.first);
  }

  @override
  Future<List<model.Transaction>> findPotentialDuplicates({
    required double amount,
    required DateTime date,
    String? note,
    Duration tolerance = const Duration(days: 1),
  }) async {
    final db = await _db;
    final startTime = date.subtract(tolerance).millisecondsSinceEpoch;
    final endTime = date.add(tolerance).millisecondsSinceEpoch;

    final maps = await db.query(
      'transactions',
      where: 'amount = ? AND date >= ? AND date <= ? AND isDeleted = 0',
      whereArgs: [amount, startTime, endTime],
    );

    return Future.wait(maps.map(_mapToTransaction));
  }

  @override
  Future<TransactionStatistics> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
  }) async {
    final db = await _db;
    final whereConditions = <String>['isDeleted = 0'];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereConditions.add('date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereConditions.add('date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }
    if (accountId != null) {
      whereConditions.add('accountId = ?');
      whereArgs.add(accountId);
    }

    final whereClause = whereConditions.join(' AND ');

    // 获取总支出
    final expenseResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE $whereClause AND type = ?',
      [...whereArgs, model.TransactionType.expense.index],
    );
    final totalExpense = (expenseResult.first['total'] as num).toDouble();

    // 获取总收入
    final incomeResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE $whereClause AND type = ?',
      [...whereArgs, model.TransactionType.income.index],
    );
    final totalIncome = (incomeResult.first['total'] as num).toDouble();

    // 获取交易数量
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE $whereClause',
      whereArgs,
    );
    final count = countResult.first['count'] as int;

    return TransactionStatistics(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      netAmount: totalIncome - totalExpense,
      count: count,
    );
  }

  @override
  Future<Map<String, TransactionStatistics>> getMonthlyStatistics({
    required int year,
    String? accountId,
  }) async {
    final result = <String, TransactionStatistics>{};

    for (int month = 1; month <= 12; month++) {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      final stats = await getStatistics(
        startDate: startDate,
        endDate: endDate,
        accountId: accountId,
      );

      final key = '$year-${month.toString().padLeft(2, '0')}';
      result[key] = stats;
    }

    return result;
  }

  @override
  Future<List<model.Transaction>> findReimbursable() async {
    return query(TransactionQueryParams(isReimbursable: true, isReimbursed: false));
  }

  @override
  Future<List<model.Transaction>> findReimbursed() async {
    return query(TransactionQueryParams(isReimbursed: true));
  }

  @override
  Future<int> markAsReimbursed(String id) async {
    final db = await _db;
    return await db.update(
      'transactions',
      {'isReimbursed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<model.Transaction>> findByMemberId(String memberId) async {
    final db = await _db;
    final maps = await db.query(
      'transactions',
      where: 'createdBy = ? AND isDeleted = 0',
      whereArgs: [memberId],
      orderBy: 'date DESC',
    );
    return Future.wait(maps.map(_mapToTransaction));
  }

  // ==================== 私有辅助方法 ====================

  /// 将数据库 Map 转换为 Transaction 对象
  Future<model.Transaction> _mapToTransaction(Map<String, dynamic> map) async {
    final isSplit = (map['isSplit'] as int?) == 1;
    List<TransactionSplit>? splits;

    if (isSplit) {
      splits = await _getSplits(map['id'] as String);
    }

    final tagsString = map['tags'] as String?;
    final sourceFileExpiresAtMs = map['sourceFileExpiresAt'] as int?;

    return model.Transaction(
      id: map['id'] as String,
      type: model.TransactionType.values[map['type'] as int],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      accountId: map['accountId'] as String,
      toAccountId: map['toAccountId'] as String?,
      isSplit: isSplit,
      splits: splits,
      isReimbursable: (map['isReimbursable'] as int?) == 1,
      isReimbursed: (map['isReimbursed'] as int?) == 1,
      tags: tagsString != null && tagsString.isNotEmpty
          ? tagsString.split(',')
          : null,
      source: model.TransactionSource.values[(map['source'] as int?) ?? 0],
      aiConfidence: (map['aiConfidence'] as num?)?.toDouble(),
      sourceFileLocalPath: map['sourceFileLocalPath'] as String?,
      sourceFileServerUrl: map['sourceFileServerUrl'] as String?,
      sourceFileType: map['sourceFileType'] as String?,
      sourceFileSize: map['sourceFileSize'] as int?,
      recognitionRawData: map['recognitionRawData'] as String?,
      sourceFileExpiresAt: sourceFileExpiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(sourceFileExpiresAtMs)
          : null,
      externalId: map['externalId'] as String?,
      externalSource: map['externalSource'] != null
          ? model.ExternalSource.values[map['externalSource'] as int]
          : null,
      importBatchId: map['importBatchId'] as String?,
      rawMerchant: map['rawMerchant'] as String?,
      vaultId: map['vaultId'] as String?,
      moneyAge: map['moneyAge'] as int?,
      moneyAgeLevel: map['moneyAgeLevel'] as String?,
      resourcePoolId: map['resourcePoolId'] as String?,
      visibility: (map['visibility'] as int?) ?? 1,
      location: _parseLocationJson(map['locationJson'] as String?),
    );
  }

  /// 将 Transaction 对象转换为数据库 Map
  Map<String, dynamic> _transactionToMap(model.Transaction t, {bool isUpdate = false}) {
    final map = <String, dynamic>{
      'type': t.type.index,
      'amount': t.amount,
      'category': t.category,
      'note': t.note,
      'date': t.date.millisecondsSinceEpoch,
      'accountId': t.accountId,
      'toAccountId': t.toAccountId,
      'isSplit': t.isSplit ? 1 : 0,
      'isReimbursable': t.isReimbursable ? 1 : 0,
      'isReimbursed': t.isReimbursed ? 1 : 0,
      'tags': t.tags?.join(','),
      'source': t.source.index,
      'aiConfidence': t.aiConfidence,
      'sourceFileLocalPath': t.sourceFileLocalPath,
      'sourceFileServerUrl': t.sourceFileServerUrl,
      'sourceFileType': t.sourceFileType,
      'sourceFileSize': t.sourceFileSize,
      'recognitionRawData': t.recognitionRawData,
      'sourceFileExpiresAt': t.sourceFileExpiresAt?.millisecondsSinceEpoch,
      'externalId': t.externalId,
      'externalSource': t.externalSource?.index,
      'importBatchId': t.importBatchId,
      'rawMerchant': t.rawMerchant,
      'vaultId': t.vaultId,
      'moneyAge': t.moneyAge,
      'moneyAgeLevel': t.moneyAgeLevel,
      'resourcePoolId': t.resourcePoolId,
      'visibility': t.visibility,
      'locationJson': t.location != null
          ? '${t.location!.latitude},${t.location!.longitude},${t.location!.placeName ?? ''},${t.location!.address ?? ''}'
          : null,
    };

    if (!isUpdate) {
      map['id'] = t.id;
      map['ledgerId'] = 'default';
      map['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    }

    return map;
  }

  /// 解析位置 JSON 字符串
  TransactionLocation? _parseLocationJson(String? locationJson) {
    if (locationJson == null || locationJson.isEmpty) return null;
    final parts = locationJson.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return TransactionLocation(
      latitude: lat,
      longitude: lng,
      placeName: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      address: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
    );
  }

  /// 获取交易的拆分项
  Future<List<TransactionSplit>> _getSplits(String transactionId) async {
    final db = await _db;
    final maps = await db.query(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );

    return maps.map((map) => TransactionSplit(
      id: map['id'] as String,
      transactionId: map['transactionId'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
    )).toList();
  }

  /// 插入拆分项
  Future<int> _insertSplit(TransactionSplit split) async {
    final db = await _db;
    return await db.insert('transaction_splits', _splitToMap(split));
  }

  /// 删除交易的所有拆分项
  Future<int> _deleteSplits(String transactionId) async {
    final db = await _db;
    return await db.delete(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
  }

  /// 将 TransactionSplit 转换为数据库 Map
  Map<String, dynamic> _splitToMap(TransactionSplit split) {
    return {
      'id': split.id,
      'transactionId': split.transactionId,
      'category': split.category,
      'amount': split.amount,
      'note': split.note,
    };
  }
}
