/// Ledger Repository Implementation
///
/// 实现 ILedgerRepository 接口，封装账本相关的数据库操作。
library;

import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../../models/ledger.dart';
import '../../../domain/repositories/i_ledger_repository.dart';

/// 账本仓库实现
class LedgerRepository implements ILedgerRepository {
  final Future<Database> Function() _databaseProvider;

  LedgerRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  // ==================== IRepository 基础实现 ====================

  @override
  Future<Ledger?> findById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'ledgers',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Ledger.fromMap(maps.first);
  }

  @override
  Future<List<Ledger>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query(
      'ledgers',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Ledger.fromMap(m)).toList();
  }

  @override
  Future<int> insert(Ledger entity) async {
    debugPrint('[LedgerRepository] 插入账本: id=${entity.id}, name=${entity.name}');
    final db = await _db;
    return await db.insert('ledgers', entity.toMap());
  }

  @override
  Future<void> insertAll(List<Ledger> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final entity in entities) {
      batch.insert('ledgers', entity.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(Ledger entity) async {
    final db = await _db;
    return await db.update(
      'ledgers',
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'ledgers',
      {'isDeleted': 1, 'deletedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update(
      'ledgers',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ledgers WHERE id = ?',
      [id],
    );
    return (result.first['count'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ledgers WHERE isDeleted = 0',
    );
    return result.first['count'] as int;
  }

  // ==================== ILedgerRepository 特定实现 ====================

  @override
  Future<Ledger?> findDefault() async {
    final db = await _db;
    final maps = await db.query(
      'ledgers',
      where: 'isDefault = 1 AND isDeleted = 0',
      limit: 1,
    );
    if (maps.isEmpty) {
      // 如果没有默认账本，返回第一个
      final allMaps = await db.query(
        'ledgers',
        where: 'isDeleted = 0',
        orderBy: 'createdAt ASC',
        limit: 1,
      );
      if (allMaps.isEmpty) return null;
      return Ledger.fromMap(allMaps.first);
    }
    return Ledger.fromMap(maps.first);
  }

  @override
  Future<int> setDefault(String id) async {
    final db = await _db;
    // 先清除所有默认标记
    await db.update('ledgers', {'isDefault': 0});
    // 设置新的默认账本
    return await db.update(
      'ledgers',
      {'isDefault': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Ledger>> findByType(LedgerType type) async {
    final db = await _db;
    final maps = await db.query(
      'ledgers',
      where: 'type = ? AND isDeleted = 0',
      whereArgs: [type.index],
    );
    return maps.map((m) => Ledger.fromMap(m)).toList();
  }

  @override
  Future<List<Ledger>> findAccessible(String userId) async {
    // 返回用户有权访问的账本（自己创建的 + 被邀请的）
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT l.* FROM ledgers l
      LEFT JOIN ledger_members m ON l.id = m.ledgerId
      WHERE (l.ownerId = ? OR m.userId = ?) AND l.isDeleted = 0
      GROUP BY l.id
      ORDER BY l.createdAt DESC
    ''', [userId, userId]);
    return maps.map((m) => Ledger.fromMap(m)).toList();
  }

  @override
  Future<List<Ledger>> findByOwner(String ownerId) async {
    final db = await _db;
    final maps = await db.query(
      'ledgers',
      where: 'ownerId = ? AND isDeleted = 0',
      whereArgs: [ownerId],
    );
    return maps.map((m) => Ledger.fromMap(m)).toList();
  }

  @override
  Future<List<Ledger>> findShared() async {
    final db = await _db;
    // 查找所有非个人类型的账本（家庭、情侣、群组、专项）
    final maps = await db.query(
      'ledgers',
      where: 'type != ? AND isDeleted = 0',
      whereArgs: [LedgerType.personal.index],
    );
    return maps.map((m) => Ledger.fromMap(m)).toList();
  }

  @override
  Future<bool> hasAccess(String ledgerId, String userId) async {
    final db = await _db;
    // 检查是否是所有者
    final ownerResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ledgers WHERE id = ? AND ownerId = ?',
      [ledgerId, userId],
    );
    if ((ownerResult.first['count'] as int) > 0) return true;

    // 检查是否是成员
    final memberResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ledger_members WHERE ledgerId = ? AND userId = ?',
      [ledgerId, userId],
    );
    return (memberResult.first['count'] as int) > 0;
  }

  @override
  Future<int> getMemberCount(String ledgerId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ledger_members WHERE ledgerId = ?',
      [ledgerId],
    );
    // +1 for the owner
    return (result.first['count'] as int) + 1;
  }
}
