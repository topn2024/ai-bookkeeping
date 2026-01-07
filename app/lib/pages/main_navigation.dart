import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_upgrade_service.dart';
import '../widgets/app_update_dialog.dart';
import '../l10n/l10n.dart';
import 'home_page.dart';
import 'trends_page.dart';
import 'budget_center_page.dart';
import 'profile_page.dart';
import 'add_transaction_page.dart';

/// 主导航页面
/// 原型设计 1.01-1.05：5个底部导航主页面
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
      bottomNavigationBar: _buildBottomNavigationBar(context),
      floatingActionButton: _buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// 底部导航栏
  /// 原型设计：4个导航项 + 中间FAB
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: context.l10n.home,
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: Icons.insights_outlined,
                activeIcon: Icons.insights,
                label: context.l10n.trends,
              ),
              const SizedBox(width: 56), // FAB 占位
              _buildNavItem(
                context,
                index: 2,
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
                label: context.l10n.budget,
              ),
              _buildNavItem(
                context,
                index: 3,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: context.l10n.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单个导航项
  /// 无障碍设计：触控目标 >= 48dp
  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 浮动操作按钮
  /// 原型设计：中间记账按钮
  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AddTransactionPage(),
          ),
        );
      },
      elevation: 4,
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add, size: 28, color: Colors.white),
    );
  }
}
