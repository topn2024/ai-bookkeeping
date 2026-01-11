import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/glass_components.dart';
import '../services/app_upgrade_service.dart';
import '../services/secure_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';
import '../l10n/l10n.dart';
import '../providers/ledger_context_provider.dart';
import 'home_page.dart';
import 'analysis_center_page.dart';
import 'profile_page.dart';
import 'enhanced_voice_assistant_page.dart';
import 'add_transaction_page.dart';

/// 主导航页面
/// 底部导航：首页 | 分析 | ➕ | 小记 | 我的
/// - 首页（仪表盘）
/// - 分析（数据分析中心）
/// - ➕（单击手动记账，长按语音记账）
/// - 小记（语音助手）
/// - 我的（个人中心，包含预算）
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  bool _hasCheckedUpdate = false;

  // 页面列表（不包含中间的+按钮）
  final List<Widget> _pages = const [
    HomePage(),
    AnalysisCenterPage(),
    EnhancedVoiceAssistantPage(),  // 小记宠物助手
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
      bottomNavigationBar: _buildBottomNavBar(context),
      floatingActionButton: _buildCenterButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// 中间的+按钮
  /// 单击：手动记账
  /// 长按：语音记账
  Widget _buildCenterButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 单击进入手动记账
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionPage()),
        );
      },
      onLongPress: () {
        // 长按进入语音助手（小记）
        setState(() => _currentIndex = 2);  // 切换到小记页面
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.85),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// 底部导航栏
  Widget _buildBottomNavBar(BuildContext context) {
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
          icon: Icons.analytics_outlined,
          activeIcon: Icons.analytics,
          label: context.l10n.trends,
        ),
        // 中间占位（给FAB留空间）
        const GlassBottomNavItem(
          icon: Icons.add,
          activeIcon: Icons.add,
          label: '',
        ),
        // 小记宠物助手
        const GlassBottomNavItem(
          icon: Icons.pets_outlined,
          activeIcon: Icons.pets,
          label: '小记',
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
