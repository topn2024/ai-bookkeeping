import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/account_provider.dart';
import '../services/gamification_service.dart';
import '../services/database_service.dart';
import '../l10n/l10n.dart';
import 'account_management_page.dart';
import 'credit_card_page.dart';
import 'ledger_management_page.dart';
import 'category_management_page.dart';
import 'budget_management_page.dart';
import 'savings_goal_page.dart';
import 'template_management_page.dart';
import 'recurring_management_page.dart';
import 'bill_reminder_page.dart';
import 'reimbursement_page.dart';
import 'tag_statistics_page.dart';
import 'investment_page.dart';
import 'import_page.dart';
import 'import/smart_import_page.dart';
import 'export_page.dart';
import 'backup_page.dart';
import 'annual_report_page.dart';
import 'custom_report_page.dart';
import 'asset_overview_page.dart';
import 'system_settings_page.dart';
import 'help_page.dart';
import 'login_page.dart';
import 'financial_freedom_simulator_page.dart';
import 'actionable_advice_page.dart';
import 'smart_feature_recommendation_page.dart';
import 'user_profile_visualization_page.dart';
import 'goal_achievement_dashboard_page.dart';
import 'growth/nps_survey_page.dart';
import 'growth/achievement_share_page.dart';
import 'growth/invite_friend_page.dart';
import 'growth/viral_campaign_page.dart';
import 'growth/negative_experience_recovery_page.dart';
import 'growth/detractor_care_page.dart';
import 'multimodal_wakeup_settings_page.dart';

/// 我的页面
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  /// 导航到需要登录的页面
  void _navigateWithAuth(BuildContext context, Widget page) {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserHeader(context, theme),
              _buildAchievementCards(context, theme),
              _buildAccountGroup(context, theme),
              _buildBudgetGroup(context, theme),
              _buildFinancialToolsGroup(context, theme),
              _buildDataGroup(context, theme),
              _buildReportGroup(context, theme),
              _buildGrowthGroup(context, theme),
              _buildSystemGroup(context, theme),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  /// 用户头部信息
  Widget _buildUserHeader(BuildContext context, ThemeData theme) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.nickname ?? authState.user?.email?.split('@').first ?? '未登录';

    return InkWell(
      onTap: () {
        if (authState.isAuthenticated) {
          _navigateWithAuth(context, const UserProfileVisualizationPage());
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    const Color(0xFF8B5CF6),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<StreakStats>(
                    future: GamificationService(DatabaseService()).getStreakStats(),
                    builder: (context, snapshot) {
                      final totalDays = snapshot.data?.totalDaysRecorded ?? 0;
                      return Text(
                        totalDays > 0 ? '已记账 $totalDays 天' : '开始记账吧',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 成就卡片横向滚动
  Widget _buildAchievementCards(BuildContext context, ThemeData theme) {
    return FutureBuilder<StreakStats>(
      future: GamificationService(DatabaseService()).getStreakStats(),
      builder: (context, snapshot) {
        final streakDays = snapshot.data?.currentStreak ?? 0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (streakDays > 0) ...[
                _buildAchievementCard(
                  context,
                  theme,
                  emoji: '🔥',
                  title: '连续记账',
                  subtitle: '$streakDays天',
                  gradientColors: const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                ),
                const SizedBox(width: 16),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 单个成就卡片
  Widget _buildAchievementCard(
    BuildContext context,
    ThemeData theme, {
    required String emoji,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 账户管理分组
  Widget _buildAccountGroup(BuildContext context, ThemeData theme) {
    final accounts = ref.watch(accountProvider);
    final accountCount = accounts.length;

    return _buildSettingsGroup(
      context,
      theme,
      title: '账户管理',
      items: [
        _SettingsItem(
          icon: Icons.book,
          title: context.l10n.ledgerManagement,
          subtitle: '管理多账本',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LedgerManagementPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.account_balance,
          title: context.l10n.accountManagement,
          subtitle: accountCount > 0 ? '$accountCount个账户' : '暂无账户',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountManagementPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.credit_card,
          title: context.l10n.creditCard,
          subtitle: '管理信用卡',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreditCardPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.trending_up,
          title: context.l10n.investmentAccount,
          subtitle: '投资理财账户',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InvestmentPage()),
          ),
        ),
      ],
    );
  }

  /// 预算与目标分组
  Widget _buildBudgetGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '预算与目标',
      items: [
        _SettingsItem(
          icon: Icons.category,
          title: context.l10n.categoryManagement,
          subtitle: '管理收支分类',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryManagementPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.savings,
          title: context.l10n.budgetManagement,
          subtitle: '设置预算计划',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.flag,
          title: context.l10n.savingsGoal,
          subtitle: '储蓄目标管理',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavingsGoalPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.flash_on,
          title: context.l10n.templateManagement,
          subtitle: '快速记账模板',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TemplateManagementPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.schedule,
          title: context.l10n.recurringManagement,
          subtitle: '周期性交易',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecurringManagementPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.notifications_active,
          title: context.l10n.billReminder,
          subtitle: '账单提醒设置',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillReminderPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.receipt_long,
          title: context.l10n.reimbursement,
          subtitle: '报销管理',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReimbursementPage()),
          ),
        ),
      ],
    );
  }

  /// 财务工具分组
  Widget _buildFinancialToolsGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '财务工具',
      items: [
        _SettingsItem(
          icon: Icons.person_search,
          title: '我的画像',
          subtitle: '了解你的消费性格',
          onTap: () => _navigateWithAuth(context, const UserProfileVisualizationPage()),
        ),
        _SettingsItem(
          icon: Icons.beach_access,
          title: '财务自由模拟器',
          subtitle: '规划你的财务自由之路',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FinancialFreedomSimulatorPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.tips_and_updates,
          title: '智能建议',
          subtitle: '查看个性化理财建议',
          onTap: () => _navigateWithAuth(context, const ActionableAdvicePage()),
        ),
      ],
    );
  }

  /// 数据管理分组
  Widget _buildDataGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '数据管理',
      items: [
        _SettingsItem(
          icon: Icons.file_upload,
          title: context.l10n.dataImportTitle,
          subtitle: '导入银行账单、微信/支付宝账单',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SmartImportPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.file_download,
          title: context.l10n.dataExportTitle,
          subtitle: '导出为CSV/Excel',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExportPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.backup,
          title: context.l10n.dataBackupTitle,
          subtitle: '备份与恢复',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BackupPage()),
          ),
        ),
      ],
    );
  }

  /// 报表分析分组
  Widget _buildReportGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '报表分析',
      items: [
        _SettingsItem(
          icon: Icons.account_balance,
          title: context.l10n.assetOverview,
          subtitle: '资产总览与趋势',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssetOverviewPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.assessment,
          title: context.l10n.annualReportTitle,
          subtitle: '年度账单总结',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnualReportPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.analytics,
          title: context.l10n.customReportTitle,
          subtitle: '多维度数据分析',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomReportPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.label,
          title: context.l10n.tagStatistics,
          subtitle: '标签统计分析',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TagStatisticsPage()),
          ),
        ),
      ],
    );
  }

  /// 增长与分享分组
  Widget _buildGrowthGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '增长与分享',
      items: [
        _SettingsItem(
          icon: Icons.share,
          title: '分享成就',
          subtitle: '炫耀你的理财成果',
          onTap: () => _navigateWithAuth(context, const AchievementSharePage()),
        ),
        _SettingsItem(
          icon: Icons.person_add,
          title: '邀请好友',
          subtitle: '邀请奖励等你拿',
          onTap: () => _navigateWithAuth(context, const InviteFriendPage()),
        ),
        _SettingsItem(
          icon: Icons.campaign,
          title: '活动中心',
          subtitle: '参与活动赢奖励',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ViralCampaignPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.feedback,
          title: '反馈中心',
          subtitle: '满意度调查、问题反馈',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NpsSurveyPage()),
          ),
        ),
      ],
    );
  }

  /// 系统设置分组
  Widget _buildSystemGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '系统设置',
      items: [
        _SettingsItem(
          icon: Icons.touch_app,
          title: '多模态唤醒',
          subtitle: '语音、手势、悬浮球等快捷入口',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MultimodalWakeUpSettingsPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.settings,
          title: context.l10n.systemSettings,
          subtitle: '主题、语言、安全',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SystemSettingsPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.help_outline,
          title: '帮助与反馈',
          subtitle: '使用帮助与问题反馈',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpPage()),
          ),
        ),
      ],
    );
  }

  /// 设置分组通用组件
  Widget _buildSettingsGroup(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required List<_SettingsItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == items.length - 1;
                return _buildSettingsListItem(context, theme, item, !isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 设置列表项
  Widget _buildSettingsListItem(
    BuildContext context,
    ThemeData theme,
    _SettingsItem item,
    bool showDivider,
  ) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置项数据模型
class _SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
