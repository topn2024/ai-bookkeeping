import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'http_service.dart';

/// OAuth provider types
enum OAuthProviderType {
  wechat,
  apple,
  google,
}

extension OAuthProviderTypeExtension on OAuthProviderType {
  String get name {
    switch (this) {
      case OAuthProviderType.wechat:
        return 'wechat';
      case OAuthProviderType.apple:
        return 'apple';
      case OAuthProviderType.google:
        return 'google';
    }
  }

  String get displayName {
    switch (this) {
      case OAuthProviderType.wechat:
        return '微信';
      case OAuthProviderType.apple:
        return 'Apple';
      case OAuthProviderType.google:
        return 'Google';
    }
  }
}

/// OAuth configuration from server
class OAuthConfig {
  final bool wechatEnabled;
  final String? wechatAppId;
  final bool appleEnabled;
  final String? appleClientId;
  final bool googleEnabled;
  final String? googleClientId;
  final String? googleRedirectUri;

  OAuthConfig({
    this.wechatEnabled = false,
    this.wechatAppId,
    this.appleEnabled = false,
    this.appleClientId,
    this.googleEnabled = false,
    this.googleClientId,
    this.googleRedirectUri,
  });

  factory OAuthConfig.fromJson(Map<String, dynamic> json) {
    final wechat = json['wechat'] as Map<String, dynamic>? ?? {};
    final apple = json['apple'] as Map<String, dynamic>? ?? {};
    final google = json['google'] as Map<String, dynamic>? ?? {};

    return OAuthConfig(
      wechatEnabled: wechat['enabled'] ?? false,
      wechatAppId: wechat['app_id'],
      appleEnabled: apple['enabled'] ?? false,
      appleClientId: apple['client_id'],
      googleEnabled: google['enabled'] ?? false,
      googleClientId: google['client_id'],
      googleRedirectUri: google['redirect_uri'],
    );
  }

  bool isProviderEnabled(OAuthProviderType provider) {
    switch (provider) {
      case OAuthProviderType.wechat:
        return wechatEnabled;
      case OAuthProviderType.apple:
        return appleEnabled;
      case OAuthProviderType.google:
        return googleEnabled;
    }
  }
}

/// OAuth provider binding info
class OAuthProviderInfo {
  final String id;
  final String provider;
  final String? providerUsername;
  final String? providerAvatar;
  final String? providerEmail;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  OAuthProviderInfo({
    required this.id,
    required this.provider,
    this.providerUsername,
    this.providerAvatar,
    this.providerEmail,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory OAuthProviderInfo.fromJson(Map<String, dynamic> json) {
    return OAuthProviderInfo(
      id: json['id'],
      provider: json['provider'],
      providerUsername: json['provider_username'],
      providerAvatar: json['provider_avatar'],
      providerEmail: json['provider_email'],
      isActive: json['is_active'] ?? true,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  OAuthProviderType get providerType {
    switch (provider) {
      case 'wechat':
        return OAuthProviderType.wechat;
      case 'apple':
        return OAuthProviderType.apple;
      case 'google':
        return OAuthProviderType.google;
      default:
        return OAuthProviderType.wechat;
    }
  }
}

/// Service for OAuth authentication
class OAuthService {
  static final OAuthService _instance = OAuthService._internal();
  final HttpService _http = HttpService();

  factory OAuthService() => _instance;
  OAuthService._internal();

  /// Get OAuth configuration from server
  Future<OAuthConfig> getConfig() async {
    try {
      final response = await _http.get('/auth/oauth/config');
      return OAuthConfig.fromJson(response.data);
    } catch (e) {
      debugPrint('Failed to get OAuth config: $e');
      return OAuthConfig();
    }
  }

  /// Login with OAuth provider
  /// Returns token data if successful
  Future<Map<String, dynamic>> loginWithOAuth(
    OAuthProviderType provider,
    String authCode,
  ) async {
    final response = await _http.post('/auth/oauth/login', data: {
      'provider': provider.name,
      'code': authCode,
    });
    return response.data;
  }

  /// Bind OAuth account to current user
  Future<OAuthProviderInfo> bindOAuthAccount(
    OAuthProviderType provider,
    String authCode,
  ) async {
    final response = await _http.post(
      '/auth/oauth/bind/${provider.name}',
      data: {'code': authCode},
    );
    return OAuthProviderInfo.fromJson(response.data);
  }

  /// Unbind OAuth account from current user
  Future<void> unbindOAuthAccount(OAuthProviderType provider) async {
    await _http.delete('/auth/oauth/unbind/${provider.name}');
  }

  /// Get user's bound OAuth providers
  Future<List<OAuthProviderInfo>> getBoundProviders() async {
    final response = await _http.get('/auth/oauth/providers');
    final providers = response.data['providers'] as List;
    return providers.map((p) => OAuthProviderInfo.fromJson(p)).toList();
  }

  /// Get available providers with bound status
  Future<List<Map<String, dynamic>>> getAvailableProviders() async {
    final response = await _http.get('/auth/oauth/providers');
    return List<Map<String, dynamic>>.from(response.data['available_providers']);
  }
}
