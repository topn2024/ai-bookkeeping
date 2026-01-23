import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random, min;

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

  /// 当前是否正在识别
  bool _isRecognizing = false;
  bool get isRecognizing => _isRecognizing;

  /// 取消标记
  bool _isCancelled = false;

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
    debugPrint('[VoiceRecognitionEngine] transcribe开始，音频大小: ${audio.data.length} bytes');

    // 1. 检测网络状态
    final hasNetwork = await _networkChecker.isOnline();
    debugPrint('[VoiceRecognitionEngine] 网络状态: ${hasNetwork ? "在线" : "离线"}');
    Object? onlineError;

    // 2. 选择ASR引擎
    if (hasNetwork && audio.duration.inSeconds < 60) {
      // 短音频 + 有网络：使用在线服务（更准确）
      debugPrint('[VoiceRecognitionEngine] 使用阿里云在线ASR');
      try {
        final result = await _aliASR.transcribe(audio);
        debugPrint('[VoiceRecognitionEngine] 阿里云ASR成功: ${result.text}');
        return _postProcess(result);
      } catch (e) {
        // 在线服务失败，记录错误并降级到本地
        onlineError = e;
        debugPrint('[VoiceRecognitionEngine] 阿里云ASR失败，降级到本地: $e');
      }
    } else {
      debugPrint('[VoiceRecognitionEngine] 跳过在线ASR (hasNetwork=$hasNetwork, duration=${audio.duration.inSeconds}s)');
    }

    // 尝试本地识别（作为降级或无网络时的选择）
    debugPrint('[VoiceRecognitionEngine] 尝试本地Whisper识别');
    final result = await _whisper.transcribe(audio);
    final processedResult = _postProcess(result);
    debugPrint('[VoiceRecognitionEngine] 本地识别结果: ${processedResult.text}');

    // 如果本地识别也返回空结果，且之前有在线错误，抛出原始错误
    if (processedResult.text.isEmpty && onlineError != null) {
      debugPrint('[VoiceRecognitionEngine] 本地识别为空且有在线错误，抛出原始错误');
      throw onlineError;
    }

    return processedResult;
  }

  /// 流式识别（实时转写）
  ///
  /// 如果已有识别进行中，会先取消之前的识别
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    debugPrint('[VoiceRecognitionEngine] transcribeStream 开始');

    // 防止并发：如果已有识别在进行中，先取消
    if (_isRecognizing) {
      debugPrint('[VoiceRecognitionEngine] 取消之前的识别');
      await cancelTranscription();
    }

    _isRecognizing = true;
    _isCancelled = false;

    try {
      // 检查网络状态
      final hasNetwork = await _networkChecker.isOnline();
      debugPrint('[VoiceRecognitionEngine] 网络状态: ${hasNetwork ? "在线" : "离线"}');

      if (hasNetwork) {
        // 使用阿里云实时语音识别
        debugPrint('[VoiceRecognitionEngine] 使用阿里云流式ASR');
        await for (final partial in _aliASR.transcribeStream(audioStream)) {
          if (_isCancelled) {
            debugPrint('[VoiceRecognitionEngine] 已取消，停止yield');
            break;
          }

          debugPrint('[VoiceRecognitionEngine] 收到ASR结果: "${partial.text}" (isFinal: ${partial.isFinal})');
          yield ASRPartialResult(
            text: _optimizer.postProcessNumbers(partial.text),
            isFinal: partial.isFinal,
            index: partial.index,
            confidence: partial.confidence,
          );
        }
        debugPrint('[VoiceRecognitionEngine] 流式ASR结束');
      } else {
        // 离线模式：收集音频后批量识别
        debugPrint('[VoiceRecognitionEngine] 使用离线模式');
        final audioData = <int>[];
        await for (final chunk in audioStream) {
          if (_isCancelled) break;
          audioData.addAll(chunk);
        }

        if (!_isCancelled) {
          final result = await _whisper.transcribe(ProcessedAudio(
            data: Uint8List.fromList(audioData),
            segments: [],
            duration: Duration(
                milliseconds: (audioData.length / 32).round()),
          ));

          yield ASRPartialResult(
            text: _optimizer.postProcessNumbers(result.text),
            isFinal: true,
            index: 0,
            confidence: result.confidence,
          );
        }
      }
    } catch (e) {
      debugPrint('[VoiceRecognitionEngine] 流式识别错误: $e');
      rethrow;
    } finally {
      _isRecognizing = false;
      debugPrint('[VoiceRecognitionEngine] transcribeStream 结束');
    }
  }

  /// 取消当前识别
  ///
  /// 立即停止当前的流式识别任务（用于TTS播放前暂停等场景）
  Future<void> cancelTranscription() async {
    if (!_isRecognizing) return;

    _isCancelled = true;
    _isRecognizing = false;

    // 立即取消阿里云ASR（关闭WebSocket，不等待）
    await _aliASR.cancelTranscription();

    debugPrint('VoiceRecognitionEngine: transcription cancelled');
  }

  /// 检查是否已取消
  bool get isCancelled => _isCancelled;

  /// 重置取消状态
  void resetCancelState() {
    _isCancelled = false;
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
      debugPrint('[VoiceRecognitionEngine] recognizeFromFile: ${file.path}');

      // 读取音频文件
      final bytes = await file.readAsBytes();
      debugPrint('[VoiceRecognitionEngine] 文件大小: ${bytes.length} bytes');

      // 如果是WAV文件，需要跳过WAV头部获取纯PCM数据
      Uint8List pcmData;
      if (file.path.toLowerCase().endsWith('.wav') && bytes.length > 44) {
        // WAV文件头部是44字节，跳过它获取纯PCM数据
        // 验证WAV头部
        final riff = String.fromCharCodes(bytes.sublist(0, 4));
        final wave = String.fromCharCodes(bytes.sublist(8, 12));
        if (riff == 'RIFF' && wave == 'WAVE') {
          // 找到data chunk的位置
          int dataOffset = 12;
          while (dataOffset < bytes.length - 8) {
            final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
            final chunkSize = bytes.buffer.asByteData().getUint32(dataOffset + 4, Endian.little);
            if (chunkId == 'data') {
              dataOffset += 8; // 跳过chunk ID和size
              pcmData = bytes.sublist(dataOffset, min(dataOffset + chunkSize, bytes.length));
              debugPrint('[VoiceRecognitionEngine] WAV文件，提取PCM数据: ${pcmData.length} bytes');
              break;
            }
            dataOffset += 8 + chunkSize;
          }
          pcmData = bytes.sublist(44); // 降级方案：直接跳过前44字节
        } else {
          pcmData = bytes;
        }
      } else {
        pcmData = bytes;
      }

      // 计算音频时长（16000Hz, 16bit, 单声道）
      final durationMs = (pcmData.length / 32).round(); // 32 bytes per ms
      debugPrint('[VoiceRecognitionEngine] 估算时长: ${durationMs}ms');

      // 创建ProcessedAudio对象
      final audio = ProcessedAudio(
        data: pcmData,
        segments: [],
        duration: Duration(milliseconds: durationMs),
      );

      // 使用现有的transcribe方法
      final result = await transcribe(audio);
      debugPrint('[VoiceRecognitionEngine] 识别结果: ${result.text}');

      return FileRecognitionResult(
        isSuccess: true,
        text: result.text,
        confidence: result.confidence,
      );
    } catch (e) {
      debugPrint('[VoiceRecognitionEngine] 识别失败: $e');
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

  /// 流式识别计时器（用于外部取消）
  Timer? _timeoutTimer;
  Timer? _silenceTimer;

  /// 是否已取消
  bool _isCancelled = false;

  /// 当前会话ID（用于防止旧会话的音频处理继续运行）
  int _currentSessionId = 0;

  /// 流式识别控制器（用于外部取消）
  StreamController<ASRPartialResult>? _streamController;

  /// 当前appKey（用于StopTranscription）
  String? _currentAppKey;

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
        throw ASRException('服务繁忙，请在$waitSeconds秒后重试',
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
      } on ASRException catch (e) {
        // 如果是需要重试的ASR异常（如空结果重试），则进行重试
        if (e.message.contains('需要重试') && _retryCount < maxRetries) {
          _retryCount++;
          final delay = _calculateBackoffDelay(_retryCount);
          debugPrint('[ASR] ASRException重试 $_retryCount/$maxRetries after ${delay}ms: ${e.message}');
          await Future.delayed(Duration(milliseconds: delay));
          continue;
        }
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
        return ASRException('网络错误: ${e.message ?? '请稍后重试'}',
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
    debugPrint('[AliCloudASR] transcribe开始，音频数据: ${audio.data.length} bytes, 时长: ${audio.duration.inMilliseconds}ms');

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
        debugPrint('[AliCloudASR] 正在获取Token...');
        tokenInfo = await _tokenService.getToken();
        debugPrint('[AliCloudASR] Token获取成功: appKey=${tokenInfo.appKey}, token=${tokenInfo.token.substring(0, 8)}..., asrRestUrl=${tokenInfo.asrRestUrl}');
      } on VoiceTokenException catch (e) {
        debugPrint('[AliCloudASR] Token获取失败: ${e.message}');
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

      debugPrint('[AliCloudASR] 请求URL: $uri');
      debugPrint('[AliCloudASR] 发送音频数据: ${audio.data.length} bytes');

      // 检查音频数据是否有内容（计算平均振幅）
      int sum = 0;
      for (int i = 0; i < audio.data.length - 1; i += 2) {
        int sample = audio.data[i] | (audio.data[i + 1] << 8);
        if (sample > 32767) sample -= 65536; // 转为有符号
        sum += sample.abs();
      }
      final avgAmplitude = sum ~/ (audio.data.length ~/ 2);
      debugPrint('[AliCloudASR] 音频平均振幅: $avgAmplitude (静音阈值约100)');

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

      debugPrint('[AliCloudASR] 响应状态码: ${response.statusCode}');
      debugPrint('[AliCloudASR] 响应内容: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == 20000000) {
          // 成功
          final resultText = data['result'] ?? '';
          debugPrint('[AliCloudASR] 识别成功: $resultText');

          // 如果结果为空但音频振幅较高，说明可能是ASR服务问题，抛出异常触发重试
          if (resultText.isEmpty && avgAmplitude > 500) {
            debugPrint('[AliCloudASR] 音频有内容(振幅=$avgAmplitude)但ASR返回空，触发重试');
            throw ASRException(
              'ASR返回空结果，需要重试',
              errorCode: ASRErrorCode.serverError,
            );
          }

          return ASRResult(
            text: resultText,
            confidence: 0.9, // 阿里云一句话识别不返回置信度
            words: [],
            duration: audio.duration,
            isOffline: false,
          );
        } else {
          debugPrint('[AliCloudASR] 识别失败: status=${data['status']}, message=${data['message']}');
          throw ASRException(
            'ASR失败: ${data['message']}',
            errorCode: ASRErrorCode.serverError,
          );
        }
      } else {
        debugPrint('[AliCloudASR] HTTP请求失败: ${response.statusCode}');
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
  /// 如果已有识别在进行中，会先取消之前的识别
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    debugPrint('[AliCloudASR] transcribeStream 开始');

    // 防止并发：如果已有 WebSocket 连接，先取消
    if (_webSocket != null) {
      debugPrint('[AliCloudASR] 取消之前的识别');
      await cancelTranscription();
      // 等待旧的音频处理循环完全停止
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 递增会话ID，使旧会话的音频处理循环自动停止
    _currentSessionId++;
    final sessionId = _currentSessionId;
    debugPrint('[AliCloudASR] 新会话ID: $sessionId');

    // 重置状态（在确认旧循环停止后）
    _isCancelled = false;
    _cleanupTimers();

    final controller = StreamController<ASRPartialResult>.broadcast();
    _streamController = controller;

    bool isCompleted = false;

    // 等待服务器就绪的Completer
    final serverReadyCompleter = Completer<void>();

    // 标记完成并清理
    void markCompleted() {
      if (!isCompleted) {
        isCompleted = true;
        _cleanupTimers();
      }
    }

    // 重置静音计时器
    void resetSilenceTimer() {
      _silenceTimer?.cancel();
      _silenceTimer = Timer(
        Duration(seconds: ASRErrorHandlingConfig.silenceTimeoutSeconds),
        () {
          if (!isCompleted && !_isCancelled) {
            debugPrint('[AliCloudASR] 静音超时，停止识别');
            controller.addError(ASRException(
              '检测到静音，识别自动停止',
              errorCode: ASRErrorCode.recognitionTimeout,
            ));
            markCompleted();
            _webSocket?.close();
          }
        },
      );
    }

    // 启动总超时计时器
    _timeoutTimer = Timer(
      Duration(seconds: ASRErrorHandlingConfig.maxRecognitionSeconds),
      () {
        if (!isCompleted && !_isCancelled) {
          debugPrint('[AliCloudASR] 识别超时');
          controller.addError(ASRException(
            '识别超时，已达到最大时长限制',
            errorCode: ASRErrorCode.recognitionTimeout,
          ));
          markCompleted();
          _webSocket?.close();
        }
      },
    );

    try {
      // 获取Token
      debugPrint('[AliCloudASR] 正在获取Token...');
      final VoiceTokenInfo tokenInfo;
      try {
        tokenInfo = await _tokenService.getToken();
        debugPrint('[AliCloudASR] Token获取成功');
      } on VoiceTokenException catch (e) {
        debugPrint('[AliCloudASR] Token获取失败: ${e.message}');
        throw ASRException(
          'Token获取失败: ${e.message}',
          errorCode: ASRErrorCode.tokenFailed,
        );
      }

      // 构建WebSocket URL
      // 注意：Android 平台的 WebSocket 不支持自定义 headers，
      // 因此将 token 作为查询参数传递
      final wsUri = Uri.parse(tokenInfo.asrUrl).replace(
        queryParameters: {
          'appkey': tokenInfo.appKey,
          'token': tokenInfo.token,
        },
      );
      debugPrint('[AliCloudASR] WebSocket URL: ${wsUri.toString().replaceAll(tokenInfo.token, '***')}');

      // 连接WebSocket（带超时）
      debugPrint('[AliCloudASR] 正在连接WebSocket...');
      _webSocket = await WebSocket.connect(
        wsUri.toString(),
      ).timeout(
        Duration(seconds: ASRErrorHandlingConfig.defaultTimeoutSeconds),
        onTimeout: () {
          throw ASRException(
            '连接超时',
            errorCode: ASRErrorCode.connectionTimeout,
          );
        },
      );
      debugPrint('[AliCloudASR] WebSocket已连接');

      // 发送开始识别命令
      final taskId = _generateTaskId();
      _currentTaskId = taskId;
      _currentAppKey = tokenInfo.appKey;
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
          // VAD参数
          'max_sentence_silence': 800, // 句子内最大静音时间(ms)
          'enable_voice_detection': true, // 启用语音检测
          // 暂时禁用disfluency过滤，以便调试
          // 'disfluency': true, // 过滤语气词（嗯、啊等）
          // 增加语音增强选项
          'enable_semantic_sentence_detection': false, // 禁用语义断句，使用纯时间断句
        },
      };

      _webSocket!.add(jsonEncode(startParams));
      debugPrint('[AliCloudASR] 已发送StartTranscription命令');

      // 监听响应
      int resultIndex = 0;

      _webSocket!.listen(
        (data) {
          if (data is String) {
            final response = jsonDecode(data);
            final header = response['header'];
            final payload = response['payload'];
            final name = header['name'];
            debugPrint('[AliCloudASR] 收到响应: $name');

            if (name == 'TranscriptionStarted') {
              debugPrint('[AliCloudASR] 识别已开始，服务器就绪');
              // 通知可以开始发送音频了
              if (!serverReadyCompleter.isCompleted) {
                serverReadyCompleter.complete();
              }
            } else if (name == 'TranscriptionResultChanged') {
              // 中间结果
              resetSilenceTimer();
              final text = payload['result'] ?? '';
              debugPrint('[AliCloudASR] 中间结果: $text');
              if (!controller.isClosed) {
                controller.add(ASRPartialResult(
                  text: text,
                  isFinal: false,
                  index: resultIndex++,
                  confidence: payload['confidence'],
                ));
              }
            } else if (name == 'SentenceBegin') {
              debugPrint('[AliCloudASR] 句子开始: index=${payload['index']}, time=${payload['time']}');
            } else if (name == 'SentenceEnd') {
              // 句子结束
              final text = payload['result'] ?? '';
              final confidence = payload['confidence'];
              final beginTime = payload['begin_time'];
              final time = payload['time'];
              debugPrint('[AliCloudASR] 句子结束: "$text", 置信度=$confidence, beginTime=$beginTime, time=$time');
              debugPrint('[AliCloudASR] SentenceEnd完整payload: $payload');
              // 只有非空结果才添加
              if (text.trim().isNotEmpty && !controller.isClosed) {
                controller.add(ASRPartialResult(
                  text: text,
                  isFinal: true,
                  index: resultIndex++,
                  confidence: payload['confidence'],
                ));
              } else if (text.trim().isEmpty) {
                debugPrint('[AliCloudASR] 跳过空的句子结束结果');
              }
            } else if (name == 'TranscriptionCompleted') {
              debugPrint('[AliCloudASR] 识别完成');
              markCompleted();
              if (!controller.isClosed) {
                controller.close();
              }
            } else if (name == 'TaskFailed') {
              debugPrint('[AliCloudASR] 任务失败: ${header['status_text']}');
              markCompleted();
              // 如果还在等待服务器就绪，完成Completer以避免挂起
              if (!serverReadyCompleter.isCompleted) {
                serverReadyCompleter.completeError(ASRException(
                  '识别失败: ${header['status_text']}',
                  errorCode: ASRErrorCode.serverError,
                ));
              }
              // 检查controller是否已关闭，避免异常
              if (!controller.isClosed) {
                controller.addError(ASRException(
                  '识别失败: ${header['status_text']}',
                  errorCode: ASRErrorCode.serverError,
                ));
                controller.close();
              }
            }
          }
        },
        onError: (error) {
          debugPrint('[AliCloudASR] WebSocket错误: $error');
          markCompleted();
          // 检查controller是否已关闭，避免异常
          if (!controller.isClosed) {
            controller.addError(ASRException(
              'WebSocket错误: $error',
              errorCode: ASRErrorCode.noConnection,
            ));
            controller.close();
          }
        },
        onDone: () {
          debugPrint('[AliCloudASR] WebSocket关闭');
          markCompleted();
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );

      // 异步处理音频流（不阻塞yield）
      // 传入serverReadyCompleter，等待服务器就绪后才开始发送音频
      // 传入sessionId，用于检测会话是否已被新会话替代
      _processAudioStreamAsync(audioStream, taskId, tokenInfo.appKey, resetSilenceTimer, serverReadyCompleter, sessionId);

    } on ASRException {
      rethrow;
    } on VoiceTokenException catch (e) {
      markCompleted();
      controller.addError(ASRException(
        'Token获取失败: ${e.message}',
        errorCode: ASRErrorCode.tokenFailed,
      ));
      controller.close();
    } catch (e) {
      debugPrint('[AliCloudASR] 流式识别错误: $e');
      markCompleted();
      controller.addError(ASRException(
        '流式识别错误: $e',
        errorCode: ASRErrorCode.unknown,
      ));
      controller.close();
    }

    // 立即开始yield结果（不等待音频流结束）
    debugPrint('[AliCloudASR] 开始yield结果流');
    await for (final result in controller.stream) {
      yield result;
    }
    debugPrint('[AliCloudASR] 结果流结束');

    // 清理
    _cleanupTimers();
    _streamController = null;
  }

  /// 异步处理音频流（不阻塞主函数）
  Future<void> _processAudioStreamAsync(
    Stream<Uint8List> audioStream,
    String taskId,
    String appKey,
    void Function() resetSilenceTimer,
    Completer<void> serverReadyCompleter,
    int sessionId,
  ) async {
    debugPrint('[AliCloudASR] 开始处理音频流, sessionId=$sessionId');

    // 缓冲区：存储服务器就绪前收到的音频
    final audioBuffer = <Uint8List>[];
    bool serverReady = false;
    int chunkCount = 0;

    try {
      // 立即开始监听音频流（不等待服务器就绪）
      // 这样可以缓冲在等待期间收到的音频
      await for (final chunk in audioStream) {
        // 检查会话是否已被新会话替代
        if (sessionId != _currentSessionId) {
          debugPrint('[AliCloudASR] 会话已过期 (当前=$sessionId, 新=$_currentSessionId)，停止处理');
          break;
        }
        if (_isCancelled) {
          debugPrint('[AliCloudASR] 音频流处理被取消');
          break;
        }

        chunkCount++;

        // 前5次每次都打印，包含音频振幅分析
        if (chunkCount <= 5 || chunkCount % 50 == 0) {
          // 计算音频振幅
          int maxAmplitude = 0;
          int sumAmplitude = 0;
          if (chunk.length >= 2) {
            for (int i = 0; i < chunk.length - 1; i += 2) {
              int sample = chunk[i] | (chunk[i + 1] << 8);
              if (sample > 32767) sample -= 65536;
              final absValue = sample.abs();
              if (absValue > maxAmplitude) maxAmplitude = absValue;
              sumAmplitude += absValue;
            }
          }
          final avgAmplitude = chunk.length > 2 ? sumAmplitude ~/ (chunk.length ~/ 2) : 0;
          debugPrint('[AliCloudASR] 收到音频块 #$chunkCount, 大小=${chunk.length}, 最大振幅=$maxAmplitude, 平均振幅=$avgAmplitude, serverReady=$serverReady');
        }

        // 检查服务器是否就绪
        if (!serverReady) {
          if (serverReadyCompleter.isCompleted) {
            serverReady = true;
            debugPrint('[AliCloudASR] 服务器已就绪，发送缓冲的 ${audioBuffer.length} 个音频块');
            // 发送缓冲的音频（再次检查会话ID）
            for (final bufferedChunk in audioBuffer) {
              if (sessionId != _currentSessionId) break;
              if (_webSocket?.readyState == WebSocket.open) {
                _webSocket!.add(bufferedChunk);
              }
            }
            audioBuffer.clear();
          } else {
            // 服务器未就绪，缓冲音频（最多缓冲100个块，约3秒）
            if (audioBuffer.length < 100) {
              audioBuffer.add(chunk);
            }
            continue;
          }
        }

        resetSilenceTimer();

        // 再次检查会话ID，确保不向新会话的WebSocket发送旧数据
        if (sessionId == _currentSessionId && _webSocket?.readyState == WebSocket.open) {
          _webSocket!.add(chunk);
          if (chunkCount % 100 == 0) {
            debugPrint('[AliCloudASR] 已发送 $chunkCount 个音频块');
          }
        }
      }

      debugPrint('[AliCloudASR] 音频流结束，发送StopTranscription');
      // 只有当前会话才发送StopTranscription
      if (sessionId == _currentSessionId && !_isCancelled && _webSocket?.readyState == WebSocket.open) {
        final stopParams = {
          'header': {
            'message_id': _generateMessageId(),
            'task_id': taskId,
            'namespace': 'SpeechTranscriber',
            'name': 'StopTranscription',
            'appkey': appKey,
          },
        };
        _webSocket?.add(jsonEncode(stopParams));
      }
    } catch (e) {
      debugPrint('[AliCloudASR] 音频流处理错误: $e');
    }
  }

  /// 生成符合阿里云NLS要求的消息ID（UUID格式）
  String _generateMessageId() {
    return _generateUUID();
  }

  /// 生成符合阿里云NLS要求的任务ID（UUID格式）
  String _generateTaskId() {
    return _generateUUID();
  }

  /// 随机数生成器（用于UUID）
  static final Random _random = Random();

  /// 生成UUID格式的字符串（32位16进制，无连字符）
  String _generateUUID() {
    final bytes = <int>[];

    // 生成16个随机字节
    for (var i = 0; i < 16; i++) {
      bytes.add(_random.nextInt(256));
    }

    // 设置UUID版本4（随机）
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // 设置UUID变体
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    // 转换为32位16进制字符串（无连字符）
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// 清理计时器
  void _cleanupTimers() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// 停止当前流式识别
  ///
  /// 发送StopTranscription命令并关闭WebSocket连接
  Future<void> stopTranscription() async {
    // 先设置取消标志，停止音频发送
    _isCancelled = true;

    // 清理计时器
    _cleanupTimers();

    if (_webSocket == null || _webSocket!.readyState != WebSocket.open) {
      return;
    }

    // 等待音频发送循环停止
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // 发送停止命令
      final stopParams = {
        'header': {
          'message_id': _generateMessageId(),
          'task_id': _currentTaskId ?? 'unknown',
          'namespace': 'SpeechTranscriber',
          'name': 'StopTranscription',
          'appkey': _currentAppKey ?? '',
        },
      };
      _webSocket!.add(jsonEncode(stopParams));

      // 等待一小段时间让服务器处理
      await Future.delayed(const Duration(milliseconds: 100));

      // 关闭WebSocket
      await _webSocket!.close();
      _webSocket = null;
      _currentTaskId = null;
      _currentAppKey = null;

      debugPrint('AliCloudASRService: transcription stopped');
    } catch (e) {
      debugPrint('AliCloudASRService: stop transcription error - $e');
    }
  }

  /// 取消当前流式识别（用于打断场景）
  ///
  /// 立即停止识别，不等待服务器响应
  Future<void> cancelTranscription() async {
    debugPrint('[AliCloudASR] cancelTranscription 开始');
    _isCancelled = true;

    // 递增会话ID，使旧会话的音频处理循环立即停止
    _currentSessionId++;
    debugPrint('[AliCloudASR] 会话ID递增到 $_currentSessionId');

    _cleanupTimers();

    // 关闭流控制器
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.close();
    }
    _streamController = null;

    // 关闭WebSocket（不发送停止命令，直接关闭）
    final ws = _webSocket;
    _webSocket = null;
    _currentTaskId = null;
    _currentAppKey = null;

    if (ws != null) {
      try {
        await ws.close();
        debugPrint('[AliCloudASR] WebSocket已关闭');
      } catch (e) {
        debugPrint('[AliCloudASR] 关闭WebSocket错误: $e');
      }
    }

    debugPrint('AliCloudASRService: transcription cancelled');
  }

  /// 当前任务ID
  String? _currentTaskId;

  void dispose() {
    cancelTranscription();
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

    // 打断相关（高优先级）
    HotWord('停', weight: 2.5),
    HotWord('等等', weight: 2.5),
    HotWord('等一下', weight: 2.5),
    HotWord('算了', weight: 2.5),
    HotWord('不对', weight: 2.5),
    HotWord('不是', weight: 2.5),
    HotWord('停止', weight: 2.5),
    HotWord('打住', weight: 2.5),
    HotWord('继续', weight: 2.0),

    // 确认相关
    HotWord('好的', weight: 1.8),
    HotWord('确认', weight: 1.8),
    HotWord('对', weight: 1.8),
    HotWord('是的', weight: 1.8),
    HotWord('取消', weight: 2.0),
    HotWord('不要', weight: 2.0),

    // 自动化相关
    HotWord('支付宝', weight: 2.0),
    HotWord('微信', weight: 2.0),
    HotWord('同步', weight: 1.8),
    HotWord('导入', weight: 1.8),
    HotWord('账单', weight: 1.8),
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
