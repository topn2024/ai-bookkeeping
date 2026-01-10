import 'dart:async';
import 'package:flutter/foundation.dart';
import 'voice_wake_word_service.dart';
import 'gesture_wake_service.dart';
import 'home_screen_widget_service.dart';

/// 唤醒入口类型
enum WakeUpEntryType {
  voiceWakeWord,      // 语音唤醒词
  lockScreenVoice,    // 锁屏语音
  homeWidget,         // 桌面小组件
  floatingBall,       // 全局悬浮球
  gesture,            // 手势快捷方式
  wearableDevice,     // 可穿戴设备
  paymentNotification,// 支付通知
  locationTrigger,    // 位置触发
}

/// 唤醒事件
class MultimodalWakeUpEvent {
  final WakeUpEntryType entryType;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  MultimodalWakeUpEvent({
    required this.entryType,
    required this.timestamp,
    this.metadata,
  });

  @override
  String toString() {
    return 'WakeUpEvent(type: $entryType, time: $timestamp, metadata: $metadata)';
  }
}

/// 多模态唤醒入口管理服务
class MultimodalWakeUpService {
  static final MultimodalWakeUpService _instance = MultimodalWakeUpService._internal();
  factory MultimodalWakeUpService() => _instance;
  MultimodalWakeUpService._internal();

  final VoiceWakeWordService _voiceWakeService = VoiceWakeWordService();
  final GestureWakeService _gestureWakeService = GestureWakeService();

  /// 统一的唤醒事件流
  final StreamController<MultimodalWakeUpEvent> _wakeUpController =
      StreamController<MultimodalWakeUpEvent>.broadcast();
  Stream<MultimodalWakeUpEvent> get onWakeUp => _wakeUpController.stream;

  StreamSubscription<WakeUpEvent>? _voiceWakeSubscription;
  StreamSubscription<GestureWakeType>? _gestureWakeSubscription;

  /// 初始化所有唤醒入口
  Future<void> initialize() async {
    debugPrint('Initializing multimodal wake-up service...');

    // 初始化各个服务
    await _voiceWakeService.initialize();
    await _gestureWakeService.initialize();

    // 监听语音唤醒
    _voiceWakeSubscription = _voiceWakeService.onWakeUp.listen((event) {
      _wakeUpController.add(MultimodalWakeUpEvent(
        entryType: WakeUpEntryType.voiceWakeWord,
        timestamp: event.timestamp,
        metadata: {
          'wakeWord': event.wakeWord,
          'followingText': event.followingText,
          'confidence': event.confidence,
        },
      ));
    });

    // 监听手势唤醒
    _gestureWakeSubscription = _gestureWakeService.onGestureWake.listen((gestureType) {
      _wakeUpController.add(MultimodalWakeUpEvent(
        entryType: WakeUpEntryType.gesture,
        timestamp: DateTime.now(),
        metadata: {
          'gestureType': gestureType.name,
        },
      ));
    });

    // 设置小组件点击处理
    HomeScreenWidgetService.setupWidgetClickHandler(() {
      _wakeUpController.add(MultimodalWakeUpEvent(
        entryType: WakeUpEntryType.homeWidget,
        timestamp: DateTime.now(),
      ));
    });

    debugPrint('Multimodal wake-up service initialized');
  }

  /// 启动所有唤醒监听
  Future<void> startListening() async {
    await _voiceWakeService.startListening();
    await _gestureWakeService.startListening();
  }

  /// 停止所有唤醒监听
  Future<void> stopListening() async {
    await _voiceWakeService.stopListening();
    await _gestureWakeService.stopListening();
  }

  /// 更新小组件数据
  Future<void> updateWidgetData({
    required double todayExpense,
    required double weekExpense,
    Map<String, double>? categoryBreakdown,
    String? insight,
  }) async {
    await HomeScreenWidgetService.updateWidget(
      todayExpense: todayExpense,
      weekExpense: weekExpense,
      categoryBreakdown: categoryBreakdown,
      insight: insight,
    );
  }

  /// 获取语音唤醒服务
  VoiceWakeWordService get voiceWakeService => _voiceWakeService;

  /// 获取手势唤醒服务
  GestureWakeService get gestureWakeService => _gestureWakeService;

  void dispose() {
    _voiceWakeSubscription?.cancel();
    _gestureWakeSubscription?.cancel();
    _voiceWakeService.dispose();
    _gestureWakeService.dispose();
    _wakeUpController.close();
  }
}
