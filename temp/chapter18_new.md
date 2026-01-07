## 18. 测试策略

本章节定义2.0版本的全面测试策略，确保产品质量和用户体验。

### 18.0 设计原则与测试目标

#### 18.0.1 测试设计原则

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          测试设计原则                                        │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │  质量优先   │    │  自动化驱动  │    │  快速反馈   │    │  持续改进   │ │
│  │  Quality    │    │  Automation │    │    Fast     │    │  Continuous │ │
│  │   First     │    │   Driven    │    │  Feedback   │    │ Improvement │ │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘ │
│       ↓                  ↓                  ↓                  ↓          │
│   功能正确性优先     测试代码即文档       CI/CD快速验证      测试覆盖率持续   │
│   用户体验保障       减少手工测试         本地验证秒级        追踪和提升       │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 18.0.2 2.0版本测试重点

| 测试重点 | 描述 | 优先级 |
|----------|------|--------|
| **钱龄计算** | FIFO算法正确性、边界条件、性能 | P0 |
| **零基预算** | 分配逻辑、结转规则、预警触发 | P0 |
| **小金库系统** | 余额计算、分配验证、展示正确 | P0 |
| **AI语音识别** | 识别准确率、多交易解析、错误恢复 | P1 |
| **数据联动** | 下钻导航、状态同步、刷新机制 | P1 |
| **离线同步** | 冲突解决、队列处理、断点续传 | P1 |
| **国际化** | 多语言显示、货币格式、日期格式 | P2 |

### 18.1 测试金字塔

```
┌───────────────────────────────────────────────────────────────────────────┐
│                            测试金字塔                                       │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│                              ┌───────┐                                    │
│                              │ E2E   │  5%   端到端测试                    │
│                             ─┴───────┴─      (关键用户旅程)                │
│                           ┌─────────────┐                                 │
│                           │  集成测试    │  15%  (API/数据库/服务集成)      │
│                          ─┴─────────────┴─                                │
│                        ┌───────────────────┐                              │
│                        │    Widget测试     │  25%  (UI组件/页面交互)        │
│                       ─┴───────────────────┴─                             │
│                     ┌───────────────────────────┐                         │
│                     │        单元测试            │  55%  (业务逻辑/模型)     │
│                    ─┴───────────────────────────┴─                        │
│                                                                           │
│  执行频率:   每次提交    ───────────────────────────────────────>   每日    │
│  执行速度:   毫秒级      ───────────────────────────────────────>   分钟级  │
│  维护成本:   低          ───────────────────────────────────────>   高      │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

### 18.2 单元测试策略

#### 18.2.1 覆盖率要求

```dart
/// 单元测试覆盖要求
class UnitTestCoverage {
  /// 核心业务逻辑 - 最高优先级
  static const coreLogicCoverage = {
    'MoneyAgeCalculator': 95,      // 钱龄计算 ≥95%
    'BudgetAllocationService': 95, // 预算分配 ≥95%
    'VaultBalanceService': 90,     // 小金库余额 ≥90%
    'TransactionMatcher': 90,      // 交易匹配 ≥90%
    'DataSyncService': 85,         // 数据同步 ≥85%
    'ConflictResolver': 90,        // 冲突解决 ≥90%
  };

  /// 数据模型 - 高覆盖要求
  static const modelCoverage = {
    'Transaction': 90,
    'Budget': 90,
    'BudgetVault': 90,
    'MoneyAge': 90,
    'SyncQueue': 85,
  };

  /// AI服务 - 中高覆盖
  static const aiServiceCoverage = {
    'QwenService': 80,
    'VoiceRecognitionParser': 85,
    'TransactionExtractor': 85,
  };

  /// 工具类 - 中等覆盖要求
  static const utilsCoverage = {
    'DateUtils': 80,
    'CurrencyUtils': 80,
    'ValidationUtils': 85,
    'LocalizationService': 75,
  };
}
```

#### 18.2.2 钱龄计算单元测试

```dart
/// 钱龄计算单元测试
@Tags(['unit', 'money-age', 'core'])
void main() {
  group('MoneyAgeCalculator', () {
    late MoneyAgeCalculator calculator;
    late MockTransactionRepository mockRepo;

    setUp(() {
      mockRepo = MockTransactionRepository();
      calculator = MoneyAgeCalculator(repository: mockRepo);
    });

    group('基础场景', () {
      test('空交易列表应返回零钱龄', () {
        when(mockRepo.getTransactions(any)).thenReturn([]);

        final result = calculator.calculate(DateTime.now());

        expect(result.days, equals(0));
        expect(result.level, equals(MoneyAgeLevel.danger));
      });

      test('只有收入无支出应返回最大钱龄', () {
        final income = Transaction(
          type: TransactionType.income,
          amount: 10000,
          date: DateTime.now().subtract(Duration(days: 60)),
        );
        when(mockRepo.getTransactions(any)).thenReturn([income]);

        final result = calculator.calculate(DateTime.now());

        expect(result.days, greaterThanOrEqualTo(60));
        expect(result.level, equals(MoneyAgeLevel.excellent));
      });
    });

    group('FIFO算法验证', () {
      test('FIFO算法正确消耗收入', () {
        final incomes = [
          Transaction(type: TransactionType.income, amount: 1000,
            date: DateTime.now().subtract(Duration(days: 30))),
          Transaction(type: TransactionType.income, amount: 2000,
            date: DateTime.now().subtract(Duration(days: 15))),
        ];
        final expense = Transaction(
          type: TransactionType.expense,
          amount: 1500,
          date: DateTime.now(),
        );
        when(mockRepo.getTransactions(any)).thenReturn([...incomes, expense]);

        final result = calculator.calculate(DateTime.now());

        // 1500支出应先消耗30天前的1000，再消耗15天前的500
        // 加权平均: (1000*30 + 500*15) / 1500 = 25天
        expect(result.days, closeTo(25, 1));
      });

      test('支出大于总收入时钱龄为0', () {
        final income = Transaction(
          type: TransactionType.income,
          amount: 1000,
          date: DateTime.now().subtract(Duration(days: 30)),
        );
        final expense = Transaction(
          type: TransactionType.expense,
          amount: 2000,
          date: DateTime.now(),
        );
        when(mockRepo.getTransactions(any)).thenReturn([income, expense]);

        final result = calculator.calculate(DateTime.now());

        expect(result.days, equals(0));
        expect(result.isNegativeBalance, isTrue);
      });
    });

    group('钱龄等级判定', () {
      test('0-7天为危险等级', () {
        final result = MoneyAge(days: 5);
        expect(result.level, equals(MoneyAgeLevel.danger));
        expect(result.levelColor, equals(Colors.red));
      });

      test('8-14天为警告等级', () {
        final result = MoneyAge(days: 10);
        expect(result.level, equals(MoneyAgeLevel.warning));
      });

      test('15-29天为良好等级', () {
        final result = MoneyAge(days: 20);
        expect(result.level, equals(MoneyAgeLevel.good));
      });

      test('30天以上为优秀等级', () {
        final result = MoneyAge(days: 45);
        expect(result.level, equals(MoneyAgeLevel.excellent));
      });
    });

    group('边界条件', () {
      test('处理同一天的多笔交易', () { /* ... */ });
      test('处理跨年交易', () { /* ... */ });
      test('处理大量交易(10000+)性能', () { /* ... */ });
    });
  });
}
```

#### 18.2.3 零基预算单元测试

```dart
/// 零基预算单元测试
@Tags(['unit', 'budget', 'core'])
void main() {
  group('BudgetAllocationService', () {
    late BudgetAllocationService service;

    setUp(() {
      service = BudgetAllocationService();
    });

    group('收入分配', () {
      test('收入应完全分配到各预算类别', () {
        final income = 10000.0;
        final allocations = {
          'food': 3000.0,
          'transport': 1000.0,
          'entertainment': 500.0,
          'savings': 5500.0,
        };

        final result = service.allocate(income, allocations);

        expect(result.isValid, isTrue);
        expect(result.unallocated, equals(0));
        expect(result.totalAllocated, equals(income));
      });

      test('分配超过收入应报错', () {
        final income = 10000.0;
        final allocations = {
          'food': 6000.0,
          'transport': 5000.0,
        };

        expect(
          () => service.allocate(income, allocations),
          throwsA(isA<AllocationExceededException>()),
        );
      });

      test('部分分配应显示未分配金额', () {
        final income = 10000.0;
        final allocations = {'food': 3000.0};

        final result = service.allocate(income, allocations);

        expect(result.unallocated, equals(7000.0));
        expect(result.allocationRate, equals(0.3));
      });
    });

    group('预算结转', () {
      test('月末结余正确结转到下月', () {
        final currentBudget = Budget(
          category: 'food',
          amount: 3000,
          spent: 2500,
          month: DateTime(2024, 12),
        );

        final nextMonth = service.carryOver(currentBudget);

        expect(nextMonth.carryOverAmount, equals(500));
        expect(nextMonth.month, equals(DateTime(2025, 1)));
      });

      test('超支预算不结转负数', () {
        final overBudget = Budget(
          category: 'food',
          amount: 3000,
          spent: 3500,
          month: DateTime(2024, 12),
        );

        final nextMonth = service.carryOver(overBudget);

        expect(nextMonth.carryOverAmount, equals(0));
        expect(nextMonth.previousOverspend, equals(500));
      });
    });

    group('预算预警', () {
      test('使用率达80%触发预警', () {
        final budget = Budget(amount: 1000, spent: 800);

        expect(budget.warningLevel, equals(BudgetWarning.approaching));
        expect(budget.shouldNotify, isTrue);
      });

      test('使用率达100%触发超支警告', () {
        final budget = Budget(amount: 1000, spent: 1000);

        expect(budget.warningLevel, equals(BudgetWarning.exceeded));
      });
    });
  });
}
```

#### 18.2.4 小金库单元测试

```dart
/// 小金库单元测试
@Tags(['unit', 'vault', 'core'])
void main() {
  group('VaultService', () {
    late VaultService service;

    test('创建小金库初始余额为0', () {
      final vault = service.create(name: '旅游基金', targetAmount: 10000);

      expect(vault.balance, equals(0));
      expect(vault.progress, equals(0));
    });

    test('存入金额正确更新余额', () {
      final vault = Vault(balance: 1000);

      final updated = service.deposit(vault, 500);

      expect(updated.balance, equals(1500));
    });

    test('取出金额不能超过余额', () {
      final vault = Vault(balance: 1000);

      expect(
        () => service.withdraw(vault, 1500),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });

    test('达到目标金额标记为已完成', () {
      final vault = Vault(balance: 9500, targetAmount: 10000);

      final updated = service.deposit(vault, 500);

      expect(updated.isCompleted, isTrue);
      expect(updated.progress, equals(1.0));
    });
  });
}
```

### 18.3 Widget测试策略

#### 18.3.1 核心页面测试要求

```dart
/// Widget测试要求
class WidgetTestRequirements {
  /// 核心页面必须有Widget测试
  static const requiredPages = [
    'HomePage',              // 首页仪表盘
    'BudgetManagementPage',  // 预算管理
    'VaultManagementPage',   // 小金库管理
    'TransactionListPage',   // 交易列表
    'MoneyAgeDetailPage',    // 钱龄详情
    'StatisticsPage',        // 统计分析
    'VoiceRecognitionPage',  // 语音记账
    'QuickEntryPage',        // 快速记账
  ];

  /// 核心组件必须有Widget测试
  static const requiredWidgets = [
    'MoneyAgeCard',          // 钱龄卡片
    'MoneyAgeGauge',         // 钱龄仪表盘
    'BudgetProgressBar',     // 预算进度条
    'VaultBalanceWidget',    // 小金库余额
    'TransactionTile',       // 交易项
    'DrillDownPieChart',     // 可下钻饼图
    'DrillDownLineChart',    // 可下钻折线图
    'EnhancedBreadcrumb',    // 面包屑导航
  ];
}
```

#### 18.3.2 首页Widget测试

```dart
/// 首页Widget测试
@Tags(['widget', 'home'])
void main() {
  group('HomePage Widget Tests', () {
    testWidgets('显示钱龄卡片和正确数值', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moneyAgeProvider.overrideWith((_) =>
              MoneyAge(days: 25, level: MoneyAgeLevel.good)),
          ],
          child: MaterialApp(home: HomePage()),
        ),
      );

      expect(find.text('钱龄'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('天'), findsOneWidget);
      expect(find.byType(MoneyAgeCard), findsOneWidget);
    });

    testWidgets('显示预算概览卡片', (tester) async {
      await tester.pumpWidget(createTestApp(
        budgetOverview: BudgetOverview(
          totalBudget: 10000,
          totalSpent: 6500,
          remainingDays: 15,
        ),
      ));

      expect(find.text('本月预算'), findsOneWidget);
      expect(find.text('¥10,000'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget); // 使用率
    });

    testWidgets('显示小金库概览', (tester) async {
      await tester.pumpWidget(createTestApp(
        vaults: [
          Vault(name: '旅游基金', balance: 5000, targetAmount: 10000),
          Vault(name: '应急资金', balance: 20000, targetAmount: 20000),
        ],
      ));

      expect(find.text('小金库'), findsOneWidget);
      expect(find.text('旅游基金'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('点击钱龄卡片导航到详情页', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.tap(find.byType(MoneyAgeCard));
      await tester.pumpAndSettle();

      expect(find.byType(MoneyAgeDetailPage), findsOneWidget);
    });

    testWidgets('下拉刷新更新所有数据', (tester) async {
      final mockRefresh = MockRefreshCallback();
      await tester.pumpWidget(createTestApp(onRefresh: mockRefresh));

      await tester.fling(
        find.byType(CustomScrollView),
        Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      verify(mockRefresh.call()).called(1);
    });
  });
}
```

#### 18.3.3 数据联动Widget测试

```dart
/// 数据联动Widget测试
@Tags(['widget', 'drill-down'])
void main() {
  group('DrillDown Widget Tests', () {
    testWidgets('饼图点击触发下钻', (tester) async {
      await tester.pumpWidget(createTestApp(
        pieChartData: [
          ChartSegment(category: 'food', value: 3000, label: '餐饮'),
          ChartSegment(category: 'transport', value: 1000, label: '交通'),
        ],
      ));

      // 点击餐饮分类
      await tester.tap(find.text('餐饮'));
      await tester.pumpAndSettle();

      // 验证下钻到餐饮详情
      expect(find.text('餐饮支出详情'), findsOneWidget);
      expect(find.byType(EnhancedBreadcrumb), findsOneWidget);
    });

    testWidgets('面包屑导航正确显示层级', (tester) async {
      await tester.pumpWidget(createTestApp(
        drillDownPath: ['统计', '餐饮', '12月25日'],
      ));

      expect(find.text('统计'), findsOneWidget);
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('12月25日'), findsOneWidget);
    });

    testWidgets('点击面包屑返回上级', (tester) async {
      await tester.pumpWidget(createTestApp(
        drillDownPath: ['统计', '餐饮', '12月25日'],
      ));

      await tester.tap(find.text('餐饮'));
      await tester.pumpAndSettle();

      // 验证返回到餐饮层级
      expect(find.text('餐饮支出详情'), findsOneWidget);
    });
  });
}
```

### 18.4 集成测试策略

#### 18.4.1 关键用户旅程

```dart
/// 集成测试场景
class IntegrationTestScenarios {
  /// 关键用户旅程 - 必须覆盖
  static const criticalJourneys = [
    'new_user_onboarding',       // 新用户引导流程
    'quick_expense_entry',       // 快速记账
    'voice_expense_entry',       // 语音记账
    'multi_transaction_voice',   // 多笔交易语音记账
    'budget_creation_flow',      // 预算创建流程
    'vault_allocation_flow',     // 小金库分配流程
    'data_drill_down',           // 数据下钻
    'monthly_report_view',       // 月度报表查看
  ];

  /// 数据同步场景
  static const syncScenarios = [
    'offline_to_online_sync',    // 离线转在线同步
    'conflict_resolution',       // 冲突解决
    'partial_sync_recovery',     // 部分同步恢复
    'incremental_sync',          // 增量同步
  ];

  /// 2.0核心功能场景
  static const v2CoreScenarios = [
    'money_age_calculation',     // 钱龄计算流程
    'zero_budget_allocation',    // 零基预算分配
    'vault_management',          // 小金库管理
    'ai_voice_recognition',      // AI语音识别
    'cross_page_filter',         // 跨页面筛选
  ];
}
```

#### 18.4.2 语音记账集成测试

```dart
/// 语音记账集成测试
@Tags(['integration', 'voice', 'ai'])
void main() {
  group('语音记账集成测试', () {
    integration_test('单笔交易语音记账', () async {
      final app = await initializeTestApp();

      // 1. 打开语音记账
      await app.tap(find.byIcon(Icons.mic));
      await app.pumpAndSettle();

      // 2. 模拟语音输入
      await app.simulateVoiceInput('午餐花了35块');
      await app.pumpAndSettle();

      // 3. 验证AI解析结果
      expect(find.text('¥35.00'), findsOneWidget);
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('午餐'), findsOneWidget);

      // 4. 确认保存
      await app.tap(find.text('确认'));
      await app.pumpAndSettle();

      // 5. 验证交易已保存
      await app.tap(find.byIcon(Icons.list));
      expect(find.text('¥35.00'), findsOneWidget);
    });

    integration_test('多笔交易语音记账', () async {
      final app = await initializeTestApp();

      await app.tap(find.byIcon(Icons.mic));
      await app.simulateVoiceInput('今天早餐15块，午餐28块，晚餐花了45');
      await app.pumpAndSettle();

      // 验证解析出3笔交易
      expect(find.byType(TransactionConfirmTile), findsNWidgets(3));
      expect(find.text('¥15.00'), findsOneWidget);
      expect(find.text('¥28.00'), findsOneWidget);
      expect(find.text('¥45.00'), findsOneWidget);

      // 全部确认
      await app.tap(find.text('全部确认'));
      await app.pumpAndSettle();

      // 验证钱龄已更新
      final moneyAge = app.getMoneyAge();
      expect(moneyAge.lastUpdated, isNotNull);
    });

    integration_test('语音识别失败重试', () async {
      final app = await initializeTestApp();

      // 模拟识别失败
      await app.tap(find.byIcon(Icons.mic));
      await app.simulateVoiceError(VoiceError.networkTimeout);

      // 验证显示重试选项
      expect(find.text('识别失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      // 点击重试
      await app.tap(find.text('重试'));
      await app.simulateVoiceInput('咖啡25元');
      await app.pumpAndSettle();

      expect(find.text('¥25.00'), findsOneWidget);
    });
  });
}
```

#### 18.4.3 数据下钻集成测试

```dart
/// 数据下钻集成测试
@Tags(['integration', 'drill-down'])
integration_test('统计图表下钻流程', () async {
  final app = await initializeTestApp(withSampleData: true);

  // 1. 进入统计页
  await app.tap(find.byIcon(Icons.bar_chart));
  await app.pumpAndSettle();

  // 2. 点击饼图的"餐饮"分类
  await app.tapChartSegment('餐饮');
  await app.pumpAndSettle();

  // 3. 验证进入餐饮分类详情
  expect(find.text('餐饮支出详情'), findsOneWidget);

  // 4. 验证面包屑显示
  expect(find.byType(EnhancedBreadcrumb), findsOneWidget);
  expect(find.text('统计'), findsOneWidget);
  expect(find.text('餐饮'), findsOneWidget);

  // 5. 点击某一天
  await app.tap(find.text('12月25日'));
  await app.pumpAndSettle();

  // 6. 验证显示当天交易列表
  expect(find.byType(TransactionList), findsOneWidget);

  // 7. 验证面包屑更新
  expect(find.text('12月25日'), findsOneWidget);

  // 8. 点击面包屑返回统计页
  await app.tap(find.text('统计'));
  await app.pumpAndSettle();

  expect(find.byType(StatisticsPage), findsOneWidget);
});
```

### 18.5 API与后端测试

#### 18.5.1 API测试策略

```python
# server/tests/test_api.py

import pytest
from httpx import AsyncClient
from app.main import app

class TestTransactionAPI:
    """交易API测试"""

    @pytest.mark.asyncio
    async def test_create_transaction(self, client: AsyncClient, auth_headers):
        """创建交易"""
        response = await client.post(
            "/api/v1/transactions",
            json={
                "type": "expense",
                "amount": 88.5,
                "category_id": "food",
                "date": "2024-12-31",
                "note": "午餐"
            },
            headers=auth_headers
        )

        assert response.status_code == 201
        data = response.json()
        assert data["amount"] == 88.5
        assert data["category_id"] == "food"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_get_transactions_with_filter(self, client: AsyncClient, auth_headers):
        """带筛选条件查询交易"""
        response = await client.get(
            "/api/v1/transactions",
            params={
                "start_date": "2024-12-01",
                "end_date": "2024-12-31",
                "category": "food",
                "type": "expense"
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data

    @pytest.mark.asyncio
    async def test_batch_create_transactions(self, client: AsyncClient, auth_headers):
        """批量创建交易（语音记账场景）"""
        response = await client.post(
            "/api/v1/transactions/batch",
            json={
                "transactions": [
                    {"type": "expense", "amount": 15, "category_id": "food"},
                    {"type": "expense", "amount": 28, "category_id": "food"},
                    {"type": "expense", "amount": 45, "category_id": "food"},
                ]
            },
            headers=auth_headers
        )

        assert response.status_code == 201
        data = response.json()
        assert len(data["created"]) == 3


class TestBudgetAPI:
    """预算API测试"""

    @pytest.mark.asyncio
    async def test_create_zero_based_budget(self, client: AsyncClient, auth_headers):
        """创建零基预算"""
        response = await client.post(
            "/api/v1/budgets",
            json={
                "month": "2025-01",
                "total_income": 15000,
                "allocations": [
                    {"category_id": "food", "amount": 3000},
                    {"category_id": "transport", "amount": 1000},
                    {"category_id": "savings", "amount": 5000},
                ]
            },
            headers=auth_headers
        )

        assert response.status_code == 201
        data = response.json()
        assert data["total_allocated"] == 9000
        assert data["unallocated"] == 6000

    @pytest.mark.asyncio
    async def test_budget_carryover(self, client: AsyncClient, auth_headers):
        """预算结转测试"""
        response = await client.post(
            "/api/v1/budgets/carryover",
            json={"from_month": "2024-12", "to_month": "2025-01"},
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert "carryover_amounts" in data


class TestSyncAPI:
    """数据同步API测试"""

    @pytest.mark.asyncio
    async def test_incremental_sync(self, client: AsyncClient, auth_headers):
        """增量同步测试"""
        response = await client.post(
            "/api/v1/sync/pull",
            json={
                "last_sync_time": "2024-12-30T00:00:00Z",
                "device_id": "test-device-001"
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert "changes" in data
        assert "server_time" in data

    @pytest.mark.asyncio
    async def test_conflict_resolution(self, client: AsyncClient, auth_headers):
        """冲突解决测试"""
        response = await client.post(
            "/api/v1/sync/push",
            json={
                "changes": [
                    {
                        "id": "tx-001",
                        "type": "update",
                        "data": {"amount": 100},
                        "client_version": 2,
                        "server_version": 1  # 模拟冲突
                    }
                ]
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert "conflicts" in data
```

#### 18.5.2 数据库测试

```python
# server/tests/test_db.py

import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import Transaction, Budget, Vault

class TestTransactionRepository:
    """交易仓库测试"""

    @pytest.mark.asyncio
    async def test_calculate_money_age(self, session: AsyncSession, user_id: str):
        """钱龄计算数据库查询测试"""
        # 插入测试数据
        await self._insert_test_transactions(session, user_id)

        repo = TransactionRepository(session)
        result = await repo.calculate_money_age(user_id, datetime.now())

        assert result.total_income > 0
        assert result.total_expense >= 0
        assert result.weighted_age >= 0

    @pytest.mark.asyncio
    async def test_get_category_statistics(self, session: AsyncSession, user_id: str):
        """分类统计查询测试"""
        repo = TransactionRepository(session)
        stats = await repo.get_category_statistics(
            user_id,
            start_date=date(2024, 12, 1),
            end_date=date(2024, 12, 31)
        )

        assert isinstance(stats, list)
        for item in stats:
            assert "category_id" in item
            assert "total_amount" in item
            assert "transaction_count" in item
```

### 18.6 端到端测试

#### 18.6.1 E2E测试场景

```dart
/// E2E测试场景定义
class E2ETestScenarios {
  /// 完整用户流程
  static const fullUserFlows = [
    E2EFlow(
      name: '月度财务管理完整流程',
      steps: [
        '登录应用',
        '查看本月概览（钱龄、预算、小金库）',
        '记录收入（工资）',
        '创建零基预算分配收入',
        '分配资金到各小金库',
        '记录多笔日常支出',
        '查看钱龄变化趋势',
        '检查预算执行情况',
        '查看统计图表并下钻',
        '生成月度财务报告',
      ],
      expectedDuration: Duration(minutes: 20),
    ),
    E2EFlow(
      name: '语音记账完整流程',
      steps: [
        '打开语音记账',
        '语音输入多笔交易',
        '确认AI识别结果',
        '修改错误识别的项目',
        '保存所有交易',
        '验证首页数据更新',
      ],
      expectedDuration: Duration(minutes: 5),
    ),
  ];
}
```

#### 18.6.2 月度财务管理E2E测试

```dart
/// 月度财务管理E2E测试
@Tags(['e2e', 'slow'])
e2e_test('月度财务管理完整流程', () async {
  final driver = await FlutterDriver.connect();

  try {
    // 1. 登录
    await driver.tap(find.byValueKey('login_button'));
    await driver.waitFor(find.byType('HomePage'));

    // 2. 验证首页显示钱龄
    await driver.waitFor(find.text('钱龄'));

    // 3. 记录收入
    await driver.tap(find.byValueKey('add_transaction'));
    await driver.tap(find.text('收入'));
    await driver.enterText(find.byType('AmountInput'), '15000');
    await driver.tap(find.text('工资'));
    await driver.tap(find.text('保存'));

    // 4. 创建零基预算
    await driver.tap(find.byValueKey('budget_tab'));
    await driver.tap(find.text('创建本月预算'));
    await driver.enterText(find.byValueKey('budget_food'), '3000');
    await driver.enterText(find.byValueKey('budget_transport'), '1000');
    await driver.enterText(find.byValueKey('budget_entertainment'), '500');
    await driver.tap(find.text('确认'));

    // 5. 分配到小金库
    await driver.tap(find.byValueKey('vault_tab'));
    await driver.tap(find.text('分配资金'));
    await driver.enterText(find.byValueKey('vault_travel'), '2000');
    await driver.enterText(find.byValueKey('vault_emergency'), '3000');
    await driver.tap(find.text('确认分配'));

    // 6. 验证钱龄更新
    await driver.tap(find.byValueKey('home_tab'));
    final moneyAgeText = await driver.getText(find.byValueKey('money_age_days'));
    expect(int.parse(moneyAgeText), greaterThan(0));

    // 7. 记录支出
    await driver.tap(find.byValueKey('add_transaction'));
    await driver.enterText(find.byType('AmountInput'), '88.5');
    await driver.tap(find.text('餐饮'));
    await driver.tap(find.text('保存'));

    // 8. 查看统计并下钻
    await driver.tap(find.byValueKey('stats_tab'));
    await driver.waitFor(find.byType('PieChart'));
    await driver.tap(find.text('餐饮'));
    await driver.waitFor(find.text('餐饮支出详情'));

    // 9. 生成报告
    await driver.tap(find.byValueKey('reports'));
    await driver.tap(find.text('生成月度报表'));
    await driver.waitFor(find.text('报表已生成'));

  } finally {
    await driver.close();
  }
});
```

### 18.7 性能测试

#### 18.7.1 性能基准

```dart
/// 性能测试基准
class PerformanceBenchmarks {
  /// 页面加载时间基准 (毫秒)
  static const pageLoadTimes = {
    'HomePage': 500,
    'TransactionListPage': 800,
    'StatisticsPage': 1000,
    'MoneyAgeDetailPage': 600,
    'BudgetManagementPage': 700,
    'VaultManagementPage': 600,
  };

  /// 操作响应时间基准 (毫秒)
  static const operationTimes = {
    'save_transaction': 200,
    'calculate_money_age': 100,
    'generate_chart': 500,
    'voice_recognition': 2000,
    'sync_data': 3000,
    'export_report': 5000,
  };

  /// 内存使用基准 (MB)
  static const memoryLimits = {
    'idle': 150,
    'active': 250,
    'peak': 400,
    'after_gc': 180,
  };

  /// 帧率基准
  static const frameRateLimits = {
    'scroll_list': 55,      // 列表滚动 ≥55fps
    'chart_animation': 50,  // 图表动画 ≥50fps
    'page_transition': 55,  // 页面切换 ≥55fps
  };
}
```

#### 18.7.2 性能测试用例

```dart
/// 性能测试
@Tags(['performance'])
void main() {
  group('页面加载性能', () {
    test('首页加载时间 < 500ms', () async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(HomePage());
      await tester.pumpAndSettle();

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds,
        lessThan(PerformanceBenchmarks.pageLoadTimes['HomePage']!));
    });

    test('统计页图表渲染 < 1000ms', () async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(StatisticsPage(data: largeDataSet));
      await tester.pumpAndSettle();

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('核心算法性能', () {
    test('钱龄计算 < 100ms (1000条交易)', () async {
      final transactions = generateTransactions(1000);
      final calculator = MoneyAgeCalculator();

      final stopwatch = Stopwatch()..start();
      calculator.calculate(transactions, DateTime.now());
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('钱龄计算 < 500ms (10000条交易)', () async {
      final transactions = generateTransactions(10000);
      final calculator = MoneyAgeCalculator();

      final stopwatch = Stopwatch()..start();
      calculator.calculate(transactions, DateTime.now());
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('UI流畅度', () {
    test('交易列表滚动帧率 >= 55fps', () async {
      await tester.pumpWidget(TransactionListPage(
        transactions: generateTransactions(500),
      ));

      final timeline = await tester.traceAction(() async {
        await tester.fling(
          find.byType(ListView),
          Offset(0, -500),
          1000,
        );
        await tester.pumpAndSettle();
      });

      final summary = TimelineSummary.summarize(timeline);
      expect(summary.averageFrameBuildTimeMillis, lessThan(18)); // ~55fps
    });

    test('饼图动画帧率 >= 50fps', () async {
      await tester.pumpWidget(DrillDownPieChart(data: testData));

      final timeline = await tester.traceAction(() async {
        await tester.tap(find.byType(DrillDownPieChart));
        await tester.pumpAndSettle();
      });

      final summary = TimelineSummary.summarize(timeline);
      expect(summary.averageFrameBuildTimeMillis, lessThan(20)); // ~50fps
    });
  });

  group('内存使用', () {
    test('空闲状态内存 < 150MB', () async {
      await tester.pumpWidget(HomePage());
      await tester.pumpAndSettle();

      // 等待稳定
      await Future.delayed(Duration(seconds: 2));

      final memoryUsage = await getMemoryUsage();
      expect(memoryUsage, lessThan(150 * 1024 * 1024));
    });
  });
}
```

### 18.8 AI功能测试

#### 18.8.1 语音识别测试

```dart
/// AI语音识别测试
@Tags(['ai', 'voice'])
void main() {
  group('VoiceRecognitionParser', () {
    late VoiceRecognitionParser parser;

    setUp(() {
      parser = VoiceRecognitionParser();
    });

    group('单笔交易解析', () {
      test('解析简单支出', () {
        final result = parser.parse('午餐花了35块');

        expect(result.transactions.length, equals(1));
        expect(result.transactions[0].amount, equals(35));
        expect(result.transactions[0].type, equals(TransactionType.expense));
        expect(result.transactions[0].category, equals('food'));
      });

      test('解析带小数金额', () {
        final result = parser.parse('打车花了28.5元');

        expect(result.transactions[0].amount, equals(28.5));
        expect(result.transactions[0].category, equals('transport'));
      });

      test('解析收入', () {
        final result = parser.parse('收到工资15000');

        expect(result.transactions[0].type, equals(TransactionType.income));
        expect(result.transactions[0].amount, equals(15000));
        expect(result.transactions[0].category, equals('salary'));
      });
    });

    group('多笔交易解析', () {
      test('解析逗号分隔的多笔交易', () {
        final result = parser.parse('早餐15块，午餐28块，晚餐45块');

        expect(result.transactions.length, equals(3));
        expect(result.transactions[0].amount, equals(15));
        expect(result.transactions[1].amount, equals(28));
        expect(result.transactions[2].amount, equals(45));
      });

      test('解析混合类型交易', () {
        final result = parser.parse('收到红包200，买了杯咖啡25');

        expect(result.transactions.length, equals(2));
        expect(result.transactions[0].type, equals(TransactionType.income));
        expect(result.transactions[1].type, equals(TransactionType.expense));
      });
    });

    group('边界情况', () {
      test('无法解析时返回空列表', () {
        final result = parser.parse('今天天气真好');

        expect(result.transactions, isEmpty);
        expect(result.confidence, lessThan(0.5));
      });

      test('处理模糊金额', () {
        final result = parser.parse('买东西花了几十块');

        expect(result.needsConfirmation, isTrue);
        expect(result.suggestedAmount, isNull);
      });
    });
  });
}
```

#### 18.8.2 AI服务Mock测试

```dart
/// AI服务Mock测试
@Tags(['ai', 'mock'])
void main() {
  group('QwenService', () {
    late QwenService service;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      service = QwenService(httpClient: mockClient);
    });

    test('正常响应解析', () async {
      when(mockClient.post(any, any)).thenAnswer((_) async => Response(
        statusCode: 200,
        body: jsonEncode({
          'output': {
            'text': '{"transactions":[{"amount":35,"category":"food"}]}'
          }
        }),
      ));

      final result = await service.parseVoiceInput('午餐35元');

      expect(result.isSuccess, isTrue);
      expect(result.transactions.length, equals(1));
    });

    test('网络超时重试', () async {
      var callCount = 0;
      when(mockClient.post(any, any)).thenAnswer((_) async {
        callCount++;
        if (callCount < 3) {
          throw TimeoutException('Connection timeout');
        }
        return Response(statusCode: 200, body: '{"output":{"text":"{}"}}');
      });

      final result = await service.parseVoiceInput('测试');

      expect(callCount, equals(3));
      expect(result.isSuccess, isTrue);
    });

    test('API限流处理', () async {
      when(mockClient.post(any, any)).thenAnswer((_) async => Response(
        statusCode: 429,
        body: '{"error":"rate_limited"}',
      ));

      final result = await service.parseVoiceInput('测试');

      expect(result.isSuccess, isFalse);
      expect(result.error, equals(AIError.rateLimited));
    });
  });
}
```

### 18.9 安全测试

#### 18.9.1 安全测试策略

```dart
/// 安全测试要求
class SecurityTestRequirements {
  /// 必须覆盖的安全测试场景
  static const requiredTests = [
    'sql_injection_prevention',
    'xss_prevention',
    'authentication_bypass',
    'authorization_check',
    'sensitive_data_encryption',
    'token_expiration',
    'rate_limiting',
  ];
}
```

#### 18.9.2 安全测试用例

```python
# server/tests/test_security.py

import pytest

class TestSecurityVulnerabilities:
    """安全漏洞测试"""

    @pytest.mark.asyncio
    async def test_sql_injection_prevention(self, client, auth_headers):
        """SQL注入防护测试"""
        malicious_inputs = [
            "'; DROP TABLE transactions; --",
            "1 OR 1=1",
            "1; SELECT * FROM users",
        ]

        for payload in malicious_inputs:
            response = await client.get(
                f"/api/v1/transactions?category={payload}",
                headers=auth_headers
            )
            # 应该返回空结果或错误，而不是执行注入
            assert response.status_code in [200, 400]
            assert "error" not in response.text.lower() or "invalid" in response.text.lower()

    @pytest.mark.asyncio
    async def test_xss_prevention(self, client, auth_headers):
        """XSS防护测试"""
        xss_payloads = [
            "<script>alert('xss')</script>",
            "javascript:alert(1)",
            "<img src=x onerror=alert(1)>",
        ]

        for payload in xss_payloads:
            response = await client.post(
                "/api/v1/transactions",
                json={"note": payload, "amount": 100, "category_id": "food"},
                headers=auth_headers
            )
            data = response.json()
            # 验证输出被转义
            assert "<script>" not in str(data)
            assert "javascript:" not in str(data)

    @pytest.mark.asyncio
    async def test_authentication_required(self, client):
        """认证要求测试"""
        protected_endpoints = [
            "/api/v1/transactions",
            "/api/v1/budgets",
            "/api/v1/sync/pull",
            "/api/v1/user/profile",
        ]

        for endpoint in protected_endpoints:
            response = await client.get(endpoint)
            assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_authorization_isolation(self, client, user1_headers, user2_headers):
        """用户数据隔离测试"""
        # 用户1创建交易
        response = await client.post(
            "/api/v1/transactions",
            json={"amount": 100, "category_id": "food"},
            headers=user1_headers
        )
        tx_id = response.json()["id"]

        # 用户2尝试访问用户1的交易
        response = await client.get(
            f"/api/v1/transactions/{tx_id}",
            headers=user2_headers
        )
        assert response.status_code == 404  # 应该看不到

    @pytest.mark.asyncio
    async def test_rate_limiting(self, client, auth_headers):
        """速率限制测试"""
        # 快速发送大量请求
        responses = []
        for _ in range(100):
            response = await client.get(
                "/api/v1/transactions",
                headers=auth_headers
            )
            responses.append(response.status_code)

        # 应该有一些请求被限流
        assert 429 in responses
```

### 18.10 测试自动化与CI/CD

#### 18.10.1 CI/CD流水线配置

```yaml
# .github/workflows/test.yml
name: Test Pipeline

on:
  push:
    branches: [master, develop]
  pull_request:
    branches: [master]

env:
  FLUTTER_VERSION: '3.24.0'

jobs:
  # 单元测试
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Install dependencies
        run: cd app && flutter pub get

      - name: Run unit tests
        run: cd app && flutter test --coverage --tags=unit

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: app/coverage/lcov.info

  # Widget测试
  widget-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - run: cd app && flutter pub get
      - run: cd app && flutter test --tags=widget

  # 集成测试
  integration-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Start iOS Simulator
        run: |
          xcrun simctl boot "iPhone 15 Pro"

      - name: Run integration tests
        run: cd app && flutter drive --target=test_driver/app.dart

  # 后端API测试
  api-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd server
          pip install -r requirements.txt
          pip install pytest pytest-asyncio httpx

      - name: Run API tests
        run: |
          cd server
          pytest tests/ -v --cov=app

  # 性能测试（仅主分支）
  performance-tests:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/master'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - run: cd app && flutter pub get
      - run: cd app && flutter test --tags=performance

      - name: Upload performance results
        uses: actions/upload-artifact@v4
        with:
          name: performance-results
          path: app/build/performance/

  # 安全扫描
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'HIGH,CRITICAL'
```

#### 18.10.2 本地测试脚本

```bash
#!/bin/bash
# scripts/run_tests.sh

set -e

echo "=== Running AI Bookkeeping Tests ==="

# 单元测试
echo "📋 Running unit tests..."
cd app
flutter test --tags=unit --coverage
echo "✅ Unit tests passed"

# Widget测试
echo "📋 Running widget tests..."
flutter test --tags=widget
echo "✅ Widget tests passed"

# 后端测试
echo "📋 Running API tests..."
cd ../server
pytest tests/ -v
echo "✅ API tests passed"

# 代码覆盖率检查
echo "📊 Checking coverage..."
cd ../app
lcov --summary coverage/lcov.info

echo "=== All tests passed! ==="
```

### 18.11 测试覆盖率要求

#### 18.11.1 覆盖率目标

| 模块 | 最低覆盖率 | 目标覆盖率 | 强制检查 |
|------|-----------|-----------|----------|
| 核心业务逻辑（钱龄/预算/小金库） | 90% | 95% | ✅ |
| 数据模型 | 85% | 90% | ✅ |
| Provider/Service | 80% | 85% | ✅ |
| AI服务 | 75% | 85% | ✅ |
| API端点 | 80% | 90% | ✅ |
| UI组件 | 60% | 75% | ❌ |
| 工具类 | 75% | 85% | ❌ |
| **整体** | **75%** | **85%** | ✅ |

#### 18.11.2 覆盖率监控

```dart
/// 覆盖率检查脚本
class CoverageChecker {
  static const requiredCoverage = {
    'lib/core/money_age/': 90,
    'lib/core/budget/': 90,
    'lib/core/vault/': 90,
    'lib/services/': 80,
    'lib/providers/': 80,
  };

  static Future<bool> check(String lcovPath) async {
    final coverage = await parseLcov(lcovPath);

    for (final entry in requiredCoverage.entries) {
      final dirCoverage = coverage.getCoverage(entry.key);
      if (dirCoverage < entry.value) {
        print('❌ ${entry.key}: $dirCoverage% < ${entry.value}% required');
        return false;
      }
      print('✅ ${entry.key}: $dirCoverage% >= ${entry.value}%');
    }

    return true;
  }
}
```

### 18.12 目标达成检测

#### 18.12.1 测试质量目标

```dart
/// 测试策略目标达成检测（对齐1.4.2节定义）
class TestingGoalAchievement {
  static const testingGoal = GoalCriteria(
    name: '测试质量保障',
    description: '确保产品质量和稳定性',

    // 功能完整度标准
    featureCompleteness: [
      '单元测试覆盖所有核心业务逻辑',
      'Widget测试覆盖所有核心页面',
      '集成测试覆盖关键用户旅程',
      'API测试覆盖所有端点',
      '性能测试建立基准并持续监控',
      'AI功能测试覆盖识别准确率',
      '安全测试覆盖OWASP Top 10',
    ],

    // 测试效果标准
    outcomeMetrics: [
      OutcomeMetric(
        name: '代码覆盖率',
        measurement: '整体代码覆盖率',
        target: 0.80,  // 80%
        method: 'lcov统计',
      ),
      OutcomeMetric(
        name: '缺陷逃逸率',
        measurement: '上线后发现的缺陷/总缺陷',
        target: 0.05,  // <5%
        method: '缺陷追踪统计',
      ),
      OutcomeMetric(
        name: 'CI通过率',
        measurement: 'CI流水线首次通过率',
        target: 0.90,  // 90%
        method: 'GitHub Actions统计',
      ),
      OutcomeMetric(
        name: '回归缺陷率',
        measurement: '回归测试发现的新缺陷率',
        target: 0.02,  // <2%
        method: '版本迭代缺陷统计',
      ),
    ],

    // 满意度标准
    satisfactionTarget: SatisfactionMetric(
      appCrashRate: 0.001,  // 崩溃率 <0.1%
      userReportedBugs: 5,  // 每月用户报告缺陷 <5个
    ),
  );
}
```

---
