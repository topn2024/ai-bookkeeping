import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 数据不足警告
class AnomalyDataInsufficiency {
  final AnomalyType checkType;
  final String message;
  final int currentDataCount;
  final int requiredDataCount;

  const AnomalyDataInsufficiency({
    required this.checkType,
    required this.message,
    required this.currentDataCount,
    required this.requiredDataCount,
  });
}

/// 异常检测结果
class AnomalyDetectionResult {
  final List<AnomalyAlert> alerts;
  final List<AnomalyDataInsufficiency> dataInsufficiencies;

  const AnomalyDetectionResult({
    required this.alerts,
    required this.dataInsufficiencies,
  });

  bool get hasDataInsufficiency => dataInsufficiencies.isNotEmpty;

  String get summaryMessage {
    if (dataInsufficiencies.isEmpty) {
      return '完成${alerts.length}项异常检测';
    }
    return '完成${alerts.length}项异常检测，${dataInsufficiencies.length}项检测因数据不足跳过';
  }
}

/// 单个检测结果
class _DetectionResult {
  final AnomalyAlert? alert;
  final AnomalyDataInsufficiency? insufficiency;

  const _DetectionResult({this.alert, this.insufficiency});
}

/// 交易异常检测服务
///
/// 功能：
/// 1. 金额异常检测（3σ原则）
/// 2. 时间异常检测（凌晨消费等）
/// 3. 频率异常检测（异常高频消费）
/// 4. 重复交易检测
/// 5. 个性化阈值学习
class AnomalyDetectionService {
  final AnomalyTransactionRepository _transactionRepo;
  final AnomalyPreferencesRepository _preferencesRepo;

  AnomalyDetectionService({
    required AnomalyTransactionRepository transactionRepo,
    AnomalyPreferencesRepository? preferencesRepo,
  })  : _transactionRepo = transactionRepo,
        _preferencesRepo = preferencesRepo ?? InMemoryPreferencesRepository();

  /// 检测异常交易（包含数据不足信息）
  Future<AnomalyDetectionResult> detectAnomaliesWithInfo(
    AnomalyTransaction newTx, {
    String? userId,
  }) async {
    final alerts = <AnomalyAlert>[];
    final dataInsufficiencies = <AnomalyDataInsufficiency>[];

    // 获取用户个性化偏好（如有）
    UserAnomalyPreferences? prefs;
    if (userId != null) {
      prefs = await _preferencesRepo.get(userId);
    }

    // ===== 检测1: 金额异常（基于分类历史） =====
    final amountResult = await _detectAmountAnomalyWithInfo(newTx, prefs);
    if (amountResult.alert != null) {
      alerts.add(amountResult.alert!);
    }
    if (amountResult.insufficiency != null) {
      dataInsufficiencies.add(amountResult.insufficiency!);
    }

    // ===== 检测2: 时间异常 =====
    final timeResult = await _detectTimeAnomalyWithInfo(newTx, prefs);
    if (timeResult.alert != null) {
      alerts.add(timeResult.alert!);
    }
    if (timeResult.insufficiency != null) {
      dataInsufficiencies.add(timeResult.insufficiency!);
    }

    // ===== 检测3: 频率异常 =====
    final frequencyResult = await _detectFrequencyAnomalyWithInfo(newTx, prefs);
    if (frequencyResult.alert != null) {
      alerts.add(frequencyResult.alert!);
    }
    if (frequencyResult.insufficiency != null) {
      dataInsufficiencies.add(frequencyResult.insufficiency!);
    }

    // ===== 检测4: 重复交易嫌疑 =====
    final duplicateAlert = await _detectDuplicateAnomaly(newTx);
    if (duplicateAlert != null) {
      alerts.add(duplicateAlert);
    }

    // ===== 检测5: 异地消费 =====
    final locationAlert = await _detectLocationAnomaly(newTx, prefs);
    if (locationAlert != null) {
      alerts.add(locationAlert);
    }

    return AnomalyDetectionResult(
      alerts: alerts,
      dataInsufficiencies: dataInsufficiencies,
    );
  }

  /// 检测异常交易（向后兼容）
  Future<List<AnomalyAlert>> detectAnomalies(
    AnomalyTransaction newTx, {
    String? userId,
  }) async {
    final result = await detectAnomaliesWithInfo(newTx, userId: userId);
    return result.alerts;
  }

  /// 金额异常检测（包含数据不足信息）
  Future<_DetectionResult> _detectAmountAnomalyWithInfo(
    AnomalyTransaction newTx,
    UserAnomalyPreferences? prefs,
  ) async {
    if (newTx.categoryId == null) return const _DetectionResult();

    final categoryHistory = await _transactionRepo.getByCategory(
      newTx.categoryId!,
      limit: 50,
    );

    if (categoryHistory.length < 10) {
      return _DetectionResult(
        insufficiency: AnomalyDataInsufficiency(
          checkType: AnomalyType.unusualAmount,
          message: '金额异常检测需要至少10笔历史交易（当前${categoryHistory.length}笔）',
          currentDataCount: categoryHistory.length,
          requiredDataCount: 10,
        ),
      );
    }

    final alert = await _detectAmountAnomaly(newTx, prefs);
    return _DetectionResult(alert: alert);
  }

  /// 时间异常检测（包含数据不足信息）
  Future<_DetectionResult> _detectTimeAnomalyWithInfo(
    AnomalyTransaction newTx,
    UserAnomalyPreferences? prefs,
  ) async {
    final alert = await _detectTimeAnomaly(newTx, prefs);
    return _DetectionResult(alert: alert);
  }

  /// 频率异常检测（包含数据不足信息）
  Future<_DetectionResult> _detectFrequencyAnomalyWithInfo(
    AnomalyTransaction newTx,
    UserAnomalyPreferences? prefs,
  ) async {
    if (newTx.categoryId == null) return const _DetectionResult();

    final categoryHistory = await _transactionRepo.getByCategory(
      newTx.categoryId!,
      limit: 50,
    );

    if (categoryHistory.length < 10) {
      return _DetectionResult(
        insufficiency: AnomalyDataInsufficiency(
          checkType: AnomalyType.unusualFrequency,
          message: '频率异常检测需要至少10笔历史交易（当前${categoryHistory.length}笔）',
          currentDataCount: categoryHistory.length,
          requiredDataCount: 10,
        ),
      );
    }

    final alert = await _detectFrequencyAnomaly(newTx, prefs);
    return _DetectionResult(alert: alert);
  }


  /// 金额异常检测
  Future<AnomalyAlert?> _detectAmountAnomaly(
    AnomalyTransaction newTx,
    UserAnomalyPreferences? prefs,
  ) async {
    if (newTx.categoryId == null) return null;

    final categoryHistory = await _transactionRepo.getByCategory(
      newTx.categoryId!,
      limit: 50,
    );

    if (categoryHistory.length < 10) return null;

    final amounts = categoryHistory.map((t) => t.amount).toList();
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final stdDev = _calculateStdDev(amounts);

    if (stdDev == 0) return null;

    // 获取个性化阈值，默认为 2.0
    final threshold = prefs?.categoryThresholds[newTx.categoryId] ?? 2.0;

    final zScore = (newTx.amount - mean).abs() / stdDev;

    // 3σ原则：超过3个标准差视为高异常
    if (zScore > 3 * threshold / 2) {
      return AnomalyAlert(
        id: _generateId(),
        type: AnomalyType.unusualAmount,
        severity: AnomalySeverity.high,
        transactionId: newTx.id,
        message:
            '此笔${newTx.categoryName ?? ""}消费金额(¥${newTx.amount.toStringAsFixed(2)})显著高于平均水平(¥${mean.toStringAsFixed(0)})',
        suggestion: '请确认金额是否正确',
        metadata: {
          'mean': mean,
          'stdDev': stdDev,
          'zScore': zScore,
        },
        createdAt: DateTime.now(),
      );
    } else if (zScore > 2 * threshold / 2) {
      return AnomalyAlert(
        id: _generateId(),
        type: AnomalyType.unusualAmount,
        severity: AnomalySeverity.medium,
        transactionId: newTx.id,
        message: '此笔消费金额较高',
        metadata: {
          'mean': mean,
          'stdDev': stdDev,
          'zScore': zScore,
        },
        createdAt: DateTime.now(),
      );
    }

    return null;
  }

  /// 时间异常检测
  Future<AnomalyAlert?> _detectTimeAnomaly(
    AnomalyTransaction newTx,
    UserAnomalyPreferences? prefs,
  ) async {
    final hour = newTx.date.hour;

    // 凌晨消费（0:00 - 6:00）
    if (hour >= 0 && hour < 6) {
      if (newTx.categoryId == null) {
        return AnomalyAlert(
          id: _generateId(),
          type: AnomalyType.unusualTime,
          severity: AnomalySeverity.low,
          transactionId: newTx.id,
          message: '凌晨消费记录',
          createdAt: DateTime.now(),
        );
      }

      final categoryHistory = await _transactionRepo.getByCategory(
        newTx.categoryId!,
        limit: 50,
      );

      if (categoryHistory.isEmpty) return null;

      final lateNightHistory = categoryHistory.where((t) {
        final h = t.date.hour;
        return h >= 0 && h < 6;
      }).length;

      // 如果凌晨消费少于10%，则视为异常
      if (lateNightHistory < categoryHistory.length * 0.1) {
        return AnomalyAlert(
          id: _generateId(),
          type: AnomalyType.unusualTime,
          severity: AnomalySeverity.low,
          transactionId: newTx.id,
          message: '凌晨消费记录，与您的消费习惯不符',
          metadata: {
            'lateNightRatio': lateNightHistory / categoryHistory.length,
          },
          createdAt: DateTime.now(),
        );
      }
    }

    return null;
  }

  /// 频率异常检测
  Future<AnomalyAlert?> _detectFrequencyAnomaly(
    AnomalyTransaction newTx,
    UserAnomalyPreferences? prefs,
  ) async {
    if (newTx.categoryId == null) return null;

    final todayCount = await _transactionRepo.countToday(newTx.categoryId!);
    final categoryHistory = await _transactionRepo.getByCategory(
      newTx.categoryId!,
      limit: 50,
    );

    if (categoryHistory.length < 10) return null;

    // 计算日均消费次数（假设30天历史）
    final avgDailyCount = categoryHistory.length / 30;

    // 敏感度调整
    final sensitivity = prefs?.frequencySensitivity ?? 0.5;
    final multiplier = 3.0 - sensitivity; // 敏感度越高，阈值越低

    if (todayCount > avgDailyCount * multiplier && todayCount > 3) {
      return AnomalyAlert(
        id: _generateId(),
        type: AnomalyType.unusualFrequency,
        severity: AnomalySeverity.medium,
        transactionId: newTx.id,
        message:
            '今日${newTx.categoryName ?? "此类"}消费次数($todayCount次)明显多于平常',
        suggestion: '是否有重复记录?',
        metadata: {
          'todayCount': todayCount,
          'avgDailyCount': avgDailyCount,
        },
        createdAt: DateTime.now(),
      );
    }

    return null;
  }

  /// 重复交易检测
  Future<AnomalyAlert?> _detectDuplicateAnomaly(AnomalyTransaction newTx) async {
    final duplicateSuspects = await _findPotentialDuplicates(newTx);

    if (duplicateSuspects.isNotEmpty) {
      return AnomalyAlert(
        id: _generateId(),
        type: AnomalyType.potentialDuplicate,
        severity: AnomalySeverity.high,
        transactionId: newTx.id,
        message: '发现${duplicateSuspects.length}笔相似交易',
        suggestion: '点击查看是否重复',
        relatedTransactionIds: duplicateSuspects.map((t) => t.id).toList(),
        metadata: {
          'duplicateCount': duplicateSuspects.length,
        },
        createdAt: DateTime.now(),
      );
    }

    return null;
  }

  /// 异地消费检测
  Future<AnomalyAlert?> _detectLocationAnomaly(
    AnomalyTransaction newTx,
    UserAnomalyPreferences? prefs,
  ) async {
    if (newTx.city == null) return null;

    // 获取用户常驻城市
    final homeCity = await _transactionRepo.getMostFrequentCity();
    if (homeCity == null || homeCity == newTx.city) return null;

    // 检查是否经常去这个城市
    final cityVisits = await _transactionRepo.getCityVisitCount(newTx.city!);
    if (cityVisits > 5) return null; // 经常去的城市不报警

    // 敏感度调整
    final sensitivity = prefs?.locationSensitivity ?? 0.5;
    if (sensitivity < 0.3) return null; // 用户不关心异地消费

    return AnomalyAlert(
      id: _generateId(),
      type: AnomalyType.unusualLocation,
      severity: AnomalySeverity.low,
      transactionId: newTx.id,
      message: '检测到异地消费（${newTx.city}）',
      suggestion: '如有出行计划可忽略此提醒',
      metadata: {
        'currentCity': newTx.city,
        'homeCity': homeCity,
      },
      createdAt: DateTime.now(),
    );
  }

  /// 查找潜在重复交易
  Future<List<AnomalyTransaction>> _findPotentialDuplicates(
    AnomalyTransaction tx,
  ) async {
    // 查找同一天、相同金额的交易
    final sameDaySameAmount = await _transactionRepo.findByDateAndAmount(
      date: tx.date,
      amount: tx.amount,
      excludeId: tx.id,
    );

    // 使用描述相似度过滤
    return sameDaySameAmount.where((t) {
      final similarity =
          _stringSimilarity(t.description ?? '', tx.description ?? '');
      return similarity > 0.6;
    }).toList();
  }

  /// 字符串相似度（Jaccard相似度）
  double _stringSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final setA = a.split('').toSet();
    final setB = b.split('').toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// 计算标准差
  double _calculateStdDev(List<double> values) {
    if (values.length < 2) return 0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;

    return sqrt(variance);
  }

  /// 记录用户对异常的反馈
  Future<void> recordFeedback({
    required String alertId,
    required String userId,
    required AnomalyFeedbackType feedbackType,
  }) async {
    // 记录反馈用于后续学习
    debugPrint('Anomaly feedback recorded: $alertId -> $feedbackType');

    // 更新用户偏好
    await _updateUserPreferences(userId, alertId, feedbackType);
  }

  /// 更新用户偏好
  Future<void> _updateUserPreferences(
    String userId,
    String alertId,
    AnomalyFeedbackType feedbackType,
  ) async {
    var prefs = await _preferencesRepo.get(userId);
    prefs ??= UserAnomalyPreferences.defaultPrefs();

    // 根据反馈调整偏好
    if (feedbackType == AnomalyFeedbackType.dismissed) {
      // 用户忽略了提醒，降低敏感度
      prefs = prefs.copyWith(
        amountSensitivity: (prefs.amountSensitivity * 0.95).clamp(0.1, 1.0),
      );
    } else if (feedbackType == AnomalyFeedbackType.confirmed) {
      // 用户确认了异常，提高敏感度
      prefs = prefs.copyWith(
        amountSensitivity: (prefs.amountSensitivity * 1.05).clamp(0.1, 1.0),
      );
    }

    await _preferencesRepo.save(userId, prefs);
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }
}

/// 异常类型
enum AnomalyType {
  unusualAmount, // 金额异常
  unusualTime, // 时间异常
  unusualFrequency, // 频率异常
  potentialDuplicate, // 潜在重复
  unusualCategory, // 分类异常
  unusualLocation, // 位置异常
}

/// 异常严重程度
enum AnomalySeverity {
  low, // 低
  medium, // 中
  high, // 高
}

/// 异常反馈类型
enum AnomalyFeedbackType {
  confirmed, // 用户确认是异常
  dismissed, // 用户忽略
  corrected, // 用户修正
}

/// 异常警报
class AnomalyAlert {
  final String id;
  final AnomalyType type;
  final AnomalySeverity severity;
  final String transactionId;
  final String message;
  final String? suggestion;
  final List<String>? relatedTransactionIds;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isRead;

  const AnomalyAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.transactionId,
    required this.message,
    this.suggestion,
    this.relatedTransactionIds,
    this.metadata,
    required this.createdAt,
    this.isRead = false,
  });

  AnomalyAlert copyWith({
    bool? isRead,
  }) {
    return AnomalyAlert(
      id: id,
      type: type,
      severity: severity,
      transactionId: transactionId,
      message: message,
      suggestion: suggestion,
      relatedTransactionIds: relatedTransactionIds,
      metadata: metadata,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  String toString() {
    return 'AnomalyAlert(type: $type, severity: $severity, message: $message)';
  }
}

/// 用户异常偏好
class UserAnomalyPreferences {
  final Map<String, double> categoryThresholds; // 默认2.0
  final double amountSensitivity; // 0-1, 默认0.5
  final double locationSensitivity; // 0-1, 默认0.5
  final double frequencySensitivity; // 0-1, 默认0.5
  final double timeSensitivity; // 0-1, 默认0.5

  const UserAnomalyPreferences({
    required this.categoryThresholds,
    required this.amountSensitivity,
    required this.locationSensitivity,
    required this.frequencySensitivity,
    required this.timeSensitivity,
  });

  factory UserAnomalyPreferences.defaultPrefs() {
    return const UserAnomalyPreferences(
      categoryThresholds: {},
      amountSensitivity: 0.5,
      locationSensitivity: 0.5,
      frequencySensitivity: 0.5,
      timeSensitivity: 0.5,
    );
  }

  UserAnomalyPreferences copyWith({
    Map<String, double>? categoryThresholds,
    double? amountSensitivity,
    double? locationSensitivity,
    double? frequencySensitivity,
    double? timeSensitivity,
  }) {
    return UserAnomalyPreferences(
      categoryThresholds: categoryThresholds ?? this.categoryThresholds,
      amountSensitivity: amountSensitivity ?? this.amountSensitivity,
      locationSensitivity: locationSensitivity ?? this.locationSensitivity,
      frequencySensitivity: frequencySensitivity ?? this.frequencySensitivity,
      timeSensitivity: timeSensitivity ?? this.timeSensitivity,
    );
  }

  /// 应用个性化阈值判定异常
  bool isAnomalous({
    required AnomalyType type,
    required double zScore,
    String? categoryId,
  }) {
    double threshold;

    switch (type) {
      case AnomalyType.unusualAmount:
        threshold = categoryThresholds[categoryId] ?? 2.0;
        return zScore > threshold * (1 + (1 - amountSensitivity));
      case AnomalyType.unusualLocation:
        return locationSensitivity > 0.3;
      case AnomalyType.unusualFrequency:
        threshold = 3.0 - frequencySensitivity;
        return zScore > threshold;
      default:
        return zScore > 2.0;
    }
  }
}

/// 异常交易数据
class AnomalyTransaction {
  final String id;
  final double amount;
  final DateTime date;
  final String? categoryId;
  final String? categoryName;
  final String? merchant;
  final String? description;
  final String? city;
  final double? latitude;
  final double? longitude;

  const AnomalyTransaction({
    required this.id,
    required this.amount,
    required this.date,
    this.categoryId,
    this.categoryName,
    this.merchant,
    this.description,
    this.city,
    this.latitude,
    this.longitude,
  });
}

/// 异常交易仓库接口
abstract class AnomalyTransactionRepository {
  Future<List<AnomalyTransaction>> getByCategory(String categoryId,
      {int limit});
  Future<int> countToday(String categoryId);
  Future<List<AnomalyTransaction>> findByDateAndAmount({
    required DateTime date,
    required double amount,
    String? excludeId,
  });
  Future<String?> getMostFrequentCity();
  Future<int> getCityVisitCount(String city);
}

/// 用户偏好仓库接口
abstract class AnomalyPreferencesRepository {
  Future<UserAnomalyPreferences?> get(String userId);
  Future<void> save(String userId, UserAnomalyPreferences prefs);
}

/// 内存偏好仓库实现
class InMemoryPreferencesRepository implements AnomalyPreferencesRepository {
  final Map<String, UserAnomalyPreferences> _cache = {};

  @override
  Future<UserAnomalyPreferences?> get(String userId) async {
    return _cache[userId];
  }

  @override
  Future<void> save(String userId, UserAnomalyPreferences prefs) async {
    _cache[userId] = prefs;
  }
}
