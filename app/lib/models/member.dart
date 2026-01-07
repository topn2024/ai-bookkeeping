import 'package:flutter/material.dart';

/// 成员角色
enum MemberRole {
  owner,    // 所有者（创建者）
  admin,    // 管理员
  editor,   // 编辑者
  viewer,   // 只读查看者
}

extension MemberRoleExtension on MemberRole {
  String get displayName {
    switch (this) {
      case MemberRole.owner:
        return '所有者';
      case MemberRole.admin:
        return '管理员';
      case MemberRole.editor:
        return '编辑者';
      case MemberRole.viewer:
        return '只读';
    }
  }

  String get description {
    switch (this) {
      case MemberRole.owner:
        return '完全控制权限，可删除账本';
      case MemberRole.admin:
        return '可管理成员、设置预算';
      case MemberRole.editor:
        return '可记账、编辑交易';
      case MemberRole.viewer:
        return '仅查看账目和统计';
    }
  }

  IconData get icon {
    switch (this) {
      case MemberRole.owner:
        return Icons.star;
      case MemberRole.admin:
        return Icons.admin_panel_settings;
      case MemberRole.editor:
        return Icons.edit;
      case MemberRole.viewer:
        return Icons.visibility;
    }
  }

  Color get color {
    switch (this) {
      case MemberRole.owner:
        return Colors.amber;
      case MemberRole.admin:
        return Colors.purple;
      case MemberRole.editor:
        return Colors.blue;
      case MemberRole.viewer:
        return Colors.grey;
    }
  }

  /// 是否可以记账
  bool get canCreateTransaction {
    return this == MemberRole.owner ||
           this == MemberRole.admin ||
           this == MemberRole.editor;
  }

  /// 是否可以管理成员
  bool get canManageMembers {
    return this == MemberRole.owner || this == MemberRole.admin;
  }

  /// 是否可以设置预算
  bool get canSetBudget {
    return this == MemberRole.owner || this == MemberRole.admin;
  }

  /// 是否可以审批消费
  bool get canApproveExpense {
    return this == MemberRole.owner || this == MemberRole.admin;
  }

  /// 是否可以删除账本
  bool get canDeleteLedger {
    return this == MemberRole.owner;
  }
}

/// 邀请状态
enum InviteStatus {
  pending,   // 待接受
  accepted,  // 已接受
  rejected,  // 已拒绝
  expired,   // 已过期
}

extension InviteStatusExtension on InviteStatus {
  String get displayName {
    switch (this) {
      case InviteStatus.pending:
        return '待接受';
      case InviteStatus.accepted:
        return '已接受';
      case InviteStatus.rejected:
        return '已拒绝';
      case InviteStatus.expired:
        return '已过期';
    }
  }

  Color get color {
    switch (this) {
      case InviteStatus.pending:
        return Colors.orange;
      case InviteStatus.accepted:
        return Colors.green;
      case InviteStatus.rejected:
        return Colors.red;
      case InviteStatus.expired:
        return Colors.grey;
    }
  }
}

/// 账本成员
class LedgerMember {
  final String id;
  final String ledgerId;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userAvatar;
  final MemberRole role;
  final DateTime joinedAt;
  final bool isActive;
  final String? nickname; // 在账本中的昵称

  const LedgerMember({
    required this.id,
    required this.ledgerId,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userAvatar,
    required this.role,
    required this.joinedAt,
    this.isActive = true,
    this.nickname,
  });

  /// 显示名称（优先使用昵称）
  String get displayName => nickname ?? userName;

  /// 头像URL
  String? get avatarUrl => userAvatar;

  LedgerMember copyWith({
    String? id,
    String? ledgerId,
    String? userId,
    String? userName,
    String? userEmail,
    String? userAvatar,
    MemberRole? role,
    DateTime? joinedAt,
    bool? isActive,
    String? nickname,
  }) {
    return LedgerMember(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userAvatar: userAvatar ?? this.userAvatar,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      nickname: nickname ?? this.nickname,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userAvatar': userAvatar,
      'role': role.index,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
      'nickname': nickname,
    };
  }

  factory LedgerMember.fromMap(Map<String, dynamic> map) {
    return LedgerMember(
      id: map['id'] as String,
      ledgerId: map['ledgerId'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      userEmail: map['userEmail'] as String?,
      userAvatar: map['userAvatar'] as String?,
      role: MemberRole.values[map['role'] as int],
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int),
      isActive: (map['isActive'] as int) == 1,
      nickname: map['nickname'] as String?,
    );
  }
}

/// 成员邀请
class MemberInvite {
  final String id;
  final String ledgerId;
  final String ledgerName;
  final String inviterId;
  final String inviterName;
  final String? inviteeEmail;
  final String? inviteCode;      // 邀请码
  final MemberRole role;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  const MemberInvite({
    required this.id,
    required this.ledgerId,
    required this.ledgerName,
    required this.inviterId,
    required this.inviterName,
    this.inviteeEmail,
    this.inviteCode,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == InviteStatus.pending && !isExpired;

  MemberInvite copyWith({
    String? id,
    String? ledgerId,
    String? ledgerName,
    String? inviterId,
    String? inviterName,
    String? inviteeEmail,
    String? inviteCode,
    MemberRole? role,
    InviteStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? respondedAt,
  }) {
    return MemberInvite(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      ledgerName: ledgerName ?? this.ledgerName,
      inviterId: inviterId ?? this.inviterId,
      inviterName: inviterName ?? this.inviterName,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
      inviteCode: inviteCode ?? this.inviteCode,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'ledgerName': ledgerName,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviteeEmail': inviteeEmail,
      'inviteCode': inviteCode,
      'role': role.index,
      'status': status.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
    };
  }

  factory MemberInvite.fromMap(Map<String, dynamic> map) {
    return MemberInvite(
      id: map['id'] as String,
      ledgerId: map['ledgerId'] as String,
      ledgerName: map['ledgerName'] as String,
      inviterId: map['inviterId'] as String,
      inviterName: map['inviterName'] as String,
      inviteeEmail: map['inviteeEmail'] as String?,
      inviteCode: map['inviteCode'] as String?,
      role: MemberRole.values[map['role'] as int],
      status: InviteStatus.values[map['status'] as int],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
      respondedAt: map['respondedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['respondedAt'] as int)
          : null,
    );
  }

  /// 生成邀请链接（模拟）
  String get inviteLink => 'bookkeeping://invite/$inviteCode';
}

/// 成员预算
class MemberBudget {
  final String id;
  final String ledgerId;
  final String memberId;
  final String memberName;
  final double monthlyLimit;      // 月度预算上限
  final double currentSpent;      // 当月已花费
  final bool requireApproval;     // 超额是否需要审批
  final double approvalThreshold; // 单笔审批阈值
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemberBudget({
    required this.id,
    required this.ledgerId,
    required this.memberId,
    required this.memberName,
    required this.monthlyLimit,
    this.currentSpent = 0,
    this.requireApproval = false,
    this.approvalThreshold = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remaining => monthlyLimit - currentSpent;
  double get usagePercent => monthlyLimit > 0 ? currentSpent / monthlyLimit : 0;
  bool get isOverBudget => currentSpent > monthlyLimit;

  MemberBudget copyWith({
    String? id,
    String? ledgerId,
    String? memberId,
    String? memberName,
    double? monthlyLimit,
    double? currentSpent,
    bool? requireApproval,
    double? approvalThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemberBudget(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      currentSpent: currentSpent ?? this.currentSpent,
      requireApproval: requireApproval ?? this.requireApproval,
      approvalThreshold: approvalThreshold ?? this.approvalThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'memberId': memberId,
      'memberName': memberName,
      'monthlyLimit': monthlyLimit,
      'currentSpent': currentSpent,
      'requireApproval': requireApproval ? 1 : 0,
      'approvalThreshold': approvalThreshold,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory MemberBudget.fromMap(Map<String, dynamic> map) {
    return MemberBudget(
      id: map['id'] as String,
      ledgerId: map['ledgerId'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      monthlyLimit: map['monthlyLimit'] as double,
      currentSpent: map['currentSpent'] as double? ?? 0,
      requireApproval: (map['requireApproval'] as int) == 1,
      approvalThreshold: map['approvalThreshold'] as double? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}

/// 审批状态
enum ApprovalStatus {
  pending,   // 待审批
  approved,  // 已批准
  rejected,  // 已拒绝
}

extension ApprovalStatusExtension on ApprovalStatus {
  String get displayName {
    switch (this) {
      case ApprovalStatus.pending:
        return '待审批';
      case ApprovalStatus.approved:
        return '已批准';
      case ApprovalStatus.rejected:
        return '已拒绝';
    }
  }

  Color get color {
    switch (this) {
      case ApprovalStatus.pending:
        return Colors.orange;
      case ApprovalStatus.approved:
        return Colors.green;
      case ApprovalStatus.rejected:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case ApprovalStatus.pending:
        return Icons.hourglass_empty;
      case ApprovalStatus.approved:
        return Icons.check_circle;
      case ApprovalStatus.rejected:
        return Icons.cancel;
    }
  }
}

/// 消费审批
class ExpenseApproval {
  final String id;
  final String ledgerId;
  final String transactionId;
  final String requesterId;
  final String requesterName;
  final double amount;
  final String category;
  final String? note;
  final ApprovalStatus status;
  final String? approverId;
  final String? approverName;
  final String? approverComment;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const ExpenseApproval({
    required this.id,
    required this.ledgerId,
    required this.transactionId,
    required this.requesterId,
    required this.requesterName,
    required this.amount,
    required this.category,
    this.note,
    required this.status,
    this.approverId,
    this.approverName,
    this.approverComment,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == ApprovalStatus.pending;

  ExpenseApproval copyWith({
    String? id,
    String? ledgerId,
    String? transactionId,
    String? requesterId,
    String? requesterName,
    double? amount,
    String? category,
    String? note,
    ApprovalStatus? status,
    String? approverId,
    String? approverName,
    String? approverComment,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return ExpenseApproval(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      transactionId: transactionId ?? this.transactionId,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      status: status ?? this.status,
      approverId: approverId ?? this.approverId,
      approverName: approverName ?? this.approverName,
      approverComment: approverComment ?? this.approverComment,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'transactionId': transactionId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'amount': amount,
      'category': category,
      'note': note,
      'status': status.index,
      'approverId': approverId,
      'approverName': approverName,
      'approverComment': approverComment,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
    };
  }

  factory ExpenseApproval.fromMap(Map<String, dynamic> map) {
    return ExpenseApproval(
      id: map['id'] as String,
      ledgerId: map['ledgerId'] as String,
      transactionId: map['transactionId'] as String,
      requesterId: map['requesterId'] as String,
      requesterName: map['requesterName'] as String,
      amount: map['amount'] as double,
      category: map['category'] as String,
      note: map['note'] as String?,
      status: ApprovalStatus.values[map['status'] as int],
      approverId: map['approverId'] as String?,
      approverName: map['approverName'] as String?,
      approverComment: map['approverComment'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      respondedAt: map['respondedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['respondedAt'] as int)
          : null,
    );
  }
}

/// 家庭账本类型
enum FamilyLedgerType {
  couple,      // 情侣/夫妻
  family,      // 家庭
  roommates,   // 室友
  group,       // 其他群组
}

extension FamilyLedgerTypeExtension on FamilyLedgerType {
  String get displayName {
    switch (this) {
      case FamilyLedgerType.couple:
        return '情侣/夫妻';
      case FamilyLedgerType.family:
        return '家庭';
      case FamilyLedgerType.roommates:
        return '室友';
      case FamilyLedgerType.group:
        return '群组';
    }
  }

  IconData get icon {
    switch (this) {
      case FamilyLedgerType.couple:
        return Icons.favorite;
      case FamilyLedgerType.family:
        return Icons.family_restroom;
      case FamilyLedgerType.roommates:
        return Icons.people;
      case FamilyLedgerType.group:
        return Icons.groups;
    }
  }
}
