import '../models/family_leaderboard.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import 'database_service.dart';

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
    try {
      final db = await DatabaseService().database;

      // 计算时间范围
      final now = DateTime.now();
      DateTime startDate;
      switch (period) {
        case LeaderboardPeriod.week:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case LeaderboardPeriod.month:
          startDate = DateTime(now.year, now.month, 1);
          break;
        case LeaderboardPeriod.year:
          startDate = DateTime(now.year, 1, 1);
          break;
        case LeaderboardPeriod.allTime:
          startDate = DateTime(2000, 1, 1);
          break;
      }

      // 查询成员的交易记录
      final results = await db.query(
        'transactions',
        where: 'ledgerId = ? AND createdBy = ? AND datetime >= ?',
        whereArgs: [
          ledgerId,
          memberId,
          startDate.millisecondsSinceEpoch,
        ],
      );

      switch (type) {
        case LeaderboardType.savings:
          // 储蓄排行：收入 - 支出
          double income = 0;
          double expense = 0;
          for (var row in results) {
            final transaction = Transaction.fromMap(row);
            if (transaction.type == TransactionType.income) {
              income += transaction.amount;
            } else if (transaction.type == TransactionType.expense) {
              expense += transaction.amount;
            }
          }
          return income - expense;

        case LeaderboardType.recording:
          // 记账排行：交易记录数量
          return results.length.toDouble();

        case LeaderboardType.budgetControl:
          // 预算控制排行：简化实现，返回记录数量
          return results.length.toDouble();

        case LeaderboardType.goalContribution:
          // 目标贡献排行：简化实现，返回收入总额
          double income = 0;
          for (var row in results) {
            final transaction = Transaction.fromMap(row);
            if (transaction.type == TransactionType.income) {
              income += transaction.amount;
            }
          }
          return income;
      }
    } catch (e) {
      return 0;
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
