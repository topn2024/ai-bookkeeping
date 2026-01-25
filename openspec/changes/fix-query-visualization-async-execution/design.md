# 设计文档：查询可视化异步执行架构

## 1. 问题域分析

### 1.1 当前架构

```
用户语音输入
    ↓
InputPipeline (接收语音)
    ↓
IntelligenceEngine (意图识别)
    ↓ (立即返回自然语言响应)
DualChannelProcessor
    ├─ ConversationChannel (对话管理)
    └─ ExecutionChannel (异步执行)
           ↓
    BookkeepingOperationAdapter (执行查询)
           ↓
    ResultBuffer (存储结果)
```

**关键特征**：
- **异步执行**：IntelligenceEngine 立即返回，实际操作在 ExecutionChannel 中异步执行
- **结果存储**：查询结果存储在 ResultBuffer 中，不直接返回给调用者
- **双通道设计**：对话和执行分离，提高响应速度

### 1.2 问题根源

**问题1：数据提取时机错误**

```dart
// main.dart 中的命令处理器
final result = await coordinator.processVoiceCommand(command);
// ↑ 此时返回的是 IntelligenceEngine 的响应，不包含查询结果

final cardData = result.data['cardData'];  // ← null
```

**时序图**：
```
T0: 用户说"本月餐饮花了多少钱"
T1: IntelligenceEngine 返回"好的，我来查一下" ← main.dart 在这里提取数据
T2: ExecutionChannel 开始执行查询
T3: 查询完成，结果存入 ResultBuffer
T4: UI 需要显示卡片，但数据已经错过
```

**问题2：数据库查询依赖不存在的列**

```dart
// database_voice_extension.dart
whereConditions.add('(category LIKE ? OR sub_category LIKE ?)');
// ↑ sub_category 列不存在
```

**根本原因**：
- 设计假设：数据库有完整的预计算字段
- 现实情况：用户需求多样，无法预存所有数据
- 正确方向：动态计算查询结果

## 2. 解决方案设计

### 2.1 整体架构

```
用户语音输入
    ↓
InputPipeline
    ↓
IntelligenceEngine (返回"好的")
    ↓
DualChannelProcessor
    ├─ ConversationChannel
    └─ ExecutionChannel
           ↓
    BookkeepingOperationAdapter
           ↓
    QueryCalculator (动态计算) ← 新增
           ↓
    ResultBuffer (存储结果 + 通知监听器) ← 增强
           ↓
    监听器回调 ← 新增
           ↓
    GlobalVoiceAssistantManager.updateLastMessageMetadata() ← 新增
           ↓
    UI 自动更新 (通过 ChangeNotifier)
```

### 2.2 核心组件设计

#### 2.2.1 ResultBuffer 监听机制

**设计目标**：
- 在查询结果存入时通知监听者
- 支持多个监听器
- 自动清理过期监听器

**接口设计**：
```dart
class ResultBuffer {
  // 监听器存储：operationId -> 回调列表
  final Map<String, List<ResultListener>> _listeners = {};

  // 监听器超时管理
  final Map<String, Timer> _timeouts = {};

  /// 添加监听器
  void addListener(String operationId, ResultListener callback) {
    _listeners.putIfAbsent(operationId, () => []).add(callback);

    // 设置30秒超时
    _timeouts[operationId] = Timer(Duration(seconds: 30), () {
      _listeners.remove(operationId);
      debugPrint('[ResultBuffer] 监听器超时清理: $operationId');
    });
  }

  /// 移除监听器
  void removeListener(String operationId) {
    _listeners.remove(operationId);
    _timeouts[operationId]?.cancel();
    _timeouts.remove(operationId);
  }

  /// 通知监听器
  void notifyResult(String operationId, ExecutionResult result) {
    final listeners = _listeners[operationId];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(result);
        } catch (e) {
          debugPrint('[ResultBuffer] 监听器回调异常: $e');
        }
      }
    }

    // 清理
    removeListener(operationId);
  }

  /// 存储结果（增强版）
  void storeResult(String operationId, ExecutionResult result) {
    _results[operationId] = result;

    // 通知监听器
    notifyResult(operationId, result);
  }
}

typedef ResultListener = void Function(ExecutionResult result);
```

**关键设计决策**：
- **超时机制**：防止监听器泄漏，30秒后自动清理
- **异常隔离**：单个监听器异常不影响其他监听器
- **一次性通知**：通知后立即清理，避免重复通知

#### 2.2.2 QueryCalculator 动态计算引擎

**设计目标**：
- 从原始交易数据动态计算查询结果
- 不依赖固定数据库列
- 支持多种查询类型

**架构设计**：
```dart
class QueryCalculator {
  final DatabaseService _database;

  /// 计算查询结果
  Future<QueryResult> calculate(QueryRequest request) async {
    // 1. 获取原始交易数据
    final transactions = await _fetchTransactions(request);

    // 2. 根据查询类型选择计算策略
    final calculator = _getCalculator(request.queryType);

    // 3. 执行计算
    return calculator.calculate(transactions, request);
  }

  /// 获取交易数据
  Future<List<Transaction>> _fetchTransactions(QueryRequest request) async {
    final db = await _database.database;

    // 构建查询条件
    final where = <String>[];
    final whereArgs = <dynamic>[];

    // 时间范围
    if (request.timeRange != null) {
      where.add('date >= ? AND date <= ?');
      whereArgs.add(request.timeRange!.start.toIso8601String());
      whereArgs.add(request.timeRange!.end.toIso8601String());
    }

    // 分类过滤
    if (request.category != null) {
      where.add('category = ?');
      whereArgs.add(request.category);
    }

    // 交易类型
    if (request.transactionType != null) {
      where.add('type = ?');
      whereArgs.add(request.transactionType!.index);
    }

    // 执行查询
    final results = await db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return results.map((row) => Transaction.fromMap(row)).toList();
  }

  /// 获取计算器
  QueryCalculatorStrategy _getCalculator(QueryType type) {
    switch (type) {
      case QueryType.categoryExpense:
        return CategoryExpenseCalculator();
      case QueryType.timeRangeSummary:
        return TimeRangeSummaryCalculator();
      case QueryType.trendAnalysis:
        return TrendAnalysisCalculator();
      default:
        return SimpleQueryCalculator();
    }
  }
}
```

**计算策略接口**：
```dart
abstract class QueryCalculatorStrategy {
  QueryResult calculate(List<Transaction> transactions, QueryRequest request);
}

/// 分类支出计算器
class CategoryExpenseCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(List<Transaction> transactions, QueryRequest request) {
    // 过滤支出交易
    final expenses = transactions.where((t) => t.type == TransactionType.expense);

    // 计算总支出
    final totalExpense = expenses.fold<double>(0, (sum, t) => sum + t.amount);

    // 计算分类支出
    final categoryExpense = expenses
        .where((t) => t.category == request.category)
        .fold<double>(0, (sum, t) => sum + t.amount);

    // 计算占比
    final percentage = totalExpense > 0 ? (categoryExpense / totalExpense) * 100 : 0;

    return QueryResult(
      totalExpense: categoryExpense,
      totalIncome: 0,
      transactionCount: expenses.where((t) => t.category == request.category).length,
      percentage: percentage,
      calculatedAt: DateTime.now(),
    );
  }
}

/// 趋势分析计算器
class TrendAnalysisCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(List<Transaction> transactions, QueryRequest request) {
    // 按日期分组
    final groupedByDate = <DateTime, double>{};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final date = DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        );
        groupedByDate[date] = (groupedByDate[date] ?? 0) + transaction.amount;
      }
    }

    // 生成趋势数据点
    final dataPoints = groupedByDate.entries
        .map((e) => DataPoint(
              label: DateFormat('MM-dd').format(e.key),
              value: e.value,
            ))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return QueryResult(
      totalExpense: transactions
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount),
      totalIncome: transactions
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount),
      transactionCount: transactions.length,
      trendData: dataPoints,
      calculatedAt: DateTime.now(),
    );
  }
}
```

**关键设计决策**：
- **策略模式**：不同查询类型使用不同计算策略，易于扩展
- **内存计算**：将数据加载到内存计算，避免复杂 SQL
- **时间范围限制**：通过 WHERE 条件限制数据量，避免加载过多数据

#### 2.2.3 GlobalVoiceAssistantManager 元数据更新

**设计目标**：
- 支持延迟更新消息元数据
- 触发 UI 自动刷新
- 线程安全

**接口设计**：
```dart
class GlobalVoiceAssistantManager extends ChangeNotifier {
  final List<ChatMessage> _messages = [];

  /// 更新最后一条助手消息的元数据
  void updateLastMessageMetadata(Map<String, dynamic> metadata) {
    final lastAssistantMessage = _findLastAssistantMessage();

    if (lastAssistantMessage != null) {
      // 创建新的消息对象（不可变模式）
      final updatedMessage = lastAssistantMessage.copyWith(
        metadata: {
          ...?lastAssistantMessage.metadata,
          ...metadata,
        },
      );

      // 替换消息
      final index = _messages.indexOf(lastAssistantMessage);
      _messages[index] = updatedMessage;

      // 通知 UI 更新
      notifyListeners();

      debugPrint('[GlobalVoiceAssistant] 已更新消息元数据: ${metadata.keys.join(", ")}');
    } else {
      debugPrint('[GlobalVoiceAssistant] 未找到助手消息，无法更新元数据');
    }
  }

  /// 查找最后一条助手消息
  ChatMessage? _findLastAssistantMessage() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].type == ChatMessageType.assistant) {
        return _messages[i];
      }
    }
    return null;
  }
}
```

**关键设计决策**：
- **不可变模式**：使用 `copyWith` 创建新消息，避免直接修改
- **ChangeNotifier**：自动触发 UI 更新
- **向后查找**：从最后一条消息开始查找，提高效率

### 2.3 数据流设计

#### 2.3.1 完整数据流

```
T0: 用户说"本月餐饮花了多少钱"
    ↓
T1: InputPipeline 接收语音
    ↓
T2: IntelligenceEngine 识别意图
    - 返回: "好的，我来查一下"
    - 生成: operationId = "query_123"
    ↓
T3: main.dart 命令处理器
    - 注册监听器: resultBuffer.addListener("query_123", callback)
    - 添加助手消息: "好的，我来查一下"
    ↓
T4: ExecutionChannel 异步执行
    ↓
T5: BookkeepingOperationAdapter 执行查询
    - 调用: QueryCalculator.calculate()
    ↓
T6: QueryCalculator 动态计算
    - 获取交易数据
    - 计算分类支出
    - 计算占比
    - 生成 cardData
    ↓
T7: 查询完成，存储结果
    - resultBuffer.storeResult("query_123", result)
    ↓
T8: ResultBuffer 通知监听器
    - 调用: callback(result)
    ↓
T9: 监听器回调
    - 提取: cardData, chartData
    - 调用: GlobalVoiceAssistantManager.updateLastMessageMetadata()
    ↓
T10: GlobalVoiceAssistantManager 更新消息
    - 查找最后一条助手消息
    - 更新 metadata
    - 调用: notifyListeners()
    ↓
T11: UI 自动刷新
    - EnhancedVoiceAssistantPage 重建
    - 渲染 LightweightQueryCard
```

#### 2.3.2 错误处理流

```
查询失败场景：
T5: BookkeepingOperationAdapter 执行查询
    ↓ (异常)
T6: 捕获异常
    - 记录日志
    - 返回: ExecutionResult.failure(error: "查询失败")
    ↓
T7: ResultBuffer 存储失败结果
    - resultBuffer.storeResult("query_123", failureResult)
    ↓
T8: 监听器回调
    - 检查: result.status == ExecutionStatus.failure
    - 不更新元数据
    - 可选: 显示错误提示
```

### 2.4 性能优化设计

#### 2.4.1 查询性能优化

**问题**：动态计算可能导致性能问题

**优化策略**：

1. **时间范围限制**
```dart
Future<List<Transaction>> _fetchTransactions(QueryRequest request) async {
  // 限制最多查询1年数据
  final maxRange = Duration(days: 365);
  if (request.timeRange != null &&
      request.timeRange!.end.difference(request.timeRange!.start) > maxRange) {
    throw QueryException('查询时间范围不能超过1年');
  }
  // ...
}
```

2. **数据采样**
```dart
List<Transaction> _sampleTransactions(List<Transaction> transactions) {
  const maxDataPoints = 1000;
  if (transactions.length <= maxDataPoints) {
    return transactions;
  }

  // 均匀采样
  final step = transactions.length / maxDataPoints;
  final sampled = <Transaction>[];
  for (int i = 0; i < maxDataPoints; i++) {
    sampled.add(transactions[(i * step).floor()]);
  }
  return sampled;
}
```

3. **结果缓存**
```dart
class QueryCalculator {
  final Map<String, CachedResult> _cache = {};

  Future<QueryResult> calculate(QueryRequest request) async {
    final cacheKey = _generateCacheKey(request);

    // 检查缓存
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.result;
    }

    // 计算
    final result = await _doCalculate(request);

    // 缓存结果（5分钟有效期）
    _cache[cacheKey] = CachedResult(
      result: result,
      expiresAt: DateTime.now().add(Duration(minutes: 5)),
    );

    return result;
  }
}
```

#### 2.4.2 内存优化

**问题**：监听器可能导致内存泄漏

**优化策略**：

1. **超时清理**
```dart
void addListener(String operationId, ResultListener callback) {
  // ...

  // 30秒后自动清理
  _timeouts[operationId] = Timer(Duration(seconds: 30), () {
    removeListener(operationId);
  });
}
```

2. **弱引用**（如果 Dart 支持）
```dart
// 使用 WeakReference 避免循环引用
class ResultBuffer {
  final Map<String, List<WeakReference<ResultListener>>> _listeners = {};
  // ...
}
```

3. **定期清理**
```dart
void _startPeriodicCleanup() {
  Timer.periodic(Duration(minutes: 5), (_) {
    final now = DateTime.now();
    _cache.removeWhere((key, value) => value.expiresAt.isBefore(now));
  });
}
```

## 3. 实施细节

### 3.1 operationId 生成

**方案1：UUID**
```dart
import 'package:uuid/uuid.dart';

final operationId = Uuid().v4();
```

**方案2：时间戳 + 随机数**
```dart
final operationId = 'query_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
```

**推荐**：方案2，无需额外依赖

### 3.2 线程安全

**问题**：多个查询并发执行时可能冲突

**解决方案**：
```dart
import 'package:synchronized/synchronized.dart';

class GlobalVoiceAssistantManager extends ChangeNotifier {
  final _lock = Lock();

  void updateLastMessageMetadata(Map<String, dynamic> metadata) async {
    await _lock.synchronized(() {
      // 原有逻辑
    });
  }
}
```

### 3.3 日志跟踪

**设计目标**：完整跟踪查询生命周期

**日志点**：
```dart
// T1: 命令接收
debugPrint('[App] 接收语音命令: $command, operationId: $operationId');

// T3: 注册监听器
debugPrint('[App] 注册查询监听器: $operationId');

// T5: 开始查询
debugPrint('[QueryCalculator] 开始计算查询: $operationId, type: ${request.queryType}');

// T6: 查询完成
debugPrint('[QueryCalculator] 查询完成: $operationId, 耗时: ${elapsed}ms');

// T8: 通知监听器
debugPrint('[ResultBuffer] 通知监听器: $operationId');

// T9: 更新元数据
debugPrint('[GlobalVoiceAssistant] 更新元数据: $operationId, keys: ${metadata.keys}');

// T11: UI 刷新
debugPrint('[EnhancedVoiceAssistantPage] 渲染可视化组件: cardData=${cardData != null}, chartData=${chartData != null}');
```

## 4. 测试策略

### 4.1 单元测试

**ResultBuffer 测试**：
```dart
test('监听器应该在结果存储时被通知', () async {
  final buffer = ResultBuffer();
  var notified = false;

  buffer.addListener('test_op', (result) {
    notified = true;
  });

  buffer.storeResult('test_op', ExecutionResult.success());

  expect(notified, true);
});

test('监听器应该在30秒后自动清理', () async {
  final buffer = ResultBuffer();
  var notified = false;

  buffer.addListener('test_op', (result) {
    notified = true;
  });

  await Future.delayed(Duration(seconds: 31));

  buffer.storeResult('test_op', ExecutionResult.success());

  expect(notified, false);
});
```

**QueryCalculator 测试**：
```dart
test('应该正确计算分类支出', () async {
  final calculator = QueryCalculator(mockDatabase);

  final result = await calculator.calculate(QueryRequest(
    queryType: QueryType.categoryExpense,
    category: '餐饮',
    timeRange: TimeRange(
      start: DateTime(2024, 1, 1),
      end: DateTime(2024, 1, 31),
    ),
  ));

  expect(result.totalExpense, 2180.0);
  expect(result.percentage, closeTo(28.5, 0.1));
});
```

### 4.2 集成测试

**端到端测试**：
```dart
testWidgets('查询应该显示卡片', (tester) async {
  await tester.pumpWidget(MyApp());

  // 输入语音命令
  await tester.enterText(find.byType(TextField), '本月餐饮花了多少钱');
  await tester.tap(find.byIcon(Icons.send));

  // 等待查询完成
  await tester.pumpAndSettle(Duration(seconds: 3));

  // 验证卡片显示
  expect(find.byType(LightweightQueryCard), findsOneWidget);
});
```

### 4.3 性能测试

**查询性能测试**：
```dart
test('查询应该在2秒内完成', () async {
  final calculator = QueryCalculator(database);

  final stopwatch = Stopwatch()..start();

  await calculator.calculate(complexQueryRequest);

  stopwatch.stop();

  expect(stopwatch.elapsedMilliseconds, lessThan(2000));
});
```

## 5. 风险评估

### 5.1 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 监听器内存泄漏 | 高 | 中 | 超时清理 + 定期清理 |
| 查询性能问题 | 中 | 中 | 时间范围限制 + 数据采样 + 缓存 |
| 并发冲突 | 中 | 低 | 使用 Lock 保护关键区域 |
| UI 更新失败 | 低 | 低 | 异常捕获 + 日志跟踪 |

### 5.2 业务风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 查询结果不准确 | 高 | 低 | 充分的单元测试 + 人工验证 |
| 用户体验下降 | 中 | 低 | 性能测试 + 用户测试 |
| 破坏现有功能 | 高 | 低 | 回归测试 + 渐进式发布 |

## 6. 后续优化方向

### 6.1 查询缓存优化
- 实现分布式缓存（Redis）
- 智能缓存失效策略
- 缓存预热

### 6.2 查询性能监控
- 记录查询耗时
- 慢查询告警
- 性能分析报告

### 6.3 查询类型扩展
- 支持更多查询类型
- 自定义查询语法
- 查询模板

### 6.4 可视化增强
- 更多图表类型
- 交互式数据探索
- 数据导出功能
