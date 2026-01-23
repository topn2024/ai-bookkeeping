import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 阿里云NLS Token服务
///
/// 使用AccessKey自动获取和刷新NLS Token
class AliyunNLSTokenService {
  static final AliyunNLSTokenService _instance =
      AliyunNLSTokenService._internal();
  factory AliyunNLSTokenService() => _instance;
  AliyunNLSTokenService._internal();

  final Dio _dio = Dio();

  String? _cachedToken;
  DateTime? _tokenExpireTime;

  /// 获取NLS Token
  ///
  /// 如果缓存的Token有效则返回缓存，否则重新获取
  Future<String> getToken({
    required String accessKeyId,
    required String accessKeySecret,
  }) async {
    // 检查缓存是否有效（提前5分钟过期）
    if (_cachedToken != null &&
        _tokenExpireTime != null &&
        DateTime.now().isBefore(_tokenExpireTime!.subtract(const Duration(minutes: 5)))) {
      debugPrint('[AliyunNLSToken] 使用缓存Token');
      return _cachedToken!;
    }

    // 获取新Token
    return await _fetchNewToken(accessKeyId, accessKeySecret);
  }

  /// 从阿里云获取新Token
  Future<String> _fetchNewToken(
    String accessKeyId,
    String accessKeySecret,
  ) async {
    debugPrint('[AliyunNLSToken] 正在获取新Token...');

    try {
      // 构建请求参数
      final timestamp = _formatTimestamp(DateTime.now().toUtc());
      final nonce = _generateNonce();

      final params = {
        'AccessKeyId': accessKeyId,
        'Action': 'CreateToken',
        'Format': 'JSON',
        'RegionId': 'cn-shanghai',
        'SignatureMethod': 'HMAC-SHA1',
        'SignatureNonce': nonce,
        'SignatureVersion': '1.0',
        'Timestamp': timestamp,
        'Version': '2019-02-28',
      };

      // 计算签名
      final signature = _calculateSignature(params, accessKeySecret);
      params['Signature'] = signature;

      // 发送请求
      final response = await _dio.get(
        'https://nls-meta.cn-shanghai.aliyuncs.com/',
        queryParameters: params,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['Token'] != null) {
          _cachedToken = data['Token']['Id'];
          final expireTime = data['Token']['ExpireTime'] as int;
          _tokenExpireTime =
              DateTime.fromMillisecondsSinceEpoch(expireTime * 1000);

          debugPrint('[AliyunNLSToken] Token获取成功，过期时间: $_tokenExpireTime');
          return _cachedToken!;
        } else {
          throw Exception('响应中没有Token: $data');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      debugPrint('[AliyunNLSToken] 获取Token失败: $e');
      rethrow;
    }
  }

  /// 格式化时间戳 (ISO8601 UTC)
  String _formatTimestamp(DateTime time) {
    return time.toIso8601String().replaceAll(RegExp(r'\.\d+'), '') + 'Z';
  }

  /// 生成随机数
  String _generateNonce() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 计算签名
  String _calculateSignature(
      Map<String, String> params, String accessKeySecret) {
    // 1. 按参数名排序
    final sortedKeys = params.keys.toList()..sort();

    // 2. 构建规范化查询字符串
    final canonicalizedQueryString = sortedKeys
        .map((key) => '${_percentEncode(key)}=${_percentEncode(params[key]!)}')
        .join('&');

    // 3. 构建待签名字符串
    final stringToSign =
        'GET&${_percentEncode('/')}&${_percentEncode(canonicalizedQueryString)}';

    // 4. 计算HMAC-SHA1签名
    final key = utf8.encode('$accessKeySecret&');
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(utf8.encode(stringToSign));

    return base64Encode(digest.bytes);
  }

  /// URL编码（阿里云要求的特殊编码规则）
  String _percentEncode(String value) {
    return Uri.encodeComponent(value)
        .replaceAll('+', '%20')
        .replaceAll('*', '%2A')
        .replaceAll('%7E', '~');
  }

  /// 清除缓存
  void clearCache() {
    _cachedToken = null;
    _tokenExpireTime = null;
    debugPrint('[AliyunNLSToken] 缓存已清除');
  }
}
