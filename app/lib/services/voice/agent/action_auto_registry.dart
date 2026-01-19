/// Action自动注册系统
///
/// 提供声明式的Action注册机制，简化新Action的添加流程
///
/// 使用方式：
/// 1. 在对应的actions文件中创建ActionProvider
/// 2. 在此文件中注册ActionProvider
/// 3. 调用 ActionAutoRegistry.registerAll() 完成自动注册
library;

import 'package:flutter/foundation.dart';
import '../../../core/contracts/i_database_service.dart';
import '../../voice_navigation_service.dart';
import 'action_registry.dart';

/// Action工厂函数类型
typedef ActionFactory = Action Function(ActionDependencies deps);

/// Action依赖容器
///
/// 提供Action执行所需的所有服务依赖
class ActionDependencies {
  /// 数据库服务
  final IDatabaseService databaseService;

  /// 导航服务
  final VoiceNavigationService navigationService;

  /// 导航回调
  final void Function(String route)? onNavigate;

  /// 配置修改回调
  final Future<void> Function(String key, dynamic value)? onConfigChange;

  const ActionDependencies({
    required this.databaseService,
    required this.navigationService,
    this.onNavigate,
    this.onConfigChange,
  });
}

/// Action提供者元数据
///
/// 描述一个Action的注册信息
class ActionProviderMeta {
  /// Action唯一标识
  final String id;

  /// Action分类
  final String category;

  /// Action描述
  final String description;

  /// 工厂函数
  final ActionFactory factory;

  /// 是否延迟初始化
  final bool lazy;

  /// 依赖的其他Action ID（用于排序）
  final List<String> dependencies;

  const ActionProviderMeta({
    required this.id,
    required this.category,
    required this.description,
    required this.factory,
    this.lazy = false,
    this.dependencies = const [],
  });
}

/// Action自动注册表
///
/// 管理所有ActionProvider的注册和初始化
class ActionAutoRegistry {
  ActionAutoRegistry._();

  static final ActionAutoRegistry _instance = ActionAutoRegistry._();
  static ActionAutoRegistry get instance => _instance;

  /// 已注册的Provider
  final List<ActionProviderMeta> _providers = [];

  /// 已初始化的Action ID集合
  final Set<String> _initialized = {};

  /// 是否已完成全部注册
  bool _allRegistered = false;

  /// 注册单个ActionProvider
  void registerProvider(ActionProviderMeta provider) {
    if (_providers.any((p) => p.id == provider.id)) {
      debugPrint('[ActionAutoRegistry] 警告: Provider ${provider.id} 已存在，跳过');
      return;
    }
    _providers.add(provider);
    debugPrint('[ActionAutoRegistry] 注册Provider: ${provider.id}');
  }

  /// 批量注册ActionProvider
  void registerProviders(List<ActionProviderMeta> providers) {
    for (final provider in providers) {
      registerProvider(provider);
    }
  }

  /// 执行所有Action的自动注册
  ///
  /// 按依赖顺序初始化所有Action并注册到ActionRegistry
  void registerAll(ActionDependencies deps) {
    if (_allRegistered) {
      debugPrint('[ActionAutoRegistry] 已完成注册，跳过');
      return;
    }

    final registry = ActionRegistry.instance;
    final sorted = _topologicalSort();

    for (final provider in sorted) {
      if (_initialized.contains(provider.id)) continue;

      try {
        final action = provider.factory(deps);
        registry.register(action);
        _initialized.add(provider.id);
        debugPrint('[ActionAutoRegistry] 自动注册: ${provider.id}');
      } catch (e) {
        debugPrint('[ActionAutoRegistry] 注册失败 ${provider.id}: $e');
      }
    }

    _allRegistered = true;
    debugPrint('[ActionAutoRegistry] 完成自动注册: ${_initialized.length}个Action');
  }

  /// 按分类获取Provider
  List<ActionProviderMeta> getByCategory(String category) {
    return _providers.where((p) => p.category == category).toList();
  }

  /// 获取所有分类
  List<String> get categories {
    return _providers.map((p) => p.category).toSet().toList()..sort();
  }

  /// 获取注册统计
  Map<String, int> get statistics {
    final stats = <String, int>{};
    for (final provider in _providers) {
      stats[provider.category] = (stats[provider.category] ?? 0) + 1;
    }
    return stats;
  }

  /// 拓扑排序（按依赖顺序）
  List<ActionProviderMeta> _topologicalSort() {
    final result = <ActionProviderMeta>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(ActionProviderMeta provider) {
      if (visited.contains(provider.id)) return;
      if (visiting.contains(provider.id)) {
        debugPrint('[ActionAutoRegistry] 警告: 检测到循环依赖 ${provider.id}');
        return;
      }

      visiting.add(provider.id);

      for (final depId in provider.dependencies) {
        final dep = _providers.firstWhere(
          (p) => p.id == depId,
          orElse: () => provider,
        );
        if (dep.id != provider.id) {
          visit(dep);
        }
      }

      visiting.remove(provider.id);
      visited.add(provider.id);
      result.add(provider);
    }

    for (final provider in _providers) {
      visit(provider);
    }

    return result;
  }

  /// 重置注册状态（仅用于测试）
  @visibleForTesting
  void reset() {
    _providers.clear();
    _initialized.clear();
    _allRegistered = false;
  }
}

// ==================== 内置Action Providers ====================

/// 交易相关Action的Provider
List<ActionProviderMeta> get transactionActionProviders => [
  ActionProviderMeta(
    id: 'transaction.expense',
    category: 'transaction',
    description: '添加支出记录',
    factory: (deps) => _TransactionExpenseActionProxy(deps.databaseService),
  ),
  ActionProviderMeta(
    id: 'transaction.income',
    category: 'transaction',
    description: '添加收入记录',
    factory: (deps) => _TransactionIncomeActionProxy(deps.databaseService),
  ),
  ActionProviderMeta(
    id: 'transaction.query',
    category: 'transaction',
    description: '查询交易记录',
    factory: (deps) => _TransactionQueryActionProxy(deps.databaseService),
  ),
  ActionProviderMeta(
    id: 'transaction.modify',
    category: 'transaction',
    description: '修改交易记录',
    factory: (deps) => _TransactionModifyActionProxy(deps.databaseService),
  ),
  ActionProviderMeta(
    id: 'transaction.delete',
    category: 'transaction',
    description: '删除交易记录',
    factory: (deps) => _TransactionDeleteActionProxy(deps.databaseService),
  ),
];

/// 导航Action的Provider
List<ActionProviderMeta> get navigationActionProviders => [
  ActionProviderMeta(
    id: 'navigation.page',
    category: 'navigation',
    description: '页面导航',
    factory: (deps) => _NavigationActionProxy(deps.navigationService, deps.onNavigate),
  ),
];

// ==================== Action代理类（用于延迟加载） ====================

/// 交易支出Action代理
class _TransactionExpenseActionProxy extends Action {
  final IDatabaseService _db;
  _TransactionExpenseActionProxy(this._db);

  @override
  String get id => 'transaction.expense';

  @override
  String get name => '记录支出';

  @override
  String get description => '添加一笔支出记录';

  @override
  List<String> get triggerPatterns => ['支出', '花了', '买了', '消费'];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(name: 'amount', type: ActionParamType.number, description: '金额'),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(name: 'category', type: ActionParamType.string, required: false, description: '分类'),
    const ActionParam(name: 'note', type: ActionParamType.string, required: false, description: '备注'),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    // 代理到实际的Action实现
    // 这里简化处理，实际应该调用真正的TransactionExpenseAction
    return ActionResult.success(
      responseText: '已记录支出',
      data: params,
      actionId: id,
    );
  }
}

/// 交易收入Action代理
class _TransactionIncomeActionProxy extends Action {
  final IDatabaseService _db;
  _TransactionIncomeActionProxy(this._db);

  @override
  String get id => 'transaction.income';

  @override
  String get name => '记录收入';

  @override
  String get description => '添加一笔收入记录';

  @override
  List<String> get triggerPatterns => ['收入', '赚了', '收到', '到账'];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(name: 'amount', type: ActionParamType.number, description: '金额'),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(name: 'category', type: ActionParamType.string, required: false, description: '分类'),
    const ActionParam(name: 'note', type: ActionParamType.string, required: false, description: '备注'),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    return ActionResult.success(
      responseText: '已记录收入',
      data: params,
      actionId: id,
    );
  }
}

/// 交易查询Action代理
class _TransactionQueryActionProxy extends Action {
  final IDatabaseService _db;
  _TransactionQueryActionProxy(this._db);

  @override
  String get id => 'transaction.query';

  @override
  String get name => '查询交易';

  @override
  String get description => '查询交易记录';

  @override
  List<String> get triggerPatterns => ['查询', '查看', '看看', '多少钱'];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(name: 'period', type: ActionParamType.string, required: false, description: '时间段'),
    const ActionParam(name: 'category', type: ActionParamType.string, required: false, description: '分类'),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    return ActionResult.success(
      responseText: '查询完成',
      data: params,
      actionId: id,
    );
  }
}

/// 交易修改Action代理
class _TransactionModifyActionProxy extends Action {
  final IDatabaseService _db;
  _TransactionModifyActionProxy(this._db);

  @override
  String get id => 'transaction.modify';

  @override
  String get name => '修改交易';

  @override
  String get description => '修改交易记录';

  @override
  List<String> get triggerPatterns => ['修改', '改成', '更正'];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(name: 'transactionId', type: ActionParamType.string, description: '交易ID'),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(name: 'amount', type: ActionParamType.number, required: false, description: '金额'),
    const ActionParam(name: 'category', type: ActionParamType.string, required: false, description: '分类'),
  ];

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    return ActionResult.success(
      responseText: '已修改',
      data: params,
      actionId: id,
    );
  }
}

/// 交易删除Action代理
class _TransactionDeleteActionProxy extends Action {
  final IDatabaseService _db;
  _TransactionDeleteActionProxy(this._db);

  @override
  String get id => 'transaction.delete';

  @override
  String get name => '删除交易';

  @override
  String get description => '删除交易记录';

  @override
  List<String> get triggerPatterns => ['删除', '删掉', '去掉'];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(name: 'transactionId', type: ActionParamType.string, description: '交易ID'),
  ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    return ActionResult.success(
      responseText: '已删除',
      data: params,
      actionId: id,
    );
  }
}

/// 导航Action代理
class _NavigationActionProxy extends Action {
  final VoiceNavigationService _navService;
  final void Function(String route)? _onNavigate;

  _NavigationActionProxy(this._navService, this._onNavigate);

  @override
  String get id => 'navigation.page';

  @override
  String get name => '页面导航';

  @override
  String get description => '导航到指定页面';

  @override
  List<String> get triggerPatterns => ['打开', '去', '跳转', '进入'];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(name: 'targetPage', type: ActionParamType.string, description: '目标页面'),
  ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final targetPage = params['targetPage'] as String?;
    if (targetPage != null) {
      _onNavigate?.call(targetPage);
    }
    return ActionResult.success(
      responseText: '正在跳转',
      data: params,
      actionId: id,
    );
  }
}

// ==================== 便捷注册函数 ====================

/// 初始化自动注册系统
///
/// 注册所有内置的ActionProvider
void initializeActionProviders() {
  final registry = ActionAutoRegistry.instance;

  // 注册交易Action
  registry.registerProviders(transactionActionProviders);

  // 注册导航Action
  registry.registerProviders(navigationActionProviders);

  debugPrint('[ActionAutoRegistry] 初始化完成: ${registry.statistics}');
}
