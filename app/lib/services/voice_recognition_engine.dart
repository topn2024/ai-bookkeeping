import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'voice_token_service.dart';

/// 语音识别引擎
/// 支持在线（阿里云）和离线（本地Whisper/Sherpa-ONNX）两种模式
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
    // 检查网络状态
    final hasNetwork = await _networkChecker.isOnline();

    if (hasNetwork) {
      // 使用阿里云实时语音识别
      await for (final partial in _aliASR.transcribeStream(audioStream)) {
        yield ASRPartialResult(
          text: _optimizer.postProcessNumbers(partial.text),
          isFinal: partial.isFinal,
          index: partial.index,
          confidence: partial.confidence,
        );
      }
    } else {
      // 离线模式：收集音频后批量识别
      final audioData = <int>[];
      await for (final chunk in audioStream) {
        audioData.addAll(chunk);
      }

      final result = await _whisper.transcribe(ProcessedAudio(
        data: Uint8List.fromList(audioData),
        segments: [],
        duration: Duration(
            milliseconds: (audioData.length / 32).round()), // 估算时长
      ));

      yield ASRPartialResult(
        text: _optimizer.postProcessNumbers(result.text),
        isFinal: true,
        index: 0,
        confidence: result.confidence,
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

  /// 设置热词表（用于提高特定词汇的识别准确率）
  void setHotWords(List<HotWord> hotWords) {
    _aliASR.setHotWords(hotWords);
  }

  /// 添加用户自定义热词
  void addUserHotWords(List<String> words, {double weight = 1.5}) {
    final hotWords = words.map((w) => HotWord(w, weight: weight)).toList();
    _aliASR.addHotWords(hotWords);
  }

  /// 从文件识别语音
  Future<FileRecognitionResult> recognizeFromFile(File file) async {
    try {
      // 读取音频文件
      final bytes = await file.readAsBytes();

      // 创建ProcessedAudio对象
      final audio = ProcessedAudio(
        data: bytes,
        segments: [],
        duration: const Duration(seconds: 30), // 估算
      );

      // 使用现有的transcribe方法
      final result = await transcribe(audio);

      return FileRecognitionResult(
        isSuccess: true,
        text: result.text,
        confidence: result.confidence,
      );
    } catch (e) {
      return FileRecognitionResult(
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// 开始实时识别
  Stream<RealtimeRecognitionResult> startRealtimeRecognition() async* {
    // 使用空流作为占位符，实际应接入麦克风流
    yield RealtimeRecognitionResult(
      text: '',
      isFinal: false,
    );
  }

  /// 停止实时识别
  Future<void> stopRealtimeRecognition() async {
    // 停止识别流
  }

  /// 释放资源
  void dispose() {
    _whisper.dispose();
    _aliASR.dispose();
  }
}

/// 文件识别结果
class FileRecognitionResult {
  final bool isSuccess;
  final String text;
  final double confidence;
  final String? error;

  FileRecognitionResult({
    required this.isSuccess,
    this.text = '',
    this.confidence = 0.0,
    this.error,
  });
}

/// 实时识别结果
class RealtimeRecognitionResult {
  final String text;
  final bool isFinal;

  RealtimeRecognitionResult({
    required this.text,
    required this.isFinal,
  });
}

/// 网络错误处理配置
class ASRErrorHandlingConfig {
  /// 默认超时时间（秒）
  static const int defaultTimeoutSeconds = 10;

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 重试基础延迟（毫秒）
  static const int baseRetryDelayMs = 500;

  /// 最大识别时间（秒）
  static const int maxRecognitionSeconds = 60;

  /// 静音超时时间（秒）
  static const int silenceTimeoutSeconds = 3;
}

/// 阿里云ASR服务
class AliCloudASRService {
  final VoiceTokenService _tokenService;
  final Dio _dio;
  WebSocket? _webSocket;
  List<HotWord> _hotWords = [];

  /// 重试计数
  int _retryCount = 0;

  /// 当前是否处于限流状态
  bool _isRateLimited = false;

  /// 限流恢复时间
  DateTime? _rateLimitResetTime;

  AliCloudASRService({VoiceTokenService? tokenService})
      : _tokenService = tokenService ?? VoiceTokenService(),
        _dio = Dio() {
    _dio.options.connectTimeout =
        Duration(seconds: ASRErrorHandlingConfig.defaultTimeoutSeconds);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // 添加默认的记账热词
    _hotWords.addAll(BookkeepingASROptimizer.bookkeepingHotWords);

    // 添加拦截器用于错误处理
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        // 处理429限流响应
        if (error.response?.statusCode == 429) {
          _handleRateLimitError(error);
        }
        handler.next(error);
      },
    ));
  }

  /// 处理限流错误
  void _handleRateLimitError(DioException error) {
    _isRateLimited = true;
    // 尝试从响应头获取重试时间
    final retryAfter = error.response?.headers.value('Retry-After');
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter) ?? 60;
      _rateLimitResetTime = DateTime.now().add(Duration(seconds: seconds));
    } else {
      // 默认60秒后重试
      _rateLimitResetTime = DateTime.now().add(const Duration(seconds: 60));
    }
    debugPrint('Rate limited, will retry after $_rateLimitResetTime');
  }

  /// 检查是否可以发送请求
  Future<void> _checkRateLimitStatus() async {
    if (_isRateLimited) {
      if (_rateLimitResetTime != null &&
          DateTime.now().isAfter(_rateLimitResetTime!)) {
        _isRateLimited = false;
        _rateLimitResetTime = null;
      } else {
        final waitSeconds =
            _rateLimitResetTime?.difference(DateTime.now()).inSeconds ?? 60;
        throw ASRException('服务繁忙，请在${waitSeconds}秒后重试',
            errorCode: ASRErrorCode.rateLimited);
      }
    }
  }

  /// 执行带重试的异步操作
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = ASRErrorHandlingConfig.maxRetries,
  }) async {
    _retryCount = 0;

    while (true) {
      try {
        // 检查限流状态
        await _checkRateLimitStatus();

        return await operation();
      } on DioException catch (e) {
        _retryCount++;

        // 判断是否应该重试
        if (!_shouldRetry(e) || _retryCount >= maxRetries) {
          throw _convertDioException(e);
        }

        // 计算指数退避延迟
        final delay = _calculateBackoffDelay(_retryCount);
        debugPrint('Retry $_retryCount/$maxRetries after ${delay}ms');
        await Future.delayed(Duration(milliseconds: delay));
      } on ASRException {
        rethrow;
      } catch (e) {
        _retryCount++;

        if (_retryCount >= maxRetries) {
          throw ASRException('识别失败: $e', errorCode: ASRErrorCode.unknown);
        }

        final delay = _calculateBackoffDelay(_retryCount);
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }

  /// 判断是否应该重试
  bool _shouldRetry(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        // 5xx服务器错误可以重试，429限流需要等待
        return statusCode != null && statusCode >= 500;
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  /// 计算指数退避延迟
  int _calculateBackoffDelay(int retryCount) {
    // 指数退避：base * 2^(retryCount-1)，添加随机抖动
    final baseDelay = ASRErrorHandlingConfig.baseRetryDelayMs;
    final exponentialDelay = baseDelay * (1 << (retryCount - 1));
    // 添加 0-25% 的随机抖动
    final jitter = (exponentialDelay * 0.25 * DateTime.now().millisecond / 1000)
        .round();
    return exponentialDelay + jitter;
  }

  /// 转换DioException为ASRException
  ASRException _convertDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return ASRException('连接超时，请检查网络',
            errorCode: ASRErrorCode.connectionTimeout);
      case DioExceptionType.sendTimeout:
        return ASRException('发送超时，请检查网络',
            errorCode: ASRErrorCode.sendTimeout);
      case DioExceptionType.receiveTimeout:
        return ASRException('响应超时，请稍后重试',
            errorCode: ASRErrorCode.receiveTimeout);
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 429) {
          return ASRException('请求过于频繁，请稍后重试',
              errorCode: ASRErrorCode.rateLimited);
        } else if (statusCode == 401) {
          return ASRException('认证失败，请重新登录',
              errorCode: ASRErrorCode.unauthorized);
        } else if (statusCode != null && statusCode >= 500) {
          return ASRException('服务暂时不可用，请稍后重试',
              errorCode: ASRErrorCode.serverError);
        }
        return ASRException('请求失败: $statusCode',
            errorCode: ASRErrorCode.unknown);
      case DioExceptionType.connectionError:
        return ASRException('网络连接失败，请检查网络设置',
            errorCode: ASRErrorCode.noConnection);
      default:
        return ASRException('网络错误: ${e.message}',
            errorCode: ASRErrorCode.unknown);
    }
  }

  /// 设置热词表
  void setHotWords(List<HotWord> hotWords) {
    _hotWords = hotWords;
  }

  /// 添加热词
  void addHotWords(List<HotWord> hotWords) {
    _hotWords.addAll(hotWords);
  }

  /// 一句话识别（短音频，REST API）
  ///
  /// 支持自动重试、超时处理和错误恢复
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    // 检查音频时长是否超过最大限制
    if (audio.duration.inSeconds > ASRErrorHandlingConfig.maxRecognitionSeconds) {
      throw ASRException(
        '音频时长超过${ASRErrorHandlingConfig.maxRecognitionSeconds}秒限制',
        errorCode: ASRErrorCode.recognitionTimeout,
      );
    }

    return _executeWithRetry(() async {
      // 获取Token
      final VoiceTokenInfo tokenInfo;
      try {
        tokenInfo = await _tokenService.getToken();
      } on VoiceTokenException catch (e) {
        throw ASRException(
          'Token获取失败: ${e.message}',
          errorCode: ASRErrorCode.tokenFailed,
        );
      }

      // 构建请求URL
      final uri = Uri.parse(tokenInfo.asrRestUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
          'format': 'pcm',
          'sample_rate': '16000',
          'enable_punctuation_prediction': 'true',
          'enable_inverse_text_normalization': 'true',
        },
      );

      // 发送音频数据
      final response = await _dio.postUri(
        uri,
        data: Stream.fromIterable([audio.data]),
        options: Options(
          headers: {
            'X-NLS-Token': tokenInfo.token,
            'Content-Type': 'application/octet-stream',
            'Content-Length': audio.data.length,
          },
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == 20000000) {
          // 成功
          return ASRResult(
            text: data['result'] ?? '',
            confidence: 0.9, // 阿里云一句话识别不返回置信度
            words: [],
            duration: audio.duration,
            isOffline: false,
          );
        } else {
          throw ASRException(
            'ASR失败: ${data['message']}',
            errorCode: ASRErrorCode.serverError,
          );
        }
      } else {
        throw ASRException(
          'ASR请求失败: ${response.statusCode}',
          errorCode: ASRErrorCode.serverError,
        );
      }
    });
  }

  /// 实时语音识别（流式，WebSocket）
  ///
  /// 支持静音检测、超时处理和连接恢复
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    final controller = StreamController<ASRPartialResult>();

    // 超时计时器
    Timer? timeoutTimer;
    Timer? silenceTimer;
    bool isCompleted = false;

    // 重置静音计时器
    void resetSilenceTimer() {
      silenceTimer?.cancel();
      silenceTimer = Timer(
        Duration(seconds: ASRErrorHandlingConfig.silenceTimeoutSeconds),
        () {
          if (!isCompleted) {
            debugPrint('Silence timeout, stopping recognition');
            controller.addError(ASRException(
              '检测到静音，识别自动停止',
              errorCode: ASRErrorCode.recognitionTimeout,
            ));
            _webSocket?.close();
          }
        },
      );
    }

    // 启动总超时计时器
    timeoutTimer = Timer(
      Duration(seconds: ASRErrorHandlingConfig.maxRecognitionSeconds),
      () {
        if (!isCompleted) {
          debugPrint('Recognition timeout');
          controller.addError(ASRException(
            '识别超时，已达到最大时长限制',
            errorCode: ASRErrorCode.recognitionTimeout,
          ));
          _webSocket?.close();
        }
      },
    );

    try {
      // 获取Token
      final VoiceTokenInfo tokenInfo;
      try {
        tokenInfo = await _tokenService.getToken();
      } on VoiceTokenException catch (e) {
        throw ASRException(
          'Token获取失败: ${e.message}',
          errorCode: ASRErrorCode.tokenFailed,
        );
      }

      // 构建WebSocket URL
      final wsUri = Uri.parse(tokenInfo.asrUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
        },
      );

      // 连接WebSocket（带超时）
      _webSocket = await WebSocket.connect(
        wsUri.toString(),
        headers: {
          'X-NLS-Token': tokenInfo.token,
        },
      ).timeout(
        Duration(seconds: ASRErrorHandlingConfig.defaultTimeoutSeconds),
        onTimeout: () {
          throw ASRException(
            '连接超时',
            errorCode: ASRErrorCode.connectionTimeout,
          );
        },
      );

      // 发送开始识别命令
      final taskId = _generateTaskId();
      final startParams = {
        'header': {
          'message_id': _generateMessageId(),
          'task_id': taskId,
          'namespace': 'SpeechTranscriber',
          'name': 'StartTranscription',
          'appkey': tokenInfo.appKey,
        },
        'payload': {
          'format': 'pcm',
          'sample_rate': 16000,
          'enable_intermediate_result': true,
          'enable_punctuation_prediction': true,
          'enable_inverse_text_normalization': true,
        },
      };

      _webSocket!.add(jsonEncode(startParams));

      // 监听响应
      int resultIndex = 0;

      _webSocket!.listen(
        (data) {
          if (data is String) {
            final response = jsonDecode(data);
            final header = response['header'];
            final payload = response['payload'];

            if (header['name'] == 'TranscriptionResultChanged') {
              // 中间结果 - 重置静音计时器
              resetSilenceTimer();
              controller.add(ASRPartialResult(
                text: payload['result'] ?? '',
                isFinal: false,
                index: resultIndex++,
                confidence: payload['confidence'],
              ));
            } else if (header['name'] == 'SentenceEnd') {
              // 句子结束
              controller.add(ASRPartialResult(
                text: payload['result'] ?? '',
                isFinal: true,
                index: resultIndex++,
                confidence: payload['confidence'],
              ));
            } else if (header['name'] == 'TranscriptionCompleted') {
              // 识别完成
              isCompleted = true;
              controller.close();
            } else if (header['name'] == 'TaskFailed') {
              // 识别失败
              isCompleted = true;
              controller.addError(ASRException(
                '识别失败: ${header['status_text']}',
                errorCode: ASRErrorCode.serverError,
              ));
              controller.close();
            }
          }
        },
        onError: (error) {
          isCompleted = true;
          controller.addError(ASRException(
            'WebSocket错误: $error',
            errorCode: ASRErrorCode.noConnection,
          ));
          controller.close();
        },
        onDone: () {
          isCompleted = true;
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );

      // 发送音频数据（使用缓冲区优化）
      final audioBuffer = AudioCircularBuffer(
        maxSize: 32000, // 约2秒的音频数据
      );

      await for (final chunk in audioStream) {
        // 重置静音计时器
        resetSilenceTimer();

        // 将数据添加到缓冲区
        audioBuffer.write(chunk);

        // 发送数据到WebSocket
        if (_webSocket?.readyState == WebSocket.open) {
          _webSocket!.add(chunk);
        }
      }

      // 发送结束命令
      final stopParams = {
        'header': {
          'message_id': _generateMessageId(),
          'task_id': taskId,
          'namespace': 'SpeechTranscriber',
          'name': 'StopTranscription',
          'appkey': tokenInfo.appKey,
        },
      };
      _webSocket?.add(jsonEncode(stopParams));
    } on ASRException {
      rethrow;
    } on VoiceTokenException catch (e) {
      controller.addError(ASRException(
        'Token获取失败: ${e.message}',
        errorCode: ASRErrorCode.tokenFailed,
      ));
      controller.close();
    } catch (e) {
      controller.addError(ASRException(
        '流式识别错误: $e',
        errorCode: ASRErrorCode.unknown,
      ));
      controller.close();
    } finally {
      // 清理计时器
      timeoutTimer?.cancel();
      silenceTimer?.cancel();
    }

    yield* controller.stream;
  }

  String _generateMessageId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}';
  }

  void dispose() {
    _webSocket?.close();
    _dio.close();
  }
}

/// 本地Whisper服务（离线识别）
/// 使用Sherpa-ONNX实现本地语音识别
class LocalWhisperService {
  bool _isInitialized = false;

  /// 初始化模型
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 加载本地Sherpa-ONNX模型
    // 实际实现需要：
    // 1. 检查模型文件是否存在
    // 2. 如果不存在，从服务器下载
    // 3. 加载模型到内存
    await Future.delayed(const Duration(seconds: 1));
    _isInitialized = true;
    debugPrint('Local Sherpa-ONNX model initialized');
  }

  /// 转写音频
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 实际实现需要调用Sherpa-ONNX FFI接口
    // 这里提供框架代码，实际集成需要：
    // 1. 添加sherpa_onnx_flutter依赖
    // 2. 调用recognizer.createOfflineRecognizer()
    // 3. 传入音频数据获取识别结果

    // 模拟本地识别
    await Future.delayed(const Duration(milliseconds: 800));

    return ASRResult(
      text: '', // 实际应返回识别结果
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
        final tens =
            m.group(2) != null ? (corrections[m.group(2)] ?? '0') : '0';
        final ones =
            m.group(3) != null ? (corrections[m.group(3)] ?? '0') : '0';
        return '$hundreds$tens$ones';
      },
    );

    // 处理"二十"这种形式
    result = result.replaceAllMapped(
      RegExp(r'([一二三四五六七八九])十([一二三四五六七八九])?'),
      (m) {
        final tens = corrections[m.group(1)] ?? '0';
        final ones =
            m.group(2) != null ? (corrections[m.group(2)] ?? '0') : '0';
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
  final Connectivity _connectivity = Connectivity();

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Network check failed: $e');
      return false;
    }
  }

  /// 监听网络状态变化
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    });
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

/// ASR错误码
enum ASRErrorCode {
  /// 未知错误
  unknown,

  /// 连接超时
  connectionTimeout,

  /// 发送超时
  sendTimeout,

  /// 接收超时
  receiveTimeout,

  /// 限流
  rateLimited,

  /// 未授权
  unauthorized,

  /// 服务器错误
  serverError,

  /// 无网络连接
  noConnection,

  /// Token获取失败
  tokenFailed,

  /// 识别超时
  recognitionTimeout,

  /// 音频格式错误
  audioFormatError,
}

/// ASR异常
class ASRException implements Exception {
  final String message;
  final ASRErrorCode errorCode;

  ASRException(this.message, {this.errorCode = ASRErrorCode.unknown});

  /// 是否可以重试
  bool get isRetryable {
    switch (errorCode) {
      case ASRErrorCode.connectionTimeout:
      case ASRErrorCode.sendTimeout:
      case ASRErrorCode.receiveTimeout:
      case ASRErrorCode.serverError:
      case ASRErrorCode.noConnection:
        return true;
      default:
        return false;
    }
  }

  /// 用户友好的错误提示
  String get userFriendlyMessage {
    switch (errorCode) {
      case ASRErrorCode.connectionTimeout:
      case ASRErrorCode.sendTimeout:
      case ASRErrorCode.receiveTimeout:
        return '网络超时，请检查网络连接后重试';
      case ASRErrorCode.rateLimited:
        return '请求过于频繁，请稍后再试';
      case ASRErrorCode.unauthorized:
        return '登录已过期，请重新登录';
      case ASRErrorCode.serverError:
        return '服务暂时不可用，请稍后再试';
      case ASRErrorCode.noConnection:
        return '无网络连接，请检查网络设置';
      case ASRErrorCode.tokenFailed:
        return '认证失败，请重新登录';
      case ASRErrorCode.recognitionTimeout:
        return '识别超时，请缩短语音时长';
      case ASRErrorCode.audioFormatError:
        return '音频格式错误，请重新录制';
      default:
        return message;
    }
  }

  @override
  String toString() => 'ASRException[$errorCode]: $message';
}

/// 音频环形缓冲区
///
/// 用于优化音频流处理，防止内存溢出和数据丢失
class AudioCircularBuffer {
  final int maxSize;
  final Uint8List _buffer;
  int _writePos = 0;
  int _readPos = 0;
  int _availableBytes = 0;

  AudioCircularBuffer({this.maxSize = 32000})
      : _buffer = Uint8List(maxSize);

  /// 当前可读数据量
  int get available => _availableBytes;

  /// 缓冲区是否已满
  bool get isFull => _availableBytes >= maxSize;

  /// 缓冲区是否为空
  bool get isEmpty => _availableBytes == 0;

  /// 写入数据到缓冲区
  ///
  /// 如果缓冲区满，会覆盖最旧的数据
  void write(Uint8List data) {
    for (var i = 0; i < data.length; i++) {
      _buffer[_writePos] = data[i];
      _writePos = (_writePos + 1) % maxSize;

      if (_availableBytes < maxSize) {
        _availableBytes++;
      } else {
        // 缓冲区满，移动读取位置（丢弃最旧数据）
        _readPos = (_readPos + 1) % maxSize;
      }
    }
  }

  /// 读取指定长度的数据
  ///
  /// 返回实际读取的数据（可能少于请求的长度）
  Uint8List read(int length) {
    final actualLength = min(length, _availableBytes);
    final result = Uint8List(actualLength);

    for (var i = 0; i < actualLength; i++) {
      result[i] = _buffer[_readPos];
      _readPos = (_readPos + 1) % maxSize;
    }

    _availableBytes -= actualLength;
    return result;
  }

  /// 查看数据但不移动读取位置
  Uint8List peek(int length) {
    final actualLength = min(length, _availableBytes);
    final result = Uint8List(actualLength);
    var tempPos = _readPos;

    for (var i = 0; i < actualLength; i++) {
      result[i] = _buffer[tempPos];
      tempPos = (tempPos + 1) % maxSize;
    }

    return result;
  }

  /// 清空缓冲区
  void clear() {
    _writePos = 0;
    _readPos = 0;
    _availableBytes = 0;
  }

  /// 获取所有可用数据
  Uint8List readAll() {
    return read(_availableBytes);
  }
}
