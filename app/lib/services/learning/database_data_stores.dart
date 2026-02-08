import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';
import 'voice_intent_learning_service.dart';
import 'anomaly_learning_service.dart';

/// 数据库意图数据存储
/// 将意图学习数据持久化到 SQLite
class DatabaseIntentDataStore implements IntentDataStore {
  IDatabaseService? _db;

  IDatabaseService get db {
    _db ??= sl<IDatabaseService>();
    return _db!;
  }

  /// 确保表存在
  Future<void> ensureTableExists() async {
    debugPrint('[DatabaseIntentDataStore] 开始创建意图学习表...');
    await db.rawExecute('''
      CREATE TABLE IF NOT EXISTS intent_learning_data (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        input TEXT NOT NULL,
        recognizedIntent TEXT NOT NULL,
        correctedIntent TEXT,
        confidence REAL NOT NULL,
        context TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.rawExecute(
      'CREATE INDEX IF NOT EXISTS idx_intent_learning_user ON intent_learning_data(userId)',
    );
    await db.rawExecute(
      'CREATE INDEX IF NOT EXISTS idx_intent_learning_timestamp ON intent_learning_data(timestamp)',
    );
    debugPrint('[DatabaseIntentDataStore] 意图学习表创建完成');
  }

  @override
  Future<void> saveData(IntentLearningData data) async {
    final id = '${data.userId}_${data.timestamp.millisecondsSinceEpoch}';
    await db.rawInsert('''
      INSERT OR REPLACE INTO intent_learning_data
      (id, userId, input, recognizedIntent, correctedIntent, confidence, context, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      id,
      data.userId,
      data.input,
      data.recognizedIntent,
      data.correctedIntent,
      data.confidence,
      jsonEncode(data.context.toJson()),
      data.timestamp.millisecondsSinceEpoch,
    ]);
  }

  @override
  Future<List<IntentLearningData>> getUserData(String userId, {int? months}) async {
    String sql = '''
      SELECT * FROM intent_learning_data
      WHERE userId = ?
    ''';
    final params = <dynamic>[userId];

    if (months != null) {
      final cutoff = DateTime.now().subtract(Duration(days: months * 30));
      sql += ' AND timestamp > ?';
      params.add(cutoff.millisecondsSinceEpoch);
    }

    sql += ' ORDER BY timestamp DESC';

    final results = await db.rawQuery(sql, params);
    return results.map((row) => _rowToIntentLearningData(row)).toList();
  }

  @override
  Future<int> getDataCount({String? userId}) async {
    String sql = 'SELECT COUNT(*) as count FROM intent_learning_data';
    final params = <dynamic>[];

    if (userId != null) {
      sql += ' WHERE userId = ?';
      params.add(userId);
    }

    final result = await db.rawQuery(sql, params);
    return result.first['count'] as int? ?? 0;
  }

  IntentLearningData _rowToIntentLearningData(Map<String, dynamic> row) {
    Map<String, dynamic>? contextJson;
    try {
      final contextStr = row['context'] as String?;
      if (contextStr != null && contextStr.isNotEmpty) {
        contextJson = jsonDecode(contextStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[DatabaseIntentDataStore] JSON parse error for context field');
      debugPrint('[DatabaseIntentDataStore] Row ID: ${row['id']}, Error: $e');
      debugPrint('[DatabaseIntentDataStore] Raw context string: ${row['context']}');
    }

    return IntentLearningData(
      userId: row['userId'] as String,
      input: row['input'] as String,
      recognizedIntent: row['recognizedIntent'] as String,
      correctedIntent: row['correctedIntent'] as String?,
      confidence: (row['confidence'] as num).toDouble(),
      context: contextJson != null
          ? IntentContext(
              hour: contextJson['hour'] as int?,
              dayOfWeek: contextJson['day_of_week'] as int?,
              previousIntent: contextJson['previous_intent'] as String?,
              currentPage: contextJson['current_page'] as String?,
            )
          : const IntentContext(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }
}

/// 数据库异常数据存储
/// 将异常学习数据持久化到 SQLite
class DatabaseAnomalyDataStore implements AnomalyDataStore {
  IDatabaseService? _db;

  IDatabaseService get db {
    _db ??= sl<IDatabaseService>();
    return _db!;
  }

  /// 确保表存在
  Future<void> ensureTableExists() async {
    debugPrint('[DatabaseAnomalyDataStore] 开始创建异常学习表...');
    await db.rawExecute('''
      CREATE TABLE IF NOT EXISTS anomaly_learning_data (
        id TEXT PRIMARY KEY,
        transactionId TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date INTEGER NOT NULL,
        anomalyType TEXT NOT NULL,
        feedback TEXT,
        context TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.rawExecute(
      'CREATE INDEX IF NOT EXISTS idx_anomaly_learning_txn ON anomaly_learning_data(transactionId)',
    );
    await db.rawExecute(
      'CREATE INDEX IF NOT EXISTS idx_anomaly_learning_date ON anomaly_learning_data(date)',
    );
    debugPrint('[DatabaseAnomalyDataStore] 异常学习表创建完成');
  }

  @override
  Future<void> saveData(AnomalyLearningData data) async {
    final id = '${data.transactionId}_${DateTime.now().millisecondsSinceEpoch}';
    await db.rawInsert('''
      INSERT OR REPLACE INTO anomaly_learning_data
      (id, transactionId, amount, category, date, anomalyType, feedback, context, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      id,
      data.transactionId,
      data.amount,
      data.category,
      data.date.millisecondsSinceEpoch,
      data.anomalyType.name,
      data.feedback?.name,
      jsonEncode(data.transactionContext),
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  @override
  Future<List<AnomalyLearningData>> getUserData(String userId, {int? months}) async {
    String sql = '''
      SELECT * FROM anomaly_learning_data
      WHERE transactionId LIKE ?
    ''';
    final params = <dynamic>['$userId%'];

    if (months != null) {
      final cutoff = DateTime.now().subtract(Duration(days: months * 30));
      sql += ' AND date > ?';
      params.add(cutoff.millisecondsSinceEpoch);
    }

    sql += ' ORDER BY date DESC';

    final results = await db.rawQuery(sql, params);
    return results.map((row) => _rowToAnomalyLearningData(row)).toList();
  }

  @override
  Future<int> getDataCount({String? userId}) async {
    String sql = 'SELECT COUNT(*) as count FROM anomaly_learning_data';
    final params = <dynamic>[];

    if (userId != null) {
      sql += ' WHERE transactionId LIKE ?';
      params.add('$userId%');
    }

    final result = await db.rawQuery(sql, params);
    return result.first['count'] as int? ?? 0;
  }

  @override
  Future<List<AnomalyLearningData>> getRecentData({int limit = 100}) async {
    final results = await db.rawQuery('''
      SELECT * FROM anomaly_learning_data
      ORDER BY date DESC
      LIMIT ?
    ''', [limit]);
    return results.map((row) => _rowToAnomalyLearningData(row)).toList();
  }

  AnomalyLearningData _rowToAnomalyLearningData(Map<String, dynamic> row) {
    Map<String, dynamic>? contextJson;
    try {
      final contextStr = row['context'] as String?;
      if (contextStr != null && contextStr.isNotEmpty) {
        contextJson = jsonDecode(contextStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[DatabaseAnomalyDataStore] JSON parse error for context field');
      debugPrint('[DatabaseAnomalyDataStore] Row ID: ${row['id']}, Error: $e');
      debugPrint('[DatabaseAnomalyDataStore] Raw context string: ${row['context']}');
    }

    return AnomalyLearningData(
      transactionId: row['transactionId'] as String,
      amount: (row['amount'] as num).toDouble(),
      category: row['category'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      anomalyType: AnomalyType.values.firstWhere(
        (t) => t.name == row['anomalyType'],
        orElse: () => AnomalyType.unusualAmount,
      ),
      feedback: row['feedback'] != null
          ? AnomalyFeedback.values.firstWhere(
              (f) => f.name == row['feedback'],
              orElse: () => AnomalyFeedback.dismissed,
            )
          : null,
      transactionContext: contextJson ?? {},
    );
  }
}
