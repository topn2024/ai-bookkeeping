# 实施任务清单

## 阶段1：参数化导航（核心功能）

### 1.1 增强 LLM Prompt
- [x] 1.1.1 修改 `SmartIntentRecognizer._buildMultiOperationLLMPrompt`
  - 添加导航参数说明（category, timeRange, source, account）
  - 添加带参数的导航示例
  - 文件：`lib/services/voice/smart_intent_recognizer.dart`

### 1.2 修改导航适配器
- [x] 1.2.1 修改 `BookkeepingOperationAdapter._navigate` 方法
  - 从 params 中提取导航参数
  - 将参数包装在 navigationParams 中返回
  - 文件：`lib/services/voice/adapters/bookkeeping_operation_adapter.dart`

### 1.3 修改导航执行器
- [x] 1.3.1 修改 `VoiceNavigationExecutor.navigateTo` 方法签名
  - 添加可选 params 参数
  - 文件：`lib/services/voice_navigation_executor.dart`

- [x] 1.3.2 修改 `_getPageForRoute` 方法
  - 接受 params 参数
  - 根据路由和参数构造页面
  - 文件：`lib/services/voice_navigation_executor.dart`

- [x] 1.3.3 添加 `_parseTimeRange` 辅助方法
  - 将时间范围字符串转换为 DateTimeRange
  - 文件：`lib/services/voice_navigation_executor.dart`

### 1.4 修改页面构造函数
- [x] 1.4.1 修改 `TransactionListPage` 构造函数
  - 添加 categoryFilter, sourceFilter, timeRange 参数
  - 在 initState 中应用初始筛选条件
  - 文件：`lib/pages/transaction_list_page.dart`

- [x] 1.4.2 检查并修改 `StatisticsCategoryPage`（如存在）
  - 添加 initialCategory, timeRange 参数
  - 文件：`lib/pages/statistics/category_page.dart`（待确认路径）
  - 注：使用 CategoryDetailPage 代替

### 1.5 修改调用链
- [x] 1.5.1 更新调用链以传递 navigationParams
  - 在 `IntelligenceEngine` 中添加导航回调机制
  - 在 `VoiceServiceCoordinator` 中注册导航处理器
  - 确保 navigationParams 正确传递到 `navigateToRoute`
  - 文件：`lib/services/voice/intelligence_engine/intelligence_engine.dart`
  - 文件：`lib/services/voice_service_coordinator.dart`

### 1.6 测试验证
- [x] 1.6.1 创建测试框架
  - 创建测试结果文档
  - 创建单元测试文件框架
  - 文件：`openspec/changes/add-parameterized-voice-navigation/test-results.md`
  - 文件：`app/test/services/voice_navigation_parameterized_test.dart`

- [ ] 1.6.2 编写单元测试
  - 测试 LLM prompt 参数提取
  - 测试适配器参数传递
  - 测试执行器参数处理

- [ ] 1.6.3 集成测试
  - "查看餐饮类的账单" → 验证打开交易列表页+餐饮筛选
  - "看看本周的交通消费" → 验证打开分类统计+交通+本周
  - "查看支付宝的支出" → 验证打开交易列表+支付宝来源

## 阶段2：复合操作支持（可选，根据阶段1反馈决定）

### 2.1 增强 LLM Prompt 支持多操作
- [ ] 2.1.1 添加复合操作识别示例
  - 识别操作序列
  - 标记操作间的依赖关系

### 2.2 实现操作结果传递
- [ ] 2.2.1 修改 `DualChannelProcessor`
  - 保存前一操作的执行结果
  - 传递给依赖该结果的后续操作

### 2.3 测试验证
- [ ] 2.3.1 集成测试
  - "把今天的支出做个分类" → 验证查询+分类编辑组合

## 验收检查

### 功能验收
- [ ] 无参数导航仍正常工作（回归测试）
- [ ] 带分类参数的导航正常工作
- [ ] 带时间范围的导航正常工作
- [ ] 带来源参数的导航正常工作
- [ ] 多参数组合导航正常工作

### 性能验收
- [ ] 参数化导航响应时间与无参数导航相当（< 500ms 差异）

### 兼容性验收
- [ ] 现有语音功能不受影响
- [ ] 无效参数静默忽略，不影响导航
