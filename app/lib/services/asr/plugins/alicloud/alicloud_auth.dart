import 'package:flutter/foundation.dart';

import '../../core/asr_exception.dart';
import '../../../voice_token_service.dart';

/// 阿里云ASR鉴权
///
/// 通过VoiceTokenService获取Token
class AliCloudAuth {
  final VoiceTokenService _tokenService;

  /// 缓存的Token信息
  VoiceTokenInfo? _cachedToken;

  AliCloudAuth({VoiceTokenService? tokenService})
      : _tokenService = tokenService ?? VoiceTokenService();

  /// 获取Token信息
  Future<VoiceTokenInfo> getTokenInfo() async {
    try {
      // 检查缓存
      if (_cachedToken != null && !_cachedToken!.isExpiringSoon) {
        return _cachedToken!;
      }

      debugPrint('[AliCloudAuth] 正在获取Token...');
      final tokenInfo = await _tokenService.getToken();
      _cachedToken = tokenInfo;
      debugPrint(
          '[AliCloudAuth] Token获取成功: appKey=${tokenInfo.appKey}, expires=${tokenInfo.expiresAt}');

      return tokenInfo;
    } on VoiceTokenException catch (e) {
      debugPrint('[AliCloudAuth] Token获取失败: ${e.message}');
      throw ASRException(
        'Token获取失败: ${e.message}',
        errorCode: ASRErrorCode.tokenFailed,
      );
    }
  }

  /// 构建REST API URL
  Future<Uri> buildRestUrl() async {
    final tokenInfo = await getTokenInfo();

    return Uri.parse(tokenInfo.asrRestUrl).replace(
      queryParameters: {
        'appkey': tokenInfo.appKey,
        'format': 'pcm',
        'sample_rate': '16000',
        'enable_punctuation_prediction': 'true',
        'enable_inverse_text_normalization': 'true',
      },
    );
  }

  /// 构建WebSocket URL
  Future<Uri> buildWebSocketUrl() async {
    final tokenInfo = await getTokenInfo();

    // Android 平台的 WebSocket 不支持自定义 headers，
    // 因此将 token 作为查询参数传递
    return Uri.parse(tokenInfo.asrUrl).replace(
      queryParameters: {
        'appkey': tokenInfo.appKey,
        'token': tokenInfo.token,
      },
    );
  }

  /// 获取当前Token
  Future<String> getToken() async {
    final tokenInfo = await getTokenInfo();
    return tokenInfo.token;
  }

  /// 获取AppKey
  Future<String> getAppKey() async {
    final tokenInfo = await getTokenInfo();
    return tokenInfo.appKey;
  }

  /// 清除缓存
  void clearCache() {
    _cachedToken = null;
  }

  /// 强制刷新Token
  Future<VoiceTokenInfo> refreshToken() async {
    clearCache();
    return await _tokenService.refreshToken();
  }
}
