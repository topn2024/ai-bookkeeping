import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

// ============== 成员管理 Provider ==============

class MemberState {
  final List<LedgerMember> members;
  final List<MemberInvite> invites;
  final List<MemberBudget> budgets;
  final List<ExpenseApproval> approvals;
  final bool isLoading;

  const MemberState({
    this.members = const [],
    this.invites = const [],
    this.budgets = const [],
    this.approvals = const [],
    this.isLoading = false,
  });

  MemberState copyWith({
    List<LedgerMember>? members,
    List<MemberInvite>? invites,
    List<MemberBudget>? budgets,
    List<ExpenseApproval>? approvals,
    bool? isLoading,
  }) {
    return MemberState(
      members: members ?? this.members,
      invites: invites ?? this.invites,
      budgets: budgets ?? this.budgets,
      approvals: approvals ?? this.approvals,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MemberNotifier extends Notifier<MemberState> {
  /// 数据库服务实例（通过服务定位器获取）
  IDatabaseService get _db => sl<IDatabaseService>();

  @override
  MemberState build() {
    Future.microtask(() => _loadData());
    return const MemberState(isLoading: true);
  }

  Future<void> _loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      final members = await _db.getLedgerMembers();
      final invites = await _db.getMemberInvites();
      final budgets = await _db.getMemberBudgets();
      final approvals = await _db.getExpenseApprovals();
      state = state.copyWith(
        members: members,
        invites: invites,
        budgets: budgets,
        approvals: approvals,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await _loadData();
  }

  // ============== 成员管理 ==============

  /// 获取账本的所有成员
  List<LedgerMember> getMembersForLedger(String ledgerId) {
    return state.members.where((m) => m.ledgerId == ledgerId).toList();
  }

  /// 添加成员
  Future<void> addMember(LedgerMember member) async {
    await _db.insertLedgerMember(member);
    state = state.copyWith(members: [...state.members, member]);
  }

  /// 更新成员角色
  Future<void> updateMemberRole(String memberId, MemberRole newRole) async {
    final member = state.members.firstWhere((m) => m.id == memberId);
    final updated = member.copyWith(role: newRole);
    await _db.updateLedgerMember(updated);
    state = state.copyWith(
      members: state.members.map((m) => m.id == memberId ? updated : m).toList(),
    );
  }

  /// 移除成员
  Future<void> removeMember(String memberId) async {
    await _db.deleteLedgerMember(memberId);
    state = state.copyWith(
      members: state.members.where((m) => m.id != memberId).toList(),
    );
  }

  /// 停用成员
  Future<void> deactivateMember(String memberId) async {
    final member = state.members.firstWhere((m) => m.id == memberId);
    final updated = member.copyWith(isActive: false);
    await _db.updateLedgerMember(updated);
    state = state.copyWith(
      members: state.members.map((m) => m.id == memberId ? updated : m).toList(),
    );
  }

  /// 激活成员
  Future<void> activateMember(String memberId) async {
    final member = state.members.firstWhere((m) => m.id == memberId);
    final updated = member.copyWith(isActive: true);
    await _db.updateLedgerMember(updated);
    state = state.copyWith(
      members: state.members.map((m) => m.id == memberId ? updated : m).toList(),
    );
  }

  // ============== 邀请管理 ==============

  /// 生成邀请码
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 创建邀请
  Future<MemberInvite> createInvite({
    required String ledgerId,
    required String ledgerName,
    required String inviterId,
    required String inviterName,
    String? inviteeEmail,
    required MemberRole role,
    int expirationDays = 7,
  }) async {
    final invite = MemberInvite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ledgerId: ledgerId,
      ledgerName: ledgerName,
      inviterId: inviterId,
      inviterName: inviterName,
      inviteeEmail: inviteeEmail,
      inviteCode: _generateInviteCode(),
      role: role,
      status: InviteStatus.pending,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: expirationDays)),
    );

    await _db.insertMemberInvite(invite);
    state = state.copyWith(invites: [...state.invites, invite]);
    return invite;
  }

  /// 接受邀请
  Future<void> acceptInvite(String inviteId, String userId, String userName) async {
    final invite = state.invites.firstWhere((i) => i.id == inviteId);

    // 更新邀请状态
    final updatedInvite = invite.copyWith(
      status: InviteStatus.accepted,
      respondedAt: DateTime.now(),
    );
    await _db.updateMemberInvite(updatedInvite);

    // 创建成员
    final member = LedgerMember(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ledgerId: invite.ledgerId,
      userId: userId,
      userName: userName,
      userEmail: invite.inviteeEmail,
      role: invite.role,
      joinedAt: DateTime.now(),
    );
    await _db.insertLedgerMember(member);

    state = state.copyWith(
      invites: state.invites.map((i) => i.id == inviteId ? updatedInvite : i).toList(),
      members: [...state.members, member],
    );
  }

  /// 拒绝邀请
  Future<void> rejectInvite(String inviteId) async {
    final invite = state.invites.firstWhere((i) => i.id == inviteId);
    final updated = invite.copyWith(
      status: InviteStatus.rejected,
      respondedAt: DateTime.now(),
    );
    await _db.updateMemberInvite(updated);
    state = state.copyWith(
      invites: state.invites.map((i) => i.id == inviteId ? updated : i).toList(),
    );
  }

  /// 取消邀请
  Future<void> cancelInvite(String inviteId) async {
    await _db.deleteMemberInvite(inviteId);
    state = state.copyWith(
      invites: state.invites.where((i) => i.id != inviteId).toList(),
    );
  }

  /// 通过邀请码查找邀请
  MemberInvite? findInviteByCode(String code) {
    try {
      return state.invites.firstWhere(
        (i) => i.inviteCode == code && i.isPending,
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取待处理的邀请（发送给我的）
  List<MemberInvite> getPendingInvitesForUser(String userId) {
    // 假设inviteeEmail匹配用户
    return state.invites.where((i) => i.isPending).toList();
  }

  /// 获取我发送的邀请
  List<MemberInvite> getSentInvites(String inviterId) {
    return state.invites.where((i) => i.inviterId == inviterId).toList();
  }

  // ============== 预算管理 ==============

  /// 获取成员预算
  MemberBudget? getMemberBudget(String memberId) {
    try {
      return state.budgets.firstWhere((b) => b.memberId == memberId);
    } catch (e) {
      return null;
    }
  }

  /// 设置成员预算
  Future<void> setMemberBudget(MemberBudget budget) async {
    final existing = state.budgets.where((b) => b.memberId == budget.memberId).firstOrNull;

    if (existing != null) {
      await _db.updateMemberBudget(budget);
      state = state.copyWith(
        budgets: state.budgets.map((b) => b.memberId == budget.memberId ? budget : b).toList(),
      );
    } else {
      await _db.insertMemberBudget(budget);
      state = state.copyWith(budgets: [...state.budgets, budget]);
    }
  }

  /// 更新成员已花费金额
  Future<void> updateMemberSpent(String memberId, double spent) async {
    final budget = state.budgets.firstWhere((b) => b.memberId == memberId);
    final updated = budget.copyWith(
      currentSpent: spent,
      updatedAt: DateTime.now(),
    );
    await _db.updateMemberBudget(updated);
    state = state.copyWith(
      budgets: state.budgets.map((b) => b.memberId == memberId ? updated : b).toList(),
    );
  }

  /// 删除成员预算
  Future<void> deleteMemberBudget(String budgetId) async {
    await _db.deleteMemberBudget(budgetId);
    state = state.copyWith(
      budgets: state.budgets.where((b) => b.id != budgetId).toList(),
    );
  }

  /// 检查是否需要审批
  bool needsApproval(String memberId, double amount) {
    final budget = getMemberBudget(memberId);
    if (budget == null) return false;

    // 检查单笔审批阈值
    if (budget.approvalThreshold > 0 && amount >= budget.approvalThreshold) {
      return true;
    }

    // 检查是否超预算
    if (budget.requireApproval && (budget.currentSpent + amount) > budget.monthlyLimit) {
      return true;
    }

    return false;
  }

  // ============== 审批管理 ==============

  /// 创建审批请求
  Future<ExpenseApproval> createApprovalRequest({
    required String ledgerId,
    required String transactionId,
    required String requesterId,
    required String requesterName,
    required double amount,
    required String category,
    String? note,
  }) async {
    final approval = ExpenseApproval(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ledgerId: ledgerId,
      transactionId: transactionId,
      requesterId: requesterId,
      requesterName: requesterName,
      amount: amount,
      category: category,
      note: note,
      status: ApprovalStatus.pending,
      createdAt: DateTime.now(),
    );

    await _db.insertExpenseApproval(approval);
    state = state.copyWith(approvals: [...state.approvals, approval]);
    return approval;
  }

  /// 批准请求
  Future<void> approveRequest(String approvalId, String approverId, String approverName, {String? comment}) async {
    final approval = state.approvals.firstWhere((a) => a.id == approvalId);
    final updated = approval.copyWith(
      status: ApprovalStatus.approved,
      approverId: approverId,
      approverName: approverName,
      approverComment: comment,
      respondedAt: DateTime.now(),
    );
    await _db.updateExpenseApproval(updated);
    state = state.copyWith(
      approvals: state.approvals.map((a) => a.id == approvalId ? updated : a).toList(),
    );
  }

  /// 拒绝请求
  Future<void> rejectRequest(String approvalId, String approverId, String approverName, {String? comment}) async {
    final approval = state.approvals.firstWhere((a) => a.id == approvalId);
    final updated = approval.copyWith(
      status: ApprovalStatus.rejected,
      approverId: approverId,
      approverName: approverName,
      approverComment: comment,
      respondedAt: DateTime.now(),
    );
    await _db.updateExpenseApproval(updated);
    state = state.copyWith(
      approvals: state.approvals.map((a) => a.id == approvalId ? updated : a).toList(),
    );
  }

  /// 获取待审批列表
  List<ExpenseApproval> getPendingApprovals(String ledgerId) {
    return state.approvals.where((a) =>
      a.ledgerId == ledgerId && a.status == ApprovalStatus.pending
    ).toList();
  }

  /// 获取用户的审批请求
  List<ExpenseApproval> getUserApprovals(String userId) {
    return state.approvals.where((a) => a.requesterId == userId).toList();
  }

  /// 获取账本的所有审批记录
  List<ExpenseApproval> getLedgerApprovals(String ledgerId) {
    return state.approvals.where((a) => a.ledgerId == ledgerId).toList();
  }
}

final memberProvider = NotifierProvider<MemberNotifier, MemberState>(
  MemberNotifier.new,
);

// ============== 便捷 Provider ==============

/// 账本成员列表Provider
final ledgerMembersProvider = Provider.family<List<LedgerMember>, String>((ref, ledgerId) {
  final state = ref.watch(memberProvider);
  return state.members.where((m) => m.ledgerId == ledgerId && m.isActive).toList();
});

/// 待处理邀请数量
final pendingInviteCountProvider = Provider<int>((ref) {
  final state = ref.watch(memberProvider);
  return state.invites.where((i) => i.isPending).length;
});

/// 待审批数量
final pendingApprovalCountProvider = Provider.family<int, String>((ref, ledgerId) {
  final state = ref.watch(memberProvider);
  return state.approvals.where((a) =>
    a.ledgerId == ledgerId && a.status == ApprovalStatus.pending
  ).length;
});

/// 成员预算汇总
class MemberBudgetSummary {
  final int totalMembers;
  final int membersWithBudget;
  final double totalBudget;
  final double totalSpent;
  final int overBudgetCount;

  const MemberBudgetSummary({
    required this.totalMembers,
    required this.membersWithBudget,
    required this.totalBudget,
    required this.totalSpent,
    required this.overBudgetCount,
  });

  double get overallUsagePercent => totalBudget > 0 ? totalSpent / totalBudget : 0;
}

final memberBudgetSummaryProvider = Provider.family<MemberBudgetSummary, String>((ref, ledgerId) {
  final state = ref.watch(memberProvider);
  final members = state.members.where((m) => m.ledgerId == ledgerId && m.isActive).toList();
  final budgets = state.budgets.where((b) => b.ledgerId == ledgerId).toList();

  return MemberBudgetSummary(
    totalMembers: members.length,
    membersWithBudget: budgets.length,
    totalBudget: budgets.fold(0.0, (sum, b) => sum + b.monthlyLimit),
    totalSpent: budgets.fold(0.0, (sum, b) => sum + b.currentSpent),
    overBudgetCount: budgets.where((b) => b.isOverBudget).length,
  );
});
