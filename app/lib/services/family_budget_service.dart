import '../models/budget_vault.dart';
import 'vault_repository.dart';

/// 家庭成员角色
enum FamilyRole {
  /// 户主（管理员）
  owner,

  /// 配偶
  spouse,

  /// 子女
  child,

  /// 父母
  parent,

  /// 其他成员
  other,
}

extension FamilyRoleExtension on FamilyRole {
  String get displayName {
    switch (this) {
      case FamilyRole.owner:
        return '户主';
      case FamilyRole.spouse:
        return '配偶';
      case FamilyRole.child:
        return '子女';
      case FamilyRole.parent:
        return '父母';
      case FamilyRole.other:
        return '其他成员';
    }
  }

  /// 默认权限级别（1-10）
  int get defaultPermissionLevel {
    switch (this) {
      case FamilyRole.owner:
        return 10;
      case FamilyRole.spouse:
        return 8;
      case FamilyRole.parent:
        return 6;
      case FamilyRole.child:
        return 4;
      case FamilyRole.other:
        return 2;
    }
  }
}

/// 家庭成员
class FamilyMember {
  final String id;
  final String name;
  final String? avatarUrl;
  final FamilyRole role;
  final int permissionLevel;
  final double? monthlyQuota; // 月度配额
  final double spentThisMonth; // 本月已花费
  final bool isActive;
  final DateTime joinedAt;

  const FamilyMember({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.permissionLevel,
    this.monthlyQuota,
    this.spentThisMonth = 0,
    this.isActive = true,
    required this.joinedAt,
  });

  /// 剩余配额
  double? get remainingQuota =>
      monthlyQuota != null ? monthlyQuota! - spentThisMonth : null;

  /// 配额使用率
  double? get quotaUsageRate =>
      monthlyQuota != null && monthlyQuota! > 0
          ? spentThisMonth / monthlyQuota!
          : null;

  /// 是否超配额
  bool get isOverQuota =>
      monthlyQuota != null && spentThisMonth > monthlyQuota!;

  FamilyMember copyWith({
    String? name,
    FamilyRole? role,
    int? permissionLevel,
    double? monthlyQuota,
    double? spentThisMonth,
    bool? isActive,
  }) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl,
      role: role ?? this.role,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      monthlyQuota: monthlyQuota ?? this.monthlyQuota,
      spentThisMonth: spentThisMonth ?? this.spentThisMonth,
      isActive: isActive ?? this.isActive,
      joinedAt: joinedAt,
    );
  }
}

/// 共享小金库配置
class SharedVaultConfig {
  final String vaultId;
  final List<String> memberIds; // 可访问的成员ID列表
  final Map<String, double> memberQuotas; // 成员配额
  final bool requireApproval; // 大额支出是否需要审批
  final double approvalThreshold; // 审批阈值
  final bool notifyOnSpending; // 消费时是否通知其他成员

  const SharedVaultConfig({
    required this.vaultId,
    required this.memberIds,
    this.memberQuotas = const {},
    this.requireApproval = false,
    this.approvalThreshold = 500,
    this.notifyOnSpending = true,
  });
}

/// 家庭预算概览
class FamilyBudgetOverview {
  final double totalFamilyBudget;
  final double totalFamilySpent;
  final Map<String, double> memberSpending; // 成员ID -> 消费金额
  final List<BudgetVault> sharedVaults;
  final List<BudgetVault> personalVaults;
  final List<FamilyMember> members;
  final DateTime periodStart;
  final DateTime periodEnd;

  const FamilyBudgetOverview({
    required this.totalFamilyBudget,
    required this.totalFamilySpent,
    required this.memberSpending,
    required this.sharedVaults,
    required this.personalVaults,
    required this.members,
    required this.periodStart,
    required this.periodEnd,
  });

  /// 家庭储蓄率
  double get familySavingsRate =>
      totalFamilyBudget > 0
          ? (totalFamilyBudget - totalFamilySpent) / totalFamilyBudget
          : 0;

  /// 获取成员消费占比
  Map<String, double> get memberSpendingRates {
    if (totalFamilySpent == 0) return {};
    return memberSpending.map(
      (memberId, amount) => MapEntry(memberId, amount / totalFamilySpent),
    );
  }
}

/// 成员配额分配结果
class QuotaAllocationResult {
  final Map<String, double> allocations; // 成员ID -> 分配金额
  final double totalAllocated;
  final double remaining;
  final List<String> warnings;

  const QuotaAllocationResult({
    required this.allocations,
    required this.totalAllocated,
    required this.remaining,
    this.warnings = const [],
  });
}

/// 支出审批请求
class SpendingApprovalRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String vaultId;
  final String vaultName;
  final double amount;
  final String description;
  final DateTime requestedAt;
  final ApprovalStatus status;
  final String? approverId;
  final DateTime? respondedAt;
  final String? responseNote;

  const SpendingApprovalRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.vaultId,
    required this.vaultName,
    required this.amount,
    required this.description,
    required this.requestedAt,
    required this.status,
    this.approverId,
    this.respondedAt,
    this.responseNote,
  });
}

/// 审批状态
enum ApprovalStatus {
  pending,
  approved,
  rejected,
  expired,
}

/// 家庭共享预算管理服务
///
/// 支持家庭成员共享预算、配额分配、支出审批等功能
class FamilyBudgetService {
  final VaultRepository _vaultRepo;

  // 内存存储（实际应用中应使用数据库）
  final List<FamilyMember> _members = [];
  final Map<String, SharedVaultConfig> _sharedConfigs = {};
  final List<SpendingApprovalRequest> _approvalRequests = [];

  FamilyBudgetService(this._vaultRepo);

  // ==================== 成员管理 ====================

  /// 添加家庭成员
  Future<FamilyMember> addMember({
    required String name,
    required FamilyRole role,
    double? monthlyQuota,
  }) async {
    final member = FamilyMember(
      id: 'member_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      role: role,
      permissionLevel: role.defaultPermissionLevel,
      monthlyQuota: monthlyQuota,
      joinedAt: DateTime.now(),
    );

    _members.add(member);
    return member;
  }

  /// 更新成员信息
  Future<FamilyMember?> updateMember(
    String memberId, {
    String? name,
    FamilyRole? role,
    double? monthlyQuota,
    bool? isActive,
  }) async {
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index < 0) return null;

    final updated = _members[index].copyWith(
      name: name,
      role: role,
      monthlyQuota: monthlyQuota,
      isActive: isActive,
    );

    _members[index] = updated;
    return updated;
  }

  /// 获取所有成员
  Future<List<FamilyMember>> getMembers() async {
    return List.unmodifiable(_members);
  }

  /// 获取活跃成员
  Future<List<FamilyMember>> getActiveMembers() async {
    return _members.where((m) => m.isActive).toList();
  }

  // ==================== 共享小金库管理 ====================

  /// 设置小金库为共享
  Future<void> setVaultShared({
    required String vaultId,
    required List<String> memberIds,
    Map<String, double>? memberQuotas,
    bool requireApproval = false,
    double approvalThreshold = 500,
  }) async {
    _sharedConfigs[vaultId] = SharedVaultConfig(
      vaultId: vaultId,
      memberIds: memberIds,
      memberQuotas: memberQuotas ?? {},
      requireApproval: requireApproval,
      approvalThreshold: approvalThreshold,
    );
  }

  /// 取消小金库共享
  Future<void> unsetVaultShared(String vaultId) async {
    _sharedConfigs.remove(vaultId);
  }

  /// 获取成员可访问的小金库
  Future<List<BudgetVault>> getAccessibleVaults(String memberId) async {
    final allVaults = await _vaultRepo.getEnabled();
    final accessibleVaults = <BudgetVault>[];

    for (final vault in allVaults) {
      final config = _sharedConfigs[vault.id];

      // 如果没有共享配置，检查是否是该成员的个人小金库
      if (config == null) {
        // 假设没有特殊标记的都是户主的个人小金库
        final member = _members.firstWhere(
          (m) => m.id == memberId,
          orElse: () => FamilyMember(
            id: memberId,
            name: '',
            role: FamilyRole.other,
            permissionLevel: 0,
            joinedAt: DateTime.now(),
          ),
        );
        if (member.role == FamilyRole.owner) {
          accessibleVaults.add(vault);
        }
      } else if (config.memberIds.contains(memberId)) {
        // 在共享成员列表中
        accessibleVaults.add(vault);
      }
    }

    return accessibleVaults;
  }

  /// 获取共享小金库
  Future<List<BudgetVault>> getSharedVaults() async {
    final allVaults = await _vaultRepo.getEnabled();
    return allVaults.where((v) => _sharedConfigs.containsKey(v.id)).toList();
  }

  // ==================== 配额管理 ====================

  /// 分配成员配额
  Future<QuotaAllocationResult> allocateMemberQuotas({
    required double totalBudget,
    required Map<String, double> quotaRatios, // 成员ID -> 分配比例
  }) async {
    final allocations = <String, double>{};
    var totalAllocated = 0.0;
    final warnings = <String>[];

    // 按比例分配
    for (final entry in quotaRatios.entries) {
      final memberId = entry.key;
      final ratio = entry.value;

      final allocated = totalBudget * ratio;
      allocations[memberId] = allocated;
      totalAllocated += allocated;

      // 更新成员配额
      final memberIndex = _members.indexWhere((m) => m.id == memberId);
      if (memberIndex >= 0) {
        _members[memberIndex] = _members[memberIndex].copyWith(
          monthlyQuota: allocated,
          spentThisMonth: 0, // 重置消费
        );
      }
    }

    final remaining = totalBudget - totalAllocated;
    if (remaining > totalBudget * 0.01) {
      warnings.add('还有¥${remaining.toStringAsFixed(0)}未分配');
    }

    return QuotaAllocationResult(
      allocations: allocations,
      totalAllocated: totalAllocated,
      remaining: remaining,
      warnings: warnings,
    );
  }

  /// 检查成员是否可以消费
  Future<MemberSpendingCheck> checkMemberSpending({
    required String memberId,
    required String vaultId,
    required double amount,
  }) async {
    final member = _members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => throw Exception('成员不存在'),
    );

    final vault = await _vaultRepo.getById(vaultId);
    if (vault == null) {
      return MemberSpendingCheck.denied('小金库不存在');
    }

    // 检查是否有访问权限
    final config = _sharedConfigs[vaultId];
    if (config != null && !config.memberIds.contains(memberId)) {
      return MemberSpendingCheck.denied('您没有该小金库的访问权限');
    }

    // 检查个人配额
    if (member.monthlyQuota != null) {
      if (member.spentThisMonth + amount > member.monthlyQuota!) {
        return MemberSpendingCheck.denied(
          '超出个人月度配额，剩余¥${member.remainingQuota?.toStringAsFixed(0)}',
        );
      }
    }

    // 检查小金库成员配额
    if (config != null && config.memberQuotas.containsKey(memberId)) {
      // ignore: unused_local_variable
      final vaultQuota = config.memberQuotas[memberId]!;
      // 需要追踪该成员在该小金库的消费，这里简化处理
    }

    // 检查是否需要审批
    if (config != null &&
        config.requireApproval &&
        amount >= config.approvalThreshold) {
      return MemberSpendingCheck.needsApproval(
        '金额超过¥${config.approvalThreshold.toStringAsFixed(0)}，需要审批',
      );
    }

    // 检查小金库余额
    if (amount > vault.available) {
      return MemberSpendingCheck.denied(
        '${vault.name}余额不足，可用¥${vault.available.toStringAsFixed(0)}',
      );
    }

    return MemberSpendingCheck.allowed();
  }

  /// 记录成员消费
  Future<void> recordMemberSpending({
    required String memberId,
    required double amount,
  }) async {
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index >= 0) {
      _members[index] = _members[index].copyWith(
        spentThisMonth: _members[index].spentThisMonth + amount,
      );
    }
  }

  // ==================== 审批管理 ====================

  /// 创建支出审批请求
  Future<SpendingApprovalRequest> createApprovalRequest({
    required String requesterId,
    required String vaultId,
    required double amount,
    required String description,
  }) async {
    final requester = _members.firstWhere((m) => m.id == requesterId);
    final vault = await _vaultRepo.getById(vaultId);

    final request = SpendingApprovalRequest(
      id: 'approval_${DateTime.now().millisecondsSinceEpoch}',
      requesterId: requesterId,
      requesterName: requester.name,
      vaultId: vaultId,
      vaultName: vault?.name ?? '未知',
      amount: amount,
      description: description,
      requestedAt: DateTime.now(),
      status: ApprovalStatus.pending,
    );

    _approvalRequests.add(request);
    return request;
  }

  /// 审批支出请求
  Future<SpendingApprovalRequest?> respondToApproval({
    required String requestId,
    required String approverId,
    required bool approved,
    String? note,
  }) async {
    final index = _approvalRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) return null;

    final request = _approvalRequests[index];
    final updated = SpendingApprovalRequest(
      id: request.id,
      requesterId: request.requesterId,
      requesterName: request.requesterName,
      vaultId: request.vaultId,
      vaultName: request.vaultName,
      amount: request.amount,
      description: request.description,
      requestedAt: request.requestedAt,
      status: approved ? ApprovalStatus.approved : ApprovalStatus.rejected,
      approverId: approverId,
      respondedAt: DateTime.now(),
      responseNote: note,
    );

    _approvalRequests[index] = updated;
    return updated;
  }

  /// 获取待审批请求
  Future<List<SpendingApprovalRequest>> getPendingApprovals({
    String? approverId,
  }) async {
    return _approvalRequests
        .where((r) => r.status == ApprovalStatus.pending)
        .toList();
  }

  // ==================== 概览和统计 ====================

  /// 获取家庭预算概览
  Future<FamilyBudgetOverview> getFamilyOverview() async {
    final allVaults = await _vaultRepo.getEnabled();
    final sharedVaults = await getSharedVaults();
    final personalVaults = allVaults
        .where((v) => !_sharedConfigs.containsKey(v.id))
        .toList();

    final totalBudget = allVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final totalSpent = allVaults.fold(0.0, (sum, v) => sum + v.spentAmount);

    final memberSpending = <String, double>{};
    for (final member in _members) {
      memberSpending[member.id] = member.spentThisMonth;
    }

    final now = DateTime.now();

    return FamilyBudgetOverview(
      totalFamilyBudget: totalBudget,
      totalFamilySpent: totalSpent,
      memberSpending: memberSpending,
      sharedVaults: sharedVaults,
      personalVaults: personalVaults,
      members: List.unmodifiable(_members),
      periodStart: DateTime(now.year, now.month, 1),
      periodEnd: DateTime(now.year, now.month + 1, 0),
    );
  }

  /// 获取成员消费排行
  Future<List<MemberSpendingRank>> getMemberSpendingRanks() async {
    final ranks = <MemberSpendingRank>[];

    final sortedMembers = List<FamilyMember>.from(_members)
      ..sort((a, b) => b.spentThisMonth.compareTo(a.spentThisMonth));

    for (var i = 0; i < sortedMembers.length; i++) {
      final member = sortedMembers[i];
      ranks.add(MemberSpendingRank(
        rank: i + 1,
        member: member,
        spentAmount: member.spentThisMonth,
        quotaUsageRate: member.quotaUsageRate,
      ));
    }

    return ranks;
  }

  /// 重置月度数据
  Future<void> resetMonthlyData() async {
    for (var i = 0; i < _members.length; i++) {
      _members[i] = _members[i].copyWith(spentThisMonth: 0);
    }
  }
}

/// 成员消费检查结果
class MemberSpendingCheck {
  final bool allowed;
  final bool needsApproval;
  final String? message;

  const MemberSpendingCheck._({
    required this.allowed,
    required this.needsApproval,
    this.message,
  });

  factory MemberSpendingCheck.allowed() {
    return const MemberSpendingCheck._(
      allowed: true,
      needsApproval: false,
    );
  }

  factory MemberSpendingCheck.denied(String message) {
    return MemberSpendingCheck._(
      allowed: false,
      needsApproval: false,
      message: message,
    );
  }

  factory MemberSpendingCheck.needsApproval(String message) {
    return MemberSpendingCheck._(
      allowed: false,
      needsApproval: true,
      message: message,
    );
  }
}

/// 成员消费排名
class MemberSpendingRank {
  final int rank;
  final FamilyMember member;
  final double spentAmount;
  final double? quotaUsageRate;

  const MemberSpendingRank({
    required this.rank,
    required this.member,
    required this.spentAmount,
    this.quotaUsageRate,
  });
}
