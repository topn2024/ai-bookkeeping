# 任务列表：App 代码质量修复

## Phase 1: 严重问题修复 [Critical]

### 1.1 运行时崩溃修复
- [x] **P1-1** 修复 `enhanced_voice_assistant_page.dart` 第 496 行 `if (null != null)` 逻辑错误
- [x] **P1-2** 修复 `enhanced_voice_assistant_page.dart` 第 506 行 `null!` 强制解包崩溃
- [x] **P1-3** 验证修复后页面正常运行

### 1.2 内存泄漏修复
- [x] **P1-4** 修复 `crdt_sync_service.dart` 第 43-54 行未保存的 StreamSubscription
- [x] **P1-5** 添加 `_messageSubscription` 和 `_stateSubscription` 成员变量
- [x] **P1-6** 在 `dispose()` 中正确取消所有订阅
- [x] **P1-7** 检查并修复其他服务中类似的 Stream 泄漏问题（已修复 cloud_verification_service, multimodal_wakeup_service, family_offline_sync_service, source_file_sync_service）

### 1.3 安全漏洞修复
- [x] **P1-8** 修复 `http_service.dart` 第 171-179 行 SSL 验证配置（确认已正确实现）
- [x] **P1-9** 确保 refreshDio 实例与主 Dio 实例使用相同的安全配置（确认已正确实现）

### 1.4 async void 修复
- [x] **P1-10** 修复 `offline_queue_service.dart` 第 84 行 `async void` 反模式
- [x] **P1-11** 添加错误处理包装 `unawaited()` 和 `catchError()`
- [x] **P1-12** 检查并修复其他服务中类似的 async void 问题（已检查，无问题）

**验证点**: `flutter analyze` 无 error，应用启动无崩溃

---

## Phase 2: 模型层一致性 [High]

### 2.1 类名冲突解决
- [x] **P2-1** 重命名 `family_leaderboard.dart` 中的 `Achievement` 类为 `LeaderboardAchievement`
- [x] **P2-2** 更新所有引用该类的代码

### 2.2 补全缺失的序列化方法
- [x] **P2-3** 为 `RecurringTransaction` 添加 `toMap()` 方法（已存在）
- [x] **P2-4** 为 `RecurringTransaction` 添加 `fromMap()` 工厂构造函数（已存在）
- [x] **P2-5** 为 `TransactionTemplate` 添加 `toMap()` 方法（已存在）
- [x] **P2-6** 为 `TransactionTemplate` 添加 `fromMap()` 工厂构造函数（已存在）

### 2.3 DateTime 序列化统一
- [x] **P2-7** 创建 `parseDateTime()` 兼容性解析函数（在 common_types.dart 中）
- [x] **P2-8** 修复 `achievement.dart` 使用 `toIso8601String()` 替代 `millisecondsSinceEpoch`
- [x] **P2-9** 修复 `bill_reminder.dart` DateTime 序列化
- [x] **P2-10** 修复 `budget_vault.dart` DateTime 序列化
- [x] **P2-11** 检查并统一其他模型的 DateTime 序列化（parseDateTime() 提供向后兼容性）

### 2.4 Boolean 序列化统一
- [x] **P2-12** 确认所有 SQLite 存储使用 `0/1` 格式（已确认）
- [x] **P2-13** 确认所有 JSON/API 传输使用原生布尔值（已确认）
- [x] **P2-14** 修复 `expense_split.dart` Boolean 序列化不一致（已确认使用原生布尔值）
- [x] **P2-15** 修复 `family_dashboard.dart` Boolean 序列化不一致（已确认无问题）

### 2.5 Enum 序列化统一
- [x] **P2-16** 创建 `parseEnum<T>()` 兼容性解析函数（在 common_types.dart 中）
- [x] **P2-17** 修复 `family_dashboard.dart` Enum 序列化使用 `name` 而非 `index`
- [x] **P2-18** 修复 `achievement.dart` Enum 序列化
- [x] **P2-19** 修复 `family_savings_goal.dart` Enum 序列化

### 2.6 copyWith 方法完善
- [x] **P2-20** 修复 `family_savings_goal.dart` 第 282 行 `createdAt` 参数缺失

**验证点**: 所有模型序列化往返测试通过

---

## Phase 3: 服务层健壮性 [High]

### 3.1 单例模式规范化
- [x] **P3-1** 修复 `OfflineQueueService` 的单例实现，移除多实例构造
- [x] **P3-2** 添加 `configure()` 方法替代构造函数配置

### 3.2 数据库资源管理
- [x] **P3-3** 修复 `database_service.dart` 第 50-57 行异常时数据库未关闭问题
- [x] **P3-4** 使用 try-finally 确保资源释放

### 3.3 错误处理完善
- [x] **P3-5** 为 `cold_start_service.dart` 添加错误处理
- [ ] **P3-6** 统一异常类型，创建 `AppException` 层次结构
- [ ] **P3-7** 替换 `throw Exception()` 为具体异常类型

### 3.4 TODO 清理
- [ ] **P3-8** 完成 `location_trigger_service.dart` 的数据库操作 TODO
- [ ] **P3-9** 完成 `cold_start_service.dart` 的数据库操作 TODO
- [ ] **P3-10** 审查并处理其他 15 个服务 TODO

### 3.5 并发控制
- [ ] **P3-11** 为 `offline_queue_service.dart` 的 `processQueue()` 添加互斥锁
- [ ] **P3-12** 为 `server_sync_service.dart` 添加同步锁
- [ ] **P3-13** 为 `auto_sync_service.dart` 添加同步锁

### 3.6 HTTP 处理一致性
- [ ] **P3-14** 统一 HTTP 状态码检查逻辑
- [ ] **P3-15** 创建 `isSuccessStatus()` 辅助函数

**验证点**: 服务层无 `flutter analyze` 警告

---

## Phase 4: Provider 层规范化 [Medium]

### 4.1 dispose 实现统一
- [x] **P4-1** 修复 `sync_provider.dart` 使用 `ref.onDispose()` 替代 `dispose()` 方法
- [x] **P4-2** 修复 `budget_vault_provider.dart` 资源清理
- [ ] **P4-3** 检查并修复其他 15+ 个 Provider 的 dispose 实现

### 4.2 错误处理完善
- [ ] **P4-4** 为 `ai_provider.dart` FutureProvider 添加错误处理
- [ ] **P4-5** 为 `budget_provider.dart` 的 `categorySuggestionProvider` 添加错误处理
- [ ] **P4-6** 统一使用 `AsyncValue` 处理加载/错误状态

### 4.3 异步初始化修复
- [x] **P4-7** 修复 `auth_provider.dart` `Future.microtask()` 未捕获错误
- [x] **P4-8** 修复 `budget_vault_provider.dart` 异步初始化
- [x] **P4-9** 添加 `.catchError()` 处理初始化失败

### 4.4 服务实例管理
- [ ] **P4-10** 修复 `ai_provider.dart` 第 188 行重复创建 `AIService()` 实例
- [ ] **P4-11** 统一使用 `ref.read(serviceProvider)` 获取服务实例

### 4.5 ref 使用规范
- [ ] **P4-12** 修复 `budget_vault_provider.dart` 在异步方法中使用 `ref.read()` 的问题
- [ ] **P4-13** 改用 `ref.watch()` 或在 build 期间读取

**验证点**: Provider 层无内存泄漏警告

---

## Phase 5: 页面层关键修复 [Medium]

### 5.1 严重 Bug 修复
- [ ] **P5-1** 审查 `enhanced_voice_assistant_page.dart` 完整逻辑（与 P1-1, P1-2 相关）

### 5.2 关键 TODO 完成
- [x] **P5-2** 完成 `smart_feature_recommendation_page.dart` 功能启用逻辑
- [x] **P5-3** 完成 `voice_history_page.dart` 重新识别逻辑
- [x] **P5-4** 完成 `vault_overview_page.dart` 存入/取出对话框

**验证点**: 关键页面功能正常

---

## 验收标准

### 必须满足
- [x] `flutter analyze` 无 error（主代码无 error，仅 test 文件有预存问题）
- [ ] 现有测试全部通过
- [ ] 应用启动无崩溃
- [ ] 无新增内存泄漏

### 建议满足
- [ ] `flutter analyze` 警告数减少 50%
- [ ] 新增模型序列化测试覆盖
- [ ] 新增服务层关键方法测试

---

## 依赖关系

```
Phase 1 (Critical) ─────┬───> Phase 2 (Models)
                        │
                        └───> Phase 3 (Services) ───> Phase 4 (Providers)
                                                            │
                                                            v
                                                      Phase 5 (Pages)
```

- Phase 2 和 Phase 3 可以并行进行
- Phase 4 依赖 Phase 3 完成（服务层规范化后才能规范 Provider）
- Phase 5 依赖 Phase 4 完成

---

## 工作量估计

| 阶段 | 任务数 | 复杂度 |
|------|--------|--------|
| Phase 1 | 12 | 中 |
| Phase 2 | 20 | 中 |
| Phase 3 | 15 | 高 |
| Phase 4 | 13 | 中 |
| Phase 5 | 4 | 低 |
| **总计** | **64** | - |
