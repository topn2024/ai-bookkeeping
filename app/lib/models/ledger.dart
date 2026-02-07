import 'dart:convert';

import 'package:flutter/material.dart';

/// 账本类型枚举
enum LedgerType {
  /// 个人账本
  personal,
  /// 家庭账本
  family,
  /// 情侣账本
  couple,
  /// 群组账本（如室友、朋友）
  group,
  /// 专项账本（如旅行、装修）
  special,
}

/// 账本类型扩展
extension LedgerTypeExtension on LedgerType {
  /// 显示名称
  String get displayName {
    switch (this) {
      case LedgerType.personal:
        return '个人账本';
      case LedgerType.family:
        return '家庭账本';
      case LedgerType.couple:
        return '情侣账本';
      case LedgerType.group:
        return '群组账本';
      case LedgerType.special:
        return '专项账本';
    }
  }

  /// 账本描述
  String get description {
    switch (this) {
      case LedgerType.personal:
        return '仅自己可见的私人账本';
      case LedgerType.family:
        return '与家人共享的账本';
      case LedgerType.couple:
        return '与伴侣共享的账本';
      case LedgerType.group:
        return '与朋友或室友共享的账本';
      case LedgerType.special:
        return '针对特定项目的专项账本';
    }
  }

  /// 默认图标
  IconData get icon {
    switch (this) {
      case LedgerType.personal:
        return Icons.person;
      case LedgerType.family:
        return Icons.family_restroom;
      case LedgerType.couple:
        return Icons.favorite;
      case LedgerType.group:
        return Icons.group;
      case LedgerType.special:
        return Icons.star;
    }
  }

  /// 默认颜色
  Color get defaultColor {
    switch (this) {
      case LedgerType.personal:
        return const Color(0xFF2196F3); // 蓝色
      case LedgerType.family:
        return const Color(0xFF4CAF50); // 绿色
      case LedgerType.couple:
        return const Color(0xFFE91E63); // 粉色
      case LedgerType.group:
        return const Color(0xFF9C27B0); // 紫色
      case LedgerType.special:
        return const Color(0xFFFF9800); // 橙色
    }
  }

  /// 是否支持多成员
  bool get supportsMultipleMembers {
    switch (this) {
      case LedgerType.personal:
        return false;
      case LedgerType.family:
      case LedgerType.couple:
      case LedgerType.group:
      case LedgerType.special:
        return true;
    }
  }

  /// 是否支持AA分摊
  bool get supportsSplit {
    switch (this) {
      case LedgerType.personal:
        return false;
      case LedgerType.family:
      case LedgerType.couple:
      case LedgerType.group:
      case LedgerType.special:
        return true;
    }
  }

  /// 最大成员数
  int get maxMembers {
    switch (this) {
      case LedgerType.personal:
        return 1;
      case LedgerType.couple:
        return 2;
      case LedgerType.family:
        return 20;
      case LedgerType.group:
        return 50;
      case LedgerType.special:
        return 100;
    }
  }
}

/// 账本可见性
enum LedgerVisibility {
  /// 完全私密（仅自己可见）
  private,
  /// 对所有成员可见
  members,
  /// 选择性可见（部分成员可见）
  selective,
}

/// 可见性扩展
extension LedgerVisibilityExtension on LedgerVisibility {
  String get displayName {
    switch (this) {
      case LedgerVisibility.private:
        return '私密';
      case LedgerVisibility.members:
        return '成员可见';
      case LedgerVisibility.selective:
        return '部分可见';
    }
  }

  String get description {
    switch (this) {
      case LedgerVisibility.private:
        return '仅账本所有者可见';
      case LedgerVisibility.members:
        return '所有账本成员可见';
      case LedgerVisibility.selective:
        return '仅选定的成员可见';
    }
  }

  IconData get icon {
    switch (this) {
      case LedgerVisibility.private:
        return Icons.lock;
      case LedgerVisibility.members:
        return Icons.visibility;
      case LedgerVisibility.selective:
        return Icons.visibility_outlined;
    }
  }
}

/// 账本设置
class LedgerSettings {
  /// 是否启用预算
  final bool enableBudget;
  /// 是否启用审批
  final bool enableApproval;
  /// 审批阈值（超过此金额需要审批）
  final double? approvalThreshold;
  /// 是否启用AA分摊
  final bool enableSplit;
  /// 是否启用储蓄目标
  final bool enableSavingsGoal;
  /// 默认货币
  final String currency;
  /// 是否显示成员余额
  final bool showMemberBalance;
  /// 是否允许成员邀请他人
  final bool allowMemberInvite;

  const LedgerSettings({
    this.enableBudget = true,
    this.enableApproval = false,
    this.approvalThreshold,
    this.enableSplit = true,
    this.enableSavingsGoal = true,
    this.currency = 'CNY',
    this.showMemberBalance = true,
    this.allowMemberInvite = false,
  });

  LedgerSettings copyWith({
    bool? enableBudget,
    bool? enableApproval,
    double? approvalThreshold,
    bool? enableSplit,
    bool? enableSavingsGoal,
    String? currency,
    bool? showMemberBalance,
    bool? allowMemberInvite,
  }) {
    return LedgerSettings(
      enableBudget: enableBudget ?? this.enableBudget,
      enableApproval: enableApproval ?? this.enableApproval,
      approvalThreshold: approvalThreshold ?? this.approvalThreshold,
      enableSplit: enableSplit ?? this.enableSplit,
      enableSavingsGoal: enableSavingsGoal ?? this.enableSavingsGoal,
      currency: currency ?? this.currency,
      showMemberBalance: showMemberBalance ?? this.showMemberBalance,
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableBudget': enableBudget,
      'enableApproval': enableApproval,
      'approvalThreshold': approvalThreshold,
      'enableSplit': enableSplit,
      'enableSavingsGoal': enableSavingsGoal,
      'currency': currency,
      'showMemberBalance': showMemberBalance,
      'allowMemberInvite': allowMemberInvite,
    };
  }

  factory LedgerSettings.fromMap(Map<String, dynamic> map) {
    return LedgerSettings(
      enableBudget: map['enableBudget'] ?? true,
      enableApproval: map['enableApproval'] ?? false,
      approvalThreshold: map['approvalThreshold']?.toDouble(),
      enableSplit: map['enableSplit'] ?? true,
      enableSavingsGoal: map['enableSavingsGoal'] ?? true,
      currency: map['currency'] ?? 'CNY',
      showMemberBalance: map['showMemberBalance'] ?? true,
      allowMemberInvite: map['allowMemberInvite'] ?? false,
    );
  }
}

/// 账本数据模型
class Ledger {
  /// 账本唯一标识
  final String id;
  /// 账本名称
  final String name;
  /// 账本描述
  final String? description;
  /// 账本类型
  final LedgerType type;
  /// 账本图标
  final IconData icon;
  /// 账本颜色
  final Color color;
  /// 是否为默认账本
  final bool isDefault;
  /// 创建时间
  final DateTime createdAt;
  /// 更新时间
  final DateTime? updatedAt;
  /// 成员ID列表
  final List<String> memberIds;
  /// 账本所有者ID
  final String ownerId;
  /// 可见性设置
  final LedgerVisibility visibility;
  /// 邀请码
  final String? inviteCode;
  /// 邀请码过期时间
  final DateTime? inviteCodeExpiry;
  /// 是否已归档
  final bool isArchived;
  /// 账本设置
  final LedgerSettings settings;
  /// 封面图片URL
  final String? coverImage;

  const Ledger({
    required this.id,
    required this.name,
    this.description,
    this.type = LedgerType.personal,
    required this.icon,
    required this.color,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
    this.memberIds = const [],
    required this.ownerId,
    this.visibility = LedgerVisibility.members,
    this.inviteCode,
    this.inviteCodeExpiry,
    this.isArchived = false,
    this.settings = const LedgerSettings(),
    this.coverImage,
  });

  /// 是否为共享账本
  bool get isShared => type.supportsMultipleMembers && memberIds.length > 1;

  /// 是否支持AA分摊
  bool get supportsSplit => type.supportsSplit && settings.enableSplit;

  /// 邀请码是否有效
  bool get isInviteCodeValid {
    if (inviteCode == null || inviteCode!.isEmpty) return false;
    if (inviteCodeExpiry == null) return true;
    return DateTime.now().isBefore(inviteCodeExpiry!);
  }

  /// 是否已达到最大成员数
  bool get isMaxMembersReached => memberIds.length >= type.maxMembers;

  Ledger copyWith({
    String? id,
    String? name,
    String? description,
    LedgerType? type,
    IconData? icon,
    Color? color,
    bool? isDefault,
    DateTime? updatedAt,
    List<String>? memberIds,
    String? ownerId,
    LedgerVisibility? visibility,
    String? inviteCode,
    DateTime? inviteCodeExpiry,
    bool? isArchived,
    LedgerSettings? settings,
    String? coverImage,
  }) {
    return Ledger(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      memberIds: memberIds ?? this.memberIds,
      ownerId: ownerId ?? this.ownerId,
      visibility: visibility ?? this.visibility,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteCodeExpiry: inviteCodeExpiry ?? this.inviteCodeExpiry,
      isArchived: isArchived ?? this.isArchived,
      settings: settings ?? this.settings,
      coverImage: coverImage ?? this.coverImage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'icon': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'color': color.toARGB32(),
      'isDefault': isDefault ? 1 : 0,  // SQLite: bool → int
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'memberIds': jsonEncode(memberIds),  // SQLite: List → JSON string
      'ownerId': ownerId,
      'visibility': visibility.name,
      'inviteCode': inviteCode,
      'inviteCodeExpiry': inviteCodeExpiry?.toIso8601String(),
      'isArchived': isArchived ? 1 : 0,  // SQLite: bool → int
      'settings': jsonEncode(settings.toMap()),  // SQLite: Map → JSON string
      'coverImage': coverImage,
    };
  }

  factory Ledger.fromMap(Map<String, dynamic> map) {
    // 解析 memberIds：支持 JSON 字符串或 List
    List<String> parseMemberIds() {
      final raw = map['memberIds'];
      if (raw == null) return [];
      if (raw is String) {
        try {
          return List<String>.from(jsonDecode(raw));
        } catch (_) {
          return [];
        }
      }
      return List<String>.from(raw);
    }

    // 解析 settings：支持 JSON 字符串或 Map
    LedgerSettings parseSettings() {
      final raw = map['settings'];
      if (raw == null) return const LedgerSettings();
      if (raw is String) {
        try {
          return LedgerSettings.fromMap(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {
          return const LedgerSettings();
        }
      }
      return LedgerSettings.fromMap(raw as Map<String, dynamic>);
    }

    // 解析 bool：支持 int (0/1) 或 bool
    bool parseBool(dynamic value, {bool defaultValue = false}) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value != 0;
      return defaultValue;
    }

    return Ledger(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      type: LedgerType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LedgerType.personal,
      ),
      icon: IconData(
        map['icon'] as int,
        fontFamily: map['iconFontFamily'] as String?,
      ),
      color: Color(map['color'] as int),
      isDefault: parseBool(map['isDefault']),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      memberIds: parseMemberIds(),
      ownerId: map['ownerId'] as String,
      visibility: LedgerVisibility.values.firstWhere(
        (e) => e.name == map['visibility'],
        orElse: () => LedgerVisibility.members,
      ),
      inviteCode: map['inviteCode'] as String?,
      inviteCodeExpiry: map['inviteCodeExpiry'] != null
          ? DateTime.parse(map['inviteCodeExpiry'] as String)
          : null,
      isArchived: parseBool(map['isArchived']),
      settings: parseSettings(),
      coverImage: map['coverImage'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ledger && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Ledger(id: $id, name: $name, type: ${type.displayName}, members: ${memberIds.length})';
  }
}

/// 默认账本配置
class DefaultLedgers {
  static Ledger defaultLedger(String ownerId) => Ledger(
        id: 'default',
        name: '日常账本',
        description: '默认账本',
        type: LedgerType.personal,
        icon: Icons.book,
        color: const Color(0xFF2196F3),
        isDefault: true,
        createdAt: DateTime.now(),
        ownerId: ownerId,
      );

  /// 创建家庭账本模板
  static Ledger familyTemplate(String ownerId) => Ledger(
        id: '',
        name: '家庭账本',
        description: '与家人共同管理财务',
        type: LedgerType.family,
        icon: Icons.family_restroom,
        color: const Color(0xFF4CAF50),
        createdAt: DateTime.now(),
        ownerId: ownerId,
        settings: const LedgerSettings(
          enableBudget: true,
          enableApproval: true,
          approvalThreshold: 500.0,
          enableSplit: true,
          enableSavingsGoal: true,
        ),
      );

  /// 创建情侣账本模板
  static Ledger coupleTemplate(String ownerId) => Ledger(
        id: '',
        name: '我们的账本',
        description: '共同记录生活点滴',
        type: LedgerType.couple,
        icon: Icons.favorite,
        color: const Color(0xFFE91E63),
        createdAt: DateTime.now(),
        ownerId: ownerId,
        settings: const LedgerSettings(
          enableBudget: true,
          enableSplit: true,
          enableSavingsGoal: true,
          showMemberBalance: true,
        ),
      );

  /// 创建群组账本模板
  static Ledger groupTemplate(String ownerId, String name) => Ledger(
        id: '',
        name: name,
        description: '群组共享账本',
        type: LedgerType.group,
        icon: Icons.group,
        color: const Color(0xFF9C27B0),
        createdAt: DateTime.now(),
        ownerId: ownerId,
        settings: const LedgerSettings(
          enableBudget: false,
          enableSplit: true,
          enableSavingsGoal: false,
          allowMemberInvite: true,
        ),
      );

  /// 创建专项账本模板
  static Ledger specialTemplate(String ownerId, String name) => Ledger(
        id: '',
        name: name,
        description: '专项支出账本',
        type: LedgerType.special,
        icon: Icons.star,
        color: const Color(0xFFFF9800),
        createdAt: DateTime.now(),
        ownerId: ownerId,
        settings: const LedgerSettings(
          enableBudget: true,
          enableSplit: true,
          enableSavingsGoal: true,
        ),
      );
}
