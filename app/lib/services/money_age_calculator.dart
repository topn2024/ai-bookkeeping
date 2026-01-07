import 'dart:math';
import '../models/resource_pool.dart';
import '../models/transaction.dart';

/// 消费顺序策略枚举
/// 定义资源池消耗的顺序规则
enum ConsumptionStrategy {
  /// FIFO - 先进先出（默认）
  /// 优先消耗最老的资金，提高整体钱龄
  fifo,

  /// LIFO - 后进先出
  /// 优先消耗最新的资金，保留老资金
  lifo,

  /// 加权平均
  /// 按比例从所有资源池消耗，计算加权平均钱龄
  weightedAverage,
}

extension ConsumptionStrategyExtension on ConsumptionStrategy {
  String get displayName {
    switch (this) {
      case ConsumptionStrategy.fifo:
        return '先进先出';
      case ConsumptionStrategy.lifo:
        return '后进先出';
      case ConsumptionStrategy.weightedAverage:
        return '加权平均';
    }
  }

  String get description {
    switch (this) {
      case ConsumptionStrategy.fifo:
        return '优先使用最老的资金，推荐用于追踪真实财务健康';
      case ConsumptionStrategy.lifo:
        return '优先使用最新的资金，适合保留应急储备';
      case ConsumptionStrategy.weightedAverage:
        return '按比例使用所有资金，适合均衡消费场景';
    }
  }
}

/// 钱龄计算引擎
///
/// 核心功能：
/// 1. 管理资源池（每笔收入创建一个池）
/// 2. 处理收入和支出交易
/// 3. 计算每笔消费的钱龄
/// 4. 支持多种消费顺序策略（FIFO/LIFO/加权平均）
///
/// 使用示例：
/// ```dart
/// final calculator = MoneyAgeCalculator();
/// calculator.processIncome(incomeTransaction);
/// final result = calculator.processExpense(expenseTransaction);
/// print('钱龄: ${result.moneyAge} 天');
/// ```
class MoneyAgeCalculator {
  /// 资源池列表（按创建时间排序）
  final List<ResourcePool> _pools = [];

  /// 消耗记录列表
  final List<ResourceConsumption> _consumptions = [];

  /// 当前使用的消费策略
  ConsumptionStrategy _strategy = ConsumptionStrategy.fifo;

  /// 账本ID过滤（可选，用于多账本场景）
  String? _ledgerFilter;

  /// 账户ID过滤（可选，用于按账户追踪）
  String? _accountFilter;

  /// ID生成计数器
  int _idCounter = 0;

  MoneyAgeCalculator({
    ConsumptionStrategy strategy = ConsumptionStrategy.fifo,
    String? ledgerFilter,
    String? accountFilter,
  })  : _strategy = strategy,
        _ledgerFilter = ledgerFilter,
        _accountFilter = accountFilter;

  /// 获取所有资源池（只读）
  List<ResourcePool> get pools => List.unmodifiable(_pools);

  /// 获取所有消耗记录（只读）
  List<ResourceConsumption> get consumptions => List.unmodifiable(_consumptions);

  /// 获取当前策略
  ConsumptionStrategy get strategy => _strategy;

  /// 设置消费策略
  set strategy(ConsumptionStrategy value) {
    _strategy = value;
  }

  /// 获取账本过滤器
  String? get ledgerFilter => _ledgerFilter;

  /// 设置账本过滤器
  set ledgerFilter(String? value) {
    _ledgerFilter = value;
  }

  /// 获取账户过滤器
  String? get accountFilter => _accountFilter;

  /// 设置账户过滤器
  set accountFilter(String? value) {
    _accountFilter = value;
  }

  /// 生成唯一ID
  String _generateId() {
    _idCounter++;
    return 'pool_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  /// 获取有剩余金额的活跃资源池
  List<ResourcePool> get _activePools =>
      _pools.where((p) => p.hasRemaining).toList();

  /// 总可用余额
  double get totalAvailableBalance =>
      _activePools.fold(0.0, (sum, p) => sum + p.remainingAmount);

  /// 活跃资源池数量
  int get activePoolCount => _activePools.length;

  /// 处理收入：创建新的资源池
  ///
  /// [income] 收入交易
  /// [ledgerId] 可选的账本ID
  /// [accountId] 可选的账户ID
  ///
  /// 返回创建的资源池
  ResourcePool processIncome(
    Transaction income, {
    String? ledgerId,
    String? accountId,
  }) {
    if (income.type != TransactionType.income) {
      throw ArgumentError('Transaction must be of type income');
    }

    final pool = ResourcePool(
      id: _generateId(),
      incomeTransactionId: income.id,
      createdAt: income.date,
      originalAmount: income.amount,
      remainingAmount: income.amount,
      ledgerId: ledgerId,
      accountId: accountId,
    );

    _pools.add(pool);
    _sortPoolsByStrategy();

    return pool;
  }

  /// 批量处理收入交易
  ///
  /// [incomes] 收入交易列表
  /// 返回创建的资源池列表
  List<ResourcePool> processIncomes(List<Transaction> incomes) {
    final result = <ResourcePool>[];
    for (final income in incomes) {
      if (income.type == TransactionType.income) {
        result.add(processIncome(income));
      }
    }
    return result;
  }

  /// 处理支出：按策略消耗资源池并计算钱龄
  ///
  /// [expense] 支出交易
  ///
  /// 返回钱龄计算结果，包含：
  /// - 加权平均钱龄
  /// - 消耗详情列表
  /// - 覆盖/未覆盖金额
  MoneyAgeResult processExpense(Transaction expense) {
    if (expense.type != TransactionType.expense) {
      throw ArgumentError('Transaction must be of type expense');
    }

    switch (_strategy) {
      case ConsumptionStrategy.fifo:
        return _processWithFIFO(expense);
      case ConsumptionStrategy.lifo:
        return _processWithLIFO(expense);
      case ConsumptionStrategy.weightedAverage:
        return _processWithWeightedAverage(expense);
    }
  }

  /// FIFO策略：先进先出
  ///
  /// 优先消耗最早创建的资源池（钱龄最高）
  MoneyAgeResult _processWithFIFO(Transaction expense) {
    // 按创建时间升序排列（最老的在前）
    final sortedPools = _getFilteredPools()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return _consumePools(sortedPools, expense);
  }

  /// LIFO策略：后进先出
  ///
  /// 优先消耗最近创建的资源池（钱龄最低）
  MoneyAgeResult _processWithLIFO(Transaction expense) {
    // 按创建时间降序排列（最新的在前）
    final sortedPools = _getFilteredPools()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return _consumePools(sortedPools, expense);
  }

  /// 加权平均策略
  ///
  /// 按比例从所有资源池消耗，每个池消耗的比例与其余额占总余额的比例相同
  MoneyAgeResult _processWithWeightedAverage(Transaction expense) {
    final activePools = _getFilteredPools().where((p) => p.hasRemaining).toList();

    if (activePools.isEmpty) {
      return MoneyAgeResult(
        transactionId: expense.id,
        moneyAge: 0,
        consumptions: const [],
        totalAmount: expense.amount,
        coveredAmount: 0,
        uncoveredAmount: expense.amount,
      );
    }

    final totalAvailable =
        activePools.fold(0.0, (sum, p) => sum + p.remainingAmount);
    final consumptions = <ResourceConsumption>[];
    var totalConsumed = 0.0;

    // 按比例分配消耗金额
    for (final pool in activePools) {
      final ratio = pool.remainingAmount / totalAvailable;
      var consumeAmount = expense.amount * ratio;

      // 不能超过池的剩余金额
      consumeAmount = min(consumeAmount, pool.remainingAmount);

      if (consumeAmount > 0) {
        final consumption = pool.consume(consumeAmount, expense.id);
        consumptions.add(consumption);
        _consumptions.add(consumption);
        totalConsumed += consumeAmount;
      }
    }

    // 计算加权平均钱龄
    final weightedAge = _calculateWeightedAge(consumptions, totalConsumed);

    return MoneyAgeResult(
      transactionId: expense.id,
      moneyAge: weightedAge,
      consumptions: consumptions,
      totalAmount: expense.amount,
      coveredAmount: totalConsumed,
      uncoveredAmount: expense.amount - totalConsumed,
    );
  }

  /// 按顺序消耗资源池（用于FIFO和LIFO）
  MoneyAgeResult _consumePools(List<ResourcePool> sortedPools, Transaction expense) {
    final consumptions = <ResourceConsumption>[];
    var remaining = expense.amount;

    for (final pool in sortedPools) {
      if (remaining <= 0) break;
      if (pool.remainingAmount <= 0) continue;

      final consumption = pool.consume(remaining, expense.id);
      consumptions.add(consumption);
      _consumptions.add(consumption);
      remaining -= consumption.amount;
    }

    // 计算覆盖金额
    final coveredAmount =
        consumptions.fold(0.0, (sum, c) => sum + c.amount);

    // 计算加权平均钱龄
    final weightedAge = _calculateWeightedAge(consumptions, coveredAmount);

    return MoneyAgeResult(
      transactionId: expense.id,
      moneyAge: weightedAge,
      consumptions: consumptions,
      totalAmount: expense.amount,
      coveredAmount: coveredAmount,
      uncoveredAmount: expense.amount - coveredAmount,
    );
  }

  /// 计算加权平均钱龄
  int _calculateWeightedAge(List<ResourceConsumption> consumptions, double totalAmount) {
    if (consumptions.isEmpty || totalAmount <= 0) return 0;

    final weightedSum = consumptions.fold(
      0.0,
      (sum, c) => sum + c.amount * c.moneyAge,
    );

    return (weightedSum / totalAmount).round();
  }

  /// 获取经过过滤的资源池列表
  List<ResourcePool> _getFilteredPools() {
    var filtered = _pools.where((p) => p.hasRemaining);

    if (_ledgerFilter != null) {
      filtered = filtered.where((p) => p.ledgerId == _ledgerFilter);
    }

    if (_accountFilter != null) {
      filtered = filtered.where((p) => p.accountId == _accountFilter);
    }

    return filtered.toList();
  }

  /// 根据当前策略排序资源池
  void _sortPoolsByStrategy() {
    switch (_strategy) {
      case ConsumptionStrategy.fifo:
        _pools.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ConsumptionStrategy.lifo:
        _pools.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ConsumptionStrategy.weightedAverage:
        // 加权平均不需要特定排序，按创建时间即可
        _pools.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }
  }

  /// 计算当前平均钱龄
  ///
  /// 基于所有活跃资源池的加权平均钱龄
  MoneyAge getCurrentMoneyAge() {
    final activePools = _activePools;
    if (activePools.isEmpty) {
      return const MoneyAge(days: 0);
    }

    final totalBalance =
        activePools.fold(0.0, (sum, p) => sum + p.remainingAmount);
    final weightedAge = activePools.fold(
      0.0,
      (sum, p) => sum + p.remainingAmount * p.ageInDays,
    );

    return MoneyAge(days: (weightedAge / totalBalance).round());
  }

  /// 获取钱龄统计信息
  MoneyAgeStatistics getStatistics() {
    final activePools = _activePools;
    final currentAge = getCurrentMoneyAge();

    // 按分类计算钱龄分布（需要交易信息，这里简化处理）
    final ageByCategory = <String, int>{};
    final ageByAccount = <String, int>{};

    // 按账户分组计算
    for (final pool in activePools) {
      if (pool.accountId != null) {
        ageByAccount[pool.accountId!] = pool.ageInDays;
      }
    }

    return MoneyAgeStatistics(
      averageAge: currentAge.days,
      trend: const [], // 趋势需要历史数据，由其他服务计算
      ageByCategory: ageByCategory,
      ageByAccount: ageByAccount,
      totalResourcePoolBalance: totalAvailableBalance,
      activePoolCount: activePoolCount,
      calculatedAt: DateTime.now(),
    );
  }

  /// 模拟支出对钱龄的影响（不实际消耗）
  ///
  /// [amount] 支出金额
  /// 返回预计的钱龄结果
  MoneyAgeResult simulateExpense(double amount) {
    final fakeExpense = Transaction(
      id: 'simulation_${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.expense,
      amount: amount,
      category: 'simulation',
      date: DateTime.now(),
      accountId: 'simulation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 创建池的副本进行模拟
    final simulatedPools = _pools.map((p) => p.copyWith()).toList();
    final consumptions = <ResourceConsumption>[];
    var remaining = amount;

    // 按当前策略排序
    switch (_strategy) {
      case ConsumptionStrategy.fifo:
        simulatedPools.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ConsumptionStrategy.lifo:
        simulatedPools.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ConsumptionStrategy.weightedAverage:
        // 加权平均的模拟更复杂，这里简化为FIFO
        simulatedPools.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    for (final pool in simulatedPools) {
      if (remaining <= 0) break;
      if (pool.remainingAmount <= 0) continue;

      final consumed = min(remaining, pool.remainingAmount);
      consumptions.add(ResourceConsumption(
        id: 'sim_${pool.id}',
        resourcePoolId: pool.id,
        expenseTransactionId: fakeExpense.id,
        amount: consumed,
        moneyAge: pool.ageInDays,
        consumedAt: DateTime.now(),
      ));
      remaining -= consumed;
    }

    final coveredAmount = consumptions.fold(0.0, (sum, c) => sum + c.amount);
    final weightedAge = _calculateWeightedAge(consumptions, coveredAmount);

    return MoneyAgeResult(
      transactionId: fakeExpense.id,
      moneyAge: weightedAge,
      consumptions: consumptions,
      totalAmount: amount,
      coveredAmount: coveredAmount,
      uncoveredAmount: amount - coveredAmount,
    );
  }

  /// 预测未来钱龄趋势
  ///
  /// [daysAhead] 预测天数
  /// [estimatedDailyExpense] 预估每日支出
  /// [expectedIncomes] 预期收入列表（金额和日期）
  ///
  /// 返回每日预测钱龄列表
  List<DailyMoneyAge> predictTrend({
    required int daysAhead,
    required double estimatedDailyExpense,
    List<({double amount, DateTime date})>? expectedIncomes,
  }) {
    final predictions = <DailyMoneyAge>[];

    // 创建资源池副本用于模拟
    var simulatedPools = _pools.map((p) => p.copyWith()).toList();
    final today = DateTime.now();

    for (var i = 0; i < daysAhead; i++) {
      final targetDate = today.add(Duration(days: i));

      // 检查是否有预期收入
      if (expectedIncomes != null) {
        for (final income in expectedIncomes) {
          if (_isSameDay(income.date, targetDate)) {
            simulatedPools.add(ResourcePool(
              id: 'pred_${targetDate.millisecondsSinceEpoch}',
              incomeTransactionId: 'predicted',
              createdAt: targetDate,
              originalAmount: income.amount,
              remainingAmount: income.amount,
            ));
          }
        }
      }

      // 模拟每日支出
      var dailyExpenseRemaining = estimatedDailyExpense;
      simulatedPools.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final pool in simulatedPools) {
        if (dailyExpenseRemaining <= 0) break;
        if (pool.remainingAmount <= 0) continue;

        final consumed = min(dailyExpenseRemaining, pool.remainingAmount);
        pool.remainingAmount -= consumed;
        dailyExpenseRemaining -= consumed;
      }

      // 计算当日加权平均钱龄
      final activePools = simulatedPools.where((p) => p.remainingAmount > 0).toList();
      var avgAge = 0;

      if (activePools.isNotEmpty) {
        final totalBalance =
            activePools.fold(0.0, (sum, p) => sum + p.remainingAmount);
        final weightedAge = activePools.fold(
          0.0,
          (sum, p) =>
              sum +
              p.remainingAmount *
                  targetDate.difference(p.createdAt).inDays,
        );
        avgAge = (weightedAge / totalBalance).round();
      }

      final level = _getLevelFromDays(avgAge);
      predictions.add(DailyMoneyAge(
        date: targetDate,
        averageAge: avgAge,
        level: level,
      ));
    }

    return predictions;
  }

  /// 根据天数获取健康等级
  MoneyAgeLevel _getLevelFromDays(int days) {
    if (days < 7) return MoneyAgeLevel.danger;
    if (days < 14) return MoneyAgeLevel.warning;
    if (days < 30) return MoneyAgeLevel.normal;
    if (days < 60) return MoneyAgeLevel.good;
    if (days < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }

  /// 判断两个日期是否是同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 清除所有数据
  void clear() {
    _pools.clear();
    _consumptions.clear();
    _idCounter = 0;
  }

  /// 从持久化数据恢复状态
  ///
  /// [pools] 资源池列表
  /// [consumptions] 消耗记录列表
  void restore({
    required List<ResourcePool> pools,
    List<ResourceConsumption>? consumptions,
  }) {
    _pools.clear();
    _pools.addAll(pools);
    _sortPoolsByStrategy();

    if (consumptions != null) {
      _consumptions.clear();
      _consumptions.addAll(consumptions);
    }
  }

  /// 导出当前状态（用于持久化）
  Map<String, dynamic> export() {
    return {
      'pools': _pools.map((p) => p.toMap()).toList(),
      'consumptions': _consumptions.map((c) => c.toMap()).toList(),
      'strategy': _strategy.index,
      'ledgerFilter': _ledgerFilter,
      'accountFilter': _accountFilter,
    };
  }

  /// 从导出数据导入状态
  factory MoneyAgeCalculator.fromExport(Map<String, dynamic> data) {
    final calculator = MoneyAgeCalculator(
      strategy: ConsumptionStrategy.values[data['strategy'] as int? ?? 0],
      ledgerFilter: data['ledgerFilter'] as String?,
      accountFilter: data['accountFilter'] as String?,
    );

    final poolsData = data['pools'] as List<dynamic>? ?? [];
    final consumptionsData = data['consumptions'] as List<dynamic>? ?? [];

    calculator._pools.addAll(
      poolsData.map((p) => ResourcePool.fromMap(p as Map<String, dynamic>)),
    );
    calculator._consumptions.addAll(
      consumptionsData
          .map((c) => ResourceConsumption.fromMap(c as Map<String, dynamic>)),
    );

    return calculator;
  }
}

/// 钱龄计算结果扩展
extension MoneyAgeResultExtension on MoneyAgeResult {
  /// 获取消耗来源描述
  String get consumptionSummary {
    if (consumptions.isEmpty) {
      return '无资金来源';
    }

    if (consumptions.length == 1) {
      return '来自${consumptions.first.moneyAge}天前的收入';
    }

    final ages = consumptions.map((c) => c.moneyAge).toList()..sort();
    return '来自${ages.first}-${ages.last}天前的多笔收入';
  }

  /// 钱龄是否健康
  bool get isHealthy => moneyAge >= 14;

  /// 获取钱龄建议
  String get suggestion {
    if (hasUncovered) {
      return '部分支出未被资金覆盖，建议增加收入或减少支出';
    }

    switch (level) {
      case MoneyAgeLevel.danger:
        return '您正在花费刚收到的钱，建议建立储蓄缓冲';
      case MoneyAgeLevel.warning:
        return '资金周转较紧张，建议控制非必要支出';
      case MoneyAgeLevel.normal:
        return '资金状况尚可，继续保持';
      case MoneyAgeLevel.good:
        return '资金周转良好，财务健康';
      case MoneyAgeLevel.excellent:
        return '资金状况优秀，可以考虑投资理财';
      case MoneyAgeLevel.ideal:
        return '财务状况理想，继续保持良好习惯';
    }
  }
}
