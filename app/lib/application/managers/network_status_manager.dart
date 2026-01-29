/// Network Status Manager
///
/// 负责网络状态监控的管理器，从 GlobalVoiceAssistantManager 中提取。
/// 遵循单一职责原则，仅处理网络状态检测和监控。
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 网络状态
enum NetworkStatus {
  /// 在线（WiFi 或移动数据）
  online,

  /// 仅 WiFi
  wifi,

  /// 仅移动数据
  mobile,

  /// 离线
  offline,

  /// 未知
  unknown,
}

/// 网络状态变化事件
class NetworkStatusEvent {
  final NetworkStatus status;
  final NetworkStatus? previousStatus;
  final DateTime timestamp;

  const NetworkStatusEvent({
    required this.status,
    this.previousStatus,
    required this.timestamp,
  });

  bool get becameOnline =>
      previousStatus == NetworkStatus.offline &&
      (status == NetworkStatus.online ||
          status == NetworkStatus.wifi ||
          status == NetworkStatus.mobile);

  bool get becameOffline =>
      previousStatus != NetworkStatus.offline &&
      previousStatus != NetworkStatus.unknown &&
      status == NetworkStatus.offline;
}

/// 网络状态管理器
///
/// 职责：
/// - 监控网络连接状态
/// - 提供网络状态查询
/// - 通知网络状态变化
class NetworkStatusManager extends ChangeNotifier {
  /// Connectivity 实例
  final Connectivity _connectivity;

  /// 当前网络状态
  NetworkStatus _status = NetworkStatus.unknown;

  /// 上一次网络状态
  NetworkStatus? _previousStatus;

  /// 连接监听订阅
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// 事件流控制器
  final StreamController<NetworkStatusEvent> _eventController =
      StreamController<NetworkStatusEvent>.broadcast();

  /// 是否已初始化
  bool _isInitialized = false;

  NetworkStatusManager({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// 当前状态
  NetworkStatus get status => _status;

  /// 是否在线
  bool get isOnline =>
      _status == NetworkStatus.online ||
      _status == NetworkStatus.wifi ||
      _status == NetworkStatus.mobile;

  /// 是否离线
  bool get isOffline => _status == NetworkStatus.offline;

  /// 是否使用 WiFi
  bool get isWifi => _status == NetworkStatus.wifi;

  /// 是否使用移动数据
  bool get isMobile => _status == NetworkStatus.mobile;

  /// 状态变化事件流
  Stream<NetworkStatusEvent> get events => _eventController.stream;

  // ==================== 初始化 ====================

  /// 初始化并开始监控
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 获取初始状态
    await _checkStatus();

    // 监听状态变化
    _subscription = _connectivity.onConnectivityChanged.listen(_onStatusChanged);

    _isInitialized = true;
    debugPrint('[NetworkStatusManager] 初始化完成，当前状态: $_status');
  }

  /// 释放资源
  @override
  void dispose() {
    _subscription?.cancel();
    _eventController.close();
    super.dispose();
  }

  // ==================== 状态查询 ====================

  /// 手动检查网络状态
  Future<NetworkStatus> checkStatus() async {
    await _checkStatus();
    return _status;
  }

  /// 检查是否可以访问指定 URL
  Future<bool> canReach(String url) async {
    // 简单实现：如果在线就认为可达
    // 实际应用中可以做真正的连接测试
    return isOnline;
  }

  // ==================== 私有方法 ====================

  /// 检查状态
  Future<void> _checkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(_mapResults(results));
    } catch (e) {
      debugPrint('[NetworkStatusManager] 检查状态失败: $e');
      _updateStatus(NetworkStatus.unknown);
    }
  }

  /// 状态变化回调
  void _onStatusChanged(List<ConnectivityResult> results) {
    _updateStatus(_mapResults(results));
  }

  /// 映射连接结果到网络状态
  NetworkStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return NetworkStatus.offline;
    }

    // 检查优先级：WiFi > Mobile > Other
    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkStatus.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkStatus.mobile;
    }
    if (results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn)) {
      return NetworkStatus.online;
    }
    if (results.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }

    return NetworkStatus.unknown;
  }

  /// 更新状态
  void _updateStatus(NetworkStatus newStatus) {
    if (_status == newStatus) return;

    _previousStatus = _status;
    _status = newStatus;

    final event = NetworkStatusEvent(
      status: newStatus,
      previousStatus: _previousStatus,
      timestamp: DateTime.now(),
    );

    _eventController.add(event);
    notifyListeners();

    debugPrint('[NetworkStatusManager] 状态变化: $_previousStatus -> $_status');
  }
}
