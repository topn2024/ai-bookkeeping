import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../services/encryption_service.dart';
import '../services/secure_storage_service.dart';
import '../services/http_service.dart';

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
  static const String _userKey = 'current_user';
  static const String _usersKey = 'registered_users';

  final EncryptionService _encryption = EncryptionService();
  final SecureStorageService _secureStorage = SecureStorageService();
  final HttpService _http = HttpService();

  @override
  AuthState build() {
    // Use Future.microtask to delay loading until state is initialized
    Future.microtask(() => _loadUser());
    return const AuthState(status: AuthStatus.loading);
  }

  Future<void> _loadUser() async {
    // 首先尝试从安全存储加载用户
    final userJson = await _secureStorage.read('current_user_data');

    if (userJson != null) {
      try {
        final user = User.fromJson(jsonDecode(userJson));
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
        return;
      } catch (e) {
        // 安全存储失败，尝试从SharedPreferences迁移
      }
    }

    // 兼容旧版本：从SharedPreferences加载
    final prefs = await SharedPreferences.getInstance();
    final legacyUserJson = prefs.getString(_userKey);

    if (legacyUserJson != null) {
      try {
        final user = User.fromJson(jsonDecode(legacyUserJson));
        // 迁移到安全存储
        await _secureStorage.write('current_user_data', legacyUserJson);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } catch (e) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();

    // Get existing users
    final usersJson = prefs.getString(_usersKey);
    final Map<String, dynamic> users = usersJson != null
        ? jsonDecode(usersJson)
        : {};

    // Check if email already exists
    if (users.containsKey(email)) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '该邮箱已被注册',
      );
      return false;
    }

    // Create new user
    final userId = const Uuid().v4();
    final user = User(
      id: userId,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    // 生成密码盐值
    final salt = _encryption.generateSalt();
    // 使用盐值对密码进行哈希
    final hashedPassword = _encryption.hashPassword(password, salt: salt);

    // 存储用户凭证（密码已哈希）
    users[email] = {
      'passwordHash': hashedPassword,  // 存储哈希后的密码
      'salt': salt,                     // 存储盐值
      'user': user.toJson(),
    };

    await prefs.setString(_usersKey, jsonEncode(users));

    // 用户数据存储到安全存储
    await _secureStorage.write('current_user_data', jsonEncode(user.toJson()));
    await _secureStorage.saveUserId(userId);

    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );

    return true;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      final prefs = await SharedPreferences.getInstance();

      // Get existing users
      final usersJson = prefs.getString(_usersKey);
      if (usersJson == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: '账号不存在，请先注册',
        );
        return false;
      }

      final Map<String, dynamic> users = jsonDecode(usersJson);

    // Check if user exists
    if (!users.containsKey(email)) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '账号不存在，请先注册',
      );
      return false;
    }

    final userData = users[email] as Map<String, dynamic>;

    // 验证密码 - 支持新旧两种格式
    bool passwordValid = false;

    if (userData.containsKey('passwordHash') && userData.containsKey('salt')) {
      // 新格式：使用盐值验证哈希密码
      final salt = userData['salt'] as String;
      passwordValid = _encryption.verifyPassword(
        password,
        userData['passwordHash'] as String,
        salt: salt,
      );
    } else if (userData.containsKey('password')) {
      // 旧格式：明文密码比较（兼容迁移）
      passwordValid = userData['password'] == password;

      // 如果验证成功，迁移到新格式
      if (passwordValid) {
        final salt = _encryption.generateSalt();
        final hashedPassword = _encryption.hashPassword(password, salt: salt);
        userData['passwordHash'] = hashedPassword;
        userData['salt'] = salt;
        userData.remove('password');  // 删除明文密码
        users[email] = userData;
        await prefs.setString(_usersKey, jsonEncode(users));
      }
    }

    if (!passwordValid) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '密码错误',
      );
      return false;
    }

    // Load user and update last login
    final user = User.fromJson(userData['user']).copyWith(
      lastLoginAt: DateTime.now(),
    );

    // Update stored user
    userData['user'] = user.toJson();
    users[email] = userData;

    await prefs.setString(_usersKey, jsonEncode(users));

    // 用户数据存储到安全存储
    await _secureStorage.write('current_user_data', jsonEncode(user.toJson()));
    await _secureStorage.saveUserId(user.id);

    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );

    return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '登录失败: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);

    // 清除安全存储中的用户数据
    await _secureStorage.clearOnLogout();
    await _secureStorage.delete('current_user_data');

    // 清除HTTP服务中的Token
    await _http.clearTokens();

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    if (state.user == null) return;

    final updatedUser = state.user!.copyWith(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );

    final prefs = await SharedPreferences.getInstance();

    // Update stored user in secure storage
    await _secureStorage.write('current_user_data', jsonEncode(updatedUser.toJson()));

    // Also update in users database
    final usersJson = prefs.getString(_usersKey);
    if (usersJson != null) {
      final Map<String, dynamic> users = jsonDecode(usersJson);
      if (users.containsKey(state.user!.email)) {
        final userData = users[state.user!.email] as Map<String, dynamic>;
        userData['user'] = updatedUser.toJson();
        users[state.user!.email] = userData;
        await prefs.setString(_usersKey, jsonEncode(users));
      }
    }

    state = state.copyWith(user: updatedUser);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 设置OAuth登录用户（供OAuth Provider调用）
  void setUserFromOAuth(User user) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );
  }

  /// Check if an email is registered
  Future<bool> checkEmailExists({required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) return false;

    final Map<String, dynamic> users = jsonDecode(usersJson);
    return users.containsKey(email);
  }

  /// Reset password for a registered email
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) return false;

    final Map<String, dynamic> users = jsonDecode(usersJson);

    if (!users.containsKey(email)) return false;

    // 使用哈希更新密码
    final userData = users[email] as Map<String, dynamic>;
    final salt = _encryption.generateSalt();
    final hashedPassword = _encryption.hashPassword(newPassword, salt: salt);

    userData['passwordHash'] = hashedPassword;
    userData['salt'] = salt;
    userData.remove('password');  // 确保删除任何旧的明文密码
    users[email] = userData;

    await prefs.setString(_usersKey, jsonEncode(users));

    return true;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
