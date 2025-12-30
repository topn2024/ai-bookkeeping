import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_upgrade_service.dart';
import '../widgets/app_update_dialog.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'add_transaction_page.dart';

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
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 延迟显示更新对话框，等待界面加载完成
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddTransactionPage(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
