import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/antigravity_shadows.dart';
import '../widgets/glass_components.dart';
import '../widgets/antigravity_animations.dart';
import '../services/app_upgrade_service.dart';
import '../widgets/app_update_dialog.dart';
import '../l10n/l10n.dart';
import 'home_page.dart';
import 'trends_page.dart';
import 'budget_center_page.dart';
import 'profile_page.dart';
import 'add_transaction_page.dart';
import 'enhanced_voice_assistant_page.dart';

/// 主导航页面
/// 原型设计 1.01-1.05：5个底部导航主页面
/// 反重力设计：玻璃态底部导航 + 悬浮FAB + L4阴影
/// - 首页（仪表盘）
/// - 趋势（趋势分析）
/// - 预算（预算中心）
/// - 我的（个人中心）
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _hasCheckedUpdate = false;
  bool _isFabExpanded = false;

  final List<Widget> _pages = const [
    HomePage(),
    TrendsPage(),
    BudgetCenterPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowUpdate();
    });
  }

  Future<void> _checkAndShowUpdate() async {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildAntigravityBottomNav(context),
      floatingActionButton: _buildAntigravityFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// 反重力底部导航栏
  /// 玻璃态背景 + 毛玻璃模糊 + 弹性动画
  Widget _buildAntigravityBottomNav(BuildContext context) {
    return GlassBottomNavigation(
      currentIndex: _currentIndex,
      onTap: (index) {
        // 跳过中间的占位项(index=2)
        if (index == 2) return;
        final actualIndex = index > 2 ? index - 1 : index;
        setState(() => _currentIndex = actualIndex);
      },
      items: [
        GlassBottomNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: context.l10n.home,
        ),
        GlassBottomNavItem(
          icon: Icons.insights_outlined,
          activeIcon: Icons.insights,
          label: context.l10n.trends,
        ),
        // FAB 占位
        const GlassBottomNavItem(
          icon: Icons.add,
          activeIcon: Icons.add,
          label: '',
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

  /// 反重力FAB按钮
  /// L4悬浮阴影 + 呼吸动画 + 展开菜单
  Widget _buildAntigravityFab(BuildContext context) {
    if (_isFabExpanded) {
      return FabExpandAnimation(
        isExpanded: _isFabExpanded,
        mainButton: _buildMainFab(context, isClose: true),
        children: [
          _buildMiniFab(
            context,
            icon: Icons.camera_alt,
            label: '扫描票据',
            onTap: () {
              setState(() => _isFabExpanded = false);
              // TODO: 导航到扫描页面
            },
          ),
          _buildMiniFab(
            context,
            icon: Icons.mic,
            label: '语音记账',
            onTap: () {
              setState(() => _isFabExpanded = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EnhancedVoiceAssistantPage(),
                ),
              );
            },
          ),
          _buildMiniFab(
            context,
            icon: Icons.edit,
            label: '手动记账',
            onTap: () {
              setState(() => _isFabExpanded = false);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddTransactionPage(),
                ),
              );
            },
          ),
        ],
      );
    }

    return _buildMainFab(context, isClose: false);
  }

  Widget _buildMainFab(BuildContext context, {required bool isClose}) {
    return GlassFab(
      onPressed: () {
        if (isClose) {
          setState(() => _isFabExpanded = false);
        } else {
          // 长按展开菜单，单击直接进入记账
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddTransactionPage(),
            ),
          );
        }
      },
      backgroundColor: AntigravityColors.primary,
      enableBreathe: !isClose,
      child: AnimatedRotation(
        turns: isClose ? 0.125 : 0, // 45度旋转
        duration: const Duration(milliseconds: 300),
        curve: AntigravityCurves.easeOutBack,
        child: Icon(
          isClose ? Icons.close : Icons.add,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMiniFab(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AntigravityShadows.L3,
            ),
            child: Icon(icon, color: AntigravityColors.primary),
          ),
        ),
      ],
    );
  }
}
