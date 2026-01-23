# 实施任务清单

## 1. 核心组件实现

### 1.1 创建 SwipeableDismissDialog 组件
- [ ] 1.1.1 创建 `lib/widgets/dialogs/swipeable_dismiss_dialog.dart` 文件
- [ ] 1.1.2 实现 `SwipeableDismissDirection` 枚举（horizontal, vertical, both）
- [ ] 1.1.3 实现 `SwipeableDismissDialog` StatefulWidget
- [ ] 1.1.4 添加手势检测（GestureDetector）
- [ ] 1.1.5 实现位移和透明度动画
- [ ] 1.1.6 添加触觉反馈支持
- [ ] 1.1.7 实现回弹动画逻辑

### 1.2 添加静态便捷方法
- [ ] 1.2.1 添加 `SwipeableDismissDialog.show()` 静态方法
- [ ] 1.2.2 支持自定义 barrierDismissible 参数
- [ ] 1.2.3 支持返回值传递

## 2. 集成现有对话框

### 2.1 更新 ConfirmationDialog
- [ ] 2.1.1 添加 `enableSwipeDismiss` 参数（默认 false）
- [ ] 2.1.2 在 show 方法中集成 SwipeableDismissDialog
- [ ] 2.1.3 更新 showDangerous 方法（默认禁用滑动关闭）
- [ ] 2.1.4 更新 showWithContent 方法

## 3. 测试验证

### 3.1 单元测试
- [ ] 3.1.1 创建 `test/widgets/swipeable_dismiss_dialog_test.dart`
- [ ] 3.1.2 测试水平滑动关闭
- [ ] 3.1.3 测试滑动距离不足时的回弹
- [ ] 3.1.4 测试触觉反馈触发

### 3.2 手动测试
- [ ] 3.2.1 测试左右滑动关闭效果
- [ ] 3.2.2 测试滑动过程中的透明度变化
- [ ] 3.2.3 测试快速滑动场景
- [ ] 3.2.4 测试与对话框内容交互的兼容性

---

## 完成进度

| 分类 | 总计 | 已完成 | 待完成 |
|-----|------|-------|-------|
| 核心组件 | 10 | 0 | 10 |
| 集成 | 4 | 0 | 4 |
| 测试 | 7 | 0 | 7 |
| **总计** | **21** | **0** | **21** |
