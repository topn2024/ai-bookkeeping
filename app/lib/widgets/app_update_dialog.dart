import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/app_upgrade_service.dart';
import '../theme/app_theme.dart';

/// APP 更新对话框
class AppUpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;
  final bool isForceUpdate;
  final String languageCode;

  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.isForceUpdate,
    this.languageCode = 'zh',
  });

  /// 显示更新对话框
  static Future<bool?> show(
    BuildContext context, {
    required VersionInfo versionInfo,
    required bool isForceUpdate,
    String languageCode = 'zh',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !isForceUpdate, // 强制更新不可关闭
      builder: (context) => AppUpdateDialog(
        versionInfo: versionInfo,
        isForceUpdate: isForceUpdate,
        languageCode: languageCode,
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String _statusText = '';
  CancelToken? _cancelToken;
  bool _downloadFailed = false;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForceUpdate && !_downloading,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('发现新版本'),
                  Text(
                    'v${widget.versionInfo.versionName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 强制更新提示
              if (widget.isForceUpdate)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '此版本为必要更新，请更新后继续使用',
                          style:
                              TextStyle(color: Colors.orange[900], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // 更新说明标题
              const Text(
                '更新内容：',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // 更新说明内容
              Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.versionInfo
                        .getLocalizedReleaseNotes(widget.languageCode),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),

              // 文件大小
              if (widget.versionInfo.fileSize != null) ...[
                const SizedBox(height: 12),
                Text(
                  '安装包大小：${widget.versionInfo.formattedFileSize}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              // 下载进度
              if (_downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText.isNotEmpty
                      ? _statusText
                      : '下载中... ${(_progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              // 下载失败提示
              if (_downloadFailed) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '下载失败，请尝试浏览器下载',
                          style: TextStyle(color: Colors.red[900], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: _buildActions(),
      ),
    );
  }

  List<Widget> _buildActions() {
    final actions = <Widget>[];

    // 稍后更新按钮（非强制更新时显示）
    if (!widget.isForceUpdate && !_downloading) {
      actions.add(
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后更新'),
        ),
      );
    }

    // 取消下载按钮
    if (_downloading) {
      actions.add(
        TextButton(
          onPressed: _cancelDownload,
          child: const Text('取消下载'),
        ),
      );
    }

    // 浏览器下载按钮（下载失败时显示）
    if (_downloadFailed && widget.versionInfo.downloadUrl != null) {
      actions.add(
        TextButton(
          onPressed: _openInBrowser,
          child: const Text('浏览器下载'),
        ),
      );
    }

    // 立即更新按钮
    if (!_downloading) {
      actions.add(
        ElevatedButton(
          onPressed: _downloadFailed ? _retryDownload : _startDownload,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(_downloadFailed ? '重试下载' : '立即更新'),
        ),
      );
    }

    return actions;
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    setState(() {
      _downloading = false;
      _progress = 0;
      _statusText = '';
    });
  }

  void _retryDownload() {
    setState(() {
      _downloadFailed = false;
    });
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _statusText = '准备下载...';
      _downloadFailed = false;
    });

    _cancelToken = CancelToken();

    final filePath = await AppUpgradeService().downloadApk(
      widget.versionInfo,
      onProgress: (received, total) {
        if (total > 0 && mounted) {
          setState(() {
            _progress = received / total;
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
            _statusText = '下载中... $receivedMB / $totalMB MB';
          });
        }
      },
      cancelToken: _cancelToken,
    );

    if (!mounted) return;

    if (filePath != null) {
      // 下载完成，开始安装
      setState(() {
        _statusText = '正在安装...';
      });

      final installed = await AppUpgradeService().installApk(filePath);

      if (mounted) {
        if (installed) {
          Navigator.of(context).pop(true);
        } else {
          // 安装失败，提供浏览器下载选项
          setState(() {
            _downloading = false;
            _downloadFailed = true;
            _statusText = '';
          });
        }
      }
    } else {
      // 下载失败
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadFailed = true;
          _statusText = '';
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (widget.versionInfo.downloadUrl != null) {
      final success =
          await AppUpgradeService().openInBrowser(widget.versionInfo.downloadUrl!);
      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }
}
