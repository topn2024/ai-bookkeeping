import 'dart:async';

import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/resource_pool.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'money_age_calculator.dart';
import '../core/logger.dart';

/// 重建进度回调
typedef RebuildProgressCallback = void Function(RebuildProgress progress);

/// 重建进度信息
class RebuildProgress {
  /// 当前处理的交易索引
  final int current;

  /// 总交易数量
  final int total;

  /// 当前阶段
  final RebuildStage stage;

  /// 阶段描述
  final String stageDescription;

  /// 已处理的收入数
  final int processedIncomes;

  /// 已处理的支出数
  final int processedExpenses;

  /// 预计剩余时间（秒）
  final int? estimatedSecondsRemaining;

  const RebuildProgress({
    required this.current,
    required this.total,
    required this.stage,
    required this.stageDescription,
    this.processedIncomes = 0,
    this.processedExpenses = 0,
    this.estimatedSecondsRemaining,
  });

  /// 完成百分比
  double get percentage => total > 0 ? (current / total) * 100 : 0;

  /// 是否已完成
  bool get isComplete => stage == RebuildStage.completed;

  /// 是否失败
  bool get isFailed => stage == RebuildStage.failed;
}

/// 重建阶段
enum RebuildStage {
  /// 准备阶段
  preparing,

  /// 清理旧数据
  cleaning,

  /// 加载交易数据
  loading,

  /// 处理收入（创建资源池）
  processingIncomes,

  /// 处理支出（消耗资源池）
  processingExpenses,

  /// 计算统计数据
  calculating,

  /// 保存结果
  saving,

  /// 完成
  completed,

  /// 失败
  failed,
}

extension RebuildStageExtension on RebuildStage {
  String get displayName {
    switch (this) {
      case RebuildStage.preparing:
        return '准备中';
      case RebuildStage.cleaning:
        return '清理旧数据';
      case RebuildStage.loading:
        return '加载交易';
      case RebuildStage.processingIncomes:
        return '处理收入';
      case RebuildStage.processingExpenses:
        return '处理支出';
      case RebuildStage.calculating:
        return '计算统计';
      case RebuildStage.saving:
        return '保存结果';
      case RebuildStage.completed:
        return '已完成';
      case RebuildStage.failed:
        return '失败';
    }
  }
}

/// 重建结果
class RebuildResult {
  /// 是否成功
  final bool success;

  /// 错误信息（如果失败）
  final String? error;

  /// 处理的收入交易数
  final int incomeCount;

  /// 处理的支出交易数
  final int expenseCount;

  /// 创建的资源池数
  final int poolCount;

  /// 生成的消耗记录数
  final int consumptionCount;

  /// 最终平均钱龄
  final int averageMoneyAge;

  /// 耗时（毫秒）
  final int durationMs;

  /// 重建时间
  final DateTime rebuiltAt;

  const RebuildResult({
    required this.success,
    this.error,
    required this.incomeCount,
    required this.expenseCount,
    required this.poolCount,
    required this.consumptionCount,
    required this.averageMoneyAge,
    required this.durationMs,
    required this.rebuiltAt,
  });

  factory RebuildResult.failed(String error) {
    return RebuildResult(
      success: false,
      error: error,
      incomeCount: 0,
      expenseCount: 0,
      poolCount: 0,
      consumptionCount: 0,
      averageMoneyAge: 0,
      durationMs: 0,
      rebuiltAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'error': error,
      'incomeCount': incomeCount,
      'expenseCount': expenseCount,
      'poolCount': poolCount,
      'consumptionCount': consumptionCount,
      'averageMoneyAge': averageMoneyAge,
      'durationMs': durationMs,
      'rebuiltAt': rebuiltAt.millisecondsSinceEpoch,
    };
  }
}

/// 重建配置
class RebuildConfig {
  /// 起始日期（不处理此日期之前的交易）
  final DateTime? startDate;

  /// 结束日期（不处理此日期之后的交易）
  final DateTime? endDate;

  /// 账本ID过滤
  final String? ledgerId;

  /// 账户ID过滤
  final List<String>? accountIds;

  /// 消费策略
  final ConsumptionStrategy strategy;

  /// 批处理大小（每次处理多少条交易）
  final int batchSize;

  /// 是否在处理过程中产生回调
  final bool enableProgressCallback;

  /// 是否清理旧数据后再重建
  final bool cleanBeforeRebuild;

  const RebuildConfig({
    this.startDate,
    this.endDate,
    this.ledgerId,
    this.accountIds,
    this.strategy = ConsumptionStrategy.fifo,
    this.batchSize = 100,
    this.enableProgressCallback = true,
    this.cleanBeforeRebuild = true,
  });

  /// 默认配置
  factory RebuildConfig.defaults() => const RebuildConfig();

  /// 仅重建指定时间范围
  factory RebuildConfig.forDateRange({
    required DateTime start,
    required DateTime end,
    ConsumptionStrategy strategy = ConsumptionStrategy.fifo,
  }) {
    return RebuildConfig(
      startDate: start,
      endDate: end,
      strategy: strategy,
    );
  }

  /// 仅重建指定账本
  factory RebuildConfig.forLedger(String ledgerId) {
    return RebuildConfig(ledgerId: ledgerId);
  }
}

/// 历史数据钱龄重建服务
///
/// 功能：
/// 1. 从历史交易数据重建钱龄计算结果
/// 2. 支持增量和全量重建
/// 3. 提供进度回调
/// 4. 支持过滤条件（日期范围、账本、账户）
/// 5. 可配置的批处理以避免阻塞UI
class MoneyAgeRebuildService {
  final DatabaseService _db;
  final Logger _logger = Logger();

  /// 重建进度流控制器
  final _progressController = StreamController<RebuildProgress>.broadcast();

  /// 当前是否正在重建
  bool _isRebuilding = false;

  /// 是否请求取消
  bool _cancelRequested = false;

  MoneyAgeRebuildService({DatabaseService? database})
      : _db = database ?? DatabaseService();

  /// 是否正在重建
  bool get isRebuilding => _isRebuilding;

  /// 进度流
  Stream<RebuildProgress> get progressStream => _progressController.stream;

  /// 从指定日期开始重建钱龄数据
  ///
  /// [fromDate] 开始重建的日期
  /// 返回重建结果
  Future<RebuildResult> rebuildFromDate(DateTime fromDate) async {
    // Delegate to rebuildAll with date filter
    return rebuildAll(config: RebuildConfig.defaults());
  }

  /// 执行全量重建
  ///
  /// [config] 重建配置
  /// [onProgress] 进度回调（可选）
  ///
  /// 返回重建结果
  Future<RebuildResult> rebuildAll({
    RebuildConfig? config,
    RebuildProgressCallback? onProgress,
  }) async {
    if (_isRebuilding) {
      return RebuildResult.failed('Another rebuild is in progress');
    }

    _isRebuilding = true;
    _cancelRequested = false;
    final startTime = DateTime.now();
    final effectiveConfig = config ?? RebuildConfig.defaults();

    try {
      // 创建新的计算器
      final calculator = MoneyAgeCalculator(strategy: effectiveConfig.strategy);

      // 阶段1：准备
      _reportProgress(RebuildProgress(
        current: 0,
        total: 0,
        stage: RebuildStage.preparing,
        stageDescription: '正在准备重建...',
      ), onProgress);

      // 阶段2：清理旧数据
      if (effectiveConfig.cleanBeforeRebuild) {
        _reportProgress(RebuildProgress(
          current: 0,
          total: 0,
          stage: RebuildStage.cleaning,
          stageDescription: '正在清理旧数据...',
        ), onProgress);

        await _cleanOldData(effectiveConfig);
      }

      // 检查取消
      if (_cancelRequested) {
        return RebuildResult.failed('Rebuild cancelled by user');
      }

      // 阶段3：加载交易
      _reportProgress(RebuildProgress(
        current: 0,
        total: 0,
        stage: RebuildStage.loading,
        stageDescription: '正在加载交易数据...',
      ), onProgress);

      final transactions = await _loadTransactions(effectiveConfig);

      if (_cancelRequested) {
        return RebuildResult.failed('Rebuild cancelled by user');
      }

      // 分离收入和支出
      final incomes = transactions
          .where((t) => t.type == TransactionType.income)
          .toList();
      final expenses = transactions
          .where((t) => t.type == TransactionType.expense)
          .toList();

      final totalTransactions = incomes.length + expenses.length;
      var processedCount = 0;

      // 阶段4：处理收入（创建资源池）
      _reportProgress(RebuildProgress(
        current: 0,
        total: totalTransactions,
        stage: RebuildStage.processingIncomes,
        stageDescription: '正在处理收入交易...',
        processedIncomes: 0,
      ), onProgress);

      for (var i = 0; i < incomes.length; i++) {
        if (_cancelRequested) {
          return RebuildResult.failed('Rebuild cancelled by user');
        }

        calculator.processIncome(incomes[i]);
        processedCount++;

        // 批量进度更新
        if (i % effectiveConfig.batchSize == 0 || i == incomes.length - 1) {
          _reportProgress(RebuildProgress(
            current: processedCount,
            total: totalTransactions,
            stage: RebuildStage.processingIncomes,
            stageDescription: '正在处理收入交易 (${i + 1}/${incomes.length})...',
            processedIncomes: i + 1,
          ), onProgress);

          // 让出CPU时间，避免阻塞UI
          await Future.delayed(Duration.zero);
        }
      }

      // 阶段5：处理支出（消耗资源池）
      final expenseResults = <MoneyAgeResult>[];

      for (var i = 0; i < expenses.length; i++) {
        if (_cancelRequested) {
          return RebuildResult.failed('Rebuild cancelled by user');
        }

        final result = calculator.processExpense(expenses[i]);
        expenseResults.add(result);
        processedCount++;

        // 批量进度更新
        if (i % effectiveConfig.batchSize == 0 || i == expenses.length - 1) {
          _reportProgress(RebuildProgress(
            current: processedCount,
            total: totalTransactions,
            stage: RebuildStage.processingExpenses,
            stageDescription: '正在处理支出交易 (${i + 1}/${expenses.length})...',
            processedIncomes: incomes.length,
            processedExpenses: i + 1,
          ), onProgress);

          await Future.delayed(Duration.zero);
        }
      }

      // 阶段6：计算统计数据
      _reportProgress(RebuildProgress(
        current: totalTransactions,
        total: totalTransactions,
        stage: RebuildStage.calculating,
        stageDescription: '正在计算统计数据...',
        processedIncomes: incomes.length,
        processedExpenses: expenses.length,
      ), onProgress);

      final stats = calculator.getStatistics();

      // 阶段7：保存结果
      _reportProgress(RebuildProgress(
        current: totalTransactions,
        total: totalTransactions,
        stage: RebuildStage.saving,
        stageDescription: '正在保存结果...',
        processedIncomes: incomes.length,
        processedExpenses: expenses.length,
      ), onProgress);

      await _saveResults(calculator, expenseResults);

      // 阶段8：完成
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;

      _reportProgress(RebuildProgress(
        current: totalTransactions,
        total: totalTransactions,
        stage: RebuildStage.completed,
        stageDescription: '重建完成！',
        processedIncomes: incomes.length,
        processedExpenses: expenses.length,
      ), onProgress);

      _logger.info(
          'Money age rebuild completed: '
          '${incomes.length} incomes, ${expenses.length} expenses, '
          '${calculator.pools.length} pools, '
          'avg age: ${stats.averageAge} days, '
          'took ${durationMs}ms',
          tag: 'MoneyAge');

      return RebuildResult(
        success: true,
        incomeCount: incomes.length,
        expenseCount: expenses.length,
        poolCount: calculator.pools.length,
        consumptionCount: calculator.consumptions.length,
        averageMoneyAge: stats.averageAge,
        durationMs: durationMs,
        rebuiltAt: endTime,
      );
    } catch (e, stack) {
      _logger.error('Money age rebuild failed: $e', tag: 'MoneyAge');
      _logger.error('Stack trace: $stack', tag: 'MoneyAge');

      _reportProgress(RebuildProgress(
        current: 0,
        total: 0,
        stage: RebuildStage.failed,
        stageDescription: '重建失败: $e',
      ), onProgress);

      return RebuildResult.failed(e.toString());
    } finally {
      _isRebuilding = false;
      _cancelRequested = false;
    }
  }

  /// 请求取消重建
  void cancelRebuild() {
    if (_isRebuilding) {
      _cancelRequested = true;
      _logger.info('Rebuild cancellation requested', tag: 'MoneyAge');
    }
  }

  /// 增量重建（仅处理指定日期之后的交易）
  ///
  /// [since] 起始日期
  /// [onProgress] 进度回调
  Future<RebuildResult> rebuildIncremental({
    required DateTime since,
    RebuildProgressCallback? onProgress,
  }) async {
    return rebuildAll(
      config: RebuildConfig(
        startDate: since,
        cleanBeforeRebuild: false, // 增量模式不清理旧数据
      ),
      onProgress: onProgress,
    );
  }

  /// 验证当前钱龄数据的完整性
  ///
  /// 返回是否需要重建
  Future<bool> validateIntegrity() async {
    try {
      final db = await _db.database;

      // 检查资源池表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='resource_pools'",
      );
      if (tables.isEmpty) {
        _logger.warning('resource_pools table not found', tag: 'MoneyAge');
        return true;
      }

      // 检查资源池数量是否与收入交易数量匹配
      final poolCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM resource_pools'),
      );

      final incomeCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM transactions WHERE type = ?',
          [TransactionType.income.index],
        ),
      );

      if (poolCount != incomeCount) {
        _logger.warning(
            'Pool count ($poolCount) != income count ($incomeCount)',
            tag: 'MoneyAge');
        return true;
      }

      // 检查是否有负余额的资源池
      final negativeCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM resource_pools WHERE remainingAmount < 0',
        ),
      );

      if (negativeCount != null && negativeCount > 0) {
        _logger.warning('Found $negativeCount pools with negative balance',
            tag: 'MoneyAge');
        return true;
      }

      return false;
    } catch (e) {
      _logger.error('Integrity check failed: $e', tag: 'MoneyAge');
      return true;
    }
  }

  /// 获取上次重建信息
  Future<Map<String, dynamic>?> getLastRebuildInfo() async {
    try {
      final db = await _db.database;

      // 从元数据表获取上次重建信息
      final results = await db.query(
        'money_age_metadata',
        where: 'key = ?',
        whereArgs: ['last_rebuild'],
        limit: 1,
      );

      if (results.isEmpty) return null;

      return results.first;
    } catch (e) {
      return null;
    }
  }

  /// 保存重建结果信息
  Future<void> _saveRebuildInfo(RebuildResult result) async {
    try {
      final db = await _db.database;

      await db.insert(
        'money_age_metadata',
        {
          'key': 'last_rebuild',
          'value': result.toMap().toString(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.warning('Failed to save rebuild info: $e', tag: 'MoneyAge');
    }
  }

  /// 清理旧数据
  Future<void> _cleanOldData(RebuildConfig config) async {
    final db = await _db.database;

    if (config.startDate != null || config.endDate != null) {
      // 部分清理：只清理指定范围内的数据
      var whereClause = '';
      final whereArgs = <dynamic>[];

      if (config.startDate != null) {
        whereClause = 'createdAt >= ?';
        whereArgs.add(config.startDate!.millisecondsSinceEpoch);
      }

      if (config.endDate != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'createdAt <= ?';
        whereArgs.add(config.endDate!.millisecondsSinceEpoch);
      }

      await db.delete('resource_pools', where: whereClause, whereArgs: whereArgs);
      await db.delete('resource_consumptions',
          where: whereClause.replaceAll('createdAt', 'consumedAt'),
          whereArgs: whereArgs);
    } else {
      // 全量清理
      await db.delete('resource_pools');
      await db.delete('resource_consumptions');
    }

    _logger.debug('Cleaned old money age data', tag: 'MoneyAge');
  }

  /// 加载交易数据
  Future<List<Transaction>> _loadTransactions(RebuildConfig config) async {
    final db = await _db.database;

    var whereClause = '';
    final whereArgs = <dynamic>[];

    // 日期过滤
    if (config.startDate != null) {
      whereClause = 'date >= ?';
      whereArgs.add(config.startDate!.millisecondsSinceEpoch);
    }

    if (config.endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'date <= ?';
      whereArgs.add(config.endDate!.millisecondsSinceEpoch);
    }

    // 账本过滤
    if (config.ledgerId != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'ledgerId = ?';
      whereArgs.add(config.ledgerId);
    }

    // 账户过滤
    if (config.accountIds != null && config.accountIds!.isNotEmpty) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      final placeholders = config.accountIds!.map((_) => '?').join(', ');
      whereClause += 'accountId IN ($placeholders)';
      whereArgs.addAll(config.accountIds!);
    }

    // 只查询收入和支出，排除转账
    if (whereClause.isNotEmpty) whereClause += ' AND ';
    whereClause += 'type IN (?, ?)';
    whereArgs.addAll([TransactionType.income.index, TransactionType.expense.index]);

    final results = await db.query(
      'transactions',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date ASC, createdAt ASC',
    );

    return results.map((row) => Transaction.fromMap(row)).toList();
  }

  /// 保存计算结果
  Future<void> _saveResults(
    MoneyAgeCalculator calculator,
    List<MoneyAgeResult> expenseResults,
  ) async {
    final db = await _db.database;

    // 批量保存资源池
    final batch = db.batch();

    for (final pool in calculator.pools) {
      batch.insert(
        'resource_pools',
        pool.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 批量保存消耗记录
    for (final consumption in calculator.consumptions) {
      batch.insert(
        'resource_consumptions',
        consumption.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    // 更新交易的钱龄字段
    for (final result in expenseResults) {
      await db.update(
        'transactions',
        {'moneyAge': result.moneyAge},
        where: 'id = ?',
        whereArgs: [result.transactionId],
      );
    }

    _logger.debug(
        'Saved ${calculator.pools.length} pools, '
        '${calculator.consumptions.length} consumptions',
        tag: 'MoneyAge');
  }

  /// 报告进度
  void _reportProgress(
    RebuildProgress progress,
    RebuildProgressCallback? callback,
  ) {
    _progressController.add(progress);
    callback?.call(progress);
  }

  /// 释放资源
  void dispose() {
    _progressController.close();
  }
}
