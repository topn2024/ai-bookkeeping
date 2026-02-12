import 'package:flutter/material.dart';

import '../../models/email_account.dart';
import '../../services/import/email/email_credential_service.dart';
import '../../services/import/email/email_imap_service.dart';
import '../../theme/app_theme.dart';
import 'email_account_setup_page.dart';
import 'email_import_progress_page.dart';

/// 邮箱导入配置页面
/// 选择邮箱账户、日期范围、账单类型
class EmailImportConfigPage extends StatefulWidget {
  const EmailImportConfigPage({super.key});

  @override
  State<EmailImportConfigPage> createState() => _EmailImportConfigPageState();
}

class _EmailImportConfigPageState extends State<EmailImportConfigPage> {
  final _credentialService = EmailCredentialService();

  List<EmailAccount> _accounts = [];
  EmailAccount? _selectedAccount;
  bool _isLoadingAccounts = true;

  // 日期范围
  late DateTime _startDate;
  late DateTime _endDate;

  // 账单类型筛选
  bool _filterCmb = true;
  bool _filterWechat = true;
  bool _filterAlipay = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _credentialService.getAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _selectedAccount = accounts.isNotEmpty ? accounts.first : null;
        _isLoadingAccounts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('邮箱账单导入')),
      body: _isLoadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountSection(theme),
                  const SizedBox(height: 20),
                  _buildDateRangeSection(theme),
                  const SizedBox(height: 20),
                  _buildBillTypeFilter(theme),
                  const SizedBox(height: 20),
                  _buildSecurityNote(theme),
                  const SizedBox(height: 24),
                  _buildStartButton(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildAccountSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择邮箱账户',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (_accounts.isEmpty)
          _buildAddAccountPrompt(theme)
        else ...[
          ..._accounts.map((account) => _buildAccountTile(theme, account)),
          const SizedBox(height: 8),
          _buildAddAccountButton(theme),
        ],
      ],
    );
  }

  Widget _buildAddAccountPrompt(ThemeData theme) {
    return GestureDetector(
      onTap: _navigateToAddAccount,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              '还没有添加邮箱账户',
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '点击添加 QQ邮箱、163邮箱或126邮箱',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(ThemeData theme, EmailAccount account) {
    final isSelected = _selectedAccount?.id == account.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccount = account),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: account.id,
              groupValue: _selectedAccount?.id,
              onChanged: (_) => setState(() => _selectedAccount = account),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.email, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.emailAddress,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    account.providerName,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              onPressed: () => _navigateToEditAccount(account),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              onPressed: () => _deleteAccount(account),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAccountButton(ThemeData theme) {
    return TextButton.icon(
      onPressed: _navigateToAddAccount,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('添加新邮箱'),
    );
  }

  Widget _buildDateRangeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '搜索日期范围',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDatePicker(theme, '开始日期', _startDate, (date) {
              setState(() => _startDate = date);
            })),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('至', style: TextStyle(fontSize: 14)),
            ),
            Expanded(child: _buildDatePicker(theme, '结束日期', _endDate, (date) {
              setState(() => _endDate = date);
            })),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _buildQuickDateChip(theme, '最近7天', 7),
            _buildQuickDateChip(theme, '最近30天', 30),
            _buildQuickDateChip(theme, '最近90天', 90),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    ThemeData theme,
    String label,
    DateTime date,
    void Function(DateTime) onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(ThemeData theme, String label, int days) {
    final now = DateTime.now();
    final isSelected = now.difference(_startDate).inDays == days &&
        _endDate.day == now.day;

    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
      ),
      onPressed: () {
        setState(() {
          _endDate = now;
          _startDate = now.subtract(Duration(days: days));
        });
      },
    );
  }

  Widget _buildBillTypeFilter(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账单类型',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('招商银行信用卡账单'),
          subtitle: const Text('HTML 电子账单邮件'),
          value: _filterCmb,
          onChanged: (v) => setState(() => _filterCmb = v ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        CheckboxListTile(
          title: const Text('微信支付账单'),
          subtitle: const Text('CSV 附件'),
          value: _filterWechat,
          onChanged: (v) => setState(() => _filterWechat = v ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        CheckboxListTile(
          title: const Text('支付宝账单'),
          subtitle: const Text('CSV 附件'),
          value: _filterAlipay,
          onChanged: (v) => setState(() => _filterAlipay = v ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildSecurityNote(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, size: 20, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '安全说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '授权码存储在设备本地安全区域，邮件内容仅在本地解析，不会上传到任何服务器。',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(ThemeData theme) {
    final canStart = _selectedAccount != null &&
        (_filterCmb || _filterWechat || _filterAlipay);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canStart ? _startImport : null,
        icon: const Icon(Icons.download),
        label: const Text('开始导入'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  List<String> _getSelectedSenders() {
    final senders = <String>[];
    if (_filterCmb) {
      senders.add(BillEmailSenders.cmbCreditCard);
      senders.add(BillEmailSenders.cmbDaily);
    }
    if (_filterWechat) senders.add(BillEmailSenders.wechatPay);
    if (_filterAlipay) senders.add(BillEmailSenders.alipay);
    return senders;
  }

  void _startImport() {
    if (_selectedAccount == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailImportProgressPage(
          account: _selectedAccount!,
          startDate: _startDate,
          endDate: _endDate,
          senderFilter: _getSelectedSenders(),
        ),
      ),
    );
  }

  Future<void> _navigateToAddAccount() async {
    final result = await Navigator.push<EmailAccount>(
      context,
      MaterialPageRoute(builder: (_) => const EmailAccountSetupPage()),
    );
    if (result != null) {
      await _loadAccounts();
      setState(() => _selectedAccount = result);
    }
  }

  Future<void> _navigateToEditAccount(EmailAccount account) async {
    final result = await Navigator.push<EmailAccount>(
      context,
      MaterialPageRoute(
        builder: (_) => EmailAccountSetupPage(existingAccount: account),
      ),
    );
    if (result != null) {
      await _loadAccounts();
    }
  }

  Future<void> _deleteAccount(EmailAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除邮箱账户'),
        content: Text('确定要删除 ${account.emailAddress} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _credentialService.deleteAccount(account.id);
      await _loadAccounts();
    }
  }
}
