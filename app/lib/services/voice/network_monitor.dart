/// 网络监控服务
///
/// 提供主动网络监控和LLM服务可用性检测
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 路由模式
enum RoutingMode {
  /// LLM优先
  llmPreferred,

  /// 规则优先
  rulePreferred,

  /// 仅规则（离线模式）
  ruleOnly,

  /// 离线模式（无网络）
  offline,
}

/// 网络状态
class NetworkStatus {
  /// 是否在线
  final bool isOnline;

  /// LLM服务是否可用
  final bool llmAvailable;

  /// 预估延迟（毫秒）
  final int estimatedLatency;

  /// 推荐的路由模式
  final RoutingMode recommendedMode;

  /// 最后检测时间
  final DateTime lastCheckTime;

  const NetworkStatus({
    required this.isOnline,
    required this.llmAvailable,
    required this.estimatedLatency,
    required this.recommendedMode,
    required this.lastCheckTime,
  });

  /// 未知状态
  factory NetworkStatus.unknown() => NetworkStatus(
        isOnline: false,
        llmAvailable: false,
        estimatedLatency: 0,
        recommendedMode: RoutingMode.ruleOnly,
        lastCheckTime: DateTime.now(),
      );

  /// 检查缓存是否有效
  bool isCacheValid({int validitySeconds = 30}) {
    return DateTime.now().difference(lastCheckTime).inSeconds < validitySeconds;
  }
}

/// 主动网络监控器
///
/// 提前检测网络状态，减少用户等待时间
class ProactiveNetworkMonitor {
  /// 缓存的网络状态
  NetworkStatus _cachedStatus = NetworkStatus.unknown();

  /// 状态变化通知流
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  /// 延迟阈值（毫秒）
  static const int _latencyThresholdMs = 2000;

  /// 缓存有效期（秒）
  static const int _cacheValiditySeconds = 30;

  /// 定时刷新间隔（秒）
  static const int _refreshIntervalSeconds = 60;

  /// 历史延迟记录
  final List<int> _latencyHistory = [];

  /// 最大历史记录数
  static const int _maxLatencyHistory = 10;

  /// 定时器
  Timer? _refreshTimer;

  /// 网络连接订阅
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// LLM可用性检测回调
  Future<bool> Function()? _llmAvailabilityChecker;

  /// LLM延迟测量回调
  Future<int> Function()? _llmLatencyMeasurer;

  /// 连接预热回调
  Future<void> Function()? _connectionWarmer;

  /// 获取缓存的网络状态
  NetworkStatus get cachedStatus => _cachedStatus;

  /// 获取状态变化流
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// 配置回调函数
  void configure({
    Future<bool> Function()? llmAvailabilityChecker,
    Future<int> Function()? llmLatencyMeasurer,
    Future<void> Function()? connectionWarmer,
  }) {
    _llmAvailabilityChecker = llmAvailabilityChecker;
    _llmLatencyMeasurer = llmLatencyMeasurer;
    _connectionWarmer = connectionWarmer;
  }

  /// App启动时完整检测
  Future<void> initializeOnAppStart() async {
    debugPrint('[NetworkMonitor] App启动，开始完整网络检测...');

    // 1. 基础连通性检测
    final isOnline = await _checkConnectivity();

    // 2. LLM服务可用性检测
    bool llmAvailable = false;
    int latency = 0;

    if (isOnline && _llmAvailabilityChecker != null) {
      try {
        llmAvailable = await _llmAvailabilityChecker!();
      } catch (e) {
        debugPrint('[NetworkMonitor] LLM可用性检测失败: $e');
      }
    }

    // 3. 延迟测量
    if (isOnline && llmAvailable && _llmLatencyMeasurer != null) {
      try {
        latency = await _llmLatencyMeasurer!();
        _addLatencyRecord(latency);
      } catch (e) {
        debugPrint('[NetworkMonitor] 延迟测量失败: $e');
      }
    }

    // 4. 更新缓存状态
    _cachedStatus = NetworkStatus(
      isOnline: isOnline,
      llmAvailable: llmAvailable,
      estimatedLatency: latency,
      recommendedMode: _determineMode(isOnline, llmAvailable, latency),
      lastCheckTime: DateTime.now(),
    );

    debugPrint(
        '[NetworkMonitor] 初始化完成: online=$isOnline, llm=$llmAvailable, latency=${latency}ms, mode=${_cachedStatus.recommendedMode.name}');

    // 5. 广播初始状态（让订阅者获取初始值）
    _statusController.add(_cachedStatus);

    // 6. 启动定时刷新
    _startPeriodicRefresh();

    // 7. 监听网络变化
    _listenToNetworkChanges();
  }

  /// 语音按钮按下时快速检测
  Future<NetworkStatus> checkOnVoiceButtonPressed() async {
    debugPrint('[NetworkMonitor] 语音按钮按下，快速检测...');

    // 如果缓存仍然有效，直接返回
    if (_cachedStatus.isCacheValid(validitySeconds: _cacheValiditySeconds)) {
      debugPrint('[NetworkMonitor] 使用缓存状态');
      // 同时在后台预热连接（不阻塞）
      _preheatConnectionAsync();
      return _cachedStatus;
    }

    // 缓存过期，快速增量检测
    final isOnline = await _checkConnectivity();
    if (isOnline != _cachedStatus.isOnline) {
      debugPrint('[NetworkMonitor] 网络状态变化，快速刷新...');
      await _quickRefresh();
    }

    // 预热连接
    _preheatConnectionAsync();

    return _cachedStatus;
  }

  /// 语音识别完成时直接使用缓存（零延迟）
  NetworkStatus getStatusForRouting() {
    return _cachedStatus;
  }

  /// 检查网络连通性
  Future<bool> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('[NetworkMonitor] 连通性检测失败: $e');
      return false;
    }
  }

  /// 快速刷新状态
  Future<void> _quickRefresh() async {
    final isOnline = await _checkConnectivity();

    bool llmAvailable = _cachedStatus.llmAvailable;
    int latency = _cachedStatus.estimatedLatency;

    if (isOnline && _llmAvailabilityChecker != null) {
      try {
        llmAvailable = await _llmAvailabilityChecker!()
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        llmAvailable = false;
      }
    } else if (!isOnline) {
      llmAvailable = false;
    }

    final oldLlmAvailable = _cachedStatus.llmAvailable;
    _cachedStatus = NetworkStatus(
      isOnline: isOnline,
      llmAvailable: llmAvailable,
      estimatedLatency: latency,
      recommendedMode: _determineMode(isOnline, llmAvailable, latency),
      lastCheckTime: DateTime.now(),
    );

    // 如果LLM可用性发生变化，通知监听者
    if (oldLlmAvailable != llmAvailable) {
      debugPrint('[NetworkMonitor] LLM状态变化: $oldLlmAvailable -> $llmAvailable');
      _statusController.add(_cachedStatus);
    }
  }

  /// 预热连接（异步，不阻塞）
  void _preheatConnectionAsync() {
    if (_connectionWarmer != null && _cachedStatus.llmAvailable) {
      unawaited(_connectionWarmer!().catchError((e) {
        debugPrint('[NetworkMonitor] 连接预热失败: $e');
      }));
    }
  }

  /// 添加延迟记录
  void _addLatencyRecord(int latency) {
    _latencyHistory.add(latency);
    if (_latencyHistory.length > _maxLatencyHistory) {
      _latencyHistory.removeAt(0);
    }
  }

  /// 获取平均延迟
  int _getAverageLatency() {
    if (_latencyHistory.isEmpty) return 0;
    final sum = _latencyHistory.reduce((a, b) => a + b);
    return sum ~/ _latencyHistory.length;
  }

  /// 判断推荐模式
  RoutingMode _determineMode(bool isOnline, bool llmAvailable, int latency) {
    if (!isOnline) return RoutingMode.ruleOnly;
    if (!llmAvailable) return RoutingMode.ruleOnly;
    if (latency > _latencyThresholdMs) return RoutingMode.rulePreferred;
    return RoutingMode.llmPreferred;
  }

  /// 启动定时刷新
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: _refreshIntervalSeconds),
      (_) => _quickRefresh(),
    );
  }

  /// 监听网络变化
  void _listenToNetworkChanges() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        final isOnline =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);
        if (isOnline != _cachedStatus.isOnline) {
          debugPrint('[NetworkMonitor] 网络状态变化: $isOnline');
          _quickRefresh();
        }
      },
    );
  }

  /// 释放资源
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
  }

  /// 主动检查LLM连接状态（用户点击悬浮球时调用）
  ///
  /// 返回检查结果，如果LLM不可用会返回 false
  Future<bool> checkLLMAvailability() async {
    debugPrint('[NetworkMonitor] 主动检查LLM连接...');

    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      debugPrint('[NetworkMonitor] 网络不可用');
      _updateStatus(isOnline: false, llmAvailable: false);
      return false;
    }

    if (_llmAvailabilityChecker == null) {
      debugPrint('[NetworkMonitor] 未配置LLM检测器');
      return _cachedStatus.llmAvailable;
    }

    try {
      final llmAvailable = await _llmAvailabilityChecker!()
          .timeout(const Duration(seconds: 3));
      debugPrint('[NetworkMonitor] LLM检查结果: $llmAvailable');
      _updateStatus(isOnline: true, llmAvailable: llmAvailable);
      return llmAvailable;
    } catch (e) {
      debugPrint('[NetworkMonitor] LLM检查失败: $e');
      _updateStatus(isOnline: true, llmAvailable: false);
      return false;
    }
  }

  /// 更新状态并通知
  void _updateStatus({required bool isOnline, required bool llmAvailable}) {
    final oldLlmAvailable = _cachedStatus.llmAvailable;
    _cachedStatus = NetworkStatus(
      isOnline: isOnline,
      llmAvailable: llmAvailable,
      estimatedLatency: _cachedStatus.estimatedLatency,
      recommendedMode: _determineMode(isOnline, llmAvailable, _cachedStatus.estimatedLatency),
      lastCheckTime: DateTime.now(),
    );

    if (oldLlmAvailable != llmAvailable) {
      _statusController.add(_cachedStatus);
    }
  }
}
