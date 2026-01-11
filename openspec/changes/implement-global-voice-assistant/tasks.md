# 全局语音助手实现任务清单

## 阶段一：基础架构（必须先完成）

- [x] **1.1 创建 GlobalVoiceAssistantManager**
  - 文件：`lib/services/global_voice_assistant_manager.dart`
  - 单例模式管理全局状态
  - 整合现有 VoiceServiceCoordinator
  - 添加对话历史管理
  - 验证：Manager 可正常初始化和获取实例

- [x] **1.2 创建 Riverpod Providers**
  - 文件：`lib/providers/global_voice_assistant_provider.dart`
  - floatingBallStateProvider
  - floatingBallPositionProvider
  - floatingBallVisibilityProvider
  - conversationHistoryProvider
  - currentPageContextProvider
  - 验证：各 Provider 状态变更正确触发 UI 更新

- [x] **1.3 创建 VoiceContextService**
  - 文件：`lib/services/voice_context_service.dart`
  - PageContext 数据模型
  - PageContextType 枚举
  - 上下文增强逻辑
  - 验证：能根据页面类型正确增强意图理解

## 阶段二：悬浮球组件（核心交互）

- [x] **2.1 创建 GlobalFloatingBall Widget**
  - 文件：`lib/widgets/global_floating_ball.dart`
  - 使用 Stack + Positioned 实现（通过 MaterialApp builder）
  - 可拖动定位
  - 边缘吸附动画
  - 避让底部导航和 FAB 区域
  - 验证：悬浮球可拖动、吸附，不遮挡关键区域

- [x] **2.2 实现悬浮球状态视觉**
  - idle 状态：麦克风图标
  - recording 状态：波浪动画
  - processing 状态：加载动画
  - success 状态：勾号图标
  - error 状态：错误图标
  - 验证：各状态切换时视觉正确变化

- [x] **2.3 创建 WaveformAnimation 组件**
  - 文件：`lib/widgets/waveform_animation.dart`
  - CustomPainter 绘制波形
  - 支持真实音频振幅输入
  - 平滑动画过渡
  - 验证：录音时波形随语音变化

- [x] **2.4 实现 GlobalFloatingBallOverlay**
  - 文件：`lib/widgets/global_floating_ball.dart`（包含在同一文件）
  - 包装 GlobalFloatingBall
  - 处理 Overlay 生命周期
  - 集成到 MaterialApp builder
  - 验证：悬浮球在所有页面正确显示

## 阶段三：页面上下文感知（智能响应）

- [x] **3.1 创建 VoiceContextRouteObserver**
  - 文件：`lib/services/voice_context_route_observer.dart`
  - 继承 RouteObserver<PageRoute>
  - 监听页面 push/pop
  - 更新 currentPageContext
  - 验证：页面切换时上下文正确更新

- [x] **3.2 定义页面上下文数据**
  - 首页上下文：最近交易信息
  - 预算页上下文：当前预算分类和余额
  - 交易详情上下文：当前交易信息
  - 报表页上下文：当前时间范围
  - 验证：各页面能提供正确的上下文数据
  - 注：基础数据结构已在 VoiceContextService 中定义

- [x] **3.3 实现上下文感知响应**
  - 修改 VoiceIntentRouter
  - 根据上下文调整意图解析
  - 生成上下文相关的响应
  - 验证：在不同页面说相同话得到合适响应
  - 注：在 GlobalVoiceAssistantManager 中实现了 _handleContextAwareQuery

## 阶段四：对话界面改造（后台运行）

- [x] **4.1 改造 VoiceChatPage**
  - 修改：`lib/pages/voice_chat_page.dart`
  - 使用共享的 conversationHistory
  - 支持从悬浮球添加的消息
  - 移除独立的录音功能（统一到悬浮球）
  - 验证：悬浮球交互的消息在聊天界面可见
  - 注：已改造为使用 globalVoiceAssistantProvider 的共享状态

- [x] **4.2 添加聊天界面快速入口**
  - 悬浮球长按打开聊天界面
  - 悬浮球上滑打开聊天界面
  - 成功/失败时显示"查看详情"选项
  - 验证：能从悬浮球快速进入聊天界面
  - 注：长按悬浮球可打开 VoiceChatPage

- [x] **4.3 实现聊天界面后台保持**
  - 聊天界面关闭时状态保留
  - 再次打开时恢复滚动位置
  - 对话历史持久化到本地存储
  - 验证：关闭再打开聊天界面，历史记录完整
  - 注：使用 SharedPreferences 存储 JSON 格式历史，initialize 时加载，addMessage 时保存

## 阶段五：集成与配置（最终整合）

- [x] **5.1 集成到 main.dart**
  - 初始化 GlobalVoiceAssistantManager
  - 添加 VoiceContextRouteObserver
  - 添加 GlobalFloatingBallOverlay
  - 验证：App 启动后悬浮球正常显示

- [x] **5.2 实现排除页面配置**
  - 定义排除页面列表
  - 在排除页面自动隐藏悬浮球
  - 离开排除页面后自动恢复显示
  - 验证：在配置的页面悬浮球不显示
  - 注：已在 VoiceContextService 和 VoiceContextRouteObserver 中实现

- [x] **5.3 添加悬浮球设置项**
  - 修改：`lib/pages/settings/settings_page.dart`
  - 悬浮球开关
  - 默认位置设置
  - 悬浮球大小设置（可选）
  - 验证：设置项能正确控制悬浮球行为
  - 注：创建了 VoiceAssistantSettingsPage，集成到 SystemSettingsPage

- [x] **5.4 处理权限和错误**
  - 首次使用时请求麦克风权限
  - 权限被拒时显示引导
  - 网络错误时显示提示
  - 验证：各种异常情况有友好提示
  - 注：添加 MicrophonePermissionStatus 枚举、权限检查方法、权限对话框、网络错误区分处理

## 阶段六：测试与优化（质量保证）

- [x] **6.1 编写单元测试**
  - VoiceContextService 测试
  - GlobalVoiceAssistantManager 测试
  - 上下文增强逻辑测试
  - 验证：核心逻辑测试覆盖率 > 80%
  - 注：创建了 voice_context_service_test.dart (23个测试) 和 global_voice_assistant_manager_test.dart (11个测试)

- [ ] **6.2 编写 Widget 测试** _(后续优化)_
  - GlobalFloatingBall 测试
  - WaveformAnimation 测试
  - 状态切换测试
  - 验证：关键组件测试通过

- [ ] **6.3 性能优化** _(后续优化)_
  - 悬浮球动画性能检查
  - 内存使用检查
  - 对话历史清理策略
  - 验证：无明显卡顿或内存泄漏

- [ ] **6.4 用户体验优化** _(后续优化)_
  - 悬浮球出现/消失动画
  - 录音反馈优化（振动、声音）
  - 错误提示措辞优化
  - 验证：交互流畅自然

## 依赖关系

```
阶段一 ─┬→ 阶段二 ─→ 阶段五
        │
        └→ 阶段三 ─→ 阶段四 ─→ 阶段五 ─→ 阶段六
```

## 验证清单

完成所有任务后，需验证以下场景：

- [ ] 从首页点击悬浮球记账
- [ ] 在预算页面询问预算余额
- [ ] 在交易详情页修改金额
- [ ] 拖动悬浮球到屏幕各位置
- [ ] 在设置中关闭悬浮球
- [ ] 查看聊天历史记录
- [ ] 麦克风权限被拒后的提示
- [ ] 网络断开时的错误处理
