# 规范：Repository Pattern 实现

## 新增需求

### 需求：基础 Repository 接口
**ID**: `repository-pattern.base-interface`
**优先级**: P0
**状态**: 提案中

系统应提供通用的 Repository 接口，定义所有实体仓库的基本 CRUD 操作。

#### 场景：定义基础 Repository 接口
**前置条件**:
- 无

**操作**:
1. 创建 `IRepository<T, ID>` 泛型接口
2. 定义基本方法：insert, getById, getAll, update, delete

**预期结果**:
- 接口定义清晰，包含完整的 CRUD 方法签名
- 使用泛型支持不同实体类型
- 方法返回 Future 支持异步操作

**示例代码**:
```dart
abstract class IRepository<T, ID> {
  /// 插入新实体
  Future<ID> insert(T entity);

  /// 根据ID获取实体
  Future<T?> getById(ID id);

  /// 获取所有实体
  Future<List<T>> getAll();

  /// 更新实体
  Future<int> update(T entity);

  /// 删除实体
  Future<int> delete(ID id);
}
```

---

### 需求：Transaction Repository 接口
**ID**: `repository-pattern.transaction-repository`
**优先级**: P0
**状态**: 提案中
**依赖**: `repository-pattern.base-interface`

系统应提供 Transaction 专用的 Repository 接口，扩展基础接口并添加交易特定的查询方法。

#### 场景：定义 Transaction Repository 接口
**前置条件**:
- `IRepository<T, ID>` 接口已定义

**操作**:
1. 创建 `ITransactionRepository` 接口继承 `IRepository<Transaction, String>`
2. 添加交易特定查询方法

**预期结果**:
- 接口包含所有交易相关查询方法
- 方法签名清晰，参数合理

**示例代码**:
```dart
abstract class ITransactionRepository extends IRepository<Transaction, String> {
  /// 按日期范围查询交易
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);

  /// 按分类查询交易
  Future<List<Transaction>> getByCategory(String category);

  /// 按账户查询交易
  Future<List<Transaction>> getByAccount(String accountId);

  /// 计算总金额
  Future<double> getTotalAmount(DateTime start, DateTime end);

  /// 按条件查询交易
  Future<List<Transaction>> query({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? account,
    int? limit,
  });
}
```

#### 场景：实现 Transaction Repository
**前置条件**:
- `ITransactionRepository` 接口已定义
- Database 实例可用

**操作**:
1. 创建 `TransactionRepository` 类实现 `ITransactionRepository`
2. 实现所有接口方法
3. 使用 SQLite 进行数据持久化

**预期结果**:
- 所有方法正确实现
- 数据库操作正确执行
- 错误处理完善

**示例代码**:
```dart
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
      'date': transaction.date.toIso8601String(),
      // ... 其他字段
    });
    return id;
  }

  @override
  Future<Transaction?> getById(String id) async {
    final results = await _db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Transaction.fromMap(results.first);
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
      orderBy: 'date DESC',
    );
    return results.map((r) => Transaction.fromMap(r)).toList();
  }

  // ... 其他方法实现
}
```

---

### 需求：Account Repository
**ID**: `repository-pattern.account-repository`
**优先级**: P0
**状态**: 提案中
**依赖**: `repository-pattern.base-interface`

系统应提供 Account 专用的 Repository 接口和实现。

#### 场景：Account Repository 接口和实现
**前置条件**:
- `IRepository<T, ID>` 接口已定义

**操作**:
1. 创建 `IAccountRepository` 接口
2. 实现 `AccountRepository` 类

**预期结果**:
- 接口包含账户特定查询方法
- 实现正确处理账户数据

**示例代码**:
```dart
abstract class IAccountRepository extends IRepository<Account, String> {
  Future<List<Account>> getByLedger(String ledgerId);
  Future<double> getBalance(String accountId);
  Future<List<Account>> getActive();
}
```

---

### 需求：Category Repository
**ID**: `repository-pattern.category-repository`
**优先级**: P0
**状态**: 提案中
**依赖**: `repository-pattern.base-interface`

系统应提供 Category 专用的 Repository 接口和实现。

#### 场景：Category Repository 接口和实现
**前置条件**:
- `IRepository<T, ID>` 接口已定义

**操作**:
1. 创建 `ICategoryRepository` 接口
2. 实现 `CategoryRepository` 类

**预期结果**:
- 接口包含分类特定查询方法
- 实现正确处理分类数据

**示例代码**:
```dart
abstract class ICategoryRepository extends IRepository<Category, String> {
  Future<List<Category>> getByType(CategoryType type);
  Future<List<Category>> getTopLevel();
  Future<List<Category>> getSubCategories(String parentId);
}
```

---

### 需求：Repository Factory
**ID**: `repository-pattern.factory`
**优先级**: P1
**状态**: 提案中
**依赖**: `repository-pattern.transaction-repository`, `repository-pattern.account-repository`, `repository-pattern.category-repository`

系统应提供 Repository Factory 用于创建和管理所有 Repository 实例。

#### 场景：创建 Repository Factory
**前置条件**:
- 所有 Repository 实现已完成
- DatabaseService 可用

**操作**:
1. 创建 `RepositoryFactory` 类
2. 提供创建各种 Repository 的方法

**预期结果**:
- Factory 可以创建所有类型的 Repository
- Repository 实例正确初始化

**示例代码**:
```dart
class RepositoryFactory {
  final DatabaseService _dbService;

  RepositoryFactory(this._dbService);

  ITransactionRepository createTransactionRepository() {
    return TransactionRepository(_dbService.database);
  }

  IAccountRepository createAccountRepository() {
    return AccountRepository(_dbService.database);
  }

  ICategoryRepository createCategoryRepository() {
    return CategoryRepository(_dbService.database);
  }

  // ... 其他 Repository 创建方法
}
```

---

## 修改需求

### 需求：重构 DatabaseService
**ID**: `repository-pattern.refactor-database-service`
**优先级**: P0
**状态**: 提案中
**依赖**: `repository-pattern.factory`

DatabaseService 应该从包含所有 CRUD 操作的 God Object 重构为仅负责数据库初始化和迁移的轻量级服务。

#### 场景：简化 DatabaseService
**前置条件**:
- Repository Pattern 已实现
- 所有 Repository 可用

**操作**:
1. 移除 DatabaseService 中的所有 CRUD 方法
2. 保留数据库初始化和迁移逻辑
3. 提供 Database 实例访问

**预期结果**:
- DatabaseService 行数<500
- 职责单一：仅负责数据库生命周期管理
- 所有 CRUD 操作通过 Repository 进行

**示例代码**:
```dart
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
    // 创建所有表
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    // ... 其他表
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // 数据库迁移逻辑
  }

  Database get database {
    if (_database == null) {
      throw StateError('Database not initialized');
    }
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
```

---

## 测试需求

### 需求：Repository 单元测试
**ID**: `repository-pattern.unit-tests`
**优先级**: P0
**状态**: 提案中

所有 Repository 实现必须有完整的单元测试覆盖。

#### 场景：Transaction Repository 单元测试
**前置条件**:
- TransactionRepository 已实现

**操作**:
1. 创建测试文件
2. 测试所有 CRUD 操作
3. 测试边界条件和错误处理

**预期结果**:
- 测试覆盖率>80%
- 所有测试通过
- 边界条件和错误情况有覆盖

**示例代码**:
```dart
void main() {
  late Database db;
  late TransactionRepository repository;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');
      },
    );
    repository = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionRepository', () {
    test('insert should add transaction to database', () async {
      final transaction = Transaction(
        amount: 100.0,
        category: 'food',
        date: DateTime.now(),
      );

      final id = await repository.insert(transaction);

      expect(id, isNotEmpty);
      final retrieved = await repository.getById(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.amount, equals(100.0));
    });

    test('getByDateRange should return transactions in range', () async {
      // 测试实现...
    });

    // ... 更多测试
  });
}
```

---

## 非功能需求

### 需求：性能要求
**ID**: `repository-pattern.performance`
**优先级**: P1
**状态**: 提案中

Repository 操作应满足性能要求。

#### 场景：Repository 性能基准
**前置条件**:
- Repository 实现完成

**操作**:
1. 测试常见操作的性能
2. 确保性能符合要求

**预期结果**:
- 单条记录插入 <10ms
- 单条记录查询 <5ms
- 批量查询(100条) <50ms
- 复杂查询 <100ms

---

### 需求：代码质量
**ID**: `repository-pattern.code-quality`
**优先级**: P1
**状态**: 提案中

Repository 代码应符合质量标准。

#### 场景：代码质量检查
**前置条件**:
- Repository 实现完成

**操作**:
1. 运行 flutter analyze
2. 检查代码覆盖率
3. 代码审查

**预期结果**:
- 无 lint 错误
- 测试覆盖率>80%
- 代码审查通过
- 每个 Repository <200行

---

## 交叉引用

- 依赖规范: 无（这是基础规范）
- 被依赖规范: `coordinator-pattern`, `clean-architecture`
- 相关规范: `database-service`
