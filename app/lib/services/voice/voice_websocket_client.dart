import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 简化的语音WebSocket消息类型
///
/// 新架构下，后端仅作为ASR/TTS代理：
/// - 客户端处理：VAD、打断检测、回声抑制、LLM调用
/// - 后端处理：ASR转写、TTS合成
enum VoiceMessageType {
  // 客户端 -> 服务器
  audioChunk,       // 音频数据块
  ttsRequest,       // TTS合成请求
  interrupt,        // 打断信号
  sessionStart,     // 会话开始
  sessionEnd,       // 会话结束

  // 服务器 -> 客户端
  asrIntermediate,  // ASR中间结果（实时转写）
  asrFinal,         // ASR最终结果
  ttsAudio,         // TTS音频数据
  ttsComplete,      // TTS合成完成
  sessionReady,     // 会话就绪
  sessionClosed,    // 会话已关闭
  error,            // 错误消息
}

/// 消息类型扩展
extension VoiceMessageTypeExtension on VoiceMessageType {
  String get value {
    switch (this) {
      case VoiceMessageType.audioChunk:
        return 'audio_chunk';
      case VoiceMessageType.ttsRequest:
        return 'tts_request';
      case VoiceMessageType.interrupt:
        return 'interrupt';
      case VoiceMessageType.sessionStart:
        return 'session_start';
      case VoiceMessageType.sessionEnd:
        return 'session_end';
      case VoiceMessageType.asrIntermediate:
        return 'asr_intermediate';
      case VoiceMessageType.asrFinal:
        return 'asr_final';
      case VoiceMessageType.ttsAudio:
        return 'tts_audio';
      case VoiceMessageType.ttsComplete:
        return 'tts_complete';
      case VoiceMessageType.sessionReady:
        return 'session_ready';
      case VoiceMessageType.sessionClosed:
        return 'session_closed';
      case VoiceMessageType.error:
        return 'error';
    }
  }

  static VoiceMessageType? fromValue(String value) {
    switch (value) {
      case 'audio_chunk':
        return VoiceMessageType.audioChunk;
      case 'tts_request':
        return VoiceMessageType.ttsRequest;
      case 'interrupt':
        return VoiceMessageType.interrupt;
      case 'session_start':
        return VoiceMessageType.sessionStart;
      case 'session_end':
        return VoiceMessageType.sessionEnd;
      case 'asr_intermediate':
        return VoiceMessageType.asrIntermediate;
      case 'asr_final':
        return VoiceMessageType.asrFinal;
      case 'tts_audio':
        return VoiceMessageType.ttsAudio;
      case 'tts_complete':
        return VoiceMessageType.ttsComplete;
      case 'session_ready':
        return VoiceMessageType.sessionReady;
      case 'session_closed':
        return VoiceMessageType.sessionClosed;
      case 'error':
        return VoiceMessageType.error;
      default:
        return null;
    }
  }
}

/// ASR结果
class ASRResult {
  /// 转写文本
  final String text;

  /// 是否为最终结果
  final bool isFinal;

  /// 置信度（0-1）
  final double? confidence;

  /// 时间戳
  final DateTime timestamp;

  const ASRResult({
    required this.text,
    required this.isFinal,
    this.confidence,
    required this.timestamp,
  });

  factory ASRResult.fromJson(Map<String, dynamic> json) {
    return ASRResult(
      text: json['text'] as String? ?? '',
      isFinal: json['is_final'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestamp: DateTime.now(),
    );
  }
}

/// TTS请求
class TTSRequest {
  /// 要合成的文本
  final String text;

  /// 请求ID
  final int requestId;

  /// 语音参数（可选）
  final TTSVoiceParams? voiceParams;

  const TTSRequest({
    required this.text,
    required this.requestId,
    this.voiceParams,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'text': text,
      'request_id': requestId,
    };
    if (voiceParams != null) {
      json['voice_params'] = voiceParams!.toJson();
    }
    return json;
  }
}

/// TTS语音参数
class TTSVoiceParams {
  /// 语速（0.5-2.0，默认1.0）
  final double? speed;

  /// 音调（0.5-2.0，默认1.0）
  final double? pitch;

  /// 音量（0.0-1.0，默认1.0）
  final double? volume;

  /// 语音ID
  final String? voiceId;

  const TTSVoiceParams({
    this.speed,
    this.pitch,
    this.volume,
    this.voiceId,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (speed != null) json['speed'] = speed;
    if (pitch != null) json['pitch'] = pitch;
    if (volume != null) json['volume'] = volume;
    if (voiceId != null) json['voice_id'] = voiceId;
    return json;
  }
}

/// WebSocket连接状态
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  error,
}

/// 简化的语音WebSocket客户端
///
/// 职责：
/// - 与后端代理服务通信
/// - 发送音频数据进行ASR
/// - 请求TTS合成并接收音频
/// - 处理打断信号
///
/// 不负责：
/// - VAD检测（由ClientVADService处理）
/// - 打断判断（由BargeInDetectorV2处理）
/// - LLM调用（由ClientLLMService处理）
class VoiceWebSocketClient {
  /// 服务器URL
  final String serverUrl;

  /// 用户ID
  final String userId;

  /// 配置
  final VoiceWebSocketConfig config;

  /// WebSocket通道
  WebSocketChannel? _channel;

  /// 消息订阅
  StreamSubscription? _subscription;

  /// 连接状态
  WebSocketState _state = WebSocketState.disconnected;

  /// 状态流
  final _stateController = StreamController<WebSocketState>.broadcast();
  Stream<WebSocketState> get stateStream => _stateController.stream;

  /// 音频发送计数
  int _audioChunkCount = 0;

  /// TTS请求ID计数
  int _ttsRequestId = 0;

  /// 回调
  void Function(ASRResult result)? onASRResult;
  void Function(Uint8List audio, int requestId)? onTTSAudio;
  void Function(int requestId)? onTTSComplete;
  VoidCallback? onSessionReady;
  void Function(String reason)? onSessionClosed;
  void Function(String code, String message)? onError;

  VoiceWebSocketClient({
    required this.serverUrl,
    this.userId = 'user',
    VoiceWebSocketConfig? config,
  }) : config = config ?? const VoiceWebSocketConfig();

  /// 当前状态
  WebSocketState get state => _state;

  /// 是否已连接
  bool get isConnected => _state == WebSocketState.connected;

  /// 连接到服务器
  Future<void> connect() async {
    if (_state == WebSocketState.connecting || _state == WebSocketState.connected) {
      debugPrint('[VoiceWebSocket] 已连接或正在连接中');
      return;
    }

    _setState(WebSocketState.connecting);
    _audioChunkCount = 0;

    try {
      debugPrint('[VoiceWebSocket] 连接到 $serverUrl');

      _channel = WebSocketChannel.connect(
        Uri.parse(serverUrl),
        protocols: ['voice-proxy-v1'],
      );

      // 监听消息
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('[VoiceWebSocket] 连接错误: $error');
          _setState(WebSocketState.error);
          onError?.call('connection_error', error.toString());
        },
        onDone: () {
          debugPrint('[VoiceWebSocket] 连接关闭');
          if (_state != WebSocketState.disconnected) {
            _setState(WebSocketState.disconnected);
          }
        },
      );

      // 发送会话开始消息
      _sendMessage(VoiceMessageType.sessionStart, {
        'user_id': userId,
        'audio_format': {
          'sample_rate': config.sampleRate,
          'channels': config.channels,
          'encoding': config.encoding,
        },
      });

    } catch (e) {
      debugPrint('[VoiceWebSocket] 连接失败: $e');
      _setState(WebSocketState.error);
      onError?.call('connection_failed', e.toString());
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    if (_state == WebSocketState.disconnected) return;

    debugPrint('[VoiceWebSocket] 断开连接');

    // 发送会话结束消息
    if (_state == WebSocketState.connected) {
      _sendMessage(VoiceMessageType.sessionEnd, {});
    }

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _setState(WebSocketState.disconnected);
  }

  /// 发送音频数据
  void sendAudio(Uint8List audioData) {
    if (!isConnected) return;

    _audioChunkCount++;
    if (_audioChunkCount == 1 || _audioChunkCount % 100 == 0) {
      debugPrint('[VoiceWebSocket] 发送音频块 #$_audioChunkCount (${audioData.length} bytes)');
    }

    _sendMessage(VoiceMessageType.audioChunk, {
      'data': base64Encode(audioData),
      'sequence': _audioChunkCount,
    });
  }

  /// 请求TTS合成
  ///
  /// 返回请求ID，用于匹配响应
  int requestTTS(String text, {TTSVoiceParams? voiceParams}) {
    if (!isConnected) {
      throw StateError('WebSocket未连接');
    }

    _ttsRequestId++;
    final request = TTSRequest(
      text: text,
      requestId: _ttsRequestId,
      voiceParams: voiceParams,
    );

    debugPrint('[VoiceWebSocket] TTS请求 #$_ttsRequestId: ${text.length}字');

    _sendMessage(VoiceMessageType.ttsRequest, request.toJson());

    return _ttsRequestId;
  }

  /// 发送打断信号
  void sendInterrupt() {
    if (!isConnected) return;

    debugPrint('[VoiceWebSocket] 发送打断信号');
    _sendMessage(VoiceMessageType.interrupt, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 处理服务器消息
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> json;

      if (message is String) {
        json = jsonDecode(message);
      } else {
        debugPrint('[VoiceWebSocket] 未知消息类型: ${message.runtimeType}');
        return;
      }

      final typeStr = json['type'] as String?;
      if (typeStr == null) return;

      final type = VoiceMessageTypeExtension.fromValue(typeStr);
      if (type == null) {
        debugPrint('[VoiceWebSocket] 未知消息类型: $typeStr');
        return;
      }

      switch (type) {
        case VoiceMessageType.sessionReady:
          debugPrint('[VoiceWebSocket] 会话就绪');
          _setState(WebSocketState.connected);
          onSessionReady?.call();
          break;

        case VoiceMessageType.asrIntermediate:
          final result = ASRResult.fromJson(json);
          debugPrint('[VoiceWebSocket] ASR中间结果: ${result.text}');
          onASRResult?.call(result);
          break;

        case VoiceMessageType.asrFinal:
          final result = ASRResult.fromJson(json);
          debugPrint('[VoiceWebSocket] ASR最终结果: ${result.text}');
          onASRResult?.call(result);
          break;

        case VoiceMessageType.ttsAudio:
          final data = json['data'] as String?;
          final requestId = json['request_id'] as int? ?? 0;
          if (data != null) {
            final audioData = base64Decode(data);
            onTTSAudio?.call(Uint8List.fromList(audioData), requestId);
          }
          break;

        case VoiceMessageType.ttsComplete:
          final requestId = json['request_id'] as int? ?? 0;
          debugPrint('[VoiceWebSocket] TTS完成 #$requestId');
          onTTSComplete?.call(requestId);
          break;

        case VoiceMessageType.sessionClosed:
          final reason = json['reason'] as String? ?? 'unknown';
          debugPrint('[VoiceWebSocket] 会话关闭: $reason');
          _setState(WebSocketState.disconnected);
          onSessionClosed?.call(reason);
          break;

        case VoiceMessageType.error:
          final code = json['code'] as String? ?? 'unknown';
          final errorMessage = json['message'] as String? ?? '';
          debugPrint('[VoiceWebSocket] 错误: $code - $errorMessage');
          onError?.call(code, errorMessage);
          break;

        default:
          debugPrint('[VoiceWebSocket] 忽略客户端消息类型: $type');
      }
    } catch (e) {
      debugPrint('[VoiceWebSocket] 消息解析错误: $e');
    }
  }

  /// 发送消息
  void _sendMessage(VoiceMessageType type, Map<String, dynamic> data) {
    if (_channel == null) return;

    try {
      final message = {
        'type': type.value,
        ...data,
      };
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[VoiceWebSocket] 发送消息失败: $e');
    }
  }

  /// 设置状态
  void _setState(WebSocketState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(_state);
    debugPrint('[VoiceWebSocket] 状态变更: $newState');
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _stateController.close();
  }
}

/// WebSocket配置
class VoiceWebSocketConfig {
  /// 采样率
  final int sampleRate;

  /// 声道数
  final int channels;

  /// 编码格式
  final String encoding;

  /// 重连间隔（毫秒）
  final int reconnectIntervalMs;

  /// 最大重连次数
  final int maxReconnectAttempts;

  const VoiceWebSocketConfig({
    this.sampleRate = 16000,
    this.channels = 1,
    this.encoding = 'pcm_s16le',
    this.reconnectIntervalMs = 1000,
    this.maxReconnectAttempts = 3,
  });
}
