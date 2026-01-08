import 'database_service.dart';

/// 钱龄等级
enum MoneyAgeLevel {
  /// 入门级 (0-7天)
  beginner,

  /// 新手级 (7-14天)
  novice,

  /// 进阶级 (14-21天)
  intermediate,

  /// 熟练级 (21-30天)
  proficient,

  /// 专家级 (30-60天)
  expert,

  /// 大师级 (60天以上)
  master,
}

extension MoneyAgeLevelExtension on MoneyAgeLevel {
  String get displayName {
    switch (this) {
      case MoneyAgeLevel.beginner:
        return '入门';
      case MoneyAgeLevel.novice:
        return '新手';
      case MoneyAgeLevel.intermediate:
        return '进阶';
      case MoneyAgeLevel.proficient:
        return '熟练';
      case MoneyAgeLevel.expert:
        return '专家';
      case MoneyAgeLevel.master:
        return '大师';
    }
  }

  String get description {
    switch (this) {
      case MoneyAgeLevel.beginner:
        return '刚开始培养理财意识';
      case MoneyAgeLevel.novice:
        return '正在养成延迟消费习惯';
      case MoneyAgeLevel.intermediate:
        return '消费更加理性';
      case MoneyAgeLevel.proficient:
        return '具备良好的财务规划能力';
      case MoneyAgeLevel.expert:
        return '理财能力出众';
      case MoneyAgeLevel.master:
        return '财务自律大师';
    }
  }

  int get minDays {
    switch (this) {
      case MoneyAgeLevel.beginner:
        return 0;
      case MoneyAgeLevel.novice:
        return 7;
      case MoneyAgeLevel.intermediate:
        return 14;
      case MoneyAgeLevel.proficient:
        return 21;
      case MoneyAgeLevel.expert:
        return 30;
      case MoneyAgeLevel.master:
        return 60;
    }
  }

  int get maxDays {
    switch (this) {
      case MoneyAgeLevel.beginner:
        return 7;
      case MoneyAgeLevel.novice:
        return 14;
      case MoneyAgeLevel.intermediate:
        return 21;
      case MoneyAgeLevel.proficient:
        return 30;
      case MoneyAgeLevel.expert:
        return 60;
      case MoneyAgeLevel.master:
        return 365;
    }
  }

  MoneyAgeLevel? get nextLevel {
    final index = MoneyAgeLevel.values.indexOf(this);
    if (index < MoneyAgeLevel.values.length - 1) {
      return MoneyAgeLevel.values[index + 1];
    }
    return null;
  }
}

/// 钱龄进阶目标
class MoneyAgeGoal {
  final String id;
  final MoneyAgeLevel targetLevel;
  final double targetMoneyAge;
  final DateTime createdAt;
  final DateTime? achievedAt;
  final bool isActive;

  const MoneyAgeGoal({
    required this.id,
    required this.targetLevel,
    required this.targetMoneyAge,
    required this.createdAt,
    this.achievedAt,
    this.isActive = true,
  });

  bool get isAchieved => achievedAt != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'targetLevel': targetLevel.index,
        'targetMoneyAge': targetMoneyAge,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'achievedAt': achievedAt?.millisecondsSinceEpoch,
        'isActive': isActive ? 1 : 0,
      };

  factory MoneyAgeGoal.fromMap(Map<String, dynamic> map) => MoneyAgeGoal(
        id: map['id'] as String,
        targetLevel: MoneyAgeLevel.values[map['targetLevel'] as int],
        targetMoneyAge: (map['targetMoneyAge'] as num).toDouble(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        achievedAt: map['achievedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['achievedAt'] as int)
            : null,
        isActive: (map['isActive'] as int?) != 0,
      );
}

/// 钱龄进度
class MoneyAgeProgress {
  final MoneyAgeLevel currentLevel;
  final double currentMoneyAge;
  final MoneyAgeLevel? nextLevel;
  final double progressToNext; // 0-1
  final int daysToNextLevel;
  final String encouragement;

  const MoneyAgeProgress({
    required this.currentLevel,
    required this.currentMoneyAge,
    this.nextLevel,
    required this.progressToNext,
    required this.daysToNextLevel,
    required this.encouragement,
  });
}

/// 钱龄挑战
class MoneyAgeChallenge {
  final String id;
  final String title;
  final String description;
  final int targetIncrease; // 目标增加天数
  final int durationDays; // 挑战持续天数
  final DateTime startDate;
  final DateTime endDate;
  final double startMoneyAge;
  final double? endMoneyAge;
  final bool isCompleted;
  final String reward;

  const MoneyAgeChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.targetIncrease,
    required this.durationDays,
    required this.startDate,
    required this.endDate,
    required this.startMoneyAge,
    this.endMoneyAge,
    this.isCompleted = false,
    required this.reward,
  });

  double get progress {
    if (endMoneyAge == null) return 0;
    final increase = endMoneyAge! - startMoneyAge;
    return (increase / targetIncrease).clamp(0, 1);
  }

  bool get isActive => DateTime.now().isBefore(endDate) && !isCompleted;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'targetIncrease': targetIncrease,
        'durationDays': durationDays,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'startMoneyAge': startMoneyAge,
        'endMoneyAge': endMoneyAge,
        'isCompleted': isCompleted ? 1 : 0,
        'reward': reward,
      };

  factory MoneyAgeChallenge.fromMap(Map<String, dynamic> map) =>
      MoneyAgeChallenge(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        targetIncrease: map['targetIncrease'] as int,
        durationDays: map['durationDays'] as int,
        startDate:
            DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
        endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int),
        startMoneyAge: (map['startMoneyAge'] as num).toDouble(),
        endMoneyAge: (map['endMoneyAge'] as num?)?.toDouble(),
        isCompleted: (map['isCompleted'] as int?) != 0,
        reward: map['reward'] as String,
      );
}

/// 钱龄进阶目标管理服务
///
/// 帮助用户逐步提升钱龄：
/// - 钱龄等级系统
/// - 进阶目标设定
/// - 挑战任务
/// - 进度追踪与激励
class MoneyAgeProgressionService {
  final DatabaseService _db;

  MoneyAgeProgressionService(this._db);

  /// 预定义的挑战模板
  static const List<Map<String, dynamic>> _challengeTemplates = [
    {
      'title': '7天钱龄挑战',
      'description': '一周内将平均钱龄提升3天',
      'targetIncrease': 3,
      'durationDays': 7,
      'reward': '获得"钱龄新星"徽章',
    },
    {
      'title': '21天习惯养成',
      'description': '三周内将平均钱龄提升7天',
      'targetIncrease': 7,
      'durationDays': 21,
      'reward': '获得"理财达人"徽章',
    },
    {
      'title': '月度钱龄飞跃',
      'description': '一个月内将平均钱龄提升10天',
      'targetIncrease': 10,
      'durationDays': 30,
      'reward': '获得"钱龄大师"徽章',
    },
    {
      'title': '极限挑战',
      'description': '两周内将平均钱龄提升14天',
      'targetIncrease': 14,
      'durationDays': 14,
      'reward': '获得"钱龄传奇"徽章',
    },
  ];

  /// 获取当前平均钱龄
  Future<double> getCurrentAverageMoneyAge() async {
    final result = await _db.rawQuery('''
      SELECT AVG(moneyAge) as avg FROM resource_pools
      WHERE remainingAmount > 0
    ''');

    return (result.first['avg'] as num?)?.toDouble() ?? 0;
  }

  /// 根据钱龄获取等级
  MoneyAgeLevel getLevelForAge(double moneyAge) {
    for (final level in MoneyAgeLevel.values.reversed) {
      if (moneyAge >= level.minDays) {
        return level;
      }
    }
    return MoneyAgeLevel.beginner;
  }

  /// 获取钱龄进度
  Future<MoneyAgeProgress> getProgress() async {
    final currentAge = await getCurrentAverageMoneyAge();
    final currentLevel = getLevelForAge(currentAge);
    final nextLevel = currentLevel.nextLevel;

    double progressToNext = 0;
    int daysToNext = 0;

    if (nextLevel != null) {
      final levelRange = nextLevel.minDays - currentLevel.minDays;
      final currentProgress = currentAge - currentLevel.minDays;
      progressToNext = (currentProgress / levelRange).clamp(0, 1);
      daysToNext = (nextLevel.minDays - currentAge).ceil();
    } else {
      progressToNext = 1.0;
    }

    final encouragement = _generateEncouragement(currentLevel, progressToNext);

    return MoneyAgeProgress(
      currentLevel: currentLevel,
      currentMoneyAge: currentAge,
      nextLevel: nextLevel,
      progressToNext: progressToNext,
      daysToNextLevel: daysToNext,
      encouragement: encouragement,
    );
  }

  /// 设置钱龄目标
  Future<MoneyAgeGoal> setGoal(MoneyAgeLevel targetLevel) async {
    // 先取消之前的活跃目标
    await _db.rawUpdate('''
      UPDATE money_age_goals SET isActive = 0 WHERE isActive = 1
    ''');

    final goal = MoneyAgeGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetLevel: targetLevel,
      targetMoneyAge: targetLevel.minDays.toDouble(),
      createdAt: DateTime.now(),
    );

    await _db.rawInsert('''
      INSERT INTO money_age_goals
      (id, targetLevel, targetMoneyAge, createdAt, isActive)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      goal.id,
      goal.targetLevel.index,
      goal.targetMoneyAge,
      goal.createdAt.millisecondsSinceEpoch,
      1,
    ]);

    return goal;
  }

  /// 获取当前活跃目标
  Future<MoneyAgeGoal?> getCurrentGoal() async {
    final results = await _db.rawQuery('''
      SELECT * FROM money_age_goals WHERE isActive = 1 LIMIT 1
    ''');

    if (results.isEmpty) return null;
    return MoneyAgeGoal.fromMap(results.first);
  }

  /// 检查并更新目标达成状态
  Future<MoneyAgeGoal?> checkGoalAchievement() async {
    final goal = await getCurrentGoal();
    if (goal == null || goal.isAchieved) return null;

    final currentAge = await getCurrentAverageMoneyAge();

    if (currentAge >= goal.targetMoneyAge) {
      // 达成目标
      await _db.rawUpdate('''
        UPDATE money_age_goals
        SET achievedAt = ?, isActive = 0
        WHERE id = ?
      ''', [DateTime.now().millisecondsSinceEpoch, goal.id]);

      return MoneyAgeGoal(
        id: goal.id,
        targetLevel: goal.targetLevel,
        targetMoneyAge: goal.targetMoneyAge,
        createdAt: goal.createdAt,
        achievedAt: DateTime.now(),
        isActive: false,
      );
    }

    return null;
  }

  /// 开始挑战
  Future<MoneyAgeChallenge> startChallenge(int templateIndex) async {
    if (templateIndex >= _challengeTemplates.length) {
      throw Exception('无效的挑战模板');
    }

    final template = _challengeTemplates[templateIndex];
    final currentAge = await getCurrentAverageMoneyAge();
    final now = DateTime.now();

    final challenge = MoneyAgeChallenge(
      id: now.millisecondsSinceEpoch.toString(),
      title: template['title'] as String,
      description: template['description'] as String,
      targetIncrease: template['targetIncrease'] as int,
      durationDays: template['durationDays'] as int,
      startDate: now,
      endDate: now.add(Duration(days: template['durationDays'] as int)),
      startMoneyAge: currentAge,
      reward: template['reward'] as String,
    );

    await _db.rawInsert('''
      INSERT INTO money_age_challenges
      (id, title, description, targetIncrease, durationDays,
       startDate, endDate, startMoneyAge, reward, isCompleted)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      challenge.id,
      challenge.title,
      challenge.description,
      challenge.targetIncrease,
      challenge.durationDays,
      challenge.startDate.millisecondsSinceEpoch,
      challenge.endDate.millisecondsSinceEpoch,
      challenge.startMoneyAge,
      challenge.reward,
      0,
    ]);

    return challenge;
  }

  /// 获取活跃挑战
  Future<MoneyAgeChallenge?> getActiveChallenge() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final results = await _db.rawQuery('''
      SELECT * FROM money_age_challenges
      WHERE endDate > ? AND isCompleted = 0
      ORDER BY startDate DESC
      LIMIT 1
    ''', [now]);

    if (results.isEmpty) return null;

    final challenge = MoneyAgeChallenge.fromMap(results.first);
    final currentAge = await getCurrentAverageMoneyAge();

    // 返回带有当前钱龄的挑战
    return MoneyAgeChallenge(
      id: challenge.id,
      title: challenge.title,
      description: challenge.description,
      targetIncrease: challenge.targetIncrease,
      durationDays: challenge.durationDays,
      startDate: challenge.startDate,
      endDate: challenge.endDate,
      startMoneyAge: challenge.startMoneyAge,
      endMoneyAge: currentAge,
      isCompleted: challenge.isCompleted,
      reward: challenge.reward,
    );
  }

  /// 检查并完成挑战
  Future<MoneyAgeChallenge?> checkChallengeCompletion() async {
    final challenge = await getActiveChallenge();
    if (challenge == null) return null;

    final currentAge = await getCurrentAverageMoneyAge();
    final increase = currentAge - challenge.startMoneyAge;

    if (increase >= challenge.targetIncrease) {
      // 完成挑战
      await _db.rawUpdate('''
        UPDATE money_age_challenges
        SET endMoneyAge = ?, isCompleted = 1
        WHERE id = ?
      ''', [currentAge, challenge.id]);

      return MoneyAgeChallenge(
        id: challenge.id,
        title: challenge.title,
        description: challenge.description,
        targetIncrease: challenge.targetIncrease,
        durationDays: challenge.durationDays,
        startDate: challenge.startDate,
        endDate: challenge.endDate,
        startMoneyAge: challenge.startMoneyAge,
        endMoneyAge: currentAge,
        isCompleted: true,
        reward: challenge.reward,
      );
    }

    return null;
  }

  /// 获取挑战历史
  Future<List<MoneyAgeChallenge>> getChallengeHistory({int limit = 10}) async {
    final results = await _db.rawQuery('''
      SELECT * FROM money_age_challenges
      ORDER BY startDate DESC
      LIMIT ?
    ''', [limit]);

    return results.map((m) => MoneyAgeChallenge.fromMap(m)).toList();
  }

  /// 获取可用的挑战模板
  List<Map<String, dynamic>> getAvailableChallenges() {
    return _challengeTemplates.asMap().entries.map((entry) => {
      'index': entry.key,
      ...entry.value,
    }).toList();
  }

  /// 获取钱龄提升建议
  Future<List<String>> getImprovementTips() async {
    final tips = <String>[];
    final progress = await getProgress();

    if (progress.currentMoneyAge < 7) {
      tips.add('尝试延迟非必要消费24小时，给自己思考时间');
      tips.add('将想买的东西先加入愿望清单，等待7天后再决定');
    } else if (progress.currentMoneyAge < 14) {
      tips.add('设置每周固定的"无消费日"，提升资金停留时间');
      tips.add('使用预算小金库，让每笔钱都有明确用途');
    } else if (progress.currentMoneyAge < 21) {
      tips.add('建立应急资金，减少冲动消费的压力');
      tips.add('定期回顾消费记录，识别可优化的支出');
    } else {
      tips.add('继续保持良好的消费习惯');
      tips.add('可以考虑将部分资金用于长期投资');
    }

    return tips;
  }

  /// 获取钱龄历史趋势
  Future<List<Map<String, dynamic>>> getMoneyAgeTrend({int days = 30}) async {
    final trend = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      // 获取当天结束时的平均钱龄
      final result = await _db.rawQuery('''
        SELECT AVG(
          CASE
            WHEN remainingAmount > 0
            THEN (? - createdAt) / 86400000.0
            ELSE 0
          END
        ) as avg
        FROM resource_pools
        WHERE createdAt < ?
      ''', [dayEnd.millisecondsSinceEpoch, dayEnd.millisecondsSinceEpoch]);

      final avgAge = (result.first['avg'] as num?)?.toDouble() ?? 0;

      trend.add({
        'date': dayStart.toIso8601String().substring(0, 10),
        'moneyAge': avgAge,
        'level': getLevelForAge(avgAge).displayName,
      });
    }

    return trend;
  }

  /// 获取统计摘要
  Future<Map<String, dynamic>> getStatsSummary() async {
    final progress = await getProgress();
    final goal = await getCurrentGoal();
    final challenge = await getActiveChallenge();

    // 获取历史最高钱龄
    final maxAgeResult = await _db.rawQuery('''
      SELECT MAX(moneyAge) as max FROM resource_pools
    ''');
    final maxAge = (maxAgeResult.first['max'] as num?)?.toDouble() ?? 0;

    // 获取已完成的挑战数
    final completedChallengesResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM money_age_challenges WHERE isCompleted = 1
    ''');
    final completedChallenges =
        (completedChallengesResult.first['count'] as int?) ?? 0;

    return {
      'currentMoneyAge': progress.currentMoneyAge,
      'currentLevel': progress.currentLevel.displayName,
      'maxMoneyAge': maxAge,
      'progressToNext': progress.progressToNext,
      'daysToNextLevel': progress.daysToNextLevel,
      'hasActiveGoal': goal != null && !goal.isAchieved,
      'hasActiveChallenge': challenge != null && challenge.isActive,
      'completedChallenges': completedChallenges,
      'encouragement': progress.encouragement,
    };
  }

  // 私有方法

  String _generateEncouragement(MoneyAgeLevel level, double progress) {
    if (progress >= 0.9) {
      return '即将突破${level.nextLevel?.displayName ?? ""}等级！';
    } else if (progress >= 0.5) {
      return '已完成一半，继续加油！';
    } else if (level == MoneyAgeLevel.beginner) {
      return '开始培养延迟消费习惯';
    } else {
      return level.description;
    }
  }
}
