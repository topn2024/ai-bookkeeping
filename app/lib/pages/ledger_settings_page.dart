import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/ledger.dart';
import '../providers/ledger_provider.dart';

/// 15.08 账本设置页面
/// 配置账本名称、图标、隐私和通知设置
class LedgerSettingsPage extends ConsumerStatefulWidget {
  final String ledgerId;

  const LedgerSettingsPage({
    super.key,
    required this.ledgerId,
  });

  @override
  ConsumerState<LedgerSettingsPage> createState() => _LedgerSettingsPageState();
}

class _LedgerSettingsPageState extends ConsumerState<LedgerSettingsPage> {
  bool _memberRecordNotify = true;
  bool _budgetOverflowAlert = true;
  bool _hideAmount = false;
  String _defaultVisibility = '所有成员';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgers = ref.watch(ledgerProvider);
    final ledger = ledgers.firstWhere(
      (l) => l.id == widget.ledgerId,
      orElse: () => Ledger(
        id: widget.ledgerId,
        name: '未知账本',
        icon: Icons.book,
        color: AppTheme.primaryColor,
        ownerId: 'default_user',
        isDefault: false,
        createdAt: DateTime.now(),
        memberIds: [],
      ),
    );

    return Scaffold(
      
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.ledgerSettings,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 账本信息
            _buildLedgerInfoSection(ledger, l10n),
            // 隐私设置
            _buildPrivacySection(l10n),
            // 通知设置
            _buildNotificationSection(l10n),
            // 危险操作
            _buildDangerSection(ledger, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerInfoSection(Ledger ledger, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem(
            title: l10n.ledgerName,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ledger.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondaryColor),
              ],
            ),
            onTap: () => _showEditNameDialog(ledger),
          ),
          _buildDivider(),
          _buildSettingItem(
            title: l10n.ledgerIcon,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ledger.icon, color: ledger.color, size: 22),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondaryColor),
              ],
            ),
            onTap: () => _showIconPickerDialog(ledger),
          ),
          _buildDivider(),
          _buildSettingItem(
            title: l10n.ledgerType,
            trailing: Text(
              '家庭账本',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.privacySettings,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingItem(
                title: l10n.defaultVisibility,
                subtitle: l10n.visibilityDesc,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _defaultVisibility,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Icon(Icons.expand_more, size: 18, color: AppTheme.primaryColor),
                  ],
                ),
                onTap: _showVisibilityPicker,
              ),
              _buildDivider(),
              _buildSwitchItem(
                title: l10n.hideAmount,
                subtitle: l10n.hideAmountDesc,
                value: _hideAmount,
                onChanged: (value) {
                  setState(() => _hideAmount = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 12),
          child: Text(
            l10n.notificationSettings,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSwitchItem(
                title: l10n.memberRecordNotify,
                value: _memberRecordNotify,
                onChanged: (value) {
                  setState(() => _memberRecordNotify = value);
                },
              ),
              _buildDivider(),
              _buildSwitchItem(
                title: l10n.budgetOverflowAlert,
                value: _budgetOverflowAlert,
                onChanged: (value) {
                  setState(() => _budgetOverflowAlert = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerSection(Ledger ledger, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 12),
          child: Text(
            l10n.dangerZone,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingItem(
                title: l10n.leaveLedger,
                titleColor: AppTheme.errorColor,
                trailing: Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondaryColor),
                onTap: () => _showLeaveConfirmDialog(ledger),
              ),
              _buildDivider(),
              _buildSettingItem(
                title: l10n.deleteLedger,
                subtitle: l10n.onlyOwnerCanDelete,
                titleColor: AppTheme.errorColor,
                trailing: Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondaryColor),
                onTap: () => _showDeleteConfirmDialog(ledger),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSettingItem({
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: titleColor ?? AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppTheme.dividerColor,
    );
  }

  void _showEditNameDialog(Ledger ledger) {
    final controller = TextEditingController(text: ledger.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑账本名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '账本名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final updated = Ledger(
                  id: ledger.id,
                  name: controller.text.trim(),
                  description: ledger.description,
                  icon: ledger.icon,
                  color: ledger.color,
                  ownerId: ledger.ownerId,
                  isDefault: ledger.isDefault,
                  createdAt: ledger.createdAt,
                  memberIds: ledger.memberIds,
                );
                ref.read(ledgerProvider.notifier).updateLedger(updated);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showIconPickerDialog(Ledger ledger) {
    final icons = [
      Icons.family_restroom,
      Icons.home,
      Icons.favorite,
      Icons.account_balance,
      Icons.shopping_bag,
      Icons.flight,
      Icons.school,
      Icons.sports_esports,
    ];

    final colors = [
      const Color(0xFFFFB74D),
      const Color(0xFF66BB6A),
      const Color(0xFF42A5F5),
      const Color(0xFFE57373),
      const Color(0xFFBA68C8),
      const Color(0xFF4DB6AC),
    ];

    IconData selectedIcon = ledger.icon;
    Color selectedColor = ledger.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('选择图标'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('图标', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: icons.map((icon) {
                  final isSelected = icon == selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = icon),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor.withValues(alpha: 0.2)
                            : AppTheme.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: selectedColor, width: 2)
                            : null,
                      ),
                      child: Icon(icon, color: selectedColor),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('颜色', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = Ledger(
                  id: ledger.id,
                  name: ledger.name,
                  description: ledger.description,
                  icon: selectedIcon,
                  color: selectedColor,
                  ownerId: ledger.ownerId,
                  isDefault: ledger.isDefault,
                  createdAt: ledger.createdAt,
                  memberIds: ledger.memberIds,
                );
                ref.read(ledgerProvider.notifier).updateLedger(updated);
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVisibilityPicker() {
    final options = ['所有成员', '仅管理员', '仅自己'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          return ListTile(
            title: Text(option),
            trailing: _defaultVisibility == option
                ? Icon(Icons.check, color: AppTheme.primaryColor)
                : null,
            onTap: () {
              setState(() => _defaultVisibility = option);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showLeaveConfirmDialog(Ledger ledger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出账本'),
        content: Text('确定要退出"${ledger.name}"吗？退出后将无法查看此账本的内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出账本')),
              );
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Ledger ledger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账本'),
        content: Text('确定要删除"${ledger.name}"吗？账本下的所有记录都会被删除，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              ref.read(ledgerProvider.notifier).deleteLedger(ledger.id);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('账本已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
