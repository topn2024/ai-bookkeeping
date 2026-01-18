# 组件解耦能力规范

> **能力ID**: component-decoupling
> **变更ID**: upgrade-voice-intelligence-engine
> **依赖**: multi-operation-recognition, dual-channel-processing, intelligent-aggregation, adaptive-conversation

## 新增需求

### 需求：定义 OperationAdapter 接口

**优先级**: P0
**关联能力**: dual-channel-processing

必须定义 OperationAdapter 接口，解耦核心引擎和业务操作执行逻辑。

#### 场景：定义标准接口

**前置条件**:
- 无

**输入**: 接口定义需求

**预期输出**:
```dart
abstract class OperationAdapter {
  Future<ExecutionResult> execute(Operation operation);
  bool canHandle(OperationType type);
  String get adapterName;
}
```

**验收标准**:
- 接口包含 execute() 方法
- 接口包含 canHandle() 方法
- 接口包含 adapterName 属性
- 接口文档完整

#### 场景：实现 BookkeepingOperationAdapter

**前置条件**:
- OperationAdapter 接口已定义

**输入**: 记账业务需求

**预期输出**:
```dart
class BookkeepingOperationAdapter implements OperationAdapter {
  @override
  Future<ExecutionResult> execute(Operation operation) async {
    switch (operation.type) {
      case OperationType.addTransaction:
        return await _addTransaction(operation.params);
      case OperationType.query:
        return await _query(operation.params);
      case OperationType.navigate:
        return await _navigate(operation.params);
      default:
        return ExecutionResult.unsupported();
    }
  }

  @override
  bool canHandle(OperationType type) {
    return [
      OperationType.addTransaction,
      OperationType.query,
      OperationType.navigate,
      OperationType.delete,
      OperationType.modify,
    ].contains(type);
  }

  @override
  String get adapterName => 'BookkeepingOperationAdapter';
}
```

**验收标准**:
- 实现所有接口方法
- 支持 5 种操作类型
- 与现有服务集成（DatabaseService、VoiceNavigationService）

#### 场景：适配器正确处理不支持的操作

**前置条件**:
- BookkeepingOperationAdapter 已实现

**输入**: 不支持的操作类型（shopping）

**预期行为**:
- canHandle() 返回 false
- execute() 返回 ExecutionResult.unsupported()
- 不抛出异常

**验收标准**:
- 不支持的操作不阻塞系统
- 返回明确的不支持结果
- 错误信息清晰

### 需求：定义 FeedbackAdapter 接口

**优先级**: P0
**关联能力**: adaptive-conversation

必须定义 FeedbackAdapter 接口，解耦核心引擎和业务反馈生成逻辑。

#### 场景：定义标准接口

**前置条件**:
- 无

**输入**: 接口定义需求

**预期输出**:
```dart
abstract class FeedbackAdapter {
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  );
  bool supportsMode(ConversationMode mode);
  String get adapterName;
}
```

**验收标准**:
- 接口包含 generateFeedback() 方法
- 接口包含 supportsMode() 方法
- 接口包含 adapterName 属性
- 接口文档完整

#### 场景：实现 BookkeepingFeedbackAdapter

**前置条件**:
- FeedbackAdapter 接口已定义

**输入**: 记账业务需求

**预期输出**:
```dart
class BookkeepingFeedbackAdapter implements FeedbackAdapter {
  @override
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  ) async {
    switch (mode) {
      case ConversationMode.chat:
        return await _generateChatFeedback(chatContent);
      case ConversationMode.chatWithIntent:
        return await _generateDetailedFeedback(results, chatContent);
      case ConversationMode.quickBookkeeping:
        return _generateQuickFeedback(results);
      case ConversationMode.mixed:
        return await _generateMixedFeedback(results, chatContent);
    }
  }

  @override
  bool supportsMode(ConversationMode mode) {
    return true; // 支持所有模式
  }

  @override
  String get adapterName => 'BookkeepingFeedbackAdapter';
}
```

**验收标准**:
- 实现所有接口方法
- 支持 4 种对话模式
- 与 LLMResponseGenerator 集成

#### 场景：适配器根据模式生成不同风格反馈

**前置条件**:
- BookkeepingFeedbackAdapter 已实现

**输入**:
- 模式: quickBookkeeping
- 结果: 2 笔记账成功

**预期输出**: "✓ 2笔"

**验收标准**:
- 反馈风格符合模式
- 反馈长度符合要求
- 反馈内容准确

### 需求：IntelligenceEngine 支持适配器注入

**优先级**: P0
**关联能力**: 无

IntelligenceEngine 必须支持通过构造函数注入适配器，实现依赖倒置。

#### 场景：通过构造函数注入适配器

**前置条件**:
- OperationAdapter 和 FeedbackAdapter 接口已定义

**输入**: 创建 IntelligenceEngine 实例

**预期输出**:
```dart
final engine = IntelligenceEngine(
  operationAdapter: BookkeepingOperationAdapter(
    databaseService: databaseService,
    navigationService: navigationService,
  ),
  feedbackAdapter: BookkeepingFeedbackAdapter(
    llmGenerator: llmGenerator,
  ),
);
```

**验收标准**:
- 构造函数接受适配器参数
- 适配器可替换
- 不依赖具体实现

#### 场景：适配器为空时抛出异常

**前置条件**:
- IntelligenceEngine 已定义

**输入**: 创建 IntelligenceEngine 实例，operationAdapter 为 null

**预期行为**:
- 构造函数抛出 ArgumentError
- 错误信息: "operationAdapter cannot be null"
- 不创建实例

**验收标准**:
- 参数验证正确
- 错误信息清晰
- 不允许空适配器

#### 场景：运行时替换适配器

**前置条件**:
- IntelligenceEngine 已创建

**输入**: 调用 setOperationAdapter() 方法

**预期行为**:
- 替换现有适配器
- 新适配器立即生效
- 不影响正在执行的操作

**验收标准**:
- 适配器可动态替换
- 替换不影响稳定性
- 线程安全

### 需求：支持多适配器注册

**优先级**: P1
**关联能力**: 无

IntelligenceEngine 必须支持注册多个适配器，根据操作类型自动选择。

#### 场景：注册多个 OperationAdapter

**前置条件**:
- IntelligenceEngine 已创建

**输入**:
- 注册 BookkeepingOperationAdapter
- 注册 ShoppingOperationAdapter

**预期行为**:
- 两个适配器都注册成功
- 根据 canHandle() 自动选择适配器
- 记账操作使用 BookkeepingOperationAdapter
- 购物操作使用 ShoppingOperationAdapter

**验收标准**:
- 支持多适配器注册
- 自动选择逻辑正确
- 不冲突

#### 场景：没有适配器支持操作时返回错误

**前置条件**:
- IntelligenceEngine 已创建
- 只注册了 BookkeepingOperationAdapter

**输入**: 购物操作（shopping）

**预期行为**:
- 遍历所有适配器
- 没有适配器 canHandle() 返回 true
- 返回 ExecutionResult.unsupported()
- 记录警告日志

**验收标准**:
- 不支持的操作不阻塞系统
- 返回明确的错误
- 日志记录完整

### 需求：适配器支持单元测试

**优先级**: P0
**关联能力**: 无

适配器接口必须易于 mock，支持单元测试。

#### 场景：使用 MockOperationAdapter 测试

**前置条件**:
- OperationAdapter 接口已定义

**输入**: 创建 MockOperationAdapter

**预期输出**:
```dart
class MockOperationAdapter implements OperationAdapter {
  @override
  Future<ExecutionResult> execute(Operation operation) async {
    return ExecutionResult.success(data: {'mock': true});
  }

  @override
  bool canHandle(OperationType type) => true;

  @override
  String get adapterName => 'MockOperationAdapter';
}

// 测试代码
final engine = IntelligenceEngine(
  operationAdapter: MockOperationAdapter(),
  feedbackAdapter: MockFeedbackAdapter(),
);
```

**验收标准**:
- 接口易于 mock
- 测试代码简洁
- 不依赖真实服务

#### 场景：使用 MockFeedbackAdapter 测试

**前置条件**:
- FeedbackAdapter 接口已定义

**输入**: 创建 MockFeedbackAdapter

**预期输出**:
```dart
class MockFeedbackAdapter implements FeedbackAdapter {
  @override
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  ) async {
    return 'Mock feedback';
  }

  @override
  bool supportsMode(ConversationMode mode) => true;

  @override
  String get adapterName => 'MockFeedbackAdapter';
}
```

**验收标准**:
- 接口易于 mock
- 测试代码简洁
- 不依赖 LLM 服务

### 需求：适配器支持扩展到其他应用

**优先级**: P1
**关联能力**: 无

适配器模式必须支持快速扩展到其他应用场景。

#### 场景：添加购物助手适配器

**前置条件**:
- OperationAdapter 和 FeedbackAdapter 接口已定义

**输入**: 购物助手业务需求

**预期输出**:
```dart
class ShoppingOperationAdapter implements OperationAdapter {
  @override
  Future<ExecutionResult> execute(Operation operation) async {
    switch (operation.type) {
      case OperationType.addToCart:
        return await _addToCart(operation.params);
      case OperationType.searchProduct:
        return await _searchProduct(operation.params);
      default:
        return ExecutionResult.unsupported();
    }
  }

  @override
  bool canHandle(OperationType type) {
    return [
      OperationType.addToCart,
      OperationType.searchProduct,
    ].contains(type);
  }

  @override
  String get adapterName => 'ShoppingOperationAdapter';
}
```

**验收标准**:
- 新适配器实现简单
- 不修改核心引擎代码
- 可独立测试

#### 场景：添加旅行助手适配器

**前置条件**:
- OperationAdapter 和 FeedbackAdapter 接口已定义

**输入**: 旅行助手业务需求

**预期输出**:
```dart
class TravelOperationAdapter implements OperationAdapter {
  @override
  Future<ExecutionResult> execute(Operation operation) async {
    switch (operation.type) {
      case OperationType.bookFlight:
        return await _bookFlight(operation.params);
      case OperationType.searchHotel:
        return await _searchHotel(operation.params);
      default:
        return ExecutionResult.unsupported();
    }
  }

  @override
  bool canHandle(OperationType type) {
    return [
      OperationType.bookFlight,
      OperationType.searchHotel,
    ].contains(type);
  }

  @override
  String get adapterName => 'TravelOperationAdapter';
}
```

**验收标准**:
- 新适配器实现简单
- 不修改核心引擎代码
- 可独立测试

## 修改需求

### 需求：扩展 OperationType 枚举支持自定义类型

**优先级**: P1
**关联能力**: 无

OperationType 枚举必须支持业务自定义操作类型。

#### 场景：添加购物相关操作类型

**前置条件**:
- OperationType 枚举已定义

**输入**: 购物业务需求

**预期输出**:
```dart
enum OperationType {
  // 记账相关
  addTransaction,
  query,
  navigate,
  delete,
  modify,

  // 购物相关
  addToCart,
  searchProduct,
  checkout,

  // 旅行相关
  bookFlight,
  searchHotel,
}
```

**验收标准**:
- 枚举可扩展
- 不影响现有类型
- 类型命名清晰

#### 场景：自定义操作类型不冲突

**前置条件**:
- OperationType 枚举已扩展

**输入**: 同时使用记账和购物操作

**预期行为**:
- 记账操作使用 BookkeepingOperationAdapter
- 购物操作使用 ShoppingOperationAdapter
- 两者不冲突

**验收标准**:
- 操作类型不冲突
- 适配器选择正确
- 执行结果准确

## 性能要求

- 适配器选择延迟：< 10ms
- 适配器执行延迟：取决于业务逻辑
- 适配器注册延迟：< 5ms
- Mock 适配器执行延迟：< 1ms

## 安全要求

- 适配器参数验证
- 不允许空适配器
- 适配器执行超时保护（5s）
- 适配器异常隔离

## 兼容性要求

- 保持现有业务逻辑不变
- 适配器接口向后兼容
- 支持逐步迁移到适配器模式
