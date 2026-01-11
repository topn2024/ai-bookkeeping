import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 支付通知事件
class PaymentNotificationEvent {
  final String app; // 微信、支付宝等
  final double amount;
  final String? merchant;
  final DateTime timestamp;
  final String? title;
  final String? text;

  PaymentNotificationEvent({
    required this.app,
    required this.amount,
    this.merchant,
    required this.timestamp,
    this.title,
    this.text,
  });

  factory PaymentNotificationEvent.fromJson(Map<String, dynamic> json) {
    return PaymentNotificationEvent(
      app: json['appName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchant: json['merchant'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      title: json['title'] as String?,
      text: json['text'] as String?,
    );
  }

  @override
  String toString() => 'PaymentNotificationEvent(app: $app, amount: $amount, merchant: $merchant)';
}

/// 支付通知监听服务
class PaymentNotificationService {
  static final PaymentNotificationService _instance =
      PaymentNotificationService._internal();
  factory PaymentNotificationService() => _instance;
  PaymentNotificationService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.bookkeeping.ai/payment_notification');
  static const EventChannel _eventChannel =
      EventChannel('com.bookkeeping.ai/payment_notification_events');

  final StreamController<PaymentNotificationEvent> _eventController =
      StreamController<PaymentNotificationEvent>.broadcast();
  Stream<PaymentNotificationEvent> get onPaymentDetected =>
      _eventController.stream;

  StreamSubscription? _eventSubscription;
  bool _isMonitoring = false;
  bool _initialized = false;

  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 方式1: MethodChannel 回调
    _channel.setMethodCallHandler(_handleMethodCall);

    // 方式2: EventChannel 流式监听 (来自 NotificationListenerService)
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is String) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final event = PaymentNotificationEvent.fromJson(json);
            debugPrint('PaymentNotificationService: Detected via event: $event');
            _eventController.add(event);
          } catch (e) {
            debugPrint('PaymentNotificationService: Error parsing event data: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('PaymentNotificationService: EventChannel error: $error');
      },
    );

    debugPrint('PaymentNotificationService initialized');
  }

  /// 处理原生调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPaymentDetected':
        final data = call.arguments as Map;
        _eventController.add(PaymentNotificationEvent(
          app: data['app'] as String,
          amount: (data['amount'] as num).toDouble(),
          merchant: data['merchant'] as String?,
          timestamp: DateTime.now(),
        ));
        break;
    }
  }

  /// 开始监听
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    try {
      // 请求通知权限
      final hasPermission =
          await _channel.invokeMethod<bool>('requestNotificationPermission') ??
              false;

      if (!hasPermission) {
        debugPrint('Notification permission denied (native not implemented)');
        return;
      }

      await _channel.invokeMethod('startMonitoring');
      debugPrint('Payment notification monitoring started');
    } catch (e) {
      debugPrint('Payment notification native implementation not available: $e');
    }
  }

  /// 停止监听
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    try {
      await _channel.invokeMethod('stopMonitoring');
      debugPrint('Payment notification monitoring stopped');
    } catch (e) {
      debugPrint('Payment notification native implementation not available: $e');
    }
  }

  /// 是否正在监听
  bool get isMonitoring => _isMonitoring;

  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
    _initialized = false;
  }
}
