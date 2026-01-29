/// Voice Recognition Coordinator
///
/// 负责语音识别生命周期管理的协调器，从VoiceServiceCoordinator中提取。
/// 遵循单一职责原则，仅处理语音识别相关的业务逻辑。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 语音识别结果
class RecognitionResult {
  final String text;
  final double confidence;
  final Duration duration;
  final bool isPartial;
  final RecognitionSource source;

  const RecognitionResult({
    required this.text,
    required this.confidence,
    required this.duration,
    this.isPartial = false,
    this.source = RecognitionSource.online,
  });

  factory RecognitionResult.empty() {
    return const RecognitionResult(
      text: '',
      confidence: 0.0,
      duration: Duration.zero,
    );
  }

  bool get isEmpty => text.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  RecognitionResult copyWith({
    String? text,
    double? confidence,
    Duration? duration,
    bool? isPartial,
    RecognitionSource? source,
  }) {
    return RecognitionResult(
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      duration: duration ?? this.duration,
      isPartial: isPartial ?? this.isPartial,
      source: source ?? this.source,
    );
  }
}

/// 识别来源
enum RecognitionSource {
  /// 在线识别（阿里云等）
  online,

  /// 离线识别（本地Whisper等）
  offline,

  /// 混合模式
  hybrid,
}

/// 识别状态
enum RecognitionState {
  /// 空闲
  idle,

  /// 准备中
  preparing,

  /// 识别中
  recognizing,

  /// 处理中
  processing,

  /// 已完成
  completed,

  /// 已取消
  cancelled,

  /// 错误
  error,
}

/// 语音识别协调器
///
/// 职责：
/// - 管理语音识别生命周期
/// - 协调在线/离线识别引擎
/// - 处理识别结果后处理
/// - 提供识别状态管理
class VoiceRecognitionCoordinator extends ChangeNotifier {
  /// 识别引擎抽象接口
  final IVoiceRecognitionEngine _engine;

  /// 当前识别状态
  RecognitionState _state = RecognitionState.idle;

  /// 当前识别会话ID
  String? _sessionId;

  /// 最后一次识别结果
  RecognitionResult? _lastResult;

  /// 识别开始时间
  DateTime? _recognitionStartTime;

  /// 流式识别订阅
  StreamSubscription<RecognitionResult>? _streamSubscription;

  /// 流式识别控制器
  final StreamController<RecognitionResult> _resultController =
      StreamController<RecognitionResult>.broadcast();

  VoiceRecognitionCoordinator({
    required IVoiceRecognitionEngine engine,
  }) : _engine = engine;

  /// 当前状态
  RecognitionState get state => _state;

  /// 是否正在识别
  bool get isRecognizing =>
      _state == RecognitionState.recognizing ||
      _state == RecognitionState.processing;

  /// 当前会话ID
  String? get sessionId => _sessionId;

  /// 最后识别结果
  RecognitionResult? get lastResult => _lastResult;

  /// 识别结果流
  Stream<RecognitionResult> get resultStream => _resultController.stream;

  /// 开始识别会话
  Future<void> startSession() async {
    if (_state != RecognitionState.idle) {
      debugPrint('[VoiceRecognitionCoordinator] 无法开始会话，当前状态: $_state');
      return;
    }

    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _updateState(RecognitionState.preparing);
    debugPrint('[VoiceRecognitionCoordinator] 开始识别会话: $_sessionId');
  }

  /// 单次识别
  ///
  /// 从音频数据进行一次性识别
  Future<RecognitionResult> recognize(Uint8List audioData) async {
    if (_state != RecognitionState.idle &&
        _state != RecognitionState.preparing) {
      throw StateError('无法开始识别，当前状态: $_state');
    }

    _recognitionStartTime = DateTime.now();
    _updateState(RecognitionState.recognizing);

    try {
      debugPrint('[VoiceRecognitionCoordinator] 开始单次识别，音频大小: ${audioData.length} bytes');

      final result = await _engine.transcribe(audioData);

      _lastResult = result;
      _updateState(RecognitionState.completed);

      debugPrint('[VoiceRecognitionCoordinator] 识别完成: "${result.text}" (confidence: ${result.confidence})');
      return result;
    } catch (e) {
      debugPrint('[VoiceRecognitionCoordinator] 识别失败: $e');
      _updateState(RecognitionState.error);
      rethrow;
    }
  }

  /// 流式识别
  ///
  /// 从音频流进行实时识别
  Stream<RecognitionResult> recognizeStream(Stream<Uint8List> audioStream) {
    if (_state != RecognitionState.idle &&
        _state != RecognitionState.preparing) {
      throw StateError('无法开始流式识别，当前状态: $_state');
    }

    _recognitionStartTime = DateTime.now();
    _updateState(RecognitionState.recognizing);

    debugPrint('[VoiceRecognitionCoordinator] 开始流式识别');

    // 创建转换后的流
    final transformedStream = _engine.transcribeStream(audioStream).map((result) {
      _lastResult = result;

      if (!result.isPartial) {
        _updateState(RecognitionState.completed);
      }

      _resultController.add(result);
      return result;
    }).handleError((error) {
      debugPrint('[VoiceRecognitionCoordinator] 流式识别错误: $error');
      _updateState(RecognitionState.error);
      throw error;
    });

    return transformedStream;
  }

  /// 取消识别
  Future<void> cancelRecognition() async {
    if (!isRecognizing) {
      debugPrint('[VoiceRecognitionCoordinator] 没有正在进行的识别');
      return;
    }

    debugPrint('[VoiceRecognitionCoordinator] 取消识别');

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    await _engine.cancel();
    _updateState(RecognitionState.cancelled);
  }

  /// 结束会话
  Future<void> endSession() async {
    debugPrint('[VoiceRecognitionCoordinator] 结束识别会话: $_sessionId');

    await cancelRecognition();
    _sessionId = null;
    _lastResult = null;
    _recognitionStartTime = null;
    _updateState(RecognitionState.idle);
  }

  /// 重置状态
  void reset() {
    _updateState(RecognitionState.idle);
    _lastResult = null;
    _recognitionStartTime = null;
  }

  /// 获取识别时长
  Duration? getRecognitionDuration() {
    if (_recognitionStartTime == null) return null;
    return DateTime.now().difference(_recognitionStartTime!);
  }

  /// 更新状态
  void _updateState(RecognitionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _resultController.close();
    super.dispose();
  }
}

/// 语音识别引擎接口
///
/// 抽象识别引擎，支持依赖注入和测试
abstract class IVoiceRecognitionEngine {
  /// 单次识别
  Future<RecognitionResult> transcribe(Uint8List audioData);

  /// 流式识别
  Stream<RecognitionResult> transcribeStream(Stream<Uint8List> audioStream);

  /// 取消识别
  Future<void> cancel();

  /// 是否正在识别
  bool get isRecognizing;
}
