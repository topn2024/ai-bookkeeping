import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'webrtc_apm_platform_interface.dart';

/// WebRTC 音频处理器
///
/// 提供软件级的 AEC/NS/AGC 处理：
/// - 在录音后、发送给 ASR 前处理音频
/// - TTS 播放时设置参考信号用于 AEC
///
/// 使用示例：
/// ```dart
/// final processor = WebrtcAudioProcessor();
/// await processor.initialize();
///
/// // TTS 播放时设置参考信号
/// processor.setTTSPlaying(true);
/// await processor.feedRenderAudio(ttsAudioData);
///
/// // 处理麦克风输入
/// final cleanAudio = await processor.processAudio(microphoneData);
/// // cleanAudio 可以发送给 ASR
/// ```
class WebrtcAudioProcessor {
  bool _isInitialized = false;
  bool _isTTSPlaying = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// TTS 是否正在播放
  bool get isTTSPlaying => _isTTSPlaying;

  /// 初始化处理器
  ///
  /// [sampleRate] 采样率，默认 16000（与 ASR 一致）
  /// [channels] 声道数，默认 1（单声道）
  /// [enableAec] 是否启用 AEC，默认 true
  /// [enableNs] 是否启用 NS，默认 true
  /// [enableAgc] 是否启用 AGC，默认 true
  Future<bool> initialize({
    int sampleRate = 16000,
    int channels = 1,
    bool enableAec = true,
    bool enableNs = true,
    bool enableAgc = true,
  }) async {
    if (_isInitialized) {
      debugPrint('[WebrtcAudioProcessor] 已初始化，跳过');
      return true;
    }

    try {
      debugPrint('[WebrtcAudioProcessor] 开始初始化...');

      // 初始化 APM
      final success = await WebrtcApmPlatform.initialize(
        sampleRate: sampleRate,
        channels: channels,
      );

      if (!success) {
        debugPrint('[WebrtcAudioProcessor] 初始化失败');
        return false;
      }

      // 配置 AEC
      if (enableAec) {
        await WebrtcApmPlatform.setAecEnabled(true);
        await WebrtcApmPlatform.setAecSuppressionLevel(
          AecSuppressionLevel.high,
        );
        debugPrint('[WebrtcAudioProcessor] AEC 已启用 (high)');
      }

      // 配置 NS
      if (enableNs) {
        await WebrtcApmPlatform.setNsEnabled(true);
        await WebrtcApmPlatform.setNsSuppressionLevel(
          NsSuppressionLevel.high,
        );
        debugPrint('[WebrtcAudioProcessor] NS 已启用 (high)');
      }

      // 配置 AGC
      if (enableAgc) {
        await WebrtcApmPlatform.setAgcEnabled(true);
        await WebrtcApmPlatform.setAgcMode(AgcMode.adaptiveDigital);
        await WebrtcApmPlatform.setAgcTargetLevel(3);
        debugPrint('[WebrtcAudioProcessor] AGC 已启用 (adaptiveDigital)');
      }

      _isInitialized = true;
      debugPrint('[WebrtcAudioProcessor] 初始化完成');
      return true;
    } catch (e) {
      debugPrint('[WebrtcAudioProcessor] 初始化异常: $e');
      return false;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await WebrtcApmPlatform.dispose();
      _isInitialized = false;
      debugPrint('[WebrtcAudioProcessor] 已释放');
    } catch (e) {
      debugPrint('[WebrtcAudioProcessor] 释放异常: $e');
    }
  }

  /// 设置 TTS 播放状态
  ///
  /// TTS 播放时应调用 setTTSPlaying(true)
  /// TTS 停止时应调用 setTTSPlaying(false)
  void setTTSPlaying(bool playing) {
    _isTTSPlaying = playing;
    debugPrint('[WebrtcAudioProcessor] TTS 播放状态: $playing');
  }

  /// 处理麦克风捕获的音频
  ///
  /// [audioData] PCM16 格式的音频数据
  /// 返回处理后的干净音频，或 null 如果处理失败
  Future<Uint8List?> processAudio(Uint8List audioData) async {
    if (!_isInitialized) {
      debugPrint('[WebrtcAudioProcessor] 未初始化，返回原始数据');
      return audioData;
    }

    try {
      final result = await WebrtcApmPlatform.processCaptureFrame(audioData);
      return result ?? audioData;
    } catch (e) {
      debugPrint('[WebrtcAudioProcessor] 处理音频异常: $e');
      return audioData;
    }
  }

  /// 输入 TTS/扬声器播放的音频（AEC 参考信号）
  ///
  /// [audioData] PCM16 格式的音频数据
  /// AEC 需要知道扬声器播放了什么来准确消除回声
  Future<void> feedRenderAudio(Uint8List audioData) async {
    if (!_isInitialized) return;

    try {
      await WebrtcApmPlatform.processRenderFrame(audioData);
    } catch (e) {
      debugPrint('[WebrtcAudioProcessor] 输入参考信号异常: $e');
    }
  }

  /// 启用/禁用 AEC
  Future<void> setAecEnabled(bool enabled) async {
    if (!_isInitialized) return;
    await WebrtcApmPlatform.setAecEnabled(enabled);
  }

  /// 启用/禁用 NS
  Future<void> setNsEnabled(bool enabled) async {
    if (!_isInitialized) return;
    await WebrtcApmPlatform.setNsEnabled(enabled);
  }

  /// 启用/禁用 AGC
  Future<void> setAgcEnabled(bool enabled) async {
    if (!_isInitialized) return;
    await WebrtcApmPlatform.setAgcEnabled(enabled);
  }

  /// 获取状态信息（用于调试）
  Future<Map<String, dynamic>> getStatus() async {
    if (!_isInitialized) {
      return {'initialized': false};
    }
    final status = await WebrtcApmPlatform.getStatus();
    status['initialized'] = true;
    status['isTTSPlaying'] = _isTTSPlaying;
    return status;
  }
}
