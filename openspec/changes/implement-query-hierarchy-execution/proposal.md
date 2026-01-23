# 提案：实现查询分层执行功能

## 背景

当前系统已经设计了完整的查询分层响应策略（见 `docs/design/app_v2_design.md`），将查询按复杂度分为三层：

1. **Level 1: 纯语音响应** - 简单报数（如"今天花了156块，3笔"）
2. **Level 2: 语音+轻量卡片** - 带比例/占比的查询（如"餐饮2180，占了快三成"）
3. **Level 3: 语音摘要+交互图表** - 复杂趋势分析（如"最近三个月消费趋势"）

然而，当前代码实现存在以下问题：

### 现状分析

✅ **已实现**：
- 基础查询功能（`BookkeepingOperationAdapter._query()`）
- 页面配置和备注说明（237个页面配置）
- 参数化导航（支持分类、时间、来源等参数）
- 时间范围解析（支持今天、昨天、本周、本月等）

❌ **未实现**：
- 查询复杂度自动判定逻辑
- Level 2 轻量卡片UI组件
- Level 3 交互图表组件
- 自定义SQL查询功能（用于复杂查询）
- 查询结果的智能路由（根据复杂度选择响应方式）

### 问题

1. **所有查询都是简单报数**：无论查询多复杂，都只返回文本响应
2. **无法处理复杂查询**：如"最近三个月的消费趋势"、"各分类占比"等
3. **用户体验不一致**：简单查询和复杂查询的响应方式相同
4. **缺少可视化支持**：无法展示图表、趋势等可视化数据

## 目标

实现完整的查询分层执行功能，使系统能够：

1. **自动判定查询复杂度**：根据时间跨度、数据维度、数据点数等因素计算复杂度评分
2. **智能选择响应方式**：
   - 简单查询 → 纯语音响应
   - 中等查询 → 语音 + 轻量卡片
   - 复杂查询 → 语音摘要 + 交互图表
3. **支持复杂查询**：实现自定义SQL查询功能，处理多维度、多时间段的复杂分析
4. **提升用户体验**：根据查询复杂度提供最合适的响应方式

## 范围

### 包含

1. **查询复杂度判定引擎**
   - 实现复杂度评分算法
   - 支持时间跨度、数据维度、数据点数等因素
   - 自动分类到Level 1/2/3

2. **Level 1: 纯语音响应**（增强现有实现）
   - 优化响应文本生成
   - 支持更多查询类型（余额、笔数、平均值等）

3. **Level 2: 轻量卡片**（新增）
   - 设计轻量卡片UI组件
   - 支持进度条、占比、对比等可视化
   - 3秒后自动淡出

4. **Level 3: 交互图表**（新增）
   - 集成图表库（如fl_chart）
   - 支持折线图、柱状图、饼图
   - 支持点击查看明细

5. **自定义SQL查询**（新增）
   - 实现SQL查询生成器
   - 支持多维度、多时间段查询
   - 安全的SQL执行引擎

6. **查询结果路由**
   - 根据复杂度自动选择响应方式
   - 统一的查询结果数据结构

### 不包含

- 查询缓存优化（后续优化）
- 查询性能监控（后续优化）
- 查询结果导出功能（后续功能）
- 自然语言查询优化（后续优化）

## 设计原则

1. **渐进式增强**：从简单到复杂，逐步实现各层级功能
2. **向后兼容**：不破坏现有查询功能
3. **性能优先**：复杂度判定要快速（<10ms）
4. **用户体验**：响应方式要符合用户预期
5. **可扩展性**：易于添加新的查询类型和响应方式

## 技术方案概述

### 1. 查询复杂度判定引擎

```dart
class QueryComplexityAnalyzer {
  int calculateComplexity(QueryRequest request) {
    int score = 0;

    // 时间跨度评分
    score += _scoreTimeSpan(request.timeRange);

    // 数据维度评分
    score += _scoreDimensions(request.dimensions);

    // 数据点数评分
    score += _scoreDataPoints(request.expectedDataPoints);

    // 特殊类型加分
    score += _scoreQueryType(request.queryType);

    return score;
  }

  QueryLevel determineLevel(int complexityScore) {
    if (complexityScore <= 1) return QueryLevel.simple;
    if (complexityScore <= 4) return QueryLevel.medium;
    return QueryLevel.complex;
  }
}
```

### 2. 查询结果路由

```dart
class QueryResultRouter {
  Future<QueryResponse> route(QueryRequest request, QueryResult result) async {
    final complexity = _analyzer.calculateComplexity(request);
    final level = _analyzer.determineLevel(complexity);

    switch (level) {
      case QueryLevel.simple:
        return _buildVoiceResponse(result);
      case QueryLevel.medium:
        return _buildCardResponse(result);
      case QueryLevel.complex:
        return _buildChartResponse(result);
    }
  }
}
```

### 3. 自定义SQL查询

```dart
class CustomQueryExecutor {
  Future<QueryResult> execute(QueryRequest request) async {
    // 生成安全的SQL
    final sql = _sqlGenerator.generate(request);

    // 验证SQL安全性
    _sqlValidator.validate(sql);

    // 执行查询
    final rawData = await _database.rawQuery(sql);

    // 转换为统一数据结构
    return _resultTransformer.transform(rawData, request);
  }
}
```

## 实施计划

### Phase 1: 基础架构（1-2天）
- 实现查询复杂度判定引擎
- 设计统一的查询请求/响应数据结构
- 实现查询结果路由器

### Phase 2: Level 1 增强（1天）
- 优化现有语音响应
- 支持更多查询类型
- 改进响应文本生成

### Phase 3: Level 2 实现（2-3天）
- 设计轻量卡片UI组件
- 实现进度条、占比等可视化
- 实现自动淡出动画

### Phase 4: Level 3 实现（3-4天）
- 集成图表库
- 实现折线图、柱状图、饼图
- 实现交互功能（点击查看明细）

### Phase 5: 自定义SQL查询（2-3天）
- 实现SQL查询生成器
- 实现SQL安全验证
- 实现查询执行引擎

### Phase 6: 集成测试（1-2天）
- 端到端测试
- 性能测试
- 用户体验测试

**总计：10-15天**

## 风险与缓解

### 风险1：SQL注入安全风险
**缓解**：
- 使用参数化查询
- 严格的SQL验证
- 白名单机制（只允许特定的表和字段）

### 风险2：复杂度判定不准确
**缓解**：
- 基于设计文档的算法
- 充分的测试用例
- 支持手动调整

### 风险3：图表性能问题
**缓解**：
- 数据点限制（最多1000个点）
- 数据采样
- 懒加载

### 风险4：UI组件兼容性
**缓解**：
- 使用成熟的图表库
- 充分的设备测试
- 降级方案

## 成功标准

1. **功能完整性**：
   - ✅ 复杂度判定准确率 > 90%
   - ✅ 支持所有三个层级的响应
   - ✅ 自定义SQL查询功能可用

2. **性能指标**：
   - ✅ 复杂度判定 < 10ms
   - ✅ 简单查询响应 < 500ms
   - ✅ 复杂查询响应 < 2s

3. **用户体验**：
   - ✅ 响应方式符合用户预期
   - ✅ 轻量卡片自动淡出
   - ✅ 图表交互流畅

4. **代码质量**：
   - ✅ 单元测试覆盖率 > 80%
   - ✅ 无SQL注入漏洞
   - ✅ 代码符合项目规范

## 依赖

- **外部依赖**：
  - fl_chart (图表库) - 需要添加到pubspec.yaml
  - 无其他新增外部依赖

- **内部依赖**：
  - DatabaseService（现有）
  - BookkeepingOperationAdapter（现有）
  - VoiceCoordinator（现有）

## 参考资料

- 设计文档：`docs/design/app_v2_design.md` (第11479-11768行)
- 现有实现：`app/lib/services/voice/adapters/bookkeeping_operation_adapter.dart`
- 页面配置：`app/lib/services/voice_navigation_service.dart`
