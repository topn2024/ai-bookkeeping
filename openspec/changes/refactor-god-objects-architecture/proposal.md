# 变更提案：架构重构 - 拆分 God Objects 并引入清晰分层

## 变更ID
`refactor-god-objects-architecture`

## 概述
对当前语音服务系统和数据库服务进行系统性架构重构，解决 God Object 反模式、SOLID 原则违反、紧耦合等严重架构问题，引入清晰的分层架构和职责分离。

## 动机

### 当前架构存在的严重问题

#### 1. God Object 反模式（最严重）

**VoiceServiceCoordinator.dart (4,645行 - 2026-01-29更新)**
- 违反单一职责原则，承担15+种不同职责
- 30+个处理方法，31个依赖注入
- 职责包括：语音识别、意图路由、实体消歧、交易CRUD、导航、自动化、预算查询、建议生成、聊天管理、TTS协调、会话超时、打断检测、网络监控、学习服务集成等
- **近期新增职责**（2026-01-29）：
  - 对话式金额补充（_pendingAmountIntent）
  - 对话式分类补充（_pendingCategoryIntent）
  - 备注提取和分类推断
  - TTS消息记录到聊天历史
- **增长趋势**：提案创建以来增长582行（+14%），证明重构紧迫性

**DatabaseService.dart (4,448行)**
- 196个异步方法，管理20+种不同实体类型
- 无职责分离：交易、账户、分类、账本、预算、模板、循环交易、信用卡、储蓄目标、账单提醒、投资、债务、成员、导入、资源池、小金库、学习记录等全部混在一起
- SQL schema 管理、迁移逻辑、CRUD 操作混合

**GlobalVoiceAssistantManager.dart (2,782行)**
- 87+个字段管理过多状态
- 28个异步方法，多重职责
- 管理：权限、录音、VAD、打断、流式ASR、连续模式、主动对话、TTS、管道控制、网络监控、音频处理、对话历史、偏好设置、LLM集成等

**SmartIntentRecognizer.dart (2,482行)**
- 500+行 LLM prompt 硬编码在代码中
- 意图识别、LLM交互、规则回退、学习缓存、网络状态检查混合
- 业务逻辑（分类映射、关键词列表）嵌入在 prompt 中

#### 2. SOLID 原则严重违反

**单一职责原则 (SRP)**
- VoiceServiceCoordinator 有10+个变更原因
- DatabaseService 任何实体模型变更都需要修改此类

**开闭原则 (OCP)**
- 添加新意图类型需要修改 switch 语句
- 添加新实体需要修改 DatabaseService

**接口隔离原则 (ISP)**
- IDatabaseService 有196个方法，客户端被迫依赖不需要的方法

**依赖倒置原则 (DIP)**
- 混用抽象接口和具体类
- Service Locator 模式创建隐藏依赖

#### 3. 其他架构问题

- **紧耦合**：直接访问单例 (GlobalVoiceAssistantManager.instance)
- **状态管理混乱**：32个服务扩展 ChangeNotifier，状态重复
- **Service Locator 滥用**：隐藏依赖，难以测试
- **业务逻辑与基础设施混合**：数据库服务包含业务规则
- **测试困难**：God Objects 无法有效单元测试

## 目标

### 短期目标（Phase 1: 4周）
- 将 VoiceServiceCoordinator 拆分为6个独立协调器
- 将 DatabaseService 拆分为独立的 Repository 模式
- 移除关键路径上的 Service Locator
- 为所有主要服务添加接口抽象

### 中期目标（Phase 2: 4周）
- 实现清晰的分层架构（Domain/Application/Infrastructure）
- 重构 GlobalVoiceAssistantManager
- 提取 SmartIntentRecognizer 配置
- 添加全面的单元测试

### 长期目标（Phase 3: 4周）
- 实现 Command 模式处理意图
- 引入事件驱动架构
- 在适当场景实现 CQRS
- 添加集成测试

### 质量指标（2026-01-29 更新）

| 指标 | 提案时 | 当前值 | 目标值 | 优先级 | 趋势 |
|------|--------|--------|--------|--------|------|
| VoiceServiceCoordinator LOC | 4,063 | **4,645** | <300 | P0 | 📈+14% |
| DatabaseService LOC | 4,448 | 4,448 | <200/repo | P0 | ➡️ |
| GlobalVoiceAssistantManager LOC | 2,782 | **2,813** | <500 | P1 | 📈+1% |
| SmartIntentRecognizer LOC | 2,482 | **2,496** | <500 | P1 | 📈+0.5% |
| 每类依赖数 | 17+ | 17+ | <5 | P0 | ➡️ |
| 每类方法数 | 196 | 196 | <20 | P0 | ➡️ |
| 单元测试覆盖率 | 未知 | 未知 | >80% | P1 | ⚠️ |
| 循环依赖 | 高风险 | 高风险 | 0 | P0 | ➡️ |

## 核心设计原则

### 1. 单一职责原则
每个类只有一个变更原因，职责清晰

### 2. 依赖倒置
高层模块不依赖低层模块，都依赖抽象

### 3. 接口隔离
客户端不应被迫依赖不使用的接口

### 4. 开闭原则
对扩展开放，对修改关闭

### 5. 清晰分层
Domain → Application → Infrastructure → Presentation

## 受影响规范
- `voice-assistant` (重构)
- `database-service` (重构)
- `voice-recognition` (重构)
- `intent-processing` (新建)
- `repository-pattern` (新建)
- `clean-architecture` (新建)

## 复用现有模块

| 模块 | 文件 | 复用方式 |
|------|------|---------|
| Pipeline系统 | `lib/services/voice/pipeline/` | 保持不变，已经设计良好 |
| Adapter模式 | `lib/services/voice/adapters/` | 保持不变 |
| Intelligence Engine | `lib/services/voice/intelligence_engine/` | 保持不变 |
| Memory系统 | `lib/services/voice/memory/` | 保持不变 |
| 实体模型 | `lib/models/` | 保持不变 |

## 新增组件架构

### Phase 1: 拆分 God Objects

#### VoiceServiceCoordinator 拆分
```
VoiceServiceCoordinator (仅编排，<300行)
├── VoiceRecognitionCoordinator (语音识别生命周期)
├── IntentProcessingCoordinator (意图分析和路由)
├── TransactionOperationCoordinator (交易CRUD操作)
├── NavigationCoordinator (页面导航)
├── ConversationCoordinator (对话管理)
└── FeedbackCoordinator (反馈和TTS)
```

#### DatabaseService 拆分
```
DatabaseService (仅初始化和迁移，<500行)
├── ITransactionRepository (交易仓库接口)
│   └── TransactionRepository (实现)
├── IAccountRepository (账户仓库接口)
│   └── AccountRepository (实现)
├── ICategoryRepository (分类仓库接口)
│   └── CategoryRepository (实现)
├── ILedgerRepository (账本仓库接口)
│   └── LedgerRepository (实现)
├── IBudgetRepository (预算仓库接口)
│   └── BudgetRepository (实现)
└── ... (每个实体一个仓库)
```

#### GlobalVoiceAssistantManager 拆分
```
GlobalVoiceAssistantManager (仅 Facade，<300行)
├── AudioRecordingManager (录音管理)
├── VADManager (VAD管理)
├── BargeInManager (打断检测)
├── ConversationHistoryManager (对话历史)
├── TTSManager (TTS管理)
├── PipelineManager (管道控制)
└── NetworkStatusManager (网络状态)
```

### Phase 2: 清晰分层架构

```
lib/
├── domain/                    # 领域层
│   ├── entities/             # 领域实体
│   ├── repositories/         # 仓库接口
│   ├── value_objects/        # 值对象
│   └── use_cases/            # 用例
├── application/              # 应用层
│   ├── services/             # 应用服务
│   ├── coordinators/         # 协调器
│   └── dto/                  # 数据传输对象
├── infrastructure/           # 基础设施层
│   ├── database/             # 数据库实现
│   │   └── repositories/     # 仓库实现
│   ├── network/              # 网络服务
│   └── voice/                # 语音服务
└── presentation/             # 表现层
    ├── pages/                # 页面
    ├── widgets/              # 组件
    └── providers/            # 状态管理
```

### Phase 3: 高级模式

#### Command 模式
```dart
abstract class IntentCommand {
  Future<VoiceSessionResult> execute();
}

class AddTransactionCommand implements IntentCommand {
  final Transaction transaction;
  final ITransactionRepository repository;

  @override
  Future<VoiceSessionResult> execute() async {
    await repository.insert(transaction);
    return VoiceSessionResult.success('Transaction added');
  }
}
```

#### Event-Driven Architecture
```dart
abstract class DomainEvent {
  final DateTime occurredAt;
}

class TransactionCreatedEvent extends DomainEvent {
  final String transactionId;
  final double amount;
}

class EventBus {
  void publish(DomainEvent event);
  Stream<T> on<T extends DomainEvent>();
}
```

## 风险评估

### 高风险
- **大规模重构**：影响核心业务逻辑
- **回归风险**：现有功能可能受影响
- **学习曲线**：团队需要适应新架构

### 缓解措施
- **分阶段实施**：每个 Phase 独立可验证
- **并行开发**：新旧代码共存，逐步迁移
- **全面测试**：每个阶段完成后进行回归测试
- **文档先行**：详细设计文档和迁移指南
- **代码审查**：严格的 PR review 流程

## 成功标准

### Phase 1 完成标准
- [ ] VoiceServiceCoordinator 拆分为6个协调器，每个<300行
- [ ] DatabaseService 拆分为10+个 Repository，每个<200行
- [ ] 移除80%的 Service Locator 调用
- [ ] 所有新代码有单元测试
- [ ] 现有功能无回归

### Phase 2 完成标准
- [ ] 实现清晰的4层架构
- [ ] GlobalVoiceAssistantManager 重构完成
- [ ] SmartIntentRecognizer 配置外部化
- [ ] 单元测试覆盖率>60%

### Phase 3 完成标准
- [ ] Command 模式实现
- [ ] Event-Driven 架构就绪
- [ ] 单元测试覆盖率>80%
- [ ] 集成测试覆盖核心流程

## 时间线

- **Phase 1**: 第1-4周（关键重构）
- **Phase 2**: 第5-8周（架构优化）
- **Phase 3**: 第9-12周（高级模式）

## 依赖关系
- 无前置依赖
- 后续变更应基于新架构进行

## 备注
这是一个大规模的架构重构项目，需要团队充分理解和支持。建议在开始前进行架构评审会议，确保所有利益相关者对目标和方法达成共识。
