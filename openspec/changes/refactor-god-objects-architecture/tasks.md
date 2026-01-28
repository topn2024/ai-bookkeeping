# 任务清单

## Phase 1: Repository Pattern 和基础重构（第1-4周）

### 1.1 创建 Repository 基础设施（第1周）
- [ ] **任务1.1.1**: 创建 `IRepository<T, ID>` 基础接口
  - 文件: `lib/domain/repositories/i_repository.dart`
  - 验证: 接口定义清晰，包含基本 CRUD 方法
  - 依赖: 无

- [ ] **任务1.1.2**: 创建 `ITransactionRepository` 接口
  - 文件: `lib/domain/repositories/i_transaction_repository.dart`
  - 验证: 继承 `IRepository`，包含交易特定查询方法
  - 依赖: 任务1.1.1

- [ ] **任务1.1.3**: 实现 `TransactionRepository`
  - 文件: `lib/infrastructure/database/repositories/transaction_repository.dart`
  - 验证: 实现所有接口方法，通过单元测试
  - 依赖: 任务1.1.2

- [ ] **任务1.1.4**: 为 `TransactionRepository` 添加单元测试
  - 文件: `test/infrastructure/database/repositories/transaction_repository_test.dart`
  - 验证: 测试覆盖率>80%，所有测试通过
  - 依赖: 任务1.1.3

### 1.2 创建其他核心 Repository（第2周）
- [ ] **任务1.2.1**: 创建 `IAccountRepository` 和实现
  - 文件: `lib/domain/repositories/i_account_repository.dart`, `lib/infrastructure/database/repositories/account_repository.dart`
  - 验证: 接口和实现完整，单元测试通过
  - 依赖: 任务1.1.1
  - 可并行: 与任务1.2.2-1.2.5

- [ ] **任务1.2.2**: 创建 `ICategoryRepository` 和实现
  - 文件: `lib/domain/repositories/i_category_repository.dart`, `lib/infrastructure/database/repositories/category_repository.dart`
  - 验证: 接口和实现完整，单元测试通过
  - 依赖: 任务1.1.1
  - 可并行: 与任务1.2.1, 1.2.3-1.2.5

- [ ] **任务1.2.3**: 创建 `ILedgerRepository` 和实现
  - 文件: `lib/domain/repositories/i_ledger_repository.dart`, `lib/infrastructure/database/repositories/ledger_repository.dart`
  - 验证: 接口和实现完整，单元测试通过
  - 依赖: 任务1.1.1
  - 可并行: 与任务1.2.1-1.2.2, 1.2.4-1.2.5

- [ ] **任务1.2.4**: 创建 `IBudgetRepository` 和实现
  - 文件: `lib/domain/repositories/i_budget_repository.dart`, `lib/infrastructure/database/repositories/budget_repository.dart`
  - 验证: 接口和实现完整，单元测试通过
  - 依赖: 任务1.1.1
  - 可并行: 与任务1.2.1-1.2.3, 1.2.5

- [ ] **任务1.2.5**: 创建 `ITemplateRepository` 和实现
  - 文件: `lib/domain/repositories/i_template_repository.dart`, `lib/infrastructure/database/repositories/template_repository.dart`
  - 验证: 接口和实现完整，单元测试通过
  - 依赖: 任务1.1.1
  - 可并行: 与任务1.2.1-1.2.4

### 1.3 创建 Coordinator 基础架构（第3周）
- [ ] **任务1.3.1**: 创建 `VoiceRecognitionCoordinator`
  - 文件: `lib/application/coordinators/voice_recognition_coordinator.dart`
  - 验证: 职责单一，行数<300，单元测试通过
  - 依赖: 无

- [ ] **任务1.3.2**: 创建 `IntentProcessingCoordinator`
  - 文件: `lib/application/coordinators/intent_processing_coordinator.dart`
  - 验证: 职责单一，行数<300，单元测试通过
  - 依赖: 无

- [ ] **任务1.3.3**: 创建 `TransactionOperationCoordinator`
  - 文件: `lib/application/coordinators/transaction_operation_coordinator.dart`
  - 验证: 使用 Repository 接口，行数<300，单元测试通过
  - 依赖: 任务1.1.3, 1.2.1, 1.2.2

- [ ] **任务1.3.4**: 创建 `NavigationCoordinator`
  - 文件: `lib/application/coordinators/navigation_coordinator.dart`
  - 验证: 职责单一，行数<200，单元测试通过
  - 依赖: 无

- [ ] **任务1.3.5**: 创建 `ConversationCoordinator`
  - 文件: `lib/application/coordinators/conversation_coordinator.dart`
  - 验证: 职责单一，行数<300，单元测试通过
  - 依赖: 无

- [ ] **任务1.3.6**: 创建 `FeedbackCoordinator`
  - 文件: `lib/application/coordinators/feedback_coordinator.dart`
  - 验证: 职责单一，行数<200，单元测试通过
  - 依赖: 无

### 1.4 重构主 VoiceServiceCoordinator（第4周）
- [ ] **任务1.4.1**: 创建新的 `VoiceServiceCoordinator` 作为编排器
  - 文件: `lib/application/coordinators/voice_service_coordinator.dart`
  - 验证: 仅负责编排，行数<300，依赖6个子协调器
  - 依赖: 任务1.3.1-1.3.6

- [ ] **任务1.4.2**: 实现 Feature Flag 控制
  - 文件: `lib/core/feature_flags.dart`
  - 验证: 可以在新旧实现之间切换
  - 依赖: 任务1.4.1

- [ ] **任务1.4.3**: 创建 `VoiceServiceFacade` 统一入口
  - 文件: `lib/application/facades/voice_service_facade.dart`
  - 验证: 根据 Feature Flag 路由到新旧实现
  - 依赖: 任务1.4.2

- [ ] **任务1.4.4**: 更新 Riverpod Provider
  - 文件: `lib/providers/voice_service_provider.dart`
  - 验证: 所有依赖正确注入，Provider 可用
  - 依赖: 任务1.4.3

- [ ] **任务1.4.5**: 集成测试 - 交易操作流程
  - 文件: `test/integration/voice_transaction_flow_test.dart`
  - 验证: 端到端测试通过，新旧实现结果一致
  - 依赖: 任务1.4.4

## Phase 2: 完整迁移和清理（第5-8周）

### 2.1 迁移剩余 Repository（第5周）
- [ ] **任务2.1.1**: 创建剩余10+个 Repository 接口和实现
  - 包括: RecurringTransaction, CreditCard, SavingsGoal, BillReminder, Investment, Debt, Member, Import, ResourcePool, Vault, Learning
  - 验证: 每个 Repository 有完整测试
  - 依赖: 任务1.1.1
  - 可并行: 多个 Repository 可同时开发

- [ ] **任务2.1.2**: 创建 `RepositoryFactory`
  - 文件: `lib/infrastructure/database/repository_factory.dart`
  - 验证: 可以创建所有 Repository 实例
  - 依赖: 任务2.1.1

- [ ] **任务2.1.3**: 更新 `DatabaseService` 为轻量级初始化服务
  - 文件: `lib/infrastructure/database/database_service.dart`
  - 验证: 仅负责数据库初始化和迁移，行数<500
  - 依赖: 任务2.1.2

### 2.2 重构 GlobalVoiceAssistantManager（第6周）
- [ ] **任务2.2.1**: 创建 `AudioRecordingManager`
  - 文件: `lib/application/managers/audio_recording_manager.dart`
  - 验证: 职责单一，行数<300
  - 依赖: 无

- [ ] **任务2.2.2**: 创建 `VADManager`
  - 文件: `lib/application/managers/vad_manager.dart`
  - 验证: 职责单一，行数<300
  - 依赖: 无

- [ ] **任务2.2.3**: 创建 `BargeInManager`
  - 文件: `lib/application/managers/barge_in_manager.dart`
  - 验证: 职责单一，行数<200
  - 依赖: 无

- [ ] **任务2.2.4**: 创建 `ConversationHistoryManager`
  - 文件: `lib/application/managers/conversation_history_manager.dart`
  - 验证: 职责单一，行数<300
  - 依赖: 无

- [ ] **任务2.2.5**: 创建 `TTSManager`
  - 文件: `lib/application/managers/tts_manager.dart`
  - 验证: 职责单一，行数<300
  - 依赖: 无

- [ ] **任务2.2.6**: 创建 `PipelineManager`
  - 文件: `lib/application/managers/pipeline_manager.dart`
  - 验证: 职责单一，行数<300
  - 依赖: 无

- [ ] **任务2.2.7**: 创建 `NetworkStatusManager`
  - 文件: `lib/application/managers/network_status_manager.dart`
  - 验证: 职责单一，行数<200
  - 依赖: 无

- [ ] **任务2.2.8**: 重构 `GlobalVoiceAssistantManager` 为 Facade
  - 文件: `lib/application/facades/global_voice_assistant_manager.dart`
  - 验证: 仅作为 Facade，行数<300，依赖7个 Manager
  - 依赖: 任务2.2.1-2.2.7

### 2.3 提取 SmartIntentRecognizer 配置（第7周）
- [ ] **任务2.3.1**: 创建 `IntentRecognitionConfig` 类
  - 文件: `lib/domain/config/intent_recognition_config.dart`
  - 验证: 包含分类关键词、prompt 模板、规则配置
  - 依赖: 无

- [ ] **任务2.3.2**: 创建 YAML 配置文件
  - 文件: `assets/config/intent_recognition.yaml`
  - 验证: 包含所有分类映射和 prompt 模板
  - 依赖: 任务2.3.1

- [ ] **任务2.3.3**: 实现配置加载器
  - 文件: `lib/infrastructure/config/config_loader.dart`
  - 验证: 可以从 YAML 加载配置
  - 依赖: 任务2.3.2

- [ ] **任务2.3.4**: 重构 `SmartIntentRecognizer` 使用配置
  - 文件: `lib/services/voice/smart_intent_recognizer.dart`
  - 验证: Prompt 从配置加载，行数<500
  - 依赖: 任务2.3.3

### 2.4 清理和文档（第8周）
- [ ] **任务2.4.1**: 移除旧的 `VoiceServiceCoordinator` 实现
  - 验证: 所有引用已更新，旧代码已删除
  - 依赖: Phase 1 和 Phase 2 所有任务完成

- [ ] **任务2.4.2**: 移除旧的 `DatabaseService` 实现
  - 验证: 所有引用已更新，旧代码已删除
  - 依赖: 任务2.1.3

- [ ] **任务2.4.3**: 移除 Feature Flags
  - 验证: 仅使用新实现，Feature Flag 代码已删除
  - 依赖: 任务2.4.1, 2.4.2

- [ ] **任务2.4.4**: 更新架构文档
  - 文件: `docs/architecture/README.md`
  - 验证: 文档反映新架构，包含图表和示例
  - 依赖: 任务2.4.3

- [ ] **任务2.4.5**: 创建迁移指南
  - 文件: `docs/migration/god-objects-refactoring.md`
  - 验证: 包含详细的迁移步骤和最佳实践
  - 依赖: 任务2.4.4

## Phase 3: 高级模式和优化（第9-12周）

### 3.1 实现 Command Pattern（第9周）
- [ ] **任务3.1.1**: 创建 `IntentCommand` 基类
  - 文件: `lib/domain/commands/intent_command.dart`
  - 验证: 定义 execute() 接口
  - 依赖: 无

- [ ] **任务3.1.2**: 实现具体 Command 类
  - 包括: AddTransactionCommand, DeleteTransactionCommand, ModifyTransactionCommand, NavigateCommand, QueryCommand
  - 验证: 每个 Command 职责单一，可测试
  - 依赖: 任务3.1.1

- [ ] **任务3.1.3**: 创建 `CommandFactory`
  - 文件: `lib/application/factories/command_factory.dart`
  - 验证: 根据 Intent 创建对应 Command
  - 依赖: 任务3.1.2

- [ ] **任务3.1.4**: 更新 Coordinator 使用 Command Pattern
  - 验证: Coordinator 通过 Command 执行操作
  - 依赖: 任务3.1.3

### 3.2 实现 Event-Driven Architecture（第10周）
- [ ] **任务3.2.1**: 创建 `DomainEvent` 基类
  - 文件: `lib/domain/events/domain_event.dart`
  - 验证: 包含时间戳和事件元数据
  - 依赖: 无

- [ ] **任务3.2.2**: 定义具体 Domain Events
  - 包括: TransactionCreatedEvent, TransactionUpdatedEvent, TransactionDeletedEvent, BudgetExceededEvent
  - 验证: 每个事件包含必要数据
  - 依赖: 任务3.2.1

- [ ] **任务3.2.3**: 创建 `EventBus`
  - 文件: `lib/infrastructure/events/event_bus.dart`
  - 验证: 支持发布/订阅模式
  - 依赖: 任务3.2.2

- [ ] **任务3.2.4**: 在 Repository 中发布事件
  - 验证: CRUD 操作后发布对应事件
  - 依赖: 任务3.2.3

- [ ] **任务3.2.5**: 创建事件处理器
  - 包括: BudgetAlertHandler, StatisticsUpdateHandler, LearningUpdateHandler
  - 验证: 事件处理器正确响应事件
  - 依赖: 任务3.2.4

### 3.3 性能优化和测试（第11-12周）
- [ ] **任务3.3.1**: 性能基准测试
  - 文件: `test/performance/benchmark_test.dart`
  - 验证: 关键操作性能符合要求
  - 依赖: Phase 1-2 完成

- [ ] **任务3.3.2**: 内存泄漏检测
  - 验证: 无内存泄漏，资源正确释放
  - 依赖: 任务3.3.1

- [ ] **任务3.3.3**: 集成测试覆盖
  - 文件: `test/integration/`
  - 验证: 核心流程有集成测试覆盖
  - 依赖: Phase 1-2 完成

- [ ] **任务3.3.4**: 单元测试覆盖率提升
  - 验证: 整体覆盖率>80%
  - 依赖: Phase 1-2 完成

- [ ] **任务3.3.5**: 代码质量检查
  - 验证: 所有 lint 警告解决，代码符合规范
  - 依赖: Phase 1-3 所有任务完成

## 验证检查清单

### Phase 1 完成标准
- [ ] VoiceServiceCoordinator 拆分为6个协调器，每个<300行
- [ ] 核心 Repository (Transaction, Account, Category, Ledger, Budget) 实现完成
- [ ] 所有新代码有单元测试，覆盖率>70%
- [ ] Feature Flag 可以在新旧实现间切换
- [ ] 集成测试通过，功能无回归

### Phase 2 完成标准
- [ ] 所有 Repository 实现完成（15+个）
- [ ] DatabaseService 重构为轻量级服务，<500行
- [ ] GlobalVoiceAssistantManager 重构为 Facade，<300行
- [ ] SmartIntentRecognizer 配置外部化，<500行
- [ ] 单元测试覆盖率>75%
- [ ] 旧代码已清理

### Phase 3 完成标准
- [ ] Command Pattern 实现
- [ ] Event-Driven Architecture 就绪
- [ ] 单元测试覆盖率>80%
- [ ] 性能基准测试通过
- [ ] 集成测试覆盖核心流程
- [ ] 文档完整

## 依赖关系图

```
Phase 1
├── 1.1 Repository 基础 (Week 1)
│   └── 1.2 核心 Repository (Week 2)
│       └── 1.3 Coordinator 基础 (Week 3)
│           └── 1.4 主 Coordinator 重构 (Week 4)
│
Phase 2
├── 2.1 剩余 Repository (Week 5)
│   └── 2.3 配置提取 (Week 7)
├── 2.2 Manager 拆分 (Week 6)
└── 2.4 清理文档 (Week 8)
    │
Phase 3
├── 3.1 Command Pattern (Week 9)
├── 3.2 Event-Driven (Week 10)
└── 3.3 优化测试 (Week 11-12)
```

## 并行工作机会

**Week 2**: 任务1.2.1-1.2.5 可并行开发（5个 Repository）
**Week 3**: 任务1.3.1-1.3.6 可并行开发（6个 Coordinator）
**Week 5**: 任务2.1.1 中的多个 Repository 可并行开发
**Week 6**: 任务2.2.1-2.2.7 可并行开发（7个 Manager）
**Week 9**: 任务3.1.2 中的多个 Command 可并行开发
**Week 10**: 任务3.2.2 中的多个 Event 可并行开发
