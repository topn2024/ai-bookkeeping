# 架构设计：改进架构解耦

## 1. 目标架构

### 1.1 分层架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        UI 层                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Pages     │  │   Widgets   │  │    Dialogs          │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┴──────────┬──────────┘             │
│                                     ▼                        │
├─────────────────────────────────────────────────────────────┤
│                     状态管理层                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Providers (Riverpod)                       │ │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │ │
│  │   │ Transaction │  │   Account   │  │   Budget    │    │ │
│  │   │  Provider   │  │  Provider   │  │  Provider   │    │ │
│  │   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │ │
│  └──────────┼────────────────┼────────────────┼────────────┘ │
│             │                │                │              │
│             └────────────────┴────────┬───────┘              │
│                                       ▼                      │
├─────────────────────────────────────────────────────────────┤
│                      服务层                                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Service Locator                         │ │
│  │   ┌───────────────────────────────────────────────────┐ │ │
│  │   │              服务接口 (Contracts)                 │ │ │
│  │   │  ITransactionService  IAccountService  IBudget... │ │ │
│  │   └───────────────────────────────────────────────────┘ │ │
│  │                          ▼                              │ │
│  │   ┌───────────────────────────────────────────────────┐ │ │
│  │   │              服务实现                             │ │ │
│  │   │  TransactionService  AccountService  BudgetSvc... │ │ │
│  │   └───────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                               │
│                              ▼                               │
├─────────────────────────────────────────────────────────────┤
│                    数据访问层                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Repositories                            │ │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │ │
│  │   │ Transaction │  │   Account   │  │   Budget    │    │ │
│  │   │ Repository  │  │ Repository  │  │ Repository  │    │ │
│  │   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │ │
│  └──────────┼────────────────┼────────────────┼────────────┘ │
│             │                │                │              │
│             └────────────────┴────────┬───────┘              │
│                                       ▼                      │
├─────────────────────────────────────────────────────────────┤
│                      基础设施层                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Database   │  │    HTTP     │  │   Secure Storage    │  │
│  │   Service   │  │   Service   │  │      Service        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 依赖规则

- **UI 层** → 只依赖 Providers
- **Providers** → 只依赖 服务接口
- **服务层** → 依赖 Repositories 和 基础设施接口
- **Repositories** → 只依赖 基础设施层
- **基础设施层** → 无上层依赖

---

## 2. 依赖注入设计

### 2.1 Service Locator 实现

使用 `get_it` 包实现服务定位器：

```dart
// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // 基础设施层
  sl.registerLazySingleton<IDatabaseService>(() => DatabaseService());
  sl.registerLazySingleton<IHttpService>(() => HttpService());
  sl.registerLazySingleton<ISecureStorageService>(() => SecureStorageService());

  // 数据访问层
  sl.registerLazySingleton<ITransactionRepository>(
    () => TransactionRepository(sl<IDatabaseService>()),
  );
  sl.registerLazySingleton<IAccountRepository>(
    () => AccountRepository(sl<IDatabaseService>()),
  );

  // 服务层
  sl.registerLazySingleton<ITransactionService>(
    () => TransactionService(sl<ITransactionRepository>()),
  );
  sl.registerLazySingleton<IAIService>(
    () => AIService(sl<IHttpService>()),
  );
}
```

### 2.2 Riverpod 集成

```dart
// lib/providers/service_providers.dart
import 'package:riverpod/riverpod.dart';
import '../core/di/service_locator.dart';

final transactionServiceProvider = Provider<ITransactionService>((ref) {
  return sl<ITransactionService>();
});

final accountServiceProvider = Provider<IAccountService>((ref) {
  return sl<IAccountService>();
});
```

---

## 3. 服务接口设计

### 3.1 核心服务接口

```dart
// lib/services/contracts/i_transaction_service.dart
abstract class ITransactionService {
  Future<List<Transaction>> getAll();
  Future<Transaction?> getById(String id);
  Future<void> create(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(String id);
  Future<List<Transaction>> query(TransactionQuery query);
}

// lib/services/contracts/i_account_service.dart
abstract class IAccountService {
  Future<List<Account>> getAll();
  Future<Account?> getById(String id);
  Future<void> create(Account account);
  Future<void> update(Account account);
  Future<void> delete(String id);
  Future<void> transfer(String fromId, String toId, double amount);
}

// lib/services/contracts/i_ai_service.dart
abstract class IAIService {
  Future<RecognitionResult> recognizeImage(File image);
  Future<ParseResult> parseText(String text);
  Future<List<String>> suggestCategories(String description);
}
```

### 3.2 Repository 接口

```dart
// lib/repositories/contracts/i_transaction_repository.dart
abstract class ITransactionRepository {
  Future<List<Transaction>> findAll();
  Future<Transaction?> findById(String id);
  Future<void> insert(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(String id);
  Future<List<Transaction>> findByDateRange(DateTime start, DateTime end);
}
```

---

## 4. 模型层解耦设计

### 4.1 当前问题

```dart
// 当前实现 (违反分层)
class Account {
  String get localizedName {
    return AccountLocalizationService.instance.getAccountName(id);
  }
}
```

### 4.2 改进方案

**方案 A：扩展方法 (推荐)**

```dart
// lib/models/account.dart (纯数据模型)
class Account {
  final String id;
  final String name;
  final double balance;
  // ... 纯数据属性，无服务依赖
}

// lib/extensions/account_extensions.dart
extension AccountLocalization on Account {
  String localizedName(ILocalizationService service) {
    return service.getAccountName(id);
  }
}

// 使用方式
final name = account.localizedName(sl<ILocalizationService>());
```

**方案 B：ViewModel 封装**

```dart
// lib/view_models/account_view_model.dart
class AccountViewModel {
  final Account _account;
  final ILocalizationService _localization;

  AccountViewModel(this._account, this._localization);

  String get localizedName => _localization.getAccountName(_account.id);
  String get formattedBalance => _account.balance.toCurrency();
}
```

---

## 5. CRUD Notifier 改进设计

### 5.1 当前问题

```dart
// 当前实现 (内部创建依赖)
abstract class SimpleCrudNotifier<T, ID> {
  DatabaseService get db => DatabaseService();  // 无法注入
}
```

### 5.2 改进方案

```dart
// lib/providers/base/crud_notifier.dart
abstract class CrudNotifier<T, ID> extends StateNotifier<AsyncValue<List<T>>> {
  final IRepository<T, ID> repository;

  CrudNotifier(this.repository) : super(const AsyncValue.loading());

  Future<void> loadAll() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.findAll());
  }

  Future<void> create(T entity) async {
    await repository.insert(entity);
    await loadAll();
  }

  // ... 其他 CRUD 方法
}

// 使用方式
class TransactionNotifier extends CrudNotifier<Transaction, String> {
  TransactionNotifier(ITransactionRepository repository) : super(repository);
}

// Provider 定义
final transactionNotifierProvider = StateNotifierProvider<
    TransactionNotifier, AsyncValue<List<Transaction>>>((ref) {
  return TransactionNotifier(ref.watch(transactionRepositoryProvider));
});
```

---

## 6. 配置管理设计

### 6.1 环境配置

```dart
// lib/core/config/app_config.dart
abstract class AppConfig {
  String get apiBaseUrl;
  String get aiServiceUrl;
  bool get enableAnalytics;
  Duration get syncInterval;
}

class DevConfig implements AppConfig {
  @override
  String get apiBaseUrl => 'https://dev-api.example.com';
  // ...
}

class ProdConfig implements AppConfig {
  @override
  String get apiBaseUrl => 'https://api.example.com';
  // ...
}
```

### 6.2 API 端点定义

```dart
// lib/core/api/api_endpoints.dart
class ApiEndpoints {
  final String baseUrl;

  const ApiEndpoints(this.baseUrl);

  String get transactions => '$baseUrl/v1/transactions';
  String get accounts => '$baseUrl/v1/accounts';
  String get sync => '$baseUrl/v1/sync';

  String transaction(String id) => '$baseUrl/v1/transactions/$id';
}
```

---

## 7. 目录结构调整

```
lib/
├── core/
│   ├── di/
│   │   └── service_locator.dart       # 依赖注入配置
│   ├── config/
│   │   ├── app_config.dart            # 应用配置
│   │   └── api_endpoints.dart         # API 端点
│   └── contracts/                      # 基础设施接口
│       ├── i_database_service.dart
│       └── i_http_service.dart
├── models/                             # 纯数据模型 (无服务依赖)
├── repositories/
│   ├── contracts/                      # Repository 接口
│   │   ├── i_transaction_repository.dart
│   │   └── i_account_repository.dart
│   └── impl/                           # Repository 实现
│       ├── transaction_repository.dart
│       └── account_repository.dart
├── services/
│   ├── contracts/                      # 服务接口
│   │   ├── i_transaction_service.dart
│   │   └── i_ai_service.dart
│   └── impl/                           # 服务实现
│       ├── transaction_service.dart
│       └── ai_service.dart
├── extensions/                         # 模型扩展方法
│   └── account_extensions.dart
├── providers/
│   ├── service_providers.dart          # 服务 Provider
│   └── state_providers.dart            # 状态 Provider
├── pages/
└── widgets/
```

---

## 8. 迁移策略

### 阶段 1：基础设施 (低风险)
1. 添加 `get_it` 依赖
2. 创建 Service Locator
3. 定义核心服务接口

### 阶段 2：数据访问层 (中风险)
1. 创建 Repository 接口
2. 实现 Repository
3. 迁移 DatabaseService 调用

### 阶段 3：服务层 (中风险)
1. 服务实现接口
2. 通过 Service Locator 注册
3. 更新 Provider 使用接口

### 阶段 4：模型层 (低风险)
1. 移除模型中的服务依赖
2. 创建扩展方法
3. 更新 UI 调用方式

### 阶段 5：UI 层 (低风险)
1. 移除页面中的直接服务调用
2. 全部通过 Provider 访问

---

## 9. 技术选型理由

| 决策 | 选择 | 理由 |
|------|------|------|
| DI 方案 | get_it | 轻量、与 Riverpod 兼容、社区广泛使用 |
| 接口定义 | 抽象类 | Dart 原生支持，无需额外依赖 |
| 模型解耦 | 扩展方法 | 侵入性最小，保持模型纯净 |
| Repository | 手动实现 | 控制力强，避免过度抽象 |
