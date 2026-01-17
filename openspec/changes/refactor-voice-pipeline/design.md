# 语音处理流水线重构 - 架构设计

## 1. 整体架构

### 1.1 当前架构 vs 目标架构

**当前架构（串行模式）**：
```
用户说话 → ASR识别 → 等待完成 → LLM生成 → 等待完成 → TTS合成 → 等待完成 → 播放
                                                              │
                                                         总延迟：3-5秒
```

**目标架构（流水线模式）**：
```
                    ┌─────────────────────────────────────────────────────────┐
                    │              VoicePipelineController                     │
                    │                   (核心控制器)                            │
                    └─────────────────────────────────────────────────────────┘
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        │                                 │                                 │
        ▼                                 ▼                                 ▼
┌───────────────┐               ┌───────────────┐               ┌───────────────┐
│   输入流水线   │               │   处理流水线   │               │   输出流水线   │
│               │               │               │               │               │
│ ┌───────────┐ │               │ ┌───────────┐ │               │ ┌───────────┐ │
│ │ VAD检测   │ │               │ │ LLM生成   │ │               │ │句子缓冲区 │ │
│ └─────┬─────┘ │               │ └─────┬─────┘ │               │ └─────┬─────┘ │
│       ▼       │               │       ▼       │               │       ▼       │
│ ┌───────────┐ │               │ ┌───────────┐ │               │ ┌───────────┐ │
│ │ ASR识别   │ │ ────────────▶ │ │意图识别   │ │ ────────────▶ │ │TTS队列   │ │
│ └─────┬─────┘ │               │ └─────┬─────┘ │               │ └─────┬─────┘ │
│       ▼       │               │       ▼       │               │       ▼       │
│ ┌───────────┐ │               │ ┌───────────┐ │               │ ┌───────────┐ │
│ │打断检测   │ │               │ │操作执行   │ │               │ │音频播放  │ │
│ └───────────┘ │               │ └───────────┘ │               │ └───────────┘ │
└───────────────┘               └───────────────┘               └───────────────┘
        │                                                               │
        │                      ┌───────────────┐                        │
        └─────────────────────▶│   回声过滤    │◀───────────────────────┘
                               └───────────────┘
```

### 1.2 核心设计原则

1. **并行优先**：能并行的绝不串行
2. **流式处理**：数据到达即处理，不等待完整输入
3. **快速响应**：优先保证用户感知的响应速度
4. **优雅降级**：任何环节失败都有备选方案

## 2. 核心组件设计

### 2.1 VoicePipelineController（流水线控制器）

```dart
/// 语音流水线控制器
///
/// 核心职责：
/// - 协调输入、处理、输出三条流水线
/// - 管理会话状态
/// - 处理打断和异常
class VoicePipelineController {
  // 状态
  PipelineState _state = PipelineState.idle;

  // 响应追踪（防竞态）
  final ResponseTracker _responseTracker = ResponseTracker();

  // 三条流水线
  late final InputPipeline _inputPipeline;
  late final ProcessingPipeline _processingPipeline;
  late final OutputPipeline _outputPipeline;

  // 回声过滤
  late final EchoFilter _echoFilter;

  // 打断检测
  late final BargeInDetectorV2 _bargeInDetector;

  /// 启动流水线
  Future<void> start() async {
    _state = PipelineState.listening;

    // 1. 启动输入流水线（持续监听）
    _inputPipeline.start(
      onPartialResult: _handlePartialASR,
      onFinalResult: _handleFinalASR,
      onSpeechStart: _handleSpeechStart,
      onSpeechEnd: _handleSpeechEnd,
    );

    // 2. 启动回声过滤（与输出流水线联动）
    _echoFilter.start();

    // 3. 启动打断检测
    _bargeInDetector.start(
      onBargeIn: _handleBargeIn,
    );
  }

  /// 处理用户输入
  Future<void> _processUserInput(String text) async {
    final responseId = _responseTracker.startNewResponse();
    _state = PipelineState.processing;

    // 启动输出流水线（准备接收LLM输出）
    _outputPipeline.start(responseId);

    // 处理流水线生成响应
    await _processingPipeline.process(
      text,
      onChunk: (chunk) {
        if (_responseTracker.isCurrentResponse(responseId)) {
          _outputPipeline.addChunk(chunk);
        }
      },
      onComplete: (fullText) {
        if (_responseTracker.isCurrentResponse(responseId)) {
          _outputPipeline.complete();
        }
      },
    );
  }

  /// 处理打断
  Future<void> _handleBargeIn() async {
    // 1. 立即停止输出
    await _outputPipeline.stop();

    // 2. 取消当前处理
    _processingPipeline.cancel();

    // 3. 回到监听状态
    _state = PipelineState.listening;
  }
}

enum PipelineState {
  idle,       // 空闲
  listening,  // 监听中
  processing, // 处理中
  speaking,   // 说话中
  closing,    // 关闭中
}
```

### 2.2 SentenceBuffer（句子缓冲区）

```dart
/// 句子缓冲区
///
/// 职责：从LLM流式输出中检测完整句子
class SentenceBuffer {
  final StringBuffer _buffer = StringBuffer();

  // 句子分隔符
  static const _delimiters = ['。', '！', '？', '；', '\n'];

  // 最小句子长度（避免过短的句子）
  static const _minSentenceLength = 4;

  /// 添加文本块
  ///
  /// 返回检测到的完整句子（可能为空）
  String? addChunk(String chunk) {
    _buffer.write(chunk);

    final text = _buffer.toString();

    // 检测句子边界
    for (final delimiter in _delimiters) {
      final index = text.indexOf(delimiter);
      if (index >= 0) {
        final sentence = text.substring(0, index + 1);
        final remaining = text.substring(index + 1);

        // 更新缓冲区
        _buffer.clear();
        _buffer.write(remaining);

        // 检查最小长度
        if (sentence.trim().length >= _minSentenceLength) {
          return sentence.trim();
        }
      }
    }

    return null;
  }

  /// 获取剩余文本
  String flush() {
    final remaining = _buffer.toString().trim();
    _buffer.clear();
    return remaining;
  }

  /// 清空缓冲区
  void clear() {
    _buffer.clear();
  }
}
```

### 2.3 TTSQueueWorker（TTS队列工作器）

```dart
/// TTS队列工作器
///
/// 职责：
/// - 从队列中获取句子
/// - 流式合成音频
/// - 管理播放状态
class TTSQueueWorker {
  final StreamingTTSService _ttsService;
  final AudioStreamPlayer _audioPlayer;

  final Queue<_TTSTask> _queue = Queue();
  bool _isWorking = false;
  bool _isStopped = false;

  int _currentResponseId = 0;
  String _currentTTSText = '';  // 用于回声过滤

  /// 当前正在播放的TTS文本
  String get currentTTSText => _currentTTSText;

  /// 添加句子到队列
  void enqueue(String sentence, int responseId) {
    _queue.add(_TTSTask(sentence, responseId));
    _startWorkerIfNeeded();
  }

  /// 启动工作器
  void _startWorkerIfNeeded() {
    if (_isWorking || _isStopped) return;

    _isWorking = true;
    _processQueue();
  }

  /// 处理队列
  Future<void> _processQueue() async {
    while (_queue.isNotEmpty && !_isStopped) {
      final task = _queue.removeFirst();

      // 检查响应ID是否过期
      if (task.responseId != _currentResponseId) {
        continue;
      }

      // 更新当前TTS文本（用于回声过滤）
      _currentTTSText += task.sentence;

      // 流式合成并播放
      try {
        await for (final audioChunk in _ttsService.synthesizeStream(task.sentence)) {
          if (_isStopped) break;
          await _audioPlayer.playChunk(audioChunk);
        }
      } catch (e) {
        debugPrint('TTS合成失败: $e');
        // 降级到离线TTS
        await _fallbackToOfflineTTS(task.sentence);
      }
    }

    _isWorking = false;
  }

  /// 停止（用于打断）
  Future<void> stop() async {
    _isStopped = true;
    _queue.clear();
    await _audioPlayer.stop();
    _currentTTSText = '';
  }

  /// 重置（用于新响应）
  void reset(int responseId) {
    _currentResponseId = responseId;
    _currentTTSText = '';
    _isStopped = false;
    _queue.clear();
  }
}

class _TTSTask {
  final String sentence;
  final int responseId;

  _TTSTask(this.sentence, this.responseId);
}
```

### 2.4 BargeInDetectorV2（三层打断检测器）

```dart
/// 三层打断检测器
///
/// 层级设计：
/// - 第1层：VAD + ASR中间结果（最快，~200ms）
/// - 第2层：纯ASR中间结果（~500ms）
/// - 第3层：完整句子 + 四层回声过滤（~1000ms）
class BargeInDetectorV2 {
  final SimilarityCalculator _similarity = SimilarityCalculator();

  // 配置
  static const _layer1MinChars = 4;    // 第1层最小字符数
  static const _layer1Threshold = 0.4; // 第1层相似度阈值
  static const _layer2MinChars = 8;    // 第2层最小字符数
  static const _layer2Threshold = 0.3; // 第2层相似度阈值
  static const _cooldownDuration = Duration(milliseconds: 1500);

  // 状态
  bool _isTTSPlaying = false;
  DateTime? _lastInterruptTime;
  String _currentTTSText = '';
  bool _vadSpeechDetected = false;

  // 回调
  VoidCallback? onBargeIn;

  /// 更新TTS状态
  void updateTTSState({
    required bool isPlaying,
    required String currentText,
  }) {
    _isTTSPlaying = isPlaying;
    _currentTTSText = currentText;
  }

  /// 更新VAD状态
  void updateVADState(bool isSpeechDetected) {
    _vadSpeechDetected = isSpeechDetected;
  }

  /// 处理ASR中间结果
  void handlePartialResult(String text) {
    if (!_isTTSPlaying || !_canInterrupt()) return;

    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return;

    // 第1层：VAD + ASR联合（最快）
    if (_vadSpeechDetected && cleanText.length >= _layer1MinChars) {
      final similarity = _similarity.calculate(cleanText, _currentTTSText);
      if (similarity < _layer1Threshold) {
        debugPrint('[BargeIn] 第1层触发: VAD+ASR, 文本="$cleanText", 相似度=$similarity');
        _triggerBargeIn();
        return;
      }
    }

    // 第2层：纯ASR中间结果
    if (cleanText.length >= _layer2MinChars) {
      final similarity = _similarity.calculate(cleanText, _currentTTSText);
      if (similarity < _layer2Threshold) {
        debugPrint('[BargeIn] 第2层触发: ASR, 文本="$cleanText", 相似度=$similarity');
        _triggerBargeIn();
        return;
      }
    }
  }

  /// 处理ASR最终结果（第3层）
  void handleFinalResult(String text) {
    if (!_isTTSPlaying || !_canInterrupt()) return;

    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return;

    // 四层回声过滤
    if (_isEcho(cleanText)) {
      debugPrint('[BargeIn] 第3层: 识别为回声，忽略');
      return;
    }

    debugPrint('[BargeIn] 第3层触发: 完整句子="$cleanText"');
    _triggerBargeIn();
  }

  /// 四层回声过滤
  bool _isEcho(String text) {
    // 1. 子串匹配
    if (_currentTTSText.contains(text) || text.contains(_currentTTSText)) {
      return true;
    }

    // 2. 高相似度
    final similarity = _similarity.calculate(text, _currentTTSText);
    if (similarity > 0.6) {
      return true;
    }

    // 3. 过短文本（可能是回声片段）
    if (text.length < 3) {
      return true;
    }

    // 4. 常见回声模式
    if (_isCommonEchoPattern(text)) {
      return true;
    }

    return false;
  }

  bool _isCommonEchoPattern(String text) {
    // 检查是否与TTS文本的开头或结尾高度相似
    final ttsWords = _currentTTSText.split('');
    final textWords = text.split('');

    if (textWords.isEmpty || ttsWords.isEmpty) return false;

    // 检查前缀匹配
    var prefixMatch = 0;
    for (var i = 0; i < textWords.length && i < ttsWords.length; i++) {
      if (textWords[i] == ttsWords[i]) {
        prefixMatch++;
      } else {
        break;
      }
    }

    return prefixMatch > textWords.length * 0.5;
  }

  bool _canInterrupt() {
    if (_lastInterruptTime == null) return true;
    return DateTime.now().difference(_lastInterruptTime!) > _cooldownDuration;
  }

  void _triggerBargeIn() {
    _lastInterruptTime = DateTime.now();
    onBargeIn?.call();
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[。，！？；,.!?;\s]'), '').trim();
  }
}
```

### 2.5 SimilarityCalculator（相似度计算器）

```dart
/// 文本相似度计算器
///
/// 使用多种算法综合计算相似度
class SimilarityCalculator {
  /// 计算两段文本的相似度
  ///
  /// 返回值：0.0（完全不同）~ 1.0（完全相同）
  double calculate(String text1, String text2) {
    final clean1 = _normalize(text1);
    final clean2 = _normalize(text2);

    if (clean1.isEmpty || clean2.isEmpty) return 0.0;

    // 1. 子串匹配（最高优先级）
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      return 1.0;
    }

    // 2. Jaccard相似度
    final set1 = clean1.split('').toSet();
    final set2 = clean2.split('').toSet();
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    final jaccard = union > 0 ? intersection / union : 0.0;

    // 3. 最长公共子串比率
    final lcsRatio = _longestCommonSubstringRatio(clean1, clean2);

    // 取最大值
    return [jaccard, lcsRatio].reduce((a, b) => a > b ? a : b);
  }

  String _normalize(String text) {
    return text.replaceAll(RegExp(r'[。，！？；,.!?;\s]'), '').toLowerCase();
  }

  double _longestCommonSubstringRatio(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    var maxLen = 0;
    final m = s1.length;
    final n = s2.length;

    // 简化实现：滑动窗口
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        var len = 0;
        while (i + len < m && j + len < n && s1[i + len] == s2[j + len]) {
          len++;
        }
        maxLen = maxLen > len ? maxLen : len;
      }
    }

    final minLen = m < n ? m : n;
    return minLen > 0 ? maxLen / minLen : 0.0;
  }
}
```

### 2.6 EchoFilter（回声过滤器）

```dart
/// 回声过滤器
///
/// 四层回声防护：
/// 1. 硬件级AEC（录音配置）
/// 2. 文本相似度过滤
/// 3. 短句过滤
/// 4. 静默窗口
class EchoFilter {
  final SimilarityCalculator _similarity = SimilarityCalculator();

  // 配置
  static const _silenceWindowDuration = Duration(milliseconds: 500);
  static const _minTextLength = 3;
  static const _similarityThreshold = 0.5;

  // 状态
  String _lastTTSText = '';
  DateTime? _ttsEndTime;

  /// 更新TTS状态
  void onTTSStarted(String text) {
    _lastTTSText = text;
    _ttsEndTime = null;
  }

  void onTTSStopped() {
    _ttsEndTime = DateTime.now();
  }

  /// 判断ASR结果是否为回声
  bool isEcho(String asrText) {
    // 1. 静默窗口内的结果可能是回声
    if (_isInSilenceWindow()) {
      debugPrint('[EchoFilter] 在静默窗口内，标记为可疑');
      // 不直接判定为回声，而是提高警惕
    }

    // 2. 短文本过滤
    if (asrText.length < _minTextLength) {
      debugPrint('[EchoFilter] 文本过短，忽略: "$asrText"');
      return true;
    }

    // 3. 相似度过滤
    final similarity = _similarity.calculate(asrText, _lastTTSText);
    if (similarity > _similarityThreshold) {
      debugPrint('[EchoFilter] 高相似度($similarity)，判定为回声: "$asrText"');
      return true;
    }

    return false;
  }

  bool _isInSilenceWindow() {
    if (_ttsEndTime == null) return false;
    return DateTime.now().difference(_ttsEndTime!) < _silenceWindowDuration;
  }

  /// 清除状态
  void reset() {
    _lastTTSText = '';
    _ttsEndTime = null;
  }
}
```

### 2.7 ResponseTracker（响应追踪器）

```dart
/// 响应ID追踪器
///
/// 防止竞态条件：
/// - 用户打断后，旧响应的TTS不应继续播放
/// - 新响应开始后，旧响应的完成事件不应影响状态
class ResponseTracker {
  int _currentId = 0;

  /// 开始新响应
  ///
  /// 返回新的响应ID
  int startNewResponse() {
    _currentId++;
    debugPrint('[ResponseTracker] 新响应ID: $_currentId');
    return _currentId;
  }

  /// 检查是否为当前响应
  bool isCurrentResponse(int id) {
    return id == _currentId;
  }

  /// 获取当前响应ID
  int get currentId => _currentId;

  /// 取消当前响应
  ///
  /// 使当前ID失效，但不分配新ID
  void cancelCurrentResponse() {
    debugPrint('[ResponseTracker] 取消响应: $_currentId');
    _currentId++;
  }
}
```

## 3. 数据流设计

### 3.1 正常对话流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 时间线                                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ t=0ms     用户开始说话                                                       │
│           VAD检测到语音 → speechStart事件                                    │
│                                                                             │
│ t=200ms   ASR返回中间结果: "今天"                                            │
│           → 更新UI显示                                                       │
│                                                                             │
│ t=500ms   ASR返回中间结果: "今天花了"                                         │
│           → 更新UI显示                                                       │
│                                                                             │
│ t=1200ms  用户停止说话 (静音1200ms)                                          │
│           VAD检测到静音 → speechEnd事件                                      │
│                                                                             │
│ t=1300ms  ASR返回最终结果: "今天花了多少钱"                                    │
│           → ResponseTracker.startNewResponse() 获取ID=1                     │
│           → 启动ProcessingPipeline                                          │
│           → 启动OutputPipeline                                              │
│                                                                             │
│ t=1500ms  LLM开始流式生成: "让"                                              │
│           → SentenceBuffer.addChunk("让") → 无完整句子                       │
│                                                                             │
│ t=1600ms  LLM继续生成: "让我帮你"                                             │
│           → SentenceBuffer.addChunk("我帮你") → 无完整句子                   │
│                                                                             │
│ t=1800ms  LLM继续生成: "让我帮你看看。"                                        │
│           → SentenceBuffer.addChunk("看看。") → 返回"让我帮你看看。"          │
│           → TTSQueueWorker.enqueue("让我帮你看看。", 1)                      │
│                                                                             │
│ t=1900ms  TTS开始合成第一个句子                                               │
│           → EchoFilter.onTTSStarted("让我帮你看看。")                        │
│           → BargeInDetector.updateTTSState(isPlaying: true)                 │
│                                                                             │
│ t=2100ms  TTS首个音频块就绪                                                   │
│           → AudioPlayer开始播放                                              │
│           → 首字延迟 = 2100 - 1300 = 800ms ✓                                │
│                                                                             │
│ t=2200ms  LLM继续生成: "今天你一共花了"                                        │
│           → SentenceBuffer.addChunk(...) → 无完整句子                        │
│                                                                             │
│ t=2500ms  LLM生成完成: "今天你一共花了256元。"                                 │
│           → SentenceBuffer.addChunk("256元。") → 返回句子                    │
│           → TTSQueueWorker.enqueue("今天你一共花了256元。", 1)               │
│           → SentenceBuffer.flush() → 无剩余                                  │
│                                                                             │
│ t=3500ms  第一个句子播放完成                                                  │
│           → TTS队列工作器自动处理下一个句子                                    │
│                                                                             │
│ t=5000ms  所有句子播放完成                                                    │
│           → EchoFilter.onTTSStopped()                                       │
│           → 等待500ms静默窗口                                                │
│                                                                             │
│ t=5500ms  回到监听状态                                                        │
│           → 准备接收下一轮输入                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 打断流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 打断场景时间线                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ t=0ms     TTS正在播放: "今天你一共花了256元..."                                │
│                                                                             │
│ t=100ms   用户开始说话                                                       │
│           VAD检测到语音 → vadSpeechDetected = true                          │
│                                                                             │
│ t=200ms   ASR返回中间结果: "不对"                                             │
│           → BargeInDetector.handlePartialResult("不对")                     │
│           → 第1层检测: VAD=true, 长度=2 < 4, 不触发                          │
│                                                                             │
│ t=350ms   ASR返回中间结果: "不对，是"                                          │
│           → BargeInDetector.handlePartialResult("不对，是")                  │
│           → 第1层检测: VAD=true, 长度=4 ≥ 4                                  │
│           → 计算相似度("不对是", "今天你一共花了256元") = 0.1 < 0.4           │
│           → 触发打断！                                                       │
│                                                                             │
│ t=360ms   执行打断                                                           │
│           → TTSQueueWorker.stop()                                           │
│           → AudioPlayer.stop()                                              │
│           → ProcessingPipeline.cancel()                                     │
│           → ResponseTracker.cancelCurrentResponse()                         │
│                                                                             │
│ t=400ms   回到监听状态                                                        │
│           → 打断响应时间 = 400 - 100 = 300ms ✓                              │
│                                                                             │
│ t=800ms   ASR返回最终结果: "不对，是昨天的"                                    │
│           → 开始处理用户新输入                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 4. 文件结构

```
app/lib/services/voice/
├── pipeline/                           # 流水线核心
│   ├── voice_pipeline_controller.dart  # 流水线控制器
│   ├── input_pipeline.dart             # 输入流水线
│   ├── processing_pipeline.dart        # 处理流水线
│   ├── output_pipeline.dart            # 输出流水线
│   ├── sentence_buffer.dart            # 句子缓冲区
│   └── tts_queue_worker.dart           # TTS队列工作器
│
├── detection/                          # 检测器
│   ├── barge_in_detector_v2.dart       # 三层打断检测器
│   ├── echo_filter.dart                # 回声过滤器
│   └── similarity_calculator.dart      # 相似度计算器
│
├── tracking/                           # 追踪器
│   └── response_tracker.dart           # 响应ID追踪器
│
└── config/                             # 配置
    └── pipeline_config.dart            # 流水线配置
```

## 5. 与现有代码的集成

### 5.1 GlobalVoiceAssistantManager 改造

```dart
class GlobalVoiceAssistantManager extends ChangeNotifier {
  // 新增：流水线控制器
  VoicePipelineController? _pipelineController;

  // 保留：基础状态管理
  FloatingBallState _ballState = FloatingBallState.idle;

  /// 开始录音（重构后）
  Future<void> startRecording() async {
    // ... 权限检查 ...

    // 初始化流水线
    _pipelineController ??= VoicePipelineController(
      asrService: _recognitionEngine!,
      ttsService: _ttsService!,
      vadService: _vadService!,
      commandProcessor: _commandProcessor,
    );

    // 启动流水线
    await _pipelineController!.start();

    setBallState(FloatingBallState.recording);
  }

  /// 停止录音
  Future<void> stopRecording() async {
    await _pipelineController?.stop();
    setBallState(FloatingBallState.idle);
  }
}
```

### 5.2 迁移策略

1. **阶段1**：实现核心组件，不修改现有代码
2. **阶段2**：添加功能开关，可切换新旧实现
3. **阶段3**：验证通过后，逐步迁移到新实现
4. **阶段4**：移除旧代码

## 6. 性能优化要点

### 6.1 减少内存分配

```dart
// 使用对象池复用音频缓冲区
class AudioBufferPool {
  final List<Uint8List> _pool = [];
  static const _bufferSize = 3200; // 100ms @ 16kHz

  Uint8List acquire() {
    if (_pool.isNotEmpty) {
      return _pool.removeLast();
    }
    return Uint8List(_bufferSize);
  }

  void release(Uint8List buffer) {
    if (_pool.length < 10) {
      _pool.add(buffer);
    }
  }
}
```

### 6.2 异步处理优化

```dart
// 使用 compute 隔离 CPU 密集计算
Future<double> calculateSimilarityIsolate(String text1, String text2) {
  return compute(_calculateSimilarity, [text1, text2]);
}

double _calculateSimilarity(List<String> args) {
  final calculator = SimilarityCalculator();
  return calculator.calculate(args[0], args[1]);
}
```

### 6.3 节流与防抖

```dart
// 打断检测节流
class ThrottledBargeInDetector {
  DateTime? _lastCheck;
  static const _minInterval = Duration(milliseconds: 100);

  void check(String text) {
    final now = DateTime.now();
    if (_lastCheck != null &&
        now.difference(_lastCheck!) < _minInterval) {
      return; // 跳过本次检测
    }
    _lastCheck = now;
    // 执行检测...
  }
}
```

## 7. 测试策略

### 7.1 单元测试

- SentenceBuffer 句子分割测试
- SimilarityCalculator 相似度计算测试
- BargeInDetectorV2 打断检测测试
- EchoFilter 回声过滤测试

### 7.2 集成测试

- 完整对话流程测试
- 打断场景测试
- 回声防护测试
- 异常恢复测试

### 7.3 性能测试

- 首字延迟测量
- 打断响应时间测量
- CPU/内存占用监控
