/// Audio Recording Manager
///
/// 负责音频录制的管理器，从 GlobalVoiceAssistantManager 中提取。
/// 遵循单一职责原则，仅处理音频录制相关逻辑。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// 麦克风权限状态
enum MicrophonePermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  unknown,
}

/// 录音状态
enum RecordingState {
  idle,
  preparing,
  recording,
  paused,
  stopping,
  error,
}

/// 音频录制管理器
///
/// 职责：
/// - 管理麦克风权限
/// - 控制录音生命周期
/// - 处理音频数据流
/// - 监听音频振幅
class AudioRecordingManager extends ChangeNotifier {
  /// 录音器实例
  AudioRecorder? _audioRecorder;

  /// 当前录音状态
  RecordingState _state = RecordingState.idle;

  /// 当前音频振幅 (0.0 - 1.0)
  double _amplitude = 0.0;

  /// 录音开始时间
  DateTime? _recordingStartTime;

  /// 振幅监听订阅
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  /// 音频流控制器
  StreamController<Uint8List>? _audioStreamController;

  /// 音频流订阅
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  /// 当前录音状态
  RecordingState get state => _state;

  /// 是否正在录音
  bool get isRecording => _state == RecordingState.recording;

  /// 当前振幅
  double get amplitude => _amplitude;

  /// 录音时长
  Duration? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// 音频数据流
  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;

  // ==================== 初始化 ====================

  /// 初始化录音器
  Future<void> initialize() async {
    if (_audioRecorder != null) return;

    _audioRecorder = AudioRecorder();
    debugPrint('[AudioRecordingManager] 录音器已初始化');
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopRecording();
    await _amplitudeSubscription?.cancel();
    await _audioStreamSubscription?.cancel();
    await _audioStreamController?.close();
    await _audioRecorder?.dispose();
    _audioRecorder = null;
    super.dispose();
  }

  // ==================== 权限管理 ====================

  /// 检查麦克风权限
  Future<MicrophonePermissionStatus> checkPermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return MicrophonePermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return MicrophonePermissionStatus.permanentlyDenied;
    } else if (status.isDenied) {
      return MicrophonePermissionStatus.denied;
    }

    return MicrophonePermissionStatus.unknown;
  }

  /// 请求麦克风权限
  Future<MicrophonePermissionStatus> requestPermission() async {
    final status = await Permission.microphone.request();

    if (status.isGranted) {
      return MicrophonePermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return MicrophonePermissionStatus.permanentlyDenied;
    }

    return MicrophonePermissionStatus.denied;
  }

  // ==================== 录音控制 ====================

  /// 开始录音
  Future<bool> startRecording({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    if (_audioRecorder == null) {
      await initialize();
    }

    // 检查权限
    final permission = await checkPermission();
    if (permission != MicrophonePermissionStatus.granted) {
      final requested = await requestPermission();
      if (requested != MicrophonePermissionStatus.granted) {
        debugPrint('[AudioRecordingManager] 麦克风权限被拒绝');
        return false;
      }
    }

    try {
      _updateState(RecordingState.preparing);

      // 创建音频流（先关闭旧的 StreamController 防止泄漏）
      await _audioStreamController?.close();
      await _audioStreamSubscription?.cancel();
      _audioStreamController = StreamController<Uint8List>.broadcast();

      // 配置录音
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
      );

      // 开始流式录音
      final stream = await _audioRecorder!.startStream(config);

      _audioStreamSubscription = stream.listen(
        (data) {
          _audioStreamController?.add(data);
        },
        onError: (error) {
          debugPrint('[AudioRecordingManager] 音频流错误: $error');
          _updateState(RecordingState.error);
        },
      );

      // 开始监听振幅
      _startAmplitudeMonitoring();

      _recordingStartTime = DateTime.now();
      _updateState(RecordingState.recording);

      debugPrint('[AudioRecordingManager] 录音已开始');
      return true;
    } catch (e) {
      debugPrint('[AudioRecordingManager] 开始录音失败: $e');
      _updateState(RecordingState.error);
      return false;
    }
  }

  /// 停止录音
  Future<void> stopRecording() async {
    if (_state == RecordingState.idle || _state == RecordingState.stopping) return;

    try {
      _updateState(RecordingState.stopping);

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      await _audioRecorder?.stop();

      await _audioStreamController?.close();
      _audioStreamController = null;

      _recordingStartTime = null;
      _amplitude = 0.0;

      _updateState(RecordingState.idle);
      debugPrint('[AudioRecordingManager] 录音已停止');
    } catch (e) {
      debugPrint('[AudioRecordingManager] 停止录音失败: $e');
      _updateState(RecordingState.error);
    }
  }

  /// 暂停录音
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) return;

    try {
      await _audioRecorder?.pause();
      _updateState(RecordingState.paused);
      debugPrint('[AudioRecordingManager] 录音已暂停');
    } catch (e) {
      debugPrint('[AudioRecordingManager] 暂停录音失败: $e');
    }
  }

  /// 恢复录音
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) return;

    try {
      await _audioRecorder?.resume();
      _updateState(RecordingState.recording);
      debugPrint('[AudioRecordingManager] 录音已恢复');
    } catch (e) {
      debugPrint('[AudioRecordingManager] 恢复录音失败: $e');
    }
  }

  // ==================== 私有方法 ====================

  /// 开始监听振幅
  void _startAmplitudeMonitoring() {
    _amplitudeSubscription = _audioRecorder
        ?.onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      // 将 dB 转换为 0-1 的范围
      // dB 通常在 -160 到 0 之间
      final normalizedAmp = ((amp.current + 160) / 160).clamp(0.0, 1.0);
      _amplitude = normalizedAmp;
      notifyListeners();
    });
  }

  /// 更新状态
  void _updateState(RecordingState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }
}
