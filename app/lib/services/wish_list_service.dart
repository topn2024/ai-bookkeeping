import 'database_service.dart';

/// 愿望优先级
enum WishPriority {
  low,
  medium,
  high,
  urgent,
}

extension WishPriorityExtension on WishPriority {
  String get displayName {
    switch (this) {
      case WishPriority.low:
        return '随缘';
      case WishPriority.medium:
        return '想要';
      case WishPriority.high:
        return '很想要';
      case WishPriority.urgent:
        return '迫切需要';
    }
  }

  int get weight {
    switch (this) {
      case WishPriority.low:
        return 1;
      case WishPriority.medium:
        return 2;
      case WishPriority.high:
        return 3;
      case WishPriority.urgent:
        return 4;
    }
  }
}

/// 愿望状态
enum WishStatus {
  /// 计划中
  planning,

  /// 存钱中
  saving,

  /// 已实现
  achieved,

  /// 已放弃
  abandoned,

  /// 已过期（设定的截止日期已过）
  expired,
}

extension WishStatusExtension on WishStatus {
  String get displayName {
    switch (this) {
      case WishStatus.planning:
        return '计划中';
      case WishStatus.saving:
        return '存钱中';
      case WishStatus.achieved:
        return '已实现';
      case WishStatus.abandoned:
        return '已放弃';
      case WishStatus.expired:
        return '已过期';
    }
  }

  bool get isActive =>
      this == WishStatus.planning || this == WishStatus.saving;
}

/// 愿望清单项目
class WishItem {
  final String id;
  final String name;
  final String? description;
  final double targetAmount;
  final double savedAmount;
  final String? imageUrl;
  final String? productUrl;
  final WishPriority priority;
  final WishStatus status;
  final DateTime createdAt;
  final DateTime? targetDate;
  final DateTime? achievedAt;
  final String? categoryId;
  final String? note;
  final List<String> tags;

  const WishItem({
    required this.id,
    required this.name,
    this.description,
    required this.targetAmount,
    this.savedAmount = 0,
    this.imageUrl,
    this.productUrl,
    this.priority = WishPriority.medium,
    this.status = WishStatus.planning,
    required this.createdAt,
    this.targetDate,
    this.achievedAt,
    this.categoryId,
    this.note,
    this.tags = const [],
  });

  /// 已完成进度（0-1）
  double get progress {
    if (targetAmount <= 0) return 0;
    return (savedAmount / targetAmount).clamp(0.0, 1.0);
  }

  /// 进度百分比
  int get progressPercent => (progress * 100).round();

  /// 还差多少
  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  /// 是否已达成目标
  bool get isGoalReached => savedAmount >= targetAmount;

  /// 距离目标日期还有多少天
  int? get daysUntilTarget {
    if (targetDate == null) return null;
    return targetDate!.difference(DateTime.now()).inDays;
  }

  /// 是否已过目标日期
  bool get isOverdue {
    if (targetDate == null) return false;
    return DateTime.now().isAfter(targetDate!);
  }

  /// 每天需要存多少才能达成目标
  double? get dailySavingNeeded {
    if (targetDate == null || isGoalReached) return null;
    final days = daysUntilTarget ?? 0;
    if (days <= 0) return remaining;
    return remaining / days;
  }

  WishItem copyWith({
    String? id,
    String? name,
    String? description,
    double? targetAmount,
    double? savedAmount,
    String? imageUrl,
    String? productUrl,
    WishPriority? priority,
    WishStatus? status,
    DateTime? createdAt,
    DateTime? targetDate,
    DateTime? achievedAt,
    String? categoryId,
    String? note,
    List<String>? tags,
  }) {
    return WishItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      imageUrl: imageUrl ?? this.imageUrl,
      productUrl: productUrl ?? this.productUrl,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
      achievedAt: achievedAt ?? this.achievedAt,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'imageUrl': imageUrl,
      'productUrl': productUrl,
      'priority': priority.index,
      'status': status.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'targetDate': targetDate?.millisecondsSinceEpoch,
      'achievedAt': achievedAt?.millisecondsSinceEpoch,
      'categoryId': categoryId,
      'note': note,
      'tags': tags.join(','),
    };
  }

  factory WishItem.fromMap(Map<String, dynamic> map) {
    return WishItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0,
      imageUrl: map['imageUrl'] as String?,
      productUrl: map['productUrl'] as String?,
      priority: WishPriority.values[map['priority'] as int? ?? 1],
      status: WishStatus.values[map['status'] as int? ?? 0],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      targetDate: map['targetDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['targetDate'] as int)
          : null,
      achievedAt: map['achievedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['achievedAt'] as int)
          : null,
      categoryId: map['categoryId'] as String?,
      note: map['note'] as String?,
      tags: (map['tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
    );
  }
}

/// 愿望清单统计
class WishListStats {
  final int totalWishes;
  final int activeWishes;
  final int achievedWishes;
  final double totalTargetAmount;
  final double totalSavedAmount;
  final double achievementRate;

  const WishListStats({
    required this.totalWishes,
    required this.activeWishes,
    required this.achievedWishes,
    required this.totalTargetAmount,
    required this.totalSavedAmount,
    required this.achievementRate,
  });
}

/// 愿望清单服务
///
/// 帮助用户管理购物愿望，通过"先规划再消费"的方式
/// 将冲动消费转化为有计划的目标储蓄。
///
/// 功能：
/// - 添加/管理愿望清单
/// - 追踪储蓄进度
/// - 优先级排序
/// - 与预算系统联动
class WishListService {
  final DatabaseService _db;

  WishListService(this._db);

  /// 添加愿望
  Future<WishItem> addWish({
    required String name,
    required double targetAmount,
    String? description,
    String? imageUrl,
    String? productUrl,
    WishPriority priority = WishPriority.medium,
    DateTime? targetDate,
    String? categoryId,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final wish = WishItem(
      id: '${now.millisecondsSinceEpoch}',
      name: name,
      targetAmount: targetAmount,
      description: description,
      imageUrl: imageUrl,
      productUrl: productUrl,
      priority: priority,
      createdAt: now,
      targetDate: targetDate,
      categoryId: categoryId,
      tags: tags,
    );

    await _db.rawInsert('''
      INSERT INTO wish_items
      (id, name, description, targetAmount, savedAmount, imageUrl, productUrl,
       priority, status, createdAt, targetDate, categoryId, note, tags)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      wish.id,
      wish.name,
      wish.description,
      wish.targetAmount,
      wish.savedAmount,
      wish.imageUrl,
      wish.productUrl,
      wish.priority.index,
      wish.status.index,
      wish.createdAt.millisecondsSinceEpoch,
      wish.targetDate?.millisecondsSinceEpoch,
      wish.categoryId,
      wish.note,
      wish.tags.join(','),
    ]);

    return wish;
  }

  /// 更新愿望
  Future<void> updateWish(WishItem wish) async {
    await _db.rawUpdate('''
      UPDATE wish_items SET
        name = ?, description = ?, targetAmount = ?, savedAmount = ?,
        imageUrl = ?, productUrl = ?, priority = ?, status = ?,
        targetDate = ?, categoryId = ?, note = ?, tags = ?
      WHERE id = ?
    ''', [
      wish.name,
      wish.description,
      wish.targetAmount,
      wish.savedAmount,
      wish.imageUrl,
      wish.productUrl,
      wish.priority.index,
      wish.status.index,
      wish.targetDate?.millisecondsSinceEpoch,
      wish.categoryId,
      wish.note,
      wish.tags.join(','),
      wish.id,
    ]);
  }

  /// 删除愿望
  Future<void> deleteWish(String wishId) async {
    await _db.rawDelete('DELETE FROM wish_items WHERE id = ?', [wishId]);
  }

  /// 向愿望存钱
  Future<WishItem?> addSavings(String wishId, double amount) async {
    if (amount <= 0) return null;

    final wish = await getWish(wishId);
    if (wish == null) return null;

    final newSaved = wish.savedAmount + amount;
    final newStatus = newSaved >= wish.targetAmount
        ? WishStatus.achieved
        : WishStatus.saving;

    final updatedWish = wish.copyWith(
      savedAmount: newSaved,
      status: newStatus,
      achievedAt: newStatus == WishStatus.achieved ? DateTime.now() : null,
    );

    await updateWish(updatedWish);

    // 记录存款历史
    await _db.rawInsert('''
      INSERT INTO wish_savings_history (id, wishId, amount, savedAt)
      VALUES (?, ?, ?, ?)
    ''', [
      DateTime.now().millisecondsSinceEpoch.toString(),
      wishId,
      amount,
      DateTime.now().millisecondsSinceEpoch,
    ]);

    return updatedWish;
  }

  /// 标记为已实现
  Future<void> markAsAchieved(String wishId) async {
    await _db.rawUpdate('''
      UPDATE wish_items SET status = ?, achievedAt = ? WHERE id = ?
    ''', [
      WishStatus.achieved.index,
      DateTime.now().millisecondsSinceEpoch,
      wishId,
    ]);
  }

  /// 标记为已放弃
  Future<void> markAsAbandoned(String wishId, {String? reason}) async {
    await _db.rawUpdate('''
      UPDATE wish_items SET status = ?, note = ? WHERE id = ?
    ''', [WishStatus.abandoned.index, reason, wishId]);
  }

  /// 获取单个愿望
  Future<WishItem?> getWish(String wishId) async {
    final results = await _db.rawQuery(
      'SELECT * FROM wish_items WHERE id = ?',
      [wishId],
    );
    if (results.isEmpty) return null;
    return WishItem.fromMap(results.first);
  }

  /// 获取所有活跃愿望
  Future<List<WishItem>> getActiveWishes({
    WishPriority? priority,
    String? categoryId,
  }) async {
    String query = '''
      SELECT * FROM wish_items WHERE status IN (?, ?)
    ''';
    final params = <dynamic>[
      WishStatus.planning.index,
      WishStatus.saving.index,
    ];

    if (priority != null) {
      query += ' AND priority = ?';
      params.add(priority.index);
    }

    if (categoryId != null) {
      query += ' AND categoryId = ?';
      params.add(categoryId);
    }

    query += ' ORDER BY priority DESC, createdAt DESC';

    final results = await _db.rawQuery(query, params);
    return results.map((m) => WishItem.fromMap(m)).toList();
  }

  /// 获取已实现的愿望
  Future<List<WishItem>> getAchievedWishes({int limit = 20}) async {
    final results = await _db.rawQuery('''
      SELECT * FROM wish_items
      WHERE status = ?
      ORDER BY achievedAt DESC
      LIMIT ?
    ''', [WishStatus.achieved.index, limit]);

    return results.map((m) => WishItem.fromMap(m)).toList();
  }

  /// 获取即将到期的愿望
  Future<List<WishItem>> getUpcomingDeadlines({int daysAhead = 7}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deadline = DateTime.now()
        .add(Duration(days: daysAhead))
        .millisecondsSinceEpoch;

    final results = await _db.rawQuery('''
      SELECT * FROM wish_items
      WHERE status IN (?, ?) AND targetDate IS NOT NULL
        AND targetDate > ? AND targetDate <= ?
      ORDER BY targetDate ASC
    ''', [
      WishStatus.planning.index,
      WishStatus.saving.index,
      now,
      deadline,
    ]);

    return results.map((m) => WishItem.fromMap(m)).toList();
  }

  /// 获取统计数据
  Future<WishListStats> getStats() async {
    // 总数
    final totalResult = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM wish_items',
    );
    final total = (totalResult.first['count'] as int?) ?? 0;

    // 活跃数
    final activeResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM wish_items WHERE status IN (?, ?)
    ''', [WishStatus.planning.index, WishStatus.saving.index]);
    final active = (activeResult.first['count'] as int?) ?? 0;

    // 已实现数
    final achievedResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM wish_items WHERE status = ?
    ''', [WishStatus.achieved.index]);
    final achieved = (achievedResult.first['count'] as int?) ?? 0;

    // 金额统计
    final amountResult = await _db.rawQuery('''
      SELECT SUM(targetAmount) as target, SUM(savedAmount) as saved
      FROM wish_items WHERE status IN (?, ?)
    ''', [WishStatus.planning.index, WishStatus.saving.index]);

    final targetAmount = (amountResult.first['target'] as num?)?.toDouble() ?? 0;
    final savedAmount = (amountResult.first['saved'] as num?)?.toDouble() ?? 0;

    return WishListStats(
      totalWishes: total,
      activeWishes: active,
      achievedWishes: achieved,
      totalTargetAmount: targetAmount,
      totalSavedAmount: savedAmount,
      achievementRate: total > 0 ? achieved / total : 0,
    );
  }

  /// 获取存款历史
  Future<List<Map<String, dynamic>>> getSavingsHistory(String wishId) async {
    return await _db.rawQuery('''
      SELECT * FROM wish_savings_history
      WHERE wishId = ?
      ORDER BY savedAt DESC
    ''', [wishId]);
  }

  /// 智能推荐：根据用户预算和愿望优先级，推荐本月可以实现的愿望
  Future<List<WishItem>> getRecommendedWishes({
    required double availableBudget,
  }) async {
    final activeWishes = await getActiveWishes();

    // 按优先级和剩余金额排序
    final affordable = activeWishes
        .where((w) => w.remaining <= availableBudget)
        .toList()
      ..sort((a, b) {
        // 先按优先级，再按完成进度
        final priorityCompare = b.priority.weight.compareTo(a.priority.weight);
        if (priorityCompare != 0) return priorityCompare;
        return b.progress.compareTo(a.progress);
      });

    return affordable.take(3).toList();
  }

  /// 从冲动消费转化为愿望
  Future<WishItem> convertFromImpulse({
    required String itemName,
    required double amount,
    String? description,
  }) async {
    return addWish(
      name: itemName,
      targetAmount: amount,
      description: description ?? '从冲动消费转化',
      priority: WishPriority.medium,
      tags: ['冲动转化'],
    );
  }
}
