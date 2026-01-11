import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

/// 手势唤醒类型
enum GestureWakeType {
  shake,           // 摇一摇
  doubleTapBack,   // 双击背面
  threeFingerSwipe,// 三指下滑
  flipDown,        // 翻转放下
  volumeLongPress, // 长按音量键
}

/// 手势唤醒服务
class GestureWakeService {
  static final GestureWakeService _instance = GestureWakeService._internal();
  factory GestureWakeService() => _instance;
  GestureWakeService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('com.example.ai_bookkeeping/gesture_wake');
  static const EventChannel _eventChannel =
      EventChannel('com.example.ai_bookkeeping/gesture_wake_events');

  /// 手势唤醒事件流
  final StreamController<GestureWakeType> _gestureController = StreamController<GestureWakeType>.broadcast();
  Stream<GestureWakeType> get onGestureWake => _gestureController.stream;

  /// 启用的手势类型
  final Map<GestureWakeType, bool> _enabledGestures = {
    GestureWakeType.shake: true,
    GestureWakeType.doubleTapBack: false,
    GestureWakeType.threeFingerSwipe: false,
    GestureWakeType.flipDown: false,
    GestureWakeType.volumeLongPress: false,
  };

  /// 摇一摇相关
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastShakeTime;
  int _shakeCount = 0;
  static const double _shakeThreshold = 15.0; // 摇晃阈值
  static const Duration _shakeWindow = Duration(milliseconds: 500); // 摇晃时间窗口
  static const Duration _shakeCooldown = Duration(seconds: 3); // 防误触冷却时间

  /// 翻转检测相关
  StreamSubscription<AccelerometerEvent>? _flipSubscription;
  bool _wasPhoneFlat = false;
  DateTime? _lastFlipTime;
  static const Duration _flipCooldown = Duration(seconds: 3);
  static const double _flatThreshold = 1.5;  // 平放阈值 (接近0)
  static const double _flipThreshold = 8.0;  // 翻转阈值 (接近9.8)

  /// 原生事件监听
  StreamSubscription? _nativeEventSubscription;

  /// 初始化
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载手势设置
    for (var gesture in GestureWakeType.values) {
      final key = 'gesture_wake_${gesture.name}';
      _enabledGestures[gesture] = prefs.getBool(key) ?? _enabledGestures[gesture]!;
    }

    // 监听原生手势事件
    _nativeEventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is String) {
          _handleNativeGesture(data);
        }
      },
      onError: (error) {
        debugPrint('GestureWakeService: Native event error: $error');
      },
    );

    debugPrint('GestureWakeService initialized');
  }

  /// 处理原生手势事件
  void _handleNativeGesture(String gestureType) {
    switch (gestureType) {
      case 'doubleTapBack':
        if (_enabledGestures[GestureWakeType.doubleTapBack]!) {
          debugPrint('Double tap back detected');
          _gestureController.add(GestureWakeType.doubleTapBack);
        }
        break;
      case 'volumeLongPress':
        if (_enabledGestures[GestureWakeType.volumeLongPress]!) {
          debugPrint('Volume long press detected');
          _gestureController.add(GestureWakeType.volumeLongPress);
        }
        break;
      case 'threeFingerSwipe':
        if (_enabledGestures[GestureWakeType.threeFingerSwipe]!) {
          debugPrint('Three finger swipe detected');
          _gestureController.add(GestureWakeType.threeFingerSwipe);
        }
        break;
    }
  }

  /// 开始监听手势
  Future<void> startListening() async {
    // 启动摇一摇监听
    if (_enabledGestures[GestureWakeType.shake]!) {
      _startShakeDetection();
    }

    // 启动翻转检测
    if (_enabledGestures[GestureWakeType.flipDown]!) {
      _startFlipDetection();
    }

    // 启动原生手势监听 (双击背面、长按音量键)
    if (_enabledGestures[GestureWakeType.doubleTapBack]! ||
        _enabledGestures[GestureWakeType.volumeLongPress]!) {
      await _startNativeGestureDetection();
    }
  }

  /// 停止监听
  Future<void> stopListening() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    await _flipSubscription?.cancel();
    _flipSubscription = null;

    await _stopNativeGestureDetection();
  }

  /// 启动摇一摇检测
  void _startShakeDetection() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      final now = DateTime.now();

      // 计算加速度幅度
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // 检测摇晃
      if (magnitude > _shakeThreshold) {
        if (_lastShakeTime == null || now.difference(_lastShakeTime!) > _shakeWindow) {
          // 新的摇晃序列
          _shakeCount = 1;
          _lastShakeTime = now;
        } else {
          // 连续摇晃
          _shakeCount++;
          _lastShakeTime = now;

          // 检测到2次连续摇晃
          if (_shakeCount >= 2) {
            _onShakeDetected();
            _shakeCount = 0;
            _lastShakeTime = null;
          }
        }
      }
    });
  }

  /// 摇一摇检测到
  void _onShakeDetected() {
    final now = DateTime.now();

    // 防误触：检查冷却时间
    if (_lastShakeTime != null && now.difference(_lastShakeTime!) < _shakeCooldown) {
      return;
    }

    debugPrint('Shake gesture detected');
    _gestureController.add(GestureWakeType.shake);
  }

  /// 启动翻转检测
  void _startFlipDetection() {
    _flipSubscription?.cancel();
    _flipSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      final now = DateTime.now();

      // Z轴加速度：正值表示屏幕朝上，负值表示屏幕朝下
      final zAxis = event.z;

      // 检测是否平放（屏幕朝上）
      if (zAxis > _flipThreshold) {
        _wasPhoneFlat = true;
      }

      // 检测翻转（从平放变为屏幕朝下）
      if (_wasPhoneFlat && zAxis < -_flipThreshold) {
        _wasPhoneFlat = false;

        // 检查冷却时间
        if (_lastFlipTime == null || now.difference(_lastFlipTime!) > _flipCooldown) {
          _lastFlipTime = now;
          _onFlipDetected();
        }
      }
    });
  }

  /// 翻转检测到
  void _onFlipDetected() {
    debugPrint('Flip down gesture detected');
    _gestureController.add(GestureWakeType.flipDown);
  }

  /// 启动原生手势检测
  Future<void> _startNativeGestureDetection() async {
    try {
      await _methodChannel.invokeMethod('startGestureDetection', {
        'doubleTapBack': _enabledGestures[GestureWakeType.doubleTapBack],
        'volumeLongPress': _enabledGestures[GestureWakeType.volumeLongPress],
      });
    } catch (e) {
      debugPrint('GestureWakeService: Failed to start native gesture detection: $e');
    }
  }

  /// 停止原生手势检测
  Future<void> _stopNativeGestureDetection() async {
    try {
      await _methodChannel.invokeMethod('stopGestureDetection');
    } catch (e) {
      debugPrint('GestureWakeService: Failed to stop native gesture detection: $e');
    }
  }

  /// 设置手势启用状态
  Future<void> setGestureEnabled(GestureWakeType gesture, bool enabled) async {
    _enabledGestures[gesture] = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gesture_wake_${gesture.name}', enabled);

    // 重新启动监听
    if (enabled) {
      switch (gesture) {
        case GestureWakeType.shake:
          _startShakeDetection();
          break;
        case GestureWakeType.flipDown:
          _startFlipDetection();
          break;
        case GestureWakeType.doubleTapBack:
        case GestureWakeType.volumeLongPress:
          await _startNativeGestureDetection();
          break;
        case GestureWakeType.threeFingerSwipe:
          // 三指下滑在UI层处理
          break;
      }
    } else {
      switch (gesture) {
        case GestureWakeType.shake:
          await _accelerometerSubscription?.cancel();
          _accelerometerSubscription = null;
          break;
        case GestureWakeType.flipDown:
          await _flipSubscription?.cancel();
          _flipSubscription = null;
          break;
        case GestureWakeType.doubleTapBack:
        case GestureWakeType.volumeLongPress:
          // 检查是否还有其他原生手势启用
          if (!_enabledGestures[GestureWakeType.doubleTapBack]! &&
              !_enabledGestures[GestureWakeType.volumeLongPress]!) {
            await _stopNativeGestureDetection();
          } else {
            await _startNativeGestureDetection();
          }
          break;
        case GestureWakeType.threeFingerSwipe:
          break;
      }
    }
  }

  /// 获取手势启用状态
  bool isGestureEnabled(GestureWakeType gesture) {
    return _enabledGestures[gesture] ?? false;
  }

  /// 获取所有手势状态
  Map<GestureWakeType, bool> get enabledGestures => Map.unmodifiable(_enabledGestures);

  /// 处理三指下滑手势 (从UI层调用)
  void handleThreeFingerSwipe() {
    if (_enabledGestures[GestureWakeType.threeFingerSwipe]!) {
      debugPrint('Three finger swipe detected');
      _gestureController.add(GestureWakeType.threeFingerSwipe);
    }
  }

  void dispose() {
    _accelerometerSubscription?.cancel();
    _flipSubscription?.cancel();
    _nativeEventSubscription?.cancel();
    _gestureController.close();
  }
}
