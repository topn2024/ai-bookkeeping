import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

/// 协同学习服务
///
/// 功能：
/// 1. 本地规则脱敏上报
/// 2. 下载协同规则
/// 3. 规则融合
/// 4. 隐私保护
class CollaborativeLearningService {
  final CollaborativeApiClient _apiClient;
  final LocalRuleStorage _ruleStorage;
  final Duration _syncInterval;
  Timer? _syncTimer;
  bool _isEnabled = true;

  CollaborativeLearningService({
    required CollaborativeApiClient apiClient,
    required LocalRuleStorage ruleStorage,
    Duration? syncInterval,
  })  : _apiClient = apiClient,
        _ruleStorage = ruleStorage,
        _syncInterval = syncInterval ?? const Duration(hours: 6);

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

    try {
      // 1. 上报本地脱敏数据
      final uploadCount = await _uploadAnonymizedPatterns();

      // 2. 下载协同规则
      final collaborativeRules = await _downloadCollaborativeRules();

      // 3. 融合到本地
      final mergedCount = await _mergeCollaborativeRules(collaborativeRules);

      debugPrint('协同学习同步成功: 上传$uploadCount条，下载${collaborativeRules.length}条，融合$mergedCount条');

      return SyncResult(
        success: true,
        uploadedCount: uploadCount,
        downloadedCount: collaborativeRules.length,
        mergedCount: mergedCount,
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

  /// 上报脱敏模式
  Future<int> _uploadAnonymizedPatterns() async {
    final localRules = await _ruleStorage.getAllRules();
    if (localRules.isEmpty) return 0;

    // 脱敏处理
    final anonymizedRules = <Map<String, dynamic>>[];
    for (final rule in localRules) {
      // 只上报高置信度的规则
      if (rule.confidence >= 0.8 && rule.hitCount >= 5) {
        anonymizedRules.add(_anonymizeRule(rule));
      }
    }

    if (anonymizedRules.isEmpty) return 0;

    // 上报到云端
    await _apiClient.uploadPatterns(anonymizedRules);

    return anonymizedRules.length;
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

  /// 融合协同规则到本地
  Future<int> _mergeCollaborativeRules(List<CollaborativeRule> rules) async {
    int mergedCount = 0;

    for (final rule in rules) {
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
          confidence: rule.confidence * 0.6, // 协同规则初始置信��打折
          hitCount: 0,
          source: RuleSource.collaborative,
          createdAt: DateTime.now(),
        ));
        mergedCount++;
      }
    }

    return mergedCount;
  }

  /// 获取协同学习状态
  Future<CollaborativeStatus> getStatus() async {
    final localRules = await _ruleStorage.getAllRules();
    final collaborativeRules =
        localRules.where((r) => r.source == RuleSource.collaborative).toList();

    return CollaborativeStatus(
      isEnabled: _isEnabled,
      localRuleCount: localRules.length,
      collaborativeRuleCount: collaborativeRules.length,
      lastSyncTime: await _ruleStorage.getLastSyncTime(),
      syncInterval: _syncInterval,
    );
  }

  /// 清除协同规则
  Future<int> clearCollaborativeRules() async {
    return await _ruleStorage.deleteBySource(RuleSource.collaborative);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        '_${Random().nextInt(10000)}';
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

  const SyncResult({
    required this.success,
    this.reason,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.mergedCount = 0,
  });
}

/// 协同学习状态
class CollaborativeStatus {
  final bool isEnabled;
  final int localRuleCount;
  final int collaborativeRuleCount;
  final DateTime? lastSyncTime;
  final Duration syncInterval;

  const CollaborativeStatus({
    required this.isEnabled,
    required this.localRuleCount,
    required this.collaborativeRuleCount,
    this.lastSyncTime,
    required this.syncInterval,
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
