import 'package:sqflite/sqflite.dart';

import '../models/resource_pool.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'money_age_calculator.dart';
import '../core/logger.dart';

/// 资源池变更类型
enum ResourcePoolChangeType {
  /// 新建（收入）
  created,

  /// 消耗（支出）
  consumed,

  /// 修改（交易编辑）
  modified,

  /// 删除（交易删除）
  deleted,

  /// 重建（全量重算）
  rebuilt,
}

/// 资源池变更记录
class ResourcePoolChange {
  final String poolId;
  final ResourcePoolChangeType type;
  final double? amountChange;
  final String? transactionId;
  final DateTime timestamp;

  const ResourcePoolChange({
    required this.poolId,
    required this.type,
    this.amountChange,
    this.transactionId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'poolId': poolId,
      'type': type.index,
      'amountChange': amountChange,
      'transactionId': transactionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ResourcePoolChange.fromMap(Map<String, dynamic> map) {
    return ResourcePoolChange(
      poolId: map['poolId'] as String,
      type: ResourcePoolChangeType.values[map['type'] as int],
      amountChange: (map['amountChange'] as num?)?.toDouble(),
      transactionId: map['transactionId'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

/// 脏数据标记 - 用于增量计算优化
class DirtyPoolMarker {
  final String poolId;
  final DateTime markedAt;
  final String reason;

  const DirtyPoolMarker({
    required this.poolId,
    required this.markedAt,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'poolId': poolId,
      'markedAt': markedAt.millisecondsSinceEpoch,
      'reason': reason,
    };
  }

  factory DirtyPoolMarker.fromMap(Map<String, dynamic> map) {
    return DirtyPoolMarker(
      poolId: map['poolId'] as String,
      markedAt: DateTime.fromMillisecondsSinceEpoch(map['markedAt'] as int),
      reason: map['reason'] as String,
    );
  }
}

/// 资源池管理器
///
/// 负责：
/// 1. 资源池的持久化存储和读取
/// 2. 增量计算优化（脏数据标记机制）
/// 3. 与 MoneyAgeCalculator 的集成
/// 4. 交易变更时的资源池同步更新
///
/// 核心设计原则：
/// - 收入交易创建资源池
/// - 支出交易消耗资源池
/// - 修改/删除交易需要重新计算受影响的资源池
class ResourcePoolManager {
  final DatabaseService _db;
  final MoneyAgeCalculator _calculator;
  final Logger _logger = Logger();

  /// 脏数据标记列表（需要重新计算的资源池）
  final List<DirtyPoolMarker> _dirtyMarkers = [];

  /// 变更历史（用于调试和审计）
  final List<ResourcePoolChange> _changeHistory = [];

  /// 最后计算时间
  DateTime? _lastCalculatedAt;

  /// 是否需要全量重建
  bool _needsFullRebuild = false;

  ResourcePoolManager({
    DatabaseService? database,
    MoneyAgeCalculator? calculator,
  })  : _db = database ?? DatabaseService(),
        _calculator = calculator ?? MoneyAgeCalculator();

  /// 获取计算器实例
  MoneyAgeCalculator get calculator => _calculator;

  /// 获取脏数据标记列表
  List<DirtyPoolMarker> get dirtyMarkers => List.unmodifiable(_dirtyMarkers);

  /// 是否有脏数据
  bool get hasDirtyData => _dirtyMarkers.isNotEmpty || _needsFullRebuild;

  /// 最后计算时间
  DateTime? get lastCalculatedAt => _lastCalculatedAt;

  /// 初始化：从数据库加载资源池和消耗记录
  Future<void> initialize() async {
    try {
      final pools = await _loadPoolsFromDb();
      final consumptions = await _loadConsumptionsFromDb();

      _calculator.restore(
        pools: pools,
        consumptions: consumptions,
      );

      _lastCalculatedAt = DateTime.now();
      _logger.info('ResourcePoolManager initialized with ${pools.length} pools',
          tag: 'MoneyAge');
    } catch (e) {
      _logger.error('Failed to initialize ResourcePoolManager: $e',
          tag: 'MoneyAge');
      // 标记需要全量重建
      _needsFullRebuild = true;
    }
  }

  /// 从数据库加载资源池
  Future<List<ResourcePool>> _loadPoolsFromDb() async {
    final db = await _db.database;
    final results = await db.query('resource_pools');
    return results.map((row) => ResourcePool.fromMap(row)).toList();
  }

  /// 从数据库加载消耗记录
  Future<List<ResourceConsumption>> _loadConsumptionsFromDb() async {
    final db = await _db.database;
    final results = await db.query('resource_consumptions');
    return results.map((row) => ResourceConsumption.fromMap(row)).toList();
  }

  /// 处理收入交易：创建新资源池
  Future<ResourcePool> onIncomeCreated(Transaction income) async {
    if (income.type != TransactionType.income) {
      throw ArgumentError('Transaction must be income type');
    }

    // 创建资源池
    final pool = _calculator.processIncome(income);

    // 持久化
    await _savePool(pool);

    // 记录变更
    _recordChange(ResourcePoolChange(
      poolId: pool.id,
      type: ResourcePoolChangeType.created,
      amountChange: pool.originalAmount,
      transactionId: income.id,
      timestamp: DateTime.now(),
    ));

    _logger.debug('Created resource pool ${pool.id} for income ${income.id}',
        tag: 'MoneyAge');

    return pool;
  }

  /// 处理支出交易：消耗资源池并计算钱龄
  Future<MoneyAgeResult> onExpenseCreated(Transaction expense) async {
    if (expense.type != TransactionType.expense) {
      throw ArgumentError('Transaction must be expense type');
    }

    // 计算钱龄并消耗资源池
    final result = _calculator.processExpense(expense);

    // 持久化消耗记录
    for (final consumption in result.consumptions) {
      await _saveConsumption(consumption);
    }

    // 更新受影响的资源池
    for (final consumption in result.consumptions) {
      final pool = _calculator.pools.firstWhere(
        (p) => p.id == consumption.resourcePoolId,
        orElse: () => throw StateError('Pool not found: ${consumption.resourcePoolId}'),
      );
      await _updatePool(pool);

      // 记录变更
      _recordChange(ResourcePoolChange(
        poolId: pool.id,
        type: ResourcePoolChangeType.consumed,
        amountChange: -consumption.amount,
        transactionId: expense.id,
        timestamp: DateTime.now(),
      ));
    }

    _logger.debug(
        'Processed expense ${expense.id}, money age: ${result.moneyAge} days',
        tag: 'MoneyAge');

    return result;
  }

  /// 处理交易删除
  Future<void> onTransactionDeleted(Transaction transaction) async {
    if (transaction.type == TransactionType.income) {
      // 删除收入：标记相关资源池为脏数据，需要重建
      await _handleIncomeDeleted(transaction);
    } else if (transaction.type == TransactionType.expense) {
      // 删除支出：恢复已消耗的资源池金额
      await _handleExpenseDeleted(transaction);
    }
  }

  /// 处理收入删除
  Future<void> _handleIncomeDeleted(Transaction income) async {
    // 查找关联的资源池
    final pool = _calculator.pools.firstWhere(
      (p) => p.incomeTransactionId == income.id,
      orElse: () => throw StateError('Pool not found for income: ${income.id}'),
    );

    // 如果资源池已被部分或全部消耗，需要全量重建
    if (pool.consumedAmount > 0) {
      _needsFullRebuild = true;
      _logger.warning(
          'Income ${income.id} deleted but pool was consumed, need full rebuild',
          tag: 'MoneyAge');
    } else {
      // 资源池未被使用，可以直接删除
      await _deletePool(pool.id);

      _recordChange(ResourcePoolChange(
        poolId: pool.id,
        type: ResourcePoolChangeType.deleted,
        amountChange: -pool.originalAmount,
        transactionId: income.id,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// 处理支出删除
  Future<void> _handleExpenseDeleted(Transaction expense) async {
    // 查找关联的消耗记录
    final consumptions = _calculator.consumptions
        .where((c) => c.expenseTransactionId == expense.id)
        .toList();

    if (consumptions.isEmpty) {
      _logger.warning('No consumptions found for expense: ${expense.id}',
          tag: 'MoneyAge');
      return;
    }

    // 恢复每个资源池的金额
    for (final consumption in consumptions) {
      final poolIndex = _calculator.pools.indexWhere(
        (p) => p.id == consumption.resourcePoolId,
      );

      if (poolIndex != -1) {
        // 恢复金额
        _calculator.pools[poolIndex].remainingAmount += consumption.amount;
        await _updatePool(_calculator.pools[poolIndex]);

        // 删除消耗记录
        await _deleteConsumption(consumption.id);

        _recordChange(ResourcePoolChange(
          poolId: consumption.resourcePoolId,
          type: ResourcePoolChangeType.modified,
          amountChange: consumption.amount, // 正数表示恢复
          transactionId: expense.id,
          timestamp: DateTime.now(),
        ));
      }
    }

    _logger.debug(
        'Restored ${consumptions.length} consumptions for deleted expense ${expense.id}',
        tag: 'MoneyAge');
  }

  /// 处理交易修改
  Future<MoneyAgeResult?> onTransactionUpdated(
    Transaction oldTransaction,
    Transaction newTransaction,
  ) async {
    // 如果金额或日期改变，需要重新计算
    if (oldTransaction.amount != newTransaction.amount ||
        oldTransaction.date != newTransaction.date) {
      if (oldTransaction.type == TransactionType.income) {
        // 收入修改：需要全量重建（因为可能影响后续消费）
        _needsFullRebuild = true;
        return null;
      } else if (oldTransaction.type == TransactionType.expense) {
        // 支出修改：先撤销旧消耗，再重新计算
        await onTransactionDeleted(oldTransaction);
        return await onExpenseCreated(newTransaction);
      }
    }
    return null;
  }

  /// 标记资源池为脏数据
  void markDirty(String poolId, String reason) {
    _dirtyMarkers.add(DirtyPoolMarker(
      poolId: poolId,
      markedAt: DateTime.now(),
      reason: reason,
    ));

    _logger.debug('Marked pool $poolId as dirty: $reason', tag: 'MoneyAge');
  }

  /// 清除脏数据标记
  void clearDirtyMarkers() {
    _dirtyMarkers.clear();
    _needsFullRebuild = false;
  }

  /// 执行增量计算（处理脏数据）
  Future<void> processIncrementalUpdate() async {
    if (_needsFullRebuild) {
      await rebuildAll();
      return;
    }

    if (_dirtyMarkers.isEmpty) {
      return;
    }

    // 对每个脏数据池进行重新计算
    for (final marker in _dirtyMarkers) {
      await _recalculatePool(marker.poolId);
    }

    clearDirtyMarkers();
    _lastCalculatedAt = DateTime.now();

    _logger.info('Processed ${_dirtyMarkers.length} dirty pools',
        tag: 'MoneyAge');
  }

  /// 重新计算单个资源池
  Future<void> _recalculatePool(String poolId) async {
    // 这里的实现取决于具体的业务逻辑
    // 通常需要重新计算该池相关的所有消费
    _logger.debug('Recalculating pool: $poolId', tag: 'MoneyAge');
  }

  /// 全量重建：从交易历史重新计算所有钱龄数据
  ///
  /// 使用场景：
  /// 1. 首次使用钱龄功能
  /// 2. 数据损坏需要恢复
  /// 3. 复杂的交易修改导致无法增量更新
  Future<void> rebuildAll() async {
    _logger.info('Starting full rebuild of money age data', tag: 'MoneyAge');

    try {
      // 清除现有数据
      await _clearAllData();
      _calculator.clear();

      // 获取所有交易，按时间排序
      final transactions = await _getAllTransactionsSorted();

      // 按时间顺序处理每笔交易
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.income) {
          await onIncomeCreated(transaction);
        } else if (transaction.type == TransactionType.expense) {
          await onExpenseCreated(transaction);
        }
      }

      clearDirtyMarkers();
      _lastCalculatedAt = DateTime.now();

      _logger.info(
          'Full rebuild completed: ${_calculator.pools.length} pools, '
          '${_calculator.consumptions.length} consumptions',
          tag: 'MoneyAge');
    } catch (e) {
      _logger.error('Full rebuild failed: $e', tag: 'MoneyAge');
      rethrow;
    }
  }

  /// 获取所有交易（按时间排序）
  Future<List<Transaction>> _getAllTransactionsSorted() async {
    final db = await _db.database;
    final results = await db.query(
      'transactions',
      orderBy: 'date ASC, createdAt ASC',
    );

    return results.map((row) => Transaction.fromMap(row)).toList();
  }

  /// 清除所有钱龄相关数据
  Future<void> _clearAllData() async {
    final db = await _db.database;
    await db.delete('resource_pools');
    await db.delete('resource_consumptions');

    _recordChange(ResourcePoolChange(
      poolId: 'all',
      type: ResourcePoolChangeType.rebuilt,
      timestamp: DateTime.now(),
    ));
  }

  /// 保存资源池到数据库
  Future<void> _savePool(ResourcePool pool) async {
    final db = await _db.database;
    await db.insert(
      'resource_pools',
      pool.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新资源池
  Future<void> _updatePool(ResourcePool pool) async {
    final db = await _db.database;
    await db.update(
      'resource_pools',
      pool.toMap(),
      where: 'id = ?',
      whereArgs: [pool.id],
    );
  }

  /// 删除资源池
  Future<void> _deletePool(String poolId) async {
    final db = await _db.database;
    await db.delete(
      'resource_pools',
      where: 'id = ?',
      whereArgs: [poolId],
    );
  }

  /// 保存消耗记录
  Future<void> _saveConsumption(ResourceConsumption consumption) async {
    final db = await _db.database;
    await db.insert(
      'resource_consumptions',
      consumption.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除消耗记录
  Future<void> _deleteConsumption(String consumptionId) async {
    final db = await _db.database;
    await db.delete(
      'resource_consumptions',
      where: 'id = ?',
      whereArgs: [consumptionId],
    );
  }

  /// 记录变更历史
  void _recordChange(ResourcePoolChange change) {
    _changeHistory.add(change);

    // 只保留最近1000条记录
    if (_changeHistory.length > 1000) {
      _changeHistory.removeRange(0, _changeHistory.length - 1000);
    }
  }

  /// 获取变更历史
  List<ResourcePoolChange> getChangeHistory({int? limit}) {
    if (limit != null && limit < _changeHistory.length) {
      return _changeHistory.sublist(_changeHistory.length - limit);
    }
    return List.unmodifiable(_changeHistory);
  }

  /// 获取当前钱龄
  MoneyAge getCurrentMoneyAge() {
    return _calculator.getCurrentMoneyAge();
  }

  /// 获取钱龄统计
  MoneyAgeStatistics getStatistics() {
    return _calculator.getStatistics();
  }

  /// 模拟支出
  MoneyAgeResult simulateExpense(double amount) {
    return _calculator.simulateExpense(amount);
  }

  /// 预测趋势
  List<DailyMoneyAge> predictTrend({
    required int daysAhead,
    required double estimatedDailyExpense,
    List<({double amount, DateTime date})>? expectedIncomes,
  }) {
    return _calculator.predictTrend(
      daysAhead: daysAhead,
      estimatedDailyExpense: estimatedDailyExpense,
      expectedIncomes: expectedIncomes,
    );
  }

  /// 设置消费策略
  void setStrategy(ConsumptionStrategy strategy) {
    _calculator.strategy = strategy;
  }

  /// 获取当前策略
  ConsumptionStrategy get currentStrategy => _calculator.strategy;
}
