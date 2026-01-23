# 提案：修复查询可视化异步执行问题

## 背景

当前系统已实现查询分层执行功能（`implement-query-hierarchy-execution`），包括：
- ✅ 查询复杂度判定引擎（QueryComplexityAnalyzer）
- ✅ 查询结果路由器（QueryResultRouter）
- ✅ Level 1/2/3 响应生成（语音、卡片、图表）
- ✅ UI 可视化组件（LightweightQueryCard、InteractiveQueryChart）

然而，在实际部署测试中发现**可视化组件无法显示**的严重问题。

### 问题分析

通过日志分析和代码审查，发现两个根本性问题：

#### 问题1：异步执行导致数据提取时机错误

**现象**：
```
[App] 处理语音命令: 本月餐饮花了多少钱？
[App] 处理完成: VoiceSessionStatus.success  // ← 立即返回
[BookkeepingOperationAdapter] 执行操作: OperationType.query  // ← 查询在之后才开始
```

**根本原因**：
在流水线模式（Pipeline Mode）下，语音命令处理采用异步执行架构：

1. **InputPipeline** 接收用户语音 → **IntelligenceEngine** 识别意图
2. **IntelligenceEngine** 立即返回自然语言响应（如"好的，我来查一下"）
3. **DualChannelProcessor** 将操作发送到 **ExecutionChannel** 异步执行
4. **ExecutionChannel** 在后台执行查询操作
5. 查询结果存储到 **ConversationChannel** 和 **ResultBuffer**

**问题所在**：
`main.dart` 中的 `_setupCommandProcessor()` 在步骤2就返回了，此时查询还未执行，`result.data` 中没有 `cardData` 和 `chartData`：

```dart
// main.dart:299-318
final data = result.data;
if (data is Map<String, dynamic> && data.containsKey('route')) {
  // 此时 data 只包含 IntelligenceEngine 的响应，不包含查询结果
  final cardData = data['cardData'];  // ← null
  final chartData = data['chartData'];  // ← null
}
```

#### 问题2：数据库查询依赖不存在的列

**现象**：
```
[BookkeepingOperationAdapter] 查询失败: DatabaseException(no such column: sub_category...)
```

**根本原因**：
`database_voice_extension.dart` 中的查询逻辑尝试查询 `sub_category` 列：

```dart
whereConditions.add('(category LIKE ? OR sub_category LIKE ?)');
```

但数据库 schema 中并不存在 `sub_category` 列，导致所有查询都失败。

**更深层的架构问题**：
用户提出的关键洞察："这些要查询的数据可能是通过某种方式计算就能获取到的，不一定是某个数据库现成的列，用户的诉求千千万万，我们不可能把所有的数据都事先存好。比如说这个本月餐饮花了多少钱，其实就是基于时间和类型进行统计得出来的金额。"

当前实现过度依赖固定的数据库列，无法灵活应对用户的多样化查询需求。

## 目标

1. **修复异步执行问题**：确保可视化数据能够正确传递到 UI 层
2. **重构查询执行逻辑**：从依赖固定列转向动态计算查询结果
3. **保持架构一致性**：不破坏现有的流水线模式和异步执行架构
4. **提升系统灵活性**：支持更多样化的查询需求

## 范围

### 包含

1. **异步结果传递机制**
   - 设计新的结果通知机制，在查询完成后通知 UI 层
   - 实现 ResultBuffer 监听器，监听查询结果变化
   - 修改 GlobalVoiceAssistantManager，支持延迟添加可视化数据

2. **动态查询计算引擎**
   - 重构 QueryExecutor，从 SQL 查询转向计算逻辑
   - 实现查询计算器（QueryCalculator），基于时间范围和分类动态计算
   - 移除对 `sub_category` 等不存在列的依赖

3. **可视化数据流重构**
   - 修改 BookkeepingOperationAdapter，在查询完成后触发可视化更新
   - 实现可视化数据通知机制（通过 ResultBuffer 或新的 VisualizationChannel）
   - 更新 EnhancedVoiceAssistantPage，监听可视化数据变化

### 不包含

- 查询缓存优化（后续优化）
- 查询性能监控（后续优化）
- 新增查询类型（当前提案仅修复现有功能）
- UI 组件样式调整（当前组件已实现）

## 设计原则

1. **异步优先**：尊重流水线模式的异步执行架构，不强制同步化
2. **计算优于存储**：查询结果通过动态计算获得，而非依赖固定数据库列
3. **最小侵入**：尽量复用现有组件和架构，减少破坏性变更
4. **可扩展性**：设计应支持未来添加更多查询类型和可视化方式

## 技术方案概述

### 方案1：ResultBuffer 监听机制（推荐）

**核心思路**：在 ResultBuffer 中添加监听器，当查询结果存入时触发可视化更新。

```dart
// 1. ResultBuffer 添加监听器支持
class ResultBuffer {
  final _listeners = <String, List<Function(ExecutionResult)>>{};

  void addListener(String operationId, Function(ExecutionResult) callback) {
    _listeners.putIfAbsent(operationId, () => []).add(callback);
  }

  void notifyResult(String operationId, ExecutionResult result) {
    _listeners[operationId]?.forEach((callback) => callback(result));
    _listeners.remove(operationId);
  }
}

// 2. GlobalVoiceAssistantManager 注册监听器
void _setupCommandProcessor() {
  GlobalVoiceAssistantManager.instance.setCommandProcessor((command) async {
    final result = await coordinator.processVoiceCommand(command);

    // 注册监听器，等待查询结果
    if (result.status == VoiceSessionStatus.success) {
      final operationId = result.data?['operationId'];
      if (operationId != null) {
        coordinator.resultBuffer.addListener(operationId, (queryResult) {
          _handleVisualizationData(queryResult);
        });
      }
    }

    return result.message ?? '';
  });
}

// 3. 处理可视化数据
void _handleVisualizationData(ExecutionResult result) {
  final cardData = result.data?['cardData'];
  final chartData = result.data?['chartData'];

  if (cardData != null || chartData != null) {
    // 更新最后一条助手消息的 metadata
    GlobalVoiceAssistantManager.instance.updateLastMessageMetadata({
      if (cardData != null) 'cardData': cardData,
      if (chartData != null) 'chartData': chartData,
    });
  }
}
```

**优点**：
- 不破坏现有异步架构
- 清晰的事件驱动模型
- 易于扩展和测试

**缺点**：
- 需要修改 ResultBuffer 类
- 需要管理监听器生命周期

### 方案2：动态查询计算引擎

**核心思路**：将查询从 SQL 查询转向基于 Transaction 数据的动态计算。

```dart
// 查询计算器
class QueryCalculator {
  Future<QueryResult> calculate(QueryRequest request) async {
    // 1. 从数据库获取原始交易数据
    final transactions = await _fetchTransactions(request.timeRange);

    // 2. 根据查询类型进行计算
    switch (request.queryType) {
      case QueryType.categoryExpense:
        return _calculateCategoryExpense(transactions, request.category);
      case QueryType.timeRangeSummary:
        return _calculateTimeRangeSummary(transactions);
      case QueryType.trendAnalysis:
        return _calculateTrend(transactions);
    }
  }

  QueryResult _calculateCategoryExpense(
    List<Transaction> transactions,
    String category,
  ) {
    // 过滤分类
    final filtered = transactions.where((t) =>
      t.category == category && t.type == TransactionType.expense
    );

    // 计算总额
    final total = filtered.fold<double>(0, (sum, t) => sum + t.amount);

    // 计算占比（相对于总支出）
    final totalExpense = transactions
      .where((t) => t.type == TransactionType.expense)
      .fold<double>(0, (sum, t) => sum + t.amount);
    final percentage = totalExpense > 0 ? (total / totalExpense) * 100 : 0;

    return QueryResult(
      totalExpense: total,
      percentage: percentage,
      transactionCount: filtered.length,
    );
  }
}
```

**优点**：
- 不依赖固定数据库列
- 灵活支持各种查询需求
- 易于理解和维护

**缺点**：
- 需要加载更多原始数据到内存
- 复杂查询可能性能较低（可通过缓存优化）

## 实施计划

### Phase 1: 修复数据库查询问题（1天）
- 移除 `sub_category` 相关查询逻辑
- 实现基础的动态查询计算
- 确保现有查询功能正常工作

### Phase 2: 实现 ResultBuffer 监听机制（2天）
- 在 ResultBuffer 中添加监听器支持
- 修改 GlobalVoiceAssistantManager，注册查询结果监听器
- 实现 `updateLastMessageMetadata()` 方法

### Phase 3: 重构查询执行流程（2-3天）
- 实现 QueryCalculator 类
- 重构 BookkeepingOperationAdapter，使用 QueryCalculator
- 更新查询结果数据结构

### Phase 4: 集成测试（1-2天）
- 端到端测试查询可视化功能
- 测试各种查询类型（简单、中等、复杂）
- 性能测试和优化

**总计：6-8天**

## 风险与缓解

### 风险1：监听器内存泄漏
**缓解**：
- 设置监听器超时机制（30秒后自动清理）
- 在 dispose 时清理所有监听器
- 使用 WeakReference 避免循环引用

### 风险2：动态计算性能问题
**缓解**：
- 限制查询时间范围（最多1年）
- 实现查询结果缓存
- 对大数据集进行采样

### 风险3：异步更新 UI 时机问题
**缓解**：
- 使用 ChangeNotifier 确保 UI 更新
- 添加详细的日志跟踪
- 实现重试机制

## 成功标准

1. **功能完整性**：
   - ✅ 查询可视化组件正常显示
   - ✅ 卡片和图表数据正确
   - ✅ 所有查询类型都能正常工作

2. **性能指标**：
   - ✅ 查询响应时间 < 2秒
   - ✅ UI 更新延迟 < 500ms
   - ✅ 内存占用增长 < 10MB

3. **代码质量**：
   - ✅ 无内存泄漏
   - ✅ 无数据库错误
   - ✅ 单元测试覆盖率 > 80%

## 依赖

- **内部依赖**：
  - ResultBuffer（需要修改）
  - GlobalVoiceAssistantManager（需要修改）
  - BookkeepingOperationAdapter（需要修改）
  - QueryExecutor（需要重构）

- **外部依赖**：
  - 无新增外部依赖

## 参考资料

- 现有提案：`openspec/changes/implement-query-hierarchy-execution/proposal.md`
- 设计文档：`docs/design/app_v2_design.md`
- 相关代码：
  - `app/lib/services/voice/adapters/bookkeeping_operation_adapter.dart`
  - `app/lib/services/global_voice_assistant_manager.dart`
  - `app/lib/main.dart`
  - `app/lib/services/database_voice_extension.dart`
