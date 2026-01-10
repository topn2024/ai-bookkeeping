# 错误处理规范

## 新增需求

### 需求：禁止使用 async void 模式

除 Flutter 框架要求的回调外，禁止使用 `async void` 方法签名。必须确保所有异步错误都能被正确捕获和处理。

#### 场景：事件处理回调中的异步操作

**给定** 一个需要执行异步操作的事件回调方法
**当** 定义该方法时
**那么** 方法签名应该保持 `void` 返回类型（不加 `async`）
**并且** 内部异步调用应该使用 `unawaited()` 包装
**并且** 必须添加 `.catchError()` 处理潜在错误

**正确示例**：
```dart
void _onConnectivityChanged(List<ConnectivityResult> results) {
  if (shouldSync) {
    unawaited(
      processQueue().catchError((e) {
        _logger.error('Sync failed', error: e);
      }),
    );
  }
}
```

**错误示例**：
```dart
void _onConnectivityChanged(List<ConnectivityResult> results) async {
  await processQueue();  // 错误不会被捕获
}
```

---

### 需求：FutureProvider 必须处理错误状态

所有 FutureProvider 的消费者必须正确处理 loading、data 和 error 三种状态。

#### 场景：FutureProvider 错误处理

**给定** 一个使用 FutureProvider 的 Widget
**当** Provider 处于 error 状态时
**那么** Widget 必须显示适当的错误 UI
**并且** 应该提供重试机制

**示例**：
```dart
ref.watch(dataProvider).when(
  loading: () => LoadingIndicator(),
  data: (data) => DataView(data),
  error: (error, stack) => ErrorView(
    error: error,
    onRetry: () => ref.invalidate(dataProvider),
  ),
);
```

---

### 需求：服务层方法必须有统一的错误处理

服务层的公共方法必须捕获并适当处理或转换异常。

#### 场景：服务方法错误处理

**给定** 一个服务层的公共异步方法
**当** 内部操作抛出异常时
**那么** 应该记录错误日志
**并且** 应该抛出或返回应用级异常（而非底层异常）

**示例**：
```dart
Future<List<Transaction>> getTransactions() async {
  try {
    return await _db.query('transactions');
  } catch (e, stackTrace) {
    _logger.error('Failed to get transactions', error: e, stackTrace: stackTrace);
    throw DataAccessException('Unable to load transactions', cause: e);
  }
}
```

---

### 需求：空值安全必须正确处理

禁止对可能为 null 的值使用强制解包（`!`）操作符，除非有明确的前置条件检查。

#### 场景：禁止无保护的强制解包

**给定** 一个可空类型的变量
**当** 需要使用该变量的非空值时
**那么** 必须先进行空值检查
**或者** 使用空值合并操作符提供默认值

**正确示例**：
```dart
// 方式1：空值检查
if (value != null) {
  Text(value)
}

// 方式2：空值合并
Text(value ?? 'default')

// 方式3：条件访问
Text(value?.toString() ?? '')
```

**错误示例**：
```dart
Text(value!)  // 危险：如果 value 为 null 会崩溃
```

---

## 修改需求

### 需求：异常类型必须具体化

必须修改现有使用通用 `Exception` 的代码，改为使用具体的异常类型。禁止使用 `throw Exception('message')` 这种通用形式。

#### 场景：使用具体异常类型

**给定** 需要抛出异常的场景
**当** 创建异常对象时
**那么** 应该使用或创建具体的异常类（如 `NetworkException`、`DataAccessException`）
**而非** 使用通用的 `Exception('message')`

**正确示例**：
```dart
throw NetworkException(
  message: 'Server returned ${response.statusCode}',
  statusCode: response.statusCode,
);
```

**错误示例**：
```dart
throw Exception('Server returned ${response.statusCode}');
```
