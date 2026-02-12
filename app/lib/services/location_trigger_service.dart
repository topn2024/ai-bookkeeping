import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 位置触发点
class LocationTrigger {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // 触发半径（米）
  final String? category; // 关联的分类
  final bool enabled;

  LocationTrigger({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 100,
    this.category,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'category': category,
        'enabled': enabled,
      };

  factory LocationTrigger.fromJson(Map<String, dynamic> json) =>
      LocationTrigger(
        id: json['id'],
        name: json['name'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        radius: json['radius'] ?? 100,
        category: json['category'],
        enabled: json['enabled'] ?? true,
      );
}

/// 位置触发事件
class LocationTriggerEvent {
  final LocationTrigger trigger;
  final DateTime timestamp;
  final Position position;

  LocationTriggerEvent({
    required this.trigger,
    required this.timestamp,
    required this.position,
  });
}

/// 位置触发服务
class LocationTriggerService {
  static final LocationTriggerService _instance =
      LocationTriggerService._internal();
  factory LocationTriggerService() => _instance;
  LocationTriggerService._internal();

  final StreamController<LocationTriggerEvent> _eventController =
      StreamController<LocationTriggerEvent>.broadcast();
  Stream<LocationTriggerEvent> get onLocationTriggered =>
      _eventController.stream;

  static const String _storageKey = 'location_triggers';

  final List<LocationTrigger> _triggers = [];
  bool _isMonitoring = false;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  /// 初始化
  Future<void> initialize() async {
    // 加载保存的触发点
    await _loadTriggers();
  }

  /// 加载触发点
  Future<void> _loadTriggers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _triggers.addAll(list.map((e) => LocationTrigger.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      debugPrint('Failed to load location triggers: $e');
    }
  }

  /// 保存触发点
  Future<void> _saveTriggers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_triggers.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('Failed to save location triggers: $e');
    }
  }

  /// 开始监听
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    try {
      // 检查权限
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          debugPrint('Location permission denied');
          return;
        }
      }

      // 开始监听位置变化
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10, // 每移动10米更新一次
        ),
      ).listen(_onPositionChanged);

      debugPrint('Location trigger monitoring started');
    } catch (e) {
      debugPrint('Location service not available: $e');
    }
  }

  /// 停止监听
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMonitoring = false;
    debugPrint('Location trigger monitoring stopped');
  }

  /// 位置变化处理
  void _onPositionChanged(Position position) {
    _lastPosition = position;

    // 检查是否进入任何触发点范围
    for (final trigger in _triggers) {
      if (!trigger.enabled) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        trigger.latitude,
        trigger.longitude,
      );

      if (distance <= trigger.radius) {
        _eventController.add(LocationTriggerEvent(
          trigger: trigger,
          timestamp: DateTime.now(),
          position: position,
        ));
      }
    }
  }

  /// 添加触发点
  Future<void> addTrigger(LocationTrigger trigger) async {
    _triggers.add(trigger);
    await _saveTriggers();
  }

  /// 删除触发点
  Future<void> removeTrigger(String id) async {
    _triggers.removeWhere((t) => t.id == id);
    await _saveTriggers();
  }

  /// 获取所有触发点
  List<LocationTrigger> get triggers => List.unmodifiable(_triggers);

  /// 是否正在监听
  bool get isMonitoring => _isMonitoring;

  /// 当前位置
  Position? get lastPosition => _lastPosition;

  void dispose() {
    _positionSubscription?.cancel();
    _eventController.close();
  }
}
