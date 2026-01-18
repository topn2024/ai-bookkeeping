import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/user_reputation.dart';

/// 恶意用户追踪器
///
/// 追踪和管理用户在协同学习中的信誉状态，
/// 识别并隔离提交异常规则的恶意用户。
class MaliciousUserTracker extends ChangeNotifier {
  /// 用户信誉存储
  final Map<String, UserReputation> _reputations = {};

  /// 配置
  final ReputationConfig _config;

  /// 持久化存储
  final UserReputationStorage? _storage;

  /// 隔离用户变更回调
  final List<void Function(String userId, bool isolated)> _isolationCallbacks =
      [];

  MaliciousUserTracker({
    ReputationConfig? config,
    UserReputationStorage? storage,
  })  : _config = config ?? ReputationConfig.defaultConfig,
        _storage = storage;

  /// 所有用户信誉
  Map<String, UserReputation> get reputations =>
      Map.unmodifiable(_reputations);

  /// 隔离用户列表
  List<String> get isolatedUsers => _reputations.entries
      .where((e) => e.value.isIsolated)
      .map((e) => e.key)
      .toList();

  /// 观察中用户列表
  List<String> get usersUnderReview => _reputations.entries
      .where((e) => e.value.level == ReputationLevel.underReview)
      .map((e) => e.key)
      .toList();

  /// 初始化，从存储加载
  Future<void> initialize() async {
    if (_storage != null) {
      final saved = await _storage.loadAllReputations();
      _reputations.addAll(saved);
    }
    notifyListeners();
  }

  /// 伪匿名化用户ID
  String pseudonymizeUserId(String userId) {
    final bytes = utf8.encode(userId);
    final digest = sha256.convert(bytes);
    return 'user_${digest.toString().substring(0, 16)}';
  }

  /// 获取用户信誉（如果不存在则创建）
  UserReputation getOrCreateReputation(String pseudonymizedUserId) {
    return _reputations.putIfAbsent(
      pseudonymizedUserId,
      () => UserReputation.newUser(pseudonymizedUserId),
    );
  }

  /// 记录异常规则
  ///
  /// [userId] 原始用户ID（会被伪匿名化）
  Future<void> recordAnomaly(String userId) async {
    final pseudoId = pseudonymizeUserId(userId);
    final reputation = getOrCreateReputation(pseudoId);

    final newAnomalyCount = reputation.anomalyCount + 1;
    final newTotalContributions = reputation.totalContributions + 1;

    // 计算新的分数
    var newScore = (reputation.score - _config.anomalyPenalty).clamp(0.0, 100.0);

    // 确定新的信誉等级
    ReputationLevel newLevel = reputation.level;
    DateTime? isolatedAt = reputation.isolatedAt;

    if (newScore <= _config.minScore ||
        newAnomalyCount >= _config.isolationThreshold) {
      newLevel = ReputationLevel.isolated;
      isolatedAt = DateTime.now();
      _notifyIsolation(pseudoId, true);
      debugPrint('用户 $pseudoId 已被隔离：异常次数=$newAnomalyCount, 分数=$newScore');
    } else if (newAnomalyCount >= _config.reviewThreshold) {
      newLevel = ReputationLevel.underReview;
      debugPrint('用户 $pseudoId 进入观察状态：异常次数=$newAnomalyCount');
    }

    final updated = reputation.copyWith(
      score: newScore,
      level: newLevel,
      totalContributions: newTotalContributions,
      anomalyCount: newAnomalyCount,
      consecutiveNormalCount: 0, // 重置连续正常次数
      isolatedAt: isolatedAt,
      lastUpdated: DateTime.now(),
    );

    _reputations[pseudoId] = updated;
    await _persistReputation(updated);
    notifyListeners();
  }

  /// 记录正常贡献
  Future<void> recordNormalContribution(String userId) async {
    final pseudoId = pseudonymizeUserId(userId);
    final reputation = getOrCreateReputation(pseudoId);

    final newConsecutiveNormal = reputation.consecutiveNormalCount + 1;
    final newTotalContributions = reputation.totalContributions + 1;

    // 增加分数
    var newScore =
        (reputation.score + _config.normalReward).clamp(0.0, 100.0);

    // 检查是否可以恢复信誉
    ReputationLevel newLevel = reputation.level;
    DateTime? isolatedAt = reputation.isolatedAt;

    if (reputation.level == ReputationLevel.isolated &&
        newConsecutiveNormal >= _config.recoveryToReviewCount) {
      newLevel = ReputationLevel.underReview;
      isolatedAt = null;
      _notifyIsolation(pseudoId, false);
      debugPrint('用户 $pseudoId 从隔离恢复到观察状态');
    } else if (reputation.level == ReputationLevel.underReview &&
        newConsecutiveNormal >= _config.recoveryToTrustedCount) {
      newLevel = ReputationLevel.trusted;
      debugPrint('用户 $pseudoId 恢复为可信用户');
    }

    final updated = reputation.copyWith(
      score: newScore,
      level: newLevel,
      totalContributions: newTotalContributions,
      consecutiveNormalCount: newConsecutiveNormal,
      isolatedAt: isolatedAt,
      lastUpdated: DateTime.now(),
    );

    _reputations[pseudoId] = updated;
    await _persistReputation(updated);
    notifyListeners();
  }

  /// 批量记录贡献结果
  Future<void> recordBatchContributions({
    required String userId,
    required int normalCount,
    required int anomalyCount,
  }) async {
    for (var i = 0; i < normalCount; i++) {
      await recordNormalContribution(userId);
    }
    for (var i = 0; i < anomalyCount; i++) {
      await recordAnomaly(userId);
    }
  }

  /// 检查用户是否可以贡献规则
  bool canContribute(String userId) {
    final pseudoId = pseudonymizeUserId(userId);
    final reputation = _reputations[pseudoId];

    if (reputation == null) {
      return true; // 新用户可以贡献
    }

    return reputation.level.canContribute;
  }

  /// 检查用户的规则是否需要额外审查
  bool needsReview(String userId) {
    final pseudoId = pseudonymizeUserId(userId);
    final reputation = _reputations[pseudoId];

    if (reputation == null) {
      return false;
    }

    return reputation.needsReview;
  }

  /// 获取用户信誉
  UserReputation? getReputation(String userId) {
    final pseudoId = pseudonymizeUserId(userId);
    return _reputations[pseudoId];
  }

  /// 手动隔离用户
  Future<void> isolateUser(String userId, {String? reason}) async {
    final pseudoId = pseudonymizeUserId(userId);
    final reputation = getOrCreateReputation(pseudoId);

    final updated = reputation.copyWith(
      level: ReputationLevel.isolated,
      isolatedAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );

    _reputations[pseudoId] = updated;
    await _persistReputation(updated);
    _notifyIsolation(pseudoId, true);
    notifyListeners();

    debugPrint('手动隔离用户 $pseudoId: ${reason ?? "无原因"}');
  }

  /// 手动恢复用户
  Future<void> reinstateUser(String userId) async {
    final pseudoId = pseudonymizeUserId(userId);
    final reputation = _reputations[pseudoId];

    if (reputation == null) return;

    final updated = reputation.copyWith(
      level: ReputationLevel.underReview, // 恢复到观察状态
      isolatedAt: null,
      consecutiveNormalCount: 0,
      lastUpdated: DateTime.now(),
    );

    _reputations[pseudoId] = updated;
    await _persistReputation(updated);
    _notifyIsolation(pseudoId, false);
    notifyListeners();

    debugPrint('手动恢复用户 $pseudoId 到观察状态');
  }

  /// 添加隔离状态变更监听器
  void addIsolationListener(
      void Function(String userId, bool isolated) callback) {
    _isolationCallbacks.add(callback);
  }

  /// 移除隔离状态变更监听器
  void removeIsolationListener(
      void Function(String userId, bool isolated) callback) {
    _isolationCallbacks.remove(callback);
  }

  /// 获取统计信息
  UserTrackingStatistics getStatistics() {
    final total = _reputations.length;
    final trusted = _reputations.values
        .where((r) => r.level == ReputationLevel.trusted)
        .length;
    final underReview = _reputations.values
        .where((r) => r.level == ReputationLevel.underReview)
        .length;
    final isolated = _reputations.values
        .where((r) => r.level == ReputationLevel.isolated)
        .length;

    final totalAnomalies =
        _reputations.values.fold(0, (sum, r) => sum + r.anomalyCount);
    final totalContributions =
        _reputations.values.fold(0, (sum, r) => sum + r.totalContributions);

    return UserTrackingStatistics(
      totalUsers: total,
      trustedUsers: trusted,
      usersUnderReview: underReview,
      isolatedUsers: isolated,
      totalAnomalies: totalAnomalies,
      totalContributions: totalContributions,
    );
  }

  /// 清除所有追踪数据
  Future<void> clearAll() async {
    _reputations.clear();
    await _storage?.clearAll();
    notifyListeners();
  }

  void _notifyIsolation(String userId, bool isolated) {
    for (final callback in _isolationCallbacks) {
      callback(userId, isolated);
    }
  }

  Future<void> _persistReputation(UserReputation reputation) async {
    await _storage?.saveReputation(reputation);
  }

  @override
  void dispose() {
    _isolationCallbacks.clear();
    super.dispose();
  }
}

/// 用户追踪统计
class UserTrackingStatistics {
  final int totalUsers;
  final int trustedUsers;
  final int usersUnderReview;
  final int isolatedUsers;
  final int totalAnomalies;
  final int totalContributions;

  const UserTrackingStatistics({
    required this.totalUsers,
    required this.trustedUsers,
    required this.usersUnderReview,
    required this.isolatedUsers,
    required this.totalAnomalies,
    required this.totalContributions,
  });

  double get anomalyRate =>
      totalContributions > 0 ? totalAnomalies / totalContributions : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'totalUsers': totalUsers,
      'trustedUsers': trustedUsers,
      'usersUnderReview': usersUnderReview,
      'isolatedUsers': isolatedUsers,
      'totalAnomalies': totalAnomalies,
      'totalContributions': totalContributions,
      'anomalyRate': anomalyRate,
    };
  }
}

/// 用户信誉存储接口
abstract class UserReputationStorage {
  Future<void> saveReputation(UserReputation reputation);
  Future<UserReputation?> loadReputation(String pseudonymizedUserId);
  Future<Map<String, UserReputation>> loadAllReputations();
  Future<void> deleteReputation(String pseudonymizedUserId);
  Future<void> clearAll();
}

/// 内存存储实现（用于测试）
class InMemoryUserReputationStorage implements UserReputationStorage {
  final Map<String, UserReputation> _storage = {};

  @override
  Future<void> saveReputation(UserReputation reputation) async {
    _storage[reputation.pseudonymizedUserId] = reputation;
  }

  @override
  Future<UserReputation?> loadReputation(String pseudonymizedUserId) async {
    return _storage[pseudonymizedUserId];
  }

  @override
  Future<Map<String, UserReputation>> loadAllReputations() async {
    return Map.unmodifiable(_storage);
  }

  @override
  Future<void> deleteReputation(String pseudonymizedUserId) async {
    _storage.remove(pseudonymizedUserId);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }
}
