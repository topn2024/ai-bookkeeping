# 移除传统预算系统规范

## 规范信息

- **规范ID**: remove-budget-system
- **变更ID**: remove-traditional-budget
- **版本**: v1.0
- **状态**: 草稿
- **创建日期**: 2026-01-25

---

## 移除需求

### 需求：传统预算系统

系统必须移除所有传统预算相关的代码和数据，只保留零基预算（小金库）系统。

**需求ID**: RBS-001
**优先级**: P0（必须）

**影响范围**:
- 数据模型和数据表
- Provider 和 Service
- UI 页面和组件
- 语音助手和报表

**迁移方案**:
- 删除 `budgets` 表
- 删除 `Budget` 模型
- 删除所有传统预算相关的代码
- 保留零基预算（BudgetVault）系统

#### 场景：删除传统预算数据表

**前置条件**:
- 数据库已备份
- 确认用户数据为空（0个预算）

**操作步骤**:
1. 应用启动
2. 检测到数据库版本需要升级
3. 执行迁移脚本
4. 删除 `budgets` 表
5. 删除 `budget_carryovers` 表
6. 更新数据库版本

**预期结果**:
- `budgets` 表不存在
- `budget_carryovers` 表不存在
- 数据库版本已更新
- 应用正常启动

**验证**:
```dart
test('应该删除传统预算数据表', () async {
  await migrationService.migrate();

  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table'"
  );

  final tableNames = tables.map((t) => t['name']).toList();

  expect(tableNames.contains('budgets'), isFalse);
  expect(tableNames.contains('budget_carryovers'), isFalse);
  expect(tableNames.contains('budget_vaults'), isTrue);
});
```

#### 场景：删除传统预算模型

**前置条件**:
- 代码已备份

**操作步骤**:
1. 删除 `app/lib/models/budget.dart`
2. 删除相关的枚举和类型定义
3. 运行 `flutter analyze`

**预期结果**:
- `budget.dart` 文件不存在
- 编译无错误
- 所有引用已清理

**验证**:
```bash
# 验证文件不存在
test ! -f app/lib/models/budget.dart

# 验证无编译错误
flutter analyze

# 验证无残留引用
! grep -r "import.*models/budget.dart" app/lib/
```

#### 场景：删除传统预算 Provider

**前置条件**:
- 模型已删除

**操作步骤**:
1. 删除 `app/lib/providers/budget_provider.dart`
2. 从 Provider 注册中移除
3. 运行 `flutter analyze`

**预期结果**:
- `budget_provider.dart` 文件不存在
- Provider 注册已更新
- 编译无错误

**验证**:
```bash
# 验证文件不存在
test ! -f app/lib/providers/budget_provider.dart

# 验证无残留引用
! grep -r "budgetProvider" app/lib/
```

---

## 修改需求

### 需求：首页预算显示

首页必须只显示小金库摘要，移除传统预算相关的显示。

**需求ID**: RBS-002
**优先级**: P0（必须）

#### 场景：首页只显示小金库摘要

**前置条件**:
- 传统预算代码已删除
- 用户有小金库数据

**操作步骤**:
1. 用户打开应用首页

**预期结果**:
- 显示"小金库总览"卡片
- 显示总分配金额
- 显示已使用金额
- 显示可用金额
- 不显示传统预算相关内容

**验证**:
```dart
test('首页应该只显示小金库摘要', () async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  expect(find.text('小金库总览'), findsOneWidget);
  expect(find.text('预算管理'), findsNothing);
  expect(find.text('传统预算'), findsNothing);
});
```

---

### 需求：导航菜单

导航菜单必须移除"预算管理"入口，只保留"小金库"入口。

**需求ID**: RBS-003
**优先级**: P0（必须）

#### 场景：导航菜单只显示小金库

**前置条件**:
- UI代码已更新

**操作步骤**:
1. 用户打开导航菜单

**预期结果**:
- 显示"小金库"菜单项
- 不显示"预算管理"菜单项
- 点击"小金库"跳转到小金库页面

**验证**:
```dart
test('导航菜单应该只显示小金库', () async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();

  expect(find.text('小金库'), findsOneWidget);
  expect(find.text('预算管理'), findsNothing);

  await tester.tap(find.text('小金库'));
  await tester.pumpAndSettle();

  expect(find.byType(VaultOverviewPage), findsOneWidget);
});
```

---

### 需求：语音助手命令

语音助手必须移除传统预算相关的命令，只保留小金库相关的命令。

**需求ID**: RBS-004
**优先级**: P1（重要）

#### 场景：语音助手不响应传统预算命令

**前置条件**:
- 语音助手代码已更新

**操作步骤**:
1. 用户说"查看预算"
2. 系统识别意图

**预期结果**:
- 系统理解为"查看小金库"
- 显示小金库列表
- 不显示传统预算相关内容

**验证**:
```dart
test('语音助手应该将预算命令映射到小金库', () async {
  final intent = await voiceService.recognizeIntent('查看预算');

  expect(intent.type, IntentType.viewVaults);
  expect(intent.type, isNot(IntentType.viewBudgets));
});
```

---

## 新增需求

### 需求：小金库系统完整性

系统必须确保小金库系统的所有功能完整可用，不受传统预算删除的影响。

**需求ID**: RBS-005
**优先级**: P0（必须）

#### 场景：小金库创建功能正常

**前置条件**:
- 传统预算代码已删除

**操作步骤**:
1. 用户进入小金库页面
2. 点击"创建小金库"
3. 填写小金库信息
4. 保存

**预期结果**:
- 小金库创建成功
- 数据保存到 `budget_vaults` 表
- 列表中显示新创建的小金库

**验证**:
```dart
test('小金库创建功能应该正常', () async {
  final vault = BudgetVault(
    id: 'test-1',
    name: '餐饮小金库',
    targetAmount: 1000,
    vaultType: VaultType.flexible,
    ledgerId: 'ledger-1',
    // ...
  );

  await repository.create(vault);
  final saved = await repository.getById('test-1');

  expect(saved, isNotNull);
  expect(saved!.name, '餐饮小金库');
});
```

#### 场景：收入分配功能正常

**前置条件**:
- 用户有小金库
- 用户记录了收入

**操作步骤**:
1. 系统提示"有新收入待分配"
2. 用户点击"分配收入"
3. 为小金库分配金额
4. 确认分配

**预期结果**:
- 分配成功
- 小金库的 `allocatedAmount` 增加
- 分配记录被保存

**验证**:
```dart
test('收入分配功能应该正常', () async {
  await service.allocateIncome('income-1', {
    'vault-1': 500.0,
  });

  final vault = await repository.getById('vault-1');
  expect(vault!.allocatedAmount, 500);
});
```

---

## 交叉引用

### 相关规范

- 无（这是独立的删除操作）

### 依赖的功能

- 小金库系统（BudgetVault）必须保持完整

### 被依赖的功能

- 无（删除操作不影响其他功能）

---

## 验收标准

### 功能完整性

- [ ] 所有传统预算相关的代码已删除
- [ ] 所有传统预算相关的数据表已删除
- [ ] 小金库系统功能完整可用

### 代码质量

- [ ] 编译无错误无警告
- [ ] 无残留的 Budget 引用
- [ ] 无残留的 budgetProvider 引用
- [ ] 代码整洁，无未使用的导入

### 用户体验

- [ ] 首页只显示小金库摘要
- [ ] 导航菜单只显示小金库入口
- [ ] 所有功能正常使用
- [ ] 无功能缺失

### 测试覆盖

- [ ] 所有小金库功能测试通过
- [ ] 集成测试通过
- [ ] 无回归问题

---

**规范版本**: v1.0
**最后更新**: 2026-01-25
**状态**: 草稿
