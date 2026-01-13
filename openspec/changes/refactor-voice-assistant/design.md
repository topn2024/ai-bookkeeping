# 语音助手重构 - 详细设计

## 1. 架构概览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GlobalVoiceAssistantManager                       │
│                          (对外接口保持不变)                                │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     VoiceSessionController                          │ │
│  │                                                                     │ │
│  │  ┌─────────────────────┐    ┌─────────────────────┐               │ │
│  │  │ VoiceSessionState   │    │    AudioPipeline     │               │ │
│  │  │     Machine         │───>│                      │               │ │
│  │  │                     │    │  - AudioRecorder     │               │ │
│  │  │  IDLE               │    │  - VADService        │               │ │
│  │  │  LISTENING          │    │  - ASRService        │               │ │
│  │  │  PROCESSING         │    │  - TTSService        │               │ │
│  │  │  SPEAKING           │    │                      │               │ │
│  │  │  INTERRUPTED        │    └─────────────────────┘               │ │
│  │  └─────────────────────┘                                          │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     CommandProcessor                                │ │
│  │                   (现有逻辑保持不变)                                  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## 2. 核心类设计

### 2.1 VoiceSessionState (枚举)

```dart
/// 语音会话状态
enum VoiceSessionState {
  /// 空闲 - 没有活动的语音会话
  idle,

  /// 监听中 - 正在接收和识别用户语音
  listening,

  /// 处理中 - 正在处理用户命令，等待响应
  processing,

  /// 播放中 - 正在播放TTS响应，可被打断
  speaking,

  /// 被打断 - TTS被用户打断，正在恢复监听
  interrupted,
}
```

### 2.2 VoiceSessionStateMachine

```dart
/// 语音会话状态机
///
/// 核心原则：
/// 1. 状态转换是原子操作
/// 2. 每个状态有明确的资源配置（哪些服务运行/停止）
/// 3. 不使用额外的标志位，所有状态由状态机管理
class VoiceSessionStateMachine {
  VoiceSessionState _state = VoiceSessionState.idle;

  /// 当前状态
  VoiceSessionState get state => _state;

  /// 状态变化流
  final _stateController = StreamController<VoiceSessionState>.broadcast();
  Stream<VoiceSessionState> get stateStream => _stateController.stream;

  /// 状态转换
  ///
  /// 返回true表示转换成功，false表示转换无效
  bool transition(VoiceSessionState newState) {
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

  /// 验证状态转换是否有效
  bool _isValidTransition(VoiceSessionState from, VoiceSessionState to) {
    switch (from) {
      case VoiceSessionState.idle:
        return to == VoiceSessionState.listening;

      case VoiceSessionState.listening:
        return to == VoiceSessionState.processing ||
               to == VoiceSessionState.idle;

      case VoiceSessionState.processing:
        return to == VoiceSessionState.speaking ||
               to == VoiceSessionState.listening ||  // 无需TTS响应时
               to == VoiceSessionState.idle;

      case VoiceSessionState.speaking:
        return to == VoiceSessionState.listening ||  // TTS完成
               to == VoiceSessionState.interrupted || // 用户打断
               to == VoiceSessionState.idle;

      case VoiceSessionState.interrupted:
        return to == VoiceSessionState.listening ||
               to == VoiceSessionState.idle;
    }
  }

  /// 检查当前状态是否应该运行ASR
  bool get shouldRunASR =>
      _state == VoiceSessionState.listening ||
      _state == VoiceSessionState.interrupted;

  /// 检查当前状态是否应该运行VAD
  bool get shouldRunVAD =>
      _state == VoiceSessionState.listening ||
      _state == VoiceSessionState.speaking ||
      _state == VoiceSessionState.interrupted;

  /// 检查当前状态是否可以被打断
  bool get isInterruptible => _state == VoiceSessionState.speaking;

  void dispose() {
    _stateController.close();
  }
}
```

### 2.3 VoiceSessionController

```dart
/// 语音会话控制器
///
/// 负责协调状态机与音频服务的交互
class VoiceSessionController {
  final VoiceSessionStateMachine _stateMachine;
  final AudioRecorder _audioRecorder;
  final RealtimeVADService _vadService;
  final VoiceRecognitionEngine _asrService;
  final TTSService _ttsService;

  // 音频流控制
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _asrSubscription;
  StreamSubscription? _vadSubscription;

  // 打断检测
  DateTime? _speechStartTime;
  static const Duration _minInterruptionDuration = Duration(milliseconds: 500);

  // 回调
  final Function(String)? onFinalResult;
  final Function(String)? onPartialResult;
  final Function(VoiceSessionState)? onStateChanged;

  VoiceSessionController({
    required this.onFinalResult,
    this.onPartialResult,
    this.onStateChanged,
  }) : _stateMachine = VoiceSessionStateMachine(),
       _audioRecorder = AudioRecorder(),
       _vadService = RealtimeVADService(),
       _asrService = VoiceRecognitionEngine(),
       _ttsService = TTSService() {
    _setupStateListener();
  }

  void _setupStateListener() {
    _stateMachine.stateStream.listen((state) {
      onStateChanged?.call(state);
      _configureServicesForState(state);
    });
  }

  /// 根据状态配置服务
  ///
  /// 这是核心逻辑：每个状态有明确的服务配置
  void _configureServicesForState(VoiceSessionState state) {
    switch (state) {
      case VoiceSessionState.idle:
        _stopAllServices();
        break;

      case VoiceSessionState.listening:
        _startRecording();
        _startVAD();
        _startASR();  // 关键：listening状态运行ASR
        break;

      case VoiceSessionState.processing:
        _stopRecording();
        _stopVAD();
        _stopASR();
        break;

      case VoiceSessionState.speaking:
        _startRecording();  // 保持录音用于VAD
        _startVAD();        // 用于打断检测
        _stopASR();         // 关键：speaking状态停止ASR，避免回声
        break;

      case VoiceSessionState.interrupted:
        _startRecording();
        _startVAD();
        _startASR();  // 恢复ASR
        break;
    }
  }

  // ========== 公共API ==========

  /// 开始会话
  Future<void> startSession() async {
    if (_stateMachine.state != VoiceSessionState.idle) {
      debugPrint('[Controller] 会话已在进行中');
      return;
    }
    _stateMachine.transition(VoiceSessionState.listening);
  }

  /// 结束会话
  Future<void> endSession() async {
    _stateMachine.transition(VoiceSessionState.idle);
  }

  /// 播放TTS响应
  Future<void> speakResponse(String text) async {
    if (!_stateMachine.transition(VoiceSessionState.speaking)) {
      return;
    }

    try {
      await _ttsService.speak(text);
      // TTS完成，恢复监听
      // 注意：这里不需要延迟！因为ASR已经停止，没有回声
      _stateMachine.transition(VoiceSessionState.listening);
    } catch (e) {
      debugPrint('[Controller] TTS失败: $e');
      _stateMachine.transition(VoiceSessionState.listening);
    }
  }

  // ========== 私有方法 ==========

  void _startRecording() async {
    if (_audioStreamController != null) return;

    _audioStreamController = StreamController<Uint8List>.broadcast();

    await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      (data) {
        _audioStreamController?.add(data);
        // 同时发送到VAD
        if (_stateMachine.shouldRunVAD) {
          _vadService.processAudioFrame(data);
        }
      },
    );
  }

  void _stopRecording() {
    _audioRecorder.stop();
    _audioStreamController?.close();
    _audioStreamController = null;
  }

  void _startVAD() {
    _vadSubscription?.cancel();
    _vadSubscription = _vadService.eventStream.listen(_handleVADEvent);
  }

  void _stopVAD() {
    _vadSubscription?.cancel();
    _vadSubscription = null;
    _vadService.reset();
  }

  void _startASR() {
    if (_audioStreamController == null) return;

    _asrSubscription?.cancel();
    _asrSubscription = _asrService
        .transcribeStream(_audioStreamController!.stream)
        .listen(_handleASRResult);
  }

  void _stopASR() {
    _asrSubscription?.cancel();
    _asrSubscription = null;
  }

  void _stopAllServices() {
    _stopASR();
    _stopVAD();
    _stopRecording();
    _ttsService.stop();
  }

  /// 处理VAD事件
  void _handleVADEvent(VADEvent event) {
    switch (event.type) {
      case VADEventType.speechStart:
        _speechStartTime = DateTime.now();
        // 如果正在播放TTS，检查是否应该打断
        if (_stateMachine.isInterruptible) {
          _checkInterruption();
        }
        break;

      case VADEventType.speechEnd:
        _speechStartTime = null;
        break;

      default:
        break;
    }
  }

  /// 检查是否应该打断TTS
  void _checkInterruption() {
    if (_speechStartTime == null) return;
    if (!_stateMachine.isInterruptible) return;

    final duration = DateTime.now().difference(_speechStartTime!);
    if (duration >= _minInterruptionDuration) {
      debugPrint('[Controller] 检测到打断，停止TTS');
      _ttsService.stop();
      _stateMachine.transition(VoiceSessionState.interrupted);
    } else {
      // 继续检查
      Future.delayed(const Duration(milliseconds: 100), _checkInterruption);
    }
  }

  /// 处理ASR结果
  void _handleASRResult(ASRResult result) {
    // 只在应该运行ASR的状态下处理结果
    if (!_stateMachine.shouldRunASR) {
      debugPrint('[Controller] 忽略ASR结果（当前状态不接收）: ${result.text}');
      return;
    }

    if (result.isFinal && result.text.isNotEmpty) {
      // 转换到处理状态
      _stateMachine.transition(VoiceSessionState.processing);
      onFinalResult?.call(result.text);
    } else {
      onPartialResult?.call(result.text);
    }
  }

  void dispose() {
    _stopAllServices();
    _stateMachine.dispose();
  }
}
```

## 3. 集成方案

### 3.1 GlobalVoiceAssistantManager 改造

```dart
class GlobalVoiceAssistantManager extends ChangeNotifier {
  // 新增：会话控制器
  VoiceSessionController? _sessionController;

  // 移除的标志位：
  // - _isProcessingCommand ❌
  // - _isTTSPlayingWithBargeIn ❌
  // - _isProactiveConversation ❌
  // - _isRestartingASR ❌

  // 保持的接口：
  Future<void> startRecording() async {
    await _ensureControllerInitialized();
    await _sessionController!.startSession();
    setBallState(FloatingBallState.recording);
  }

  Future<void> stopRecording() async {
    await _sessionController?.endSession();
    setBallState(FloatingBallState.idle);
  }

  // 命令处理
  Future<void> _handleFinalASRResult(String text) async {
    _addUserMessage(text);

    // 调用命令处理器
    final response = await _commandProcessor?.call(text);

    if (response != null && response.isNotEmpty) {
      _addAssistantMessage(response);
      // 使用控制器播放TTS（自动处理状态转换和回声消除）
      await _sessionController!.speakResponse(response);
    }
  }

  Future<void> _ensureControllerInitialized() async {
    if (_sessionController != null) return;

    _sessionController = VoiceSessionController(
      onFinalResult: _handleFinalASRResult,
      onPartialResult: (text) {
        _partialText = text;
        notifyListeners();
      },
      onStateChanged: (state) {
        debugPrint('[GlobalVoiceAssistant] 会话状态: $state');
      },
    );
  }
}
```

## 4. 时序图

### 4.1 正常对话流程

```
用户        Controller    StateMachine    ASR       VAD       TTS
 │              │              │           │         │         │
 │ 点击开始     │              │           │         │         │
 │─────────────>│              │           │         │         │
 │              │─ transition ─>│ LISTENING │         │         │
 │              │              │           │         │         │
 │              │──────────────────────────>│ start   │         │
 │              │─────────────────────────────────────>│ start  │
 │              │              │           │         │         │
 │  "记一笔"   │              │           │         │         │
 │~~~~~~~~~~~~~~│~~~~~~~~~~~~~~│~~~~~~~~~~~│         │         │
 │              │              │           │ result  │         │
 │              │<─────────────────────────│ final   │         │
 │              │              │           │         │         │
 │              │─ transition ─>│PROCESSING │         │         │
 │              │──────────────────────────>│ STOP    │         │ ← 关键！
 │              │─────────────────────────────────────>│ STOP   │
 │              │              │           │         │         │
 │              │  处理命令... │           │         │         │
 │              │              │           │         │         │
 │              │─ transition ─>│ SPEAKING  │         │         │
 │              │─────────────────────────────────────>│ start  │ ← VAD继续
 │              │─────────────────────────────────────────────────>│ speak
 │              │              │           │         │         │
 │              │              │           │  (ASR停止,无回声)  │
 │              │              │           │         │         │
 │              │<────────────────────────────────────────────────│ done
 │              │─ transition ─>│ LISTENING │         │         │
 │              │──────────────────────────>│ start   │         │ ← 恢复ASR
 │              │              │           │         │         │
```

### 4.2 打断流程

```
用户        Controller    StateMachine    ASR       VAD       TTS
 │              │              │           │         │         │
 │              │              │ SPEAKING  │ STOPPED │ running │ playing
 │              │              │           │         │         │
 │  "停"       │              │           │         │         │
 │~~~~~~~~~~~~~~│~~~~~~~~~~~~~~│~~~~~~~~~~~│         │         │
 │              │              │           │         │ speech  │
 │              │<────────────────────────────────────│ start   │
 │              │              │           │         │         │
 │              │  等待500ms   │           │         │         │
 │              │              │           │         │         │
 │              │  确认打断    │           │         │         │
 │              │─────────────────────────────────────────────────>│ STOP
 │              │─ transition ─>│INTERRUPTED│         │         │
 │              │──────────────────────────>│ start   │         │ ← 恢复ASR
 │              │              │           │         │         │
 │  继续说话... │              │           │         │         │
 │~~~~~~~~~~~~~~│~~~~~~~~~~~~~~│~~~~~~~~~~~│         │         │
 │              │              │           │ result  │         │
 │              │<─────────────────────────│ final   │         │
 │              │              │           │         │         │
```

## 5. 测试计划

### 5.1 单元测试
- 状态机转换测试
- 服务配置测试（每个状态的服务启停）

### 5.2 集成测试
- 正常对话流程
- 打断流程
- 快速连续操作

### 5.3 真机测试
- 回声消除验证
- 打断响应时间
- 长时间使用稳定性
