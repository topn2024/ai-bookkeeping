import 'dart:typed_data';

import 'package:flutter/services.dart';

/// AEC 抑制级别
enum AecSuppressionLevel {
  low,      // 0
  moderate, // 1
  high,     // 2
}

/// NS 抑制级别
enum NsSuppressionLevel {
  low,       // 0
  moderate,  // 1
  high,      // 2
  veryHigh,  // 3
}

/// AGC 模式
enum AgcMode {
  adaptiveAnalog,   // 0 - 自适应模拟增益
  adaptiveDigital,  // 1 - 自适应数字增益
  fixedDigital,     // 2 - 固定数字增益
}

/// WebRTC APM 平台接口
class WebrtcApmPlatform {
  static const MethodChannel _channel = MethodChannel('webrtc_apm');

  /// 初始化 APM
  ///
  /// [sampleRate] 采样率（默认 16000）
  /// [channels] 声道数（默认 1）
  static Future<bool> initialize({
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    final result = await _channel.invokeMethod<bool>('initialize', {
      'sampleRate': sampleRate,
      'channels': channels,
    });
    return result ?? false;
  }

  /// 释放 APM 资源
  static Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
  }

  /// 启用/禁用 AEC（回声消除）
  static Future<bool> setAecEnabled(bool enabled) async {
    final result = await _channel.invokeMethod<bool>('setAecEnabled', {
      'enabled': enabled,
    });
    return result ?? false;
  }

  /// 设置 AEC 抑制级别
  static Future<bool> setAecSuppressionLevel(AecSuppressionLevel level) async {
    final result = await _channel.invokeMethod<bool>('setAecSuppressionLevel', {
      'level': level.index,
    });
    return result ?? false;
  }

  /// 启用/禁用 NS（噪声抑制）
  static Future<bool> setNsEnabled(bool enabled) async {
    final result = await _channel.invokeMethod<bool>('setNsEnabled', {
      'enabled': enabled,
    });
    return result ?? false;
  }

  /// 设置 NS 抑制级别
  static Future<bool> setNsSuppressionLevel(NsSuppressionLevel level) async {
    final result = await _channel.invokeMethod<bool>('setNsSuppressionLevel', {
      'level': level.index,
    });
    return result ?? false;
  }

  /// 启用/禁用 AGC（自动增益控制）
  static Future<bool> setAgcEnabled(bool enabled) async {
    final result = await _channel.invokeMethod<bool>('setAgcEnabled', {
      'enabled': enabled,
    });
    return result ?? false;
  }

  /// 设置 AGC 模式
  static Future<bool> setAgcMode(AgcMode mode) async {
    final result = await _channel.invokeMethod<bool>('setAgcMode', {
      'mode': mode.index,
    });
    return result ?? false;
  }

  /// 设置 AGC 目标电平（dBFS）
  ///
  /// [targetLevelDbfs] 目标电平，范围 0-31，默认 3
  static Future<bool> setAgcTargetLevel(int targetLevelDbfs) async {
    final result = await _channel.invokeMethod<bool>('setAgcTargetLevel', {
      'targetLevelDbfs': targetLevelDbfs,
    });
    return result ?? false;
  }

  /// 处理捕获的音频帧（麦克风输入）
  ///
  /// [audioData] PCM16 格式的音频数据
  /// 返回处理后的音频数据
  static Future<Uint8List?> processCaptureFrame(Uint8List audioData) async {
    final result = await _channel.invokeMethod<Uint8List>('processCaptureFrame', {
      'audioData': audioData,
    });
    return result;
  }

  /// 处理渲染的音频帧（扬声器输出/TTS参考信号）
  ///
  /// [audioData] PCM16 格式的音频数据
  /// AEC 需要知道扬声器播放了什么来消除回声
  static Future<bool> processRenderFrame(Uint8List audioData) async {
    final result = await _channel.invokeMethod<bool>('processRenderFrame', {
      'audioData': audioData,
    });
    return result ?? false;
  }

  /// 获取当前配置状态
  static Future<Map<String, dynamic>> getStatus() async {
    final result = await _channel.invokeMethod<Map>('getStatus');
    return Map<String, dynamic>.from(result ?? {});
  }
}
