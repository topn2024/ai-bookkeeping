import 'package:flutter/material.dart';

/// 网络错误页面
/// 原型设计 11.01：网络错误页面
/// - 错误图标
/// - 错误标题和描述
/// - 错误代码
/// - 重新连接按钮
/// - 使用离线模式按钮
/// - 帮助链接
class NetworkErrorPage extends StatelessWidget {
  final String? errorCode;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onOfflineMode;
  final VoidCallback? onHelp;

  const NetworkErrorPage({
    super.key,
    this.errorCode,
    this.errorMessage,
    this.onRetry,
    this.onOfflineMode,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 错误图标
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),

              // 错误标题
              Text(
                '网络连接失败',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // 错误描述
              Text(
                errorMessage ?? '无法连接到服务器，请检查您的网络设置后重试',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 错误代码
              if (errorCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '错误代码: $errorCode',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // 操作按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新连接'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onOfflineMode,
                  icon: const Icon(Icons.wifi_off),
                  label: const Text('使用离线模式'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 帮助链接
              GestureDetector(
                onTap: onHelp,
                child: Text(
                  '查看网络故障排除指南',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 网络错误类型
enum NetworkErrorType {
  noConnection,
  timeout,
  serverError,
  unauthorized,
  unknown,
}

/// 获取错误代码
String getNetworkErrorCode(NetworkErrorType type) {
  switch (type) {
    case NetworkErrorType.noConnection:
      return 'NETWORK_UNAVAILABLE';
    case NetworkErrorType.timeout:
      return 'REQUEST_TIMEOUT';
    case NetworkErrorType.serverError:
      return 'SERVER_ERROR';
    case NetworkErrorType.unauthorized:
      return 'UNAUTHORIZED';
    case NetworkErrorType.unknown:
      return 'UNKNOWN_ERROR';
  }
}

/// 获取错误消息
String getNetworkErrorMessage(NetworkErrorType type) {
  switch (type) {
    case NetworkErrorType.noConnection:
      return '无法连接到服务器，请检查您的网络设置后重试';
    case NetworkErrorType.timeout:
      return '请求超时，服务器响应时间过长';
    case NetworkErrorType.serverError:
      return '服务器出现问题，请稍后重试';
    case NetworkErrorType.unauthorized:
      return '登录已过期，请重新登录';
    case NetworkErrorType.unknown:
      return '发生未知错误，请稍后重试';
  }
}
