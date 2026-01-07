import 'database_service.dart';

/// 激励类型
enum MotivationType {
  /// 庆祝成就
  celebration,

  /// 鼓励恢复
  recovery,

  /// 进度提醒
  progress,

  /// 习惯强化
  habitReinforcement,

  /// 情感支持
  emotionalSupport,

  /// 里程碑达成
  milestone,
}

extension MotivationTypeExtension on MotivationType {
  String get displayName {
    switch (this) {
      case MotivationType.celebration:
        return '成就庆祝';
      case MotivationType.recovery:
        return '恢复鼓励';
      case MotivationType.progress:
        return '进度提醒';
      case MotivationType.habitReinforcement:
        return '习惯强化';
      case MotivationType.emotionalSupport:
        return '情感支持';
      case MotivationType.milestone:
        return '里程碑';
    }
  }
}

/// 记账目标类型
enum RecordingGoalType {
  /// 每日记账
  daily,

  /// 每周记账（至少N天）
  weekly,

  /// 每笔消费记录
  everyExpense,

  /// 弹性目标
  flexible,
}

extension RecordingGoalTypeExtension on RecordingGoalType {
  String get displayName {
    switch (this) {
      case RecordingGoalType.daily:
        return '每日记账';
      case RecordingGoalType.weekly:
        return '每周记账';
      case RecordingGoalType.everyExpense:
        return '每笔必记';
      case RecordingGoalType.flexible:
        return '弹性记账';
    }
  }
}

/// 激励消息
class MotivationMessage {
  final String id;
  final MotivationType type;
  final String title;
  final String content;
  final String? actionText;
  final String? actionRoute;
  final DateTime createdAt;
  final bool isRead;

  const MotivationMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.actionText,
    this.actionRoute,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'title': title,
        'content': content,
        'actionText': actionText,
        'actionRoute': actionRoute,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'isRead': isRead ? 1 : 0,
      };

  factory MotivationMessage.fromMap(Map<String, dynamic> map) =>
      MotivationMessage(
        id: map['id'] as String,
        type: MotivationType.values[map['type'] as int],
        title: map['title'] as String,
        content: map['content'] as String,
        actionText: map['actionText'] as String?,
        actionRoute: map['actionRoute'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        isRead: (map['isRead'] as int?) != 0,
      );
}

/// 弹性记账目标
class FlexibleRecordingGoal {
  final String id;
  final RecordingGoalType type;
  final int targetDays; // 目标天数（周目标时使用）
  final int currentStreak;
  final int longestStreak;
  final int totalRecordingDays;
  final double completionRate; // 完成率
  final DateTime? lastRecordingDate;

  const FlexibleRecordingGoal({
    required this.id,
    required this.type,
    required this.targetDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalRecordingDays,
    required this.completionRate,
    this.lastRecordingDate,
  });

  bool get isOnTrack => completionRate >= 0.7;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'targetDays': targetDays,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalRecordingDays': totalRecordingDays,
        'completionRate': completionRate,
        'lastRecordingDate': lastRecordingDate?.millisecondsSinceEpoch,
      };

  factory FlexibleRecordingGoal.fromMap(Map<String, dynamic> map) =>
      FlexibleRecordingGoal(
        id: map['id'] as String,
        type: RecordingGoalType.values[map['type'] as int],
        targetDays: map['targetDays'] as int,
        currentStreak: map['currentStreak'] as int? ?? 0,
        longestStreak: map['longestStreak'] as int? ?? 0,
        totalRecordingDays: map['totalRecordingDays'] as int? ?? 0,
        completionRate: (map['completionRate'] as num?)?.toDouble() ?? 0,
        lastRecordingDate: map['lastRecordingDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['lastRecordingDate'] as int)
            : null,
      );
}

/// 用户情绪状态
enum UserMoodState {
  /// 积极
  positive,

  /// 中性
  neutral,

  /// 需要鼓励
  needsEncouragement,

  /// 需要安慰
  needsComfort,
}

/// 包容性记账激励服务
///
/// 提供包容性的激励机制，避免用户因中断或超支而感到挫败：
/// - 弹性记账目标（不强求每日）
/// - 中断恢复鼓励（而非惩罚）
/// - 进步导向（关注进步而非完美）
/// - 情感化支持消息
class InclusiveMotivationService {
  final DatabaseService _db;

  InclusiveMotivationService(this._db);

  /// 预定义的鼓励消息模板
  static const Map<MotivationType, List<String>> _messageTemplates = {
    MotivationType.celebration: [
      '太棒了！连续记账{days}天，你正在养成好习惯',
      '本月已记录{count}笔账，财务清晰度提升了',
      '储蓄率达到{rate}%，理财能力越来越强',
      '本周预算执行率{rate}%，控制得很好',
    ],
    MotivationType.recovery: [
      '欢迎回来！中断不是失败，重新开始就是胜利',
      '没关系，每个人都有忙碌的时候，今天继续就好',
      '过去的已经过去，从今天开始记录也很棒',
      '记账是为了自己，什么时候开始都不晚',
    ],
    MotivationType.progress: [
      '本周记账{days}天，比上周进步了',
      '消费记录越来越完整，继续保持',
      '这个月的记账完成率{rate}%，稳步提升中',
      '已经养成了{days}天的记账习惯，很棒',
    ],
    MotivationType.habitReinforcement: [
      '每天花1分钟记账，一年后你会感谢自己',
      '记账不是为了省钱，是为了心里有数',
      '财务自由从了解自己的消费开始',
      '记账是送给未来自己的礼物',
    ],
    MotivationType.emotionalSupport: [
      '超支了也没关系，重要的是知道钱花在哪了',
      '财务管理是长跑，偶尔的波动很正常',
      '不完美的记账，也比不记账强百倍',
      '你已经比大多数人更关注财务健康了',
    ],
    MotivationType.milestone: [
      '恭喜！累计记账满{count}笔，财务意识满分',
      '连续记账{days}天，获得"记账达人"称号',
      '本月储蓄目标达成，为你鼓掌',
      '钱龄首次突破{days}天，理财能力提升',
    ],
  };

  /// 设置记账目标
  Future<FlexibleRecordingGoal> setRecordingGoal({
    required RecordingGoalType type,
    int targetDays = 5, // 每周目标默认5天
  }) async {
    final goal = FlexibleRecordingGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      targetDays: targetDays,
      currentStreak: 0,
      longestStreak: 0,
      totalRecordingDays: 0,
      completionRate: 0,
    );

    await _db.rawInsert('''
      INSERT OR REPLACE INTO recording_goals
      (id, type, targetDays, currentStreak, longestStreak, totalRecordingDays, completionRate)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      goal.id,
      goal.type.index,
      goal.targetDays,
      goal.currentStreak,
      goal.longestStreak,
      goal.totalRecordingDays,
      goal.completionRate,
    ]);

    return goal;
  }

  /// 获取当前记账目标
  Future<FlexibleRecordingGoal?> getCurrentGoal() async {
    final results = await _db.rawQuery('''
      SELECT * FROM recording_goals ORDER BY id DESC LIMIT 1
    ''');

    if (results.isEmpty) return null;
    return FlexibleRecordingGoal.fromMap(results.first);
  }

  /// 记录今日记账活动
  Future<void> recordTodayActivity() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    // 检查今天是否已记录
    final existing = await _db.rawQuery('''
      SELECT id FROM recording_activity
      WHERE date >= ? AND date < ?
    ''', [
      todayStart.millisecondsSinceEpoch,
      todayStart.add(const Duration(days: 1)).millisecondsSinceEpoch,
    ]);

    if (existing.isNotEmpty) return;

    // 记录今天
    await _db.rawInsert('''
      INSERT INTO recording_activity (date) VALUES (?)
    ''', [todayStart.millisecondsSinceEpoch]);

    // 更新目标进度
    await _updateGoalProgress();
  }

  /// 更新目标进度
  Future<void> _updateGoalProgress() async {
    final goal = await getCurrentGoal();
    if (goal == null) return;

    // 计算本周/本月记账天数
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    // 本周记账天数
    final weekDaysResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT date(date/1000, 'unixepoch')) as days
      FROM recording_activity
      WHERE date >= ?
    ''', [weekStart.millisecondsSinceEpoch]);
    final weekDays = (weekDaysResult.first['days'] as int?) ?? 0;

    // 本月记账天数
    final monthDaysResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT date(date/1000, 'unixepoch')) as days
      FROM recording_activity
      WHERE date >= ?
    ''', [monthStart.millisecondsSinceEpoch]);
    final monthDays = (monthDaysResult.first['days'] as int?) ?? 0;

    // 计算连续天数
    final streakDays = await _calculateStreak();

    // 计算完成率
    double completionRate;
    switch (goal.type) {
      case RecordingGoalType.weekly:
        completionRate = weekDays / goal.targetDays;
        break;
      case RecordingGoalType.daily:
        completionRate = streakDays > 0 ? 1.0 : 0.0;
        break;
      default:
        completionRate = monthDays / now.day;
    }

    // 更新目标
    await _db.rawUpdate('''
      UPDATE recording_goals
      SET currentStreak = ?,
          longestStreak = MAX(longestStreak, ?),
          totalRecordingDays = totalRecordingDays + 1,
          completionRate = ?,
          lastRecordingDate = ?
      WHERE id = ?
    ''', [
      streakDays,
      streakDays,
      completionRate.clamp(0, 1),
      now.millisecondsSinceEpoch,
      goal.id,
    ]);
  }

  /// 计算连续记账天数
  Future<int> _calculateStreak() async {
    final results = await _db.rawQuery('''
      SELECT DISTINCT date(date/1000, 'unixepoch') as day
      FROM recording_activity
      ORDER BY date DESC
    ''');

    if (results.isEmpty) return 0;

    int streak = 0;
    DateTime? prevDate;

    for (final row in results) {
      final dayStr = row['day'] as String;
      final date = DateTime.parse(dayStr);

      if (prevDate == null) {
        // 检查是否是今天或昨天
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        if (date.isAtSameMomentAs(today) || date.isAtSameMomentAs(yesterday)) {
          streak = 1;
          prevDate = date;
        } else {
          break;
        }
      } else {
        final diff = prevDate.difference(date).inDays;
        if (diff == 1) {
          streak++;
          prevDate = date;
        } else {
          break;
        }
      }
    }

    return streak;
  }

  /// 推断用户情绪状态
  Future<UserMoodState> inferUserMood() async {
    final goal = await getCurrentGoal();

    if (goal == null) {
      return UserMoodState.neutral;
    }

    // 基于多个因素判断
    final lastRecording = goal.lastRecordingDate;
    final now = DateTime.now();

    // 如果超过3天没记账
    if (lastRecording != null &&
        now.difference(lastRecording).inDays > 3) {
      return UserMoodState.needsEncouragement;
    }

    // 如果连续记账中
    if (goal.currentStreak >= 7) {
      return UserMoodState.positive;
    }

    // 如果完成率低
    if (goal.completionRate < 0.5) {
      return UserMoodState.needsComfort;
    }

    return UserMoodState.neutral;
  }

  /// 生成激励消息
  Future<MotivationMessage> generateMotivation() async {
    final mood = await inferUserMood();
    final goal = await getCurrentGoal();

    MotivationType type;
    String template;

    switch (mood) {
      case UserMoodState.positive:
        type = MotivationType.celebration;
        break;
      case UserMoodState.needsEncouragement:
        type = MotivationType.recovery;
        break;
      case UserMoodState.needsComfort:
        type = MotivationType.emotionalSupport;
        break;
      default:
        type = MotivationType.habitReinforcement;
    }

    final templates = _messageTemplates[type]!;
    template = templates[DateTime.now().millisecond % templates.length];

    // 替换模板变量
    String content = template
        .replaceAll('{days}', (goal?.currentStreak ?? 0).toString())
        .replaceAll('{count}', (goal?.totalRecordingDays ?? 0).toString())
        .replaceAll('{rate}', ((goal?.completionRate ?? 0) * 100).toStringAsFixed(0));

    final message = MotivationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: type.displayName,
      content: content,
      createdAt: DateTime.now(),
    );

    // 保存消息
    await _db.rawInsert('''
      INSERT INTO motivation_messages
      (id, type, title, content, createdAt, isRead)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      message.id,
      message.type.index,
      message.title,
      message.content,
      message.createdAt.millisecondsSinceEpoch,
      0,
    ]);

    return message;
  }

  /// 获取最近的激励消息
  Future<List<MotivationMessage>> getRecentMessages({int limit = 10}) async {
    final results = await _db.rawQuery('''
      SELECT * FROM motivation_messages
      ORDER BY createdAt DESC
      LIMIT ?
    ''', [limit]);

    return results.map((m) => MotivationMessage.fromMap(m)).toList();
  }

  /// 标记消息已读
  Future<void> markAsRead(String messageId) async {
    await _db.rawUpdate('''
      UPDATE motivation_messages SET isRead = 1 WHERE id = ?
    ''', [messageId]);
  }

  /// 获取记账统计摘要
  Future<Map<String, dynamic>> getRecordingSummary() async {
    final goal = await getCurrentGoal();
    final streak = await _calculateStreak();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 本月记账天数
    final monthDaysResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT date(date/1000, 'unixepoch')) as days
      FROM recording_activity
      WHERE date >= ?
    ''', [monthStart.millisecondsSinceEpoch]);
    final monthDays = (monthDaysResult.first['days'] as int?) ?? 0;

    // 总记账天数
    final totalDaysResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT date(date/1000, 'unixepoch')) as days
      FROM recording_activity
    ''');
    final totalDays = (totalDaysResult.first['days'] as int?) ?? 0;

    return {
      'currentStreak': streak,
      'longestStreak': goal?.longestStreak ?? streak,
      'monthDays': monthDays,
      'totalDays': totalDays,
      'completionRate': goal?.completionRate ?? 0,
      'goalType': goal?.type.displayName ?? '未设置',
      'isOnTrack': goal?.isOnTrack ?? false,
    };
  }

  /// 获取个性化建议
  Future<List<String>> getPersonalizedTips() async {
    final tips = <String>[];
    final mood = await inferUserMood();
    final summary = await getRecordingSummary();

    final streak = summary['currentStreak'] as int;
    final completionRate = summary['completionRate'] as double;

    if (streak == 0) {
      tips.add('试试设置每日提醒，帮助你养成记账习惯');
    } else if (streak < 7) {
      tips.add('继续保持！再坚持${7 - streak}天就能养成习惯');
    } else if (streak >= 21) {
      tips.add('21天习惯已养成！你已经是记账达人了');
    }

    if (completionRate < 0.5) {
      tips.add('不必追求每日记账，每周记3-4次也很好');
    }

    if (mood == UserMoodState.needsEncouragement) {
      tips.add('中断了也没关系，从今天开始就好');
    }

    return tips;
  }

  /// 发送恢复鼓励（在用户中断后回归时调用）
  Future<MotivationMessage> sendRecoveryEncouragement() async {
    final templates = _messageTemplates[MotivationType.recovery]!;
    final template = templates[DateTime.now().millisecond % templates.length];

    final message = MotivationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MotivationType.recovery,
      title: '欢迎回来',
      content: template,
      actionText: '开始记账',
      actionRoute: '/add-transaction',
      createdAt: DateTime.now(),
    );

    await _db.rawInsert('''
      INSERT INTO motivation_messages
      (id, type, title, content, actionText, actionRoute, createdAt, isRead)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      message.id,
      message.type.index,
      message.title,
      message.content,
      message.actionText,
      message.actionRoute,
      message.createdAt.millisecondsSinceEpoch,
      0,
    ]);

    return message;
  }

  /// 发送里程碑庆祝
  Future<MotivationMessage?> checkAndCelebrateMilestone() async {
    final summary = await getRecordingSummary();
    final totalDays = summary['totalDays'] as int;
    final streak = summary['currentStreak'] as int;

    // 检查里程碑
    final milestones = [7, 21, 30, 60, 90, 100, 180, 365];

    String? milestoneContent;
    if (milestones.contains(totalDays)) {
      milestoneContent = '恭喜！累计记账满$totalDays天，你的财务意识满分';
    } else if (milestones.contains(streak)) {
      milestoneContent = '恭喜！连续记账$streak天，获得"记账达人"称号';
    }

    if (milestoneContent == null) return null;

    final message = MotivationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MotivationType.milestone,
      title: '里程碑达成',
      content: milestoneContent,
      createdAt: DateTime.now(),
    );

    await _db.rawInsert('''
      INSERT INTO motivation_messages
      (id, type, title, content, createdAt, isRead)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      message.id,
      message.type.index,
      message.title,
      message.content,
      message.createdAt.millisecondsSinceEpoch,
      0,
    ]);

    return message;
  }
}
