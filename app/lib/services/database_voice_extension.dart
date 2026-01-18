import '../models/transaction.dart' as model;
import '../services/database_service.dart';

/// 数据库服务的语音查询扩展
extension VoiceQueryExtension on DatabaseService {
  /// 为语音服务提供的高级查询方法
  Future<List<model.Transaction>> queryTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? merchant,
    double? minAmount,
    double? maxAmount,
    String? description,
    String? account,
    List<String>? tags,
    int limit = 50,
  }) async {
    final db = await database;

    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    // 时间范围过滤
    if (startDate != null) {
      whereConditions.add('date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereConditions.add('date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    // 分类过滤（注意：transactions表没有subcategory列，只有category）
    if (category != null && category.isNotEmpty) {
      whereConditions.add('category LIKE ?');
      whereArgs.add('%$category%');
    }

    // 商家过滤
    if (merchant != null && merchant.isNotEmpty) {
      whereConditions.add('merchant LIKE ?');
      whereArgs.add('%$merchant%');
    }

    // 金额范围过滤
    if (minAmount != null) {
      whereConditions.add('amount >= ?');
      whereArgs.add(minAmount);
    }
    if (maxAmount != null) {
      whereConditions.add('amount <= ?');
      whereArgs.add(maxAmount);
    }

    // 描述过滤
    if (description != null && description.isNotEmpty) {
      whereConditions.add('description LIKE ?');
      whereArgs.add('%$description%');
    }

    // 账户过滤
    if (account != null && account.isNotEmpty) {
      whereConditions.add('account LIKE ?');
      whereArgs.add('%$account%');
    }

    // 标签过滤
    if (tags != null && tags.isNotEmpty) {
      final tagConditions = tags.map((_) => 'tags LIKE ?').join(' OR ');
      whereConditions.add('($tagConditions)');
      for (final tag in tags) {
        whereArgs.add('%$tag%');
      }
    }

    final whereClause = whereConditions.isEmpty ? null : whereConditions.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC',
      limit: limit,
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      // 获取分账信息
      final splits = await getTransactionSplits(map['id'] as String);

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int? ?? 0],
        amount: map['amount'] as double,
        category: map['category'] as String? ?? '',
        // transactions表没有subcategory列，设为null
        subcategory: null,
        rawMerchant: map['rawMerchant'] as String?,
        note: map['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['accountId'] as String? ?? '',
        tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
        splits: splits,
        createdAt: map['createdAt'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int) :
          DateTime.now(),
        updatedAt: map['updatedAt'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int) :
          DateTime.now(),
      ));
    }

    return transactions;
  }

  /// 智能搜索交易记录（支持模糊匹配）
  Future<List<model.Transaction>> smartSearchTransactions(
    String query, {
    int limit = 20,
  }) async {
    final db = await database;

    // 构建智能搜索查询
    final searchTerms = query.toLowerCase().split(' ').where((term) => term.isNotEmpty).toList();
    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    for (final term in searchTerms) {
      // 注意：transactions表没有subcategory列，使用note代替description（表中列名是note）
      whereConditions.add('''
        (LOWER(note) LIKE ? OR
         LOWER(rawMerchant) LIKE ? OR
         LOWER(category) LIKE ? OR
         LOWER(tags) LIKE ?)
      ''');
      whereArgs.addAll(['%$term%', '%$term%', '%$term%', '%$term%']);
    }

    final whereClause = whereConditions.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final splits = await getTransactionSplits(map['id'] as String);

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int? ?? 0],
        amount: map['amount'] as double,
        category: map['category'] as String? ?? '',
        subcategory: null, // transactions表没有subcategory列
        rawMerchant: map['merchant'] as String?,
        note: map['description'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['account'] as String? ?? '',
        tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
        splits: splits,
        createdAt: map['created_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) :
          DateTime.now(),
        updatedAt: map['updated_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int) :
          DateTime.now(),
      ));
    }

    return transactions;
  }

  /// 获取最近的交易记录
  Future<List<model.Transaction>> getRecentTransactions({
    int limit = 10,
    Duration? within,
  }) async {
    final db = await database;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (within != null) {
      final cutoffTime = DateTime.now().subtract(within);
      whereClause = 'date >= ?';
      whereArgs = [cutoffTime.millisecondsSinceEpoch];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final splits = await getTransactionSplits(map['id'] as String);

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int? ?? 0],
        amount: map['amount'] as double,
        category: map['category'] as String? ?? '',
        subcategory: null, // transactions表没有subcategory列
        rawMerchant: map['merchant'] as String?,
        note: map['description'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['account'] as String? ?? '',
        tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
        splits: splits,
        createdAt: map['created_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) :
          DateTime.now(),
        updatedAt: map['updated_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int) :
          DateTime.now(),
      ));
    }

    return transactions;
  }

  /// 按金额排序获取交易记录
  Future<List<model.Transaction>> getTransactionsByAmount({
    required bool ascending,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    final db = await database;

    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereConditions.add('date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereConditions.add('date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final whereClause = whereConditions.isEmpty ? null : whereConditions.join(' AND ');
    final orderBy = ascending ? 'amount ASC' : 'amount DESC';

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
      limit: limit,
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final splits = await getTransactionSplits(map['id'] as String);

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int? ?? 0],
        amount: map['amount'] as double,
        category: map['category'] as String? ?? '',
        subcategory: null, // transactions表没有subcategory列
        rawMerchant: map['merchant'] as String?,
        note: map['description'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['account'] as String? ?? '',
        tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
        splits: splits,
        createdAt: map['created_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) :
          DateTime.now(),
        updatedAt: map['updated_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int) :
          DateTime.now(),
      ));
    }

    return transactions;
  }

  /// 软删除交易记录（移到回收站）
  Future<bool> softDeleteTransaction(String transactionId) async {
    try {
      final db = await database;
      await db.update(
        'transactions',
        {
          'deleted': 1,
          'deleted_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 恢复删除的交易记录
  Future<bool> restoreTransaction(String transactionId) async {
    try {
      final db = await database;
      await db.update(
        'transactions',
        {
          'deleted': 0,
          'deleted_at': null,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取回收站中的记录
  Future<List<model.Transaction>> getDeletedTransactions({
    int limit = 50,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'deleted = 1',
      orderBy: 'deleted_at DESC',
      limit: limit,
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final splits = await getTransactionSplits(map['id'] as String);

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int? ?? 0],
        amount: map['amount'] as double,
        category: map['category'] as String? ?? '',
        subcategory: null, // transactions表没有subcategory列
        rawMerchant: map['merchant'] as String?,
        note: map['description'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['account'] as String? ?? '',
        tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
        splits: splits,
        createdAt: map['created_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) :
          DateTime.now(),
        updatedAt: map['updated_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int) :
          DateTime.now(),
      ));
    }

    return transactions;
  }

  /// 永久删除过期的回收站记录
  Future<int> cleanupExpiredDeletedTransactions({
    Duration retentionPeriod = const Duration(days: 30),
  }) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(retentionPeriod);

    final result = await db.delete(
      'transactions',
      where: 'deleted = 1 AND deleted_at <= ?',
      whereArgs: [cutoffTime.millisecondsSinceEpoch],
    );

    return result;
  }

  /// 获取单个交易记录的详细信息
  Future<model.Transaction?> getTransactionById(String transactionId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final splits = await getTransactionSplits(map['id'] as String);

    return model.Transaction(
      id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int? ?? 0],
      amount: map['amount'] as double,
      category: map['category'] as String? ?? '',
      subcategory: null, // transactions表没有subcategory列
      rawMerchant: map['merchant'] as String?,
      note: map['description'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      accountId: map['account'] as String? ?? '',
      tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
      splits: splits,
      createdAt: map['created_at'] != null ?
        DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) :
        DateTime.now(),
      updatedAt: map['updated_at'] != null ?
        DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int) :
        DateTime.now(),
    );
  }
}