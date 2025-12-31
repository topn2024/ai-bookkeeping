import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'account_management_page.dart';
import 'category_management_page.dart';
import 'ledger_management_page.dart';
import 'budget_management_page.dart';
import 'template_management_page.dart';
import 'recurring_management_page.dart';
import 'credit_card_page.dart';
import 'savings_goal_page.dart';
import 'bill_reminder_page.dart';
import 'annual_report_page.dart';
import 'asset_overview_page.dart';
import 'export_page.dart';
import 'import_page.dart';
import 'investment_page.dart';
import 'login_page.dart';
import 'reimbursement_page.dart';
import 'tag_statistics_page.dart';
import 'custom_report_page.dart';
import 'backup_page.dart';
import 'system_settings_page.dart';
import '../services/auto_sync_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUserHeader(context, ref),
            _buildMemberCard(),
            _buildMenuSection(context),
            _buildSettingsSection(context, ref),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        if (authState.isAuthenticated) {
          _showUserMenu(context, ref);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        color: primaryColor,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: authState.user?.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        authState.user!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 40,
                      color: primaryColor,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.isAuthenticated
                        ? authState.user!.displayName
                        : '点击登录',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authState.isAuthenticated
                        ? authState.user!.accountIdentifier
                        : '登录后可同步数据到云端',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑资料'),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('退出登录', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout(context, ref);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final nameController = TextEditingController(text: user.nickname ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑资料'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '请输入昵称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).updateProfile(
                nickname: nameController.text.trim().isNotEmpty
                    ? nameController.text.trim()
                    : null,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('资料已更新')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录')),
              );
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha:0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开通会员',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '解锁AI智能记账功能',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '立即开通',
              style: TextStyle(
                color: Color(0xFFFF8C00),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.book,
            iconColor: AppColors.primary,
            title: '账本管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LedgerManagementPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.account_balance_wallet,
            iconColor: AppColors.income,
            title: '账户管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountManagementPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.credit_card,
            iconColor: const Color(0xFF2196F3),
            title: '信用卡管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreditCardPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.trending_up,
            iconColor: const Color(0xFFE91E63),
            title: '投资账户',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InvestmentPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.category,
            iconColor: AppColors.transfer,
            title: '分类管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryManagementPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.savings,
            iconColor: const Color(0xFF9C27B0),
            title: '预算设置',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetManagementPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.flag,
            iconColor: const Color(0xFF4CAF50),
            title: '储蓄目标',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavingsGoalPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.receipt_long,
            iconColor: const Color(0xFFFF5722),
            title: '报销管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReimbursementPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.label,
            iconColor: const Color(0xFF3F51B5),
            title: '标签统计',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TagStatisticsPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.flash_on,
            iconColor: AppColors.transfer,
            title: '记账模板',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TemplateManagementPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.schedule,
            iconColor: AppColors.primary,
            title: '定时记账',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecurringManagementPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.notifications_active,
            iconColor: const Color(0xFFE91E63),
            title: '账单提醒',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BillReminderPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSyncToggleItem(context),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.cloud_sync,
            iconColor: AppColors.primary,
            title: '数据备份',
            subtitle: '备份到云端',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.download,
            iconColor: AppColors.income,
            title: '数据导出',
            subtitle: '导出CSV文件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExportPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.upload_file,
            iconColor: const Color(0xFF4CAF50),
            title: '数据导入',
            subtitle: '从CSV文件导入',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.assessment,
            iconColor: const Color(0xFF673AB7),
            title: '年度报告',
            subtitle: '查看年度财务总结',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnnualReportPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.analytics,
            iconColor: const Color(0xFF009688),
            title: '自定义报表',
            subtitle: '多维度自定义分析',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomReportPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.account_balance,
            iconColor: const Color(0xFF00897B),
            title: '资产概览',
            subtitle: '净资产、趋势与分布',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AssetOverviewPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.settings,
            iconColor: const Color(0xFF607D8B),
            title: '系统设置',
            subtitle: '主题、语言、安全等',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SystemSettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 56,
      color: AppColors.divider,
    );
  }

  /// 构建数据同步开关
  Widget _buildSyncToggleItem(BuildContext context) {
    final autoSync = AutoSyncService();

    return StatefulBuilder(
      builder: (context, setState) {
        final settings = autoSync.settings;
        final isEnabled = settings.syncPrivateData;

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEnabled ? Icons.sync : Icons.sync_disabled,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          title: const Text(
            '数据云同步',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            isEnabled ? '已开启，数据自动同步到云端' : '已关闭，数据仅保存在本地',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Switch(
            value: isEnabled,
            activeColor: AppColors.primary,
            onChanged: (value) async {
              final newSettings = settings.copyWith(syncPrivateData: value);
              await autoSync.updateSettings(newSettings);
              setState(() {});

              // 如果开启同步，立即执行一次同步
              if (value) {
                autoSync.performSync();
              }

              // 显示提示
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value ? '已开启数据云同步' : '已关闭数据云同步，数据将仅保存在本地'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

}
