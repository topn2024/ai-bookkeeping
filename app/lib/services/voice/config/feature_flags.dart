import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 语音功能特性开关
///
/// 用于控制语音处理功能的开关，支持：
/// - 运行时切换
/// - 持久化存储
/// - 调试模式
///
/// 当前架构：流水线模式为默认且唯一的语音处理模式
class VoiceFeatureFlags {
  static VoiceFeatureFlags? _instance;
  static VoiceFeatureFlags get instance {
    _instance ??= VoiceFeatureFlags._internal();
    return _instance!;
  }

  VoiceFeatureFlags._internal();

  static const String _keyEnableBargeInV2 = 'voice_enable_barge_in_v2';
  static const String _keyEnableEchoFilter = 'voice_enable_echo_filter';
  static const String _keyDebugMode = 'voice_debug_mode';

  /// 流水线模式始终启用（当前唯一的语音处理模式）
  bool get usePipelineMode => true;

  /// 是否启用三层打断检测 V2
  bool _enableBargeInV2 = true;
  bool get enableBargeInV2 => _enableBargeInV2;

  /// 是否启用回声过滤
  bool _enableEchoFilter = true;
  bool get enableEchoFilter => _enableEchoFilter;

  /// 调试模式（输出详细日志）
  bool _debugMode = kDebugMode;
  bool get debugMode => _debugMode;

  /// 是否已加载配置
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// 从持久化存储加载配置
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      _enableBargeInV2 = prefs.getBool(_keyEnableBargeInV2) ?? true;
      _enableEchoFilter = prefs.getBool(_keyEnableEchoFilter) ?? true;
      _debugMode = prefs.getBool(_keyDebugMode) ?? kDebugMode;

      _isLoaded = true;
      debugPrint('[VoiceFeatureFlags] 配置已加载: '
          'pipelineMode=true, '
          'bargeInV2=$_enableBargeInV2, '
          'echoFilter=$_enableEchoFilter, '
          'debug=$_debugMode');
    } catch (e) {
      debugPrint('[VoiceFeatureFlags] 加载配置失败: $e');
    }
  }

  /// 设置三层打断检测 V2
  Future<void> setEnableBargeInV2(bool value) async {
    if (_enableBargeInV2 == value) return;

    _enableBargeInV2 = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnableBargeInV2, value);
      debugPrint('[VoiceFeatureFlags] 三层打断V2已设置: $value');
    } catch (e) {
      debugPrint('[VoiceFeatureFlags] 保存配置失败: $e');
    }
  }

  /// 设置回声过滤
  Future<void> setEnableEchoFilter(bool value) async {
    if (_enableEchoFilter == value) return;

    _enableEchoFilter = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnableEchoFilter, value);
      debugPrint('[VoiceFeatureFlags] 回声过滤已设置: $value');
    } catch (e) {
      debugPrint('[VoiceFeatureFlags] 保存配置失败: $e');
    }
  }

  /// 设置调试模式
  Future<void> setDebugMode(bool value) async {
    if (_debugMode == value) return;

    _debugMode = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDebugMode, value);
      debugPrint('[VoiceFeatureFlags] 调试模式已设置: $value');
    } catch (e) {
      debugPrint('[VoiceFeatureFlags] 保存配置失败: $e');
    }
  }

  /// 重置为默认配置
  Future<void> reset() async {
    _enableBargeInV2 = true;
    _enableEchoFilter = true;
    _debugMode = kDebugMode;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEnableBargeInV2);
      await prefs.remove(_keyEnableEchoFilter);
      await prefs.remove(_keyDebugMode);
      debugPrint('[VoiceFeatureFlags] 配置已重置');
    } catch (e) {
      debugPrint('[VoiceFeatureFlags] 重置配置失败: $e');
    }
  }

  /// 获取所有配置的摘要（用于调试）
  Map<String, dynamic> toMap() => {
        'usePipelineMode': true,
        'enableBargeInV2': _enableBargeInV2,
        'enableEchoFilter': _enableEchoFilter,
        'debugMode': _debugMode,
      };

  @override
  String toString() => 'VoiceFeatureFlags(${toMap()})';
}
