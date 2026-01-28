import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/common_types.dart';
export '../models/common_types.dart' show CityTier, CityTierExtension, CityInfo, CityLocation;

/// 位置服务抽象接口
abstract class LocationService {
  /// 获取当前位置
  Future<Position?> getCurrentPosition();

  /// 检查权限状态
  Future<LocationPermissionResult> checkPermission();

  /// 请求权限
  Future<LocationPermissionResult> requestPermission();

  /// 开始位置监听
  Stream<Position> startLocationStream();

  /// 停止位置监听
  void stopLocationStream();
}

/// 位置权限结果
enum LocationPermissionResult {
  full,           // 完全权限（前后台）
  foregroundOnly, // 仅前台权限
  approximate,    // 仅粗略位置
  denied,         // 被拒绝
  permanentlyDenied, // 永久拒绝
}

/// 位置信息
class Position {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final DateTime timestamp;

  const Position({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    required this.timestamp,
  });

  /// 计算与另一点的距离（米）
  double distanceTo(Position other) {
    const earthRadius = 6371000.0; // 地球半径（米）
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

/// 精确地理位置服务
class PreciseLocationService implements LocationService {
  StreamController<Position>? _locationStreamController;
  StreamSubscription<geo.Position>? _geoSubscription;

  /// 检查并请求精确位置权限
  @override
  Future<LocationPermissionResult> requestPermission() async {
    try {
      // 检查位置服务是否启用
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] 位置服务未启用');
        return LocationPermissionResult.denied;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      return _mapPermission(permission);
    } catch (e) {
      debugPrint('[LocationService] 请求权限失败: $e');
      return LocationPermissionResult.denied;
    }
  }

  @override
  Future<LocationPermissionResult> checkPermission() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] 位置服务未启用');
        return LocationPermissionResult.denied;
      }

      final permission = await geo.Geolocator.checkPermission();
      return _mapPermission(permission);
    } catch (e) {
      debugPrint('[LocationService] 检查权限失败: $e');
      return LocationPermissionResult.denied;
    }
  }

  /// 映射权限结果
  LocationPermissionResult _mapPermission(geo.LocationPermission permission) {
    switch (permission) {
      case geo.LocationPermission.always:
        return LocationPermissionResult.full;
      case geo.LocationPermission.whileInUse:
        return LocationPermissionResult.foregroundOnly;
      case geo.LocationPermission.denied:
        return LocationPermissionResult.denied;
      case geo.LocationPermission.deniedForever:
        return LocationPermissionResult.permanentlyDenied;
      case geo.LocationPermission.unableToDetermine:
        return LocationPermissionResult.denied;
    }
  }

  /// 获取当前精确位置
  @override
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (hasPermission == LocationPermissionResult.denied ||
          hasPermission == LocationPermissionResult.permanentlyDenied) {
        debugPrint('[LocationService] 无位置权限');
        return null;
      }

      debugPrint('[LocationService] 正在获取位置...');
      final geoPosition = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint('[LocationService] 获取位置成功: ${geoPosition.latitude}, ${geoPosition.longitude}');
      return Position(
        latitude: geoPosition.latitude,
        longitude: geoPosition.longitude,
        accuracy: geoPosition.accuracy,
        altitude: geoPosition.altitude,
        speed: geoPosition.speed,
        timestamp: geoPosition.timestamp,
      );
    } catch (e) {
      debugPrint('[LocationService] 获取位置失败: $e');
      return null;
    }
  }

  /// 获取当前精确位置（带详细信息）
  Future<PreciseLocation?> getCurrentLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    // 反向地理编码获取详细地址
    final addressInfo = await _reverseGeocode(position);

    return PreciseLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy ?? 0,
      timestamp: position.timestamp,
      country: addressInfo['country'] ?? '中国',
      province: addressInfo['province'] ?? '',
      city: addressInfo['city'] ?? '',
      district: addressInfo['district'] ?? '',
      street: addressInfo['street'] ?? '',
      address: addressInfo['address'] ?? '',
      poiName: addressInfo['poi'] ?? '',
      cityTier: _determineCityTier(addressInfo['city'] ?? ''),
      isOverseas: addressInfo['country'] != '中国',
    );
  }

  @override
  Stream<Position> startLocationStream() {
    _locationStreamController?.close();
    _geoSubscription?.cancel();
    _locationStreamController = StreamController<Position>.broadcast();

    try {
      _geoSubscription = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          distanceFilter: 10, // 每移动10米更新一次
        ),
      ).listen(
        (geoPosition) {
          final position = Position(
            latitude: geoPosition.latitude,
            longitude: geoPosition.longitude,
            accuracy: geoPosition.accuracy,
            altitude: geoPosition.altitude,
            speed: geoPosition.speed,
            timestamp: geoPosition.timestamp,
          );
          _locationStreamController?.add(position);
        },
        onError: (e) {
          debugPrint('[LocationService] 位置流错误: $e');
        },
      );
      debugPrint('[LocationService] 位置流监听已启动');
    } catch (e) {
      debugPrint('[LocationService] 启动位置流失败: $e');
    }

    return _locationStreamController!.stream;
  }

  @override
  void stopLocationStream() {
    _geoSubscription?.cancel();
    _geoSubscription = null;
    _locationStreamController?.close();
    _locationStreamController = null;
    debugPrint('[LocationService] 位置流监听已停止');
  }

  /// 反向地理编码
  Future<Map<String, String>> _reverseGeocode(Position position) async {
    // 实际实现需要调用高德或百度地图API
    return {
      'country': '中国',
      'province': '北京市',
      'city': '北京市',
      'district': '朝阳区',
      'street': '建国路',
      'address': '北京市朝阳区建国路',
      'poi': '',
    };
  }

  /// 判定城市等级
  CityTier _determineCityTier(String city) {
    const tier1Cities = ['北京', '上海', '广州', '深圳'];
    const tier2Cities = [
      '成都', '杭州', '重庆', '武汉', '苏州', '西安', '南京',
      '天津', '郑州', '长沙', '东莞', '沈阳', '青岛', '合肥',
      '佛山', '宁波', '昆明', '无锡', '大连', '厦门', '福州',
      '济南', '哈尔滨', '温州', '石家庄', '南宁', '长春', '泉州',
      '贵阳', '南昌',
    ];

    final cityName = city.replaceAll('市', '');
    if (tier1Cities.contains(cityName)) return CityTier.tier1;
    if (tier2Cities.contains(cityName)) return CityTier.tier2;
    return CityTier.tier3;
  }
}

/// 精确位置信息
class PreciseLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final String country;
  final String province;
  final String city;
  final String district;
  final String street;
  final String address;
  final String poiName;
  final CityTier cityTier;
  final bool isOverseas;

  const PreciseLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.country,
    required this.province,
    required this.city,
    required this.district,
    required this.street,
    required this.address,
    required this.poiName,
    required this.cityTier,
    required this.isOverseas,
  });

  /// 计算与另一点的距离（米）
  double distanceTo(PreciseLocation other) {
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

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'country': country,
    'province': province,
    'city': city,
    'district': district,
    'street': street,
    'address': address,
    'poiName': poiName,
    'cityTier': cityTier.name,
    'isOverseas': isOverseas,
  };

  factory PreciseLocation.fromJson(Map<String, dynamic> json) {
    return PreciseLocation(
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      country: json['country'],
      province: json['province'],
      city: json['city'],
      district: json['district'],
      street: json['street'],
      address: json['address'],
      poiName: json['poiName'],
      cityTier: CityTier.values.byName(json['cityTier']),
      isOverseas: json['isOverseas'],
    );
  }
}

/// 用户常驻地点管理服务
class UserHomeLocationService {
  final PreciseLocationService _locationService;
  final SharedPreferences _prefs;

  static const String _homeKey = 'user_home_location';
  static const String _workKey = 'user_work_location';
  static const String _frequentKey = 'user_frequent_locations';

  UserHomeLocationService({
    required PreciseLocationService locationService,
    required SharedPreferences prefs,
  })  : _locationService = locationService,
        _prefs = prefs;

  /// 获取用户家庭位置
  Future<PreciseLocation?> getHomeLocation() async {
    final json = _prefs.getString(_homeKey);
    if (json == null) return null;
    return PreciseLocation.fromJson(jsonDecode(json));
  }

  /// 设置用户家庭位置
  Future<void> setHomeLocation(PreciseLocation location) async {
    await _prefs.setString(_homeKey, jsonEncode(location.toJson()));
  }

  /// 获取用户工作位置
  Future<PreciseLocation?> getWorkLocation() async {
    final json = _prefs.getString(_workKey);
    if (json == null) return null;
    return PreciseLocation.fromJson(jsonDecode(json));
  }

  /// 设置用户工作位置
  Future<void> setWorkLocation(PreciseLocation location) async {
    await _prefs.setString(_workKey, jsonEncode(location.toJson()));
  }

  /// 判断当前是否在家附近
  Future<bool> isNearHome({double radiusMeters = 500}) async {
    final home = await getHomeLocation();
    if (home == null) return false;

    final current = await _locationService.getCurrentLocation();
    if (current == null) return false;

    return current.distanceTo(home) < radiusMeters;
  }

  /// 判断当前是否在工作地点附近
  Future<bool> isNearWork({double radiusMeters = 500}) async {
    final work = await getWorkLocation();
    if (work == null) return false;

    final current = await _locationService.getCurrentLocation();
    if (current == null) return false;

    return current.distanceTo(work) < radiusMeters;
  }

  /// 获取用户常去的地点列表
  Future<List<FrequentLocation>> getFrequentLocations() async {
    final json = _prefs.getString(_frequentKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => FrequentLocation.fromJson(e)).toList();
  }

  /// 添加常去地点
  Future<void> addFrequentLocation(FrequentLocation location) async {
    final locations = await getFrequentLocations();
    locations.add(location);
    await _prefs.setString(
      _frequentKey,
      jsonEncode(locations.map((e) => e.toJson()).toList()),
    );
  }
}

/// 常去地点
class FrequentLocation {
  final String id;
  final String name;
  final PreciseLocation location;
  final int visitCount;
  final DateTime lastVisit;
  final LocationType type;

  const FrequentLocation({
    required this.id,
    required this.name,
    required this.location,
    required this.visitCount,
    required this.lastVisit,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location.toJson(),
    'visitCount': visitCount,
    'lastVisit': lastVisit.toIso8601String(),
    'type': type.name,
  };

  factory FrequentLocation.fromJson(Map<String, dynamic> json) {
    return FrequentLocation(
      id: json['id'],
      name: json['name'],
      location: PreciseLocation.fromJson(json['location']),
      visitCount: json['visitCount'],
      lastVisit: DateTime.parse(json['lastVisit']),
      type: LocationType.values.byName(json['type']),
    );
  }
}

/// 地点类型
enum LocationType {
  home,       // 家
  work,       // 公司
  gym,        // 健身房
  supermarket,// 超市
  restaurant, // 常去餐厅
  hospital,   // 医院
  school,     // 学校
  other,      // 其他
}

/// 城市位置服务
class CityLocationService {
  final PreciseLocationService _locationService;
  final SharedPreferences _prefs;

  static const String _homeCityKey = 'user_home_city';

  CityLocationService({
    required PreciseLocationService locationService,
    required SharedPreferences prefs,
  })  : _locationService = locationService,
        _prefs = prefs;

  /// 获取用户常驻城市
  Future<CityLocation?> getHomeCity() async {
    final json = _prefs.getString(_homeCityKey);
    if (json == null) return null;
    return CityLocation.fromJson(jsonDecode(json));
  }

  /// 设置用户常驻城市
  Future<void> setHomeCity(CityLocation city) async {
    await _prefs.setString(_homeCityKey, jsonEncode(city.toJson()));
  }

  /// 从精确位置提取城市信息
  CityLocation extractCityFromLocation(PreciseLocation location) {
    return CityLocation(
      country: location.country,
      province: location.province,
      city: location.city,
      tier: location.cityTier,
      isOverseas: location.isOverseas,
    );
  }

  /// 获取当前所在城市
  Future<CityLocation?> getCurrentCity() async {
    final location = await _locationService.getCurrentLocation();
    if (location == null) return null;
    return extractCityFromLocation(location);
  }

  /// 判断是否在异地
  Future<bool> isInDifferentCity() async {
    final homeCity = await getHomeCity();
    if (homeCity == null) return false;

    final currentCity = await getCurrentCity();
    if (currentCity == null) return false;

    return homeCity.city != currentCity.city;
  }

  /// 根据精确位置识别城市信息
  Future<CityLocation?> identifyCity(PreciseLocation? position) async {
    if (position == null) return null;
    return extractCityFromLocation(position);
  }
}

/// 城市位置信息
class CityLocation {
  final String country;
  final String province;
  final String city;
  final CityTier tier;
  final bool isOverseas;

  const CityLocation({
    required this.country,
    required this.province,
    required this.city,
    required this.tier,
    required this.isOverseas,
  });

  Map<String, dynamic> toJson() => {
    'country': country,
    'province': province,
    'city': city,
    'tier': tier.name,
    'isOverseas': isOverseas,
  };

  factory CityLocation.fromJson(Map<String, dynamic> json) {
    return CityLocation(
      country: json['country'],
      province: json['province'],
      city: json['city'],
      tier: CityTier.values.byName(json['tier']),
      isOverseas: json['isOverseas'],
    );
  }
}

/// 异地消费检测服务
class CrossRegionSpendingService {
  final CityLocationService _cityService;
  // ignore: unused_field
  final SharedPreferences __prefs;

  CrossRegionSpendingService({
    required CityLocationService cityService,
    required SharedPreferences prefs,
  })  : _cityService = cityService,
        __prefs = prefs;

  /// 检测当前是否为异地消费
  Future<CrossRegionResult> detectCrossRegion() async {
    final homeCity = await _cityService.getHomeCity();
    if (homeCity == null) {
      return CrossRegionResult(
        isAway: false,
        reason: CrossRegionReason.noHomeCity,
      );
    }

    final currentCity = await _cityService.getCurrentCity();
    if (currentCity == null) {
      return CrossRegionResult(
        isAway: false,
        reason: CrossRegionReason.locationUnavailable,
      );
    }

    if (currentCity.isOverseas && !homeCity.isOverseas) {
      return CrossRegionResult(
        isAway: true,
        reason: CrossRegionReason.overseas,
        homeCity: homeCity,
        currentCity: currentCity,
        travelType: TravelType.overseas,
      );
    }

    if (currentCity.city != homeCity.city) {
      return CrossRegionResult(
        isAway: true,
        reason: CrossRegionReason.differentCity,
        homeCity: homeCity,
        currentCity: currentCity,
        travelType: _determineTravelType(homeCity, currentCity),
      );
    }

    return CrossRegionResult(
      isAway: false,
      reason: CrossRegionReason.sameCity,
      homeCity: homeCity,
      currentCity: currentCity,
    );
  }

  TravelType _determineTravelType(CityLocation home, CityLocation current) {
    if (current.isOverseas) return TravelType.overseas;
    if (current.province != home.province) return TravelType.crossProvince;
    return TravelType.crossCity;
  }
}

/// 异地检测结果
class CrossRegionResult {
  final bool isAway;
  final CrossRegionReason reason;
  final CityLocation? homeCity;
  final CityLocation? currentCity;
  final TravelType? travelType;

  const CrossRegionResult({
    required this.isAway,
    required this.reason,
    this.homeCity,
    this.currentCity,
    this.travelType,
  });
}

enum CrossRegionReason {
  sameCity,
  differentCity,
  overseas,
  noHomeCity,
  locationUnavailable,
}

enum TravelType {
  crossCity,     // 跨市
  crossProvince, // 跨省
  overseas,      // 海外
}

/// 地理围栏提醒服务
class GeofenceAlertService {
  final PreciseLocationService _locationService;
  final List<Geofence> _geofences = [];
  StreamSubscription<Position>? _locationSubscription;
  final _alertController = StreamController<GeofenceAlert>.broadcast();

  GeofenceAlertService({
    required PreciseLocationService locationService,
  }) : _locationService = locationService;

  /// 获取提醒流
  Stream<GeofenceAlert> get alerts => _alertController.stream;

  /// 添加地理围栏
  void addGeofence(Geofence geofence) {
    _geofences.add(geofence);
  }

  /// 移除地理围栏
  void removeGeofence(String id) {
    _geofences.removeWhere((g) => g.id == id);
  }

  /// 开始监控
  void startMonitoring() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.startLocationStream().listen(
      _checkGeofences,
    );
  }

  /// 停止监控
  void stopMonitoring() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _checkGeofences(Position position) {
    for (final geofence in _geofences) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        geofence.latitude,
        geofence.longitude,
      );

      final wasInside = geofence.isInside;
      final isInside = distance <= geofence.radius;

      if (isInside && !wasInside) {
        // 进入围栏
        geofence.isInside = true;
        _alertController.add(GeofenceAlert(
          geofence: geofence,
          type: GeofenceAlertType.enter,
          timestamp: DateTime.now(),
        ));
      } else if (!isInside && wasInside) {
        // 离开围栏
        geofence.isInside = false;
        _alertController.add(GeofenceAlert(
          geofence: geofence,
          type: GeofenceAlertType.exit,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  void dispose() {
    stopMonitoring();
    _alertController.close();
  }
}

/// 地理围栏
class Geofence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // 米
  final GeofenceType type;
  final Map<String, dynamic>? metadata;
  bool isInside = false;

  Geofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.type,
    this.metadata,
  });
}

enum GeofenceType {
  shopping,    // 购物场所
  restaurant,  // 餐饮场所
  entertainment, // 娱乐场所
  transport,   // 交通枢纽
  custom,      // 自定义
}

/// 地理围栏提醒
class GeofenceAlert {
  final Geofence geofence;
  final GeofenceAlertType type;
  final DateTime timestamp;

  const GeofenceAlert({
    required this.geofence,
    required this.type,
    required this.timestamp,
  });
}

enum GeofenceAlertType {
  enter,
  exit,
  dwell,
}

/// 消费场景分析器
class SpendingContextAnalyzer {
  final PreciseLocationService _locationService;
  final UserHomeLocationService _homeService;

  SpendingContextAnalyzer({
    required PreciseLocationService locationService,
    required UserHomeLocationService homeService,
  })  : _locationService = locationService,
        _homeService = homeService;

  /// 分析当前消费场景
  Future<SpendingContext> analyzeContext() async {
    final location = await _locationService.getCurrentLocation();
    if (location == null) {
      return SpendingContext(
        type: SpendingContextType.unknown,
        confidence: 0,
      );
    }

    // 检查是否在家附近
    final isNearHome = await _homeService.isNearHome();
    if (isNearHome) {
      return SpendingContext(
        type: SpendingContextType.home,
        location: location,
        confidence: 0.9,
        suggestedCategory: '居住',
      );
    }

    // 检查是否在工作地点附近
    final isNearWork = await _homeService.isNearWork();
    if (isNearWork) {
      return SpendingContext(
        type: SpendingContextType.work,
        location: location,
        confidence: 0.9,
        suggestedCategory: '工作',
      );
    }

    // 根据POI类型推断场景
    return _inferContextFromPOI(location);
  }

  SpendingContext _inferContextFromPOI(PreciseLocation location) {
    final poi = location.poiName.toLowerCase();

    if (poi.contains('餐') || poi.contains('食') || poi.contains('饭')) {
      return SpendingContext(
        type: SpendingContextType.dining,
        location: location,
        confidence: 0.8,
        suggestedCategory: '餐饮',
      );
    }

    if (poi.contains('超市') || poi.contains('商场') || poi.contains('购物')) {
      return SpendingContext(
        type: SpendingContextType.shopping,
        location: location,
        confidence: 0.8,
        suggestedCategory: '购物',
      );
    }

    if (poi.contains('医院') || poi.contains('诊所') || poi.contains('药')) {
      return SpendingContext(
        type: SpendingContextType.medical,
        location: location,
        confidence: 0.8,
        suggestedCategory: '医疗',
      );
    }

    return SpendingContext(
      type: SpendingContextType.other,
      location: location,
      confidence: 0.5,
    );
  }
}

/// 消费场景
class SpendingContext {
  final SpendingContextType type;
  final PreciseLocation? location;
  final double confidence;
  final String? suggestedCategory;
  final Map<String, dynamic>? metadata;

  const SpendingContext({
    required this.type,
    this.location,
    required this.confidence,
    this.suggestedCategory,
    this.metadata,
  });
}

enum SpendingContextType {
  home,
  work,
  dining,
  shopping,
  entertainment,
  transport,
  medical,
  education,
  travel,
  other,
  unknown,
}

/// 位置服务定位器（依赖注入）
class LocationServiceLocator {
  static final _instance = LocationServiceLocator._();
  factory LocationServiceLocator() => _instance;
  LocationServiceLocator._();

  late final PreciseLocationService preciseLocation;
  late final UserHomeLocationService userHome;
  late final CityLocationService cityLocation;
  late final CrossRegionSpendingService crossRegion;
  late final SpendingContextAnalyzer spendingContext;
  late final GeofenceAlertService geofenceAlert;

  bool _isInitialized = false;

  Future<void> initialize(SharedPreferences prefs) async {
    if (_isInitialized) return;

    // 第1层：基础定位服务
    preciseLocation = PreciseLocationService();

    // 第2层：位置数据服务
    userHome = UserHomeLocationService(
      locationService: preciseLocation,
      prefs: prefs,
    );
    cityLocation = CityLocationService(
      locationService: preciseLocation,
      prefs: prefs,
    );

    // 第3层：业务分析服务
    crossRegion = CrossRegionSpendingService(
      cityService: cityLocation,
      prefs: prefs,
    );
    spendingContext = SpendingContextAnalyzer(
      locationService: preciseLocation,
      homeService: userHome,
    );
    geofenceAlert = GeofenceAlertService(
      locationService: preciseLocation,
    );

    _isInitialized = true;
  }
}
