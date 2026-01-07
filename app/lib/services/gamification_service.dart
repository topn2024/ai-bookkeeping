import 'dart:math';

import 'database_service.dart';

/// 成就类型
enum AchievementType {
  /// 连续记账
  streak,

  /// 预算达成
  budgetAchieved,

  /// 储蓄目标
  savingsGoal,

  /// 钱龄提升
  moneyAgeImproved,

  /// 习惯养成
  habitFormed,

  /// 里程碑
  milestone,

  /// 特殊成就
  special,
}

extension AchievementTypeExtension on AchievementType {
  String get displayName {
    switch (this) {
      case AchievementType.streak:
        return '坚持记账';
      case AchievementType.budgetAchieved:
        return '预算达人';
      case AchievementType.savingsGoal:
        return '储蓄高手';
      case AchievementType.moneyAgeImproved:
        return '钱龄提升';
      case AchievementType.habitFormed:
        return '习惯养成';
      case AchievementType.milestone:
        return '里程碑';
      case AchievementType.special:
        return '特殊成就';
    }
  }
}

/// 成就稀有度
enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

extension AchievementRarityExtension on AchievementRarity {
  String get displayName {
    switch (this) {
      case AchievementRarity.common:
        return '普通';
      case AchievementRarity.uncommon:
        return '稀有';
      case AchievementRarity.rare:
        return '珍贵';
      case AchievementRarity.epic:
        return '史诗';
      case AchievementRarity.legendary:
        return '传说';
    }
  }

  int get pointMultiplier {
    switch (this) {
      case AchievementRarity.common:
        return 1;
      case AchievementRarity.uncommon:
        return 2;
      case AchievementRarity.rare:
        return 5;
      case AchievementRarity.epic:
        return 10;
      case AchievementRarity.legendary:
        return 25;
    }
  }
}

/// 成就定义
class Achievement {
  final String id;
  final String name;
  final String description;
  final AchievementType type;
  final AchievementRarity rarity;
  final int points;
  final String? iconName;
  final Map<String, dynamic>? criteria; // 达成条件

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.rarity = AchievementRarity.common,
    this.points = 10,
    this.iconName,
    this.criteria,
  });

  int get actualPoints => points * rarity.pointMultiplier;
}

/// 用户成就记录
class UserAchievement {
  final String id;
  final String achievementId;
  final DateTime unlockedAt;
  final int progress;
  final int target;

  const UserAchievement({
    required this.id,
    required this.achievementId,
    required this.unlockedAt,
    this.progress = 0,
    this.target = 1,
  });

  bool get isUnlocked => progress >= target;
  double get progressPercent => target > 0 ? progress / target : 0;
}

/// 连续记账统计
class StreakStats {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastRecordDate;
  final int totalDaysRecorded;
  final bool isActiveToday;

  const StreakStats({
    required this.currentStreak,
    required this.longestStreak,
    this.lastRecordDate,
    required this.totalDaysRecorded,
    required this.isActiveToday,
  });

  /// 是否处于连续状态（今天或昨天有记录）
  bool get isStreakActive {
    if (lastRecordDate == null) return false;
    final daysSince = DateTime.now().difference(lastRecordDate!).inDays;
    return daysSince <= 1;
  }
}

/// 用户等级
class UserLevel {
  final int level;
  final int currentPoints;
  final int pointsForNextLevel;
  final String title;

  const UserLevel({
    required this.level,
    required this.currentPoints,
    required this.pointsForNextLevel,
    required this.title,
  });

  double get progressToNext {
    if (pointsForNextLevel <= 0) return 1;
    return currentPoints / pointsForNextLevel;
  }

  int get pointsNeeded => max(0, pointsForNextLevel - currentPoints);
}

/// 游戏化激励服务
///
/// 通过成就、连续记账、积分等机制激励用户养成良好的财务习惯：
/// - 连续记账追踪与奖励
/// - 成就系统
/// - 积分与等级
/// - 挑战任务
class GamificationService {
  final DatabaseService _db;

  // 预定义成就
  static final List<Achievement> _achievements = [
    // 连续记账成就
    const Achievement(
      id: 'streak_3',
      name: '初试锋芒',
      description: '连续记账3天',
      type: AchievementType.streak,
      rarity: AchievementRarity.common,
      points: 10,
      criteria: {'streakDays': 3},
    ),
    const Achievement(
      id: 'streak_7',
      name: '一周坚持',
      description: '连续记账7天',
      type: AchievementType.streak,
      rarity: AchievementRarity.common,
      points: 25,
      criteria: {'streakDays': 7},
    ),
    const Achievement(
      id: 'streak_30',
      name: '月度达人',
      description: '连续记账30天',
      type: AchievementType.streak,
      rarity: AchievementRarity.uncommon,
      points: 100,
      criteria: {'streakDays': 30},
    ),
    const Achievement(
      id: 'streak_100',
      name: '百日之约',
      description: '连续记账100天',
      type: AchievementType.streak,
      rarity: AchievementRarity.rare,
      points: 500,
      criteria: {'streakDays': 100},
    ),
    const Achievement(
      id: 'streak_365',
      name: '年度传奇',
      description: '连续记账365天',
      type: AchievementType.streak,
      rarity: AchievementRarity.legendary,
      points: 2000,
      criteria: {'streakDays': 365},
    ),

    // 预算成就
    const Achievement(
      id: 'budget_first',
      name: '预算新手',
      description: '首次完成月度预算',
      type: AchievementType.budgetAchieved,
      rarity: AchievementRarity.common,
      points: 20,
    ),
    const Achievement(
      id: 'budget_3months',
      name: '预算达人',
      description: '连续3个月完成预算目标',
      type: AchievementType.budgetAchieved,
      rarity: AchievementRarity.uncommon,
      points: 100,
      criteria: {'consecutiveMonths': 3},
    ),

    // 储蓄成就
    const Achievement(
      id: 'savings_first',
      name: '储蓄起步',
      description: '首次存入应急金',
      type: AchievementType.savingsGoal,
      rarity: AchievementRarity.common,
      points: 15,
    ),
    const Achievement(
      id: 'savings_1000',
      name: '小有积蓄',
      description: '应急金达到1000元',
      type: AchievementType.savingsGoal,
      rarity: AchievementRarity.common,
      points: 30,
      criteria: {'amount': 1000},
    ),
    const Achievement(
      id: 'savings_10000',
      name: '万元俱乐部',
      description: '应急金达到10000元',
      type: AchievementType.savingsGoal,
      rarity: AchievementRarity.rare,
      points: 200,
      criteria: {'amount': 10000},
    ),

    // 钱龄成就
    const Achievement(
      id: 'moneyage_7',
      name: '钱龄新手',
      description: '平均钱龄达到7天',
      type: AchievementType.moneyAgeImproved,
      rarity: AchievementRarity.common,
      points: 20,
      criteria: {'days': 7},
    ),
    const Achievement(
      id: 'moneyage_30',
      name: '钱龄达人',
      description: '平均钱龄达到30天',
      type: AchievementType.moneyAgeImproved,
      rarity: AchievementRarity.uncommon,
      points: 75,
      criteria: {'days': 30},
    ),
    const Achievement(
      id: 'moneyage_90',
      name: '钱龄大师',
      description: '平均钱龄达到90天',
      type: AchievementType.moneyAgeImproved,
      rarity: AchievementRarity.rare,
      points: 200,
      criteria: {'days': 90},
    ),

    // 特殊成就
    const Achievement(
      id: 'first_record',
      name: '记账新秀',
      description: '记录第一笔交易',
      type: AchievementType.milestone,
      rarity: AchievementRarity.common,
      points: 5,
    ),
    const Achievement(
      id: 'records_100',
      name: '百笔达成',
      description: '累计记录100笔交易',
      type: AchievementType.milestone,
      rarity: AchievementRarity.common,
      points: 50,
      criteria: {'count': 100},
    ),
    const Achievement(
      id: 'records_1000',
      name: '千笔大师',
      description: '累计记录1000笔交易',
      type: AchievementType.milestone,
      rarity: AchievementRarity.rare,
      points: 300,
      criteria: {'count': 1000},
    ),
    const Achievement(
      id: 'impulse_saved',
      name: '理性消费者',
      description: '通过冷静期取消5次冲动消费',
      type: AchievementType.habitFormed,
      rarity: AchievementRarity.uncommon,
      points: 80,
      criteria: {'count': 5},
    ),
    const Achievement(
      id: 'wish_achieved',
      name: '愿望成真',
      description: '完成第一个愿望清单目标',
      type: AchievementType.savingsGoal,
      rarity: AchievementRarity.common,
      points: 30,
    ),
  ];

  // 等级定义
  static const List<Map<String, dynamic>> _levels = [
    {'level': 1, 'title': '财务小白', 'pointsRequired': 0},
    {'level': 2, 'title': '记账新手', 'pointsRequired': 50},
    {'level': 3, 'title': '理财入门', 'pointsRequired': 150},
    {'level': 4, 'title': '预算能手', 'pointsRequired': 350},
    {'level': 5, 'title': '储蓄达人', 'pointsRequired': 700},
    {'level': 6, 'title': '财务精英', 'pointsRequired': 1200},
    {'level': 7, 'title': '理财专家', 'pointsRequired': 2000},
    {'level': 8, 'title': '财富管家', 'pointsRequired': 3500},
    {'level': 9, 'title': '金融大师', 'pointsRequired': 6000},
    {'level': 10, 'title': '财务自由', 'pointsRequired': 10000},
  ];

  GamificationService(this._db);

  /// 获取所有成就定义
  List<Achievement> getAllAchievements() => _achievements;

  /// 记录今日活动（调用此方法更新连续记账）
  Future<StreakStats> recordDailyActivity() async {
    final today = _dateOnly(DateTime.now());
    final todayMs = today.millisecondsSinceEpoch;

    // 检查今天是否已记录
    final existing = await _db.rawQuery('''
      SELECT * FROM daily_activity WHERE date = ?
    ''', [todayMs]);

    if (existing.isEmpty) {
      await _db.rawInsert('''
        INSERT INTO daily_activity (date, recordedAt) VALUES (?, ?)
      ''', [todayMs, DateTime.now().millisecondsSinceEpoch]);
    }

    final stats = await getStreakStats();

    // 检查连续记账成就
    await _checkStreakAchievements(stats.currentStreak);

    return stats;
  }

  /// 获取连续记账统计
  Future<StreakStats> getStreakStats() async {
    final today = _dateOnly(DateTime.now());

    // 获取所有活动记录
    final activities = await _db.rawQuery('''
      SELECT date FROM daily_activity ORDER BY date DESC
    ''');

    if (activities.isEmpty) {
      return const StreakStats(
        currentStreak: 0,
        longestStreak: 0,
        totalDaysRecorded: 0,
        isActiveToday: false,
      );
    }

    final dates = activities
        .map((a) => DateTime.fromMillisecondsSinceEpoch(a['date'] as int))
        .toList();

    final lastDate = dates.first;
    final isActiveToday = _dateOnly(lastDate) == today;

    // 计算当前连续天数
    int currentStreak = 0;
    var checkDate = isActiveToday ? today : today.subtract(const Duration(days: 1));

    for (final date in dates) {
      if (_dateOnly(date) == checkDate) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (_dateOnly(date).isBefore(checkDate)) {
        break;
      }
    }

    // 计算最长连续天数
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? prevDate;

    for (final date in dates.reversed) {
      if (prevDate == null) {
        tempStreak = 1;
      } else {
        final diff = _dateOnly(date).difference(_dateOnly(prevDate)).inDays;
        if (diff == 1) {
          tempStreak++;
        } else {
          longestStreak = max(longestStreak, tempStreak);
          tempStreak = 1;
        }
      }
      prevDate = date;
    }
    longestStreak = max(longestStreak, tempStreak);

    return StreakStats(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastRecordDate: lastDate,
      totalDaysRecorded: dates.length,
      isActiveToday: isActiveToday,
    );
  }

  /// 解锁成就
  Future<bool> unlockAchievement(String achievementId) async {
    final achievement = _achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw ArgumentError('Achievement not found: $achievementId'),
    );

    // 检查是否已解锁
    final existing = await _db.rawQuery('''
      SELECT * FROM user_achievements WHERE achievementId = ?
    ''', [achievementId]);

    if (existing.isNotEmpty) return false;

    // 解锁成就
    final now = DateTime.now();
    await _db.rawInsert('''
      INSERT INTO user_achievements (id, achievementId, unlockedAt, progress, target)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      '${now.millisecondsSinceEpoch}',
      achievementId,
      now.millisecondsSinceEpoch,
      1,
      1,
    ]);

    // 增加积分
    await addPoints(achievement.actualPoints, reason: '解锁成就: ${achievement.name}');

    return true;
  }

  /// 获取已解锁的成就
  Future<List<UserAchievement>> getUnlockedAchievements() async {
    final results = await _db.rawQuery('''
      SELECT * FROM user_achievements ORDER BY unlockedAt DESC
    ''');

    return results.map((m) => UserAchievement(
      id: m['id'] as String,
      achievementId: m['achievementId'] as String,
      unlockedAt: DateTime.fromMillisecondsSinceEpoch(m['unlockedAt'] as int),
      progress: m['progress'] as int? ?? 1,
      target: m['target'] as int? ?? 1,
    )).toList();
  }

  /// 获取用户总积分
  Future<int> getTotalPoints() async {
    final result = await _db.rawQuery('''
      SELECT SUM(points) as total FROM user_points
    ''');
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  /// 增加积分
  Future<void> addPoints(int points, {String? reason}) async {
    await _db.rawInsert('''
      INSERT INTO user_points (id, points, reason, earnedAt)
      VALUES (?, ?, ?, ?)
    ''', [
      DateTime.now().millisecondsSinceEpoch.toString(),
      points,
      reason,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  /// 获取用户等级
  Future<UserLevel> getUserLevel() async {
    final totalPoints = await getTotalPoints();

    var currentLevel = _levels.first;
    var nextLevel = _levels.length > 1 ? _levels[1] : null;

    for (var i = 0; i < _levels.length; i++) {
      if (totalPoints >= _levels[i]['pointsRequired']) {
        currentLevel = _levels[i];
        nextLevel = i + 1 < _levels.length ? _levels[i + 1] : null;
      } else {
        break;
      }
    }

    return UserLevel(
      level: currentLevel['level'] as int,
      currentPoints: totalPoints,
      pointsForNextLevel: nextLevel?['pointsRequired'] ?? totalPoints,
      title: currentLevel['title'] as String,
    );
  }

  /// 获取积分历史
  Future<List<Map<String, dynamic>>> getPointsHistory({int limit = 20}) async {
    return await _db.rawQuery('''
      SELECT * FROM user_points ORDER BY earnedAt DESC LIMIT ?
    ''', [limit]);
  }

  /// 检查并触发成就
  Future<List<Achievement>> checkAchievements({
    int? transactionCount,
    double? emergencyFundBalance,
    int? moneyAgeDays,
    int? impulseCancelCount,
    int? wishAchievedCount,
  }) async {
    final unlocked = <Achievement>[];

    // 交易数量成就
    if (transactionCount != null) {
      if (transactionCount >= 1) {
        if (await unlockAchievement('first_record')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'first_record'));
        }
      }
      if (transactionCount >= 100) {
        if (await unlockAchievement('records_100')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'records_100'));
        }
      }
      if (transactionCount >= 1000) {
        if (await unlockAchievement('records_1000')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'records_1000'));
        }
      }
    }

    // 应急金成就
    if (emergencyFundBalance != null) {
      if (emergencyFundBalance > 0) {
        if (await unlockAchievement('savings_first')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'savings_first'));
        }
      }
      if (emergencyFundBalance >= 1000) {
        if (await unlockAchievement('savings_1000')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'savings_1000'));
        }
      }
      if (emergencyFundBalance >= 10000) {
        if (await unlockAchievement('savings_10000')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'savings_10000'));
        }
      }
    }

    // 钱龄成就
    if (moneyAgeDays != null) {
      if (moneyAgeDays >= 7) {
        if (await unlockAchievement('moneyage_7')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'moneyage_7'));
        }
      }
      if (moneyAgeDays >= 30) {
        if (await unlockAchievement('moneyage_30')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'moneyage_30'));
        }
      }
      if (moneyAgeDays >= 90) {
        if (await unlockAchievement('moneyage_90')) {
          unlocked.add(_achievements.firstWhere((a) => a.id == 'moneyage_90'));
        }
      }
    }

    // 冲动消费取消成就
    if (impulseCancelCount != null && impulseCancelCount >= 5) {
      if (await unlockAchievement('impulse_saved')) {
        unlocked.add(_achievements.firstWhere((a) => a.id == 'impulse_saved'));
      }
    }

    // 愿望达成成就
    if (wishAchievedCount != null && wishAchievedCount >= 1) {
      if (await unlockAchievement('wish_achieved')) {
        unlocked.add(_achievements.firstWhere((a) => a.id == 'wish_achieved'));
      }
    }

    return unlocked;
  }

  Future<void> _checkStreakAchievements(int streak) async {
    final streakMilestones = [3, 7, 30, 100, 365];
    final achievementIds = ['streak_3', 'streak_7', 'streak_30', 'streak_100', 'streak_365'];

    for (var i = 0; i < streakMilestones.length; i++) {
      if (streak >= streakMilestones[i]) {
        await unlockAchievement(achievementIds[i]);
      }
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
