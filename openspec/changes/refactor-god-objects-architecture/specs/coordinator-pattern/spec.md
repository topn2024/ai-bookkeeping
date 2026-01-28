# 规范：Coordinator Pattern 实现

## 新增需求

### 需求：VoiceRecognitionCoordinator
**ID**: `coordinator-pattern.voice-recognition`
**优先级**: P0
**状态**: 提案中

系统应提供专门的语音识别协调器，负责语音识别生命周期管理。

#### 场景：创建 VoiceRecognitionCoordinator
**前置条件**:
- VoiceRecognitionEngine 可用
- SmartIntentRecognizer 可用

**操作**:
1. 创建 `VoiceRecognitionCoordinator` 类
2. 实现语音识别流程管理
3. 处理识别结果

**预期结果**:
- 协调器职责单一
- 代码行数<300
- 有完整单元测试

**示例代码**:
```dart
class VoiceRecognitionCoordinator {
  final VoiceRecognitionEngine _engine;
  final SmartIntentRecognizer _recognizer;

  VoiceRecognitionCoordinator({
    required VoiceRecognitionEngine engine,
    required SmartIntentRecognizer recognizer,
  })  : _engine = engine,
        _recognizer = recognizer;

  Future<RecognitionResult> recognize(String input) async {
    // 1. 使用识别引擎处理输入
    final engineResult = await _engine.recognize(input);

    // 2. 使用智能识别器分析意图
    final intentResult = await _recognizer.recognize(engineResult.text);

    return RecognitionResult(
      text: engineResult.text,
      intent: intentResult,
      confidence: intentResult.confidence,
    );
  }

  Future<void> startListening() async {
    await _engine.startListening();
  }

  Future<void> stopListening() async {
    await _engine.stopListening();
  }
}
```

---

### 需求：IntentProcessingCoordinator
**ID**: `coordinator-pattern.intent-processing`
**优先级**: P0
**状态**: 提案中

系统应提供意图处理协调器，负责意图分析、路由和消歧。

#### 场景：创建 IntentProcessingCoordinator
**前置条件**:
- VoiceIntentRouter 可用
- EntityDisambiguationService 可用

**操作**:
1. 创建 `IntentProcessingCoordinator` 类
2. 实现意图处理流程
3. 处理多意图和消歧

**预期结果**:
- 协调器职责单一
- 代码行数<300
- 有完整单元测试

**示例代码**:
```dart
class IntentProcessingCoordinator {
  final VoiceIntentRouter _router;
  final EntityDisambiguationService _disambiguation;
  final AIIntentDecomposer _decomposer;

  IntentProcessingCoordinator({
    required VoiceIntentRouter router,
    required EntityDisambiguationService disambiguation,
    required AIIntentDecomposer decomposer,
  })  : _router = router,
        _disambiguation = disambiguation,
        _decomposer = decomposer;

  Future<ProcessedIntent> process(RecognitionResult result) async {
    // 1. 路由意图
    final routedIntent = await _router.route(result.intent);

    // 2. 检查是否需要消歧
    if (routedIntent.needsDisambiguation) {
      final disambiguated = await _disambiguation.disambiguate(
        routedIntent,
      );
      return ProcessedIntent.fromDisambiguated(disambiguated);
    }

    // 3. 检查是否是多意图
    if (routedIntent.isMultiIntent) {
      final decomposed = await _decomposer.decompose(routedIntent);
      return ProcessedIntent.fromMulti(decomposed);
    }

    return ProcessedIntent.fromSingle(routedIntent);
  }
}
```

---

### 需求：TransactionOperationCoordinator
**ID**: `coordinator-pattern.transaction-operation`
**优先级**: P0
**状态**: 提案中
**依赖**: `repository-pattern.transaction-repository`

系统应提供交易操作协调器，负责所有交易相关的 CRUD 操作。

#### 场景：创建 TransactionOperationCoordinator
**前置条件**:
- ITransactionRepository 可用
- ICategoryRepository 可用
- IAccountRepository 可用

**操作**:
1. 创建 `TransactionOperationCoordinator` 类
2. 实现交易 CRUD 操作
3. 处理交易验证和业务规则

**预期结果**:
- 协调器职责单一
- 代码行数<300
- 使用 Repository 接口
- 有完整单元测试

**示例代码**:
```dart
class TransactionOperationCoordinator {
  final ITransactionRepository _transactionRepo;
  final ICategoryRepository _categoryRepo;
  final IAccountRepository _accountRepo;

  TransactionOperationCoordinator({
    required ITransactionRepository transactionRepo,
    required ICategoryRepository categoryRepo,
    required IAccountRepository accountRepo,
  })  : _transactionRepo = transactionRepo,
        _categoryRepo = categoryRepo,
        _accountRepo = accountRepo;

  Future<VoiceSessionResult> addTransaction(Intent intent) async {
    // 1. 验证分类
    final category = await _categoryRepo.getById(intent.category);
    if (category == null) {
      return VoiceSessionResult.error('分类不存在');
    }

    // 2. 验证账户
    final account = await _accountRepo.getById(intent.accountId);
    if (account == null) {
      return VoiceSessionResult.error('账户不存在');
    }

    // 3. 创建交易
    final transaction = Transaction(
      amount: intent.amount,
      category: intent.category,
      account: intent.accountId,
      date: DateTime.now(),
    );

    // 4. 保存交易
    final id = await _transactionRepo.insert(transaction);

    return VoiceSessionResult.success(
      '已添加交易',
      {'transactionId': id},
    );
  }

  Future<VoiceSessionResult> deleteTransaction(Intent intent) async {
    // 删除逻辑...
  }

  Future<VoiceSessionResult> modifyTransaction(Intent intent) async {
    // 修改逻辑...
  }

  Future<VoiceSessionResult> queryTransactions(Intent intent) async {
    // 查询逻辑...
  }
}
```

---

### 需求：NavigationCoordinator
**ID**: `coordinator-pattern.navigation`
**优先级**: P0
**状态**: 提案中

系统应提供导航协调器，负责页面导航操作。

#### 场景：创建 NavigationCoordinator
**前置条件**:
- VoiceNavigationService 可用

**操作**:
1. 创建 `NavigationCoordinator` 类
2. 实现导航操作

**预期结果**:
- 协调器职责单一
- 代码行数<200
- 有完整单元测试

**示例代码**:
```dart
class NavigationCoordinator {
  final VoiceNavigationService _navigationService;

  NavigationCoordinator({
    required VoiceNavigationService navigationService,
  }) : _navigationService = navigationService;

  Future<VoiceSessionResult> handle(Intent intent) async {
    final result = await _navigationService.navigate(
      targetPage: intent.targetPage,
      params: intent.params,
    );

    if (result.success) {
      return VoiceSessionResult.success('已打开${intent.targetPage}');
    } else {
      return VoiceSessionResult.error('导航失败: ${result.error}');
    }
  }
}
```

---

### 需求：ConversationCoordinator
**ID**: `coordinator-pattern.conversation`
**优先级**: P0
**状态**: 提案中

系统应提供对话协调器，负责对话管理和聊天功能。

#### 场景：创建 ConversationCoordinator
**前置条件**:
- ConversationContext 可用
- CasualChatService 可用

**操作**:
1. 创建 `ConversationCoordinator` 类
2. 实现对话管理

**预期结果**:
- 协调器职责单一
- 代码行数<300
- 有完整单元测试

**示例代码**:
```dart
class ConversationCoordinator {
  final ConversationContext _context;
  final CasualChatService _chatService;

  ConversationCoordinator({
    required ConversationContext context,
    required CasualChatService chatService,
  })  : _context = context,
        _chatService = chatService;

  Future<VoiceSessionResult> handle(Intent intent) async {
    // 1. 更新对话上下文
    _context.addUserMessage(intent.originalText);

    // 2. 生成回复
    final response = await _chatService.generateResponse(
      input: intent.originalText,
      context: _context,
    );

    // 3. 更新上下文
    _context.addAssistantMessage(response);

    return VoiceSessionResult.success(response);
  }
}
```

---

### 需求：FeedbackCoordinator
**ID**: `coordinator-pattern.feedback`
**优先级**: P0
**状态**: 提案中

系统应提供反馈协调器，负责语音反馈和 TTS。

#### 场景：创建 FeedbackCoordinator
**前置条件**:
- VoiceFeedbackSystem 可用
- TTSService 可用

**操作**:
1. 创建 `FeedbackCoordinator` 类
2. 实现反馈管理

**预期结果**:
- 协调器职责单一
- 代码行数<200
- 有完整单元测试

**示例代码**:
```dart
class FeedbackCoordinator {
  final VoiceFeedbackSystem _feedbackSystem;
  final TTSService _ttsService;

  FeedbackCoordinator({
    required VoiceFeedbackSystem feedbackSystem,
    required TTSService ttsService,
  })  : _feedbackSystem = feedbackSystem,
        _ttsService = ttsService;

  Future<void> provideFeedback(VoiceSessionResult result) async {
    // 1. 生成反馈消息
    final message = _generateMessage(result);

    // 2. 提供视觉反馈
    await _feedbackSystem.provideFeedback(
      message: message,
      type: _getFeedbackType(result),
    );

    // 3. 提供语音反馈
    await _ttsService.speak(message);
  }

  String _generateMessage(VoiceSessionResult result) {
    if (result.isSuccess) {
      return result.message;
    } else {
      return '操作失败: ${result.message}';
    }
  }

  VoiceFeedbackType _getFeedbackType(VoiceSessionResult result) {
    return result.isSuccess
        ? VoiceFeedbackType.success
        : VoiceFeedbackType.error;
  }
}
```

---

## 修改需求

### 需求：重构 VoiceServiceCoordinator 为编排器
**ID**: `coordinator-pattern.refactor-main-coordinator`
**优先级**: P0
**状态**: 提案中
**依赖**: `coordinator-pattern.voice-recognition`, `coordinator-pattern.intent-processing`, `coordinator-pattern.transaction-operation`, `coordinator-pattern.navigation`, `coordinator-pattern.conversation`, `coordinator-pattern.feedback`

VoiceServiceCoordinator 应该从 God Object 重构为仅负责编排的轻量级协调器。

#### 场景：重构主协调器
**前置条件**:
- 所有子协调器已实现

**操作**:
1. 创建新的 `VoiceServiceCoordinator` 类
2. 注入所有子协调器
3. 实现编排逻辑

**预期结果**:
- 主协调器行数<300
- 职责单一：仅负责编排
- 依赖数<7（6个子协调器）
- 有完整单元测试

**示例代码**:
```dart
class VoiceServiceCoordinator extends ChangeNotifier {
  final VoiceRecognitionCoordinator _recognitionCoordinator;
  final IntentProcessingCoordinator _intentCoordinator;
  final TransactionOperationCoordinator _transactionCoordinator;
  final NavigationCoordinator _navigationCoordinator;
  final ConversationCoordinator _conversationCoordinator;
  final FeedbackCoordinator _feedbackCoordinator;

  VoiceServiceCoordinator({
    required VoiceRecognitionCoordinator recognitionCoordinator,
    required IntentProcessingCoordinator intentCoordinator,
    required TransactionOperationCoordinator transactionCoordinator,
    required NavigationCoordinator navigationCoordinator,
    required ConversationCoordinator conversationCoordinator,
    required FeedbackCoordinator feedbackCoordinator,
  })  : _recognitionCoordinator = recognitionCoordinator,
        _intentCoordinator = intentCoordinator,
        _transactionCoordinator = transactionCoordinator,
        _navigationCoordinator = navigationCoordinator,
        _conversationCoordinator = conversationCoordinator,
        _feedbackCoordinator = feedbackCoordinator;

  Future<VoiceSessionResult> processVoiceCommand(String input) async {
    try {
      // 1. 识别
      final recognition = await _recognitionCoordinator.recognize(input);

      // 2. 处理意图
      final intent = await _intentCoordinator.process(recognition);

      // 3. 路由到具体协调器
      final result = await _routeToCoordinator(intent);

      // 4. 提供反馈
      await _feedbackCoordinator.provideFeedback(result);

      return result;
    } catch (e) {
      final errorResult = VoiceSessionResult.error('处理失败: $e');
      await _feedbackCoordinator.provideFeedback(errorResult);
      return errorResult;
    }
  }

  Future<VoiceSessionResult> _routeToCoordinator(
    ProcessedIntent intent,
  ) async {
    switch (intent.type) {
      case IntentType.transaction:
        return await _transactionCoordinator.handle(intent);
      case IntentType.navigation:
        return await _navigationCoordinator.handle(intent);
      case IntentType.conversation:
        return await _conversationCoordinator.handle(intent);
      default:
        return VoiceSessionResult.error('未知意图类型');
    }
  }
}
```

---

## 测试需求

### 需求：Coordinator 单元测试
**ID**: `coordinator-pattern.unit-tests`
**优先级**: P0
**状态**: 提案中

所有 Coordinator 必须有完整的单元测试覆盖。

#### 场景：TransactionOperationCoordinator 单元测试
**前置条件**:
- TransactionOperationCoordinator 已实现

**操作**:
1. 创建测试文件
2. Mock 所有依赖
3. 测试所有方法

**预期结果**:
- 测试覆盖率>80%
- 所有测试通过
- 使用 Mock 隔离依赖

**示例代码**:
```dart
void main() {
  late MockTransactionRepository mockTransactionRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockAccountRepository mockAccountRepo;
  late TransactionOperationCoordinator coordinator;

  setUp(() {
    mockTransactionRepo = MockTransactionRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockAccountRepo = MockAccountRepository();

    coordinator = TransactionOperationCoordinator(
      transactionRepo: mockTransactionRepo,
      categoryRepo: mockCategoryRepo,
      accountRepo: mockAccountRepo,
    );
  });

  group('TransactionOperationCoordinator', () {
    test('addTransaction should create transaction successfully', () async {
      // Arrange
      final intent = Intent(
        amount: 100.0,
        category: 'food',
        accountId: 'account1',
      );

      when(() => mockCategoryRepo.getById('food'))
          .thenAnswer((_) async => Category(id: 'food', name: '餐饮'));
      when(() => mockAccountRepo.getById('account1'))
          .thenAnswer((_) async => Account(id: 'account1', name: '现金'));
      when(() => mockTransactionRepo.insert(any()))
          .thenAnswer((_) async => 'transaction1');

      // Act
      final result = await coordinator.addTransaction(intent);

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockTransactionRepo.insert(any())).called(1);
    });

    // ... 更多测试
  });
}
```

---

## 非功能需求

### 需求：代码质量
**ID**: `coordinator-pattern.code-quality`
**优先级**: P1
**状态**: 提案中

Coordinator 代码应符合质量标准。

#### 场景：代码质量检查
**前置条件**:
- Coordinator 实现完成

**操作**:
1. 检查代码行数
2. 检查依赖数量
3. 检查测试覆盖率

**预期结果**:
- 每个 Coordinator <300行
- 依赖数<5
- 测试覆盖率>80%
- 无 lint 错误

---

## 交叉引用

- 依赖规范: `repository-pattern`
- 被依赖规范: `clean-architecture`
- 相关规范: `voice-assistant`
