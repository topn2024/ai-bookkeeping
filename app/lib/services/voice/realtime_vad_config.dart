import 'dart:async';
import 'package:flutter/foundation.dart';
import 'client_vad_service.dart';

/// 实时对话VAD配置
///
/// 基于设计文档优化的VAD参数：
/// - 语音开始阈值: 200ms（快速检测到用户开始说话）
/// - 语音结束阈值: 800ms（静音800ms判定用户说完，适应自然停顿）
/// - 背景噪音自适应: 根据环境动态调整阈值
class RealtimeVADConfig {
  /// 语音开始检测阈值（毫秒）
  /// 检测到连续语音活动超过此时长才认为用户开始说话
  final int speechStartThresholdMs;

  /// 语音结束检测阈值（毫秒）
  /// 静音超过此时长认为用户说话结束
  /// 注意：值太小会导致用户还没说完就被打断，值太大会增加响应延迟
  final int speechEndThresholdMs;

  /// 能量阈值（0.0-1.0）
  /// 音频帧能量超过此值认为是语音
  final double energyThreshold;

  /// 是否启用自适应阈值
  final bool adaptiveThreshold;

  /// 自适应阈值更新周期（毫秒）
  final int adaptiveUpdatePeriodMs;

  /// 最小能量阈值（自适应模式下的下限）
  final double minEnergyThreshold;

  /// 最大能量阈值（自适应模式下的上限）
  final double maxEnergyThreshold;

  /// 轮次结束停顿时长（毫秒）
  /// 智能体说完后等待用户可能的响应
  final int turnEndPauseMs;

  const RealtimeVADConfig({
    this.speechStartThresholdMs = 200,
    this.speechEndThresholdMs = 800,  // 从500ms增加到800ms，适应自然停顿
    this.energyThreshold = 0.02,
    this.adaptiveThreshold = true,
    this.adaptiveUpdatePeriodMs = 3000,
    this.minEnergyThreshold = 0.01,
    this.maxEnergyThreshold = 0.1,
    this.turnEndPauseMs = 1500,
  });

  /// 默认配置（适用于大多数场景）
  factory RealtimeVADConfig.defaultConfig() => const RealtimeVADConfig();

  /// 安静环境配置（更敏感）
  factory RealtimeVADConfig.quietEnvironment() => const RealtimeVADConfig(
        energyThreshold: 0.01,
        minEnergyThreshold: 0.005,
        maxEnergyThreshold: 0.05,
      );

  /// 嘈杂环境配置（更鲁棒）
  factory RealtimeVADConfig.noisyEnvironment() => const RealtimeVADConfig(
        energyThreshold: 0.05,
        minEnergyThreshold: 0.02,
        maxEnergyThreshold: 0.2,
        speechStartThresholdMs: 300,
      );

  /// 快速响应配置（牺牲准确性换取速度）
  /// 适用于简短指令场景
  factory RealtimeVADConfig.fastResponse() => const RealtimeVADConfig(
        speechStartThresholdMs: 100,
        speechEndThresholdMs: 500,  // 快速响应时可以短一些
        turnEndPauseMs: 1000,
      );

  /// 连续对话配置（适应自然语速和停顿）
  /// 适用于用户需要思考或说较长句子的场景
  factory RealtimeVADConfig.continuousConversation() => const RealtimeVADConfig(
        speechStartThresholdMs: 200,
        speechEndThresholdMs: 1000,  // 1秒静音才判定说话结束
        turnEndPauseMs: 2000,        // 更长的轮次停顿等待
      );

  RealtimeVADConfig copyWith({
    int? speechStartThresholdMs,
    int? speechEndThresholdMs,
    double? energyThreshold,
    bool? adaptiveThreshold,
    int? adaptiveUpdatePeriodMs,
    double? minEnergyThreshold,
    double? maxEnergyThreshold,
    int? turnEndPauseMs,
  }) {
    return RealtimeVADConfig(
      speechStartThresholdMs: speechStartThresholdMs ?? this.speechStartThresholdMs,
      speechEndThresholdMs: speechEndThresholdMs ?? this.speechEndThresholdMs,
      energyThreshold: energyThreshold ?? this.energyThreshold,
      adaptiveThreshold: adaptiveThreshold ?? this.adaptiveThreshold,
      adaptiveUpdatePeriodMs: adaptiveUpdatePeriodMs ?? this.adaptiveUpdatePeriodMs,
      minEnergyThreshold: minEnergyThreshold ?? this.minEnergyThreshold,
      maxEnergyThreshold: maxEnergyThreshold ?? this.maxEnergyThreshold,
      turnEndPauseMs: turnEndPauseMs ?? this.turnEndPauseMs,
    );
  }
}

/// VAD状态
enum VADState {
  /// 静音/无语音
  silence,

  /// 可能开始说话（语音检测中，未达到阈值）
  possibleSpeech,

  /// 确认说话中
  speaking,

  /// 可能结束说话（静音检测中，未达到阈值）
  possibleSilence,
}

/// VAD事件类型
enum VADEventType {
  /// 语音开始
  speechStart,

  /// 语音结束
  speechEnd,

  /// 轮次结束停顿开始
  turnEndPauseStart,

  /// 轮次结束停顿结束（无用户响应）
  turnEndPauseTimeout,

  /// 环境噪音更新
  noiseFloorUpdated,
}

/// VAD事件
class VADEvent {
  /// 事件类型
  final VADEventType type;

  /// 事件时间戳
  final DateTime timestamp;

  /// 语音时长（仅speechEnd事件有效）
  final Duration? speechDuration;

  /// 当前能量阈值（仅noiseFloorUpdated事件有效）
  final double? currentThreshold;

  const VADEvent({
    required this.type,
    required this.timestamp,
    this.speechDuration,
    this.currentThreshold,
  });
}

/// 实时VAD服务
///
/// 提供实时语音活动检测，支持：
/// - Silero VAD神经网络检测（首选）
/// - 自动降级到能量检测
/// - 自适应噪音阈值
/// - 轮次结束停顿检测
class RealtimeVADService {
  /// 配置
  final RealtimeVADConfig config;

  /// Silero VAD服务（优先使用）
  ClientVADService? _sileroVAD;

  /// 是否使用Silero VAD
  bool _usingSileroVAD = false;

  /// 当前状态
  VADState _state = VADState.silence;

  /// 当前能量阈值（自适应模式下会动态调整）
  double _currentThreshold;

  /// 语音开始时间
  DateTime? _speechStartTime;

  /// 事件流控制器
  final _eventController = StreamController<VADEvent>.broadcast();

  /// 轮次结束停顿计时器
  Timer? _turnEndPauseTimer;

  /// 噪音采样缓冲区
  final List<double> _noiseFloorSamples = [];

  /// 最大噪音采样数
  static const int _maxNoiseFloorSamples = 100;

  /// 帧时长（毫秒）
  static const int _frameDurationMs = 30;

  /// 连续语音帧计数
  int _speechFrameCount = 0;

  /// 连续静音帧计数
  int _silenceFrameCount = 0;

  RealtimeVADService({RealtimeVADConfig? config})
      : config = config ?? RealtimeVADConfig.defaultConfig(),
        _currentThreshold = config?.energyThreshold ?? 0.02;

  /// 是否正在使用Silero VAD
  bool get isUsingSileroVAD => _usingSileroVAD;

  /// 初始化Silero VAD（异步，可选）
  ///
  /// 建议在服务启动时调用此方法初始化Silero VAD
  /// 如果初始化失败，将自动降级到能量检测
  Future<void> initializeSileroVAD() async {
    try {
      debugPrint('[RealtimeVAD] 正在初始化Silero VAD...');
      _sileroVAD = ClientVADService(
        config: ClientVADConfig(
          vadThreshold: 0.5,
          minSpeechFrames: 3,
          minSilenceFrames: 10,
        ),
      );
      await _sileroVAD!.initialize();

      if (_sileroVAD!.isInitialized && !_sileroVAD!.isUsingFallback) {
        _usingSileroVAD = true;

        // 设置Silero VAD回调
        _sileroVAD!.onSpeechStart = _handleSileroSpeechStart;
        _sileroVAD!.onSpeechEnd = _handleSileroSpeechEnd;

        await _sileroVAD!.start();
        debugPrint('[RealtimeVAD] ✓ Silero VAD初始化成功，已启用神经网络检测');
      } else {
        debugPrint('[RealtimeVAD] Silero VAD降级模式，继续使用能量检测');
        _usingSileroVAD = false;
      }
    } catch (e) {
      debugPrint('[RealtimeVAD] Silero VAD初始化失败: $e，使用能量检测');
      _usingSileroVAD = false;
    }
  }

  /// Silero VAD语音开始回调
  void _handleSileroSpeechStart() {
    if (_state != VADState.speaking) {
      _transitionTo(VADState.speaking);
      _speechStartTime = DateTime.now();
      _emitEvent(VADEventType.speechStart);
      debugPrint('[RealtimeVAD] [Silero] 检测到语音开始');
    }
  }

  /// Silero VAD语音结束回调
  void _handleSileroSpeechEnd() {
    if (_state == VADState.speaking || _state == VADState.possibleSilence) {
      _transitionTo(VADState.silence);
      final speechDuration = _speechStartTime != null
          ? DateTime.now().difference(_speechStartTime!)
          : null;
      _emitEvent(VADEventType.speechEnd, speechDuration: speechDuration);
      _speechStartTime = null;
      _speechFrameCount = 0;
      _silenceFrameCount = 0;
      debugPrint('[RealtimeVAD] [Silero] 检测到语音结束');
    }
  }

  /// 当前状态
  VADState get state => _state;

  /// 事件流
  Stream<VADEvent> get eventStream => _eventController.stream;

  /// 当前能量阈值
  double get currentThreshold => _currentThreshold;

  /// 处理音频帧
  ///
  /// 输入：16kHz单声道16bit PCM音频数据
  void processAudioFrame(Uint8List audioFrame) {
    // 如果使用Silero VAD，将音频传递给它处理
    // Silero VAD通过回调通知语音开始/结束
    if (_usingSileroVAD && _sileroVAD != null) {
      _sileroVAD!.processAudio(audioFrame);
      return;  // Silero VAD通过回调处理状态转换
    }

    // 降级到能量检测
    final energy = _calculateFrameEnergy(audioFrame);
    final isSpeech = energy > _currentThreshold;

    // 更新噪音基底（仅在静音状态下）
    if (_state == VADState.silence && config.adaptiveThreshold) {
      _updateNoiseFloor(energy);
    }

    // 状态机处理
    switch (_state) {
      case VADState.silence:
        if (isSpeech) {
          _speechFrameCount++;
          if (_speechFrameCount * _frameDurationMs >= config.speechStartThresholdMs) {
            _transitionTo(VADState.speaking);
            _speechStartTime = DateTime.now();
            _emitEvent(VADEventType.speechStart);
          } else {
            _transitionTo(VADState.possibleSpeech);
          }
        }
        break;

      case VADState.possibleSpeech:
        if (isSpeech) {
          _speechFrameCount++;
          if (_speechFrameCount * _frameDurationMs >= config.speechStartThresholdMs) {
            _transitionTo(VADState.speaking);
            _speechStartTime = DateTime.now();
            _emitEvent(VADEventType.speechStart);
          }
        } else {
          // 语音中断，重置计数
          _speechFrameCount = 0;
          _transitionTo(VADState.silence);
        }
        break;

      case VADState.speaking:
        if (!isSpeech) {
          _silenceFrameCount++;
          if (_silenceFrameCount * _frameDurationMs >= config.speechEndThresholdMs) {
            _transitionTo(VADState.silence);
            final speechDuration = _speechStartTime != null
                ? DateTime.now().difference(_speechStartTime!)
                : null;
            _emitEvent(VADEventType.speechEnd, speechDuration: speechDuration);
            _speechStartTime = null;
            _speechFrameCount = 0;
            _silenceFrameCount = 0;
          } else {
            _transitionTo(VADState.possibleSilence);
          }
        } else {
          // 重置静音计数
          _silenceFrameCount = 0;
        }
        break;

      case VADState.possibleSilence:
        if (!isSpeech) {
          _silenceFrameCount++;
          if (_silenceFrameCount * _frameDurationMs >= config.speechEndThresholdMs) {
            _transitionTo(VADState.silence);
            final speechDuration = _speechStartTime != null
                ? DateTime.now().difference(_speechStartTime!)
                : null;
            _emitEvent(VADEventType.speechEnd, speechDuration: speechDuration);
            _speechStartTime = null;
            _speechFrameCount = 0;
            _silenceFrameCount = 0;
          }
        } else {
          // 语音恢复，重置静音计数
          _silenceFrameCount = 0;
          _transitionTo(VADState.speaking);
        }
        break;
    }
  }

  /// 开始轮次结束停顿检测
  ///
  /// 智能体说完话后调用，等待用户可能的响应
  void startTurnEndPauseDetection() {
    _cancelTurnEndPauseTimer();
    _emitEvent(VADEventType.turnEndPauseStart);

    _turnEndPauseTimer = Timer(
      Duration(milliseconds: config.turnEndPauseMs),
      () {
        if (_state == VADState.silence) {
          _emitEvent(VADEventType.turnEndPauseTimeout);
        }
      },
    );
  }

  /// 重置状态
  void reset() {
    _state = VADState.silence;
    _speechFrameCount = 0;
    _silenceFrameCount = 0;
    _speechStartTime = null;
    _cancelTurnEndPauseTimer();
    _sileroVAD?.reset();
    debugPrint('[RealtimeVAD] 状态已重置${_usingSileroVAD ? " (Silero VAD)" : ""}');
  }

  /// 释放资源
  void dispose() {
    _sileroVAD?.dispose();
    _sileroVAD = null;
    _usingSileroVAD = false;
    _eventController.close();
    _cancelTurnEndPauseTimer();
  }

  // ==================== 内部方法 ====================

  /// 计算帧能量
  double _calculateFrameEnergy(Uint8List frame) {
    if (frame.isEmpty) return 0;

    double sum = 0;
    final numSamples = frame.length ~/ 2;

    for (int i = 0; i < frame.length - 1; i += 2) {
      // 16-bit little-endian signed
      final sample = (frame[i] | (frame[i + 1] << 8)).toSigned(16);
      sum += sample * sample;
    }

    // 归一化到0-1范围
    return (sum / numSamples).abs() / (32768 * 32768);
  }

  /// 更新噪音基底
  void _updateNoiseFloor(double energy) {
    _noiseFloorSamples.add(energy);

    if (_noiseFloorSamples.length > _maxNoiseFloorSamples) {
      _noiseFloorSamples.removeAt(0);
    }

    // 计算噪音基底（取中位数）
    if (_noiseFloorSamples.length >= 10) {
      final sorted = List<double>.from(_noiseFloorSamples)..sort();
      final median = sorted[sorted.length ~/ 2];

      // 新阈值 = 噪音基底 * 系数
      final newThreshold = (median * 3).clamp(
        config.minEnergyThreshold,
        config.maxEnergyThreshold,
      );

      // 平滑更新
      _currentThreshold = _currentThreshold * 0.9 + newThreshold * 0.1;
    }
  }

  /// 状态转换
  void _transitionTo(VADState newState) {
    if (_state != newState) {
      debugPrint('[RealtimeVAD] 状态转换: $_state -> $newState');
      _state = newState;
    }
  }

  /// 发送事件
  void _emitEvent(VADEventType type, {Duration? speechDuration}) {
    final event = VADEvent(
      type: type,
      timestamp: DateTime.now(),
      speechDuration: speechDuration,
      currentThreshold: type == VADEventType.noiseFloorUpdated ? _currentThreshold : null,
    );
    _eventController.add(event);
    debugPrint('[RealtimeVAD] 事件: $type');
  }

  /// 取消轮次结束停顿计时器
  void _cancelTurnEndPauseTimer() {
    _turnEndPauseTimer?.cancel();
    _turnEndPauseTimer = null;
  }
}

/// 扩展Uint8List以支持16位有符号整数转换
extension Int16Extension on int {
  int toSigned(int bits) {
    final mask = 1 << (bits - 1);
    return (this & ((1 << bits) - 1)) - ((this & mask) << 1);
  }
}
