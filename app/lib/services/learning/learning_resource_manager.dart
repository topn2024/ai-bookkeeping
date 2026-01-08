import 'dart:async';

import 'package:flutter/foundation.dart';

// ==================== 学习资源管理器 ====================

/// 学习资源管理器
/// 负责控制学习模块的资源消耗，包括内存、存储、电量
class LearningResourceManager {
  static final LearningResourceManager _instance = LearningResourceManager._();
  factory LearningResourceManager() => _instance;
  LearningResourceManager._();

  // ==================== 配置常量 ====================

  /// 单个模块最大样本数
  static const int maxSamplesPerModule = 1000;

  /// 单个模块最大规则数
  static const int maxRulesPerModule = 100;

  /// 协同学习上报批次大小
  static const int reportBatchSize = 10;

  /// 协同学习上报间隔（避免频繁网络请求）
  static const Duration reportInterval = Duration(minutes: 5);

  /// 数据保留天数
  static const int dataRetentionDays = 90;

  /// 低电量阈值
  static const double lowBatteryThreshold = 0.2;

  /// 后台学习允许的最大CPU时间（毫秒）
  static const int maxBackgroundCpuTimeMs = 100;

  // ==================== 运行时状态 ====================

  bool _isLowPowerMode = false;
  bool _isBackgroundMode = false;
  double _batteryLevel = 1.0;
  final Map<String, int> _moduleSampleCounts = {};
  final Map<String, DateTime> _lastReportTimes = {};
  final List<_PendingReport> _pendingReports = [];
  Timer? _batchReportTimer;

  // ==================== 状态管理 ====================

  /// 是否处于低功耗模式
  bool get isLowPowerMode => _isLowPowerMode;

  /// 是否处于后台模式
  bool get isBackgroundMode => _isBackgroundMode;

  /// 更新电量状态
  void updateBatteryLevel(double level) {
    _batteryLevel = level;
    _isLowPowerMode = level < lowBatteryThreshold;

    if (_isLowPowerMode) {
      debugPrint('Learning: Entering low power mode (battery: ${(level * 100).toStringAsFixed(0)}%)');
    }
  }

  /// 进入后台模式
  void enterBackgroundMode() {
    _isBackgroundMode = true;
    debugPrint('Learning: Entering background mode');
  }

  /// 退出后台模式
  void exitBackgroundMode() {
    _isBackgroundMode = false;
    debugPrint('Learning: Exiting background mode');
  }

  // ==================== 样本数量控制 ====================

  /// 检查是否可以添加新样本
  bool canAddSample(String moduleId) {
    final count = _moduleSampleCounts[moduleId] ?? 0;
    return count < maxSamplesPerModule;
  }

  /// 记录样本添加
  void recordSampleAdded(String moduleId) {
    _moduleSampleCounts[moduleId] = (_moduleSampleCounts[moduleId] ?? 0) + 1;
  }

  /// 记录样本删除
  void recordSampleRemoved(String moduleId, int count) {
    final current = _moduleSampleCounts[moduleId] ?? 0;
    _moduleSampleCounts[moduleId] = (current - count).clamp(0, maxSamplesPerModule);
  }

  /// 获取模块样本数
  int getSampleCount(String moduleId) {
    return _moduleSampleCounts[moduleId] ?? 0;
  }

  /// 计算需要清理的样本数
  int calculateCleanupCount(String moduleId, int currentCount) {
    if (currentCount <= maxSamplesPerModule) return 0;
    // 清理到 80% 容量，避免频繁清理
    return currentCount - (maxSamplesPerModule * 0.8).toInt();
  }

  // ==================== 学习频率控制 ====================

  /// 检查是否应该执行学习（考虑功耗）
  bool shouldPerformLearning() {
    // 低电量模式下减少学习
    if (_isLowPowerMode) {
      return false;
    }

    // 后台模式下延迟学习
    if (_isBackgroundMode) {
      return false;
    }

    return true;
  }

  /// 检查是否应该触发规则学习
  bool shouldTriggerRuleLearning(String moduleId, int sampleCount, int minRequired) {
    if (!shouldPerformLearning()) return false;
    return sampleCount >= minRequired;
  }

  // ==================== 协同学习上报控制 ====================

  /// 排队上报（批量合并）
  void queueReport(String moduleId, Map<String, dynamic> data) {
    // 低电量模式下不上报
    if (_isLowPowerMode) {
      debugPrint('Learning: Skipping report in low power mode');
      return;
    }

    _pendingReports.add(_PendingReport(
      moduleId: moduleId,
      data: data,
      timestamp: DateTime.now(),
    ));

    // 达到批次大小时触发上报
    if (_pendingReports.length >= reportBatchSize) {
      _flushReports();
    } else {
      // 启动定时器，确保数据最终被上报
      _scheduleBatchReport();
    }
  }

  void _scheduleBatchReport() {
    _batchReportTimer?.cancel();
    _batchReportTimer = Timer(reportInterval, _flushReports);
  }

  void _flushReports() {
    if (_pendingReports.isEmpty) return;

    final reports = List<_PendingReport>.from(_pendingReports);
    _pendingReports.clear();

    // 按模块分组
    final byModule = <String, List<Map<String, dynamic>>>{};
    for (final report in reports) {
      byModule.putIfAbsent(report.moduleId, () => []);
      byModule[report.moduleId]!.add(report.data);
    }

    // 触发批量上报回调
    for (final entry in byModule.entries) {
      _onBatchReport?.call(entry.key, entry.value);
    }

    debugPrint('Learning: Flushed ${reports.length} reports');
  }

  void Function(String moduleId, List<Map<String, dynamic>> data)? _onBatchReport;

  /// 设置批量上报回调
  void setOnBatchReport(void Function(String moduleId, List<Map<String, dynamic>> data) callback) {
    _onBatchReport = callback;
  }

  /// 检查是否可以上报（频率限制）
  bool canReport(String moduleId) {
    if (_isLowPowerMode) return false;

    final lastReport = _lastReportTimes[moduleId];
    if (lastReport == null) return true;

    return DateTime.now().difference(lastReport) >= reportInterval;
  }

  /// 记录上报时间
  void recordReport(String moduleId) {
    _lastReportTimes[moduleId] = DateTime.now();
  }

  // ==================== 数据清理策略 ====================

  /// 获取数据过期时间
  DateTime getDataExpiryDate() {
    return DateTime.now().subtract(Duration(days: dataRetentionDays));
  }

  /// 检查数据是否过期
  bool isDataExpired(DateTime timestamp) {
    return timestamp.isBefore(getDataExpiryDate());
  }

  /// 计算存储空间使用估算（字节）
  int estimateStorageUsage(int sampleCount, int avgSampleSize) {
    return sampleCount * avgSampleSize;
  }

  // ==================== 资源使用统计 ====================

  /// 获取资源使用报告
  LearningResourceReport getResourceReport() {
    int totalSamples = 0;
    for (final count in _moduleSampleCounts.values) {
      totalSamples += count;
    }

    return LearningResourceReport(
      totalSamples: totalSamples,
      moduleSampleCounts: Map.from(_moduleSampleCounts),
      pendingReports: _pendingReports.length,
      isLowPowerMode: _isLowPowerMode,
      isBackgroundMode: _isBackgroundMode,
      batteryLevel: _batteryLevel,
      estimatedMemoryUsageKB: totalSamples * 2, // 估算每样本 2KB
    );
  }

  // ==================== 生命周期 ====================

  /// 释放资源
  void dispose() {
    _batchReportTimer?.cancel();
    _flushReports();
  }
}

class _PendingReport {
  final String moduleId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _PendingReport({
    required this.moduleId,
    required this.data,
    required this.timestamp,
  });
}

/// 资源使用报告
class LearningResourceReport {
  final int totalSamples;
  final Map<String, int> moduleSampleCounts;
  final int pendingReports;
  final bool isLowPowerMode;
  final bool isBackgroundMode;
  final double batteryLevel;
  final int estimatedMemoryUsageKB;

  const LearningResourceReport({
    required this.totalSamples,
    required this.moduleSampleCounts,
    required this.pendingReports,
    required this.isLowPowerMode,
    required this.isBackgroundMode,
    required this.batteryLevel,
    required this.estimatedMemoryUsageKB,
  });

  @override
  String toString() {
    return '''LearningResourceReport:
  - Total Samples: $totalSamples
  - Modules: ${moduleSampleCounts.length}
  - Pending Reports: $pendingReports
  - Low Power Mode: $isLowPowerMode
  - Background Mode: $isBackgroundMode
  - Battery: ${(batteryLevel * 100).toStringAsFixed(0)}%
  - Est. Memory: ${estimatedMemoryUsageKB}KB''';
  }
}

// ==================== 数据存储基类（带资源管理） ====================

/// 带资源管理的数据存储基类
abstract class ManagedDataStore<T> {
  final String moduleId;
  final LearningResourceManager _resourceManager = LearningResourceManager();
  final List<T> _data = [];

  ManagedDataStore(this.moduleId);

  /// 获取时间戳
  DateTime getTimestamp(T item);

  /// 添加数据（自动清理）
  Future<void> add(T item) async {
    // 检查是否可以添加
    if (!_resourceManager.canAddSample(moduleId)) {
      // 清理旧数据
      await _cleanup();
    }

    _data.add(item);
    _resourceManager.recordSampleAdded(moduleId);
  }

  /// 清理过期数据
  Future<void> _cleanup() async {
    final expiryDate = _resourceManager.getDataExpiryDate();
    final beforeCount = _data.length;

    // 移除过期数据
    _data.removeWhere((item) => getTimestamp(item).isBefore(expiryDate));

    // 如果还是超过上限，移除最旧的
    final cleanupCount = _resourceManager.calculateCleanupCount(moduleId, _data.length);
    if (cleanupCount > 0) {
      _data.sort((a, b) => getTimestamp(a).compareTo(getTimestamp(b)));
      _data.removeRange(0, cleanupCount);
    }

    final removed = beforeCount - _data.length;
    if (removed > 0) {
      _resourceManager.recordSampleRemoved(moduleId, removed);
      debugPrint('Learning [$moduleId]: Cleaned up $removed old samples');
    }
  }

  /// 获取所有数据
  List<T> getAll() => List.unmodifiable(_data);

  /// 获取最近数据
  List<T> getRecent({int limit = 100}) {
    final sorted = _data.toList()
      ..sort((a, b) => getTimestamp(b).compareTo(getTimestamp(a)));
    return sorted.take(limit).toList();
  }

  /// 数据数量
  int get length => _data.length;

  /// 清空数据
  void clear() {
    final count = _data.length;
    _data.clear();
    _resourceManager.recordSampleRemoved(moduleId, count);
  }
}

// ==================== 学习配置 ====================

/// 学习配置
class LearningConfig {
  /// 是否启用自学习
  final bool enableSelfLearning;

  /// 是否启用协同学习
  final bool enableCollaborativeLearning;

  /// 是否启用后台学习
  final bool enableBackgroundLearning;

  /// 最大存储空间（MB）
  final int maxStorageMB;

  /// 低电量时是否暂停学习
  final bool pauseOnLowBattery;

  /// 仅WiFi时上报
  final bool reportOnlyOnWifi;

  const LearningConfig({
    this.enableSelfLearning = true,
    this.enableCollaborativeLearning = true,
    this.enableBackgroundLearning = false,
    this.maxStorageMB = 50,
    this.pauseOnLowBattery = true,
    this.reportOnlyOnWifi = true,
  });

  /// 默认配置
  static const LearningConfig defaults = LearningConfig();

  /// 省电配置
  static const LearningConfig powerSaving = LearningConfig(
    enableSelfLearning: true,
    enableCollaborativeLearning: false,
    enableBackgroundLearning: false,
    maxStorageMB: 20,
    pauseOnLowBattery: true,
    reportOnlyOnWifi: true,
  );

  /// 最小配置（仅本地学习）
  static const LearningConfig minimal = LearningConfig(
    enableSelfLearning: true,
    enableCollaborativeLearning: false,
    enableBackgroundLearning: false,
    maxStorageMB: 10,
    pauseOnLowBattery: true,
    reportOnlyOnWifi: true,
  );
}
