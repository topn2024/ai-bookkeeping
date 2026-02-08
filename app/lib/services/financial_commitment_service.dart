import 'database_service.dart';

/// 承诺类型
enum CommitmentType {
  /// 预算承诺
  budget,

  /// 储蓄承诺
  savings,

  /// 消费限制承诺
  spendingLimit,

  /// 无消费日承诺
  noSpendDay,

  /// 债务还款承诺
  debtPayment,

  /// 习惯养成承诺
  habitFormation,
}

extension CommitmentTypeExtension on CommitmentType {
  String get displayName {
    switch (this) {
      case CommitmentType.budget:
        return '预算承诺';
      case CommitmentType.savings:
        return '储蓄承诺';
      case CommitmentType.spendingLimit:
        return '消费限制';
      case CommitmentType.noSpendDay:
        return '无消费日';
      case CommitmentType.debtPayment:
        return '债务还款';
      case CommitmentType.habitFormation:
        return '习惯养成';
    }
  }

  String get icon {
    switch (this) {
      case CommitmentType.budget:
        return '📊';
      case CommitmentType.savings:
        return '💰';
      case CommitmentType.spendingLimit:
        return '🚫';
      case CommitmentType.noSpendDay:
        return '📅';
      case CommitmentType.debtPayment:
        return '💳';
      case CommitmentType.habitFormation:
        return '🎯';
    }
  }
}

/// 承诺状态
enum CommitmentStatus {
  /// 进行中
  active,

  /// 已完成
  completed,

  /// 已失败
  failed,

  /// 已取消
  cancelled,

  /// 已过期
  expired,
}

/// 承诺可见性
enum CommitmentVisibility {
  /// 仅自己可见
  private,

  /// 好友可见
  friends,

  /// 公开
  public,
}

/// 财务承诺
class FinancialCommitment {
  final String id;
  final CommitmentType type;
  final String title;
  final String description;
  final double? targetAmount;
  final int? targetDays;
  final DateTime startDate;
  final DateTime endDate;
  final CommitmentStatus status;
  final CommitmentVisibility visibility;
  final double progress; // 0.0 - 1.0
  final int checkInCount;
  final DateTime? lastCheckIn;
  final String? reward; // 完成后的奖励描述
  final String? consequence; // 失败后的后果描述
  final List<String> witnesses; // 见证人（好友ID）

  const FinancialCommitment({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.targetAmount,
    this.targetDays,
    required this.startDate,
    required this.endDate,
    this.status = CommitmentStatus.active,
    this.visibility = CommitmentVisibility.private,
    this.progress = 0.0,
    this.checkInCount = 0,
    this.lastCheckIn,
    this.reward,
    this.consequence,
    this.witnesses = const [],
  });

  bool get isActive => status == CommitmentStatus.active;
  bool get isCompleted => status == CommitmentStatus.completed;
  bool get isExpired => DateTime.now().isAfter(endDate) && isActive;

  int get remainingDays {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays;
  }

  int get totalDays => endDate.difference(startDate).inDays;
  int get elapsedDays => DateTime.now().difference(startDate).inDays;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'title': title,
        'description': description,
        'targetAmount': targetAmount,
        'targetDays': targetDays,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'status': status.index,
        'visibility': visibility.index,
        'progress': progress,
        'checkInCount': checkInCount,
        'lastCheckIn': lastCheckIn?.millisecondsSinceEpoch,
        'reward': reward,
        'consequence': consequence,
        'witnesses': witnesses.join(','),
      };

  factory FinancialCommitment.fromMap(Map<String, dynamic> map) =>
      FinancialCommitment(
        id: map['id'] as String,
        type: CommitmentType.values[map['type'] as int],
        title: map['title'] as String,
        description: map['description'] as String,
        targetAmount: (map['targetAmount'] as num?)?.toDouble(),
        targetDays: map['targetDays'] as int?,
        startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
        endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int),
        status: CommitmentStatus.values[map['status'] as int? ?? 0],
        visibility:
            CommitmentVisibility.values[map['visibility'] as int? ?? 0],
        progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
        checkInCount: map['checkInCount'] as int? ?? 0,
        lastCheckIn: map['lastCheckIn'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['lastCheckIn'] as int)
            : null,
        reward: map['reward'] as String?,
        consequence: map['consequence'] as String?,
        witnesses: (map['witnesses'] as String?)?.split(',') ?? [],
      );

  FinancialCommitment copyWith({
    CommitmentStatus? status,
    double? progress,
    int? checkInCount,
    DateTime? lastCheckIn,
  }) {
    return FinancialCommitment(
      id: id,
      type: type,
      title: title,
      description: description,
      targetAmount: targetAmount,
      targetDays: targetDays,
      startDate: startDate,
      endDate: endDate,
      status: status ?? this.status,
      visibility: visibility,
      progress: progress ?? this.progress,
      checkInCount: checkInCount ?? this.checkInCount,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      reward: reward,
      consequence: consequence,
      witnesses: witnesses,
    );
  }
}

/// 承诺打卡记录
class CommitmentCheckIn {
  final String id;
  final String commitmentId;
  final DateTime checkInTime;
  final String? note;
  final double? amount; // 当日相关金额
  final bool success;

  const CommitmentCheckIn({
    required this.id,
    required this.commitmentId,
    required this.checkInTime,
    this.note,
    this.amount,
    this.success = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'commitmentId': commitmentId,
        'checkInTime': checkInTime.millisecondsSinceEpoch,
        'note': note,
        'amount': amount,
        'success': success ? 1 : 0,
      };

  factory CommitmentCheckIn.fromMap(Map<String, dynamic> map) =>
      CommitmentCheckIn(
        id: map['id'] as String,
        commitmentId: map['commitmentId'] as String,
        checkInTime:
            DateTime.fromMillisecondsSinceEpoch(map['checkInTime'] as int),
        note: map['note'] as String?,
        amount: (map['amount'] as num?)?.toDouble(),
        success: (map['success'] as int?) != 0,
      );
}

/// 承诺统计
class CommitmentStats {
  final int totalCommitments;
  final int activeCommitments;
  final int completedCommitments;
  final int failedCommitments;
  final double successRate;
  final int longestStreak;
  final int currentStreak;

  const CommitmentStats({
    required this.totalCommitments,
    required this.activeCommitments,
    required this.completedCommitments,
    required this.failedCommitments,
    required this.successRate,
    required this.longestStreak,
    required this.currentStreak,
  });
}

/// 承诺模板
class CommitmentTemplate {
  final String id;
  final CommitmentType type;
  final String title;
  final String description;
  final int defaultDays;
  final double? defaultAmount;
  final String? suggestedReward;
  final String? suggestedConsequence;

  const CommitmentTemplate({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.defaultDays,
    this.defaultAmount,
    this.suggestedReward,
    this.suggestedConsequence,
  });
}

/// 财务承诺服务
///
/// 利用承诺一致性心理学原理帮助用户达成财务目标：
/// - 公开承诺增加执行力
/// - 社交见证提供问责
/// - 打卡追踪保持动力
/// - 奖惩机制强化行为
class FinancialCommitmentService {
  final DatabaseService _db;

  FinancialCommitmentService(this._db);

  /// 预定义的承诺模板
  static const List<CommitmentTemplate> templates = [
    CommitmentTemplate(
      id: 'no_spend_week',
      type: CommitmentType.noSpendDay,
      title: '无消费周挑战',
      description: '连续7天只进行必要消费',
      defaultDays: 7,
      suggestedReward: '奖励自己一杯奶茶',
      suggestedConsequence: '下周继续挑战',
    ),
    CommitmentTemplate(
      id: 'budget_month',
      type: CommitmentType.budget,
      title: '月度预算挑战',
      description: '本月严格控制在预算内',
      defaultDays: 30,
      suggestedReward: '节省金额的10%用于犒劳自己',
    ),
    CommitmentTemplate(
      id: 'savings_30',
      type: CommitmentType.savings,
      title: '30天储蓄挑战',
      description: '每天存入固定金额',
      defaultDays: 30,
      defaultAmount: 10,
      suggestedReward: '看到账户增长就是最好的奖励',
    ),
    CommitmentTemplate(
      id: 'coffee_free',
      type: CommitmentType.spendingLimit,
      title: '咖啡自由挑战',
      description: '一个月不买咖啡，自己冲泡',
      defaultDays: 30,
      suggestedReward: '月末买一袋优质咖啡豆',
      suggestedConsequence: '请朋友喝咖啡',
    ),
    CommitmentTemplate(
      id: 'debt_accelerate',
      type: CommitmentType.debtPayment,
      title: '债务加速还款',
      description: '每月额外还款',
      defaultDays: 90,
      defaultAmount: 500,
      suggestedReward: '清债后庆祝一下',
    ),
    CommitmentTemplate(
      id: 'record_habit',
      type: CommitmentType.habitFormation,
      title: '记账习惯养成',
      description: '连续21天每日记账',
      defaultDays: 21,
      suggestedReward: '解锁记账达人成就',
    ),
  ];

  /// 创建承诺
  Future<FinancialCommitment> createCommitment({
    required CommitmentType type,
    required String title,
    required String description,
    double? targetAmount,
    int? targetDays,
    required DateTime endDate,
    CommitmentVisibility visibility = CommitmentVisibility.private,
    String? reward,
    String? consequence,
    List<String> witnesses = const [],
  }) async {
    final commitment = FinancialCommitment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      description: description,
      targetAmount: targetAmount,
      targetDays: targetDays,
      startDate: DateTime.now(),
      endDate: endDate,
      visibility: visibility,
      reward: reward,
      consequence: consequence,
      witnesses: witnesses,
    );

    await _db.rawInsert('''
      INSERT INTO financial_commitments
      (id, type, title, description, targetAmount, targetDays, startDate, endDate,
       status, visibility, progress, checkInCount, reward, consequence, witnesses)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      commitment.id,
      commitment.type.index,
      commitment.title,
      commitment.description,
      commitment.targetAmount,
      commitment.targetDays,
      commitment.startDate.millisecondsSinceEpoch,
      commitment.endDate.millisecondsSinceEpoch,
      commitment.status.index,
      commitment.visibility.index,
      commitment.progress,
      commitment.checkInCount,
      commitment.reward,
      commitment.consequence,
      commitment.witnesses.join(','),
    ]);

    return commitment;
  }

  /// 从模板创建承诺
  Future<FinancialCommitment> createFromTemplate({
    required String templateId,
    double? customAmount,
    int? customDays,
    CommitmentVisibility visibility = CommitmentVisibility.private,
    List<String> witnesses = const [],
  }) async {
    final template = templates.firstWhere((t) => t.id == templateId);
    final days = customDays ?? template.defaultDays;

    return createCommitment(
      type: template.type,
      title: template.title,
      description: template.description,
      targetAmount: customAmount ?? template.defaultAmount,
      targetDays: days,
      endDate: DateTime.now().add(Duration(days: days)),
      visibility: visibility,
      reward: template.suggestedReward,
      consequence: template.suggestedConsequence,
      witnesses: witnesses,
    );
  }

  /// 打卡
  Future<void> checkIn({
    required String commitmentId,
    String? note,
    double? amount,
    bool success = true,
  }) async {
    final checkIn = CommitmentCheckIn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      commitmentId: commitmentId,
      checkInTime: DateTime.now(),
      note: note,
      amount: amount,
      success: success,
    );

    await _db.rawInsert('''
      INSERT INTO commitment_checkins
      (id, commitmentId, checkInTime, note, amount, success)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      checkIn.id,
      checkIn.commitmentId,
      checkIn.checkInTime.millisecondsSinceEpoch,
      checkIn.note,
      checkIn.amount,
      checkIn.success ? 1 : 0,
    ]);

    // 更新承诺进度
    await _updateCommitmentProgress(commitmentId);
  }

  /// 更新承诺进度
  Future<void> _updateCommitmentProgress(String commitmentId) async {
    final results = await _db.rawQuery('''
      SELECT * FROM financial_commitments WHERE id = ?
    ''', [commitmentId]);

    if (results.isEmpty) return;

    final commitment = FinancialCommitment.fromMap(results.first);

    // 计算打卡次数
    final checkInResults = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM commitment_checkins
      WHERE commitmentId = ? AND success = 1
    ''', [commitmentId]);
    final checkInCount = (checkInResults.first['count'] as int?) ?? 0;

    // 计算进度
    double progress = 0.0;
    if (commitment.targetDays != null && commitment.targetDays! > 0) {
      progress = checkInCount / commitment.targetDays!;
    } else {
      progress = commitment.elapsedDays / commitment.totalDays;
    }
    progress = progress.clamp(0.0, 1.0);

    // 检查是否完成
    CommitmentStatus newStatus = commitment.status;
    if (progress >= 1.0) {
      newStatus = CommitmentStatus.completed;
    }

    await _db.rawUpdate('''
      UPDATE financial_commitments
      SET progress = ?, checkInCount = ?, lastCheckIn = ?, status = ?
      WHERE id = ?
    ''', [
      progress,
      checkInCount,
      DateTime.now().millisecondsSinceEpoch,
      newStatus.index,
      commitmentId,
    ]);
  }

  /// 获取活跃承诺
  Future<List<FinancialCommitment>> getActiveCommitments() async {
    final results = await _db.rawQuery('''
      SELECT * FROM financial_commitments
      WHERE status = ?
      ORDER BY endDate ASC
    ''', [CommitmentStatus.active.index]);

    return results.map((m) => FinancialCommitment.fromMap(m)).toList();
  }

  /// 获取所有承诺
  Future<List<FinancialCommitment>> getAllCommitments({
    CommitmentStatus? status,
    int? limit,
  }) async {
    String query = 'SELECT * FROM financial_commitments';
    final params = <dynamic>[];

    if (status != null) {
      query += ' WHERE status = ?';
      params.add(status.index);
    }

    query += ' ORDER BY startDate DESC';

    if (limit != null) {
      query += ' LIMIT ?';
      params.add(limit);
    }

    final results = await _db.rawQuery(query, params);
    return results.map((m) => FinancialCommitment.fromMap(m)).toList();
  }

  /// 获取承诺详情
  Future<FinancialCommitment?> getCommitment(String id) async {
    final results = await _db.rawQuery('''
      SELECT * FROM financial_commitments WHERE id = ?
    ''', [id]);

    if (results.isEmpty) return null;
    return FinancialCommitment.fromMap(results.first);
  }

  /// 获取承诺打卡记录
  Future<List<CommitmentCheckIn>> getCheckIns(String commitmentId) async {
    final results = await _db.rawQuery('''
      SELECT * FROM commitment_checkins
      WHERE commitmentId = ?
      ORDER BY checkInTime DESC
    ''', [commitmentId]);

    return results.map((m) => CommitmentCheckIn.fromMap(m)).toList();
  }

  /// 标记承诺失败
  Future<void> failCommitment(String commitmentId, {String? reason}) async {
    await _db.rawUpdate('''
      UPDATE financial_commitments SET status = ? WHERE id = ?
    ''', [CommitmentStatus.failed.index, commitmentId]);
  }

  /// 取消承诺
  Future<void> cancelCommitment(String commitmentId) async {
    await _db.rawUpdate('''
      UPDATE financial_commitments SET status = ? WHERE id = ?
    ''', [CommitmentStatus.cancelled.index, commitmentId]);
  }

  /// 检查并更新过期承诺
  Future<void> checkExpiredCommitments() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 找出已过期但状态仍为active的承诺
    final results = await _db.rawQuery('''
      SELECT * FROM financial_commitments
      WHERE status = ? AND endDate < ?
    ''', [CommitmentStatus.active.index, now]);

    for (final map in results) {
      final commitment = FinancialCommitment.fromMap(map);

      // 如果进度达到目标，标记为完成；否则标记为过期
      final newStatus = commitment.progress >= 1.0
          ? CommitmentStatus.completed
          : CommitmentStatus.expired;

      await _db.rawUpdate('''
        UPDATE financial_commitments SET status = ? WHERE id = ?
      ''', [newStatus.index, commitment.id]);
    }
  }

  /// 获取今日需要打卡的承诺
  Future<List<FinancialCommitment>> getTodayCheckInRequired() async {
    final activeCommitments = await getActiveCommitments();
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    final needCheckIn = <FinancialCommitment>[];

    for (final commitment in activeCommitments) {
      if (commitment.targetDays == null) continue;

      // 检查今日是否已打卡
      final checkInResults = await _db.rawQuery('''
        SELECT COUNT(*) as count FROM commitment_checkins
        WHERE commitmentId = ? AND checkInTime >= ?
      ''', [commitment.id, startOfToday.millisecondsSinceEpoch]);

      final checkedToday = (checkInResults.first['count'] as int?) ?? 0;

      if (checkedToday == 0) {
        needCheckIn.add(commitment);
      }
    }

    return needCheckIn;
  }

  /// 获取承诺统计
  Future<CommitmentStats> getStats() async {
    // 总承诺数
    final totalResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM financial_commitments
    ''');
    final total = (totalResult.first['count'] as int?) ?? 0;

    // 活跃承诺数
    final activeResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM financial_commitments WHERE status = ?
    ''', [CommitmentStatus.active.index]);
    final active = (activeResult.first['count'] as int?) ?? 0;

    // 完成承诺数
    final completedResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM financial_commitments WHERE status = ?
    ''', [CommitmentStatus.completed.index]);
    final completed = (completedResult.first['count'] as int?) ?? 0;

    // 失败承诺数
    final failedResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM financial_commitments
      WHERE status IN (?, ?)
    ''', [CommitmentStatus.failed.index, CommitmentStatus.expired.index]);
    final failed = (failedResult.first['count'] as int?) ?? 0;

    // 计算成功率
    final finished = completed + failed;
    final successRate = finished > 0 ? completed / finished : 0.0;

    // 计算连续完成天数（简化版）
    final streakResult = await _db.rawQuery('''
      SELECT MAX(checkInCount) as longest FROM financial_commitments
      WHERE status = ?
    ''', [CommitmentStatus.completed.index]);
    final longestStreak = (streakResult.first['longest'] as int?) ?? 0;

    // 当前连续天数（最近活跃承诺的打卡数）
    final currentResult = await _db.rawQuery('''
      SELECT checkInCount FROM financial_commitments
      WHERE status = ?
      ORDER BY lastCheckIn DESC
      LIMIT 1
    ''', [CommitmentStatus.active.index]);
    final currentStreak = currentResult.isNotEmpty
        ? (currentResult.first['checkInCount'] as int?) ?? 0
        : 0;

    return CommitmentStats(
      totalCommitments: total,
      activeCommitments: active,
      completedCommitments: completed,
      failedCommitments: failed,
      successRate: successRate,
      longestStreak: longestStreak,
      currentStreak: currentStreak,
    );
  }

  /// 获取公开承诺（用于社交展示）
  Future<List<FinancialCommitment>> getPublicCommitments({int limit = 20}) async {
    final results = await _db.rawQuery('''
      SELECT * FROM financial_commitments
      WHERE visibility = ?
      ORDER BY startDate DESC
      LIMIT ?
    ''', [CommitmentVisibility.public.index, limit]);

    return results.map((m) => FinancialCommitment.fromMap(m)).toList();
  }

  /// 生成承诺报告
  Future<Map<String, dynamic>> generateReport({int days = 30}) async {
    final stats = await getStats();
    final since =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    // 最近完成的承诺
    final recentCompleted = await _db.rawQuery('''
      SELECT * FROM financial_commitments
      WHERE status = ? AND endDate >= ?
      ORDER BY endDate DESC
      LIMIT 5
    ''', [CommitmentStatus.completed.index, since]);

    // 按类型统计
    final byType = await _db.rawQuery('''
      SELECT type, COUNT(*) as count FROM financial_commitments
      WHERE startDate >= ?
      GROUP BY type
    ''', [since]);

    final typeStats = <CommitmentType, int>{};
    for (final row in byType) {
      final type = CommitmentType.values[row['type'] as int];
      typeStats[type] = row['count'] as int;
    }

    return {
      'stats': stats,
      'recentCompleted':
          recentCompleted.map((m) => FinancialCommitment.fromMap(m)).toList(),
      'byType': typeStats,
      'periodDays': days,
    };
  }
}
