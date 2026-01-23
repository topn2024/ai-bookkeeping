# 技术设计：语音意图参数化与复合操作支持

## 上下文

### 现有架构

```
用户语音输入
    ↓
SmartIntentRecognizer (LLM + 规则)
    ↓ 输出: MultiOperationResult
    ↓   - operations: [{type, priority, params, originalText}]
    ↓
DualChannelProcessor
    ├── ExecutionChannel → BookkeepingOperationAdapter
    │                          ↓
    │                      _navigate() → VoiceNavigationService.parseNavigation()
    │                          ↓ 只返回 route，无参数
    │
    └── ConversationChannel → 生成语音反馈
                                   ↓
                               VoiceNavigationExecutor.navigateTo(route)
                                   ↓ 无参数传递
                               _getPageForRoute(route)
                                   ↓ 构造无参页面
                               TransactionListPage()  ← 无筛选条件
```

### 问题分析

1. **LLM Prompt 不提取导航参数**
   - 当前只提取 `targetPage` 和 `route`
   - 未定义 `category`、`timeRange`、`source` 等筛选参数

2. **适配器不传递参数**
   - `_navigate()` 只返回 route 信息
   - 即使 LLM 提取了参数也会丢失

3. **执行器不使用参数**
   - `navigateTo(String route)` 方法签名不接受参数
   - `_getPageForRoute()` 硬编码页面构造

## 目标 / 非目标

### 目标
- 支持"查看餐饮类的账单"这类带参数的语音导航
- 保持现有无参数导航的兼容性
- 最小化代码改动

### 非目标
- 不修改 `PageConfig` 结构（避免大规模改动）
- 不实现完整的复合操作编排（第二阶段可选）
- 不支持所有页面的参数化（先实现核心页面）

## 决策

### 方案选择：LLM参数提取 + 适配器透传

选择此方案而非修改 `PageConfig` 的原因：
1. **改动范围小**：只需修改3-4个文件
2. **向后兼容**：不影响现有导航逻辑
3. **易于扩展**：添加新参数类型只需修改 prompt

```
用户输入: "查看餐饮类的账单"
    ↓
SmartIntentRecognizer (增强LLM prompt)
    ↓ 提取: {
    ↓   type: "navigate",
    ↓   params: {
    ↓     route: "/transaction-list",
    ↓     category: "餐饮"  ← 新增
    ↓   }
    ↓ }
    ↓
BookkeepingOperationAdapter._navigate()
    ↓ 返回: {
    ↓   route: "/transaction-list",
    ↓   navigationParams: {category: "餐饮"}  ← 新增
    ↓ }
    ↓
VoiceNavigationExecutor.navigateTo(route, params)  ← 改签名
    ↓
_getPageForRoute(route, params)  ← 改签名
    ↓
TransactionListPage(categoryFilter: "餐饮")  ← 传参数
```

### 考虑的替代方案

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| 修改 PageConfig 支持参数模板 | 集中管理 | 改动大，影响237个页面配置 | 拒绝 |
| 使用路由参数 `/transaction-list?category=餐饮` | URL标准 | 需改造路由系统 | 拒绝 |
| LLM + 适配器透传（本方案） | 改动小，灵活 | 参数类型需手动维护 | 采用 |

## 详细设计

### 1. 增强 LLM Prompt

文件：`lib/services/voice/smart_intent_recognizer.dart`

在 `_buildMultiOperationLLMPrompt` 中添加：

```dart
【导航操作参数】
- targetPage: 目标页面名称
- route: 目标路由（可选）
- category: 分类筛选（餐饮/交通/购物/娱乐/居住/医疗/其他）
- timeRange: 时间范围（今天/昨天/本周/本月/上月）
- account: 账户筛选
- source: 来源筛选（支付宝/微信/银行卡等）

【导航示例】
输入："查看餐饮类的账单"
输出：{"result_type":"operation","operations":[{"type":"navigate","priority":"immediate","params":{"targetPage":"交易列表","route":"/transaction-list","category":"餐饮"}}]}

输入："看看本周的交通消费"
输出：{"result_type":"operation","operations":[{"type":"navigate","priority":"immediate","params":{"targetPage":"分类统计","route":"/statistics/category","category":"交通","timeRange":"本周"}}]}
```

### 2. 修改导航适配器

文件：`lib/services/voice/adapters/bookkeeping_operation_adapter.dart`

```dart
Future<ExecutionResult> _navigate(Map<String, dynamic> params) async {
  final targetPage = params['targetPage'] as String?;
  final route = params['route'] as String?;

  // 提取导航参数
  final navigationParams = <String, dynamic>{};
  for (final key in ['category', 'timeRange', 'source', 'account']) {
    if (params.containsKey(key)) {
      navigationParams[key] = params[key];
    }
  }

  // 解析路由
  String? finalRoute = route;
  if (finalRoute == null && targetPage != null) {
    final navigationResult = _navigationService.parseNavigation(targetPage);
    if (navigationResult.success) {
      finalRoute = navigationResult.route;
    }
  }

  if (finalRoute != null) {
    return ExecutionResult.success(data: {
      'route': finalRoute,
      'targetPage': targetPage,
      'navigationParams': navigationParams,  // 新增
    });
  }

  return ExecutionResult.failure('无法识别导航目标');
}
```

### 3. 修改导航执行器

文件：`lib/services/voice_navigation_executor.dart`

```dart
// 修改方法签名
Future<bool> navigateTo(String route, {Map<String, dynamic>? params}) async {
  // ...
  final page = _getPageForRoute(route, params);
  // ...
}

// 修改页面构造
Widget? _getPageForRoute(String route, Map<String, dynamic>? params) {
  switch (route) {
    case '/transaction-list':
      return TransactionListPage(
        categoryFilter: params?['category'] as String?,
        sourceFilter: params?['source'] as String?,
        timeRange: _parseTimeRange(params?['timeRange']),
      );
    case '/statistics/category':
      return StatisticsCategoryPage(
        initialCategory: params?['category'] as String?,
        timeRange: _parseTimeRange(params?['timeRange']),
      );
    // 其他页面保持原样
    default:
      return _getDefaultPageForRoute(route);
  }
}

// 辅助方法
DateTimeRange? _parseTimeRange(String? range) {
  if (range == null) return null;
  final now = DateTime.now();
  switch (range) {
    case '今天':
      return DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: now,
      );
    case '本周':
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return DateTimeRange(
        start: DateTime(weekStart.year, weekStart.month, weekStart.day),
        end: now,
      );
    // ... 其他时间范围
  }
  return null;
}
```

### 4. 修改页面构造函数

文件：`lib/pages/transaction_list_page.dart`

```dart
class TransactionListPage extends ConsumerStatefulWidget {
  final String? categoryFilter;
  final String? sourceFilter;
  final DateTimeRange? timeRange;

  const TransactionListPage({
    super.key,
    this.categoryFilter,
    this.sourceFilter,
    this.timeRange,
  });

  @override
  ConsumerState<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  @override
  void initState() {
    super.initState();
    // 应用初始筛选条件
    if (widget.categoryFilter != null) {
      _selectedCategory = widget.categoryFilter;
    }
    if (widget.sourceFilter != null) {
      _selectedSource = widget.sourceFilter;
    }
    if (widget.timeRange != null) {
      _dateRange = widget.timeRange;
    }
  }
  // ...
}
```

## 风险 / 权衡

### 风险1：LLM 参数提取不准确
- **缓解**：在适配器层添加参数校验，无效参数直接忽略
- **监控**：记录参数提取日志用于后续优化

### 风险2：页面不支持所有参数组合
- **缓解**：先实现最常用的参数组合
- **降级**：不支持的参数静默忽略，仍能打开页面

### 风险3：与现有导航逻辑冲突
- **缓解**：params 参数可选，现有调用不受影响
- **测试**：添加无参数和有参数两种测试用例

## 迁移计划

1. **第一步**：修改 LLM prompt，不影响现有逻辑
2. **第二步**：修改适配器，提取但不使用参数
3. **第三步**：修改执行器和页面，完成端到端

回滚策略：每一步都可独立回滚

## 待决问题

1. **参数标准化**：用户说"饮食"和"餐饮"是否都应匹配餐饮分类？
   - 建议：在适配器层做同义词映射

2. **复合操作优先级**：第二阶段是否需要？
   - 建议：先完成阶段1，根据用户反馈决定

## 附录：支持的参数类型

| 参数 | 类型 | 可选值 | 说明 |
|------|------|--------|------|
| category | String | 餐饮/交通/购物/娱乐/居住/医疗/其他 | 分类筛选 |
| timeRange | String | 今天/昨天/本周/本月/上月/今年 | 时间范围 |
| source | String | 支付宝/微信/银行卡/现金 | 来源筛选 |
| account | String | 任意账户名称 | 账户筛选 |
| transactionType | String | income/expense | 交易类型 |
