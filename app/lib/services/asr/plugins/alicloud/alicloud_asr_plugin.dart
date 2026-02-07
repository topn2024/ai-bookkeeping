import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/asr_capabilities.dart';
import '../../core/asr_config.dart';
import '../../core/asr_exception.dart';
import '../../core/asr_models.dart';
import '../../core/asr_plugin_interface.dart';
import '../../utils/audio_buffer.dart';
import '../../utils/retry_policy.dart';
import 'alicloud_auth.dart';
import 'alicloud_parser.dart';

/// 阿里云ASR插件
///
/// 支持REST API和WebSocket实时转写
class AliCloudASRPlugin extends ASRPluginBase {
  final AliCloudAuth _auth;
  final AliCloudParser _parser = AliCloudParser();
  final Dio _dio;
  final RetryExecutor _retryExecutor;

  WebSocket? _webSocket;
  StreamController<ASRPartialResult>? _streamController;

  /// 当前会话ID
  int _currentSessionId = 0;

  /// 是否已取消
  bool _isCancelled = false;

  /// 当前任务ID
  String? _currentTaskId;

  /// 当前AppKey
  String? _currentAppKey;

  /// 计时器
  Timer? _timeoutTimer;
  Timer? _silenceTimer;

  AliCloudASRPlugin({
    AliCloudAuth? auth,
    Dio? dio,
    RetryPolicy? retryPolicy,
  })  : _auth = auth ?? AliCloudAuth(),
        _dio = dio ?? Dio(),
        _retryExecutor =
            RetryExecutor(policy: retryPolicy ?? RetryPolicy.defaults()) {
    _dio.options.connectTimeout = Duration(
        seconds: ASRErrorHandlingConfig.defaultTimeoutSeconds);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  @override
  String get pluginId => 'alicloud_asr';

  @override
  String get displayName => '阿里云语音识别';

  @override
  int get priority => 20; // 次高优先级

  @override
  ASRCapabilities get capabilities => ASRCapabilities.online().copyWith(
        supportsStreaming: true,
        supportsBatch: true,
        requiresNetwork: true,
        supportedLanguages: ['zh-CN', 'en-US'],
        maxDurationSeconds: 60,
        supportsHotWords: true,
        supportsPunctuation: true,
        supportsVAD: true,
        estimatedLatencyMs: 300,
      );

  @override
  Future<void> doInitialize() async {
    // 预先获取Token验证配置
    try {
      await _auth.getTokenInfo();
      debugPrint('[AliCloudASRPlugin] 初始化完成');
    } catch (e) {
      debugPrint('[AliCloudASRPlugin] 初始化失败: $e');
      // 不抛出异常，允许插件在可用时重试
    }
  }

  @override
  Future<ASRAvailability> checkAvailability() async {
    try {
      await _auth.getTokenInfo();
      return ASRAvailability.available();
    } catch (e) {
      return ASRAvailability.unavailable('Token获取失败: $e');
    }
  }

  @override
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    debugPrint(
        '[AliCloudASRPlugin] transcribe开始，音频数据: ${audio.data.length} bytes, 时长: ${audio.duration.inMilliseconds}ms');

    // 检查音频时长
    if (audio.duration.inSeconds > ASRErrorHandlingConfig.maxRecognitionSeconds) {
      throw ASRException(
        '音频时长超过${ASRErrorHandlingConfig.maxRecognitionSeconds}秒限制',
        errorCode: ASRErrorCode.recognitionTimeout,
      );
    }

    final stopwatch = Stopwatch()..start();

    return _retryExecutor.execute(
      () async {
        final tokenInfo = await _auth.getTokenInfo();
        final uri = await _auth.buildRestUrl();

        debugPrint('[AliCloudASRPlugin] 请求URL: $uri');

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

        debugPrint('[AliCloudASRPlugin] 响应状态码: ${response.statusCode}');

        if (response.statusCode == 200) {
          final result = _parser.parseRestResponse(response.data);
          if (result == null) {
            throw ASRException(
              '解析响应失败',
              errorCode: ASRErrorCode.serverError,
            );
          }

          if (result.type == AliCloudParsedResultType.error) {
            throw result.error!;
          }

          stopwatch.stop();

          // 检查结果是否为空但音频有内容
          if (result.text?.isEmpty == true && audio.hasContent) {
            throw ASRException(
              'ASR返回空结果，需要重试',
              errorCode: ASRErrorCode.serverError,
            );
          }

          return ASRResult(
            text: result.text ?? '',
            confidence: result.confidence ?? 0.9,
            words: [],
            duration: audio.duration,
            isOffline: false,
            pluginId: pluginId,
            processingTime: stopwatch.elapsed,
          );
        } else {
          throw ASRException(
            'ASR请求失败: ${response.statusCode}',
            errorCode: ASRErrorCode.serverError,
          );
        }
      },
      onRetry: (retryCount, error, delay) {
        debugPrint(
            '[AliCloudASRPlugin] 重试 $retryCount, 延迟: ${delay.inMilliseconds}ms, 错误: $error');
      },
    );
  }

  @override
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    debugPrint('[AliCloudASRPlugin] transcribeStream 开始');

    // 防止并发
    if (_webSocket != null) {
      debugPrint('[AliCloudASRPlugin] 取消之前的识别');
      await cancelTranscription();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _currentSessionId++;
    final sessionId = _currentSessionId;
    state = ASRPluginState.recognizing;
    _isCancelled = false;
    _cleanupTimers();

    final controller = StreamController<ASRPartialResult>.broadcast();
    _streamController = controller;

    bool isCompleted = false;
    int resultIndex = 0;
    final serverReadyCompleter = Completer<void>();

    void markCompleted() {
      if (!isCompleted) {
        isCompleted = true;
        _cleanupTimers();
      }
    }

    void resetSilenceTimer() {
      _silenceTimer?.cancel();
      _silenceTimer = Timer(
        Duration(seconds: ASRErrorHandlingConfig.silenceTimeoutSeconds),
        () {
          if (!isCompleted && !_isCancelled) {
            debugPrint('[AliCloudASRPlugin] 静音超时，停止识别');
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
          debugPrint('[AliCloudASRPlugin] 识别超时');
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
      final wsUri = await _auth.buildWebSocketUrl();
      final tokenInfo = await _auth.getTokenInfo();
      debugPrint('[AliCloudASRPlugin] WebSocket URL: ${wsUri.toString().replaceAll(tokenInfo.token, '***')}');

      // 连接WebSocket
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
      debugPrint('[AliCloudASRPlugin] WebSocket已连接');

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
          'max_sentence_silence': 800,
          'enable_voice_detection': true,
          'enable_semantic_sentence_detection': false,
        },
      };

      _webSocket!.add(jsonEncode(startParams));
      debugPrint('[AliCloudASRPlugin] 已发送StartTranscription命令');

      // 监听响应
      _webSocket!.listen(
        (data) {
          if (data is String) {
            final result = _parser.parse(data);
            if (result == null) return;

            switch (result.type) {
              case AliCloudParsedResultType.serverReady:
                if (!serverReadyCompleter.isCompleted) {
                  serverReadyCompleter.complete();
                }
                break;

              case AliCloudParsedResultType.partialResult:
                resetSilenceTimer();
                if (!controller.isClosed && result.text != null) {
                  controller.add(ASRPartialResult(
                    text: result.text!,
                    isFinal: false,
                    index: resultIndex++,
                    confidence: result.confidence,
                    pluginId: pluginId,
                  ));
                }
                break;

              case AliCloudParsedResultType.sentenceEnd:
                if (!controller.isClosed && result.text != null) {
                  controller.add(ASRPartialResult(
                    text: result.text!,
                    isFinal: true,
                    index: resultIndex++,
                    confidence: result.confidence,
                    pluginId: pluginId,
                  ));
                }
                break;

              case AliCloudParsedResultType.completed:
                markCompleted();
                if (!controller.isClosed) {
                  controller.close();
                }
                break;

              case AliCloudParsedResultType.error:
                markCompleted();
                if (!serverReadyCompleter.isCompleted) {
                  serverReadyCompleter.completeError(result.error!);
                }
                if (!controller.isClosed) {
                  controller.addError(result.error!);
                  controller.close();
                }
                break;
            }
          }
        },
        onError: (error) {
          debugPrint('[AliCloudASRPlugin] WebSocket错误: $error');
          markCompleted();
          if (!controller.isClosed) {
            controller.addError(ASRException(
              'WebSocket错误: $error',
              errorCode: ASRErrorCode.noConnection,
            ));
            controller.close();
          }
        },
        onDone: () {
          debugPrint('[AliCloudASRPlugin] WebSocket关闭');
          markCompleted();
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );

      // 异步处理音频流
      _processAudioStreamAsync(
        audioStream,
        taskId,
        tokenInfo.appKey,
        resetSilenceTimer,
        serverReadyCompleter,
        sessionId,
      );
    } catch (e) {
      debugPrint('[AliCloudASRPlugin] 流式识别错误: $e');
      markCompleted();
      if (e is ASRException) {
        controller.addError(e);
      } else {
        controller.addError(ASRException(
          '流式识别错误: $e',
          errorCode: ASRErrorCode.unknown,
        ));
      }
      controller.close();
    }

    // 输出结果
    debugPrint('[AliCloudASRPlugin] 开始yield结果流');
    await for (final result in controller.stream) {
      yield result;
    }
    debugPrint('[AliCloudASRPlugin] 结果流结束');

    // 清理
    _cleanupTimers();
    _streamController = null;
    state = ASRPluginState.idle;
  }

  /// 异步处理音频流
  Future<void> _processAudioStreamAsync(
    Stream<Uint8List> audioStream,
    String taskId,
    String appKey,
    void Function() resetSilenceTimer,
    Completer<void> serverReadyCompleter,
    int sessionId,
  ) async {
    debugPrint('[AliCloudASRPlugin] 开始处理音频流, sessionId=$sessionId');

    final audioBuffer = AudioListBuffer(maxChunks: 100);
    bool serverReady = false;
    int chunkCount = 0;

    try {
      await for (final chunk in audioStream) {
        // 检查会话是否有效
        if (sessionId != _currentSessionId) {
          debugPrint('[AliCloudASRPlugin] 会话已过期，停止处理');
          break;
        }
        if (_isCancelled) {
          debugPrint('[AliCloudASRPlugin] 音频流处理被取消');
          break;
        }

        chunkCount++;

        // 检查服务器是否就绪
        if (!serverReady) {
          if (serverReadyCompleter.isCompleted) {
            serverReady = true;
            debugPrint(
                '[AliCloudASRPlugin] 服务器已就绪，发送缓冲的 ${audioBuffer.length} 个音频块');
            // 发送缓冲的音频
            for (final bufferedChunk in audioBuffer.chunks) {
              if (sessionId != _currentSessionId) break;
              if (_webSocket?.readyState == WebSocket.open) {
                _webSocket!.add(bufferedChunk);
              }
            }
            audioBuffer.clear();
          } else {
            // 服务器未就绪，缓冲音频
            audioBuffer.add(chunk);
            continue;
          }
        }

        resetSilenceTimer();

        if (sessionId == _currentSessionId &&
            _webSocket?.readyState == WebSocket.open) {
          _webSocket!.add(chunk);
          if (chunkCount % 100 == 0) {
            debugPrint('[AliCloudASRPlugin] 已发送 $chunkCount 个音频块');
          }
        }
      }

      debugPrint('[AliCloudASRPlugin] 音频流结束，发送StopTranscription');
      if (sessionId == _currentSessionId &&
          !_isCancelled &&
          _webSocket?.readyState == WebSocket.open) {
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
      debugPrint('[AliCloudASRPlugin] 音频流处理错误: $e');
    }
  }

  @override
  Future<void> cancelTranscription() async {
    debugPrint('[AliCloudASRPlugin] cancelTranscription 开始');
    _isCancelled = true;
    _currentSessionId++;
    _cleanupTimers();

    // 关闭流控制器
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.close();
    }
    _streamController = null;

    // 关闭WebSocket
    final ws = _webSocket;
    _webSocket = null;
    _currentTaskId = null;
    _currentAppKey = null;

    if (ws != null) {
      try {
        await ws.close();
        debugPrint('[AliCloudASRPlugin] WebSocket已关闭');
      } catch (e) {
        debugPrint('[AliCloudASRPlugin] 关闭WebSocket错误: $e');
      }
    }

    state = ASRPluginState.idle;
    debugPrint('[AliCloudASRPlugin] cancelTranscription 完成');
  }

  void _cleanupTimers() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  String _generateMessageId() => _generateUUID();
  String _generateTaskId() => _generateUUID();

  static final Random _random = Random();

  String _generateUUID() {
    final bytes = <int>[];
    for (var i = 0; i < 16; i++) {
      bytes.add(_random.nextInt(256));
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  @override
  Future<void> doDispose() async {
    await cancelTranscription();
    _dio.close();
  }
}
