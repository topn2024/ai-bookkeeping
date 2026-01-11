# 全局语音助手系统 - 技术设计

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                        App Root                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    MaterialApp                          ││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │               NavigatorOverlay                      │││
│  │  │  ┌───────────────────────────────────────────────┐  │││
│  │  │  │              Page Content                      │  │││
│  │  │  │                                               │  │││
│  │  │  └───────────────────────────────────────────────┘  │││
│  │  │  ┌───────────────────────────────────────────────┐  │││
│  │  │  │         GlobalFloatingBall (Overlay)         │  │││
│  │  │  │              [始终在最顶层]                    │  │││
│  │  │  └───────────────────────────────────────────────┘  │││
│  │  └─────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## 核心组件设计

### 1. GlobalVoiceAssistantManager

全局语音助手的核心管理器，作为单例运行：

```dart
class GlobalVoiceAssistantManager {
  // 单例模式
  static final GlobalVoiceAssistantManager _instance = GlobalVoiceAssistantManager._();
  factory GlobalVoiceAssistantManager() => _instance;

  // 状态管理
  final ValueNotifier<FloatingBallState> ballState = ValueNotifier(FloatingBallState.idle);
  final ValueNotifier<bool> isVisible = ValueNotifier(true);
  final ValueNotifier<Offset> position = ValueNotifier(Offset.zero);

  // 上下文感知
  final ValueNotifier<PageContext?> currentPageContext = ValueNotifier(null);

  // 对话历史
  final List<ChatMessage> conversationHistory = [];

  // 核心服务
  late VoiceRecognitionEngine _asr;
  late TtsService _tts;
  late VoiceContextService _contextService;
  late AIIntentParser _intentParser;
}
```

### 2. GlobalFloatingBall Widget

使用 OverlayEntry 实现的全局悬浮球：

```dart
class GlobalFloatingBall extends StatefulWidget {
  // 通过 Overlay.of(context).insert() 添加到顶层
}

// 悬浮球状态
enum FloatingBallState {
  idle,        // 默认状态，显示麦克风图标
  recording,   // 录音中，显示波浪动画
  processing,  // 处理中，显示加载动画
  success,     // 成功，短暂显示勾号
  error,       // 错误，短暂显示错误图标
  hidden,      // 隐藏状态
}
```

### 3. VoiceContextService

页面上下文感知服务：

```dart
class VoiceContextService {
  // 当前页面上下文
  PageContext? currentContext;

  // 页面上下文类型
  enum PageContextType {
    home,           // 首页 - 快速记账
    transaction,    // 交易页 - 查询/编辑交易
    budget,         // 预算页 - 查询预算
    report,         // 报表页 - 查询统计
    moneyAge,       // 钱龄页 - 查询钱龄
    savings,        // 储蓄页 - 储蓄操作
    settings,       // 设置页 - 配置调整
    other,          // 其他页面
  }

  // 根据页面上下文增强意图理解
  EnhancedIntent enhanceIntent(RawIntent intent, PageContext context);
}
```

### 4. 页面上下文注册

通过 RouteObserver 自动感知页面切换：

```dart
class VoiceContextRouteObserver extends RouteObserver<PageRoute> {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PageRoute) {
      final pageName = route.settings.name;
      final arguments = route.settings.arguments;
      VoiceContextService().updateContext(pageName, arguments);
    }
  }
}
```

### 5. 波浪动画组件

录音时的波浪动画效果：

```dart
class WaveformAnimation extends StatefulWidget {
  // 使用 CustomPainter 绘制实时音频波形
  // 或使用预设的波浪动画
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes; // 音频振幅数据

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制动态波形
  }
}
```

## 数据流设计

### 语音交互流程

```
用户点击悬浮球
      ↓
FloatingBallState → recording
      ↓
VoiceRecognitionEngine.startRecording()
      ↓
用户松开或再次点击
      ↓
VoiceRecognitionEngine.stopRecording()
      ↓
FloatingBallState → processing
      ↓
ASR 返回文本
      ↓
VoiceContextService.getEnhancedContext()
      ↓
AIIntentParser.parse(text, context)
      ↓
IntentRouter.execute(intent)
      ↓
生成响应 + 执行操作
      ↓
FloatingBallState → success/error
      ↓
保存到 conversationHistory
      ↓
可选：TTS 播报结果
      ↓
FloatingBallState → idle (延迟恢复)
```

### 上下文感知示例

```dart
// 在首页说"记一笔35块"
context: PageContext(type: home)
intent: RecordExpense(amount: 35)
response: "好的，已记录支出 ¥35"

// 在预算页说"还剩多少"
context: PageContext(type: budget, data: {budgetId: 'food'})
intent: QueryBudget(budgetId: 'food')
response: "餐饮预算还剩 ¥523.50"

// 在交易详情页说"改成50"
context: PageContext(type: transactionDetail, data: {transactionId: '123'})
intent: ModifyTransaction(id: '123', amount: 50)
response: "已将金额修改为 ¥50"
```

## 状态管理

使用 Riverpod 管理全局状态：

```dart
// 悬浮球状态 Provider
final floatingBallStateProvider = StateNotifierProvider<FloatingBallStateNotifier, FloatingBallState>((ref) {
  return FloatingBallStateNotifier();
});

// 悬浮球位置 Provider
final floatingBallPositionProvider = StateProvider<Offset>((ref) {
  return const Offset(0, 0); // 默认右下角
});

// 悬浮球可见性 Provider
final floatingBallVisibilityProvider = StateProvider<bool>((ref) {
  return true;
});

// 对话历史 Provider
final conversationHistoryProvider = StateNotifierProvider<ConversationHistoryNotifier, List<ChatMessage>>((ref) {
  return ConversationHistoryNotifier();
});

// 页面上下文 Provider
final currentPageContextProvider = StateProvider<PageContext?>((ref) {
  return null;
});
```

## 集成方式

### main.dart 集成

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化全局语音助手
  await GlobalVoiceAssistantManager().initialize();

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorObservers: [
        VoiceContextRouteObserver(), // 页面上下文监听
      ],
      builder: (context, child) {
        return Stack(
          children: [
            child!, // 页面内容
            const GlobalFloatingBallOverlay(), // 全局悬浮球
          ],
        );
      },
    );
  }
}
```

## 性能优化

1. **延迟初始化**
   - 语音服务在首次使用时才初始化
   - 悬浮球本身极轻量，仅包含图标和基础动画

2. **资源释放**
   - 录音结束后立即释放音频资源
   - ASR/TTS 连接池复用

3. **动画优化**
   - 波浪动画使用 RepaintBoundary 隔离重绘
   - 使用 AnimatedBuilder 避免不必要的 rebuild

4. **内存管理**
   - 对话历史限制最近 100 条
   - 超出限制时自动清理旧记录

## 排除页面配置

某些页面不显示悬浮球：

```dart
const excludedRoutes = [
  '/voice-assistant',  // 已有语音界面
  '/voice-chat',       // 聊天界面
  '/settings/voice',   // 语音设置页
  '/camera',           // 相机页
];
```

## 错误处理

```dart
enum VoiceAssistantError {
  microphonePermissionDenied,  // 麦克风权限被拒
  networkError,                 // 网络错误
  asrServiceUnavailable,       // ASR 服务不可用
  intentParseError,            // 意图解析失败
  operationFailed,             // 操作执行失败
}

// 错误处理策略
- 权限错误：显示引导用户开启权限的提示
- 网络错误：提示网络问题，支持重试
- 服务错误：降级到本地识别或提示稍后再试
- 解析错误：显示友好提示，引导用户重新表达
```

## 测试策略

1. **单元测试**
   - VoiceContextService 上下文解析
   - 意图增强逻辑
   - 状态流转逻辑

2. **Widget 测试**
   - 悬浮球渲染和交互
   - 波浪动画正确性
   - 状态切换 UI 变化

3. **集成测试**
   - 完整语音记账流程
   - 页面切换上下文更新
   - 错误恢复场景
