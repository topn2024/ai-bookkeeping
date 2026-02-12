import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// 邀请与社交裂变服务
///
/// 提供邀请码生成、奖励系统、社交分享等功能
///
/// 对应实施方案：用户增长体系 - 社交裂变与低成本获客（第29章）

// ==================== 邀请码模型 ====================

/// 邀请码类型
enum InviteCodeType {
  /// 通用邀请码
  general,

  /// 家庭记账邀请
  family,

  /// 情侣记账邀请
  couple,

  /// 限时活动邀请
  campaign,
}

/// 邀请码状态
enum InviteCodeStatus {
  /// 有效
  active,

  /// 已使用
  used,

  /// 已过期
  expired,

  /// 已禁用
  disabled,
}

/// 邀请码
class InviteCode {
  final String code;
  final String creatorId;
  final InviteCodeType type;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int maxUses;
  final int currentUses;
  final Map<String, dynamic>? metadata;
  InviteCodeStatus status;

  InviteCode({
    required this.code,
    required this.creatorId,
    this.type = InviteCodeType.general,
    DateTime? createdAt,
    this.expiresAt,
    this.maxUses = 0, // 0 表示无限制
    this.currentUses = 0,
    this.metadata,
    this.status = InviteCodeStatus.active,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isValid {
    if (status != InviteCodeStatus.active) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    if (maxUses > 0 && currentUses >= maxUses) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'creator_id': creatorId,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'max_uses': maxUses,
        'current_uses': currentUses,
        'metadata': metadata,
        'status': status.name,
      };
}

/// 邀请记录
class InviteRecord {
  final String id;
  final String inviteCode;
  final String inviterId;
  final String inviteeId;
  final DateTime timestamp;
  final bool rewardClaimed;
  final Map<String, dynamic>? metadata;

  InviteRecord({
    required this.id,
    required this.inviteCode,
    required this.inviterId,
    required this.inviteeId,
    DateTime? timestamp,
    this.rewardClaimed = false,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'invite_code': inviteCode,
        'inviter_id': inviterId,
        'invitee_id': inviteeId,
        'timestamp': timestamp.toIso8601String(),
        'reward_claimed': rewardClaimed,
        'metadata': metadata,
      };
}

// ==================== 奖励系统 ====================

/// 奖励类型
enum RewardType {
  /// 高级功能试用天数
  premiumDays,

  /// 积分
  points,

  /// 徽章
  badge,

  /// 主题
  theme,

  /// 自定义
  custom,
}

/// 奖励配置
class RewardConfig {
  final RewardType type;
  final dynamic value;
  final String displayName;
  final String? description;
  final String? iconAsset;

  const RewardConfig({
    required this.type,
    required this.value,
    required this.displayName,
    this.description,
    this.iconAsset,
  });
}

/// 双向奖励配置
class DualRewardConfig {
  /// 邀请人奖励
  final RewardConfig inviterReward;

  /// 被邀请人奖励
  final RewardConfig inviteeReward;

  /// 邀请人额外奖励（达到一定数量后）
  final List<MilestoneReward>? milestoneRewards;

  const DualRewardConfig({
    required this.inviterReward,
    required this.inviteeReward,
    this.milestoneRewards,
  });
}

/// 里程碑奖励
class MilestoneReward {
  final int inviteCount;
  final RewardConfig reward;

  const MilestoneReward({
    required this.inviteCount,
    required this.reward,
  });
}

// ==================== 分享相关 ====================

/// 分享渠道
enum ShareChannel {
  wechat,
  wechatMoments,
  weibo,
  qq,
  copyLink,
  systemShare,
}

/// 分享内容
class ShareContent {
  final String title;
  final String description;
  final String? imageUrl;
  final String? link;
  final Map<String, dynamic>? extra;

  const ShareContent({
    required this.title,
    required this.description,
    this.imageUrl,
    this.link,
    this.extra,
  });
}

/// 分享卡片模板
class ShareCardTemplate {
  final String id;
  final String name;
  final String templateType; // 'bill', 'achievement', 'milestone', 'tip'
  final Map<String, dynamic> config;

  const ShareCardTemplate({
    required this.id,
    required this.name,
    required this.templateType,
    this.config = const {},
  });
}

// ==================== 邀请服务 ====================

/// 邀请与分享服务
class InvitationService {
  static final InvitationService _instance = InvitationService._internal();
  factory InvitationService() => _instance;
  InvitationService._internal();

  // 数据存储
  final Map<String, InviteCode> _inviteCodes = {};
  final List<InviteRecord> _inviteRecords = [];
  final Map<String, int> _userInviteCounts = {};

  // 配置
  DualRewardConfig _rewardConfig = const DualRewardConfig(
    inviterReward: RewardConfig(
      type: RewardType.premiumDays,
      value: 7,
      displayName: '7天高级会员',
      description: '成功邀请好友即可获得',
    ),
    inviteeReward: RewardConfig(
      type: RewardType.premiumDays,
      value: 3,
      displayName: '3天高级会员',
      description: '新用户专享',
    ),
    milestoneRewards: [
      MilestoneReward(
        inviteCount: 5,
        reward: RewardConfig(
          type: RewardType.badge,
          value: 'invite_master',
          displayName: '邀请达人徽章',
        ),
      ),
      MilestoneReward(
        inviteCount: 10,
        reward: RewardConfig(
          type: RewardType.premiumDays,
          value: 30,
          displayName: '30天高级会员',
        ),
      ),
    ],
  );

  // 分享卡片模板
  final List<ShareCardTemplate> _shareTemplates = [
    const ShareCardTemplate(
      id: 'bill_summary',
      name: '账单总结卡片',
      templateType: 'bill',
      config: {'style': 'modern', 'showDetails': true},
    ),
    const ShareCardTemplate(
      id: 'achievement_card',
      name: '成就分享卡片',
      templateType: 'achievement',
      config: {'style': 'celebration'},
    ),
    const ShareCardTemplate(
      id: 'saving_milestone',
      name: '存款里程碑',
      templateType: 'milestone',
      config: {'style': 'goal'},
    ),
    const ShareCardTemplate(
      id: 'finance_tip',
      name: '理财小贴士',
      templateType: 'tip',
      config: {'style': 'educational'},
    ),
  ];

  String? _currentUserId;

  /// 初始化
  Future<void> initialize({String? userId}) async {
    _currentUserId = userId;
    await _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    // 实际实现中从持久化存储加载
  }

  // ==================== 邀请码管理 ====================

  /// 生成邀请码
  Future<InviteCode> generateInviteCode({
    InviteCodeType type = InviteCodeType.general,
    Duration? validDuration,
    int maxUses = 0,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUserId == null) {
      throw StateError('用户未登录');
    }

    final code = _generateUniqueCode();
    final inviteCode = InviteCode(
      code: code,
      creatorId: _currentUserId!,
      type: type,
      expiresAt: validDuration != null
          ? DateTime.now().add(validDuration)
          : null,
      maxUses: maxUses,
      metadata: metadata,
    );

    _inviteCodes[code] = inviteCode;
    await _saveInviteCode(inviteCode);

    return inviteCode;
  }

  String _generateUniqueCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    String code;
    do {
      code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    } while (_inviteCodes.containsKey(code));
    return code;
  }

  Future<void> _saveInviteCode(InviteCode code) async {
    // 实际实现中保存到持久化存储
  }

  /// 验证邀请码
  Future<InviteCode?> validateInviteCode(String code) async {
    final inviteCode = _inviteCodes[code.toUpperCase()];
    if (inviteCode == null) return null;

    // 检查是否过期
    if (inviteCode.expiresAt != null &&
        DateTime.now().isAfter(inviteCode.expiresAt!)) {
      inviteCode.status = InviteCodeStatus.expired;
      return null;
    }

    // 检查使用次数
    if (inviteCode.maxUses > 0 &&
        inviteCode.currentUses >= inviteCode.maxUses) {
      inviteCode.status = InviteCodeStatus.used;
      return null;
    }

    return inviteCode.isValid ? inviteCode : null;
  }

  /// 使用邀请码
  Future<InviteRecord?> useInviteCode({
    required String code,
    required String inviteeId,
  }) async {
    final inviteCode = await validateInviteCode(code);
    if (inviteCode == null) return null;

    // 不能自己邀请自己
    if (inviteCode.creatorId == inviteeId) return null;

    // 创建邀请记录
    final record = InviteRecord(
      id: 'invite_${DateTime.now().millisecondsSinceEpoch}',
      inviteCode: code,
      inviterId: inviteCode.creatorId,
      inviteeId: inviteeId,
    );

    _inviteRecords.add(record);

    // 更新邀请码使用次数
    _inviteCodes[code] = InviteCode(
      code: inviteCode.code,
      creatorId: inviteCode.creatorId,
      type: inviteCode.type,
      createdAt: inviteCode.createdAt,
      expiresAt: inviteCode.expiresAt,
      maxUses: inviteCode.maxUses,
      currentUses: inviteCode.currentUses + 1,
      metadata: inviteCode.metadata,
      status: inviteCode.status,
    );

    // 更新邀请人计数
    _userInviteCounts[inviteCode.creatorId] =
        (_userInviteCounts[inviteCode.creatorId] ?? 0) + 1;

    // 发放奖励
    await _grantRewards(record);

    return record;
  }

  Future<void> _grantRewards(InviteRecord record) async {
    // 发放邀请人奖励
    await _grantReward(record.inviterId, _rewardConfig.inviterReward);

    // 发放被邀请人奖励
    await _grantReward(record.inviteeId, _rewardConfig.inviteeReward);

    // 检查里程碑奖励
    final inviteCount = _userInviteCounts[record.inviterId] ?? 0;
    for (final milestone in _rewardConfig.milestoneRewards ?? []) {
      if (inviteCount == milestone.inviteCount) {
        await _grantReward(record.inviterId, milestone.reward);
      }
    }
  }

  Future<void> _grantReward(String userId, RewardConfig reward) async {
    // 实际实现中发放奖励
    debugPrint('发放奖励给用户 $userId: ${reward.displayName}');
  }

  /// 获取用户的邀请码列表
  List<InviteCode> getUserInviteCodes(String userId) {
    return _inviteCodes.values
        .where((code) => code.creatorId == userId)
        .toList();
  }

  /// 获取用户的邀请记录
  List<InviteRecord> getUserInviteRecords(String userId) {
    return _inviteRecords
        .where((record) => record.inviterId == userId)
        .toList();
  }

  /// 获取用户邀请统计
  Map<String, dynamic> getUserInviteStats(String userId) {
    final records = getUserInviteRecords(userId);
    return {
      'total_invites': records.length,
      'pending_rewards': records.where((r) => !r.rewardClaimed).length,
      'next_milestone': _getNextMilestone(records.length),
    };
  }

  MilestoneReward? _getNextMilestone(int currentCount) {
    for (final milestone in _rewardConfig.milestoneRewards ?? []) {
      if (milestone.inviteCount > currentCount) {
        return milestone;
      }
    }
    return null;
  }

  // ==================== 社交分享 ====================

  /// 生成分享内容
  ShareContent generateShareContent({
    required String type,
    Map<String, dynamic>? data,
    String? inviteCode,
  }) {
    switch (type) {
      case 'invite':
        return ShareContent(
          title: '邀你一起记账',
          description: '我在用白记，帮我省了不少钱！使用邀请码 $inviteCode 注册，我们都能获得奖励！',
          link: 'https://app.example.com/invite?code=$inviteCode',
        );

      case 'bill_summary':
        final month = data?['month'] ?? '本月';
        final saving = data?['saving'] ?? 0;
        return ShareContent(
          title: '$month账单总结',
          description: '这个月我省下了 ¥$saving，你也来试试吧！',
          link: 'https://app.example.com/download',
        );

      case 'achievement':
        final achievement = data?['achievement'] ?? '记账达人';
        return ShareContent(
          title: '我获得了「$achievement」成就！',
          description: '在白记坚持记录，收获满满成就感！',
          link: 'https://app.example.com/download',
        );

      case 'milestone':
        final milestone = data?['milestone'] ?? '存款目标';
        return ShareContent(
          title: '达成里程碑：$milestone',
          description: '一步步实现财务目标，你也可以！',
          link: 'https://app.example.com/download',
        );

      case 'tip':
        final tip = data?['tip'] ?? '理财小贴士';
        return ShareContent(
          title: '理财小贴士',
          description: tip,
          link: 'https://app.example.com/tips',
        );

      default:
        return ShareContent(
          title: '白记',
          description: '让记账变得简单有趣',
          link: 'https://app.example.com/download',
        );
    }
  }

  /// 分享到指定渠道
  Future<bool> shareToChannel({
    required ShareChannel channel,
    required ShareContent content,
  }) async {
    // 记录分享事件
    await _trackShareEvent(channel, content);

    // 实际实现中调用各平台SDK
    switch (channel) {
      case ShareChannel.wechat:
        return await _shareToWechat(content, isTimeline: false);
      case ShareChannel.wechatMoments:
        return await _shareToWechat(content, isTimeline: true);
      case ShareChannel.weibo:
        return await _shareToWeibo(content);
      case ShareChannel.qq:
        return await _shareToQQ(content);
      case ShareChannel.copyLink:
        return await _copyLink(content);
      case ShareChannel.systemShare:
        return await _systemShare(content);
    }
  }

  Future<bool> _shareToWechat(ShareContent content, {required bool isTimeline}) async {
    // 实际实现调用微信SDK
    return true;
  }

  Future<bool> _shareToWeibo(ShareContent content) async {
    // 实际实现调用微博SDK
    return true;
  }

  Future<bool> _shareToQQ(ShareContent content) async {
    // 实际实现调用QQ SDK
    return true;
  }

  Future<bool> _copyLink(ShareContent content) async {
    // 复制链接到剪贴板
    return true;
  }

  Future<bool> _systemShare(ShareContent content) async {
    // 调用系统分享
    return true;
  }

  Future<void> _trackShareEvent(ShareChannel channel, ShareContent content) async {
    // 埋点分享事件
  }

  /// 获取分享卡片模板列表
  List<ShareCardTemplate> getShareTemplates({String? type}) {
    if (type == null) return _shareTemplates;
    return _shareTemplates.where((t) => t.templateType == type).toList();
  }

  /// 生成分享卡片图片
  Future<String?> generateShareCardImage({
    required String templateId,
    required Map<String, dynamic> data,
  }) async {
    // 实际实现中生成分享卡片图片
    // 返回图片本地路径
    return null;
  }

  // ==================== 邀请漏斗分析 ====================

  /// 记录漏斗事件
  Future<void> trackFunnelEvent({
    required String stage,
    Map<String, dynamic>? properties,
  }) async {
    // stage: 'code_generated', 'code_shared', 'code_clicked',
    //        'code_entered', 'registration_started', 'registration_completed'
  }

  /// 获取漏斗统计
  Future<Map<String, int>> getFunnelStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // 实际实现中从分析服务获取数据
    return {
      'code_generated': 100,
      'code_shared': 80,
      'code_clicked': 50,
      'code_entered': 30,
      'registration_started': 25,
      'registration_completed': 20,
    };
  }

  /// 更新奖励配置
  void updateRewardConfig(DualRewardConfig config) {
    _rewardConfig = config;
  }

  /// 获取当前奖励配置
  DualRewardConfig get rewardConfig => _rewardConfig;

  /// 重置（测试用）
  void reset() {
    _inviteCodes.clear();
    _inviteRecords.clear();
    _userInviteCounts.clear();
  }
}

/// 全局邀请服务实例
final invitationService = InvitationService();
