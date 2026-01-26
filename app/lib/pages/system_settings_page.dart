import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';
import '../core/build_info.dart';
import 'language_settings_page.dart';
import 'currency_settings_page.dart';
import 'source_data_settings_page.dart';
import 'about_page.dart';
import 'region_settings_page.dart';
import 'ai_language_settings_page.dart';
import 'notification_settings_page.dart';
import 'security_settings_page.dart';
import 'location_service_settings_page.dart';
// import 'membership_page.dart'; // 暂时隐藏会员功能
import 'accessibility_settings_page.dart';
import 'ai_learning_curve_page.dart';
import 'voice_assistant_settings_page.dart';
import 'home_layout_page.dart';
import 'data_management_page.dart';
import 'app_lock_settings_page.dart';
import 'observability/app_health_page.dart';
import 'observability/performance_monitor_page.dart';
import 'observability/system_log_page.dart';
import 'observability/alert_history_page.dart';
import 'observability/diagnostic_report_page.dart';

class SystemSettingsPage extends ConsumerWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('外观与显示'),
            _buildSettingsCard(
              context,
              ref,
              children: [
                _buildThemeMenuItem(context, ref),
                _buildDivider(),
                _buildLanguageMenuItem(context, ref),
                _buildDivider(),
                _buildCurrencyMenuItem(context, ref),
              ],
            ),
            _buildSectionHeader('隐私与安全'),
            _buildSettingsCard(
              context,
              ref,
              children: [
                _buildMenuItem(
                  icon: Icons.notifications,
                  iconColor: AppColors.transfer,
                  title: '通知设置',
                  subtitle: '管理推送通知',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationSettingsPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.lock,
                  iconColor: AppColors.expense,
                  title: '安全设置',
                  subtitle: '密码、指纹等',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SecuritySettingsPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.lock_outline,
                  iconColor: const Color(0xFF795548),
                  title: '应用锁设置',
                  subtitle: 'PIN码、指纹解锁',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppLockSettingsPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.location_on,
                  iconColor: const Color(0xFF00BCD4),
                  title: '位置服务',
                  subtitle: '位置权限与围栏',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LocationServiceSettingsPage()),
                    );
                  },
                ),
              ],
            ),
            _buildSectionHeader('数据管理'),
            _buildSettingsCard(
              context,
              ref,
              children: [
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
                  icon: Icons.storage,
                  iconColor: const Color(0xFF9C27B0),
                  title: '数据管理',
                  subtitle: '存储、缓存、清理',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DataManagementPage()),
                    );
                  },
                ),
              ],
            ),
            _buildSectionHeader('个性化'),
            _buildSettingsCard(
              context,
              ref,
              children: [
                _buildMenuItem(
                  icon: Icons.public,
                  iconColor: const Color(0xFF009688),
                  title: '地区设置',
                  subtitle: '日期、时间、数字格式',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegionSettingsPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.dashboard_customize,
                  iconColor: const Color(0xFFFF5722),
                  title: '首页布局',
                  subtitle: '自定义首页卡片',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeLayoutPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.accessibility,
                  iconColor: const Color(0xFF3F51B5),
                  title: '无障碍设置',
                  subtitle: '字体、对比度、朗读',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AccessibilitySettingsPage()),
                    );
                  },
                ),
              ],
            ),
            _buildSectionHeader('AI智能'),
            _buildSettingsCard(
              context,
              ref,
              children: [
                _buildMenuItem(
                  icon: Icons.mic,
                  iconColor: AppTheme.primaryColor,
                  title: '语音助手设置',
                  subtitle: '悬浮球、语音交互配置',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VoiceAssistantSettingsPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.translate,
                  iconColor: const Color(0xFFE91E63),
                  title: 'AI语言设置',
                  subtitle: 'AI回复语言偏好',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AILanguageSettingsPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.trending_up,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'AI学习成长',
                  subtitle: '查看AI准确率提升',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AILearningCurvePage()),
                    );
                  },
                ),
              ],
            ),
            // 暂时隐藏会员功能
            // _buildSectionHeader('会员与服务'),
            // _buildSettingsCard(
            //   context,
            //   ref,
            //   children: [
            //     _buildMenuItem(
            //       icon: Icons.card_membership,
            //       iconColor: const Color(0xFFFFD700),
            //       title: '会员中心',
            //       subtitle: '管理订阅和权益',
            //       onTap: () {
            //         Navigator.push(
            //           context,
            //           MaterialPageRoute(builder: (context) => const MembershipPage()),
            //         );
            //       },
            //     ),
            //   ],
            // ),
            _buildSectionHeader('其他'),
            _buildSettingsCard(
              context,
              ref,
              children: [
                _buildMenuItem(
                  icon: Icons.monitor_heart,
                  iconColor: AppColors.income,
                  title: '应用健康',
                  subtitle: '系统状态与诊断',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppHealthPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.speed,
                  iconColor: const Color(0xFF00BCD4),
                  title: '性能监控',
                  subtitle: '帧率、内存、启动时间',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PerformanceMonitorPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.article,
                  iconColor: const Color(0xFF607D8B),
                  title: '系统日志',
                  subtitle: '查看运行日志',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SystemLogPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.notifications_active,
                  iconColor: AppColors.warning,
                  title: '告警历史',
                  subtitle: '查看系统告警',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AlertHistoryPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.bug_report,
                  iconColor: AppColors.expense,
                  title: '诊断报告',
                  subtitle: '生成完整诊断',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DiagnosticReportPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.info_outline,
                  iconColor: AppColors.primary,
                  title: '关于我们',
                  subtitle: '版本 ${BuildInfo.displayVersion}',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutPage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    WidgetRef ref, {
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeMenuItem(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.watch(themeProvider.notifier);
    return _buildMenuItem(
      icon: themeNotifier.themeIcon,
      iconColor: const Color(0xFFE91E63),
      title: '主题换肤',
      subtitle: themeNotifier.themeName,
      onTap: () => _showThemeDialog(context, ref),
    );
  }

  Widget _buildLanguageMenuItem(BuildContext context, WidgetRef ref) {
    return _buildMenuItem(
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
    );
  }

  Widget _buildCurrencyMenuItem(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyProvider);
    return _buildMenuItem(
      icon: Icons.currency_exchange,
      iconColor: const Color(0xFF4CAF50),
      title: '货币设置',
      subtitle: '${currencyState.currency.name} (${currencyState.currency.symbol})',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CurrencySettingsPage()),
        );
      },
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
          color: iconColor.withValues(alpha: 0.1),
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
                                          color: themeData.primaryColor.withValues(alpha: 0.6),
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
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

}
