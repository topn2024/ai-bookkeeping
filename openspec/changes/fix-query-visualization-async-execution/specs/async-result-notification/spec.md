# 规范：异步结果通知机制

## 概述

本规范定义了语音查询系统中异步执行结果的通知机制，确保查询结果能够正确传递到 UI 层进行可视化展示。

## 新增需求

### 需求：ResultBuffer 监听器支持

**目标**：系统必须允许外部组件监听查询结果的完成事件

#### 场景：注册查询结果监听器

**前置条件**：
- 用户发起语音查询命令
- 系统生成唯一的 operationId

**操作**：
```dart
final operationId = 'query_${DateTime.now().millisecondsSinceEpoch}';

resultBuffer.addListener(operationId, (result) {
  // 处理查询结果
  if (result.status == ExecutionStatus.success) {
    final cardData = result.data?['cardData'];
    final chartData = result.data?['chartData'];
    // 更新 UI
  }
});
```

**预期结果**：
- 监听器成功注册
- 当查询完成时，监听器被调用
- 监听器接收到完整的查询结果

**验收标准**：
- [ ] `addListener()` 方法接受 operationId 和回调函数
- [ ] 监听器存储在内部 Map 中
- [ ] 支持同一 operationId 注册多个监听器

#### 场景：查询完成时通知监听器

**前置条件**：
- 监听器已注册
- 查询执行完成

**操作**：
```dart
// 在 BookkeepingOperationAdapter 中
final result = ExecutionResult.success(data: {
  'cardData': cardData,
  'chartData': chartData,
});

resultBuffer.storeResult(operationId, result);
```

**预期结果**：
- ResultBuffer 存储查询结果
- 所有注册的监听器被依次调用
- 监听器接收到正确的结果数据
- 监听器调用后自动清理

**验收标准**：
- [ ] `storeResult()` 方法触发监听器通知
- [ ] 所有监听器都被调用
- [ ] 监听器异常不影响其他监听器
- [ ] 通知后监听器自动移除

#### 场景：监听器超时清理

**前置条件**：
- 监听器已注册
- 30秒内查询未完成

**操作**：
```dart
// 注册监听器
resultBuffer.addListener(operationId, callback);

// 等待30秒
await Future.delayed(Duration(seconds: 30));

// 查询完成（超时后）
resultBuffer.storeResult(operationId, result);
```

**预期结果**：
- 监听器在30秒后自动清理
- 超时后的查询结果不触发监听器
- 日志记录超时清理事件

**验收标准**：
- [ ] 监听器注册时启动30秒定时器
- [ ] 定时器到期时自动移除监听器
- [ ] 超时清理记录日志
- [ ] 定时器在监听器触发后取消

### 需求：GlobalVoiceAssistantManager 元数据更新

**目标**：系统必须支持延迟更新聊天消息的元数据，用于添加可视化数据

#### 场景：更新最后一条助手消息的元数据

**前置条件**：
- 聊天历史中存在至少一条助手消息
- 查询结果包含 cardData 或 chartData

**操作**：
```dart
GlobalVoiceAssistantManager.instance.updateLastMessageMetadata({
  'cardData': {
    'type': 'CardType.percentage',
    'primaryValue': 2180.0,
    'percentage': 28.5,
  },
});
```

**预期结果**：
- 最后一条助手消息的 metadata 被更新
- UI 自动刷新显示可视化组件
- 原有 metadata 不被覆盖（合并模式）

**验收标准**：
- [ ] `updateLastMessageMetadata()` 方法查找最后一条助手消息
- [ ] 使用 `copyWith()` 创建新消息对象
- [ ] 新旧 metadata 合并
- [ ] 调用 `notifyListeners()` 触发 UI 更新
- [ ] 记录更新日志

#### 场景：未找到助手消息时的处理

**前置条件**：
- 聊天历史为空，或只有用户消息

**操作**：
```dart
GlobalVoiceAssistantManager.instance.updateLastMessageMetadata({
  'cardData': cardData,
});
```

**预期结果**：
- 方法安全返回，不抛出异常
- 记录警告日志
- 不触发 UI 更新

**验收标准**：
- [ ] `_findLastAssistantMessage()` 返回 null 时安全处理
- [ ] 记录警告日志："未找到助手消息，无法更新元数据"
- [ ] 不调用 `notifyListeners()`

### 需求：命令处理器集成

**目标**：系统必须在语音命令处理流程中集成监听器机制

#### 场景：处理查询命令时注册监听器

**前置条件**：
- 用户发起语音查询命令
- IntelligenceEngine 识别为查询意图

**操作**：
```dart
// 在 main.dart 的 _setupCommandProcessor() 中
final result = await coordinator.processVoiceCommand(command);

if (result.status == VoiceSessionStatus.success) {
  final operationId = result.data?['operationId'];
  if (operationId != null) {
    coordinator.resultBuffer.addListener(operationId, (queryResult) {
      _handleVisualizationData(queryResult);
    });
  }
}
```

**预期结果**：
- 监听器成功注册
- IntelligenceEngine 的响应立即返回给用户
- 查询在后台异步执行
- 查询完成后监听器被调用

**验收标准**：
- [ ] 从 result.data 中提取 operationId
- [ ] 注册监听器到 resultBuffer
- [ ] 监听器回调处理可视化数据
- [ ] 记录监听器注册日志

#### 场景：处理可视化数据

**前置条件**：
- 查询完成，监听器被调用
- 查询结果包含 cardData 或 chartData

**操作**：
```dart
void _handleVisualizationData(ExecutionResult result) {
  final cardData = result.data?['cardData'];
  final chartData = result.data?['chartData'];

  if (cardData != null || chartData != null) {
    GlobalVoiceAssistantManager.instance.updateLastMessageMetadata({
      if (cardData != null) 'cardData': cardData,
      if (chartData != null) 'chartData': chartData,
    });
  }
}
```

**预期结果**：
- 从查询结果中提取 cardData 和 chartData
- 调用 GlobalVoiceAssistantManager 更新元数据
- UI 自动刷新显示可视化组件

**验收标准**：
- [ ] 正确提取 cardData 和 chartData
- [ ] 只在有可视化数据时更新元数据
- [ ] 记录提取日志
- [ ] 异常情况下记录错误日志

## 技术约束

### 性能约束
- 监听器回调执行时间 < 100ms
- 监听器数量 < 100 个（同时）
- 超时清理时间 = 30秒

### 线程安全
- `updateLastMessageMetadata()` 使用 Lock 保护
- 监听器回调在主线程执行
- 异常隔离，单个监听器异常不影响其他监听器

### 内存管理
- 监听器超时自动清理
- 定期清理过期监听器（每5分钟）
- 监听器触发后立即移除

## 数据结构

### ResultListener 类型定义
```dart
typedef ResultListener = void Function(ExecutionResult result);
```

### ResultBuffer 扩展
```dart
class ResultBuffer {
  // 监听器存储
  final Map<String, List<ResultListener>> _listeners = {};

  // 超时定时器
  final Map<String, Timer> _timeouts = {};

  // 添加监听器
  void addListener(String operationId, ResultListener callback);

  // 移除监听器
  void removeListener(String operationId);

  // 通知监听器
  void notifyResult(String operationId, ExecutionResult result);

  // 存储结果（增强版）
  void storeResult(String operationId, ExecutionResult result);
}
```

### ChatMessage 扩展
```dart
class ChatMessage {
  final String id;
  final ChatMessageType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;  // ← 已存在

  // 添加 copyWith 方法
  ChatMessage copyWith({
    String? id,
    ChatMessageType? type,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  });
}
```

## 错误处理

### 监听器回调异常
```dart
void notifyResult(String operationId, ExecutionResult result) {
  final listeners = _listeners[operationId];
  if (listeners != null) {
    for (final listener in listeners) {
      try {
        listener(result);
      } catch (e, stackTrace) {
        debugPrint('[ResultBuffer] 监听器回调异常: $e');
        debugPrint('[ResultBuffer] 堆栈: $stackTrace');
        // 继续执行其他监听器
      }
    }
  }
  removeListener(operationId);
}
```

### 元数据更新失败
```dart
void updateLastMessageMetadata(Map<String, dynamic> metadata) {
  try {
    final lastMessage = _findLastAssistantMessage();
    if (lastMessage == null) {
      debugPrint('[GlobalVoiceAssistant] 未找到助手消息，无法更新元数据');
      return;
    }

    // 更新逻辑
    // ...

  } catch (e, stackTrace) {
    debugPrint('[GlobalVoiceAssistant] 更新元数据失败: $e');
    debugPrint('[GlobalVoiceAssistant] 堆栈: $stackTrace');
  }
}
```

## 日志规范

### 日志级别
- **DEBUG**：监听器注册、通知、清理
- **INFO**：元数据更新成功
- **WARN**：未找到助手消息
- **ERROR**：监听器回调异常、元数据更新失败

### 日志格式
```dart
debugPrint('[ResultBuffer] 注册监听器: operationId=$operationId');
debugPrint('[ResultBuffer] 通知监听器: operationId=$operationId, listenerCount=${listeners.length}');
debugPrint('[ResultBuffer] 监听器超时清理: operationId=$operationId');
debugPrint('[GlobalVoiceAssistant] 更新元数据: keys=${metadata.keys.join(", ")}');
```

## 测试要求

### 单元测试
- [ ] 监听器注册和移除
- [ ] 监听器通知
- [ ] 监听器超时清理
- [ ] 元数据更新
- [ ] 异常处理

### 集成测试
- [ ] 端到端查询流程
- [ ] 多个查询并发执行
- [ ] 监听器生命周期

### 性能测试
- [ ] 监听器回调性能
- [ ] 元数据更新性能
- [ ] 内存泄漏测试

## 依赖

### 内部依赖
- `ResultBuffer` (需要修改)
- `GlobalVoiceAssistantManager` (需要修改)
- `ExecutionResult` (现有)
- `ChatMessage` (需要添加 copyWith)

### 外部依赖
- `synchronized` 包 (用于线程安全)

## 向后兼容性

- 现有的 `resultBuffer.storeResult()` 调用保持兼容
- 不注册监听器时，行为与之前完全相同
- ChatMessage 的 metadata 字段已存在，只是增加更新方法

## 安全考虑

- 监听器回调不应执行耗时操作
- 监听器回调不应修改共享状态（除了 UI 更新）
- 超时机制防止内存泄漏
- 异常隔离防止级联失败
