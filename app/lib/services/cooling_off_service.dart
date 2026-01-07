import 'dart:async';

import 'database_service.dart';

/// 冷静期状态
enum CoolingOffStatus {
  /// 等待中（冷静期未结束）
  waiting,

  /// 已完成（冷静期已结束）
  completed,

  /// 已取消（用户取消了购买计划）
  cancelled,

  /// 已执行（用户在冷静期结束后完成购买）
  executed,

  /// 已过期（冷静期结束但用户未操作）
  expired,
}

extension CoolingOffStatusExtension on CoolingOffStatus {
  String get displayName {
    switch (this) {
      case CoolingOffStatus.waiting:
        return '冷静中';
      case CoolingOffStatus.completed:
        return '已完成';
      case CoolingOffStatus.cancelled:
        return '已取消';
      case CoolingOffStatus.executed:
        return '已购买';
      case CoolingOffStatus.expired:
        return '已过期';
    }
  }

  bool get isActive => this == CoolingOffStatus.waiting;
}

/// 冷静期项目
class CoolingOffItem {
  final String id;
  final String itemName;
  final double amount;
  final String? categoryId;
  final String? description;
  final DateTime createdAt;
  final DateTime expiresAt;
  final CoolingOffStatus status;
  final String? cancelReason;
  final DateTime? completedAt;

  const CoolingOffItem({
    required this.id,
    required this.itemName,
    required this.amount,
    this.categoryId,
    this.description,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.cancelReason,
    this.completedAt,
  });

  /// 剩余等待时间
  Duration get remainingTime {
    if (!status.isActive) return Duration.zero;
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 是否已到期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 等待进度（0-1）
  double get progress {
    final total = expiresAt.difference(createdAt).inSeconds;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// 格式化剩余时间
  String get remainingTimeFormatted {
    final remaining = remainingTime;
    if (remaining.inHours >= 24) {
      return '${remaining.inDays}天${remaining.inHours % 24}小时';
    } else if (remaining.inHours >= 1) {
      return '${remaining.inHours}小时${remaining.inMinutes % 60}分钟';
    } else if (remaining.inMinutes >= 1) {
      return '${remaining.inMinutes}分钟';
    } else {
      return '即将结束';
    }
  }

  CoolingOffItem copyWith({
    String? id,
    String? itemName,
    double? amount,
    String? categoryId,
    String? description,
    DateTime? createdAt,
    DateTime? expiresAt,
    CoolingOffStatus? status,
    String? cancelReason,
    DateTime? completedAt,
  }) {
    return CoolingOffItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'amount': amount,
      'categoryId': categoryId,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'status': status.index,
      'cancelReason': cancelReason,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory CoolingOffItem.fromMap(Map<String, dynamic> map) {
    return CoolingOffItem(
      id: map['id'] as String,
      itemName: map['itemName'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String?,
      description: map['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
      status: CoolingOffStatus.values[map['status'] as int],
      cancelReason: map['cancelReason'] as String?,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
    );
  }
}

/// 冷静期统计
class CoolingOffStats {
  final int totalItems;
  final int cancelledCount;
  final int executedCount;
  final int expiredCount;
  final double totalSaved; // 因取消而节省的金额
  final double cancelRate; // 取消率

  const CoolingOffStats({
    required this.totalItems,
    required this.cancelledCount,
    required this.executedCount,
    required this.expiredCount,
    required this.totalSaved,
    required this.cancelRate,
  });
}

/// 冷静期配置
class CoolingOffConfig {
  /// 默认冷静期时长
  final Duration defaultDuration;

  /// 大额消费冷静期时长
  final Duration largeAmountDuration;

  /// 大额消费阈值
  final double largeAmountThreshold;

  /// 是否启用到期提醒
  final bool enableExpiryReminder;

  /// 到期提醒提前时间
  final Duration reminderBefore;

  const CoolingOffConfig({
    this.defaultDuration = const Duration(hours: 24),
    this.largeAmountDuration = const Duration(hours: 72),
    this.largeAmountThreshold = 1000,
    this.enableExpiryReminder = true,
    this.reminderBefore = const Duration(hours: 1),
  });
}

/// 冷静期服务
///
/// 帮助用户在冲动消费前设置等待期，通过延迟满足
/// 减少非理性消费。研究表明，24-48小时的等待期
/// 可以显著降低冲动购买的完成率。
class CoolingOffPeriodService {
  final DatabaseService _db;
  CoolingOffConfig _config;

  // 到期提醒回调
  final List<void Function(CoolingOffItem)> _expiryCallbacks = [];

  // 定时检查任务
  Timer? _checkTimer;

  CoolingOffPeriodService(this._db, {CoolingOffConfig? config})
      : _config = config ?? const CoolingOffConfig() {
    _startPeriodicCheck();
  }

  /// 获取当前配置
  CoolingOffConfig get config => _config;

  /// 更新配置
  void updateConfig(CoolingOffConfig config) {
    _config = config;
  }

  /// 添加到期提醒回调
  void addExpiryCallback(void Function(CoolingOffItem) callback) {
    _expiryCallbacks.add(callback);
  }

  /// 移除到期提醒回调
  void removeExpiryCallback(void Function(CoolingOffItem) callback) {
    _expiryCallbacks.remove(callback);
  }

  /// 添加冷静期项目
  Future<CoolingOffItem> addItem({
    required String itemName,
    required double amount,
    String? categoryId,
    String? description,
    Duration? customDuration,
  }) async {
    final now = DateTime.now();

    // 根据金额确定冷静期时长
    Duration duration;
    if (customDuration != null) {
      duration = customDuration;
    } else if (amount >= _config.largeAmountThreshold) {
      duration = _config.largeAmountDuration;
    } else {
      duration = _config.defaultDuration;
    }

    final item = CoolingOffItem(
      id: '${now.millisecondsSinceEpoch}',
      itemName: itemName,
      amount: amount,
      categoryId: categoryId,
      description: description,
      createdAt: now,
      expiresAt: now.add(duration),
      status: CoolingOffStatus.waiting,
    );

    await _db.rawInsert('''
      INSERT INTO cooling_off_items
      (id, itemName, amount, categoryId, description, createdAt, expiresAt, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      item.id,
      item.itemName,
      item.amount,
      item.categoryId,
      item.description,
      item.createdAt.millisecondsSinceEpoch,
      item.expiresAt.millisecondsSinceEpoch,
      item.status.index,
    ]);

    return item;
  }

  /// 取消冷静期项目（决定不买了）
  Future<void> cancelItem(String itemId, {String? reason}) async {
    await _db.rawUpdate('''
      UPDATE cooling_off_items
      SET status = ?, cancelReason = ?, completedAt = ?
      WHERE id = ?
    ''', [
      CoolingOffStatus.cancelled.index,
      reason,
      DateTime.now().millisecondsSinceEpoch,
      itemId,
    ]);
  }

  /// 执行购买（冷静期结束后决定购买）
  Future<void> executeItem(String itemId) async {
    await _db.rawUpdate('''
      UPDATE cooling_off_items
      SET status = ?, completedAt = ?
      WHERE id = ?
    ''', [
      CoolingOffStatus.executed.index,
      DateTime.now().millisecondsSinceEpoch,
      itemId,
    ]);
  }

  /// 延长冷静期
  Future<void> extendCoolingPeriod(String itemId, Duration extension) async {
    final item = await getItem(itemId);
    if (item == null || !item.status.isActive) return;

    final newExpiry = item.expiresAt.add(extension);

    await _db.rawUpdate('''
      UPDATE cooling_off_items SET expiresAt = ? WHERE id = ?
    ''', [newExpiry.millisecondsSinceEpoch, itemId]);
  }

  /// 获取单个项目
  Future<CoolingOffItem?> getItem(String itemId) async {
    final results = await _db.rawQuery('''
      SELECT * FROM cooling_off_items WHERE id = ?
    ''', [itemId]);

    if (results.isEmpty) return null;
    return CoolingOffItem.fromMap(results.first);
  }

  /// 获取所有活跃的冷静期项目
  Future<List<CoolingOffItem>> getActiveItems() async {
    final results = await _db.rawQuery('''
      SELECT * FROM cooling_off_items
      WHERE status = ?
      ORDER BY expiresAt ASC
    ''', [CoolingOffStatus.waiting.index]);

    return results.map((m) => CoolingOffItem.fromMap(m)).toList();
  }

  /// 获取历史记录
  Future<List<CoolingOffItem>> getHistory({
    int limit = 50,
    CoolingOffStatus? status,
  }) async {
    String query = '''
      SELECT * FROM cooling_off_items
      WHERE status != ?
    ''';
    final params = <dynamic>[CoolingOffStatus.waiting.index];

    if (status != null) {
      query += ' AND status = ?';
      params.add(status.index);
    }

    query += ' ORDER BY completedAt DESC LIMIT ?';
    params.add(limit);

    final results = await _db.rawQuery(query, params);
    return results.map((m) => CoolingOffItem.fromMap(m)).toList();
  }

  /// 获取统计数据
  Future<CoolingOffStats> getStats({int days = 30}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    // 总数
    final totalResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM cooling_off_items WHERE createdAt >= ?
    ''', [since]);
    final total = (totalResult.first['count'] as int?) ?? 0;

    // 取消数
    final cancelledResult = await _db.rawQuery('''
      SELECT COUNT(*) as count, SUM(amount) as total
      FROM cooling_off_items
      WHERE status = ? AND createdAt >= ?
    ''', [CoolingOffStatus.cancelled.index, since]);
    final cancelled = (cancelledResult.first['count'] as int?) ?? 0;
    final savedAmount = (cancelledResult.first['total'] as num?)?.toDouble() ?? 0;

    // 执行数
    final executedResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM cooling_off_items
      WHERE status = ? AND createdAt >= ?
    ''', [CoolingOffStatus.executed.index, since]);
    final executed = (executedResult.first['count'] as int?) ?? 0;

    // 过期数
    final expiredResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM cooling_off_items
      WHERE status = ? AND createdAt >= ?
    ''', [CoolingOffStatus.expired.index, since]);
    final expired = (expiredResult.first['count'] as int?) ?? 0;

    return CoolingOffStats(
      totalItems: total,
      cancelledCount: cancelled,
      executedCount: executed,
      expiredCount: expired,
      totalSaved: savedAmount,
      cancelRate: total > 0 ? cancelled / total : 0,
    );
  }

  /// 检查并更新过期项目
  Future<void> checkExpiredItems() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 获取已过期但状态仍为waiting的项目
    final expiredItems = await _db.rawQuery('''
      SELECT * FROM cooling_off_items
      WHERE status = ? AND expiresAt < ?
    ''', [CoolingOffStatus.waiting.index, now]);

    for (final map in expiredItems) {
      final item = CoolingOffItem.fromMap(map);

      // 更新状态为已完成（等待用户决定）
      await _db.rawUpdate('''
        UPDATE cooling_off_items SET status = ? WHERE id = ?
      ''', [CoolingOffStatus.completed.index, item.id]);

      // 触发回调
      for (final callback in _expiryCallbacks) {
        callback(item.copyWith(status: CoolingOffStatus.completed));
      }
    }
  }

  /// 检查即将到期的项目（用于提醒）
  Future<List<CoolingOffItem>> getUpcomingExpirations() async {
    if (!_config.enableExpiryReminder) return [];

    final now = DateTime.now();
    final deadline = now.add(_config.reminderBefore);

    final results = await _db.rawQuery('''
      SELECT * FROM cooling_off_items
      WHERE status = ? AND expiresAt > ? AND expiresAt <= ?
    ''', [
      CoolingOffStatus.waiting.index,
      now.millisecondsSinceEpoch,
      deadline.millisecondsSinceEpoch,
    ]);

    return results.map((m) => CoolingOffItem.fromMap(m)).toList();
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => checkExpiredItems(),
    );
  }

  /// 释放资源
  void dispose() {
    _checkTimer?.cancel();
    _expiryCallbacks.clear();
  }
}
