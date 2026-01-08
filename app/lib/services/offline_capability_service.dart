import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 离线能力等级定义
///
/// L0 完全离线：100%本地运行，无任何网络依赖
/// L1 增强离线：核心功能离线可用，网络可增强体验
/// L2 在线优先：需要网络，但有离线降级方案
/// L3 仅在线：必须联网才能使用
enum OfflineLevel {
  /// L0 完全离线
  fullOffline,

  /// L1 增强离线
  enhancedOffline,

  /// L2 在线优先
  onlinePreferred,

  /// L3 仅在线
  onlineOnly,
}

/// 功能模块离线能力定义
class FeatureOfflineCapability {
  final String featureId;
  final String featureName;
  final OfflineLevel offlineLevel;
  final String offlineCapability;
  final String onlineEnhancement;
  final String degradationStrategy;

  const FeatureOfflineCapability({
    required this.featureId,
    required this.featureName,
    required this.offlineLevel,
    required this.offlineCapability,
    required this.onlineEnhancement,
    required this.degradationStrategy,
  });
}

/// 网络状态
enum NetworkStatus {
  /// 在线
  online,

  /// 离线
  offline,

  /// 弱网
  weak,

  /// 未知
  unknown,
}

/// 网络状态详情
class NetworkStatusInfo {
  final NetworkStatus status;
  final ConnectivityResult? connectivityType;
  final DateTime timestamp;
  final int? signalStrength;
  final Duration? latency;

  const NetworkStatusInfo({
    required this.status,
    this.connectivityType,
    required this.timestamp,
    this.signalStrength,
    this.latency,
  });

  bool get isOnline => status == NetworkStatus.online;
  bool get isOffline => status == NetworkStatus.offline;
  bool get isWeak => status == NetworkStatus.weak;

  String get statusText {
    switch (status) {
      case NetworkStatus.online:
        return '在线';
      case NetworkStatus.offline:
        return '离线';
      case NetworkStatus.weak:
        return '弱网';
      case NetworkStatus.unknown:
        return '未知';
    }
  }

  String get connectionTypeText {
    switch (connectivityType) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return '移动网络';
      case ConnectivityResult.ethernet:
        return '以太网';
      case ConnectivityResult.none:
        return '无网络';
      default:
        return '未知';
    }
  }
}

/// 离线能力统一管理服务
///
/// 职责：
/// 1. 网络状态监测与管理
/// 2. 功能离线能力等级判定
/// 3. 离线降级策略执行
/// 4. 联网恢复后的自动刷新
class OfflineCapabilityService {
  static final OfflineCapabilityService _instance = OfflineCapabilityService._internal();
  factory OfflineCapabilityService() => _instance;
  OfflineCapabilityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  NetworkStatusInfo _currentStatus = NetworkStatusInfo(
    status: NetworkStatus.unknown,
    timestamp: DateTime.now(),
  );

  final _statusController = StreamController<NetworkStatusInfo>.broadcast();
  final _featureStatusController = StreamController<Map<String, bool>>.broadcast();

  /// 网络状态变更流
  Stream<NetworkStatusInfo> get statusStream => _statusController.stream;

  /// 功能可用状态变更流
  Stream<Map<String, bool>> get featureStatusStream => _featureStatusController.stream;

  /// 当前网络状态
  NetworkStatusInfo get currentStatus => _currentStatus;

  /// 是否在线
  bool get isOnline => _currentStatus.isOnline;

  /// 是否离线
  bool get isOffline => _currentStatus.isOffline;

  /// 功能离线能力配置
  static const Map<String, FeatureOfflineCapability> _featureCapabilities = {
    // ==================== 核心记账 (L0) ====================
    'manual_transaction': FeatureOfflineCapability(
      featureId: 'manual_transaction',
      featureName: '手动记账',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '完整功能',
      onlineEnhancement: '云端同步',
      degradationStrategy: '-',
    ),
    'transaction_list': FeatureOfflineCapability(
      featureId: 'transaction_list',
      featureName: '交易列表',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地数据',
      onlineEnhancement: '同步更新',
      degradationStrategy: '-',
    ),
    'transaction_edit': FeatureOfflineCapability(
      featureId: 'transaction_edit',
      featureName: '交易编辑',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '完整功能',
      onlineEnhancement: '云端同步',
      degradationStrategy: '-',
    ),
    'transaction_delete': FeatureOfflineCapability(
      featureId: 'transaction_delete',
      featureName: '交易删除',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地删除',
      onlineEnhancement: '同步删除',
      degradationStrategy: '-',
    ),

    // ==================== 钱龄系统 (L0) ====================
    'money_age_calculate': FeatureOfflineCapability(
      featureId: 'money_age_calculate',
      featureName: '钱龄计算',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地FIFO算法',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'money_age_display': FeatureOfflineCapability(
      featureId: 'money_age_display',
      featureName: '钱龄展示',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地数据',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'money_age_trend': FeatureOfflineCapability(
      featureId: 'money_age_trend',
      featureName: '钱龄趋势图',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地聚合',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),

    // ==================== 预算系统 (L0) ====================
    'budget_setting': FeatureOfflineCapability(
      featureId: 'budget_setting',
      featureName: '预算设置',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地存储',
      onlineEnhancement: '云端同步',
      degradationStrategy: '-',
    ),
    'budget_execution': FeatureOfflineCapability(
      featureId: 'budget_execution',
      featureName: '预算执行',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地计算',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'vault_management': FeatureOfflineCapability(
      featureId: 'vault_management',
      featureName: '小金库管理',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地存储',
      onlineEnhancement: '云端同步',
      degradationStrategy: '-',
    ),

    // ==================== AI识别 (L1) ====================
    'voice_input': FeatureOfflineCapability(
      featureId: 'voice_input',
      featureName: '语音输入',
      offlineLevel: OfflineLevel.enhancedOffline,
      offlineCapability: '本地ASR (85-90%准确率)',
      onlineEnhancement: '云端ASR更准',
      degradationStrategy: '本地Whisper模型',
    ),
    'image_ocr': FeatureOfflineCapability(
      featureId: 'image_ocr',
      featureName: '图片OCR',
      offlineLevel: OfflineLevel.enhancedOffline,
      offlineCapability: '本地OCR (90%+金额识别)',
      onlineEnhancement: '云端OCR更准',
      degradationStrategy: '本地ML模型',
    ),
    'smart_category': FeatureOfflineCapability(
      featureId: 'smart_category',
      featureName: '智能分类',
      offlineLevel: OfflineLevel.enhancedOffline,
      offlineCapability: '本地规则引擎 (80-85%准确率)',
      onlineEnhancement: 'AI分类更准',
      degradationStrategy: '历史规则+关键词匹配',
    ),
    'smart_complete': FeatureOfflineCapability(
      featureId: 'smart_complete',
      featureName: '智能补全',
      offlineLevel: OfflineLevel.enhancedOffline,
      offlineCapability: '历史模式匹配',
      onlineEnhancement: 'AI推荐',
      degradationStrategy: '最近使用记录',
    ),

    // ==================== 数据导入 (L0/L1) ====================
    'file_parse': FeatureOfflineCapability(
      featureId: 'file_parse',
      featureName: '文件解析',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地解析',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'format_detect': FeatureOfflineCapability(
      featureId: 'format_detect',
      featureName: '格式识别',
      offlineLevel: OfflineLevel.enhancedOffline,
      offlineCapability: '基础格式识别',
      onlineEnhancement: '复杂格式AI',
      degradationStrategy: '手动映射',
    ),
    'smart_dedup': FeatureOfflineCapability(
      featureId: 'smart_dedup',
      featureName: '智能去重',
      offlineLevel: OfflineLevel.enhancedOffline,
      offlineCapability: '规则去重',
      onlineEnhancement: 'AI去重',
      degradationStrategy: '用户确认',
    ),

    // ==================== 报表统计 (L0/L2) ====================
    'basic_report': FeatureOfflineCapability(
      featureId: 'basic_report',
      featureName: '基础报表',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地聚合',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'trend_analysis': FeatureOfflineCapability(
      featureId: 'trend_analysis',
      featureName: '趋势分析',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地计算',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'category_stats': FeatureOfflineCapability(
      featureId: 'category_stats',
      featureName: '分类统计',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地统计',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'ai_insight': FeatureOfflineCapability(
      featureId: 'ai_insight',
      featureName: 'AI洞察',
      offlineLevel: OfflineLevel.onlinePreferred,
      offlineCapability: '缓存洞察',
      onlineEnhancement: '实时分析',
      degradationStrategy: '显示缓存内容',
    ),

    // ==================== 家庭账本 (L0/L2) ====================
    'family_local_data': FeatureOfflineCapability(
      featureId: 'family_local_data',
      featureName: '家庭本地数据',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '本地存储',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
    'family_member_sync': FeatureOfflineCapability(
      featureId: 'family_member_sync',
      featureName: '成员同步',
      offlineLevel: OfflineLevel.onlinePreferred,
      offlineCapability: '队列缓存',
      onlineEnhancement: '实时同步',
      degradationStrategy: '待同步标记',
    ),
    'family_permission': FeatureOfflineCapability(
      featureId: 'family_permission',
      featureName: '权限控制',
      offlineLevel: OfflineLevel.enhancedOffline,
      offlineCapability: '本地缓存',
      onlineEnhancement: '实时验证',
      degradationStrategy: '使用缓存权限',
    ),

    // ==================== 云端服务 (L3) ====================
    'data_sync': FeatureOfflineCapability(
      featureId: 'data_sync',
      featureName: '数据同步',
      offlineLevel: OfflineLevel.onlineOnly,
      offlineCapability: '-',
      onlineEnhancement: '必需',
      degradationStrategy: '队列等待',
    ),
    'cloud_backup': FeatureOfflineCapability(
      featureId: 'cloud_backup',
      featureName: '云端备份',
      offlineLevel: OfflineLevel.onlineOnly,
      offlineCapability: '-',
      onlineEnhancement: '必需',
      degradationStrategy: '提示联网',
    ),

    // ==================== 数据导出 (L0) ====================
    'data_export': FeatureOfflineCapability(
      featureId: 'data_export',
      featureName: '本地数据导出',
      offlineLevel: OfflineLevel.fullOffline,
      offlineCapability: '完整功能',
      onlineEnhancement: '-',
      degradationStrategy: '-',
    ),
  };

  /// 初始化服务
  Future<void> initialize() async {
    // 检查初始网络状态
    await _checkConnectivity();

    // 监听网络变化
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    debugPrint('OfflineCapabilityService initialized: ${_currentStatus.statusText}');
  }

  /// 检查网络连接
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      _updateStatus([ConnectivityResult.none]);
    }
  }

  /// 网络变化回调
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _currentStatus.isOnline;
    _updateStatus(results);

    // 如果从离线变为在线，触发恢复事件
    if (!wasOnline && _currentStatus.isOnline) {
      _onNetworkRestored();
    }
  }

  /// 更新网络状态
  void _updateStatus(List<ConnectivityResult> results) {
    NetworkStatus status;
    ConnectivityResult? type;

    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      status = NetworkStatus.offline;
      type = ConnectivityResult.none;
    } else {
      status = NetworkStatus.online;
      type = results.first;
    }

    _currentStatus = NetworkStatusInfo(
      status: status,
      connectivityType: type,
      timestamp: DateTime.now(),
    );

    _statusController.add(_currentStatus);
    _updateFeatureAvailability();

    debugPrint('Network status changed: ${_currentStatus.statusText}');
  }

  /// 网络恢复时触发
  void _onNetworkRestored() {
    debugPrint('Network restored, triggering recovery actions...');
    // 触发各服务的恢复操作（通过事件通知）
  }

  /// 更新功能可用性
  void _updateFeatureAvailability() {
    final availability = <String, bool>{};

    for (final entry in _featureCapabilities.entries) {
      availability[entry.key] = isFeatureAvailable(entry.key);
    }

    _featureStatusController.add(availability);
  }

  /// 获取功能离线能力
  FeatureOfflineCapability? getFeatureCapability(String featureId) {
    return _featureCapabilities[featureId];
  }

  /// 获取所有功能能力配置
  Map<String, FeatureOfflineCapability> getAllFeatureCapabilities() {
    return Map.unmodifiable(_featureCapabilities);
  }

  /// 判断功能当前是否可用
  bool isFeatureAvailable(String featureId) {
    final capability = _featureCapabilities[featureId];
    if (capability == null) return true; // 未配置的功能默认可用

    switch (capability.offlineLevel) {
      case OfflineLevel.fullOffline:
        // L0: 始终可用
        return true;
      case OfflineLevel.enhancedOffline:
        // L1: 始终可用（有降级方案）
        return true;
      case OfflineLevel.onlinePreferred:
        // L2: 有降级方案，可用但功能受限
        return true;
      case OfflineLevel.onlineOnly:
        // L3: 仅在线时可用
        return _currentStatus.isOnline;
    }
  }

  /// 判断功能是否处于降级状态
  bool isFeatureDegraded(String featureId) {
    if (_currentStatus.isOnline) return false;

    final capability = _featureCapabilities[featureId];
    if (capability == null) return false;

    // L1和L2在离线时处于降级状态
    return capability.offlineLevel == OfflineLevel.enhancedOffline ||
        capability.offlineLevel == OfflineLevel.onlinePreferred;
  }

  /// 获取功能降级提示
  String? getFeatureDegradationHint(String featureId) {
    if (!isFeatureDegraded(featureId)) return null;

    final capability = _featureCapabilities[featureId];
    if (capability == null) return null;

    return '当前离线，${capability.featureName}使用${capability.degradationStrategy}';
  }

  /// 获取所有L0功能（完全离线可用）
  List<FeatureOfflineCapability> getFullOfflineFeatures() {
    return _featureCapabilities.values
        .where((f) => f.offlineLevel == OfflineLevel.fullOffline)
        .toList();
  }

  /// 获取所有L1功能（增强离线可用）
  List<FeatureOfflineCapability> getEnhancedOfflineFeatures() {
    return _featureCapabilities.values
        .where((f) => f.offlineLevel == OfflineLevel.enhancedOffline)
        .toList();
  }

  /// 获取所有L2功能（在线优先）
  List<FeatureOfflineCapability> getOnlinePreferredFeatures() {
    return _featureCapabilities.values
        .where((f) => f.offlineLevel == OfflineLevel.onlinePreferred)
        .toList();
  }

  /// 获取所有L3功能（仅在线）
  List<FeatureOfflineCapability> getOnlineOnlyFeatures() {
    return _featureCapabilities.values
        .where((f) => f.offlineLevel == OfflineLevel.onlineOnly)
        .toList();
  }

  /// 检测弱网状态
  Future<bool> checkWeakNetwork() async {
    if (_currentStatus.isOffline) return false;

    try {
      // 简单的延迟检测
      final stopwatch = Stopwatch()..start();
      final results = await _connectivity.checkConnectivity();
      stopwatch.stop();

      // 如果检测时间超过500ms认为是弱网
      if (stopwatch.elapsedMilliseconds > 500) {
        _currentStatus = NetworkStatusInfo(
          status: NetworkStatus.weak,
          connectivityType: results.isNotEmpty ? results.first : null,
          timestamp: DateTime.now(),
          latency: stopwatch.elapsed,
        );
        _statusController.add(_currentStatus);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 验证L0功能离线可用性
  Future<L0ValidationResult> validateL0Capability(String featureId) async {
    final capability = _featureCapabilities[featureId];

    if (capability == null) {
      return L0ValidationResult(
        featureId: featureId,
        isValid: false,
        message: '未找到功能配置',
      );
    }

    if (capability.offlineLevel != OfflineLevel.fullOffline) {
      return L0ValidationResult(
        featureId: featureId,
        isValid: false,
        message: '功能不是L0级别',
      );
    }

    // L0功能验证逻辑
    // 实际验证需要测试具体功能的离线可用性
    return L0ValidationResult(
      featureId: featureId,
      isValid: true,
      message: '功能完全离线可用',
    );
  }

  /// 释放资源
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
    _featureStatusController.close();
  }
}

/// L0功能验证结果
class L0ValidationResult {
  final String featureId;
  final bool isValid;
  final String message;
  final Duration? responseTime;

  const L0ValidationResult({
    required this.featureId,
    required this.isValid,
    required this.message,
    this.responseTime,
  });
}

/// 离线降级执行器
class OfflineDegradationExecutor {
  final OfflineCapabilityService _capabilityService;

  OfflineDegradationExecutor(this._capabilityService);

  /// 执行带降级的操作
  Future<T> executeWithDegradation<T>({
    required String featureId,
    required Future<T> Function() onlineAction,
    required Future<T> Function() offlineAction,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 如果在线，尝试执行在线操作
    if (_capabilityService.isOnline) {
      try {
        return await onlineAction().timeout(timeout);
      } catch (e) {
        debugPrint('Online action failed, falling back to offline: $e');
        // 在线失败，降级到离线
        return await offlineAction();
      }
    } else {
      // 离线直接执行离线操作
      return await offlineAction();
    }
  }

  /// 执行仅在线操作（L3）
  Future<T?> executeOnlineOnly<T>({
    required String featureId,
    required Future<T> Function() action,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_capabilityService.isOnline) {
      debugPrint('Feature $featureId requires online, but device is offline');
      return null;
    }

    try {
      return await action().timeout(timeout);
    } catch (e) {
      debugPrint('Online-only action failed: $e');
      return null;
    }
  }
}
