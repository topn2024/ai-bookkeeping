/// Navigation Coordinator
///
/// 负责应用内导航的协调器，从VoiceServiceCoordinator中提取。
/// 处理语音命令触发的页面导航。
library;

import 'package:flutter/material.dart';

/// 导航目标
class NavigationTarget {
  final String route;
  final String displayName;
  final Map<String, dynamic>? arguments;

  const NavigationTarget({
    required this.route,
    required this.displayName,
    this.arguments,
  });
}

/// 导航结果
class NavigationResult {
  final bool success;
  final String message;
  final NavigationTarget? target;

  const NavigationResult._({
    required this.success,
    required this.message,
    this.target,
  });

  factory NavigationResult.success(NavigationTarget target) {
    return NavigationResult._(
      success: true,
      message: '正在打开${target.displayName}',
      target: target,
    );
  }

  factory NavigationResult.failure(String message) {
    return NavigationResult._(
      success: false,
      message: message,
    );
  }
}

/// 导航协调器
///
/// 职责：
/// - 解析导航意图
/// - 映射页面路由
/// - 执行导航操作
class NavigationCoordinator {
  final GlobalKey<NavigatorState>? _navigatorKey;

  /// 支持的导航目标映射
  static const Map<String, NavigationTarget> _navigationTargets = {
    // 主要页面
    'home': NavigationTarget(route: '/home', displayName: '首页'),
    'statistics': NavigationTarget(route: '/statistics', displayName: '统计'),
    'settings': NavigationTarget(route: '/settings', displayName: '设置'),
    'accounts': NavigationTarget(route: '/accounts', displayName: '账户管理'),
    'categories': NavigationTarget(route: '/categories', displayName: '分类管理'),
    'budgets': NavigationTarget(route: '/budgets', displayName: '预算'),

    // 交易相关
    'transactions': NavigationTarget(route: '/transactions', displayName: '交易记录'),
    'add_transaction': NavigationTarget(route: '/add-transaction', displayName: '记一笔'),
    'add_expense': NavigationTarget(route: '/add-transaction', displayName: '记支出', arguments: {'type': 'expense'}),
    'add_income': NavigationTarget(route: '/add-transaction', displayName: '记收入', arguments: {'type': 'income'}),
    'add_transfer': NavigationTarget(route: '/add-transaction', displayName: '记转账', arguments: {'type': 'transfer'}),

    // 高级功能
    'recurring': NavigationTarget(route: '/recurring', displayName: '循环交易'),
    'templates': NavigationTarget(route: '/templates', displayName: '模板'),
    'import': NavigationTarget(route: '/import', displayName: '导入账单'),
    'export': NavigationTarget(route: '/export', displayName: '导出数据'),

    // 报表
    'monthly_report': NavigationTarget(route: '/reports/monthly', displayName: '月度报表'),
    'annual_report': NavigationTarget(route: '/reports/annual', displayName: '年度报表'),
    'category_report': NavigationTarget(route: '/reports/category', displayName: '分类报表'),

    // 设置子页面
    'profile': NavigationTarget(route: '/settings/profile', displayName: '个人资料'),
    'notifications': NavigationTarget(route: '/settings/notifications', displayName: '通知设置'),
    'backup': NavigationTarget(route: '/settings/backup', displayName: '数据备份'),
    'about': NavigationTarget(route: '/settings/about', displayName: '关于'),
  };

  /// 关键词到导航目标的映射
  static const Map<String, String> _keywordMapping = {
    // 首页
    '首页': 'home',
    '主页': 'home',
    '回首页': 'home',

    // 统计
    '统计': 'statistics',
    '报表': 'statistics',
    '分析': 'statistics',
    '看看花了多少': 'statistics',

    // 设置
    '设置': 'settings',
    '配置': 'settings',

    // 账户
    '账户': 'accounts',
    '银行卡': 'accounts',
    '钱包': 'accounts',

    // 分类
    '分类': 'categories',
    '类别': 'categories',

    // 预算
    '预算': 'budgets',
    '预算管理': 'budgets',

    // 交易
    '交易记录': 'transactions',
    '账单': 'transactions',
    '流水': 'transactions',
    '明细': 'transactions',

    // 记账
    '记一笔': 'add_transaction',
    '记账': 'add_transaction',
    '添加': 'add_transaction',
    '新增': 'add_transaction',
    '记支出': 'add_expense',
    '花钱': 'add_expense',
    '记收入': 'add_income',
    '赚钱': 'add_income',
    '转账': 'add_transfer',

    // 导入导出
    '导入': 'import',
    '导入账单': 'import',
    '导出': 'export',
    '导出数据': 'export',

    // 报表
    '月报': 'monthly_report',
    '月度报表': 'monthly_report',
    '年报': 'annual_report',
    '年度报表': 'annual_report',

    // 其他
    '关于': 'about',
    '备份': 'backup',
    '通知': 'notifications',
  };

  NavigationCoordinator({GlobalKey<NavigatorState>? navigatorKey})
      : _navigatorKey = navigatorKey;

  /// 解析导航意图
  ///
  /// 从用户输入中识别导航目标
  NavigationResult parseNavigationIntent(String input) {
    final normalizedInput = input.toLowerCase().trim();

    // 首先尝试精确匹配
    for (final entry in _keywordMapping.entries) {
      if (normalizedInput.contains(entry.key)) {
        final target = _navigationTargets[entry.value];
        if (target != null) {
          return NavigationResult.success(target);
        }
      }
    }

    // 模糊匹配
    for (final entry in _navigationTargets.entries) {
      if (normalizedInput.contains(entry.value.displayName.toLowerCase())) {
        return NavigationResult.success(entry.value);
      }
    }

    return NavigationResult.failure('无法识别导航目标');
  }

  /// 执行导航
  Future<NavigationResult> navigate(String targetKey) async {
    final target = _navigationTargets[targetKey];
    if (target == null) {
      return NavigationResult.failure('未知的导航目标: $targetKey');
    }

    if (_navigatorKey?.currentState != null) {
      _navigatorKey!.currentState!.pushNamed(
        target.route,
        arguments: target.arguments,
      );
    }

    return NavigationResult.success(target);
  }

  /// 根据用户输入执行导航
  Future<NavigationResult> navigateByInput(String input) async {
    final parseResult = parseNavigationIntent(input);
    if (!parseResult.success || parseResult.target == null) {
      return parseResult;
    }

    if (_navigatorKey?.currentState != null) {
      _navigatorKey!.currentState!.pushNamed(
        parseResult.target!.route,
        arguments: parseResult.target!.arguments,
      );
    }

    return parseResult;
  }

  /// 返回上一页
  Future<bool> goBack() async {
    if (_navigatorKey?.currentState?.canPop() ?? false) {
      _navigatorKey!.currentState!.pop();
      return true;
    }
    return false;
  }

  /// 返回首页
  Future<void> goHome() async {
    _navigatorKey?.currentState?.popUntil((route) => route.isFirst);
  }

  /// 获取所有可用的导航目标
  List<NavigationTarget> getAvailableTargets() {
    return _navigationTargets.values.toList();
  }

  /// 检查是否为有效的导航关键词
  bool isNavigationKeyword(String keyword) {
    return _keywordMapping.containsKey(keyword) ||
        _navigationTargets.containsKey(keyword);
  }
}
