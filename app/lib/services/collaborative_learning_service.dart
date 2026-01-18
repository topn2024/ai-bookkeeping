import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import 'privacy/differential_privacy/differential_privacy_engine.dart';
import 'privacy/anomaly_detection/anomaly_detector.dart';

/// 协同学习服务
///
/// 功能：
/// 1. 本地规则脱敏上报
/// 2. 下载协同规则
/// 3. 规则融合
/// 4. 隐私保护（差分隐私 + 异常检测）
class CollaborativeLearningService {
  final CollaborativeApiClient _apiClient;
  final LocalRuleStorage _ruleStorage;
  final Duration _syncInterval;
  Timer? _syncTimer;
  bool _isEnabled = true;

  /// 差分隐私引擎（可选）
  final DifferentialPrivacyEngine? _privacyEngine;

  /// 异常检测器（可选）
  final AnomalyDetector? _anomalyDetector;

  /// 当前用户ID（用于异常追踪）
  String? _currentUserId;

  CollaborativeLearningService({
    required CollaborativeApiClient apiClient,
    required LocalRuleStorage ruleStorage,
    Duration? syncInterval,
    DifferentialPrivacyEngine? privacyEngine,
    AnomalyDetector? anomalyDetector,
    String? currentUserId,
  })  : _apiClient = apiClient,
        _ruleStorage = ruleStorage,
        _syncInterval = syncInterval ?? const Duration(hours: 6),
        _privacyEngine = privacyEngine,
        _anomalyDetector = anomalyDetector,
        _currentUserId = currentUserId;

  /// 差分隐私引擎
  DifferentialPrivacyEngine? get privacyEngine => _privacyEngine;

  /// 异常检测器
  AnomalyDetector? get anomalyDetector => _anomalyDetector;

  /// 设置当前用户ID
  set currentUserId(String? userId) => _currentUserId = userId;

  /// 是否启用协同学习
  bool get isEnabled => _isEnabled;
  set isEnabled(bool value) {
    _isEnabled = value;
    if (value) {
      start();
    } else {
      stop();
    }
  }

  /// 启动协同学习
  void start() {
    if (!_isEnabled) return;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _syncWithCloud());
    // 立即执行一次
    _syncWithCloud();
  }

  /// 停止协同学习
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// 与云端同步
  Future<SyncResult> _syncWithCloud() async {
    if (!_isEnabled) {
      return SyncResult(success: false, reason: '协同学习已禁用');
    }

    // 检查隐私预算是否耗尽
    if (_privacyEngine != null && !_privacyEngine.canPerformOperation) {
      debugPrint('协同学习：隐私预算已耗尽，跳过本次同步');
      return SyncResult(
        success: false,
        reason: '隐私预算已耗尽',
        privacyBudgetExhausted: true,
      );
    }

    try {
      // 1. 上报本地脱敏数据（含差分隐私保护）
      final uploadResult = await _uploadAnonymizedPatterns();

      // 2. 下载协同规则
      final collaborativeRules = await _downloadCollaborativeRules();

      // 3. 融合到本地（含异常检测）
      final mergeResult = await _mergeCollaborativeRules(collaborativeRules);

      debugPrint(
        '协同学习同步成功: 上传${uploadResult.uploadedCount}条'
        '${uploadResult.protectedCount > 0 ? "(差分隐私保护${uploadResult.protectedCount}条)" : ""}, '
        '下载${collaborativeRules.length}条, '
        '融合${mergeResult.mergedCount}条'
        '${mergeResult.filteredCount > 0 ? "(过滤异常${mergeResult.filteredCount}条)" : ""}',
      );

      return SyncResult(
        success: true,
        uploadedCount: uploadResult.uploadedCount,
        downloadedCount: collaborativeRules.length,
        mergedCount: mergeResult.mergedCount,
        protectedCount: uploadResult.protectedCount,
        filteredAnomalyCount: mergeResult.filteredCount,
      );
    } catch (e) {
      debugPrint('协同学习同步失败: $e');
      return SyncResult(success: false, reason: e.toString());
    }
  }

  /// 手动触发同步
  Future<SyncResult> syncNow() async {
    return await _syncWithCloud();
  }

  /// 上报脱敏模式（含差分隐私保护）
  Future<_UploadResult> _uploadAnonymizedPatterns() async {
    final localRules = await _ruleStorage.getAllRules();
    if (localRules.isEmpty) {
      return const _UploadResult(uploadedCount: 0, protectedCount: 0);
    }

    // 筛选符合条件的规则
    final eligibleRules = localRules
        .where((rule) => rule.confidence >= 0.8 && rule.hitCount >= 5)
        .toList();

    if (eligibleRules.isEmpty) {
      return const _UploadResult(uploadedCount: 0, protectedCount: 0);
    }

    // 如果启用了差分隐私，对规则进行保护
    final anonymizedRules = <Map<String, dynamic>>[];
    int protectedCount = 0;

    if (_privacyEngine != null && _privacyEngine.canPerformOperation) {
      // 使用差分隐私保护规则
      final protectedRules = await _privacyEngine.protectRules(eligibleRules);
      protectedCount = protectedRules.length;

      for (final protectedRule in protectedRules) {
        anonymizedRules.add(protectedRule.toUploadData());
      }

      debugPrint('差分隐私：保护了 $protectedCount 条规则');
    } else {
      // 不使用差分隐私，直接脱敏处理
      for (final rule in eligibleRules) {
        anonymizedRules.add(_anonymizeRule(rule));
      }
    }

    if (anonymizedRules.isEmpty) {
      return const _UploadResult(uploadedCount: 0, protectedCount: 0);
    }

    // 上报到云端
    await _apiClient.uploadPatterns(anonymizedRules);

    return _UploadResult(
      uploadedCount: anonymizedRules.length,
      protectedCount: protectedCount,
    );
  }

  /// 规则脱敏处理
  Map<String, dynamic> _anonymizeRule(LearnedRule rule) {
    return {
      'pattern_hash': _hashPattern(rule),
      'category': rule.category,
      'confidence': rule.confidence,
      'hit_count': rule.hitCount,
      'amount_range': _toAmountRange(rule.avgAmount),
      // 不包含任何可识别用户的信息
    };
  }

  /// 哈希模式
  String _hashPattern(LearnedRule rule) {
    final content = '${rule.type}:${rule.pattern}';
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 金额转换为范围
  String _toAmountRange(double? amount) {
    if (amount == null) return 'unknown';
    if (amount < 10) return 'tiny'; // <10
    if (amount < 50) return 'small'; // 10-50
    if (amount < 100) return 'medium'; // 50-100
    if (amount < 500) return 'large'; // 100-500
    if (amount < 1000) return 'xlarge'; // 500-1000
    return 'huge'; // >1000
  }

  /// 下载协同规则
  Future<List<CollaborativeRule>> _downloadCollaborativeRules() async {
    try {
      return await _apiClient.downloadRules();
    } catch (e) {
      debugPrint('下载协同规则失败: $e');
      return [];
    }
  }

  /// 融合协同规则到本地（含异常检测）
  Future<_MergeResult> _mergeCollaborativeRules(
      List<CollaborativeRule> rules) async {
    if (rules.isEmpty) {
      return const _MergeResult(mergedCount: 0, filteredCount: 0);
    }

    int mergedCount = 0;
    int filteredCount = 0;

    // 如果启用了异常检测，先转换为 LearnedRule 进行检测
    List<CollaborativeRule> rulesToMerge = rules;

    if (_anomalyDetector != null) {
      // 将 CollaborativeRule 转换为 LearnedRule 以进行异常检测
      final learnedRules = rules
          .map((r) => LearnedRule(
                id: r.patternHash,
                type: r.type,
                pattern: r.patternHash,
                category: r.category,
                confidence: r.confidence,
                hitCount: r.aggregatedCount,
                source: RuleSource.collaborative,
                createdAt: DateTime.now(),
              ))
          .toList();

      // 执行异常检测
      final detectionResult = await _anomalyDetector.detectAnomalies(
        learnedRules,
        userId: _currentUserId,
      );

      // 过滤出正常规则
      final normalPatterns =
          detectionResult.normalRules.map((r) => r.pattern).toSet();
      rulesToMerge = rules
          .where((r) => normalPatterns.contains(r.patternHash))
          .toList();

      filteredCount = rules.length - rulesToMerge.length;

      if (filteredCount > 0) {
        debugPrint(
          '异常检测：过滤了 $filteredCount 条异常规则，'
          '异常率 ${(detectionResult.anomalyRate * 100).toStringAsFixed(1)}%',
        );
      }
    }

    // 融合正常规则
    for (final rule in rulesToMerge) {
      // 检查是否已存在相同规则
      final existingRule = await _ruleStorage.findByPattern(rule.patternHash);

      if (existingRule != null) {
        // 已存在，增强置信度
        final newConfidence =
            (existingRule.confidence * 0.7 + rule.confidence * 0.3)
                .clamp(0.0, 1.0);
        await _ruleStorage.updateConfidence(existingRule.id, newConfidence);
      } else {
        // 不存在，添加新规则（降低初始置信度）
        await _ruleStorage.addRule(LearnedRule(
          id: _generateId(),
          type: rule.type,
          pattern: rule.patternHash, // 使用哈希作为模式标识
          category: rule.category,
          confidence: rule.confidence * 0.6, // 协同规则初始置信度打折
          hitCount: 0,
          source: RuleSource.collaborative,
          createdAt: DateTime.now(),
        ));
        mergedCount++;
      }
    }

    return _MergeResult(mergedCount: mergedCount, filteredCount: filteredCount);
  }

  /// 获取协同学习状态
  Future<CollaborativeStatus> getStatus() async {
    final localRules = await _ruleStorage.getAllRules();
    final collaborativeRules =
        localRules.where((r) => r.source == RuleSource.collaborative).toList();

    // 获取隐私预算信息
    double? remainingBudgetPercent;
    bool privacyBudgetExhausted = false;

    if (_privacyEngine != null) {
      remainingBudgetPercent = _privacyEngine.budgetManager.remainingBudgetPercent;
      privacyBudgetExhausted = _privacyEngine.budgetManager.isExhausted;
    }

    return CollaborativeStatus(
      isEnabled: _isEnabled,
      localRuleCount: localRules.length,
      collaborativeRuleCount: collaborativeRules.length,
      lastSyncTime: await _ruleStorage.getLastSyncTime(),
      syncInterval: _syncInterval,
      remainingBudgetPercent: remainingBudgetPercent,
      privacyBudgetExhausted: privacyBudgetExhausted,
    );
  }

  /// 清除协同规则
  Future<int> clearCollaborativeRules() async {
    return await _ruleStorage.deleteBySource(RuleSource.collaborative);
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  void dispose() {
    stop();
  }
}

/// 数据脱敏服务
class CollaborativeLearningAnonymizer {
  /// 脱敏配置
  static const _anonymizationConfig = {
    'merchant_name': AnonymizeStrategy.hash,
    'amount': AnonymizeStrategy.range,
    'description': AnonymizeStrategy.remove,
    'user_id': AnonymizeStrategy.pseudonymize,
    'date': AnonymizeStrategy.keep,
    'category': AnonymizeStrategy.keep,
  };

  /// 脱敏学习样本
  static Map<String, dynamic> anonymize(Map<String, dynamic> sample) {
    final result = <String, dynamic>{};

    for (final entry in sample.entries) {
      final strategy =
          _anonymizationConfig[entry.key] ?? AnonymizeStrategy.keep;
      final anonymized = _applyStrategy(entry.value, strategy);
      if (anonymized != null) {
        result[entry.key] = anonymized;
      }
    }

    return result;
  }

  static dynamic _applyStrategy(dynamic value, AnonymizeStrategy strategy) {
    if (value == null) return null;

    switch (strategy) {
      case AnonymizeStrategy.hash:
        return _hashValue(value.toString());
      case AnonymizeStrategy.range:
        if (value is num) {
          return _toRange(value);
        }
        return null;
      case AnonymizeStrategy.remove:
        return null;
      case AnonymizeStrategy.pseudonymize:
        return _pseudonymize(value.toString());
      case AnonymizeStrategy.keep:
        return value;
    }
  }

  static String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  static String _toRange(num amount) {
    if (amount < 10) return 'tiny';
    if (amount < 50) return 'small';
    if (amount < 100) return 'medium';
    if (amount < 500) return 'large';
    if (amount < 1000) return 'xlarge';
    return 'huge';
  }

  static String _pseudonymize(String userId) {
    return 'user_${_hashValue(userId).substring(0, 8)}';
  }
}

// ==================== 数据模型 ====================

/// 脱敏策略
enum AnonymizeStrategy {
  hash, // 哈希处理
  range, // 转换为范围
  remove, // 完全移除
  pseudonymize, // 伪匿名化
  keep, // 保持原样
}

/// 规则来源
enum RuleSource {
  userLearned, // 用户学习
  collaborative, // 协同学习
  builtin, // 内置
}

/// 学习规则
class LearnedRule {
  final String id;
  final String type;
  final String pattern;
  final String category;
  final double confidence;
  final int hitCount;
  final double? avgAmount;
  final RuleSource source;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LearnedRule({
    required this.id,
    required this.type,
    required this.pattern,
    required this.category,
    required this.confidence,
    required this.hitCount,
    this.avgAmount,
    required this.source,
    required this.createdAt,
    this.updatedAt,
  });

  LearnedRule copyWith({
    double? confidence,
    int? hitCount,
    DateTime? updatedAt,
  }) {
    return LearnedRule(
      id: id,
      type: type,
      pattern: pattern,
      category: category,
      confidence: confidence ?? this.confidence,
      hitCount: hitCount ?? this.hitCount,
      avgAmount: avgAmount,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 协同规则
class CollaborativeRule {
  final String patternHash;
  final String type;
  final String category;
  final double confidence;
  final int aggregatedCount; // 聚合数量

  const CollaborativeRule({
    required this.patternHash,
    required this.type,
    required this.category,
    required this.confidence,
    required this.aggregatedCount,
  });

  factory CollaborativeRule.fromJson(Map<String, dynamic> json) {
    return CollaborativeRule(
      patternHash: json['pattern_hash'] as String,
      type: json['type'] as String? ?? 'merchant',
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      aggregatedCount: json['aggregated_count'] as int? ?? 1,
    );
  }
}

/// 同步结果
class SyncResult {
  final bool success;
  final String? reason;
  final int uploadedCount;
  final int downloadedCount;
  final int mergedCount;

  /// 差分隐私保护的规则数量
  final int protectedCount;

  /// 异常检测过滤的规则数量
  final int filteredAnomalyCount;

  /// 隐私预算是否耗尽
  final bool privacyBudgetExhausted;

  const SyncResult({
    required this.success,
    this.reason,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.mergedCount = 0,
    this.protectedCount = 0,
    this.filteredAnomalyCount = 0,
    this.privacyBudgetExhausted = false,
  });
}

/// 协同学习状态
class CollaborativeStatus {
  final bool isEnabled;
  final int localRuleCount;
  final int collaborativeRuleCount;
  final DateTime? lastSyncTime;
  final Duration syncInterval;

  /// 剩余隐私预算百分比（0-100）
  final double? remainingBudgetPercent;

  /// 隐私预算是否耗尽
  final bool privacyBudgetExhausted;

  const CollaborativeStatus({
    required this.isEnabled,
    required this.localRuleCount,
    required this.collaborativeRuleCount,
    this.lastSyncTime,
    required this.syncInterval,
    this.remainingBudgetPercent,
    this.privacyBudgetExhausted = false,
  });
}

/// API客户端接口
abstract class CollaborativeApiClient {
  Future<void> uploadPatterns(List<Map<String, dynamic>> patterns);
  Future<List<CollaborativeRule>> downloadRules();
}

/// 本地规则存储接口
abstract class LocalRuleStorage {
  Future<List<LearnedRule>> getAllRules();
  Future<LearnedRule?> findByPattern(String pattern);
  Future<void> addRule(LearnedRule rule);
  Future<void> updateConfidence(String id, double confidence);
  Future<int> deleteBySource(RuleSource source);
  Future<DateTime?> getLastSyncTime();
  Future<void> setLastSyncTime(DateTime time);
}

/// 内存规则存储实现
class InMemoryRuleStorage implements LocalRuleStorage {
  final List<LearnedRule> _rules = [];
  DateTime? _lastSyncTime;

  @override
  Future<List<LearnedRule>> getAllRules() async {
    return List.unmodifiable(_rules);
  }

  @override
  Future<LearnedRule?> findByPattern(String pattern) async {
    try {
      return _rules.firstWhere((r) => r.pattern == pattern);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addRule(LearnedRule rule) async {
    _rules.add(rule);
  }

  @override
  Future<void> updateConfidence(String id, double confidence) async {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rules[index] = _rules[index].copyWith(
        confidence: confidence,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<int> deleteBySource(RuleSource source) async {
    final count = _rules.where((r) => r.source == source).length;
    _rules.removeWhere((r) => r.source == source);
    return count;
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    return _lastSyncTime;
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    _lastSyncTime = time;
  }
}

/// 模拟API客户端实现
class MockCollaborativeApiClient implements CollaborativeApiClient {
  @override
  Future<void> uploadPatterns(List<Map<String, dynamic>> patterns) async {
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('Uploaded ${patterns.length} patterns');
  }

  @override
  Future<List<CollaborativeRule>> downloadRules() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // 返回模拟的协同规则
    return [
      const CollaborativeRule(
        patternHash: 'hash_starbucks',
        type: 'merchant',
        category: '餐饮',
        confidence: 0.95,
        aggregatedCount: 1000,
      ),
      const CollaborativeRule(
        patternHash: 'hash_didi',
        type: 'merchant',
        category: '交通',
        confidence: 0.98,
        aggregatedCount: 5000,
      ),
    ];
  }
}

// ==================== 内部辅助类 ====================

/// 上传结果（内部使用）
class _UploadResult {
  final int uploadedCount;
  final int protectedCount;

  const _UploadResult({
    required this.uploadedCount,
    required this.protectedCount,
  });
}

/// 合并结果（内部使用）
class _MergeResult {
  final int mergedCount;
  final int filteredCount;

  const _MergeResult({
    required this.mergedCount,
    required this.filteredCount,
  });
}
