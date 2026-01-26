# 统一预算系统规范

## 规范信息

- **规范ID**: unified-budget-system
- **变更ID**: refactor-budget-architecture
- **版本**: v1.0
- **状态**: 草稿
- **创建日期**: 2026-01-25

---

## 新增需求

### 需求：统一预算模型

系统必须提供统一的预算模型，支持传统预算和零基预算两种模式。

**需求ID**: UBS-001
**优先级**: P0（必须）

#### 场景：创建传统预算

**前置条件**:
- 用户已登录
- 用户有至少一个账本

**操作步骤**:
1. 用户进入预算中心
2. 选择"传统预算"模式
3. 点击"创建预算"
4. 填写预算信息：
   - 预算名称：必填
   - 预算金额：必填，> 0
   - 预算周期：必选（日/周/月/年）
   - 关联分类：可选
   - 图标和颜色：可选
5. 点击"保存"

**预期结果**:
- 预算创建成功
- 预算出现在预算列表中
- 预算状态为"健康"（未使用）
- 数据库中插入一条记录，mode='traditional'

**验证**:
```dart
test('应该能创建传统预算', () async {
  final budget = UnifiedBudget(
    id: 'test-1',
    name: '餐饮预算',
    amount: 1000,
    period: BudgetPeriod.monthly,
    mode: BudgetMode.traditional,
    categoryId: 'food',
    ledgerId: 'ledger-1',
    // ...
  );

  await repository.create(budget);
  final saved = await repository.getById('test-1');

  expect(saved, isNotNull);
  expect(saved!.mode, BudgetMode.traditional);
  expect(saved.targetAmount, 1000);
});
```

#### 场景：创建零基预算（小金库）

**前置条件**:
- 用户已登录
- 用户有至少一个账本
- 用户选择了零基预算模式

**操作步骤**:
1. 用户进入预算中心
2. 选择"零基预算"模式
3. 点击"创建小金库"
4. 选择小金库类型：固定支出/弹性支出/储蓄目标/债务还款
5. 填写小金库信息：
   - 名称：必填
   - 目标金额：必填，> 0
   - 分配方式：固定金额/按百分比/分配剩余/补齐目标
   - 关联分类：可选（可多选）
   - 图标和颜色：可选
6. 点击"保存"

**预期结果**:
- 小金库创建成功
- 小金库出现在对应类型的列表中
- 初始分配金额为0
- 数据库中插入一条记录，mode='zeroBased'

**验证**:
```dart
test('应该能创建零基预算小金库', () async {
  final budget = UnifiedBudget(
    id: 'test-2',
    name: '餐饮小金库',
    targetAmount: 1000,
    mode: BudgetMode.zeroBased,
    vaultType: VaultType.flexible,
    allocationType: AllocationType.percentage,
    targetPercentage: 0.3,
    categoryIds: ['food', 'food_delivery'],
    ledgerId: 'ledger-1',
    // ...
  );

  await repository.create(budget);
  final saved = await repository.getById('test-2');

  expect(saved, isNotNull);
  expect(saved!.mode, BudgetMode.zeroBased);
  expect(saved.vaultType, VaultType.flexible);
  expect(saved.allocatedAmount, 0);
});
```

---

### 需求：预算模式切换

用户必须能在传统预算和零基预算两种模式之间切换。

**需求ID**: UBS-002
**优先级**: P0（必须）

#### 场景：首次选择预算模式

**前置条件**:
- 用户首次使用预算功能
- 没有任何预算数据

**操作步骤**:
1. 用户首次进入预算中心
2. 系统显示预算模式选择向导
3. 向导展示两种模式的对比说明
4. 用户选择一种模式
5. 点击"开始使用"

**预期结果**:
- 用户选择被保存
- 预算中心显示对应模式的界面
- 后续进入预算中心直接显示选择的模式

**验证**:
```dart
test('首次使用应显示模式选择向导', () async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('budget_mode');

  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('预算中心'));
  await tester.pumpAndSettle();

  expect(find.byType(BudgetModeWizardPage), findsOneWidget);
});
```

#### 场景：切换预算模式

**前置条件**:
- 用户已选择预算模式
- 可能有现有预算数据

**操作步骤**:
1. 用户进入预算中心
2. 点击模式切换按钮
3. 系统显示切换确认对话框
4. 如果有现有数据，提示数据迁移影响
5. 用户确认切换
6. 系统切换模式

**预期结果**:
- 模式切换成功
- 界面更新为新模式
- 现有数据保持不变（仅显示方式改变）

**验证**:
```dart
test('应该能切换预算模式', () async {
  await tester.tap(find.byIcon(Icons.swap_horiz));
  await tester.pumpAndSettle();

  expect(find.text('切换预算模式'), findsOneWidget);

  await tester.tap(find.text('确认'));
  await tester.pumpAndSettle();

  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('budget_mode'), 'zeroBased');
});
```

---

### 需求：预算计算和统计

系统必须正确计算预算的使用情况、剩余金额和状态。

**需求ID**: UBS-003
**优先级**: P0（必须）

#### 场景：传统预算使用率计算

**前置条件**:
- 存在一个传统预算，目标金额1000元
- 本期已有支出600元

**操作步骤**:
1. 用户查看预算详情

**预期结果**:
- 显示已使用：¥600
- 显示剩余：¥400
- 显示使用率：60%
- 显示状态：健康

**验证**:
```dart
test('传统预算应正确计算使用率', () {
  final budget = UnifiedBudget(
    mode: BudgetMode.traditional,
    targetAmount: 1000,
    spentAmount: 600,
    // ...
  );

  expect(budget.remaining, 400);
  expect(budget.usageRate, 0.6);
  expect(budget.status, BudgetStatus.healthy);
});
```

#### 场景：零基预算可用金额计算

**前置条件**:
- 存在一个零基预算小金库
- 已分配金额800元
- 已花费金额500元

**操作步骤**:
1. 用户查看小金库详情

**预期结果**:
- 显示已分配：¥800
- 显示已使用：¥500
- 显示可用：¥300
- 显示使用率：62.5%

**验证**:
```dart
test('零基预算应正确计算可用金额', () {
  final budget = UnifiedBudget(
    mode: BudgetMode.zeroBased,
    targetAmount: 1000,
    allocatedAmount: 800,
    spentAmount: 500,
    // ...
  );

  expect(budget.available, 300);
  expect(budget.usageRate, 0.625);
  expect(budget.progress, 0.8);
});
```

---

### 需求：零基预算收入分配

系统必须支持将收入分配到各个小金库，支持多种分配策略。

**需求ID**: UBS-004
**优先级**: P1（重要）

#### 场景：手动分配收入

**前置条件**:
- 用户有零基预算小金库
- 用户记录了一笔收入3000元

**操作步骤**:
1. 系统提示"有新收入待分配"
2. 用户点击"分配收入"
3. 系统显示所有小金库列表
4. 用户为每个小金库输入分配金额：
   - 房租：1500元
   - 餐饮：800元
   - 储蓄：700元
5. 系统显示剩余未分配：0元
6. 用户点击"确认分配"

**预期结果**:
- 各小金库的allocatedAmount增加对应金额
- 分配记录被保存
- 收入交易关联到分配记录

**验证**:
```dart
test('应该能手动分配收入到小金库', () async {
  final allocations = {
    'vault-1': 1500.0,  // 房租
    'vault-2': 800.0,   // 餐饮
    'vault-3': 700.0,   // 储蓄
  };

  await service.allocateIncome('income-1', allocations);

  final vault1 = await repository.getById('vault-1');
  expect(vault1!.allocatedAmount, 1500);

  final vault2 = await repository.getById('vault-2');
  expect(vault2!.allocatedAmount, 800);
});
```

#### 场景：自动分配收入

**前置条件**:
- 用户有零基预算小金库，已设置分配策略：
  - 房租：固定1500元
  - 餐饮：30%
  - 储蓄：分配剩余
- 用户记录了一笔收入3000元

**操作步骤**:
1. 系统提示"有新收入待分配"
2. 用户点击"自动分配"
3. 系统根据策略计算分配方案：
   - 房租：1500元（固定）
   - 餐饮：900元（30%）
   - 储蓄：600元（剩余）
4. 系统显示分配预览
5. 用户确认

**预期结果**:
- 分配方案符合预设策略
- 所有收入被完全分配
- 各小金库金额正确更新

**验证**:
```dart
test('应该能自动分配收入', () async {
  final allocation = await service.calculateAutoAllocation(
    'ledger-1',
    3000,
  );

  expect(allocation['vault-1'], 1500);  // 固定
  expect(allocation['vault-2'], 900);   // 30%
  expect(allocation['vault-3'], 600);   // 剩余
});
```

---

### 需求：预算提醒和通知

系统必须在预算即将超支或已超支时提醒用户。

**需求ID**: UBS-005
**优先级**: P1（重要）

#### 场景：预算即将超支提醒

**前置条件**:
- 存在一个预算，目标金额1000元
- 当前已使用900元（90%）

**操作步骤**:
1. 用户记录一笔新支出50元
2. 系统检测到使用率将达到95%

**预期结果**:
- 系统显示提醒："餐饮预算即将用完，已使用95%"
- 用户可以选择继续或取消
- 如果继续，支出正常记录

**验证**:
```dart
test('预算使用率超过90%应提醒', () async {
  final budget = UnifiedBudget(
    name: '餐饮',
    targetAmount: 1000,
    spentAmount: 900,
    // ...
  );

  final shouldAlert = service.shouldAlertBeforeSpending(
    budget,
    50,
  );

  expect(shouldAlert, isTrue);
});
```

#### 场景：预算超支提醒

**前置条件**:
- 存在一个预算，目标金额1000元
- 当前已使用1000元

**操作步骤**:
1. 用户记录一笔新支出100元
2. 系统检测到将超支

**预期结果**:
- 系统显示警告："餐饮预算已超支100元"
- 用户可以选择继续或取消
- 如果继续，支出正常记录，预算状态变为"超支"

**验证**:
```dart
test('预算超支应显示警告', () {
  final budget = UnifiedBudget(
    targetAmount: 1000,
    spentAmount: 1100,
    // ...
  );

  expect(budget.status, BudgetStatus.overSpent);
  expect(budget.overspentAmount, 100);
});
```

---

### 需求：预算数据迁移

系统必须能将现有的预算数据迁移到新的统一模型。

**需求ID**: UBS-006
**优先级**: P0（必须）

#### 场景：从旧版本升级

**前置条件**:
- 用户从旧版本升级到新版本
- 数据库中有旧的budgets和budget_vaults表

**操作步骤**:
1. 应用启动
2. 检测到数据库版本需要升级
3. 执行迁移脚本
4. 迁移完成

**预期结果**:
- 所有旧预算数据迁移到unified_budgets表
- 传统预算的mode='traditional'
- 零基预算的mode='zeroBased'
- 旧表重命名为_backup后缀
- 数据完整性验证通过

**验证**:
```dart
test('应该能迁移旧预算数据', () async {
  // 准备旧数据
  await db.insert('budgets', {
    'id': 'old-1',
    'name': '餐饮预算',
    'amount': 1000,
    // ...
  });

  // 执行迁移
  await migrationService.migrate();

  // 验证新数据
  final migrated = await db.query(
    'unified_budgets',
    where: 'id = ?',
    whereArgs: ['old-1'],
  );

  expect(migrated.length, 1);
  expect(migrated[0]['mode'], 'traditional');
});
```

---

## 修改需求

### 需求：首页预算摘要显示

首页必须根据用户选择的预算模式显示不同的预算摘要指标。

**需求ID**: UBS-007
**优先级**: P1（重要）

#### 场景：传统预算模式的首页显示

**前置条件**:
- 用户选择了传统预算模式
- 有多个分类预算

**操作步骤**:
1. 用户打开应用首页

**预期结果**:
- 显示"本月预算"卡片
- 显示总预算金额
- 显示已使用金额和百分比
- 显示剩余金额
- 显示超支预算数量（如果有）

#### 场景：零基预算模式的首页显示

**前置条件**:
- 用户选择了零基预算模式
- 有多个小金库

**操作步骤**:
1. 用户打开应用首页

**预期结果**:
- 显示"小金库总览"卡片
- 显示总分配金额
- 显示已使用金额和百分比
- 显示可用金额
- 显示待分配收入（如果有）

---

## 移除需求

### 需求：独立的预算和小金库入口

移除独立的"预算管理"和"小金库"入口，统一为"预算中心"。

**需求ID**: UBS-008
**优先级**: P0（必须）

**影响范围**:
- 首页导航
- 设置页面
- 语音助手命令

**迁移方案**:
- 将"预算管理"和"小金库"入口合并为"预算中心"
- 在预算中心内通过模式切换访问不同功能
- 更新所有相关的导航和链接

---

## 交叉引用

### 相关规范

- 无（这是新的核心规范）

### 依赖的功能

- 交易记录系统（用于关联支出）
- 账本系统（预算属于账本）
- 分类系统（预算关联分类）

### 被依赖的功能

- 报表系统（使用预算数据生成报表）
- 语音助手（语音查询和操作预算）
- 家庭账本（家庭成员共享预算）

---

## 验收标准

### 功能完整性

- [ ] 所有新增需求的场景都能正常工作
- [ ] 所有修改需求的场景都已更新
- [ ] 所有移除需求的功能已清理

### 数据完整性

- [ ] 数据迁移成功率100%
- [ ] 迁移后数据验证通过
- [ ] 支持回滚到旧版本

### 性能要求

- [ ] 预算列表加载时间 < 500ms
- [ ] 预算计算响应时间 < 100ms
- [ ] 数据库查询优化，使用索引

### 用户体验

- [ ] 界面清晰易懂
- [ ] 操作流程顺畅
- [ ] 错误提示友好
- [ ] 帮助文档完善

### 测试覆盖

- [ ] 单元测试覆盖率 > 80%
- [ ] 集成测试覆盖核心流程
- [ ] UI测试覆盖主要页面

---

**规范版本**: v1.0
**最后更新**: 2026-01-25
**状态**: 草稿
