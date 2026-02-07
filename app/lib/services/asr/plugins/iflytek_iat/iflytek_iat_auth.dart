import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 讯飞语音听写鉴权
///
/// 生成WebSocket URL（带HMAC-SHA256签名）
class IFlytekIATAuth {
  final String appId;
  final String apiSecret;
  final String apiKey;
  final String hostUrl;

  const IFlytekIATAuth({
    required this.appId,
    required this.apiSecret,
    required this.apiKey,
    this.hostUrl = 'wss://iat-api.xfyun.cn/v2/iat',
  });

  /// 默认配置
  factory IFlytekIATAuth.defaults() {
    return const IFlytekIATAuth(
      appId: '7adc2cc4',
      apiSecret: 'Mjk1MWUyNjIxNDNiMWEzNTNlMzYxNTlj',
      apiKey: '71f9de1684a741d249dbdda8ebe5d9f1',
    );
  }

  /// 生成WebSocket URL（带鉴权）
  String generateUrl() {
    // 生成RFC1123格式的时间戳
    final now = DateTime.now().toUtc();
    final date = _httpDate(now);

    // 解析host
    final uri = Uri.parse(hostUrl);
    final host = uri.host;
    final path = uri.path;

    // 拼接signature原始字符串
    final signatureOrigin = 'host: $host\n'
        'date: $date\n'
        'GET $path HTTP/1.1';

    // 使用hmac-sha256加密
    final hmac = Hmac(sha256, utf8.encode(apiSecret));
    final signature =
        base64.encode(hmac.convert(utf8.encode(signatureOrigin)).bytes);

    // 拼接authorization
    final authorizationOrigin = 'api_key="$apiKey", '
        'algorithm="hmac-sha256", '
        'headers="host date request-line", '
        'signature="$signature"';
    final authorization = base64.encode(utf8.encode(authorizationOrigin));

    // 构建最终URL
    final url =
        '$hostUrl?authorization=$authorization&date=${Uri.encodeComponent(date)}&host=$host';

    return url;
  }

  /// 将DateTime转为RFC1123格式
  String _httpDate(DateTime date) {
    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final weekDay = weekDays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$weekDay, $day $month $year $hour:$minute:$second GMT';
  }
}
