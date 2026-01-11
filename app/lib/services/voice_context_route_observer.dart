import 'package:flutter/material.dart';

import 'voice_context_service.dart';
import 'global_voice_assistant_manager.dart';

/// 语音上下文路由观察器
///
/// 监听页面导航事件，自动更新语音助手的页面上下文
class VoiceContextRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  /// 获取 VoiceContextService 的回调
  /// 用于延迟获取服务实例（避免在 main.dart 中循环依赖）
  VoiceContextService? Function()? getContextService;

  VoiceContextRouteObserver({this.getContextService});

  VoiceContextService? get _contextService {
    if (getContextService != null) {
      return getContextService!();
    }
    return GlobalVoiceAssistantManager.instance.contextService;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRouteChange(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _handleRouteChange(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _handleRouteChange(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (previousRoute != null) {
      _handleRouteChange(previousRoute);
    }
  }

  /// 处理路由变化
  void _handleRouteChange(Route<dynamic> route) {
    final contextService = _contextService;
    if (contextService == null) return;

    if (route is PageRoute) {
      final routeName = route.settings.name;
      final arguments = route.settings.arguments;

      debugPrint('[VoiceContextRouteObserver] 路由变化: $routeName');

      contextService.updateContextFromRoute(routeName, arguments: arguments);
    }
  }
}

/// 页面上下文 Mixin
///
/// 页面可以使用此 Mixin 主动更新上下文数据
mixin VoiceContextMixin<T extends StatefulWidget> on State<T> {
  /// 获取上下文服务
  VoiceContextService? get voiceContextService =>
      GlobalVoiceAssistantManager.instance.contextService;

  /// 更新上下文数据
  void updateVoiceContextData(Map<String, dynamic> data) {
    voiceContextService?.updateContextData(data);
  }

  /// 设置当前页面上下文
  void setVoiceContext({
    required PageContextType type,
    Map<String, dynamic>? data,
  }) {
    final routeName = ModalRoute.of(context)?.settings.name;
    voiceContextService?.updateContext(PageContext(
      type: type,
      routeName: routeName,
      data: data,
    ));
  }
}

/// 用于在特定页面排除悬浮球的 Widget
class ExcludeFloatingBall extends StatefulWidget {
  final Widget child;

  const ExcludeFloatingBall({
    super.key,
    required this.child,
  });

  @override
  State<ExcludeFloatingBall> createState() => _ExcludeFloatingBallState();
}

class _ExcludeFloatingBallState extends State<ExcludeFloatingBall> {
  @override
  void initState() {
    super.initState();
    // 进入页面时隐藏悬浮球
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalVoiceAssistantManager.instance.setVisible(false);
    });
  }

  @override
  void dispose() {
    // 离开页面时恢复悬浮球
    GlobalVoiceAssistantManager.instance.setVisible(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
