# 提案：重构重复代码

## 概述

本提案旨在系统性地解决代码库中发现的重复和冗余代码问题，通过提取公共基类、统一服务接口、引入设计模式来提高代码可维护性和减少代码量。

## 动机

代码审计发现以下主要问题：

1. **本地化服务完全重复** - `AccountLocalizationService` 和 `CategoryLocalizationService` 有 ~70% 相同代码
2. **预算服务重叠** - 5个预算相关服务存在相似逻辑和重复的模型定义
3. **对话框组件重复** - 8个确认对话框共享相同的结构模式
4. **语音操作服务重复** - `VoiceModifyService` 和 `VoiceDeleteService` 结构几乎相同
5. **模型序列化样板** - 35个模型有重复的 `copyWith`、`toMap`、`fromMap` 代码
6. **货币格式化分散** - 格式化逻辑散布在多个位置

## 目标

- **减少代码重复率** - 目标减少 3000+ 行重复代码
- **提高可维护性** - 修改一处即可影响所有相关功能
- **统一代码风格** - 建立一致的设计模式
- **保持向后兼容** - 现有 API 和功能不受影响

## 非目标

- 不改变现有功能行为
- 不引入新的外部依赖（除 Freezed 可选）
- 不重构页面层代码（本次仅关注服务层和组件层）

## 范围

### 包含

| 模块 | 改动 | 预计减少代码 |
|------|------|-------------|
| 本地化服务 | 提取 `BaseLocalizationService` | ~200 行 |
| 对话框组件 | 创建 `BaseConfirmationDialog` | ~400 行 |
| 预算服务 | 统一 `BudgetSuggestion` 模型 | ~300 行 |
| 语音服务 | 提取 `BaseVoiceOperationService` | ~150 行 |
| 货币格式化 | 统一 `CurrencyFormatter` | ~100 行 |

### 不包含

- 模型层 Freezed 代码生成（作为后续提案）
- 页面层重复代码
- 学习服务架构重组

## 设计概要

详见 [design.md](./design.md)

### 核心改动

1. **泛型本地化基类** - `BaseLocalizationService<T>` 处理 locale 管理
2. **对话框构建器模式** - `ConfirmationDialogBuilder` 统一对话框创建
3. **预算建议引擎** - `BudgetSuggestionEngine` 核心计算逻辑
4. **语音操作基类** - `BaseVoiceOperationService` 管理会话和历史
5. **统一格式化服务** - `FormattingService` 整合所有格式化逻辑

## 风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 重构引入 bug | 中 | 保持完整测试覆盖，逐步迁移 |
| 打破现有 API | 高 | 保留原有公共接口，内部调用基类 |
| 合并冲突 | 低 | 在功能冻结期执行 |

## 验收标准

- [ ] `flutter analyze` 无新增 warning
- [ ] 所有现有测试通过
- [ ] 代码行数减少 ≥1000 行
- [ ] 无功能回归

## 时间线

- Phase 1: 本地化服务 + 货币格式化（基础设施）
- Phase 2: 对话框组件重构
- Phase 3: 语音服务基类
- Phase 4: 预算服务整合

## 相关提案

- `fix-app-code-quality` - 代码质量修复（已完成部分）
