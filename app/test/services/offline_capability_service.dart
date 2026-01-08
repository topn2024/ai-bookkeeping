/// 测试用离线能力服务
///
/// 此文件仅用于测试目的，提供离线功能的模拟实现
library;

/// 网络状态枚举
enum NetworkStatus {
  /// 在线状态
  online,

  /// 离线状态
  offline,

  /// 弱网状态
  weak,
}

/// 离线级别枚举
enum OfflineLevel {
  /// L0: 完全离线可用
  fullOffline,

  /// L1: 增强离线（降级可用）
  enhancedOffline,

  /// L2: 在线优先（缓存可用）
  onlinePreferred,

  /// L3: 仅在线
  onlineOnly,
}

/// 网络状态信息
class NetworkStatusInfo {
  final NetworkStatus status;
  final DateTime timestamp;
  final Duration? latency;

  NetworkStatusInfo({
    required this.status,
    required this.timestamp,
    this.latency,
  });
}

/// 功能能力配置
class FeatureCapability {
  final String featureId;
  final OfflineLevel offlineLevel;
  final String? degradationHint;
  final bool requiresSync;

  const FeatureCapability({
    required this.featureId,
    required this.offlineLevel,
    this.degradationHint,
    this.requiresSync = false,
  });
}

/// 离线能力服务
///
/// 管理应用的离线功能能力
class OfflineCapabilityService {
  /// 功能能力配置映射
  static const Map<String, FeatureCapability> _capabilities = {
    // L0: 完全离线可用的功能
    'manual_transaction': FeatureCapability(
      featureId: 'manual_transaction',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'transaction_list': FeatureCapability(
      featureId: 'transaction_list',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'budget_setting': FeatureCapability(
      featureId: 'budget_setting',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'budget_execution': FeatureCapability(
      featureId: 'budget_execution',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'money_age_calculate': FeatureCapability(
      featureId: 'money_age_calculate',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'money_age_display': FeatureCapability(
      featureId: 'money_age_display',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'money_age_trend': FeatureCapability(
      featureId: 'money_age_trend',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'basic_report': FeatureCapability(
      featureId: 'basic_report',
      offlineLevel: OfflineLevel.fullOffline,
    ),
    'data_export': FeatureCapability(
      featureId: 'data_export',
      offlineLevel: OfflineLevel.fullOffline,
    ),

    // L1: 增强离线（降级可用）
    'voice_input': FeatureCapability(
      featureId: 'voice_input',
      offlineLevel: OfflineLevel.enhancedOffline,
      degradationHint: '使用本地语音识别，精度可能降低',
    ),
    'image_ocr': FeatureCapability(
      featureId: 'image_ocr',
      offlineLevel: OfflineLevel.enhancedOffline,
      degradationHint: '使用本地OCR模型，识别速度可能较慢',
    ),
    'smart_category': FeatureCapability(
      featureId: 'smart_category',
      offlineLevel: OfflineLevel.enhancedOffline,
      degradationHint: '使用规则引擎分类，准确率可能降低',
    ),

    // L2: 在线优先（缓存可用）
    'ai_insight': FeatureCapability(
      featureId: 'ai_insight',
      offlineLevel: OfflineLevel.onlinePreferred,
      degradationHint: '显示缓存的洞察内容',
    ),
    'family_sync': FeatureCapability(
      featureId: 'family_sync',
      offlineLevel: OfflineLevel.onlinePreferred,
      degradationHint: '变更已保存，将在联网后同步',
      requiresSync: true,
    ),

    // L3: 仅在线
    'ai_chat': FeatureCapability(
      featureId: 'ai_chat',
      offlineLevel: OfflineLevel.onlineOnly,
    ),
    'cloud_backup': FeatureCapability(
      featureId: 'cloud_backup',
      offlineLevel: OfflineLevel.onlineOnly,
    ),
  };

  /// 当前网络状态
  NetworkStatus _currentStatus = NetworkStatus.online;

  /// 设置网络状态（测试用）
  void setNetworkStatus(NetworkStatus status) {
    _currentStatus = status;
  }

  /// 获取当前网络状态
  NetworkStatus get currentStatus => _currentStatus;

  /// 检查功能是否可用
  bool isFeatureAvailable(String featureId) {
    final capability = _capabilities[featureId];
    if (capability == null) return false;

    switch (_currentStatus) {
      case NetworkStatus.online:
        return true;
      case NetworkStatus.weak:
        return capability.offlineLevel != OfflineLevel.onlineOnly;
      case NetworkStatus.offline:
        return capability.offlineLevel != OfflineLevel.onlineOnly;
    }
  }

  /// 检查功能是否处于降级状态
  bool isFeatureDegraded(String featureId) {
    if (_currentStatus == NetworkStatus.online) return false;

    final capability = _capabilities[featureId];
    if (capability == null) return true;

    return capability.offlineLevel == OfflineLevel.enhancedOffline ||
        capability.offlineLevel == OfflineLevel.onlinePreferred;
  }

  /// 获取功能能力配置
  FeatureCapability? getFeatureCapability(String featureId) {
    return _capabilities[featureId];
  }

  /// 获取功能降级提示
  String? getFeatureDegradationHint(String featureId) {
    final capability = _capabilities[featureId];
    return capability?.degradationHint;
  }

  /// 获取所有支持离线的功能
  List<String> getOfflineCapableFeatures() {
    return _capabilities.entries
        .where((e) => e.value.offlineLevel != OfflineLevel.onlineOnly)
        .map((e) => e.key)
        .toList();
  }

  /// 获取需要同步的功能
  List<String> getFeaturesRequiringSync() {
    return _capabilities.entries
        .where((e) => e.value.requiresSync)
        .map((e) => e.key)
        .toList();
  }
}
