import 'package:flutter/material.dart';

/// AA分摊类型
enum SplitType {
  /// 均摊 - 所有参与者平均分担
  equal,
  /// 精确金额 - 指定每人具体金额
  exact,
  /// 按份额 - 按份数比例分担
  shares,
  /// 按百分比 - 按百分比分担
  percentage,
}

/// 分摊类型扩展
extension SplitTypeExtension on SplitType {
  String get displayName {
    switch (this) {
      case SplitType.equal:
        return '均摊';
      case SplitType.exact:
        return '精确金额';
      case SplitType.shares:
        return '按份额';
      case SplitType.percentage:
        return '按百分比';
    }
  }

  String get description {
    switch (this) {
      case SplitType.equal:
        return '所有参与者平均分担费用';
      case SplitType.exact:
        return '指定每人具体承担的金额';
      case SplitType.shares:
        return '按份数比例分担费用';
      case SplitType.percentage:
        return '按百分比分担费用';
    }
  }

  IconData get icon {
    switch (this) {
      case SplitType.equal:
        return Icons.balance;
      case SplitType.exact:
        return Icons.paid;
      case SplitType.shares:
        return Icons.pie_chart;
      case SplitType.percentage:
        return Icons.percent;
    }
  }
}

/// 分摊状态
enum SplitStatus {
  /// 待处理 - 等待参与者确认
  pending,
  /// 部分结算 - 部分参与者已确认
  partiallySettled,
  /// 已结算 - 所有参与者已确认
  settled,
  /// 已取消 - 分摊已取消
  cancelled,
}

/// 分摊状态扩展
extension SplitStatusExtension on SplitStatus {
  String get displayName {
    switch (this) {
      case SplitStatus.pending:
        return '待处理';
      case SplitStatus.partiallySettled:
        return '部分结算';
      case SplitStatus.settled:
        return '已结算';
      case SplitStatus.cancelled:
        return '已取消';
    }
  }

  Color get color {
    switch (this) {
      case SplitStatus.pending:
        return const Color(0xFFFF9800); // 橙色
      case SplitStatus.partiallySettled:
        return const Color(0xFF2196F3); // 蓝色
      case SplitStatus.settled:
        return const Color(0xFF4CAF50); // 绿色
      case SplitStatus.cancelled:
        return const Color(0xFF9E9E9E); // 灰色
    }
  }

  IconData get icon {
    switch (this) {
      case SplitStatus.pending:
        return Icons.hourglass_empty;
      case SplitStatus.partiallySettled:
        return Icons.pending;
      case SplitStatus.settled:
        return Icons.check_circle;
      case SplitStatus.cancelled:
        return Icons.cancel;
    }
  }
}

/// 分摊参与者
class SplitParticipant {
  /// 成员ID
  final String memberId;
  /// 成员名称
  final String memberName;
  /// 成员头像URL
  final String? avatarUrl;
  /// 应付金额
  final double amount;
  /// 百分比（用于按百分比分摊）
  final double? percentage;
  /// 份额数（用于按份额分摊）
  final int? shares;
  /// 是否为付款人
  final bool isPayer;
  /// 是否已结算
  final bool isSettled;
  /// 结算时间
  final DateTime? settledAt;
  /// 结算备注
  final String? settlementNote;

  const SplitParticipant({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.amount,
    this.percentage,
    this.shares,
    this.isPayer = false,
    this.isSettled = false,
    this.settledAt,
    this.settlementNote,
  });

  /// 待结算金额（非付款人且未结算）
  double get pendingAmount => !isPayer && !isSettled ? amount : 0;

  SplitParticipant copyWith({
    String? memberId,
    String? memberName,
    String? avatarUrl,
    double? amount,
    double? percentage,
    int? shares,
    bool? isPayer,
    bool? isSettled,
    DateTime? settledAt,
    String? settlementNote,
  }) {
    return SplitParticipant(
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      isPayer: isPayer ?? this.isPayer,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
      settlementNote: settlementNote ?? this.settlementNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'avatarUrl': avatarUrl,
      'amount': amount,
      'percentage': percentage,
      'shares': shares,
      'isPayer': isPayer,
      'isSettled': isSettled,
      'settledAt': settledAt?.toIso8601String(),
      'settlementNote': settlementNote,
    };
  }

  factory SplitParticipant.fromMap(Map<String, dynamic> map) {
    return SplitParticipant(
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      amount: (map['amount'] as num).toDouble(),
      percentage: (map['percentage'] as num?)?.toDouble(),
      shares: map['shares'] as int?,
      isPayer: map['isPayer'] as bool? ?? false,
      isSettled: map['isSettled'] as bool? ?? false,
      settledAt: map['settledAt'] != null
          ? DateTime.parse(map['settledAt'] as String)
          : null,
      settlementNote: map['settlementNote'] as String?,
    );
  }
}

/// 分摊信息
class SplitInfo {
  /// 分摊类型
  final SplitType type;
  /// 分摊状态
  final SplitStatus status;
  /// 参与者列表
  final List<SplitParticipant> participants;
  /// 付款人ID
  final String payerId;
  /// 创建时间
  final DateTime createdAt;
  /// 更新时间
  final DateTime? updatedAt;
  /// 备注
  final String? note;

  const SplitInfo({
    required this.type,
    this.status = SplitStatus.pending,
    required this.participants,
    required this.payerId,
    required this.createdAt,
    this.updatedAt,
    this.note,
  });

  /// 总金额
  double get totalAmount =>
      participants.fold(0, (sum, p) => sum + p.amount);

  /// 已结算金额
  double get settledAmount =>
      participants.where((p) => p.isSettled).fold(0, (sum, p) => sum + p.amount);

  /// 待结算金额
  double get pendingAmount =>
      participants.where((p) => !p.isSettled && !p.isPayer).fold(0, (sum, p) => sum + p.amount);

  /// 参与者数量
  int get participantCount => participants.length;

  /// 已结算参与者数量
  int get settledCount => participants.where((p) => p.isSettled).length;

  /// 是否全部结算
  bool get isFullySettled =>
      participants.every((p) => p.isSettled || p.isPayer);

  /// 获取付款人
  SplitParticipant? get payer =>
      participants.where((p) => p.isPayer).firstOrNull;

  /// 获取非付款人参与者
  List<SplitParticipant> get nonPayerParticipants =>
      participants.where((p) => !p.isPayer).toList();

  SplitInfo copyWith({
    SplitType? type,
    SplitStatus? status,
    List<SplitParticipant>? participants,
    String? payerId,
    DateTime? updatedAt,
    String? note,
  }) {
    return SplitInfo(
      type: type ?? this.type,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      payerId: payerId ?? this.payerId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'status': status.name,
      'participants': participants.map((p) => p.toMap()).toList(),
      'payerId': payerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'note': note,
    };
  }

  factory SplitInfo.fromMap(Map<String, dynamic> map) {
    return SplitInfo(
      type: SplitType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SplitType.equal,
      ),
      status: SplitStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SplitStatus.pending,
      ),
      participants: (map['participants'] as List)
          .map((p) => SplitParticipant.fromMap(p as Map<String, dynamic>))
          .toList(),
      payerId: map['payerId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      note: map['note'] as String?,
    );
  }
}

/// 分摊交易
class SplitTransaction {
  /// 唯一标识
  final String id;
  /// 关联的账本ID
  final String ledgerId;
  /// 总金额
  final double amount;
  /// 分类ID
  final String categoryId;
  /// 描述
  final String description;
  /// 分摊信息
  final SplitInfo splitInfo;
  /// 创建者ID
  final String createdBy;
  /// 创建时间
  final DateTime createdAt;
  /// 更新时间
  final DateTime? updatedAt;
  /// 交易日期
  final DateTime transactionDate;
  /// 附件URL列表
  final List<String>? attachments;
  /// 地点
  final String? location;
  /// 标签
  final List<String>? tags;

  const SplitTransaction({
    required this.id,
    required this.ledgerId,
    required this.amount,
    required this.categoryId,
    required this.description,
    required this.splitInfo,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.transactionDate,
    this.attachments,
    this.location,
    this.tags,
  });

  /// 分摊状态
  SplitStatus get status => splitInfo.status;

  /// 是否已完全结算
  bool get isFullySettled => splitInfo.isFullySettled;

  /// 待结算金额
  double get pendingAmount => splitInfo.pendingAmount;

  SplitTransaction copyWith({
    String? id,
    String? ledgerId,
    double? amount,
    String? categoryId,
    String? description,
    SplitInfo? splitInfo,
    String? createdBy,
    DateTime? updatedAt,
    DateTime? transactionDate,
    List<String>? attachments,
    String? location,
    List<String>? tags,
  }) {
    return SplitTransaction(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      splitInfo: splitInfo ?? this.splitInfo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      transactionDate: transactionDate ?? this.transactionDate,
      attachments: attachments ?? this.attachments,
      location: location ?? this.location,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'amount': amount,
      'categoryId': categoryId,
      'description': description,
      'splitInfo': splitInfo.toMap(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'transactionDate': transactionDate.toIso8601String(),
      'attachments': attachments,
      'location': location,
      'tags': tags,
    };
  }

  factory SplitTransaction.fromMap(Map<String, dynamic> map) {
    return SplitTransaction(
      id: map['id'] as String,
      ledgerId: map['ledgerId'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      description: map['description'] as String,
      splitInfo: SplitInfo.fromMap(map['splitInfo'] as Map<String, dynamic>),
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      transactionDate: DateTime.parse(map['transactionDate'] as String),
      attachments: map['attachments'] != null
          ? List<String>.from(map['attachments'])
          : null,
      location: map['location'] as String?,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SplitTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SplitTransaction(id: $id, amount: $amount, status: ${status.displayName})';
  }
}

/// 分摊结算记录
class SettlementRecord {
  /// 唯一标识
  final String id;
  /// 关联的分摊交易ID
  final String splitTransactionId;
  /// 付款人ID（结算方）
  final String fromMemberId;
  /// 收款人ID（被结算方，通常是原付款人）
  final String toMemberId;
  /// 结算金额
  final double amount;
  /// 结算方式
  final String? settlementMethod;
  /// 结算时间
  final DateTime settledAt;
  /// 备注
  final String? note;

  const SettlementRecord({
    required this.id,
    required this.splitTransactionId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    this.settlementMethod,
    required this.settledAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'splitTransactionId': splitTransactionId,
      'fromMemberId': fromMemberId,
      'toMemberId': toMemberId,
      'amount': amount,
      'settlementMethod': settlementMethod,
      'settledAt': settledAt.toIso8601String(),
      'note': note,
    };
  }

  factory SettlementRecord.fromMap(Map<String, dynamic> map) {
    return SettlementRecord(
      id: map['id'] as String,
      splitTransactionId: map['splitTransactionId'] as String,
      fromMemberId: map['fromMemberId'] as String,
      toMemberId: map['toMemberId'] as String,
      amount: (map['amount'] as num).toDouble(),
      settlementMethod: map['settlementMethod'] as String?,
      settledAt: DateTime.parse(map['settledAt'] as String),
      note: map['note'] as String?,
    );
  }
}

/// 成员余额
class MemberBalance {
  /// 成员ID
  final String memberId;
  /// 成员名称
  final String memberName;
  /// 总应收（其他人欠该成员的）
  final double totalOwed;
  /// 总应付（该成员欠其他人的）
  final double totalOwing;
  /// 净余额（正数表示应收，负数表示应付）
  double get netBalance => totalOwed - totalOwing;
  /// 详细欠款关系
  final List<BalanceDetail> details;

  const MemberBalance({
    required this.memberId,
    required this.memberName,
    required this.totalOwed,
    required this.totalOwing,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'totalOwed': totalOwed,
      'totalOwing': totalOwing,
      'netBalance': netBalance,
      'details': details.map((d) => d.toMap()).toList(),
    };
  }
}

/// 余额明细
class BalanceDetail {
  /// 对方成员ID
  final String otherMemberId;
  /// 对方成员名称
  final String otherMemberName;
  /// 金额（正数表示对方欠你，负数表示你欠对方）
  final double amount;
  /// 相关的分摊交易ID列表
  final List<String> relatedTransactionIds;

  const BalanceDetail({
    required this.otherMemberId,
    required this.otherMemberName,
    required this.amount,
    required this.relatedTransactionIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'otherMemberId': otherMemberId,
      'otherMemberName': otherMemberName,
      'amount': amount,
      'relatedTransactionIds': relatedTransactionIds,
    };
  }
}
