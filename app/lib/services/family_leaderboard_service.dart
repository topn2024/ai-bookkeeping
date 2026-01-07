import '../models/family_leaderboard.dart';
import '../models/member.dart';

/// 家庭排行榜服务
class FamilyLeaderboardService {
  static final FamilyLeaderboardService _instance =
      FamilyLeaderboardService._internal();
  factory FamilyLeaderboardService() => _instance;
  FamilyLeaderboardService._internal();

  // 排行榜缓存
  final Map<String, FamilyLeaderboard> _leaderboardCache = {};
  // 成就缓存
  final Map<String, List<Achievement>> _achievementCache = {};

  /// 获取排行榜
  Future<FamilyLeaderboard> getLeaderboard({
    required String ledgerId,
    required LeaderboardType type,
    required LeaderboardPeriod period,
    required List<LedgerMember> members,
  }) async {
    final cacheKey = '$ledgerId:${type.name}:${period.name}';

    // 检查缓存
    if (_leaderboardCache.containsKey(cacheKey)) {
      final cached = _leaderboardCache[cacheKey]!;
      if (DateTime.now().difference(cached.generatedAt).inMinutes < 5) {
        return cached;
      }
    }

    // 生成排行榜
    final entries = await _calculateRankings(
      ledgerId: ledgerId,
      type: type,
      period: period,
      members: members,
    );

    final leaderboard = FamilyLeaderboard(
      ledgerId: ledgerId,
      type: type,
      period: period,
      entries: entries,
      generatedAt: DateTime.now(),
    );

    _leaderboardCache[cacheKey] = leaderboard;
    return leaderboard;
  }

  /// 计算排名
  Future<List<LeaderboardEntry>> _calculateRankings({
    required String ledgerId,
    required LeaderboardType type,
    required LeaderboardPeriod period,
    required List<LedgerMember> members,
  }) async {
    final scores = <String, double>{};

    for (final member in members) {
      scores[member.userId] = await _calculateScore(
        memberId: member.userId,
        ledgerId: ledgerId,
        type: type,
        period: period,
      );
    }

    // 按分数排序
    final sortedMembers = members.toList()
      ..sort((a, b) =>
          (scores[b.userId] ?? 0).compareTo(scores[a.userId] ?? 0));

    return sortedMembers.asMap().entries.map((entry) {
      final member = entry.value;
      return LeaderboardEntry(
        memberId: member.userId,
        memberName: member.displayName,
        avatarUrl: member.avatarUrl,
        rank: entry.key + 1,
        score: scores[member.userId] ?? 0,
      );
    }).toList();
  }

  /// 计算成员分数
  Future<double> _calculateScore({
    required String memberId,
    required String ledgerId,
    required LeaderboardType type,
    required LeaderboardPeriod period,
  }) async {
    // 模拟数据 - 实际应从��据库计算
    switch (type) {
      case LeaderboardType.savings:
        return 1000 + (memberId.hashCode % 5000).toDouble();
      case LeaderboardType.recording:
        return 10 + (memberId.hashCode % 50).toDouble();
      case LeaderboardType.budgetControl:
        return 50 + (memberId.hashCode % 50).toDouble();
      case LeaderboardType.goalContribution:
        return 500 + (memberId.hashCode % 2000).toDouble();
    }
  }

  /// 获取成员成就
  Future<List<Achievement>> getMemberAchievements(String memberId) async {
    if (_achievementCache.containsKey(memberId)) {
      return _achievementCache[memberId]!;
    }
    return [];
  }

  /// 解锁成就
  Future<Achievement?> unlockAchievement({
    required String memberId,
    required AchievementType type,
    required String title,
    required String description,
    required String emoji,
  }) async {
    final achievement = Achievement(
      id: '${memberId}_${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      description: description,
      emoji: emoji,
      unlockedAt: DateTime.now(),
      memberId: memberId,
    );

    _achievementCache[memberId] = [
      ...(_achievementCache[memberId] ?? []),
      achievement,
    ];

    return achievement;
  }

  /// 清除缓存
  void clearCache() {
    _leaderboardCache.clear();
    _achievementCache.clear();
  }
}