import 'package:flutter/material.dart';

/// 网络状态通知服务
///
/// 负责向用户显示网络状态变化的通知
class NetworkStatusNotifier {
  /// 显示离线模式通知
  static void showOfflineModeNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('网络不佳，已启动离线模式'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// 显示在线模式恢复通知
  static void showOnlineModeRestored(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('网络已恢复，智能模式已启用'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 显示LLM处理中通知
  static void showProcessingNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在思考...'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// 显示LLM超时降级通知
  static void showLLMTimeoutNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('网络响应较慢，已切换到快速模式'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
