import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Scenario-based timing statistics service (第23章场景化耗时统计)
/// 统计语音/拍照/手动各场景的记账耗时
class ScenarioTimingService {
  static const String _keyTimingHistory = 'scenario_timing_history';
  // ignore: unused_field
  static const String __keyDailyStats = 'scenario_daily_stats';

  SharedPreferences? _prefs;

  // Active timing sessions
  final Map<String, DateTime> _activeSessions = {};

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Start timing a transaction entry
  String startTiming(TransactionScenario scenario) {
    final sessionId = '${scenario.name}_${DateTime.now().millisecondsSinceEpoch}';
    _activeSessions[sessionId] = DateTime.now();
    return sessionId;
  }

  /// End timing and record the result
  Future<TimingRecord?> endTiming(String sessionId, {
    bool wasSuccessful = true,
    bool wasModified = false,
    int? stepCount,
  }) async {
    await _ensureInitialized();

    final startTime = _activeSessions.remove(sessionId);
    if (startTime == null) return null;

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    // Parse scenario from session ID
    final scenarioName = sessionId.split('_').first;
    final scenario = TransactionScenario.values.firstWhere(
      (s) => s.name == scenarioName,
      orElse: () => TransactionScenario.manual,
    );

    final record = TimingRecord(
      sessionId: sessionId,
      scenario: scenario,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      wasSuccessful: wasSuccessful,
      wasModified: wasModified,
      stepCount: stepCount,
    );

    await _saveRecord(record);
    return record;
  }

  /// Cancel an active timing session
  void cancelTiming(String sessionId) {
    _activeSessions.remove(sessionId);
  }

  /// Get timing statistics by scenario
  Future<Map<TransactionScenario, ScenarioTimingStats>> getStatsByScenario() async {
    final history = await _getTimingHistory();
    final result = <TransactionScenario, ScenarioTimingStats>{};

    for (final scenario in TransactionScenario.values) {
      final records = history.where((r) => r.scenario == scenario).toList();
      if (records.isNotEmpty) {
        result[scenario] = _calculateStats(records);
      } else {
        result[scenario] = ScenarioTimingStats.empty(scenario);
      }
    }

    return result;
  }

  /// Get today's timing summary
  Future<DailyTimingSummary> getTodaySummary() async {
    final history = await _getTimingHistory();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final todayRecords = history.where((r) => r.startTime.isAfter(todayStart)).toList();

    return DailyTimingSummary(
      date: today,
      totalTransactions: todayRecords.length,
      totalDuration: todayRecords.fold(
        Duration.zero,
        (sum, r) => sum + r.duration,
      ),
      byScenario: _groupByScenario(todayRecords),
      averagePerTransaction: todayRecords.isNotEmpty
          ? Duration(
              milliseconds: todayRecords.fold<int>(
                    0,
                    (sum, r) => sum + r.duration.inMilliseconds,
                  ) ~/
                  todayRecords.length,
            )
          : Duration.zero,
    );
  }

  /// Get weekly trend
  Future<List<DailyTimingSummary>> getWeeklyTrend() async {
    final history = await _getTimingHistory();
    final result = <DailyTimingSummary>[];

    final today = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayRecords = history.where((r) =>
        r.startTime.isAfter(dayStart) && r.startTime.isBefore(dayEnd)
      ).toList();

      result.add(DailyTimingSummary(
        date: date,
        totalTransactions: dayRecords.length,
        totalDuration: dayRecords.fold(
          Duration.zero,
          (sum, r) => sum + r.duration,
        ),
        byScenario: _groupByScenario(dayRecords),
        averagePerTransaction: dayRecords.isNotEmpty
            ? Duration(
                milliseconds: dayRecords.fold<int>(
                      0,
                      (sum, r) => sum + r.duration.inMilliseconds,
                    ) ~/
                    dayRecords.length,
              )
            : Duration.zero,
      ));
    }

    return result;
  }

  /// Get efficiency comparison between scenarios
  Future<ScenarioEfficiencyComparison> getEfficiencyComparison() async {
    final stats = await getStatsByScenario();

    // Find fastest scenario
    TransactionScenario? fastestScenario;
    Duration? fastestDuration;

    for (final entry in stats.entries) {
      if (entry.value.sampleSize >= 5) { // Need at least 5 samples
        if (fastestDuration == null ||
            entry.value.averageDuration < fastestDuration) {
          fastestScenario = entry.key;
          fastestDuration = entry.value.averageDuration;
        }
      }
    }

    return ScenarioEfficiencyComparison(
      stats: stats,
      fastestScenario: fastestScenario,
      recommendations: _generateRecommendations(stats),
    );
  }

  /// Get time saved compared to manual entry
  Future<Duration> getTimeSaved() async {
    final stats = await getStatsByScenario();
    final manualStats = stats[TransactionScenario.manual];

    if (manualStats == null || manualStats.sampleSize < 5) {
      // Default manual time: 30 seconds
      return Duration.zero;
    }

    final manualAvg = manualStats.averageDuration;
    var totalSaved = Duration.zero;

    for (final entry in stats.entries) {
      if (entry.key != TransactionScenario.manual && entry.value.sampleSize > 0) {
        final savedPerTransaction = manualAvg - entry.value.averageDuration;
        if (savedPerTransaction.isNegative == false) {
          totalSaved += savedPerTransaction * entry.value.sampleSize;
        }
      }
    }

    return totalSaved;
  }

  ScenarioTimingStats _calculateStats(List<TimingRecord> records) {
    if (records.isEmpty) {
      return ScenarioTimingStats.empty(TransactionScenario.manual);
    }

    final durations = records.map((r) => r.duration.inMilliseconds).toList()..sort();
    final total = durations.fold<int>(0, (sum, d) => sum + d);

    return ScenarioTimingStats(
      scenario: records.first.scenario,
      sampleSize: records.length,
      averageDuration: Duration(milliseconds: total ~/ records.length),
      medianDuration: Duration(milliseconds: durations[durations.length ~/ 2]),
      minDuration: Duration(milliseconds: durations.first),
      maxDuration: Duration(milliseconds: durations.last),
      successRate: records.where((r) => r.wasSuccessful).length / records.length,
      modificationRate: records.where((r) => r.wasModified).length / records.length,
    );
  }

  Map<TransactionScenario, int> _groupByScenario(List<TimingRecord> records) {
    final result = <TransactionScenario, int>{};
    for (final record in records) {
      result[record.scenario] = (result[record.scenario] ?? 0) + 1;
    }
    return result;
  }

  List<String> _generateRecommendations(Map<TransactionScenario, ScenarioTimingStats> stats) {
    final recommendations = <String>[];

    // Check voice efficiency
    final voiceStats = stats[TransactionScenario.voice];
    if (voiceStats != null && voiceStats.sampleSize < 10) {
      recommendations.add('多尝试语音记账，通常能节省50%以上的时间');
    }

    // Check camera efficiency
    final cameraStats = stats[TransactionScenario.camera];
    if (cameraStats != null && cameraStats.modificationRate > 0.3) {
      recommendations.add('拍照识别准确率较低，建议确保票据清晰、光线充足');
    }

    // Check manual entry time
    final manualStats = stats[TransactionScenario.manual];
    if (manualStats != null && manualStats.averageDuration.inSeconds > 45) {
      recommendations.add('手动记账耗时较长，可以考虑使用语音或模板记账');
    }

    // Check template usage
    final templateStats = stats[TransactionScenario.template];
    if (templateStats == null || templateStats.sampleSize < 5) {
      recommendations.add('为常用消费创建模板，可以大幅提升记账效率');
    }

    return recommendations;
  }

  Future<List<TimingRecord>> _getTimingHistory() async {
    await _ensureInitialized();
    final json = _prefs?.getString(_keyTimingHistory);
    if (json == null) return [];

    final list = jsonDecode(json) as List;
    return list.map((e) => TimingRecord.fromJson(e)).toList();
  }

  Future<void> _saveRecord(TimingRecord record) async {
    final history = await _getTimingHistory();
    history.add(record);

    // Keep only last 500 records
    if (history.length > 500) {
      history.removeRange(0, history.length - 500);
    }

    await _prefs?.setString(
      _keyTimingHistory,
      jsonEncode(history.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }
}

/// Transaction entry scenarios
enum TransactionScenario {
  voice,    // 语音记账
  camera,   // 拍照记账
  manual,   // 手动记账
  template, // 模板记账
  import_,  // 导入记账
}

extension TransactionScenarioExtension on TransactionScenario {
  String get displayName {
    switch (this) {
      case TransactionScenario.voice:
        return '语音记账';
      case TransactionScenario.camera:
        return '拍照记账';
      case TransactionScenario.manual:
        return '手动记账';
      case TransactionScenario.template:
        return '模板记账';
      case TransactionScenario.import_:
        return '导入记账';
    }
  }

  String get icon {
    switch (this) {
      case TransactionScenario.voice:
        return 'mic';
      case TransactionScenario.camera:
        return 'camera_alt';
      case TransactionScenario.manual:
        return 'edit';
      case TransactionScenario.template:
        return 'bookmark';
      case TransactionScenario.import_:
        return 'file_upload';
    }
  }
}

/// Timing record
class TimingRecord {
  final String sessionId;
  final TransactionScenario scenario;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final bool wasSuccessful;
  final bool wasModified;
  final int? stepCount;

  TimingRecord({
    required this.sessionId,
    required this.scenario,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.wasSuccessful,
    required this.wasModified,
    this.stepCount,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'scenario': scenario.index,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'wasSuccessful': wasSuccessful,
    'wasModified': wasModified,
    'stepCount': stepCount,
  };

  factory TimingRecord.fromJson(Map<String, dynamic> json) => TimingRecord(
    sessionId: json['sessionId'] as String,
    scenario: TransactionScenario.values[json['scenario'] as int],
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    duration: Duration(milliseconds: json['durationMs'] as int),
    wasSuccessful: json['wasSuccessful'] as bool,
    wasModified: json['wasModified'] as bool,
    stepCount: json['stepCount'] as int?,
  );
}

/// Statistics for a scenario
class ScenarioTimingStats {
  final TransactionScenario scenario;
  final int sampleSize;
  final Duration averageDuration;
  final Duration medianDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final double successRate;
  final double modificationRate;

  ScenarioTimingStats({
    required this.scenario,
    required this.sampleSize,
    required this.averageDuration,
    required this.medianDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.successRate,
    required this.modificationRate,
  });

  factory ScenarioTimingStats.empty(TransactionScenario scenario) => ScenarioTimingStats(
    scenario: scenario,
    sampleSize: 0,
    averageDuration: Duration.zero,
    medianDuration: Duration.zero,
    minDuration: Duration.zero,
    maxDuration: Duration.zero,
    successRate: 0.0,
    modificationRate: 0.0,
  );
}

/// Daily timing summary
class DailyTimingSummary {
  final DateTime date;
  final int totalTransactions;
  final Duration totalDuration;
  final Map<TransactionScenario, int> byScenario;
  final Duration averagePerTransaction;

  DailyTimingSummary({
    required this.date,
    required this.totalTransactions,
    required this.totalDuration,
    required this.byScenario,
    required this.averagePerTransaction,
  });
}

/// Scenario efficiency comparison
class ScenarioEfficiencyComparison {
  final Map<TransactionScenario, ScenarioTimingStats> stats;
  final TransactionScenario? fastestScenario;
  final List<String> recommendations;

  ScenarioEfficiencyComparison({
    required this.stats,
    this.fastestScenario,
    required this.recommendations,
  });
}
