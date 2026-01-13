# 语音助手重构方案（参考 LiveKit 设计）

## 一、重构目标

1. **简化状态管理**: 6+ 个标志位 → 4 个状态的状态机
2. **移除过度工程**: 删除 1.5 秒延迟，信任硬件 AEC
3. **添加假打断恢复**: 2 秒超时后恢复播放
4. **统一服务实例**: TTS 服务单例化

---

## 二、新架构设计

### 2.1 状态机设计

```dart
/// 语音会话状态（参考 LiveKit AgentState）
enum VoiceSessionState {
  idle,        // 空闲，等待用户启动
  listening,   // 监听用户说话（ASR 运行）
  thinking,    // 处理中（等待 LLM 响应）
  speaking,    // TTS 播放中（VAD 监听打断）
}

/// 用户状态
enum UserState {
  idle,        // 空闲
  speaking,    // 正在说话
  away,        // 离开（长时间无响应）
}
```

### 2.2 状态转换图

```
                    用户点击开始
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                         idle                                      │
│                    (空闲，等待启动)                                │
└──────────────────────────────────────────────────────────────────┘
                         │ startSession()
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                       listening                                   │
│                    (监听用户说话)                                  │
│                                                                   │
│  服务状态: 录音=ON, ASR=ON, VAD=ON, TTS=OFF                       │
│                                                                   │
│  触发条件:                                                        │
│  - ASR 返回最终结果 → thinking                                    │
│  - 用户主动停止 → idle                                            │
│  - 静默超时(15s) → 主动对话 → speaking                            │
└──────────────────────────────────────────────────────────────────┘
                         │ ASR 最终结果
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                       thinking                                    │
│                    (处理中，等待 LLM)                              │
│                                                                   │
│  服务状态: 录音=ON, ASR=OFF(可选), VAD=ON, TTS=OFF               │
│                                                                   │
│  触发条件:                                                        │
│  - LLM 响应就绪 → speaking                                        │
│  - 处理超时/错误 → listening (带错误提示)                         │
└──────────────────────────────────────────────────────────────────┘
                         │ LLM 响应就绪
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                       speaking                                    │
│                    (TTS 播放中)                                   │
│                                                                   │
│  服务状态: 录音=ON, ASR=OFF, VAD=ON, TTS=ON                       │
│                                                                   │
│  打断处理:                                                        │
│  - VAD 检测到用户说话 500ms → 停止 TTS → listening                │
│  - 假打断: 2s 内无 ASR 结果 → 恢复播放                            │
│                                                                   │
│  触发条件:                                                        │
│  - TTS 播放完成 → listening（无延迟！）                           │
│  - 用户打断 → listening                                           │
└──────────────────────────────────────────────────────────────────┘
                         │ TTS 完成
                         ▼
                     listening (继续监听)
```

### 2.3 与当前实现的对比

| 维度 | 当前实现 | 新设计 |
|------|---------|--------|
| 状态表示 | `_isProcessingCommand` + `_isTTSPlayingWithBargeIn` + `_isProactiveConversation` + ... | `VoiceSessionState state` |
| TTS 后延迟 | 1.5 秒 | 0（信任硬件 AEC） |
| 假打断恢复 | 无 | 2 秒超时恢复 |
| ASR 运行 | 始终运行，结果被忽略 | speaking 时停止 |
| 打断确认 | 300ms | 500ms |

---

## 三、核心类设计

### 3.1 VoiceSessionStateMachine（状态机）

```dart
/// 语音会话状态机
///
/// 职责：管理状态转换，验证转换合法性，发送状态变化事件
class VoiceSessionStateMachine {
  VoiceSessionState _state = VoiceSessionState.idle;

  /// 当前状态
  VoiceSessionState get state => _state;

  /// 状态变化流
  final _stateController = StreamController<VoiceSessionStateChange>.broadcast();
  Stream<VoiceSessionStateChange> get stateStream => _stateController.stream;

  /// 状态转换验证表
  static const Map<VoiceSessionState, Set<VoiceSessionState>> _validTransitions = {
    VoiceSessionState.idle: {
      VoiceSessionState.listening,
    },
    VoiceSessionState.listening: {
      VoiceSessionState.thinking,
      VoiceSessionState.speaking,  // 主动对话
      VoiceSessionState.idle,
    },
    VoiceSessionState.thinking: {
      VoiceSessionState.speaking,
      VoiceSessionState.listening,  // 处理失败
      VoiceSessionState.idle,
    },
    VoiceSessionState.speaking: {
      VoiceSessionState.listening,  // TTS 完成或被打断
      VoiceSessionState.idle,
    },
  };

  /// 尝试转换状态
  bool transition(VoiceSessionState newState, {String? reason}) {
    if (!canTransition(newState)) {
      debugPrint('[StateMachine] 非法转换: $_state -> $newState');
      return false;
    }

    final oldState = _state;
    _state = newState;

    debugPrint('[StateMachine] 状态转换: $oldState -> $newState ($reason)');

    _stateController.add(VoiceSessionStateChange(
      oldState: oldState,
      newState: newState,
      reason: reason,
      timestamp: DateTime.now(),
    ));

    return true;
  }

  /// 检查是否可以转换
  bool canTransition(VoiceSessionState newState) {
    return _validTransitions[_state]?.contains(newState) ?? false;
  }

  /// 辅助属性：是否应该运行 ASR
  bool get shouldRunASR => _state == VoiceSessionState.listening;

  /// 辅助属性：是否应该运行 VAD
  bool get shouldRunVAD => _state != VoiceSessionState.idle;

  /// 辅助属性：是否可以被打断
  bool get isInterruptible => _state == VoiceSessionState.speaking;

  void dispose() {
    _stateController.close();
  }
}

/// 状态变化事件
class VoiceSessionStateChange {
  final VoiceSessionState oldState;
  final VoiceSessionState newState;
  final String? reason;
  final DateTime timestamp;

  VoiceSessionStateChange({
    required this.oldState,
    required this.newState,
    this.reason,
    required this.timestamp,
  });
}
```

### 3.2 VoiceSessionController（会话控制器）

```dart
/// 语音会话控制器
///
/// 职责：协调各服务，处理业务逻辑，响应状态变化
class VoiceSessionController {
  final VoiceSessionStateMachine _stateMachine;
  final VoiceRecognitionEngine _asrService;
  final TTSService _ttsService;
  final RealtimeVADService _vadService;
  final AudioRecorder _audioRecorder;

  /// 配置
  final VoiceSessionConfig config;

  /// 打断检测相关
  Timer? _interruptionConfirmTimer;
  Timer? _falseInterruptionTimer;
  DateTime? _userSpeechStartTime;
  String? _interruptedText;  // 被打断时的剩余文本（用于恢复）

  /// 音频流
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<ASRPartialResult>? _asrSubscription;

  /// 命令处理器（外部注入，用于调用执行层）
  CommandProcessorCallback? commandProcessor;

  VoiceSessionController({
    VoiceSessionConfig? config,
  }) : config = config ?? VoiceSessionConfig.defaultConfig,
       _stateMachine = VoiceSessionStateMachine(),
       _asrService = VoiceRecognitionEngine(),
       _ttsService = TTSService.instance,  // 单例
       _vadService = RealtimeVADService(),
       _audioRecorder = AudioRecorder() {
    _setupStateListener();
    _setupVADListener();
  }

  /// 监听状态变化，配置服务
  void _setupStateListener() {
    _stateMachine.stateStream.listen((change) {
      _configureServicesForState(change.newState);
    });
  }

  /// 根据状态配置服务
  void _configureServicesForState(VoiceSessionState state) {
    switch (state) {
      case VoiceSessionState.idle:
        _stopAllServices();
        break;

      case VoiceSessionState.listening:
        _startListening();
        break;

      case VoiceSessionState.thinking:
        _stopASR();  // 停止 ASR 节省资源
        // VAD 继续运行
        break;

      case VoiceSessionState.speaking:
        _stopASR();  // 停止 ASR（关键！避免回声）
        // VAD 继续运行（检测打断）
        break;
    }
  }

  /// 开始监听
  void _startListening() async {
    // 确保音频流已启动
    if (_audioStreamController == null) {
      await _startAudioStream();
    }

    // 启动 ASR
    _startASR();
  }

  /// 启动音频流
  Future<void> _startAudioStream() async {
    _audioStreamController = StreamController<Uint8List>.broadcast();

    final audioStream = await _audioRecorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));

    _audioSubscription = audioStream.listen((data) {
      final audioData = Uint8List.fromList(data);

      // 传递给 ASR（如果应该运行）
      if (_stateMachine.shouldRunASR && _audioStreamController != null) {
        _audioStreamController!.add(audioData);
      }

      // 始终传递给 VAD
      if (_stateMachine.shouldRunVAD) {
        _vadService.processAudioFrame(audioData);
      }
    });
  }

  /// 启动 ASR
  void _startASR() {
    if (_audioStreamController == null) return;

    _asrSubscription?.cancel();
    _asrSubscription = _asrService
        .transcribeStream(_audioStreamController!.stream)
        .listen(_handleASRResult);
  }

  /// 停止 ASR
  void _stopASR() {
    _asrSubscription?.cancel();
    _asrSubscription = null;
  }

  /// 处理 ASR 结果
  void _handleASRResult(ASRPartialResult result) {
    // 只在 listening 状态处理
    if (_stateMachine.state != VoiceSessionState.listening) {
      return;
    }

    if (result.isFinal && result.text.isNotEmpty) {
      _processFinalResult(result.text);
    }
  }

  /// 处理最终识别结果
  Future<void> _processFinalResult(String text) async {
    // 转换到 thinking 状态
    _stateMachine.transition(VoiceSessionState.thinking, reason: 'ASR 最终结果');

    // 调用命令处理器（执行层）
    String? response;
    try {
      response = await commandProcessor?.call(text);
    } catch (e) {
      debugPrint('[Controller] 命令处理失败: $e');
      response = '抱歉，处理失败了';
    }

    if (response != null && response.isNotEmpty) {
      // 转换到 speaking 状态并播放
      _stateMachine.transition(VoiceSessionState.speaking, reason: '开始 TTS');
      await _speakWithInterruptionSupport(response);
    } else {
      // 无响应，回到 listening
      _stateMachine.transition(VoiceSessionState.listening, reason: '无响应');
    }
  }

  /// 带打断支持的 TTS 播放
  Future<void> _speakWithInterruptionSupport(String text) async {
    _interruptedText = text;

    try {
      await _ttsService.speak(text);

      // TTS 正常完成，直接回到 listening（无延迟！）
      if (_stateMachine.state == VoiceSessionState.speaking) {
        _stateMachine.transition(VoiceSessionState.listening, reason: 'TTS 完成');
        _interruptedText = null;
      }
    } catch (e) {
      debugPrint('[Controller] TTS 播放失败: $e');
      _stateMachine.transition(VoiceSessionState.listening, reason: 'TTS 失败');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 打断检测逻辑（参考 LiveKit）
  // ═══════════════════════════════════════════════════════════════

  /// 设置 VAD 监听
  void _setupVADListener() {
    _vadService.eventStream.listen((event) {
      switch (event.type) {
        case VADEventType.speechStart:
          _onUserSpeechStart();
          break;
        case VADEventType.speechEnd:
          _onUserSpeechEnd();
          break;
        default:
          break;
      }
    });
  }

  /// 用户开始说话
  void _onUserSpeechStart() {
    _userSpeechStartTime = DateTime.now();

    // 只在 speaking 状态检测打断
    if (_stateMachine.state != VoiceSessionState.speaking) {
      return;
    }

    if (!config.allowInterruptions) {
      return;
    }

    // 启动打断确认计时器（500ms）
    _interruptionConfirmTimer?.cancel();
    _interruptionConfirmTimer = Timer(config.interruptionConfirmDelay, () {
      _confirmInterruption();
    });
  }

  /// 用户停止说话
  void _onUserSpeechEnd() {
    // 取消打断确认（说话时间不够）
    _interruptionConfirmTimer?.cancel();
    _interruptionConfirmTimer = null;
    _userSpeechStartTime = null;
  }

  /// 确认打断
  void _confirmInterruption() {
    debugPrint('[Controller] 用户打断确认');

    // 停止 TTS
    _ttsService.stop();

    // 转换到 listening 状态
    _stateMachine.transition(VoiceSessionState.listening, reason: '用户打断');

    // 启动假打断检测计时器（2秒）
    _startFalseInterruptionTimer();

    // 重启 ASR
    _startASR();
  }

  /// 启动假打断检测
  void _startFalseInterruptionTimer() {
    _falseInterruptionTimer?.cancel();
    _falseInterruptionTimer = Timer(config.falseInterruptionTimeout, () {
      _handleFalseInterruption();
    });
  }

  /// 处理假打断（2秒内无有效 ASR 结果）
  void _handleFalseInterruption() {
    if (!config.resumeFalseInterruption) {
      return;
    }

    if (_interruptedText != null && _stateMachine.state == VoiceSessionState.listening) {
      debugPrint('[Controller] 假打断，恢复播放');

      // 恢复播放
      _stateMachine.transition(VoiceSessionState.speaking, reason: '假打断恢复');
      _speakWithInterruptionSupport(_interruptedText!);
    }
  }

  /// 取消假打断计时器（收到有效 ASR 结果时调用）
  void _cancelFalseInterruptionTimer() {
    _falseInterruptionTimer?.cancel();
    _falseInterruptionTimer = null;
    _interruptedText = null;  // 清除被打断的文本
  }

  // ═══════════════════════════════════════════════════════════════
  // 公开接口
  // ═══════════════════════════════════════════════════════════════

  /// 开始会话
  Future<void> startSession() async {
    if (_stateMachine.state != VoiceSessionState.idle) {
      return;
    }

    _stateMachine.transition(VoiceSessionState.listening, reason: '用户启动');
  }

  /// 停止会话
  Future<void> stopSession() async {
    _stateMachine.transition(VoiceSessionState.idle, reason: '用户停止');
  }

  /// 当前状态
  VoiceSessionState get state => _stateMachine.state;

  /// 状态流
  Stream<VoiceSessionStateChange> get stateStream => _stateMachine.stateStream;

  /// 停止所有服务
  void _stopAllServices() {
    _asrSubscription?.cancel();
    _audioSubscription?.cancel();
    _audioStreamController?.close();
    _audioStreamController = null;
    _audioRecorder.stop();
    _ttsService.stop();

    _interruptionConfirmTimer?.cancel();
    _falseInterruptionTimer?.cancel();
  }

  void dispose() {
    _stopAllServices();
    _stateMachine.dispose();
  }
}
```

### 3.3 配置类

```dart
/// 语音会话配置（参考 LiveKit 参数）
class VoiceSessionConfig {
  /// 是否允许打断
  final bool allowInterruptions;

  /// 打断确认延迟（用户说话多久才算打断）
  final Duration interruptionConfirmDelay;

  /// 假打断超时（多久没有 ASR 结果算假打断）
  final Duration falseInterruptionTimeout;

  /// 是否恢复假打断
  final bool resumeFalseInterruption;

  /// 静默超时（触发主动对话）
  final Duration silenceTimeout;

  /// 用户离开超时
  final Duration userAwayTimeout;

  const VoiceSessionConfig({
    this.allowInterruptions = true,
    this.interruptionConfirmDelay = const Duration(milliseconds: 500),
    this.falseInterruptionTimeout = const Duration(seconds: 2),
    this.resumeFalseInterruption = true,
    this.silenceTimeout = const Duration(seconds: 5),
    this.userAwayTimeout = const Duration(seconds: 15),
  });

  static const defaultConfig = VoiceSessionConfig();

  /// 保守配置（减少误打断）
  static const conservative = VoiceSessionConfig(
    interruptionConfirmDelay: Duration(milliseconds: 800),
    falseInterruptionTimeout: Duration(seconds: 3),
  );
}
```

---

## 四、集成方案

### 4.1 修改 GlobalVoiceAssistantManager

```dart
class GlobalVoiceAssistantManager extends ChangeNotifier {
  // 删除这些标志位：
  // - _isProcessingCommand
  // - _isTTSPlayingWithBargeIn
  // - _isProactiveConversation
  // - _isRestartingASR

  // 替换为：
  late final VoiceSessionController _sessionController;

  Future<void> initialize() async {
    _sessionController = VoiceSessionController();
    _sessionController.commandProcessor = _handleCommand;

    // 监听状态变化，更新 UI
    _sessionController.stateStream.listen((change) {
      // 映射到 FloatingBallState
      switch (change.newState) {
        case VoiceSessionState.idle:
          _ballState = FloatingBallState.idle;
          break;
        case VoiceSessionState.listening:
          _ballState = FloatingBallState.recording;
          break;
        case VoiceSessionState.thinking:
          _ballState = FloatingBallState.processing;
          break;
        case VoiceSessionState.speaking:
          _ballState = FloatingBallState.recording;  // 或新增一个状态
          break;
      }
      notifyListeners();
    });
  }

  Future<void> startRecording() async {
    await _sessionController.startSession();
  }

  Future<void> stopRecording() async {
    await _sessionController.stopSession();
  }

  Future<String?> _handleCommand(String text) async {
    // 调用 VoiceServiceCoordinator（执行层，保持不变）
    if (_commandProcessor != null) {
      return await _commandProcessor!(text);
    }
    return null;
  }
}
```

### 4.2 需要删除的代码

```dart
// 删除这些方法：
void _enableBargeInDetection() { ... }
void _disableBargeInDetection() { ... }
void _handleBargeInEvent(BargeInEvent event) { ... }
void _onBargeInDetected() { ... }
void _restartASRIfNeeded() { ... }

// 删除这些延迟：
await Future.delayed(const Duration(milliseconds: 1500));  // TTS 后延迟
```

---

## 五、文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/services/voice/voice_session_state.dart` | **新建** | 状态枚举定义 |
| `lib/services/voice/voice_session_state_machine.dart` | **新建** | 状态机实现 |
| `lib/services/voice/voice_session_controller.dart` | **新建** | 会话控制器 |
| `lib/services/voice/voice_session_config.dart` | **新建** | 配置类 |
| `lib/services/global_voice_assistant_manager.dart` | **修改** | 集成新控制器，删除旧标志位 |
| `lib/services/tts_service.dart` | **修改** | 改为单例模式 |
| `lib/services/voice/barge_in_detector.dart` | **删除** | 功能已整合到控制器 |

---

## 六、测试计划

### 6.1 单元测试

```dart
void main() {
  group('VoiceSessionStateMachine', () {
    test('初始状态为 idle', () {
      final machine = VoiceSessionStateMachine();
      expect(machine.state, VoiceSessionState.idle);
    });

    test('idle -> listening 允许', () {
      final machine = VoiceSessionStateMachine();
      expect(machine.transition(VoiceSessionState.listening), true);
      expect(machine.state, VoiceSessionState.listening);
    });

    test('idle -> speaking 不允许', () {
      final machine = VoiceSessionStateMachine();
      expect(machine.transition(VoiceSessionState.speaking), false);
      expect(machine.state, VoiceSessionState.idle);
    });

    test('speaking -> listening (打断) 允许', () {
      final machine = VoiceSessionStateMachine();
      machine.transition(VoiceSessionState.listening);
      machine.transition(VoiceSessionState.thinking);
      machine.transition(VoiceSessionState.speaking);

      expect(machine.transition(VoiceSessionState.listening), true);
    });
  });

  group('打断检测', () {
    test('用户说话 500ms 后触发打断', () async {
      // ...
    });

    test('假打断 2s 后恢复播放', () async {
      // ...
    });
  });
}
```

### 6.2 真机测试清单

- [ ] 基本对话：说话 → 响应 → 继续说话
- [ ] 打断测试：TTS 播放时说话，验证 500ms 后停止
- [ ] 假打断测试：清嗓子/背景噪音，验证 2s 后恢复
- [ ] 无延迟验证：TTS 结束后立即可说话
- [ ] 回声验证：TTS 内容不被 ASR 识别
- [ ] 连续对话：10 轮对话无异常

---

## 七、回滚计划

1. 新代码在独立文件中实现
2. 通过 feature flag 控制启用
3. 保留旧代码直到新代码稳定
4. 可随时切换回旧实现

```dart
// 在 GlobalVoiceAssistantManager 中
static const bool _useNewStateMachine = true;

Future<void> startRecording() async {
  if (_useNewStateMachine) {
    await _sessionController.startSession();
  } else {
    await _legacyStartRecording();
  }
}
```

---

## 八、时间线

| 阶段 | 内容 |
|------|------|
| 阶段 1 | 创建状态机和控制器类（不修改现有代码） |
| 阶段 2 | 单元测试 |
| 阶段 3 | 集成到 GlobalVoiceAssistantManager |
| 阶段 4 | 真机测试 |
| 阶段 5 | 清理旧代码，发布 |
