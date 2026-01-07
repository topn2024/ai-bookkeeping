import 'package:flutter/material.dart';

/// 重试状态提示组件
/// 原型设计 11.06：重试状态提示
/// - 自动重试 SnackBar
/// - 加载动画
/// - 重试次数
/// - 取消按钮
class RetryStatusWidget extends StatelessWidget {
  final int currentAttempt;
  final int maxAttempts;
  final String message;
  final VoidCallback? onCancel;

  const RetryStatusWidget({
    super.key,
    required this.currentAttempt,
    required this.maxAttempts,
    this.message = '网络连接不稳定',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF323232),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 加载动画
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // 文字信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '正在重试... ($currentAttempt/$maxAttempts)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // 取消按钮
          if (onCancel != null)
            GestureDetector(
              onTap: onCancel,
              child: Text(
                '取消',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 显示重试状态的 SnackBar
void showRetrySnackBar(
  BuildContext context, {
  required int currentAttempt,
  required int maxAttempts,
  String message = '网络连接不稳定',
  VoidCallback? onCancel,
  Duration duration = const Duration(seconds: 10),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: RetryStatusWidget(
        currentAttempt: currentAttempt,
        maxAttempts: maxAttempts,
        message: message,
        onCancel: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          onCancel?.call();
        },
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.zero,
    ),
  );
}

/// 加载状态横幅
class LoadingBanner extends StatelessWidget {
  final String message;
  final bool showProgress;
  final double? progress;

  const LoadingBanner({
    super.key,
    required this.message,
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFE3F2FD),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }
}

/// 同步状态指示器
class SyncStatusIndicator extends StatelessWidget {
  final SyncStatus status;
  final int? pendingCount;
  final VoidCallback? onTap;

  const SyncStatusIndicator({
    super.key,
    required this.status,
    this.pendingCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;
    String text;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = const Color(0xFF4CAF50);
        text = '已同步';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = theme.colorScheme.primary;
        text = '同步中...';
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_upload;
        color = const Color(0xFFFFB74D);
        text = pendingCount != null ? '$pendingCount 待同步' : '待同步';
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = theme.colorScheme.error;
        text = '同步失败';
        break;
      case SyncStatus.offline:
        icon = Icons.wifi_off;
        color = theme.colorScheme.onSurfaceVariant;
        text = '离线';
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == SyncStatus.syncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 同步状态
enum SyncStatus {
  synced,   // 已同步
  syncing,  // 同步中
  pending,  // 待同步
  error,    // 同步失败
  offline,  // 离线
}

/// 网络状态横幅
class NetworkStatusBanner extends StatelessWidget {
  final bool isOnline;
  final VoidCallback? onRetry;

  const NetworkStatusBanner({
    super.key,
    required this.isOnline,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFEF3C7),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '网络连接已断开',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                '重试',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
