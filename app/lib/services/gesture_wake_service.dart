import 'dart:async';
import 'package:flutter/foundation.dart';
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

  /// 初始化
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载手势设置
    for (var gesture in GestureWakeType.values) {
      final key = 'gesture_wake_${gesture.name}';
      _enabledGestures[gesture] = prefs.getBool(key) ?? _enabledGestures[gesture]!;
    }

    debugPrint('GestureWakeService initialized');
  }

  /// 开始监听手势
  Future<void> startListening() async {
    // 启动摇一摇监听
    if (_enabledGestures[GestureWakeType.shake]!) {
      _startShakeDetection();
    }

    // TODO: 启动其他手势监听
  }

  /// 停止监听
  Future<void> stopListening() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  /// 启动摇一摇检测
  void _startShakeDetection() {
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

  /// 设置手势启用状态
  Future<void> setGestureEnabled(GestureWakeType gesture, bool enabled) async {
    _enabledGestures[gesture] = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gesture_wake_${gesture.name}', enabled);

    // 重新启动监听
    if (enabled) {
      if (gesture == GestureWakeType.shake) {
        _startShakeDetection();
      }
    } else {
      if (gesture == GestureWakeType.shake) {
        await _accelerometerSubscription?.cancel();
        _accelerometerSubscription = null;
      }
    }
  }

  /// 获取手势启用状态
  bool isGestureEnabled(GestureWakeType gesture) {
    return _enabledGestures[gesture] ?? false;
  }

  /// 获取所有手势状态
  Map<GestureWakeType, bool> get enabledGestures => Map.unmodifiable(_enabledGestures);

  void dispose() {
    _accelerometerSubscription?.cancel();
    _gestureController.close();
  }
}
