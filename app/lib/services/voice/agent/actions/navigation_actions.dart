import '../action_registry.dart';

/// 返回上一页操作
class NavigationBackAction extends Action {
  final void Function()? onNavigateBack;

  NavigationBackAction({this.onNavigateBack});

  @override
  String get id => 'navigation.back';

  @override
  String get name => '返回上一页';

  @override
  String get description => '返回到上一个页面';

  @override
  List<String> get triggerPatterns => [
    '返回',
    '后退',
    '回去',
    '上一页',
    '退出',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      onNavigateBack?.call();
      return ActionResult.success(
        responseText: '好的，返回上一页',
        data: {'action': 'back'},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('返回失败: $e', actionId: id);
    }
  }
}

/// 返回首页操作
class NavigationHomeAction extends Action {
  final void Function()? onNavigateHome;

  NavigationHomeAction({this.onNavigateHome});

  @override
  String get id => 'navigation.home';

  @override
  String get name => '返回首页';

  @override
  String get description => '返回到应用首页';

  @override
  List<String> get triggerPatterns => [
    '首页',
    '主页',
    '回到首页',
    '返回首页',
    '回主页',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      onNavigateHome?.call();
      return ActionResult.success(
        responseText: '好的，回到首页',
        data: {'action': 'home'},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('返回首页失败: $e', actionId: id);
    }
  }
}
