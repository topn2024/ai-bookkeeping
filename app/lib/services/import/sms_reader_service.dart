import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart' as tel;
import '../../models/sms_message.dart';
import 'import_exceptions.dart';

/// SMS读取服务
/// 负责权限管理和短信读取
class SmsReaderService {
  final tel.Telephony _telephony = tel.Telephony.instance;

  /// 检查短信读取权限
  Future<bool> checkPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// 申请短信读取权限
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// 读取短信
  ///
  /// [startDate] 开始时间
  /// [endDate] 结束时间
  /// [senderFilter] 发件人过滤列表（可选）
  /// [onProgress] 进度回调
  Future<List<SmsMessage>> readSms({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? senderFilter,
    Function(int current, int total)? onProgress,
  }) async {
    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw PermissionException('未授予短信读取权限');
    }

    try {
      // 读取所有短信
      final messages = await _telephony.getInboxSms(
        columns: [tel.SmsColumn.ID, tel.SmsColumn.ADDRESS, tel.SmsColumn.BODY, tel.SmsColumn.DATE],
        sortOrder: [tel.OrderBy(tel.SmsColumn.DATE, sort: tel.Sort.DESC)],
      );

      // 过滤时间范围和发件人
      final filteredMessages = <SmsMessage>[];
      final startTimestamp = startDate.millisecondsSinceEpoch;
      final endTimestamp = endDate.millisecondsSinceEpoch;

      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        final timestamp = msg.date ?? 0;

        // 时间范围过滤
        if (timestamp < startTimestamp || timestamp > endTimestamp) {
          continue;
        }

        // 发件人过滤
        if (senderFilter != null && senderFilter.isNotEmpty) {
          final address = msg.address ?? '';
          bool matchesSender = false;
          for (final sender in senderFilter) {
            if (address.contains(sender)) {
              matchesSender = true;
              break;
            }
          }
          if (!matchesSender) {
            continue;
          }
        }

        // 转换为SmsMessage
        filteredMessages.add(SmsMessage(
          id: msg.id?.toString() ?? '',
          address: msg.address ?? '',
          body: msg.body ?? '',
          date: DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0),
        ));

        // 进度回调
        if (onProgress != null && i % 100 == 0) {
          onProgress(i, messages.length);
        }
      }

      // 最终进度回调
      onProgress?.call(messages.length, messages.length);

      return filteredMessages;
    } catch (e) {
      if (e is PermissionException) {
        rethrow;
      }
      throw SmsReadException('读取短信失败: $e');
    }
  }

  /// 获取常见支付平台发件人列表
  List<String> getPaymentSenders() {
    return [
      // 银行
      '95588', // 工商银行
      '95599', // 农业银行
      '95533', // 建设银行
      '95566', // 中国银行
      '95555', // 招商银行
      '95558', // 中信银行
      '95595', // 光大银行
      '95559', // 交通银行
      '95568', // 民生银行
      '95501', // 浦发银行
      '95561', // 兴业银行
      '95577', // 华夏银行
      '95508', // 广发银行
      '95511', // 平安银行
      '95526', // 渤海银行
      '95527', // 浙商银行
      '95528', // 邮储银行

      // 支付平台
      '支付宝',
      'Alipay',
      '微信支付',
      'WeChat',
      'WeChatPay',
      '财付通',

      // 其他金融平台
      '京东金融',
      '美团',
      '拼多多',
      '云闪付',
    ];
  }
}
