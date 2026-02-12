import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/oauth_provider.dart';
import '../services/oauth_service.dart';
import '../theme/app_theme.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _oauthLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    // Watch oauth provider for state changes
    final oauthState = ref.watch(oauthProvider);

    // Listen for auth errors
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    // Listen for OAuth errors
    ref.listen<OAuthState>(oauthProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(oauthProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo and Title
                Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                const Text(
                  '白记',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '登录账户，同步您的数据',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    hintText: '请输入邮箱地址',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入邮箱';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return '请输入有效的邮箱地址';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '请输入密码',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (value.length < 6) {
                      return '密码至少6位';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text('忘记密码？'),
                  ),
                ),
                const SizedBox(height: 24),

                // Login button
                ElevatedButton(
                  onPressed: authState.status == AuthStatus.loading
                      ? null
                      : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: authState.status == AuthStatus.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '还没有账户？',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text('立即注册'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Social login divider
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '或者使用以下方式登录',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                // Social login buttons
                if (_oauthLoading || oauthState.isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        icon: Icons.wechat,
                        color: const Color(0xFF07C160),
                        label: '微信',
                        enabled: oauthState.config?.wechatEnabled ?? false,
                        onTap: () => _handleOAuthLogin(OAuthProviderType.wechat),
                      ),
                      const SizedBox(width: 24),
                      _buildSocialButton(
                        icon: Icons.apple,
                        color: Colors.black,
                        label: 'Apple',
                        enabled: oauthState.config?.appleEnabled ?? false,
                        onTap: () => _handleOAuthLogin(OAuthProviderType.apple),
                      ),
                      const SizedBox(width: 24),
                      _buildSocialButton(
                        icon: Icons.g_mobiledata,
                        color: const Color(0xFF4285F4),
                        label: 'Google',
                        enabled: oauthState.config?.googleEnabled ?? false,
                        onTap: () => _handleOAuthLogin(OAuthProviderType.google),
                      ),
                    ],
                  ),

                // Show hint if no OAuth providers available
                if (oauthState.config != null &&
                    !oauthState.config!.wechatEnabled &&
                    !oauthState.config!.appleEnabled &&
                    !oauthState.config!.googleEnabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      '第三方登录功能暂未配置',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: enabled ? '使用$label登录' : '$label登录暂未开放',
      child: InkWell(
        onTap: enabled ? onTap : () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label登录暂未配置，请使用其他方式登录')),
          );
        },
        borderRadius: BorderRadius.circular(25),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final success = await ref.read(authProvider.notifier).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
        }
        // 如果失败，error 会通过 ref.listen 显示
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录异常: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleOAuthLogin(OAuthProviderType provider) async {
    setState(() {
      _oauthLoading = true;
    });

    try {
      // Get authorization code from OAuth provider
      final authCode = await _getOAuthAuthorizationCode(provider);

      if (authCode == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('授权已取消')),
          );
        }
        return;
      }

      // Login with OAuth
      final success = await ref.read(oauthProvider.notifier).loginWithOAuth(
        provider,
        authCode,
      );

      if (success && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _oauthLoading = false;
        });
      }
    }
  }

  Future<String?> _getOAuthAuthorizationCode(OAuthProviderType provider) async {
    // This method should be implemented with actual OAuth SDK integration
    // For now, show a dialog explaining the integration requirement

    switch (provider) {
      case OAuthProviderType.wechat:
        return await _showOAuthIntegrationDialog(
          provider: provider,
          title: '微信登录',
          description: '需要集成微信 SDK 才能使用微信登录功能。\n\n'
              '请在 pubspec.yaml 中添加:\nfluwx: ^4.x.x\n\n'
              '并配置微信开放平台相关参数。',
        );
      case OAuthProviderType.apple:
        // Apple Sign In only available on iOS
        if (!Platform.isIOS && !Platform.isMacOS) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Apple登录仅支持iOS和macOS设备')),
            );
          }
          return null;
        }
        return await _showOAuthIntegrationDialog(
          provider: provider,
          title: 'Apple 登录',
          description: '需要集成 Apple Sign In SDK。\n\n'
              '请在 pubspec.yaml 中添加:\nsign_in_with_apple: ^5.x.x\n\n'
              '并在 Apple Developer Portal 配置 Sign in with Apple。',
        );
      case OAuthProviderType.google:
        return await _showOAuthIntegrationDialog(
          provider: provider,
          title: 'Google 登录',
          description: '需要集成 Google Sign In SDK。\n\n'
              '请在 pubspec.yaml 中添加:\ngoogle_sign_in: ^6.x.x\n\n'
              '并在 Google Cloud Console 配置 OAuth 2.0。',
        );
    }
  }

  Future<String?> _showOAuthIntegrationDialog({
    required OAuthProviderType provider,
    required String title,
    required String description,
  }) async {
    // In production, this would use the actual OAuth SDK
    // For development, show integration instructions
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                '开发测试说明：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '后端 API 已准备就绪，前端需要集成相应的 OAuth SDK 获取授权码后调用登录接口。',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // For testing purposes, you can enter a mock auth code
              _showTestAuthCodeDialog(context, provider);
            },
            child: const Text('测试登录'),
          ),
        ],
      ),
    );
  }

  void _showTestAuthCodeDialog(BuildContext context, OAuthProviderType provider) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入测试授权码'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: '输入从OAuth提供商获取的授权码',
            helperText: '仅用于开发测试',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, codeController.text);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((_) => codeController.dispose()); // 对话框关闭时释放
  }
}
