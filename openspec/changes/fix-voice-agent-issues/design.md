# 技术设计文档

## 上下文

语音智能体是应用的核心功能模块，包含多个协同工作的组件：
- `IntelligenceEngine` - 核心智能引擎
- `ProactiveConversationManager` - 主动对话管理
- `VoicePipelineController` - 语音流水线控制
- `VoiceSessionController` - 会话状态控制
- `DualChannelProcessor` - 双通道处理器

当前实现存在严重的逻辑错误和并发问题，需要系统性修复。

## 目标 / 非目标

### 目标
- 修复所有已识别的严重和高优先级问题
- 提高代码健壮性和可维护性
- 保持向后兼容，不改变外部 API
- 添加必要的测试覆盖

### 非目标
- 重构整体架构
- 添加新功能
- 优化性能（除非与修复相关）

## 决策

### 决策 1：主动对话计数重置控制

**方案**: 添加 `isUserInitiated` 参数区分用户输入和系统响应

```dart
// 修改后的 resetTimer 方法
void resetTimer({bool isUserInitiated = true}) {
  _silenceTimer?.cancel();

  if (isUserInitiated) {
    // 只有用户主动输入才重置计数
    _totalSilenceTimer?.cancel();
    _totalSilenceTimer = null;

    if (_proactiveCount > 0) {
      debugPrint('[ProactiveConversationManager] 用户响应，重置计数');
      _proactiveCount = 0;
    }
  }
  // 系统延迟响应不重置计数，只重启静默计时器

  _state = ProactiveState.idle;
  startSilenceMonitoring();
}
```

**调用方修改**:
```dart
// VoicePipelineController - deferred响应
_proactiveManager.resetTimer(isUserInitiated: false);

// GlobalVoiceAssistantManager - 用户输入
_proactiveManager.resetTimer(isUserInitiated: true);
```

**考虑的替代方案**:
- 使用事件类型枚举 - 更复杂，当前场景不需要
- 分离两个方法 - 会增加API复杂度

---

### 决策 2：30秒计时器重启机制

**方案**: 修改 `startSilenceMonitoring()` 逻辑

```dart
void startSilenceMonitoring() {
  // 启动5秒静默计时器
  _silenceTimer?.cancel();
  _silenceTimer = Timer(
    Duration(milliseconds: _silenceThresholdMs),
    _triggerProactiveMessage,
  );

  // 始终确保30秒总计时器存在
  // 如果已经在运行，不重新创建（保持原有计时）
  // 如果不存在，创建新的
  if (_totalSilenceTimer == null) {
    _totalSilenceStartTime = DateTime.now();
    _totalSilenceTimer = Timer(
      Duration(milliseconds: _maxTotalSilenceMs),
      _triggerSessionEnd,
    );
  }
}

void resetTimer({bool isUserInitiated = true}) {
  _silenceTimer?.cancel();

  if (isUserInitiated) {
    // 用户输入：重置30秒计时器
    _totalSilenceTimer?.cancel();
    _totalSilenceTimer = null;  // 设为null，下次startSilenceMonitoring会重建
    _totalSilenceStartTime = null;
    _proactiveCount = 0;
  }
  // 注意：不设置 _totalSilenceTimer = null，保持计时继续

  _state = ProactiveState.idle;
  startSilenceMonitoring();
}
```

---

### 决策 3：Deferred操作最大等待时间

**方案**: 添加最大等待时间限制，使用双计时器机制

```dart
static const int _deferredWaitMs = 2500;      // 滑动窗口
static const int _maxDeferredWaitMs = 10000;  // 最大等待时间

DateTime? _deferredStartTime;
Timer? _deferredTimer;
Timer? _maxDeferredTimer;

void _scheduleDeferredProcessing() {
  // 记录首次缓存时间
  _deferredStartTime ??= DateTime.now();

  // 滑动窗口计时器（每次输入重置）
  _deferredTimer?.cancel();
  _deferredTimer = Timer(
    Duration(milliseconds: _deferredWaitMs),
    _processDeferredOperations,
  );

  // 最大等待计时器（只在首次创建）
  _maxDeferredTimer ??= Timer(
    Duration(milliseconds: _maxDeferredWaitMs),
    () {
      debugPrint('[IntelligenceEngine] 达到最大等待时间，强制执行');
      _processDeferredOperations();
    },
  );
}

void _processDeferredOperations() {
  // 清理计时器
  _deferredTimer?.cancel();
  _deferredTimer = null;
  _maxDeferredTimer?.cancel();
  _maxDeferredTimer = null;
  _deferredStartTime = null;

  // 执行缓存的操作...
}
```

**考虑的替代方案**:
- 只用最大等待时间，不用滑动窗口 - 用户体验差，快速连续输入会被打断
- 根据操作数量动态调整 - 增加复杂度，收益不明显

---

### 决策 4：状态竞态保护

**方案**: 使用状态版本号 + 处理锁

```dart
int _stateVersion = 0;
bool _isProcessingResult = false;

void _onASRResult(ASRPartialResult result) {
  if (_stateMachine.state != VoiceSessionState.listening) {
    return;
  }

  if (result.isFinal && result.text.isNotEmpty) {
    _processFinalResult(result.text);
  }
}

Future<void> _processFinalResult(String text) async {
  // 防止并发处理
  if (_isProcessingResult) {
    debugPrint('[Controller] 已有处理中，忽略');
    return;
  }

  _isProcessingResult = true;
  final currentVersion = ++_stateVersion;

  try {
    // 立即转换状态，防止后续ASR结果进入
    _stateMachine.transition(VoiceSessionState.processing);

    // 异步处理...
    await _processText(text);

    // 检查版本，如果已过期则不更新状态
    if (_stateVersion != currentVersion) {
      debugPrint('[Controller] 状态版本已过期，跳过状态更新');
      return;
    }

    // 正常完成处理...
  } finally {
    _isProcessingResult = false;
  }
}
```

---

### 决策 5：音频流资源管理

**方案**: 使用标志位 + try-finally 确保清理

```dart
bool _isRecording = false;
StreamSubscription<Uint8List>? _audioSubscription;
StreamController<Uint8List>? _audioStreamController;

Future<void> _ensureRecordingStarted() async {
  if (_isRecording) {
    debugPrint('[Controller] 已在录音中，跳过');
    return;
  }

  // 确保清理旧资源
  await _cleanupRecordingResources();

  _isRecording = true;

  try {
    _audioStreamController = StreamController<Uint8List>.broadcast();

    final audioStream = await _audioRecorder.startStream(config);

    _audioSubscription = audioStream.listen(
      (data) { /* 处理音频数据 */ },
      onError: (e) {
        debugPrint('[Controller] 音频流错误: $e');
        _cleanupRecordingResources();
      },
      cancelOnError: true,
    );
  } catch (e) {
    _isRecording = false;
    await _cleanupRecordingResources();
    rethrow;
  }
}

Future<void> _cleanupRecordingResources() async {
  await _audioSubscription?.cancel();
  _audioSubscription = null;

  await _audioStreamController?.close();
  _audioStreamController = null;

  try {
    await _audioRecorder.stop();
  } catch (e) {
    debugPrint('[Controller] 停止录音器失败: $e');
  }

  _isRecording = false;
}
```

---

### 决策 6：双通道处理队列同步

**方案**: 使用简单锁机制保护队列操作（无需额外依赖）

```dart
class ExecutionChannel {
  // 队列操作锁（防止并发入队导致的竞态）
  bool _isEnqueuing = false;

  // 执行锁（防止并发执行）
  bool _isExecuting = false;

  // 等待队列（当有操作正在处理时，新操作暂存在此）
  final List<Operation> _pendingOperations = [];

  Future<void> enqueue(Operation operation) async {
    // 如果正在入队，将操作加入等待队列
    if (_isEnqueuing) {
      debugPrint('[ExecutionChannel] 检测到并发入队，操作加入等待队列');
      _pendingOperations.add(operation);
      return;
    }

    _isEnqueuing = true;

    try {
      await _enqueueInternal(operation);

      // 处理等待队列中的操作
      while (_pendingOperations.isNotEmpty) {
        final pendingOp = _pendingOperations.removeAt(0);
        await _enqueueInternal(pendingOp);
      }
    } finally {
      _isEnqueuing = false;
    }
  }

  /// 等待执行锁（简单的自旋等待）
  Future<void> _waitForExecutionLock() async {
    int waitCount = 0;
    const maxWaitMs = 5000;
    const checkIntervalMs = 10;

    while (_isExecuting) {
      waitCount++;
      if (waitCount * checkIntervalMs > maxWaitMs) {
        debugPrint('[ExecutionChannel] 等待执行锁超时，强制获取');
        break;
      }
      await Future.delayed(const Duration(milliseconds: checkIntervalMs));
    }

    _isExecuting = true;
  }
}
```

**实现说明**:
- 使用 `_isEnqueuing` 标志防止并发入队
- 使用 `_isExecuting` 标志防止并发执行
- 使用 `_pendingOperations` 列表缓存并发操作
- 所有执行方法都被 `_waitForExecutionLock()` 保护

**考虑的替代方案**:
- 使用 mutex 包 - 需要额外依赖，当前场景简单锁足够
- 使用 synchronized 包 - 功能类似，增加依赖
- 使用 Isolate - 过度设计，当前场景不需要

---

### 决策 7：网络重试机制

**方案**: 指数退避重试，区分错误类型

```dart
Future<MultiOperationResult> _recognizeWithRetry(
  String input, {
  int maxRetries = 3,
}) async {
  int attempt = 0;
  Duration delay = const Duration(milliseconds: 100);

  while (attempt < maxRetries) {
    try {
      return await _recognizer.recognize(input).timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException {
      attempt++;
      if (attempt >= maxRetries) {
        debugPrint('[IntelligenceEngine] 识别超时，降级到本地处理');
        return _fallbackToLocalRecognition(input);
      }
      debugPrint('[IntelligenceEngine] 超时重试 $attempt/$maxRetries');
      await Future.delayed(delay);
      delay *= 2; // 指数退避
    } on SocketException catch (e) {
      // 网络错误，重试
      attempt++;
      if (attempt >= maxRetries) {
        return _fallbackToLocalRecognition(input);
      }
      debugPrint('[IntelligenceEngine] 网络错误重试: $e');
      await Future.delayed(delay);
      delay *= 2;
    } catch (e) {
      // 业务错误，不重试
      debugPrint('[IntelligenceEngine] 业务错误: $e');
      return MultiOperationResult.error('识别失败: $e');
    }
  }

  return MultiOperationResult.error('重试次数耗尽');
}
```

---

### 决策 8：操作执行结果报告

**方案**: 创建结构化的执行报告

```dart
class OperationExecutionReport {
  final List<OperationResult> results;
  final int successCount;
  final int failureCount;

  OperationExecutionReport(this.results)
      : successCount = results.where((r) => r.isSuccess).length,
        failureCount = results.where((r) => !r.isSuccess).length;

  String toUserFriendlyMessage() {
    if (failureCount == 0) {
      return '已记录${successCount}笔';
    }

    final successOps = results
        .where((r) => r.isSuccess)
        .map((r) => r.description)
        .join('、');
    final failedOps = results
        .where((r) => !r.isSuccess)
        .map((r) => '${r.description}(${r.errorMessage})')
        .join('、');

    if (successCount > 0 && failureCount > 0) {
      return '已记录: $successOps；失败: $failedOps';
    }

    return '记录失败: $failedOps';
  }
}

class OperationResult {
  final int index;
  final String description;
  final bool isSuccess;
  final String? errorMessage;
  final double? amount;

  // ...
}
```

---

## 风险 / 权衡

| 风险 | 缓解措施 |
|-----|---------|
| 修改计时器逻辑可能引入新bug | 添加充分的单元测试覆盖所有边界情况 |
| Mutex 锁可能影响性能 | 监控执行时间，必要时优化锁粒度 |
| 重试机制可能延长响应时间 | 设置合理的超时和重试次数 |
| 状态版本号溢出 | 使用足够大的整数类型，或定期重置 |

## 迁移计划

1. **第一阶段**: 修复严重问题（1.1-1.3）
   - 不改变外部API
   - 可以单独部署验证

2. **第二阶段**: 修复高优先级问题（2.1-2.3）
   - 添加内部锁机制
   - 需要完整测试

3. **第三阶段**: 修复中等优先级问题（3.1-3.4）
   - 增强错误处理
   - 改进用户反馈

**回滚方案**: 所有修改都是代码层面的，可以通过 Git 回滚。建议使用特性开关控制新逻辑的启用。

## 待决问题

1. ~~`mutex` 包是否已在项目依赖中？~~ **已解决**: 使用简单锁机制，无需额外依赖
2. ~~最大等待时间 10 秒是否合适？~~ **已确认**: 使用 10 秒作为最大等待时间
3. ~~网络重试次数 3 次是否足够？~~ **已确认**: 使用 3 次重试，指数退避
4. 是否需要添加特性开关来控制新逻辑？**待讨论**

## 实施状态

| 决策 | 状态 | 说明 |
|-----|------|------|
| 决策 1: 主动对话计数重置 | ✅ 已完成 | `resetTimer(isUserInitiated)` 已实现 |
| 决策 2: 30秒计时器重启 | ✅ 已完成 | 在 `resetTimer` 中正确处理 |
| 决策 3: Deferred最大等待 | ✅ 已完成 | 10秒最大等待时间 |
| 决策 4: 状态竞态保护 | ✅ 已完成 | 状态版本号 + 处理锁 |
| 决策 5: 音频流资源管理 | ✅ 已完成 | 标志位 + try-catch 清理 |
| 决策 6: 双通道队列同步 | ✅ 已完成 | 简单锁机制 |
| 决策 7: 网络重试机制 | ✅ 已完成 | 指数退避重试 |
| 决策 8: 操作执行报告 | ✅ 已完成 | OperationExecutionReport 类 |

**所有代码修改已完成，待测试验证。**
