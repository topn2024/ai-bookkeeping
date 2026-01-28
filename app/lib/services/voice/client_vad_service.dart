import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';

/// 客户端VAD服务
///
/// 使用Silero VAD模型进行本地语音活动检测
/// 特点：
/// - 完全离线运行
/// - 低延迟（<10ms）
/// - 自适应噪声阈值
/// - 支持降级到能量检测
class ClientVADService {
  /// Silero VAD 实例
  VadHandler? _vadHandler;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否正在运行
  bool _isRunning = false;

  /// 当前是否检测到语音
  bool _isSpeaking = false;

  /// 连续语音帧计数
  int _speechFrameCount = 0;

  /// 连续静音帧计数
  int _silenceFrameCount = 0;

  /// 配置
  final ClientVADConfig config;

  /// 回调
  VoidCallback? onSpeechStart;
  VoidCallback? onSpeechEnd;
  void Function(double probability)? onVADResult;
  void Function(String error)? onError;

  /// 事件流
  final _eventController = StreamController<ClientVADEvent>.broadcast();
  Stream<ClientVADEvent> get eventStream => _eventController.stream;

  /// 能量检测降级（当Silero VAD不可用时）
  bool _useFallback = false;
  double _currentEnergyThreshold = 0.02;
  final List<double> _noiseFloorSamples = [];

  /// 音频流控制器（用于传递音频数据给VAD）
  StreamController<Uint8List>? _audioStreamController;

  /// 事件订阅
  StreamSubscription<void>? _speechStartSubscription;
  StreamSubscription<void>? _speechEndSubscription;
  StreamSubscription<void>? _vadMisfireSubscription;
  StreamSubscription<
          ({double isSpeech, double notSpeech, List<double> frame})>?
      _frameProcessedSubscription;

  ClientVADService({ClientVADConfig? config})
      : config = config ?? const ClientVADConfig();

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 当前是否在说话
  bool get isSpeaking => _isSpeaking;

  /// 是否使用降级模式
  bool get isUsingFallback => _useFallback;

  /// 初始化VAD服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[ClientVAD] 正在初始化Silero VAD...');

      // 创建Silero VAD实例
      _vadHandler = VadHandler.create(isDebug: kDebugMode);

      _isInitialized = true;
      _useFallback = false;
      debugPrint('[ClientVAD] Silero VAD初始化成功');
    } catch (e) {
      debugPrint('[ClientVAD] Silero VAD初始化失败，启用能量检测降级: $e');
      _useFallback = true;
      _isInitialized = true;
      onError?.call('VAD初始化失败，使用降级模式: $e');
    }
  }

  /// 开始VAD检测
  ///
  /// 如果使用Silero VAD，将启动内置录音功能
  /// 如果使用降级模式，需要通过[processAudio]方法手动传入音频
  Future<void> start() async {
    if (!_isInitialized) {
      debugPrint('[ClientVAD] 服务未初始化');
      return;
    }

    _isRunning = true;
    _isSpeaking = false;
    _speechFrameCount = 0;
    _silenceFrameCount = 0;

    if (!_useFallback && _vadHandler != null) {
      try {
        // 创建音频流控制器
        _audioStreamController = StreamController<Uint8List>.broadcast();

        // 设置事件监听
        _speechStartSubscription = _vadHandler!.onSpeechStart.listen((_) {
          _handleSpeechStart();
        });

        _speechEndSubscription = _vadHandler!.onSpeechEnd.listen((_) {
          _handleSpeechEnd();
        });

        _vadMisfireSubscription = _vadHandler!.onVADMisfire.listen((_) {
          debugPrint('[ClientVAD] VAD误触发');
        });

        _frameProcessedSubscription =
            _vadHandler!.onFrameProcessed.listen((result) {
          // 通知VAD结果概率
          onVADResult?.call(result.isSpeech);
        });

        // 启动VAD监听，使用自定义音频流
        await _vadHandler!.startListening(
          positiveSpeechThreshold: config.vadThreshold,
          negativeSpeechThreshold: config.vadThreshold - 0.15,
          frameSamples: config.frameSamples,
          minSpeechFrames: config.minSpeechFrames,
          model: 'v5', // 使用v5模型，更适合实时场景
          audioStream: _audioStreamController!.stream,
        );

        debugPrint('[ClientVAD] Silero VAD检测已启动');
      } catch (e) {
        debugPrint('[ClientVAD] 启动Silero VAD失败，降级到能量检测: $e');

        // 清理已创建的订阅，防止资源泄漏
        await _speechStartSubscription?.cancel();
        await _speechEndSubscription?.cancel();
        await _vadMisfireSubscription?.cancel();
        await _frameProcessedSubscription?.cancel();
        _speechStartSubscription = null;
        _speechEndSubscription = null;
        _vadMisfireSubscription = null;
        _frameProcessedSubscription = null;

        // 关闭音频流控制器
        await _audioStreamController?.close();
        _audioStreamController = null;

        _useFallback = true;
        onError?.call('VAD启动失败，使用降级模式: $e');
      }
    }

    debugPrint('[ClientVAD] VAD检测已启动 (降级模式: $_useFallback)');
  }

  /// 停止VAD检测
  Future<void> stop() async {
    _isRunning = false;
    _isSpeaking = false;

    // 取消订阅
    await _speechStartSubscription?.cancel();
    await _speechEndSubscription?.cancel();
    await _vadMisfireSubscription?.cancel();
    await _frameProcessedSubscription?.cancel();

    _speechStartSubscription = null;
    _speechEndSubscription = null;
    _vadMisfireSubscription = null;
    _frameProcessedSubscription = null;

    // 关闭音频流
    await _audioStreamController?.close();
    _audioStreamController = null;

    // 停止VAD监听
    if (_vadHandler != null) {
      try {
        await _vadHandler!.stopListening();
      } catch (e) {
        debugPrint('[ClientVAD] 停止VAD监听时出错: $e');
      }
    }

    debugPrint('[ClientVAD] VAD检测已停止');
  }

  /// 处理音频帧
  ///
  /// 输入：PCM 16kHz 单声道 16bit 音频数据
  /// 返回：是否检测到语音
  Future<bool> processAudio(Uint8List audioData) async {
    if (!_isRunning) return false;

    if (_useFallback) {
      return _processAudioFallback(audioData);
    }

    try {
      // 将音频数据发送到VAD流
      _audioStreamController?.add(audioData);

      // 返回当前状态
      return _isSpeaking;
    } catch (e) {
      debugPrint('[ClientVAD] 处理音频错误: $e');
      // 降级到能量检测
      return _processAudioFallback(audioData);
    }
  }

  /// 降级模式：能量检测
  bool _processAudioFallback(Uint8List audioData) {
    final energy = _calculateEnergy(audioData);
    final isSpeech = energy > _currentEnergyThreshold;

    // 更新噪音基底（仅在静音状态下）
    if (!_isSpeaking && config.adaptiveThreshold) {
      _updateNoiseFloor(energy);
    }

    // 通知VAD结果
    onVADResult?.call(energy);

    if (isSpeech) {
      _speechFrameCount++;
      _silenceFrameCount = 0;

      if (!_isSpeaking && _speechFrameCount >= config.minSpeechFrames) {
        _handleSpeechStart();
      }
    } else {
      _silenceFrameCount++;
      _speechFrameCount = 0;

      if (_isSpeaking && _silenceFrameCount >= config.minSilenceFrames) {
        _handleSpeechEnd();
      }
    }

    return _isSpeaking;
  }

  /// 处理语音开始
  void _handleSpeechStart() {
    if (_isSpeaking) return;

    _isSpeaking = true;
    debugPrint('[ClientVAD] 语音开始');

    onSpeechStart?.call();
    _eventController.add(ClientVADEvent(
      type: ClientVADEventType.speechStart,
      timestamp: DateTime.now(),
    ));
  }

  /// 处理语音结束
  void _handleSpeechEnd() {
    if (!_isSpeaking) return;

    _isSpeaking = false;
    debugPrint('[ClientVAD] 语音结束');

    onSpeechEnd?.call();
    _eventController.add(ClientVADEvent(
      type: ClientVADEventType.speechEnd,
      timestamp: DateTime.now(),
    ));
  }

  /// 计算音频能量
  double _calculateEnergy(Uint8List frame) {
    if (frame.isEmpty) return 0;

    double sum = 0;
    final numSamples = frame.length ~/ 2;

    for (int i = 0; i < frame.length - 1; i += 2) {
      final sample = (frame[i] | (frame[i + 1] << 8)).toSigned(16);
      sum += sample * sample;
    }

    return (sum / numSamples).abs() / (32768 * 32768);
  }

  /// 更新噪音基底
  void _updateNoiseFloor(double energy) {
    _noiseFloorSamples.add(energy);

    if (_noiseFloorSamples.length > 100) {
      _noiseFloorSamples.removeAt(0);
    }

    if (_noiseFloorSamples.length >= 10) {
      final sorted = List<double>.from(_noiseFloorSamples)..sort();
      final median = sorted[sorted.length ~/ 2];
      final newThreshold = (median * 3).clamp(
        config.minEnergyThreshold,
        config.maxEnergyThreshold,
      );
      _currentEnergyThreshold =
          _currentEnergyThreshold * 0.9 + newThreshold * 0.1;
    }
  }

  /// 重置状态
  void reset() {
    _isSpeaking = false;
    _speechFrameCount = 0;
    _silenceFrameCount = 0;
    debugPrint('[ClientVAD] 状态已重置');
  }

  /// 释放资源
  Future<void> dispose() async {
    await stop();
    if (_vadHandler != null) {
      try {
        await _vadHandler!.dispose();
      } catch (e) {
        debugPrint('[ClientVAD] 释放VAD资源时出错: $e');
      }
    }
    _vadHandler = null;
    _eventController.close();
    _isInitialized = false;
    debugPrint('[ClientVAD] 资源已释放');
  }
}

/// 客户端VAD配置
class ClientVADConfig {
  /// 采样率
  final int sampleRate;

  /// 每帧采样数
  final int frameSamples;

  /// VAD阈值（Silero VAD）
  final double vadThreshold;

  /// 最小静音时长（毫秒）
  final int minSilenceDurationMs;

  /// 语音填充时长（毫秒）
  final int speechPadMs;

  /// 最小语音帧数（能量检测）
  final int minSpeechFrames;

  /// 最小静音帧数（能量检测）
  final int minSilenceFrames;

  /// 是否启用自适应阈值
  final bool adaptiveThreshold;

  /// 最小能量阈值
  final double minEnergyThreshold;

  /// 最大能量阈值
  final double maxEnergyThreshold;

  const ClientVADConfig({
    this.sampleRate = 16000,
    this.frameSamples = 512,
    this.vadThreshold = 0.5,
    this.minSilenceDurationMs = 500,
    this.speechPadMs = 300,
    this.minSpeechFrames = 3,
    this.minSilenceFrames = 10,
    this.adaptiveThreshold = true,
    this.minEnergyThreshold = 0.01,
    this.maxEnergyThreshold = 0.1,
  });
}

/// 客户端VAD事件类型
enum ClientVADEventType {
  speechStart,
  speechEnd,
}

/// 客户端VAD事件
class ClientVADEvent {
  final ClientVADEventType type;
  final DateTime timestamp;

  const ClientVADEvent({
    required this.type,
    required this.timestamp,
  });
}

/// Int扩展：有符号转换
extension Int16ExtensionForVAD on int {
  /// 将无符号整数转换为有符号整数
  int toSigned(int bits) {
    final mask = 1 << (bits - 1);
    return (this & ((1 << bits) - 1)) - ((this & mask) << 1);
  }
}
