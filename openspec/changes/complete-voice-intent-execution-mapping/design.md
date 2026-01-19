# 设计文档：完成语音意图执行层映射

## 架构概览

### 当前架构问题

```
用户语音输入
    ↓
VoiceIntentRouter (21种意图)
    ↓
SmartIntentRecognizer (6种操作类型)
    ↓
ActionRouter (12种Action) ← 映射不完整
    ↓
执行层 (部分TODO)
```

**问题**：
1. 三层意图类型系统映射复杂
2. 很多意图没有对应的执行器
3. BookkeepingOperationAdapter 实现不完整

### 目标架构

```
用户语音输入
    ↓
统一意图识别 (IntentType)
    ↓
ActionRouter (完整的Action集合)
    ↓
执行层 (完整实现)
```

## 核心设计

### 1. Action 分类体系

#### 1.1 交易操作 (Transaction Actions)
```dart
// 已实现
- transaction.expense    // 添加支出
- transaction.income     // 添加收入
- transaction.modify     // 修改交易
- transaction.delete     // 删除交易
- transaction.query      // 查询交易
```

#### 1.2 配置操作 (Config Actions)
```dart
// 已实现
- config.budget          // 预算设置
- config.account         // 账户设置
- config.reminder        // 提醒设置
- config.theme           // 主题设置

// 待实现
- config.category        // 分类管理
- config.tag             // 标签管理
- config.ledger          // 账本管理
- config.member          // 成员管理
- config.creditCard      // 信用卡管理
- config.savingsGoal     // 储蓄目标管理
- config.recurringTransaction  // 定期交易管理
```

#### 1.3 高级功能 (Advanced Actions)
```dart
// 待实现
- vault.create           // 创建小金库
- vault.query            // 查询小金库
- vault.transfer         // 小金库转账
- vault.budget           // 小金库预算

- moneyAge.query         // 查询钱龄
- moneyAge.reminder      // 钱龄提醒
- moneyAge.report        // 钱龄报告

- data.export            // 导出数据
- data.backup            // 备份数据
- data.statistics        // 数据统计

- habit.query            // 查询习惯
- habit.analysis         // 习惯分析
- habit.reminder         // 习惯提醒

- share.transaction      // 分享交易
- share.report           // 分享报告
- share.budget           // 分享预算

- system.settings        // 系统设置
- system.about           // 关于信息
- system.help            // 帮助文档
```

#### 1.4 自动化操作 (Automation Actions)
```dart
// 待实现
- automation.screenRecognition  // 屏幕识别
- automation.alipaySync         // 支付宝同步
- automation.wechatSync         // 微信同步
- automation.bankSync           // 银行同步
```

### 2. Action 基类设计

```dart
/// Action 基类
abstract class Action {
  /// Action ID (如 "transaction.expense")
  String get id;

  /// Action 显示名称
  String get displayName;

  /// 触发词列表
  List<String> get triggers;

  /// 执行 Action
  Future<ActionResult> execute(Map<String, dynamic> entities);

  /// 是否需要确认
  bool get requiresConfirmation => false;

  /// 是否需要参数
  List<String> get requiredParams => [];
}

/// 配置操作基类
abstract class ConfigAction extends Action {
  final IDatabaseService databaseService;

  ConfigAction(this.databaseService);

  @override
  bool get requiresConfirmation => true;
}

/// 数据操作基类
abstract class DataAction extends Action {
  final IDatabaseService databaseService;

  DataAction(this.databaseService);

  @override
  bool get requiresConfirmation => true;
}
```

### 3. 配置操作实现示例

#### 3.1 分类管理
```dart
class CategoryConfigAction extends ConfigAction {
  CategoryConfigAction(super.databaseService);

  @override
  String get id => 'config.category';

  @override
  String get displayName => '分类管理';

  @override
  List<String> get triggers => [
    '添加分类', '创建分类', '新建分类',
    '修改分类', '更改分类',
    '删除分类', '移除分类',
    '查询分类', '查看分类', '分类列表',
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> entities) async {
    final operation = entities['operation'] as String?; // add/modify/delete/query
    final categoryName = entities['categoryName'] as String?;

    switch (operation) {
      case 'add':
        return await _addCategory(categoryName!);
      case 'modify':
        return await _modifyCategory(categoryName!, entities);
      case 'delete':
        return await _deleteCategory(categoryName!);
      case 'query':
        return await _queryCategories();
      default:
        return ActionResult.failure('不支持的操作: $operation');
    }
  }

  Future<ActionResult> _addCategory(String name) async {
    try {
      final category = Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        type: CategoryType.expense,
        icon: 'default',
      );
      await databaseService.insertCategory(category);
      return ActionResult.success(
        message: '已添加分类: $name',
        data: {'categoryId': category.id},
      );
    } catch (e) {
      return ActionResult.failure('添加分类失败: $e');
    }
  }

  // ... 其他方法实现
}
```

#### 3.2 信用卡管理
```dart
class CreditCardConfigAction extends ConfigAction {
  CreditCardConfigAction(super.databaseService);

  @override
  String get id => 'config.creditCard';

  @override
  String get displayName => '信用卡管理';

  @override
  List<String> get triggers => [
    '添加信用卡', '绑定信用卡',
    '设置还款日', '信用卡还款',
    '查询信用卡', '信用卡列表',
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> entities) async {
    final operation = entities['operation'] as String?;

    switch (operation) {
      case 'add':
        return await _addCreditCard(entities);
      case 'setRepaymentDate':
        return await _setRepaymentDate(entities);
      case 'query':
        return await _queryCreditCards();
      default:
        return ActionResult.failure('不支持的操作: $operation');
    }
  }

  Future<ActionResult> _addCreditCard(Map<String, dynamic> entities) async {
    final cardName = entities['cardName'] as String?;
    final bankName = entities['bankName'] as String?;
    final creditLimit = entities['creditLimit'] as double?;

    if (cardName == null) {
      return ActionResult.needParams(
        missing: ['cardName'],
        prompt: '请告诉我信用卡名称',
      );
    }

    try {
      final creditCard = CreditCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: cardName,
        bankName: bankName ?? '未知银行',
        creditLimit: creditLimit ?? 0,
        billingDay: 1,
        repaymentDay: 20,
      );
      await databaseService.insertCreditCard(creditCard);
      return ActionResult.success(
        message: '已添加信用卡: $cardName',
        data: {'cardId': creditCard.id},
      );
    } catch (e) {
      return ActionResult.failure('添加信用卡失败: $e');
    }
  }

  // ... 其他方法实现
}
```

### 4. 高级功能实现示例

#### 4.1 小金库操作
```dart
class VaultQueryAction extends Action {
  final VaultRepository vaultRepository;

  VaultQueryAction(this.vaultRepository);

  @override
  String get id => 'vault.query';

  @override
  String get displayName => '查询小金库';

  @override
  List<String> get triggers => [
    '查询小金库', '小金库余额', '查看小金库',
    '我的小金库', '小金库有多少钱',
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> entities) async {
    final vaultName = entities['vaultName'] as String?;

    try {
      if (vaultName != null) {
        // 查询特定小金库
        final vault = await vaultRepository.getVaultByName(vaultName);
        if (vault == null) {
          return ActionResult.failure('未找到小金库: $vaultName');
        }
        return ActionResult.success(
          message: '$vaultName 余额: ${vault.balance}元',
          data: {'vault': vault},
        );
      } else {
        // 查询所有小金库
        final vaults = await vaultRepository.getAllVaults();
        final totalBalance = vaults.fold(0.0, (sum, v) => sum + v.balance);
        return ActionResult.success(
          message: '共有${vaults.length}个小金库，总余额: $totalBalance元',
          data: {'vaults': vaults, 'totalBalance': totalBalance},
        );
      }
    } catch (e) {
      return ActionResult.failure('查询小金库失败: $e');
    }
  }
}
```

#### 4.2 钱龄操作
```dart
class MoneyAgeQueryAction extends Action {
  final IDatabaseService databaseService;

  MoneyAgeQueryAction(this.databaseService);

  @override
  String get id => 'moneyAge.query';

  @override
  String get displayName => '查询钱龄';

  @override
  List<String> get triggers => [
    '查询钱龄', '钱龄健康度', '查看钱龄',
    '我的钱龄', '钱龄报告',
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> entities) async {
    try {
      // 获取最近的交易记录
      final transactions = await databaseService.getTransactions();

      // 计算平均钱龄
      final expenseTransactions = transactions
          .where((t) => t.type == TransactionType.expense && t.moneyAge != null)
          .toList();

      if (expenseTransactions.isEmpty) {
        return ActionResult.success(
          message: '暂无钱龄数据',
          data: {'averageMoneyAge': 0},
        );
      }

      final totalMoneyAge = expenseTransactions.fold(
        0, (sum, t) => sum + (t.moneyAge ?? 0)
      );
      final averageMoneyAge = totalMoneyAge / expenseTransactions.length;

      // 判断健康等级
      String healthLevel;
      if (averageMoneyAge < 30) {
        healthLevel = 'health';
      } else if (averageMoneyAge < 60) {
        healthLevel = 'warning';
      } else {
        healthLevel = 'danger';
      }

      return ActionResult.success(
        message: '平均钱龄: ${averageMoneyAge.toStringAsFixed(1)}天，健康等级: $healthLevel',
        data: {
          'averageMoneyAge': averageMoneyAge,
          'healthLevel': healthLevel,
          'transactionCount': expenseTransactions.length,
        },
      );
    } catch (e) {
      return ActionResult.failure('查询钱龄失败: $e');
    }
  }
}
```

### 5. 自动化功能实现示例

#### 5.1 屏幕识别
```dart
class ScreenRecognitionAction extends Action {
  final OCRService ocrService;
  final IDatabaseService databaseService;

  ScreenRecognitionAction(this.ocrService, this.databaseService);

  @override
  String get id => 'automation.screenRecognition';

  @override
  String get displayName => '屏幕识别记账';

  @override
  List<String> get triggers => [
    '识别屏幕', '读取屏幕', '扫描屏幕',
    '屏幕记账', '识别账单',
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> entities) async {
    try {
      // 1. 截取屏幕
      final screenshot = await _captureScreen();

      // 2. OCR 识别
      final ocrResult = await ocrService.recognize(screenshot);

      // 3. 解析账单信息
      final billInfo = _parseBillInfo(ocrResult);

      if (billInfo == null) {
        return ActionResult.failure('未识别到账单信息');
      }

      // 4. 创建交易记录
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: TransactionType.expense,
        amount: billInfo.amount,
        category: billInfo.category ?? '其他',
        note: billInfo.merchant,
        date: billInfo.date ?? DateTime.now(),
        accountId: 'default',
        source: TransactionSource.image,
        aiConfidence: billInfo.confidence,
      );

      await databaseService.insertTransaction(transaction);

      return ActionResult.success(
        message: '已识别并记录: ${billInfo.merchant} ${billInfo.amount}元',
        data: {'transaction': transaction},
      );
    } catch (e) {
      return ActionResult.failure('屏幕识别失败: $e');
    }
  }

  Future<Uint8List> _captureScreen() async {
    // 实现屏幕截图逻辑
    throw UnimplementedError();
  }

  BillInfo? _parseBillInfo(OCRResult result) {
    // 实现账单信息解析逻辑
    throw UnimplementedError();
  }
}
```

### 6. Action 注册机制

#### 6.1 当前手动注册
```dart
class ActionRouter {
  void _registerBuiltInActions() {
    _registry.registerAll([
      _TransactionExpenseAction(_databaseService),
      _TransactionIncomeAction(_databaseService),
      // ... 手动注册每个Action
    ]);
  }
}
```

#### 6.2 目标自动注册
```dart
// 使用注解标记Action
@RegisterAction()
class CategoryConfigAction extends ConfigAction {
  // ...
}

// ActionRouter 自动发现和注册
class ActionRouter {
  void _registerBuiltInActions() {
    // 自动扫描所有带 @RegisterAction 注解的类
    final actions = ActionRegistry.discoverActions();
    _registry.registerAll(actions);
  }
}
```

## 实施策略

### 阶段1：快速修复（1周）
1. 完善 BookkeepingOperationAdapter 的导航操作
2. 实现7个配置Action
3. 确保基础功能完整可用

### 阶段2：高级功能（2周）
1. 实现小金库、钱龄、数据、习惯、分享、系统操作
2. 每个功能模块独立开发和测试
3. 逐步集成到 ActionRouter

### 阶段3：自动化功能（1-2周）
1. 集成 OCR 服务
2. 实现屏幕识别
3. 实现账单同步
4. 处理异步和错误情况

### 阶段4：架构优化（1周）
1. 设计统一的意图类型系统
2. 实现自动注册机制
3. 重构现有代码
4. 更新文档

## 测试策略

### 单元测试
- 每个 Action 独立测试
- Mock 依赖服务
- 覆盖正常和异常情况

### 集成测试
- 测试 ActionRouter 路由逻辑
- 测试意图识别到执行的完整流程
- 测试多个 Action 的交互

### 端到端测试
- 模拟真实语音输入
- 验证完整的语音交互流程
- 测试各种边界情况

## 性能优化

### 1. Action 缓存
- 缓存已注册的 Action
- 避免重复创建实例

### 2. 异步执行
- 非关键操作异步执行
- 使用任务队列管理

### 3. 批量操作
- 支持批量配置修改
- 减少数据库访问次数

## 安全考虑

### 1. 权限检查
- 敏感操作需要确认
- 数据导出需要权限验证

### 2. 数据验证
- 验证用户输入
- 防止 SQL 注入

### 3. 错误处理
- 优雅处理异常
- 避免敏感信息泄露

## 总结

本设计文档提供了完整的意图执行层映射方案，包括：
- 95个任务的详细实施计划
- 清晰的 Action 分类体系
- 完整的代码实现示例
- 分阶段的实施策略
- 全面的测试和优化方案

预计4-6周完成所有工作，最终实现语音功能的完整覆盖。
