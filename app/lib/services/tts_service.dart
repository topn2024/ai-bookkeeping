import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 文字转语音服务（TTS）
///
/// 功能：
/// 1. 文本转语音合成
/// 2. 语音播报
/// 3. 语音设置（语速、音量、音色）
/// 4. 离线TTS支持
class TTSService {
  final TTSEngine _engine;
  final TTSSettings _settings;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  final _speakingController = StreamController<TTSSpeakingState>.broadcast();

  TTSService({
    TTSEngine? engine,
    TTSSettings? settings,
  })  : _engine = engine ?? DefaultTTSEngine(),
        _settings = settings ?? TTSSettings.defaultSettings();

  /// 是否正在播报
  bool get isSpeaking => _isSpeaking;

  /// 播报状态��
  Stream<TTSSpeakingState> get speakingStream => _speakingController.stream;

  /// 初始化TTS引擎
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _engine.initialize();
      await _applySettings();
      _isInitialized = true;
      debugPrint('TTS service initialized');
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
      rethrow;
    }
  }

  /// 应用设置
  Future<void> _applySettings() async {
    await _engine.setRate(_settings.rate);
    await _engine.setVolume(_settings.volume);
    await _engine.setPitch(_settings.pitch);
    await _engine.setLanguage(_settings.language);

    if (_settings.voiceName != null) {
      await _engine.setVoice(_settings.voiceName!);
    }
  }

  /// 朗读文本
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.trim().isEmpty) return;

    if (interrupt && _isSpeaking) {
      await stop();
    }

    try {
      _isSpeaking = true;
      _speakingController.add(TTSSpeakingState.started);

      await _engine.speak(text);

      _isSpeaking = false;
      _speakingController.add(TTSSpeakingState.completed);
    } catch (e) {
      _isSpeaking = false;
      _speakingController.add(TTSSpeakingState.error);
      debugPrint('TTS speak failed: $e');
      rethrow;
    }
  }

  /// 朗读记账结果
  Future<void> speakTransactionResult({
    required String type, // 'expense' or 'income'
    required double amount,
    String? category,
    String? merchant,
  }) async {
    final typeText = type == 'expense' ? '支出' : '收入';
    final buffer = StringBuffer();

    buffer.write('已记录$typeText');
    buffer.write(_formatAmount(amount));

    if (category != null) {
      buffer.write('，分类$category');
    }

    if (merchant != null) {
      buffer.write('，商家$merchant');
    }

    await speak(buffer.toString());
  }

  /// 朗读查询结果
  Future<void> speakQueryResult({
    required String period, // '今天', '本月' 等
    required double total,
    int? count,
  }) async {
    final buffer = StringBuffer();

    buffer.write('$period共消费');
    buffer.write(_formatAmount(total));

    if (count != null) {
      buffer.write('，共$count笔');
    }

    await speak(buffer.toString());
  }

  /// 朗读异常提醒
  Future<void> speakAnomaly({
    required String type,
    required String message,
  }) async {
    await speak('提醒：$message');
  }

  /// 朗读帮助信息
  Future<void> speakHelp() async {
    const helpText = '''
您可以说：
记一笔支出，30元午餐。
查询本月消费。
生成月度报告。
''';
    await speak(helpText);
  }

  /// 格式化金额播报
  String _formatAmount(double amount) {
    if (amount >= 10000) {
      final wan = amount / 10000;
      if (wan == wan.truncate()) {
        return '${wan.truncate()}万元';
      }
      return '${wan.toStringAsFixed(1)}万元';
    }

    if (amount == amount.truncate()) {
      return '${amount.truncate()}元';
    }

    // 处理小数
    final parts = amount.toStringAsFixed(2).split('.');
    final yuan = parts[0];
    final jiao = parts[1][0];
    final fen = parts[1][1];

    if (fen == '0') {
      if (jiao == '0') {
        return '$yuan元';
      }
      return '$yuan元$jiao角';
    }

    return '$yuan元$jiao角$fen分';
  }

  /// 停止播报
  Future<void> stop() async {
    if (!_isSpeaking) return;

    try {
      await _engine.stop();
      _isSpeaking = false;
      _speakingController.add(TTSSpeakingState.stopped);
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  /// 暂停播报
  Future<void> pause() async {
    if (!_isSpeaking) return;

    try {
      await _engine.pause();
      _speakingController.add(TTSSpeakingState.paused);
    } catch (e) {
      debugPrint('TTS pause failed: $e');
    }
  }

  /// 恢复播报
  Future<void> resume() async {
    try {
      await _engine.resume();
      _speakingController.add(TTSSpeakingState.resumed);
    } catch (e) {
      debugPrint('TTS resume failed: $e');
    }
  }

  /// 更新设置
  Future<void> updateSettings(TTSSettings newSettings) async {
    _settings.rate = newSettings.rate;
    _settings.volume = newSettings.volume;
    _settings.pitch = newSettings.pitch;
    _settings.language = newSettings.language;
    _settings.voiceName = newSettings.voiceName;

    if (_isInitialized) {
      await _applySettings();
    }
  }

  /// 获取可用的语音列表
  Future<List<TTSVoice>> getAvailableVoices() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _engine.getAvailableVoices();
  }

  /// 获取当前设置
  TTSSettings get currentSettings => _settings;

  /// 合成音频（不播放）
  Future<Uint8List?> synthesize(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _engine.synthesize(text);
  }

  /// 释放资源
  void dispose() {
    stop();
    _speakingController.close();
    _engine.dispose();
  }
}

// ==================== TTS引擎接口 ====================

/// TTS引擎接口
abstract class TTSEngine {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setPitch(double pitch);
  Future<void> setLanguage(String language);
  Future<void> setVoice(String voiceName);
  Future<List<TTSVoice>> getAvailableVoices();
  Future<Uint8List?> synthesize(String text);
  void dispose();
}

/// 默认TTS引擎实现（模拟）
class DefaultTTSEngine implements TTSEngine {
  double _rate = 1.0;
  double _volume = 1.0;
  double _pitch = 1.0;
  String _language = 'zh-CN';
  String? _voice;

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('TTS engine initialized');
  }

  @override
  Future<void> speak(String text) async {
    // 模拟播报时间（基于文本长度）
    final duration = Duration(milliseconds: text.length * 100);
    debugPrint('TTS speaking: $text (duration: ${duration.inMilliseconds}ms)');
    await Future.delayed(duration);
  }

  @override
  Future<void> stop() async {
    debugPrint('TTS stopped');
  }

  @override
  Future<void> pause() async {
    debugPrint('TTS paused');
  }

  @override
  Future<void> resume() async {
    debugPrint('TTS resumed');
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.5, 2.0);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
  }

  @override
  Future<void> setLanguage(String language) async {
    _language = language;
  }

  @override
  Future<void> setVoice(String voiceName) async {
    _voice = voiceName;
  }

  @override
  Future<List<TTSVoice>> getAvailableVoices() async {
    return [
      const TTSVoice(
        name: 'zh-CN-Standard-A',
        language: 'zh-CN',
        gender: TTSGender.female,
        displayName: '普通话女声',
      ),
      const TTSVoice(
        name: 'zh-CN-Standard-B',
        language: 'zh-CN',
        gender: TTSGender.male,
        displayName: '普通话男声',
      ),
      const TTSVoice(
        name: 'zh-CN-Standard-C',
        language: 'zh-CN',
        gender: TTSGender.female,
        displayName: '普通话甜美女声',
      ),
    ];
  }

  @override
  Future<Uint8List?> synthesize(String text) async {
    // 实际实现需要调用TTS API
    await Future.delayed(const Duration(milliseconds: 300));
    return null;
  }

  @override
  void dispose() {
    debugPrint('TTS engine disposed');
  }
}

// ==================== 数据模型 ====================

/// TTS设置
class TTSSettings {
  double rate; // 语速 0.5-2.0
  double volume; // 音量 0.0-1.0
  double pitch; // 音调 0.5-2.0
  String language; // 语言
  String? voiceName; // 语音名称

  TTSSettings({
    required this.rate,
    required this.volume,
    required this.pitch,
    required this.language,
    this.voiceName,
  });

  factory TTSSettings.defaultSettings() {
    return TTSSettings(
      rate: 1.0,
      volume: 1.0,
      pitch: 1.0,
      language: 'zh-CN',
    );
  }

  TTSSettings copyWith({
    double? rate,
    double? volume,
    double? pitch,
    String? language,
    String? voiceName,
  }) {
    return TTSSettings(
      rate: rate ?? this.rate,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      language: language ?? this.language,
      voiceName: voiceName ?? this.voiceName,
    );
  }
}

/// TTS语音
class TTSVoice {
  final String name;
  final String language;
  final TTSGender gender;
  final String displayName;

  const TTSVoice({
    required this.name,
    required this.language,
    required this.gender,
    required this.displayName,
  });
}

/// TTS性别
enum TTSGender {
  male,
  female,
  neutral,
}

/// TTS播报状态
enum TTSSpeakingState {
  started,
  completed,
  stopped,
  paused,
  resumed,
  error,
}

/// TTS记账播报助手
class TTSBookkeepingHelper {
  final TTSService _ttsService;

  TTSBookkeepingHelper(this._ttsService);

  /// 播报欢迎语
  Future<void> speakWelcome() async {
    await _ttsService.speak('欢迎使用智能记账，请说出您的记账需求');
  }

  /// 播报记账成功
  Future<void> speakRecordSuccess({
    required double amount,
    required String category,
  }) async {
    await _ttsService.speakTransactionResult(
      type: 'expense',
      amount: amount,
      category: category,
    );
  }

  /// 播报需要补充信息
  Future<void> speakNeedInfo(String field) async {
    switch (field) {
      case 'amount':
        await _ttsService.speak('请告诉我金额是多少');
        break;
      case 'category':
        await _ttsService.speak('请选择消费分类');
        break;
      case 'date':
        await _ttsService.speak('请告诉我消费日期');
        break;
      default:
        await _ttsService.speak('请补充相关信息');
    }
  }

  /// 播报确认信息
  Future<void> speakConfirmation({
    required double amount,
    required String category,
    DateTime? date,
  }) async {
    final dateStr = date != null
        ? '${date.month}月${date.day}日'
        : '今天';

    await _ttsService.speak(
      '确认记录$dateStr$category消费${_ttsService._formatAmount(amount)}，请说确认或取消',
    );
  }

  /// 播报取消
  Future<void> speakCancelled() async {
    await _ttsService.speak('已取消');
  }

  /// 播报错误
  Future<void> speakError(String? message) async {
    await _ttsService.speak(message ?? '操作失败，请重试');
  }

  /// 播报识别失败
  Future<void> speakRecognitionFailed() async {
    await _ttsService.speak('抱歉，我没有听清，请再说一遍');
  }
}
