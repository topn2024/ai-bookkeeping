# QueryCalculator 动态查询计算引擎

## 概述

QueryCalculator 是一个基于原始交易数据的动态查询计算引擎，用于替代依赖固定数据库列的查询方式。它支持灵活多样的查询需求，并包含完善的性能优化机制。

## 核心特性

### 1. 动态计算
- 从原始交易数据实时计算查询结果
- 不依赖固定数据库列（如 `sub_category`）
- 支持任意维度的查询组合

### 2. 策略模式
使用策略模式支持多种查询类型：
- **SummaryCalculator** - 汇总统计（总额、分类占比）
- **TrendCalculator** - 趋势分析（按日期分组）
- **DistributionCalculator** - 分布统计（按分类分组）
- **ComparisonCalculator** - 对比分析（多维度对比）
- **RecentCalculator** - 最近记录（最新交易）

### 3. 性能优化
- **查询结果缓存** - 5分钟有效期，避免重复计算
- **时间范围限制** - 最多查询365天数据
- **数据采样** - 超过1000条记录时均匀采样
- **定期清理** - 每5分钟清理过期缓存

## 使用方法

### 基本用法

```dart
import 'package:ai_bookkeeping/services/voice/query/query_calculator.dart';
import 'package:ai_bookkeeping/services/voice/query/query_models.dart';
import 'package:ai_bookkeeping/services/database_service.dart';

// 创建计算器实例
final database = DatabaseService();
final calculator = QueryCalculator(database);

// 创建查询请求
final request = QueryRequest(
  queryType: QueryType.summary,
  timeRange: TimeRange(
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 31),
    periodText: '本月',
  ),
  category: '餐饮',
);

// 执行查询
final result = await calculator.calculate(request);

// 使用结果
print('总支出: ${result.totalExpense}');
print('总收入: ${result.totalIncome}');
print('交易笔数: ${result.transactionCount}');
```

### 查询类型示例

#### 1. 汇总查询（Summary）
```dart
final request = QueryRequest(
  queryType: QueryType.summary,
  timeRange: TimeRange(
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 31),
    periodText: '本月',
  ),
  category: '餐饮',
);

final result = await calculator.calculate(request);
// result.groupedData 包含分类占比数据
```

#### 2. 趋势分析（Trend）
```dart
final request = QueryRequest(
  queryType: QueryType.trend,
  timeRange: TimeRange(
    startDate: DateTime.now().subtract(Duration(days: 7)),
    endDate: DateTime.now(),
    periodText: '最近7天',
  ),
);

final result = await calculator.calculate(request);
// result.detailedData 包含每日支出数据点
```

#### 3. 分布统计（Distribution）
```dart
final request = QueryRequest(
  queryType: QueryType.distribution,
  timeRange: TimeRange(
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 31),
    periodText: '本月',
  ),
);

final result = await calculator.calculate(request);
// result.groupedData 包含各分类的支出金额
// result.detailedData 包含前10个分类的数据点
```

#### 4. 对比分析（Comparison）
```dart
final request = QueryRequest(
  queryType: QueryType.comparison,
  timeRange: TimeRange(
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 31),
    periodText: '本月',
  ),
  groupBy: [GroupByDimension.category],
);

final result = await calculator.calculate(request);
// result.detailedData 包含各分类的对比数据
```

#### 5. 最近记录（Recent）
```dart
final request = QueryRequest(
  queryType: QueryType.recent,
  limit: 10,
);

final result = await calculator.calculate(request);
// result.detailedData 包含最近10条交易记录
```

## 查询过滤条件

QueryRequest 支持多种过滤条件：

```dart
final request = QueryRequest(
  queryType: QueryType.summary,

  // 时间范围
  timeRange: TimeRange(
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 31),
    periodText: '本月',
  ),

  // 分类筛选
  category: '餐饮',

  // 交易类型筛选
  transactionType: 'expense', // 'expense', 'income', 'transfer'

  // 账户筛选
  account: 'account_id',

  // 来源筛选
  source: 'voice', // 'manual', 'image', 'voice', 'email', 'import'

  // 分组维度
  groupBy: [GroupByDimension.category],

  // 数据点限制
  limit: 10,
);
```

## 性能考虑

### 时间范围限制
```dart
// ✅ 正确：查询1个月数据
final request = QueryRequest(
  queryType: QueryType.summary,
  timeRange: TimeRange(
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 31),
    periodText: '本月',
  ),
);

// ❌ 错误：查询超过1年数据会抛出异常
final request = QueryRequest(
  queryType: QueryType.summary,
  timeRange: TimeRange(
    startDate: DateTime(2020, 1, 1),
    endDate: DateTime(2024, 1, 1),
    periodText: '4年',
  ),
);
// 抛出: QueryException: 查询时间范围不能超过365天
```

### 缓存机制
相同的查询请求在5分钟内会直接返回缓存结果：

```dart
// 第一次查询：从数据库计算
final result1 = await calculator.calculate(request);

// 2分钟后再次查询：直接返回缓存
final result2 = await calculator.calculate(request);
```

### 数据采样
当查询结果超过1000条记录时，会自动进行均匀采样：

```dart
// 如果查询返回5000条记录，会自动采样到1000条
// 采样算法保证数据分布特征不变
```

## 错误处理

```dart
try {
  final result = await calculator.calculate(request);
} on QueryException catch (e) {
  // 处理查询异常
  print('查询失败: ${e.message}');
} catch (e) {
  // 处理其他异常
  print('未知错误: $e');
}
```

常见异常：
- `QueryException: 查询时间范围不能超过365天` - 时间范围超限
- `QueryException: 获取交易数据失败` - 数据库查询失败
- `QueryException: 查询计算失败` - 计算过程异常

## 扩展新的查询类型

如果需要添加新的查询类型，按以下步骤操作：

1. 在 `query_models.dart` 中添加新的 `QueryType` 枚举值
2. 在 `query_calculator_strategies.dart` 中创建新的计算器类
3. 在 `QueryCalculator._getCalculator()` 中添加新类型的映射

示例：

```dart
// 1. 添加枚举
enum QueryType {
  // ... 现有类型
  customAnalysis, // 新增
}

// 2. 创建计算器
class CustomAnalysisCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  ) {
    // 实现自定义计算逻辑
    return QueryResult(
      totalExpense: 0,
      totalIncome: 0,
      transactionCount: 0,
      periodText: request.timeRange?.periodText ?? '全部',
    );
  }
}

// 3. 添加映射
QueryCalculatorStrategy _getCalculator(QueryType type) {
  switch (type) {
    // ... 现有映射
    case QueryType.customAnalysis:
      return CustomAnalysisCalculator();
    default:
      return SimpleCalculator();
  }
}
```

## 测试

运行单元测试：

```bash
cd app
flutter test test/services/voice/query/query_calculator_test.dart
```

## 日志

QueryCalculator 会输出详细的调试日志：

```
[QueryCalculator] 开始计算: type=QueryType.summary, timeRange=本月, category=餐饮
[QueryCalculator] 获取交易数据: count=50
[QueryCalculator] 计算完成: 耗时=125ms
[QueryCalculator] 缓存命中: key=summary_1704067200000_1706745600000_餐饮_null_null_null
[QueryCalculator] 清理过期缓存，剩余: 3
```

## 架构图

```
QueryCalculator
    ├── 缓存管理
    │   ├── 5分钟有效期
    │   └── 定期清理
    ├── 数据获取
    │   ├── 时间范围验证
    │   ├── 构建查询条件
    │   └── 数据采样
    └── 策略选择
        ├── SummaryCalculator
        ├── TrendCalculator
        ├── DistributionCalculator
        ├── ComparisonCalculator
        └── RecentCalculator
```

## 相关文件

- `query_calculator.dart` - 主计算引擎
- `query_calculator_strategies.dart` - 策略实现
- `query_models.dart` - 数据模型
- `query_calculator_test.dart` - 单元测试
