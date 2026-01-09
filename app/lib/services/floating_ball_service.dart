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
  bool _isEnabled = false;
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
class FloatingBallWidget extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingBallWidget({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  State<FloatingBallWidget> createState() => _FloatingBallWidgetState();
}

class _FloatingBallWidgetState extends State<FloatingBallWidget> {
  Offset _position = const Offset(300, 500);
  FloatingBallState _state = FloatingBallState.normal;

  @override
  void initState() {
    super.initState();
    FloatingBallService().onStateChanged.listen((state) {
      setState(() => _state = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: _buildBall(),
      ),
    );
  }

  Widget _buildBall() {
    final size = _state == FloatingBallState.amountDetected ? 60.0 : 50.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getBallColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: _getBallContent(),
      ),
    );
  }

  Color _getBallColor() {
    switch (_state) {
      case FloatingBallState.amountDetected:
        return Colors.orange;
      case FloatingBallState.expanded:
        return Colors.blue;
      default:
        return Colors.blue.shade400;
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

    return const Icon(
      Icons.mic,
      color: Colors.white,
      size: 24,
    );
  }
}
