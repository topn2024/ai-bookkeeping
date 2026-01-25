# 规范：动态查询计算引擎

## 概述

本规范定义了基于原始交易数据的动态查询计算引擎，替代依赖固定数据库列的查询方式，支持灵活多样的查询需求。

## 背景

**问题**：
- 当前查询依赖 `sub_category` 等不存在的数据库列
- 用户需求多样，无法预存所有查询结果
- 固定列设计限制了查询灵活性

**解决方案**：
- 从数据库获取原始交易数据
- 在内存中动态计算查询结果
- 支持任意维度的查询组合

## 新增需求

### 需求：移除固定列依赖

**目标**：系统必须移除对不存在数据库列的依赖，使用动态计算替代

#### 场景：移除 sub_category 查询

**前置条件**：
- 代码中存在 `sub_category` 列的查询

**操作**：
```dart
// 修改前
whereConditions.add('(category LIKE ? OR sub_category LIKE ?)');
whereArgs.addAll([categoryPattern, categoryPattern]);

// 修改后
whereConditions.add('category LIKE ?');
whereArgs.add(categoryPattern);
```

**预期结果**：
- 查询不再引用 `sub_category` 列
- 查询正常执行，无数据库错误
- 查询结果正确

**验收标准**：
- [ ] 审查所有 SQL 查询，移除 `sub_category` 引用
- [ ] 运行查询测试，确保无 DatabaseException
- [ ] 查询结果与预期一致

### 需求：QueryCalculator 实现

**目标**：系统必须实现基于原始交易数据的动态查询计算引擎

#### 场景：计算分类支出

**前置条件**：
- 数据库中存在交易记录
- 用户查询"本月餐饮花了多少钱"

**操作**：
```dart
final calculator = QueryCalculator(database);

final result = await calculator.calculate(QueryRequest(
  queryType: QueryType.categoryExpense,
  category: '餐饮',
  timeRange: TimeRange(
    start: DateTime(2024, 1, 1),
    end: DateTime(2024, 1, 31),
  ),
));
```

**预期结果**：
- 返回 QueryResult 包含：
  - `totalExpense`: 餐饮总支出
  - `percentage`: 占总支出的百分比
  - `transactionCount`: 交易笔数
- 计算结果准确
- 响应时间 < 2秒

**验收标准**：
- [ ] `calculate()` 方法接受 QueryRequest
- [ ] 从数据库获取指定时间范围的交易数据
- [ ] 过滤指定分类的支出交易
- [ ] 计算总额、占比、笔数
- [ ] 返回 QueryResult 对象

#### 场景：计算时间范围汇总

**前置条件**：
- 用户查询"本月总支出"

**操作**：
```dart
final result = await calculator.calculate(QueryRequest(
  queryType: QueryType.timeRangeSummary,
  timeRange: TimeRange(
    start: DateTime(2024, 1, 1),
    end: DateTime(2024, 1, 31),
  ),
));
```

**预期结果**：
- 返回 QueryResult 包含：
  - `totalExpense`: 总支出
  - `totalIncome`: 总收入
  - `balance`: 结余
  - `transactionCount`: 交易笔数
- 计算结果准确

**验收标准**：
- [ ] 获取时间范围内所有交易
- [ ] 分别计算收入和支出总额
- [ ] 计算结余（收入 - 支出）
- [ ] 统计交易笔数

#### 场景：计算趋势分析

**前置条件**：
- 用户查询"最近7天消费趋势"

**操作**：
```dart
final result = await calculator.calculate(QueryRequest(
  queryType: QueryType.trendAnalysis,
  timeRange: TimeRange(
    start: DateTime.now().subtract(Duration(days: 7)),
    end: DateTime.now(),
  ),
));
```

**预期结果**：
- 返回 QueryResult 包含：
  - `trendData`: 每日支出数据点列表
  - `totalExpense`: 总支出
  - `averageDaily`: 日均支出
- 数据点按日期排序
- 支持图表展示

**验收标准**：
- [ ] 按日期分组交易数据
- [ ] 计算每日支出总额
- [ ] 生成 DataPoint 列表
- [ ] 数据点按日期升序排列
- [ ] 计算日均支出

### 需求：查询策略模式

**目标**：系统必须使用策略模式支持不同类型的查询计算

#### 场景：选择查询策略

**前置条件**：
- QueryCalculator 接收到查询请求

**操作**：
```dart
final strategy = _getCalculator(request.queryType);
final result = strategy.calculate(transactions, request);
```

**预期结果**：
- 根据 queryType 选择正确的计算策略
- 策略执行计算并返回结果

**验收标准**：
- [ ] 定义 `QueryCalculatorStrategy` 接口
- [ ] 实现 `CategoryExpenseCalculator`
- [ ] 实现 `TimeRangeSummaryCalculator`
- [ ] 实现 `TrendAnalysisCalculator`
- [ ] `_getCalculator()` 方法返回正确策略

### 需求：性能优化

**目标**：系统必须确保查询计算性能满足要求

#### 场景：限制查询时间范围

**前置条件**：
- 用户查询超过1年的数据

**操作**：
```dart
final result = await calculator.calculate(QueryRequest(
  queryType: QueryType.trendAnalysis,
  timeRange: TimeRange(
    start: DateTime(2020, 1, 1),
    end: DateTime(2024, 1, 1),  // 4年
  ),
));
```

**预期结果**：
- 抛出 QueryException: "查询时间范围不能超过1年"
- 不执行查询

**验收标准**：
- [ ] 检查时间范围是否超过365天
- [ ] 超过限制时抛出异常
- [ ] 异常消息清晰

#### 场景：数据采样

**前置条件**：
- 查询结果超过1000条记录

**操作**：
```dart
final transactions = await _fetchTransactions(request);
// transactions.length = 5000

final sampled = _sampleTransactions(transactions);
// sampled.length = 1000
```

**预期结果**：
- 返回均匀采样的1000条记录
- 保持数据分布特征
- 不影响趋势分析准确性

**验收标准**：
- [ ] 检查记录数是否超过1000
- [ ] 使用均匀采样算法
- [ ] 采样后记录数 = 1000
- [ ] 记录日志说明采样

#### 场景：查询结果缓存

**前置条件**：
- 相同查询在5分钟内重复执行

**操作**：
```dart
// 第一次查询
final result1 = await calculator.calculate(request);

// 2分钟后再次查询
await Future.delayed(Duration(minutes: 2));
final result2 = await calculator.calculate(request);
```

**预期结果**：
- 第二次查询直接返回缓存结果
- 不重新计算
- 响应时间 < 50ms

**验收标准**：
- [ ] 生成查询缓存键
- [ ] 检查缓存是否存在且未过期
- [ ] 缓存命中时直接返回
- [ ] 缓存未命中时计算并缓存
- [ ] 缓存有效期 = 5分钟

## 修改需求

### 需求：BookkeepingOperationAdapter 集成

**目标**：系统必须将 QueryCalculator 集成到现有查询流程

#### 场景：使用 QueryCalculator 执行查询

**前置条件**：
- BookkeepingOperationAdapter 接收到查询操作

**操作**：
```dart
// 修改前
final result = await _database.queryTransactions(request);

// 修改后
final calculator = QueryCalculator(_database);
final result = await calculator.calculate(request);
```

**预期结果**：
- 查询使用 QueryCalculator 执行
- 返回结果格式不变
- 现有代码无需修改

**验收标准**：
- [ ] 创建 QueryCalculator 实例
- [ ] 调用 `calculate()` 方法
- [ ] 转换 QueryResult 为 ExecutionResult
- [ ] 保持 cardData 和 chartData 生成逻辑不变

### 需求：QueryResult 数据结构扩展

**目标**：系统必须扩展 QueryResult 以支持更多查询类型

#### 场景：添加趋势数据字段

**前置条件**：
- 需要支持趋势分析查询

**操作**：
```dart
class QueryResult {
  final double totalExpense;
  final double totalIncome;
  final int transactionCount;
  final double? percentage;
  final double? progress;
  final List<DataPoint>? trendData;  // ← 新增
  final DateTime calculatedAt;       // ← 新增
}
```

**预期结果**：
- QueryResult 包含趋势数据字段
- 向后兼容现有代码

**验收标准**：
- [ ] 添加 `trendData` 可选字段
- [ ] 添加 `calculatedAt` 时间戳字段
- [ ] 更新构造函数
- [ ] 更新 `toMap()` 和 `fromMap()` 方法

## 技术约束

### 性能约束
- 查询响应时间 < 2秒
- 时间范围限制 ≤ 1年
- 数据点数量 ≤ 1000
- 缓存有效期 = 5分钟

### 内存约束
- 单次查询内存占用 < 10MB
- 缓存总大小 < 50MB
- 定期清理过期缓存

### 数据约束
- 支持的查询类型：
  - 分类支出/收入
  - 时间范围汇总
  - 趋势分析
  - 对比分析
- 支持的时间粒度：日、周、月
- 支持的分类：所有预定义分类

## 数据结构

### QueryRequest
```dart
class QueryRequest {
  final QueryType queryType;
  final String? category;
  final TimeRange? timeRange;
  final TransactionType? transactionType;
  final String? account;
}
```

### QueryResult
```dart
class QueryResult {
  final double totalExpense;
  final double totalIncome;
  final int transactionCount;
  final double? percentage;
  final double? progress;
  final List<DataPoint>? trendData;
  final DateTime calculatedAt;
}
```

### QueryCalculatorStrategy
```dart
abstract class QueryCalculatorStrategy {
  QueryResult calculate(
    List<Transaction> transactions,
    QueryRequest request,
  );
}
```

### DataPoint
```dart
class DataPoint {
  final String label;
  final double value;
}
```

## 错误处理

### 时间范围超限
```dart
if (timeRange.end.difference(timeRange.start) > Duration(days: 365)) {
  throw QueryException('查询时间范围不能超过1年');
}
```

### 数据库查询失败
```dart
try {
  final transactions = await _fetchTransactions(request);
} catch (e) {
  throw QueryException('获取交易数据失败: $e');
}
```

### 计算异常
```dart
try {
  final result = strategy.calculate(transactions, request);
} catch (e) {
  debugPrint('[QueryCalculator] 计算失败: $e');
  throw QueryException('查询计算失败: $e');
}
```

## 日志规范

### 日志级别
- **DEBUG**：查询开始、完成、缓存命中
- **INFO**：查询结果统计
- **WARN**：数据采样、时间范围限制
- **ERROR**：查询失败、计算异常

### 日志格式
```dart
debugPrint('[QueryCalculator] 开始计算: type=${request.queryType}, timeRange=${request.timeRange}');
debugPrint('[QueryCalculator] 获取交易数据: count=${transactions.length}');
debugPrint('[QueryCalculator] 数据采样: ${transactions.length} -> 1000');
debugPrint('[QueryCalculator] 计算完成: 耗时=${elapsed}ms');
debugPrint('[QueryCalculator] 缓存命中: key=$cacheKey');
```

## 测试要求

### 单元测试
- [ ] 分类支出计算
- [ ] 时间范围汇总计算
- [ ] 趋势分析计算
- [ ] 数据采样算法
- [ ] 缓存机制
- [ ] 异常处理

### 集成测试
- [ ] 端到端查询流程
- [ ] 多种查询类型
- [ ] 大数据集查询
- [ ] 缓存有效性

### 性能测试
- [ ] 查询响应时间
- [ ] 内存占用
- [ ] 缓存命中率
- [ ] 并发查询

## 依赖

### 内部依赖
- `DatabaseService` (现有)
- `Transaction` 模型 (现有)
- `QueryRequest` (现有)
- `QueryResult` (需要扩展)

### 外部依赖
- 无新增外部依赖

## 向后兼容性

- QueryResult 新增字段为可选，不影响现有代码
- BookkeepingOperationAdapter 接口不变
- 查询结果格式保持一致

## 安全考虑

- 时间范围限制防止过度查询
- 数据采样防止内存溢出
- 缓存大小限制防止内存泄漏
- SQL 注入防护（使用参数化查询）

## 扩展性

### 未来支持的查询类型
- 多分类对比
- 账户余额变化
- 预算执行情况
- 自定义时间粒度

### 未来优化方向
- 分布式缓存（Redis）
- 查询结果预计算
- 增量计算
- 并行计算
