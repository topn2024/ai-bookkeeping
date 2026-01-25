# QueryCalculator 与 LLM 集成指南

## 概述

本文档详细说明 QueryCalculator 动态计算引擎如何与 LLM 的意图识别和实体提取结合，实现灵活的自然语言查询功能。

## 完整数据流

```
用户语音："本月餐饮花了多少钱？"
    ↓
┌──────────────────────────────────────────────────────────────┐
│ 第1步：LLM 意图识别与实体提取                                  │
│ SmartIntentRecognizer._layer5LLMFallback()                   │
│                                                              │
│ LLM Prompt:                                                  │
│ "你是一个记账助手，请理解用户输入并返回JSON"                    │
│ 【用户输入】本月餐饮花了多少钱？                                │
│ 【意图类型】query: 查询统计                                    │
│                                                              │
│ LLM Response:                                                │
│ {                                                            │
│   "intent": "query",           ← 意图识别                     │
│   "confidence": 0.9,                                         │
│   "entities": {                                              │
│     "timeRange": "本月",       ← 实体提取：时间                │
│     "category": "餐饮",        ← 实体提取：分类                │
│     "queryType": "summary"     ← 实体提取：查询类型            │
│   }                                                          │
│ }                                                            │
└──────────────────────────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────────────────────────┐
│ 第2步：实体转换为 QueryRequest                                │
│ BookkeepingOperationAdapter._query()                         │
│                                                              │
│ 输入：LLM 提取的实体                                           │
│ {                                                            │
│   "queryType": "summary",                                    │
│   "time": "本月",                                            │
│   "category": "餐饮"                                         │
│ }                                                            │
│                                                              │
│ 转换过程：                                                     │
│ 1. _parseTimeRange("本月") →                                 │
│    TimeRange(                                                │
│      startDate: 2024-01-01,                                  │
│      endDate: 2024-01-31,                                    │
│      periodText: "本月"                                      │
│    )                                                         │
│                                                              │
│ 2. _buildQueryRequest() →                                    │
│    QueryRequest(                                             │
│      queryType: QueryType.summary,                           │
│      timeRange: TimeRange(...),                              │
│      category: "餐饮",                                       │
│      transactionType: "expense"                              │
│    )                                                         │
└──────────────────────────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────────────────────────┐
│ 第3步：动态查询计算                                            │
│ QueryCalculator.calculate()                                  │
│                                                              │
│ 输入：QueryRequest                                            │
│                                                              │
│ 执行流程：                                                     │
│ 1. _fetchTransactions(request)                              │
│    - WHERE date >= '2024-01-01' AND date <= '2024-01-31'   │
│    - WHERE category = '餐饮'                                 │
│    - WHERE type = 0 (expense)                                │
│    → 获取50条原始交易记录                                      │
│                                                              │
│ 2. _getCalculator(QueryType.summary)                        │
│    → CategoryExpenseCalculator                               │
│                                                              │
│ 3. calculator.calculate(transactions, request)              │
│    - 过滤餐饮支出：30条                                        │
│    - 计算总额：sum(amounts) = 2180.0元                        │
│    - 计算占比：2180 / 7650 = 28.5%                           │
│    - 统计笔数：30笔                                           │
│                                                              │
│ 输出：QueryResult                                             │
│ {                                                            │
│   totalExpense: 2180.0,                                      │
│   percentage: 28.5,                                          │
│   transactionCount: 30,                                      │
│   periodText: "本月",                                        │
│   calculatedAt: DateTime.now()                               │
│ }                                                            │
└──────────────────────────────────────────────────────────────┘
│                                                              │
│ 2. _buildQueryRequest() →                                    │
│    QueryRequest(                                             │
│      queryType: QueryType.summary,                           │
│      timeRange: TimeRange(...),                              │
│      category: "餐饮",                                       │
│      transactionType: "expense"                              │
│    )                                                         │
└──────────────────────────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────────────────────────┐
│ 第3步：动态查询计算                                            │
│ QueryCalculator.calculate()                                  │
│                                                              │
│ 输入：QueryRequest                                            │
│                                                              │
│ 执行流程：                                                     │
│ 1. _fetchTransactions(request)                              │
│    - WHERE date >= '2024-01-01' AND date <= '2024-01-31'   │
│    - WHERE category = '餐饮'                                 │
│    - WHERE type = 0 (expense)                                │
│    → 获取50条原始交易记录                                      │
│                                                              │
│ 2. _getCalculator(QueryType.summary)                        │
│    → CategoryExpenseCalculator                               │
│                                                              │
│ 3. calculator.calculate(transactions, request)              │
│    - 过滤餐饮支出：30条                                        │
│    - 计算总额：sum(amounts) = 2180.0元                        │
│    - 计算占比：2180 / 7650 = 28.5%                           │
│    - 统计笔数：30笔                                           │
│                                                              │
│ 输出：QueryResult                                             │
│ {                                                            │
│   totalExpense: 2180.0,                                      │
│   percentage: 28.5,                                          │
│   transactionCount: 30,                                      │
│   periodText: "本月",                                        │
│   calculatedAt: DateTime.now()                               │
│ }                                                            │
└──────────────────────────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────────────────────────┐
│ 第4步：查询结果路由                                            │
│ QueryResultRouter.route()                                    │
│                                                              │
│ 输入：QueryRequest + QueryResult                              │
│                                                              │
│ 复杂度判定：                                                   │
│ - 时间范围：本月 → +2分                                        │
│ - 分类筛选：餐饮 → +2分                                        │
│ - 查询类型：summary → +1分                                    │
│ - 总分：5分 → Level 2（语音+卡片）                            │
│                                                              │
│ 生成响应：                                                     │
│ QueryResponse(                                               │
│   level: QueryLevel.medium,                                  │
│   voiceText: "本月餐饮支出2180元，占总支出的28.5%",            │
│   cardData: QueryCardData(                                   │
│     cardType: CardType.percentage,                           │
│     primaryValue: 2180.0,                                    │
│     percentage: 0.285                                        │
│   ),                                                         │
│   chartData: null  // Level 2 不生成图表                     │
│ )                                                            │
└──────────────────────────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────────────────────────┐
│ 第5步：异步结果通知（新增功能）                                │
│ ResultBuffer.notifyResult()                                  │
│                                                              │
│ 1. 查询完成后，触发监听器                                      │
│ 2. 监听器回调 _handleVisualizationData()                      │
│ 3. 提取 cardData 和 chartData                                │
│ 4. 调用 GlobalVoiceAssistantManager.updateLastMessageMetadata()│
│ 5. UI 自动刷新，显示可视化组件                                 │
└──────────────────────────────────────────────────────────────┘
    ↓
[UI 层] LightweightQueryCard 显示卡片
```

## 核心优势

### 1. 灵活性

- **LLM 层**：理解自然语言，提取任意实体
- **QueryCalculator 层**：动态计算，不依赖固定数据库列

**优势体现**：
- 用户可以用任意自然语言表达查询需求
- 系统可以处理千变万化的查询组合
- 无需预先定义所有可能的查询类型

### 2. 可扩展性

- **新增查询类型**：只需添加新的 Calculator 策略
- **新增实体类型**：LLM 自动识别，无需修改代码

### 3. 性能保障

- **缓存机制**：5分钟缓存，避免重复计算
- **时间范围限制**：最多查询1年数据
- **数据采样**：最多1000个数据点
- **查询优化**：使用索引，限制返回字段

**性能指标**：
- 查询响应时间 < 2秒
- 内存占用 < 10MB/查询
- 缓存命中率 > 60%

### 4. 易于维护

- **计算逻辑集中**：所有查询计算都在 QueryCalculator 中
- **策略模式**：每种查询类型独立实现，互不影响
- **易于测试**：可以单独测试每个计算器
- **清晰的数据流**：LLM → QueryRequest → QueryCalculator → QueryResult

## 数据结构映射

```
LLM 实体 → QueryRequest → QueryCalculator → QueryResult → QueryResponse
────────────────────────────────────────────────────────────────────────
timeRange:"本月"  →  TimeRange(...)  →  WHERE date  →  totalExpense  →  voiceText
category:"餐饮"   →  category:"餐饮"  →  WHERE cat   →  percentage   →  cardData
queryType:"summary" → QueryType.summary → Calculator → transactionCount → chartData
```

## 完整示例

### 示例 1：分类支出查询

```
用户："本月餐饮花了多少钱？"
    ↓
LLM: {"intent":"query", "entities":{"timeRange":"本月", "category":"餐饮"}}
    ↓
QueryRequest(queryType:summary, timeRange:本月, category:餐饮)
    ↓
QueryCalculator: 获取50条交易 → 过滤30条餐饮 → 计算2180元
    ↓
QueryResult(totalExpense:2180, percentage:28.5, count:30)
    ↓
QueryResponse(level:Level2, voiceText:"本月餐饮支出2180元，占28.5%", cardData:{...})
    ↓
UI: 显示卡片 + 语音播报
```

### 示例 2：趋势分析查询

```
用户："最近一周消费趋势"
    ↓
LLM: {"intent":"query", "entities":{"timeRange":"最近一周", "queryType":"trend"}}
    ↓
QueryRequest(queryType:trend, timeRange:最近7天)
    ↓
QueryCalculator: 获取100条交易 → 按日期分组 → 生成7个数据点
    ↓
QueryResult(detailedData:[{day1:150}, {day2:200}, ...])
    ↓
QueryResponse(level:Level3, chartData:{type:line, dataPoints:[...]})
    ↓
UI: 显示折线图 + 语音播报
```

### 示例 3：多分类对比查询

```
用户："最近一周交通和餐饮哪个花得多？"
    ↓
LLM: {"intent":"query", "entities":{
  "timeRange":"最近一周",
  "categories":["交通","餐饮"],
  "queryType":"comparison"
}}
    ↓
QueryRequest(queryType:comparison, timeRange:最近7天, categories:["交通","餐饮"])
    ↓
QueryCalculator: 获取交易 → 分别计算交通和餐饮 → 生成对比数据
    ↓
QueryResult(groupedData:{"交通":450, "餐饮":680})
    ↓
QueryResponse(level:Level3, chartData:{type:bar, dataPoints:[...]})
    ↓
UI: 显示柱状图对比 + 语音播报
```

## 相关文件

### 核心文件

- `app/lib/services/voice/smart_intent_recognizer.dart` - LLM 意图识别
- `app/lib/services/voice/adapters/bookkeeping_operation_adapter.dart` - 实体转换
- `app/lib/services/voice/query/query_calculator.dart` - 动态计算引擎（新增）
- `app/lib/services/voice/query/query_models.dart` - 数据模型
- `app/lib/services/voice/query/query_executor.dart` - 查询执行器
- `app/lib/services/voice/query/query_result_router.dart` - 结果路由

### 数据模型

- `QueryRequest` - 查询请求
- `QueryResult` - 查询结果
- `QueryResponse` - 查询响应
- `QueryCardData` - 卡片数据
- `QueryChartData` - 图表数据

## 总结

QueryCalculator 动态计算引擎与 LLM 的集成实现了：

1. **灵活的自然语言理解**：LLM 提取任意查询实体
2. **动态的查询计算**：从原始数据实时计算，不依赖固定列
3. **可扩展的架构**：策略模式支持任意查询类型
4. **高性能**：缓存、采样、时间限制保障性能
5. **易于维护**：清晰的数据流和模块划分

这个设计完美结合了 **LLM 的语义理解能力** 和 **QueryCalculator 的动态计算能力**，实现了灵活、可扩展的查询系统！
