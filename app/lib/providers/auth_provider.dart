import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/secure_storage_service.dart';
import '../services/http_service.dart';
import '../services/qwen_service.dart';
import '../core/config.dart';
import 'ledger_context_provider.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
}

class AuthNotifier extends Notifier<AuthState> {
  final SecureStorageService _secureStorage = SecureStorageService();
  final HttpService _http = HttpService();

  @override
  AuthState build() {
    Future.microtask(() => _loadUser().catchError((e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '初始化失败: $e',
      );
    }));
    return const AuthState(status: AuthStatus.loading);
  }

  /// 初始化账本上下文
  Future<void> _initializeLedgerContext(String userId) async {
    try {
      await ref.read(ledgerContextProvider.notifier).initialize(userId);
    } catch (e) {
      debugPrint('Failed to initialize ledger context: $e');
    }
  }

  /// 从本地存储加载用户（用于离线访问）
  Future<void> _loadUser() async {
    try {
      // 初始化 HTTP 服务（加载已保存的 token）
      await _http.initialize();
      // 初始化配置（加载缓存的 API keys）
      await appConfig.initialize();

      // 从安全存储加载用户数据
      final userJson = await _secureStorage.read('current_user_data');

      if (userJson != null) {
        try {
          final user = User.fromLocalJson(jsonDecode(userJson));

          // 检查是否有有效 token
          final hasToken = await _http.hasValidToken();

          if (hasToken) {
            // 有 token，尝试验证并刷新用户信息
            try {
              final response = await _http.get('/auth/me');
              if (response.statusCode == 200) {
                final serverUser = User.fromJson(response.data);
                // 更新本地缓存
                await _secureStorage.write(
                    'current_user_data', jsonEncode(serverUser.toJson()));
                // 刷新 API keys
                final fetchResult = await appConfig.fetchFromServer();
                // 重新初始化 QwenService 以使用新的 API key
                QwenService().reinitialize();
                if (!fetchResult) {
                  debugPrint('AuthProvider: Warning - Failed to fetch API keys from server');
                }
                state = AuthState(
                  status: AuthStatus.authenticated,
                  user: serverUser,
                );
                // 初始化账本上下文
                await _initializeLedgerContext(serverUser.id);
                return;
              }
            } catch (e) {
              // 网络错误，使用本地缓存（包括缓存的 API keys）
              // 重新初始化 QwenService 以使用缓存的 API key
              QwenService().reinitialize();
              state = AuthState(
                status: AuthStatus.authenticated,
                user: user,
              );
              // 初始化账本上下文
              await _initializeLedgerContext(user.id);
              return;
            }
          }

          // 没有有效 token，需要重新登录
          state = const AuthState(status: AuthStatus.unauthenticated);
        } catch (e) {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 注册新用户
  Future<bool> register({
    String? email,
    String? phone,
    required String password,
    String? nickname,
  }) async {
    if (email == null && phone == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '请输入邮箱或手机号',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final response = await _http.post('/auth/register', data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
        if (nickname != null) 'nickname': nickname,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String?;
        final userData = data['user'] as Map<String, dynamic>;

        // 保存 tokens
        await _http.setTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        // 解析用户信息
        final user = User.fromJson(userData);

        // 保存用户信息到本地
        await _secureStorage.write('current_user_data', jsonEncode(user.toJson()));
        await _secureStorage.saveUserId(user.id);

        // 获取 API 配置
        await appConfig.fetchFromServer();
        // 重新初始化 QwenService 以使用新的 API key
        QwenService().reinitialize();

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );

        // 初始化账本上下文
        await _initializeLedgerContext(user.id);

        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: '注册失败',
        );
        return false;
      }
    } on DioException catch (e) {
      final errorMessage = _parseError(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '注册失败: $e',
      );
      return false;
    }
  }

  /// 登录
  Future<bool> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    if (email == null && phone == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '请输入邮箱或手机号',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final response = await _http.post('/auth/login', data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String?;
        final userData = data['user'] as Map<String, dynamic>;

        // 保存 tokens
        await _http.setTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        // 解析用户信息
        final user = User.fromJson(userData);

        // 保存用户信息到本地
        await _secureStorage.write('current_user_data', jsonEncode(user.toJson()));
        await _secureStorage.saveUserId(user.id);

        // 获取 API 配置
        await appConfig.fetchFromServer();
        // 重新初始化 QwenService 以使用新的 API key
        QwenService().reinitialize();

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );

        // 初始化账本上下文
        await _initializeLedgerContext(user.id);

        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: '登录失败',
        );
        return false;
      }
    } on DioException catch (e) {
      final errorMessage = _parseError(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '登录失败: $e',
      );
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    // 清除 token
    await _http.clearTokens();

    // 清除本地用户数据
    await _secureStorage.clearOnLogout();
    await _secureStorage.delete('current_user_data');

    // 清除缓存的 API 配置
    await appConfig.clearCache();

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// 更新用户资料
  Future<bool> updateProfile({
    String? nickname,
    String? avatarUrl,
  }) async {
    if (state.user == null) return false;

    try {
      final response = await _http.patch('/users/me', data: {
        if (nickname != null) 'nickname': nickname,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      });

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);

        // 更新本地缓存
        await _secureStorage.write('current_user_data', jsonEncode(user.toJson()));

        state = state.copyWith(user: user);
        return true;
      }
    } catch (e) {
      // 网络错误，本地更新
      final updatedUser = state.user!.copyWith(
        nickname: nickname,
        avatarUrl: avatarUrl,
      );
      await _secureStorage.write(
          'current_user_data', jsonEncode(updatedUser.toJson()));
      state = state.copyWith(user: updatedUser);
    }
    return false;
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 设置 OAuth 登录用户（供 OAuth Provider 调用）
  Future<void> setUserFromOAuth(User user, String accessToken, {String? refreshToken}) async {
    await _http.setTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _secureStorage.write('current_user_data', jsonEncode(user.toJson()));
    await _secureStorage.saveUserId(user.id);

    // 获取 API 配置
    await appConfig.fetchFromServer();
    // 重新初始化 QwenService 以使用新的 API key
    QwenService().reinitialize();

    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );
  }

  /// 解析错误信息
  String _parseError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return '网络连接失败，请检查网络设置';
    }

    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      if (data is Map && data.containsKey('detail')) {
        final detail = data['detail'];
        // 翻译常见错误
        switch (detail) {
          case 'Incorrect credentials':
            return '邮箱或密码错误';
          case 'Email already registered':
            return '该邮箱已被注册';
          case 'Phone number already registered':
            return '该手机号已被注册';
          case 'Phone or email is required':
            return '请输入邮箱或手机号';
          case 'User is inactive':
            return '账号已被禁用';
          default:
            return detail.toString();
        }
      }

      switch (statusCode) {
        case 400:
          return '请求参数错误';
        case 401:
          return '认证失败';
        case 403:
          return '没有权限';
        case 404:
          return '账号不存在';
        case 422:
          return '数据验证失败';
        case 500:
          return '服务器错误，请稍后重试';
        default:
          return '请求失败 ($statusCode)';
      }
    }

    return '请求失败: ${e.message}';
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    try {
      final response = await _http.get('/auth/me');
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        await _secureStorage.write('current_user_data', jsonEncode(user.toJson()));
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // 忽略刷新错误
    }
  }

  /// 检查邮箱是否已注册
  Future<bool> checkEmailExists({required String email}) async {
    try {
      // 尝试调用服务器 API 检查邮箱
      final response = await _http.post('/auth/check-email', data: {
        'email': email,
      });
      return response.data['exists'] == true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // API 不存在，功能暂不可用
        throw Exception('密码重置功能暂不可用');
      }
      rethrow;
    }
  }

  /// 重置密码
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await _http.post('/auth/reset-password', data: {
        'email': email,
        'new_password': newPassword,
      });
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // API 不存在，功能暂不可用
        throw Exception('密码重置功能暂不可用');
      }
      rethrow;
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
