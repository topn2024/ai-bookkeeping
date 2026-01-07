import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 语音识别引擎
/// 支持在线（阿里云）和离线（本地Whisper）两种模式
class VoiceRecognitionEngine {
  final AliCloudASRService _aliASR;
  final LocalWhisperService _whisper;
  final NetworkChecker _networkChecker;
  final BookkeepingASROptimizer _optimizer;

  VoiceRecognitionEngine({
    AliCloudASRService? aliASR,
    LocalWhisperService? whisper,
    NetworkChecker? networkChecker,
  })  : _aliASR = aliASR ?? AliCloudASRService(),
        _whisper = whisper ?? LocalWhisperService(),
        _networkChecker = networkChecker ?? NetworkChecker(),
        _optimizer = BookkeepingASROptimizer();

  /// ASR服务选择策略
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    // 1. 检测网络状态
    final hasNetwork = await _networkChecker.isOnline();

    // 2. 选择ASR引擎
    if (hasNetwork && audio.duration.inSeconds < 60) {
      // 短音频 + 有网络：使用在线服务（更准确）
      try {
        final result = await _aliASR.transcribe(audio);
        return _postProcess(result);
      } catch (e) {
        // 在线服务失败，降级到本地
        debugPrint('Online ASR failed, fallback to local: $e');
        final result = await _whisper.transcribe(audio);
        return _postProcess(result);
      }
    } else {
      // 长音频或无网络：使用本地Whisper
      final result = await _whisper.transcribe(audio);
      return _postProcess(result);
    }
  }

  /// 流式识别（实时转写）
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    // 使用阿里云实时语音识别
    await for (final partial in _aliASR.transcribeStream(audioStream)) {
      yield ASRPartialResult(
        text: _optimizer.postProcessNumbers(partial.text),
        isFinal: partial.isFinal,
        index: partial.index,
        confidence: partial.confidence,
      );
    }
  }

  /// 后处理ASR结果
  ASRResult _postProcess(ASRResult result) {
    var text = result.text;
    text = _optimizer.postProcessNumbers(text);
    text = _optimizer.normalizeAmountUnit(text);

    return ASRResult(
      text: text,
      confidence: result.confidence,
      words: result.words,
      duration: result.duration,
      isOffline: result.isOffline,
    );
  }

  /// 初始化离线模型
  Future<void> initializeOfflineModel() async {
    await _whisper.initialize();
  }

  /// 释放资源
  void dispose() {
    _whisper.dispose();
  }
}

/// 阿里云ASR服务
class AliCloudASRService {
  final String? _appKey;
  final String? _accessKeyId;
  final String? _accessKeySecret;

  // 配置从环境或配置文件读取
  AliCloudASRService({
    String? appKey,
    String? accessKeyId,
    String? accessKeySecret,
  })  : _appKey = appKey,
        _accessKeyId = accessKeyId,
        _accessKeySecret = accessKeySecret;

  /// 一句话识别（短音频）
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    // 获取认证token
    final token = await _getToken();
    if (token == null) {
      throw ASRException('Failed to get ASR token');
    }

    // 模拟API调用（实际实现需要HTTP请求）
    // final response = await http.post(
    //   Uri.parse('https://nls-gateway.cn-shanghai.aliyuncs.com/stream/v1/asr'),
    //   headers: {
    //     'X-NLS-Token': token,
    //     'Content-Type': 'application/octet-stream',
    //   },
    //   body: audio.data,
    // );

    // 模拟返回结果
    await Future.delayed(const Duration(milliseconds: 500));

    return ASRResult(
      text: '模拟识别结果',
      confidence: 0.85,
      words: [],
      duration: audio.duration,
      isOffline: false,
    );
  }

  /// 实时语音识别（流式）
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    // WebSocket连接实现
    // final ws = await WebSocket.connect(
    //   'wss://nls-gateway.cn-shanghai.aliyuncs.com/ws/v1',
    // );

    // 模拟流式结果
    int index = 0;
    await for (final chunk in audioStream) {
      // 处理音频块
      await Future.delayed(const Duration(milliseconds: 100));

      yield ASRPartialResult(
        text: '识别中...',
        isFinal: false,
        index: index++,
      );
    }

    yield ASRPartialResult(
      text: '识别完成',
      isFinal: true,
      index: index,
      confidence: 0.9,
    );
  }

  Future<String?> _getToken() async {
    if (_appKey == null || _accessKeyId == null || _accessKeySecret == null) {
      return null;
    }
    // 实际实现需要调用阿里云API获取token
    return 'mock_token';
  }
}

/// 本地Whisper服务（离线识别）
class LocalWhisperService {
  bool _isInitialized = false;

  /// 初始化模型
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 加载本地Whisper模型
    // 实际实现需要加载TFLite模型
    await Future.delayed(const Duration(seconds: 1));
    _isInitialized = true;
    debugPrint('Local Whisper model initialized');
  }

  /// 转写音频
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 实际实现需要调用本地模型
    await Future.delayed(const Duration(milliseconds: 800));

    return ASRResult(
      text: '本地识别结果',
      confidence: 0.75,
      words: [],
      duration: audio.duration,
      isOffline: true,
    );
  }

  void dispose() {
    _isInitialized = false;
  }
}

/// 记账领域语音识别优化器
class BookkeepingASROptimizer {
  /// 记账专用热词表
  static const List<HotWord> bookkeepingHotWords = [
    // 金额表达
    HotWord('块钱', weight: 2.0),
    HotWord('元', weight: 2.0),
    HotWord('毛', weight: 1.5),
    HotWord('分', weight: 1.5),

    // 常见分类
    HotWord('早餐', weight: 1.8),
    HotWord('午餐', weight: 1.8),
    HotWord('晚餐', weight: 1.8),
    HotWord('外卖', weight: 1.8),
    HotWord('打车', weight: 1.8),
    HotWord('地铁', weight: 1.8),
    HotWord('公交', weight: 1.8),
    HotWord('房租', weight: 1.8),
    HotWord('水电费', weight: 1.8),

    // 时间表达
    HotWord('今天', weight: 1.5),
    HotWord('昨天', weight: 1.5),
    HotWord('前天', weight: 1.5),
    HotWord('上周', weight: 1.5),
    HotWord('上个月', weight: 1.5),

    // 动作词
    HotWord('花了', weight: 1.8),
    HotWord('买了', weight: 1.8),
    HotWord('充值', weight: 1.8),
    HotWord('转账', weight: 1.8),
    HotWord('收入', weight: 1.8),
    HotWord('工资', weight: 1.8),
  ];

  /// 后处理：数字识别纠错
  String postProcessNumbers(String text) {
    final corrections = {
      '一': '1',
      '二': '2',
      '三': '3',
      '四': '4',
      '五': '5',
      '六': '6',
      '七': '7',
      '八': '8',
      '九': '9',
      '十': '10',
      '两': '2',
      '俩': '2',
      '零': '0',
    };

    var result = text;

    // 处理"十五"这种形式
    result = result.replaceAllMapped(
      RegExp(r'十([一二三四五六七八九])'),
      (m) => '1${corrections[m.group(1)]}',
    );

    // 处理单独的"十"
    result = result.replaceAll('十', '10');

    // 处理"一百二十三"这种形式
    result = result.replaceAllMapped(
      RegExp(r'([一二三四五六七八九])百([一二三四五六七八九零])?十?([一二三四五六七八九])?'),
      (m) {
        final hundreds = corrections[m.group(1)] ?? '0';
        final tens = m.group(2) != null ? (corrections[m.group(2)] ?? '0') : '0';
        final ones = m.group(3) != null ? (corrections[m.group(3)] ?? '0') : '0';
        return '$hundreds$tens$ones';
      },
    );

    // 处理"二十"这种形式
    result = result.replaceAllMapped(
      RegExp(r'([一二三四五六七八九])十([一二三四五六七八九])?'),
      (m) {
        final tens = corrections[m.group(1)] ?? '0';
        final ones = m.group(2) != null ? (corrections[m.group(2)] ?? '0') : '0';
        return '$tens$ones';
      },
    );

    return result;
  }

  /// 后处理：金额单位标准化
  String normalizeAmountUnit(String text) {
    return text
        .replaceAll(RegExp(r'块钱?'), '元')
        .replaceAll(RegExp(r'毛'), '角')
        .replaceAllMapped(
          RegExp(r'(\d+)元(\d)角'),
          (m) => '${m.group(1)}.${m.group(2)}元',
        )
        .replaceAllMapped(
          RegExp(r'(\d+)元(\d)分'),
          (m) => '${m.group(1)}.0${m.group(2)}元',
        );
  }
}

/// 网络检测器
class NetworkChecker {
  Future<bool> isOnline() async {
    // 实际实现需要检测网络状态
    return true;
  }
}

/// 处理后的音频数据
class ProcessedAudio {
  final Uint8List data;
  final List<AudioSegment> segments;
  final Duration duration;
  final int sampleRate;

  const ProcessedAudio({
    required this.data,
    required this.segments,
    required this.duration,
    this.sampleRate = 16000,
  });
}

/// 音频片段
class AudioSegment {
  final int startMs;
  final int endMs;
  final bool isSpeech;

  const AudioSegment({
    required this.startMs,
    required this.endMs,
    required this.isSpeech,
  });

  Duration get duration => Duration(milliseconds: endMs - startMs);
}

/// ASR识别结果
class ASRResult {
  final String text;
  final double confidence;
  final List<ASRWord> words;
  final Duration duration;
  final bool isOffline;

  const ASRResult({
    required this.text,
    required this.confidence,
    required this.words,
    required this.duration,
    this.isOffline = false,
  });

  ASRResult copyWith({
    String? text,
    double? confidence,
    List<ASRWord>? words,
    Duration? duration,
    bool? isOffline,
  }) {
    return ASRResult(
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      words: words ?? this.words,
      duration: duration ?? this.duration,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// ASR单词级结果
class ASRWord {
  final String word;
  final int startMs;
  final int endMs;
  final double confidence;

  const ASRWord({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.confidence,
  });
}

/// ASR部分结果（流式）
class ASRPartialResult {
  final String text;
  final bool isFinal;
  final int index;
  final double? confidence;

  const ASRPartialResult({
    required this.text,
    required this.isFinal,
    required this.index,
    this.confidence,
  });
}

/// 热词
class HotWord {
  final String word;
  final double weight;

  const HotWord(this.word, {this.weight = 1.0});
}

/// ASR异常
class ASRException implements Exception {
  final String message;
  ASRException(this.message);

  @override
  String toString() => 'ASRException: $message';
}
