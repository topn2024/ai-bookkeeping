# -*- coding: utf-8 -*-
"""
添加家庭账本与多成员管理系统章节
"""

FAMILY_CHAPTER = '''

## 13. 家庭账本与多成员管理系统

### 13.0 设计原则回顾

本章定义AI记账应用的家庭账本与多成员协作系统，为家庭理财者提供共享记账、预算协作、支出追踪等核心能力。

#### 13.0.1 家庭账本设计原则矩阵

| 设计原则 | 在家庭账本中的体现 | 实现方式 |
|----------|-------------------|----------|
| **懒人设计** | 一键邀请家人，自动同步 | 二维码邀请，实时数据同步 |
| **伙伴化** | 家庭成员互动激励 | 成员贡献排行，共同目标达成庆祝 |
| **隐私优先** | 个人隐私与家庭共享平衡 | 灵活的可见性控制，敏感账目隐藏 |
| **渐进式** | 从个人账本平滑过渡到家庭 | 保留个人账本，按需开启共享 |
| **开放集成** | 与其他系统无缝协作 | 统一的账本切换，预算/钱龄联动 |

#### 13.0.2 设计理念

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         家庭账本系统设计理念                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   🎯 核心目标：让家庭财务管理透明、协作、高效                                   │
│                                                                              │
│   ┌────────────────────────────────────────────────────────────────────────┐ │
│   │  设计理念：共享不失私密，协作不增负担，透明促进沟通                         │ │
│   └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│   四大核心能力：                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│   │  多账本管理   │  │  成员协作    │  │  预算共享    │  │  支出追踪    │   │
│   │  ──────────  │  │  ──────────  │  │  ──────────  │  │  ──────────  │   │
│   │ 个人/家庭/   │  │ 邀请成员，   │  │ 家庭预算分配 │  │ 谁花了多少   │   │
│   │ 专项账本     │  │ 角色权限     │  │ AA制分摊     │  │ 分类贡献     │   │
│   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### 13.0.3 与其他系统的关系

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                      家庭账本系统与其他模块的关系                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        ┌─────────────────────────┐                           │
│                        │   13. 家庭账本系统       │                           │
│                        │      （本章）            │                           │
│                        └───────────┬─────────────┘                           │
│                                    │                                         │
│        ┌───────────────────────────┼───────────────────────────┐             │
│        │                           │                           │             │
│        ▼                           ▼                           ▼             │
│   ┌──────────┐              ┌──────────┐              ┌──────────┐          │
│   │ 7.钱龄   │              │ 8.预算   │              │ 9.习惯   │          │
│   │  系统    │              │  系统    │              │  培养    │          │
│   │ ──────── │              │ ──────── │              │ ──────── │          │
│   │ 家庭钱龄 │              │ 家庭预算 │              │ 家庭习惯 │          │
│   │ 成员贡献 │              │ 成员配额 │              │ 共同目标 │          │
│   └──────────┘              └──────────┘              └──────────┘          │
│        │                           │                           │             │
│        └───────────────────────────┼───────────────────────────┘             │
│                                    ▼                                         │
│                        ┌─────────────────────────┐                           │
│                        │   12. 数据联动与可视化   │                           │
│                        │   - 家庭报表             │                           │
│                        │   - 成员对比分析         │                           │
│                        └─────────────────────────┘                           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 13.1 账本体系架构

#### 13.1.1 账本类型定义

```dart
/// 账本类型枚举
enum LedgerType {
  personal,    // 个人账本（默认，私有）
  family,      // 家庭账本（多成员共享）
  couple,      // 情侣账本（两人共享）
  group,       // 群组账本（多人AA）
  project,     // 专项账本（装修、旅行等）
}

/// 账本实体
class Ledger {
  final String id;
  final String name;
  final LedgerType type;
  final String ownerId;           // 创建者/所有者
  final String? iconEmoji;        // 账本图标
  final String? coverColor;       // 封面颜色
  final DateTime createdAt;
  final LedgerSettings settings;
  final List<LedgerMember> members;
  final LedgerStats stats;

  Ledger({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    this.iconEmoji,
    this.coverColor,
    required this.createdAt,
    required this.settings,
    required this.members,
    required this.stats,
  });

  /// 是否为共享账本
  bool get isShared => type != LedgerType.personal;

  /// 获取成员数量
  int get memberCount => members.length;

  /// 检查用户是否有权限
  bool hasPermission(String userId, LedgerPermission permission) {
    final member = members.firstWhereOrNull((m) => m.userId == userId);
    if (member == null) return false;
    return member.role.hasPermission(permission);
  }
}

/// 账本设置
class LedgerSettings {
  final String defaultCurrency;       // 默认货币
  final bool autoSyncEnabled;         // 自动同步
  final bool notifyOnNewTransaction;  // 新交易通知
  final bool notifyOnBudgetAlert;     // 预算告警通知
  final VisibilityLevel defaultVisibility;  // 默认可见性
  final bool allowMemberInvite;       // 允许成员邀请他人
  final int? monthlyBudgetLimit;      // 月度预算上限

  LedgerSettings({
    this.defaultCurrency = 'CNY',
    this.autoSyncEnabled = true,
    this.notifyOnNewTransaction = true,
    this.notifyOnBudgetAlert = true,
    this.defaultVisibility = VisibilityLevel.allMembers,
    this.allowMemberInvite = false,
    this.monthlyBudgetLimit,
  });
}

/// 可见性级别
enum VisibilityLevel {
  private,      // 仅自己可见
  allMembers,   // 所有成员可见
  adminsOnly,   // 仅管理员可见
  custom,       // 自定义可见成员
}
```

#### 13.1.2 账本管理服务

```dart
/// 账本管理服务
class LedgerService {
  final LedgerRepository _repository;
  final MemberService _memberService;
  final SyncService _syncService;
  final NotificationService _notificationService;

  // 当前活跃账本
  final ValueNotifier<Ledger?> currentLedger = ValueNotifier(null);

  // 用户的所有账本
  final ValueNotifier<List<Ledger>> userLedgers = ValueNotifier([]);

  LedgerService(
    this._repository,
    this._memberService,
    this._syncService,
    this._notificationService,
  );

  /// 创建账本
  Future<Ledger> createLedger({
    required String name,
    required LedgerType type,
    String? iconEmoji,
    String? coverColor,
    LedgerSettings? settings,
  }) async {
    final userId = AuthService().currentUserId;

    final ledger = Ledger(
      id: generateUuid(),
      name: name,
      type: type,
      ownerId: userId,
      iconEmoji: iconEmoji ?? _getDefaultEmoji(type),
      coverColor: coverColor,
      createdAt: DateTime.now(),
      settings: settings ?? LedgerSettings(),
      members: [
        LedgerMember(
          userId: userId,
          role: MemberRole.owner,
          joinedAt: DateTime.now(),
        ),
      ],
      stats: LedgerStats.empty(),
    );

    await _repository.create(ledger);
    await _refreshUserLedgers();

    return ledger;
  }

  String _getDefaultEmoji(LedgerType type) {
    switch (type) {
      case LedgerType.personal: return '📔';
      case LedgerType.family: return '👨‍👩‍👧‍👦';
      case LedgerType.couple: return '💑';
      case LedgerType.group: return '👥';
      case LedgerType.project: return '📋';
    }
  }

  /// 切换当前账本
  Future<void> switchLedger(String ledgerId) async {
    final ledger = await _repository.getById(ledgerId);
    if (ledger == null) throw LedgerNotFoundException();

    // 检查权限
    final userId = AuthService().currentUserId;
    if (!ledger.members.any((m) => m.userId == userId)) {
      throw NoPermissionException();
    }

    currentLedger.value = ledger;
    await _syncService.syncLedgerData(ledgerId);

    // 保存最后使用的账本
    await PreferencesService().setLastLedgerId(ledgerId);
  }

  /// 获取用户的所有账本
  Future<List<Ledger>> getUserLedgers() async {
    final userId = AuthService().currentUserId;
    final ledgers = await _repository.getByUserId(userId);
    userLedgers.value = ledgers;
    return ledgers;
  }

  /// 删除账本
  Future<void> deleteLedger(String ledgerId) async {
    final ledger = await _repository.getById(ledgerId);
    if (ledger == null) return;

    final userId = AuthService().currentUserId;
    if (ledger.ownerId != userId) {
      throw NoPermissionException('只有账本所有者可以删除账本');
    }

    // 通知所有成员
    for (final member in ledger.members) {
      if (member.userId != userId) {
        await _notificationService.send(
          member.userId,
          NotificationType.ledgerDeleted,
          {'ledgerName': ledger.name},
        );
      }
    }

    await _repository.delete(ledgerId);
    await _refreshUserLedgers();

    // 如果删除的是当前账本，切换到个人账本
    if (currentLedger.value?.id == ledgerId) {
      await _switchToPersonalLedger();
    }
  }

  Future<void> _switchToPersonalLedger() async {
    final ledgers = userLedgers.value;
    final personal = ledgers.firstWhereOrNull(
      (l) => l.type == LedgerType.personal
    );
    if (personal != null) {
      await switchLedger(personal.id);
    }
  }

  Future<void> _refreshUserLedgers() async {
    await getUserLedgers();
  }
}
```

### 13.2 成员管理系统

#### 13.2.1 成员角色与权限

```dart
/// 成员角色
enum MemberRole {
  owner,    // 所有者：全部权限
  admin,    // 管理员：除删除账本外的全部权限
  member,   // 成员：记账、查看
  viewer,   // 查看者：仅查看
}

/// 权限类型
enum LedgerPermission {
  // 账本管理
  editLedgerSettings,     // 编辑账本设置
  deleteLedger,           // 删除账本
  inviteMember,           // 邀请成员
  removeMember,           // 移除成员
  changeMemberRole,       // 修改成员角色

  // 交易操作
  createTransaction,      // 创建交易
  editOwnTransaction,     // 编辑自己的交易
  editAnyTransaction,     // 编辑任何交易
  deleteOwnTransaction,   // 删除自己的交易
  deleteAnyTransaction,   // 删除任何交易

  // 预算操作
  viewBudget,             // 查看预算
  editBudget,             // 编辑预算

  // 数据查看
  viewAllTransactions,    // 查看所有交易
  viewStatistics,         // 查看统计数据
  exportData,             // 导出数据
}

/// 角色权限映射
extension MemberRolePermissions on MemberRole {
  Set<LedgerPermission> get permissions {
    switch (this) {
      case MemberRole.owner:
        return LedgerPermission.values.toSet();

      case MemberRole.admin:
        return LedgerPermission.values.toSet()
          ..remove(LedgerPermission.deleteLedger);

      case MemberRole.member:
        return {
          LedgerPermission.createTransaction,
          LedgerPermission.editOwnTransaction,
          LedgerPermission.deleteOwnTransaction,
          LedgerPermission.viewBudget,
          LedgerPermission.viewAllTransactions,
          LedgerPermission.viewStatistics,
        };

      case MemberRole.viewer:
        return {
          LedgerPermission.viewAllTransactions,
          LedgerPermission.viewStatistics,
        };
    }
  }

  bool hasPermission(LedgerPermission permission) {
    return permissions.contains(permission);
  }
}

/// 账本成员
class LedgerMember {
  final String id;
  final String userId;
  final String? nickname;         // 在账本中的昵称
  final String? avatarUrl;
  final MemberRole role;
  final DateTime joinedAt;
  final String? invitedBy;        // 邀请人ID
  final MemberSettings settings;  // 个人设置

  LedgerMember({
    String? id,
    required this.userId,
    this.nickname,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
    MemberSettings? settings,
  }) : id = id ?? generateUuid(),
       settings = settings ?? MemberSettings();

  /// 显示名称
  String get displayName => nickname ?? '成员';
}

/// 成员个人设置
class MemberSettings {
  final bool receiveNotifications;   // 接收通知
  final bool showInRanking;          // 显示在排行中
  final VisibilityLevel defaultVisibility;  // 默认可见性

  MemberSettings({
    this.receiveNotifications = true,
    this.showInRanking = true,
    this.defaultVisibility = VisibilityLevel.allMembers,
  });
}
```

#### 13.2.2 邀请机制

```dart
/// 邀请服务
class InvitationService {
  final InvitationRepository _repository;
  final LedgerService _ledgerService;
  final NotificationService _notificationService;

  /// 创建邀请链接
  Future<Invitation> createInvitation({
    required String ledgerId,
    MemberRole role = MemberRole.member,
    Duration? expiresIn,
    int? maxUses,
  }) async {
    final ledger = await _ledgerService.getLedger(ledgerId);
    final userId = AuthService().currentUserId;

    // 检查权限
    if (!ledger.hasPermission(userId, LedgerPermission.inviteMember)) {
      throw NoPermissionException('无权邀请成员');
    }

    final invitation = Invitation(
      id: generateUuid(),
      ledgerId: ledgerId,
      ledgerName: ledger.name,
      inviterId: userId,
      role: role,
      createdAt: DateTime.now(),
      expiresAt: expiresIn != null
          ? DateTime.now().add(expiresIn)
          : DateTime.now().add(const Duration(days: 7)),
      maxUses: maxUses,
      usedCount: 0,
      status: InvitationStatus.active,
    );

    await _repository.create(invitation);
    return invitation;
  }

  /// 生成邀请二维码数据
  String generateQRCodeData(Invitation invitation) {
    return 'aibook://invite/${invitation.id}';
  }

  /// 生成分享文案
  String generateShareText(Invitation invitation) {
    return '邀请你加入 \${invitation.ledgerName} 账本\\n\\n'
        '点击链接加入：https://aibook.app/invite/\${invitation.id}\\n\\n'
        '或在AI记账App中扫描二维码加入';
  }

  /// 接受邀请
  Future<void> acceptInvitation(String invitationId) async {
    final invitation = await _repository.getById(invitationId);
    if (invitation == null) {
      throw InvitationNotFoundException();
    }

    // 验证邀请有效性
    _validateInvitation(invitation);

    final userId = AuthService().currentUserId;

    // 检查是否已是成员
    final ledger = await _ledgerService.getLedger(invitation.ledgerId);
    if (ledger.members.any((m) => m.userId == userId)) {
      throw AlreadyMemberException();
    }

    // 添加成员
    final member = LedgerMember(
      userId: userId,
      role: invitation.role,
      joinedAt: DateTime.now(),
      invitedBy: invitation.inviterId,
    );

    await _ledgerService.addMember(invitation.ledgerId, member);

    // 更新邀请使用次数
    await _repository.incrementUsedCount(invitationId);

    // 通知邀请人
    await _notificationService.send(
      invitation.inviterId,
      NotificationType.memberJoined,
      {
        'ledgerName': invitation.ledgerName,
        'memberName': AuthService().currentUser?.displayName,
      },
    );
  }

  void _validateInvitation(Invitation invitation) {
    if (invitation.status != InvitationStatus.active) {
      throw InvitationExpiredException();
    }

    if (invitation.expiresAt.isBefore(DateTime.now())) {
      throw InvitationExpiredException();
    }

    if (invitation.maxUses != null &&
        invitation.usedCount >= invitation.maxUses!) {
      throw InvitationExhaustedException();
    }
  }
}

/// 邀请实体
class Invitation {
  final String id;
  final String ledgerId;
  final String ledgerName;
  final String inviterId;
  final MemberRole role;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int? maxUses;
  final int usedCount;
  final InvitationStatus status;

  Invitation({
    required this.id,
    required this.ledgerId,
    required this.ledgerName,
    required this.inviterId,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    this.maxUses,
    required this.usedCount,
    required this.status,
  });

  bool get isValid =>
      status == InvitationStatus.active &&
      expiresAt.isAfter(DateTime.now()) &&
      (maxUses == null || usedCount < maxUses!);
}

enum InvitationStatus {
  active,
  expired,
  revoked,
}
```

### 13.3 家庭预算协作

#### 13.3.1 家庭预算分配模型

```dart
/// 家庭预算分配策略
enum FamilyBudgetStrategy {
  unified,      // 统一预算：家庭共用一个预算池
  perMember,    // 成员配额：每个成员有独立配额
  perCategory,  // 分类负责：不同成员负责不同分类
  hybrid,       // 混合模式：部分统一+部分独立
}

/// 家庭预算
class FamilyBudget {
  final String id;
  final String ledgerId;
  final String period;            // 预算周期 (2026-01)
  final FamilyBudgetStrategy strategy;
  final double totalBudget;       // 总预算
  final Map<String, MemberBudget> memberBudgets;  // 成员预算
  final Map<String, CategoryBudget> categoryBudgets;  // 分类预算
  final FamilyBudgetRules rules;

  FamilyBudget({
    required this.id,
    required this.ledgerId,
    required this.period,
    required this.strategy,
    required this.totalBudget,
    required this.memberBudgets,
    required this.categoryBudgets,
    required this.rules,
  });

  /// 获取成员剩余预算
  double getMemberRemaining(String userId) {
    final memberBudget = memberBudgets[userId];
    if (memberBudget == null) return 0;
    return memberBudget.allocated - memberBudget.spent;
  }

  /// 获取家庭总体剩余
  double get totalRemaining {
    final totalSpent = memberBudgets.values
        .fold(0.0, (sum, m) => sum + m.spent);
    return totalBudget - totalSpent;
  }

  /// 获取预算使用百分比
  double get usagePercentage {
    if (totalBudget == 0) return 0;
    return (totalBudget - totalRemaining) / totalBudget * 100;
  }
}

/// 成员预算
class MemberBudget {
  final String memberId;
  final double allocated;         // 分配额度
  final double spent;             // 已使用
  final Map<String, double> categorySpent;  // 各分类支出

  MemberBudget({
    required this.memberId,
    required this.allocated,
    required this.spent,
    required this.categorySpent,
  });

  double get remaining => allocated - spent;
  double get usagePercentage => allocated > 0 ? spent / allocated * 100 : 0;
}

/// 家庭预算规则
class FamilyBudgetRules {
  final bool allowOverspend;          // 允许超支
  final double? overspendLimit;       // 超支上限
  final bool requireApprovalForLarge; // 大额支出需审批
  final double? largeExpenseThreshold;// 大额支出阈值
  final bool notifyOnThreshold;       // 达到阈值时通知
  final List<int> thresholdPercentages;  // 通知阈值 [50, 80, 100]

  FamilyBudgetRules({
    this.allowOverspend = false,
    this.overspendLimit,
    this.requireApprovalForLarge = false,
    this.largeExpenseThreshold,
    this.notifyOnThreshold = true,
    this.thresholdPercentages = const [50, 80, 100],
  });
}
```

#### 13.3.2 家庭预算服务

```dart
/// 家庭预算服务
class FamilyBudgetService {
  final FamilyBudgetRepository _repository;
  final LedgerService _ledgerService;
  final NotificationService _notificationService;

  /// 创建家庭预算
  Future<FamilyBudget> createBudget({
    required String ledgerId,
    required String period,
    required double totalBudget,
    required FamilyBudgetStrategy strategy,
    Map<String, double>? memberAllocations,
    Map<String, double>? categoryAllocations,
    FamilyBudgetRules? rules,
  }) async {
    final ledger = await _ledgerService.getLedger(ledgerId);

    // 根据策略初始化成员预算
    final memberBudgets = <String, MemberBudget>{};

    switch (strategy) {
      case FamilyBudgetStrategy.unified:
        // 统一预算：所有成员共享
        for (final member in ledger.members) {
          memberBudgets[member.userId] = MemberBudget(
            memberId: member.userId,
            allocated: totalBudget,  // 共享总额
            spent: 0,
            categorySpent: {},
          );
        }
        break;

      case FamilyBudgetStrategy.perMember:
        // 成员配额：按分配比例
        if (memberAllocations == null) {
          // 平均分配
          final perMember = totalBudget / ledger.members.length;
          for (final member in ledger.members) {
            memberBudgets[member.userId] = MemberBudget(
              memberId: member.userId,
              allocated: perMember,
              spent: 0,
              categorySpent: {},
            );
          }
        } else {
          for (final entry in memberAllocations.entries) {
            memberBudgets[entry.key] = MemberBudget(
              memberId: entry.key,
              allocated: entry.value,
              spent: 0,
              categorySpent: {},
            );
          }
        }
        break;

      // ... 其他策略
    }

    final budget = FamilyBudget(
      id: generateUuid(),
      ledgerId: ledgerId,
      period: period,
      strategy: strategy,
      totalBudget: totalBudget,
      memberBudgets: memberBudgets,
      categoryBudgets: {},
      rules: rules ?? FamilyBudgetRules(),
    );

    await _repository.create(budget);

    // 通知所有成员
    await _notifyBudgetCreated(ledger, budget);

    return budget;
  }

  /// 记录支出时更新预算
  Future<BudgetUpdateResult> recordExpense({
    required String ledgerId,
    required String memberId,
    required double amount,
    required String categoryId,
  }) async {
    final budget = await _repository.getCurrentBudget(ledgerId);
    if (budget == null) {
      return BudgetUpdateResult(success: true, alerts: []);
    }

    final memberBudget = budget.memberBudgets[memberId];
    if (memberBudget == null) {
      return BudgetUpdateResult(success: true, alerts: []);
    }

    // 更新支出
    final newSpent = memberBudget.spent + amount;
    final newCategorySpent = Map<String, double>.from(memberBudget.categorySpent);
    newCategorySpent[categoryId] = (newCategorySpent[categoryId] ?? 0) + amount;

    await _repository.updateMemberSpent(
      budget.id,
      memberId,
      newSpent,
      newCategorySpent,
    );

    // 检查预算告警
    final alerts = await _checkBudgetAlerts(budget, memberId, newSpent);

    return BudgetUpdateResult(
      success: true,
      alerts: alerts,
      newRemaining: memberBudget.allocated - newSpent,
    );
  }

  /// 检查预算告警
  Future<List<BudgetAlert>> _checkBudgetAlerts(
    FamilyBudget budget,
    String memberId,
    double newSpent,
  ) async {
    final alerts = <BudgetAlert>[];
    final memberBudget = budget.memberBudgets[memberId]!;
    final usagePercent = newSpent / memberBudget.allocated * 100;

    for (final threshold in budget.rules.thresholdPercentages) {
      final previousPercent = memberBudget.spent / memberBudget.allocated * 100;

      // 刚刚越过阈值
      if (previousPercent < threshold && usagePercent >= threshold) {
        final alert = BudgetAlert(
          type: threshold >= 100
              ? BudgetAlertType.exceeded
              : BudgetAlertType.threshold,
          threshold: threshold,
          currentUsage: usagePercent,
          memberId: memberId,
        );
        alerts.add(alert);

        // 发送通知
        if (budget.rules.notifyOnThreshold) {
          await _notifyBudgetAlert(budget, memberId, alert);
        }
      }
    }

    return alerts;
  }

  Future<void> _notifyBudgetAlert(
    FamilyBudget budget,
    String memberId,
    BudgetAlert alert,
  ) async {
    final ledger = await _ledgerService.getLedger(budget.ledgerId);

    // 通知所有管理员
    for (final member in ledger.members) {
      if (member.role == MemberRole.owner ||
          member.role == MemberRole.admin) {
        await _notificationService.send(
          member.userId,
          NotificationType.budgetAlert,
          {
            'ledgerName': ledger.name,
            'alertType': alert.type.name,
            'threshold': alert.threshold,
            'currentUsage': alert.currentUsage.toStringAsFixed(1),
          },
        );
      }
    }
  }
}

/// 预算更新结果
class BudgetUpdateResult {
  final bool success;
  final List<BudgetAlert> alerts;
  final double? newRemaining;

  BudgetUpdateResult({
    required this.success,
    required this.alerts,
    this.newRemaining,
  });
}

/// 预算告警
class BudgetAlert {
  final BudgetAlertType type;
  final int threshold;
  final double currentUsage;
  final String memberId;

  BudgetAlert({
    required this.type,
    required this.threshold,
    required this.currentUsage,
    required this.memberId,
  });
}

enum BudgetAlertType {
  threshold,    // 达到阈值
  exceeded,     // 超支
  largeExpense, // 大额支出
}
```

### 13.4 交易协作与分摊

#### 13.4.1 交易可见性控制

```dart
/// 家庭交易扩展
class FamilyTransaction extends Transaction {
  final String ledgerId;
  final VisibilityLevel visibility;
  final List<String>? visibleToMembers;  // 自定义可见成员
  final SplitInfo? splitInfo;            // 分摊信息

  FamilyTransaction({
    required super.id,
    required super.amount,
    required super.categoryId,
    required super.createdBy,
    required super.createdAt,
    required this.ledgerId,
    this.visibility = VisibilityLevel.allMembers,
    this.visibleToMembers,
    this.splitInfo,
    // ... 其他字段
  });

  /// 检查用户是否可见此交易
  bool isVisibleTo(String userId, MemberRole userRole) {
    // 创建者总是可见
    if (createdBy == userId) return true;

    // 所有者和管理员可见全部
    if (userRole == MemberRole.owner || userRole == MemberRole.admin) {
      return true;
    }

    switch (visibility) {
      case VisibilityLevel.private:
        return false;
      case VisibilityLevel.allMembers:
        return true;
      case VisibilityLevel.adminsOnly:
        return false;
      case VisibilityLevel.custom:
        return visibleToMembers?.contains(userId) ?? false;
    }
  }
}
```

#### 13.4.2 AA分摊系统

```dart
/// 分摊信息
class SplitInfo {
  final SplitType type;
  final List<SplitParticipant> participants;
  final SplitStatus status;

  SplitInfo({
    required this.type,
    required this.participants,
    required this.status,
  });

  /// 获取总金额
  double get totalAmount =>
      participants.fold(0.0, (sum, p) => sum + p.amount);

  /// 获取已结算金额
  double get settledAmount =>
      participants.where((p) => p.isSettled).fold(0.0, (sum, p) => sum + p.amount);

  /// 是否全部结算
  bool get isFullySettled =>
      participants.every((p) => p.isSettled || p.isPayer);
}

/// 分摊类型
enum SplitType {
  equal,        // 平均分摊
  percentage,   // 按比例分摊
  exact,        // 精确金额
  shares,       // 按份数
}

/// 分摊参与者
class SplitParticipant {
  final String memberId;
  final String memberName;
  final double amount;        // 应付金额
  final double? percentage;   // 分摊比例
  final int? shares;          // 份数
  final bool isPayer;         // 是否为付款人
  final bool isSettled;       // 是否已结算
  final DateTime? settledAt;

  SplitParticipant({
    required this.memberId,
    required this.memberName,
    required this.amount,
    this.percentage,
    this.shares,
    this.isPayer = false,
    this.isSettled = false,
    this.settledAt,
  });
}

enum SplitStatus {
  pending,      // 待确认
  confirmed,    // 已确认
  settling,     // 结算中
  settled,      // 已结算
}

/// 分摊服务
class SplitService {
  final TransactionRepository _transactionRepository;
  final NotificationService _notificationService;
  final LedgerService _ledgerService;

  /// 创建分摊交易
  Future<FamilyTransaction> createSplitTransaction({
    required String ledgerId,
    required double totalAmount,
    required String categoryId,
    required String description,
    required SplitType splitType,
    required List<String> participantIds,
    String? payerId,
    Map<String, double>? exactAmounts,
    Map<String, int>? shares,
  }) async {
    final ledger = await _ledgerService.getLedger(ledgerId);
    final currentUserId = AuthService().currentUserId;
    final actualPayerId = payerId ?? currentUserId;

    // 计算每人应付金额
    final participants = _calculateSplit(
      totalAmount: totalAmount,
      splitType: splitType,
      participantIds: participantIds,
      payerId: actualPayerId,
      ledger: ledger,
      exactAmounts: exactAmounts,
      shares: shares,
    );

    final transaction = FamilyTransaction(
      id: generateUuid(),
      amount: totalAmount,
      categoryId: categoryId,
      description: description,
      createdBy: currentUserId,
      createdAt: DateTime.now(),
      ledgerId: ledgerId,
      visibility: VisibilityLevel.allMembers,
      splitInfo: SplitInfo(
        type: splitType,
        participants: participants,
        status: SplitStatus.pending,
      ),
    );

    await _transactionRepository.create(transaction);

    // 通知参与者
    for (final participant in participants) {
      if (!participant.isPayer) {
        await _notificationService.send(
          participant.memberId,
          NotificationType.splitRequest,
          {
            'amount': participant.amount,
            'description': description,
            'payerName': ledger.members
                .firstWhere((m) => m.userId == actualPayerId)
                .displayName,
          },
        );
      }
    }

    return transaction;
  }

  List<SplitParticipant> _calculateSplit({
    required double totalAmount,
    required SplitType splitType,
    required List<String> participantIds,
    required String payerId,
    required Ledger ledger,
    Map<String, double>? exactAmounts,
    Map<String, int>? shares,
  }) {
    final participants = <SplitParticipant>[];

    switch (splitType) {
      case SplitType.equal:
        final perPerson = totalAmount / participantIds.length;
        for (final id in participantIds) {
          final member = ledger.members.firstWhere((m) => m.userId == id);
          participants.add(SplitParticipant(
            memberId: id,
            memberName: member.displayName,
            amount: perPerson,
            percentage: 100 / participantIds.length,
            isPayer: id == payerId,
            isSettled: id == payerId,  // 付款人自动结算
          ));
        }
        break;

      case SplitType.exact:
        for (final id in participantIds) {
          final member = ledger.members.firstWhere((m) => m.userId == id);
          final amount = exactAmounts?[id] ?? 0;
          participants.add(SplitParticipant(
            memberId: id,
            memberName: member.displayName,
            amount: amount,
            isPayer: id == payerId,
            isSettled: id == payerId,
          ));
        }
        break;

      case SplitType.shares:
        final totalShares = shares?.values.fold(0, (a, b) => a + b) ?? participantIds.length;
        for (final id in participantIds) {
          final member = ledger.members.firstWhere((m) => m.userId == id);
          final memberShares = shares?[id] ?? 1;
          final amount = totalAmount * memberShares / totalShares;
          participants.add(SplitParticipant(
            memberId: id,
            memberName: member.displayName,
            amount: amount,
            shares: memberShares,
            isPayer: id == payerId,
            isSettled: id == payerId,
          ));
        }
        break;

      default:
        break;
    }

    return participants;
  }

  /// 确认分摊（参与者确认自己的份额）
  Future<void> confirmSplit(String transactionId, String memberId) async {
    await _transactionRepository.updateSplitParticipantStatus(
      transactionId,
      memberId,
      isSettled: true,
      settledAt: DateTime.now(),
    );

    // 检查是否全部结算
    final transaction = await _transactionRepository.getById(transactionId);
    if (transaction?.splitInfo?.isFullySettled ?? false) {
      await _transactionRepository.updateSplitStatus(
        transactionId,
        SplitStatus.settled,
      );
    }
  }
}
```

### 13.5 家庭统计与报表

#### 13.5.1 家庭财务看板

```dart
/// 家庭财务看板数据
class FamilyDashboardData {
  final String ledgerId;
  final String period;
  final FamilySummary summary;
  final List<MemberContribution> memberContributions;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<TrendPoint> spendingTrend;
  final List<BudgetStatus> budgetStatuses;
  final List<PendingSplit> pendingSplits;

  FamilyDashboardData({
    required this.ledgerId,
    required this.period,
    required this.summary,
    required this.memberContributions,
    required this.categoryBreakdown,
    required this.spendingTrend,
    required this.budgetStatuses,
    required this.pendingSplits,
  });
}

/// 家庭汇总
class FamilySummary {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate;
  final int transactionCount;
  final double avgDailyExpense;

  FamilySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.transactionCount,
    required this.avgDailyExpense,
  });
}

/// 成员贡献
class MemberContribution {
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final double income;
  final double expense;
  final int transactionCount;
  final double contributionPercentage;  // 支出占比
  final List<String> topCategories;     // 主要支出分类

  MemberContribution({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.income,
    required this.expense,
    required this.transactionCount,
    required this.contributionPercentage,
    required this.topCategories,
  });
}

/// 家庭看板服务
class FamilyDashboardService {
  final TransactionRepository _transactionRepository;
  final FamilyBudgetService _budgetService;
  final LedgerService _ledgerService;

  /// 获取家庭看板数据
  Future<FamilyDashboardData> getDashboardData({
    required String ledgerId,
    required String period,
  }) async {
    final ledger = await _ledgerService.getLedger(ledgerId);
    final transactions = await _transactionRepository.getByLedgerAndPeriod(
      ledgerId,
      period,
    );

    // 计算汇总
    final summary = _calculateSummary(transactions);

    // 计算成员贡献
    final memberContributions = _calculateMemberContributions(
      transactions,
      ledger.members,
    );

    // 分类分布
    final categoryBreakdown = _calculateCategoryBreakdown(transactions);

    // 支出趋势
    final spendingTrend = _calculateSpendingTrend(transactions, period);

    // 预算状态
    final budgetStatuses = await _getBudgetStatuses(ledgerId, period);

    // 待处理分摊
    final pendingSplits = await _getPendingSplits(ledgerId);

    return FamilyDashboardData(
      ledgerId: ledgerId,
      period: period,
      summary: summary,
      memberContributions: memberContributions,
      categoryBreakdown: categoryBreakdown,
      spendingTrend: spendingTrend,
      budgetStatuses: budgetStatuses,
      pendingSplits: pendingSplits,
    );
  }

  FamilySummary _calculateSummary(List<FamilyTransaction> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? netSavings / totalIncome * 100 : 0;

    // 计算日均（假设一个月30天）
    final avgDailyExpense = totalExpense / 30;

    return FamilySummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: netSavings,
      savingsRate: savingsRate,
      transactionCount: transactions.length,
      avgDailyExpense: avgDailyExpense,
    );
  }

  List<MemberContribution> _calculateMemberContributions(
    List<FamilyTransaction> transactions,
    List<LedgerMember> members,
  ) {
    final contributions = <String, MemberContribution>{};

    // 初始化所有成员
    for (final member in members) {
      contributions[member.userId] = MemberContribution(
        memberId: member.userId,
        memberName: member.displayName,
        avatarUrl: member.avatarUrl,
        income: 0,
        expense: 0,
        transactionCount: 0,
        contributionPercentage: 0,
        topCategories: [],
      );
    }

    // 统计各成员数据
    final memberCategorySpend = <String, Map<String, double>>{};

    for (final t in transactions) {
      final current = contributions[t.createdBy];
      if (current == null) continue;

      final categorySpend = memberCategorySpend[t.createdBy] ?? {};

      if (t.type == TransactionType.income) {
        contributions[t.createdBy] = MemberContribution(
          memberId: current.memberId,
          memberName: current.memberName,
          avatarUrl: current.avatarUrl,
          income: current.income + t.amount,
          expense: current.expense,
          transactionCount: current.transactionCount + 1,
          contributionPercentage: 0,
          topCategories: current.topCategories,
        );
      } else {
        categorySpend[t.categoryId] = (categorySpend[t.categoryId] ?? 0) + t.amount;
        memberCategorySpend[t.createdBy] = categorySpend;

        contributions[t.createdBy] = MemberContribution(
          memberId: current.memberId,
          memberName: current.memberName,
          avatarUrl: current.avatarUrl,
          income: current.income,
          expense: current.expense + t.amount,
          transactionCount: current.transactionCount + 1,
          contributionPercentage: 0,
          topCategories: current.topCategories,
        );
      }
    }

    // 计算占比和Top分类
    final totalExpense = contributions.values.fold(0.0, (sum, c) => sum + c.expense);

    return contributions.values.map((c) {
      final categorySpend = memberCategorySpend[c.memberId] ?? {};
      final sortedCategories = categorySpend.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategories = sortedCategories.take(3).map((e) => e.key).toList();

      return MemberContribution(
        memberId: c.memberId,
        memberName: c.memberName,
        avatarUrl: c.avatarUrl,
        income: c.income,
        expense: c.expense,
        transactionCount: c.transactionCount,
        contributionPercentage: totalExpense > 0 ? c.expense / totalExpense * 100 : 0,
        topCategories: topCategories,
      );
    }).toList()
      ..sort((a, b) => b.expense.compareTo(a.expense));
  }

  // ... 其他辅助方法
}
```

### 13.6 家庭目标与激励

#### 13.6.1 共同储蓄目标

```dart
/// 家庭储蓄目标
class FamilySavingsGoal {
  final String id;
  final String ledgerId;
  final String name;
  final String? emoji;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final List<GoalContributor> contributors;
  final GoalStatus status;

  FamilySavingsGoal({
    required this.id,
    required this.ledgerId,
    required this.name,
    this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.contributors,
    required this.status,
  });

  double get progressPercentage =>
      targetAmount > 0 ? currentAmount / targetAmount * 100 : 0;

  int? get daysRemaining =>
      deadline?.difference(DateTime.now()).inDays;
}

/// 目标贡献者
class GoalContributor {
  final String memberId;
  final String memberName;
  final double contribution;
  final double percentage;

  GoalContributor({
    required this.memberId,
    required this.memberName,
    required this.contribution,
    required this.percentage,
  });
}

/// 家庭目标服务
class FamilyGoalService {
  final FamilyGoalRepository _repository;
  final NotificationService _notificationService;
  final LedgerService _ledgerService;

  /// 创建家庭目标
  Future<FamilySavingsGoal> createGoal({
    required String ledgerId,
    required String name,
    required double targetAmount,
    String? emoji,
    DateTime? deadline,
  }) async {
    final goal = FamilySavingsGoal(
      id: generateUuid(),
      ledgerId: ledgerId,
      name: name,
      emoji: emoji ?? '🎯',
      targetAmount: targetAmount,
      currentAmount: 0,
      deadline: deadline,
      contributors: [],
      status: GoalStatus.active,
    );

    await _repository.create(goal);

    // 通知所有成员
    final ledger = await _ledgerService.getLedger(ledgerId);
    for (final member in ledger.members) {
      await _notificationService.send(
        member.userId,
        NotificationType.goalCreated,
        {'goalName': name, 'targetAmount': targetAmount},
      );
    }

    return goal;
  }

  /// 贡献金额
  Future<void> contribute({
    required String goalId,
    required double amount,
  }) async {
    final goal = await _repository.getById(goalId);
    if (goal == null) return;

    final userId = AuthService().currentUserId;
    await _repository.addContribution(goalId, userId, amount);

    // 检查是否达成目标
    final newAmount = goal.currentAmount + amount;
    if (newAmount >= goal.targetAmount) {
      await _celebrateGoalAchieved(goal);
    }
  }

  /// 庆祝目标达成
  Future<void> _celebrateGoalAchieved(FamilySavingsGoal goal) async {
    await _repository.updateStatus(goal.id, GoalStatus.achieved);

    final ledger = await _ledgerService.getLedger(goal.ledgerId);
    for (final member in ledger.members) {
      await _notificationService.send(
        member.userId,
        NotificationType.goalAchieved,
        {
          'goalName': goal.name,
          'targetAmount': goal.targetAmount,
          'emoji': goal.emoji,
        },
      );
    }
  }
}

enum GoalStatus {
  active,
  achieved,
  cancelled,
}
```

#### 13.6.2 家庭排行榜与激励

```dart
/// 家庭排行榜
class FamilyLeaderboard {
  final String ledgerId;
  final String period;
  final List<LeaderboardEntry> savingsRanking;      // 储蓄排行
  final List<LeaderboardEntry> recordingRanking;    // 记账勤奋度
  final List<LeaderboardEntry> budgetCompliance;    // 预算遵守度
  final List<AchievementBadge> recentAchievements;  // 近期成就

  FamilyLeaderboard({
    required this.ledgerId,
    required this.period,
    required this.savingsRanking,
    required this.recordingRanking,
    required this.budgetCompliance,
    required this.recentAchievements,
  });
}

/// 排行榜条目
class LeaderboardEntry {
  final int rank;
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final double value;
  final String valueLabel;        // 如 "¥3,200" 或 "98%"
  final int? changeFromLastPeriod;  // 排名变化

  LeaderboardEntry({
    required this.rank,
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.value,
    required this.valueLabel,
    this.changeFromLastPeriod,
  });
}

/// 成就徽章
class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String memberId;
  final String memberName;
  final DateTime earnedAt;

  AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.memberId,
    required this.memberName,
    required this.earnedAt,
  });
}

/// 家庭排行榜服务
class FamilyLeaderboardService {
  final TransactionRepository _transactionRepository;
  final FamilyBudgetService _budgetService;

  /// 获取家庭排行榜
  Future<FamilyLeaderboard> getLeaderboard({
    required String ledgerId,
    required String period,
  }) async {
    // 储蓄排行
    final savingsRanking = await _calculateSavingsRanking(ledgerId, period);

    // 记账勤奋度排行
    final recordingRanking = await _calculateRecordingRanking(ledgerId, period);

    // 预算遵守度排行
    final budgetCompliance = await _calculateBudgetCompliance(ledgerId, period);

    // 近期成就
    final recentAchievements = await _getRecentAchievements(ledgerId);

    return FamilyLeaderboard(
      ledgerId: ledgerId,
      period: period,
      savingsRanking: savingsRanking,
      recordingRanking: recordingRanking,
      budgetCompliance: budgetCompliance,
      recentAchievements: recentAchievements,
    );
  }

  /// 预定义的家庭成就
  static const familyAchievements = [
    {'id': 'first_family_record', 'name': '家庭首账', 'emoji': '👨‍👩‍👧'},
    {'id': 'savings_champion', 'name': '储蓄冠军', 'emoji': '🏆'},
    {'id': 'budget_master', 'name': '预算达人', 'emoji': '📊'},
    {'id': 'recording_streak_7', 'name': '连续记账7天', 'emoji': '🔥'},
    {'id': 'goal_contributor', 'name': '目标贡献者', 'emoji': '🎯'},
    {'id': 'family_saver', 'name': '家庭理财师', 'emoji': '💰'},
  ];

  // ... 辅助方法实现
}
```

### 13.7 数据同步与冲突处理

#### 13.7.1 实时同步机制

```dart
/// 家庭账本同步服务
class FamilyLedgerSyncService {
  final WebSocketService _wsService;
  final LocalDatabase _localDb;
  final ConflictResolver _conflictResolver;

  final StreamController<SyncEvent> _syncEvents = StreamController.broadcast();
  Stream<SyncEvent> get syncEvents => _syncEvents.stream;

  /// 启动账本同步
  Future<void> startSync(String ledgerId) async {
    // 建立WebSocket连接
    await _wsService.connect('/ledger/$ledgerId/sync');

    // 监听远程变更
    _wsService.onMessage.listen((message) {
      _handleRemoteChange(message);
    });

    // 监听本地变更
    _localDb.watchChanges(ledgerId).listen((change) {
      _pushLocalChange(ledgerId, change);
    });
  }

  /// 处理远程变更
  Future<void> _handleRemoteChange(SyncMessage message) async {
    switch (message.type) {
      case SyncMessageType.transactionCreated:
        await _handleTransactionCreated(message.data);
        break;
      case SyncMessageType.transactionUpdated:
        await _handleTransactionUpdated(message.data);
        break;
      case SyncMessageType.transactionDeleted:
        await _handleTransactionDeleted(message.data);
        break;
      case SyncMessageType.memberJoined:
        await _handleMemberJoined(message.data);
        break;
      case SyncMessageType.budgetUpdated:
        await _handleBudgetUpdated(message.data);
        break;
    }

    _syncEvents.add(SyncEvent(
      type: SyncEventType.remoteChange,
      message: message,
    ));
  }

  /// 推送本地变更
  Future<void> _pushLocalChange(String ledgerId, LocalChange change) async {
    try {
      await _wsService.send(SyncMessage(
        type: _mapChangeType(change.type),
        data: change.data,
        timestamp: DateTime.now(),
        clientId: DeviceInfo.deviceId,
      ));
    } catch (e) {
      // 离线时暂存变更
      await _localDb.queuePendingSync(change);
    }
  }

  /// 处理冲突
  Future<void> _handleConflict(
    LocalChange local,
    SyncMessage remote,
  ) async {
    final resolution = await _conflictResolver.resolve(local, remote);

    switch (resolution.strategy) {
      case ConflictStrategy.keepLocal:
        await _pushLocalChange(local.ledgerId, local);
        break;
      case ConflictStrategy.keepRemote:
        await _localDb.applyRemoteChange(remote);
        break;
      case ConflictStrategy.merge:
        await _localDb.applyMergedChange(resolution.mergedData);
        await _pushLocalChange(local.ledgerId, LocalChange(
          type: local.type,
          data: resolution.mergedData,
        ));
        break;
      case ConflictStrategy.askUser:
        _syncEvents.add(SyncEvent(
          type: SyncEventType.conflictDetected,
          conflict: ConflictInfo(local: local, remote: remote),
        ));
        break;
    }
  }
}

/// 冲突解决器
class ConflictResolver {
  /// 解决冲突
  Future<ConflictResolution> resolve(
    LocalChange local,
    SyncMessage remote,
  ) async {
    // 时间戳比较：后者优先
    if (remote.timestamp.isAfter(local.timestamp)) {
      return ConflictResolution(strategy: ConflictStrategy.keepRemote);
    }

    // 如果是同一用户的变更，保留本地
    if (remote.data['userId'] == AuthService().currentUserId) {
      return ConflictResolution(strategy: ConflictStrategy.keepLocal);
    }

    // 尝试自动合并（如金额修改）
    if (_canAutoMerge(local, remote)) {
      final merged = _autoMerge(local.data, remote.data);
      return ConflictResolution(
        strategy: ConflictStrategy.merge,
        mergedData: merged,
      );
    }

    // 无法自动解决，询问用户
    return ConflictResolution(strategy: ConflictStrategy.askUser);
  }

  bool _canAutoMerge(LocalChange local, SyncMessage remote) {
    // 检查是否可以自动合并
    // 例如：不同字段的修改可以合并
    final localFields = local.data['modifiedFields'] as Set<String>?;
    final remoteFields = remote.data['modifiedFields'] as Set<String>?;

    if (localFields == null || remoteFields == null) return false;

    // 如果修改的是不同字段，可以合并
    return localFields.intersection(remoteFields).isEmpty;
  }

  Map<String, dynamic> _autoMerge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = Map<String, dynamic>.from(remote);
    final localFields = local['modifiedFields'] as Set<String>;

    for (final field in localFields) {
      merged[field] = local[field];
    }

    return merged;
  }
}

enum ConflictStrategy {
  keepLocal,
  keepRemote,
  merge,
  askUser,
}

class ConflictResolution {
  final ConflictStrategy strategy;
  final Map<String, dynamic>? mergedData;

  ConflictResolution({
    required this.strategy,
    this.mergedData,
  });
}
```

### 13.8 隐私与安全

#### 13.8.1 家庭账本隐私设计

```dart
/// 家庭隐私设置
class FamilyPrivacySettings {
  final bool allowMembersToSeeEachOther;  // 成员互相可见
  final bool showMemberBalance;           // 显示成员余额
  final bool showMemberIncome;            // 显示成员收入
  final bool allowExportByMembers;        // 允许成员导出数据
  final List<String> hiddenCategories;    // 对普通成员隐藏的分类

  FamilyPrivacySettings({
    this.allowMembersToSeeEachOther = true,
    this.showMemberBalance = false,
    this.showMemberIncome = false,
    this.allowExportByMembers = false,
    this.hiddenCategories = const [],
  });
}

/// 敏感交易保护
class SensitiveTransactionGuard {
  /// 检查交易是否包含敏感信息
  bool isSensitive(Transaction transaction) {
    // 检查分类
    if (_sensitiveCategories.contains(transaction.categoryId)) {
      return true;
    }

    // 检查描述中的敏感词
    if (_containsSensitiveWords(transaction.description)) {
      return true;
    }

    // 检查金额是否异常大
    if (transaction.amount > _largeAmountThreshold) {
      return true;
    }

    return false;
  }

  static const _sensitiveCategories = [
    'medical',      // 医疗
    'gift_private', // 私人礼物
    'investment',   // 投资
  ];

  static const _sensitiveWords = [
    '礼物', '惊喜', '秘密', '私人',
  ];

  static const _largeAmountThreshold = 10000.0;

  bool _containsSensitiveWords(String? text) {
    if (text == null) return false;
    return _sensitiveWords.any((word) => text.contains(word));
  }
}
```

### 13.9 与其他系统的集成

#### 13.9.1 集成点概览

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        家庭账本系统集成点                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐                                                             │
│  │ 家庭账本系统 │                                                             │
│  └──────┬──────┘                                                             │
│         │                                                                    │
│  ┌──────┴──────────────────────────────────────────────────────────────┐    │
│  │                          集成接口层                                   │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │    │
│  │  │ 账本上下文 │ │ 成员上下文│ │ 权限检查  │ │ 数据过滤  │ │ 通知分发  │  │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│         │           │           │           │           │                    │
│         ▼           ▼           ▼           ▼           ▼                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │  钱龄系统 │ │  预算系统 │ │ 习惯培养  │ │ 数据可视化│ │ 语音交互  │          │
│  │  ──────── │ │  ──────── │ │ ──────── │ │  ──────── │ │  ──────── │          │
│  │ 家庭钱龄  │ │ 家庭预算  │ │ 共同目标  │ │ 成员对比  │ │ "家庭支出"│          │
│  │ 统计      │ │ 成员配额  │ │ 排行榜    │ │ 家庭报表  │ │ 语音命令  │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### 13.9.2 统一账本上下文

```dart
/// 账本上下文 - 全局可用，确定当前操作的账本和权限
class LedgerContext {
  static final LedgerContext _instance = LedgerContext._internal();
  factory LedgerContext() => _instance;
  LedgerContext._internal();

  final LedgerService _ledgerService = LedgerService();

  /// 当前账本
  Ledger? get currentLedger => _ledgerService.currentLedger.value;

  /// 当前用户在当前账本的角色
  MemberRole? get currentUserRole {
    final userId = AuthService().currentUserId;
    return currentLedger?.members
        .firstWhereOrNull((m) => m.userId == userId)
        ?.role;
  }

  /// 检查当前用户是否有指定权限
  bool hasPermission(LedgerPermission permission) {
    return currentUserRole?.hasPermission(permission) ?? false;
  }

  /// 是否为共享账本
  bool get isSharedLedger => currentLedger?.isShared ?? false;

  /// 获取当前账本的所有成员
  List<LedgerMember> get members => currentLedger?.members ?? [];

  /// 监听账本变化
  Stream<Ledger?> get ledgerChanges =>
      _ledgerService.currentLedger.asStream();
}

/// 账本感知的服务基类
abstract class LedgerAwareService {
  LedgerContext get ledgerContext => LedgerContext();

  /// 确保有权限执行操作
  void ensurePermission(LedgerPermission permission) {
    if (!ledgerContext.hasPermission(permission)) {
      throw NoPermissionException();
    }
  }

  /// 获取当前账本ID
  String get currentLedgerId {
    final ledger = ledgerContext.currentLedger;
    if (ledger == null) throw NoActiveLedgerException();
    return ledger.id;
  }
}
```

### 13.10 目标达成检测

```dart
/// 家庭账本目标检测服务
class FamilyLedgerGoalChecker implements GoalChecker {
  final LedgerService _ledgerService;
  final FamilyBudgetService _budgetService;
  final FamilyGoalService _goalService;

  @override
  String get goalId => 'family_ledger_effectiveness';

  @override
  Future<GoalCheckResult> check() async {
    final checks = <GoalCheckItem>[];

    // 检查1：家庭账本创建率
    final familyLedgers = await _ledgerService.getFamilyLedgers();
    checks.add(GoalCheckItem(
      name: '家庭账本数',
      target: '>= 1',
      actual: '${familyLedgers.length}',
      passed: familyLedgers.isNotEmpty,
    ));

    // 检查2：成员活跃度
    for (final ledger in familyLedgers) {
      final activeMembers = await _getActiveMembers(ledger.id);
      checks.add(GoalCheckItem(
        name: '${ledger.name} 活跃成员',
        target: '>= 2',
        actual: '$activeMembers',
        passed: activeMembers >= 2,
      ));
    }

    // 检查3：预算遵守率
    final budgetCompliance = await _budgetService.getAverageCompliance();
    checks.add(GoalCheckItem(
      name: '家庭预算遵守率',
      target: '>= 80%',
      actual: '${budgetCompliance.toStringAsFixed(1)}%',
      passed: budgetCompliance >= 80,
    ));

    // 检查4：共同目标达成率
    final goalAchievementRate = await _goalService.getAchievementRate();
    checks.add(GoalCheckItem(
      name: '共同目标达成率',
      target: '>= 70%',
      actual: '${goalAchievementRate.toStringAsFixed(1)}%',
      passed: goalAchievementRate >= 70,
    ));

    return GoalCheckResult(
      goalId: goalId,
      passed: checks.every((c) => c.passed),
      items: checks,
      checkedAt: DateTime.now(),
    );
  }

  Future<int> _getActiveMembers(String ledgerId) async {
    // 统计过去30天有记账行为的成员数
    // ...实现略
    return 0;
  }
}
```

'''

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 在第12章（数据联动与可视化）之后插入新章节
    # 原来的13章及之后需要顺延

    # 找到第13章的位置
    old_ch13 = '## 13. 地理位置智能化应用'
    insert_pos = content.find(old_ch13)

    if insert_pos == -1:
        print("❌ 未找到第13章位置")
        return

    # 插入新章节
    content = content[:insert_pos] + FAMILY_CHAPTER + '\n\n' + content[insert_pos:]
    print("✅ 插入家庭账本章节")

    # 更新后续章节编号：13->14, 14->15, ..., 26->27
    chapter_updates = [
        ('## 13. 地理位置智能化应用', '## 14. 地理位置智能化应用'),
        ('## 14. 技术架构设计', '## 15. 技术架构设计'),
        ('## 15. 智能化技术方案', '## 16. 智能化技术方案'),
        ('## 16. 自学习与协同学习系统', '## 17. 自学习与协同学习系统'),
        ('## 17. 智能语音交互系统', '## 18. 智能语音交互系统'),
        ('## 18. 性能设计与优化', '## 19. 性能设计与优化'),
        ('## 19. 用户体验设计', '## 20. 用户体验设计'),
        ('## 20. 国际化与本地化', '## 21. 国际化与本地化'),
        ('## 21. 安全与隐私', '## 22. 安全与隐私'),
        ('## 22. 异常处理与容错设计', '## 23. 异常处理与容错设计'),
        ('## 23. 可扩展性与演进架构', '## 24. 可扩展性与演进架构'),
        ('## 24. 可观测性与监控', '## 25. 可观测性与监控'),
        ('## 25. 版本迁移策略', '## 26. 版本迁移策略'),
        ('## 26. 实施路线图', '## 27. 实施路线图'),
    ]

    for old, new in chapter_updates:
        content = content.replace(old, new)
        print(f"✅ {old} -> {new}")

    # 保存
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n✅ 家庭账本章节添加完成！")
    print("   - 新增：第13章 家庭账本与多成员管理系统")
    print("   - 原13-26章顺延为14-27章")

if __name__ == '__main__':
    main()
