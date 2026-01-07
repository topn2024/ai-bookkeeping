import '../models/budget_vault.dart';
import 'vault_repository.dart';

/// 位置类型
enum LocationType {
  /// 购物商圈
  shopping,

  /// 餐饮区域
  restaurant,

  /// 超市
  supermarket,

  /// 娱乐场所
  entertainment,

  /// 交通枢纽
  transport,

  /// 居住区
  residential,

  /// 办公区
  office,

  /// 未知
  unknown,
}

extension LocationTypeExtension on LocationType {
  String get displayName {
    switch (this) {
      case LocationType.shopping:
        return '购物区';
      case LocationType.restaurant:
        return '餐饮区';
      case LocationType.supermarket:
        return '超市';
      case LocationType.entertainment:
        return '娱乐区';
      case LocationType.transport:
        return '交通枢纽';
      case LocationType.residential:
        return '居住区';
      case LocationType.office:
        return '办公区';
      case LocationType.unknown:
        return '未知区域';
    }
  }

  /// 关联的消费类型关键词
  List<String> get relatedKeywords {
    switch (this) {
      case LocationType.shopping:
        return ['购物', '服装', '数码', '商场', '娱乐'];
      case LocationType.restaurant:
        return ['餐饮', '美食', '外卖', '饮料'];
      case LocationType.supermarket:
        return ['日用', '生活', '超市', '食品'];
      case LocationType.entertainment:
        return ['娱乐', '电影', '游戏', '运动'];
      case LocationType.transport:
        return ['交通', '出行', '打车'];
      default:
        return [];
    }
  }
}

/// 位置坐标
class Location {
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;

  const Location({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });

  /// 计算两点间距离（米）
  double distanceTo(Location other) {
    const earthRadius = 6371000.0; // 地球半径（米）
    final lat1 = latitude * 3.14159265359 / 180;
    final lat2 = other.latitude * 3.14159265359 / 180;
    final dLat = (other.latitude - latitude) * 3.14159265359 / 180;
    final dLon = (other.longitude - longitude) * 3.14159265359 / 180;

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1) * _cos(lat2) * _sin(dLon / 2) * _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  // 简化的三角函数实现
  double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (var i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0;
  }
  double _atan(double x) => x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
}

/// 地理围栏区域
class Geofence {
  final String id;
  final String name;
  final Location center;
  final double radiusMeters;
  final LocationType type;
  final bool isActive;

  const Geofence({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusMeters,
    required this.type,
    this.isActive = true,
  });

  /// 检查位置是否在围栏内
  bool containsLocation(Location location) {
    return center.distanceTo(location) <= radiusMeters;
  }
}

/// 地理围栏事件
class GeofenceEvent {
  final String geofenceId;
  final Location location;
  final GeofenceEventType eventType;
  final DateTime timestamp;
  final LocationType locationType;

  const GeofenceEvent({
    required this.geofenceId,
    required this.location,
    required this.eventType,
    required this.timestamp,
    required this.locationType,
  });
}

/// 围栏事件类型
enum GeofenceEventType {
  /// 进入围栏
  enter,

  /// 离开围栏
  exit,

  /// 在围栏内停留
  dwell,
}

/// 通知类别
enum NotificationCategory {
  /// 预算提醒
  budgetReminder,

  /// 超支警告
  overspentWarning,

  /// 低余额提示
  lowBalance,

  /// 消费建议
  spendingSuggestion,
}

/// 通知服务接口
abstract class NotificationService {
  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    Map<String, dynamic>? data,
  });

  Future<void> cancel(String id);
}

/// 地理围栏服务接口
abstract class GeofenceService {
  Future<LocationType> getLocationType(Location location);
  Future<List<Geofence>> getActiveGeofences();
  Future<void> registerGeofence(Geofence geofence);
  Future<void> unregisterGeofence(String geofenceId);
}

/// 预算提醒配置
class BudgetReminderConfig {
  final bool enableLocationReminders;
  final bool enableLowBalanceAlert;
  final bool enableOverspentAlert;
  final double lowBalanceThreshold; // 低余额阈值（占比）
  final List<LocationType> monitoredLocationTypes;
  final int quietHoursStart; // 免打扰开始时间（小时）
  final int quietHoursEnd; // 免打扰结束时间（小时）

  const BudgetReminderConfig({
    this.enableLocationReminders = true,
    this.enableLowBalanceAlert = true,
    this.enableOverspentAlert = true,
    this.lowBalanceThreshold = 0.2,
    this.monitoredLocationTypes = const [
      LocationType.shopping,
      LocationType.restaurant,
      LocationType.entertainment,
    ],
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
  });

  /// 检查当前是否在免打扰时段
  bool get isQuietHours {
    final hour = DateTime.now().hour;
    if (quietHoursStart < quietHoursEnd) {
      return hour >= quietHoursStart && hour < quietHoursEnd;
    } else {
      return hour >= quietHoursStart || hour < quietHoursEnd;
    }
  }
}

/// 地理围栏触发的预算提醒服务
///
/// 当用户进入商圈、餐饮区等高消费区域时，
/// 自动推送相关小金库的预算状态提醒
class LocationBudgetReminder {
  final VaultRepository _vaultRepo;
  final GeofenceService? _geofenceService;
  final NotificationService? _notificationService;

  BudgetReminderConfig _config;

  // 提醒历史记录（避免重复提醒）
  final Map<String, DateTime> _lastReminderTimes = {};
  static const _reminderCooldownMinutes = 60; // 同一区域提醒间隔

  LocationBudgetReminder(
    this._vaultRepo, [
    this._geofenceService,
    this._notificationService,
    BudgetReminderConfig? config,
  ]) : _config = config ?? const BudgetReminderConfig();

  /// 更新配置
  void updateConfig(BudgetReminderConfig config) {
    _config = config;
  }

  /// 进入商圈时推送预算状态
  Future<BudgetReminderResult> onEnterShoppingArea(GeofenceEvent event) async {
    // 检查是否启用位置提醒
    if (!_config.enableLocationReminders) {
      return BudgetReminderResult.disabled();
    }

    // 检查免打扰时段
    if (_config.isQuietHours) {
      return BudgetReminderResult.quietHours();
    }

    // 检查是否在监控的位置类型中
    if (!_config.monitoredLocationTypes.contains(event.locationType)) {
      return BudgetReminderResult.notMonitored();
    }

    // 检查冷却时间
    if (_isInCooldown(event.geofenceId)) {
      return BudgetReminderResult.cooldown();
    }

    // 获取与该区域相关的小金库
    final relevantVaults = await _getVaultsForLocation(event.locationType);

    if (relevantVaults.isEmpty) {
      return BudgetReminderResult.noRelevantVaults();
    }

    // 生成提醒消息
    final messages = <String>[];
    final vaultStatuses = <VaultReminderStatus>[];

    for (final vault in relevantVaults) {
      final status = _getVaultStatusMessage(vault);
      if (status != null) {
        messages.add(status.message);
        vaultStatuses.add(status);
      }
    }

    if (messages.isEmpty) {
      return BudgetReminderResult.allHealthy(relevantVaults);
    }

    // 发送通知
    if (_notificationService != null) {
      await _notificationService!.show(
        title: '预算提醒 - ${event.locationType.displayName}',
        body: messages.join('\n'),
        category: _determineNotificationCategory(vaultStatuses),
        data: {
          'geofenceId': event.geofenceId,
          'locationType': event.locationType.index,
          'vaultIds': relevantVaults.map((v) => v.id).toList(),
        },
      );
    }

    // 记录提醒时间
    _lastReminderTimes[event.geofenceId] = DateTime.now();

    return BudgetReminderResult.success(
      messages: messages,
      vaultStatuses: vaultStatuses,
      relevantVaults: relevantVaults,
    );
  }

  /// 主动检查当前位置的预算状态
  Future<LocationBudgetStatus> checkBudgetAtLocation(Location location) async {
    // 获取位置类型
    LocationType locationType = LocationType.unknown;
    if (_geofenceService != null) {
      locationType = await _geofenceService!.getLocationType(location);
    }

    // 获取相关小金库
    final relevantVaults = await _getVaultsForLocation(locationType);
    final allVaults = await _vaultRepo.getEnabled();

    // 计算总体状态
    final overspentVaults = relevantVaults.where((v) => v.isOverSpent).toList();
    final lowBalanceVaults = relevantVaults
        .where((v) => v.usageRate > (1 - _config.lowBalanceThreshold))
        .toList();

    return LocationBudgetStatus(
      location: location,
      locationType: locationType,
      relevantVaults: relevantVaults,
      overspentVaults: overspentVaults,
      lowBalanceVaults: lowBalanceVaults,
      totalAvailableBudget: relevantVaults.fold(0.0, (sum, v) => sum + v.available),
      overallHealthScore: _calculateHealthScore(relevantVaults),
      suggestions: _generateLocationSuggestions(
        locationType,
        relevantVaults,
        allVaults,
      ),
    );
  }

  /// 获取高消费区域的预算预警
  Future<List<HighSpendingAreaWarning>> getHighSpendingAreaWarnings() async {
    final warnings = <HighSpendingAreaWarning>[];
    final vaults = await _vaultRepo.getEnabled();

    // 检查各类型区域的相关预算
    for (final locationType in _config.monitoredLocationTypes) {
      final relevantVaults = vaults.where((v) {
        final keywords = locationType.relatedKeywords;
        return keywords.any((keyword) =>
            v.name.contains(keyword) ||
            (v.categoryId?.contains(keyword) ?? false));
      }).toList();

      if (relevantVaults.isEmpty) continue;

      final overspentCount = relevantVaults.where((v) => v.isOverSpent).length;
      final lowBalanceCount = relevantVaults
          .where((v) => v.usageRate > (1 - _config.lowBalanceThreshold))
          .length;

      if (overspentCount > 0 || lowBalanceCount > 0) {
        warnings.add(HighSpendingAreaWarning(
          locationType: locationType,
          relevantVaults: relevantVaults,
          overspentCount: overspentCount,
          lowBalanceCount: lowBalanceCount,
          totalAvailable: relevantVaults.fold(0.0, (sum, v) => sum + v.available),
          warningLevel: overspentCount > 0
              ? WarningLevel.critical
              : WarningLevel.warning,
        ));
      }
    }

    // 按警告级别排序
    warnings.sort((a, b) => b.warningLevel.index.compareTo(a.warningLevel.index));

    return warnings;
  }

  /// 注册常用消费区域的地理围栏
  Future<void> registerCommonGeofences(List<CommonLocation> locations) async {
    if (_geofenceService == null) return;

    for (final location in locations) {
      final geofence = Geofence(
        id: 'common_${location.name}_${location.center.latitude}_${location.center.longitude}',
        name: location.name,
        center: location.center,
        radiusMeters: location.radiusMeters,
        type: location.type,
      );

      await _geofenceService!.registerGeofence(geofence);
    }
  }

  // ==================== 私有方法 ====================

  /// 获取与位置类型相关的小金库
  Future<List<BudgetVault>> _getVaultsForLocation(LocationType locationType) async {
    final allVaults = await _vaultRepo.getEnabled();
    final keywords = locationType.relatedKeywords;

    if (keywords.isEmpty) return [];

    return allVaults.where((v) {
      // 通过名称匹配
      if (keywords.any((keyword) => v.name.contains(keyword))) {
        return true;
      }

      // 通过分类ID匹配
      if (v.categoryId != null) {
        if (keywords.any((keyword) => v.categoryId!.contains(keyword))) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  /// 获取小金库状态消息
  VaultReminderStatus? _getVaultStatusMessage(BudgetVault vault) {
    if (vault.isOverSpent) {
      return VaultReminderStatus(
        vault: vault,
        status: VaultAlertStatus.overspent,
        message: '⚠️ ${vault.name}已超支¥${(-vault.available).toStringAsFixed(0)}',
      );
    } else if (vault.usageRate > (1 - _config.lowBalanceThreshold)) {
      return VaultReminderStatus(
        vault: vault,
        status: VaultAlertStatus.lowBalance,
        message: '💡 ${vault.name}剩余¥${vault.available.toStringAsFixed(0)}',
      );
    } else if (vault.usageRate > 0.6) {
      return VaultReminderStatus(
        vault: vault,
        status: VaultAlertStatus.moderate,
        message: '📊 ${vault.name}已用${(vault.usageRate * 100).toStringAsFixed(0)}%',
      );
    }

    return null;
  }

  /// 检查是否在冷却时间内
  bool _isInCooldown(String geofenceId) {
    final lastTime = _lastReminderTimes[geofenceId];
    if (lastTime == null) return false;

    final elapsed = DateTime.now().difference(lastTime).inMinutes;
    return elapsed < _reminderCooldownMinutes;
  }

  /// 确定通知类别
  NotificationCategory _determineNotificationCategory(
    List<VaultReminderStatus> statuses,
  ) {
    if (statuses.any((s) => s.status == VaultAlertStatus.overspent)) {
      return NotificationCategory.overspentWarning;
    }
    if (statuses.any((s) => s.status == VaultAlertStatus.lowBalance)) {
      return NotificationCategory.lowBalance;
    }
    return NotificationCategory.budgetReminder;
  }

  /// 计算健康分数（0-100）
  double _calculateHealthScore(List<BudgetVault> vaults) {
    if (vaults.isEmpty) return 100;

    double totalScore = 0;
    for (final vault in vaults) {
      if (vault.isOverSpent) {
        totalScore += 0;
      } else if (vault.usageRate > 0.9) {
        totalScore += 30;
      } else if (vault.usageRate > 0.7) {
        totalScore += 60;
      } else {
        totalScore += 100;
      }
    }

    return totalScore / vaults.length;
  }

  /// 生成位置相关建议
  List<String> _generateLocationSuggestions(
    LocationType locationType,
    List<BudgetVault> relevantVaults,
    List<BudgetVault> allVaults,
  ) {
    final suggestions = <String>[];

    // 检查是否有超支
    final overspentVaults = relevantVaults.where((v) => v.isOverSpent);
    if (overspentVaults.isNotEmpty) {
      suggestions.add('建议减少在${locationType.displayName}的消费');
    }

    // 检查是否有余额充足的替代小金库
    final healthyVaults = allVaults
        .where((v) => v.status == VaultStatus.healthy && v.usageRate < 0.5)
        .toList();

    if (healthyVaults.isNotEmpty && overspentVaults.isNotEmpty) {
      suggestions.add('可以考虑从"${healthyVaults.first.name}"调拨资金');
    }

    // 根据时间给出建议
    final now = DateTime.now();
    final daysRemaining = DateTime(now.year, now.month + 1, 0).day - now.day;

    if (daysRemaining < 7) {
      final totalAvailable = relevantVaults.fold(0.0, (sum, v) => sum + v.available);
      suggestions.add('本月还剩$daysRemaining天，相关预算剩余¥${totalAvailable.toStringAsFixed(0)}');
    }

    return suggestions;
  }
}

/// 预算提醒结果
class BudgetReminderResult {
  final bool success;
  final String? reason;
  final List<String> messages;
  final List<VaultReminderStatus> vaultStatuses;
  final List<BudgetVault> relevantVaults;

  const BudgetReminderResult._({
    required this.success,
    this.reason,
    this.messages = const [],
    this.vaultStatuses = const [],
    this.relevantVaults = const [],
  });

  factory BudgetReminderResult.success({
    required List<String> messages,
    required List<VaultReminderStatus> vaultStatuses,
    required List<BudgetVault> relevantVaults,
  }) {
    return BudgetReminderResult._(
      success: true,
      messages: messages,
      vaultStatuses: vaultStatuses,
      relevantVaults: relevantVaults,
    );
  }

  factory BudgetReminderResult.disabled() {
    return const BudgetReminderResult._(
      success: false,
      reason: '位置提醒已关闭',
    );
  }

  factory BudgetReminderResult.quietHours() {
    return const BudgetReminderResult._(
      success: false,
      reason: '当前为免打扰时段',
    );
  }

  factory BudgetReminderResult.notMonitored() {
    return const BudgetReminderResult._(
      success: false,
      reason: '该位置类型未被监控',
    );
  }

  factory BudgetReminderResult.cooldown() {
    return const BudgetReminderResult._(
      success: false,
      reason: '提醒冷却中',
    );
  }

  factory BudgetReminderResult.noRelevantVaults() {
    return const BudgetReminderResult._(
      success: false,
      reason: '没有相关小金库',
    );
  }

  factory BudgetReminderResult.allHealthy(List<BudgetVault> vaults) {
    return BudgetReminderResult._(
      success: true,
      reason: '所有相关预算状态良好',
      relevantVaults: vaults,
    );
  }
}

/// 小金库提醒状态
class VaultReminderStatus {
  final BudgetVault vault;
  final VaultAlertStatus status;
  final String message;

  const VaultReminderStatus({
    required this.vault,
    required this.status,
    required this.message,
  });
}

/// 小金库警告状态
enum VaultAlertStatus {
  healthy,
  moderate,
  lowBalance,
  overspent,
}

/// 位置预算状态
class LocationBudgetStatus {
  final Location location;
  final LocationType locationType;
  final List<BudgetVault> relevantVaults;
  final List<BudgetVault> overspentVaults;
  final List<BudgetVault> lowBalanceVaults;
  final double totalAvailableBudget;
  final double overallHealthScore;
  final List<String> suggestions;

  const LocationBudgetStatus({
    required this.location,
    required this.locationType,
    required this.relevantVaults,
    required this.overspentVaults,
    required this.lowBalanceVaults,
    required this.totalAvailableBudget,
    required this.overallHealthScore,
    required this.suggestions,
  });

  bool get hasWarnings => overspentVaults.isNotEmpty || lowBalanceVaults.isNotEmpty;
}

/// 高消费区域警告
class HighSpendingAreaWarning {
  final LocationType locationType;
  final List<BudgetVault> relevantVaults;
  final int overspentCount;
  final int lowBalanceCount;
  final double totalAvailable;
  final WarningLevel warningLevel;

  const HighSpendingAreaWarning({
    required this.locationType,
    required this.relevantVaults,
    required this.overspentCount,
    required this.lowBalanceCount,
    required this.totalAvailable,
    required this.warningLevel,
  });
}

/// 警告级别
enum WarningLevel {
  info,
  warning,
  critical,
}

/// 常用消费位置
class CommonLocation {
  final String name;
  final Location center;
  final double radiusMeters;
  final LocationType type;

  const CommonLocation({
    required this.name,
    required this.center,
    required this.radiusMeters,
    required this.type,
  });
}
