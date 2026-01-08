import 'dart:async';

import 'package:flutter/foundation.dart';

/// 降级级别
enum DegradationLevel {
  /// 正常模式
  normal,

  /// 轻微降级（关闭非核心功能）
  light,

  /// 中度降级（关闭AI/网络功能）
  moderate,

  /// 严重降级（仅保留核心功能）
  severe,

  /// 紧急模式（最小功能集）
  emergency,
}

/// 降级策略
class DegradationStrategy {
  /// 策略ID
  final String id;

  /// 策略名称
  final String name;

  /// 描述
  final String? description;

  /// 适用的降级级别
  final DegradationLevel level;

  /// 降级动作
  final Future<void> Function() onDegrade;

  /// 恢复动作
  final Future<void> Function()? onRecover;

  /// 降级条件检查
  final bool Function()? shouldDegrade;

  /// 是否已激活
  bool _isActive = false;

  DegradationStrategy({
    required this.id,
    required this.name,
    this.description,
    required this.level,
    required this.onDegrade,
    this.onRecover,
    this.shouldDegrade,
  });

  bool get isActive => _isActive;
}

/// 降级触发条件
class DegradationTrigger {
  /// 触发器ID
  final String id;

  /// 触发器名称
  final String name;

  /// 目标降级级别
  final DegradationLevel targetLevel;

  /// 条件检查
  final bool Function() condition;

  /// 检查间隔
  final Duration checkInterval;

  /// 优先级
  final int priority;

  const DegradationTrigger({
    required this.id,
    required this.name,
    required this.targetLevel,
    required this.condition,
    this.checkInterval = const Duration(seconds: 30),
    this.priority = 0,
  });
}

/// 系统健康指标
class SystemHealthMetrics {
  /// CPU 使用率
  final double cpuUsage;

  /// 内存使用率
  final double memoryUsage;

  /// 网络延迟 (ms)
  final int networkLatency;

  /// 错误率
  final double errorRate;

  /// 活跃请求数
  final int activeRequests;

  /// 数据库连接数
  final int dbConnections;

  /// 队列积压数
  final int queueBacklog;

  const SystemHealthMetrics({
    this.cpuUsage = 0,
    this.memoryUsage = 0,
    this.networkLatency = 0,
    this.errorRate = 0,
    this.activeRequests = 0,
    this.dbConnections = 0,
    this.queueBacklog = 0,
  });

  /// 计算综合健康分数 (0-100)
  double get healthScore {
    double score = 100;

    // CPU 使用率影响
    if (cpuUsage > 80) score -= (cpuUsage - 80) * 0.5;

    // 内存使用率影响
    if (memoryUsage > 85) score -= (memoryUsage - 85) * 0.8;

    // 网络延迟影响
    if (networkLatency > 1000) score -= (networkLatency - 1000) / 100;

    // 错误率影响
    score -= errorRate * 10;

    return score.clamp(0, 100);
  }

  /// 建议的降级级别
  DegradationLevel get suggestedLevel {
    final score = healthScore;

    if (score >= 80) return DegradationLevel.normal;
    if (score >= 60) return DegradationLevel.light;
    if (score >= 40) return DegradationLevel.moderate;
    if (score >= 20) return DegradationLevel.severe;
    return DegradationLevel.emergency;
  }
}

/// 优雅降级服务
///
/// 核心功能：
/// 1. 系统健康监控
/// 2. 自动降级策略
/// 3. 功能开关联动
/// 4. 降级恢复
///
/// 对应设计文档：第23章 异常处理与容错设计
/// 对应实施方案：轨道L 容错与扩展模块
class GracefulDegradationService extends ChangeNotifier {
  static final GracefulDegradationService _instance = GracefulDegradationService._();
  factory GracefulDegradationService() => _instance;
  GracefulDegradationService._();

  DegradationLevel _currentLevel = DegradationLevel.normal;
  SystemHealthMetrics _metrics = const SystemHealthMetrics();
  bool _initialized = false;

  final Map<String, DegradationStrategy> _strategies = {};
  final Map<String, DegradationTrigger> _triggers = {};
  final List<String> _activeStrategies = [];

  Timer? _healthCheckTimer;
  Timer? _autoRecoveryTimer;

  /// 降级回调
  void Function(DegradationLevel oldLevel, DegradationLevel newLevel)? _onLevelChange;

  /// 初始化服务
  Future<void> initialize({
    GracefulDegradationConfig? config,
    void Function(DegradationLevel oldLevel, DegradationLevel newLevel)? onLevelChange,
  }) async {
    if (_initialized) return;

    final effectiveConfig = config ?? const GracefulDegradationConfig();
    _onLevelChange = onLevelChange;

    // 注册默认策略
    _registerDefaultStrategies();

    // 注册默认触发器
    _registerDefaultTriggers();

    // 启动健康检查
    if (effectiveConfig.enableAutoHealthCheck) {
      _healthCheckTimer = Timer.periodic(
        effectiveConfig.healthCheckInterval,
        (_) => _performHealthCheck(),
      );
    }

    // 启动自动恢复
    if (effectiveConfig.enableAutoRecovery) {
      _autoRecoveryTimer = Timer.periodic(
        effectiveConfig.recoveryCheckInterval,
        (_) => _checkRecovery(),
      );
    }

    _initialized = true;
  }

  /// 获取当前降级级别
  DegradationLevel get currentLevel => _currentLevel;

  /// 获取当前健康指标
  SystemHealthMetrics get metrics => _metrics;

  /// 是否处于降级模式
  bool get isDegraded => _currentLevel != DegradationLevel.normal;

  /// 检查功能是否可用
  bool isFeatureAvailable(String featureId, {DegradationLevel minLevel = DegradationLevel.normal}) {
    return _currentLevel.index <= minLevel.index;
  }

  /// 更新健康指标
  void updateMetrics(SystemHealthMetrics metrics) {
    _metrics = metrics;
    notifyListeners();
  }

  /// 注册降级策略
  void registerStrategy(DegradationStrategy strategy) {
    _strategies[strategy.id] = strategy;
  }

  /// 移除降级策略
  void removeStrategy(String id) {
    _strategies.remove(id);
  }

  /// 注册降级触发器
  void registerTrigger(DegradationTrigger trigger) {
    _triggers[trigger.id] = trigger;
  }

  /// 移除降级触发器
  void removeTrigger(String id) {
    _triggers.remove(id);
  }

  /// 手动设置降级级别
  Future<void> setLevel(DegradationLevel level) async {
    if (_currentLevel == level) return;

    final oldLevel = _currentLevel;
    _currentLevel = level;

    // 执行降级或恢复策略
    if (level.index > oldLevel.index) {
      await _executeDegradation(oldLevel, level);
    } else {
      await _executeRecovery(oldLevel, level);
    }

    _onLevelChange?.call(oldLevel, level);
    notifyListeners();
  }

  /// 执行降级
  Future<void> degrade({DegradationLevel? level}) async {
    final targetLevel = level ?? DegradationLevel.values[
      (_currentLevel.index + 1).clamp(0, DegradationLevel.values.length - 1)
    ];

    await setLevel(targetLevel);
  }

  /// 执行恢复
  Future<void> recover({DegradationLevel? level}) async {
    final targetLevel = level ?? DegradationLevel.values[
      (_currentLevel.index - 1).clamp(0, DegradationLevel.values.length - 1)
    ];

    await setLevel(targetLevel);
  }

  /// 完全恢复
  Future<void> fullRecover() async {
    await setLevel(DegradationLevel.normal);
  }

  /// 获取可用功能列表
  List<String> getAvailableFeatures() {
    final features = <String>[];

    for (final strategy in _strategies.values) {
      if (strategy.level.index > _currentLevel.index) {
        features.add(strategy.id);
      }
    }

    return features;
  }

  /// 获取已禁用功能列表
  List<String> getDisabledFeatures() {
    final features = <String>[];

    for (final strategy in _strategies.values) {
      if (strategy.level.index <= _currentLevel.index && strategy.isActive) {
        features.add(strategy.id);
      }
    }

    return features;
  }

  /// 执行带降级回退的操作
  Future<T> executeWithFallback<T>({
    required Future<T> Function() operation,
    required T Function() fallback,
    DegradationLevel fallbackLevel = DegradationLevel.light,
  }) async {
    if (_currentLevel.index >= fallbackLevel.index) {
      return fallback();
    }

    try {
      return await operation();
    } catch (e) {
      if (kDebugMode) {
        print('Operation failed, using fallback: $e');
      }
      return fallback();
    }
  }

  /// 执行带降级的操作
  Future<T?> executeWithDegradation<T>({
    required Future<T> Function() operation,
    DegradationLevel requiredLevel = DegradationLevel.normal,
  }) async {
    if (_currentLevel.index > requiredLevel.index) {
      return null;
    }

    return await operation();
  }

  // ==================== 私有方法 ====================

  /// 注册默认策略
  void _registerDefaultStrategies() {
    // 轻微降级策略
    registerStrategy(DegradationStrategy(
      id: 'disable_animations',
      name: '禁用动画',
      level: DegradationLevel.light,
      onDegrade: () async {
        // 禁用复杂动画
      },
      onRecover: () async {
        // 恢复动画
      },
    ));

    registerStrategy(DegradationStrategy(
      id: 'reduce_refresh_rate',
      name: '降低刷新频率',
      level: DegradationLevel.light,
      onDegrade: () async {
        // 降低数据刷新频率
      },
    ));

    // 中度降级策略
    registerStrategy(DegradationStrategy(
      id: 'disable_ai_features',
      name: '禁用AI功能',
      level: DegradationLevel.moderate,
      onDegrade: () async {
        // 禁用AI识别、智能建议等
      },
    ));

    registerStrategy(DegradationStrategy(
      id: 'use_cached_data',
      name: '使用缓存数据',
      level: DegradationLevel.moderate,
      onDegrade: () async {
        // 优先使用缓存，减少网络请求
      },
    ));

    // 严重降级策略
    registerStrategy(DegradationStrategy(
      id: 'disable_sync',
      name: '禁用同步',
      level: DegradationLevel.severe,
      onDegrade: () async {
        // 停止所有同步操作
      },
    ));

    registerStrategy(DegradationStrategy(
      id: 'minimal_ui',
      name: '最小化UI',
      level: DegradationLevel.severe,
      onDegrade: () async {
        // 切换到最小化UI模式
      },
    ));

    // 紧急模式策略
    registerStrategy(DegradationStrategy(
      id: 'emergency_mode',
      name: '紧急模式',
      level: DegradationLevel.emergency,
      onDegrade: () async {
        // 仅保留基本记账功能
      },
    ));
  }

  /// 注册默认触发器
  void _registerDefaultTriggers() {
    registerTrigger(DegradationTrigger(
      id: 'high_memory',
      name: '内存过高',
      targetLevel: DegradationLevel.moderate,
      condition: () => _metrics.memoryUsage > 90,
    ));

    registerTrigger(DegradationTrigger(
      id: 'high_error_rate',
      name: '错误率过高',
      targetLevel: DegradationLevel.severe,
      condition: () => _metrics.errorRate > 5,
    ));

    registerTrigger(DegradationTrigger(
      id: 'network_unavailable',
      name: '网络不可用',
      targetLevel: DegradationLevel.moderate,
      condition: () => _metrics.networkLatency > 10000,
    ));
  }

  /// 执行健康检查
  void _performHealthCheck() {
    // 检查触发器
    DegradationLevel maxLevel = DegradationLevel.normal;

    final sortedTriggers = _triggers.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final trigger in sortedTriggers) {
      if (trigger.condition()) {
        if (trigger.targetLevel.index > maxLevel.index) {
          maxLevel = trigger.targetLevel;
        }
      }
    }

    // 如果需要降级
    if (maxLevel.index > _currentLevel.index) {
      setLevel(maxLevel);
    }
  }

  /// 检查是否可以恢复
  void _checkRecovery() {
    if (_currentLevel == DegradationLevel.normal) return;

    // 检查所有触发器，如果都不满足则恢复
    bool shouldRecover = true;

    for (final trigger in _triggers.values) {
      if (trigger.targetLevel.index <= _currentLevel.index && trigger.condition()) {
        shouldRecover = false;
        break;
      }
    }

    if (shouldRecover) {
      recover();
    }
  }

  /// 执行降级
  Future<void> _executeDegradation(DegradationLevel from, DegradationLevel to) async {
    for (final strategy in _strategies.values) {
      if (strategy.level.index > from.index && strategy.level.index <= to.index) {
        try {
          await strategy.onDegrade();
          strategy._isActive = true;
          _activeStrategies.add(strategy.id);
        } catch (e) {
          if (kDebugMode) {
            print('Failed to execute degradation strategy ${strategy.id}: $e');
          }
        }
      }
    }
  }

  /// 执行恢复
  Future<void> _executeRecovery(DegradationLevel from, DegradationLevel to) async {
    for (final strategy in _strategies.values) {
      if (strategy.level.index > to.index && strategy.level.index <= from.index) {
        try {
          await strategy.onRecover?.call();
          strategy._isActive = false;
          _activeStrategies.remove(strategy.id);
        } catch (e) {
          if (kDebugMode) {
            print('Failed to execute recovery strategy ${strategy.id}: $e');
          }
        }
      }
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _healthCheckTimer?.cancel();
    _autoRecoveryTimer?.cancel();
    await fullRecover();
    _strategies.clear();
    _triggers.clear();
    _initialized = false;
  }
}

/// 优雅降级配置
class GracefulDegradationConfig {
  /// 是否启用自动健康检查
  final bool enableAutoHealthCheck;

  /// 健康检查间隔
  final Duration healthCheckInterval;

  /// 是否启用自动恢复
  final bool enableAutoRecovery;

  /// 恢复检查间隔
  final Duration recoveryCheckInterval;

  const GracefulDegradationConfig({
    this.enableAutoHealthCheck = true,
    this.healthCheckInterval = const Duration(seconds: 30),
    this.enableAutoRecovery = true,
    this.recoveryCheckInterval = const Duration(minutes: 1),
  });
}

/// 全局降级服务实例
final degradation = GracefulDegradationService();
