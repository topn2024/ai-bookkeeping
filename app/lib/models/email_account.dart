import 'dart:convert';

/// 邮箱服务商
enum EmailProvider { qqMail, mail163, mail126 }

/// 邮箱账户配置模型
class EmailAccount {
  final String id;
  final EmailProvider provider;
  final String emailAddress;
  final String authCode;
  final DateTime? lastSyncTime;
  final bool isActive;

  EmailAccount({
    required this.id,
    required this.provider,
    required this.emailAddress,
    required this.authCode,
    this.lastSyncTime,
    this.isActive = true,
  });

  /// 根据 provider 派生 IMAP 主机
  String get imapHost => switch (provider) {
    EmailProvider.qqMail => 'imap.qq.com',
    EmailProvider.mail163 => 'imap.163.com',
    EmailProvider.mail126 => 'imap.126.com',
  };

  /// IMAP 端口 (SSL)
  int get imapPort => 993;

  /// 是否使用 SSL
  bool get isSecure => true;

  /// 服务商显示名称
  String get providerName => switch (provider) {
    EmailProvider.qqMail => 'QQ邮箱',
    EmailProvider.mail163 => '163邮箱',
    EmailProvider.mail126 => '126邮箱',
  };

  EmailAccount copyWith({
    String? id,
    EmailProvider? provider,
    String? emailAddress,
    String? authCode,
    DateTime? lastSyncTime,
    bool? isActive,
  }) {
    return EmailAccount(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      emailAddress: emailAddress ?? this.emailAddress,
      authCode: authCode ?? this.authCode,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider.index,
      'emailAddress': emailAddress,
      'authCode': authCode,
      'lastSyncTime': lastSyncTime?.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory EmailAccount.fromJson(Map<String, dynamic> json) {
    return EmailAccount(
      id: json['id'] as String,
      provider: EmailProvider.values[json['provider'] as int],
      emailAddress: json['emailAddress'] as String,
      authCode: json['authCode'] as String,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSyncTime'] as int)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static String encodeList(List<EmailAccount> accounts) {
    return jsonEncode(accounts.map((a) => a.toJson()).toList());
  }

  static List<EmailAccount> decodeList(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    return list.map((e) => EmailAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  String toString() {
    return 'EmailAccount(id: $id, provider: $providerName, email: $emailAddress)';
  }
}
