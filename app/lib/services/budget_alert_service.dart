import 'dart:async';

import 'package:flutter/material.dart';

import '../models/budget_vault.dart';
import 'vault_repository.dart';
import 'budget_carryover_service.dart';

/// 预警级别
enum AlertLevel {
  /// 信息（使用率 50-70%）
  info,

  /// 警告（使用率 70-90%）
  warning,

  /// 严重（使用率 90-100%）
  critical,

  /// 超支（使用率 >100%）
  overspent,
}

extension AlertLevelExtension on AlertLevel {
  String get displayName {
    switch (this) {
      case AlertLevel.info:
        return '提醒';
      case AlertLevel.warning:
        return '警告';
      case AlertLevel.critical:
        return '紧急';
      case AlertLevel.overspent:
        return '超支';
    }
  }

  Color get color {
    switch (this) {
      case AlertLevel.info:
        return Colors.blue;
      case AlertLevel.warning:
        return Colors.orange;
      case AlertLevel.critical:
        return Colors.deepOrange;
      case AlertLevel.overspent:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case AlertLevel.info:
        return Icons.info_outline;
      case AlertLevel.warning:
        return Icons.warning_amber;
      case AlertLevel.critical:
        return Icons.error_outline;
      case AlertLevel.overspent:
        return Icons.dangerous;
    }
  }

  int get priority {
    switch (this) {
      case AlertLevel.info:
        return 1;
      case AlertLevel.warning:
        return 2;
      case AlertLevel.critical:
        return 3;
      case AlertLevel.overspent:
        return 4;
    }
  }
}

/// 预警类型
enum AlertType {
  /// 预算即将用完
  lowBalance,

  /// 预算已超支
  overspent,

  /// 消费速度过快
  fastSpending,

  /// 即将到期
  dueSoon,

  /// 已过期
  overdue,

  /// 月末预算紧张
  monthEndTight,

  /// 储蓄目标进度落后
  savingsLagging,
}

extension AlertTypeExtension on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.lowBalance:
        return '余额不足';
      case AlertType.overspent:
        return '预算超支';
      case AlertType.fastSpending:
        return '消费过快';
      case AlertType.dueSoon:
        return '即将到期';
      case AlertType.overdue:
        return '已过期';
      case AlertType.monthEndTight:
        return '月末紧张';
      case AlertType.savingsLagging:
        return '储蓄落后';
    }
  }
}

/// 预算预警
class BudgetAlert {
  final String id;
  final String vaultId;
  final String vaultName;
  final AlertLevel level;
  final AlertType type;
  final String title;
  final String message;
  final String? suggestion;
  final DateTime createdAt;
  final bool isRead;
  final bool isDismissed;

  const BudgetAlert({
    required this.id,
    required this.vaultId,
    required this.vaultName,
    required this.level,
    required this.type,
    required this.title,
    required this.message,
    this.suggestion,
    required this.createdAt,
    this.isRead = false,
    this.isDismissed = false,
  });

  BudgetAlert copyWith({
    bool? isRead,
    bool? isDismissed,
  }) {
    return BudgetAlert(
      id: id,
      vaultId: vaultId,
      vaultName: vaultName,
      level: level,
      type: type,
      title: title,
      message: message,
      suggestion: suggestion,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vaultId': vaultId,
      'vaultName': vaultName,
      'level': level.index,
      'type': type.index,
      'title': title,
      'message': message,
      'suggestion': suggestion,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isRead': isRead ? 1 : 0,
      'isDismissed': isDismissed ? 1 : 0,
    };
  }

  factory BudgetAlert.fromMap(Map<String, dynamic> map) {
    return BudgetAlert(
      id: map['id'] as String,
      vaultId: map['vaultId'] as String,
      vaultName: map['vaultName'] as String,
      level: AlertLevel.values[map['level'] as int],
      type: AlertType.values[map['type'] as int],
      title: map['title'] as String,
      message: map['message'] as String,
      suggestion: map['suggestion'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      isRead: map['isRead'] == 1,
      isDismissed: map['isDismissed'] == 1,
    );
  }
}

/// 预警配置
class AlertConfig {
  final bool enabled;
  final double lowBalanceThreshold; // 低余额阈值（使用率）
  final double criticalThreshold; // 紧急阈值
  final bool enableFastSpendingAlert; // 是否启用消费过快提醒
  final bool enableDueAlert; // 是否启用到期提醒
  final int dueDaysThreshold; // 到期提前提醒天数
  final bool enableMonthEndAlert; // 是否启用月末提醒
  final bool enableSavingsAlert; // 是否启用储蓄进度提醒
  final bool enableSound; // 是否启用声音
  final bool enableVibration; // 是否启用振动

  const AlertConfig({
    this.enabled = true,
    this.lowBalanceThreshold = 0.8, // 80%
    this.criticalThreshold = 0.9, // 90%
    this.enableFastSpendingAlert = true,
    this.enableDueAlert = true,
    this.dueDaysThreshold = 3,
    this.enableMonthEndAlert = true,
    this.enableSavingsAlert = true,
    this.enableSound = true,
    this.enableVibration = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled ? 1 : 0,
      'lowBalanceThreshold': lowBalanceThreshold,
      'criticalThreshold': criticalThreshold,
      'enableFastSpendingAlert': enableFastSpendingAlert ? 1 : 0,
      'enableDueAlert': enableDueAlert ? 1 : 0,
      'dueDaysThreshold': dueDaysThreshold,
      'enableMonthEndAlert': enableMonthEndAlert ? 1 : 0,
      'enableSavingsAlert': enableSavingsAlert ? 1 : 0,
      'enableSound': enableSound ? 1 : 0,
      'enableVibration': enableVibration ? 1 : 0,
    };
  }

  factory AlertConfig.fromMap(Map<String, dynamic> map) {
    return AlertConfig(
      enabled: map['enabled'] == 1,
      lowBalanceThreshold:
          (map['lowBalanceThreshold'] as num?)?.toDouble() ?? 0.8,
      criticalThreshold: (map['criticalThreshold'] as num?)?.toDouble() ?? 0.9,
      enableFastSpendingAlert: map['enableFastSpendingAlert'] != 0,
      enableDueAlert: map['enableDueAlert'] != 0,
      dueDaysThreshold: map['dueDaysThreshold'] as int? ?? 3,
      enableMonthEndAlert: map['enableMonthEndAlert'] != 0,
      enableSavingsAlert: map['enableSavingsAlert'] != 0,
      enableSound: map['enableSound'] != 0,
      enableVibration: map['enableVibration'] != 0,
    );
  }

  AlertConfig copyWith({
    bool? enabled,
    double? lowBalanceThreshold,
    double? criticalThreshold,
    bool? enableFastSpendingAlert,
    bool? enableDueAlert,
    int? dueDaysThreshold,
    bool? enableMonthEndAlert,
    bool? enableSavingsAlert,
    bool? enableSound,
    bool? enableVibration,
  }) {
    return AlertConfig(
      enabled: enabled ?? this.enabled,
      lowBalanceThreshold: lowBalanceThreshold ?? this.lowBalanceThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
      enableFastSpendingAlert:
          enableFastSpendingAlert ?? this.enableFastSpendingAlert,
      enableDueAlert: enableDueAlert ?? this.enableDueAlert,
      dueDaysThreshold: dueDaysThreshold ?? this.dueDaysThreshold,
      enableMonthEndAlert: enableMonthEndAlert ?? this.enableMonthEndAlert,
      enableSavingsAlert: enableSavingsAlert ?? this.enableSavingsAlert,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
    );
  }
}

/// 预算预警服务
///
/// 实时监控预算状态并发送预警通知
class BudgetAlertService {
  final VaultRepository _vaultRepository;
  final BudgetCarryoverService _carryoverService;

  AlertConfig _config = const AlertConfig();
  final List<BudgetAlert> _alerts = [];
  final _alertController = StreamController<List<BudgetAlert>>.broadcast();

  BudgetAlertService(this._vaultRepository, this._carryoverService);

  /// 预警流
  Stream<List<BudgetAlert>> get alertStream => _alertController.stream;

  /// 当前预警列表
  List<BudgetAlert> get alerts =>
      _alerts.where((a) => !a.isDismissed).toList();

  /// 未读预警数量
  int get unreadCount => alerts.where((a) => !a.isRead).length;

  /// 设置配置
  void setConfig(AlertConfig config) {
    _config = config;
  }

  /// 获取当前配置
  AlertConfig get config => _config;

  /// 检查单个小金库的预算状态
  List<BudgetAlert> checkVault(BudgetVault vault) {
    if (!_config.enabled || !vault.isEnabled) return [];

    final alerts = <BudgetAlert>[];
    final now = DateTime.now();

    // 1. 检查超支
    if (vault.isOverSpent) {
      alerts.add(_createAlert(
        vault: vault,
        level: AlertLevel.overspent,
        type: AlertType.overspent,
        title: '${vault.name}已超支',
        message:
            '已超支 ¥${vault.overspentAmount.toStringAsFixed(2)}，请及时调整预算或控制消费',
        suggestion: '建议从其他小金库调拨资金，或增加本月收入分配',
      ));
    }
    // 2. 检查使用率
    else if (vault.usageRate >= _config.criticalThreshold) {
      alerts.add(_createAlert(
        vault: vault,
        level: AlertLevel.critical,
        type: AlertType.lowBalance,
        title: '${vault.name}即将用完',
        message:
            '已使用 ${(vault.usageRate * 100).toStringAsFixed(0)}%，仅剩 ¥${vault.available.toStringAsFixed(2)}',
        suggestion: '建议控制接下来的消费，或考虑从其他小金库调拨',
      ));
    } else if (vault.usageRate >= _config.lowBalanceThreshold) {
      alerts.add(_createAlert(
        vault: vault,
        level: AlertLevel.warning,
        type: AlertType.lowBalance,
        title: '${vault.name}余额不足',
        message:
            '已使用 ${(vault.usageRate * 100).toStringAsFixed(0)}%，剩余 ¥${vault.available.toStringAsFixed(2)}',
        suggestion: '建议关注后续消费，避免超支',
      ));
    }

    // 3. 检查到期日
    if (_config.enableDueAlert && vault.dueDate != null) {
      final daysUntilDue = vault.daysUntilDue;
      if (daysUntilDue != null) {
        if (daysUntilDue < 0) {
          alerts.add(_createAlert(
            vault: vault,
            level: AlertLevel.critical,
            type: AlertType.overdue,
            title: '${vault.name}已过期',
            message: '已过期 ${-daysUntilDue} 天，请尽快处理',
          ));
        } else if (daysUntilDue <= _config.dueDaysThreshold) {
          alerts.add(_createAlert(
            vault: vault,
            level: AlertLevel.warning,
            type: AlertType.dueSoon,
            title: '${vault.name}即将到期',
            message: '还有 $daysUntilDue 天到期，请确保资金充足',
          ));
        }
      }
    }

    // 4. 检查储蓄进度
    if (_config.enableSavingsAlert && vault.type == VaultType.savings) {
      final period = _carryoverService.getCurrentPeriod();
      final expectedProgress = period.progress;
      final actualProgress = vault.progress;

      if (actualProgress < expectedProgress * 0.8) {
        // 进度落后20%以上
        alerts.add(_createAlert(
          vault: vault,
          level: AlertLevel.info,
          type: AlertType.savingsLagging,
          title: '${vault.name}储蓄进度落后',
          message:
              '当前进度 ${(actualProgress * 100).toStringAsFixed(0)}%，建议进度 ${(expectedProgress * 100).toStringAsFixed(0)}%',
          suggestion: '建议增加本月储蓄分配',
        ));
      }
    }

    return alerts;
  }

  /// 检查所有小金库并生成预警
  Future<List<BudgetAlert>> checkAllVaults({String? ledgerId}) async {
    final vaults = ledgerId != null
        ? await _vaultRepository.getByLedgerId(ledgerId)
        : await _vaultRepository.getAll();

    final newAlerts = <BudgetAlert>[];

    for (final vault in vaults) {
      newAlerts.addAll(checkVault(vault));
    }

    // 检查月末预算紧张
    if (_config.enableMonthEndAlert) {
      final monthEndAlerts = await _checkMonthEndBudget(ledgerId: ledgerId);
      newAlerts.addAll(monthEndAlerts);
    }

    // 更新预警列表（去重）
    _updateAlerts(newAlerts);

    return alerts;
  }

  /// 检查月末预算状态
  Future<List<BudgetAlert>> _checkMonthEndBudget({String? ledgerId}) async {
    final alerts = <BudgetAlert>[];
    final remainingDays = _carryoverService.getRemainingDays();

    if (remainingDays > 5) return alerts; // 离月末还早

    final summary = await _vaultRepository.getSummary(ledgerId: ledgerId);
    final dailyBudget =
        await _carryoverService.getDailyBudget(ledgerId: ledgerId ?? '');

    // 如果日均可用金额低于平均水平的50%
    final avgDailySpending = summary.totalSpent /
        (_carryoverService.getCurrentPeriod().elapsedDays + 1);

    if (dailyBudget < avgDailySpending * 0.5) {
      alerts.add(BudgetAlert(
        id: 'month_end_${DateTime.now().millisecondsSinceEpoch}',
        vaultId: '',
        vaultName: '整体预算',
        level: AlertLevel.warning,
        type: AlertType.monthEndTight,
        title: '月末预算紧张',
        message:
            '剩余 $remainingDays 天，日均可用 ¥${dailyBudget.toStringAsFixed(2)}，低于平均消费水平',
        suggestion: '建议控制消费，或从储蓄调拨资金',
        createdAt: DateTime.now(),
      ));
    }

    return alerts;
  }

  /// 检查消费速度
  Future<BudgetAlert?> checkSpendingSpeed(
    BudgetVault vault, {
    required double newExpenseAmount,
    required List<double> recentExpenses,
  }) async {
    if (!_config.enableFastSpendingAlert) return null;

    // 计算平均消费
    if (recentExpenses.isEmpty) return null;
    final avgExpense =
        recentExpenses.reduce((a, b) => a + b) / recentExpenses.length;

    // 如果本次消费超过平均值的2倍
    if (newExpenseAmount > avgExpense * 2 && newExpenseAmount > 100) {
      return _createAlert(
        vault: vault,
        level: AlertLevel.info,
        type: AlertType.fastSpending,
        title: '${vault.name}消费较大',
        message:
            '本次消费 ¥${newExpenseAmount.toStringAsFixed(2)} 高于平均水平 ¥${avgExpense.toStringAsFixed(2)}',
        suggestion: '确认是否为必要消费',
      );
    }

    return null;
  }

  /// 创建预警
  BudgetAlert _createAlert({
    required BudgetVault vault,
    required AlertLevel level,
    required AlertType type,
    required String title,
    required String message,
    String? suggestion,
  }) {
    return BudgetAlert(
      id: '${vault.id}_${type.index}_${DateTime.now().millisecondsSinceEpoch}',
      vaultId: vault.id,
      vaultName: vault.name,
      level: level,
      type: type,
      title: title,
      message: message,
      suggestion: suggestion,
      createdAt: DateTime.now(),
    );
  }

  /// 更新预警列表
  void _updateAlerts(List<BudgetAlert> newAlerts) {
    // 移除已解决的预警
    _alerts.removeWhere((existing) {
      final stillExists = newAlerts.any((a) =>
          a.vaultId == existing.vaultId && a.type == existing.type);
      return !stillExists && !existing.isDismissed;
    });

    // 添加新预警（避免重复）
    for (final alert in newAlerts) {
      final existingIndex = _alerts.indexWhere(
          (a) => a.vaultId == alert.vaultId && a.type == alert.type);

      if (existingIndex == -1) {
        _alerts.add(alert);
      } else if (!_alerts[existingIndex].isDismissed) {
        // 更新现有预警的信息但保留已读状态
        _alerts[existingIndex] = alert.copyWith(
          isRead: _alerts[existingIndex].isRead,
        );
      }
    }

    // 按优先级排序
    _alerts.sort((a, b) => b.level.priority.compareTo(a.level.priority));

    // 通知监听者
    _alertController.add(alerts);
  }

  /// 标记预警为已读
  void markAsRead(String alertId) {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isRead: true);
      _alertController.add(alerts);
    }
  }

  /// 标记所有预警为已读
  void markAllAsRead() {
    for (var i = 0; i < _alerts.length; i++) {
      _alerts[i] = _alerts[i].copyWith(isRead: true);
    }
    _alertController.add(alerts);
  }

  /// 忽略预警
  void dismiss(String alertId) {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isDismissed: true);
      _alertController.add(alerts);
    }
  }

  /// 清除所有已忽略的预警
  void clearDismissed() {
    _alerts.removeWhere((a) => a.isDismissed);
  }

  /// 获取指定小金库的预警
  List<BudgetAlert> getAlertsForVault(String vaultId) {
    return alerts.where((a) => a.vaultId == vaultId).toList();
  }

  /// 获取指定级别的预警
  List<BudgetAlert> getAlertsByLevel(AlertLevel level) {
    return alerts.where((a) => a.level == level).toList();
  }

  /// 是否有紧急预警
  bool get hasCriticalAlerts =>
      alerts.any((a) => a.level == AlertLevel.critical || a.level == AlertLevel.overspent);

  /// 获取预警摘要
  AlertSummary getSummary() {
    return AlertSummary(
      totalCount: alerts.length,
      unreadCount: unreadCount,
      overspentCount: alerts.where((a) => a.level == AlertLevel.overspent).length,
      criticalCount: alerts.where((a) => a.level == AlertLevel.critical).length,
      warningCount: alerts.where((a) => a.level == AlertLevel.warning).length,
      infoCount: alerts.where((a) => a.level == AlertLevel.info).length,
    );
  }

  /// 释放资源
  void dispose() {
    _alertController.close();
  }
}

/// 预警摘要
class AlertSummary {
  final int totalCount;
  final int unreadCount;
  final int overspentCount;
  final int criticalCount;
  final int warningCount;
  final int infoCount;

  const AlertSummary({
    required this.totalCount,
    required this.unreadCount,
    required this.overspentCount,
    required this.criticalCount,
    required this.warningCount,
    required this.infoCount,
  });

  /// 最高级别
  AlertLevel? get highestLevel {
    if (overspentCount > 0) return AlertLevel.overspent;
    if (criticalCount > 0) return AlertLevel.critical;
    if (warningCount > 0) return AlertLevel.warning;
    if (infoCount > 0) return AlertLevel.info;
    return null;
  }

  /// 是否需要关注
  bool get needsAttention => overspentCount > 0 || criticalCount > 0;
}
