import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 指标类型
enum MetricType {
  /// 计数器（只增不减）
  counter,

  /// 仪表（可增可减）
  gauge,

  /// 直方图（分布统计）
  histogram,

  /// 摘要（百分位统计）
  summary,

  /// 计时器
  timer,
}

/// 指标值
class MetricValue {
  final String name;
  final MetricType type;
  final double value;
  final Map<String, String>? labels;
  final DateTime timestamp;

  MetricValue({
    required this.name,
    required this.type,
    required this.value,
    this.labels,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'value': value,
    if (labels != null) 'labels': labels,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 直方图桶
class HistogramBucket {
  final double upperBound;
  int count;

  HistogramBucket(this.upperBound, [this.count = 0]);
}

/// 直方图指标
class Histogram {
  final String name;
  final List<double> bucketBoundaries;
  final Map<String, String>? labels;

  late final List<HistogramBucket> _buckets;
  double _sum = 0;
  int _count = 0;

  Histogram({
    required this.name,
    List<double>? bucketBoundaries,
    this.labels,
  }) : bucketBoundaries = bucketBoundaries ?? _defaultBuckets {
    _buckets = [
      ...this.bucketBoundaries.map((b) => HistogramBucket(b)),
      HistogramBucket(double.infinity), // +Inf bucket
    ];
  }

  static const List<double> _defaultBuckets = [
    0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0
  ];

  /// 观察一个值
  void observe(double value) {
    _count++;
    _sum += value;

    for (final bucket in _buckets) {
      if (value <= bucket.upperBound) {
        bucket.count++;
        break;
      }
    }
  }

  /// 获取总和
  double get sum => _sum;

  /// 获取计数
  int get count => _count;

  /// 获取平均值
  double get mean => _count > 0 ? _sum / _count : 0;

  /// 获取桶数据
  List<Map<String, dynamic>> getBuckets() {
    return _buckets.map((b) => {
      'upperBound': b.upperBound,
      'count': b.count,
    }).toList();
  }

  /// 重置
  void reset() {
    _sum = 0;
    _count = 0;
    for (final bucket in _buckets) {
      bucket.count = 0;
    }
  }
}

/// 摘要指标
class Summary {
  final String name;
  final List<double> quantiles;
  final Map<String, String>? labels;
  final int maxSamples;

  final Queue<double> _samples = Queue();
  double _sum = 0;
  int _count = 0;

  Summary({
    required this.name,
    this.quantiles = const [0.5, 0.9, 0.95, 0.99],
    this.labels,
    this.maxSamples = 1000,
  });

  /// 观察一个值
  void observe(double value) {
    _samples.add(value);
    _sum += value;
    _count++;

    // 保持固定大小
    while (_samples.length > maxSamples) {
      final removed = _samples.removeFirst();
      _sum -= removed;
    }
  }

  /// 获取百分位值
  Map<double, double> getQuantiles() {
    if (_samples.isEmpty) return {};

    final sorted = _samples.toList()..sort();
    final result = <double, double>{};

    for (final q in quantiles) {
      final index = (q * (sorted.length - 1)).round();
      result[q] = sorted[index];
    }

    return result;
  }

  /// 获取计数
  int get count => _count;

  /// 获取总和
  double get sum => _sum;

  /// 重置
  void reset() {
    _samples.clear();
    _sum = 0;
    _count = 0;
  }
}

/// 计时器
class MetricTimer {
  final Stopwatch _stopwatch = Stopwatch();
  final void Function(Duration duration) _onComplete;

  MetricTimer(this._onComplete) {
    _stopwatch.start();
  }

  /// 停止计时并记录
  Duration stop() {
    _stopwatch.stop();
    final duration = _stopwatch.elapsed;
    _onComplete(duration);
    return duration;
  }
}

/// 性能监控指标服务
///
/// 核心功能：
/// 1. 多种指标类型支持（计数器、仪表、直方图、摘要）
/// 2. 标签化指标
/// 3. 定期上报
/// 4. 内存中聚合
///
/// 对应设计文档：第29章 可观测性与监控
/// 对应实施方案：轨道L 可观测性模块
class MetricsService {
  static final MetricsService _instance = MetricsService._();
  factory MetricsService() => _instance;
  MetricsService._();

  final Map<String, double> _counters = {};
  final Map<String, double> _gauges = {};
  final Map<String, Histogram> _histograms = {};
  final Map<String, Summary> _summaries = {};

  Timer? _flushTimer;
  Future<void> Function(List<MetricValue> metrics)? _onFlush;

  MetricsConfig _config = const MetricsConfig();
  bool _initialized = false;

  /// 初始化服务
  Future<void> initialize({
    MetricsConfig? config,
    Future<void> Function(List<MetricValue> metrics)? onFlush,
  }) async {
    if (_initialized) return;

    if (config != null) {
      _config = config;
    }
    _onFlush = onFlush;

    // 启动定期上报
    if (_config.enableAutoFlush) {
      _flushTimer = Timer.periodic(_config.flushInterval, (_) => flush());
    }

    _initialized = true;
  }

  // ==================== 计数器 ====================

  /// 增加计数器
  void incrementCounter(String name, {double value = 1, Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    _counters[key] = (_counters[key] ?? 0) + value;
  }

  /// 获取计数器值
  double getCounter(String name, {Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    return _counters[key] ?? 0;
  }

  // ==================== 仪表 ====================

  /// 设置仪表值
  void setGauge(String name, double value, {Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    _gauges[key] = value;
  }

  /// 增加仪表值
  void incrementGauge(String name, {double value = 1, Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    _gauges[key] = (_gauges[key] ?? 0) + value;
  }

  /// 减少仪表值
  void decrementGauge(String name, {double value = 1, Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    _gauges[key] = (_gauges[key] ?? 0) - value;
  }

  /// 获取仪表值
  double getGauge(String name, {Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    return _gauges[key] ?? 0;
  }

  // ==================== 直方图 ====================

  /// 观察直方图值
  void observeHistogram(
    String name,
    double value, {
    List<double>? buckets,
    Map<String, String>? labels,
  }) {
    final key = _buildKey(name, labels);
    _histograms.putIfAbsent(
      key,
      () => Histogram(name: name, bucketBoundaries: buckets, labels: labels),
    ).observe(value);
  }

  /// 获取直方图
  Histogram? getHistogram(String name, {Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    return _histograms[key];
  }

  // ==================== ���要 ====================

  /// 观察摘要值
  void observeSummary(
    String name,
    double value, {
    List<double>? quantiles,
    Map<String, String>? labels,
  }) {
    final key = _buildKey(name, labels);
    _summaries.putIfAbsent(
      key,
      () => Summary(name: name, quantiles: quantiles ?? [0.5, 0.9, 0.95, 0.99], labels: labels),
    ).observe(value);
  }

  /// 获取摘要
  Summary? getSummary(String name, {Map<String, String>? labels}) {
    final key = _buildKey(name, labels);
    return _summaries[key];
  }

  // ==================== 计时器 ====================

  /// 开始计时
  MetricTimer startTimer(String name, {Map<String, String>? labels}) {
    return MetricTimer((duration) {
      observeHistogram(
        name,
        duration.inMicroseconds / 1000000, // 转换为秒
        buckets: _config.timerBuckets,
        labels: labels,
      );
    });
  }

  /// 计时执行
  Future<T> timeAsync<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? labels,
  }) async {
    final timer = startTimer(name, labels: labels);
    try {
      return await operation();
    } finally {
      timer.stop();
    }
  }

  /// 同步计时执行
  T timeSync<T>(
    String name,
    T Function() operation, {
    Map<String, String>? labels,
  }) {
    final timer = startTimer(name, labels: labels);
    try {
      return operation();
    } finally {
      timer.stop();
    }
  }

  // ==================== 预定义指标 ====================

  /// 记录 HTTP 请求
  void recordHttpRequest({
    required String method,
    required String path,
    required int statusCode,
    required Duration duration,
  }) {
    final labels = {
      'method': method,
      'path': path,
      'status': statusCode.toString(),
    };

    incrementCounter('http_requests_total', labels: labels);
    observeHistogram(
      'http_request_duration_seconds',
      duration.inMicroseconds / 1000000,
      buckets: _config.httpDurationBuckets,
      labels: labels,
    );
  }

  /// 记录数据库查询
  void recordDbQuery({
    required String operation,
    required String table,
    required Duration duration,
    bool success = true,
  }) {
    final labels = {
      'operation': operation,
      'table': table,
      'success': success.toString(),
    };

    incrementCounter('db_queries_total', labels: labels);
    observeHistogram(
      'db_query_duration_seconds',
      duration.inMicroseconds / 1000000,
      labels: labels,
    );
  }

  /// 记录缓存命中/未命中
  void recordCacheAccess({
    required String cache,
    required bool hit,
  }) {
    incrementCounter(
      hit ? 'cache_hits_total' : 'cache_misses_total',
      labels: {'cache': cache},
    );
  }

  /// 记录内存使用
  void recordMemoryUsage(int bytes) {
    setGauge('memory_usage_bytes', bytes.toDouble());
  }

  /// 记录活跃用户
  void recordActiveUsers(int count) {
    setGauge('active_users', count.toDouble());
  }

  // ==================== 导出 ====================

  /// 获取所有指标
  List<MetricValue> getAllMetrics() {
    final metrics = <MetricValue>[];

    // 计数器
    for (final entry in _counters.entries) {
      final parts = _parseKey(entry.key);
      metrics.add(MetricValue(
        name: parts.name,
        type: MetricType.counter,
        value: entry.value,
        labels: parts.labels,
      ));
    }

    // 仪表
    for (final entry in _gauges.entries) {
      final parts = _parseKey(entry.key);
      metrics.add(MetricValue(
        name: parts.name,
        type: MetricType.gauge,
        value: entry.value,
        labels: parts.labels,
      ));
    }

    // 直方图
    for (final histogram in _histograms.values) {
      metrics.add(MetricValue(
        name: '${histogram.name}_sum',
        type: MetricType.histogram,
        value: histogram.sum,
        labels: histogram.labels,
      ));
      metrics.add(MetricValue(
        name: '${histogram.name}_count',
        type: MetricType.histogram,
        value: histogram.count.toDouble(),
        labels: histogram.labels,
      ));
    }

    // 摘要
    for (final summary in _summaries.values) {
      final quantiles = summary.getQuantiles();
      for (final entry in quantiles.entries) {
        metrics.add(MetricValue(
          name: summary.name,
          type: MetricType.summary,
          value: entry.value,
          labels: {
            ...?summary.labels,
            'quantile': entry.key.toString(),
          },
        ));
      }
    }

    return metrics;
  }

  /// 刷新指标到远程
  Future<void> flush() async {
    if (_onFlush == null) return;

    final metrics = getAllMetrics();
    if (metrics.isEmpty) return;

    try {
      await _onFlush!(metrics);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to flush metrics: $e');
      }
    }
  }

  /// 重置所有指标
  void reset() {
    _counters.clear();
    _gauges.clear();
    for (final h in _histograms.values) {
      h.reset();
    }
    for (final s in _summaries.values) {
      s.reset();
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _flushTimer?.cancel();
    await flush();
    _initialized = false;
  }

  // ==================== 辅助方法 ====================

  String _buildKey(String name, Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return name;

    final sortedLabels = labels.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final labelStr = sortedLabels.map((e) => '${e.key}=${e.value}').join(',');
    return '$name{$labelStr}';
  }

  _MetricKeyParts _parseKey(String key) {
    final match = RegExp(r'^([^{]+)(?:\{(.+)\})?$').firstMatch(key);
    if (match == null) return _MetricKeyParts(key, null);

    final name = match.group(1)!;
    final labelStr = match.group(2);

    if (labelStr == null) return _MetricKeyParts(name, null);

    final labels = <String, String>{};
    for (final pair in labelStr.split(',')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        labels[parts[0]] = parts[1];
      }
    }

    return _MetricKeyParts(name, labels);
  }
}

class _MetricKeyParts {
  final String name;
  final Map<String, String>? labels;

  _MetricKeyParts(this.name, this.labels);
}

/// 指标服务配置
class MetricsConfig {
  /// 是否启用自动上报
  final bool enableAutoFlush;

  /// 上报间隔
  final Duration flushInterval;

  /// 计时器桶边界
  final List<double> timerBuckets;

  /// HTTP 请求时长桶边界
  final List<double> httpDurationBuckets;

  const MetricsConfig({
    this.enableAutoFlush = true,
    this.flushInterval = const Duration(seconds: 60),
    this.timerBuckets = const [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0],
    this.httpDurationBuckets = const [0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
  });
}

/// 全局指标实例
final metrics = MetricsService();
