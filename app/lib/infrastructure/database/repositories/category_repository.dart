/// Category Repository Implementation
///
/// 实现 ICategoryRepository 接口，封装分类相关的数据库操作。
library;

import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../../models/category.dart';
import '../../../domain/repositories/i_category_repository.dart';

/// 分类仓库实现
class CategoryRepository implements ICategoryRepository {
  final Future<Database> Function() _databaseProvider;

  CategoryRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  // ==================== IRepository 基础实现 ====================

  @override
  Future<Category?> findById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'categories',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  @override
  Future<List<Category>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query(
      'categories',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'sortOrder ASC, name ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  @override
  Future<int> insert(Category entity) async {
    debugPrint('[CategoryRepository] 插入分类: id=${entity.id}, name=${entity.name}');
    final db = await _db;
    return await db.insert('categories', entity.toMap());
  }

  @override
  Future<void> insertAll(List<Category> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final entity in entities) {
      batch.insert('categories', entity.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(Category entity) async {
    final db = await _db;
    return await db.update(
      'categories',
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'categories',
      {'isDeleted': 1, 'deletedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update(
      'categories',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM categories WHERE id = ?',
      [id],
    );
    return (result.first['count'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM categories WHERE isDeleted = 0',
    );
    return result.first['count'] as int;
  }

  // ==================== ICategoryRepository 特定实现 ====================

  @override
  Future<List<Category>> findExpenseCategories() async {
    final db = await _db;
    final maps = await db.query(
      'categories',
      where: 'isExpense = 1 AND isDeleted = 0',
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  @override
  Future<List<Category>> findIncomeCategories() async {
    final db = await _db;
    final maps = await db.query(
      'categories',
      where: 'isExpense = 0 AND isDeleted = 0',
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  @override
  Future<List<Category>> findRootCategories({bool? isExpense}) async {
    final db = await _db;
    String where = 'parentId IS NULL AND isDeleted = 0';
    List<dynamic>? whereArgs;

    if (isExpense != null) {
      where += ' AND isExpense = ?';
      whereArgs = [isExpense ? 1 : 0];
    }

    final maps = await db.query(
      'categories',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  @override
  Future<List<Category>> findByParentId(String parentId) async {
    final db = await _db;
    final maps = await db.query(
      'categories',
      where: 'parentId = ? AND isDeleted = 0',
      whereArgs: [parentId],
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  @override
  Future<List<Category>> findCustomCategories() async {
    final db = await _db;
    final maps = await db.query(
      'categories',
      where: 'isSystem = 0 AND isDeleted = 0',
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  @override
  Future<Category?> findByName(String name, {bool? isExpense}) async {
    final db = await _db;
    String where = 'name = ? AND isDeleted = 0';
    List<dynamic> whereArgs = [name];

    if (isExpense != null) {
      where += ' AND isExpense = ?';
      whereArgs.add(isExpense ? 1 : 0);
    }

    final maps = await db.query(
      'categories',
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  @override
  Future<void> updateSortOrder(List<String> categoryIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (int i = 0; i < categoryIds.length; i++) {
        await txn.update(
          'categories',
          {'sortOrder': i},
          where: 'id = ?',
          whereArgs: [categoryIds[i]],
        );
      }
    });
  }

  @override
  Future<void> mergeInto(String sourceId, String targetId) async {
    final db = await _db;
    // 将所有使用 source 分类的交易改为使用 target 分类
    await db.update(
      'transactions',
      {'category': targetId},
      where: 'category = ?',
      whereArgs: [sourceId],
    );
    // 删除源分类
    await softDelete(sourceId);
  }

  @override
  Future<Map<String, int>> getUsageCount() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT category, COUNT(*) as count
      FROM transactions
      WHERE isDeleted = 0
      GROUP BY category
    ''');

    final result = <String, int>{};
    for (final map in maps) {
      final category = map['category'];
      if (category != null) {
        result[category as String] = map['count'] as int;
      }
    }
    return result;
  }

  @override
  Future<List<Category>> findMostUsed({int limit = 10}) async {
    final db = await _db;
    // 统计每个分类的使用次数
    final maps = await db.rawQuery('''
      SELECT c.*, COUNT(t.id) as usageCount
      FROM categories c
      LEFT JOIN transactions t ON c.id = t.category AND t.isDeleted = 0
      WHERE c.isDeleted = 0
      GROUP BY c.id
      ORDER BY usageCount DESC
      LIMIT ?
    ''', [limit]);
    return maps.map((m) => Category.fromMap(m)).toList();
  }
}
