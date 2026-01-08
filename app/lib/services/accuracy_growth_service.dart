import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Accuracy growth tracking service (第23章准确率成长曲线)
/// 追踪用户从70%到95%的准确率成长路径
class AccuracyGrowthService {
  static const String _keyAccuracyHistory = 'accuracy_growth_history';
  static const String _keyMilestones = 'accuracy_milestones';

  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Record a recognition result
  Future<void> recordRecognition({
    required RecognitionType type,
    required bool wasAccurate,
    required bool wasModified,
    String? originalCategory,
    String? correctedCategory,
  }) async {
    await _ensureInitialized();

    final history = await getAccuracyHistory();
    final now = DateTime.now();

    final record = AccuracyRecord(
      timestamp: now,
      type: type,
      wasAccurate: wasAccurate,
      wasModified: wasModified,
      originalCategory: originalCategory,
      correctedCategory: correctedCategory,
    );

    history.add(record);

    // Keep only last 1000 records
    if (history.length > 1000) {
      history.removeRange(0, history.length - 1000);
    }

    await _saveHistory(history);

    // Check for milestones
    await _checkMilestones(history);
  }

  /// Get accuracy history
  Future<List<AccuracyRecord>> getAccuracyHistory() async {
    await _ensureInitialized();
    final json = _prefs?.getString(_keyAccuracyHistory);
    if (json == null) return [];

    final list = jsonDecode(json) as List;
    return list.map((e) => AccuracyRecord.fromJson(e)).toList();
  }

  /// Get growth curve data points
  Future<AccuracyGrowthCurve> getGrowthCurve() async {
    final history = await getAccuracyHistory();
    if (history.isEmpty) {
      return AccuracyGrowthCurve(
        dataPoints: [],
        currentAccuracy: 0.7, // Starting point
        growthPhase: GrowthPhase.learning,
        projectedDaysToTarget: null,
      );
    }

    // Group by week
    final weeklyData = <DateTime, List<AccuracyRecord>>{};
    for (final record in history) {
      final weekStart = _getWeekStart(record.timestamp);
      weeklyData.putIfAbsent(weekStart, () => []).add(record);
    }

    // Calculate weekly accuracy
    final dataPoints = <AccuracyDataPoint>[];
    for (final entry in weeklyData.entries) {
      final records = entry.value;
      final accurate = records.where((r) => r.wasAccurate).length;
      final accuracy = records.isNotEmpty ? accurate / records.length : 0.0;

      dataPoints.add(AccuracyDataPoint(
        date: entry.key,
        accuracy: accuracy,
        sampleSize: records.length,
      ));
    }

    dataPoints.sort((a, b) => a.date.compareTo(b.date));

    // Calculate current accuracy (last 50 records)
    final recentRecords = history.length > 50
        ? history.sublist(history.length - 50)
        : history;
    final recentAccurate = recentRecords.where((r) => r.wasAccurate).length;
    final currentAccuracy = recentRecords.isNotEmpty
        ? recentAccurate / recentRecords.length
        : 0.7;

    // Determine growth phase
    final phase = _determineGrowthPhase(currentAccuracy, dataPoints);

    // Project days to target (95%)
    final projectedDays = _projectDaysToTarget(dataPoints, currentAccuracy);

    return AccuracyGrowthCurve(
      dataPoints: dataPoints,
      currentAccuracy: currentAccuracy,
      growthPhase: phase,
      projectedDaysToTarget: projectedDays,
    );
  }

  /// Get accuracy by recognition type
  Future<Map<RecognitionType, double>> getAccuracyByType() async {
    final history = await getAccuracyHistory();
    final result = <RecognitionType, double>{};

    for (final type in RecognitionType.values) {
      final typeRecords = history.where((r) => r.type == type).toList();
      if (typeRecords.isNotEmpty) {
        final accurate = typeRecords.where((r) => r.wasAccurate).length;
        result[type] = accurate / typeRecords.length;
      } else {
        result[type] = 0.7; // Default starting accuracy
      }
    }

    return result;
  }

  /// Get achieved milestones
  Future<List<AccuracyMilestone>> getAchievedMilestones() async {
    await _ensureInitialized();
    final json = _prefs?.getString(_keyMilestones);
    if (json == null) return [];

    final list = jsonDecode(json) as List;
    return list.map((e) => AccuracyMilestone.fromJson(e)).toList();
  }

  /// Get category correction patterns (for learning)
  Future<Map<String, String>> getCorrectionPatterns() async {
    final history = await getAccuracyHistory();
    final patterns = <String, Map<String, int>>{};

    for (final record in history) {
      if (record.wasModified &&
          record.originalCategory != null &&
          record.correctedCategory != null) {
        patterns.putIfAbsent(record.originalCategory!, () => {});
        patterns[record.originalCategory!]![record.correctedCategory!] =
            (patterns[record.originalCategory!]![record.correctedCategory!] ?? 0) + 1;
      }
    }

    // Find most common correction for each original category
    final result = <String, String>{};
    for (final entry in patterns.entries) {
      if (entry.value.isNotEmpty) {
        final sorted = entry.value.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (sorted.first.value >= 3) { // At least 3 corrections
          result[entry.key] = sorted.first.key;
        }
      }
    }

    return result;
  }

  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  GrowthPhase _determineGrowthPhase(double accuracy, List<AccuracyDataPoint> history) {
    if (accuracy >= 0.95) return GrowthPhase.mastery;
    if (accuracy >= 0.90) return GrowthPhase.proficient;
    if (accuracy >= 0.85) return GrowthPhase.improving;
    if (accuracy >= 0.80) return GrowthPhase.developing;
    return GrowthPhase.learning;
  }

  int? _projectDaysToTarget(List<AccuracyDataPoint> dataPoints, double currentAccuracy) {
    if (dataPoints.length < 2) return null;
    if (currentAccuracy >= 0.95) return 0;

    // Calculate weekly improvement rate
    final recentPoints = dataPoints.length > 4
        ? dataPoints.sublist(dataPoints.length - 4)
        : dataPoints;

    if (recentPoints.length < 2) return null;

    final first = recentPoints.first.accuracy;
    final last = recentPoints.last.accuracy;
    final weeks = recentPoints.length - 1;

    final weeklyImprovement = (last - first) / weeks;

    if (weeklyImprovement <= 0) return null;

    final remainingImprovement = 0.95 - currentAccuracy;
    final weeksToTarget = remainingImprovement / weeklyImprovement;

    return (weeksToTarget * 7).round();
  }

  Future<void> _checkMilestones(List<AccuracyRecord> history) async {
    final curve = await getGrowthCurve();
    final milestones = await getAchievedMilestones();

    final thresholds = [0.75, 0.80, 0.85, 0.90, 0.95];

    for (final threshold in thresholds) {
      final milestoneId = 'accuracy_${(threshold * 100).toInt()}';
      final alreadyAchieved = milestones.any((m) => m.id == milestoneId);

      if (!alreadyAchieved && curve.currentAccuracy >= threshold) {
        milestones.add(AccuracyMilestone(
          id: milestoneId,
          title: '准确率达到 ${(threshold * 100).toInt()}%',
          achievedAt: DateTime.now(),
          accuracy: threshold,
        ));
      }
    }

    await _saveMilestones(milestones);
  }

  Future<void> _saveHistory(List<AccuracyRecord> history) async {
    await _prefs?.setString(
      _keyAccuracyHistory,
      jsonEncode(history.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _saveMilestones(List<AccuracyMilestone> milestones) async {
    await _prefs?.setString(
      _keyMilestones,
      jsonEncode(milestones.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }
}

/// Recognition types
enum RecognitionType {
  voice,   // 语音记账
  camera,  // 拍照记账
  manual,  // 手动记账
  import_, // 导入记账
}

extension RecognitionTypeExtension on RecognitionType {
  String get displayName {
    switch (this) {
      case RecognitionType.voice:
        return '语音';
      case RecognitionType.camera:
        return '拍照';
      case RecognitionType.manual:
        return '手动';
      case RecognitionType.import_:
        return '导入';
    }
  }
}

/// Growth phases
enum GrowthPhase {
  learning,   // 70-80%: 学习期
  developing, // 80-85%: 发展期
  improving,  // 85-90%: 进步期
  proficient, // 90-95%: 熟练期
  mastery,    // 95%+: 精通期
}

extension GrowthPhaseExtension on GrowthPhase {
  String get displayName {
    switch (this) {
      case GrowthPhase.learning:
        return '学习期';
      case GrowthPhase.developing:
        return '发展期';
      case GrowthPhase.improving:
        return '进步期';
      case GrowthPhase.proficient:
        return '熟练期';
      case GrowthPhase.mastery:
        return '精通期';
    }
  }

  String get description {
    switch (this) {
      case GrowthPhase.learning:
        return '系统正在学习您的记账习惯';
      case GrowthPhase.developing:
        return '识别能力正在稳步提升';
      case GrowthPhase.improving:
        return '已经能够较好地理解您的需求';
      case GrowthPhase.proficient:
        return '识别准确率已达到较高水平';
      case GrowthPhase.mastery:
        return '系统已完全适应您的记账风格';
    }
  }
}

/// Accuracy record
class AccuracyRecord {
  final DateTime timestamp;
  final RecognitionType type;
  final bool wasAccurate;
  final bool wasModified;
  final String? originalCategory;
  final String? correctedCategory;

  AccuracyRecord({
    required this.timestamp,
    required this.type,
    required this.wasAccurate,
    required this.wasModified,
    this.originalCategory,
    this.correctedCategory,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.index,
    'wasAccurate': wasAccurate,
    'wasModified': wasModified,
    'originalCategory': originalCategory,
    'correctedCategory': correctedCategory,
  };

  factory AccuracyRecord.fromJson(Map<String, dynamic> json) => AccuracyRecord(
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: RecognitionType.values[json['type'] as int],
    wasAccurate: json['wasAccurate'] as bool,
    wasModified: json['wasModified'] as bool,
    originalCategory: json['originalCategory'] as String?,
    correctedCategory: json['correctedCategory'] as String?,
  );
}

/// Accuracy data point for chart
class AccuracyDataPoint {
  final DateTime date;
  final double accuracy;
  final int sampleSize;

  AccuracyDataPoint({
    required this.date,
    required this.accuracy,
    required this.sampleSize,
  });
}

/// Accuracy growth curve
class AccuracyGrowthCurve {
  final List<AccuracyDataPoint> dataPoints;
  final double currentAccuracy;
  final GrowthPhase growthPhase;
  final int? projectedDaysToTarget;

  AccuracyGrowthCurve({
    required this.dataPoints,
    required this.currentAccuracy,
    required this.growthPhase,
    this.projectedDaysToTarget,
  });
}

/// Accuracy milestone
class AccuracyMilestone {
  final String id;
  final String title;
  final DateTime achievedAt;
  final double accuracy;

  AccuracyMilestone({
    required this.id,
    required this.title,
    required this.achievedAt,
    required this.accuracy,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'achievedAt': achievedAt.toIso8601String(),
    'accuracy': accuracy,
  };

  factory AccuracyMilestone.fromJson(Map<String, dynamic> json) => AccuracyMilestone(
    id: json['id'] as String,
    title: json['title'] as String,
    achievedAt: DateTime.parse(json['achievedAt'] as String),
    accuracy: json['accuracy'] as double,
  );
}
