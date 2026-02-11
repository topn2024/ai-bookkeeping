import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/common_types.dart';
export '../models/common_types.dart' show CityTier, CityTierExtension, CityInfo, CityLocation, AmountRange;
import 'location_service.dart' hide CityTier, CityTierExtension, CityInfo, CityLocation;
import 'location_privacy_guard.dart';

/// 位置数据服务集合
/// 对应设计文档第14.2节 - 第2层：位置数据服务
///
/// 包含三个核心服务：
/// 1. UserHomeLocationService - 常驻地点检测
/// 2. CityLocationService - 城市识别
/// 3. LocationHistoryService - 位置历史管理

// ========== 1. 常驻地点检测服务 ==========

/// 常驻地点类型
enum HomeLocationType {
  home,      // 家
  office,    // 公司/办公室
  frequent,  // 常去地点
}

extension HomeLocationTypeExtension on HomeLocationType {
  String get displayName {
    switch (this) {
      case HomeLocationType.home:
        return '家';
      case HomeLocationType.office:
        return '公司';
      case HomeLocationType.frequent:
        return '常去地点';
    }
  }
}

/// 常驻地点
class HomeLocation {
  final String id;
  final HomeLocationType type;
  final Position center;
  final double radius; // 半径（米）
  final String? name;
  final int visitCount;
  final DateTime firstVisit;
  final DateTime lastVisit;
  final double confidenceScore; // 置信度 0-1

  const HomeLocation({
    required this.id,
    required this.type,
    required this.center,
    required this.radius,
    this.name,
    required this.visitCount,
    required this.firstVisit,
    required this.lastVisit,
    required this.confidenceScore,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'radius': radius,
        'name': name,
        'visitCount': visitCount,
        'firstVisit': firstVisit.toIso8601String(),
        'lastVisit': lastVisit.toIso8601String(),
        'confidenceScore': confidenceScore,
      };

  factory HomeLocation.fromJson(Map<String, dynamic> json) => HomeLocation(
        id: json['id'] as String,
        type: HomeLocationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => HomeLocationType.frequent,
        ),
        center: Position(
          latitude: json['latitude'] as double,
          longitude: json['longitude'] as double,
          timestamp: DateTime.parse(json['lastVisit'] as String),
        ),
        radius: json['radius'] as double,
        name: json['name'] as String?,
        visitCount: json['visitCount'] as int,
        firstVisit: DateTime.parse(json['firstVisit'] as String),
        lastVisit: DateTime.parse(json['lastVisit'] as String),
        confidenceScore: json['confidenceScore'] as double,
      );
}

/// 常驻地点检测服务
class UserHomeLocationService {
  static const String _keyPrefix = 'home_location_';
  static const double _defaultRadius = 200.0; // 默认半径200米
  static const int _minVisitsForDetection = 5; // 最少访问次数
  static const int _minDaysForDetection = 3; // 最少天数

  /// 检测常驻地点
  Future<List<HomeLocation>> detectHomeLocations(
    List<Position> positions,
  ) async {
    if (positions.length < _minVisitsForDetection) {
      return [];
    }

    // 1. 聚类分析位置点
    final clusters = _clusterPositions(positions);

    // 2. 筛选候选地点
    final candidates = <HomeLocation>[];
    for (final cluster in clusters) {
      if (cluster.length >= _minVisitsForDetection) {
        final daySpan = _calculateDaySpan(cluster);
        if (daySpan >= _minDaysForDetection) {
          final location = _createHomeLocation(cluster);
          candidates.add(location);
        }
      }
    }

    // 3. 保存检测结果
    await _saveHomeLocations(candidates);

    return candidates;
  }

  /// 获取已保存的常驻地点
  Future<List<HomeLocation>> getHomeLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('${_keyPrefix}list');
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((item) => HomeLocation.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 判断位置是否在常驻地点附近
  Future<HomeLocation?> isNearHomeLocation(Position position) async {
    final homeLocations = await getHomeLocations();

    for (final home in homeLocations) {
      final distance = position.distanceTo(home.center);
      if (distance <= home.radius) {
        return home;
      }
    }

    return null;
  }

  /// 设置常驻地点
  Future<void> setHomeLocation({
    required HomeLocationType type,
    required Position position,
    String? name,
  }) async {
    final locations = await getHomeLocations();

    // 移除同类型的旧地点
    locations.removeWhere((loc) => loc.type == type);

    // 添加新地点
    final newLocation = HomeLocation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      center: position,
      radius: _defaultRadius,
      name: name,
      visitCount: 1,
      firstVisit: DateTime.now(),
      lastVisit: DateTime.now(),
      confidenceScore: 1.0, // 手动设置的置信度最高
    );

    locations.add(newLocation);
    await _saveHomeLocations(locations);
  }

  // 聚类分析
  List<List<Position>> _clusterPositions(List<Position> positions) {
    final clusters = <List<Position>>[];
    final used = <bool>[];

    for (int i = 0; i < positions.length; i++) {
      used.add(false);
    }

    for (int i = 0; i < positions.length; i++) {
      if (used[i]) continue;

      final cluster = <Position>[positions[i]];
      used[i] = true;

      for (int j = i + 1; j < positions.length; j++) {
        if (used[j]) continue;

        final distance = positions[i].distanceTo(positions[j]);
        if (distance <= _defaultRadius) {
          cluster.add(positions[j]);
          used[j] = true;
        }
      }

      if (cluster.length >= _minVisitsForDetection) {
        clusters.add(cluster);
      }
    }

    return clusters;
  }

  // 计算时间跨度（天数）
  int _calculateDaySpan(List<Position> positions) {
    if (positions.isEmpty) return 0;

    final dates = positions.map((p) => p.timestamp).toList()..sort();
    final first = dates.first;
    final last = dates.last;

    return last.difference(first).inDays + 1;
  }

  // 创建常驻地点
  HomeLocation _createHomeLocation(List<Position> cluster) {
    // 计算中心点
    double sumLat = 0, sumLon = 0;
    for (final pos in cluster) {
      sumLat += pos.latitude;
      sumLon += pos.longitude;
    }

    final center = Position(
      latitude: sumLat / cluster.length,
      longitude: sumLon / cluster.length,
      timestamp: cluster.last.timestamp,
    );

    // 计算最大距离作为半径
    double maxDistance = 0;
    for (final pos in cluster) {
      final distance = pos.distanceTo(center);
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }

    final dates = cluster.map((p) => p.timestamp).toList()..sort();

    return HomeLocation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _inferLocationType(cluster),
      center: center,
      radius: max(maxDistance, _defaultRadius),
      name: null,
      visitCount: cluster.length,
      firstVisit: dates.first,
      lastVisit: dates.last,
      confidenceScore: min(cluster.length / 20.0, 1.0),
    );
  }

  // 推断地点类型
  HomeLocationType _inferLocationType(List<Position> cluster) {
    // 简单启发式：根据访问时间模式推断
    final hours = cluster.map((p) => p.timestamp.hour).toList();

    // 如果大部分访问在晚上/凌晨，可能是家
    final nightCount = hours.where((h) => h >= 20 || h <= 6).length;
    if (nightCount > cluster.length * 0.6) {
      return HomeLocationType.home;
    }

    // 如果大部分访问在工作时间，可能是公司
    final workCount = hours.where((h) => h >= 9 && h <= 18).length;
    if (workCount > cluster.length * 0.6) {
      return HomeLocationType.office;
    }

    return HomeLocationType.frequent;
  }

  Future<void> _saveHomeLocations(List<HomeLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(locations.map((l) => l.toJson()).toList());
    await prefs.setString('${_keyPrefix}list', json);
  }
}

// ========== 2. 城市识别服务 ==========

/// 城市识别服务
class CityLocationService {
  static const String _keyCurrentCity = 'current_city';
  static const String _keyHomeCity = 'home_city';

  // 一二线城市数据库（后续接入地图API后可移除）
  static final _cityDatabase = <CityInfo>[
    // 一线城市
    CityInfo(code: '110000', name: '北京', province: '北京', tier: CityTier.tier1, latitude: 39.9042, longitude: 116.4074),
    CityInfo(code: '310000', name: '上海', province: '上海', tier: CityTier.tier1, latitude: 31.2304, longitude: 121.4737),
    CityInfo(code: '440100', name: '广州', province: '广东', tier: CityTier.tier1, latitude: 23.1291, longitude: 113.2644),
    CityInfo(code: '440300', name: '深圳', province: '广东', tier: CityTier.tier1, latitude: 22.5431, longitude: 114.0579),
    // 新一线城市
    CityInfo(code: '510100', name: '成都', province: '四川', tier: CityTier.newTier1, latitude: 30.5728, longitude: 104.0668),
    CityInfo(code: '500000', name: '重庆', province: '重庆', tier: CityTier.newTier1, latitude: 29.5630, longitude: 106.5516),
    CityInfo(code: '330100', name: '杭州', province: '浙江', tier: CityTier.newTier1, latitude: 30.2741, longitude: 120.1551),
    CityInfo(code: '420100', name: '武汉', province: '湖北', tier: CityTier.newTier1, latitude: 30.5928, longitude: 114.3055),
    CityInfo(code: '610100', name: '西安', province: '陕西', tier: CityTier.newTier1, latitude: 34.3416, longitude: 108.9398),
    CityInfo(code: '320100', name: '南京', province: '江苏', tier: CityTier.newTier1, latitude: 32.0603, longitude: 118.7969),
    CityInfo(code: '120000', name: '天津', province: '天津', tier: CityTier.newTier1, latitude: 39.0842, longitude: 117.2009),
    CityInfo(code: '430100', name: '长沙', province: '湖南', tier: CityTier.newTier1, latitude: 28.2282, longitude: 112.9388),
    CityInfo(code: '410100', name: '郑州', province: '河南', tier: CityTier.newTier1, latitude: 34.7466, longitude: 113.6253),
    CityInfo(code: '441900', name: '东莞', province: '广东', tier: CityTier.newTier1, latitude: 23.0430, longitude: 113.7633),
    CityInfo(code: '320500', name: '苏州', province: '江苏', tier: CityTier.newTier1, latitude: 31.2990, longitude: 120.5853),
    CityInfo(code: '210100', name: '沈阳', province: '辽宁', tier: CityTier.newTier1, latitude: 41.8057, longitude: 123.4315),
    CityInfo(code: '370200', name: '青岛', province: '山东', tier: CityTier.newTier1, latitude: 36.0671, longitude: 120.3826),
    CityInfo(code: '340100', name: '合肥', province: '安徽', tier: CityTier.newTier1, latitude: 31.8206, longitude: 117.2272),
    CityInfo(code: '440600', name: '佛山', province: '广东', tier: CityTier.newTier1, latitude: 23.0218, longitude: 113.1219),
    // 二线城市
    CityInfo(code: '330200', name: '宁波', province: '浙江', tier: CityTier.tier2, latitude: 29.8683, longitude: 121.5440),
    CityInfo(code: '530100', name: '昆明', province: '云南', tier: CityTier.tier2, latitude: 25.0389, longitude: 102.7183),
    CityInfo(code: '320200', name: '无锡', province: '江苏', tier: CityTier.tier2, latitude: 31.4912, longitude: 120.3119),
    CityInfo(code: '210200', name: '大连', province: '辽宁', tier: CityTier.tier2, latitude: 38.9140, longitude: 121.6147),
    CityInfo(code: '350200', name: '厦门', province: '福建', tier: CityTier.tier2, latitude: 24.4798, longitude: 118.0894),
    CityInfo(code: '350100', name: '福州', province: '福建', tier: CityTier.tier2, latitude: 26.0745, longitude: 119.2965),
    CityInfo(code: '370100', name: '济南', province: '山东', tier: CityTier.tier2, latitude: 36.6512, longitude: 116.9972),
    CityInfo(code: '330300', name: '温州', province: '浙江', tier: CityTier.tier2, latitude: 27.9939, longitude: 120.6994),
    CityInfo(code: '130100', name: '石家庄', province: '河北', tier: CityTier.tier2, latitude: 38.0428, longitude: 114.5149),
    CityInfo(code: '150100', name: '呼和浩特', province: '内蒙古', tier: CityTier.tier2, latitude: 40.8414, longitude: 111.7519),
    CityInfo(code: '230100', name: '哈尔滨', province: '黑龙江', tier: CityTier.tier2, latitude: 45.8038, longitude: 126.5350),
    CityInfo(code: '220100', name: '长春', province: '吉林', tier: CityTier.tier2, latitude: 43.8171, longitude: 125.3235),
    CityInfo(code: '450100', name: '南宁', province: '广西', tier: CityTier.tier2, latitude: 22.8170, longitude: 108.3665),
    CityInfo(code: '350500', name: '泉州', province: '福建', tier: CityTier.tier2, latitude: 24.8741, longitude: 118.6757),
    CityInfo(code: '520100', name: '贵阳', province: '贵州', tier: CityTier.tier2, latitude: 26.6470, longitude: 106.6302),
    CityInfo(code: '360100', name: '南昌', province: '江西', tier: CityTier.tier2, latitude: 28.6820, longitude: 115.8579),
    CityInfo(code: '320400', name: '常州', province: '江苏', tier: CityTier.tier2, latitude: 31.8106, longitude: 119.9741),
    CityInfo(code: '460100', name: '海口', province: '海南', tier: CityTier.tier2, latitude: 20.0440, longitude: 110.1999),
    CityInfo(code: '540100', name: '拉萨', province: '西藏', tier: CityTier.tier2, latitude: 29.6500, longitude: 91.1409),
    CityInfo(code: '620100', name: '兰州', province: '甘肃', tier: CityTier.tier2, latitude: 36.0611, longitude: 103.8343),
    CityInfo(code: '640100', name: '银川', province: '宁夏', tier: CityTier.tier2, latitude: 38.4872, longitude: 106.2309),
    CityInfo(code: '630100', name: '西宁', province: '青海', tier: CityTier.tier2, latitude: 36.6171, longitude: 101.7782),
    CityInfo(code: '650100', name: '乌鲁木齐', province: '新疆', tier: CityTier.tier2, latitude: 43.8256, longitude: 87.6168),
    CityInfo(code: '460200', name: '三亚', province: '海南', tier: CityTier.tier2, latitude: 18.2528, longitude: 109.5120),
    CityInfo(code: '441300', name: '惠州', province: '广东', tier: CityTier.tier2, latitude: 23.1116, longitude: 114.4161),
    CityInfo(code: '441200', name: '肇庆', province: '广东', tier: CityTier.tier2, latitude: 23.0469, longitude: 112.4653),
    CityInfo(code: '442000', name: '中山', province: '广东', tier: CityTier.tier2, latitude: 22.5166, longitude: 113.3926),
    CityInfo(code: '440400', name: '珠海', province: '广东', tier: CityTier.tier2, latitude: 22.2710, longitude: 113.5767),
    CityInfo(code: '320600', name: '南通', province: '江苏', tier: CityTier.tier2, latitude: 31.9800, longitude: 120.8943),
    CityInfo(code: '321300', name: '宿迁', province: '江苏', tier: CityTier.tier2, latitude: 33.9631, longitude: 118.2750),
    CityInfo(code: '370300', name: '淄博', province: '山东', tier: CityTier.tier2, latitude: 36.8131, longitude: 118.0548),
    CityInfo(code: '370600', name: '烟台', province: '山东', tier: CityTier.tier2, latitude: 37.4638, longitude: 121.4479),
    // TODO: 后续接入高德/百度地图API后，可移除本地城市库
  ];

  /// 识别当前城市
  Future<CityInfo?> identifyCity(Position position) async {
    CityInfo? nearestCity;
    double minDistance = double.infinity;

    // 找到最近的城市
    for (final city in _cityDatabase) {
      final cityPos = Position(
        latitude: city.latitude,
        longitude: city.longitude,
        timestamp: DateTime.now(),
      );

      final distance = position.distanceTo(cityPos);
      if (distance < minDistance) {
        minDistance = distance;
        nearestCity = city;
      }
    }

    // 如果距离超过50公里，认为不在主要城市
    if (minDistance > 50000) {
      return null;
    }

    // 保存当前城市
    if (nearestCity != null) {
      await _setCurrentCity(nearestCity);
    }

    return nearestCity;
  }

  /// 获取当前城市
  Future<CityInfo?> getCurrentCity() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCurrentCity);
    if (json == null) return null;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CityInfo(
        code: map['code'] as String,
        name: map['name'] as String,
        province: map['province'] as String,
        tier: CityTier.values.firstWhere(
          (t) => t.name == map['tier'],
          orElse: () => CityTier.unknown,
        ),
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
      );
    } catch (e) {
      return null;
    }
  }

  /// 设置家乡城市
  Future<void> setHomeCity(CityInfo city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHomeCity, jsonEncode({
      'code': city.code,
      'name': city.name,
      'province': city.province,
      'tier': city.tier.name,
      'latitude': city.latitude,
      'longitude': city.longitude,
    }));
  }

  /// 获取家乡城市
  Future<CityInfo?> getHomeCity() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyHomeCity);
    if (json == null) return null;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CityInfo(
        code: map['code'] as String,
        name: map['name'] as String,
        province: map['province'] as String,
        tier: CityTier.values.firstWhere(
          (t) => t.name == map['tier'],
          orElse: () => CityTier.unknown,
        ),
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
      );
    } catch (e) {
      return null;
    }
  }

  /// 判断是否在异地
  Future<bool> isInDifferentCity(Position position) async {
    final homeCity = await getHomeCity();
    if (homeCity == null) return false;

    final currentCity = await identifyCity(position);
    if (currentCity == null) return true;

    return currentCity.code != homeCity.code;
  }

  Future<void> _setCurrentCity(CityInfo city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentCity, jsonEncode({
      'code': city.code,
      'name': city.name,
      'province': city.province,
      'tier': city.tier.name,
      'latitude': city.latitude,
      'longitude': city.longitude,
    }));
  }
}

// ========== 3. 位置历史服务 ==========

/// 位置历史记录
class LocationHistoryEntry {
  final String id;
  final Position position;
  final DateTime timestamp;
  final String? note;
  final Map<String, dynamic>? metadata;

  const LocationHistoryEntry({
    required this.id,
    required this.position,
    required this.timestamp,
    this.note,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
        'metadata': metadata,
      };

  factory LocationHistoryEntry.fromJson(Map<String, dynamic> json) => LocationHistoryEntry(
        id: json['id'] as String,
        position: Position(
          latitude: json['latitude'] as double,
          longitude: json['longitude'] as double,
          accuracy: json['accuracy'] as double?,
          timestamp: DateTime.parse(json['timestamp'] as String),
        ),
        timestamp: DateTime.parse(json['timestamp'] as String),
        note: json['note'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

/// 位置历史服务
class LocationHistoryService {
  final LocationPrivacyGuard _privacyGuard;
  static const String _keyHistoryList = 'location_history_list';
  static const int _maxHistorySize = 1000; // 最多保留1000条记录

  LocationHistoryService({
    LocationPrivacyGuard? privacyGuard,
  }) : _privacyGuard = privacyGuard ?? LocationPrivacyGuard();

  /// 添加位置历史记录
  Future<String> addHistory({
    required Position position,
    required LocationPurpose purpose,
    String? note,
    Map<String, dynamic>? metadata,
  }) async {
    // 使用隐私保护服务加密存储
    final id = await _privacyGuard.storeLocationSecurely(
      position: position,
      purpose: purpose,
      metadata: metadata,
    );

    // 添加到历史列表
    await _addToHistoryList(id);

    return id;
  }

  /// 获取位置历史
  Future<List<LocationHistoryEntry>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final ids = await _getHistoryIds();
    final entries = <LocationHistoryEntry>[];

    for (final id in ids) {
      final locationData = await _privacyGuard.retrieveLocationSecurely(id);
      if (locationData != null) {
        final entry = LocationHistoryEntry(
          id: locationData.id,
          position: locationData.position,
          timestamp: locationData.position.timestamp,
          metadata: locationData.metadata,
        );

        // 过滤日期范围
        bool include = true;
        if (startDate != null && entry.timestamp.isBefore(startDate)) {
          include = false;
        }
        if (endDate != null && entry.timestamp.isAfter(endDate)) {
          include = false;
        }

        if (include) {
          entries.add(entry);
        }

        // 限制数量
        if (limit != null && entries.length >= limit) {
          break;
        }
      }
    }

    return entries;
  }

  /// 清除所有历史
  Future<void> clearHistory() async {
    await _privacyGuard.clearAllLocationData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistoryList);
  }

  /// 自动清理过期数据（30天）
  Future<void> autoCleanup() async {
    final result = await _privacyGuard.cleanupExpiredData(retentionDays: 30);
    debugPrint('位置历史自动清理: ${result.toString()}');

    // 同步更新历史列表
    await _syncHistoryList();
  }

  /// 获取历史统计
  Future<LocationHistoryStatistics> getStatistics() async {
    final entries = await getHistory();
    final now = DateTime.now();

    int last7Days = 0;
    int last30Days = 0;
    double totalDistance = 0.0;

    if (entries.length > 1) {
      for (int i = 1; i < entries.length; i++) {
        totalDistance += entries[i].position.distanceTo(entries[i - 1].position);
      }
    }

    for (final entry in entries) {
      final age = now.difference(entry.timestamp).inDays;
      if (age <= 7) last7Days++;
      if (age <= 30) last30Days++;
    }

    return LocationHistoryStatistics(
      totalCount: entries.length,
      last7DaysCount: last7Days,
      last30DaysCount: last30Days,
      totalDistance: totalDistance,
      oldestEntry: entries.isNotEmpty ? entries.first.timestamp : null,
      newestEntry: entries.isNotEmpty ? entries.last.timestamp : null,
    );
  }

  Future<void> _addToHistoryList(String id) async {
    final ids = await _getHistoryIds();
    ids.add(id);

    // 限制列表大小
    if (ids.length > _maxHistorySize) {
      ids.removeRange(0, ids.length - _maxHistorySize);
    }

    await _saveHistoryIds(ids);
  }

  Future<List<String>> _getHistoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyHistoryList);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveHistoryIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHistoryList, jsonEncode(ids));
  }

  Future<void> _syncHistoryList() async {
    // 同步历史列表，移除已清理的记录
    final allIds = await _privacyGuard.getAllLocationIds();
    await _saveHistoryIds(allIds);
  }
}

/// 位置历史统计
class LocationHistoryStatistics {
  final int totalCount;
  final int last7DaysCount;
  final int last30DaysCount;
  final double totalDistance; // 总移动距离（米）
  final DateTime? oldestEntry;
  final DateTime? newestEntry;

  const LocationHistoryStatistics({
    required this.totalCount,
    required this.last7DaysCount,
    required this.last30DaysCount,
    required this.totalDistance,
    this.oldestEntry,
    this.newestEntry,
  });
}
