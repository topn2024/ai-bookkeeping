import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:webrtc_apm/webrtc_apm.dart';
import 'package:webrtc_apm/src/webrtc_apm_platform_interface.dart';

import 'ambient_noise_calibrator.dart';

/// 音频处理服务
///
/// 封装 WebRTC APM 提供软件级的 AEC/NS/AGC 处理
/// 用于在麦克风采集后、发送给 ASR 之前处理音频
///
/// 使用方式：
/// 1. 调用 initialize() 初始化
/// 2. 调用 applyCalibration() 应用环境噪声校准结果
/// 3. TTS 播放时调用 setTTSPlaying(true)
/// 4. 每帧音频调用 processAudio() 处理
/// 5. TTS 停止时调用 setTTSPlaying(false)
class AudioProcessorService {
  static AudioProcessorService? _instance;
  static AudioProcessorService get instance {
    _instance ??= AudioProcessorService._internal();
    return _instance!;
  }

  AudioProcessorService._internal();

  final WebrtcAudioProcessor _processor = WebrtcAudioProcessor();

  bool _isInitialized = false;
  bool _isEnabled = true;
  CalibrationResult? _calibrationResult;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否启用处理
  bool get isEnabled => _isEnabled;

  /// 当前校准结果
  CalibrationResult? get calibrationResult => _calibrationResult;

  /// 初始化音频处理器
  ///
  /// [sampleRate] 采样率，默认 16000
  /// [channels] 声道数，默认 1
  Future<bool> initialize({
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    if (_isInitialized) {
      debugPrint('[AudioProcessorService] 已初始化');
      return true;
    }

    try {
      debugPrint('[AudioProcessorService] 开始初始化 WebRTC APM...');

      final success = await _processor.initialize(
        sampleRate: sampleRate,
        channels: channels,
        enableAec: true,
        enableNs: true,
        enableAgc: true,
      );

      _isInitialized = success;
      debugPrint('[AudioProcessorService] 初始化${success ? "成功" : "失败"}');
      return success;
    } catch (e) {
      debugPrint('[AudioProcessorService] 初始化异常: $e');
      return false;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await _processor.dispose();
      _isInitialized = false;
      _instance = null; // 重置单例，允许重新初始化
      debugPrint('[AudioProcessorService] 已释放');
    } catch (e) {
      debugPrint('[AudioProcessorService] 释放异常: $e');
    }
  }

  /// 启用/禁用处理
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('[AudioProcessorService] 处理${enabled ? "启用" : "禁用"}');
  }

  /// 设置 TTS 播放状态
  ///
  /// TTS 播放时 AEC 会更积极地消除回声
  void setTTSPlaying(bool playing) {
    _processor.setTTSPlaying(playing);
  }

  /// 处理麦克风采集的音频
  ///
  /// [audioData] PCM16 格式的音频数据（16kHz, mono）
  /// 返回处理后的干净音频
  Future<Uint8List> processAudio(Uint8List audioData) async {
    if (!_isInitialized || !_isEnabled) {
      return audioData;
    }

    try {
      final result = await _processor.processAudio(audioData);
      return result ?? audioData;
    } catch (e) {
      debugPrint('[AudioProcessorService] 处理音频异常: $e');
      return audioData;
    }
  }

  /// 输入 TTS 播放的音频作为 AEC 参考信号
  ///
  /// [audioData] TTS 播放的 PCM16 音频数据
  /// AEC 需要知道扬声器播放了什么来消除回声
  Future<void> feedTTSAudio(Uint8List audioData) async {
    if (!_isInitialized) return;

    try {
      await _processor.feedRenderAudio(audioData);
    } catch (e) {
      debugPrint('[AudioProcessorService] 输入TTS音频异常: $e');
    }
  }

  /// 启用/禁用 AEC
  Future<void> setAecEnabled(bool enabled) async {
    if (!_isInitialized) return;
    await _processor.setAecEnabled(enabled);
  }

  /// 启用/禁用 NS
  Future<void> setNsEnabled(bool enabled) async {
    if (!_isInitialized) return;
    await _processor.setNsEnabled(enabled);
  }

  /// 启用/禁用 AGC
  Future<void> setAgcEnabled(bool enabled) async {
    if (!_isInitialized) return;
    await _processor.setAgcEnabled(enabled);
  }

  /// 应用环境噪声校准结果
  ///
  /// 根据校准结果动态调整 NS 抑制级别（自适应模式）
  Future<void> applyCalibration(CalibrationResult result) async {
    _calibrationResult = result;

    if (!_isInitialized) {
      debugPrint('[AudioProcessorService] 未初始化，保存校准结果待初始化后应用');
      return;
    }

    debugPrint('[AudioProcessorService] 应用校准结果: $result');

    // 根据校准结果设置 NS 抑制级别（自适应模式）
    final nsLevel = _mapNsSuppressionLevel(result.nsSuppressionLevel);
    await WebrtcApmPlatform.setNsSuppressionLevel(nsLevel);

    debugPrint('[AudioProcessorService] NS 抑制级别已设置为: $nsLevel');
  }

  /// 映射 NS 抑制级别到枚举（保留用于调试）
  NsSuppressionLevel _mapNsSuppressionLevel(int level) {
    switch (level) {
      case 0:
        return NsSuppressionLevel.low;
      case 1:
        return NsSuppressionLevel.moderate;
      case 2:
        return NsSuppressionLevel.high;
      case 3:
        return NsSuppressionLevel.veryHigh;
      default:
        return NsSuppressionLevel.moderate;
    }
  }

  /// 获取状态信息（用于调试）
  Future<Map<String, dynamic>> getStatus() async {
    final status = await _processor.getStatus();
    if (_calibrationResult != null) {
      status['calibration'] = {
        'level': _calibrationResult!.level.toString(),
        'noiseFloorRms': _calibrationResult!.noiseFloorRms,
        'agcThreshold': _calibrationResult!.agcThreshold,
        'nsSuppressionLevel': _calibrationResult!.nsSuppressionLevel,
        'isDefault': _calibrationResult!.isDefault,
      };
    }
    return status;
  }
}
