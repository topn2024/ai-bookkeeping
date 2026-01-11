import 'package:flutter/material.dart';

/// 确认对话框配置
class ConfirmationDialogConfig {
  /// 标题
  final String title;

  /// 消息内容
  final String message;

  /// 确认按钮文本
  final String confirmText;

  /// 取消按钮文本
  final String cancelText;

  /// 是否是危险操作
  final bool isDangerous;

  /// 图标（可选）
  final IconData? icon;

  /// 确认按钮颜色（可选）
  final Color? confirmColor;

  /// 是否显示取消按钮
  final bool showCancel;

  /// 是否可以点击外部关闭
  final bool barrierDismissible;

  const ConfirmationDialogConfig({
    required this.title,
    required this.message,
    this.confirmText = '确认',
    this.cancelText = '取消',
    this.isDangerous = false,
    this.icon,
    this.confirmColor,
    this.showCancel = true,
    this.barrierDismissible = true,
  });

  /// 创建危险操作配置
  factory ConfirmationDialogConfig.dangerous({
    required String title,
    required String message,
    String confirmText = '删除',
    String cancelText = '取消',
    IconData icon = Icons.warning_amber_rounded,
  }) {
    return ConfirmationDialogConfig(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDangerous: true,
      icon: icon,
      showCancel: true,
      barrierDismissible: true,
    );
  }

  /// 创建信息提示配置
  factory ConfirmationDialogConfig.info({
    required String title,
    required String message,
    String confirmText = '知道了',
    IconData icon = Icons.info_outline,
  }) {
    return ConfirmationDialogConfig(
      title: title,
      message: message,
      confirmText: confirmText,
      isDangerous: false,
      icon: icon,
      showCancel: false,
      barrierDismissible: true,
    );
  }
}

/// 统一确认对话框组件
///
/// 支持多种确认场景，包括：
/// - 基础确认对话框
/// - 危险操作对话框（删除等）
/// - 带自定义内容的对话框
///
/// 使用方式：
/// ```dart
/// // 基础确认
/// final result = await ConfirmationDialog.show(
///   context,
///   title: '确认',
///   message: '您确定要执行此操作吗？',
/// );
///
/// // 危险操作
/// final result = await ConfirmationDialog.showDangerous(
///   context,
///   title: '删除记录',
///   message: '此操作不可恢复，确定要删除吗？',
/// );
/// ```
class ConfirmationDialog extends StatelessWidget {
  final ConfirmationDialogConfig config;
  final Widget? content;

  const ConfirmationDialog({
    super.key,
    required this.config,
    this.content,
  });

  /// 显示基础确认对话框
  ///
  /// 返回 true 表示确认，false 或 null 表示取消
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ConfirmationDialog(
        config: ConfirmationDialogConfig(
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          icon: icon,
          barrierDismissible: barrierDismissible,
        ),
      ),
    );
  }

  /// 显示危险操作对话框
  ///
  /// 确认按钮显示为红色，带警告图标
  static Future<bool?> showDangerous(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '删除',
    String cancelText = '取消',
    IconData icon = Icons.warning_amber_rounded,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConfirmationDialog(
        config: ConfirmationDialogConfig.dangerous(
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          icon: icon,
        ),
      ),
    );
  }

  /// 显示带自定义内容的对话框
  ///
  /// 可以在对话框中央显示自定义 Widget，
  /// 确认后返回泛型结果
  static Future<T?> showWithContent<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDangerous = false,
    T? Function()? onConfirm,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ContentConfirmationDialog<T>(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDangerous: isDangerous,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            if (config.icon != null) ...[
              _buildIcon(context),
              const SizedBox(height: 16),
            ],

            // 标题
            Text(
              config.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // 消息
            Text(
              config.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // 自定义内容
            if (content != null) ...[
              const SizedBox(height: 16),
              content!,
            ],

            const SizedBox(height: 24),

            // 按钮
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final theme = Theme.of(context);

    final iconColor = config.isDangerous
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    final backgroundColor = config.isDangerous
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        config.icon,
        size: 28,
        color: iconColor,
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    final theme = Theme.of(context);

    if (!config.showCancel) {
      // 单按钮布局
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(config.confirmText),
        ),
      );
    }

    // 双按钮布局
    return Row(
      children: [
        // 取消按钮
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(config.cancelText),
          ),
        ),
        const SizedBox(width: 12),
        // 确认按钮
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: config.isDangerous
                  ? theme.colorScheme.error
                  : (config.confirmColor ?? theme.colorScheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              config.confirmText,
              style: TextStyle(
                color: config.isDangerous
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 带自定义内容的确认对话框（内部类）
class _ContentConfirmationDialog<T> extends StatelessWidget {
  final String title;
  final Widget content;
  final String confirmText;
  final String cancelText;
  final bool isDangerous;
  final T? Function()? onConfirm;

  const _ContentConfirmationDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    required this.cancelText,
    required this.isDangerous,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 自定义内容
            content,

            const SizedBox(height: 24),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final result = onConfirm?.call();
                      Navigator.pop(context, result);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: isDangerous
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        color: isDangerous
                            ? theme.colorScheme.onError
                            : theme.colorScheme.onPrimary,
                      ),
                    ),
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
