/// ASR异常模块
///
/// 定义ASR服务的统一错误码和异常类

/// ASR错误码
enum ASRErrorCode {
  /// 未知错误
  unknown,

  /// 连接超时
  connectionTimeout,

  /// 发送超时
  sendTimeout,

  /// 接收超时
  receiveTimeout,

  /// 限流
  rateLimited,

  /// 未授权
  unauthorized,

  /// 服务器错误
  serverError,

  /// 无网络连接
  noConnection,

  /// Token获取失败
  tokenFailed,

  /// 识别超时
  recognitionTimeout,

  /// 音频格式错误
  audioFormatError,

  /// 插件未初始化
  notInitialized,

  /// 插件已释放
  disposed,

  /// 无可用插件
  noAvailablePlugin,

  /// 用户取消
  cancelled,

  /// 音频数据无效
  invalidAudioData,

  /// 配置错误
  configurationError,
}

/// ASR异常
class ASRException implements Exception {
  final String message;
  final ASRErrorCode errorCode;
  final Object? cause;
  final StackTrace? stackTrace;

  ASRException(
    this.message, {
    this.errorCode = ASRErrorCode.unknown,
    this.cause,
    this.stackTrace,
  });

  /// 是否可以重试
  bool get isRetryable {
    switch (errorCode) {
      case ASRErrorCode.connectionTimeout:
      case ASRErrorCode.sendTimeout:
      case ASRErrorCode.receiveTimeout:
      case ASRErrorCode.serverError:
      case ASRErrorCode.noConnection:
        return true;
      default:
        return false;
    }
  }

  /// 是否应该降级到其他插件
  bool get shouldFallback {
    switch (errorCode) {
      case ASRErrorCode.connectionTimeout:
      case ASRErrorCode.sendTimeout:
      case ASRErrorCode.receiveTimeout:
      case ASRErrorCode.serverError:
      case ASRErrorCode.noConnection:
      case ASRErrorCode.tokenFailed:
      case ASRErrorCode.rateLimited:
        return true;
      default:
        return false;
    }
  }

  /// 用户友好的错误提示
  String get userFriendlyMessage {
    switch (errorCode) {
      case ASRErrorCode.connectionTimeout:
      case ASRErrorCode.sendTimeout:
      case ASRErrorCode.receiveTimeout:
        return '网络超时，请检查网络连接后重试';
      case ASRErrorCode.rateLimited:
        return '请求过于频繁，请稍后再试';
      case ASRErrorCode.unauthorized:
        return '登录已过期，请重新登录';
      case ASRErrorCode.serverError:
        return '服务暂时不可用，请稍后再试';
      case ASRErrorCode.noConnection:
        return '无网络连接，请检查网络设置';
      case ASRErrorCode.tokenFailed:
        return '认证失败，请重新登录';
      case ASRErrorCode.recognitionTimeout:
        return '识别超时，请缩短语音时长';
      case ASRErrorCode.audioFormatError:
        return '音频格式错误，请重新录制';
      case ASRErrorCode.notInitialized:
        return '语音服务未初始化';
      case ASRErrorCode.disposed:
        return '语音服务已关闭';
      case ASRErrorCode.noAvailablePlugin:
        return '没有可用的语音识别服务';
      case ASRErrorCode.cancelled:
        return '识别已取消';
      case ASRErrorCode.invalidAudioData:
        return '音频数据无效';
      case ASRErrorCode.configurationError:
        return '配置错误';
      default:
        return message;
    }
  }

  @override
  String toString() => 'ASRException[$errorCode]: $message';
}
