# 语音意图执行系统

## 概述

语音意图执行系统负责将用户的语音指令转换为具体的业务操作。系统采用分层架构，支持100+种语音操作。

## 架构图

```
用户语音输入
    ↓
┌─────────────────────────────────────┐
│      SmartIntentRecognizer          │  意图识别层
│  (LLM优先，规则兜底)                  │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│      UnifiedIntentType              │  统一意图类型
│  (45+意图类型，9大类别)               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│         ActionRouter                │  行为路由层
│  (意图 → Action 映射)                │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│         ActionRegistry              │  行为注册表
│  (管理所有可执行Action)              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│           Actions                   │  具体行为
│  (交易/导航/配置/数据/自动化等)        │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│         Services                    │  业务服务层
│  (DatabaseService, NavigationService)│
└─────────────────────────────────────┘
```

## 核心组件

### 1. UnifiedIntentType (统一意图类型)

位置: `unified_intent_type.dart`

#### 意图类别

| 类别 | 说明 | 示例 |
|------|------|------|
| transaction | 交易操作 | add, query, modify, delete |
| navigation | 页面导航 | page, back, home |
| configuration | 配置管理 | category, tag, ledger |
| data | 数据操作 | export, backup, statistics |
| advanced | 高级功能 | vault, moneyAge, habit |
| automation | 自动化 | screenRecognition, sync |
| conversation | 会话控制 | confirm, cancel, clarify |
| system | 系统操作 | settings, about, help |

#### 使用示例

```dart
// 获取意图类型
final intentType = UnifiedIntentType.transactionAdd;

// 检查属性
print(intentType.id);              // "transaction.add"
print(intentType.category);        // IntentCategory.transaction
print(intentType.priority);        // OperationPriority.deferred
print(intentType.requiresConfirmation); // false

// 根据ID查找
final type = UnifiedIntentType.fromId('transaction.delete');

// 获取某类别下的所有意图
final transactionIntents = UnifiedIntentType.byCategory(IntentCategory.transaction);
```

### 2. ActionRouter (行为路由器)

位置: `action_router.dart`

#### 创建方式

```dart
// 方式1: 传统方式（手动注册）
final router = ActionRouter(
  databaseService: myDb,
  navigationService: myNav,
);
router.onNavigate = (route) => navigateTo(route);

// 方式2: 自动注册（推荐）
final router = ActionRouter.withAutoRegistry(
  databaseService: myDb,
  navigationService: myNav,
  onNavigate: (route) => navigateTo(route),
);
```

#### 执行意图

```dart
// 方式1: 使用IntentResult
final result = await router.execute(intentResult);

// 方式2: 使用UnifiedIntentType
final result = await router.executeByIntentType(
  UnifiedIntentType.transactionAdd,
  params: {'amount': 100, 'category': '餐饮'},
);

// 方式3: 使用UnifiedIntentResult
final result = await router.executeUnifiedIntent(unifiedResult);
```

### 3. ActionRegistry (行为注册表)

位置: `action_registry.dart`

```dart
// 获取单例
final registry = ActionRegistry.instance;

// 注册Action
registry.register(MyCustomAction());

// 批量注册
registry.registerAll([Action1(), Action2()]);

// 查找Action
final action = registry.findById('transaction.expense');
final actions = registry.findByTrigger('记一笔');
```

### 4. ActionAutoRegistry (自动注册系统)

位置: `action_auto_registry.dart`

```dart
// 定义ActionProvider
final myProviders = [
  ActionProviderMeta(
    id: 'custom.action',
    category: 'custom',
    description: '自定义操作',
    factory: (deps) => MyCustomAction(deps.databaseService),
  ),
];

// 注册Provider
ActionAutoRegistry.instance.registerProviders(myProviders);

// 执行自动注册
final deps = ActionDependencies(
  databaseService: myDb,
  navigationService: myNav,
);
ActionAutoRegistry.instance.registerAll(deps);
```

## 创建自定义Action

### 步骤1: 继承Action基类

```dart
class MyCustomAction extends Action {
  final IDatabaseService _db;

  MyCustomAction(this._db);

  @override
  String get id => 'custom.myAction';

  @override
  String get name => '我的操作';

  @override
  String get description => '这是一个自定义操作';

  @override
  List<String> get triggerPatterns => ['触发词1', '触发词2'];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'param1',
      type: ActionParamType.string,
      description: '参数1',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      // 实现业务逻辑
      return ActionResult.success(
        responseText: '操作成功',
        data: {'result': 'ok'},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('操作失败: $e', actionId: id);
    }
  }
}
```

### 步骤2: 注册Action

#### 方式A: 手动注册

在 `action_router.dart` 的 `_registerBuiltInActions()` 中添加：

```dart
_registry.register(MyCustomAction(_databaseService));
```

#### 方式B: 使用自动注册

在 `action_auto_registry.dart` 中添加Provider：

```dart
List<ActionProviderMeta> get customActionProviders => [
  ActionProviderMeta(
    id: 'custom.myAction',
    category: 'custom',
    description: '我的操作',
    factory: (deps) => MyCustomAction(deps.databaseService),
  ),
];
```

## Action结果类型

```dart
// 成功
ActionResult.success(
  responseText: 'TTS播报文本',
  data: {'key': 'value'},
  actionId: 'action.id',
);

// 失败
ActionResult.failure('错误信息', actionId: 'action.id');

// 需要补充参数
ActionResult.needParams(
  missing: ['amount'],
  prompt: '请告诉我金额',
  actionId: 'action.id',
);

// 需要确认（4级确认系统）
ActionResult.lightConfirmation(message: '确认删除吗？');
ActionResult.standardConfirmation(message: '确认修改吗？');
ActionResult.strictConfirmation(message: '确认清空数据吗？');
ActionResult.blocked(reason: '此操作需要手动执行', redirectRoute: '/settings');
```

## 已实现的Actions

### 交易操作
- `transaction.expense` - 记录支出
- `transaction.income` - 记录收入
- `transaction.query` - 查询交易
- `transaction.modify` - 修改交易
- `transaction.delete` - 删除交易

### 配置操作
- `config.category` - 分类管理
- `config.tag` - 标签管理
- `config.ledger` - 账本管理
- `config.member` - 成员管理
- `config.creditCard` - 信用卡管理
- `config.savingsGoal` - 储蓄目标
- `config.recurring` - 定期交易

### 数据操作
- `data.export` - 导出数据 (CSV/Excel/JSON)
- `data.backup` - 备份数据 (本地/云端/自动)
- `data.statistics` - 数据统计

### 高级功能
- `vault.*` - 小金库操作
- `moneyAge.*` - 钱龄操作
- `habit.*` - 消费习惯
- `share.*` - 分享功能

### 自动化
- `automation.screenRecognition` - 屏幕识别
- `automation.alipaySync` - 支付宝同步
- `automation.wechatSync` - 微信同步
- `automation.bankSync` - 银行同步
- `automation.emailParse` - 邮箱解析
- `automation.scheduled` - 定时记账

### 系统操作
- `system.settings` - 系统设置
- `system.about` - 关于信息
- `system.help` - 使用帮助
- `system.feedback` - 用户反馈

## 测试

测试文件位于 `test/services/voice/` 目录：

```bash
# 运行所有语音相关测试
flutter test test/services/voice/

# 运行特定测试
flutter test test/services/voice/unified_intent_type_test.dart
flutter test test/services/voice/action_auto_registry_test.dart

# 生成mock文件
flutter pub run build_runner build --delete-conflicting-outputs
```

## 向后兼容

系统提供了与旧代码的兼容层：

```dart
// VoiceIntentType → UnifiedIntentType
final unified = VoiceIntentTypeMapping.fromLegacyVoiceIntent('addTransaction');

// UnifiedIntentType → VoiceIntentType
final legacy = UnifiedIntentType.transactionAdd.toLegacyVoiceIntentName();

// OperationType → UnifiedIntentType
final unified = OperationTypeMapping.fromLegacyOperationType('navigate');
```

## 性能考虑

- Action注册采用延迟初始化
- 使用单例模式减少内存占用
- 支持按需加载Action模块
- 意图匹配使用高效的Map查找

## 更新日志

### 2026-01-18
- 实现统一意图类型系统 (UnifiedIntentType)
- 实现自动注册机制 (ActionAutoRegistry)
- 完成100+个Action实现
- 添加100个单元测试
