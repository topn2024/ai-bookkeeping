import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/member.dart';
import '../providers/member_provider.dart';

/// 15.05 权限设置页面
/// 设置成员的角色和权限
class MemberPermissionPage extends ConsumerStatefulWidget {
  final String memberId;
  final String memberName;
  final MemberRole currentRole;

  const MemberPermissionPage({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.currentRole,
  });

  @override
  ConsumerState<MemberPermissionPage> createState() => _MemberPermissionPageState();
}

class _MemberPermissionPageState extends ConsumerState<MemberPermissionPage> {
  late MemberRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.permissionSettings,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // 成员信息
          _buildMemberInfo(),
          // 角色选择
          _buildRoleSelection(l10n),
          // 智能推荐
          _buildSmartRecommendation(l10n),
          // 当前权限说明
          _buildPermissionDetails(l10n),
          const Spacer(),
          // 保存按钮
          _buildSaveButton(l10n),
        ],
      ),
    );
  }

  Widget _buildMemberInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                widget.memberName.isNotEmpty ? widget.memberName[0] : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.memberName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '当前角色：${_selectedRole.displayName}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectRole,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 12),
          // 所有者 - 显示但不可选
          _buildRoleCard(
            role: MemberRole.owner,
            icon: Icons.shield,
            iconColor: const Color(0xFFFFB74D),
            iconBgColor: const Color(0xFFFFF3E0),
            title: l10n.owner,
            description: l10n.ownerDesc,
            isSelectable: false,
            isSelected: _selectedRole == MemberRole.owner,
          ),
          const SizedBox(height: 8),
          // 管理员
          _buildRoleCard(
            role: MemberRole.admin,
            icon: Icons.admin_panel_settings,
            iconColor: AppTheme.primaryColor,
            iconBgColor: const Color(0xFFE3F2FD),
            title: l10n.admin,
            description: l10n.adminDesc,
            isSelectable: widget.currentRole != MemberRole.owner,
            isSelected: _selectedRole == MemberRole.admin,
          ),
          const SizedBox(height: 8),
          // 成员
          _buildRoleCard(
            role: MemberRole.editor,
            icon: Icons.person,
            iconColor: AppTheme.primaryColor,
            iconBgColor: const Color(0xFFE3F2FD),
            title: l10n.member,
            description: l10n.memberDesc,
            isSelectable: widget.currentRole != MemberRole.owner,
            isSelected: _selectedRole == MemberRole.editor,
          ),
          const SizedBox(height: 8),
          // 查看者
          _buildRoleCard(
            role: MemberRole.viewer,
            icon: Icons.visibility,
            iconColor: AppTheme.textSecondaryColor,
            iconBgColor: AppTheme.surfaceVariantColor,
            title: l10n.viewer,
            description: l10n.viewerDesc,
            isSelectable: widget.currentRole != MemberRole.owner,
            isSelected: _selectedRole == MemberRole.viewer,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required MemberRole role,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required bool isSelectable,
    required bool isSelected,
  }) {
    return Opacity(
      opacity: isSelectable ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSelectable
              ? () {
                  setState(() {
                    _selectedRole = role;
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSelectable)
                  Icon(
                    Icons.lock,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  )
                else if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 22,
                    color: AppTheme.primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartRecommendation(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tips_and_updates,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.roleRecommendation,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDetails(AppLocalizations l10n) {
    final permissions = _getPermissionsForRole(_selectedRole);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.currentPermissions,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
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
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permissions.map((permission) {
                final hasPermission = permission['has'] as bool;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasPermission
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${hasPermission ? "✓" : "✗"} ${permission['name']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasPermission
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getPermissionsForRole(MemberRole role) {
    switch (role) {
      case MemberRole.owner:
        return [
          {'name': '添加账目', 'has': true},
          {'name': '查看账目', 'has': true},
          {'name': '编辑自己', 'has': true},
          {'name': '编辑他人', 'has': true},
          {'name': '邀请成员', 'has': true},
          {'name': '管理成员', 'has': true},
          {'name': '删除账本', 'has': true},
        ];
      case MemberRole.admin:
        return [
          {'name': '添加账目', 'has': true},
          {'name': '查看账目', 'has': true},
          {'name': '编辑自己', 'has': true},
          {'name': '编辑他人', 'has': true},
          {'name': '邀请成员', 'has': true},
          {'name': '管理成员', 'has': false},
          {'name': '删除账本', 'has': false},
        ];
      case MemberRole.editor:
        return [
          {'name': '添加账目', 'has': true},
          {'name': '查看账目', 'has': true},
          {'name': '编辑自己', 'has': true},
          {'name': '编辑他人', 'has': false},
          {'name': '邀请成员', 'has': false},
        ];
      case MemberRole.viewer:
        return [
          {'name': '查看账目', 'has': true},
          {'name': '添加账目', 'has': false},
          {'name': '编辑自己', 'has': false},
          {'name': '编辑他人', 'has': false},
          {'name': '邀请成员', 'has': false},
        ];
    }
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _selectedRole != widget.currentRole ? _saveChanges : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            child: Text(
              l10n.saveChanges,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    ref.read(memberProvider.notifier).updateMemberRole(
      widget.memberId,
      _selectedRole,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${widget.memberName} 的角色更改为 ${_selectedRole.displayName}'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
