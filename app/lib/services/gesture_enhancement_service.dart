import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 手势类型
enum GestureType {
  /// 单击
  tap,

  /// 双击
  doubleTap,

  /// 长按
  longPress,

  /// 左滑
  swipeLeft,

  /// 右滑
  swipeRight,

  /// 上滑
  swipeUp,

  /// 下滑
  swipeDown,

  /// 捏合缩小
  pinchIn,

  /// 捏合放大
  pinchOut,

  /// 双指旋转
  rotate,

  /// 拖拽
  drag,

  /// 边缘滑动返回
  edgeSwipeBack,
}

/// 手势动作配置
class GestureAction {
  /// 手势类型
  final GestureType gesture;

  /// 动作名称
  final String actionName;

  /// 动作回调
  final VoidCallback? action;

  /// 是否启用
  final bool enabled;

  /// 是否需要触觉反馈
  final bool hapticFeedback;

  /// 最小滑动距离（用于滑动手势）
  final double minSwipeDistance;

  /// 最小滑动速度（用于滑动手势）
  final double minSwipeVelocity;

  const GestureAction({
    required this.gesture,
    required this.actionName,
    this.action,
    this.enabled = true,
    this.hapticFeedback = true,
    this.minSwipeDistance = 50.0,
    this.minSwipeVelocity = 300.0,
  });
}

/// 单手操作模式
enum OneHandMode {
  /// 右手模式
  rightHand,

  /// 左手模式
  leftHand,

  /// 自动检测
  auto,

  /// 禁用
  disabled,
}

/// 单手操作区域配置
class OneHandReachConfig {
  /// 单手模式
  final OneHandMode mode;

  /// 舒适区域半径（相对于拇指可达范围）
  final double comfortZoneRadius;

  /// 拇指支点位置（屏幕底部偏移）
  final double thumbPivotOffset;

  /// 是否自动调整布局
  final bool autoAdjustLayout;

  /// 是否启用下拉到达
  final bool enablePullDownReach;

  /// 下拉触发距离
  final double pullDownThreshold;

  const OneHandReachConfig({
    this.mode = OneHandMode.auto,
    this.comfortZoneRadius = 0.6,
    this.thumbPivotOffset = 60.0,
    this.autoAdjustLayout = true,
    this.enablePullDownReach = true,
    this.pullDownThreshold = 100.0,
  });
}

/// 手势增强配置
class GestureEnhancementConfig {
  /// 是否启用手势增强
  final bool enabled;

  /// 是否启用触觉反馈
  final bool hapticFeedbackEnabled;

  /// 触摸目标最小尺寸
  final double minTouchTargetSize;

  /// 触摸目标推荐尺寸
  final double recommendedTouchTargetSize;

  /// 长按延迟
  final Duration longPressDelay;

  /// 双击间隔
  final Duration doubleTapInterval;

  /// 滑动检测阈值
  final double swipeThreshold;

  /// 单手操作配置
  final OneHandReachConfig oneHandConfig;

  /// 边缘滑动返回启用
  final bool edgeSwipeBackEnabled;

  /// 边缘滑动触发宽度
  final double edgeSwipeWidth;

  const GestureEnhancementConfig({
    this.enabled = true,
    this.hapticFeedbackEnabled = true,
    this.minTouchTargetSize = 44.0,
    this.recommendedTouchTargetSize = 48.0,
    this.longPressDelay = const Duration(milliseconds: 500),
    this.doubleTapInterval = const Duration(milliseconds: 300),
    this.swipeThreshold = 50.0,
    this.oneHandConfig = const OneHandReachConfig(),
    this.edgeSwipeBackEnabled = true,
    this.edgeSwipeWidth = 20.0,
  });
}

/// 手势增强服务
///
/// 核心功能：
/// 1. 统一手势管理
/// 2. 单手操作优化
/// 3. 触觉反馈集成
/// 4. 手势冲突解决
/// 5. 可达性区域计算
///
/// 对应设计文档：第17章 手势操作优化
/// 对应设计文档：第3章 单手操作优化
///
/// 使用示例：
/// ```dart
/// final service = GestureEnhancementService();
///
/// // 配置单手模式
/// service.setOneHandMode(OneHandMode.rightHand);
///
/// // 检查区域是否在舒适范围内
/// final isComfortable = service.isInComfortZone(offset, screenSize);
/// ```
class GestureEnhancementService extends ChangeNotifier {
  /// 配置
  GestureEnhancementConfig _config;

  /// 手势历史记录
  final List<_GestureRecord> _gestureHistory = [];

  /// 最大历史记录数
  static const int maxHistorySize = 50;

  /// 检测到的惯用手
  OneHandMode _detectedHandMode = OneHandMode.auto;

  /// 左手操作计数
  int _leftHandCount = 0;

  /// 右手操作计数
  int _rightHandCount = 0;

  GestureEnhancementService({
    GestureEnhancementConfig config = const GestureEnhancementConfig(),
  }) : _config = config;

  GestureEnhancementConfig get config => _config;
  OneHandMode get detectedHandMode => _detectedHandMode;

  /// 更新配置
  void updateConfig(GestureEnhancementConfig config) {
    _config = config;
    notifyListeners();
  }

  /// 设置单手模式
  void setOneHandMode(OneHandMode mode) {
    _config = GestureEnhancementConfig(
      enabled: _config.enabled,
      hapticFeedbackEnabled: _config.hapticFeedbackEnabled,
      minTouchTargetSize: _config.minTouchTargetSize,
      recommendedTouchTargetSize: _config.recommendedTouchTargetSize,
      longPressDelay: _config.longPressDelay,
      doubleTapInterval: _config.doubleTapInterval,
      swipeThreshold: _config.swipeThreshold,
      oneHandConfig: OneHandReachConfig(
        mode: mode,
        comfortZoneRadius: _config.oneHandConfig.comfortZoneRadius,
        thumbPivotOffset: _config.oneHandConfig.thumbPivotOffset,
        autoAdjustLayout: _config.oneHandConfig.autoAdjustLayout,
        enablePullDownReach: _config.oneHandConfig.enablePullDownReach,
        pullDownThreshold: _config.oneHandConfig.pullDownThreshold,
      ),
      edgeSwipeBackEnabled: _config.edgeSwipeBackEnabled,
      edgeSwipeWidth: _config.edgeSwipeWidth,
    );
    notifyListeners();
  }

  /// 记录手势
  void recordGesture(GestureType type, Offset position) {
    _gestureHistory.add(_GestureRecord(
      type: type,
      position: position,
      timestamp: DateTime.now(),
    ));

    // 限制历史记录大小
    if (_gestureHistory.length > maxHistorySize) {
      _gestureHistory.removeAt(0);
    }

    // 自动检测惯用手
    if (_config.oneHandConfig.mode == OneHandMode.auto) {
      _detectHandPreference(position);
    }
  }

  /// 检测惯用手
  void _detectHandPreference(Offset position) {
    // 基于触摸位置判断可能的惯用手
    // 右手用户倾向于触摸屏幕右侧，左手用户倾向于左侧
    final screenWidth = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    if (position.dx > screenWidth * 0.6) {
      _rightHandCount++;
    } else if (position.dx < screenWidth * 0.4) {
      _leftHandCount++;
    }

    // 达到阈值后判断
    if (_leftHandCount + _rightHandCount >= 20) {
      _detectedHandMode = _rightHandCount > _leftHandCount
          ? OneHandMode.rightHand
          : OneHandMode.leftHand;
      notifyListeners();
    }
  }

  /// 检查点是否在舒适区域内
  bool isInComfortZone(Offset point, Size screenSize) {
    final oneHandConfig = _config.oneHandConfig;
    final mode = oneHandConfig.mode == OneHandMode.auto
        ? _detectedHandMode
        : oneHandConfig.mode;

    if (mode == OneHandMode.disabled) {
      return true;
    }

    // 计算拇指支点位置
    final thumbPivot = Offset(
      mode == OneHandMode.rightHand
          ? screenSize.width - 40
          : 40,
      screenSize.height - oneHandConfig.thumbPivotOffset,
    );

    // 计算舒适区域半径
    final maxReach = screenSize.height * oneHandConfig.comfortZoneRadius;

    // 计算点到拇指支点的距离
    final distance = (point - thumbPivot).distance;

    return distance <= maxReach;
  }

  /// 获取舒适区域矩形（用于布局优化）
  Rect getComfortZone(Size screenSize) {
    final oneHandConfig = _config.oneHandConfig;
    final mode = oneHandConfig.mode == OneHandMode.auto
        ? _detectedHandMode
        : oneHandConfig.mode;

    if (mode == OneHandMode.disabled) {
      return Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    }

    final thumbPivot = Offset(
      mode == OneHandMode.rightHand
          ? screenSize.width - 40
          : 40,
      screenSize.height - oneHandConfig.thumbPivotOffset,
    );

    final maxReach = screenSize.height * oneHandConfig.comfortZoneRadius;

    // 返回舒适区域矩形（近似）
    return Rect.fromCenter(
      center: thumbPivot,
      width: maxReach * 1.5,
      height: maxReach * 2,
    ).intersect(Rect.fromLTWH(0, 0, screenSize.width, screenSize.height));
  }

  /// 获取推荐的FAB位置
  Alignment getRecommendedFabAlignment() {
    final mode = _config.oneHandConfig.mode == OneHandMode.auto
        ? _detectedHandMode
        : _config.oneHandConfig.mode;

    switch (mode) {
      case OneHandMode.leftHand:
        return Alignment.bottomLeft;
      case OneHandMode.rightHand:
      case OneHandMode.auto:
      case OneHandMode.disabled:
        return Alignment.bottomRight;
    }
  }

  /// 获取推荐的底部导航项顺序
  List<int> getRecommendedNavOrder(int itemCount) {
    final mode = _config.oneHandConfig.mode == OneHandMode.auto
        ? _detectedHandMode
        : _config.oneHandConfig.mode;

    final indices = List.generate(itemCount, (i) => i);

    // 左手模式时，将常用项放在左边
    if (mode == OneHandMode.leftHand) {
      return indices.reversed.toList();
    }

    return indices;
  }

  /// 触发触觉反馈
  void triggerHapticFeedback(HapticFeedbackType type) {
    if (!_config.hapticFeedbackEnabled) return;

    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.vibrate:
        HapticFeedback.vibrate();
        break;
    }
  }

  /// 检查触摸目标尺寸是否合规
  bool isTouchTargetCompliant(Size size) {
    return size.width >= _config.minTouchTargetSize &&
        size.height >= _config.minTouchTargetSize;
  }

  /// 获取推荐的触摸目标尺寸
  double getRecommendedTouchTargetSize() {
    return _config.recommendedTouchTargetSize;
  }

  /// 清除手势历史
  void clearHistory() {
    _gestureHistory.clear();
    _leftHandCount = 0;
    _rightHandCount = 0;
    _detectedHandMode = OneHandMode.auto;
  }
}

/// 手势记录
class _GestureRecord {
  final GestureType type;
  final Offset position;
  final DateTime timestamp;

  _GestureRecord({
    required this.type,
    required this.position,
    required this.timestamp,
  });
}

/// 触觉反馈类型
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
  vibrate,
}

/// 单手操作优化包装器
///
/// 自动将内容移动到舒适区域
class OneHandReachWrapper extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 手势服务
  final GestureEnhancementService gestureService;

  /// 是否启用下拉到达
  final bool enablePullDown;

  const OneHandReachWrapper({
    super.key,
    required this.child,
    required this.gestureService,
    this.enablePullDown = true,
  });

  @override
  State<OneHandReachWrapper> createState() => _OneHandReachWrapperState();
}

class _OneHandReachWrapperState extends State<OneHandReachWrapper>
    with SingleTickerProviderStateMixin {
  /// 下拉偏移量
  double _pullOffset = 0;

  /// 是否正在下拉
  bool _isPulling = false;

  /// 动画控制器
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enablePullDown ||
        !widget.gestureService.config.oneHandConfig.enablePullDownReach) {
      return widget.child;
    }

    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final offset = _isPulling
              ? _pullOffset
              : _pullOffset * (1 - _animationController.value);

          return Transform.translate(
            offset: Offset(0, offset),
            child: widget.child,
          );
        },
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    // 只在屏幕顶部开始下拉时响应
    if (details.localPosition.dy < 100) {
      setState(() {
        _isPulling = true;
        _animationController.reset();
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isPulling) return;

    setState(() {
      _pullOffset = (_pullOffset + details.delta.dy).clamp(0.0, 200.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isPulling) return;

    setState(() {
      _isPulling = false;
    });

    // 触发触觉反馈
    if (_pullOffset > widget.gestureService.config.oneHandConfig.pullDownThreshold) {
      widget.gestureService.triggerHapticFeedback(HapticFeedbackType.medium);
    }

    // 回弹动画
    _animationController.forward().then((_) {
      setState(() {
        _pullOffset = 0;
      });
    });
  }
}

/// 增强触摸目标组件
///
/// 自动扩展触摸区域到最小推荐尺寸
class EnhancedTouchTarget extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 最小尺寸
  final double minSize;

  /// 是否启用触觉反馈
  final bool hapticFeedback;

  const EnhancedTouchTarget({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.minSize = 48.0,
    this.hapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        onTap?.call();
      },
      onLongPress: () {
        if (hapticFeedback) {
          HapticFeedback.mediumImpact();
        }
        onLongPress?.call();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// 边缘滑动返回检测器
class EdgeSwipeBackDetector extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 返回回调
  final VoidCallback? onBack;

  /// 边缘宽度
  final double edgeWidth;

  /// 滑动阈值
  final double swipeThreshold;

  /// 是否启用
  final bool enabled;

  const EdgeSwipeBackDetector({
    super.key,
    required this.child,
    this.onBack,
    this.edgeWidth = 20.0,
    this.swipeThreshold = 100.0,
    this.enabled = true,
  });

  @override
  State<EdgeSwipeBackDetector> createState() => _EdgeSwipeBackDetectorState();
}

class _EdgeSwipeBackDetectorState extends State<EdgeSwipeBackDetector> {
  bool _isEdgeSwipe = false;
  double _swipeDistance = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          widget.child,
          // 滑动指示器
          if (_isEdgeSwipe && _swipeDistance > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: _swipeDistance.clamp(0, widget.swipeThreshold),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Theme.of(context).primaryColor.withValues(alpha:
                      (_swipeDistance / widget.swipeThreshold).clamp(0, 1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    if (details.localPosition.dx < widget.edgeWidth) {
      setState(() {
        _isEdgeSwipe = true;
        _swipeDistance = 0;
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isEdgeSwipe) return;

    setState(() {
      _swipeDistance = (_swipeDistance + details.delta.dx).clamp(0, widget.swipeThreshold * 1.5);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isEdgeSwipe) return;

    if (_swipeDistance >= widget.swipeThreshold) {
      HapticFeedback.mediumImpact();
      widget.onBack?.call();
    }

    setState(() {
      _isEdgeSwipe = false;
      _swipeDistance = 0;
    });
  }
}
