# 设计文档：App 代码质量修复

## 1. 架构决策

### 1.1 序列化规范统一

**决策**：采用 ISO 8601 字符串格式统一 DateTime 序列化

**理由**：
- ISO 8601 是国际标准，跨平台兼容性好
- 字符串格式便于调试和日志查看
- 与后端 API 保持一致

**实现方式**：
```dart
// 序列化
'createdAt': createdAt.toIso8601String(),

// 反序列化
createdAt: DateTime.parse(map['createdAt'] as String),
```

### 1.2 Boolean 序列化规范

**决策**：根据存储目标选择序列化方式
- SQLite 存储：使用 `0/1` 整数（SQLite 无原生布尔类型）
- JSON/API 传输：使用原生布尔值

**实现方式**：
```dart
// toMap (for SQLite)
'isActive': isActive ? 1 : 0,

// toJson (for API)
'isActive': isActive,
```

### 1.3 Enum 序列化规范

**决策**：使用 `name` 而非 `index` 进行序列化

**理由**：
- 使用 index 在 Enum 值顺序变化时会破坏数据
- name 更具可读性，便于调试

**实现方式**：
```dart
// 序列化
'status': status.name,

// 反序列化
status: TransactionStatus.values.firstWhere(
  (e) => e.name == map['status'],
  orElse: () => TransactionStatus.pending,
),
```

### 1.4 错误处理模式

**决策**：采用统一的 Result 模式或 try-catch 规范

**服务层规范**：
```dart
Future<Result<T>> safeCall<T>(Future<T> Function() operation) async {
  try {
    final result = await operation();
    return Result.success(result);
  } catch (e, stackTrace) {
    _logger.error('Operation failed', error: e, stackTrace: stackTrace);
    return Result.failure(AppException.from(e));
  }
}
```

### 1.5 资源管理模式

**决策**：使用 Riverpod 的 `ref.onDispose()` 统一管理资源

**实现方式**：
```dart
@override
State build() {
  final subscription = someStream.listen(_handleEvent);
  ref.onDispose(() {
    subscription.cancel();
  });
  return initialState;
}
```

## 2. 详细修复方案

### 2.1 严重问题修复

#### 2.1.1 enhanced_voice_assistant_page.dart 崩溃修复

**问题代码** (行 496, 506)：
```dart
if (null != null) {  // 永远为 false
  // ...
}
Text(null!)  // 强制解包 null，会崩溃
```

**修复方案**：
```dart
// 需要检查原始意图，可能是要检查某个变量
if (feedbackText != null) {
  // ...
}
Text(feedbackText ?? '')
```

#### 2.1.2 Achievement 类重复定义修复

**问题**：
- `achievement.dart` 定义了 `Achievement` 类
- `family_leaderboard.dart` 也定义了 `Achievement` 类

**修复方案**：
- 重命名 `family_leaderboard.dart` 中的类为 `LeaderboardAchievement`
- 或提取公共基类

#### 2.1.3 async void 修复

**问题代码** (offline_queue_service.dart:84)：
```dart
void _onConnectivityChanged(List<ConnectivityResult> results) async {
  // ...
  await processQueue();  // 错误不会被捕获
}
```

**修复方案**：
```dart
void _onConnectivityChanged(List<ConnectivityResult> results) {
  final wasOnline = _isOnline;
  _isOnline = !results.contains(ConnectivityResult.none);

  if (_isOnline && !wasOnline) {
    // 使用 unawaited 明确表示不等待，并添加错误处理
    unawaited(processQueue().catchError((e) {
      _logger.error('Failed to process queue on reconnect', error: e);
    }));
  }
}
```

#### 2.1.4 Stream 监听泄漏修复

**问题代码** (crdt_sync_service.dart:43-54)：
```dart
void _setupListeners() {
  _wsService.onMessage.listen(_handleRemoteMessage);  // 未保存引用
}
```

**修复方案**：
```dart
StreamSubscription? _messageSubscription;
StreamSubscription? _stateSubscription;

void _setupListeners() {
  _messageSubscription = _wsService.onMessage.listen(_handleRemoteMessage);
  _stateSubscription = _wsService.onStateChange.listen(_handleStateChange);
}

void dispose() {
  _messageSubscription?.cancel();
  _stateSubscription?.cancel();
  // ...
}
```

### 2.2 模型层修复

#### 2.2.1 补全缺失的序列化方法

**RecurringTransaction** 需要添加：
```dart
Map<String, dynamic> toMap() {
  return {
    'id': id,
    'templateId': templateId,
    'frequency': frequency.name,
    'interval': interval,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'nextExecutionDate': nextExecutionDate.toIso8601String(),
    'lastExecutionDate': lastExecutionDate?.toIso8601String(),
    'isActive': isActive ? 1 : 0,
    'executionCount': executionCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
  return RecurringTransaction(
    id: map['id'] as String,
    templateId: map['templateId'] as String,
    frequency: RecurrenceFrequency.values.firstWhere(
      (e) => e.name == map['frequency'],
    ),
    // ... 其他字段
  );
}
```

### 2.3 服务层修复

#### 2.3.1 单例模式规范化

**问题** (OfflineQueueService)：允许创建多实例

**修复方案**：
```dart
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();

  factory OfflineQueueService() => _instance;

  OfflineQueueService._internal();

  // 如需配置，使用 configure 方法而非构造函数
  void configure({RetryConfig? retryConfig}) {
    if (retryConfig != null) {
      _retryConfig = retryConfig;
    }
  }
}
```

### 2.4 Provider 层修复

#### 2.4.1 统一 dispose 实现

**修复前**：
```dart
class SyncNotifier extends Notifier<SyncState> {
  StreamSubscription? _subscription;

  void dispose() {  // 不会被自动调用
    _subscription?.cancel();
  }
}
```

**修复后**：
```dart
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    final subscription = _setupSubscription();
    ref.onDispose(() {
      subscription.cancel();
    });
    return SyncState.initial();
  }
}
```

## 3. 迁移策略

### 3.1 DateTime 序列化迁移

为保持向后兼容，反序列化时同时支持两种格式：

```dart
DateTime _parseDateTime(dynamic value) {
  if (value is int) {
    // 旧格式：毫秒时间戳
    return DateTime.fromMillisecondsSinceEpoch(value);
  } else if (value is String) {
    // 新格式：ISO 8601
    return DateTime.parse(value);
  }
  throw FormatException('Invalid DateTime format: $value');
}
```

### 3.2 Enum 序列化迁移

```dart
T _parseEnum<T extends Enum>(dynamic value, List<T> values, T defaultValue) {
  if (value is int && value < values.length) {
    // 旧格式：index
    return values[value];
  } else if (value is String) {
    // 新格式：name
    return values.firstWhere(
      (e) => e.name == value,
      orElse: () => defaultValue,
    );
  }
  return defaultValue;
}
```

## 4. 测试策略

### 4.1 序列化测试

为每个模型添加序列化往返测试：

```dart
test('Model serialization roundtrip', () {
  final original = Model(...);
  final map = original.toMap();
  final restored = Model.fromMap(map);
  expect(restored, equals(original));
});
```

### 4.2 迁移兼容性测试

测试旧格式数据能正确解析：

```dart
test('Parse legacy DateTime format', () {
  final map = {'createdAt': 1704067200000};  // 旧格式
  final model = Model.fromMap(map);
  expect(model.createdAt, equals(DateTime(2024, 1, 1)));
});
```

## 5. 影响分析

| 组件 | 影响程度 | 需要修改的文件数 |
|------|---------|----------------|
| Models | 高 | 15+ |
| Services | 高 | 10+ |
| Providers | 中 | 20+ |
| Pages | 低 | 5 |
| Tests | 中 | 需新增/修改 |
