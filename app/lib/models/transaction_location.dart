import 'package:flutter/material.dart';

/// 位置类型枚举
enum LocationType {
  /// 日常消费场所（超市、便利店等）
  daily,

  /// 餐饮场所
  dining,

  /// 购物场所（商场、店铺）
  shopping,

  /// 交通场所（加油站、停车场）
  transport,

  /// 娱乐场所
  entertainment,

  /// 医疗场所
  medical,

  /// 教育场所
  education,

  /// 住宅区域
  residential,

  /// 工作区域
  workplace,

  /// 旅行目的地
  travel,

  /// 其他
  other,
}

extension LocationTypeExtension on LocationType {
  String get displayName {
    switch (this) {
      case LocationType.daily:
        return '日常消费';
      case LocationType.dining:
        return '餐饮';
      case LocationType.shopping:
        return '购物';
      case LocationType.transport:
        return '交通';
      case LocationType.entertainment:
        return '娱乐';
      case LocationType.medical:
        return '医疗';
      case LocationType.education:
        return '教育';
      case LocationType.residential:
        return '住宅';
      case LocationType.workplace:
        return '工作';
      case LocationType.travel:
        return '旅行';
      case LocationType.other:
        return '其他';
    }
  }

  IconData get icon {
    switch (this) {
      case LocationType.daily:
        return Icons.local_grocery_store;
      case LocationType.dining:
        return Icons.restaurant;
      case LocationType.shopping:
        return Icons.shopping_bag;
      case LocationType.transport:
        return Icons.directions_car;
      case LocationType.entertainment:
        return Icons.sports_esports;
      case LocationType.medical:
        return Icons.local_hospital;
      case LocationType.education:
        return Icons.school;
      case LocationType.residential:
        return Icons.home;
      case LocationType.workplace:
        return Icons.business;
      case LocationType.travel:
        return Icons.flight;
      case LocationType.other:
        return Icons.place;
    }
  }

  Color get color {
    switch (this) {
      case LocationType.daily:
        return Colors.blue;
      case LocationType.dining:
        return Colors.orange;
      case LocationType.shopping:
        return Colors.pink;
      case LocationType.transport:
        return Colors.indigo;
      case LocationType.entertainment:
        return Colors.purple;
      case LocationType.medical:
        return Colors.red;
      case LocationType.education:
        return Colors.teal;
      case LocationType.residential:
        return Colors.green;
      case LocationType.workplace:
        return Colors.blueGrey;
      case LocationType.travel:
        return Colors.cyan;
      case LocationType.other:
        return Colors.grey;
    }
  }
}

/// 交易位置信息
///
/// 记录交易发生的地理位置，支持位置智能化功能（第14章）
class TransactionLocation {
  final double latitude;          // 纬度
  final double longitude;         // 经度
  final String? placeName;        // 地点名称（如：沃尔玛超市）
  final String? address;          // 详细地址
  final LocationType? locationType; // 位置类型
  final String? city;             // 城市
  final String? district;         // 区/县
  final String? poiId;            // POI ID（高德/百度等地图服务）
  final double? accuracy;         // 定位精度（米）
  final DateTime? capturedAt;     // 位置捕获时间

  const TransactionLocation({
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.address,
    this.locationType,
    this.city,
    this.district,
    this.poiId,
    this.accuracy,
    this.capturedAt,
  });

  /// 是否有有效坐标
  bool get hasValidCoordinates =>
      latitude != 0 && longitude != 0 &&
      latitude >= -90 && latitude <= 90 &&
      longitude >= -180 && longitude <= 180;

  /// 是否有地点名称
  bool get hasPlaceName => placeName != null && placeName!.isNotEmpty;

  /// 是否有详细地址
  bool get hasAddress => address != null && address!.isNotEmpty;

  /// 获取显示名称（优先地点名，其次地址，最后坐标）
  String get displayName {
    if (hasPlaceName) return placeName!;
    if (hasAddress) return address!;
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// 获取简短显示（地点名或区县）
  String get shortDisplay {
    if (hasPlaceName) return placeName!;
    if (district != null) return district!;
    if (city != null) return city!;
    return '未知位置';
  }

  /// 计算与另一个位置的距离（米）
  /// 使用 Haversine 公式
  double distanceTo(TransactionLocation other) {
    const double earthRadius = 6371000; // 地球半径（米）
    final double lat1Rad = latitude * 3.141592653589793 / 180;
    final double lat2Rad = other.latitude * 3.141592653589793 / 180;
    final double deltaLat = (other.latitude - latitude) * 3.141592653589793 / 180;
    final double deltaLon = (other.longitude - longitude) * 3.141592653589793 / 180;

    final double a = _sin(deltaLat / 2) * _sin(deltaLat / 2) +
        _cos(lat1Rad) * _cos(lat2Rad) *
            _sin(deltaLon / 2) * _sin(deltaLon / 2);
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  // 简单的数学函数（避免引入 dart:math）
  static double _sin(double x) {
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _cos(double x) => _sin(x + 1.5707963267948966);

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  static double _atan(double x) {
    // Taylor series for atan
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atan(1 / x);
    }
    double result = x;
    double term = x;
    for (int i = 1; i < 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  /// 是否在指定位置的指定范围内（米）
  bool isWithinRange(TransactionLocation other, double rangeMeters) {
    return distanceTo(other) <= rangeMeters;
  }

  TransactionLocation copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    String? address,
    LocationType? locationType,
    String? city,
    String? district,
    String? poiId,
    double? accuracy,
    DateTime? capturedAt,
  }) {
    return TransactionLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      address: address ?? this.address,
      locationType: locationType ?? this.locationType,
      city: city ?? this.city,
      district: district ?? this.district,
      poiId: poiId ?? this.poiId,
      accuracy: accuracy ?? this.accuracy,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'address': address,
      'locationType': locationType?.index,
      'city': city,
      'district': district,
      'poiId': poiId,
      'accuracy': accuracy,
      'capturedAt': capturedAt?.millisecondsSinceEpoch,
    };
  }

  factory TransactionLocation.fromMap(Map<String, dynamic> map) {
    return TransactionLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      placeName: map['placeName'] as String?,
      address: map['address'] as String?,
      locationType: map['locationType'] != null
          ? LocationType.values[map['locationType'] as int]
          : null,
      city: map['city'] as String?,
      district: map['district'] as String?,
      poiId: map['poiId'] as String?,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      capturedAt: map['capturedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['capturedAt'] as int)
          : null,
    );
  }

  @override
  String toString() {
    return 'TransactionLocation(lat: $latitude, lng: $longitude, place: $placeName)';
  }
}

/// 常用位置（保存用户常去的消费地点）
class FrequentLocation {
  final String id;
  final TransactionLocation location;
  final int visitCount;             // 访问次数
  final double totalSpent;          // 在此地总消费
  final String? defaultCategory;    // 默认分类
  final String? defaultVaultId;     // 默认小金库
  final DateTime lastVisitAt;       // 最后访问时间
  final DateTime createdAt;

  const FrequentLocation({
    required this.id,
    required this.location,
    required this.visitCount,
    required this.totalSpent,
    this.defaultCategory,
    this.defaultVaultId,
    required this.lastVisitAt,
    required this.createdAt,
  });

  /// 平均每次消费金额
  double get averageSpent => visitCount > 0 ? totalSpent / visitCount : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      ...location.toMap(),
      'visitCount': visitCount,
      'totalSpent': totalSpent,
      'defaultCategory': defaultCategory,
      'defaultVaultId': defaultVaultId,
      'lastVisitAt': lastVisitAt.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory FrequentLocation.fromMap(Map<String, dynamic> map) {
    return FrequentLocation(
      id: map['id'] as String,
      location: TransactionLocation.fromMap(map),
      visitCount: map['visitCount'] as int,
      totalSpent: (map['totalSpent'] as num).toDouble(),
      defaultCategory: map['defaultCategory'] as String?,
      defaultVaultId: map['defaultVaultId'] as String?,
      lastVisitAt: DateTime.fromMillisecondsSinceEpoch(map['lastVisitAt'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// 地理围栏（用于位置智能化提醒）
class GeoFence {
  final String id;
  final String name;
  final TransactionLocation center;   // 中心点
  final double radiusMeters;          // 半径（米）
  final GeoFenceAction action;        // 触发动作
  final String? linkedVaultId;        // 关联小金库
  final String? linkedCategoryId;     // 关联分类
  final double? budgetLimit;          // 预算限制
  final bool isEnabled;
  final DateTime createdAt;

  const GeoFence({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusMeters,
    required this.action,
    this.linkedVaultId,
    this.linkedCategoryId,
    this.budgetLimit,
    this.isEnabled = true,
    required this.createdAt,
  });

  /// 检查位置是否在围栏内
  bool containsLocation(TransactionLocation location) {
    return center.isWithinRange(location, radiusMeters);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'centerLatitude': center.latitude,
      'centerLongitude': center.longitude,
      'centerPlaceName': center.placeName,
      'radiusMeters': radiusMeters,
      'action': action.index,
      'linkedVaultId': linkedVaultId,
      'linkedCategoryId': linkedCategoryId,
      'budgetLimit': budgetLimit,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory GeoFence.fromMap(Map<String, dynamic> map) {
    return GeoFence(
      id: map['id'] as String,
      name: map['name'] as String,
      center: TransactionLocation(
        latitude: (map['centerLatitude'] as num).toDouble(),
        longitude: (map['centerLongitude'] as num).toDouble(),
        placeName: map['centerPlaceName'] as String?,
      ),
      radiusMeters: (map['radiusMeters'] as num).toDouble(),
      action: GeoFenceAction.values[map['action'] as int],
      linkedVaultId: map['linkedVaultId'] as String?,
      linkedCategoryId: map['linkedCategoryId'] as String?,
      budgetLimit: (map['budgetLimit'] as num?)?.toDouble(),
      isEnabled: map['isEnabled'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// 地理围栏触发动作
enum GeoFenceAction {
  /// 提醒预算状态
  remindBudget,

  /// 自动设置分类
  autoCategory,

  /// 自动关联小金库
  autoVault,

  /// 触发冲动消费防护
  impulseGuard,

  /// 记录位置
  logLocation,
}

extension GeoFenceActionExtension on GeoFenceAction {
  String get displayName {
    switch (this) {
      case GeoFenceAction.remindBudget:
        return '提醒预算';
      case GeoFenceAction.autoCategory:
        return '自动分类';
      case GeoFenceAction.autoVault:
        return '自动小金库';
      case GeoFenceAction.impulseGuard:
        return '冲动防护';
      case GeoFenceAction.logLocation:
        return '记录位置';
    }
  }

  String get description {
    switch (this) {
      case GeoFenceAction.remindBudget:
        return '进入区域时提醒当前预算状态';
      case GeoFenceAction.autoCategory:
        return '在此区域消费自动设置分类';
      case GeoFenceAction.autoVault:
        return '在此区域消费自动关联小金库';
      case GeoFenceAction.impulseGuard:
        return '进入高消费区域触发防护提醒';
      case GeoFenceAction.logLocation:
        return '自动记录消费位置';
    }
  }
}
