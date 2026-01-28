import 'environment.dart';

/// API 端点配置
class ApiEndpoints {
  ApiEndpoints._();

  // ============== 后端 API 基础 URL ==============

  /// 生产环境主服务器 API 基础 URL (服务器2 - 主服务器)
  static const String _prodApiBaseUrl = 'https://39.105.12.124/api/v1';

  /// 生产环境备份服务器 API 基础 URL (服务器1 - 备份服务器)
  static const String _prodBackupApiBaseUrl = 'https://160.202.238.29/api/v1';

  /// 预发布环境 API 基础 URL
  static const String _stagingApiBaseUrl = 'https://staging-api.example.com/api/v1';

  /// 开发环境 API 基础 URL
  static const String _devApiBaseUrl = 'http://localhost:8000/api/v1';

  /// 获取当前环境的 API 基础 URL（主服务器）
  /// 优先使用编译时变量，否则根据环境返回默认值
  static String get apiBaseUrl {
    // 编译时变量优先
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // 根据环境返回默认值
    switch (EnvironmentConfig.current) {
      case AppEnvironment.development:
        return _devApiBaseUrl;
      case AppEnvironment.staging:
        return _stagingApiBaseUrl;
      case AppEnvironment.production:
        return _prodApiBaseUrl;
    }
  }

  /// 获取所有可用的服务器 URL（用于多服务器版本检查和容灾）
  /// 返回顺序: [主服务器, 备份服务器]
  static List<String> get allServerUrls {
    switch (EnvironmentConfig.current) {
      case AppEnvironment.development:
        return [_devApiBaseUrl];
      case AppEnvironment.staging:
        return [_stagingApiBaseUrl];
      case AppEnvironment.production:
        // 生产环境返回两个服务器
        return [_prodApiBaseUrl, _prodBackupApiBaseUrl];
    }
  }

  // ============== 阿里云 Qwen API ==============

  /// Qwen 文本生成 API
  static const String qwenTextApi =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation';

  /// Qwen 视觉识别 API（图片识别）
  static const String qwenVisionApi =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

  /// Qwen 音频识别 API
  static const String qwenAudioApi =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

  // ============== 后端 API 路径 ==============

  /// 配置相关
  static const String configAi = '/config/ai';
  static const String configAppSettings = '/config/app-settings';

  /// 认证相关
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authRefreshToken = '/auth/refresh';
  static const String authLogout = '/auth/logout';

  /// 语音 Token
  static const String voiceToken = '/voice/token';

  /// 同步相关
  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';
  static const String syncStatus = '/sync/status';

  /// 备份相关 (RESTful API)
  static const String backup = '/backup';
  static const String backupById = '/backup/{id}';
  static const String backupRestore = '/backup/{id}/restore';

  /// 应用升级
  static const String appVersion = '/app/version';
  static const String appDownload = '/app/download';

  // ============== 辅助方法 ==============

  /// 从完整 URL 提取主机地址
  /// 例如: https://160.202.238.29/api/v1 -> https://160.202.238.29
  static String extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
    } catch (e) {
      return url;
    }
  }

  /// 获取完整 API URL
  static String getFullUrl(String path) {
    final base = apiBaseUrl;
    if (path.startsWith('/')) {
      return '$base$path';
    }
    return '$base/$path';
  }
}
