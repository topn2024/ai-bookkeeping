import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// 场景类型
enum SceneType {
  paymentNotification,  // 支付通知
  locationBased,        // 位置触发
  timeRoutine,          // 时间规律
  activityDetection,    // 活动检测
}

/// 场景触发事件
class SceneTriggerEvent {
  final SceneType sceneType;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  SceneTriggerEvent({
    required this.sceneType,
    required this.timestamp,
    required this.data,
  });
}

/// 场景感知智能唤醒服务
class SceneAwareWakeUpService {
  static final SceneAwareWakeUpService _instance = SceneAwareWakeUpService._internal();
  factory SceneAwareWakeUpService() => _instance;
  SceneAwareWakeUpService._internal();

  /// 场景触发事件流
  final StreamController<SceneTriggerEvent> _triggerController =
      StreamController<SceneTriggerEvent>.broadcast();
  Stream<SceneTriggerEvent> get onSceneTrigger => _triggerController.stream;

  /// 常去地点记录
  final Map<String, LocationRecord> _frequentLocations = {};

  /// 最近支付记录（用于去重）
  final Set<String> _recentPayments = {};

  /// 初始化
  Future<void> initialize() async {
    debugPrint('SceneAwareWakeUpService initialized');
    // TODO: 加载常去地点数据
  }

  /// 处理支付通知
  void handlePaymentNotification({
    required double amount,
    required String merchant,
    String? transactionId,
  }) {
    // 去重检查
    if (transactionId != null && _recentPayments.contains(transactionId)) {
      return;
    }

    // 智能过滤
    if (_shouldFilterPayment(amount, merchant)) {
      return;
    }

    // 记录并触发
    if (transactionId != null) {
      _recentPayments.add(transactionId);
      // 5分钟后清除
      Future.delayed(const Duration(minutes: 5), () {
        _recentPayments.remove(transactionId);
      });
    }

    _triggerController.add(SceneTriggerEvent(
      sceneType: SceneType.paymentNotification,
      timestamp: DateTime.now(),
      data: {
        'amount': amount,
        'merchant': merchant,
      },
    ));
  }

  /// 处理位置变化
  Future<void> handleLocationChange(Position position) async {
    // 检查是否在常去地点附近
    for (var entry in _frequentLocations.entries) {
      final location = entry.value;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );

      // 在100米范围内
      if (distance < 100) {
        // 检查是否刚离开（停留时间>10分钟）
        if (location.lastVisit != null) {
          final stayDuration = DateTime.now().difference(location.lastVisit!);
          if (stayDuration.inMinutes > 10) {
            _triggerController.add(SceneTriggerEvent(
              sceneType: SceneType.locationBased,
              timestamp: DateTime.now(),
              data: {
                'locationName': location.name,
                'locationType': location.type,
                'stayDuration': stayDuration.inMinutes,
              },
            ));
          }
        }

        location.lastVisit = DateTime.now();
      }
    }
  }

  /// 智能过滤支付通知
  bool _shouldFilterPayment(double amount, String merchant) {
    // 过滤红包/转账
    if (merchant.contains('红包') || merchant.contains('转账')) {
      return true;
    }

    // 过滤小额支付（<1元）
    if (amount < 1.0) {
      return true;
    }

    return false;
  }

  /// 添加常去地点
  void addFrequentLocation({
    required String name,
    required String type,
    required double latitude,
    required double longitude,
  }) {
    _frequentLocations[name] = LocationRecord(
      name: name,
      type: type,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void dispose() {
    _triggerController.close();
  }
}

/// 位置记录
class LocationRecord {
  final String name;
  final String type; // 'cafe', 'supermarket', 'restaurant', etc.
  final double latitude;
  final double longitude;
  DateTime? lastVisit;

  LocationRecord({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.lastVisit,
  });
}
