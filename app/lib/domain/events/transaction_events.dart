/// Transaction Events
///
/// 交易相关的领域事件。
library;

import 'domain_event.dart';

/// 交易创建事件
class TransactionCreatedEvent extends DomainEvent {
  /// 交易 ID
  final String transactionId;

  /// 金额
  final double amount;

  /// 分类
  final String category;

  /// 交易类型 (expense/income)
  final String type;

  /// 账户 ID
  final String? accountId;

  /// 账本 ID
  final String? ledgerId;

  /// 备注
  final String? note;

  /// 商户
  final String? merchant;

  /// 交易日期
  final DateTime? transactionDate;

  TransactionCreatedEvent({
    required this.transactionId,
    required this.amount,
    required this.category,
    required this.type,
    this.accountId,
    this.ledgerId,
    this.note,
    this.merchant,
    this.transactionDate,
    super.metadata,
  }) : super(
          aggregateId: transactionId,
          aggregateType: 'Transaction',
        );

  @override
  String get eventName => 'TransactionCreated';

  @override
  Map<String, dynamic> get eventData => {
        'transactionId': transactionId,
        'amount': amount,
        'category': category,
        'type': type,
        'accountId': accountId,
        'ledgerId': ledgerId,
        'note': note,
        'merchant': merchant,
        'transactionDate': transactionDate?.toIso8601String(),
      };
}

/// 交易更新事件
class TransactionUpdatedEvent extends DomainEvent {
  /// 交易 ID
  final String transactionId;

  /// 更新的字段
  final Map<String, dynamic> changes;

  /// 原始数据
  final Map<String, dynamic>? originalData;

  TransactionUpdatedEvent({
    required this.transactionId,
    required this.changes,
    this.originalData,
    super.metadata,
  }) : super(
          aggregateId: transactionId,
          aggregateType: 'Transaction',
        );

  @override
  String get eventName => 'TransactionUpdated';

  @override
  Map<String, dynamic> get eventData => {
        'transactionId': transactionId,
        'changes': changes,
        'originalData': originalData,
      };

  /// 金额是否变化
  bool get amountChanged => changes.containsKey('amount');

  /// 分类是否变化
  bool get categoryChanged => changes.containsKey('category');
}

/// 交易删除事件
class TransactionDeletedEvent extends DomainEvent {
  /// 交易 ID
  final String transactionId;

  /// 是否软删除
  final bool softDelete;

  /// 删除前的数据
  final Map<String, dynamic>? deletedData;

  TransactionDeletedEvent({
    required this.transactionId,
    this.softDelete = true,
    this.deletedData,
    super.metadata,
  }) : super(
          aggregateId: transactionId,
          aggregateType: 'Transaction',
        );

  @override
  String get eventName => 'TransactionDeleted';

  @override
  Map<String, dynamic> get eventData => {
        'transactionId': transactionId,
        'softDelete': softDelete,
        'deletedData': deletedData,
      };
}

/// 交易恢复事件
class TransactionRestoredEvent extends DomainEvent {
  /// 交易 ID
  final String transactionId;

  TransactionRestoredEvent({
    required this.transactionId,
    super.metadata,
  }) : super(
          aggregateId: transactionId,
          aggregateType: 'Transaction',
        );

  @override
  String get eventName => 'TransactionRestored';

  @override
  Map<String, dynamic> get eventData => {
        'transactionId': transactionId,
      };
}

/// 批量交易导入事件
class TransactionsBatchImportedEvent extends DomainEvent {
  /// 导入批次 ID
  final String batchId;

  /// 导入数量
  final int count;

  /// 导入来源
  final String source;

  /// 导入的交易 ID 列表
  final List<String> transactionIds;

  TransactionsBatchImportedEvent({
    required this.batchId,
    required this.count,
    required this.source,
    required this.transactionIds,
    super.metadata,
  }) : super(
          aggregateId: batchId,
          aggregateType: 'ImportBatch',
        );

  @override
  String get eventName => 'TransactionsBatchImported';

  @override
  Map<String, dynamic> get eventData => {
        'batchId': batchId,
        'count': count,
        'source': source,
        'transactionIds': transactionIds,
      };
}
