import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 桌面小组件尺寸
enum WidgetSize {
  small,   // 1×1 极简版
  medium,  // 2×2 标准版
  large,   // 4×2 信息版
}

/// 桌面小组件服务
class HomeScreenWidgetService {
  static const MethodChannel _channel = MethodChannel('com.bookkeeping.ai/home_widget');

  /// 更新小组件数据
  static Future<void> updateWidget({
    required double todayExpense,
    required double weekExpense,
    Map<String, double>? categoryBreakdown,
    String? insight,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'todayExpense': todayExpense,
        'weekExpense': weekExpense,
        'categoryBreakdown': categoryBreakdown,
        'insight': insight,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Failed to update widget: $e');
    }
  }

  /// 处理小组件点击事件
  static void setupWidgetClickHandler(Function() onWidgetClicked) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetClicked') {
        debugPrint('Widget clicked');
        onWidgetClicked();
      }
    });
  }

  /// 检查小组件是否已添加
  static Future<bool> isWidgetAdded() async {
    try {
      final result = await _channel.invokeMethod<bool>('isWidgetAdded');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to check widget status: $e');
      return false;
    }
  }

  /// 打开小组件设置页面
  static Future<void> openWidgetSettings() async {
    try {
      await _channel.invokeMethod('openWidgetSettings');
    } catch (e) {
      debugPrint('Failed to open widget settings: $e');
    }
  }
}
