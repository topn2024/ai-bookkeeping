import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_mode_provider.dart';
import '../pages/ultra_simple_home_page.dart';

/// 简易模式路由服务
///
/// 根据当前UI模式返回对应的页面
class SimpleModeRouter {
  final WidgetRef ref;

  SimpleModeRouter(this.ref);

  /// 获取主页
  Widget getHomePage() {
    final mode = ref.read(uiModeProvider).mode;
    if (mode == UIMode.simple) {
      return const UltraSimpleHomePage();
    }
    // 返回普通模式主页（需要导入实际的主页）
    return const UltraSimpleHomePage(); // TODO: 替换为普通主页
  }

  /// 模式感知导航
  ///
  /// 根据当前模式自动选择简易或普通版本的页面
  Future<T?> navigateTo<T>(
    BuildContext context,
    String route, {
    Object? arguments,
  }) async {
    final mode = ref.read(uiModeProvider).mode;
    final page = _getPageForRoute(route, mode, arguments);

    if (page != null) {
      return Navigator.push<T>(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }

    // 如果没有找到对应页面，使用普通路由
    return Navigator.pushNamed<T>(context, route, arguments: arguments);
  }

  /// 根据路由和模式获取页面
  Widget? _getPageForRoute(String route, UIMode mode, Object? arguments) {
    if (mode == UIMode.simple) {
      return _simplePages[route];
    }
    return _normalPages[route];
  }

  /// 简易模式页面注册表
  final Map<String, Widget> _simplePages = {
    '/': const UltraSimpleHomePage(),
    '/home': const UltraSimpleHomePage(),
    // 其他简易页面将在这里注册
  };

  /// 普通模式页面注册表
  final Map<String, Widget> _normalPages = {
    // 普通页面将在这里注册
  };
}

/// 简易模式路由Provider
final simpleModeRouterProvider = Provider<SimpleModeRouter>((ref) {
  return SimpleModeRouter(ref);
});
