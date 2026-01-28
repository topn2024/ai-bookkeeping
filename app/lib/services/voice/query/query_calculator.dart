/// 动态查询计算引擎
///
/// 从原始交易数据动态计算查询结果，不依赖固定数据库列
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/transaction.dart' as model;
import '../../database_service.dart';
import 'query_models.dart';
import 'query_calculator_strategies.dart';

// ═══════════════════════════════════════════════════════════════
// 异常定义
// ═══════════════════════════════════════════════════════════════

/// 查询异常
class QueryException implements Exception {
  final String message;
  QueryException(this.message);

  @override
  String toString() => 'QueryException: $message';
}

// ═══════════════════════════════════════════════════════════════
// 缓存相关
// ═══════════════════════════════════════════════════════════════

/// 缓存结果
class _CachedResult {
  final QueryResult result;
  final DateTime expiresAt;

  _CachedResult({
    required this.result,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ═══════════════════════════════════════════════════════════════
// 策略接口
// ═══════════════════════════════════════════════════════════════

/// 查询计算策略接口
abstract class QueryCalculatorStrategy {
  /// 执行计算
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  );
}

// ═══════════════════════════════════════════════════════════════
// 主计算引擎
// ═══════════════════════════════════════════════════════════════

/// 动态查询计算引擎
class QueryCalculator {
  final DatabaseService _database;

  /// 查询结果缓存（5分钟有效期）
  final Map<String, _CachedResult> _cache = {};

  /// 定期清理定时器
  Timer? _cleanupTimer;

  /// 最大查询时间范围（天）
  static const int maxTimeRangeDays = 365;

  /// 最大数据点数量
  static const int maxDataPoints = 1000;

  QueryCalculator(this._database) {
    // 启动定期清理任务
    _startPeriodicCleanup();
  }

  /// 释放资源
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _cache.clear();
    debugPrint('[QueryCalculator] 资源已释放');
  }

  /// 计算查询结果
  Future<QueryResult> calculate(QueryRequest request) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('[QueryCalculator] 开始计算: type=${request.queryType}, '
          'timeRange=${request.timeRange?.periodText}, '
          'category=${request.category}');

      // 检查缓存
      final cacheKey = _generateCacheKey(request);
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired) {
        debugPrint('[QueryCalculator] 缓存命中: key=$cacheKey');
        return cached.result;
      }

      // 验证时间范围
      _validateTimeRange(request.timeRange);

      // 获取交易数据
      final transactions = await _fetchTransactions(request);
      debugPrint('[QueryCalculator] 获取交易数据: count=${transactions.length}');

      // 数据采样（如果需要）
      final sampledTransactions = _sampleTransactions(transactions);
      if (sampledTransactions.length < transactions.length) {
        debugPrint('[QueryCalculator] 数据采样: ${transactions.length} -> ${sampledTransactions.length}');
      }

      // 选择计算策略
      final strategy = _getCalculator(request.queryType);

      // 执行计算
      final result = strategy.calculate(sampledTransactions, request);

      // 缓存结果
      _cache[cacheKey] = _CachedResult(
        result: result,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      stopwatch.stop();
      debugPrint('[QueryCalculator] 计算完成: 耗时=${stopwatch.elapsedMilliseconds}ms');

      return result;
    } catch (e, stackTrace) {
      debugPrint('[QueryCalculator] 计算失败: $e');
      debugPrint('[QueryCalculator] 堆栈: $stackTrace');
      throw QueryException('查询计算失败: $e');
    }
  }

  /// 验证时间范围
  void _validateTimeRange(TimeRange? timeRange) {
    if (timeRange == null) return;

    final duration = timeRange.endDate.difference(timeRange.startDate);
    if (duration.inDays > maxTimeRangeDays) {
      throw QueryException('查询时间范围不能超过${maxTimeRangeDays}天');
    }
  }

  /// 获取交易数据
  Future<List<model.Transaction>> _fetchTransactions(QueryRequest request) async {
    try {
      final db = await _database.database;

      // 构建查询条件
      final where = <String>[];
      final whereArgs = <dynamic>[];

      // 时间范围
      if (request.timeRange != null) {
        where.add('date >= ? AND date <= ?');
        whereArgs.add(request.timeRange!.startDate.millisecondsSinceEpoch);
        whereArgs.add(request.timeRange!.endDate.millisecondsSinceEpoch);
      }

      // 分类过滤
      if (request.category != null) {
        where.add('category = ?');
        whereArgs.add(request.category);
      }

      // 交易类型
      if (request.transactionType != null) {
        final typeIndex = _parseTransactionType(request.transactionType!);
        if (typeIndex != null) {
          where.add('type = ?');
          whereArgs.add(typeIndex);
        }
      }

      // 账户过滤
      if (request.account != null) {
        where.add('account_id = ?');
        whereArgs.add(request.account);
      }

      // 来源过滤
      if (request.source != null) {
        final sourceIndex = _parseTransactionSource(request.source!);
        if (sourceIndex != null) {
          where.add('source = ?');
          whereArgs.add(sourceIndex);
        }
      }

      // 执行查询
      final results = await db.query(
        'transactions',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date DESC',
      );

      return results.map((row) => _transactionFromMap(row)).toList();
    } catch (e) {
      throw QueryException('获取交易数据失败: $e');
    }
  }

  /// 数据采样
  List<model.Transaction> _sampleTransactions(List<model.Transaction> transactions) {
    if (transactions.length <= maxDataPoints) {
      return transactions;
    }

    // 均匀采样
    final step = transactions.length / maxDataPoints;
    final sampled = <model.Transaction>[];
    for (int i = 0; i < maxDataPoints; i++) {
      sampled.add(transactions[(i * step).floor()]);
    }
    return sampled;
  }

  /// 获取计算策略
  QueryCalculatorStrategy _getCalculator(QueryType type) {
    switch (type) {
      case QueryType.summary:
        return SummaryCalculator();
      case QueryType.trend:
        return TrendCalculator();
      case QueryType.distribution:
        return DistributionCalculator();
      case QueryType.comparison:
        return ComparisonCalculator();
      case QueryType.recent:
        return RecentCalculator();
      default:
        return SimpleCalculator();
    }
  }

  /// 生成缓存键
  String _generateCacheKey(QueryRequest request) {
    return '${request.queryType}_'
        '${request.timeRange?.startDate.millisecondsSinceEpoch}_'
        '${request.timeRange?.endDate.millisecondsSinceEpoch}_'
        '${request.category}_'
        '${request.transactionType}_'
        '${request.account}_'
        '${request.source}';
  }

  /// 定期清理过期缓存
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final now = DateTime.now();
      _cache.removeWhere((key, value) => value.expiresAt.isBefore(now));
      if (_cache.isNotEmpty) {
        debugPrint('[QueryCalculator] 清理过期缓存，剩余: ${_cache.length}');
      }
    });
  }

  /// 解析交易类型
  int? _parseTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'expense':
      case '支出':
        return 0;
      case 'income':
      case '收入':
        return 1;
      case 'transfer':
      case '转账':
        return 2;
      default:
        return null;
    }
  }

  /// 解析交易来源
  int? _parseTransactionSource(String source) {
    switch (source.toLowerCase()) {
      case 'manual':
      case '手动':
        return 0;
      case 'image':
      case '图片':
        return 1;
      case 'voice':
      case '语音':
        return 2;
      case 'email':
      case '邮件':
        return 3;
      case 'import':
      case '导入':
        return 4;
      default:
        return null;
    }
  }

  /// 从Map创建Transaction对象
  model.Transaction _transactionFromMap(Map<String, dynamic> map) {
    return model.Transaction(
      id: map['id'] as String,
      type: model.TransactionType.values[map['type'] as int],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      subcategory: map['subcategory'] as String?,
      note: map['note'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      accountId: map['accountId'] as String? ?? map['account_id'] as String? ?? 'default',
      toAccountId: map['toAccountId'] as String? ?? map['to_account_id'] as String?,
      imageUrl: map['imageUrl'] as String? ?? map['image_url'] as String?,
      isSplit: (map['isSplit'] as int? ?? map['is_split'] as int?) == 1,
      isReimbursable: (map['isReimbursable'] as int? ?? map['is_reimbursable'] as int?) == 1,
      isReimbursed: (map['isReimbursed'] as int? ?? map['is_reimbursed'] as int?) == 1,
      source: model.TransactionSource.values[map['source'] as int? ?? 0],
      aiConfidence: (map['aiConfidence'] as num?)?.toDouble() ?? (map['ai_confidence'] as num?)?.toDouble(),
      externalId: map['externalId'] as String? ?? map['external_id'] as String?,
      importBatchId: map['importBatchId'] as String? ?? map['import_batch_id'] as String?,
      rawMerchant: map['rawMerchant'] as String? ?? map['raw_merchant'] as String?,
      vaultId: map['vaultId'] as String? ?? map['vault_id'] as String?,
      moneyAge: map['moneyAge'] as int? ?? map['money_age'] as int?,
      moneyAgeLevel: map['moneyAgeLevel'] as String? ?? map['money_age_level'] as String?,
      resourcePoolId: map['resourcePoolId'] as String? ?? map['resource_pool_id'] as String?,
      visibility: map['visibility'] as int? ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : (map['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
              : DateTime.now()),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : (map['updated_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
              : null),
    );
  }
}
