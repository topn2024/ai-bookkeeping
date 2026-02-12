import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/email_account.dart';
import '../../services/import/email/email_credential_service.dart';
import '../../services/import/import_exceptions.dart';
import '../../theme/app_theme.dart';

/// 邮箱账户设置页面
/// 支持 QQ邮箱、163邮箱、126邮箱 的授权码登录配置
class EmailAccountSetupPage extends StatefulWidget {
  final EmailAccount? existingAccount;

  const EmailAccountSetupPage({super.key, this.existingAccount});

  @override
  State<EmailAccountSetupPage> createState() => _EmailAccountSetupPageState();
}

class _EmailAccountSetupPageState extends State<EmailAccountSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authCodeController = TextEditingController();
  final _credentialService = EmailCredentialService();

  EmailProvider _selectedProvider = EmailProvider.qqMail;
  bool _obscureAuthCode = true;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _testPassed = false;
  String? _testError;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingAccount != null) {
      _selectedProvider = widget.existingAccount!.provider;
      _emailController.text = widget.existingAccount!.emailAddress;
      _authCodeController.text = widget.existingAccount!.authCode;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _authCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingAccount != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑邮箱账户' : '添加邮箱账户'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProviderSelector(theme),
              const SizedBox(height: 20),
              _buildEmailField(theme),
              const SizedBox(height: 16),
              _buildAuthCodeField(theme),
              const SizedBox(height: 12),
              _buildTutorialSection(theme),
              const SizedBox(height: 24),
              _buildTestButton(theme),
              if (_testError != null) ...[
                const SizedBox(height: 12),
                _buildErrorCard(theme),
              ],
              if (_testPassed) ...[
                const SizedBox(height: 12),
                _buildSuccessCard(theme),
              ],
              const SizedBox(height: 24),
              _buildSaveButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择邮箱服务商',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildProviderCard(theme, EmailProvider.qqMail, 'QQ邮箱', const Color(0xFF12B7F5)),
            const SizedBox(width: 12),
            _buildProviderCard(theme, EmailProvider.mail163, '163邮箱', const Color(0xFFD93025)),
            const SizedBox(width: 12),
            _buildProviderCard(theme, EmailProvider.mail126, '126邮箱', const Color(0xFFFF6600)),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderCard(
    ThemeData theme,
    EmailProvider provider,
    String name,
    Color brandColor,
  ) {
    final isSelected = _selectedProvider == provider;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedProvider = provider;
            _testPassed = false;
            _testError = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? brandColor.withValues(alpha: 0.1) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? brandColor : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.email, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? brandColor : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme) {
    final suffix = switch (_selectedProvider) {
      EmailProvider.qqMail => '@qq.com',
      EmailProvider.mail163 => '@163.com',
      EmailProvider.mail126 => '@126.com',
    };

    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: '邮箱地址',
        hintText: '输入邮箱用户名即可',
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.email_outlined),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入邮箱地址';
        return null;
      },
    );
  }

  Widget _buildAuthCodeField(ThemeData theme) {
    return TextFormField(
      controller: _authCodeController,
      obscureText: _obscureAuthCode,
      decoration: InputDecoration(
        labelText: '授权码',
        hintText: '请输入邮箱授权码（非登录密码）',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.key),
        suffixIcon: IconButton(
          icon: Icon(_obscureAuthCode ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscureAuthCode = !_obscureAuthCode),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入授权码';
        return null;
      },
    );
  }

  Widget _buildTutorialSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showTutorial = !_showTutorial),
          child: Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '如何获取授权码？',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              Icon(
                _showTutorial ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        if (_showTutorial) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTutorialContent(theme),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTutorialContent(ThemeData theme) {
    switch (_selectedProvider) {
      case EmailProvider.qqMail:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QQ邮箱授权码获取步骤：', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            _tutorialStep('1. 登录 QQ邮箱网页版 (mail.qq.com)'),
            _tutorialStep('2. 进入 设置 → 账户'),
            _tutorialStep('3. 找到 POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV服务'),
            _tutorialStep('4. 开启 IMAP/SMTP 服务'),
            _tutorialStep('5. 按提示生成授权码并复制'),
          ],
        );
      case EmailProvider.mail163:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('163邮箱授权码获取步骤：', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            _tutorialStep('1. 登录 163邮箱网页版 (mail.163.com)'),
            _tutorialStep('2. 进入 设置 → POP3/SMTP/IMAP'),
            _tutorialStep('3. 开启 IMAP/SMTP 服务'),
            _tutorialStep('4. 按提示设置授权码'),
          ],
        );
      case EmailProvider.mail126:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('126邮箱授权码获取步骤：', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            _tutorialStep('1. 登录 126邮箱网页版 (mail.126.com)'),
            _tutorialStep('2. 进入 设置 → POP3/SMTP/IMAP'),
            _tutorialStep('3. 开启 IMAP/SMTP 服务'),
            _tutorialStep('4. 按提示设置授权码'),
          ],
        );
    }
  }

  Widget _tutorialStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
    );
  }

  Widget _buildTestButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isTesting ? null : _testConnection,
        icon: _isTesting
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.wifi_tethering),
        label: Text(_isTesting ? '正在测试...' : '测试连接'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _testError!,
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '连接成功！邮箱配置有效',
              style: TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveAccount,
        icon: _isSaving
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? '保存中...' : '保存'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _getFullEmailAddress() {
    final email = _emailController.text.trim();
    if (email.contains('@')) return email;
    final suffix = switch (_selectedProvider) {
      EmailProvider.qqMail => '@qq.com',
      EmailProvider.mail163 => '@163.com',
      EmailProvider.mail126 => '@126.com',
    };
    return '$email$suffix';
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testError = null;
      _testPassed = false;
    });

    final account = EmailAccount(
      id: widget.existingAccount?.id ?? const Uuid().v4(),
      provider: _selectedProvider,
      emailAddress: _getFullEmailAddress(),
      authCode: _authCodeController.text.trim(),
    );

    try {
      await _credentialService.validateCredentials(account);
      if (mounted) {
        setState(() {
          _testPassed = true;
          _isTesting = false;
        });
      }
    } on EmailAuthException catch (e) {
      if (mounted) {
        setState(() {
          _testError = e.message;
          _isTesting = false;
        });
      }
    } on EmailConnectionException catch (e) {
      if (mounted) {
        setState(() {
          _testError = e.message;
          _isTesting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testError = '测试失败: $e';
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final account = EmailAccount(
      id: widget.existingAccount?.id ?? const Uuid().v4(),
      provider: _selectedProvider,
      emailAddress: _getFullEmailAddress(),
      authCode: _authCodeController.text.trim(),
      lastSyncTime: widget.existingAccount?.lastSyncTime,
      isActive: true,
    );

    try {
      await _credentialService.saveAccount(account);
      if (mounted) {
        Navigator.pop(context, account);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
