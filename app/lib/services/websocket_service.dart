import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'circuit_breaker.dart';

/// WebSocket连接状态
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// WebSocket消息
class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? messageId;

  const WebSocketMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.messageId,
  }) : timestamp = timestamp ?? const _Now();

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      messageId: json['messageId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        if (messageId != null) 'messageId': messageId,
      };
}

class _Now implements DateTime {
  const _Now();

  DateTime get _now => DateTime.now();

  @override
  int get year => _now.year;
  @override
  int get month => _now.month;
  @override
  int get day => _now.day;
  @override
  int get hour => _now.hour;
  @override
  int get minute => _now.minute;
  @override
  int get second => _now.second;
  @override
  int get millisecond => _now.millisecond;
  @override
  int get microsecond => _now.microsecond;
  @override
  int get weekday => _now.weekday;
  @override
  bool get isUtc => _now.isUtc;
  @override
  int get millisecondsSinceEpoch => _now.millisecondsSinceEpoch;
  @override
  int get microsecondsSinceEpoch => _now.microsecondsSinceEpoch;
  @override
  String get timeZoneName => _now.timeZoneName;
  @override
  Duration get timeZoneOffset => _now.timeZoneOffset;

  @override
  DateTime add(Duration duration) => _now.add(duration);
  @override
  DateTime subtract(Duration duration) => _now.subtract(duration);
  @override
  bool isAfter(DateTime other) => _now.isAfter(other);
  @override
  bool isBefore(DateTime other) => _now.isBefore(other);
  @override
  bool isAtSameMomentAs(DateTime other) => _now.isAtSameMomentAs(other);
  @override
  int compareTo(DateTime other) => _now.compareTo(other);
  @override
  Duration difference(DateTime other) => _now.difference(other);
  @override
  DateTime toLocal() => _now.toLocal();
  @override
  DateTime toUtc() => _now.toUtc();
  @override
  String toIso8601String() => _now.toIso8601String();
  @override
  String toString() => _now.toString();
  @override
  int get hashCode => _now.hashCode;
  @override
  bool operator ==(Object other) => _now == other;
}

/// 同步消息类型
class SyncMessageType {
  static const String transactionCreated = 'transaction.created';
  static const String transactionUpdated = 'transaction.updated';
  static const String transactionDeleted = 'transaction.deleted';
  static const String memberJoined = 'member.joined';
  static const String memberLeft = 'member.left';
  static const String budgetUpdated = 'budget.updated';
  static const String vaultUpdated = 'vault.updated';
  static const String syncRequest = 'sync.request';
  static const String syncResponse = 'sync.response';
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String ack = 'ack';
  static const String error = 'error';
}

/// WebSocket配置
class WebSocketConfig {
  final String baseUrl;
  final Duration reconnectDelay;
  final Duration maxReconnectDelay;
  final int maxReconnectAttempts;
  final Duration pingInterval;
  final Duration pongTimeout;
  final Map<String, String>? headers;

  const WebSocketConfig({
    required this.baseUrl,
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.maxReconnectAttempts = 10,
    this.pingInterval = const Duration(seconds: 30),
    this.pongTimeout = const Duration(seconds: 10),
    this.headers,
  });
}

/// WebSocket实时同步服务
///
/// 提供WebSocket连接管理、消息收发、自动重连等功能
class WebSocketService {
  final WebSocketConfig config;
  final CircuitBreaker _circuitBreaker;

  WebSocket? _socket;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _pingTimer;
  Timer? _pongTimer;
  Timer? _reconnectTimer;
  String? _currentPath;
  String? _authToken;

  final StreamController<WebSocketMessage> _messageController =
      StreamController.broadcast();
  final StreamController<WebSocketConnectionState> _stateController =
      StreamController.broadcast();
  final Map<String, Completer<WebSocketMessage>> _pendingRequests = {};
  final List<WebSocketMessage> _messageQueue = [];

  WebSocketService({
    required this.config,
    CircuitBreaker? circuitBreaker,
  }) : _circuitBreaker = circuitBreaker ??
            CircuitBreaker(
              serviceName: 'websocket',
              failureThreshold: 3,
              resetTimeout: const Duration(minutes: 2),
            );

  /// 获取当前连接状态
  WebSocketConnectionState get state => _state;

  /// 是否已连接
  bool get isConnected => _state == WebSocketConnectionState.connected;

  /// 消息流
  Stream<WebSocketMessage> get onMessage => _messageController.stream;

  /// 状态变更流
  Stream<WebSocketConnectionState> get onStateChange => _stateController.stream;

  /// 设置认证Token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// 连接WebSocket
  Future<void> connect(String path) async {
    if (_state == WebSocketConnectionState.connected &&
        _currentPath == path) {
      return;
    }

    _currentPath = path;
    _updateState(WebSocketConnectionState.connecting);

    try {
      await _circuitBreaker.execute(() async {
        await _doConnect(path);
      });
    } on CircuitBreakerOpenException {
      _updateState(WebSocketConnectionState.disconnected);
      rethrow;
    } catch (e) {
      _updateState(WebSocketConnectionState.disconnected);
      _scheduleReconnect();
      rethrow;
    }
  }

  Future<void> _doConnect(String path) async {
    final uri = Uri.parse('${config.baseUrl}$path');
    final headers = <String, String>{
      ...?config.headers,
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };

    _socket = await WebSocket.connect(
      uri.toString(),
      headers: headers,
    );

    _reconnectAttempts = 0;
    _updateState(WebSocketConnectionState.connected);
    _startPingTimer();
    _flushMessageQueue();

    _socket!.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
      cancelOnError: false,
    );
  }

  /// 断开连接
  Future<void> disconnect() async {
    _cancelTimers();
    _reconnectAttempts = _reconnectAttempts; // 保持计数器，防止意外重连
    await _socket?.close();
    _socket = null;
    _currentPath = null;
    _updateState(WebSocketConnectionState.disconnected);
  }

  /// 发送消息
  Future<void> send(WebSocketMessage message) async {
    if (_state != WebSocketConnectionState.connected) {
      // 离线时加入队列
      _messageQueue.add(message);
      return;
    }

    try {
      _socket?.add(jsonEncode(message.toJson()));
    } catch (e) {
      _messageQueue.add(message);
      _handleError(e);
    }
  }

  /// 发送请求并等待响应
  Future<WebSocketMessage> sendRequest(
    WebSocketMessage message, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final messageId =
        message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final messageWithId = WebSocketMessage(
      type: message.type,
      data: message.data,
      timestamp: message.timestamp,
      messageId: messageId,
    );

    final completer = Completer<WebSocketMessage>();
    _pendingRequests[messageId] = completer;

    try {
      await send(messageWithId);
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pendingRequests.remove(messageId);
      rethrow;
    }
  }

  /// 监听特定类型的消息
  Stream<WebSocketMessage> on(String type) {
    return onMessage.where((msg) => msg.type == type);
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = WebSocketMessage.fromJson(json);

      // 处理pong响应
      if (message.type == SyncMessageType.pong) {
        _pongTimer?.cancel();
        return;
      }

      // 处理等待中的请求响应
      if (message.messageId != null &&
          _pendingRequests.containsKey(message.messageId)) {
        _pendingRequests.remove(message.messageId)?.complete(message);
        return;
      }

      // 广播消息
      _messageController.add(message);
    } catch (e) {
      // 解析失败的消息忽略
    }
  }

  void _handleError(dynamic error) {
    _scheduleReconnect();
  }

  void _handleDone() {
    _cancelTimers();
    if (_currentPath != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      _updateState(WebSocketConnectionState.disconnected);
      return;
    }

    _updateState(WebSocketConnectionState.reconnecting);

    // 指数退避
    final delay = Duration(
      milliseconds: (config.reconnectDelay.inMilliseconds *
              (1 << _reconnectAttempts))
          .clamp(0, config.maxReconnectDelay.inMilliseconds),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      if (_currentPath != null) {
        try {
          await _doConnect(_currentPath!);
        } catch (_) {
          _scheduleReconnect();
        }
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(config.pingInterval, (_) {
      _sendPing();
    });
  }

  void _sendPing() {
    if (_state != WebSocketConnectionState.connected) return;

    try {
      _socket?.add(jsonEncode({
        'type': SyncMessageType.ping,
        'timestamp': DateTime.now().toIso8601String(),
      }));

      _pongTimer?.cancel();
      _pongTimer = Timer(config.pongTimeout, () {
        // Pong超时，认为连接已断开
        _socket?.close();
      });
    } catch (_) {
      // 发送失败忽略
    }
  }

  void _flushMessageQueue() {
    while (_messageQueue.isNotEmpty && isConnected) {
      final message = _messageQueue.removeAt(0);
      send(message);
    }
  }

  void _cancelTimers() {
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _reconnectTimer?.cancel();
    _pingTimer = null;
    _pongTimer = null;
    _reconnectTimer = null;
  }

  void _updateState(WebSocketConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// 释放资源
  void dispose() {
    _cancelTimers();
    _socket?.close();
    _messageController.close();
    _stateController.close();
    _pendingRequests.clear();
    _messageQueue.clear();
  }
}

/// 同步事件
class SyncEvent {
  final SyncEventType type;
  final WebSocketMessage? message;
  final ConflictInfo? conflict;

  const SyncEvent({
    required this.type,
    this.message,
    this.conflict,
  });
}

/// 同步事件类型
enum SyncEventType {
  connected,
  disconnected,
  remoteChange,
  localChangePushed,
  conflictDetected,
  syncCompleted,
  error,
}

/// 冲突信息
class ConflictInfo {
  final dynamic local;
  final dynamic remote;

  const ConflictInfo({
    required this.local,
    required this.remote,
  });
}

/// 本地变更
class LocalChange {
  final String type;
  final Map<String, dynamic> data;
  final String? ledgerId;

  const LocalChange({
    required this.type,
    required this.data,
    this.ledgerId,
  });
}
