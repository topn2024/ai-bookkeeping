import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/privacy_settings.dart';
import '../models/member.dart';
import '../services/family_privacy_service.dart';

/// FamilyPrivacyService Provider
final familyPrivacyServiceProvider = Provider<FamilyPrivacyService>((ref) {
  return FamilyPrivacyService();
});

/// 成员隐私设置状态
class MemberPrivacyState {
  final PrivacySettings? settings;
  final bool isLoading;
  final String? error;

  const MemberPrivacyState({
    this.settings,
    this.isLoading = false,
    this.error,
  });

  MemberPrivacyState copyWith({
    PrivacySettings? settings,
    bool? isLoading,
    String? error,
  }) {
    return MemberPrivacyState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 成员隐私设置 Notifier
class MemberPrivacyNotifier extends Notifier<MemberPrivacyState> {
  @override
  MemberPrivacyState build() {
    return const MemberPrivacyState();
  }

  FamilyPrivacyService get _privacyService =>
      ref.read(familyPrivacyServiceProvider);

  /// 加载隐私设置
  Future<void> loadSettings(String memberId, String ledgerId) async {
    state = state.copyWith(isLoading: true);
    try {
      final settings = await _privacyService.getMemberPrivacySettings(
        memberId,
        ledgerId,
      );
      state = state.copyWith(settings: settings, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 更新默认可见性
  Future<void> updateDefaultVisibility(
    String memberId,
    String ledgerId,
    VisibilityLevel visibility,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    final newSettings = currentSettings.copyWith(
      defaultVisibility: visibility,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 切换金额显示
  Future<void> toggleShowAmount(
    String memberId,
    String ledgerId,
    bool show,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    final newSettings = currentSettings.copyWith(
      showAmountToMembers: show,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 切换详情显示
  Future<void> toggleShowDetails(
    String memberId,
    String ledgerId,
    bool show,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    final newSettings = currentSettings.copyWith(
      showDetailsToMembers: show,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 切换备注显示
  Future<void> toggleShowNotes(
    String memberId,
    String ledgerId,
    bool show,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    final newSettings = currentSettings.copyWith(
      showNotesToMembers: show,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 切换附件显示
  Future<void> toggleShowAttachments(
    String memberId,
    String ledgerId,
    bool show,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    final newSettings = currentSettings.copyWith(
      showAttachmentsToMembers: show,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 更新私密分类
  Future<void> updatePrivateCategories(
    String memberId,
    String ledgerId,
    List<String> categoryIds,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    final newSettings = currentSettings.copyWith(
      privateCategories: categoryIds,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 添加私密分类
  Future<void> addPrivateCategory(
    String memberId,
    String ledgerId,
    String categoryId,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    if (currentSettings.privateCategories.contains(categoryId)) return;

    final newCategories = [...currentSettings.privateCategories, categoryId];
    final newSettings = currentSettings.copyWith(
      privateCategories: newCategories,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 移除私密分类
  Future<void> removePrivateCategory(
    String memberId,
    String ledgerId,
    String categoryId,
  ) async {
    final currentSettings = state.settings ?? const PrivacySettings();
    final newCategories = currentSettings.privateCategories
        .where((c) => c != categoryId)
        .toList();
    final newSettings = currentSettings.copyWith(
      privateCategories: newCategories,
    );
    await _updateSettings(memberId, ledgerId, newSettings);
  }

  /// 更新设置
  Future<void> _updateSettings(
    String memberId,
    String ledgerId,
    PrivacySettings settings,
  ) async {
    try {
      await _privacyService.updateMemberPrivacySettings(
        memberId,
        ledgerId,
        settings,
      );
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 成员隐私设置 Provider
final memberPrivacyProvider =
    NotifierProvider<MemberPrivacyNotifier, MemberPrivacyState>(
        MemberPrivacyNotifier.new);

/// 交易可见性检查 Provider
final transactionVisibilityCheckProvider = FutureProvider.family<
    bool, TransactionVisibilityCheckParams>((ref, params) async {
  final privacyService = ref.watch(familyPrivacyServiceProvider);
  return privacyService.canViewTransaction(
    transactionId: params.transactionId,
    viewerId: params.viewerId,
    createdBy: params.createdBy,
    viewerRole: params.viewerRole,
    categoryId: params.categoryId,
    ledgerId: params.ledgerId,
  );
});

/// 交易可见性检查参数
class TransactionVisibilityCheckParams {
  final String transactionId;
  final String viewerId;
  final String createdBy;
  final MemberRole viewerRole;
  final String? categoryId;
  final String? ledgerId;

  const TransactionVisibilityCheckParams({
    required this.transactionId,
    required this.viewerId,
    required this.createdBy,
    required this.viewerRole,
    this.categoryId,
    this.ledgerId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionVisibilityCheckParams &&
        other.transactionId == transactionId &&
        other.viewerId == viewerId;
  }

  @override
  int get hashCode => transactionId.hashCode ^ viewerId.hashCode;
}

/// 可见性选项列表 Provider
final visibilityOptionsProvider = Provider<List<VisibilityOption>>((ref) {
  final privacyService = ref.watch(familyPrivacyServiceProvider);
  return privacyService.getVisibilityOptions();
});
