import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'voice_recognition_engine.dart';

/// 讯飞语音听写服务
///
/// 使用WebSocket协议进行实时语音识别
/// 文档：https://www.xfyun.cn/doc/asr/voicedictation/API.html
class IFlytekASRService {
  // 讯飞配置
  static const String _appId = '7adc2cc4';
  static const String _apiSecret = 'Mjk1MWUyNjIxNDNiMWEzNTNlMzYxNTlj';
  static const String _apiKey = '71f9de1684a741d249dbdda8ebe5d9f1';
  static const String _hostUrl = 'wss://iat-api.xfyun.cn/v2/iat';

  IOWebSocketChannel? _webSocketChannel;
  StreamController<ASRPartialResult>? _streamController;

  /// 当前是否正在识别
  bool _isRecognizing = false;

  /// 是否已取消
  bool _isCancelled = false;

  /// 会话ID（防止并发）
  int _currentSessionId = 0;

  /// 超时计时器
  Timer? _timeoutTimer;
  Timer? _silenceTimer;

  /// 静音超时时间（秒）
  static const int _silenceTimeoutSeconds = 10;

  /// 最大识别时间（秒）
  static const int _maxRecognitionSeconds = 60;

  /// 生成WebSocket URL（带鉴权）
  String _generateUrl() {
    // 生成RFC1123格式的时间戳
    final now = DateTime.now().toUtc();
    final date = _httpDate(now);

    // 拼接signature原始字符串
    final signatureOrigin = 'host: iat-api.xfyun.cn\n'
        'date: $date\n'
        'GET /v2/iat HTTP/1.1';

    // 使用hmac-sha256加密
    final hmac = Hmac(sha256, utf8.encode(_apiSecret));
    final signature = base64.encode(hmac.convert(utf8.encode(signatureOrigin)).bytes);

    // 拼接authorization
    final authorizationOrigin = 'api_key="$_apiKey", '
        'algorithm="hmac-sha256", '
        'headers="host date request-line", '
        'signature="$signature"';
    final authorization = base64.encode(utf8.encode(authorizationOrigin));

    // 构建最终URL
    final url = '$_hostUrl?authorization=$authorization&date=${Uri.encodeComponent(date)}&host=iat-api.xfyun.cn';

    return url;
  }

  /// 将DateTime转为RFC1123格式
  String _httpDate(DateTime date) {
    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final weekDay = weekDays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$weekDay, $day $month $year $hour:$minute:$second GMT';
  }

  /// 一句话识别（短音频）
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    debugPrint('[IFlytekASR] transcribe开始，音频数据: ${audio.data.length} bytes');

    // 使用流式识别，收集所有结果后返回
    final results = <String>[];

    try {
      await for (final partial in transcribeStream(Stream.value(audio.data))) {
        if (partial.isFinal) {
          results.add(partial.text);
        }
      }

      final finalText = results.join('');
      debugPrint('[IFlytekASR] 识别完成: $finalText');

      return ASRResult(
        text: finalText,
        confidence: 0.9,
        words: [],
        duration: audio.duration,
        isOffline: false,
      );
    } catch (e) {
      debugPrint('[IFlytekASR] 识别失败: $e');
      rethrow;
    }
  }

  /// 实时语音识别（流式）
  Stream<ASRPartialResult> transcribeStream(Stream<Uint8List> audioStream) async* {
    debugPrint('[IFlytekASR] transcribeStream 开始');

    // 防止并发
    if (_isRecognizing) {
      debugPrint('[IFlytekASR] 取消之前的识别');
      await cancelTranscription();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _currentSessionId++;
    final sessionId = _currentSessionId;
    _isRecognizing = true;
    _isCancelled = false;

    final controller = StreamController<ASRPartialResult>.broadcast();
    _streamController = controller;

    bool isCompleted = false;
    int frameIndex = 0;

    void markCompleted() {
      if (!isCompleted) {
        isCompleted = true;
        _cleanupTimers();
      }
    }

    void resetSilenceTimer() {
      _silenceTimer?.cancel();
      _silenceTimer = Timer(
        Duration(seconds: _silenceTimeoutSeconds),
        () {
          if (!isCompleted && !_isCancelled) {
            debugPrint('[IFlytekASR] 静音超时，停止识别');
            controller.addError(ASRException(
              '检测到静音，识别自动停止',
              errorCode: ASRErrorCode.recognitionTimeout,
            ));
            markCompleted();
            _webSocketChannel?.sink.close();
          }
        },
      );
    }

    // 启动总超时计时器
    _timeoutTimer = Timer(
      Duration(seconds: _maxRecognitionSeconds),
      () {
        if (!isCompleted && !_isCancelled) {
          debugPrint('[IFlytekASR] 识别超时');
          controller.addError(ASRException(
            '识别超时，已达到最大时长限制',
            errorCode: ASRErrorCode.recognitionTimeout,
          ));
          markCompleted();
          _webSocketChannel?.sink.close();
        }
      },
    );

    try {
      // 生成WebSocket URL
      final url = _generateUrl();
      debugPrint('[IFlytekASR] 连接WebSocket: $url');

      // 建立WebSocket连接
      _webSocketChannel = IOWebSocketChannel.connect(
        url,
        pingInterval: const Duration(seconds: 20),
      );

      // 监听WebSocket消息
      final completer = Completer<void>();

      _webSocketChannel!.stream.listen(
        (message) {
          if (_isCancelled || sessionId != _currentSessionId) {
            debugPrint('[IFlytekASR] 会话已过期，忽略消息');
            return;
          }

          try {
            final data = jsonDecode(message as String);
            debugPrint('[IFlytekASR] 收到消息: $data');

            final code = data['code'] as int?;
            if (code != 0) {
              debugPrint('[IFlytekASR] 错误: code=$code, message=${data['message']}');
              controller.addError(ASRException(
                '识别失败: ${data['message']}',
                errorCode: ASRErrorCode.serverError,
              ));
              markCompleted();
              return;
            }

            // 解析识别结果
            final resultData = data['data'];
            if (resultData != null) {
              final result = resultData['result'];
              if (result != null) {
                final ws = result['ws'] as List?;
                if (ws != null && ws.isNotEmpty) {
                  final texts = <String>[];
                  for (final w in ws) {
                    final cw = w['cw'] as List?;
                    if (cw != null && cw.isNotEmpty) {
                      texts.add(cw[0]['w'] as String);
                    }
                  }

                  final text = texts.join('');
                  final isLast = resultData['status'] == 2;

                  debugPrint('[IFlytekASR] 识别结果: text="$text", isLast=$isLast');

                  if (text.isNotEmpty) {
                    controller.add(ASRPartialResult(
                      text: text,
                      isFinal: isLast,
                      index: frameIndex++,
                      confidence: 0.9,
                    ));

                    // 重置静音计时器
                    resetSilenceTimer();
                  }

                  if (isLast) {
                    debugPrint('[IFlytekASR] 识别完成');
                    markCompleted();
                    if (!completer.isCompleted) {
                      completer.complete();
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[IFlytekASR] 解析消息失败: $e');
            controller.addError(ASRException(
              '解析结果失败: $e',
              errorCode: ASRErrorCode.unknown,
            ));
          }
        },
        onError: (error) {
          debugPrint('[IFlytekASR] WebSocket错误: $error');
          if (!controller.isClosed) {
            controller.addError(ASRException(
              '连接错误: $error',
              errorCode: ASRErrorCode.noConnection,
            ));
          }
          markCompleted();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          debugPrint('[IFlytekASR] WebSocket关闭');
          markCompleted();
          if (!controller.isClosed && !completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      // 等待WebSocket连接建立
      await Future.delayed(const Duration(milliseconds: 200));

      // 发送音频数据
      int status = 0; // 0: 首帧, 1: 中间帧, 2: 末帧
      await for (final audioChunk in audioStream) {
        if (_isCancelled || sessionId != _currentSessionId) {
          debugPrint('[IFlytekASR] 识别已取消');
          break;
        }

        // 构建数据帧
        final frame = {
          'common': {
            'app_id': _appId,
          },
          'business': {
            'language': 'zh_cn',
            'domain': 'iat',
            'accent': 'mandarin',
            'vad_eos': 5000, // 静音检测超时5秒
            'dwa': 'wpgs', // 动态修正
          },
          'data': {
            'status': status,
            'format': 'audio/L16;rate=16000',
            'encoding': 'raw',
            'audio': base64.encode(audioChunk),
          },
        };

        if (status == 0) {
          status = 1; // 后续为中间帧
        }

        _webSocketChannel!.sink.add(jsonEncode(frame));
        debugPrint('[IFlytekASR] 发送音频帧: ${audioChunk.length} bytes, status=$status');

        // 重置静音计时器
        resetSilenceTimer();

        // 控制发送速率（避免过快）
        await Future.delayed(const Duration(milliseconds: 40));
      }

      // 发送结束帧
      if (!_isCancelled && sessionId == _currentSessionId) {
        final endFrame = {
          'data': {
            'status': 2,
            'format': 'audio/L16;rate=16000',
            'encoding': 'raw',
            'audio': '',
          },
        };
        _webSocketChannel!.sink.add(jsonEncode(endFrame));
        debugPrint('[IFlytekASR] 发送结束帧');

        // 等待服务器返回最终结果
        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[IFlytekASR] 等待最终结果超时');
          },
        );
      }

      // 输出所有结果
      await for (final result in controller.stream) {
        yield result;
      }
    } catch (e) {
      debugPrint('[IFlytekASR] 识别异常: $e');
      if (!controller.isClosed) {
        controller.addError(ASRException(
          '识别异常: $e',
          errorCode: ASRErrorCode.unknown,
        ));
      }
      rethrow;
    } finally {
      markCompleted();
      await _webSocketChannel?.sink.close();
      _webSocketChannel = null;
      _isRecognizing = false;
      _streamController = null;
      debugPrint('[IFlytekASR] transcribeStream 结束');
    }
  }

  /// 取消当前识别
  Future<void> cancelTranscription() async {
    debugPrint('[IFlytekASR] cancelTranscription');
    _isCancelled = true;
    _cleanupTimers();

    await _webSocketChannel?.sink.close();
    _webSocketChannel = null;

    _streamController?.close();
    _streamController = null;

    _isRecognizing = false;
  }

  /// 清理计时器
  void _cleanupTimers() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// 释放资源
  Future<void> dispose() async {
    await cancelTranscription();
  }
}
