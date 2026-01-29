/// Barge-In Manager
///
/// 负责打断检测的管理器，从 GlobalVoiceAssistantManager 中提取。
/// 允许用户在 TTS 播放时通过说话打断。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 打断事件类型
enum BargeInEventType {
  /// 检测到打断
  detected,

  /// 打断确认（持续说话）
  confirmed,

  /// 打断取消（短暂噪音）
  cancelled,
}

/// 打断事件
class BargeInEvent {
  final BargeInEventType type;
  final DateTime timestamp;
  final double? confidence;

  const BargeInEvent({
    required this.type,
    required this.timestamp,
    this.confidence,
  });
}

/// 打断检测配置
class BargeInConfig {
  /// 能量阈值（检测到此能量以上视为可能的打断）
  final double energyThreshold;

  /// 确认延迟（毫秒）- 需要持续这么长时间才确认打断
  final int confirmationDelayMs;

  /// 取消延迟（毫秒）- 能量低于阈值这么长时间取消打断
  final int cancellationDelayMs;

  const BargeInConfig({
    this.energyThreshold = 0.02,
    this.confirmationDelayMs = 200,
    this.cancellationDelayMs = 100,
  });

  static const defaultConfig = BargeInConfig();
}

/// 打断检测状态
enum BargeInState {
  /// 空闲（未启用）
  idle,

  /// 监听中
  listening,

  /// 检测到可能的打断
  potentialBargeIn,

  /// 打断已确认
  confirmed,
}

/// 打断检测管理器
///
/// 职责：
/// - 在 TTS 播放时监听用户语音
/// - 检测用户打断意图
/// - 通知系统停止 TTS 并开始录音
class BargeInManager extends ChangeNotifier {
  /// 配置
  BargeInConfig _config;

  /// 当前状态
  BargeInState _state = BargeInState.idle;

  /// 音频流订阅
  StreamSubscription<Uint8List>? _audioSubscription;

  /// 事件流控制器
  final StreamController<BargeInEvent> _eventController =
      StreamController<BargeInEvent>.broadcast();

  /// 确认计时器
  Timer? _confirmationTimer;

  /// 取消计时器
  Timer? _cancellationTimer;

  /// 打断检测开始时间
  DateTime? _bargeInStartTime;

  /// 是否启用
  bool _isEnabled = false;

  BargeInManager({BargeInConfig? config})
      : _config = config ?? BargeInConfig.defaultConfig;

  /// 当前状态
  BargeInState get state => _state;

  /// 是否已启用
  bool get isEnabled => _isEnabled;

  /// 事件流
  Stream<BargeInEvent> get events => _eventController.stream;

  /// 更新配置
  void updateConfig(BargeInConfig config) {
    _config = config;
    notifyListeners();
  }

  // ==================== 生命周期 ====================

  /// 启用打断检测（在 TTS 播放时调用）
  void enable(Stream<Uint8List> audioStream) {
    if (_isEnabled) return;

    _isEnabled = true;
    _state = BargeInState.listening;

    _audioSubscription = audioStream.listen(
      _processAudioChunk,
      onError: (error) {
        debugPrint('[BargeInManager] 音频流错误: $error');
      },
    );

    debugPrint('[BargeInManager] 打断检测已启用');
    notifyListeners();
  }

  /// 禁用打断检测（TTS 停止时调用）
  void disable() {
    if (!_isEnabled) return;

    _isEnabled = false;
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    _cancellationTimer?.cancel();
    _cancellationTimer = null;

    _state = BargeInState.idle;
    _bargeInStartTime = null;

    debugPrint('[BargeInManager] 打断检测已禁用');
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    disable();
    _eventController.close();
    super.dispose();
  }

  // ==================== 音频处理 ====================

  /// 处理音频数据块
  void _processAudioChunk(Uint8List audioData) {
    final energy = _calculateEnergy(audioData);

    if (energy > _config.energyThreshold) {
      _onHighEnergy(energy);
    } else {
      _onLowEnergy();
    }
  }

  /// 计算音频能量
  double _calculateEnergy(Uint8List audioData) {
    if (audioData.isEmpty) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < audioData.length - 1; i += 2) {
      final sample = (audioData[i + 1] << 8) | audioData[i];
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      sum += signedSample * signedSample;
    }

    final rms = (sum / (audioData.length / 2));
    return (rms / 32768 / 32768).clamp(0.0, 1.0);
  }

  /// 检测到高能量（可能是用户说话）
  void _onHighEnergy(double energy) {
    // 取消取消计时器
    _cancellationTimer?.cancel();
    _cancellationTimer = null;

    if (_state == BargeInState.listening) {
      // 进入潜在打断状态
      _state = BargeInState.potentialBargeIn;
      _bargeInStartTime = DateTime.now();

      _emitEvent(BargeInEvent(
        type: BargeInEventType.detected,
        timestamp: DateTime.now(),
        confidence: energy,
      ));

      // 开始确认计时
      _confirmationTimer = Timer(
        Duration(milliseconds: _config.confirmationDelayMs),
        _onConfirmationTimeout,
      );

      debugPrint('[BargeInManager] 检测到可能的打断');
      notifyListeners();
    }
  }

  /// 检测到低能量
  void _onLowEnergy() {
    if (_state == BargeInState.potentialBargeIn) {
      // 取消确认计时器
      _confirmationTimer?.cancel();
      _confirmationTimer = null;

      // 开始取消计时
      _cancellationTimer ??= Timer(
        Duration(milliseconds: _config.cancellationDelayMs),
        _onCancellationTimeout,
      );
    }
  }

  /// 确认打断超时
  void _onConfirmationTimeout() {
    if (_state != BargeInState.potentialBargeIn) return;

    _state = BargeInState.confirmed;

    _emitEvent(BargeInEvent(
      type: BargeInEventType.confirmed,
      timestamp: DateTime.now(),
      confidence: 1.0,
    ));

    debugPrint('[BargeInManager] 打断已确认');
    notifyListeners();
  }

  /// 取消打断超时
  void _onCancellationTimeout() {
    if (_state != BargeInState.potentialBargeIn) return;

    _state = BargeInState.listening;
    _bargeInStartTime = null;

    _emitEvent(BargeInEvent(
      type: BargeInEventType.cancelled,
      timestamp: DateTime.now(),
    ));

    debugPrint('[BargeInManager] 打断已取消（可能是噪音）');
    notifyListeners();
  }

  /// 发送事件
  void _emitEvent(BargeInEvent event) {
    _eventController.add(event);
  }

  /// 重置状态（打断处理完成后调用）
  void reset() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    _cancellationTimer?.cancel();
    _cancellationTimer = null;
    _bargeInStartTime = null;

    if (_isEnabled) {
      _state = BargeInState.listening;
    } else {
      _state = BargeInState.idle;
    }

    notifyListeners();
  }
}
