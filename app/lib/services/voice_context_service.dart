import 'package:flutter/foundation.dart';

/// 页面上下文类型
enum PageContextType {
  home,              // 首页 - 快速记账
  transaction,       // 交易页 - 查询/编辑交易
  transactionDetail, // 交易详情页
  budget,            // 预算页 - 查询预算
  report,            // 报表页 - 查询统计
  moneyAge,          // 钱龄页 - 查询钱龄
  savings,           // 储蓄页 - 储蓄操作
  settings,          // 设置页 - 配置调整
  voiceChat,         // 语音聊天页
  other,             // 其他页面
}

/// 页面上下文
class PageContext {
  final PageContextType type;
  final String? routeName;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  PageContext({
    required this.type,
    this.routeName,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  PageContext copyWith({
    PageContextType? type,
    String? routeName,
    Map<String, dynamic>? data,
  }) {
    return PageContext(
      type: type ?? this.type,
      routeName: routeName ?? this.routeName,
      data: data ?? this.data,
      timestamp: timestamp,
    );
  }

  @override
  String toString() {
    return 'PageContext(type: $type, routeName: $routeName, data: $data)';
  }
}

/// 语音上下文服务
///
/// 负责：
/// - 跟踪当前页面上下文
/// - 根据上下文增强意图理解
/// - 管理上下文相关的对话状态
class VoiceContextService extends ChangeNotifier {
  // 当前页面上下文
  PageContext? _currentContext;

  // 上下文历史（用于回退和调试）
  final List<PageContext> _contextHistory = [];
  static const int _maxHistorySize = 10;

  // 路由名称到上下文类型的映射
  static final Map<String, PageContextType> _routeTypeMap = {
    '/': PageContextType.home,
    '/home': PageContextType.home,
    '/transactions': PageContextType.transaction,
    '/transaction-detail': PageContextType.transactionDetail,
    '/budget': PageContextType.budget,
    '/budgets': PageContextType.budget,
    '/reports': PageContextType.report,
    '/monthly-report': PageContextType.report,
    '/annual-summary': PageContextType.report,
    '/money-age': PageContextType.moneyAge,
    '/savings': PageContextType.savings,
    '/savings-goal': PageContextType.savings,
    '/settings': PageContextType.settings,
    '/voice-chat': PageContextType.voiceChat,
  };

  // 排除悬浮球的页面
  static const List<String> excludedRoutes = [
    '/voice-assistant',
    '/voice-chat',
    '/settings/voice',
    '/camera',
  ];

  /// 获取当前上下文
  PageContext? get currentContext => _currentContext;

  /// 获取上下文历史
  List<PageContext> get contextHistory => List.unmodifiable(_contextHistory);

  /// 当前页面是否应该隐藏悬浮球
  bool get shouldHideFloatingBall {
    final routeName = _currentContext?.routeName;
    if (routeName == null) return false;
    return excludedRoutes.any((r) => routeName.startsWith(r));
  }

  /// 更新上下文（通过路由名称）
  void updateContextFromRoute(String? routeName, {Object? arguments}) {
    if (routeName == null) return;

    final type = _getTypeFromRoute(routeName);
    final data = _extractDataFromArguments(arguments);

    final newContext = PageContext(
      type: type,
      routeName: routeName,
      data: data,
    );

    _setContext(newContext);
  }

  /// 更新上下文（直接设置）
  void updateContext(PageContext context) {
    _setContext(context);
  }

  /// 更新上下文数据
  void updateContextData(Map<String, dynamic> data) {
    if (_currentContext != null) {
      _currentContext = _currentContext!.copyWith(
        data: {...?_currentContext!.data, ...data},
      );
      notifyListeners();
    }
  }

  /// 设置上下文
  void _setContext(PageContext context) {
    // 保存历史
    if (_currentContext != null) {
      _contextHistory.add(_currentContext!);
      while (_contextHistory.length > _maxHistorySize) {
        _contextHistory.removeAt(0);
      }
    }

    _currentContext = context;
    debugPrint('[VoiceContextService] 上下文更新: $context');
    notifyListeners();
  }

  /// 从路由名称获取上下文类型
  PageContextType _getTypeFromRoute(String routeName) {
    // 精确匹配
    if (_routeTypeMap.containsKey(routeName)) {
      return _routeTypeMap[routeName]!;
    }

    // 前缀匹配
    for (final entry in _routeTypeMap.entries) {
      if (routeName.startsWith(entry.key)) {
        return entry.value;
      }
    }

    return PageContextType.other;
  }

  /// 从路由参数提取数据
  Map<String, dynamic>? _extractDataFromArguments(Object? arguments) {
    if (arguments == null) return null;

    if (arguments is Map<String, dynamic>) {
      return arguments;
    }

    if (arguments is Map) {
      return arguments.cast<String, dynamic>();
    }

    return {'arguments': arguments};
  }

  /// 获取上下文增强提示
  /// 用于增强语音意图理解
  String getContextHint() {
    if (_currentContext == null) return '';

    switch (_currentContext!.type) {
      case PageContextType.home:
        return '用户在首页，可能想记账或查看概览';
      case PageContextType.transaction:
        return '用户在交易列表，可能想查找或筛选交易';
      case PageContextType.transactionDetail:
        final txId = _currentContext!.data?['transactionId'];
        return '用户在查看交易详情${txId != null ? "(ID: $txId)" : ""}，可能想修改或删除';
      case PageContextType.budget:
        final category = _currentContext!.data?['category'];
        return '用户在预算页面${category != null ? "($category)" : ""}，可能想查询余额或调整预算';
      case PageContextType.report:
        return '用户在报表页面，可能想查询统计数据';
      case PageContextType.moneyAge:
        return '用户在钱龄页面，可能想了解钱龄情况';
      case PageContextType.savings:
        return '用户在储蓄页面，可能想查询或操作储蓄目标';
      case PageContextType.settings:
        return '用户在设置页面，可能想调整配置';
      case PageContextType.voiceChat:
        return '用户在语音聊天页面';
      case PageContextType.other:
        return '';
    }
  }

  /// 增强意图解析
  /// 根据当前上下文，补充缺失的意图参数
  Map<String, dynamic> enhanceIntent(Map<String, dynamic> rawIntent) {
    if (_currentContext == null) return rawIntent;

    final enhanced = Map<String, dynamic>.from(rawIntent);

    switch (_currentContext!.type) {
      case PageContextType.transactionDetail:
        // 如果在交易详情页说"改成50"，自动关联当前交易ID
        if (rawIntent['action'] == 'modify' && rawIntent['transactionId'] == null) {
          enhanced['transactionId'] = _currentContext!.data?['transactionId'];
        }
        break;

      case PageContextType.budget:
        // 如果在预算页说"还剩多少"，自动关联当前预算分类
        if (rawIntent['action'] == 'query_budget' && rawIntent['category'] == null) {
          enhanced['category'] = _currentContext!.data?['category'];
          enhanced['remaining'] = _currentContext!.data?['remaining'];
        }
        break;

      case PageContextType.report:
        // 如果在报表页查询，自动使用当前时间范围
        if (rawIntent['action'] == 'query' && rawIntent['dateRange'] == null) {
          enhanced['dateRange'] = _currentContext!.data?['dateRange'];
        }
        break;

      default:
        break;
    }

    return enhanced;
  }

  /// 清除上下文
  void clearContext() {
    _currentContext = null;
    _contextHistory.clear();
    notifyListeners();
  }
}
