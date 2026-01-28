import 'package:flutter/foundation.dart';

/// 安全日志工具
///
/// 在打印日志时自动脱敏敏感信息，防止隐私泄露
class SafeLogger {
  SafeLogger._();

  /// 敏感数字的正则（金额、电话等）
  static final RegExp _numberPattern = RegExp(r'\d{3,}');

  /// 金额模式
  static final RegExp _amountPattern = RegExp(r'¥?\d+\.?\d*元?');

  /// 打印安全日志
  ///
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [data] 可选的附加数据（会被脱敏）
  static void log(String tag, String message, [dynamic data]) {
    debugPrint('[$tag] $message');

    // 仅在调试模式下打印详细数据，且进行脱敏
    if (kDebugMode && data != null) {
      final sanitized = sanitize(data);
      debugPrint('[$tag]   -> $sanitized');
    }
  }

  /// 打印安全日志（简化版）
  static void d(String tag, String message) {
    debugPrint('[$tag] $message');
  }

  /// 脱敏处理
  ///
  /// 将敏感信息替换为占位符
  static String sanitize(dynamic data) {
    if (data == null) return 'null';

    final str = data.toString();

    // 替换金额
    var result = str.replaceAll(_amountPattern, '¥***');

    // 替换长数字（可能是电话、卡号等）
    result = result.replaceAllMapped(_numberPattern, (match) {
      final num = match.group(0)!;
      if (num.length >= 6) {
        // 长数字只显示前后各2位
        return '${num.substring(0, 2)}****${num.substring(num.length - 2)}';
      }
      return '***';
    });

    return result;
  }

  /// 脱敏金额
  static String sanitizeAmount(double? amount) {
    if (amount == null) return '***';
    // 只显示数量级
    if (amount < 10) return '<10';
    if (amount < 100) return '10-100';
    if (amount < 1000) return '100-1000';
    return '>1000';
  }

  /// 脱敏日期（只保留相对时间）
  static String sanitizeDate(DateTime? date) {
    if (date == null) return '未知';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '超过一周';
  }
}
