import 'package:flutter/material.dart';

/// 邀请码类型
enum InviteCodeType {
  /// 标准邀请码
  standard,

  /// VIP 邀请码（有额外奖励）
  vip,

  /// 活动限定邀请码
  event,

  /// 内测邀请码
  beta,
}

extension InviteCodeTypeExtension on InviteCodeType {
  String get displayName {
    switch (this) {
      case InviteCodeType.standard:
        return '标准邀请';
      case InviteCodeType.vip:
        return 'VIP邀请';
      case InviteCodeType.event:
        return '活动限定';
      case InviteCodeType.beta:
        return '内测邀请';
    }
  }

  /// 邀请者奖励积分
  int get inviterReward {
    switch (this) {
      case InviteCodeType.standard:
        return 50;
      case InviteCodeType.vip:
        return 100;
      case InviteCodeType.event:
        return 80;
      case InviteCodeType.beta:
        return 30;
    }
  }

  /// 被邀请者奖励积分
  int get inviteeReward {
    switch (this) {
      case InviteCodeType.standard:
        return 30;
      case InviteCodeType.vip:
        return 60;
      case InviteCodeType.event:
        return 50;
      case InviteCodeType.beta:
        return 20;
    }
  }
}

/// 邀请码状态
enum InviteCodeStatus {
  /// 可用
  active,

  /// 已用完（达到使用上限）
  exhausted,

  /// 已过期
  expired,

  /// 已禁用
  disabled,
}

extension InviteCodeStatusExtension on InviteCodeStatus {
  String get displayName {
    switch (this) {
      case InviteCodeStatus.active:
        return '可用';
      case InviteCodeStatus.exhausted:
        return '已用完';
      case InviteCodeStatus.expired:
        return '已过期';
      case InviteCodeStatus.disabled:
        return '已禁用';
    }
  }

  Color get color {
    switch (this) {
      case InviteCodeStatus.active:
        return Colors.green;
      case InviteCodeStatus.exhausted:
        return Colors.orange;
      case InviteCodeStatus.expired:
        return Colors.grey;
      case InviteCodeStatus.disabled:
        return Colors.red;
    }
  }
}

/// 邀请码模型
class InviteCode {
  final String id;
  final String code;                  // 邀请码字符串
  final String ownerId;               // 邀请码所有者ID
  final InviteCodeType type;
  final InviteCodeStatus status;
  final int maxUses;                  // 最大使用次数（0表示无限）
  final int usedCount;                // 已使用次数
  final DateTime? expiresAt;          // 过期时间
  final String? campaignId;           // 关联的活动ID
  final Map<String, dynamic>? metadata; // 额外数据
  final DateTime createdAt;

  const InviteCode({
    required this.id,
    required this.code,
    required this.ownerId,
    required this.type,
    this.status = InviteCodeStatus.active,
    this.maxUses = 0,
    this.usedCount = 0,
    this.expiresAt,
    this.campaignId,
    this.metadata,
    required this.createdAt,
  });

  /// 是否可用
  bool get isUsable {
    if (status != InviteCodeStatus.active) return false;
    if (maxUses > 0 && usedCount >= maxUses) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// 剩余可用次数（-1表示无限）
  int get remainingUses {
    if (maxUses == 0) return -1;
    return (maxUses - usedCount).clamp(0, maxUses);
  }

  /// 是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 剩余有效天数
  int? get daysUntilExpiry {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    final diff = expiresAt!.difference(now).inDays;
    return diff.clamp(0, 365);
  }

  InviteCode copyWith({
    String? id,
    String? code,
    String? ownerId,
    InviteCodeType? type,
    InviteCodeStatus? status,
    int? maxUses,
    int? usedCount,
    DateTime? expiresAt,
    String? campaignId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return InviteCode(
      id: id ?? this.id,
      code: code ?? this.code,
      ownerId: ownerId ?? this.ownerId,
      type: type ?? this.type,
      status: status ?? this.status,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      expiresAt: expiresAt ?? this.expiresAt,
      campaignId: campaignId ?? this.campaignId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'ownerId': ownerId,
      'type': type.index,
      'status': status.index,
      'maxUses': maxUses,
      'usedCount': usedCount,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'campaignId': campaignId,
      'metadata': metadata?.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory InviteCode.fromMap(Map<String, dynamic> map) {
    return InviteCode(
      id: map['id'] as String,
      code: map['code'] as String,
      ownerId: map['ownerId'] as String,
      type: InviteCodeType.values[map['type'] as int],
      status: InviteCodeStatus.values[map['status'] as int],
      maxUses: map['maxUses'] as int? ?? 0,
      usedCount: map['usedCount'] as int? ?? 0,
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int)
          : null,
      campaignId: map['campaignId'] as String?,
      metadata: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// 邀请记录
class InviteRecord {
  final String id;
  final String inviteCodeId;          // 使用的邀请码ID
  final String inviterId;             // 邀请者ID
  final String inviteeId;             // 被邀请者ID
  final int inviterRewardPoints;      // 邀请者获得的积分
  final int inviteeRewardPoints;      // 被邀请者获得的积分
  final bool inviterRewardClaimed;    // 邀请者是否已领取奖励
  final bool inviteeRewardClaimed;    // 被邀请者是否已领取奖励
  final DateTime usedAt;

  const InviteRecord({
    required this.id,
    required this.inviteCodeId,
    required this.inviterId,
    required this.inviteeId,
    required this.inviterRewardPoints,
    required this.inviteeRewardPoints,
    this.inviterRewardClaimed = false,
    this.inviteeRewardClaimed = false,
    required this.usedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inviteCodeId': inviteCodeId,
      'inviterId': inviterId,
      'inviteeId': inviteeId,
      'inviterRewardPoints': inviterRewardPoints,
      'inviteeRewardPoints': inviteeRewardPoints,
      'inviterRewardClaimed': inviterRewardClaimed ? 1 : 0,
      'inviteeRewardClaimed': inviteeRewardClaimed ? 1 : 0,
      'usedAt': usedAt.millisecondsSinceEpoch,
    };
  }

  factory InviteRecord.fromMap(Map<String, dynamic> map) {
    return InviteRecord(
      id: map['id'] as String,
      inviteCodeId: map['inviteCodeId'] as String,
      inviterId: map['inviterId'] as String,
      inviteeId: map['inviteeId'] as String,
      inviterRewardPoints: map['inviterRewardPoints'] as int,
      inviteeRewardPoints: map['inviteeRewardPoints'] as int,
      inviterRewardClaimed: map['inviterRewardClaimed'] == 1,
      inviteeRewardClaimed: map['inviteeRewardClaimed'] == 1,
      usedAt: DateTime.fromMillisecondsSinceEpoch(map['usedAt'] as int),
    );
  }
}

/// 邀请统计摘要
class InviteStatistics {
  final int totalInvites;             // 总邀请数
  final int successfulInvites;        // 成功邀请数（被邀请者注册并使用）
  final int activeInvitees;           // 活跃被邀请者数
  final int totalRewardsEarned;       // 总获得奖励积分
  final int unclaimedRewards;         // 未领取奖励积分
  final List<InviteRecord> recentInvites; // 最近邀请记录

  const InviteStatistics({
    required this.totalInvites,
    required this.successfulInvites,
    required this.activeInvitees,
    required this.totalRewardsEarned,
    required this.unclaimedRewards,
    required this.recentInvites,
  });

  /// 邀请成功率
  double get successRate =>
      totalInvites > 0 ? successfulInvites / totalInvites : 0;

  /// 活跃率
  double get activeRate =>
      successfulInvites > 0 ? activeInvitees / successfulInvites : 0;

  factory InviteStatistics.empty() {
    return const InviteStatistics(
      totalInvites: 0,
      successfulInvites: 0,
      activeInvitees: 0,
      totalRewardsEarned: 0,
      unclaimedRewards: 0,
      recentInvites: [],
    );
  }
}

/// 邀请活动
class InviteCampaign {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int bonusMultiplier;          // 奖励倍数
  final int maxParticipants;          // 最大参与人数（0表示无限）
  final int currentParticipants;      // 当前参与人数
  final bool isActive;
  final Map<String, dynamic>? rules;  // 活动规则
  final DateTime createdAt;

  const InviteCampaign({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.bonusMultiplier = 1,
    this.maxParticipants = 0,
    this.currentParticipants = 0,
    this.isActive = true,
    this.rules,
    required this.createdAt,
  });

  /// 活动是否正在进行
  bool get isOngoing {
    final now = DateTime.now();
    return isActive &&
        now.isAfter(startDate) &&
        now.isBefore(endDate) &&
        (maxParticipants == 0 || currentParticipants < maxParticipants);
  }

  /// 剩余名额
  int get remainingSlots {
    if (maxParticipants == 0) return -1;
    return (maxParticipants - currentParticipants).clamp(0, maxParticipants);
  }

  /// 剩余天数
  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays.clamp(0, 365);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'bonusMultiplier': bonusMultiplier,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'isActive': isActive ? 1 : 0,
      'rules': rules?.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory InviteCampaign.fromMap(Map<String, dynamic> map) {
    return InviteCampaign(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int),
      bonusMultiplier: map['bonusMultiplier'] as int? ?? 1,
      maxParticipants: map['maxParticipants'] as int? ?? 0,
      currentParticipants: map['currentParticipants'] as int? ?? 0,
      isActive: map['isActive'] == 1,
      rules: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// 分享渠道
enum ShareChannel {
  /// 微信
  wechat,

  /// 微信朋友圈
  wechatMoments,

  /// QQ
  qq,

  /// 微博
  weibo,

  /// 复制链接
  copyLink,

  /// 系统分享
  system,
}

extension ShareChannelExtension on ShareChannel {
  String get displayName {
    switch (this) {
      case ShareChannel.wechat:
        return '微信好友';
      case ShareChannel.wechatMoments:
        return '朋友圈';
      case ShareChannel.qq:
        return 'QQ';
      case ShareChannel.weibo:
        return '微博';
      case ShareChannel.copyLink:
        return '复制链接';
      case ShareChannel.system:
        return '更多';
    }
  }

  IconData get icon {
    switch (this) {
      case ShareChannel.wechat:
        return Icons.chat;
      case ShareChannel.wechatMoments:
        return Icons.public;
      case ShareChannel.qq:
        return Icons.chat_bubble;
      case ShareChannel.weibo:
        return Icons.rss_feed;
      case ShareChannel.copyLink:
        return Icons.link;
      case ShareChannel.system:
        return Icons.share;
    }
  }

  Color get color {
    switch (this) {
      case ShareChannel.wechat:
        return Colors.green;
      case ShareChannel.wechatMoments:
        return Colors.green.shade700;
      case ShareChannel.qq:
        return Colors.blue;
      case ShareChannel.weibo:
        return Colors.red;
      case ShareChannel.copyLink:
        return Colors.grey;
      case ShareChannel.system:
        return Colors.blueGrey;
    }
  }
}

/// 分享记录
class ShareRecord {
  final String id;
  final ShareChannel channel;
  final String? inviteCodeId;         // 分享的邀请码ID
  final String? contentType;          // 分享内容类型（invite, achievement, milestone）
  final String? contentId;            // 分享内容ID
  final DateTime sharedAt;

  const ShareRecord({
    required this.id,
    required this.channel,
    this.inviteCodeId,
    this.contentType,
    this.contentId,
    required this.sharedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'channel': channel.index,
      'inviteCodeId': inviteCodeId,
      'contentType': contentType,
      'contentId': contentId,
      'sharedAt': sharedAt.millisecondsSinceEpoch,
    };
  }

  factory ShareRecord.fromMap(Map<String, dynamic> map) {
    return ShareRecord(
      id: map['id'] as String,
      channel: ShareChannel.values[map['channel'] as int],
      inviteCodeId: map['inviteCodeId'] as String?,
      contentType: map['contentType'] as String?,
      contentId: map['contentId'] as String?,
      sharedAt: DateTime.fromMillisecondsSinceEpoch(map['sharedAt'] as int),
    );
  }
}
