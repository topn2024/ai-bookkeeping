/// 混合意图路由器
///
/// LLM优先，规则兜底的意图路由策略
///
/// 核心设计：
/// 1. 主动网络监控 - App启动和语音按钮按下时提前检测
/// 2. 零延迟路由决策 - 语音识别完成时直接读取缓存
/// 3. 智能降级策略 - 网络异常时无缝切换到规则引擎
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 路由类型
enum RouteType {
  /// 纯聊天
  chat,

  /// 纯功能操作
  action,

  /// 混合意图（聊天+操作）
  hybrid,

  /// 未知意图
  unknown,
}

/// 路由模式
enum RoutingMode {
  /// LLM优先
  llmPreferred,

  /// 规则优先
  rulePreferred,

  /// 仅规则（离线模式）
  ruleOnly,
}

/// 意图分类
class IntentCategory {
  static const String transaction = 'transaction';
  static const String config = 'config';
  static const String query = 'query';
  static const String navigation = 'navigation';
  static const String chat = 'chat';
}

/// 意图结果
class IntentResult {
  /// 路由类型
  final RouteType type;

  /// 置信度
  final double confidence;

  /// 意图分类
  final String? category;

  /// 具体行为
  final String? action;

  /// 提取的实体
  final Map<String, dynamic> entities;

  /// 情感类型
  final String? emotion;

  /// 聊天响应（如果是聊天或混合类型）
  final String? chatResponse;

  /// 原始输入
  final String rawInput;

  /// 识别来源
  final RecognitionSource source;

  const IntentResult({
    required this.type,
    required this.confidence,
    this.category,
    this.action,
    this.entities = const {},
    this.emotion,
    this.chatResponse,
    required this.rawInput,
    required this.source,
  });

  /// 是否需要执行行为
  bool get hasAction => action != null && action!.isNotEmpty;

  /// 获取完整的意图ID
  String? get intentId {
    if (category == null || action == null) return null;
    return '$category.$action';
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'confidence': confidence,
        'category': category,
        'action': action,
        'entities': entities,
        'emotion': emotion,
        'chatResponse': chatResponse,
        'rawInput': rawInput,
        'source': source.name,
      };

  @override
  String toString() =>
      'IntentResult(type: ${type.name}, action: $action, confidence: ${confidence.toStringAsFixed(2)}, source: ${source.name})';
}

/// 识别来源
enum RecognitionSource {
  llm,
  rule,
  cache,
  hybrid,
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

/// 混合意图路由器
///
/// 实现LLM优先、规则兜底的意图路由策略
class HybridIntentRouter {
  /// 网络监控器
  final ProactiveNetworkMonitor _networkMonitor;

  /// LLM意图分类器
  Future<IntentResult?> Function(String input, String? context)?
      _llmClassifier;

  /// 规则意图分类器
  Future<IntentResult?> Function(String input)? _ruleClassifier;

  /// LLM超时时间
  static const Duration _llmTimeout = Duration(seconds: 3);

  /// 最小置信度阈值
  static const double _minConfidenceThreshold = 0.7;

  /// LLM重试次数
  int _llmRetryCount = 0;

  /// 最大重试次数
  static const int _maxRetries = 1;

  HybridIntentRouter({
    ProactiveNetworkMonitor? networkMonitor,
  }) : _networkMonitor = networkMonitor ?? ProactiveNetworkMonitor();

  /// 获取网络监控器
  ProactiveNetworkMonitor get networkMonitor => _networkMonitor;

  /// 配置分类器
  void configure({
    Future<IntentResult?> Function(String input, String? context)?
        llmClassifier,
    Future<IntentResult?> Function(String input)? ruleClassifier,
  }) {
    _llmClassifier = llmClassifier;
    _ruleClassifier = ruleClassifier;
  }

  /// 路由意图
  ///
  /// [input] 用户输入
  /// [context] 上下文摘要
  Future<IntentResult> route(String input, {String? context}) async {
    if (input.trim().isEmpty) {
      return IntentResult(
        type: RouteType.unknown,
        confidence: 0,
        rawInput: input,
        source: RecognitionSource.rule,
      );
    }

    // 获取网络状态（零延迟，直接读取缓存）
    final networkStatus = _networkMonitor.getStatusForRouting();
    debugPrint(
        '[HybridRouter] 路由模式: ${networkStatus.recommendedMode.name}');

    // 根据推荐模式选择路由策略
    switch (networkStatus.recommendedMode) {
      case RoutingMode.llmPreferred:
        return _routeWithLLMFirst(input, context);

      case RoutingMode.rulePreferred:
        return _routeWithRuleFirst(input, context);

      case RoutingMode.ruleOnly:
        return _routeWithRulesOnly(input);
    }
  }

  /// LLM优先路由
  Future<IntentResult> _routeWithLLMFirst(
      String input, String? context) async {
    if (_llmClassifier == null) {
      return _routeWithRulesOnly(input);
    }

    try {
      // 尝试LLM路由（带超时）
      final llmResult = await _llmClassifier!(input, context)
          .timeout(_llmTimeout);

      if (llmResult != null && llmResult.confidence >= _minConfidenceThreshold) {
        _llmRetryCount = 0; // 重置重试计数
        debugPrint('[HybridRouter] LLM路由成功: ${llmResult.action}');
        return llmResult;
      }

      // LLM置信度不足，使用规则验证
      debugPrint('[HybridRouter] LLM置信度不足，使用规则验证');
      final ruleResult = await _routeWithRulesOnly(input);

      // 融合结果
      return _mergeResults(llmResult, ruleResult);
    } on TimeoutException {
      debugPrint('[HybridRouter] LLM超时，降级到规则');
      return _routeWithRulesOnly(input);
    } catch (e) {
      debugPrint('[HybridRouter] LLM异常: $e');

      // 重试逻辑
      if (_llmRetryCount < _maxRetries) {
        _llmRetryCount++;
        debugPrint('[HybridRouter] 重试LLM (${_llmRetryCount}/$_maxRetries)');
        return _routeWithLLMFirst(input, context);
      }

      // 重试失败，降级到规则
      _llmRetryCount = 0;
      return _routeWithRulesOnly(input);
    }
  }

  /// 规则优先路由（网络慢时使用）
  Future<IntentResult> _routeWithRuleFirst(
      String input, String? context) async {
    // 先尝试规则
    final ruleResult = await _routeWithRulesOnly(input);

    // 如果规则置信度高，直接返回
    if (ruleResult.confidence >= 0.85) {
      return ruleResult;
    }

    // 规则不确定，尝试LLM（如果可用）
    if (_llmClassifier != null) {
      try {
        final llmResult = await _llmClassifier!(input, context)
            .timeout(_llmTimeout);

        if (llmResult != null &&
            llmResult.confidence > ruleResult.confidence) {
          return llmResult;
        }
      } catch (e) {
        debugPrint('[HybridRouter] LLM辅助失败: $e');
      }
    }

    return ruleResult;
  }

  /// 仅规则路由
  Future<IntentResult> _routeWithRulesOnly(String input) async {
    if (_ruleClassifier == null) {
      return IntentResult(
        type: RouteType.unknown,
        confidence: 0,
        rawInput: input,
        source: RecognitionSource.rule,
      );
    }

    try {
      final result = await _ruleClassifier!(input);
      return result ??
          IntentResult(
            type: RouteType.unknown,
            confidence: 0,
            rawInput: input,
            source: RecognitionSource.rule,
          );
    } catch (e) {
      debugPrint('[HybridRouter] 规则路由异常: $e');
      return IntentResult(
        type: RouteType.unknown,
        confidence: 0,
        rawInput: input,
        source: RecognitionSource.rule,
      );
    }
  }

  /// 融合LLM和规则结果
  IntentResult _mergeResults(IntentResult? llmResult, IntentResult ruleResult) {
    if (llmResult == null) return ruleResult;

    // 置信度加权选择
    if (llmResult.confidence > ruleResult.confidence + 0.1) {
      return IntentResult(
        type: llmResult.type,
        confidence: llmResult.confidence,
        category: llmResult.category,
        action: llmResult.action,
        entities: {...ruleResult.entities, ...llmResult.entities}, // 合并实体
        emotion: llmResult.emotion,
        chatResponse: llmResult.chatResponse,
        rawInput: llmResult.rawInput,
        source: RecognitionSource.hybrid,
      );
    }

    // 规则结果更可靠
    return IntentResult(
      type: ruleResult.type,
      confidence: ruleResult.confidence,
      category: ruleResult.category,
      action: ruleResult.action,
      entities: {...llmResult.entities, ...ruleResult.entities}, // 合并实体
      emotion: llmResult.emotion, // 保留LLM的情感分析
      chatResponse: llmResult.chatResponse,
      rawInput: ruleResult.rawInput,
      source: RecognitionSource.hybrid,
    );
  }

  /// 释放资源
  void dispose() {
    _networkMonitor.dispose();
  }
}
