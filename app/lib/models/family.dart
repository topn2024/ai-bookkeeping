import 'package:flutter/material.dart';
import 'member.dart';
import 'resource_pool.dart';

/// 家庭账本扩展模型
///
/// 2.0版本新增：支持家庭钱龄统计、成员贡献度分析等功能（第13章）

/// 家庭信息
class Family {
  final String id;
  final String name;
  final String? description;
  final FamilyLedgerType type;
  final String ownerId;               // 家庭创建者ID
  final String? avatarUrl;            // 家庭头像
  final List<FamilyMember> members;   // 家庭成员列表
  final FamilySettings settings;      // 家庭设置
  final DateTime createdAt;
  final DateTime updatedAt;

  const Family({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.ownerId,
    this.avatarUrl,
    required this.members,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 成员数量
  int get memberCount => members.length;

  /// 活跃成员数量
  int get activeMemberCount => members.where((m) => m.isActive).length;

  /// 是否为单人家庭
  bool get isSingleMember => memberCount == 1;

  /// 获取所有者
  FamilyMember? get owner => members.firstWhere(
        (m) => m.role == MemberRole.owner,
        orElse: () => members.first,
      );

  Family copyWith({
    String? id,
    String? name,
    String? description,
    FamilyLedgerType? type,
    String? ownerId,
    String? avatarUrl,
    List<FamilyMember>? members,
    FamilySettings? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      ownerId: ownerId ?? this.ownerId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      members: members ?? this.members,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.index,
      'ownerId': ownerId,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Family.fromMap(Map<String, dynamic> map, {
    required List<FamilyMember> members,
    required FamilySettings settings,
  }) {
    return Family(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      type: FamilyLedgerType.values[map['type'] as int],
      ownerId: map['ownerId'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      members: members,
      settings: settings,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}

/// 家庭成员（扩展 LedgerMember）
class FamilyMember {
  final String id;
  final String odId;
  final String familyId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final MemberRole role;
  final FamilyMemberRelation? relation;  // 家庭关系
  final bool isActive;
  final DateTime joinedAt;

  // 2.0新增：成员统计数据
  final double monthlyContribution;      // 本月贡献金额
  final double totalContribution;        // 总贡献金额
  final int transactionCount;            // 交易笔数
  final int? personalMoneyAge;           // 个人钱龄（天）

  const FamilyMember({
    required this.id,
    required this.odId,
    required this.familyId,
    required this.displayName,
    this.email,
    this.avatarUrl,
    required this.role,
    this.relation,
    this.isActive = true,
    required this.joinedAt,
    this.monthlyContribution = 0,
    this.totalContribution = 0,
    this.transactionCount = 0,
    this.personalMoneyAge,
  });

  /// 贡献度百分比（需外部计算总额后设置）
  double contributionRate(double familyTotal) =>
      familyTotal > 0 ? monthlyContribution / familyTotal : 0;

  FamilyMember copyWith({
    String? id,
    String? odId,
    String? familyId,
    String? displayName,
    String? email,
    String? avatarUrl,
    MemberRole? role,
    FamilyMemberRelation? relation,
    bool? isActive,
    DateTime? joinedAt,
    double? monthlyContribution,
    double? totalContribution,
    int? transactionCount,
    int? personalMoneyAge,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      odId: odId ?? this.odId,
      familyId: familyId ?? this.familyId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      relation: relation ?? this.relation,
      isActive: isActive ?? this.isActive,
      joinedAt: joinedAt ?? this.joinedAt,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      totalContribution: totalContribution ?? this.totalContribution,
      transactionCount: transactionCount ?? this.transactionCount,
      personalMoneyAge: personalMoneyAge ?? this.personalMoneyAge,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'odId': odId,
      'familyId': familyId,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role.index,
      'relation': relation?.index,
      'isActive': isActive ? 1 : 0,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'monthlyContribution': monthlyContribution,
      'totalContribution': totalContribution,
      'transactionCount': transactionCount,
      'personalMoneyAge': personalMoneyAge,
    };
  }

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['id'] as String,
      odId: map['odId'] as String,
      familyId: map['familyId'] as String,
      displayName: map['displayName'] as String,
      email: map['email'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      role: MemberRole.values[map['role'] as int],
      relation: map['relation'] != null
          ? FamilyMemberRelation.values[map['relation'] as int]
          : null,
      isActive: map['isActive'] == 1,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int),
      monthlyContribution: (map['monthlyContribution'] as num?)?.toDouble() ?? 0,
      totalContribution: (map['totalContribution'] as num?)?.toDouble() ?? 0,
      transactionCount: map['transactionCount'] as int? ?? 0,
      personalMoneyAge: map['personalMoneyAge'] as int?,
    );
  }
}

/// 家庭成员关系
enum FamilyMemberRelation {
  /// 配偶
  spouse,

  /// 父母
  parent,

  /// 子女
  child,

  /// 兄弟姐妹
  sibling,

  /// 室友
  roommate,

  /// 朋友
  friend,

  /// 其他
  other,
}

extension FamilyMemberRelationExtension on FamilyMemberRelation {
  String get displayName {
    switch (this) {
      case FamilyMemberRelation.spouse:
        return '配偶';
      case FamilyMemberRelation.parent:
        return '父母';
      case FamilyMemberRelation.child:
        return '子女';
      case FamilyMemberRelation.sibling:
        return '兄弟姐妹';
      case FamilyMemberRelation.roommate:
        return '室友';
      case FamilyMemberRelation.friend:
        return '朋友';
      case FamilyMemberRelation.other:
        return '其他';
    }
  }

  IconData get icon {
    switch (this) {
      case FamilyMemberRelation.spouse:
        return Icons.favorite;
      case FamilyMemberRelation.parent:
        return Icons.elderly;
      case FamilyMemberRelation.child:
        return Icons.child_care;
      case FamilyMemberRelation.sibling:
        return Icons.people;
      case FamilyMemberRelation.roommate:
        return Icons.home;
      case FamilyMemberRelation.friend:
        return Icons.person;
      case FamilyMemberRelation.other:
        return Icons.person_outline;
    }
  }
}

/// 家庭设置
class FamilySettings {
  final String familyId;
  final bool enableSharedBudget;        // 是否启用共享预算
  final bool enableMemberBudgets;       // 是否启用成员独立预算
  final bool enableApprovalFlow;        // 是否启用审批流程
  final double approvalThreshold;       // 审批阈值（超过此金额需审批）
  final bool showMemberSpending;        // 是否显示成员消费明细
  final bool enableFamilyMoneyAge;      // 是否启用家庭钱龄
  final NotificationSettings notifications; // 通知设置
  final DateTime updatedAt;

  const FamilySettings({
    required this.familyId,
    this.enableSharedBudget = true,
    this.enableMemberBudgets = false,
    this.enableApprovalFlow = false,
    this.approvalThreshold = 500,
    this.showMemberSpending = true,
    this.enableFamilyMoneyAge = true,
    required this.notifications,
    required this.updatedAt,
  });

  FamilySettings copyWith({
    String? familyId,
    bool? enableSharedBudget,
    bool? enableMemberBudgets,
    bool? enableApprovalFlow,
    double? approvalThreshold,
    bool? showMemberSpending,
    bool? enableFamilyMoneyAge,
    NotificationSettings? notifications,
    DateTime? updatedAt,
  }) {
    return FamilySettings(
      familyId: familyId ?? this.familyId,
      enableSharedBudget: enableSharedBudget ?? this.enableSharedBudget,
      enableMemberBudgets: enableMemberBudgets ?? this.enableMemberBudgets,
      enableApprovalFlow: enableApprovalFlow ?? this.enableApprovalFlow,
      approvalThreshold: approvalThreshold ?? this.approvalThreshold,
      showMemberSpending: showMemberSpending ?? this.showMemberSpending,
      enableFamilyMoneyAge: enableFamilyMoneyAge ?? this.enableFamilyMoneyAge,
      notifications: notifications ?? this.notifications,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'enableSharedBudget': enableSharedBudget ? 1 : 0,
      'enableMemberBudgets': enableMemberBudgets ? 1 : 0,
      'enableApprovalFlow': enableApprovalFlow ? 1 : 0,
      'approvalThreshold': approvalThreshold,
      'showMemberSpending': showMemberSpending ? 1 : 0,
      'enableFamilyMoneyAge': enableFamilyMoneyAge ? 1 : 0,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory FamilySettings.fromMap(Map<String, dynamic> map, {
    required NotificationSettings notifications,
  }) {
    return FamilySettings(
      familyId: map['familyId'] as String,
      enableSharedBudget: map['enableSharedBudget'] == 1,
      enableMemberBudgets: map['enableMemberBudgets'] == 1,
      enableApprovalFlow: map['enableApprovalFlow'] == 1,
      approvalThreshold: (map['approvalThreshold'] as num?)?.toDouble() ?? 500,
      showMemberSpending: map['showMemberSpending'] == 1,
      enableFamilyMoneyAge: map['enableFamilyMoneyAge'] == 1,
      notifications: notifications,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  factory FamilySettings.defaults(String familyId) {
    return FamilySettings(
      familyId: familyId,
      notifications: NotificationSettings.defaults(),
      updatedAt: DateTime.now(),
    );
  }
}

/// 通知设置
class NotificationSettings {
  final bool onMemberJoin;              // 成员加入通知
  final bool onLargeExpense;            // 大额支出通知
  final bool onBudgetWarning;           // 预算预警通知
  final bool onApprovalRequest;         // 审批请求通知
  final bool dailySummary;              // 每日汇总通知
  final bool weeklySummary;             // 每周汇总通知

  const NotificationSettings({
    this.onMemberJoin = true,
    this.onLargeExpense = true,
    this.onBudgetWarning = true,
    this.onApprovalRequest = true,
    this.dailySummary = false,
    this.weeklySummary = true,
  });

  factory NotificationSettings.defaults() {
    return const NotificationSettings();
  }

  Map<String, dynamic> toMap() {
    return {
      'onMemberJoin': onMemberJoin ? 1 : 0,
      'onLargeExpense': onLargeExpense ? 1 : 0,
      'onBudgetWarning': onBudgetWarning ? 1 : 0,
      'onApprovalRequest': onApprovalRequest ? 1 : 0,
      'dailySummary': dailySummary ? 1 : 0,
      'weeklySummary': weeklySummary ? 1 : 0,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      onMemberJoin: map['onMemberJoin'] == 1,
      onLargeExpense: map['onLargeExpense'] == 1,
      onBudgetWarning: map['onBudgetWarning'] == 1,
      onApprovalRequest: map['onApprovalRequest'] == 1,
      dailySummary: map['dailySummary'] == 1,
      weeklySummary: map['weeklySummary'] == 1,
    );
  }
}

/// 家庭钱龄统计
class FamilyMoneyAge {
  final String familyId;
  final int familyAverageAge;           // 家庭平均钱龄
  final MoneyAgeLevel familyLevel;      // 家庭钱龄等级
  final Map<String, int> memberAges;    // 各成员钱龄 (memberId -> days)
  final Map<String, double> contributions; // 各成员贡献度 (memberId -> percentage)
  final String? topContributor;         // 最大贡献者ID
  final String? lowestAgeMemember;      // 钱龄最低的成员ID
  final List<DailyFamilyMoneyAge> trend; // 家庭钱龄趋势
  final DateTime calculatedAt;

  const FamilyMoneyAge({
    required this.familyId,
    required this.familyAverageAge,
    required this.familyLevel,
    required this.memberAges,
    required this.contributions,
    this.topContributor,
    this.lowestAgeMemember,
    required this.trend,
    required this.calculatedAt,
  });

  /// 家庭钱龄是否健康
  bool get isHealthy => familyAverageAge >= 14;

  /// 改善建议
  List<String> get suggestions {
    final suggestions = <String>[];

    if (familyAverageAge < 7) {
      suggestions.add('家庭整体财务状况紧张，建议减少非必要支出');
    }

    if (lowestAgeMemember != null) {
      suggestions.add('建议关注钱龄较低成员的消费情况');
    }

    if (familyAverageAge >= 30) {
      suggestions.add('家庭财务状况良好，继续保持');
    }

    return suggestions;
  }

  factory FamilyMoneyAge.empty(String familyId) {
    return FamilyMoneyAge(
      familyId: familyId,
      familyAverageAge: 0,
      familyLevel: MoneyAgeLevel.danger,
      memberAges: const {},
      contributions: const {},
      trend: const [],
      calculatedAt: DateTime.now(),
    );
  }
}

/// 每日家庭钱龄数据（用于趋势图）
class DailyFamilyMoneyAge {
  final DateTime date;
  final int averageAge;
  final Map<String, int> memberAges;

  const DailyFamilyMoneyAge({
    required this.date,
    required this.averageAge,
    required this.memberAges,
  });
}

/// 家庭财务摘要
class FamilySummary {
  final String familyId;
  final double monthlyIncome;           // 本月总收入
  final double monthlyExpense;          // 本月总支出
  final double monthlyBalance;          // 本月结余
  final Map<String, double> expenseByMember;  // 各成员支出
  final Map<String, double> incomeByMember;   // 各成员收入
  final Map<String, double> expenseByCategory; // 各分类支出
  final FamilyMoneyAge moneyAge;        // 家庭钱龄
  final DateTime calculatedAt;

  const FamilySummary({
    required this.familyId,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlyBalance,
    required this.expenseByMember,
    required this.incomeByMember,
    required this.expenseByCategory,
    required this.moneyAge,
    required this.calculatedAt,
  });

  /// 储蓄率
  double get savingsRate =>
      monthlyIncome > 0 ? monthlyBalance / monthlyIncome : 0;

  /// 是否有结余
  bool get hasPositiveBalance => monthlyBalance > 0;

  factory FamilySummary.empty(String familyId) {
    return FamilySummary(
      familyId: familyId,
      monthlyIncome: 0,
      monthlyExpense: 0,
      monthlyBalance: 0,
      expenseByMember: const {},
      incomeByMember: const {},
      expenseByCategory: const {},
      moneyAge: FamilyMoneyAge.empty(familyId),
      calculatedAt: DateTime.now(),
    );
  }
}

/// 共享小金库（家庭版）
class SharedVault {
  final String id;
  final String familyId;
  final String name;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final Map<String, double> memberContributions; // 各成员贡献
  final String? linkedGoalId;           // 关联的储蓄目标
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharedVault({
    required this.id,
    required this.familyId,
    required this.name,
    this.description,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.memberContributions,
    this.linkedGoalId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 进度
  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;

  /// 剩余金额
  double get remaining => (targetAmount - currentAmount).clamp(0, targetAmount);

  /// 是否已达成
  bool get isCompleted => currentAmount >= targetAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'familyId': familyId,
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'memberContributions': memberContributions.toString(),
      'linkedGoalId': linkedGoalId,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SharedVault.fromMap(Map<String, dynamic> map) {
    return SharedVault(
      id: map['id'] as String,
      familyId: map['familyId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0,
      memberContributions: {}, // TODO: Parse from string
      linkedGoalId: map['linkedGoalId'] as String?,
      isActive: map['isActive'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}
