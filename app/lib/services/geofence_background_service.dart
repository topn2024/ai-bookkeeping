import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 地理围栏后台触发服务
///
/// 功能：
/// 1. 系统级地理围栏注册（Android WorkManager / iOS Background Task）
/// 2. 进入/离开围栏事件触发
/// 3. 围栏持久化管理
/// 4. 电量优化策略
class GeofenceBackgroundService {
  final GeofenceNativeChannel _nativeChannel;
  final GeofenceStorage _storage;
  final GeofenceEventHandler _eventHandler;

  final Map<String, Geofence> _activeGeofences = {};
  final _eventController = StreamController<GeofenceEvent>.broadcast();

  bool _isInitialized = false;

  GeofenceBackgroundService({
    required GeofenceNativeChannel nativeChannel,
    required GeofenceStorage storage,
    required GeofenceEventHandler eventHandler,
  })  : _nativeChannel = nativeChannel,
        _storage = storage,
        _eventHandler = eventHandler;

  /// 地理围栏事件流
  Stream<GeofenceEvent> get eventStream => _eventController.stream;

  /// 获取所有活跃围栏
  List<Geofence> get activeGeofences => _activeGeofences.values.toList();

  /// 初始���服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 检查权限
      final permission = await _nativeChannel.checkBackgroundLocationPermission();
      if (permission != BackgroundLocationPermission.granted) {
        debugPrint('Background location permission not granted');
        return;
      }

      // 加载已保存的围栏
      final savedGeofences = await _storage.loadGeofences();
      for (final geofence in savedGeofences) {
        _activeGeofences[geofence.id] = geofence;
      }

      // 注册原生事件监听
      _nativeChannel.setEventCallback(_handleNativeEvent);

      // 重新注册所有围栏到系统
      await _registerAllGeofencesToSystem();

      _isInitialized = true;
      debugPrint('GeofenceBackgroundService initialized with '
          '${_activeGeofences.length} geofences');
    } catch (e) {
      debugPrint('Failed to initialize GeofenceBackgroundService: $e');
      rethrow;
    }
  }

  /// 请求后台位置权限
  Future<BackgroundLocationPermission> requestBackgroundPermission() async {
    return await _nativeChannel.requestBackgroundLocationPermission();
  }

  /// 注册地理围栏
  Future<GeofenceRegistrationResult> registerGeofence(Geofence geofence) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 验证围栏参数
      final validation = _validateGeofence(geofence);
      if (!validation.isValid) {
        return GeofenceRegistrationResult(
          success: false,
          error: validation.error,
        );
      }

      // 检查围栏数量限制
      if (_activeGeofences.length >= 100) {
        return GeofenceRegistrationResult(
          success: false,
          error: '围栏数量已达���限(100个)',
        );
      }

      // 注册到系统
      final success = await _nativeChannel.registerGeofence(
        id: geofence.id,
        latitude: geofence.center.latitude,
        longitude: geofence.center.longitude,
        radius: geofence.radius,
        transitionTypes: geofence.transitionTypes,
        expirationDuration: geofence.expirationDuration?.inMilliseconds,
        loiteringDelay: geofence.loiteringDelay?.inMilliseconds,
        notificationResponsiveness: geofence.responsiveness.inMilliseconds,
      );

      if (!success) {
        return GeofenceRegistrationResult(
          success: false,
          error: '系统注册失败',
        );
      }

      // 保存到本地
      _activeGeofences[geofence.id] = geofence;
      await _storage.saveGeofences(_activeGeofences.values.toList());

      debugPrint('Registered geofence: ${geofence.id} at '
          '(${geofence.center.latitude}, ${geofence.center.longitude})');

      return GeofenceRegistrationResult(
        success: true,
        geofenceId: geofence.id,
      );
    } catch (e) {
      debugPrint('Failed to register geofence: $e');
      return GeofenceRegistrationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 批量注册围栏
  Future<List<GeofenceRegistrationResult>> registerGeofences(
    List<Geofence> geofences,
  ) async {
    final results = <GeofenceRegistrationResult>[];
    for (final geofence in geofences) {
      results.add(await registerGeofence(geofence));
    }
    return results;
  }

  /// 移除地理围栏
  Future<bool> removeGeofence(String geofenceId) async {
    try {
      await _nativeChannel.removeGeofence(geofenceId);
      _activeGeofences.remove(geofenceId);
      await _storage.saveGeofences(_activeGeofences.values.toList());
      debugPrint('Removed geofence: $geofenceId');
      return true;
    } catch (e) {
      debugPrint('Failed to remove geofence: $e');
      return false;
    }
  }

  /// 移除所有围栏
  Future<void> removeAllGeofences() async {
    try {
      await _nativeChannel.removeAllGeofences();
      _activeGeofences.clear();
      await _storage.saveGeofences([]);
      debugPrint('Removed all geofences');
    } catch (e) {
      debugPrint('Failed to remove all geofences: $e');
    }
  }

  /// 更新围栏
  Future<bool> updateGeofence(Geofence geofence) async {
    // 先移除再注册
    await removeGeofence(geofence.id);
    final result = await registerGeofence(geofence);
    return result.success;
  }

  /// 注册商家围栏（用于智能记账）
  Future<GeofenceRegistrationResult> registerMerchantGeofence({
    required String merchantId,
    required String merchantName,
    required double latitude,
    required double longitude,
    double radius = 100, // 默认100米
    String? defaultCategory,
  }) async {
    final geofence = Geofence(
      id: 'merchant_$merchantId',
      name: merchantName,
      center: GeofenceCenter(latitude: latitude, longitude: longitude),
      radius: radius,
      transitionTypes: [GeofenceTransition.enter],
      metadata: {
        'type': 'merchant',
        'merchantId': merchantId,
        'merchantName': merchantName,
        'defaultCategory': defaultCategory,
      },
    );

    return await registerGeofence(geofence);
  }

  /// 注册预算提醒围栏
  Future<GeofenceRegistrationResult> registerBudgetReminderGeofence({
    required String locationId,
    required String locationName,
    required double latitude,
    required double longitude,
    required String category,
    double radius = 200,
  }) async {
    final geofence = Geofence(
      id: 'budget_$locationId',
      name: '预算提醒: $locationName',
      center: GeofenceCenter(latitude: latitude, longitude: longitude),
      radius: radius,
      transitionTypes: [GeofenceTransition.enter],
      metadata: {
        'type': 'budget_reminder',
        'locationName': locationName,
        'category': category,
      },
    );

    return await registerGeofence(geofence);
  }

  /// 注册家/公司围栏
  Future<GeofenceRegistrationResult> registerHomeWorkGeofence({
    required GeofenceLocationType type,
    required double latitude,
    required double longitude,
    double radius = 300,
  }) async {
    final geofence = Geofence(
      id: type.name,
      name: type == GeofenceLocationType.home ? '家' : '公司',
      center: GeofenceCenter(latitude: latitude, longitude: longitude),
      radius: radius,
      transitionTypes: [
        GeofenceTransition.enter,
        GeofenceTransition.exit,
      ],
      metadata: {
        'type': type.name,
      },
    );

    return await registerGeofence(geofence);
  }

  /// 处理原生事件
  void _handleNativeEvent(Map<String, dynamic> eventData) {
    try {
      final geofenceId = eventData['geofenceId'] as String;
      final transitionType = _parseTransitionType(eventData['transition'] as int);
      final latitude = eventData['latitude'] as double?;
      final longitude = eventData['longitude'] as double?;

      final geofence = _activeGeofences[geofenceId];
      if (geofence == null) {
        debugPrint('Received event for unknown geofence: $geofenceId');
        return;
      }

      final event = GeofenceEvent(
        geofence: geofence,
        transition: transitionType,
        timestamp: DateTime.now(),
        triggerLocation: latitude != null && longitude != null
            ? GeofenceCenter(latitude: latitude, longitude: longitude)
            : null,
      );

      _eventController.add(event);
      _eventHandler.handleEvent(event);

      debugPrint('Geofence event: ${geofence.name} - ${transitionType.name}');
    } catch (e) {
      debugPrint('Failed to handle native geofence event: $e');
    }
  }

  GeofenceTransition _parseTransitionType(int transition) {
    switch (transition) {
      case 1:
        return GeofenceTransition.enter;
      case 2:
        return GeofenceTransition.exit;
      case 4:
        return GeofenceTransition.dwell;
      default:
        return GeofenceTransition.enter;
    }
  }

  /// 验证围栏参数
  GeofenceValidation _validateGeofence(Geofence geofence) {
    if (geofence.radius < 50) {
      return GeofenceValidation(
        isValid: false,
        error: '围栏半径不能小于50米',
      );
    }

    if (geofence.radius > 10000) {
      return GeofenceValidation(
        isValid: false,
        error: '围栏半径不能大于10公里',
      );
    }

    if (geofence.center.latitude < -90 || geofence.center.latitude > 90) {
      return GeofenceValidation(
        isValid: false,
        error: '纬度范围无效',
      );
    }

    if (geofence.center.longitude < -180 || geofence.center.longitude > 180) {
      return GeofenceValidation(
        isValid: false,
        error: '经度范围无效',
      );
    }

    return GeofenceValidation(isValid: true);
  }

  /// 重新注册所有围栏到系统
  Future<void> _registerAllGeofencesToSystem() async {
    for (final geofence in _activeGeofences.values) {
      try {
        await _nativeChannel.registerGeofence(
          id: geofence.id,
          latitude: geofence.center.latitude,
          longitude: geofence.center.longitude,
          radius: geofence.radius,
          transitionTypes: geofence.transitionTypes,
          expirationDuration: geofence.expirationDuration?.inMilliseconds,
          loiteringDelay: geofence.loiteringDelay?.inMilliseconds,
          notificationResponsiveness: geofence.responsiveness.inMilliseconds,
        );
      } catch (e) {
        debugPrint('Failed to re-register geofence ${geofence.id}: $e');
      }
    }
  }

  /// 获取围栏状态
  Future<GeofenceStatus?> getGeofenceStatus(String geofenceId) async {
    final geofence = _activeGeofences[geofenceId];
    if (geofence == null) return null;

    final isActive = await _nativeChannel.isGeofenceActive(geofenceId);
    return GeofenceStatus(
      geofence: geofence,
      isActive: isActive,
      registeredAt: geofence.createdAt,
    );
  }

  /// 释放资源
  void dispose() {
    _eventController.close();
  }
}

// ==================== 数据模型 ====================

/// 地理围栏
class Geofence {
  final String id;
  final String name;
  final GeofenceCenter center;
  final double radius; // 米
  final List<GeofenceTransition> transitionTypes;
  final Duration? expirationDuration;
  final Duration? loiteringDelay; // 停留触发延迟
  final Duration responsiveness;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  Geofence({
    required this.id,
    required this.name,
    required this.center,
    required this.radius,
    required this.transitionTypes,
    this.expirationDuration,
    this.loiteringDelay,
    this.responsiveness = const Duration(seconds: 5),
    this.metadata = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'center': center.toJson(),
        'radius': radius,
        'transitionTypes': transitionTypes.map((t) => t.name).toList(),
        'expirationDuration': expirationDuration?.inMilliseconds,
        'loiteringDelay': loiteringDelay?.inMilliseconds,
        'responsiveness': responsiveness.inMilliseconds,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as String,
      name: json['name'] as String,
      center: GeofenceCenter.fromJson(json['center'] as Map<String, dynamic>),
      radius: (json['radius'] as num).toDouble(),
      transitionTypes: (json['transitionTypes'] as List<dynamic>)
          .map((t) => GeofenceTransition.values.firstWhere(
                (e) => e.name == t,
                orElse: () => GeofenceTransition.enter,
              ))
          .toList(),
      expirationDuration: json['expirationDuration'] != null
          ? Duration(milliseconds: json['expirationDuration'] as int)
          : null,
      loiteringDelay: json['loiteringDelay'] != null
          ? Duration(milliseconds: json['loiteringDelay'] as int)
          : null,
      responsiveness: Duration(
        milliseconds: json['responsiveness'] as int? ?? 5000,
      ),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 围栏中心点
class GeofenceCenter {
  final double latitude;
  final double longitude;

  const GeofenceCenter({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory GeofenceCenter.fromJson(Map<String, dynamic> json) {
    return GeofenceCenter(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  double distanceTo(GeofenceCenter other) {
    const earthRadius = 6371000.0;
    final lat1 = latitude * pi / 180;
    final lat2 = other.latitude * pi / 180;
    final dLat = (other.latitude - latitude) * pi / 180;
    final dLon = (other.longitude - longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}

/// 围栏事件类型
enum GeofenceTransition {
  enter, // 进入
  exit, // 离开
  dwell, // 停留
}

/// 围栏事件
class GeofenceEvent {
  final Geofence geofence;
  final GeofenceTransition transition;
  final DateTime timestamp;
  final GeofenceCenter? triggerLocation;

  const GeofenceEvent({
    required this.geofence,
    required this.transition,
    required this.timestamp,
    this.triggerLocation,
  });
}

/// 围栏位置类型
enum GeofenceLocationType {
  home,
  work,
  merchant,
  custom,
}

/// 后台位置权限
enum BackgroundLocationPermission {
  granted,
  denied,
  restricted,
  notDetermined,
}

/// 围栏注册结果
class GeofenceRegistrationResult {
  final bool success;
  final String? geofenceId;
  final String? error;

  const GeofenceRegistrationResult({
    required this.success,
    this.geofenceId,
    this.error,
  });
}

/// 围栏验证结果
class GeofenceValidation {
  final bool isValid;
  final String? error;

  const GeofenceValidation({
    required this.isValid,
    this.error,
  });
}

/// 围栏状态
class GeofenceStatus {
  final Geofence geofence;
  final bool isActive;
  final DateTime registeredAt;

  const GeofenceStatus({
    required this.geofence,
    required this.isActive,
    required this.registeredAt,
  });
}

// ==================== 原生通道接口 ====================

/// 地理围栏原生通道接口
abstract class GeofenceNativeChannel {
  /// 检查后台位置权限
  Future<BackgroundLocationPermission> checkBackgroundLocationPermission();

  /// 请求后台位置权限
  Future<BackgroundLocationPermission> requestBackgroundLocationPermission();

  /// 注册围栏
  Future<bool> registerGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
    required List<GeofenceTransition> transitionTypes,
    int? expirationDuration,
    int? loiteringDelay,
    int? notificationResponsiveness,
  });

  /// 移除围栏
  Future<void> removeGeofence(String id);

  /// 移除所有围栏
  Future<void> removeAllGeofences();

  /// 检查围栏是否活跃
  Future<bool> isGeofenceActive(String id);

  /// 设置事件回调
  void setEventCallback(void Function(Map<String, dynamic>) callback);
}

/// 模拟原生通道实现（用于测试）
class MockGeofenceNativeChannel implements GeofenceNativeChannel {
  final Set<String> _registeredGeofences = {};
  void Function(Map<String, dynamic>)? _eventCallback;

  @override
  Future<BackgroundLocationPermission> checkBackgroundLocationPermission() async {
    return BackgroundLocationPermission.granted;
  }

  @override
  Future<BackgroundLocationPermission> requestBackgroundLocationPermission() async {
    return BackgroundLocationPermission.granted;
  }

  @override
  Future<bool> registerGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
    required List<GeofenceTransition> transitionTypes,
    int? expirationDuration,
    int? loiteringDelay,
    int? notificationResponsiveness,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _registeredGeofences.add(id);
    debugPrint('Mock: Registered geofence $id');
    return true;
  }

  @override
  Future<void> removeGeofence(String id) async {
    _registeredGeofences.remove(id);
    debugPrint('Mock: Removed geofence $id');
  }

  @override
  Future<void> removeAllGeofences() async {
    _registeredGeofences.clear();
    debugPrint('Mock: Removed all geofences');
  }

  @override
  Future<bool> isGeofenceActive(String id) async {
    return _registeredGeofences.contains(id);
  }

  @override
  void setEventCallback(void Function(Map<String, dynamic>) callback) {
    _eventCallback = callback;
  }

  /// 模拟触发围栏事件（用于测试）
  void simulateGeofenceEvent({
    required String geofenceId,
    required int transition, // 1=enter, 2=exit, 4=dwell
    double? latitude,
    double? longitude,
  }) {
    _eventCallback?.call({
      'geofenceId': geofenceId,
      'transition': transition,
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}

/// Flutter MethodChannel实现
class FlutterGeofenceNativeChannel implements GeofenceNativeChannel {
  // 实际实现需要使用 MethodChannel
  // static const MethodChannel _channel = MethodChannel('geofence_service');

  void Function(Map<String, dynamic>)? _eventCallback;

  @override
  Future<BackgroundLocationPermission> checkBackgroundLocationPermission() async {
    // 实际实现：
    // final result = await _channel.invokeMethod('checkBackgroundPermission');
    // return BackgroundLocationPermission.values[result];

    // 模拟实现
    return BackgroundLocationPermission.granted;
  }

  @override
  Future<BackgroundLocationPermission> requestBackgroundLocationPermission() async {
    // 实际实现：
    // final result = await _channel.invokeMethod('requestBackgroundPermission');
    // return BackgroundLocationPermission.values[result];

    return BackgroundLocationPermission.granted;
  }

  @override
  Future<bool> registerGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
    required List<GeofenceTransition> transitionTypes,
    int? expirationDuration,
    int? loiteringDelay,
    int? notificationResponsiveness,
  }) async {
    // 实际实现：
    // final result = await _channel.invokeMethod('registerGeofence', {
    //   'id': id,
    //   'latitude': latitude,
    //   'longitude': longitude,
    //   'radius': radius,
    //   'transitionTypes': transitionTypes.map((t) => t.index).toList(),
    //   'expirationDuration': expirationDuration,
    //   'loiteringDelay': loiteringDelay,
    //   'notificationResponsiveness': notificationResponsiveness,
    // });
    // return result as bool;

    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<void> removeGeofence(String id) async {
    // await _channel.invokeMethod('removeGeofence', {'id': id});
  }

  @override
  Future<void> removeAllGeofences() async {
    // await _channel.invokeMethod('removeAllGeofences');
  }

  @override
  Future<bool> isGeofenceActive(String id) async {
    // final result = await _channel.invokeMethod('isGeofenceActive', {'id': id});
    // return result as bool;
    return true;
  }

  @override
  void setEventCallback(void Function(Map<String, dynamic>) callback) {
    _eventCallback = callback;

    // 实际实现需要设置 EventChannel 监听
    // const EventChannel('geofence_events').receiveBroadcastStream()
    //     .listen((event) => callback(event as Map<String, dynamic>));
  }
}

// ==================== 存储接口 ====================

/// 地理围栏存储接口
abstract class GeofenceStorage {
  Future<void> saveGeofences(List<Geofence> geofences);
  Future<List<Geofence>> loadGeofences();
  Future<void> clear();
}

/// 内存存储实现（用于测试）
class InMemoryGeofenceStorage implements GeofenceStorage {
  final List<Geofence> _geofences = [];

  @override
  Future<void> saveGeofences(List<Geofence> geofences) async {
    _geofences.clear();
    _geofences.addAll(geofences);
  }

  @override
  Future<List<Geofence>> loadGeofences() async {
    return List.unmodifiable(_geofences);
  }

  @override
  Future<void> clear() async {
    _geofences.clear();
  }
}

/// SharedPreferences存储实现
class SharedPreferencesGeofenceStorage implements GeofenceStorage {
  static const String _key = 'geofences';
  final SharedPreferencesGeofenceWrapper _prefs;

  SharedPreferencesGeofenceStorage(this._prefs);

  @override
  Future<void> saveGeofences(List<Geofence> geofences) async {
    final json = jsonEncode(geofences.map((g) => g.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  @override
  Future<List<Geofence>> loadGeofences() async {
    final json = _prefs.getString(_key);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => Geofence.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load geofences: $e');
      return [];
    }
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

/// SharedPreferences包装器接口
abstract class SharedPreferencesGeofenceWrapper {
  String? getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

// ==================== 事件处理器 ====================

/// 地理围栏事件处理器
abstract class GeofenceEventHandler {
  void handleEvent(GeofenceEvent event);
}

/// 记账围栏事件处理器
class BookkeepingGeofenceEventHandler implements GeofenceEventHandler {
  final void Function(MerchantGeofenceEvent)? onMerchantEnter;
  final void Function(BudgetReminderGeofenceEvent)? onBudgetReminder;
  final void Function(HomeWorkGeofenceEvent)? onHomeWorkTransition;

  BookkeepingGeofenceEventHandler({
    this.onMerchantEnter,
    this.onBudgetReminder,
    this.onHomeWorkTransition,
  });

  @override
  void handleEvent(GeofenceEvent event) {
    final metadata = event.geofence.metadata;
    final type = metadata['type'] as String?;

    switch (type) {
      case 'merchant':
        if (event.transition == GeofenceTransition.enter) {
          onMerchantEnter?.call(MerchantGeofenceEvent(
            merchantId: metadata['merchantId'] as String,
            merchantName: metadata['merchantName'] as String,
            defaultCategory: metadata['defaultCategory'] as String?,
            timestamp: event.timestamp,
          ));
        }
        break;

      case 'budget_reminder':
        if (event.transition == GeofenceTransition.enter) {
          onBudgetReminder?.call(BudgetReminderGeofenceEvent(
            locationName: metadata['locationName'] as String,
            category: metadata['category'] as String,
            timestamp: event.timestamp,
          ));
        }
        break;

      case 'home':
      case 'work':
        onHomeWorkTransition?.call(HomeWorkGeofenceEvent(
          locationType: type == 'home'
              ? GeofenceLocationType.home
              : GeofenceLocationType.work,
          transition: event.transition,
          timestamp: event.timestamp,
        ));
        break;
    }
  }
}

/// 商家围栏事件
class MerchantGeofenceEvent {
  final String merchantId;
  final String merchantName;
  final String? defaultCategory;
  final DateTime timestamp;

  const MerchantGeofenceEvent({
    required this.merchantId,
    required this.merchantName,
    this.defaultCategory,
    required this.timestamp,
  });
}

/// 预算提醒围栏事件
class BudgetReminderGeofenceEvent {
  final String locationName;
  final String category;
  final DateTime timestamp;

  const BudgetReminderGeofenceEvent({
    required this.locationName,
    required this.category,
    required this.timestamp,
  });
}

/// 家/公司围栏事件
class HomeWorkGeofenceEvent {
  final GeofenceLocationType locationType;
  final GeofenceTransition transition;
  final DateTime timestamp;

  const HomeWorkGeofenceEvent({
    required this.locationType,
    required this.transition,
    required this.timestamp,
  });
}

// ==================== 管理器单例 ====================

/// 地理围栏管理器（单例）
class GeofenceManager {
  static GeofenceManager? _instance;

  final GeofenceBackgroundService _service;

  GeofenceManager._(this._service);

  static GeofenceManager get instance {
    if (_instance == null) {
      throw StateError('GeofenceManager not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  static Future<void> initialize({
    GeofenceNativeChannel? nativeChannel,
    GeofenceStorage? storage,
    GeofenceEventHandler? eventHandler,
  }) async {
    if (_instance != null) return;

    final service = GeofenceBackgroundService(
      nativeChannel: nativeChannel ?? FlutterGeofenceNativeChannel(),
      storage: storage ?? InMemoryGeofenceStorage(),
      eventHandler: eventHandler ?? BookkeepingGeofenceEventHandler(),
    );

    await service.initialize();
    _instance = GeofenceManager._(service);
  }

  GeofenceBackgroundService get service => _service;

  /// 便捷方法：注册商家围栏
  Future<GeofenceRegistrationResult> registerMerchant({
    required String merchantId,
    required String merchantName,
    required double latitude,
    required double longitude,
    String? defaultCategory,
  }) {
    return _service.registerMerchantGeofence(
      merchantId: merchantId,
      merchantName: merchantName,
      latitude: latitude,
      longitude: longitude,
      defaultCategory: defaultCategory,
    );
  }

  /// 便捷方法：注册预算提醒
  Future<GeofenceRegistrationResult> registerBudgetReminder({
    required String locationId,
    required String locationName,
    required double latitude,
    required double longitude,
    required String category,
  }) {
    return _service.registerBudgetReminderGeofence(
      locationId: locationId,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      category: category,
    );
  }

  void dispose() {
    _service.dispose();
    _instance = null;
  }
}
