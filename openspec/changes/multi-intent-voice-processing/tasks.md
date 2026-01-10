# 语音多意图处理 - 任务清单

## 1. 基础架构 - 分句和数据模型

- [x] 1.1 创建多意图数据模型
  - 文件：`app/lib/services/voice/multi_intent_models.dart`
  - 实现 MultiIntentResult 类
  - 实现 SegmentAnalysis 类
  - 实现 CompleteIntent / IncompleteIntent 类
  - 实现 IntentCompleteness 槽位检查

- [x] 1.2 实现分句器
  - 文件：`app/lib/services/voice/sentence_splitter.dart`
  - 按标点符号分割（。！？；）
  - 按连接词分割（然后、还有、另外）
  - 按时间转换词分割（早上、晚上、后来）
  - 过滤空白和无意义片段
  - 保持语义完整性

- [x] 1.3 实现噪音过滤器
  - 文件：`app/lib/services/voice/noise_filter.dart`
  - 低置信度过滤（<0.3）
  - 无动作动词过滤
  - 纯状态描述过滤
  - 可配置过滤规则

## 2. 意图分析 - 批量处理和合并

- [x] 2.1 实现批量意图分析器
  - 文件：`app/lib/services/voice/batch_intent_analyzer.dart`
  - 并行分析多个分句
  - 复用现有 VoiceIntentRouter
  - 收集每个分句的意图和实体
  - 处理分析异常

- [x] 2.2 实现意图合并器
  - 文件：`app/lib/services/voice/intent_merger.dart`
  - 合并同类交易意图
  - 分离不同类型意图（记账、导航、查询）
  - 判断意图完整性（必要槽位检查）
  - 生成 MultiIntentResult

- [x] 2.3 扩展 VoiceIntentRouter
  - 文件：`app/lib/services/voice/voice_intent_router.dart`
  - 添加 `analyzeMultipleIntents()` 方法
  - 支持返回多个候选意图
  - 保持向后兼容

## 3. 服务集成 - 协调器和状态管理

- [x] 3.1 添加意图队列管理
  - 文件：`app/lib/services/voice_service_coordinator.dart`
  - 实现待处理多意图管理（pendingMultiIntent）
  - 管理待处理意图列表
  - 支持意图优先级排序
  - 支持意图的添加/移除/更新

- [x] 3.2 实现多意图处理流程
  - 文件：`app/lib/services/voice_service_coordinator.dart`
  - 添加 `processMultiIntentCommand()` 方法
  - 按优先级依次执行意图
  - 处理不完整意图的追问流程
  - 导航意图延后执行

- [x] 3.3 实现追问状态管理
  - 文件：`app/lib/services/voice_service_coordinator.dart`
  - 添加 waitingForMultiIntentConfirmation 和 waitingForAmountSupplement 状态
  - 记录待补充的意图信息
  - 支持批量金额补充
  - 实现 supplementAmount() 方法

## 4. 用户界面 - 确认和补充

- [x] 4.1 实现多意图确认组件
  - 文件：`app/lib/widgets/multi_intent_confirm_widget.dart`
  - 显示意图列表（完整/不完整/导航）
  - 支持单个意图的确认/取消/编辑
  - 批量确认按钮
  - 噪音折叠显示（可选展开）

- [x] 4.2 实现金额补充输入
  - 文件：`app/lib/widgets/amount_supplement_widget.dart`
  - 列表形式显示缺失金额的意图
  - 支持语音输入金额
  - 支持键盘快速输入
  - 支持跳过单个意图

- [x] 4.3 集成到语音助手页面
  - 文件：`app/lib/pages/enhanced_voice_assistant_page.dart`
  - 检测多意图场景触发确认UI
  - 处理用户确认/取消/补充操作
  - 更新对话历史显示

## 5. 可选增强 - AI辅助分解

- [x] 5.1 实现 Qwen 意图分解
  - 文件：`app/lib/services/voice/ai_intent_decomposer.dart`
  - 设计分解 prompt
  - 解析 JSON 返回结果
  - 异常处理和降级

- [x] 5.2 添加配置开关
  - 文件：`app/lib/services/voice/multi_intent_config.dart`
  - 多意图处理开关
  - AI辅助开关
  - 追问模式配置（逐个/批量）
  - 其他配置：自动确认单意图、显示噪音、置信度阈值

## 6. 测试和文档

- [ ] 6.1 单元测试
  - 测试分句器各种输入场景
  - 测试意图合并逻辑
  - 测试噪音过滤准确性
  - 测试完整性判断

- [ ] 6.2 集成测试
  - 测试多意图完整流程
  - 测试追问流程
  - 测试与现有单意图兼容性

- [ ] 6.3 文档更新
  - 更新语音助手使用文档
  - 记录多意图处理能力
  - 添加示例语句

## 依赖关系

```
1.1 → 1.2 → 1.3
      ↓
2.1 → 2.2 → 2.3
            ↓
      3.1 → 3.2 → 3.3
                  ↓
            4.1 → 4.2 → 4.3
                        ↓
                  5.1 → 5.2
                        ↓
                  6.1 → 6.2 → 6.3
```

## 可并行工作

- 1.2（分句器）和 1.3（噪音过滤器）可并行
- 4.1（确认组件）和 4.2（金额补充）可并行
- 5.x（AI增强）可独立开发
- 6.1（单元测试）可与开发同步进行

## 验证检查点

- [x] 分句器能正确处理各种标点和连接词
- [x] 意图合并器能正确区分完整和不完整意图
- [x] 噪音过滤器不会误删有效意图
- [x] 追问流程用户体验流畅
- [ ] 多意图处理延迟 < 500ms
- [x] 与现有单意图场景完全兼容
