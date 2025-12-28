import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

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

  @override
  AuthState build() {
    _loadUser();
    return const AuthState();
  }

  Future<void> _loadUser() async {
    state = state.copyWith(status: AuthStatus.loading);

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      try {
        final user = User.fromJson(jsonDecode(userJson));
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
    final user = User(
      id: const Uuid().v4(),
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    // Store user credentials (in real app, this would be hashed)
    users[email] = {
      'password': password,
      'user': user.toJson(),
    };

    await prefs.setString(_usersKey, jsonEncode(users));
    await prefs.setString(_userKey, jsonEncode(user.toJson()));

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

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();

    // Get existing users
    final usersJson = prefs.getString(_usersKey);
    if (usersJson == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '账号不存在',
      );
      return false;
    }

    final Map<String, dynamic> users = jsonDecode(usersJson);

    // Check if user exists
    if (!users.containsKey(email)) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: '账号不存在',
      );
      return false;
    }

    final userData = users[email] as Map<String, dynamic>;

    // Verify password
    if (userData['password'] != password) {
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
    await prefs.setString(_userKey, jsonEncode(user.toJson()));

    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );

    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);

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

    // Update stored user
    await prefs.setString(_userKey, jsonEncode(updatedUser.toJson()));

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

    // Update password
    final userData = users[email] as Map<String, dynamic>;
    userData['password'] = newPassword;
    users[email] = userData;

    await prefs.setString(_usersKey, jsonEncode(users));

    return true;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
