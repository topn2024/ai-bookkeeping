import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'voice_token_service.dart';
import 'streaming_tts_service.dart';

/// 文字转语音服务（TTS）
///
/// 功能：
/// 1. 文本转语音合成
/// 2. 语音播报
/// 3. 语音设置（语速、音量、音色）
/// 4. 离线TTS支持
/// 5. 流式合成模式（低延迟）
class TTSService {
  final TTSEngine _engine;
  final TTSSettings _settings;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// 流式TTS服务（可选）
  StreamingTTSService? _streamingTTS;

  /// 是否启用流式模式
  bool _streamingMode = false;

  /// 流式模式首字延迟
  Duration? _lastFirstChunkLatency;
  Duration? get lastFirstChunkLatency => _lastFirstChunkLatency;

  final _speakingController = StreamController<TTSSpeakingState>.broadcast();

  TTSService({
    TTSEngine? engine,
    TTSSettings? settings,
    bool enableStreaming = false,
  })  : _engine = engine ?? FlutterTTSEngine(),
        _settings = settings ?? TTSSettings.defaultSettings(),
        _streamingMode = enableStreaming;

  /// 是否正在播报
  bool get isSpeaking => _isSpeaking;

  /// 播报状态流
  Stream<TTSSpeakingState> get speakingStream => _speakingController.stream;

  /// 初始化TTS引擎
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _engine.initialize();
      await _applySettings();

      // 初始化流式TTS服务（如果启用）
      if (_streamingMode) {
        _streamingTTS = StreamingTTSService();
        await _streamingTTS!.initialize();

        // 监听流式TTS状态
        _streamingTTS!.stateStream.listen((state) {
          switch (state) {
            case StreamingTTSState.started:
              _speakingController.add(TTSSpeakingState.started);
              break;
            case StreamingTTSState.firstChunkReady:
              _lastFirstChunkLatency = _streamingTTS!.firstChunkLatency;
              break;
            case StreamingTTSState.completed:
              _speakingController.add(TTSSpeakingState.completed);
              break;
            case StreamingTTSState.stopped:
              _speakingController.add(TTSSpeakingState.stopped);
              break;
            case StreamingTTSState.interrupted:
              _speakingController.add(TTSSpeakingState.stopped);
              break;
            case StreamingTTSState.error:
              _speakingController.add(TTSSpeakingState.error);
              break;
            default:
              break;
          }
        });
      }

      _isInitialized = true;
      debugPrint('TTS service initialized (streaming: $_streamingMode)');
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
      rethrow;
    }
  }

  /// 启用流式模式
  Future<void> enableStreamingMode() async {
    if (_streamingMode) return;

    _streamingMode = true;
    if (_isInitialized && _streamingTTS == null) {
      _streamingTTS = StreamingTTSService();
      await _streamingTTS!.initialize();
    }
    debugPrint('TTS streaming mode enabled');
  }

  /// 禁用流式模式
  void disableStreamingMode() {
    _streamingMode = false;
    debugPrint('TTS streaming mode disabled');
  }

  /// 是否启用流式模式
  bool get isStreamingMode => _streamingMode;

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
  ///
  /// [text] 要朗读的文本
  /// [interrupt] 是否打断当前播报
  /// [forceStreaming] 强制使用流式模式（忽略全局设置）
  Future<void> speak(
    String text, {
    bool interrupt = true,
    bool? forceStreaming,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.trim().isEmpty) return;

    if (interrupt && _isSpeaking) {
      await stop();
    }

    final useStreaming = forceStreaming ?? _streamingMode;

    try {
      _isSpeaking = true;

      if (useStreaming && _streamingTTS != null) {
        // 使用流式TTS（低延迟）
        await _streamingTTS!.speak(text, interrupt: interrupt);
      } else {
        // 使用传统TTS
        _speakingController.add(TTSSpeakingState.started);
        await _engine.speak(text);
        _speakingController.add(TTSSpeakingState.completed);
      }

      _isSpeaking = false;
    } catch (e) {
      _isSpeaking = false;
      _speakingController.add(TTSSpeakingState.error);
      debugPrint('TTS speak failed: $e');
      rethrow;
    }
  }

  /// 流式朗读（快速响应模式）
  ///
  /// 使用流式TTS服务实现低延迟播报
  /// 适用于需要快速响应的场景
  Future<void> speakStreaming(String text, {bool interrupt = true}) async {
    await speak(text, interrupt: interrupt, forceStreaming: true);
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
      // 停止流式TTS
      if (_streamingTTS != null) {
        await _streamingTTS!.stop();
      }

      // 停止传统TTS
      await _engine.stop();

      _isSpeaking = false;
      _speakingController.add(TTSSpeakingState.stopped);
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  /// 淡出并停止（用于打断场景）
  ///
  /// 平滑降低音量后停止，避免突兀的停止感
  Future<void> fadeOutAndStop({
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    if (!_isSpeaking) return;

    try {
      // 流式TTS淡出
      if (_streamingTTS != null) {
        await _streamingTTS!.fadeOutAndStop(duration: duration);
      }

      // 传统TTS直接停止（不支持淡出）
      await _engine.stop();

      _isSpeaking = false;
      _speakingController.add(TTSSpeakingState.stopped);
    } catch (e) {
      debugPrint('TTS fadeOut failed: $e');
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

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _settings.volume = volume;
    if (_isInitialized) {
      await _engine.setVolume(volume);
    }
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    _settings.rate = rate;
    if (_isInitialized) {
      await _engine.setRate(rate);
    }
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    _settings.pitch = pitch;
    if (_isInitialized) {
      await _engine.setPitch(pitch);
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
    _streamingTTS?.dispose();
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

/// Flutter TTS 引擎实现
///
/// 使用 flutter_tts 插件实现真实的文本转语音功能
class FlutterTTSEngine implements TTSEngine {
  late FlutterTts _flutterTts;
  final Completer<void> _speakCompleter = Completer<void>();
  bool _isInitialized = false;

  String _language = 'zh-CN';

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();

      // 设置完成回调
      _flutterTts.setCompletionHandler(() {
        if (!_speakCompleter.isCompleted) {
          // 不需要complete，因为每次speak都会创建新的completer逻辑
        }
      });

      _flutterTts.setErrorHandler((message) {
        debugPrint('FlutterTTS error: $message');
      });

      // iOS特殊设置
      if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      // 设置默认语言
      await _flutterTts.setLanguage(_language);
      await _flutterTts.awaitSpeakCompletion(true);

      _isInitialized = true;
      debugPrint('FlutterTTS engine initialized');
    } catch (e) {
      debugPrint('FlutterTTS initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _flutterTts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  @override
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  @override
  Future<void> resume() async {
    // Flutter TTS 不直接支持 resume
    // 需要在应用层记录暂停位置重新播放
    debugPrint('FlutterTTS resume not directly supported');
  }

  @override
  Future<void> setRate(double rate) async {
    // flutter_tts 语速范围: 0.0 - 1.0 (iOS), 0.0 - 2.0 (Android)
    // 标准化到 0.0 - 1.0
    final normalizedRate = rate.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(normalizedRate);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
  }

  @override
  Future<void> setLanguage(String language) async {
    _language = language;
    await _flutterTts.setLanguage(language);
  }

  @override
  Future<void> setVoice(String voiceName) async {
    final voices = await _flutterTts.getVoices as List?;
    if (voices != null) {
      final voice = voices.firstWhere(
        (v) => v['name'] == voiceName,
        orElse: () => null,
      );
      if (voice != null) {
        await _flutterTts.setVoice({
          'name': voice['name'],
          'locale': voice['locale'],
        });
      }
    }
  }

  @override
  Future<List<TTSVoice>> getAvailableVoices() async {
    final voices = await _flutterTts.getVoices as List?;
    if (voices == null) return [];

    return voices
        .where((v) => v['locale']?.toString().startsWith('zh') ?? false)
        .map((v) => TTSVoice(
              name: v['name'] ?? '',
              language: v['locale'] ?? '',
              gender: _parseGender(v['name'] ?? ''),
              displayName: v['name'] ?? '',
            ))
        .toList();
  }

  TTSGender _parseGender(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('female') || lowerName.contains('女')) {
      return TTSGender.female;
    } else if (lowerName.contains('male') || lowerName.contains('男')) {
      return TTSGender.male;
    }
    return TTSGender.neutral;
  }

  @override
  Future<Uint8List?> synthesize(String text) async {
    // flutter_tts 不支持离线合成到文件
    return null;
  }

  @override
  void dispose() {
    _flutterTts.stop();
  }
}

/// 阿里云 TTS 引擎实现
///
/// 使用阿里云语音合成服务实现高质量的 TTS
/// 支持多种音色和情感表达
class AlibabaCloudTTSEngine implements TTSEngine {
  final VoiceTokenService _tokenService;
  final Dio _dio;
  final AudioPlayer _audioPlayer;

  String _voice = 'xiaoyun'; // 默认音色
  double _rate = 0; // -500 to 500
  double _volume = 50; // 0-100
  double _pitch = 0; // -500 to 500

  bool _isInitialized = false;

  AlibabaCloudTTSEngine({VoiceTokenService? tokenService})
      : _tokenService = tokenService ?? VoiceTokenService(),
        _dio = Dio(),
        _audioPlayer = AudioPlayer() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    debugPrint('Alibaba Cloud TTS engine initialized');
  }

  @override
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 获取Token
      final tokenInfo = await _tokenService.getToken();

      // 构建请求URL
      final uri = Uri.parse(tokenInfo.ttsUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
          'text': text,
          'format': 'mp3',
          'voice': _voice,
          'volume': _volume.round().toString(),
          'speech_rate': _rate.round().toString(),
          'pitch_rate': _pitch.round().toString(),
        },
      );

      // 获取音频数据
      final response = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          headers: {
            'X-NLS-Token': tokenInfo.token,
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        // 保存到临时文件
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await tempFile.writeAsBytes(response.data!);

        // 播放音频
        await _audioPlayer.setFilePath(tempFile.path);
        await _audioPlayer.play();

        // 等待播放完成
        await _audioPlayer.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );

        // 删除临时文件
        await tempFile.delete();
      }
    } on VoiceTokenException catch (e) {
      debugPrint('TTS Token error: ${e.message}');
      rethrow;
    } on DioException catch (e) {
      debugPrint('TTS network error: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> resume() async {
    await _audioPlayer.play();
  }

  @override
  Future<void> setRate(double rate) async {
    // 阿里云使用 -500 到 500 的范围，0 为正常语速
    // 输入范围 0.5 - 2.0，转换为 -500 到 500
    _rate = ((rate - 1.0) * 500).clamp(-500, 500);
  }

  @override
  Future<void> setVolume(double volume) async {
    // 阿里云使用 0-100 范围
    _volume = (volume * 100).clamp(0, 100);
  }

  @override
  Future<void> setPitch(double pitch) async {
    // 阿里云使用 -500 到 500 的范围
    _pitch = ((pitch - 1.0) * 500).clamp(-500, 500);
  }

  @override
  Future<void> setLanguage(String language) async {
    // 阿里云TTS通过选择音色来设置语言
  }

  @override
  Future<void> setVoice(String voiceName) async {
    _voice = voiceName;
  }

  @override
  Future<List<TTSVoice>> getAvailableVoices() async {
    // 阿里云支持的音色列表
    return [
      const TTSVoice(
        name: 'xiaoyun',
        language: 'zh-CN',
        gender: TTSGender.female,
        displayName: '小云（标准女声）',
      ),
      const TTSVoice(
        name: 'xiaogang',
        language: 'zh-CN',
        gender: TTSGender.male,
        displayName: '小刚（标准男声）',
      ),
      const TTSVoice(
        name: 'ruoxi',
        language: 'zh-CN',
        gender: TTSGender.female,
        displayName: '若兮（温柔女声）',
      ),
      const TTSVoice(
        name: 'siqi',
        language: 'zh-CN',
        gender: TTSGender.female,
        displayName: '思琪（活泼女声）',
      ),
      const TTSVoice(
        name: 'sicheng',
        language: 'zh-CN',
        gender: TTSGender.male,
        displayName: '思诚（沉稳男声）',
      ),
      const TTSVoice(
        name: 'aiqi',
        language: 'zh-CN',
        gender: TTSGender.female,
        displayName: '艾琪（童声）',
      ),
    ];
  }

  @override
  Future<Uint8List?> synthesize(String text) async {
    try {
      final tokenInfo = await _tokenService.getToken();

      final uri = Uri.parse(tokenInfo.ttsUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
          'text': text,
          'format': 'mp3',
          'voice': _voice,
          'volume': _volume.round().toString(),
          'speech_rate': _rate.round().toString(),
          'pitch_rate': _pitch.round().toString(),
        },
      );

      final response = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          headers: {
            'X-NLS-Token': tokenInfo.token,
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } catch (e) {
      debugPrint('TTS synthesize error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _dio.close();
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
      rate: 0.5, // flutter_tts默认语速
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

/// TTS 引擎工厂
///
/// 根据配置和网络状态创建合适的 TTS 引擎
class TTSEngineFactory {
  /// 创建 TTS 引擎
  ///
  /// [type] - 引擎类型: 'flutter', 'alibaba', 'auto'
  static TTSEngine create({
    String type = 'flutter',
  }) {
    switch (type) {
      case 'alibaba':
        return AlibabaCloudTTSEngine();

      case 'auto':
        // 自动选择：优先使用系统TTS（低延迟）
        return FlutterTTSEngine();

      case 'flutter':
      default:
        return FlutterTTSEngine();
    }
  }

  /// 根据网络状态自动选择引擎
  static Future<TTSEngine> createBest() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    final hasNetwork = results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (hasNetwork) {
      // 有网络时可以选择阿里云（更自然）
      // 但默认仍使用Flutter TTS以降低延迟
      return FlutterTTSEngine();
    }

    return FlutterTTSEngine();
  }
}

/// TTS 服务构建器
///
/// 方便创建配置好的 TTS 服务
class TTSServiceBuilder {
  TTSEngine? _engine;
  TTSSettings? _settings;

  /// 设置引擎
  TTSServiceBuilder withEngine(TTSEngine engine) {
    _engine = engine;
    return this;
  }

  /// 使用 Flutter TTS 引擎
  TTSServiceBuilder useFlutterTTS() {
    _engine = FlutterTTSEngine();
    return this;
  }

  /// 使用阿里云 TTS 引擎
  TTSServiceBuilder useAlibabaTTS() {
    _engine = AlibabaCloudTTSEngine();
    return this;
  }

  /// 设置语音参数
  TTSServiceBuilder withSettings({
    double rate = 0.5,
    double volume = 1.0,
    double pitch = 1.0,
    String language = 'zh-CN',
    String? voiceName,
  }) {
    _settings = TTSSettings(
      rate: rate,
      volume: volume,
      pitch: pitch,
      language: language,
      voiceName: voiceName,
    );
    return this;
  }

  /// 构建 TTS 服务
  TTSService build() {
    return TTSService(
      engine: _engine,
      settings: _settings,
    );
  }
}
