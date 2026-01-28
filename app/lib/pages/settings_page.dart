import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../l10n/l10n.dart';
import 'account_management_page.dart';
import 'category_management_page.dart';
import 'ledger_management_page.dart';
import 'budget_management_page.dart';
import 'template_management_page.dart';
import 'recurring_management_page.dart';
import 'credit_card_page.dart';
import 'savings_goal_page.dart';
import 'bill_reminder_page.dart';
import 'export_page.dart';
import 'import_page.dart';
import 'import/smart_import_page.dart';
import 'investment_page.dart';
import 'login_page.dart';
import 'reimbursement_page.dart';
import 'backup_page.dart';
import 'system_settings_page.dart';
import 'settings_submenu_page.dart';
import '../services/auto_sync_service.dart';
import 'zero_based_budget_page.dart';
import 'financial_freedom_simulator_page.dart';
import 'growth/nps_survey_page.dart';
import 'growth/achievement_share_page.dart';
import 'growth/invite_friend_page.dart';
import 'growth/viral_campaign_page.dart';
import 'multimodal_wakeup_settings_page.dart';
import 'help_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUserHeader(context, ref),
            // 暂时隐藏会员卡片
            // _buildMemberCard(context),
            _buildMenuSection(context),
            _buildDataSyncToggle(context, ref),
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
                        : context.l10n.login,
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
                        : context.l10n.dataSync,
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
              title: Text(context.l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(context.l10n.logout, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout(context, ref);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: Text(context.l10n.cancel),
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
        title: Text(context.l10n.profile),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.l10n.username,
            hintText: context.l10n.pleaseEnter,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
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
                SnackBar(content: Text(context.l10n.operationSuccess)),
              );
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    ).then((_) => nameController.dispose()); // 对话框关闭后释放Controller
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirm),
        content: Text(context.l10n.logout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.logoutSuccess)),
              );
            },
            child: Text(context.l10n.logout, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.openMembership,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.unlockAIFeatures,
                  style: const TextStyle(
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
            child: Text(
              context.l10n.openNow,
              style: const TextStyle(
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
          // 基础管理
          _buildMenuItem(
            context: context,
            icon: Icons.folder_open,
            iconColor: AppColors.primary,
            title: '基础管理',
            subtitle: '账本、账户、分类',
            onTap: () => _navigateToSubmenu(
              context,
              title: '基础管理',
              items: [
                SubmenuItem(
                  icon: Icons.book,
                  iconColor: AppColors.primary,
                  title: context.l10n.ledgerManagement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LedgerManagementPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.account_balance_wallet,
                  iconColor: AppColors.income,
                  title: context.l10n.accountManagement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountManagementPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.category,
                  iconColor: AppColors.transfer,
                  title: context.l10n.categoryManagement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoryManagementPage()),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          // 财务工具
          _buildMenuItem(
            icon: Icons.account_balance,
            iconColor: const Color(0xFF2196F3),
            title: '财务工具',
            subtitle: '预算、零基预算、投资、储蓄',
            onTap: () => _navigateToSubmenu(
              context,
              title: '财务工具',
              items: [
                SubmenuItem(
                  icon: Icons.savings,
                  iconColor: const Color(0xFF9C27B0),
                  title: context.l10n.budgetManagement,
                  subtitle: '设置预算计划',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.account_balance_wallet,
                  iconColor: const Color(0xFF00BCD4),
                  title: '零基预算分配',
                  subtitle: '让每一分钱都有去处',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ZeroBasedBudgetPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.credit_card,
                  iconColor: const Color(0xFF2196F3),
                  title: context.l10n.creditCard,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreditCardPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.trending_up,
                  iconColor: const Color(0xFFE91E63),
                  title: context.l10n.investmentAccount,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvestmentPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.flag,
                  iconColor: const Color(0xFF4CAF50),
                  title: context.l10n.savingsGoal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavingsGoalPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.beach_access,
                  iconColor: const Color(0xFFFF9800),
                  title: '财务自由模拟器',
                  subtitle: '规划你的财务自由之路',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinancialFreedomSimulatorPage()),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          // 记账工具
          _buildMenuItem(
            icon: Icons.edit_note,
            iconColor: const Color(0xFFFF9800),
            title: '记账工具',
            subtitle: '模板、周期、提醒、报销',
            onTap: () => _navigateToSubmenu(
              context,
              title: '记账工具',
              items: [
                SubmenuItem(
                  icon: Icons.flash_on,
                  iconColor: AppColors.transfer,
                  title: context.l10n.templateManagement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TemplateManagementPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.schedule,
                  iconColor: AppColors.primary,
                  title: context.l10n.recurringManagement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecurringManagementPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.notifications_active,
                  iconColor: const Color(0xFFE91E63),
                  title: context.l10n.billReminder,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BillReminderPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.receipt_long,
                  iconColor: const Color(0xFFFF5722),
                  title: context.l10n.reimbursement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReimbursementPage()),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          // 数据管理
          _buildMenuItem(
            icon: Icons.cloud_upload,
            iconColor: const Color(0xFF00BCD4),
            title: '数据管理',
            subtitle: '备份、导入、导出、同步',
            onTap: () => _navigateToSubmenu(
              context,
              title: '数据管理',
              items: [
                SubmenuItem(
                  icon: Icons.cloud_sync,
                  iconColor: AppColors.primary,
                  title: context.l10n.dataBackupTitle,
                  subtitle: context.l10n.backupToCloud,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.download,
                  iconColor: AppColors.income,
                  title: context.l10n.dataExportTitle,
                  subtitle: context.l10n.exportToCSV,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExportPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.upload_file,
                  iconColor: const Color(0xFF4CAF50),
                  title: context.l10n.dataImportTitle,
                  subtitle: context.l10n.importFromCSV,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.auto_awesome,
                  iconColor: Colors.indigo,
                  title: '智能账单导入',
                  subtitle: '自动识别微信/支付宝账单，智能去重',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmartImportPage()),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          // 增长与分享
          _buildMenuItem(
            icon: Icons.share,
            iconColor: const Color(0xFFE91E63),
            title: '增长与分享',
            subtitle: '成就分享、邀请好友、活动',
            onTap: () => _navigateToSubmenu(
              context,
              title: '增长与分享',
              items: [
                SubmenuItem(
                  icon: Icons.emoji_events,
                  iconColor: const Color(0xFFFFD700),
                  title: '分享成就',
                  subtitle: '炫耀你的理财成果',
                  onTap: () => _navigateWithAuth(context, const AchievementSharePage()),
                ),
                SubmenuItem(
                  icon: Icons.person_add,
                  iconColor: const Color(0xFF4CAF50),
                  title: '邀请好友',
                  subtitle: '邀请奖励等你拿',
                  onTap: () => _navigateWithAuth(context, const InviteFriendPage()),
                ),
                SubmenuItem(
                  icon: Icons.campaign,
                  iconColor: const Color(0xFFFF5722),
                  title: '活动中心',
                  subtitle: '参与活动赢奖励',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ViralCampaignPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.feedback,
                  iconColor: const Color(0xFF2196F3),
                  title: '反馈中心',
                  subtitle: '满意度调查、问题反馈',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NpsSurveyPage()),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          // 系统设置
          _buildMenuItem(
            icon: Icons.settings,
            iconColor: const Color(0xFF607D8B),
            title: context.l10n.systemSettings,
            subtitle: '主题、语言、安全、帮助',
            onTap: () => _navigateToSubmenu(
              context,
              title: context.l10n.systemSettings,
              items: [
                SubmenuItem(
                  icon: Icons.touch_app,
                  iconColor: const Color(0xFF9C27B0),
                  title: '多模态唤醒',
                  subtitle: '语音、手势、悬浮球等快捷入口',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MultimodalWakeUpSettingsPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.settings,
                  iconColor: const Color(0xFF607D8B),
                  title: '系统设置',
                  subtitle: '主题、语言、安全',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SystemSettingsPage()),
                  ),
                ),
                SubmenuItem(
                  icon: Icons.help_outline,
                  iconColor: const Color(0xFF00BCD4),
                  title: '帮助与反馈',
                  subtitle: '使用帮助与问题反馈',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSubmenu(
    BuildContext context, {
    required String title,
    required List<SubmenuItem> items,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsSubmenuPage(
          title: title,
          items: items,
        ),
      ),
    );
  }

  /// 导航到需要登录的页面
  void _navigateWithAuth(BuildContext context, Widget page) {
    final authState = ProviderScope.containerOf(context).read(authProvider);
    if (authState.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  /// 构建数据同步开关卡片
  Widget _buildDataSyncToggle(BuildContext context, WidgetRef ref) {
    final autoSync = AutoSyncService();

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
      child: StatefulBuilder(
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
            title: Text(
              context.l10n.dataCloudSync,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              isEnabled ? context.l10n.cloudSyncEnabled : context.l10n.cloudSyncDisabled,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Switch(
              value: isEnabled,
              activeTrackColor: AppColors.primary,
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
                      content: Text(value ? context.l10n.cloudSyncTurnedOn : context.l10n.cloudSyncTurnedOff),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem({
    BuildContext? context,
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
}
