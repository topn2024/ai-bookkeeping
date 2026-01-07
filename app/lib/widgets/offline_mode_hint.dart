import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 6.11 离线模式提示组件
/// 当设备处于离线状态时显示提示，并提供离线识别选项
class OfflineModeHint extends StatelessWidget {
  final VoidCallback? onUseOffline;
  final VoidCallback? onRetryOnline;
  final VoidCallback? onDismiss;
  final bool showActions;

  const OfflineModeHint({
    super.key,
    this.onUseOffline,
    this.onRetryOnline,
    this.onDismiss,
    this.showActions = true,
  });

  /// 显示离线模式提示对话框
  static Future<bool?> showDialog(
    BuildContext context, {
    VoidCallback? onUseOffline,
    VoidCallback? onRetryOnline,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => OfflineModeDialog(
        onUseOffline: onUseOffline,
        onRetryOnline: onRetryOnline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.offlineMode ?? '离线模式',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.offlineModeDesc ?? '当前网络不可用，可使用离线识别',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetryOnline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(l10n?.retryOnline ?? '重试网络'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onUseOffline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(l10n?.useOffline ?? '离线识别'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 离线模式对话框
class OfflineModeDialog extends StatelessWidget {
  final VoidCallback? onUseOffline;
  final VoidCallback? onRetryOnline;

  const OfflineModeDialog({
    super.key,
    this.onUseOffline,
    this.onRetryOnline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 图标
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.wifi_off,
              size: 40,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 20),

          // 标题
          Text(
            l10n?.networkUnavailable ?? '网络连接不可用',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // 描述
          Text(
            l10n?.offlineModeFullDesc ??
                '当前无法连接到服务器，您可以使用离线语音识别功能继续记账。离线模式下识别准确率可能略有下降。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // 离线功能说明
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  icon: Icons.mic,
                  title: l10n?.offlineVoice ?? '离线语音识别',
                  subtitle: l10n?.offlineVoiceDesc ?? '支持中文语音转文字',
                  isAvailable: true,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  icon: Icons.auto_awesome,
                  title: l10n?.aiParsing ?? 'AI智能解析',
                  subtitle: l10n?.aiParsingOfflineDesc ?? '联网后自动优化',
                  isAvailable: false,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  icon: Icons.sync,
                  title: l10n?.autoSync ?? '自动同步',
                  subtitle: l10n?.autoSyncDesc ?? '恢复网络后自动上传',
                  isAvailable: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, false);
                    onRetryOnline?.call();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n?.retryNetwork ?? '重试网络'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, true);
                    onUseOffline?.call();
                  },
                  icon: const Icon(Icons.wifi_off),
                  label: Text(l10n?.continueOffline ?? '继续离线'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isAvailable,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isAvailable
                ? AppTheme.successColor.withValues(alpha: 0.1)
                : AppTheme.textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isAvailable
                ? AppTheme.successColor
                : AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isAvailable
                      ? AppTheme.textPrimaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Icon(
          isAvailable ? Icons.check_circle : Icons.remove_circle_outline,
          size: 20,
          color:
              isAvailable ? AppTheme.successColor : AppTheme.textSecondaryColor,
        ),
      ],
    );
  }
}

/// 离线模式顶部Banner
class OfflineModeBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const OfflineModeBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppTheme.warningColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.offlineModeActive ?? '离线模式 - 数据将在联网后同步',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
