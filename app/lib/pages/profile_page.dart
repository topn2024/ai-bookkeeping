import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'account_management_page.dart';
import 'credit_card_page.dart';
import 'import_page.dart';
import 'export_page.dart';
import 'backup_page.dart';
import 'settings_page.dart';
import 'help_page.dart';
import 'financial_freedom_simulator_page.dart';
import 'actionable_advice_page.dart';
import 'smart_feature_recommendation_page.dart';

/// 个人中心页面
/// 原型设计 1.05：个人中心 Profile
/// - 用户头像和基本信息
/// - 成就卡片横向滚动
/// - 账户管理分组
/// - 数据管理分组
/// - 系统设置分组
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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
              _buildAccountManagementGroup(context, theme),
              _buildFinancialToolsGroup(context, theme),
              _buildDataManagementGroup(context, theme),
              _buildSystemSettingsGroup(context, theme),
              const SizedBox(height: 100), // 底部导航栏留白
            ],
          ),
        ),
      ),
    );
  }

  /// 用户头部信息
  /// 原型设计：头像、用户名、记账天数
  Widget _buildUserHeader(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () {
        // 跳转到个人资料编辑页面
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 头像
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
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '张三',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已记账 186 天',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
  /// 原型设计：钱龄达人、连续记账、储蓄能手
  Widget _buildAchievementCards(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildAchievementCard(
            context,
            theme,
            emoji: '🏆',
            title: '钱龄达人',
            subtitle: 'Lv.3',
            gradientColors: const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          ),
          const SizedBox(width: 12),
          _buildAchievementCard(
            context,
            theme,
            emoji: '🔥',
            title: '连续记账',
            subtitle: '32天',
            gradientColors: const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          ),
          const SizedBox(width: 12),
          _buildAchievementCard(
            context,
            theme,
            emoji: '💰',
            title: '储蓄能手',
            subtitle: '累计¥5万',
            gradientColors: const [Color(0xFFEBF3FF), Color(0xFFBBDEFB)],
          ),
          const SizedBox(width: 16),
        ],
      ),
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
  Widget _buildAccountManagementGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '账户管理',
      items: [
        _SettingsItem(
          icon: Icons.account_balance,
          title: '我的账户',
          subtitle: '5个账户',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountManagementPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.credit_card,
          title: '信用卡管理',
          subtitle: '2张信用卡',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreditCardPage()),
          ),
        ),
      ],
    );
  }

  /// 财务工具分组
  /// 原型设计 10.18-10.20：习惯培养工具
  Widget _buildFinancialToolsGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '财务工具',
      items: [
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActionableAdvicePage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.auto_awesome,
          title: '功能推荐',
          subtitle: '发现更多实用功能',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SmartFeatureRecommendationPage()),
          ),
        ),
      ],
    );
  }

  /// 数据管理分组
  Widget _buildDataManagementGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '数据管理',
      items: [
        _SettingsItem(
          icon: Icons.file_upload,
          title: '导入账单',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ImportPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.file_download,
          title: '导出数据',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExportPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.backup,
          title: '备份与恢复',
          subtitle: '上次备份: 今天 09:30',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BackupPage()),
          ),
        ),
      ],
    );
  }

  /// 系统设置分组
  Widget _buildSystemSettingsGroup(BuildContext context, ThemeData theme) {
    return _buildSettingsGroup(
      context,
      theme,
      title: '系统设置',
      items: [
        _SettingsItem(
          icon: Icons.settings,
          title: '设置',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
        _SettingsItem(
          icon: Icons.help_outline,
          title: '帮助与反馈',
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
