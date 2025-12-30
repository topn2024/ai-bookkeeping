class User {
  final String id;
  final String? phone;
  final String? email;
  final String? nickname;
  final String? avatarUrl;
  final int memberLevel;
  final DateTime? memberExpireAt;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    this.phone,
    this.email,
    this.nickname,
    this.avatarUrl,
    this.memberLevel = 0,
    this.memberExpireAt,
    required this.createdAt,
    this.lastLoginAt,
  });

  User copyWith({
    String? id,
    String? phone,
    String? email,
    String? nickname,
    String? avatarUrl,
    int? memberLevel,
    DateTime? memberExpireAt,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      memberLevel: memberLevel ?? this.memberLevel,
      memberExpireAt: memberExpireAt ?? this.memberExpireAt,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'member_level': memberLevel,
      'member_expire_at': memberExpireAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  /// 从服务器 API 响应解析
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      memberLevel: json['member_level'] as int? ?? 0,
      memberExpireAt: json['member_expire_at'] != null
          ? DateTime.parse(json['member_expire_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  /// 从本地存储解析（兼容旧格式）
  factory User.fromLocalJson(Map<String, dynamic> json) {
    // 兼容旧格式（使用 displayName 和 milliseconds）
    if (json.containsKey('displayName') || json.containsKey('createdAt') && json['createdAt'] is int) {
      return User(
        id: json['id'] as String,
        email: json['email'] as String?,
        nickname: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        createdAt: json['createdAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
            : DateTime.parse(json['createdAt'] as String),
        lastLoginAt: json['lastLoginAt'] != null
            ? (json['lastLoginAt'] is int
                ? DateTime.fromMillisecondsSinceEpoch(json['lastLoginAt'] as int)
                : DateTime.parse(json['lastLoginAt'] as String))
            : null,
      );
    }
    // 新格式
    return User.fromJson(json);
  }

  /// 显示名称：优先使用昵称，其次使用邮箱前缀或手机号
  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return nickname!;
    }
    if (email != null && email!.isNotEmpty) {
      return email!.split('@').first;
    }
    if (phone != null && phone!.isNotEmpty) {
      return '${phone!.substring(0, 3)}****${phone!.substring(7)}';
    }
    return 'User';
  }

  /// 获取账号标识（邮箱或手机号）
  String get accountIdentifier {
    return email ?? phone ?? id;
  }
}
