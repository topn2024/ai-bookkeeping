# 规范：语音操作基类

## 新增需求

### 需求：语音操作抽象接口

系统**必须**定义 `VoiceOperation` 抽象接口，支持撤销功能。

#### 场景：创建可撤销操作

**Given** 执行了一个语音修改命令
**When** 创建 `VoiceOperation` 实例
**Then** 应记录操作时间戳
**And** `canUndo` 应返回 true
**And** 调用 `undo()` 应恢复原状态

---

### 需求：语音操作服务基类

系统**必须**提供 `BaseVoiceOperationService<T>` 基类，封装会话管理和历史管理的通用实现。

#### 场景：开始语音会话

**Given** 用户进入语音输入模式
**When** 调用 `startSession(context)`
**Then** 应保存会话上下文
**And** 应清空历史记录

#### 场景：记录操作历史

**Given** 语音会话进行中
**When** 执行操作后调用 `addToHistory(operation)`
**Then** 操作应加入历史栈
**And** 历史栈最大保留 10 条

#### 场景：撤销最近操作

**Given** 历史栈有 2 条操作
**When** 调用 `undo()`
**Then** 应撤销最后一条操作
**And** 历史栈应只剩 1 条

#### 场景：历史栈为空时撤销

**Given** 历史栈为空
**When** 调用 `undo()`
**Then** 应安全返回，无操作

---

## 修改需求

### 需求：VoiceModifyService 继承基类

`VoiceModifyService` **必须**重构为继承 `BaseVoiceOperationService<ModifyOperation>`。

#### 场景：处理修改命令

**Given** 用户说"把刚才的金额改成 50"
**When** 调用 `processCommand(command)`
**Then** 应匹配修改模式
**And** 应执行修改并记录到历史

---

### 需求：VoiceDeleteService 继承基类

`VoiceDeleteService` **必须**重构为继承 `BaseVoiceOperationService<DeleteOperation>`。

#### 场景：处理删除命令

**Given** 用户说"删除刚才那笔"
**When** 调用 `processCommand(command)`
**Then** 应匹配删除模式
**And** 应执行删除并记录到历史

---

## 技术约束

- 基类位于 `lib/core/base/base_voice_operation_service.dart`
- 历史栈大小限制为常量 `maxHistorySize = 10`
- 操作类型定义在各自服务文件中
