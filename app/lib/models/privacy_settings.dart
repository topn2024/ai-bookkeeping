import 'package:flutter/material.dart';

/// 可见性级别
enum VisibilityLevel {
  /// 仅自己可见
  private,
  /// 所有成员可见
  allMembers,
  /// 仅管理员可见
  adminsOnly,
  /// 选择性可见（指定成员）
  selective,
}

/// 可见性级别扩展
extension VisibilityLevelExtension on VisibilityLevel {
  String get displayName {
    switch (this) {
      case VisibilityLevel.private:
        return '仅自己可见';
      case VisibilityLevel.allMembers:
        return '所有成员可见';
      case VisibilityLevel.adminsOnly:
        return '仅管理员可见';
      case VisibilityLevel.selective:
        return '选择性可见';
    }
  }

  String get description {
    switch (this) {
      case VisibilityLevel.private:
        return '只有您自己可以看到这笔记录';
      case VisibilityLevel.allMembers:
        return '账本所有成员都可以看到';
      case VisibilityLevel.adminsOnly:
        return '只有管理员可以看到';
      case VisibilityLevel.selective:
        return '只有选定的成员可以看到';
    }
  }

  IconData get icon {
    switch (this) {
      case VisibilityLevel.private:
        return Icons.lock;
      case VisibilityLevel.allMembers:
        return Icons.visibility;
      case VisibilityLevel.adminsOnly:
        return Icons.admin_panel_settings;
      case VisibilityLevel.selective:
        return Icons.people_outline;
    }
  }

  Color get color {
    switch (this) {
      case VisibilityLevel.private:
        return const Color(0xFF9E9E9E);
      case VisibilityLevel.allMembers:
        return const Color(0xFF4CAF50);
      case VisibilityLevel.adminsOnly:
        return const Color(0xFF9C27B0);
      case VisibilityLevel.selective:
        return const Color(0xFF2196F3);
    }
  }
}

/// 隐私设置
class PrivacySettings {
  /// 默认可见性
  final VisibilityLevel defaultVisibility;
  /// 是否显示交易金额给其他成员
  final bool showAmountToMembers;
  /// 是否显示交易详情给其他成员
  final bool showDetailsToMembers;
  /// 是否显示交易备注给其他成员
  final bool showNotesToMembers;
  /// 是否显示附件给其他成员
  final bool showAttachmentsToMembers;
  /// 私密分类ID列表（这些分类下的交易默认私密）
  final List<String> privateCategories;
  /// 隐藏余额
  final bool hideBalance;
  /// 隐藏统计
  final bool hideStatistics;

  const PrivacySettings({
    this.defaultVisibility = VisibilityLevel.allMembers,
    this.showAmountToMembers = true,
    this.showDetailsToMembers = true,
    this.showNotesToMembers = true,
    this.showAttachmentsToMembers = true,
    this.privateCategories = const [],
    this.hideBalance = false,
    this.hideStatistics = false,
  });

  PrivacySettings copyWith({
    VisibilityLevel? defaultVisibility,
    bool? showAmountToMembers,
    bool? showDetailsToMembers,
    bool? showNotesToMembers,
    bool? showAttachmentsToMembers,
    List<String>? privateCategories,
    bool? hideBalance,
    bool? hideStatistics,
  }) {
    return PrivacySettings(
      defaultVisibility: defaultVisibility ?? this.defaultVisibility,
      showAmountToMembers: showAmountToMembers ?? this.showAmountToMembers,
      showDetailsToMembers: showDetailsToMembers ?? this.showDetailsToMembers,
      showNotesToMembers: showNotesToMembers ?? this.showNotesToMembers,
      showAttachmentsToMembers:
          showAttachmentsToMembers ?? this.showAttachmentsToMembers,
      privateCategories: privateCategories ?? this.privateCategories,
      hideBalance: hideBalance ?? this.hideBalance,
      hideStatistics: hideStatistics ?? this.hideStatistics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultVisibility': defaultVisibility.index,
      'showAmountToMembers': showAmountToMembers,
      'showDetailsToMembers': showDetailsToMembers,
      'showNotesToMembers': showNotesToMembers,
      'showAttachmentsToMembers': showAttachmentsToMembers,
      'privateCategories': privateCategories,
      'hideBalance': hideBalance,
      'hideStatistics': hideStatistics,
    };
  }

  factory PrivacySettings.fromMap(Map<String, dynamic> map) {
    return PrivacySettings(
      defaultVisibility:
          VisibilityLevel.values[map['defaultVisibility'] as int? ?? 1],
      showAmountToMembers: map['showAmountToMembers'] as bool? ?? true,
      showDetailsToMembers: map['showDetailsToMembers'] as bool? ?? true,
      showNotesToMembers: map['showNotesToMembers'] as bool? ?? true,
      showAttachmentsToMembers:
          map['showAttachmentsToMembers'] as bool? ?? true,
      privateCategories: List<String>.from(map['privateCategories'] ?? []),
      hideBalance: map['hideBalance'] as bool? ?? false,
      hideStatistics: map['hideStatistics'] as bool? ?? false,
    );
  }
}

/// 交易可见性配置
class TransactionVisibility {
  /// 交易ID
  final String transactionId;
  /// 可见性级别
  final VisibilityLevel level;
  /// 可见成员ID列表（用于 selective 模式）
  final List<String> visibleMemberIds;
  /// 创建者ID
  final String createdBy;

  const TransactionVisibility({
    required this.transactionId,
    required this.level,
    this.visibleMemberIds = const [],
    required this.createdBy,
  });

  /// 检查成员是否可见
  bool isVisibleTo(String memberId, {bool isAdmin = false}) {
    // 创建者总是可见
    if (memberId == createdBy) return true;

    switch (level) {
      case VisibilityLevel.private:
        return false;
      case VisibilityLevel.allMembers:
        return true;
      case VisibilityLevel.adminsOnly:
        return isAdmin;
      case VisibilityLevel.selective:
        return visibleMemberIds.contains(memberId);
    }
  }

  TransactionVisibility copyWith({
    String? transactionId,
    VisibilityLevel? level,
    List<String>? visibleMemberIds,
    String? createdBy,
  }) {
    return TransactionVisibility(
      transactionId: transactionId ?? this.transactionId,
      level: level ?? this.level,
      visibleMemberIds: visibleMemberIds ?? this.visibleMemberIds,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'level': level.index,
      'visibleMemberIds': visibleMemberIds,
      'createdBy': createdBy,
    };
  }

  factory TransactionVisibility.fromMap(Map<String, dynamic> map) {
    return TransactionVisibility(
      transactionId: map['transactionId'] as String,
      level: VisibilityLevel.values[map['level'] as int],
      visibleMemberIds: List<String>.from(map['visibleMemberIds'] ?? []),
      createdBy: map['createdBy'] as String,
    );
  }
}

/// 成员隐私偏好
class MemberPrivacyPreference {
  /// 成员ID
  final String memberId;
  /// 账本ID
  final String ledgerId;
  /// 隐私设置
  final PrivacySettings settings;
  /// 最后更新时间
  final DateTime updatedAt;

  const MemberPrivacyPreference({
    required this.memberId,
    required this.ledgerId,
    required this.settings,
    required this.updatedAt,
  });

  MemberPrivacyPreference copyWith({
    String? memberId,
    String? ledgerId,
    PrivacySettings? settings,
    DateTime? updatedAt,
  }) {
    return MemberPrivacyPreference(
      memberId: memberId ?? this.memberId,
      ledgerId: ledgerId ?? this.ledgerId,
      settings: settings ?? this.settings,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'ledgerId': ledgerId,
      'settings': settings.toMap(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MemberPrivacyPreference.fromMap(Map<String, dynamic> map) {
    return MemberPrivacyPreference(
      memberId: map['memberId'] as String,
      ledgerId: map['ledgerId'] as String,
      settings: PrivacySettings.fromMap(map['settings'] as Map<String, dynamic>),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
