import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/oauth_service.dart';
import '../services/http_service.dart';
import '../models/user.dart';
import 'auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// OAuth state for managing third-party login
class OAuthState {
  final bool isLoading;
  final OAuthConfig? config;
  final List<OAuthProviderInfo> boundProviders;
  final String? error;

  const OAuthState({
    this.isLoading = false,
    this.config,
    this.boundProviders = const [],
    this.error,
  });

  OAuthState copyWith({
    bool? isLoading,
    OAuthConfig? config,
    List<OAuthProviderInfo>? boundProviders,
    String? error,
  }) {
    return OAuthState(
      isLoading: isLoading ?? this.isLoading,
      config: config ?? this.config,
      boundProviders: boundProviders ?? this.boundProviders,
      error: error,
    );
  }

  bool isProviderBound(OAuthProviderType provider) {
    return boundProviders.any((p) => p.provider == provider.name);
  }
}

/// OAuth notifier for managing OAuth state
class OAuthNotifier extends Notifier<OAuthState> {
  final OAuthService _oauthService = OAuthService();
  final HttpService _httpService = HttpService();

  @override
  OAuthState build() {
    _loadConfig();
    return const OAuthState();
  }

  Future<void> _loadConfig() async {
    state = state.copyWith(isLoading: true);
    try {
      final config = await _oauthService.getConfig();
      state = state.copyWith(config: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load OAuth config: $e',
      );
    }
  }

  /// Reload OAuth configuration
  Future<void> refreshConfig() async {
    await _loadConfig();
  }

  /// Load bound providers for current user
  Future<void> loadBoundProviders() async {
    state = state.copyWith(isLoading: true);
    try {
      final providers = await _oauthService.getBoundProviders();
      state = state.copyWith(boundProviders: providers, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load bound providers: $e',
      );
    }
  }

  /// Login with OAuth provider
  /// Returns true if login successful
  Future<bool> loginWithOAuth(
    OAuthProviderType provider,
    String authCode,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _oauthService.loginWithOAuth(provider, authCode);

      // Save token
      final token = result['access_token'] as String;
      _httpService.setAuthToken(token);

      // Save user data
      final userData = result['user'] as Map<String, dynamic>;
      final user = User(
        id: userData['id'],
        email: userData['email'],
        displayName: userData['nickname'],
        avatarUrl: userData['avatar_url'],
        createdAt: DateTime.parse(userData['created_at']),
        lastLoginAt: DateTime.now(),
      );

      // Store locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));
      await prefs.setString('auth_token', token);

      // Update auth provider
      ref.read(authProvider.notifier).setUserFromOAuth(user);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
      return false;
    }
  }

  /// Bind OAuth account to current user
  Future<bool> bindOAuthAccount(
    OAuthProviderType provider,
    String authCode,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final providerInfo = await _oauthService.bindOAuthAccount(provider, authCode);

      // Update bound providers list
      final updatedProviders = [...state.boundProviders, providerInfo];
      state = state.copyWith(boundProviders: updatedProviders, isLoading: false);

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
      return false;
    }
  }

  /// Unbind OAuth account from current user
  Future<bool> unbindOAuthAccount(OAuthProviderType provider) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _oauthService.unbindOAuthAccount(provider);

      // Update bound providers list
      final updatedProviders = state.boundProviders
          .where((p) => p.provider != provider.name)
          .toList();
      state = state.copyWith(boundProviders: updatedProviders, isLoading: false);

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  String _parseError(dynamic error) {
    if (error.toString().contains('400')) {
      return '绑定失败，该账号可能已被其他用户绑定';
    } else if (error.toString().contains('401')) {
      return '授权失败，请重试';
    } else if (error.toString().contains('network')) {
      return '网络错误，请检查网络连接';
    }
    return '操作失败: ${error.toString()}';
  }
}

/// Provider for OAuth state
final oauthProvider = NotifierProvider<OAuthNotifier, OAuthState>(OAuthNotifier.new);

/// Provider for checking if specific OAuth provider is available
final isOAuthProviderAvailableProvider = Provider.family<bool, OAuthProviderType>((ref, provider) {
  final oauthState = ref.watch(oauthProvider);
  return oauthState.config?.isProviderEnabled(provider) ?? false;
});

/// Provider for checking if specific OAuth provider is bound
final isOAuthProviderBoundProvider = Provider.family<bool, OAuthProviderType>((ref, provider) {
  final oauthState = ref.watch(oauthProvider);
  return oauthState.isProviderBound(provider);
});
