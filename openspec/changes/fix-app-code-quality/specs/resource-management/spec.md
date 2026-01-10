# 资源管理规范

## 新增需求

### 需求：StreamSubscription 必须保存引用并在 dispose 时取消

所有 Stream 监听必须保存订阅引用，并在资源释放时正确取消。

#### 场景：服务类中的 Stream 监听

**给定** 一个服务类需要监听 Stream
**当** 设置监听时
**那么** 必须将 `StreamSubscription` 保存为成员变量
**并且** 在 `dispose()` 方法中调用 `cancel()`

**正确示例**：
```dart
class SyncService {
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<State>? _stateSubscription;

  void _setupListeners() {
    _messageSubscription = _wsService.onMessage.listen(_handleMessage);
    _stateSubscription = _wsService.onStateChange.listen(_handleState);
  }

  void dispose() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
  }
}
```

**错误示例**：
```dart
void _setupListeners() {
  _wsService.onMessage.listen(_handleMessage);  // 无法取消！
}
```

---

### 需求：Riverpod Notifier 必须使用 ref.onDispose 管理资源

Notifier 类中的资源清理必须通过 `ref.onDispose()` 回调注册，而非定义独立的 `dispose()` 方法。

#### 场景：Notifier 资源清理

**给定** 一个 Notifier 类需要管理 Stream 或其他资源
**当** 在 `build()` 方法中初始化资源时
**那么** 必须立即使用 `ref.onDispose()` 注册清理回调

**正确示例**：
```dart
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    final subscription = _syncService.events.listen(_handleEvent);

    ref.onDispose(() {
      subscription.cancel();
    });

    return SyncState.initial();
  }
}
```

**错误示例**：
```dart
class SyncNotifier extends Notifier<SyncState> {
  StreamSubscription? _subscription;

  @override
  SyncState build() {
    _subscription = _syncService.events.listen(_handleEvent);
    return SyncState.initial();
  }

  void dispose() {  // 不会被 Riverpod 自动调用！
    _subscription?.cancel();
  }
}
```

---

### 需求：数据库连接必须在所有代码路径上关闭

打开的数据库连接必须使用 try-finally 确保在所有情况下都能正确关闭。

#### 场景：数据库连接管理

**给定** 需要临时打开数据库连接进行操作
**当** 执行数据库操作时
**那么** 必须使用 try-finally 确保连接关闭
**即使** 操作过程中发生异常

**正确示例**：
```dart
Future<int> getDatabaseVersion(String path) async {
  Database? db;
  try {
    db = await openDatabase(path, readOnly: true);
    return await db.getVersion();
  } catch (e) {
    _logger.error('Failed to get version', error: e);
    return 0;
  } finally {
    await db?.close();
  }
}
```

**错误示例**：
```dart
Future<int> getDatabaseVersion(String path) async {
  try {
    final db = await openDatabase(path, readOnly: true);
    final version = await db.getVersion();
    await db.close();  // 如果 getVersion() 抛异常，这行不会执行
    return version;
  } catch (e) {
    return 0;  // db 未关闭！
  }
}
```

---

### 需求：单例服务必须遵循标准实现模式

单例服务必须使用私有构造函数和静态实例，不允许通过构造函数参数创建不同实例。

#### 场景：单例服务配置

**给定** 一个需要配置的单例服务
**当** 需要动态配置服务参数时
**那么** 应该通过独立的 `configure()` 方法
**而非** 通过构造函数参数

**正确示例**：
```dart
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();

  factory OfflineQueueService() => _instance;

  OfflineQueueService._internal();

  RetryConfig _retryConfig = RetryConfig.defaultConfig;

  void configure({RetryConfig? retryConfig}) {
    if (retryConfig != null) {
      _retryConfig = retryConfig;
    }
  }
}
```

**错误示例**：
```dart
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();

  factory OfflineQueueService({RetryConfig? retryConfig}) {
    if (retryConfig != null) {
      return OfflineQueueService._withConfig(retryConfig);  // 创建新实例！
    }
    return _instance;
  }
}
```

---

### 需求：Timer 必须在不再需要时取消

所有创建的 Timer 对象必须保存引用，并在适当时机取消。

#### 场景：防抖 Timer 管理

**给定** 一个使用 Timer 实现防抖的服务
**当** 创建新的防抖 Timer 时
**那么** 必须先取消之前的 Timer
**并且** 在 `dispose()` 中取消所有未完成的 Timer

**正确示例**：
```dart
class AutoSyncService {
  Timer? _debounceTimer;

  void _scheduleSyncWithDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(seconds: 5), _performSync);
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
```

---

## 修改需求

### 需求：并发操作必须有互斥保护

必须修改现有使用简单布尔标志位控制并发的代码，改为使用适当的互斥机制。禁止仅依赖布尔标志位来防止并发执行。

#### 场景：防止并发执行

**给定** 一个不应该并发执行的异步操作
**当** 多处代码可能同时调用该操作时
**那么** 应该使用 `Completer` 或互斥锁确保串行执行
**而非** 仅依赖简单的布尔标志位

**正确示例**：
```dart
class SyncService {
  Completer<void>? _syncCompleter;

  Future<void> sync() async {
    if (_syncCompleter != null) {
      return _syncCompleter!.future;  // 等待已有操作完成
    }

    _syncCompleter = Completer<void>();
    try {
      await _performSync();
      _syncCompleter!.complete();
    } catch (e) {
      _syncCompleter!.completeError(e);
      rethrow;
    } finally {
      _syncCompleter = null;
    }
  }
}
```
