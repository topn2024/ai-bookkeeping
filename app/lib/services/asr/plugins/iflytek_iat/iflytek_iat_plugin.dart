import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import '../../core/asr_capabilities.dart';
import '../../core/asr_exception.dart';
import '../../core/asr_models.dart';
import '../../core/asr_plugin_interface.dart';
import 'iflytek_iat_auth.dart';
import 'iflytek_iat_parser.dart';

/// 讯飞语音听写插件
///
/// 使用WebSocket协议进行实时语音识别
/// 文档：https://www.xfyun.cn/doc/asr/voicedictation/API.html
class IFlytekIATPlugin extends ASRPluginBase {
  final IFlytekIATAuth _auth;
  final IFlytekIATParser _parser = IFlytekIATParser();

  IOWebSocketChannel? _webSocketChannel;
  StreamController<ASRPartialResult>? _streamController;

  /// 会话ID（防止并发）
  int _currentSessionId = 0;

  /// 是否已取消
  bool _isCancelled = false;

  IFlytekIATPlugin({IFlytekIATAuth? auth})
      : _auth = auth ?? IFlytekIATAuth.defaults();

  @override
  String get pluginId => 'iflytek_iat';

  @override
  String get displayName => '讯飞语音听写';

  @override
  int get priority => 10; // 最高优先级

  @override
  ASRCapabilities get capabilities => ASRCapabilities.online().copyWith(
        supportsStreaming: true,
        supportsBatch: true,
        requiresNetwork: true,
        supportedLanguages: ['zh-CN'],
        maxDurationSeconds: 60,
        supportsHotWords: false, // 讯飞听写不支持自定义热词
        supportsPunctuation: true,
        supportsVAD: true,
        estimatedLatencyMs: 200,
      );

  @override
  Future<void> doInitialize() async {
    // 讯飞不需要额外初始化
    debugPrint('[IFlytekIATPlugin] 初始化完成');
  }

  @override
  Future<ASRAvailability> checkAvailability() async {
    // 只需要检查网络
    // 实际使用时如果鉴权失败会在transcribe时报错
    return ASRAvailability.available();
  }

  @override
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    debugPrint('[IFlytekIATPlugin] transcribe开始，音频数据: ${audio.data.length} bytes');

    // 使用流式识别，收集所有结果后返回
    final results = <String>[];
    final stopwatch = Stopwatch()..start();

    try {
      await for (final partial in transcribeStream(Stream.value(audio.data))) {
        if (partial.isFinal) {
          results.add(partial.text);
        }
      }

      stopwatch.stop();
      final finalText = results.join('');
      debugPrint('[IFlytekIATPlugin] 识别完成: $finalText');

      return ASRResult(
        text: finalText,
        confidence: 0.9,
        words: [],
        duration: audio.duration,
        isOffline: false,
        pluginId: pluginId,
        processingTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[IFlytekIATPlugin] 识别失败: $e');
      rethrow;
    }
  }

  @override
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    debugPrint('[IFlytekIATPlugin] transcribeStream 开始');

    // 防止并发
    if (state == ASRPluginState.recognizing) {
      debugPrint('[IFlytekIATPlugin] 取消之前的识别');
      await cancelTranscription();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _currentSessionId++;
    final sessionId = _currentSessionId;
    state = ASRPluginState.recognizing;
    _isCancelled = false;
    _parser.reset();

    final controller = StreamController<ASRPartialResult>.broadcast();
    _streamController = controller;

    bool isCompleted = false;
    int frameIndex = 0;
    bool hasReceivedFirstResponse = false;

    void markCompleted() {
      if (!isCompleted) {
        isCompleted = true;
      }
    }

    // 用于等待WebSocket连接就绪
    final connectionReady = Completer<void>();

    try {
      // 生成WebSocket URL
      final url = _auth.generateUrl();
      debugPrint('[IFlytekIATPlugin] 连接WebSocket...');

      // 建立WebSocket连接
      _webSocketChannel = IOWebSocketChannel.connect(
        url,
        pingInterval: const Duration(seconds: 20),
      );

      // 用于等待最终结果
      final completer = Completer<void>();

      // 监听WebSocket消息
      _webSocketChannel!.stream.listen(
        (message) {
          // 收到第一个响应时标记连接就绪
          if (!hasReceivedFirstResponse) {
            hasReceivedFirstResponse = true;
            debugPrint('[IFlytekIATPlugin] 收到首个响应，连接已就绪');
            if (!connectionReady.isCompleted) {
              connectionReady.complete();
            }
          }

          if (_isCancelled || sessionId != _currentSessionId) {
            debugPrint('[IFlytekIATPlugin] 会话已过期，忽略消息');
            return;
          }

          final result = _parser.parse(message as String);
          if (result == null) return;

          switch (result.type) {
            case IFlytekIATParsedResultType.sentence:
              if (!controller.isClosed && result.text != null) {
                controller.add(ASRPartialResult(
                  text: result.text!,
                  isFinal: result.isFinal ?? false,
                  index: frameIndex++,
                  confidence: 0.9,
                  pluginId: pluginId,
                ));
              }
              if (result.isLast == true) {
                markCompleted();
                if (!completer.isCompleted) {
                  completer.complete();
                }
              }
              break;
            case IFlytekIATParsedResultType.completed:
              markCompleted();
              if (!completer.isCompleted) {
                completer.complete();
              }
              break;
            case IFlytekIATParsedResultType.error:
              markCompleted();
              if (!controller.isClosed) {
                controller.addError(result.error!);
              }
              if (!completer.isCompleted) {
                completer.completeError(result.error!);
              }
              break;
          }
        },
        onError: (error) {
          debugPrint('[IFlytekIATPlugin] WebSocket错误: $error');
          if (!connectionReady.isCompleted) {
            connectionReady.completeError(error);
          }
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
          debugPrint('[IFlytekIATPlugin] WebSocket关闭');
          markCompleted();
          if (!controller.isClosed && !completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      // 等待WebSocket连接就绪（带超时保护）
      // 讯飞协议中，发送首帧后服务器才会响应，所以我们设置一个短暂延时让连接稳定
      await Future.delayed(const Duration(milliseconds: 100));
      if (!connectionReady.isCompleted) {
        debugPrint('[IFlytekIATPlugin] WebSocket连接已建立，开始发送音频');
        connectionReady.complete();
      }

      // 启动音频发送任务
      _sendAudioTask(audioStream, sessionId, completer, controller, connectionReady);

      // 立即开始输出结果
      await for (final result in controller.stream) {
        yield result;
      }
    } catch (e) {
      debugPrint('[IFlytekIATPlugin] 识别异常: $e');
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
      state = ASRPluginState.idle;
      _streamController = null;
      debugPrint('[IFlytekIATPlugin] transcribeStream 结束');
    }
  }

  /// 音频发送任务
  ///
  /// 添加音频缓冲机制，防止在WebSocket连接建立前丢失音频
  Future<void> _sendAudioTask(
    Stream<Uint8List> audioStream,
    int sessionId,
    Completer<void> completer,
    StreamController<ASRPartialResult> controller,
    Completer<void> connectionReady,
  ) async {
    try {
      int status = 0; // 0: 首帧, 1: 中间帧, 2: 末帧
      int frameCount = 0;

      // 音频缓冲区：存储连接就绪前收到的音频
      final audioBuffer = <Uint8List>[];
      bool isConnectionReady = false;

      await for (final audioChunk in audioStream) {
        if (_isCancelled || sessionId != _currentSessionId) {
          debugPrint('[IFlytekIATPlugin] 识别已取消');
          break;
        }

        // 检查连接是否就绪
        if (!isConnectionReady) {
          if (connectionReady.isCompleted) {
            isConnectionReady = true;
            debugPrint(
                '[IFlytekIATPlugin] WebSocket已就绪，发送缓冲的 ${audioBuffer.length} 个音频块');

            // 发送缓冲的音频
            for (final bufferedChunk in audioBuffer) {
              if (_isCancelled || sessionId != _currentSessionId) break;

              final frame = _buildFrame(bufferedChunk, status);
              if (status == 0) status = 1;

              _webSocketChannel?.sink.add(jsonEncode(frame));
              frameCount++;

              if (frameCount <= 3) {
                debugPrint(
                    '[IFlytekIATPlugin] 发送缓冲音频帧 #$frameCount: ${bufferedChunk.length} bytes');
              }
            }
            audioBuffer.clear();
          } else {
            // 连接未就绪，缓冲音频（最多缓冲100个块，约3秒）
            if (audioBuffer.length < 100) {
              audioBuffer.add(audioChunk);
              if (audioBuffer.length <= 3 || audioBuffer.length % 20 == 0) {
                debugPrint(
                    '[IFlytekIATPlugin] 缓冲音频块 #${audioBuffer.length}: ${audioChunk.length} bytes (等待连接就绪)');
              }
            }
            continue;
          }
        }

        // 构建并发送数据帧
        final frame = _buildFrame(audioChunk, status);
        if (status == 0) status = 1;

        _webSocketChannel?.sink.add(jsonEncode(frame));
        frameCount++;

        if (frameCount <= 3 || frameCount % 50 == 0) {
          debugPrint(
              '[IFlytekIATPlugin] 发送音频帧 #$frameCount: ${audioChunk.length} bytes');
        }
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
        _webSocketChannel?.sink.add(jsonEncode(endFrame));
        debugPrint('[IFlytekIATPlugin] 发送结束帧，共发送 $frameCount 个音频帧');

        // 等待服务器返回最终结果
        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[IFlytekIATPlugin] 等待最终结果超时');
            if (!controller.isClosed) {
              controller.close();
            }
          },
        );
      }
    } catch (e) {
      debugPrint('[IFlytekIATPlugin] 音频发送任务异常: $e');
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    }
  }

  /// 构建讯飞数据帧
  Map<String, dynamic> _buildFrame(Uint8List audioChunk, int status) {
    final frame = <String, dynamic>{
      'data': {
        'status': status,
        'format': 'audio/L16;rate=16000',
        'encoding': 'raw',
        'audio': base64.encode(audioChunk),
      },
    };

    // 首帧需要包含common和business参数
    if (status == 0) {
      frame['common'] = {
        'app_id': _auth.appId,
      };
      frame['business'] = {
        'language': 'zh_cn',
        'domain': 'iat',
        'accent': 'mandarin',
        'vad_eos': 5000, // 静音检测超时5秒
        'dwa': 'wpgs', // 动态修正
      };
    }

    return frame;
  }

  @override
  Future<void> cancelTranscription() async {
    debugPrint('[IFlytekIATPlugin] cancelTranscription');
    _isCancelled = true;

    await _webSocketChannel?.sink.close();
    _webSocketChannel = null;

    _streamController?.close();
    _streamController = null;

    state = ASRPluginState.idle;
  }

  @override
  Future<void> doDispose() async {
    await cancelTranscription();
    _parser.reset();
  }
}
