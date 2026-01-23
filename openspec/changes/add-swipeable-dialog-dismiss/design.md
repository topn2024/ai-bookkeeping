# 设计文档：对话框滑动关闭

## 上下文

项目中已有多种滑动手势实现可供参考：
- `SwipeableTransactionItem`：使用 `GestureDetector` + `AnimationController` 实现水平滑动
- `EdgeSwipeBackDetector`：边缘滑动检测，提供可视化反馈
- `BatchTransactionConfirmWidget`：使用 Flutter 原生 `Dismissible` 组件

对话框类型：
- `showDialog`：中心弹出的对话框，不支持滑动关闭
- `showModalBottomSheet`：底部弹出，已支持下滑关闭

## 目标 / 非目标

**目标：**
- 为 Dialog 添加滑动关闭能力
- 保持与现有对话框 API 兼容
- 提供流畅的动画和触觉反馈
- 支持配置滑动方向（水平/垂直/双向）

**非目标：**
- 不改变 ModalBottomSheet 的行为（已支持滑动关闭）
- 不强制所有对话框都支持滑动关闭（可选配置）
- 不改变对话框的视觉样式

## 决策

### 实现方案：GestureDetector + AnimationController

**选择原因：**
- 与项目现有 `SwipeableTransactionItem` 模式一致
- 完全控制动画和手势行为
- 可以实现复杂的滑动阈值和回弹逻辑

**考虑的替代方案：**

| 方案 | 优点 | 缺点 |
|------|------|------|
| Dismissible 组件 | 开箱即用 | 难以自定义动画，主要用于列表项 |
| PageRouteBuilder | 支持页面级滑动 | Dialog 不是页面路由 |
| GestureDetector | 完全可控 | 需要自己实现动画逻辑 |

### 组件设计

```
SwipeableDismissDialog
├── GestureDetector (手势检测)
│   ├── onHorizontalDragStart/Update/End (水平模式)
│   └── onPanStart/Update/End (双向模式)
├── AnimatedBuilder (动画构建)
│   ├── Transform.translate (位移)
│   └── Opacity (透明度)
└── child (实际对话框内容)
```

### 关键参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| dismissThreshold | 100.0 dp | 触发关闭的滑动距离 |
| animationDuration | 200 ms | 动画时长（与现有组件一致） |
| enableHapticFeedback | true | 是否启用触觉反馈 |
| direction | horizontal | 滑动方向：horizontal/vertical/both |

### 滑动逻辑

1. **开始滑动**：记录起始位置，触发 lightImpact 反馈
2. **滑动中**：
   - 位移 = 手指移动距离
   - 透明度 = 1.0 - (|位移| / dismissThreshold * 0.5)
3. **结束滑动**：
   - 如果 |位移| >= dismissThreshold：触发关闭动画 + mediumImpact 反馈
   - 否则：回弹动画回到原位

## 风险 / 权衡

| 风险 | 缓解措施 |
|------|----------|
| 与对话框内容的手势冲突 | 只在对话框边缘区域检测滑动，或使用 behavior: HitTestBehavior.translucent |
| 用户误触导致关闭 | 设置合理的 dismissThreshold（100dp） |
| 动画性能 | 使用 AnimatedBuilder 而非 setState，避免重建 |

## 迁移计划

1. 创建独立的 `SwipeableDismissDialog` 组件
2. 为 `ConfirmationDialog` 添加可选参数 `enableSwipeDismiss`
3. 默认不启用，需要显式开启
4. 后续可根据用户反馈决定是否默认启用

## 待决问题

- 是否需要支持取消滑动（滑动过程中手指移回原位）？ → 建议支持，回弹动画
- 危险操作对话框是否应该禁用滑动关闭？ → 建议提供配置选项
