# 架构重构设计文档

## 1. 架构现状分析

### 1.1 当前架构问题

#### God Object 反模式

**VoiceServiceCoordinator (4,645行 - 2026-01-29更新，原4,063行)**
```
职责过多（持续增长中）：
├── 语音识别生命周期管理
├── 意图分析和路由
├── 多意图处理
├── 实体消歧
├── 交易 CRUD 操作
├── 导航处理
├── 自动化任务管理
├── 预算查询
├── 建议生成
├── 聊天/对话管理
├── TTS 协调
├── 会话超时管理
├── 打断检测
├── 网络状态监控
├── 学习服务集成
├── [NEW] 对话式金额补充 (_pendingAmountIntent)
├── [NEW] 对话式分类补充 (_pendingCategoryIntent)
├── [NEW] 备注提取和分类推断
└── [NEW] TTS消息记录到聊天历史

依赖注入（17+个）：
- VoiceRecognitionEngine
- TTSService
- EntityDisambiguationService
- VoiceDeleteService
- VoiceModifyService
- VoiceNavigationService
- VoiceIntentRouter
- VoiceFeedbackSystem
- IDatabaseService
- ScreenReaderService
- AutomationTaskService
- NaturalLanguageSearchService
- CasualChatService
- VoiceConfigService
- VoiceAdviceService
- ConversationContext
- BargeInDetector
```

**DatabaseService (4,448行)**
```
管理的实体类型（20+）：
├── Transactions & Splits
├── Accounts
├── Categories
├── Ledgers
├── Budgets & Carryovers
├── Templates
├── Recurring Transactions
├── Credit Cards
├── Savings Goals & Deposits
├── Bill Reminders
├── Investment Accounts
├── Debts & Payments
├── Ledger Members
├── Member Invites
├── Member Budgets
├── Expense Approvals
├── Import Batches
├── Resource Pools
├── Budget Vaults
└── Learning Records

方法数量：196个异步方法
```

### 1.2 SOLID 违反分析

#### 单一职责原则 (SRP)
```
VoiceServiceCoordinator 的变更原因：
1. 语音识别引擎更新
2. 意图路由逻辑变更
3. 数据库 schema 变更
4. TTS 服务更新
5. 导航系统变更
6. 自动化逻辑变更
7. 预算查询逻辑变更
8. 聊天服务更新
9. 学习算法变更
10. ... 更多
```

#### 开闭原则 (OCP)
```dart
// 当前实现：添加新意图需要修改 switch
Future<VoiceSessionResult> _routeToIntentHandler(...) async {
  switch (intentResult.intent) {
    case VoiceIntentType.deleteTransaction:
      return await _handleDeleteIntent(...);
    case VoiceIntentType.modifyTransaction:
      return await _handleModifyIntent(...);
    // ... 20+ cases
    // 添加新意图必须修改这里
  }
}
```

#### 接口隔离原则 (ISP)
```dart
// 当前实现：接口过大
abstract class IDatabaseService {
  // 196个方法
  Future<int> insertTransaction(...);
  Future<int> insertAccount(...);
  Future<int> insertCategory(...);
  // ... 193 more methods
}

// 问题：VoiceServiceCoordinator 只需要交易操作
// 但必须依赖整个接口
```

## 2. 目标架构设计

### 2.1 清晰分层架构

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  (Pages, Widgets, Providers - Riverpod State Management)│
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                   Application Layer                      │
│     (Coordinators, Services, Use Cases, DTOs)           │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  VoiceServiceCoordinator (Orchestrator)          │  │
│  │  ├── VoiceRecognitionCoordinator                 │  │
│  │  ├── IntentProcessingCoordinator                 │  │
│  │  ├── TransactionOperationCoordinator             │  │
│  │  ├── NavigationCoordinator                       │  │
│  │  ├── ConversationCoordinator                     │  │
│  │  └── FeedbackCoordinator                         │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                     Domain Layer                         │
│        (Entities, Value Objects, Repository              │
│         Interfaces, Domain Events, Use Cases)            │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Repository Interfaces                           │  │
│  │  ├── ITransactionRepository                      │  │
│  │  ├── IAccountRepository                          │  │
│  │  ├── ICategoryRepository                         │  │
│  │  ├── ILedgerRepository                           │  │
│  │  └── IBudgetRepository                           │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                 Infrastructure Layer                     │
│    (Database, Network, Voice Services, External APIs)    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Repository Implementations                      │  │
│  │  ├── TransactionRepository                       │  │
│  │  ├── AccountRepository                           │  │
│  │  ├── CategoryRepository                          │  │
│  │  └── ...                                         │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 2.2 VoiceServiceCoordinator 重构设计

#### 当前结构（4,063行）
```dart
class VoiceServiceCoordinator extends ChangeNotifier {
  // 31个依赖
  // 30个处理方法
  // 15+种职责
}
```

#### 目标结构
```dart
// 主协调器（仅编排，<300行）
class VoiceServiceCoordinator extends ChangeNotifier {
  final VoiceRecognitionCoordinator _recognitionCoordinator;
  final IntentProcessingCoordinator _intentCoordinator;
  final TransactionOperationCoordinator _transactionCoordinator;
  final NavigationCoordinator _navigationCoordinator;
  final ConversationCoordinator _conversationCoordinator;
  final FeedbackCoordinator _feedbackCoordinator;

  Future<VoiceSessionResult> processVoiceCommand(String input) async {
    // 1. 识别
    final recognition = await _recognitionCoordinator.recognize(input);

    // 2. 处理意图
    final intent = await _intentCoordinator.process(recognition);

    // 3. 路由到具体协调器
    return await _routeToCoordinator(intent);
  }

  Future<VoiceSessionResult> _routeToCoordinator(Intent intent) async {
    switch (intent.type) {
      case IntentType.transaction:
        return await _transactionCoordinator.handle(intent);
      case IntentType.navigation:
        return await _navigationCoordinator.handle(intent);
      case IntentType.conversation:
        return await _conversationCoordinator.handle(intent);
      default:
        return VoiceSessionResult.error('Unknown intent');
    }
  }
}

// 语音识别协调器（<300行）
class VoiceRecognitionCoordinator {
  final VoiceRecognitionEngine _engine;
  final SmartIntentRecognizer _recognizer;

  Future<RecognitionResult> recognize(String input) async {
    // 语音识别生命周期管理
  }
}

// 意图处理协调器（<300行）
class IntentProcessingCoordinator {
  final VoiceIntentRouter _router;
  final EntityDisambiguationService _disambiguation;
  final AIIntentDecomposer _decomposer;

  Future<ProcessedIntent> process(RecognitionResult result) async {
    // 意图分析、路由、消歧
  }
}

// 交易操作协调器（<300行）
class TransactionOperationCoordinator {
  final ITransactionRepository _transactionRepo;
  final ICategoryRepository _categoryRepo;
  final IAccountRepository _accountRepo;

  Future<VoiceSessionResult> handle(Intent intent) async {
    // 交易 CRUD 操作
  }
}

// 导航协调器（<200行）
class NavigationCoordinator {
  final VoiceNavigationService _navigationService;

  Future<VoiceSessionResult> handle(Intent intent) async {
    // 页面导航
  }
}

// 对话协调器（<300行）
class ConversationCoordinator {
  final ConversationContext _context;
  final CasualChatService _chatService;

  Future<VoiceSessionResult> handle(Intent intent) async {
    // 对话管理
  }
}

// 反馈协调器（<200行）
class FeedbackCoordinator {
  final VoiceFeedbackSystem _feedbackSystem;
  final TTSService _ttsService;

  Future<void> provideFeedback(VoiceSessionResult result) async {
    // 反馈和 TTS
  }
}
```

### 2.3 DatabaseService 重构设计

#### 当前结构（4,448行）
```dart
class DatabaseService implements IDatabaseService {
  // 196个方法
  // 20+种实体类型
  // 混合：CRUD + Schema + Migration
}
```

#### 目标结构

**Repository Pattern**
```dart
// 基础仓库接口
abstract class IRepository<T, ID> {
  Future<ID> insert(T entity);
  Future<T?> getById(ID id);
  Future<List<T>> getAll();
  Future<int> update(T entity);
  Future<int> delete(ID id);
}

// 交易仓库接口
abstract class ITransactionRepository extends IRepository<Transaction, String> {
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);
  Future<List<Transaction>> getByCategory(String category);
  Future<List<Transaction>> getByAccount(String accountId);
  Future<double> getTotalAmount(DateTime start, DateTime end);
}

// 交易仓库实现
class TransactionRepository implements ITransactionRepository {
  final Database _db;

  TransactionRepository(this._db);

  @override
  Future<String> insert(Transaction transaction) async {
    final id = const Uuid().v4();
    await _db.insert('transactions', {
      'id': id,
      'amount': transaction.amount,
      'category': transaction.category,
      // ...
    });
    return id;
  }

  @override
  Future<List<Transaction>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final results = await _db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return results.map((r) => Transaction.fromMap(r)).toList();
  }

  // ... 其他方法
}

// 账户仓库接口
abstract class IAccountRepository extends IRepository<Account, String> {
  Future<List<Account>> getByLedger(String ledgerId);
  Future<double> getBalance(String accountId);
}

// 账户仓库实现
class AccountRepository implements IAccountRepository {
  final Database _db;

  AccountRepository(this._db);

  // 实现方法...
}

// 数据库服务（仅初始化和迁移，<500行）
class DatabaseService {
  Database? _database;

  Future<void> initialize() async {
    _database = await openDatabase(
      'bookkeeping.db',
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建表
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 迁移逻辑
  }

  Database get database => _database!;
}

// 仓库工厂
class RepositoryFactory {
  final DatabaseService _dbService;

  RepositoryFactory(this._dbService);

  ITransactionRepository createTransactionRepository() {
    return TransactionRepository(_dbService.database);
  }

  IAccountRepository createAccountRepository() {
    return AccountRepository(_dbService.database);
  }

  // ... 其他仓库
}
```

### 2.4 依赖注入重构

#### 当前实现（Service Locator）
```dart
class VoiceServiceCoordinator {
  VoiceServiceCoordinator() {
    // 隐藏依赖
    _databaseService = sl<IDatabaseService>();
    _learningService = sl<VoiceIntentLearningService>();
  }
}
```

#### 目标实现（Constructor Injection）
```dart
class VoiceServiceCoordinator {
  final VoiceRecognitionCoordinator recognitionCoordinator;
  final IntentProcessingCoordinator intentCoordinator;
  final TransactionOperationCoordinator transactionCoordinator;

  VoiceServiceCoordinator({
    required this.recognitionCoordinator,
    required this.intentCoordinator,
    required this.transactionCoordinator,
  });
}

// 使用 Riverpod 进行依赖注入
final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return TransactionRepository(dbService.database);
});

final transactionCoordinatorProvider = Provider<TransactionOperationCoordinator>((ref) {
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  return TransactionOperationCoordinator(
    transactionRepo: transactionRepo,
    categoryRepo: categoryRepo,
  );
});

final voiceServiceCoordinatorProvider = Provider<VoiceServiceCoordinator>((ref) {
  return VoiceServiceCoordinator(
    recognitionCoordinator: ref.watch(recognitionCoordinatorProvider),
    intentCoordinator: ref.watch(intentCoordinatorProvider),
    transactionCoordinator: ref.watch(transactionCoordinatorProvider),
  );
});
```

## 3. 实施策略

### 3.1 并行开发策略

```
现有代码（保持运行）
    │
    ├─→ Phase 1: 创建新架构
    │   ├── 创建 Repository 接口和实现
    │   ├── 创建新的 Coordinator 类
    │   └── 添加单元测试
    │
    ├─→ Phase 2: 逐步迁移
    │   ├── 迁移交易操作到新 Coordinator
    │   ├── 迁移导航到新 Coordinator
    │   └── 迁移对话到新 Coordinator
    │
    └─→ Phase 3: 清理旧代码
        ├── 删除旧的 VoiceServiceCoordinator
        ├── 删除旧的 DatabaseService
        └── 更新所有引用
```

### 3.2 Feature Flag 控制

```dart
class FeatureFlags {
  static const bool useNewVoiceArchitecture = false;
  static const bool useRepositoryPattern = false;
}

class VoiceServiceFacade {
  Future<VoiceSessionResult> processCommand(String input) async {
    if (FeatureFlags.useNewVoiceArchitecture) {
      return await _newCoordinator.processVoiceCommand(input);
    } else {
      return await _oldCoordinator.processVoiceCommand(input);
    }
  }
}
```

### 3.3 测试策略

```
单元测试
├── Repository 测试（每个仓库独立测试）
├── Coordinator 测试（Mock 依赖）
└── Use Case 测试

集成测试
├── 端到端语音命令测试
├── 数据库操作测试
└── 多协调器协作测试

回归测试
└── 现有功能验证
```

## 4. 迁移路径

### 4.1 Phase 1: Repository Pattern（第1-2周）

**步骤：**
1. 创建 `IRepository<T, ID>` 基础接口
2. 创建 `ITransactionRepository` 接口
3. 实现 `TransactionRepository`
4. 添加单元测试
5. 在新代码中使用，旧代码保持不变

**验证：**
- [ ] 所有 Repository 测试通过
- [ ] 新旧代码可以共存
- [ ] 性能无退化

### 4.2 Phase 2: Coordinator 拆分（第3-4周）

**步骤：**
1. 创建 `TransactionOperationCoordinator`
2. 迁移交易相关方法
3. 创建 `NavigationCoordinator`
4. 迁移导航相关方法
5. 创建其他 Coordinator
6. 更新主 `VoiceServiceCoordinator` 为编排器

**验证：**
- [ ] 所有 Coordinator 测试通过
- [ ] 功能无回归
- [ ] 代码行数符合目标

### 4.3 Phase 3: 清理和优化（第5-8周）

**步骤：**
1. 删除旧的 `VoiceServiceCoordinator` 实现
2. 删除旧的 `DatabaseService` 实现
3. 更新所有引用
4. 移除 Feature Flags
5. 文档更新

**验证：**
- [ ] 所有测试通过
- [ ] 代码覆盖率>80%
- [ ] 性能基准测试通过

## 5. 风险缓解

### 5.1 回归风险
**缓解措施：**
- 全面的单元测试和集成测试
- Feature Flag 控制新旧代码切换
- 分阶段发布，每个阶段独立验证

### 5.2 性能风险
**缓解措施：**
- 性能基准测试
- 关键路径性能监控
- 必要时进行性能优化

### 5.3 学习曲线
**缓解措施：**
- 详细的架构文档
- 代码示例和最佳实践
- 团队培训和知识分享

## 6. 成功指标

### 代码质量指标
- [ ] 平均类行数 < 300
- [ ] 平均方法数 < 20
- [ ] 平均依赖数 < 5
- [ ] 循环依赖 = 0

### 测试指标
- [ ] 单元测试覆盖率 > 80%
- [ ] 集成测试覆盖核心流程
- [ ] 所有测试通过

### 性能指标
- [ ] 响应时间无退化
- [ ] 内存使用无显著增加
- [ ] 启动时间无退化

### 可维护性指标
- [ ] 新功能开发时间减少30%
- [ ] Bug 修复时间减少40%
- [ ] 代码审查时间减少50%
