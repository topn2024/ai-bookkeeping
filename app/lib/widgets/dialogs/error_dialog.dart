import 'package:flutter/material.dart';

/// 错误对话框
/// 原型设计 11.05：错误对话框
/// - 错误图标
/// - 错误标题
/// - 错误信息
/// - 错误代码
/// - 操作按钮（取消、重试）
/// - 详细信息链接
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? errorCode;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onShowDetails;

  const ErrorDialog({
    super.key,
    this.title = '操作失败',
    required this.message,
    this.errorCode,
    this.onRetry,
    this.onCancel,
    this.onShowDetails,
  });

  /// 显示错误对话框
  static Future<bool?> show(
    BuildContext context, {
    String title = '操作失败',
    required String message,
    String? errorCode,
    VoidCallback? onShowDetails,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        errorCode: errorCode,
        onRetry: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
        onShowDetails: onShowDetails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 错误图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 36,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // 错误信息
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // 错误代码
            if (errorCode != null)
              Text(
                '错误代码: $errorCode',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 20),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('重试'),
                  ),
                ),
              ],
            ),

            // 详细信息链接
            if (onShowDetails != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onShowDetails,
                child: Text(
                  '查看详细错误信息',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 成功对话框
class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onConfirm;

  const SuccessDialog({
    super.key,
    this.title = '操作成功',
    required this.message,
    this.onConfirm,
  });

  /// 显示成功对话框
  static Future<void> show(
    BuildContext context, {
    String title = '操作成功',
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SuccessDialog(
        title: title,
        message: message,
        onConfirm: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 成功图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 36,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // 消息
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // 确认按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 警告对话框
class WarningDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const WarningDialog({
    super.key,
    this.title = '警告',
    required this.message,
    this.confirmText = '确定',
    this.cancelText = '取消',
    this.onConfirm,
    this.onCancel,
  });

  /// 显示警告对话框
  static Future<bool?> show(
    BuildContext context, {
    String title = '警告',
    required String message,
    String confirmText = '确定',
    String cancelText = '取消',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => WarningDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 警告图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber,
                size: 36,
                color: Color(0xFFFFB74D),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // 消息
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB74D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
