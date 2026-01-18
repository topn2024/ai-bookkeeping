import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/privacy_budget.dart';
import '../models/sensitivity_level.dart';

/// 隐私预算管理器
///
/// 负责管理和追踪差分隐私预算的消耗，确保隐私保护不被过度使用。
/// 实现组合定理：多次查询会累积消耗隐私预算。
class PrivacyBudgetManager extends ChangeNotifier {
  /// 预算配置
  PrivacyBudgetConfig _config;

  /// 当前预算状态
  PrivacyBudgetState _state;

  /// 消耗记录
  final List<BudgetConsumptionRecord> _consumptionHistory = [];

  /// 预算耗尽回调
  final List<VoidCallback> _exhaustionCallbacks = [];

  /// 持久化存储接口
  final PrivacyBudgetStorage? _storage;

  /// 重置定时器
  Timer? _resetTimer;

  PrivacyBudgetManager({
    PrivacyBudgetConfig? config,
    PrivacyBudgetStorage? storage,
  })  : _config = config ?? PrivacyBudgetConfig.defaultConfig,
        _storage = storage,
        _state = PrivacyBudgetState.initial() {
    _scheduleReset();
  }

  /// 当前配置
  PrivacyBudgetConfig get config => _config;

  /// 当前状态
  PrivacyBudgetState get state => _state;

  /// 预算是否已耗尽
  bool get isExhausted => _state.isExhausted;

  /// 剩余预算
  double get remainingBudget => _config.totalBudgetLimit - _state.totalConsumed;

  /// 剩余预算百分比
  double get remainingBudgetPercent =>
      (remainingBudget / _config.totalBudgetLimit * 100).clamp(0.0, 100.0);

  /// 消耗历史
  List<BudgetConsumptionRecord> get consumptionHistory =>
      List.unmodifiable(_consumptionHistory);

  /// 初始化，从存储加载状态
  Future<void> initialize() async {
    if (_storage != null) {
      final savedState = await _storage.loadState();
      if (savedState != null) {
        _state = savedState;

        // 检查是否需要重置
        _checkAndResetIfNeeded();
      }

      final savedHistory = await _storage.loadHistory();
      _consumptionHistory.addAll(savedHistory);
    }
    notifyListeners();
  }

  /// 获取指定敏感度级别的 epsilon 值
  double getEpsilon(SensitivityLevel level) {
    return _config.getEpsilon(level);
  }

  /// 检查是否可以消耗指定量的预算
  bool canConsume(double epsilon) {
    if (_state.isExhausted) return false;
    return _state.totalConsumed + epsilon <= _config.totalBudgetLimit;
  }

  /// 消耗预算
  ///
  /// [epsilon] 要消耗的 epsilon 值
  /// [level] 敏感度级别
  /// [operation] 操作描述
  ///
  /// 返回是否成功消耗
  Future<bool> consume({
    required double epsilon,
    required SensitivityLevel level,
    required String operation,
  }) async {
    // 检查预算是否已耗尽
    if (_state.isExhausted) {
      debugPrint('隐私预算已耗尽，拒绝操作: $operation');
      return false;
    }

    // 检查是否超出总预算
    if (!canConsume(epsilon)) {
      _state = _state.copyWith(isExhausted: true);
      _notifyExhaustion();
      await _persistState();
      notifyListeners();
      debugPrint('隐私预算不足，拒绝操作: $operation');
      return false;
    }

    // 更新对应级别的消耗
    switch (level) {
      case SensitivityLevel.high:
        _state = _state.copyWith(
          highSensitivityConsumed: _state.highSensitivityConsumed + epsilon,
        );
        break;
      case SensitivityLevel.medium:
        _state = _state.copyWith(
          mediumSensitivityConsumed: _state.mediumSensitivityConsumed + epsilon,
        );
        break;
      case SensitivityLevel.low:
        _state = _state.copyWith(
          lowSensitivityConsumed: _state.lowSensitivityConsumed + epsilon,
        );
        break;
    }

    // 检查是否达到耗尽阈值
    if (_state.totalConsumed >= _config.totalBudgetLimit) {
      _state = _state.copyWith(isExhausted: true);
      _notifyExhaustion();
    }

    // 记录消耗
    final record = BudgetConsumptionRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      epsilon: epsilon,
      level: level,
      operation: operation,
      timestamp: DateTime.now(),
    );
    _consumptionHistory.add(record);

    // 持久化
    await _persistState();
    await _persistHistory(record);

    notifyListeners();

    debugPrint('消耗隐私预算: $epsilon (${level.name}) - $operation');
    debugPrint('剩余预算: ${remainingBudgetPercent.toStringAsFixed(1)}%');

    return true;
  }

  /// 批量消耗预算（用于批量操作）
  Future<bool> consumeBatch({
    required int count,
    required double epsilonPerItem,
    required SensitivityLevel level,
    required String operation,
  }) async {
    final totalEpsilon = count * epsilonPerItem;
    return consume(
      epsilon: totalEpsilon,
      level: level,
      operation: '$operation (x$count)',
    );
  }

  /// 更新配置
  Future<void> updateConfig(PrivacyBudgetConfig newConfig) async {
    _config = newConfig;
    _scheduleReset();
    await _persistConfig();
    notifyListeners();
  }

  /// 手动重置预算
  Future<void> reset() async {
    _state = _state.reset();
    _consumptionHistory.clear();
    await _persistState();
    await _storage?.clearHistory();
    notifyListeners();
    debugPrint('隐私预算已重置');
  }

  /// 添加预算耗尽监听器
  void addExhaustionListener(VoidCallback callback) {
    _exhaustionCallbacks.add(callback);
  }

  /// 移除预算耗尽监听器
  void removeExhaustionListener(VoidCallback callback) {
    _exhaustionCallbacks.remove(callback);
  }

  /// 获取各级别的消耗统计
  Map<SensitivityLevel, BudgetLevelStats> getLevelStats() {
    return {
      SensitivityLevel.high: BudgetLevelStats(
        consumed: _state.highSensitivityConsumed,
        epsilon: _config.highSensitivityEpsilon,
        operationCount: _consumptionHistory
            .where((r) => r.level == SensitivityLevel.high)
            .length,
      ),
      SensitivityLevel.medium: BudgetLevelStats(
        consumed: _state.mediumSensitivityConsumed,
        epsilon: _config.mediumSensitivityEpsilon,
        operationCount: _consumptionHistory
            .where((r) => r.level == SensitivityLevel.medium)
            .length,
      ),
      SensitivityLevel.low: BudgetLevelStats(
        consumed: _state.lowSensitivityConsumed,
        epsilon: _config.lowSensitivityEpsilon,
        operationCount: _consumptionHistory
            .where((r) => r.level == SensitivityLevel.low)
            .length,
      ),
    };
  }

  void _checkAndResetIfNeeded() {
    final now = DateTime.now();
    final hoursSinceReset =
        now.difference(_state.lastResetTime).inHours;

    if (hoursSinceReset >= _config.resetPeriodHours) {
      _state = _state.reset();
      _consumptionHistory.clear();
      debugPrint('隐私预算已自动重置（周期: ${_config.resetPeriodHours}小时）');
    }
  }

  void _scheduleReset() {
    _resetTimer?.cancel();

    final resetDuration = Duration(hours: _config.resetPeriodHours);
    _resetTimer = Timer.periodic(resetDuration, (_) {
      _state = _state.reset();
      _consumptionHistory.clear();
      _persistState();
      notifyListeners();
      debugPrint('隐私预算已按计划重置');
    });
  }

  void _notifyExhaustion() {
    for (final callback in _exhaustionCallbacks) {
      callback();
    }
  }

  Future<void> _persistState() async {
    await _storage?.saveState(_state);
  }

  Future<void> _persistHistory(BudgetConsumptionRecord record) async {
    await _storage?.appendHistory(record);
  }

  Future<void> _persistConfig() async {
    await _storage?.saveConfig(_config);
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _exhaustionCallbacks.clear();
    super.dispose();
  }
}

/// 预算级别统计
class BudgetLevelStats {
  /// 已消耗量
  final double consumed;

  /// epsilon 值
  final double epsilon;

  /// 操作次数
  final int operationCount;

  const BudgetLevelStats({
    required this.consumed,
    required this.epsilon,
    required this.operationCount,
  });
}

/// 隐私预算存储接口
abstract class PrivacyBudgetStorage {
  /// 保存状态
  Future<void> saveState(PrivacyBudgetState state);

  /// 加载状态
  Future<PrivacyBudgetState?> loadState();

  /// 保存配置
  Future<void> saveConfig(PrivacyBudgetConfig config);

  /// 加载配置
  Future<PrivacyBudgetConfig?> loadConfig();

  /// 追加历史记录
  Future<void> appendHistory(BudgetConsumptionRecord record);

  /// 加载历史记录
  Future<List<BudgetConsumptionRecord>> loadHistory();

  /// 清除历史记录
  Future<void> clearHistory();
}

/// 内存存储实现（用于测试）
class InMemoryPrivacyBudgetStorage implements PrivacyBudgetStorage {
  PrivacyBudgetState? _state;
  PrivacyBudgetConfig? _config;
  final List<BudgetConsumptionRecord> _history = [];

  @override
  Future<void> saveState(PrivacyBudgetState state) async {
    _state = state;
  }

  @override
  Future<PrivacyBudgetState?> loadState() async => _state;

  @override
  Future<void> saveConfig(PrivacyBudgetConfig config) async {
    _config = config;
  }

  @override
  Future<PrivacyBudgetConfig?> loadConfig() async => _config;

  @override
  Future<void> appendHistory(BudgetConsumptionRecord record) async {
    _history.add(record);
  }

  @override
  Future<List<BudgetConsumptionRecord>> loadHistory() async =>
      List.unmodifiable(_history);

  @override
  Future<void> clearHistory() async {
    _history.clear();
  }
}
