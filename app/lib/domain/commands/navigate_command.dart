/// Navigate Command
///
/// 导航命令实现。
/// 用于页面跳转和筛选条件应用。
library;

import 'intent_command.dart';

/// 导航目标类型
enum NavigationTarget {
  /// 页面路由
  route,

  /// 深度链接
  deepLink,

  /// 返回上一页
  back,

  /// 返回首页
  home,
}

/// 导航回调接口
abstract class INavigationCallback {
  /// 导航到指定路由
  Future<bool> navigateTo(String route, {Map<String, dynamic>? arguments});

  /// 返回上一页
  Future<bool> goBack();

  /// 返回首页
  Future<bool> goHome();

  /// 获取当前路由
  String? get currentRoute;
}

/// 导航命令
class NavigateCommand extends IntentCommand {
  /// 导航回调
  final INavigationCallback? navigationCallback;

  /// 导航前的路由（用于记录）
  String? _previousRoute;

  NavigateCommand({
    required String id,
    this.navigationCallback,
    required Map<String, dynamic> params,
    CommandContext? context,
  }) : super(
          id: id,
          type: CommandType.navigate,
          priority: CommandPriority.immediate,
          params: params,
          context: context,
        );

  @override
  String get description {
    final targetPage = params['targetPage'] ?? params['route'] ?? '未知页面';
    final filters = <String>[];
    if (params['category'] != null) filters.add('分类: ${params['category']}');
    if (params['timeRange'] != null) filters.add('时间: ${params['timeRange']}');
    if (params['source'] != null) filters.add('来源: ${params['source']}');

    if (filters.isEmpty) {
      return '导航到: $targetPage';
    }
    return '导航到: $targetPage (${filters.join(", ")})';
  }

  /// 目标页面
  String? get targetPage => params['targetPage'] as String?;

  /// 目标路由
  String? get route => params['route'] as String?;

  /// 分类筛选
  String? get category => params['category'] as String?;

  /// 时间范围筛选
  String? get timeRange => params['timeRange'] as String?;

  /// 来源筛选
  String? get source => params['source'] as String?;

  /// 账户筛选
  String? get account => params['account'] as String?;

  /// 导航目标类型
  NavigationTarget get targetType {
    if (params['back'] == true) return NavigationTarget.back;
    if (params['home'] == true) return NavigationTarget.home;
    if (params['deepLink'] != null) return NavigationTarget.deepLink;
    return NavigationTarget.route;
  }

  @override
  bool validate() {
    // 返回操作不需要路由
    if (targetType == NavigationTarget.back ||
        targetType == NavigationTarget.home) {
      return true;
    }

    // 其他情况需要有目标路由或页面名称
    return route != null || targetPage != null;
  }

  @override
  Future<CommandResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      // 验证参数
      if (!validate()) {
        return CommandResult.failure('参数验证失败：缺少导航目标');
      }

      // 记录当前路由
      _previousRoute = navigationCallback?.currentRoute;

      bool success = false;
      String message = '';

      switch (targetType) {
        case NavigationTarget.back:
          success = await navigationCallback?.goBack() ?? false;
          message = '返回上一页';
          break;

        case NavigationTarget.home:
          success = await navigationCallback?.goHome() ?? false;
          message = '返回首页';
          break;

        case NavigationTarget.deepLink:
          final deepLink = params['deepLink'] as String;
          success = await navigationCallback?.navigateTo(
                deepLink,
                arguments: _buildArguments(),
              ) ??
              false;
          message = '打开链接: $deepLink';
          break;

        case NavigationTarget.route:
          final targetRoute = route ?? _resolveRoute(targetPage!);
          success = await navigationCallback?.navigateTo(
                targetRoute,
                arguments: _buildArguments(),
              ) ??
              false;
          message = '导航到: ${targetPage ?? targetRoute}';
          break;
      }

      stopwatch.stop();

      if (success || navigationCallback == null) {
        return CommandResult.success(
          data: {
            'targetPage': targetPage,
            'route': route,
            'message': message,
            'arguments': _buildArguments(),
          },
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return CommandResult.failure(
          '导航失败',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return CommandResult.failure(
        '导航失败: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// 构建导航参数
  Map<String, dynamic> _buildArguments() {
    final args = <String, dynamic>{};

    if (category != null) args['category'] = category;
    if (timeRange != null) args['timeRange'] = timeRange;
    if (source != null) args['source'] = source;
    if (account != null) args['account'] = account;

    // 传递额外参数
    if (params['extras'] is Map) {
      args.addAll(params['extras'] as Map<String, dynamic>);
    }

    return args;
  }

  /// 根据页面名称解析路由
  String _resolveRoute(String pageName) {
    // 页面名称到路由的映射
    const routeMap = {
      '交易列表': '/transaction-list',
      '账单': '/transaction-list',
      '统计': '/statistics',
      '分析': '/statistics',
      '报表': '/statistics',
      '设置': '/settings',
      '账户': '/accounts',
      '账户列表': '/accounts',
      '预算': '/budget',
      '分类': '/categories',
      '分类管理': '/categories',
      '首页': '/',
      '主页': '/',
    };

    return routeMap[pageName] ?? '/$pageName';
  }
}
