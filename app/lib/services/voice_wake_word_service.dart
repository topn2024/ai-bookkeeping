import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 语音唤醒词服务
/// 支持自定义唤醒词、声纹识别、连续指令识别
class VoiceWakeWordService {
  static final VoiceWakeWordService _instance = VoiceWakeWordService._internal();
  factory VoiceWakeWordService() => _instance;
  VoiceWakeWordService._internal();

  /// 默认唤醒词列表
  static const List<String> defaultWakeWords = ['小记', '记一下', '嘿记账'];

  /// 当前启用的唤醒词
  List<String> _enabledWakeWords = [...defaultWakeWords];

  /// 是否启用声纹识别
  bool _voiceprintEnabled = false;

  /// 是否正在监听
  bool _isListening = false;

  /// 唤醒回调
  final StreamController<WakeUpEvent> _wakeUpController = StreamController<WakeUpEvent>.broadcast();
  Stream<WakeUpEvent> get onWakeUp => _wakeUpController.stream;

  /// 初始化服务
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载自定义唤醒词
    final customWords = prefs.getStringList('custom_wake_words');
    if (customWords != null && customWords.isNotEmpty) {
      _enabledWakeWords = customWords;
    }

    // 加载声纹识别设置
    _voiceprintEnabled = prefs.getBool('voiceprint_enabled') ?? false;

    debugPrint('VoiceWakeWordService initialized with words: $_enabledWakeWords');
  }

  /// 开始监听唤醒词
  Future<void> startListening() async {
    if (_isListening) return;

    _isListening = true;
    debugPrint('Started listening for wake words: $_enabledWakeWords');

    // TODO: 集成端侧唤醒词检测引擎
    // 可以使用 Porcupine、Snowboy 或其他轻量级唤醒词引擎
  }

  /// 停止监听
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    debugPrint('Stopped listening for wake words');
  }

  /// 处理音频数据（用于唤醒词检测）
  void processAudioData(List<int> audioData) {
    if (!_isListening) return;

    // TODO: 将音频数据传递给唤醒词检测引擎
    // 检测到唤醒词后触发回调
  }

  /// 模拟检测到唤醒词（用于测试）
  void simulateWakeWord(String wakeWord, {String? followingText}) {
    if (_enabledWakeWords.contains(wakeWord)) {
      _wakeUpController.add(WakeUpEvent(
        wakeWord: wakeWord,
        followingText: followingText,
        timestamp: DateTime.now(),
        confidence: 0.95,
      ));
    }
  }

  /// 添加自定义唤醒词
  Future<void> addCustomWakeWord(String word) async {
    if (word.length < 2 || word.length > 4) {
      throw ArgumentError('唤醒词长度必须在2-4个字之间');
    }

    if (!_enabledWakeWords.contains(word)) {
      _enabledWakeWords.add(word);
      await _saveWakeWords();
    }
  }

  /// 移除唤醒词
  Future<void> removeWakeWord(String word) async {
    _enabledWakeWords.remove(word);
    await _saveWakeWords();
  }

  /// 设置声纹识别
  Future<void> setVoiceprintEnabled(bool enabled) async {
    _voiceprintEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voiceprint_enabled', enabled);
  }

  /// 保存唤醒词设置
  Future<void> _saveWakeWords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_wake_words', _enabledWakeWords);
  }

  /// 获取当前唤醒词列表
  List<String> get enabledWakeWords => List.unmodifiable(_enabledWakeWords);

  /// 是否启用声纹识别
  bool get voiceprintEnabled => _voiceprintEnabled;

  /// 是否正在监听
  bool get isListening => _isListening;

  void dispose() {
    _wakeUpController.close();
  }
}

/// 唤醒事件
class WakeUpEvent {
  /// 检测到的唤醒词
  final String wakeWord;

  /// 唤醒词后的连续指令文本
  final String? followingText;

  /// 时间戳
  final DateTime timestamp;

  /// 置信度 (0-1)
  final double confidence;

  WakeUpEvent({
    required this.wakeWord,
    this.followingText,
    required this.timestamp,
    required this.confidence,
  });

  @override
  String toString() {
    return 'WakeUpEvent(wakeWord: $wakeWord, followingText: $followingText, confidence: $confidence)';
  }
}
