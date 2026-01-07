import '../models/privacy_settings.dart';
import '../models/member.dart';

/// 家庭隐私服务
class FamilyPrivacyService {
  static final FamilyPrivacyService _instance = FamilyPrivacyService._internal();
  factory FamilyPrivacyService() => _instance;
  FamilyPrivacyService._internal();

  // 成员隐私偏好存储
  final Map<String, MemberPrivacyPreference> _memberPreferences = {};
  // 交易可见性存储
  final Map<String, TransactionVisibility> _transactionVisibilities = {};

  /// 获取成员的隐私设置
  Future<PrivacySettings> getMemberPrivacySettings(
    String memberId,
    String ledgerId,
  ) async {
    final key = '$memberId:$ledgerId';
    return _memberPreferences[key]?.settings ?? const PrivacySettings();
  }

  /// 更新成员隐私设置
  Future<MemberPrivacyPreference> updateMemberPrivacySettings(
    String memberId,
    String ledgerId,
    PrivacySettings settings,
  ) async {
    final key = '$memberId:$ledgerId';
    final preference = MemberPrivacyPreference(
      memberId: memberId,
      ledgerId: ledgerId,
      settings: settings,
      updatedAt: DateTime.now(),
    );
    _memberPreferences[key] = preference;
    return preference;
  }

  /// 获取交易可见性
  Future<TransactionVisibility?> getTransactionVisibility(
    String transactionId,
  ) async {
    return _transactionVisibilities[transactionId];
  }

  /// 设置交易可见性
  Future<TransactionVisibility> setTransactionVisibility({
    required String transactionId,
    required VisibilityLevel level,
    required String createdBy,
    List<String>? visibleMemberIds,
  }) async {
    final visibility = TransactionVisibility(
      transactionId: transactionId,
      level: level,
      visibleMemberIds: visibleMemberIds ?? [],
      createdBy: createdBy,
    );
    _transactionVisibilities[transactionId] = visibility;
    return visibility;
  }

  /// 检查成员是否可以查看交易
  Future<bool> canViewTransaction({
    required String transactionId,
    required String viewerId,
    required String createdBy,
    required MemberRole viewerRole,
    String? categoryId,
    String? ledgerId,
  }) async {
    // 创建者总是可以查看
    if (viewerId == createdBy) return true;

    // 检查交易可见性
    final visibility = await getTransactionVisibility(transactionId);
    if (visibility != null) {
      return visibility.isVisibleTo(
        viewerId,
        isAdmin: viewerRole == MemberRole.owner ||
            viewerRole == MemberRole.admin,
      );
    }

    // 检查成员隐私设置（创建者的设置）
    if (ledgerId != null) {
      final creatorSettings =
          await getMemberPrivacySettings(createdBy, ledgerId);

      // 检查是否为私密分类
      if (categoryId != null &&
          creatorSettings.privateCategories.contains(categoryId)) {
        return false;
      }

      // 使用默认可见性
      switch (creatorSettings.defaultVisibility) {
        case VisibilityLevel.private:
          return false;
        case VisibilityLevel.allMembers:
          return true;
        case VisibilityLevel.adminsOnly:
          return viewerRole == MemberRole.owner ||
              viewerRole == MemberRole.admin;
        case VisibilityLevel.selective:
          return false; // 需要明确设置
      }
    }

    // 默认所有成员可见
    return true;
  }

  /// 检查成员是否可以查看金额
  Future<bool> canViewAmount({
    required String createdBy,
    required String viewerId,
    required String ledgerId,
  }) async {
    if (viewerId == createdBy) return true;

    final settings = await getMemberPrivacySettings(createdBy, ledgerId);
    return settings.showAmountToMembers;
  }

  /// 检查成员是否可以查看详情
  Future<bool> canViewDetails({
    required String createdBy,
    required String viewerId,
    required String ledgerId,
  }) async {
    if (viewerId == createdBy) return true;

    final settings = await getMemberPrivacySettings(createdBy, ledgerId);
    return settings.showDetailsToMembers;
  }

  /// 检查成员是否可以查看备注
  Future<bool> canViewNotes({
    required String createdBy,
    required String viewerId,
    required String ledgerId,
  }) async {
    if (viewerId == createdBy) return true;

    final settings = await getMemberPrivacySettings(createdBy, ledgerId);
    return settings.showNotesToMembers;
  }

  /// 检查成员是否可以查看附件
  Future<bool> canViewAttachments({
    required String createdBy,
    required String viewerId,
    required String ledgerId,
  }) async {
    if (viewerId == createdBy) return true;

    final settings = await getMemberPrivacySettings(createdBy, ledgerId);
    return settings.showAttachmentsToMembers;
  }

  /// 过滤交易列表（根据可见性）
  Future<List<T>> filterTransactions<T>({
    required List<T> transactions,
    required String viewerId,
    required MemberRole viewerRole,
    required String Function(T) getTransactionId,
    required String Function(T) getCreatedBy,
    String? Function(T)? getCategoryId,
    required String ledgerId,
  }) async {
    final visibleTransactions = <T>[];

    for (final transaction in transactions) {
      final canView = await canViewTransaction(
        transactionId: getTransactionId(transaction),
        viewerId: viewerId,
        createdBy: getCreatedBy(transaction),
        viewerRole: viewerRole,
        categoryId: getCategoryId?.call(transaction),
        ledgerId: ledgerId,
      );

      if (canView) {
        visibleTransactions.add(transaction);
      }
    }

    return visibleTransactions;
  }

  /// 应用隐私遮罩到交易数据
  Future<Map<String, dynamic>> applyPrivacyMask({
    required Map<String, dynamic> transactionData,
    required String createdBy,
    required String viewerId,
    required String ledgerId,
  }) async {
    if (viewerId == createdBy) return transactionData;

    final result = Map<String, dynamic>.from(transactionData);

    // 检查金额可见性
    if (!await canViewAmount(
        createdBy: createdBy, viewerId: viewerId, ledgerId: ledgerId)) {
      result['amount'] = null;
      result['amountMasked'] = true;
    }

    // 检查备注可见性
    if (!await canViewNotes(
        createdBy: createdBy, viewerId: viewerId, ledgerId: ledgerId)) {
      result['note'] = null;
      result['noteMasked'] = true;
    }

    // 检查附件可见性
    if (!await canViewAttachments(
        createdBy: createdBy, viewerId: viewerId, ledgerId: ledgerId)) {
      result['attachments'] = null;
      result['attachmentsMasked'] = true;
    }

    return result;
  }

  /// 获取可见性选项
  List<VisibilityOption> getVisibilityOptions({
    bool includeSelective = true,
  }) {
    return [
      const VisibilityOption(
        level: VisibilityLevel.allMembers,
        isDefault: true,
      ),
      const VisibilityOption(
        level: VisibilityLevel.private,
      ),
      const VisibilityOption(
        level: VisibilityLevel.adminsOnly,
      ),
      if (includeSelective)
        const VisibilityOption(
          level: VisibilityLevel.selective,
        ),
    ];
  }

  /// 批量更新交易可见性
  Future<void> batchUpdateVisibility({
    required List<String> transactionIds,
    required VisibilityLevel level,
    required String createdBy,
    List<String>? visibleMemberIds,
  }) async {
    for (final id in transactionIds) {
      await setTransactionVisibility(
        transactionId: id,
        level: level,
        createdBy: createdBy,
        visibleMemberIds: visibleMemberIds,
      );
    }
  }

  /// 清空所有数据（测试用）
  void clearAll() {
    _memberPreferences.clear();
    _transactionVisibilities.clear();
  }
}

/// 可见性选项
class VisibilityOption {
  final VisibilityLevel level;
  final bool isDefault;

  const VisibilityOption({
    required this.level,
    this.isDefault = false,
  });

  String get displayName => level.displayName;
  String get description => level.description;
}
