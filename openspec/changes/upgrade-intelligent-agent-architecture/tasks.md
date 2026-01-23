# 任务清单

## 阶段 1：InputFilter 输入预过滤器

### 1.1 创建 InputFilter 基础结构
- [ ] 创建 `app/lib/services/voice/input_filter.dart`
- [ ] 定义 `InputCategory` 枚举（noise/emotion/feedback/processable）
- [ ] 定义 `FeedbackType` 枚举（confirm/cancel/hesitate/repeat）
- [ ] 定义 `EmotionType` 枚举（positive/negative/surprise/frustration）
- [ ] 定义 `InputFilterResult` 数据类

**验证**：单元测试覆盖各分类类型

### 1.2 实现分类规则
- [ ] 实现 noise 识别（语气词模式、填充词模式）
- [ ] 实现 feedback 识别（确认/取消/犹豫/重复模式）
- [ ] 实现 emotion 识别（重复字符检测 + 情感词库）
- [ ] 配置可调整的模式列表

**验证**：测试用例覆盖边界情况

### 1.3 集成到 IntelligenceEngine
- [ ] 在 `IntelligenceEngine.process()` 最前端调用 InputFilter
- [ ] 实现 noise 处理（静默返回）
- [ ] 实现 emotion 处理（情感回复生成）
- [ ] 实现 feedback 处理（确认/取消/犹豫/重复）
- [ ] processable 走现有意图识别流程

**验证**：端到端测试各分类场景

---

## 阶段 2：DynamicAggregationWindow 动态聚合窗口

### 2.1 创建动态聚合窗口
- [ ] 创建 `app/lib/services/voice/dynamic_aggregation_window.dart`
- [ ] 定义等待时间常量（min/short/default/extended/max）
- [ ] 实现连接词/未完成信号检测
- [ ] 实现列举模式检测
- [ ] 实现完整交易检测
- [ ] 实现 `calculateWaitTime()` 方法

**验证**：单元测试各场景的等待时间计算

### 2.2 集成到 VoicePipelineController
- [ ] 引入 DynamicAggregationWindow
- [ ] 修改 `_onAsrResult()` 实现滑动窗口机制
- [ ] 每次 ASR 返回时取消旧计时器、启动新计时器
- [ ] 记录 `_lastSpeechEndTime` 用于计算停顿时长
- [ ] 添加 5000ms 最大等待时间兜底

**验证**：验证多笔交易聚合效果，测试边界情况

---

## 阶段 3：ResultBuffer 结果缓冲

### 3.1 创建 ResultBuffer 基础结构
- [ ] 创建 `app/lib/services/voice/intelligence_engine/result_buffer.dart`
- [ ] 定义 `ResultPriority` 枚举（critical/normal/low）
- [ ] 定义 `ResultStatus` 枚举（pending/notified/expired/suppressed）
- [ ] 定义 `BufferedResult` 数据类
- [ ] 实现 `ResultBuffer` 类（add/getPending/markNotified/markSuppressed）

**验证**：单元测试缓冲操作

### 3.2 实现优先级和过期逻辑
- [ ] 实现优先级计算（删除操作→critical，大额→critical）
- [ ] 实现 30 秒过期清理
- [ ] 实现缓冲区大小限制（最多 10 条）
- [ ] 实现 `getSummaryForContext()` 方法

**验证**：验证优先级排序和过期清理

### 3.3 集成执行结果
- [ ] 修改 IntelligenceEngine，操作执行完成后加入 ResultBuffer
- [ ] 实现异步执行逻辑（立即返回确认，后台执行）

**验证**：验证结果正确入队

---

## 阶段 4：TimingJudge 时机判断器

### 4.1 创建 TimingJudge 基础结构
- [ ] 创建 `app/lib/services/voice/intelligence_engine/timing_judge.dart`
- [ ] 定义 `NotificationTiming` 枚举（immediate/natural/onIdle/onTopicShift/defer/suppress）
- [ ] 定义 `TimingContext` 数据类

**验证**：基础结构编译通过

### 4.2 实现规则层判断
- [ ] 实现用户询问结果检测（→ immediate）
- [ ] 实现用户情绪检测（负面 → defer）
- [ ] 实现用户沉默检测（> 5秒 → onIdle）
- [ ] 实现对话模式判断（chat → defer，mixed → natural）
- [ ] 实现 `judgeByRules()` 方法

**验证**：规则层判断准确性

### 4.3 实现通知文本生成
- [ ] 实现 `generateNotification()` 方法
- [ ] 不同时机使用不同前缀（"对了"、"顺便说一下"等）
- [ ] 支持多条结果合并

**验证**：通知文本自然度

### 4.4 集成到对话流程
- [ ] 在操作执行完成后调用 TimingJudge
- [ ] 在用户沉默时定期检查（与主动话题机制协同）
- [ ] 通过 TTS 播放通知
- [ ] 播放后标记结果为已通知

**验证**：端到端测试时机判断

---

## 阶段 5：执行层与对话层分离

### 5.1 重构操作执行流程
- [ ] 修改 `_handleOperations()` 为异步执行模式
- [ ] 立即返回简短确认（"好的"/"好的，N笔"）
- [ ] 后台执行操作，完成后加入 ResultBuffer

**验证**：操作不阻塞对话

### 5.2 增强对话上下文
- [ ] 修改 ChatEngine，注入 ResultBuffer 上下文
- [ ] 确保闲聊时可以自然融入执行结果
- [ ] 实现 TimingJudge 与 ChatEngine 协同

**验证**：验证对话连贯性

---

## 阶段 6：集成测试与调优

### 6.1 端到端场景测试
- [ ] 测试场景：连续多笔交易（3-5笔）
- [ ] 测试场景：语气词/情绪表达
- [ ] 测试场景：记账后闲聊
- [ ] 测试场景：用户确认/取消
- [ ] 测试场景：用户主动询问结果

**验证**：所有场景符合预期

### 6.2 参数调优
- [ ] 调整等待时间参数（min/default/extended）
- [ ] 调整沉默检测阈值（当前 5 秒）
- [ ] 调整结果过期时间（当前 30 秒）
- [ ] 收集反馈并优化规则

**验证**：用户体验测试

---

## 依赖关系

```
阶段1 InputFilter ──────────────────────────────┐
       │                                        │
       ▼                                        │
阶段2 DynamicAggregationWindow（可与阶段1并行）  │
       │                                        │
       ▼                                        │
阶段3 ResultBuffer ←────────────────────────────┘
       │
       ▼
阶段4 TimingJudge
       │
       ▼
阶段5 执行层与对话层分离
       │
       ▼
阶段6 集成测试与调优
```

## 可并行工作

- **阶段 1 和 阶段 2 可并行开发**：InputFilter 和 DynamicAggregationWindow 相互独立
- **阶段 3 依赖阶段 1**：ResultBuffer 需要在 IntelligenceEngine 中使用
- **阶段 4 依赖阶段 3**：TimingJudge 需要 ResultBuffer 提供待通知结果
- **阶段 5 依赖阶段 3 和 4**：执行层分离需要 ResultBuffer 和 TimingJudge
- **阶段 6 依赖所有阶段**：集成测试需要所有组件就绪

## 预估工作量

| 阶段 | 预估 | 说明 |
|------|------|------|
| 阶段 1 | 中 | 规则实现+集成 |
| 阶段 2 | 小 | 逻辑简单，主要是集成 |
| 阶段 3 | 小 | 数据结构简单 |
| 阶段 4 | 中 | 规则设计+集成 |
| 阶段 5 | 中 | 重构现有流程 |
| 阶段 6 | 中 | 测试和调优 |
