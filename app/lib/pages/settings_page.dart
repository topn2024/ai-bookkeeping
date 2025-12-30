import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/app_info_provider.dart';
import '../core/logger.dart';
import '../core/build_info.dart';
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
import 'language_settings_page.dart';
import 'currency_settings_page.dart';
import 'reimbursement_page.dart';
import 'tag_statistics_page.dart';
import 'custom_report_page.dart';
import 'help_page.dart';
import 'source_data_settings_page.dart';

/// 关于页面点击计数器状态
class AboutClickState {
  final int count;
  final DateTime? lastClickTime;

  const AboutClickState({this.count = 0, this.lastClickTime});

  AboutClickState increment() {
    final now = DateTime.now();
    // 如果距离上次点击超过2秒，重置计数
    if (lastClickTime != null && now.difference(lastClickTime!).inSeconds > 2) {
      return AboutClickState(count: 1, lastClickTime: now);
    }
    return AboutClickState(count: count + 1, lastClickTime: now);
  }
}

/// 关于页面点击计数器 Notifier
class AboutClickNotifier extends Notifier<AboutClickState> {
  @override
  AboutClickState build() => const AboutClickState();

  void increment() {
    state = state.increment();
  }

  void reset() {
    state = const AboutClickState();
  }
}

final aboutClickProvider = NotifierProvider<AboutClickNotifier, AboutClickState>(AboutClickNotifier.new);

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
                        ? authState.user!.name
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
                        ? authState.user!.email
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

    final nameController = TextEditingController(text: user.displayName ?? '');

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
                displayName: nameController.text.trim().isNotEmpty
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
    final themeNotifier = ref.watch(themeProvider.notifier);

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
          _buildMenuItem(
            icon: Icons.cloud_sync,
            iconColor: AppColors.primary,
            title: '数据备份',
            subtitle: '上次备份: 从未',
            onTap: () => _showBackupDialog(context),
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
            icon: themeNotifier.themeIcon,
            iconColor: const Color(0xFFE91E63),
            title: '主题换肤',
            subtitle: themeNotifier.themeName,
            onTap: () => _showThemeDialog(context, ref),
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.language,
            iconColor: const Color(0xFF2196F3),
            title: '语言设置',
            subtitle: ref.watch(localeProvider).languageInfo.name,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LanguageSettingsPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.currency_exchange,
            iconColor: const Color(0xFF4CAF50),
            title: '货币设置',
            subtitle: '${ref.watch(currencyProvider).currency.name} (${ref.watch(currencyProvider).currency.symbol})',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CurrencySettingsPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.notifications,
            iconColor: AppColors.transfer,
            title: '通知设置',
            onTap: () => _showNotificationSettingsDialog(context),
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.lock,
            iconColor: AppColors.expense,
            title: '安全设置',
            onTap: () => _showSecuritySettingsDialog(context),
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.source,
            iconColor: const Color(0xFF607D8B),
            title: '来源数据管理',
            subtitle: '管理拍照、语音原始文件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SourceDataSettingsPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.bug_report,
            iconColor: const Color(0xFF795548),
            title: '日志管理',
            subtitle: '查看和清理应用日志',
            onTap: () => _showLogManagementDialog(context),
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.help_outline,
            iconColor: AppColors.textSecondary,
            title: '帮助与反馈',
            subtitle: '使用指南、常见问题',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpPage()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.info_outline,
            iconColor: AppColors.textSecondary,
            title: '关于我们',
            subtitle: ref.watch(appInfoSyncProvider).displayVersion,
            onTap: () => _showAboutDialog(context, ref),
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

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final currentState = ref.watch(themeProvider);
          return AlertDialog(
            title: const Text('选择主题'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('外观模式', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RadioListTile<AppThemeMode>(
                    title: const Text('浅色模式'),
                    secondary: const Icon(Icons.light_mode),
                    value: AppThemeMode.light,
                    groupValue: currentState.mode,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).setThemeMode(AppThemeMode.light);
                    },
                  ),
                  RadioListTile<AppThemeMode>(
                    title: const Text('深色模式'),
                    secondary: const Icon(Icons.dark_mode),
                    value: AppThemeMode.dark,
                    groupValue: currentState.mode,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).setThemeMode(AppThemeMode.dark);
                    },
                  ),
                  RadioListTile<AppThemeMode>(
                    title: const Text('跟随系统'),
                    secondary: const Icon(Icons.brightness_auto),
                    value: AppThemeMode.system,
                    groupValue: currentState.mode,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).setThemeMode(AppThemeMode.system);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('主题色', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    // 过滤掉 custom，自定义主题有单独入口
                    children: AppColorTheme.values
                        .where((t) => t != AppColorTheme.custom)
                        .map((colorTheme) {
                      final themeData = AppColorThemes.getTheme(colorTheme);
                      final isSelected = currentState.colorTheme == colorTheme;
                      return GestureDetector(
                        onTap: () {
                          ref.read(themeProvider.notifier).setColorTheme(colorTheme);
                        },
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: themeData.primaryColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: themeData.primaryColor.withValues(alpha:0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          themeData.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? themeData.primaryColor
                                : AppColors.textSecondary,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          ),
        );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据备份'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('备份您的数据到云端，确保数据安全。'),
            SizedBox(height: 16),
            Text('此功能即将上线，敬请期待！',
              style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知设置'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('管理应用通知提醒。'),
            SizedBox(height: 16),
            Text('此功能即将上线，敬请期待！',
              style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('安全设置'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设置应用锁、指纹解锁等安全选项。'),
            SizedBox(height: 16),
            Text('此功能即将上线，敬请期待！',
              style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, WidgetRef ref) {
    // 更新点击计数
    final clickNotifier = ref.read(aboutClickProvider.notifier);
    clickNotifier.increment();
    final currentCount = ref.read(aboutClickProvider).count;

    // 检查是否显示开发者信息
    final showDevInfo = currentCount >= 5;
    if (showDevInfo) {
      // 重置计数
      clickNotifier.reset();
    }

    final appInfo = ref.read(appInfoSyncProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI智能记账', style: TextStyle(fontSize: 18)),
                Text('智能财务管理助手', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _buildAboutInfoRow('版本', appInfo.displayVersion),
            _buildAboutInfoRow('包名', appInfo.packageName),
            if (showDevInfo) ...[
              const Divider(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.developer_mode, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Text('开发者信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDevInfoRow('编译时间', BuildInfo.buildTimeFormatted),
                    _buildDevInfoRow('构建号', BuildInfo.buildNumber.toString()),
                    _buildDevInfoRow('版本标识', BuildInfo.fullVersion),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'AI智能记账是一款基于人工智能的智能记账应用，帮助您轻松管理个人财务。',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '连续点击${5 - currentCount}次查看开发者信息',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildDevInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  void _showLogManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _LogManagementDialog(),
    );
  }
}

/// Log management dialog widget
class _LogManagementDialog extends StatefulWidget {
  const _LogManagementDialog();

  @override
  State<_LogManagementDialog> createState() => _LogManagementDialogState();
}

class _LogManagementDialogState extends State<_LogManagementDialog> {
  int _logSize = 0;
  int _fileCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogInfo();
  }

  Future<void> _loadLogInfo() async {
    setState(() => _loading = true);
    try {
      final size = await logger.getLogSize();
      final files = await logger.getLogFiles();
      setState(() {
        _logSize = size;
        _fileCount = files.length;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: const Text('确定要清理所有日志文件吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await logger.clearAllLogs();
      await _loadLogInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已清理')),
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final file = await logger.exportLogs();
      if (file != null && mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'AI记账日志导出',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('日志管理'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            ListTile(
              leading: const Icon(Icons.storage, color: AppColors.primary),
              title: const Text('日志大小'),
              subtitle: Text(_formatSize(_logSize)),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppColors.income),
              title: const Text('日志文件数'),
              subtitle: Text('$_fileCount 个文件'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const Text(
              '日志自动清理策略：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 保留最近 7 天的日志\n'
              '• 单个文件最大 5MB\n'
              '• 总大小上限 50MB',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _loading ? null : _exportLogs,
          icon: const Icon(Icons.share, size: 18),
          label: const Text('导出'),
        ),
        TextButton.icon(
          onPressed: _loading ? null : _clearLogs,
          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
          label: const Text('清理', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
