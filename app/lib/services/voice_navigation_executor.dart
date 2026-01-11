import 'package:flutter/material.dart';
import '../pages/settings_page.dart';
import '../pages/analysis_center_page.dart';
import '../pages/budget_center_page.dart';
import '../pages/savings_goal_page.dart';
import '../pages/money_age_page.dart';
import 'voice_navigation_service.dart';

/// 语音导航执行器
///
/// 负责实际执行语音导航命令，将路由转换为页面跳转
class VoiceNavigationExecutor {
  static final VoiceNavigationExecutor _instance = VoiceNavigationExecutor._internal();
  factory VoiceNavigationExecutor() => _instance;
  VoiceNavigationExecutor._internal();

  static VoiceNavigationExecutor get instance => _instance;

  /// 全局导航键
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 导航服务
  final VoiceNavigationService _navigationService = VoiceNavigationService();

  /// MainNavigation 状态回调（用于切换底部导航标签）
  void Function(int index)? _tabSwitcher;

  /// 设置标签切换器
  void setTabSwitcher(void Function(int index)? switcher) {
    _tabSwitcher = switcher;
  }

  /// 执行语音导航
  ///
  /// 返回导航结果消息
  Future<String> executeNavigation(String voiceInput) async {
    final result = _navigationService.parseNavigation(voiceInput);

    if (!result.success) {
      return result.errorMessage ?? '抱歉，我不知道您想去哪个页面';
    }

    final route = result.route;
    if (route == null) {
      return '导航失败，请重试';
    }

    // 尝试执行导航
    final executed = await _navigateToRoute(route);

    if (executed) {
      return '正在打开${result.pageName}';
    } else {
      return '抱歉，暂时无法打开${result.pageName}';
    }
  }

  /// 根据路由导航到对应页面
  Future<bool> _navigateToRoute(String route) async {
    final navigator = navigatorKey.currentState;

    // 首先尝试使用底部导航切换（对于主要页面）
    if (_tryTabSwitch(route)) {
      return true;
    }

    // 如果没有 Navigator，无法导航
    if (navigator == null) {
      debugPrint('[VoiceNavigationExecutor] Navigator 不可用');
      return false;
    }

    // 获取对应的页面 Widget
    final page = _getPageForRoute(route);
    if (page == null) {
      debugPrint('[VoiceNavigationExecutor] 未找到路由对应的页面: $route');
      return false;
    }

    // 执行导航
    try {
      await navigator.push(
        MaterialPageRoute(builder: (_) => page),
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceNavigationExecutor] 导航失败: $e');
      return false;
    }
  }

  /// 尝试使用底部导航切换
  bool _tryTabSwitch(String route) {
    if (_tabSwitcher == null) return false;

    // 主要标签页的路由映射
    final tabRoutes = {
      '/': 0,
      '/home': 0,
      '/reports': 1,
      '/statistics': 1,
      '/budget': 2,
      '/savings': 3,
      '/money-age': 4,
    };

    final tabIndex = tabRoutes[route];
    if (tabIndex != null) {
      _tabSwitcher!(tabIndex);
      return true;
    }

    return false;
  }

  /// 根据路由获取页面 Widget
  Widget? _getPageForRoute(String route) {
    // 主要页面路由映射
    final pageMap = <String, Widget Function()>{
      // 设置相关
      '/settings': () => const SettingsPage(),
      '/settings/general': () => const SettingsPage(),

      // 统计报表/分析
      '/reports': () => const AnalysisCenterPage(),
      '/statistics': () => const AnalysisCenterPage(),
      '/analysis': () => const AnalysisCenterPage(),

      // 预算
      '/budget': () => const BudgetCenterPage(),

      // 储蓄目标
      '/savings': () => const SavingsGoalPage(),
      '/savings-goal': () => const SavingsGoalPage(),

      // 钱龄分析
      '/money-age': () => const MoneyAgePage(),
    };

    final builder = pageMap[route];
    if (builder != null) {
      return builder();
    }

    // 处理带参数的路由
    if (route.startsWith('/settings/')) {
      return const SettingsPage();
    }

    return null;
  }

  /// 返回上一页
  bool goBack() {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return true;
    }
    return false;
  }

  /// 返回首页
  void goHome() {
    _tabSwitcher?.call(0);
  }
}
