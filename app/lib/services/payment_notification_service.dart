import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 支付通知事件
class PaymentNotificationEvent {
  final String app; // 微信、支付宝等
  final double amount;
  final String? merchant;
  final DateTime timestamp;

  PaymentNotificationEvent({
    required this.app,
    required this.amount,
    this.merchant,
    required this.timestamp,
  });
}

/// 支付通知监听服务
class PaymentNotificationService {
  static final PaymentNotificationService _instance =
      PaymentNotificationService._internal();
  factory PaymentNotificationService() => _instance;
  PaymentNotificationService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.bookkeeping.ai/payment_notification');

  final StreamController<PaymentNotificationEvent> _eventController =
      StreamController<PaymentNotificationEvent>.broadcast();
  Stream<PaymentNotificationEvent> get onPaymentDetected =>
      _eventController.stream;

  bool _isMonitoring = false;

  /// 初始化
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
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
    _eventController.close();
  }
}
