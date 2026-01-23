import 'package:flutter/material.dart';
import '../pages/settings_page.dart';
import '../pages/analysis_center_page.dart';
import '../pages/budget_center_page.dart';
import '../pages/savings_goal_page.dart';
import '../pages/money_age_page.dart';
import '../pages/account_list_page.dart';
import '../pages/ai/ai_learning_report_page.dart';
import '../pages/voice_learning_report_page.dart';
import '../pages/voice_assistant_settings_page.dart';
import '../pages/quick_entry_page.dart';
import '../pages/transaction_list_page.dart';
import '../pages/category_detail_page.dart';
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
    debugPrint('[VoiceNavigationExecutor] setTabSwitcher: ${switcher != null ? "已设置" : "已清除"}');
    _tabSwitcher = switcher;
  }

  /// 执行语音导航
  ///
  /// 返回导航结果消息
  Future<String> executeNavigation(String voiceInput) async {
    debugPrint('[VoiceNavigationExecutor] executeNavigation: $voiceInput');
    final result = _navigationService.parseNavigation(voiceInput);

    if (!result.success) {
      debugPrint('[VoiceNavigationExecutor] 解析失败: ${result.errorMessage}');
      return result.errorMessage ?? '抱歉，我不知道您想去哪个页面';
    }

    final route = result.route;
    debugPrint('[VoiceNavigationExecutor] 解析结果: route=$route, pageName=${result.pageName}');
    if (route == null) {
      return '导航失败，请重试';
    }

    // 尝试执行导航
    final executed = await _navigateToRoute(route);
    debugPrint('[VoiceNavigationExecutor] 导航执行结果: $executed');

    if (executed) {
      return '正在打开${result.pageName}';
    } else {
      return '抱歉，暂时无法打开${result.pageName}';
    }
  }

  /// 根据路由导航到对应页面
  /// [params] 可选的导航参数，如 category、timeRange、source 等
  Future<bool> _navigateToRoute(String route, {Map<String, dynamic>? params}) async {
    final navigator = navigatorKey.currentState;

    // 首先尝试使用底部导航切换（对于主要页面，且没有筛选参数时）
    if (params == null || params.isEmpty) {
      if (_tryTabSwitch(route)) {
        return true;
      }
    }

    // 对于首页路由，如果标签切换失败但已经在首页，返回成功
    if ((route == '/' || route == '/home') && (params == null || params.isEmpty)) {
      debugPrint('[VoiceNavigationExecutor] 首页路由，标签切换器未设置，可能已在首页');
      // 不认为是失败，因为用户可能已经在首页
      return true;
    }

    // 如果没有 Navigator，无法导航
    if (navigator == null) {
      debugPrint('[VoiceNavigationExecutor] Navigator 不可用');
      return false;
    }

    // 获取对应的页面 Widget（传递参数）
    final page = _getPageForRoute(route, params);
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
    debugPrint('[VoiceNavigationExecutor] _tryTabSwitch: route=$route, _tabSwitcher=${_tabSwitcher != null ? "已设置" : "未设置"}');
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
      debugPrint('[VoiceNavigationExecutor] 切换到标签: $tabIndex');
      _tabSwitcher!(tabIndex);
      return true;
    }

    return false;
  }

  /// 根据路由获取页面 Widget
  /// [params] 可选的导航参数，如 category、timeRange、source 等
  Widget? _getPageForRoute(String route, [Map<String, dynamic>? params]) {
    // 解析时间范围
    DateTimeRange? timeRange;
    if (params != null && params.containsKey('timeRange')) {
      timeRange = _parseTimeRange(params['timeRange'] as String?);
    }

    // 提取分类和来源参数
    final category = params?['category'] as String?;
    final source = params?['source'] as String?;

    // 需要参数的页面路由
    switch (route) {
      case '/transaction-list':
      case '/transactions':
        return TransactionListPage(
          initialCategory: category,
          initialSource: source,
          initialDateRange: timeRange,
        );

      case '/statistics':
      case '/reports':
      case '/analysis':
        // 如果有分类参数，跳转到分类详情页
        if (category != null) {
          return CategoryDetailPage(
            categoryId: _mapCategoryNameToId(category),
            selectedMonth: timeRange?.start,
          );
        }
        return const AnalysisCenterPage();
    }

    // 主要页面路由映射（无参数版本）
    final pageMap = <String, Widget Function()>{
      // 快速记账
      '/quick-add': () => const QuickEntryPage(),
      '/quick-entry': () => const QuickEntryPage(),

      // 设置相关
      '/settings': () => const SettingsPage(),
      '/settings/general': () => const SettingsPage(),

      // 预算
      '/budget': () => const BudgetCenterPage(),

      // 储蓄目标
      '/savings': () => const SavingsGoalPage(),
      '/savings-goal': () => const SavingsGoalPage(),

      // 钱龄分析
      '/money-age': () => const MoneyAgePage(),

      // 账户管理
      '/accounts': () => const AccountListPage(),
      '/account': () => const AccountListPage(),

      // AI学习报告
      '/ai/learning-report': () => const AILearningReportPage(),
      '/ai-learning-report': () => const AILearningReportPage(),

      // 语音学习报告
      '/voice/learning-report': () => const VoiceLearningReportPage(),
      '/voice-learning-report': () => const VoiceLearningReportPage(),

      // 语音助手设置
      '/voice-assistant-settings': () => const VoiceAssistantSettingsPage(),
      '/settings/voice': () => const VoiceAssistantSettingsPage(),
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

  /// 解析时间范围字符串为 DateTimeRange
  DateTimeRange? _parseTimeRange(String? timeRangeStr) {
    if (timeRangeStr == null || timeRangeStr.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (timeRangeStr) {
      case '今天':
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case '昨天':
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: yesterday,
          end: today.subtract(const Duration(milliseconds: 1)),
        );
      case '本周':
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: weekStart,
          end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case '上周':
        final lastWeekStart = today.subtract(Duration(days: now.weekday + 6));
        final lastWeekEnd = today.subtract(Duration(days: now.weekday));
        return DateTimeRange(
          start: lastWeekStart,
          end: lastWeekEnd.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case '本月':
        final monthStart = DateTime(now.year, now.month, 1);
        return DateTimeRange(
          start: monthStart,
          end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case '上月':
        final lastMonthStart = now.month == 1
            ? DateTime(now.year - 1, 12, 1)
            : DateTime(now.year, now.month - 1, 1);
        final thisMonthStart = DateTime(now.year, now.month, 1);
        return DateTimeRange(
          start: lastMonthStart,
          end: thisMonthStart.subtract(const Duration(milliseconds: 1)),
        );
      default:
        return null;
    }
  }

  /// 将分类名称映射为分类ID
  String _mapCategoryNameToId(String categoryName) {
    // 常见分类名称到ID的映射
    const categoryMap = {
      '餐饮': 'food',
      '交通': 'transport',
      '购物': 'shopping',
      '娱乐': 'entertainment',
      '居住': 'housing',
      '医疗': 'medical',
      '其他': 'other',
    };
    return categoryMap[categoryName] ?? categoryName.toLowerCase();
  }

  /// 直接导航到指定路由（不需要重新解析）
  ///
  /// 供外部直接传入路由时使用
  /// [params] 可选的导航参数，如 category、timeRange、source 等
  Future<bool> navigateToRoute(String route, {Map<String, dynamic>? params}) async {
    debugPrint('[VoiceNavigationExecutor] navigateToRoute: $route, params: $params');
    return await _navigateToRoute(route, params: params);
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
