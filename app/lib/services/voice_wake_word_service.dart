import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_token_service.dart';

/// 唤醒词检测引擎接口
///
/// 实现此接口以支持不同的唤醒词检测引擎
abstract class WakeWordEngine {
  /// 初始化引擎
  Future<void> initialize({
    required List<String> wakeWords,
    double sensitivity,
  });

  /// 处理音频数据
  ///
  /// 返回检测到的唤醒词索引，-1表示未检测到
  Future<int> processAudio(Int16List audioFrame);

  /// 获取帧长度（采样点数）
  int get frameLength;

  /// 获取采样率
  int get sampleRate;

  /// 释放资源
  void dispose();
}

/// 简单的关键词检测引擎（占位实现）
///
/// 在实际生产中，应使用Porcupine或类似引擎替换
/// 此实现仅用于开发和测试
class SimpleWakeWordEngine implements WakeWordEngine {
  bool _isInitialized = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize({
    required List<String> wakeWords,
    double sensitivity = 0.5,
  }) async {
    _isInitialized = true;
    debugPrint('SimpleWakeWordEngine initialized with words: $wakeWords');
  }

  @override
  Future<int> processAudio(Int16List audioFrame) async {
    // 简单实现：不进行实际检测
    // 在生产环境中，这里应该调用真正的唤醒词检测引擎
    return -1;
  }

  @override
  int get frameLength => 512; // 32ms @ 16kHz

  @override
  int get sampleRate => 16000;

  @override
  void dispose() {
    _isInitialized = false;
  }
}

/// Porcupine唤醒词检测引擎
///
/// 使用Picovoice Porcupine SDK实现高精度的唤醒词检测
///
/// 使用步骤:
/// 1. 在Picovoice Console创建自定义唤醒词
/// 2. 下载.ppn文件放入assets/wake_words/
/// 3. 获取AccessKey并配置到服务器
class PorcupineWakeWordEngine implements WakeWordEngine {
  Porcupine? _porcupine;

  List<String> _wakeWords = [];
  bool _isInitialized = false;

  /// 获取唤醒词列表
  List<String> get wakeWords => List.unmodifiable(_wakeWords);

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// Porcupine AccessKey (从Picovoice Console获取)
  final String? accessKey;

  /// 唤醒词模型文件路径列表（assets中的路径）
  final List<String>? keywordPaths;

  /// 默认唤醒词模型（小记）
  static const String defaultKeywordAsset = 'assets/wake_words/xiaoji_zh.ppn';

  PorcupineWakeWordEngine({
    this.accessKey,
    this.keywordPaths,
  });

  @override
  Future<void> initialize({
    required List<String> wakeWords,
    double sensitivity = 0.5,
  }) async {
    _wakeWords = wakeWords;

    if (accessKey == null || accessKey!.isEmpty) {
      debugPrint('Porcupine AccessKey not configured, engine disabled');
      _isInitialized = false;
      return;
    }

    try {
      // 确定要使用的唤醒词模型路径
      List<String> modelPaths = keywordPaths ?? [defaultKeywordAsset];

      // 从assets加载模型文件到临时目录
      final loadedPaths = await _loadKeywordModels(modelPaths);

      if (loadedPaths.isEmpty) {
        debugPrint('No keyword models loaded, engine disabled');
        _isInitialized = false;
        return;
      }

      // 创建Porcupine实例
      final sensitivities = List.filled(loadedPaths.length, sensitivity);

      _porcupine = await Porcupine.fromKeywordPaths(
        accessKey!,
        loadedPaths,
        sensitivities: sensitivities,
      );

      _isInitialized = true;
      debugPrint('Porcupine initialized successfully with ${loadedPaths.length} keywords');
      debugPrint('Frame length: ${_porcupine!.frameLength}, Sample rate: ${_porcupine!.sampleRate}');
    } on PorcupineException catch (e) {
      debugPrint('Porcupine initialization failed: ${e.message}');
      _isInitialized = false;
    } catch (e) {
      debugPrint('Porcupine initialization error: $e');
      _isInitialized = false;
    }
  }

  /// 从assets加载唤醒词模型到临时目录
  Future<List<String>> _loadKeywordModels(List<String> assetPaths) async {
    final loadedPaths = <String>[];

    for (final assetPath in assetPaths) {
      try {
        // 获取临时目录
        final tempDir = await _getTempDirectory();
        final fileName = assetPath.split('/').last;
        final tempPath = '$tempDir/$fileName';

        // 从assets读取并写入临时文件
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();

        final file = await _writeFile(tempPath, bytes);
        if (file != null) {
          loadedPaths.add(tempPath);
          debugPrint('Loaded keyword model: $assetPath -> $tempPath');
        }
      } catch (e) {
        debugPrint('Failed to load keyword model $assetPath: $e');
      }
    }

    return loadedPaths;
  }

  /// 获取临时目录路径
  Future<String> _getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final porcupineDir = Directory('${tempDir.path}/porcupine_models');
    if (!await porcupineDir.exists()) {
      await porcupineDir.create(recursive: true);
    }
    return porcupineDir.path;
  }

  /// 写入文件
  Future<String?> _writeFile(String path, Uint8List bytes) async {
    try {
      final file = File(path);
      await file.writeAsBytes(bytes);
      return path;
    } catch (e) {
      debugPrint('Failed to write file $path: $e');
      return null;
    }
  }

  @override
  Future<int> processAudio(Int16List audioFrame) async {
    if (!_isInitialized || _porcupine == null) return -1;

    try {
      return await _porcupine!.process(audioFrame);
    } on PorcupineException catch (e) {
      debugPrint('Porcupine process error: ${e.message}');
      return -1;
    } catch (e) {
      debugPrint('Porcupine process error: $e');
      return -1;
    }
  }

  @override
  int get frameLength => _porcupine?.frameLength ?? 512;

  @override
  int get sampleRate => _porcupine?.sampleRate ?? 16000;

  @override
  void dispose() {
    _porcupine?.delete();
    _porcupine = null;
    _isInitialized = false;
  }
}

/// 语音唤醒词服务
/// 支持自定义唤醒词、灵敏度调节、后台检测
class VoiceWakeWordService {
  static final VoiceWakeWordService _instance = VoiceWakeWordService._internal();
  factory VoiceWakeWordService() => _instance;
  VoiceWakeWordService._internal();

  /// 默认唤醒词列表
  /// 注意：每个唤醒词需要对应一个.ppn模型文件
  static const List<String> defaultWakeWords = ['小记'];

  /// 当前启用的唤醒词
  List<String> _enabledWakeWords = [...defaultWakeWords];

  /// 唤醒词检测引擎
  WakeWordEngine? _engine;

  /// 音频录制器
  AudioRecorder? _recorder;

  /// 是否正在监听
  bool _isListening = false;

  /// 灵敏度 (0.0 - 1.0)
  double _sensitivity = 0.5;

  /// 是否启用
  bool _isEnabled = false;

  /// 声纹识别是否启用
  bool _voiceprintEnabled = false;

  /// 唤醒回调
  final StreamController<WakeUpEvent> _wakeUpController =
      StreamController<WakeUpEvent>.broadcast();
  Stream<WakeUpEvent> get onWakeUp => _wakeUpController.stream;

  /// 状态变化流
  final StreamController<WakeWordServiceState> _stateController =
      StreamController<WakeWordServiceState>.broadcast();
  Stream<WakeWordServiceState> get onStateChanged => _stateController.stream;

  /// 初始化服务
  ///
  /// 可以传入自定义引擎，或者Porcupine Access Key。
  /// 如果都不传，会尝试从VoiceTokenService获取key，
  /// 最后降级到SimpleWakeWordEngine（仅用于开发测试）。
  Future<void> initialize({
    WakeWordEngine? engine,
    String? porcupineAccessKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 加载自定义唤醒词
    final customWords = prefs.getStringList('custom_wake_words');
    if (customWords != null && customWords.isNotEmpty) {
      _enabledWakeWords = customWords;
    }

    // 加载灵敏度设置
    _sensitivity = prefs.getDouble('wake_word_sensitivity') ?? 0.5;

    // 加载启用状态
    _isEnabled = prefs.getBool('wake_word_enabled') ?? false;

    // 初始化唤醒词检测引擎
    if (engine != null) {
      _engine = engine;
    } else if (porcupineAccessKey != null && porcupineAccessKey.isNotEmpty) {
      _engine = PorcupineWakeWordEngine(accessKey: porcupineAccessKey);
    } else {
      // 尝试从VoiceTokenService获取Picovoice key
      final tokenServiceKey = await _tryGetPicovoiceKeyFromTokenService();
      if (tokenServiceKey != null && tokenServiceKey.isNotEmpty) {
        _engine = PorcupineWakeWordEngine(accessKey: tokenServiceKey);
      } else {
        _engine = SimpleWakeWordEngine();
      }
    }

    await _engine!.initialize(
      wakeWords: _enabledWakeWords,
      sensitivity: _sensitivity,
    );

    debugPrint('VoiceWakeWordService initialized with words: $_enabledWakeWords');
  }

  /// 尝试从VoiceTokenService获取Picovoice Access Key
  Future<String?> _tryGetPicovoiceKeyFromTokenService() async {
    try {
      final tokenService = VoiceTokenService();
      final tokenInfo = await tokenService.getToken();
      return tokenInfo.picovoiceAccessKey;
    } catch (e) {
      debugPrint('Failed to get Picovoice key from token service: $e');
      return null;
    }
  }

  /// 开始监听唤醒词
  Future<void> startListening() async {
    if (_isListening) return;
    if (_engine == null) {
      throw StateError('Service not initialized');
    }

    _isListening = true;
    _stateController.add(WakeWordServiceState.listening);
    debugPrint('Started listening for wake words: $_enabledWakeWords');

    // 初始化录音器
    _recorder = AudioRecorder();

    // 检查权限
    if (!await _recorder!.hasPermission()) {
      _isListening = false;
      _stateController.add(WakeWordServiceState.permissionDenied);
      throw MicrophonePermissionException(
        '麦克风权限被拒绝，请在设置中授予权限',
        isPermanentlyDenied: false,
      );
    }

    // 开始录音
    final stream = await _recorder!.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _engine!.sampleRate,
      numChannels: 1,
    ));

    // 处理音频流
    _processAudioStream(stream);
  }

  /// 处理音频流
  void _processAudioStream(Stream<Uint8List> stream) async {
    final frameLength = _engine!.frameLength;
    final buffer = <int>[];

    await for (final chunk in stream) {
      if (!_isListening) break;

      // 将字节数据转换为16位整数
      for (var i = 0; i < chunk.length - 1; i += 2) {
        final sample = chunk[i] | (chunk[i + 1] << 8);
        buffer.add(sample < 32768 ? sample : sample - 65536);
      }

      // 当缓冲区有足够数据时处理
      while (buffer.length >= frameLength) {
        final frame = Int16List.fromList(buffer.sublist(0, frameLength));
        buffer.removeRange(0, frameLength);

        final keywordIndex = await _engine!.processAudio(frame);
        if (keywordIndex >= 0 && keywordIndex < _enabledWakeWords.length) {
          _onWakeWordDetected(keywordIndex);
        }
      }
    }
  }

  /// 唤醒词检测回调
  void _onWakeWordDetected(int index) {
    final wakeWord = _enabledWakeWords[index];
    debugPrint('Wake word detected: $wakeWord');

    _wakeUpController.add(WakeUpEvent(
      wakeWord: wakeWord,
      timestamp: DateTime.now(),
      confidence: 0.95, // Porcupine不返回置信度，使用固定值
    ));

    _stateController.add(WakeWordServiceState.wakeWordDetected);
  }

  /// 停止监听
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    await _recorder?.stop();
    _recorder?.dispose();
    _recorder = null;

    _stateController.add(WakeWordServiceState.stopped);
    debugPrint('Stopped listening for wake words');
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
    if (word.length < 2 || word.length > 6) {
      throw ArgumentError('唤醒词长度必须在2-6个字之间');
    }

    if (!_enabledWakeWords.contains(word)) {
      _enabledWakeWords.add(word);
      await _saveSettings();

      // 重新初始化引擎
      await _engine?.initialize(
        wakeWords: _enabledWakeWords,
        sensitivity: _sensitivity,
      );
    }
  }

  /// 移除唤醒词
  Future<void> removeWakeWord(String word) async {
    if (_enabledWakeWords.length <= 1) {
      throw StateError('至少需要保留一个唤醒词');
    }

    _enabledWakeWords.remove(word);
    await _saveSettings();

    // 重新初始化引擎
    await _engine?.initialize(
      wakeWords: _enabledWakeWords,
      sensitivity: _sensitivity,
    );
  }

  /// 设置灵敏度
  Future<void> setSensitivity(double sensitivity) async {
    _sensitivity = sensitivity.clamp(0.0, 1.0);
    await _saveSettings();

    // 重新初始化引擎
    await _engine?.initialize(
      wakeWords: _enabledWakeWords,
      sensitivity: _sensitivity,
    );
  }

  /// 设置启用状态
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wake_word_enabled', enabled);

    if (enabled && !_isListening) {
      await startListening();
    } else if (!enabled && _isListening) {
      await stopListening();
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_wake_words', _enabledWakeWords);
    await prefs.setDouble('wake_word_sensitivity', _sensitivity);
  }

  /// 获取当前唤醒词列表
  List<String> get enabledWakeWords => List.unmodifiable(_enabledWakeWords);

  /// 灵敏度
  double get sensitivity => _sensitivity;

  /// 是否启用
  bool get isEnabled => _isEnabled;

  /// 声纹识别是否启用
  bool get voiceprintEnabled => _voiceprintEnabled;

  /// 设置声纹识别启用状态
  Future<void> setVoiceprintEnabled(bool enabled) async {
    _voiceprintEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voiceprint_enabled', enabled);
  }

  /// 是否正在监听
  bool get isListening => _isListening;

  void dispose() {
    stopListening();
    _engine?.dispose();
    _wakeUpController.close();
    _stateController.close();
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

/// 唤醒词服务状态
enum WakeWordServiceState {
  /// 未初始化
  uninitialized,

  /// 已停止
  stopped,

  /// 正在监听
  listening,

  /// 检测到唤醒词
  wakeWordDetected,

  /// 错误
  error,

  /// 权限被拒绝
  permissionDenied,
}

/// 麦克风权限异常
class MicrophonePermissionException implements Exception {
  final String message;
  final bool isPermanentlyDenied;

  MicrophonePermissionException(
    this.message, {
    this.isPermanentlyDenied = false,
  });

  @override
  String toString() => 'MicrophonePermissionException: $message';
}
