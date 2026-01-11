# 规范：对话框组件框架

## 新增需求

### 需求：统一确认对话框组件

系统**必须**提供一个可配置的 `ConfirmationDialog` 组件，支持多种确认场景。

#### 场景：显示基础确认对话框

**Given** 用户触发需要确认的操作
**When** 调用 `ConfirmationDialog.show(context, title: '确认', message: '...')`
**Then** 应显示包含标题、消息和确认/取消按钮的对话框
**And** 点击确认应返回 true
**And** 点击取消应返回 false

#### 场景：显示危险操作对话框

**Given** 用户触发危险操作（如删除）
**When** 调用 `ConfirmationDialog.showDangerous(context, title: '删除', message: '...')`
**Then** 确认按钮应显示为红色
**And** 应有警告图标

#### 场景：显示带自定义内容的对话框

**Given** 需要在对话框中显示复杂内容
**When** 调用 `ConfirmationDialog.showWithContent<T>(context, content: widget)`
**Then** 应在对话框中央显示自定义 Widget
**And** 确认后应返回泛型结果

#### 场景：适配深色主题

**Given** 系统启用深色主题
**When** 显示确认对话框
**Then** 对话框应使用深色背景和浅色文字

---

## 技术约束

- 组件位于 `lib/widgets/dialogs/confirmation_dialog.dart`
- 使用 `showDialog` 而非 `showModalBottomSheet`
- 支持无障碍访问（语义标签）
- 动画时长 200ms
