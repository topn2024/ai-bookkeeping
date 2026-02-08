import 'database_service.dart';

/// 中断类型
enum BreakType {
  /// 短期中断（1-3天）
  short,

  /// 中期中断（4-14天）
  medium,

  /// 长期中断（15天以上）
  long,

  /// 首次使用
  firstTime,
}

extension BreakTypeExtension on BreakType {
  String get displayName {
    switch (this) {
      case BreakType.short:
        return '短期中断';
      case BreakType.medium:
        return '中期中断';
      case BreakType.long:
        return '长期中断';
      case BreakType.firstTime:
        return '首次使用';
    }
  }

  String get encouragement {
    switch (this) {
      case BreakType.short:
        return '小小的中断不是问题，让我们继续！';
      case BreakType.medium:
        return '欢迎回来！习惯培养需要时间，重新开始就是胜利';
      case BreakType.long:
        return '很高兴见到你！无论过去多久，现在开始永远不晚';
      case BreakType.firstTime:
        return '欢迎开始你的财务管理之旅！';
    }
  }
}

/// 恢复状态
enum RecoveryStatus {
  /// 需要恢复
  needsRecovery,

  /// 恢复中
  recovering,

  /// 已恢复
  recovered,

  /// 活跃用户
  active,
}

/// 恢复任务
class RecoveryTask {
  final String id;
  final String title;
  final String description;
  final int priority; // 1-5, 5最高
  final bool isRequired;
  final bool isCompleted;
  final Duration estimatedTime;

  const RecoveryTask({
    required this.id,
    required this.title,
    required this.description,
    this.priority = 3,
    this.isRequired = false,
    this.isCompleted = false,
    this.estimatedTime = const Duration(minutes: 5),
  });

  RecoveryTask copyWith({bool? isCompleted}) {
    return RecoveryTask(
      id: id,
      title: title,
      description: description,
      priority: priority,
      isRequired: isRequired,
      isCompleted: isCompleted ?? this.isCompleted,
      estimatedTime: estimatedTime,
    );
  }
}

/// 恢复计划
class RecoveryPlan {
  final BreakType breakType;
  final int daysSinceLastActivity;
  final List<RecoveryTask> tasks;
  final String welcomeMessage;
  final DateTime? lastActivityDate;
  final int missedTransactionsEstimate;

  const RecoveryPlan({
    required this.breakType,
    required this.daysSinceLastActivity,
    required this.tasks,
    required this.welcomeMessage,
    this.lastActivityDate,
    this.missedTransactionsEstimate = 0,
  });

  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  double get progress =>
      tasks.isEmpty ? 0.0 : completedTasks / tasks.length;
  bool get isComplete => tasks.every((t) => t.isCompleted || !t.isRequired);
}

/// 用户活动记录
class UserActivity {
  final String id;
  final DateTime timestamp;
  final String activityType; // login, transaction, budget_check, etc.
  final Map<String, dynamic>? metadata;

  const UserActivity({
    required this.id,
    required this.timestamp,
    required this.activityType,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'activityType': activityType,
        'metadata': metadata?.toString(),
      };

  factory UserActivity.fromMap(Map<String, dynamic> map) => UserActivity(
        id: map['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        activityType: map['activityType'] as String,
      );
}

/// 中断恢复助手
///
/// 帮助用户在记账习惯中断后平滑恢复：
/// - 检测用户活跃度
/// - 生成个性化恢复计划
/// - 提供鼓励和引导
/// - 追踪恢复进度
class BreakRecoveryAssistant {
  final DatabaseService _db;

  BreakRecoveryAssistant(this._db);

  /// 记录用户活动
  Future<void> recordActivity(String activityType,
      {Map<String, dynamic>? metadata}) async {
    final activity = UserActivity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      activityType: activityType,
      metadata: metadata,
    );

    await _db.rawInsert('''
      INSERT INTO user_activities (id, timestamp, activityType, metadata)
      VALUES (?, ?, ?, ?)
    ''', [
      activity.id,
      activity.timestamp.millisecondsSinceEpoch,
      activity.activityType,
      metadata?.toString(),
    ]);
  }

  /// 获取最后活动时间
  Future<DateTime?> getLastActivityTime() async {
    final results = await _db.rawQuery('''
      SELECT MAX(timestamp) as lastActivity FROM user_activities
    ''');

    if (results.isEmpty || results.first['lastActivity'] == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
        results.first['lastActivity'] as int);
  }

  /// 检测中断类型
  Future<BreakType> detectBreakType() async {
    final lastActivity = await getLastActivityTime();

    if (lastActivity == null) {
      return BreakType.firstTime;
    }

    final daysSinceLastActivity =
        DateTime.now().difference(lastActivity).inDays;

    if (daysSinceLastActivity <= 3) {
      return BreakType.short;
    } else if (daysSinceLastActivity <= 14) {
      return BreakType.medium;
    } else {
      return BreakType.long;
    }
  }

  /// 获取恢复状态
  Future<RecoveryStatus> getRecoveryStatus() async {
    final lastActivity = await getLastActivityTime();

    if (lastActivity == null) {
      return RecoveryStatus.needsRecovery;
    }

    final daysSinceLastActivity =
        DateTime.now().difference(lastActivity).inDays;

    if (daysSinceLastActivity > 3) {
      // 检查是否有进行中的恢复计划
      final recoveryProgress = await _getRecoveryProgress();
      if (recoveryProgress != null && recoveryProgress < 1.0) {
        return RecoveryStatus.recovering;
      }
      return RecoveryStatus.needsRecovery;
    }

    return RecoveryStatus.active;
  }

  /// 生成恢复计划
  Future<RecoveryPlan> generateRecoveryPlan() async {
    final breakType = await detectBreakType();
    final lastActivity = await getLastActivityTime();
    final daysSinceLastActivity = lastActivity != null
        ? DateTime.now().difference(lastActivity).inDays
        : 0;

    // 估算遗漏的交易数
    final missedEstimate = await _estimateMissedTransactions(lastActivity);

    // 生成欢迎消息
    final welcomeMessage = _generateWelcomeMessage(breakType, daysSinceLastActivity);

    // 生成恢复任务
    final tasks = _generateRecoveryTasks(breakType, missedEstimate);

    return RecoveryPlan(
      breakType: breakType,
      daysSinceLastActivity: daysSinceLastActivity,
      tasks: tasks,
      welcomeMessage: welcomeMessage,
      lastActivityDate: lastActivity,
      missedTransactionsEstimate: missedEstimate,
    );
  }

  /// 完成恢复任务
  Future<void> completeRecoveryTask(String taskId) async {
    await _db.rawInsert('''
      INSERT OR REPLACE INTO recovery_task_progress (taskId, completedAt)
      VALUES (?, ?)
    ''', [taskId, DateTime.now().millisecondsSinceEpoch]);
  }

  /// 获取恢复计划进度
  Future<RecoveryPlan> getRecoveryPlanWithProgress() async {
    final plan = await generateRecoveryPlan();

    // 获取已完成的任务
    final completedResults = await _db.rawQuery('''
      SELECT taskId FROM recovery_task_progress
    ''');

    final completedIds =
        completedResults.map((r) => r['taskId'] as String).toSet();

    // 更新任务完成状态
    final updatedTasks = plan.tasks.map((task) {
      return task.copyWith(isCompleted: completedIds.contains(task.id));
    }).toList();

    return RecoveryPlan(
      breakType: plan.breakType,
      daysSinceLastActivity: plan.daysSinceLastActivity,
      tasks: updatedTasks,
      welcomeMessage: plan.welcomeMessage,
      lastActivityDate: plan.lastActivityDate,
      missedTransactionsEstimate: plan.missedTransactionsEstimate,
    );
  }

  /// 重置恢复进度（完成恢复后调用）
  Future<void> completeRecovery() async {
    await _db.rawDelete('DELETE FROM recovery_task_progress');
    await recordActivity('recovery_completed');
  }

  /// 获取活动统计
  Future<Map<String, dynamic>> getActivityStats({int days = 30}) async {
    final since =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    // 活跃天数
    final activeDaysResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT date(timestamp/1000, 'unixepoch')) as days
      FROM user_activities
      WHERE timestamp >= ?
    ''', [since]);
    final activeDays = (activeDaysResult.first['days'] as int?) ?? 0;

    // 按类型统计
    final byTypeResult = await _db.rawQuery('''
      SELECT activityType, COUNT(*) as count
      FROM user_activities
      WHERE timestamp >= ?
      GROUP BY activityType
    ''', [since]);

    final byType = <String, int>{};
    for (final row in byTypeResult) {
      byType[row['activityType'] as String] = row['count'] as int;
    }

    // 最长连续天数
    final streakDays = await _calculateLongestStreak(days);

    return {
      'activeDays': activeDays,
      'totalDays': days,
      'activityRate': activeDays / days,
      'byType': byType,
      'longestStreak': streakDays,
    };
  }

  /// 检查是否需要提醒
  Future<bool> shouldSendReminder() async {
    final lastActivity = await getLastActivityTime();
    if (lastActivity == null) return true;

    final hoursSinceLastActivity =
        DateTime.now().difference(lastActivity).inHours;

    // 超过48小时未活动，发送提醒
    return hoursSinceLastActivity >= 48;
  }

  /// 获取提醒消息
  Future<String> getReminderMessage() async {
    final lastActivity = await getLastActivityTime();
    final daysSinceLastActivity = lastActivity != null
        ? DateTime.now().difference(lastActivity).inDays
        : 0;

    if (daysSinceLastActivity == 0) {
      return '今天还没有记账哦，趁着还记得，记一笔吧！';
    } else if (daysSinceLastActivity == 1) {
      return '昨天忘记记账了，今天一起补上吧！';
    } else if (daysSinceLastActivity <= 3) {
      return '已经$daysSinceLastActivity天没记账了，快来看看有什么消费需要记录';
    } else if (daysSinceLastActivity <= 7) {
      return '好久不见！这周的消费还记得吗？让我们一起回顾一下';
    } else {
      return '很想你！无论过去多久，重新开始永远不晚';
    }
  }

  // 私有方法

  String _generateWelcomeMessage(BreakType breakType, int days) {
    switch (breakType) {
      case BreakType.firstTime:
        return '欢迎使用智能记账！让我们开始你的财务管理之旅。';
      case BreakType.short:
        return '欢迎回来！上次记账是$days天前，让我们继续保持好习惯。';
      case BreakType.medium:
        return '好久不见！已经$days天了，不过没关系，我们一起把遗漏的补上。';
      case BreakType.long:
        return '很高兴再次见到你！虽然过去了$days天，但重新开始永远不晚。让我帮你快速恢复状态。';
    }
  }

  List<RecoveryTask> _generateRecoveryTasks(BreakType breakType, int missedEstimate) {
    final tasks = <RecoveryTask>[];

    // 基础任务（所有类型都有）
    tasks.add(const RecoveryTask(
      id: 'review_balance',
      title: '查看账户余额',
      description: '确认当前各账户的余额是否正确',
      priority: 5,
      isRequired: true,
      estimatedTime: Duration(minutes: 2),
    ));

    // 根据中断类型添加任务
    switch (breakType) {
      case BreakType.firstTime:
        tasks.addAll([
          const RecoveryTask(
            id: 'setup_accounts',
            title: '设置账户',
            description: '添加你常用的银行卡、支付宝、微信等账户',
            priority: 5,
            isRequired: true,
            estimatedTime: Duration(minutes: 5),
          ),
          const RecoveryTask(
            id: 'set_budget',
            title: '设置月度预算',
            description: '给自己定一个合理的月度消费目标',
            priority: 4,
            isRequired: false,
            estimatedTime: Duration(minutes: 3),
          ),
          const RecoveryTask(
            id: 'first_transaction',
            title: '记录第一笔账',
            description: '记录今天的任意一笔消费或收入',
            priority: 5,
            isRequired: true,
            estimatedTime: Duration(minutes: 1),
          ),
        ]);
        break;

      case BreakType.short:
        if (missedEstimate > 0) {
          tasks.add(RecoveryTask(
            id: 'add_missed',
            title: '补录遗漏账单',
            description: '预计有$missedEstimate笔交易需要补录',
            priority: 4,
            isRequired: false,
            estimatedTime: Duration(minutes: missedEstimate * 2),
          ));
        }
        tasks.add(const RecoveryTask(
          id: 'today_transaction',
          title: '记录今日消费',
          description: '把今天的消费记录下来',
          priority: 5,
          isRequired: true,
          estimatedTime: Duration(minutes: 3),
        ));
        break;

      case BreakType.medium:
        tasks.addAll([
          const RecoveryTask(
            id: 'sync_bills',
            title: '同步账单',
            description: '从支付宝/微信导入遗漏的账单',
            priority: 5,
            isRequired: false,
            estimatedTime: Duration(minutes: 5),
          ),
          RecoveryTask(
            id: 'review_period',
            title: '回顾消费情况',
            description: '查看过去两周的消费趋势',
            priority: 3,
            isRequired: false,
            estimatedTime: const Duration(minutes: 3),
          ),
          const RecoveryTask(
            id: 'adjust_budget',
            title: '调整预算',
            description: '根据实际情况调整本月预算',
            priority: 3,
            isRequired: false,
            estimatedTime: Duration(minutes: 2),
          ),
        ]);
        break;

      case BreakType.long:
        tasks.addAll([
          const RecoveryTask(
            id: 'fresh_start',
            title: '全新开始',
            description: '不必补录所有历史，从今天开始就好',
            priority: 5,
            isRequired: true,
            estimatedTime: Duration(minutes: 1),
          ),
          const RecoveryTask(
            id: 'update_balance',
            title: '更新账户余额',
            description: '将账户余额更新为当前实际值',
            priority: 5,
            isRequired: true,
            estimatedTime: Duration(minutes: 3),
          ),
          const RecoveryTask(
            id: 'set_new_goals',
            title: '设定新目标',
            description: '给自己设定一个新的财务小目标',
            priority: 4,
            isRequired: false,
            estimatedTime: Duration(minutes: 3),
          ),
          const RecoveryTask(
            id: 'enable_reminder',
            title: '开启记账提醒',
            description: '设置每日提醒，帮助养成习惯',
            priority: 4,
            isRequired: false,
            estimatedTime: Duration(minutes: 1),
          ),
        ]);
        break;
    }

    // 按优先级排序
    tasks.sort((a, b) => b.priority.compareTo(a.priority));

    return tasks;
  }

  Future<int> _estimateMissedTransactions(DateTime? lastActivity) async {
    if (lastActivity == null) return 0;

    final daysSinceLastActivity =
        DateTime.now().difference(lastActivity).inDays;

    // 获取用户平均每日交易数
    final avgResult = await _db.rawQuery('''
      SELECT COUNT(*) * 1.0 / 30 as avg
      FROM transactions
      WHERE date >= ?
    ''', [
      DateTime.now()
          .subtract(const Duration(days: 60))
          .millisecondsSinceEpoch,
    ]);

    final avgDaily = (avgResult.first['avg'] as num?)?.toDouble() ?? 2.0;

    return (daysSinceLastActivity * avgDaily).round();
  }

  Future<double?> _getRecoveryProgress() async {
    final plan = await generateRecoveryPlan();
    final completedResults = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM recovery_task_progress
    ''');

    final completed = (completedResults.first['count'] as int?) ?? 0;
    final total = plan.tasks.length;

    if (total == 0) return null;
    return completed / total;
  }

  Future<int> _calculateLongestStreak(int maxDays) async {
    final since =
        DateTime.now().subtract(Duration(days: maxDays)).millisecondsSinceEpoch;

    final results = await _db.rawQuery('''
      SELECT DISTINCT date(timestamp/1000, 'unixepoch') as day
      FROM user_activities
      WHERE timestamp >= ?
      ORDER BY day ASC
    ''', [since]);

    if (results.isEmpty) return 0;

    int longestStreak = 1;
    int currentStreak = 1;
    DateTime? prevDate;

    for (final row in results) {
      final dayStr = row['day'] as String;
      final date = DateTime.parse(dayStr);

      if (prevDate != null) {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          currentStreak++;
          if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
          }
        } else {
          currentStreak = 1;
        }
      }
      prevDate = date;
    }

    return longestStreak;
  }
}
