import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'budget_provider.dart';

/// 预算提醒类型
enum BudgetAlertType {
  warning,   // 接近预算上限 (80%)
  danger,    // 超出预算
  safe,      // 正常
}

/// 预算提醒信息
class BudgetAlert {
  final String budgetId;
  final String budgetName;
  final BudgetAlertType type;
  final double percentage;
  final double spent;
  final double limit;
  final String? categoryId;
  final DateTime timestamp;
  final bool isRead;

  BudgetAlert({
    required this.budgetId,
    required this.budgetName,
    required this.type,
    required this.percentage,
    required this.spent,
    required this.limit,
    this.categoryId,
    DateTime? timestamp,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();

  BudgetAlert copyWith({bool? isRead}) {
    return BudgetAlert(
      budgetId: budgetId,
      budgetName: budgetName,
      type: type,
      percentage: percentage,
      spent: spent,
      limit: limit,
      categoryId: categoryId,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  String get message {
    switch (type) {
      case BudgetAlertType.danger:
        return '$budgetName 已超支 ¥${(spent - limit).toStringAsFixed(2)}';
      case BudgetAlertType.warning:
        return '$budgetName 已使用 ${(percentage * 100).toInt()}%';
      case BudgetAlertType.safe:
        return '$budgetName 使用正常';
    }
  }

  String get shortMessage {
    switch (type) {
      case BudgetAlertType.danger:
        return '已超支';
      case BudgetAlertType.warning:
        return '接近上限';
      case BudgetAlertType.safe:
        return '正常';
    }
  }
}

/// 预算提醒状态
class BudgetAlertState {
  final List<BudgetAlert> alerts;
  final int unreadCount;
  final bool showAlerts;

  BudgetAlertState({
    this.alerts = const [],
    this.unreadCount = 0,
    this.showAlerts = true,
  });

  BudgetAlertState copyWith({
    List<BudgetAlert>? alerts,
    int? unreadCount,
    bool? showAlerts,
  }) {
    return BudgetAlertState(
      alerts: alerts ?? this.alerts,
      unreadCount: unreadCount ?? this.unreadCount,
      showAlerts: showAlerts ?? this.showAlerts,
    );
  }

  /// 获取危险级别的提醒
  List<BudgetAlert> get dangerAlerts =>
      alerts.where((a) => a.type == BudgetAlertType.danger).toList();

  /// 获取警告级别的提醒
  List<BudgetAlert> get warningAlerts =>
      alerts.where((a) => a.type == BudgetAlertType.warning).toList();

  /// 是否有需要关注的提醒
  bool get hasImportantAlerts =>
      alerts.any((a) => a.type != BudgetAlertType.safe);
}

/// 预算提醒通知器
class BudgetAlertNotifier extends Notifier<BudgetAlertState> {
  @override
  BudgetAlertState build() {
    // 监听预算使用情况变化
    ref.listen(allBudgetUsagesProvider, (previous, next) {
      _updateAlerts(next);
    });
    return BudgetAlertState();
  }

  void _updateAlerts(List<BudgetUsage> usages) {
    final alerts = <BudgetAlert>[];

    for (final usage in usages) {
      BudgetAlertType type;
      if (usage.isOverBudget) {
        type = BudgetAlertType.danger;
      } else if (usage.isNearLimit) {
        type = BudgetAlertType.warning;
      } else {
        type = BudgetAlertType.safe;
      }

      // 只添加需要提醒的预算
      if (type != BudgetAlertType.safe) {
        // 检查是否已存在相同提醒
        final existingAlert = state.alerts.where((a) => a.budgetId == usage.budget.id).firstOrNull;

        alerts.add(BudgetAlert(
          budgetId: usage.budget.id,
          budgetName: usage.budget.name,
          type: type,
          percentage: usage.percentage,
          spent: usage.spent,
          limit: usage.budget.amount,
          categoryId: usage.budget.categoryId,
          isRead: existingAlert?.isRead ?? false,
        ));
      }
    }

    // 按严重程度排序
    alerts.sort((a, b) {
      if (a.type == BudgetAlertType.danger && b.type != BudgetAlertType.danger) {
        return -1;
      }
      if (a.type != BudgetAlertType.danger && b.type == BudgetAlertType.danger) {
        return 1;
      }
      return b.percentage.compareTo(a.percentage);
    });

    final unreadCount = alerts.where((a) => !a.isRead).length;

    state = state.copyWith(
      alerts: alerts,
      unreadCount: unreadCount,
    );
  }

  /// 标记提醒为已读
  void markAsRead(String budgetId) {
    final alerts = state.alerts.map((a) {
      if (a.budgetId == budgetId) {
        return a.copyWith(isRead: true);
      }
      return a;
    }).toList();

    final unreadCount = alerts.where((a) => !a.isRead).length;

    state = state.copyWith(
      alerts: alerts,
      unreadCount: unreadCount,
    );
  }

  /// 标记所有提醒为已读
  void markAllAsRead() {
    final alerts = state.alerts.map((a) => a.copyWith(isRead: true)).toList();

    state = state.copyWith(
      alerts: alerts,
      unreadCount: 0,
    );
  }

  /// 切换提醒显示状态
  void toggleShowAlerts() {
    state = state.copyWith(showAlerts: !state.showAlerts);
  }
}

/// 预算提醒Provider
final budgetAlertProvider =
    NotifierProvider<BudgetAlertNotifier, BudgetAlertState>(
        BudgetAlertNotifier.new);

/// 未读提醒数量Provider
final unreadBudgetAlertCountProvider = Provider<int>((ref) {
  return ref.watch(budgetAlertProvider).unreadCount;
});

/// 是否有重要提醒Provider
final hasImportantBudgetAlertsProvider = Provider<bool>((ref) {
  return ref.watch(budgetAlertProvider).hasImportantAlerts;
});
