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

  // 主要城市数据库（简化版）
  static final _cityDatabase = <CityInfo>[
    CityInfo(code: '110000', name: '北京', province: '北京', tier: CityTier.tier1, latitude: 39.9042, longitude: 116.4074),
    CityInfo(code: '310000', name: '上海', province: '上海', tier: CityTier.tier1, latitude: 31.2304, longitude: 121.4737),
    CityInfo(code: '440100', name: '广州', province: '广东', tier: CityTier.tier1, latitude: 23.1291, longitude: 113.2644),
    CityInfo(code: '440300', name: '深圳', province: '广东', tier: CityTier.tier1, latitude: 22.5431, longitude: 114.0579),
    CityInfo(code: '330100', name: '杭州', province: '浙江', tier: CityTier.tier2, latitude: 30.2741, longitude: 120.1551),
    CityInfo(code: '320100', name: '南京', province: '江苏', tier: CityTier.tier2, latitude: 32.0603, longitude: 118.7969),
    CityInfo(code: '510100', name: '成都', province: '四川', tier: CityTier.tier2, latitude: 30.5728, longitude: 104.0668),
    CityInfo(code: '420100', name: '武汉', province: '湖北', tier: CityTier.tier2, latitude: 30.5928, longitude: 114.3055),
    // ... 可添加更多城市
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
