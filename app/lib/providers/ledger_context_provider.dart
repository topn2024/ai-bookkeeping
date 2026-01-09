import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ledger.dart';
import '../models/member.dart';
import '../services/database_service.dart';

/// 当前账本上下文状态
class LedgerContextState {
  /// 当前选中的账本
  final Ledger? currentLedger;
  /// 当前账本的成员列表
  final List<LedgerMember> members;
  /// 当前用户ID
  final String? currentUserId;
  /// 当前用户在账本中的角色
  final MemberRole? currentUserRole;
  /// 用户拥有的所有账本
  final List<Ledger> userLedgers;
  /// 是否正在加载
  final bool isLoading;
  /// 错误信息
  final String? error;

  const LedgerContextState({
    this.currentLedger,
    this.members = const [],
    this.currentUserId,
    this.currentUserRole,
    this.userLedgers = const [],
    this.isLoading = false,
    this.error,
  });

  /// 当前用户是否为账本所有者
  bool get isOwner => currentUserRole == MemberRole.owner;

  /// 当前用户是否为管理员
  bool get isAdmin =>
      currentUserRole == MemberRole.owner ||
      currentUserRole == MemberRole.admin;

  /// 当前用户是否可以编辑
  bool get canEdit =>
      currentUserRole == MemberRole.owner ||
      currentUserRole == MemberRole.admin ||
      currentUserRole == MemberRole.editor;

  /// 当前用户是否仅有查看权限
  bool get isViewOnly => currentUserRole == MemberRole.viewer;

  /// 是否为共享账本
  bool get isSharedLedger =>
      currentLedger != null && currentLedger!.type.supportsMultipleMembers;

  /// 是否为个人账本
  bool get isPersonalLedger =>
      currentLedger != null && currentLedger!.type == LedgerType.personal;

  /// 当前账本成员数量
  int get memberCount => members.length;

  /// 当前用户的成员信息
  LedgerMember? get currentMember {
    if (currentUserId == null) return null;
    return members.where((m) => m.userId == currentUserId).firstOrNull;
  }

  LedgerContextState copyWith({
    Ledger? currentLedger,
    List<LedgerMember>? members,
    String? currentUserId,
    MemberRole? currentUserRole,
    List<Ledger>? userLedgers,
    bool? isLoading,
    String? error,
  }) {
    return LedgerContextState(
      currentLedger: currentLedger ?? this.currentLedger,
      members: members ?? this.members,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      userLedgers: userLedgers ?? this.userLedgers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 账本上下文 Notifier
class LedgerContextNotifier extends Notifier<LedgerContextState> {
  @override
  LedgerContextState build() {
    return const LedgerContextState();
  }

  /// 初始化上���文
  Future<void> initialize(String userId) async {
    state = state.copyWith(isLoading: true, currentUserId: userId);

    try {
      // 加载用户的所有账本
      final ledgers = await _loadUserLedgers(userId);

      // 设置默认账本
      final defaultLedger = ledgers.isNotEmpty
          ? ledgers.firstWhere(
              (l) => l.isDefault,
              orElse: () => ledgers.first,
            )
          : null;

      if (defaultLedger != null) {
        await _loadLedgerContext(defaultLedger, userId);
      }

      state = state.copyWith(
        userLedgers: ledgers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 切换账本
  Future<void> switchLedger(Ledger ledger) async {
    if (state.currentUserId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      await _loadLedgerContext(ledger, state.currentUserId!);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载账本上下文
  Future<void> _loadLedgerContext(Ledger ledger, String userId) async {
    // 加载成员
    final members = await _loadLedgerMembers(ledger.id);

    // 确定当前用户角色
    MemberRole? role;
    final currentMember = members.where((m) => m.userId == userId).firstOrNull;
    if (currentMember != null) {
      role = currentMember.role;
    } else if (ledger.ownerId == userId) {
      role = MemberRole.owner;
    }

    state = state.copyWith(
      currentLedger: ledger,
      members: members,
      currentUserRole: role,
    );
  }

  /// 加载用户的所有账本
  Future<List<Ledger>> _loadUserLedgers(String userId) async {
    try {
      final db = await DatabaseService().database;
      final results = await db.query(
        'ledgers',
        where: 'ownerId = ? OR id IN (SELECT ledgerId FROM ledger_members WHERE userId = ?)',
        whereArgs: [userId, userId],
        orderBy: 'isDefault DESC, createdAt DESC',
      );

      if (results.isEmpty) {
        // 如果没有账本，创建默认账本
        final defaultLedger = DefaultLedgers.defaultLedger(userId);
        await db.insert('ledgers', defaultLedger.toMap());
        return [defaultLedger];
      }

      return results.map((row) => Ledger.fromMap(row)).toList();
    } catch (e) {
      // 出错时返回默认账本
      return [DefaultLedgers.defaultLedger(userId)];
    }
  }

  /// 加载账本成员
  Future<List<LedgerMember>> _loadLedgerMembers(String ledgerId) async {
    try {
      final db = await DatabaseService().database;
      final results = await db.query(
        'ledger_members',
        where: 'ledgerId = ?',
        whereArgs: [ledgerId],
        orderBy: 'role ASC, joinedAt ASC',
      );

      return results.map((row) => LedgerMember.fromMap(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 刷新当前账本
  Future<void> refreshCurrentLedger() async {
    if (state.currentLedger == null || state.currentUserId == null) return;

    await _loadLedgerContext(state.currentLedger!, state.currentUserId!);
  }

  /// 刷新账本列表
  Future<void> refreshLedgerList() async {
    if (state.currentUserId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final ledgers = await _loadUserLedgers(state.currentUserId!);
      state = state.copyWith(userLedgers: ledgers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 添加账本到列表
  void addLedger(Ledger ledger) {
    state = state.copyWith(
      userLedgers: [...state.userLedgers, ledger],
    );
  }

  /// 更新账本
  void updateLedger(Ledger ledger) {
    final updatedLedgers = state.userLedgers.map((l) {
      return l.id == ledger.id ? ledger : l;
    }).toList();

    state = state.copyWith(
      userLedgers: updatedLedgers,
      currentLedger:
          state.currentLedger?.id == ledger.id ? ledger : state.currentLedger,
    );
  }

  /// 移除账本
  void removeLedger(String ledgerId) {
    final updatedLedgers =
        state.userLedgers.where((l) => l.id != ledgerId).toList();

    // 如果删除的是当前账本，切换到另一个
    Ledger? newCurrentLedger = state.currentLedger;
    if (state.currentLedger?.id == ledgerId) {
      newCurrentLedger = updatedLedgers.isNotEmpty ? updatedLedgers.first : null;
    }

    state = state.copyWith(
      userLedgers: updatedLedgers,
      currentLedger: newCurrentLedger,
    );
  }

  /// 添加成员
  void addMember(LedgerMember member) {
    if (member.ledgerId != state.currentLedger?.id) return;
    state = state.copyWith(
      members: [...state.members, member],
    );
  }

  /// 更新成员
  void updateMember(LedgerMember member) {
    final updatedMembers = state.members.map((m) {
      return m.id == member.id ? member : m;
    }).toList();

    state = state.copyWith(members: updatedMembers);
  }

  /// 移除成员
  void removeMember(String memberId) {
    final updatedMembers =
        state.members.where((m) => m.id != memberId).toList();
    state = state.copyWith(members: updatedMembers);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 重置上下文
  void reset() {
    state = const LedgerContextState();
  }
}

/// 账本上下文 Provider
final ledgerContextProvider =
    NotifierProvider<LedgerContextNotifier, LedgerContextState>(
        LedgerContextNotifier.new);

/// 当前账本 Provider
final currentLedgerProvider = Provider<Ledger?>((ref) {
  return ref.watch(ledgerContextProvider).currentLedger;
});

/// 当前账本ID Provider
final currentLedgerIdProvider = Provider<String?>((ref) {
  return ref.watch(ledgerContextProvider).currentLedger?.id;
});

/// 当前账本成员 Provider
final currentLedgerMembersProvider = Provider<List<LedgerMember>>((ref) {
  return ref.watch(ledgerContextProvider).members;
});

/// 当前用户角色 Provider
final currentUserRoleProvider = Provider<MemberRole?>((ref) {
  return ref.watch(ledgerContextProvider).currentUserRole;
});

/// 用户账本列表 Provider
final userLedgersProvider = Provider<List<Ledger>>((ref) {
  return ref.watch(ledgerContextProvider).userLedgers;
});

/// 是否为共享账本 Provider
final isSharedLedgerProvider = Provider<bool>((ref) {
  return ref.watch(ledgerContextProvider).isSharedLedger;
});

/// 当前用户是否可编辑 Provider
final canEditProvider = Provider<bool>((ref) {
  return ref.watch(ledgerContextProvider).canEdit;
});

/// 权限检查扩展
extension LedgerContextPermissions on LedgerContextState {
  /// 检查是否可以创建交易
  bool canCreateTransaction() {
    return currentUserRole?.canCreateTransaction ?? false;
  }

  /// 检查是否可以管理成员
  bool canManageMembers() {
    return currentUserRole?.canManageMembers ?? false;
  }

  /// 检查是否可以设置预算
  bool canSetBudget() {
    return currentUserRole?.canSetBudget ?? false;
  }

  /// 检查是否可以审批消费
  bool canApproveExpense() {
    return currentUserRole?.canApproveExpense ?? false;
  }

  /// 检查是否可以删除账本
  bool canDeleteLedger() {
    return currentUserRole?.canDeleteLedger ?? false;
  }

  /// 检查是否可以邀请成员
  bool canInviteMembers() {
    if (currentLedger == null) return false;
    if (!currentLedger!.type.supportsMultipleMembers) return false;
    if (currentLedger!.isMaxMembersReached) return false;

    // 检查账本设置是否允许成员邀请
    if (currentLedger!.settings.allowMemberInvite) {
      return currentUserRole?.canCreateTransaction ?? false;
    }

    return currentUserRole?.canManageMembers ?? false;
  }
}
