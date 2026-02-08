import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget for viewing original source image from image recognition.
///
/// Features:
/// - Full screen image view with zoom support
/// - Displays file metadata (size, capture time)
/// - Shows expiry status
class SourceImageViewer extends StatefulWidget {
  final String imagePath;
  final DateTime? expiresAt;
  final int? fileSize;
  final VoidCallback? onClose;

  const SourceImageViewer({
    super.key,
    required this.imagePath,
    this.expiresAt,
    this.fileSize,
    this.onClose,
  });

  /// Show the image viewer as a full screen dialog
  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    DateTime? expiresAt,
    int? fileSize,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => SourceImageViewer(
          imagePath: imagePath,
          expiresAt: expiresAt,
          fileSize: fileSize,
        ),
      ),
    );
  }

  @override
  State<SourceImageViewer> createState() => _SourceImageViewerState();
}

class _SourceImageViewerState extends State<SourceImageViewer> {
  bool _fileExists = false;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  Future<void> _checkFileExists() async {
    final file = File(widget.imagePath);
    final exists = await file.exists();
    if (mounted) {
      setState(() {
        _fileExists = exists;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('原始图片'),
        actions: [
          if (widget.fileSize != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _formatFileSize(widget.fileSize!),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Image view
          Expanded(
            child: _fileExists
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildErrorWidget('无法加载图片');
                        },
                      ),
                    ),
                  )
                : _buildErrorWidget('图片文件不存在'),
          ),
          // Bottom info bar
          if (widget.expiresAt != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isExpired() ? Icons.warning_amber : Icons.access_time,
                    color: _isExpired() ? AppColors.expense : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getExpiryText(),
                    style: TextStyle(
                      color: _isExpired() ? AppColors.expense : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  bool _isExpired() {
    if (widget.expiresAt == null) return false;
    return DateTime.now().isAfter(widget.expiresAt!);
  }

  String _getExpiryText() {
    if (widget.expiresAt == null) return '';
    if (_isExpired()) {
      return '已过期';
    }
    final remaining = widget.expiresAt!.difference(DateTime.now());
    if (remaining.inDays > 0) {
      return '${remaining.inDays}天后过期';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}小时后过期';
    } else {
      return '即将过期';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Thumbnail widget for showing image preview in transaction list
class SourceImageThumbnail extends StatefulWidget {
  final String imagePath;
  final double size;
  final VoidCallback? onTap;
  final bool showExpiredOverlay;
  final DateTime? expiresAt;

  const SourceImageThumbnail({
    super.key,
    required this.imagePath,
    this.size = 48,
    this.onTap,
    this.showExpiredOverlay = true,
    this.expiresAt,
  });

  @override
  State<SourceImageThumbnail> createState() => _SourceImageThumbnailState();
}

class _SourceImageThumbnailState extends State<SourceImageThumbnail> {
  bool _fileExists = false;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  Future<void> _checkFileExists() async {
    final file = File(widget.imagePath);
    final exists = await file.exists();
    if (mounted) {
      setState(() {
        _fileExists = exists;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    final isExpired = widget.expiresAt != null && DateTime.now().isAfter(widget.expiresAt!);

    return GestureDetector(
      onTap: _fileExists && !isExpired ? widget.onTap : null,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_fileExists)
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(Icons.broken_image);
                },
              )
            else
              _buildPlaceholder(Icons.image_not_supported),
            // Expired overlay
            if (widget.showExpiredOverlay && isExpired)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Icon(
                    Icons.access_time,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            // Tap indicator
            if (_fileExists && !isExpired)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(IconData icon) {
    return Center(
      child: Icon(
        icon,
        color: Colors.grey[400],
        size: widget.size * 0.5,
      ),
    );
  }
}
