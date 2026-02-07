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
import '../pages/statistics_page.dart';
import '../pages/trends_page.dart';
import '../pages/search_result_page.dart';
import '../pages/about_page.dart';
import '../pages/backup_page.dart';
import '../pages/export_page.dart';
import '../pages/import_page.dart';
import '../pages/help_page.dart';
import '../pages/bill_reminder_page.dart';
import '../pages/recurring_management_page.dart';
import '../pages/reimbursement_page.dart';
import '../pages/tag_statistics_page.dart';
import '../pages/period_comparison_page.dart';
import '../pages/reports/monthly_report_page.dart';
import '../pages/annual_report_page.dart';
import '../pages/latte_factor_page.dart';
import '../pages/zero_based_budget_page.dart';
import '../pages/custom_report_page.dart';
import '../pages/financial_health_dashboard_page.dart';
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

  /// 当前页面上下文（导航后更新）
  String? _currentPageContext;

  /// 获取当前页面上下文
  String? get currentPageContext => _currentPageContext;

  /// 执行语音导航
  ///
  /// 返回导航结果消息（包含页面上下文提示）
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
      // 更新当前页面上下文
      _currentPageContext = _buildPageContext(route, result.pageName ?? '');

      // 返回包含上下文提示的消息
      final contextHint = _getPageContextHint(route);
      if (contextHint != null) {
        return '正在打开${result.pageName}。$contextHint';
      }
      return '正在打开${result.pageName}';
    } else {
      return '抱歉，暂时无法打开${result.pageName}';
    }
  }

  /// 构建页面上下文字符串
  String _buildPageContext(String route, String pageName) {
    return '当前页面: $pageName (路由: $route)';
  }

  /// 获取页面上下文提示
  ///
  /// 返回适合在语音对话中使用的上下文提示，帮助用户了解当前页面可以做什么
  String? _getPageContextHint(String route) {
    const pageContextHints = <String, String>{
      // 统计报表模块
      '/statistics/trend': '您可以说"看本月趋势"、"看上月数据"、"按餐饮分类查看"等来切换数据维度',
      '/statistics/expense': '您可以说"看本月支出"、"看上周消费"、"看餐饮分类"等来查看不同维度的支出统计',
      '/statistics/income': '您可以说"看本月收入"、"看上月收入"等来查看不同时间段的收入',
      '/statistics': '您可以说"看支出统计"、"看收入统计"、"看消费趋势"等来查看详细数据',
      '/statistics/category': '您可以说"看餐饮"、"看交通"等来查看具体分类的消费详情',
      '/statistics/comparison': '您可以说"和上月对比"、"和去年同期对比"等来查看不同时期的数据对比',

      // 预算模块
      '/budget': '您可以说"看预算执行"、"看本月预算"、"设置餐饮预算"等来管理预算',
      '/budget/vault-list': '您可以说"创建小金库"、"查看餐饮金库"等来管理您的小金库',

      // 账户模块
      '/accounts': '您可以说"看资产总览"、"添加账户"、"转账"等来管理账户',

      // 交易列表
      '/transaction-list': '您可以说"看本月账单"、"看餐饮消费"、"搜索星巴克"等来筛选查看交易',
      '/transactions': '您可以说"看本月账单"、"看餐饮消费"、"搜索星巴克"等来筛选查看交易',

      // 钱龄分析
      '/money-age': '您可以说"看钱龄趋势"、"看健康等级"、"看优化建议"等来了解您的资金健康状况',

      // 储蓄目标
      '/savings': '您可以说"添加储蓄目标"、"看目标进度"等来管理您的储蓄计划',

      // 账单提醒
      '/bills': '您可以说"看即将到期账单"、"添加账单提醒"等来管理您的账单',
    };

    return pageContextHints[route];
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
    // 注意：不使用 await，否则会阻塞直到页面关闭
    // 这会导致语音处理回调无法及时返回，影响后续交互
    try {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => page,
          // 设置路由名称，让 VoiceContextRouteObserver 能正确检测路由变化
          // 这样导航后悬浮球能正确显示（因为新页面不在 excludedRoutes 中）
          settings: RouteSettings(name: route, arguments: params),
        ),
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

      // 如果当前在子页面（如趋势分析页面），先 pop 回主导航
      final navigator = navigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        debugPrint('[VoiceNavigationExecutor] 先 pop 回主导航');
        navigator.popUntil((route) => route.isFirst);
      }

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

      // 支出/收入统计页面
      case '/statistics/expense':
      case '/expense-statistics':
      case '/expense-analysis':
        return const StatisticsPage(); // TabController index 0 是支出

      case '/statistics/income':
      case '/income-statistics':
      case '/income-analysis':
        return const StatisticsPage(); // 收入分析也用同一个页面

      // 趋势分析
      case '/statistics/trend':
      case '/trends':
      case '/trend-analysis':
        return const TrendsPage();
    }

    // 主要页面路由映射（无参数版本）
    final pageMap = <String, Widget Function()>{
      // ═══════════════════════════════════════════════════════════════
      // 快速记账
      // ═══════════════════════════════════════════════════════════════
      '/quick-add': () => const QuickEntryPage(),
      '/quick-entry': () => const QuickEntryPage(),

      // ═══════════════════════════════════════════════════════════════
      // 设置相关
      // ═══════════════════════════════════════════════════════════════
      '/settings': () => const SettingsPage(),
      '/settings/general': () => const SettingsPage(),
      '/settings/about': () => const AboutPage(),
      '/about': () => const AboutPage(),

      // ═══════════════════════════════════════════════════════════════
      // 预算
      // ═══════════════════════════════════════════════════════════════
      '/budget': () => const BudgetCenterPage(),
      '/budget/zero-based': () => const ZeroBasedBudgetPage(),
      '/zero-based-budget': () => const ZeroBasedBudgetPage(),

      // ═══════════════════════════════════════════════════════════════
      // 储蓄目标
      // ═══════════════════════════════════════════════════════════════
      '/savings': () => const SavingsGoalPage(),
      '/savings-goal': () => const SavingsGoalPage(),

      // ═══════════════════════════════════════════════════════════════
      // 钱龄分析
      // ═══════════════════════════════════════════════════════════════
      '/money-age': () => const MoneyAgePage(),

      // ═══════════════════════════════════════════════════════════════
      // 账户管理
      // ═══════════════════════════════════════════════════════════════
      '/accounts': () => const AccountListPage(),
      '/account': () => const AccountListPage(),
      '/account-list': () => const AccountListPage(),

      // ═══════════════════════════════════════════════════════════════
      // AI和语音
      // ═══════════════════════════════════════════════════════════════
      '/ai/learning-report': () => const AILearningReportPage(),
      '/ai-learning-report': () => const AILearningReportPage(),
      '/voice/learning-report': () => const VoiceLearningReportPage(),
      '/voice-learning-report': () => const VoiceLearningReportPage(),
      '/voice-assistant-settings': () => const VoiceAssistantSettingsPage(),
      '/settings/voice': () => const VoiceAssistantSettingsPage(),

      // ═══════════════════════════════════════════════════════════════
      // 搜索（需要关键词参数，在 switch 中处理）
      // ═══════════════════════════════════════════════════════════════

      // ═══════════════════════════════════════════════════════════════
      // 数据备份导入导出
      // ═══════════════════════════════════════════════════════════════
      '/backup': () => const BackupPage(),
      '/settings/backup': () => const BackupPage(),
      '/export': () => const ExportPage(),
      '/data/export': () => const ExportPage(),
      '/import': () => const ImportPage(),
      '/data/import': () => const ImportPage(),

      // ═══════════════════════════════════════════════════════════════
      // 帮助
      // ═══════════════════════════════════════════════════════════════
      '/help': () => const HelpPage(),
      '/help/center': () => const HelpPage(),

      // ═══════════════════════════════════════════════════════════════
      // 账单和定期
      // ═══════════════════════════════════════════════════════════════
      '/bill-reminder': () => const BillReminderPage(),
      '/bills': () => const BillReminderPage(),
      '/recurring': () => const RecurringManagementPage(),
      '/recurring-transactions': () => const RecurringManagementPage(),

      // ═══════════════════════════════════════════════════════════════
      // 报销
      // ═══════════════════════════════════════════════════════════════
      '/reimbursement': () => const ReimbursementPage(),

      // ═══════════════════════════════════════════════════════════════
      // 统计报表
      // ═══════════════════════════════════════════════════════════════
      '/tag-statistics': () => const TagStatisticsPage(),
      '/statistics/tag': () => const TagStatisticsPage(),
      '/statistics/comparison': () => const PeriodComparisonPage(),
      '/period-comparison': () => const PeriodComparisonPage(),
      '/statistics/monthly': () => const MonthlyReportPage(),
      '/monthly-report': () => const MonthlyReportPage(),
      '/statistics/annual': () => const AnnualReportPage(),
      '/annual-report': () => const AnnualReportPage(),
      '/latte-factor': () => const LatteFactorPage(),
      '/statistics/latte': () => const LatteFactorPage(),
      '/custom-report': () => const CustomReportPage(),
      '/statistics/custom': () => const CustomReportPage(),

      // ═══════════════════════════════════════════════════════════════
      // 财务健康
      // ═══════════════════════════════════════════════════════════════
      '/financial-health': () => const FinancialHealthDashboardPage(),
      '/health-dashboard': () => const FinancialHealthDashboardPage(),
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
    final success = await _navigateToRoute(route, params: params);

    // 导航成功后更新页面上下文
    if (success) {
      final pageName = _getPageNameForRoute(route);
      _currentPageContext = _buildPageContext(route, pageName);
    }

    return success;
  }

  /// 直接导航到指定路由，并返回包含上下文的消息
  ///
  /// 返回导航结果消息（包含页面上下文提示）
  Future<NavigationResultWithContext> navigateToRouteWithContext(
    String route, {
    Map<String, dynamic>? params,
    String? pageName,
  }) async {
    debugPrint('[VoiceNavigationExecutor] navigateToRouteWithContext: $route, params: $params');
    final success = await _navigateToRoute(route, params: params);

    final resolvedPageName = pageName ?? _getPageNameForRoute(route);

    if (success) {
      // 更新当前页面上下文
      _currentPageContext = _buildPageContext(route, resolvedPageName);

      // 构建包含上下文提示的消息
      final contextHint = _getPageContextHint(route);
      final message = contextHint != null
          ? '正在打开$resolvedPageName。$contextHint'
          : '正在打开$resolvedPageName';

      return NavigationResultWithContext(
        success: true,
        message: message,
        route: route,
        pageName: resolvedPageName,
        contextHint: contextHint,
      );
    } else {
      return NavigationResultWithContext(
        success: false,
        message: '抱歉，暂时无法打开$resolvedPageName',
        route: route,
        pageName: resolvedPageName,
      );
    }
  }

  /// 根据路由获取页面名称
  String _getPageNameForRoute(String route) {
    // 常见路由到页面名称的映射
    const routeNames = <String, String>{
      '/': '首页',
      '/home': '首页',
      '/statistics': '统计报表',
      '/statistics/trend': '消费趋势',
      '/statistics/expense': '支出统计',
      '/statistics/income': '收入统计',
      '/statistics/category': '分类统计',
      '/statistics/comparison': '对比分析',
      '/budget': '预算',
      '/budget/vault-list': '小金库列表',
      '/accounts': '账户管理',
      '/transaction-list': '交易列表',
      '/transactions': '交易列表',
      '/money-age': '钱龄分析',
      '/savings': '储蓄目标',
      '/bills': '账单提醒',
      '/settings': '设置',
      '/quick-add': '快速记账',
    };

    return routeNames[route] ?? route.split('/').last;
  }

  /// 返回上一页
  bool goBack() {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      // 清除页面上下文（因为我们不知道返回后是哪个页面）
      _currentPageContext = null;
      return true;
    }
    return false;
  }

  /// 返回首页
  void goHome() {
    _tabSwitcher?.call(0);
    _currentPageContext = _buildPageContext('/home', '首页');
  }
}

/// 带上下文的导航结果
class NavigationResultWithContext {
  /// 是否成功
  final bool success;

  /// 导航结果消息（用于语音播报和保存到聊天历史）
  final String message;

  /// 路由路径
  final String route;

  /// 页面名称
  final String pageName;

  /// 上下文提示（可选）
  final String? contextHint;

  const NavigationResultWithContext({
    required this.success,
    required this.message,
    required this.route,
    required this.pageName,
    this.contextHint,
  });
}
