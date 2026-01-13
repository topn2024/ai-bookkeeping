# 支持打断的语音助手设计方案

## 1. 设计目标

- TTS 播放期间用户可以随时打断
- 防止 TTS 音频被 ASR 误识别为用户语音
- 假打断自动恢复（噪音触发的误打断）
- 状态清晰，易于调试

## 2. 状态机设计

```
┌─────────────────────────────────────────────────────────────────────┐
│                        VoiceStateMachine                            │
│                                                                     │
│  ┌──────────┐  用户开始说话   ┌────────────┐  ASR最终结果           │
│  │  IDLE    │───────────────>│ LISTENING  │─────────────┐          │
│  └──────────┘                └────────────┘             │          │
│       ^                            ^                     v          │
│       │                            │              ┌────────────┐    │
│       │                      假打断恢复           │ PROCESSING │    │
│       │                            │              └─────┬──────┘    │
│       │                     ┌──────┴──────┐             │          │
│       │     TTS完成         │ INTERRUPTED │             │ 开始TTS   │
│       │        │            └─────────────┘             v          │
│       │        │                   ^            ┌────────────┐      │
│       │        │              用户打断          │  SPEAKING  │      │
│       └────────┴───────────────────────────────┤(可打断模式) │      │
│                                                 └────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

### 状态说明

| 状态 | 录音 | VAD | ASR | TTS | 说明 |
|------|------|-----|-----|-----|------|
| IDLE | 停止 | 停止 | 停止 | 停止 | 空闲状态 |
| LISTENING | 运行 | 运行 | 运行 | 停止 | 监听用户输入 |
| PROCESSING | 停止 | 停止 | 停止 | 停止 | 处理命令中 |
| SPEAKING | 运行 | 运行 | **丢弃** | 运行 | TTS播放，可被打断 |
| INTERRUPTED | 运行 | 运行 | 运行 | 停止 | 被打断，等待用户输入 |

### 关键设计点

1. **SPEAKING 状态**：
   - 录音和 VAD 保持运行（用于检测打断）
   - ASR 结果被丢弃（防止回声）
   - TTS 正在播放

2. **打断检测**：
   - VAD 检测到语音活动
   - 持续时间超过 `MIN_INTERRUPTION_DURATION`（500ms）
   - 触发打断：停止 TTS，进入 INTERRUPTED 状态

3. **假打断恢复**：
   - 打断后等待 `FALSE_INTERRUPTION_TIMEOUT`（2秒）
   - 如果没有有效 ASR 结果，恢复 TTS 播放

## 3. 核心类设计

### 3.1 VoiceStateMachine

```dart
enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
  interrupted,
}

class VoiceStateMachine {
  VoiceState _state = VoiceState.idle;

  // 配置参数
  static const Duration minInterruptionDuration = Duration(milliseconds: 500);
  static const Duration falseInterruptionTimeout = Duration(seconds: 2);

  // 状态转换监听
  final _stateController = StreamController<VoiceState>.broadcast();
  Stream<VoiceState> get stateStream => _stateController.stream;

  // 打断相关
  DateTime? _interruptionStartTime;
  String? _pendingTTSText;  // 被打断时剩余的TTS文本
  int _pendingTTSPosition;  // 被打断时的播放位置

  /// 状态转换（原子操作）
  bool transition(VoiceState newState) {
    if (!_isValidTransition(_state, newState)) {
      debugPrint('[StateMachine] 无效转换: $_state -> $newState');
      return false;
    }

    final oldState = _state;
    _state = newState;
    _stateController.add(newState);
    debugPrint('[StateMachine] 状态转换: $oldState -> $newState');

    return true;
  }

  /// 检查是否在可打断状态
  bool get isInterruptible => _state == VoiceState.speaking;

  /// 检查是否应该丢弃ASR结果
  bool get shouldDiscardASR => _state == VoiceState.speaking;

  /// 检查是否应该处理ASR结果
  bool get shouldProcessASR =>
      _state == VoiceState.listening ||
      _state == VoiceState.interrupted;
}
```

### 3.2 BargeInDetector

```dart
/// 打断检测器
class BargeInDetector {
  final VoiceStateMachine _stateMachine;
  final Duration minDuration;

  DateTime? _speechStartTime;
  bool _isPotentialInterruption = false;

  BargeInDetector({
    required VoiceStateMachine stateMachine,
    this.minDuration = const Duration(milliseconds: 500),
  }) : _stateMachine = stateMachine;

  /// 处理 VAD 事件
  void onVADEvent(VADEventType event) {
    if (!_stateMachine.isInterruptible) return;

    switch (event) {
      case VADEventType.speechStart:
        _speechStartTime = DateTime.now();
        _isPotentialInterruption = true;
        debugPrint('[BargeIn] 检测到潜在打断');
        break;

      case VADEventType.speechEnd:
        if (_isPotentialInterruption && _speechStartTime != null) {
          final duration = DateTime.now().difference(_speechStartTime!);
          if (duration >= minDuration) {
            // 有效打断
            debugPrint('[BargeIn] 确认打断，时长=${duration.inMilliseconds}ms');
            _triggerInterruption();
          } else {
            // 太短，可能是噪音
            debugPrint('[BargeIn] 打断时长不足，忽略');
          }
        }
        _reset();
        break;
    }
  }

  /// 检查是否超过最小打断时长（用于持续语音）
  void checkInterruptionThreshold() {
    if (!_isPotentialInterruption || _speechStartTime == null) return;

    final duration = DateTime.now().difference(_speechStartTime!);
    if (duration >= minDuration) {
      debugPrint('[BargeIn] 持续语音触发打断');
      _triggerInterruption();
    }
  }

  void _triggerInterruption() {
    // 通知状态机发生打断
    _stateMachine.transition(VoiceState.interrupted);
    _reset();
  }

  void _reset() {
    _speechStartTime = null;
    _isPotentialInterruption = false;
  }
}
```

### 3.3 FalseInterruptionHandler

```dart
/// 假打断处理器
class FalseInterruptionHandler {
  final VoiceStateMachine _stateMachine;
  final Duration timeout;

  Timer? _timeoutTimer;

  FalseInterruptionHandler({
    required VoiceStateMachine stateMachine,
    this.timeout = const Duration(seconds: 2),
  }) : _stateMachine = stateMachine;

  /// 开始假打断检测（进入 INTERRUPTED 状态时调用）
  void startDetection({
    required String pendingTTSText,
    required int pendingPosition,
  }) {
    _timeoutTimer?.cancel();

    _timeoutTimer = Timer(timeout, () {
      if (_stateMachine.state == VoiceState.interrupted) {
        debugPrint('[FalseInterruption] 超时无有效输入，恢复TTS');
        _resumeTTS(pendingTTSText, pendingPosition);
      }
    });
  }

  /// 取消检测（收到有效ASR结果时调用）
  void cancel() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _resumeTTS(String text, int position) {
    // 恢复播放TTS
    // 从 position 位置继续播放 text
  }
}
```

## 4. 集成到现有代码

### 4.1 GlobalVoiceAssistantManager 改造

```dart
class GlobalVoiceAssistantManager {
  // 新增组件
  late final VoiceStateMachine _stateMachine;
  late final BargeInDetector _bargeInDetector;
  late final FalseInterruptionHandler _falseInterruptionHandler;

  // 初始化
  void _initStateMachine() {
    _stateMachine = VoiceStateMachine();
    _bargeInDetector = BargeInDetector(stateMachine: _stateMachine);
    _falseInterruptionHandler = FalseInterruptionHandler(stateMachine: _stateMachine);

    // 监听状态变化
    _stateMachine.stateStream.listen(_onStateChanged);
  }

  void _onStateChanged(VoiceState state) {
    switch (state) {
      case VoiceState.idle:
        _stopAllAudio();
        break;
      case VoiceState.listening:
        _startRecordingAndASR();
        break;
      case VoiceState.processing:
        _stopRecordingAndASR();
        break;
      case VoiceState.speaking:
        _startRecordingForBargeIn(); // 录音+VAD，但ASR丢弃
        break;
      case VoiceState.interrupted:
        _stopTTS();
        _startFullASR(); // 恢复完整ASR
        _falseInterruptionHandler.startDetection(...);
        break;
    }
  }

  // VAD 事件处理
  void _onVADEvent(VADEvent event) {
    // 打断检测
    _bargeInDetector.onVADEvent(event.type);

    // 其他 VAD 处理...
  }

  // ASR 结果处理
  void _onASRResult(ASRResult result) {
    // 根据状态决定是否处理
    if (_stateMachine.shouldDiscardASR) {
      debugPrint('[ASR] 丢弃结果（SPEAKING状态）: ${result.text}');
      return;
    }

    if (!_stateMachine.shouldProcessASR) {
      debugPrint('[ASR] 忽略结果（非监听状态）: ${result.text}');
      return;
    }

    // 正常处理...
    if (result.isFinal) {
      _falseInterruptionHandler.cancel(); // 取消假打断检测
      _handleFinalASRResult(result.text);
    }
  }
}
```

### 4.2 音频管道配置

```dart
/// SPEAKING 状态的音频配置
void _startRecordingForBargeIn() {
  // 1. 启动录音（用于 VAD）
  _startRecording();

  // 2. 启动 VAD（用于打断检测）
  _vadService.start();

  // 3. 启动 ASR（但标记为丢弃模式）
  // 或者完全不启动 ASR，只用 VAD
  _asrDiscardMode = true;
}

/// INTERRUPTED/LISTENING 状态的音频配置
void _startFullASR() {
  _asrDiscardMode = false;
  _startASR();
}
```

## 5. 时序图

### 5.1 正常对话流程

```
用户          系统          VAD         ASR         TTS
 │             │            │           │           │
 │  点击开始   │            │           │           │
 │────────────>│ LISTENING  │           │           │
 │             │───────────>│ start     │           │
 │             │────────────────────────>│ start    │
 │             │            │           │           │
 │  "记一笔"   │            │           │           │
 │~~~~~~~~~~~~~│~~~~~~~~~~~~│~~~~~~~~~~~│           │
 │             │            │ speech    │           │
 │             │<───────────│ detected  │           │
 │             │            │           │ "记一笔"  │
 │             │<───────────────────────│ final     │
 │             │ PROCESSING │           │           │
 │             │───────────>│ stop      │           │
 │             │────────────────────────>│ stop     │
 │             │            │           │           │
 │             │ SPEAKING   │           │           │
 │             │───────────>│ start     │           │ "好的"
 │             │────────────────────────>│ discard  │───────>
 │             │            │           │           │
 │             │ TTS完成    │           │           │
 │             │ IDLE       │           │           │
 │<────────────│────────────────────────────────────│
```

### 5.2 用户打断流程

```
用户          系统          VAD         ASR         TTS
 │             │            │           │           │
 │             │ SPEAKING   │           │           │ "好的，帮你..."
 │             │            │ running   │ discard   │───────>
 │             │            │           │           │
 │  "等等"     │            │           │           │
 │~~~~~~~~~~~~~│~~~~~~~~~~~~│           │           │
 │             │            │ speech    │           │
 │             │<───────────│ start     │           │
 │             │            │           │           │
 │             │            │ 500ms后   │           │
 │             │<───────────│ confirmed │           │
 │             │            │           │           │ stop!
 │             │ INTERRUPTED│           │           │<──────
 │             │────────────────────────>│ resume   │
 │             │            │           │           │
 │  继续说...  │            │           │           │
 │~~~~~~~~~~~~~│~~~~~~~~~~~~│~~~~~~~~~~~│           │
 │             │            │           │ "等等..." │
 │             │<───────────────────────│ final     │
 │             │ PROCESSING │           │           │
```

### 5.3 假打断流程

```
用户          系统          VAD         ASR         TTS
 │             │            │           │           │
 │             │ SPEAKING   │           │           │ "好的..."
 │             │            │ running   │ discard   │───────>
 │             │            │           │           │
 │  [噪音]     │            │           │           │
 │~~~~~~~~~~~~~│~~~~~~~~~~~~│           │           │
 │             │            │ speech    │           │
 │             │<───────────│ start     │           │
 │             │            │           │           │
 │             │            │ <500ms    │           │
 │             │            │ end       │           │
 │             │<───────────│ too short │           │
 │             │            │           │           │
 │             │ 继续SPEAKING│          │           │ 继续播放
 │             │            │           │           │───────>
```

## 6. 配置参数

```dart
class BargeInConfig {
  /// 最小打断持续时间（语音持续超过此时长才算有效打断）
  final Duration minInterruptionDuration;

  /// 假打断超时时间（打断后无有效输入，恢复TTS播放）
  final Duration falseInterruptionTimeout;

  /// 是否启用假打断恢复
  final bool enableFalseInterruptionRecovery;

  /// 打断后的TTS淡出时间
  final Duration ttseFadeOutDuration;

  const BargeInConfig({
    this.minInterruptionDuration = const Duration(milliseconds: 500),
    this.falseInterruptionTimeout = const Duration(seconds: 2),
    this.enableFalseInterruptionRecovery = true,
    this.ttsFadeOutDuration = const Duration(milliseconds: 100),
  });
}
```

## 7. 与现有代码的兼容

### 需要修改的文件

1. **global_voice_assistant_manager.dart**
   - 引入 VoiceStateMachine
   - 修改 VAD 事件处理逻辑
   - 修改 ASR 结果处理逻辑

2. **voice_service_coordinator.dart**
   - TTS 播放需要支持中断和恢复
   - 需要能获取当前播放位置

3. **tts_service.dart**
   - 添加 `stopWithFadeOut()` 方法
   - 添加 `getCurrentPosition()` 方法
   - 添加 `resumeFrom(position)` 方法

### 可复用的现有代码

1. **RealtimeVADService** - VAD 检测逻辑可直接复用
2. **AliCloudASRService** - ASR 服务可直接复用
3. **FlutterTTSEngine** - TTS 引擎可直接复用

## 8. 测试场景

1. **正常对话**: 用户说完 → 系统回复 → 用户继续
2. **有效打断**: 用户在系统说话时打断 → 系统停止 → 处理新输入
3. **假打断**: 短暂噪音 → 系统继续播放
4. **打断后沉默**: 用户打断后不说话 → 恢复播放
5. **连续打断**: 用户多次打断
