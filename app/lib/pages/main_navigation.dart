import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/glass_components.dart';
import '../services/app_upgrade_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/app_update_dialog.dart';
import '../l10n/l10n.dart';
import '../providers/ledger_context_provider.dart';
import 'home_page.dart';
import 'analysis_center_page.dart';
import 'budget_center_page.dart';
import 'profile_page.dart';
import 'enhanced_voice_assistant_page.dart';

/// 主导航页面
/// 原型设计 1.01-1.05：5个底部导航主页面
/// 反重力设计：玻璃态底部导航 + 悬浮FAB + L4阴影
/// - 首页（仪表盘）
/// - 分析（数据分析中心）
/// - 预算（预算中心）
/// - 我的（个人中心）
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  bool _hasCheckedUpdate = false;

  final List<Widget> _pages = const [
    HomePage(),
    AnalysisCenterPage(),
    EnhancedVoiceAssistantPage(),  // 小记宠物助手
    BudgetCenterPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowUpdate();
      _initializeLedgerContext();
    });
  }

  /// 初始化账本上下文
  Future<void> _initializeLedgerContext() async {
    try {
      final secureStorage = SecureStorageService();
      String? userId = await secureStorage.getUserId();

      // 如果没有用户ID，使用guest ID
      if (userId == null || userId.isEmpty) {
        userId = 'guest';
      }

      // 初始化账本上下文
      await ref.read(ledgerContextProvider.notifier).initialize(userId);
    } catch (e) {
      debugPrint('Failed to initialize ledger context in MainNavigation: $e');
    }
  }

  Future<void> _checkAndShowUpdate() async {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;

    try {
      final result = AppUpgradeService().lastCheckResult;
      if (result != null && result.hasUpdate && result.latestVersion != null) {
        if (mounted) {
          await AppUpdateDialog.show(
            context,
            versionInfo: result.latestVersion!,
            isForceUpdate: result.isForceUpdate,
          );
        }
      }
    } catch (e) {
      debugPrint('检查更新失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildAntigravityBottomNav(context),
    );
  }

  /// 反重力底部导航栏
  /// 玻璃态背景 + 毛玻璃模糊 + 弹性动画
  Widget _buildAntigravityBottomNav(BuildContext context) {
    return GlassBottomNavigation(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
      },
      items: [
        GlassBottomNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: context.l10n.home,
        ),
        GlassBottomNavItem(
          icon: Icons.analytics_outlined,
          activeIcon: Icons.analytics,
          label: context.l10n.trends, // 分析中心
        ),
        // 小记宠物助手
        const GlassBottomNavItem(
          icon: Icons.pets_outlined,
          activeIcon: Icons.pets,
          label: '小记',
        ),
        GlassBottomNavItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet,
          label: context.l10n.budget,
        ),
        GlassBottomNavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: context.l10n.profile,
        ),
      ],
    );
  }
}
