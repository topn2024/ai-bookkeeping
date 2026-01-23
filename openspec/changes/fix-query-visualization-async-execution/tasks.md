# 任务列表

## Phase 1: 修复数据库查询问题

### 1.1 移除 sub_category 依赖
- [ ] 审查 `database_voice_extension.dart` 中所有 `sub_category` 引用
- [ ] 移除或注释掉 `sub_category` 相关的 WHERE 条件
- [ ] 更新查询逻辑，仅使用 `category` 字段
- [ ] 验证：运行查询测试，确保无数据库错误

### 1.2 实现基础动态查询计算
- [ ] 创建 `query_calculator.dart` 文件
- [ ] 实现 `QueryCalculator` 类基础结构
- [ ] 实现 `_fetchTransactions()` 方法（从数据库获取原始交易数据）
- [ ] 实现 `_calculateCategoryExpense()` 方法（分类支出计算）
- [ ] 验证：单元测试查询计算逻辑

### 1.3 集成到现有查询流程
- [ ] 修改 `BookkeepingOperationAdapter._query()`，使用 QueryCalculator
- [ ] 保持现有 QueryResult 数据结构不变
- [ ] 添加日志跟踪查询计算过程
- [ ] 验证：端到端测试查询功能，确保结果正确

## Phase 2: 实现 ResultBuffer 监听机制

### 2.1 扩展 ResultBuffer 类
- [ ] 在 `result_buffer.dart` 中添加 `_listeners` 字段
- [ ] 实现 `addListener()` 方法
- [ ] 实现 `removeListener()` 方法
- [ ] 实现 `notifyResult()` 方法
- [ ] 添加监听器超时清理机制（30秒）
- [ ] 验证：单元测试监听器注册和通知

### 2.2 修改查询执行流程
- [ ] 在 `BookkeepingOperationAdapter` 中生成唯一 operationId
- [ ] 在返回 ExecutionResult 时包含 operationId
- [ ] 在查询完成后调用 `resultBuffer.notifyResult()`
- [ ] 验证：日志确认通知被正确触发

### 2.3 扩展 GlobalVoiceAssistantManager
- [ ] 实现 `updateLastMessageMetadata()` 方法
- [ ] 实现 `_findLastAssistantMessage()` 辅助方法
- [ ] 添加线程安全保护（使用 synchronized 或 Lock）
- [ ] 验证：单元测试 metadata 更新逻辑

### 2.4 集成监听器到命令处理器
- [ ] 修改 `main.dart` 中的 `_setupCommandProcessor()`
- [ ] 在处理查询命令时注册 ResultBuffer 监听器
- [ ] 实现 `_handleVisualizationData()` 回调方法
- [ ] 添加详细的日志跟踪
- [ ] 验证：端到端测试，确认可视化数据能够更新

## Phase 3: 重构查询执行流程

### 3.1 完善 QueryCalculator
- [ ] 实现 `_calculateTimeRangeSummary()` 方法（时间范围汇总）
- [ ] 实现 `_calculateTrend()` 方法（趋势分析）
- [ ] 实现 `_calculateComparison()` 方法（对比分析）
- [ ] 添加查询结果缓存机制
- [ ] 验证：单元测试各种查询类型

### 3.2 优化查询性能
- [ ] 实现时间范围限制（最多1年）
- [ ] 实现数据采样（超过1000条记录时）
- [ ] 添加查询性能监控日志
- [ ] 验证：性能测试，确保查询响应时间 < 2秒

### 3.3 更新查询结果数据结构
- [ ] 审查 QueryResult 类，确保包含所有必要字段
- [ ] 添加 `calculatedAt` 时间戳字段
- [ ] 添加 `dataSource` 字段（标识数据来源）
- [ ] 验证：确保向后兼容

## Phase 4: 集成测试

### 4.1 功能测试
- [ ] 测试简单查询（Level 1）：今天花了多少钱
- [ ] 测试中等查询（Level 2）：本月餐饮花了多少钱
- [ ] 测试复杂查询（Level 3）：最近三个月消费趋势
- [ ] 测试卡片显示和自动淡出
- [ ] 测试图表显示和交互
- [ ] 验证：所有查询类型都能正常显示可视化组件

### 4.2 异步流程测试
- [ ] 测试查询结果延迟到达（模拟慢查询）
- [ ] 测试多个查询并发执行
- [ ] 测试查询超时处理
- [ ] 测试监听器清理
- [ ] 验证：无内存泄漏，无 UI 卡顿

### 4.3 错误处理测试
- [ ] 测试数据库查询失败
- [ ] 测试查询计算异常
- [ ] 测试监听器回调异常
- [ ] 测试 UI 更新失败
- [ ] 验证：所有错误都有友好提示

### 4.4 性能测试
- [ ] 测试大数据集查询（10000+ 条记录）
- [ ] 测试查询响应时间
- [ ] 测试 UI 更新延迟
- [ ] 测试内存占用
- [ ] 验证：满足性能指标要求

### 4.5 回归测试
- [ ] 测试现有查询功能未受影响
- [ ] 测试语音命令识别
- [ ] 测试多意图处理
- [ ] 测试导航功能
- [ ] 验证：无破坏性变更

## Phase 5: 文档和清理

### 5.1 代码文档
- [ ] 为 QueryCalculator 添加详细注释
- [ ] 为 ResultBuffer 监听机制添加注释
- [ ] 更新 README 中的查询功能说明
- [ ] 添加架构图（异步查询流程）

### 5.2 测试文档
- [ ] 编写测试用例文档
- [ ] 记录已知问题和限制
- [ ] 编写故障排查指南

### 5.3 代码清理
- [ ] 移除调试日志
- [ ] 移除注释掉的旧代码
- [ ] 格式化代码（flutter format）
- [ ] 运行 lint 检查

## 依赖关系

- 1.1 → 1.2 → 1.3（Phase 1 必须顺序执行）
- 2.1 → 2.2, 2.3（ResultBuffer 扩展后才能修改查询流程）
- 2.2, 2.3 → 2.4（查询流程和 Manager 都准备好后才能集成）
- Phase 1, Phase 2 → Phase 3（基础功能完成后才能优化）
- Phase 1, 2, 3 → Phase 4（所有功能完成后才能测试）
- Phase 4 → Phase 5（测试通过后才能清理）

## 可并行工作

- 1.2 和 2.1 可以并行（不同文件）
- 2.3 和 3.1 可以并行（不同文件）
- 4.1, 4.2, 4.3 可以并行（不同测试场景）
