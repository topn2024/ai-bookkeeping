import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart'; // 包含 sha1, Hmac
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

import 'voice_recognition_engine.dart';

// 用于标记不等待的Future
void _unawaited(Future<void> future) {}

/// 讯飞实时语音转写大模型服务
///
/// 使用WebSocket协议进行实时语音识别，比语音听写更快
/// 接口地址：wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1
/// 文档：https://www.xfyun.cn/doc/spark/asr_llm/rtasr_llm.html
class IFlytekRTASRService {
  // 讯飞配置
  static const String _appId = '7adc2cc4';
  static const String _apiSecret = 'Mjk1MWUyNjIxNDNiMWEzNTNlMzYxNTlj';
  static const String _apiKey = '71f9de1684a741d249dbdda8ebe5d9f1'; // 作为accessKeyId使用
  static const String _hostUrl = 'wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1';

  IOWebSocketChannel? _webSocketChannel;
  StreamController<ASRPartialResult>? _streamController;

  /// 当前是否正在识别
  bool _isRecognizing = false;

  /// 最后累积的识别文本（用于cancel时发送最终结果）
  String _lastAccumulatedText = '';

  /// 最后的帧索引
  int _lastFrameIndex = 0;

  /// 上一个处理的segId（用于检测segment跳变）
  int _lastSegId = -1;

  /// 上一个segment的文本（用于在segment切换时发送最终结果）
  String _lastSegmentText = '';

  /// 是否已取消
  bool _isCancelled = false;

  /// 会话ID（防止并发）
  int _currentSessionId = 0;

  // ==================== 预连接相关 ====================

  /// 预连接的WebSocket
  IOWebSocketChannel? _warmupChannel;

  /// 预连接创建时间
  DateTime? _warmupCreatedAt;

  /// 预连接是否就绪
  bool _warmupReady = false;

  /// 预连接URL（用于验证）
  String? _warmupUrl;

  /// 预连接有效期（毫秒）- 签名URL通常5分钟有效，这里保守设为2分钟
  static const int _warmupValidityMs = 120000;

  /// 预连接超时计时器
  Timer? _warmupTimeoutTimer;

  /// 生成WebSocket URL（带鉴权）
  ///
  /// 实时语音转写大模型使用不同的鉴权方式：
  /// URL格式：wss://xxx/ast/communicate/v1?accessKeyId=xxx&appId=xxx&uuid=xxx&utc=xxx&signature=xxx&audio_encode=pcm_s16le&lang=autodialect&samplerate=16000
  String _generateUrl() {
    // 生成UUID
    final uuid = _generateUuid();

    // 生成UTC时间戳（格式：2025-09-04T15:38:07+0800）
    final now = DateTime.now();
    final utc = _formatUtcTime(now);

    // 构建签名参数（按字母顺序排序）
    final params = {
      'accessKeyId': _apiKey,
      'appId': _appId,
      'audio_encode': 'pcm_s16le',
      'lang': 'autodialect',
      'samplerate': '16000',
      'utc': utc,
      'uuid': uuid,
    };

    // 按key排序拼接签名字符串
    // 关键：签名原文中的key和value都需要URL编码
    final sortedKeys = params.keys.toList()..sort();
    final signatureOrigin = sortedKeys
        .map((k) => '${Uri.encodeComponent(k)}=${Uri.encodeComponent(params[k]!)}')
        .join('&');

    // 使用HMAC-SHA1签名
    final hmac = Hmac(sha1, utf8.encode(_apiSecret));
    final signature = base64.encode(hmac.convert(utf8.encode(signatureOrigin)).bytes);

    // 构建最终URL（使用Uri类的标准编码）
    final queryParams = {
      ...params,
      'signature': signature,
    };
    final uri = Uri.parse(_hostUrl).replace(queryParameters: queryParams);
    final url = uri.toString();

    return url;
  }

  /// 生成UUID（无横线的hex格式）
  String _generateUuid() {
    return const Uuid().v4().replaceAll('-', '');
  }

  /// 格式化UTC时间（格式：2025-09-04T15:38:07+0800）
  String _formatUtcTime(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    // 计算时区偏移
    final offset = date.timeZoneOffset;
    final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final offsetSign = offset.isNegative ? '-' : '+';

    return '$year-$month-${day}T$hour:$minute:$second$offsetSign$offsetHours$offsetMinutes';
  }

  // ==================== 预连接方法 ====================

  /// 预热连接（提前建立WebSocket连接）
  ///
  /// 在用户点击麦克风按钮时调用，可节省100-300ms连接延迟
  /// 预连接有效期为2分钟，超时会自动清理
  ///
  /// 注意：预连接只建立TCP/TLS连接，不监听stream（因为stream是单订阅的）
  /// 实际的消息监听在transcribeStream中进行
  Future<void> warmupConnection() async {
    // 如果正在识别，不需要预连接
    if (_isRecognizing) {
      debugPrint('[IFlytekRTASR] 正在识别中，跳过预连接');
      return;
    }

    // 如果已有有效的预连接，不重复创建
    if (_isWarmupValid()) {
      debugPrint('[IFlytekRTASR] 预连接仍有效，跳过');
      return;
    }

    // 清理旧的预连接
    await _cleanupWarmup();

    try {
      debugPrint('[IFlytekRTASR] 开始预热连接...');
      final startTime = DateTime.now();

      // 生成URL
      final url = _generateUrl();
      _warmupUrl = url;
      _warmupCreatedAt = DateTime.now();

      // 建立WebSocket连接
      // 注意：IOWebSocketChannel.connect会立即开始建立连接
      // 不需要等待或监听，连接建立是异步的
      _warmupChannel = IOWebSocketChannel.connect(
        url,
        pingInterval: const Duration(seconds: 20),
      );

      // 等待一小段时间让TCP/TLS握手完成
      // 这里不监听stream，只是给连接时间建立
      await Future.delayed(const Duration(milliseconds: 200));

      _warmupReady = true;

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('[IFlytekRTASR] 预连接完成，耗时 ${elapsed}ms');

      // 启动超时清理计时器
      _warmupTimeoutTimer?.cancel();
      _warmupTimeoutTimer = Timer(
        Duration(milliseconds: _warmupValidityMs),
        () {
          debugPrint('[IFlytekRTASR] 预连接超时，清理');
          _cleanupWarmup();
        },
      );
    } catch (e) {
      debugPrint('[IFlytekRTASR] 预连接失败: $e');
      await _cleanupWarmup();
    }
  }

  /// 检查预连接是否有效
  bool _isWarmupValid() {
    if (_warmupChannel == null || !_warmupReady) {
      return false;
    }

    if (_warmupCreatedAt == null) {
      return false;
    }

    // 检查是否超时
    final elapsed = DateTime.now().difference(_warmupCreatedAt!).inMilliseconds;
    return elapsed < _warmupValidityMs;
  }

  /// 消费预连接（用于transcribeStream）
  IOWebSocketChannel? _consumeWarmup() {
    if (!_isWarmupValid()) {
      _cleanupWarmup();
      return null;
    }

    final channel = _warmupChannel;
    // 转移所有权，不再由预连接管理
    _warmupChannel = null;
    _warmupReady = false;
    _warmupUrl = null;
    _warmupCreatedAt = null;
    _warmupTimeoutTimer?.cancel();
    _warmupTimeoutTimer = null;

    debugPrint('[IFlytekRTASR] 消费预连接');
    return channel;
  }

  /// 清理预连接
  Future<void> _cleanupWarmup() async {
    _warmupTimeoutTimer?.cancel();
    _warmupTimeoutTimer = null;

    final channel = _warmupChannel;
    _warmupChannel = null;
    _warmupReady = false;
    _warmupUrl = null;
    _warmupCreatedAt = null;

    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (e) {
        debugPrint('[IFlytekRTASR] 关闭预连接异常: $e');
      }
    }
  }

  /// 是否有有效的预连接
  bool get hasValidWarmup => _isWarmupValid();

  /// 实时语音识别（流式）
  Stream<ASRPartialResult> transcribeStream(Stream<Uint8List> audioStream) async* {
    debugPrint('[IFlytekRTASR] transcribeStream 开始');

    // 防止并发
    if (_isRecognizing) {
      debugPrint('[IFlytekRTASR] 取消之前的识别');
      await cancelTranscription();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _currentSessionId++;
    final sessionId = _currentSessionId;
    _isRecognizing = true;
    _isCancelled = false;
    _lastAccumulatedText = '';
    _lastFrameIndex = 0;
    _lastSegId = -1;  // 重置segment跟踪
    _lastSegmentText = '';

    final controller = StreamController<ASRPartialResult>.broadcast();
    _streamController = controller;

    bool isCompleted = false;
    bool hasSentFinal = false; // 是否已发送最终结果
    int frameIndex = 0;
    final resultSegments = <String>[]; // 存储识别结果的段落
    String lastText = ''; // 最后一次发送的文本

    void markCompleted() {
      if (!isCompleted) {
        isCompleted = true;
      }
    }

    try {
      // 尝试复用预连接
      final warmupChannel = _consumeWarmup();
      if (warmupChannel != null) {
        _webSocketChannel = warmupChannel;
        debugPrint('[IFlytekRTASR] 复用预连接，节省连接时间');
      } else {
        // 没有预连接，新建连接
        final url = _generateUrl();
        debugPrint('[IFlytekRTASR] 新建WebSocket连接: ${url.substring(0, 80)}...');

        _webSocketChannel = IOWebSocketChannel.connect(
          url,
          pingInterval: const Duration(seconds: 20),
        );
      }

      // 监听WebSocket消息
      final completer = Completer<void>();

      _webSocketChannel!.stream.listen(
        (message) {
          if (_isCancelled || sessionId != _currentSessionId) {
            debugPrint('[IFlytekRTASR] 会话已过期，忽略消息');
            return;
          }

          try {
            final data = jsonDecode(message as String);
            final msgType = data['msg_type'] as String?;

            debugPrint('[IFlytekRTASR] 收到消息: msgType=$msgType');

            // 处理错误消息
            if (msgType == 'error') {
              final errorData = data['data'];
              final code = errorData?['code'] as int? ?? 0;
              final msg = errorData?['message'] as String? ?? '未知错误';

              debugPrint('[IFlytekRTASR] 错误: code=$code, message=$msg');

              // 如果是余额不足错误，抛出特定异常以便降级
              if (code == 11200 || code == 11201 || msg.contains('余额')) {
                controller.addError(ASRException(
                  '实时语音转写大模型余额不足',
                  errorCode: ASRErrorCode.rateLimited,
                ));
              } else {
                controller.addError(ASRException(
                  '识别失败: $msg',
                  errorCode: ASRErrorCode.serverError,
                ));
              }
              markCompleted();
              return;
            }

            // 处理会话控制消息
            if (msgType == 'action') {
              final action = data['data']?['action'] as String?;
              debugPrint('[IFlytekRTASR] 会话控制: action=$action');
              return;
            }

            // 处理识别结果消息
            if (msgType == 'result' && data['res_type'] == 'asr') {
              final resultData = data['data'];
              if (resultData == null) return;

              final segId = resultData['seg_id'] as int? ?? 0;
              final isLast = resultData['ls'] == true;

              // 解析识别文本: data.cn.st.rt[].ws[].cw[].w
              final cn = resultData['cn'];
              if (cn == null) return;

              final st = cn['st'];
              if (st == null) return;

              final rtList = st['rt'] as List?;
              if (rtList == null || rtList.isEmpty) return;

              final texts = <String>[];
              for (final rt in rtList) {
                final wsList = rt['ws'] as List?;
                if (wsList == null) continue;

                for (final ws in wsList) {
                  final cwList = ws['cw'] as List?;
                  if (cwList == null) continue;

                  for (final cw in cwList) {
                    final word = cw['w'] as String? ?? '';
                    if (word.isNotEmpty) {
                      texts.add(word);
                    }
                  }
                }
              }

              final segmentText = texts.join('');

              debugPrint('[IFlytekRTASR] 原始结果: segId=$segId, text="$segmentText", isLast=$isLast');

              // 去除开头的标点符号
              final cleanText = segmentText.replaceFirst(RegExp(r'^[，。？！,.\?!]+'), '');

              // 检测新句子开始（累积文本回退）
              // 讯飞RTASR大模型的特点：每个segId包含累积文本，当开始新句子时，文本会变短
              // 例如：segId=4是"早餐7块，中餐8块"，segId=5变成"挽"，说明新句子开始
              if (_lastSegmentText.isNotEmpty && cleanText.length < _lastSegmentText.length) {
                debugPrint('[IFlytekRTASR] 检测到累积文本回退 (${_lastSegmentText.length} → ${cleanText.length})，发送上一句的最终结果: "$_lastSegmentText"');
                controller.add(ASRPartialResult(
                  text: _lastSegmentText,
                  isFinal: true,  // 标记为最终结果
                  index: frameIndex++,
                  confidence: 0.95,
                ));
                // 清空上一句的缓存
                _lastSegmentText = '';
              }

              // 大模型版：每个segId的内容是累积式的（包含之前所有内容）
              // 所以我们只需要使用最新的（最大segId的）文本
              if (cleanText.isNotEmpty) {
                // 更新当前segId的文本（同一segId的更新是替换）
                while (resultSegments.length <= segId) {
                  resultSegments.add('');
                }
                resultSegments[segId] = cleanText;

                // 记录当前segment信息
                _lastSegId = segId;

                // 大模型版返回的是累积式结果，只使用最大segId的文本
                // 找到最大非空segId的文本
                String fullText = '';
                for (int i = resultSegments.length - 1; i >= 0; i--) {
                  if (resultSegments[i].isNotEmpty) {
                    fullText = resultSegments[i];
                    break;
                  }
                }

                debugPrint('[IFlytekRTASR] 使用segId=$segId的文本: "$fullText"');

                if (fullText.isEmpty) {
                  return;
                }

                if (fullText.isNotEmpty) {
                  lastText = fullText; // 记录最后的文本
                  _lastAccumulatedText = fullText; // 同时更新实例变量
                  _lastSegmentText = fullText; // 记录当前segment的文本
                  _lastFrameIndex = frameIndex;
                  controller.add(ASRPartialResult(
                    text: fullText,
                    isFinal: isLast,
                    index: frameIndex++,
                    confidence: 0.95,
                  ));

                  if (isLast) {
                    hasSentFinal = true;
                  }
                }
              }

              if (isLast) {
                debugPrint('[IFlytekRTASR] 识别完成');
                markCompleted();
                if (!completer.isCompleted) {
                  completer.complete();
                }
              }
            }
          } catch (e) {
            debugPrint('[IFlytekRTASR] 解析消息失败: $e');
            controller.addError(ASRException(
              '解析结果失败: $e',
              errorCode: ASRErrorCode.unknown,
            ));
          }
        },
        onError: (error) {
          debugPrint('[IFlytekRTASR] WebSocket错误: $error');
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
          debugPrint('[IFlytekRTASR] WebSocket关闭');
          markCompleted();
          if (!controller.isClosed && !completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      // 启动音频发送任务（异步执行，不阻塞结果输出）
      // 大模型版直接发送二进制音频数据，不是JSON格式
      Future<void> sendAudioTask() async {
        try {
          int frameCount = 0;

          await for (final audioChunk in audioStream) {
            if (_isCancelled || sessionId != _currentSessionId) {
              debugPrint('[IFlytekRTASR] 识别已取消');
              break;
            }

            // 直接发送二进制音频数据（大模型版不需要JSON封装）
            _webSocketChannel?.sink.add(audioChunk);
            frameCount++;

            if (frameCount <= 3 || frameCount % 50 == 0) {
              debugPrint('[IFlytekRTASR] 发送音频帧 #$frameCount: ${audioChunk.length} bytes');
            }
          }

          // 发送结束标记（JSON格式）
          if (!_isCancelled && sessionId == _currentSessionId) {
            final endMsg = jsonEncode({'end': true});
            _webSocketChannel?.sink.add(endMsg);
            debugPrint('[IFlytekRTASR] 发送结束标记');

            await completer.future.timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('[IFlytekRTASR] 等待最终结果超时');
                if (!controller.isClosed) {
                  controller.close();
                }
              },
            );
          }
        } catch (e) {
          debugPrint('[IFlytekRTASR] 音频发送任务异常: $e');
          if (!controller.isClosed) {
            controller.addError(e);
            controller.close();
          }
        }
      }

      // 启动音频发送任务（不等待）
      _unawaited(sendAudioTask());

      // 立即开始输出结果
      await for (final result in controller.stream) {
        yield result;
      }
    } catch (e) {
      debugPrint('[IFlytekRTASR] 识别异常: $e');
      if (!controller.isClosed) {
        controller.addError(ASRException(
          '识别异常: $e',
          errorCode: ASRErrorCode.unknown,
        ));
      }
      rethrow;
    } finally {
      markCompleted();

      // 如果有未发送的最终结果，在关闭前发送
      // 注意：如果是通过cancelTranscription退出的，controller可能已关闭
      // 这里的逻辑作为正常结束时的兜底
      if (!hasSentFinal && lastText.isNotEmpty && !controller.isClosed) {
        debugPrint('[IFlytekRTASR] finally块发送最终结果: "$lastText"');
        controller.add(ASRPartialResult(
          text: lastText,
          isFinal: true,
          index: frameIndex,
          confidence: 0.95,
        ));
      }

      // 关闭controller（如果未被cancelTranscription关闭）
      if (!controller.isClosed) {
        await controller.close();
      }

      await _webSocketChannel?.sink.close();
      _webSocketChannel = null;
      _isRecognizing = false;
      _streamController = null;
      _lastAccumulatedText = '';
      _lastFrameIndex = 0;
      debugPrint('[IFlytekRTASR] transcribeStream 结束');
    }
  }

  /// 取消当前识别
  Future<void> cancelTranscription() async {
    debugPrint('[IFlytekRTASR] cancelTranscription');
    _isCancelled = true;

    // 关闭WebSocket
    await _webSocketChannel?.sink.close();
    _webSocketChannel = null;

    // 如果有streamController且未关闭，发送最终结果后关闭
    // 这会触发transcribeStream的for-await循环退出
    final controller = _streamController;
    if (controller != null && !controller.isClosed) {
      // 发送最终结果（如果有累积的文本）
      if (_lastAccumulatedText.isNotEmpty) {
        debugPrint('[IFlytekRTASR] cancelTranscription发送最终结果: "$_lastAccumulatedText"');
        controller.add(ASRPartialResult(
          text: _lastAccumulatedText,
          isFinal: true,
          index: _lastFrameIndex,
          confidence: 0.95,
        ));
      }
      // 关闭controller，触发for-await循环退出
      await controller.close();
    }

    _streamController = null;
    _lastAccumulatedText = '';
    _lastFrameIndex = 0;
    _isRecognizing = false;
  }

  /// 释放资源
  Future<void> dispose() async {
    await cancelTranscription();
  }
}
