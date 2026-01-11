import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 悬浮球状态
enum FloatingBallState {
  normal,      // 默认态
  amountDetected, // 检测到金额
  expanded,    // 展开态
  hidden,      // 隐藏
}

/// 全局悬浮球服务
class FloatingBallService {
  static final FloatingBallService _instance = FloatingBallService._internal();
  factory FloatingBallService() => _instance;
  FloatingBallService._internal();

  static const MethodChannel _channel = MethodChannel('com.bookkeeping.ai/floating_ball');

  /// 悬浮球状态流
  final StreamController<FloatingBallState> _stateController =
      StreamController<FloatingBallState>.broadcast();
  Stream<FloatingBallState> get onStateChanged => _stateController.stream;

  /// 悬浮球点击事件流
  final StreamController<void> _clickController = StreamController<void>.broadcast();
  Stream<void> get onClicked => _clickController.stream;

  FloatingBallState _currentState = FloatingBallState.normal;
  bool _isEnabled = true;  // 默认启用悬浮球
  String? _detectedAmount;

  /// 初始化
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// 处理原生调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFloatingBallClicked':
        _clickController.add(null);
        break;
      case 'onClipboardChanged':
        final text = call.arguments as String?;
        if (text != null) {
          _handleClipboardChange(text);
        }
        break;
    }
  }

  /// 处理剪贴板变化
  void _handleClipboardChange(String text) {
    // 检测金额
    final amountRegex = RegExp(r'¥?(\d+\.?\d*)');
    final match = amountRegex.firstMatch(text);

    if (match != null) {
      _detectedAmount = match.group(1);
      _updateState(FloatingBallState.amountDetected);
    }
  }

  /// 显示悬浮球
  Future<void> show() async {
    _isEnabled = true;
    try {
      await _channel.invokeMethod('showFloatingBall');
    } catch (e) {
      debugPrint('Floating ball native implementation not available: $e');
    }
  }

  /// 隐藏悬浮球
  Future<void> hide() async {
    _isEnabled = false;
    _updateState(FloatingBallState.hidden);
    try {
      await _channel.invokeMethod('hideFloatingBall');
    } catch (e) {
      debugPrint('Floating ball native implementation not available: $e');
    }
  }

  /// 更新悬浮球状态
  void _updateState(FloatingBallState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);

      // 通知原生层更新UI
      _channel.invokeMethod('updateFloatingBallState', {
        'state': newState.name,
        'amount': _detectedAmount,
      });
    }
  }

  /// 获取检测到的金额
  String? get detectedAmount => _detectedAmount;

  /// 清除检测到的金额
  void clearDetectedAmount() {
    _detectedAmount = null;
    _updateState(FloatingBallState.normal);
  }

  /// 是否已启用
  bool get isEnabled => _isEnabled;

  /// 当前状态
  FloatingBallState get currentState => _currentState;

  void dispose() {
    _stateController.close();
    _clickController.close();
  }
}

/// 悬浮球Widget（用于应用内显示）
/// 特性：
/// - 默认位置在右下角
/// - 可手动拖动
/// - 拖动结束后自动吸附到屏幕边缘
/// - 自动避开底部导航栏和FAB按钮区域
class FloatingBallWidget extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingBallWidget({
    super.key,
    required this.onTap,
  });

  @override
  State<FloatingBallWidget> createState() => _FloatingBallWidgetState();
}

class _FloatingBallWidgetState extends State<FloatingBallWidget>
    with TickerProviderStateMixin {
  Offset? _position;
  FloatingBallState _state = FloatingBallState.normal;
  bool _isDragging = false;
  late AnimationController _animationController;
  late AnimationController _breatheController;
  Animation<Offset>? _snapAnimation;

  // 悬浮球尺寸
  static const double _ballSize = 52.0;
  static const double _ballSizeExpanded = 62.0;

  // 安全边距
  static const double _edgePadding = 16.0;
  static const double _bottomNavHeight = 80.0;  // 底部导航栏高度
  static const double _fabAreaHeight = 100.0;   // FAB按钮区域高度
  static const double _fabAreaWidth = 120.0;    // FAB按钮区域宽度

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animationController.addListener(() {
      if (_snapAnimation != null) {
        setState(() {
          _position = _snapAnimation!.value;
        });
      }
    });

    FloatingBallService().onStateChanged.listen((state) {
      if (mounted) {
        setState(() => _state = state);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  /// 获取默认位置（右下角，避开导航栏）
  Offset _getDefaultPosition(Size screenSize) {
    return Offset(
      screenSize.width - _ballSize - _edgePadding,
      screenSize.height - _ballSize - _bottomNavHeight - _fabAreaHeight - _edgePadding,
    );
  }

  /// 计算吸附后的位置
  Offset _calculateSnapPosition(Offset currentPos, Size screenSize) {
    final double centerX = currentPos.dx + _ballSize / 2;
    final double screenCenterX = screenSize.width / 2;

    // 计算安全区域边界
    final double minY = MediaQuery.of(context).padding.top + _edgePadding;
    final double maxY = screenSize.height - _ballSize - _bottomNavHeight - _edgePadding;

    // 根据位置决定吸附到左边还是右边
    double targetX;
    if (centerX < screenCenterX) {
      // 吸附到左边
      targetX = _edgePadding;
    } else {
      // 吸附到右边
      targetX = screenSize.width - _ballSize - _edgePadding;
    }

    // Y坐标限制在安全范围内
    double targetY = currentPos.dy.clamp(minY, maxY);

    // 避开底部中间的FAB区域
    final fabCenterX = screenSize.width / 2;
    final fabLeft = fabCenterX - _fabAreaWidth / 2;
    final fabRight = fabCenterX + _fabAreaWidth / 2;
    final fabTop = screenSize.height - _bottomNavHeight - _fabAreaHeight;

    // 如果悬浮球在FAB区域附近，将其移到FAB区域上方
    if (targetY > fabTop - _ballSize &&
        targetX + _ballSize > fabLeft &&
        targetX < fabRight) {
      targetY = fabTop - _ballSize - _edgePadding;
    }

    return Offset(targetX, targetY);
  }

  /// 执行吸附动画
  void _snapToEdge(Size screenSize) {
    if (_position == null) return;

    final targetPos = _calculateSnapPosition(_position!, screenSize);

    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: targetPos,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 初始化位置（首次渲染时）
    _position ??= _getDefaultPosition(screenSize);

    final currentSize = _state == FloatingBallState.amountDetected
        ? _ballSizeExpanded
        : _ballSize;

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) {
          setState(() => _isDragging = true);
          _animationController.stop();
        },
        onPanUpdate: (details) {
          setState(() {
            final newX = (_position!.dx + details.delta.dx).clamp(
              0.0,
              screenSize.width - currentSize,
            );
            final newY = (_position!.dy + details.delta.dy).clamp(
              MediaQuery.of(context).padding.top,
              screenSize.height - currentSize - _bottomNavHeight,
            );
            _position = Offset(newX, newY);
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          _snapToEdge(screenSize);
        },
        child: AnimatedBuilder(
          animation: _breatheController,
          builder: (context, child) {
            final breatheScale = 1.0 + (_breatheController.value * 0.05);
            return Transform.scale(
              scale: _isDragging ? 1.1 : breatheScale,
              child: Container(
                width: currentSize,
                height: currentSize,
                decoration: BoxDecoration(
                  gradient: _getBallGradient(),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.4),
                      blurRadius: _isDragging ? 16 : 12,
                      offset: Offset(0, _isDragging ? 6 : 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _getBallContent(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 获取渐变色
  LinearGradient _getBallGradient() {
    switch (_state) {
      case FloatingBallState.amountDetected:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
        );
      default:
        // 可爱的粉紫渐变，女性喜欢的配色
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
        );
    }
  }

  Color _getPrimaryColor() {
    switch (_state) {
      case FloatingBallState.amountDetected:
        return const Color(0xFFFF8C00);
      default:
        return const Color(0xFFFF9A9E);
    }
  }

  Widget _getBallContent() {
    if (_state == FloatingBallState.amountDetected) {
      final amount = FloatingBallService().detectedAmount;
      return Text(
        '¥$amount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // 可爱的猫咪表情图标
    return const Text(
      '🐱',
      style: TextStyle(fontSize: 26),
    );
  }
}
