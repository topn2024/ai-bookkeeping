/// Pipeline Manager
///
/// 负责语音处理流水线的管理器，从 GlobalVoiceAssistantManager 中提取。
/// 遵循单一职责原则，管理语音处理的各个阶段和流程控制。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// 流水线阶段
enum PipelineStage {
  /// 空闲
  idle,

  /// 等待唤醒
  awaitingWakeWord,

  /// 正在录音
  recording,

  /// 语音识别中
  recognizing,

  /// 意图处理中
  processing,

  /// 执行操作中
  executing,

  /// 生成响应中
  responding,

  /// 播放响应中
  playing,

  /// 完成
  completed,

  /// 错误
  error,
}

/// 流水线事件类型
enum PipelineEventType {
  stageChanged,
  progress,
  completed,
  error,
  cancelled,
}

/// 流水线事件
class PipelineEvent {
  final PipelineEventType type;
  final PipelineStage? stage;
  final PipelineStage? previousStage;
  final double? progress;
  final String? message;
  final Object? error;
  final DateTime timestamp;

  const PipelineEvent({
    required this.type,
    this.stage,
    this.previousStage,
    this.progress,
    this.message,
    this.error,
    required this.timestamp,
  });

  factory PipelineEvent.stageChanged({
    required PipelineStage stage,
    PipelineStage? previousStage,
  }) =>
      PipelineEvent(
        type: PipelineEventType.stageChanged,
        stage: stage,
        previousStage: previousStage,
        timestamp: DateTime.now(),
      );

  factory PipelineEvent.progress({
    required PipelineStage stage,
    required double progress,
    String? message,
  }) =>
      PipelineEvent(
        type: PipelineEventType.progress,
        stage: stage,
        progress: progress,
        message: message,
        timestamp: DateTime.now(),
      );

  factory PipelineEvent.completed({String? message}) => PipelineEvent(
        type: PipelineEventType.completed,
        message: message,
        timestamp: DateTime.now(),
      );

  factory PipelineEvent.error({required Object error, String? message}) =>
      PipelineEvent(
        type: PipelineEventType.error,
        error: error,
        message: message,
        timestamp: DateTime.now(),
      );

  factory PipelineEvent.cancelled() => PipelineEvent(
        type: PipelineEventType.cancelled,
        timestamp: DateTime.now(),
      );
}

/// 流水线配置
class PipelineConfig {
  /// 每个阶段的超时时间（毫秒）
  final Map<PipelineStage, int> stageTimeouts;

  /// 是否启用自动重试
  final bool autoRetry;

  /// 最大重试次数
  final int maxRetries;

  /// 重试延迟（毫秒）
  final int retryDelay;

  /// 是否启用并行处理
  final bool enableParallelProcessing;

  const PipelineConfig({
    this.stageTimeouts = const {
      PipelineStage.recording: 30000,
      PipelineStage.recognizing: 10000,
      PipelineStage.processing: 15000,
      PipelineStage.executing: 20000,
      PipelineStage.responding: 10000,
      PipelineStage.playing: 60000,
    },
    this.autoRetry = true,
    this.maxRetries = 2,
    this.retryDelay = 1000,
    this.enableParallelProcessing = false,
  });

  static const defaultConfig = PipelineConfig();
}

/// 阶段处理器接口
abstract class IStageHandler {
  /// 处理阶段
  Future<StageResult> handle(StageContext context);

  /// 是否可以处理该阶段
  bool canHandle(PipelineStage stage);
}

/// 阶段上下文
class StageContext {
  final PipelineStage stage;
  final Map<String, dynamic> data;
  final DateTime startTime;

  StageContext({
    required this.stage,
    Map<String, dynamic>? data,
  })  : data = data ?? {},
        startTime = DateTime.now();

  /// 添加数据
  void set(String key, dynamic value) {
    data[key] = value;
  }

  /// 获取数据
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }

  /// 耗时（毫秒）
  int get elapsedMs => DateTime.now().difference(startTime).inMilliseconds;
}

/// 阶段处理结果
class StageResult {
  final bool success;
  final Map<String, dynamic>? output;
  final String? errorMessage;
  final PipelineStage? nextStage;

  const StageResult({
    required this.success,
    this.output,
    this.errorMessage,
    this.nextStage,
  });

  factory StageResult.success({
    Map<String, dynamic>? output,
    PipelineStage? nextStage,
  }) =>
      StageResult(
        success: true,
        output: output,
        nextStage: nextStage,
      );

  factory StageResult.failure(String errorMessage) => StageResult(
        success: false,
        errorMessage: errorMessage,
      );
}

/// 流水线管理器
///
/// 职责：
/// - 管理语音处理流水线的各个阶段
/// - 控制阶段之间的转换
/// - 处理超时和错误
/// - 支持流水线的暂停、恢复和取消
class PipelineManager extends ChangeNotifier {
  /// 配置
  final PipelineConfig _config;

  /// 当前阶段
  PipelineStage _currentStage = PipelineStage.idle;

  /// 上一阶段
  PipelineStage? _previousStage;

  /// 阶段处理器
  final Map<PipelineStage, IStageHandler> _handlers = {};

  /// 事件流控制器
  final StreamController<PipelineEvent> _eventController =
      StreamController<PipelineEvent>.broadcast();

  /// 当前上下文
  StageContext? _currentContext;

  /// 超时计时器
  Timer? _timeoutTimer;

  /// 是否正在运行
  bool _isRunning = false;

  /// 是否已暂停
  bool _isPaused = false;

  /// 重试计数
  int _retryCount = 0;

  PipelineManager({PipelineConfig? config})
      : _config = config ?? PipelineConfig.defaultConfig;

  /// 当前阶段
  PipelineStage get currentStage => _currentStage;

  /// 上一阶段
  PipelineStage? get previousStage => _previousStage;

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 是否已暂停
  bool get isPaused => _isPaused;

  /// 是否空闲
  bool get isIdle => _currentStage == PipelineStage.idle;

  /// 事件流
  Stream<PipelineEvent> get events => _eventController.stream;

  /// 配置
  PipelineConfig get config => _config;

  // ==================== 处理器注册 ====================

  /// 注册阶段处理器
  void registerHandler(PipelineStage stage, IStageHandler handler) {
    _handlers[stage] = handler;
  }

  /// 移除阶段处理器
  void unregisterHandler(PipelineStage stage) {
    _handlers.remove(stage);
  }

  // ==================== 流水线控制 ====================

  /// 启动流水线
  Future<void> start({
    PipelineStage initialStage = PipelineStage.awaitingWakeWord,
    Map<String, dynamic>? initialData,
  }) async {
    if (_isRunning) {
      debugPrint('[PipelineManager] 流水线已在运行中');
      return;
    }

    _isRunning = true;
    _isPaused = false;
    _retryCount = 0;

    _currentContext = StageContext(
      stage: initialStage,
      data: initialData,
    );

    await _transitionTo(initialStage);
    debugPrint('[PipelineManager] 流水线已启动，初始阶段: $initialStage');
  }

  /// 停止流水线
  Future<void> stop() async {
    if (!_isRunning) return;

    _cancelTimeout();
    _isRunning = false;
    _isPaused = false;

    await _transitionTo(PipelineStage.idle);
    _emitEvent(PipelineEvent.cancelled());

    debugPrint('[PipelineManager] 流水线已停止');
  }

  /// 暂停流水线
  void pause() {
    if (!_isRunning || _isPaused) return;

    _isPaused = true;
    _cancelTimeout();
    notifyListeners();

    debugPrint('[PipelineManager] 流水线已暂停');
  }

  /// 恢复流水线
  void resume() {
    if (!_isRunning || !_isPaused) return;

    _isPaused = false;
    _startTimeout();
    notifyListeners();

    debugPrint('[PipelineManager] 流水线已恢复');
  }

  /// 手动推进到下一阶段
  Future<void> advanceTo(PipelineStage stage, {Map<String, dynamic>? data}) async {
    if (!_isRunning) {
      debugPrint('[PipelineManager] 流水线未运行，无法推进');
      return;
    }

    if (data != null && _currentContext != null) {
      data.forEach((key, value) => _currentContext!.set(key, value));
    }

    await _transitionTo(stage);
  }

  /// 报告阶段进度
  void reportProgress(double progress, {String? message}) {
    _emitEvent(PipelineEvent.progress(
      stage: _currentStage,
      progress: progress,
      message: message,
    ));
  }

  /// 报告错误
  Future<void> reportError(Object error, {String? message}) async {
    debugPrint('[PipelineManager] 错误: $error');

    if (_config.autoRetry && _retryCount < _config.maxRetries) {
      _retryCount++;
      debugPrint('[PipelineManager] 重试 $_retryCount/${_config.maxRetries}');
      await Future.delayed(Duration(milliseconds: _config.retryDelay));
      await _executeCurrentStage();
    } else {
      _emitEvent(PipelineEvent.error(error: error, message: message));
      await _transitionTo(PipelineStage.error);
    }
  }

  // ==================== 私有方法 ====================

  /// 转换到新阶段
  Future<void> _transitionTo(PipelineStage newStage) async {
    if (_currentStage == newStage) return;

    _cancelTimeout();

    _previousStage = _currentStage;
    _currentStage = newStage;

    _emitEvent(PipelineEvent.stageChanged(
      stage: newStage,
      previousStage: _previousStage,
    ));

    notifyListeners();

    debugPrint('[PipelineManager] 阶段转换: $_previousStage -> $_currentStage');

    if (newStage == PipelineStage.idle ||
        newStage == PipelineStage.error ||
        newStage == PipelineStage.completed) {
      _isRunning = false;
      if (newStage == PipelineStage.completed) {
        _emitEvent(PipelineEvent.completed());
      }
      return;
    }

    _startTimeout();
    await _executeCurrentStage();
  }

  /// 执行当前阶段
  Future<void> _executeCurrentStage() async {
    if (_isPaused) return;

    final handler = _handlers[_currentStage];
    if (handler == null) {
      debugPrint('[PipelineManager] 没有找到阶段处理器: $_currentStage');
      return;
    }

    try {
      final context = _currentContext ?? StageContext(stage: _currentStage);
      final result = await handler.handle(context);

      if (result.success) {
        _retryCount = 0;

        // 合并输出到上下文
        if (result.output != null) {
          result.output!.forEach((key, value) => _currentContext?.set(key, value));
        }

        // 自动推进到下一阶段
        if (result.nextStage != null) {
          await _transitionTo(result.nextStage!);
        }
      } else {
        await reportError(
          Exception(result.errorMessage ?? '阶段执行失败'),
          message: result.errorMessage,
        );
      }
    } catch (e) {
      await reportError(e, message: e.toString());
    }
  }

  /// 启动超时计时器
  void _startTimeout() {
    _cancelTimeout();

    final timeout = _config.stageTimeouts[_currentStage];
    if (timeout == null) return;

    _timeoutTimer = Timer(Duration(milliseconds: timeout), () {
      debugPrint('[PipelineManager] 阶段超时: $_currentStage');
      reportError(TimeoutException('阶段超时: $_currentStage'));
    });
  }

  /// 取消超时计时器
  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// 发送事件
  void _emitEvent(PipelineEvent event) {
    _eventController.add(event);
  }

  @override
  void dispose() {
    _cancelTimeout();
    _eventController.close();
    super.dispose();
  }
}

/// 超时异常
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
