import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// 讯飞实时语音转写大模型连通性测试
void main() async {
  print('开始测试讯飞实时语音转写大模型连通性...\n');

  // 讯飞配置
  const appId = '7adc2cc4';
  const apiSecret = 'Mjk1MWUyNjIxNDNiMWEzNTNlMzYxNTlj';
  const apiKey = '71f9de1684a741d249dbdda8ebe5d9f1';
  const hostUrl = 'wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1';

  try {
    // 1. 生成鉴权URL
    print('1. 生成WebSocket URL...');
    final url = generateUrl(appId, apiSecret, apiKey, hostUrl);
    print('   URL: ${url.substring(0, 120)}...\n');

    // 2. 连接WebSocket
    print('2. 连接WebSocket...');
    final ws = await WebSocket.connect(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('连接超时');
      },
    );
    print('   WebSocket连接成功!\n');

    // 3. 监听消息
    print('3. 监听服务器响应...');
    final completer = Completer<void>();
    int messageCount = 0;

    ws.listen(
      (message) {
        messageCount++;
        print('   收到消息 #$messageCount: $message');

        // 尝试解析JSON
        try {
          final data = jsonDecode(message as String);
          print('   解析后: ${jsonEncode(data)}');
        } catch (e) {
          print('   (非JSON消息)');
        }

        if (!completer.isCompleted && messageCount >= 1) {
          // 收到第一条消息后继续测试
        }
      },
      onError: (error) {
        print('   WebSocket错误: $error');
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        print('   WebSocket关闭');
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    // 4. 发送测试音频帧（二进制格式）
    print('\n4. 发送测试音频帧...');

    // 生成40ms的静音音频（16kHz, 16bit PCM = 1280字节）
    final silentAudio = Uint8List(1280);

    // 发送几帧静音音频
    for (int i = 0; i < 5; i++) {
      ws.add(silentAudio);
      print('   发送音频帧 #${i + 1}: ${silentAudio.length} bytes');
      await Future.delayed(const Duration(milliseconds: 40));
    }

    // 5. 发送结束标记
    print('\n5. 发送结束标记...');
    final endMsg = jsonEncode({'end': true});
    ws.add(endMsg);
    print('   发送: $endMsg');

    // 等待服务器响应
    print('\n6. 等待服务器响应...');
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('   等待响应超时（这是正常的，因为发送的是静音）');
      },
    );

    // 关闭连接
    await ws.close();
    print('\n测试完成!');
    exit(0);
  } catch (e, stack) {
    print('\n测试失败: $e');
    print('堆栈: $stack');
    exit(1);
  }
}

/// 生成WebSocket URL（带鉴权）
/// 关键：签名原文中的key和value都需要URL编码
String generateUrl(String appId, String apiSecret, String apiKey, String hostUrl) {
  // 生成UUID（无横线的hex格式）
  final uuid = const Uuid().v4().replaceAll('-', '');

  // 生成UTC时间戳（格式：2025-09-04T15:38:07+0800）
  final now = DateTime.now();
  final utc = formatUtcTime(now);

  // 构建签名参数
  final params = {
    'accessKeyId': apiKey,
    'appId': appId,
    'audio_encode': 'pcm_s16le',
    'lang': 'autodialect',
    'samplerate': '16000',
    'utc': utc,
    'uuid': uuid,
  };

  // 按key排序，并对key和value都进行URL编码
  final sortedKeys = params.keys.toList()..sort();
  final signatureOrigin = sortedKeys
      .map((k) => '${Uri.encodeComponent(k)}=${Uri.encodeComponent(params[k]!)}')
      .join('&');

  print('   签名原文: $signatureOrigin');

  // 使用HMAC-SHA1签名
  final hmac = Hmac(sha1, utf8.encode(apiSecret));
  final signature = base64.encode(hmac.convert(utf8.encode(signatureOrigin)).bytes);

  print('   签名结果: $signature');

  // 构建最终URL
  final queryParams = {
    ...params,
    'signature': signature,
  };

  // 使用Uri类构建URL
  final uri = Uri.parse(hostUrl).replace(queryParameters: queryParams);

  return uri.toString();
}

/// 格式化UTC时间（格式：2025-09-04T15:38:07+0800）
String formatUtcTime(DateTime date) {
  final year = date.year;
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final second = date.second.toString().padLeft(2, '0');

  // 计算时区偏移
  final offset = date.timeZoneOffset;
  final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
  final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final offsetSign = offset.isNegative ? '-' : '+';

  return '$year-$month-${day}T$hour:$minute:$second$offsetSign$offsetHours$offsetMinutes';
}
