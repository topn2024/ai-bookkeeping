import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/member.dart';

/// 邀请类型
enum InviteType {
  /// 链接邀请（可多人使用）
  link,
  /// 二维码邀请（可多人使用）
  qrCode,
  /// 直接邀请（指定用户）
  direct,
  /// 语音邀请码（6位数字，视障友好）
  voice,
}

/// 邀请链接信息
class InviteLinkInfo {
  /// 账本ID
  final String ledgerId;
  /// 账本名称
  final String ledgerName;
  /// 邀请码
  final String inviteCode;
  /// 邀请者ID
  final String inviterId;
  /// 邀请者名称
  final String inviterName;
  /// 分配的角色
  final MemberRole role;
  /// 创建时间
  final DateTime createdAt;
  /// 过期时间
  final DateTime expiresAt;
  /// 最大使用次数（0表示无限制）
  final int maxUses;
  /// 已使用次数
  final int usedCount;
  /// 邀请类型
  final InviteType type;

  const InviteLinkInfo({
    required this.ledgerId,
    required this.ledgerName,
    required this.inviteCode,
    required this.inviterId,
    required this.inviterName,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    this.maxUses = 0,
    this.usedCount = 0,
    this.type = InviteType.link,
  });

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 是否已达到最大使用次数
  bool get isMaxUsesReached => maxUses > 0 && usedCount >= maxUses;

  /// 是否仍然有效
  bool get isValid => !isExpired && !isMaxUsesReached;

  /// 剩余有效时间
  Duration get remainingTime => expiresAt.difference(DateTime.now());

  /// 剩余有效时间描述
  String get remainingTimeDescription {
    final remaining = remainingTime;
    if (remaining.isNegative) return '已过期';
    if (remaining.inDays > 0) return '${remaining.inDays}天后过期';
    if (remaining.inHours > 0) return '${remaining.inHours}小时后过期';
    if (remaining.inMinutes > 0) return '${remaining.inMinutes}分钟后过期';
    return '即将过期';
  }

  /// 生成邀请链接
  String get inviteLink => 'bookkeeping://invite/$inviteCode';

  /// 生成分享文本
  String get shareText =>
      '$inviterName 邀请你加入账本「$ledgerName」，点击链接加入：$inviteLink';

  InviteLinkInfo copyWith({
    String? ledgerId,
    String? ledgerName,
    String? inviteCode,
    String? inviterId,
    String? inviterName,
    MemberRole? role,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? maxUses,
    int? usedCount,
    InviteType? type,
  }) {
    return InviteLinkInfo(
      ledgerId: ledgerId ?? this.ledgerId,
      ledgerName: ledgerName ?? this.ledgerName,
      inviteCode: inviteCode ?? this.inviteCode,
      inviterId: inviterId ?? this.inviterId,
      inviterName: inviterName ?? this.inviterName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ledgerId': ledgerId,
      'ledgerName': ledgerName,
      'inviteCode': inviteCode,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'role': role.index,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'maxUses': maxUses,
      'usedCount': usedCount,
      'type': type.index,
    };
  }

  factory InviteLinkInfo.fromMap(Map<String, dynamic> map) {
    return InviteLinkInfo(
      ledgerId: map['ledgerId'] as String,
      ledgerName: map['ledgerName'] as String,
      inviteCode: map['inviteCode'] as String,
      inviterId: map['inviterId'] as String,
      inviterName: map['inviterName'] as String,
      role: MemberRole.values[map['role'] as int],
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      maxUses: map['maxUses'] as int? ?? 0,
      usedCount: map['usedCount'] as int? ?? 0,
      type: InviteType.values[map['type'] as int? ?? 0],
    );
  }

  /// 生成二维码数据（JSON格式）
  String toQrData() {
    return jsonEncode({
      'type': 'ledger_invite',
      'version': 1,
      'code': inviteCode,
      'ledger': ledgerName,
      'inviter': inviterName,
      'role': role.displayName,
      'expires': expiresAt.toIso8601String(),
    });
  }

  /// 从二维码数据解析邀请码
  static String? parseQrData(String qrData) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      if (data['type'] == 'ledger_invite') {
        return data['code'] as String?;
      }
    } catch (_) {
      // 如果不是JSON，尝试解析为URL
      final uri = Uri.tryParse(qrData);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        if (uri.pathSegments.first == 'invite' && uri.pathSegments.length > 1) {
          return uri.pathSegments[1];
        }
      }
    }
    return null;
  }
}

/// 邀请处理结果
class InviteResult {
  final bool success;
  final String? message;
  final LedgerMember? member;
  final InviteError? error;

  const InviteResult({
    required this.success,
    this.message,
    this.member,
    this.error,
  });

  factory InviteResult.success(LedgerMember member) {
    return InviteResult(
      success: true,
      message: '成功加入账本',
      member: member,
    );
  }

  factory InviteResult.failure(InviteError error) {
    return InviteResult(
      success: false,
      error: error,
      message: error.message,
    );
  }
}

/// 邀请错误类型
enum InviteError {
  invalidCode,
  expired,
  maxUsesReached,
  alreadyMember,
  ledgerNotFound,
  ledgerFull,
  networkError,
  unknown,
}

extension InviteErrorExtension on InviteError {
  String get message {
    switch (this) {
      case InviteError.invalidCode:
        return '无效的邀请码';
      case InviteError.expired:
        return '邀请已过期';
      case InviteError.maxUsesReached:
        return '邀请已达到最大使用次数';
      case InviteError.alreadyMember:
        return '您已经是该账本的成员';
      case InviteError.ledgerNotFound:
        return '账本不存在';
      case InviteError.ledgerFull:
        return '账本成员数已达上限';
      case InviteError.networkError:
        return '网络错误，请稍后重试';
      case InviteError.unknown:
        return '未知错误';
    }
  }
}

/// 二维码邀请服务
class QrInviteService {
  static final QrInviteService _instance = QrInviteService._internal();
  factory QrInviteService() => _instance;
  QrInviteService._internal();

  final _uuid = const Uuid();
  final _random = Random.secure();

  // 邀请链接存储（实际应使用数据库）
  final Map<String, InviteLinkInfo> _inviteLinks = {};

  /// 生成邀请码（6位字母数字组合）
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 排除容易混淆的字符
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// 生成语音邀请码（6位纯数字，便于口述）
  String _generateVoiceCode() {
    return List.generate(6, (_) => _random.nextInt(10)).join();
  }

  /// 获取语音邀请码的语义化描述（便于屏幕阅读器朗读）
  String getVoiceCodeDescription(String code) {
    final digits = code.split('');
    return digits.map((d) => _digitToWord(d)).join(' ');
  }

  String _digitToWord(String digit) {
    const words = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final index = int.tryParse(digit);
    return index != null ? words[index] : digit;
  }

  /// 创建邀请链接
  Future<InviteLinkInfo> createInviteLink({
    required String ledgerId,
    required String ledgerName,
    required String inviterId,
    required String inviterName,
    MemberRole role = MemberRole.editor,
    Duration validDuration = const Duration(days: 7),
    int maxUses = 0,
    InviteType type = InviteType.link,
  }) async {
    final inviteCode = _generateInviteCode();
    final now = DateTime.now();

    final inviteInfo = InviteLinkInfo(
      ledgerId: ledgerId,
      ledgerName: ledgerName,
      inviteCode: inviteCode,
      inviterId: inviterId,
      inviterName: inviterName,
      role: role,
      createdAt: now,
      expiresAt: now.add(validDuration),
      maxUses: maxUses,
      type: type,
    );

    _inviteLinks[inviteCode] = inviteInfo;
    return inviteInfo;
  }

  /// 创建二维码邀请
  Future<InviteLinkInfo> createQrInvite({
    required String ledgerId,
    required String ledgerName,
    required String inviterId,
    required String inviterName,
    MemberRole role = MemberRole.editor,
    Duration validDuration = const Duration(hours: 24),
    int maxUses = 1,
  }) async {
    return createInviteLink(
      ledgerId: ledgerId,
      ledgerName: ledgerName,
      inviterId: inviterId,
      inviterName: inviterName,
      role: role,
      validDuration: validDuration,
      maxUses: maxUses,
      type: InviteType.qrCode,
    );
  }

  /// 创建语音邀请码（6位纯数字，便于口述，视障友好）
  Future<InviteLinkInfo> createVoiceInvite({
    required String ledgerId,
    required String ledgerName,
    required String inviterId,
    required String inviterName,
    MemberRole role = MemberRole.editor,
    Duration validDuration = const Duration(minutes: 30),
    int maxUses = 1,
  }) async {
    final voiceCode = _generateVoiceCode();
    final now = DateTime.now();

    final inviteInfo = InviteLinkInfo(
      ledgerId: ledgerId,
      ledgerName: ledgerName,
      inviteCode: voiceCode,
      inviterId: inviterId,
      inviterName: inviterName,
      role: role,
      createdAt: now,
      expiresAt: now.add(validDuration),
      maxUses: maxUses,
      type: InviteType.voice,
    );

    _inviteLinks[voiceCode] = inviteInfo;
    return inviteInfo;
  }

  /// 获取邀请信息
  Future<InviteLinkInfo?> getInviteInfo(String inviteCode) async {
    return _inviteLinks[inviteCode.toUpperCase()];
  }

  /// 验证邀请码
  Future<InviteResult> validateInviteCode(
    String inviteCode,
    String userId,
    List<String> existingMemberIds,
  ) async {
    final inviteInfo = await getInviteInfo(inviteCode);

    if (inviteInfo == null) {
      return InviteResult.failure(InviteError.invalidCode);
    }

    if (inviteInfo.isExpired) {
      return InviteResult.failure(InviteError.expired);
    }

    if (inviteInfo.isMaxUsesReached) {
      return InviteResult.failure(InviteError.maxUsesReached);
    }

    if (existingMemberIds.contains(userId)) {
      return InviteResult.failure(InviteError.alreadyMember);
    }

    return InviteResult(
      success: true,
      message: '邀请码有效',
    );
  }

  /// 使用邀请码加入账本
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
    final inviteInfo = await getInviteInfo(inviteCode);

    if (inviteInfo == null) {
      return InviteResult.failure(InviteError.invalidCode);
    }

    if (inviteInfo.isExpired) {
      return InviteResult.failure(InviteError.expired);
    }

    if (inviteInfo.isMaxUsesReached) {
      return InviteResult.failure(InviteError.maxUsesReached);
    }

    if (existingMemberIds.contains(userId)) {
      return InviteResult.failure(InviteError.alreadyMember);
    }

    if (currentMemberCount >= maxMembers) {
      return InviteResult.failure(InviteError.ledgerFull);
    }

    // 创建新成员
    final member = LedgerMember(
      id: _uuid.v4(),
      ledgerId: inviteInfo.ledgerId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userAvatar: userAvatar,
      role: inviteInfo.role,
      joinedAt: DateTime.now(),
    );

    // 更新使用次数
    _inviteLinks[inviteCode.toUpperCase()] = inviteInfo.copyWith(
      usedCount: inviteInfo.usedCount + 1,
    );

    return InviteResult.success(member);
  }

  /// 撤销邀请链接
  Future<bool> revokeInvite(String inviteCode) async {
    final code = inviteCode.toUpperCase();
    if (_inviteLinks.containsKey(code)) {
      _inviteLinks.remove(code);
      return true;
    }
    return false;
  }

  /// 获取账本的所有邀请链接
  Future<List<InviteLinkInfo>> getInvitesByLedger(String ledgerId) async {
    return _inviteLinks.values
        .where((invite) => invite.ledgerId == ledgerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取用户创建的所有邀请链接
  Future<List<InviteLinkInfo>> getInvitesByInviter(String inviterId) async {
    return _inviteLinks.values
        .where((invite) => invite.inviterId == inviterId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 清理过期邀请
  Future<int> cleanupExpiredInvites() async {
    final expiredCodes = _inviteLinks.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final code in expiredCodes) {
      _inviteLinks.remove(code);
    }

    return expiredCodes.length;
  }

  /// 解析深度链接
  InviteDeepLinkData? parseDeepLink(String uri) {
    try {
      final parsedUri = Uri.parse(uri);
      if (parsedUri.scheme == 'bookkeeping' && parsedUri.host == 'invite') {
        final inviteCode = parsedUri.pathSegments.isNotEmpty
            ? parsedUri.pathSegments.first
            : null;
        if (inviteCode != null) {
          return InviteDeepLinkData(
            inviteCode: inviteCode,
            source: parsedUri.queryParameters['source'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// 清空所有数据（测试用）
  void clearAll() {
    _inviteLinks.clear();
  }
}

/// 深度链接数据
class InviteDeepLinkData {
  final String inviteCode;
  final String? source;

  const InviteDeepLinkData({
    required this.inviteCode,
    this.source,
  });
}
