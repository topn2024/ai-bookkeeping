import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../services/qr_invite_service.dart';

/// QrInviteService Provider
final qrInviteServiceProvider = Provider<QrInviteService>((ref) {
  return QrInviteService();
});

/// 邀请链接列表状态
class InviteLinksState {
  final List<InviteLinkInfo> invites;
  final bool isLoading;
  final String? error;

  const InviteLinksState({
    this.invites = const [],
    this.isLoading = false,
    this.error,
  });

  InviteLinksState copyWith({
    List<InviteLinkInfo>? invites,
    bool? isLoading,
    String? error,
  }) {
    return InviteLinksState(
      invites: invites ?? this.invites,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 邀请链接 Notifier
class InviteLinksNotifier extends Notifier<InviteLinksState> {
  @override
  InviteLinksState build() {
    return const InviteLinksState();
  }

  QrInviteService get _inviteService => ref.read(qrInviteServiceProvider);

  /// 加载账本的邀请链接
  Future<void> loadInvitesByLedger(String ledgerId) async {
    state = state.copyWith(isLoading: true);
    try {
      final invites = await _inviteService.getInvitesByLedger(ledgerId);
      state = state.copyWith(invites: invites, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 创建邀请链接
  Future<InviteLinkInfo?> createInviteLink({
    required String ledgerId,
    required String ledgerName,
    required String inviterId,
    required String inviterName,
    MemberRole role = MemberRole.editor,
    Duration validDuration = const Duration(days: 7),
    int maxUses = 0,
  }) async {
    try {
      final invite = await _inviteService.createInviteLink(
        ledgerId: ledgerId,
        ledgerName: ledgerName,
        inviterId: inviterId,
        inviterName: inviterName,
        role: role,
        validDuration: validDuration,
        maxUses: maxUses,
      );
      state = state.copyWith(invites: [invite, ...state.invites]);
      return invite;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 创建二维码邀请
  Future<InviteLinkInfo?> createQrInvite({
    required String ledgerId,
    required String ledgerName,
    required String inviterId,
    required String inviterName,
    MemberRole role = MemberRole.editor,
    Duration validDuration = const Duration(hours: 24),
    int maxUses = 1,
  }) async {
    try {
      final invite = await _inviteService.createQrInvite(
        ledgerId: ledgerId,
        ledgerName: ledgerName,
        inviterId: inviterId,
        inviterName: inviterName,
        role: role,
        validDuration: validDuration,
        maxUses: maxUses,
      );
      state = state.copyWith(invites: [invite, ...state.invites]);
      return invite;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 撤销邀请
  Future<bool> revokeInvite(String inviteCode) async {
    try {
      final success = await _inviteService.revokeInvite(inviteCode);
      if (success) {
        final updatedInvites = state.invites
            .where((i) => i.inviteCode != inviteCode)
            .toList();
        state = state.copyWith(invites: updatedInvites);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 清理过期邀请
  Future<void> cleanupExpiredInvites() async {
    await _inviteService.cleanupExpiredInvites();
    final validInvites = state.invites.where((i) => i.isValid).toList();
    state = state.copyWith(invites: validInvites);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 邀请链接列表 Provider
final inviteLinksProvider =
    NotifierProvider<InviteLinksNotifier, InviteLinksState>(
        InviteLinksNotifier.new);

/// 处理邀请状态
class ProcessInviteState {
  final InviteLinkInfo? inviteInfo;
  final bool isLoading;
  final bool isProcessing;
  final InviteResult? result;
  final String? error;

  const ProcessInviteState({
    this.inviteInfo,
    this.isLoading = false,
    this.isProcessing = false,
    this.result,
    this.error,
  });

  ProcessInviteState copyWith({
    InviteLinkInfo? inviteInfo,
    bool? isLoading,
    bool? isProcessing,
    InviteResult? result,
    String? error,
  }) {
    return ProcessInviteState(
      inviteInfo: inviteInfo ?? this.inviteInfo,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      result: result ?? this.result,
      error: error,
    );
  }
}

/// 处理邀请 Notifier
class ProcessInviteNotifier extends Notifier<ProcessInviteState> {
  @override
  ProcessInviteState build() {
    return const ProcessInviteState();
  }

  QrInviteService get _inviteService => ref.read(qrInviteServiceProvider);

  /// 获取邀请信息
  Future<void> loadInviteInfo(String inviteCode) async {
    state = state.copyWith(isLoading: true);
    try {
      final inviteInfo = await _inviteService.getInviteInfo(inviteCode);
      if (inviteInfo != null) {
        state = state.copyWith(inviteInfo: inviteInfo, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '无效的邀请码',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 验证邀请码
  Future<InviteResult> validateInvite(
    String inviteCode,
    String userId,
    List<String> existingMemberIds,
  ) async {
    return await _inviteService.validateInviteCode(
      inviteCode,
      userId,
      existingMemberIds,
    );
  }

  /// 接受邀请
  Future<InviteResult> acceptInvite({
    required String inviteCode,
    required String userId,
    required String userName,
    String? userEmail,
    String? userAvatar,
    required List<String> existingMemberIds,
    required int currentMemberCount,
    required int maxMembers,
  }) async {
    state = state.copyWith(isProcessing: true);
    try {
      final result = await _inviteService.acceptInvite(
        inviteCode: inviteCode,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userAvatar: userAvatar,
        existingMemberIds: existingMemberIds,
        currentMemberCount: currentMemberCount,
        maxMembers: maxMembers,
      );
      state = state.copyWith(isProcessing: false, result: result);
      return result;
    } catch (e) {
      final errorResult = InviteResult.failure(InviteError.unknown);
      state = state.copyWith(
        isProcessing: false,
        result: errorResult,
        error: e.toString(),
      );
      return errorResult;
    }
  }

  /// 从二维码数据解析邀请码
  Future<String?> parseQrCode(String qrData) async {
    return InviteLinkInfo.parseQrData(qrData);
  }

  /// 重置状态
  void reset() {
    state = const ProcessInviteState();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 处理邀请 Provider
final processInviteProvider =
    NotifierProvider<ProcessInviteNotifier, ProcessInviteState>(
        ProcessInviteNotifier.new);

/// 单个邀请信息 Provider（用于预览）
final inviteInfoProvider = FutureProvider.family<InviteLinkInfo?, String>(
    (ref, inviteCode) async {
  final inviteService = ref.watch(qrInviteServiceProvider);
  return inviteService.getInviteInfo(inviteCode);
});
