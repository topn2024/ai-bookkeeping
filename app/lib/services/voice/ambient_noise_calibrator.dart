import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// 环境噪声级别
enum NoiseLevel {
  quiet,      // 安静 < 50
  moderate,   // 一般 50-200
  noisy,      // 嘈杂 200-500
  veryNoisy,  // 非常嘈杂 > 500
}

/// 校准结果
class CalibrationResult {
  final NoiseLevel level;
  final double noiseFloorRms;
  final int agcThreshold;
  final int nsSuppressionLevel;
  final bool isDefault;

  const CalibrationResult({
    required this.level,
    required this.noiseFloorRms,
    required this.agcThreshold,
    required this.nsSuppressionLevel,
    this.isDefault = false,
  });

  /// 默认值（未完成检测时使用）
  factory CalibrationResult.defaultValues() {
    return const CalibrationResult(
      level: NoiseLevel.moderate,
      noiseFloorRms: 100,
      agcThreshold: 100,
      nsSuppressionLevel: 1,
      isDefault: true,
    );
  }

  @override
  String toString() {
    return 'CalibrationResult(level: $level, rms: ${noiseFloorRms.toStringAsFixed(1)}, '
        'agcThreshold: $agcThreshold, nsLevel: $nsSuppressionLevel, isDefault: $isDefault)';
  }
}

/// 环境噪声校准器
///
/// 在 App 启动时检测环境噪声，动态调整 AGC 和 NS 参数
class AmbientNoiseCalibrator {
  static AmbientNoiseCalibrator? _instance;
  static AmbientNoiseCalibrator get instance {
    _instance ??= AmbientNoiseCalibrator._internal();
    return _instance!;
  }

  AmbientNoiseCalibrator._internal();

  final AudioRecorder _recorder = AudioRecorder();

  bool _isCalibrating = false;
  bool _isCalibrationComplete = false;
  CalibrationResult? _result;

  final List<double> _rmsValues = [];
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _calibrationTimer;
  Completer<CalibrationResult>? _completer;

  /// 是否正在校准
  bool get isCalibrating => _isCalibrating;

  /// 校准是否完成
  bool get isCalibrationComplete => _isCalibrationComplete;

  /// 获取校准结果（如果未完成返回默认值）
  CalibrationResult get result => _result ?? CalibrationResult.defaultValues();

  /// 开始环境噪声校准
  ///
  /// [duration] 检测时长，默认3秒
  /// 返回校准结果
  Future<CalibrationResult> startCalibration({
    Duration duration = const Duration(seconds: 3),
  }) async {
    if (_isCalibrating) {
      debugPrint('[AmbientNoiseCalibrator] 已在校准中，返回现有 Future');
      return _completer!.future;
    }

    if (_isCalibrationComplete && _result != null) {
      debugPrint('[AmbientNoiseCalibrator] 已完成校准，返回缓存结果');
      return _result!;
    }

    _isCalibrating = true;
    _rmsValues.clear();
    _completer = Completer<CalibrationResult>();

    debugPrint('[AmbientNoiseCalibrator] 开始环境噪声检测，时长: ${duration.inSeconds}秒');

    try {
      // 检查麦克风权限
      if (!await _recorder.hasPermission()) {
        debugPrint('[AmbientNoiseCalibrator] 无麦克风权限，使用默认值');
        _finishWithDefault();
        return _completer!.future;
      }

      // 开始录音
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      // 监听音频数据
      _audioSubscription = stream.listen(
        _processAudioData,
        onError: (error) {
          debugPrint('[AmbientNoiseCalibrator] 录音错误: $error');
          _finishWithDefault();
        },
      );

      // 设置超时定时器
      _calibrationTimer = Timer(duration, () {
        _finishCalibration();
      });

    } catch (e) {
      debugPrint('[AmbientNoiseCalibrator] 启动录音失败: $e');
      _finishWithDefault();
    }

    return _completer!.future;
  }

  /// 取消校准（用户提前点击悬浮球）
  /// 返回当前结果或默认值
  CalibrationResult cancelAndGetResult() {
    if (_isCalibrationComplete && _result != null) {
      return _result!;
    }

    debugPrint('[AmbientNoiseCalibrator] 校准被取消，使用已采集数据或默认值');

    if (_rmsValues.isNotEmpty) {
      // 使用已采集的数据计算结果
      _calculateResult();
    } else {
      // 使用默认值
      _finishWithDefault();
    }

    return _result ?? CalibrationResult.defaultValues();
  }

  /// 处理音频数据
  void _processAudioData(Uint8List audioData) {
    if (!_isCalibrating) return;

    // 计算 RMS
    final samples = _bytesToInt16(audioData);
    if (samples.isEmpty) return;

    double sumSquares = 0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    final rms = sqrt(sumSquares / samples.length);
    _rmsValues.add(rms);
  }

  /// 将字节数据转换为 Int16 数组
  List<int> _bytesToInt16(Uint8List bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final value = bytes[i] | (bytes[i + 1] << 8);
      // 转换为有符号数
      result.add(value > 32767 ? value - 65536 : value);
    }
    return result;
  }

  /// 完成校准，计算结果
  void _finishCalibration() {
    _stopRecording();

    if (_rmsValues.isEmpty) {
      _finishWithDefault();
      return;
    }

    _calculateResult();
  }

  /// 计算校准结果
  void _calculateResult() {
    _stopRecording();

    if (_rmsValues.isEmpty) {
      _finishWithDefault();
      return;
    }

    // 计算平均 RMS（去掉最高和最低 10% 的异常值）
    final sorted = List<double>.from(_rmsValues)..sort();
    final trimCount = (sorted.length * 0.1).floor();
    final trimmed = sorted.sublist(
      trimCount,
      sorted.length - trimCount > trimCount ? sorted.length - trimCount : sorted.length,
    );

    final avgRms = trimmed.isEmpty
        ? sorted.reduce((a, b) => a + b) / sorted.length
        : trimmed.reduce((a, b) => a + b) / trimmed.length;

    // 根据 RMS 确定噪声级别和参数
    NoiseLevel level;
    int agcThreshold;
    int nsSuppressionLevel;

    if (avgRms < 50) {
      level = NoiseLevel.quiet;
      agcThreshold = 30;
      nsSuppressionLevel = 0;
    } else if (avgRms < 200) {
      level = NoiseLevel.moderate;
      agcThreshold = 100;
      nsSuppressionLevel = 1;
    } else if (avgRms < 500) {
      level = NoiseLevel.noisy;
      agcThreshold = 200;
      nsSuppressionLevel = 2;
    } else {
      level = NoiseLevel.veryNoisy;
      agcThreshold = 300;
      nsSuppressionLevel = 3;
    }

    _result = CalibrationResult(
      level: level,
      noiseFloorRms: avgRms,
      agcThreshold: agcThreshold,
      nsSuppressionLevel: nsSuppressionLevel,
    );

    _isCalibrating = false;
    _isCalibrationComplete = true;

    debugPrint('[AmbientNoiseCalibrator] 校准完成: $_result');

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(_result);
    }
  }

  /// 使用默认值完成
  void _finishWithDefault() {
    _stopRecording();

    _result = CalibrationResult.defaultValues();
    _isCalibrating = false;
    _isCalibrationComplete = true;

    debugPrint('[AmbientNoiseCalibrator] 使用默认值: $_result');

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(_result);
    }
  }

  /// 停止录音
  void _stopRecording() {
    _calibrationTimer?.cancel();
    _calibrationTimer = null;

    _audioSubscription?.cancel();
    _audioSubscription = null;

    _recorder.stop().catchError((e) {
      debugPrint('[AmbientNoiseCalibrator] 停止录音错误: $e');
    });
  }

  /// 重置校准状态（用于重新校准）
  void reset() {
    _stopRecording();
    _isCalibrating = false;
    _isCalibrationComplete = false;
    _result = null;
    _rmsValues.clear();
    debugPrint('[AmbientNoiseCalibrator] 已重置');
  }

  /// 释放资源
  void dispose() {
    _stopRecording();
    _recorder.dispose();
  }
}
