/// 公共类型定义
/// 此文件包含在多个服务和页面中共享的通用类型

// ═══════════════════════════════════════════════════════════════
// 序列化工具函数
// ═══════════════════════════════════════════════════════════════

/// 解析 DateTime，兼容 ISO 8601 字符串和毫秒时间戳两种格式
///
/// 用于反序列化时保持向后兼容性
DateTime parseDateTime(dynamic value) {
  if (value == null) {
    throw const FormatException('DateTime value cannot be null');
  }
  if (value is int) {
    // 旧格式：毫秒时间戳
    return DateTime.fromMillisecondsSinceEpoch(value);
  } else if (value is String) {
    // 新格式：ISO 8601 字符串
    return DateTime.parse(value);
  }
  throw FormatException('Invalid DateTime format: $value');
}

/// 解析可空的 DateTime，兼容 ISO 8601 字符串和毫秒时间戳两种格式
DateTime? parseDateTimeOrNull(dynamic value) {
  if (value == null) return null;
  return parseDateTime(value);
}

/// 解析 Enum，兼容 index 整数和 name 字符串两种格式
///
/// [value] - 要解析的值（int 或 String）
/// [values] - Enum 的所有值列表
/// [defaultValue] - 解析失败时的默认值
T parseEnum<T extends Enum>(dynamic value, List<T> values, T defaultValue) {
  if (value == null) return defaultValue;

  if (value is int) {
    // 旧格式：index
    if (value >= 0 && value < values.length) {
      return values[value];
    }
    return defaultValue;
  } else if (value is String) {
    // 新格式：name
    for (final enumValue in values) {
      if (enumValue.name == value) {
        return enumValue;
      }
    }
    return defaultValue;
  }
  return defaultValue;
}

// ═══════════════════════════════════════════════════════════════
// 城市级别枚举
// ═══════════════════════════════════════════════════════════════

/// 城市级别
enum CityTier {
  /// 一线城市（北上广深）
  tier1,

  /// 新一线城市（杭州、成都、武汉等）
  newTier1,

  /// 二线城市
  tier2,

  /// 三线城市
  tier3,

  /// 四线及以下
  tier4Plus,

  /// 海外
  overseas,

  /// 未知
  unknown,
}

/// 城市级别扩展
extension CityTierExtension on CityTier {
  /// 显示名称
  String get displayName {
    switch (this) {
      case CityTier.tier1:
        return '一线城市';
      case CityTier.newTier1:
        return '新一线城市';
      case CityTier.tier2:
        return '二线城市';
      case CityTier.tier3:
        return '三线城市';
      case CityTier.tier4Plus:
        return '四线及以下';
      case CityTier.overseas:
        return '海外';
      case CityTier.unknown:
        return '未知';
    }
  }

  /// 生活成本系数
  double get costOfLivingMultiplier {
    switch (this) {
      case CityTier.tier1:
        return 1.5;
      case CityTier.newTier1:
        return 1.3;
      case CityTier.tier2:
        return 1.1;
      case CityTier.tier3:
        return 1.0;
      case CityTier.tier4Plus:
        return 0.85;
      case CityTier.overseas:
        return 2.0;
      case CityTier.unknown:
        return 1.0;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 金额范围
// ═══════════════════════════════════════════════════════════════

/// 金额范围
class AmountRange {
  final double min;
  final double max;
  final String? label;

  const AmountRange({
    required this.min,
    required this.max,
    this.label,
  });

  /// 检查金额是否在范围内
  bool contains(double amount) => amount >= min && amount <= max;

  /// 获取中间值
  double get midpoint => (min + max) / 2;

  @override
  String toString() => label ?? '¥${min.toStringAsFixed(0)}-¥${max.toStringAsFixed(0)}';
}

// ═══════════════════════════════════════════════════════════════
// 城市信息
// ═══════════════════════════════════════════════════════════════

/// 城市信息
class CityInfo {
  final String code;
  final String name;
  final String province;
  final CityTier tier;
  final double latitude;
  final double longitude;

  const CityInfo({
    required this.code,
    required this.name,
    required this.province,
    required this.tier,
    required this.latitude,
    required this.longitude,
  });
}

/// 城市位置（用于位置服务）
class CityLocation {
  final String name;
  final String code;
  final CityTier tier;
  final double? latitude;
  final double? longitude;
  final String? province;

  const CityLocation({
    required this.name,
    required this.code,
    required this.tier,
    this.latitude,
    this.longitude,
    this.province,
  });

  /// 从CityInfo转换
  factory CityLocation.fromCityInfo(CityInfo info) {
    return CityLocation(
      name: info.name,
      code: info.code,
      tier: info.tier,
      latitude: info.latitude,
      longitude: info.longitude,
      province: info.province,
    );
  }
}
