# 变更：为对话框添加滑动关闭手势支持

## 为什么

当前应用中的对话框（Dialog）不支持滑动手势关闭，用户只能通过点击按钮或点击遮罩来关闭对话框。这与现代移动端交互习惯不符，尤其是 iOS 用户已经习惯了滑动返回的交互方式。添加滑动关闭手势可以提升用户体验的流畅度和自然感。

## 变更内容

- 创建 `SwipeableDismissDialog` 组件，支持水平或垂直滑动关闭对话框
- 为现有的 `ConfirmationDialog` 添加可选的滑动关闭支持
- 滑动过程中提供视觉反馈（透明度变化 + 位移动画）
- 触发关闭时提供触觉反馈
- 保持与现有对话框 API 的兼容性

## 影响

- 受影响规范：gesture-interaction（新增）
- 受影响代码：
  - `lib/widgets/dialogs/swipeable_dismiss_dialog.dart`（新建）
  - `lib/widgets/dialogs/confirmation_dialog.dart`（修改）
