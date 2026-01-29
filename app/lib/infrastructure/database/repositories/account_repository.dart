/// Account Repository Implementation
///
/// 实现 IAccountRepository 接口，封装账户相关的数据库操作。
library;

import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../../models/account.dart';
import '../../../domain/repositories/i_account_repository.dart';

/// 账户仓库实现
class AccountRepository implements IAccountRepository {
  final Future<Database> Function() _databaseProvider;

  AccountRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  // ==================== IRepository 基础实现 ====================

  @override
  Future<Account?> findById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'accounts',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  @override
  Future<List<Account>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query(
      'accounts',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'sortOrder ASC, createdAt DESC',
    );
    return maps.map((m) => Account.fromMap(m)).toList();
  }

  @override
  Future<int> insert(Account entity) async {
    debugPrint('[AccountRepository] 插入账户: id=${entity.id}, name=${entity.name}');
    final db = await _db;
    return await db.insert('accounts', entity.toMap());
  }

  @override
  Future<void> insertAll(List<Account> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final entity in entities) {
      batch.insert('accounts', entity.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(Account entity) async {
    final db = await _db;
    return await db.update(
      'accounts',
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'accounts',
      {'isDeleted': 1, 'deletedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update(
      'accounts',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM accounts WHERE id = ?',
      [id],
    );
    return (result.first['count'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM accounts WHERE isDeleted = 0',
    );
    return result.first['count'] as int;
  }

  // ==================== IAccountRepository 特定实现 ====================

  @override
  Future<Account?> findDefault() async {
    final db = await _db;
    final maps = await db.query(
      'accounts',
      where: 'isDefault = 1 AND isDeleted = 0',
      limit: 1,
    );
    if (maps.isEmpty) {
      // 如果没有默认账户，返回第一个账户
      final allMaps = await db.query(
        'accounts',
        where: 'isDeleted = 0',
        orderBy: 'createdAt ASC',
        limit: 1,
      );
      if (allMaps.isEmpty) return null;
      return Account.fromMap(allMaps.first);
    }
    return Account.fromMap(maps.first);
  }

  @override
  Future<int> setDefault(String id) async {
    final db = await _db;
    // 先清除所有默认标记
    await db.update('accounts', {'isDefault': 0});
    // 设置新的默认账户
    return await db.update(
      'accounts',
      {'isDefault': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Account>> findByType(AccountType type) async {
    final db = await _db;
    final maps = await db.query(
      'accounts',
      where: 'type = ? AND isDeleted = 0',
      whereArgs: [type.index],
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Account.fromMap(m)).toList();
  }

  @override
  Future<List<Account>> findActive() async {
    final db = await _db;
    final maps = await db.query(
      'accounts',
      where: 'isActive = 1 AND isDeleted = 0',
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Account.fromMap(m)).toList();
  }

  @override
  Future<List<Account>> findCustom() async {
    final db = await _db;
    final maps = await db.query(
      'accounts',
      where: 'isSystem = 0 AND isDeleted = 0',
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Account.fromMap(m)).toList();
  }

  @override
  Future<int> updateBalance(String id, double newBalance) async {
    final db = await _db;
    return await db.update(
      'accounts',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> increaseBalance(String id, double amount) async {
    final db = await _db;
    return await db.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [amount, id],
    );
  }

  @override
  Future<int> decreaseBalance(String id, double amount) async {
    final db = await _db;
    return await db.rawUpdate(
      'UPDATE accounts SET balance = balance - ? WHERE id = ?',
      [amount, id],
    );
  }

  @override
  Future<void> transfer(String fromId, String toId, double amount) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [amount, fromId],
      );
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [amount, toId],
      );
    });
  }

  @override
  Future<double> getTotalBalance() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) as total FROM accounts WHERE isDeleted = 0',
    );
    return (result.first['total'] as num).toDouble();
  }

  @override
  Future<Map<AccountType, double>> getTotalBalanceByType() async {
    final db = await _db;
    final result = <AccountType, double>{};

    for (final type in AccountType.values) {
      final query = await db.rawQuery(
        'SELECT COALESCE(SUM(balance), 0) as total FROM accounts WHERE type = ? AND isDeleted = 0',
        [type.index],
      );
      result[type] = (query.first['total'] as num).toDouble();
    }

    return result;
  }
}
