/// Event Handlers
///
/// 事件处理器实现。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/events/domain_event.dart';
import '../../services/category_localization_service.dart';
import '../../domain/events/transaction_events.dart';
import '../../domain/events/budget_events.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// 预算警报处理器
///
/// 职责：
/// - 监听交易创建/更新事件
/// - 检查预算使用情况
/// - 触发预算警告或超支事件
class BudgetAlertHandler implements IEventSubscriber {
  /// 预算仓储
  final IBudgetRepository budgetRepository;

  /// 事件发布回调
  final Future<void> Function(DomainEvent event)? onEventPublish;

  /// 预警阈值（默认 80%）
  final double warningThreshold;

  BudgetAlertHandler({
    required this.budgetRepository,
    this.onEventPublish,
    this.warningThreshold = 0.8,
  });

  @override
  List<Type> get subscribedEvents => [
        TransactionCreatedEvent,
        TransactionUpdatedEvent,
        TransactionDeletedEvent,
      ];

  @override
  Future<void> onEvent(DomainEvent event) async {
    if (event is TransactionCreatedEvent) {
      await _handleTransactionCreated(event);
    } else if (event is TransactionUpdatedEvent) {
      await _handleTransactionUpdated(event);
    } else if (event is TransactionDeletedEvent) {
      await _handleTransactionDeleted(event);
    }
  }

  Future<void> _handleTransactionCreated(TransactionCreatedEvent event) async {
    // 只处理支出
    if (event.type != 'expense') return;

    await _checkBudgetForCategory(event.category, event.amount);
  }

  Future<void> _handleTransactionUpdated(TransactionUpdatedEvent event) async {
    if (!event.amountChanged && !event.categoryChanged) return;

    // 如果分类或金额变化，需要重新检查预算
    final category = event.changes['category'] as String? ??
        event.originalData?['category'] as String?;
    if (category == null) return;

    await _checkBudgetForCategory(category, null);
  }

  Future<void> _handleTransactionDeleted(TransactionDeletedEvent event) async {
    // 删除交易可能会释放预算空间，不需要特殊处理
    debugPrint('[BudgetAlertHandler] 交易已删除: ${event.transactionId}');
  }

  Future<void> _checkBudgetForCategory(String category, double? newAmount) async {
    try {
      // 查找该分类的活跃预算
      final budgets = await budgetRepository.findActive();

      for (final budget in budgets) {
        // 检查是否是该分类的预算
        final budgetCategory = _getBudgetCategory(budget);
        if (budgetCategory != null && budgetCategory != category) continue;

        final budgetAmount = _getBudgetAmount(budget);
        final usedAmount = _getBudgetUsed(budget);

        if (budgetAmount <= 0) continue;

        final usagePercent = usedAmount / budgetAmount;

        // 检查是否超支
        if (usagePercent >= 1.0) {
          await _publishEvent(BudgetExceededEvent(
            budgetId: _getBudgetId(budget),
            budgetName: _getBudgetName(budget),
            category: budgetCategory,
            budgetAmount: budgetAmount,
            usedAmount: usedAmount,
          ));
        }
        // 检查是否达到预警阈值
        else if (usagePercent >= warningThreshold) {
          await _publishEvent(BudgetWarningEvent(
            budgetId: _getBudgetId(budget),
            budgetName: _getBudgetName(budget),
            category: budgetCategory,
            budgetAmount: budgetAmount,
            usedAmount: usedAmount,
            warningThreshold: warningThreshold * 100,
          ));
        }
      }
    } catch (e) {
      debugPrint('[BudgetAlertHandler] 检查预算失败: $e');
    }
  }

  Future<void> _publishEvent(DomainEvent event) async {
    if (onEventPublish != null) {
      await onEventPublish!(event);
    }
  }

  // 辅助方法：从动态对象提取属性
  String _getBudgetId(dynamic budget) {
    if (budget is Map) return budget['id']?.toString() ?? '';
    try {
      return budget.id?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String? _getBudgetName(dynamic budget) {
    if (budget is Map) return budget['name'] as String?;
    try {
      return budget.name as String?;
    } catch (_) {
      return null;
    }
  }

  String? _getBudgetCategory(dynamic budget) {
    if (budget is Map) return budget['category'] as String?;
    try {
      return budget.category as String?;
    } catch (_) {
      return null;
    }
  }

  double _getBudgetAmount(dynamic budget) {
    if (budget is Map) return (budget['amount'] as num?)?.toDouble() ?? 0;
    try {
      return (budget.amount as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  double _getBudgetUsed(dynamic budget) {
    if (budget is Map) return (budget['usedAmount'] as num?)?.toDouble() ?? 0;
    try {
      return (budget.usedAmount as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

/// 统计更新处理器
///
/// 职责：
/// - 监听交易事件
/// - 更新统计缓存
/// - 触发统计更新通知
class StatisticsUpdateHandler implements IEventSubscriber {
  /// 统计缓存更新回调
  final Future<void> Function(String period)? onStatisticsUpdate;

  StatisticsUpdateHandler({
    this.onStatisticsUpdate,
  });

  @override
  List<Type> get subscribedEvents => [
        TransactionCreatedEvent,
        TransactionUpdatedEvent,
        TransactionDeletedEvent,
        TransactionRestoredEvent,
      ];

  @override
  Future<void> onEvent(DomainEvent event) async {
    // 确定需要更新的统计周期
    final periods = _getAffectedPeriods(event);

    for (final period in periods) {
      debugPrint('[StatisticsUpdateHandler] 更新统计: $period');
      await onStatisticsUpdate?.call(period);
    }
  }

  List<String> _getAffectedPeriods(DomainEvent event) {
    final now = DateTime.now();
    return [
      'today',
      'week',
      'month_${now.year}_${now.month}',
      'year_${now.year}',
    ];
  }
}

/// 学习更新处理器
///
/// 职责：
/// - 监听交易事件
/// - 更新意图识别学习缓存
/// - 提取模式用于未来识别
class LearningUpdateHandler implements IEventSubscriber {
  /// 学习缓存更新回调
  final Future<void> Function(String input, Map<String, dynamic> result)?
      onLearnPattern;

  LearningUpdateHandler({
    this.onLearnPattern,
  });

  @override
  List<Type> get subscribedEvents => [
        TransactionCreatedEvent,
      ];

  @override
  Future<void> onEvent(DomainEvent event) async {
    if (event is TransactionCreatedEvent) {
      await _handleTransactionCreated(event);
    }
  }

  Future<void> _handleTransactionCreated(TransactionCreatedEvent event) async {
    // 如果有原始输入，可以用于学习
    final originalInput = event.metadata['originalInput'] as String?;
    if (originalInput == null || originalInput.isEmpty) return;

    final result = {
      'category': event.category,
      'type': event.type,
      'merchant': event.merchant,
    };

    debugPrint('[LearningUpdateHandler] 学习模式: $originalInput -> $result');
    await onLearnPattern?.call(originalInput, result);
  }
}

/// 账户余额同步处理器
///
/// 职责：
/// - 监听交易事件
/// - 同步账户余额
class AccountBalanceSyncHandler implements IEventSubscriber {
  /// 余额更新回调
  final Future<void> Function(String accountId, double change)?
      onBalanceUpdate;

  AccountBalanceSyncHandler({
    this.onBalanceUpdate,
  });

  @override
  List<Type> get subscribedEvents => [
        TransactionCreatedEvent,
        TransactionUpdatedEvent,
        TransactionDeletedEvent,
        TransactionRestoredEvent,
      ];

  @override
  Future<void> onEvent(DomainEvent event) async {
    if (event is TransactionCreatedEvent) {
      await _handleCreated(event);
    } else if (event is TransactionUpdatedEvent) {
      await _handleUpdated(event);
    } else if (event is TransactionDeletedEvent) {
      await _handleDeleted(event);
    } else if (event is TransactionRestoredEvent) {
      // 恢复时需要重新计算余额
      debugPrint('[AccountBalanceSyncHandler] 交易已恢复: ${event.transactionId}');
    }
  }

  Future<void> _handleCreated(TransactionCreatedEvent event) async {
    if (event.accountId == null) return;

    final change = event.type == 'expense' ? -event.amount : event.amount;
    await onBalanceUpdate?.call(event.accountId!, change);
    debugPrint('[AccountBalanceSyncHandler] 余额变化: ${event.accountId} $change');
  }

  Future<void> _handleUpdated(TransactionUpdatedEvent event) async {
    if (!event.amountChanged) return;

    final originalData = event.originalData;
    if (originalData == null) return;

    final accountId = originalData['accountId'] as String?;
    if (accountId == null) return;

    final oldAmount = (originalData['amount'] as num?)?.toDouble() ?? 0;
    final newAmount = (event.changes['amount'] as num?)?.toDouble() ?? oldAmount;
    final type = originalData['type'] as String? ?? 'expense';

    final diff = newAmount - oldAmount;
    final change = type == 'expense' ? -diff : diff;

    await onBalanceUpdate?.call(accountId, change);
    debugPrint('[AccountBalanceSyncHandler] 余额调整: $accountId $change');
  }

  Future<void> _handleDeleted(TransactionDeletedEvent event) async {
    final deletedData = event.deletedData;
    if (deletedData == null) return;

    final accountId = deletedData['accountId'] as String?;
    if (accountId == null) return;

    final amount = (deletedData['amount'] as num?)?.toDouble() ?? 0;
    final type = deletedData['type'] as String? ?? 'expense';

    // 删除时反向操作
    final change = type == 'expense' ? amount : -amount;

    await onBalanceUpdate?.call(accountId, change);
    debugPrint('[AccountBalanceSyncHandler] 删除回退: $accountId $change');
  }
}

/// 通知处理器
///
/// 职责：
/// - 监听重要事件
/// - 发送用户通知
class NotificationHandler implements IEventSubscriber {
  /// 通知回调
  final Future<void> Function(String title, String message)? onNotify;

  NotificationHandler({
    this.onNotify,
  });

  @override
  List<Type> get subscribedEvents => [
        BudgetExceededEvent,
        BudgetWarningEvent,
      ];

  @override
  Future<void> onEvent(DomainEvent event) async {
    if (event is BudgetExceededEvent) {
      await _handleBudgetExceeded(event);
    } else if (event is BudgetWarningEvent) {
      await _handleBudgetWarning(event);
    }
  }

  Future<void> _handleBudgetExceeded(BudgetExceededEvent event) async {
    final title = '预算超支提醒';
    final message =
        '${event.budgetName ?? (event.category != null ? event.category!.localizedCategoryName : "总预算")}已超支${event.exceededAmount.toStringAsFixed(2)}元';

    await onNotify?.call(title, message);
    debugPrint('[NotificationHandler] $title: $message');
  }

  Future<void> _handleBudgetWarning(BudgetWarningEvent event) async {
    final title = '预算预警';
    final message =
        '${event.budgetName ?? (event.category != null ? event.category!.localizedCategoryName : "总预算")}已使用${event.usagePercent.toStringAsFixed(1)}%';

    await onNotify?.call(title, message);
    debugPrint('[NotificationHandler] $title: $message');
  }
}
