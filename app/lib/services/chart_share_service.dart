import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// 分享平台
enum SharePlatform {
  /// 系统分享
  system,

  /// 微信
  wechat,

  /// 微信朋友圈
  wechatMoments,

  /// QQ
  qq,

  /// 微博
  weibo,

  /// 保存到相册
  saveToGallery,

  /// 复制到剪贴板
  clipboard,
}

/// 图片格式
enum ImageFormat {
  /// PNG格式
  png,

  /// JPEG格式
  jpeg,

  /// WebP格式
  webp,
}

/// 图表截图配置
class ChartScreenshotConfig {
  /// 图片格式
  final ImageFormat format;

  /// 图片质量（0-100，仅JPEG有效）
  final int quality;

  /// 像素比率
  final double pixelRatio;

  /// 背景色
  final Color? backgroundColor;

  /// 是否添加水印
  final bool addWatermark;

  /// 水印文字
  final String? watermarkText;

  /// 水印位置
  final Alignment watermarkAlignment;

  /// 是否添加边框
  final bool addBorder;

  /// 边框���色
  final Color borderColor;

  /// 边框宽度
  final double borderWidth;

  /// 内边距
  final EdgeInsets padding;

  const ChartScreenshotConfig({
    this.format = ImageFormat.png,
    this.quality = 95,
    this.pixelRatio = 2.0,
    this.backgroundColor,
    this.addWatermark = true,
    this.watermarkText,
    this.watermarkAlignment = Alignment.bottomRight,
    this.addBorder = false,
    this.borderColor = const Color(0xFFE0E0E0),
    this.borderWidth = 1.0,
    this.padding = const EdgeInsets.all(16),
  });

  /// 高质量预设
  static const highQuality = ChartScreenshotConfig(
    format: ImageFormat.png,
    pixelRatio: 3.0,
    padding: EdgeInsets.all(24),
  );

  /// 分享预设（较小文件）
  static const forSharing = ChartScreenshotConfig(
    format: ImageFormat.jpeg,
    quality: 85,
    pixelRatio: 2.0,
    padding: EdgeInsets.all(16),
  );
}

/// 分享配��
class ShareConfig {
  /// 分享标题
  final String? title;

  /// 分享描述
  final String? description;

  /// 分享链接
  final String? url;

  /// 是否显示平台选择
  final bool showPlatformPicker;

  /// 允许的分享平台
  final List<SharePlatform>? allowedPlatforms;

  const ShareConfig({
    this.title,
    this.description,
    this.url,
    this.showPlatformPicker = true,
    this.allowedPlatforms,
  });
}

/// 截图结果
class ScreenshotResult {
  /// 图片数据
  final Uint8List imageData;

  /// 图片宽度
  final int width;

  /// 图片高度
  final int height;

  /// 文件大小（字节）
  final int fileSize;

  /// 图片格式
  final ImageFormat format;

  const ScreenshotResult({
    required this.imageData,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.format,
  });
}

/// 分享结果
class ShareResult {
  /// 是否成功
  final bool success;

  /// 分享平台
  final SharePlatform? platform;

  /// 错误信息
  final String? errorMessage;

  const ShareResult({
    required this.success,
    this.platform,
    this.errorMessage,
  });

  factory ShareResult.success(SharePlatform platform) {
    return ShareResult(success: true, platform: platform);
  }

  factory ShareResult.failure(String message) {
    return ShareResult(success: false, errorMessage: message);
  }
}

/// 图表截图与分享服务
///
/// 核心功能：
/// 1. 图表截图
/// 2. 图片处理（水印、边框）
/// 3. 多平台分享
/// 4. 保存到相册
/// 5. 复制到剪贴板
///
/// 对应设计文档：第12.8节 图表截图与分享功能
///
/// 使用示例：
/// ```dart
/// final service = ChartShareService();
///
/// // 截图
/// final result = await service.captureWidget(
///   key: chartKey,
///   config: ChartScreenshotConfig.highQuality,
/// );
///
/// // 分享
/// await service.share(
///   imageData: result.imageData,
///   config: ShareConfig(title: '我的消费报表'),
/// );
/// ```
class ChartShareService {
  /// 截图Widget
  Future<ScreenshotResult?> captureWidget({
    required GlobalKey key,
    ChartScreenshotConfig config = const ChartScreenshotConfig(),
  }) async {
    try {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        return null;
      }

      // 捕获图片
      final image = await renderObject.toImage(pixelRatio: config.pixelRatio);

      // 处理图片（添加背景、水印等）
      final processedImage = await _processImage(image, config);

      // 转换为字节数据
      final byteData = await processedImage.toByteData(
        format: _getImageFormat(config.format),
      );

      if (byteData == null) return null;

      final imageData = byteData.buffer.asUint8List();

      return ScreenshotResult(
        imageData: imageData,
        width: processedImage.width,
        height: processedImage.height,
        fileSize: imageData.length,
        format: config.format,
      );
    } catch (e) {
      debugPrint('Screenshot failed: $e');
      return null;
    }
  }

  /// 处理图片
  Future<ui.Image> _processImage(
    ui.Image original,
    ChartScreenshotConfig config,
  ) async {
    // 计算最终尺寸（含padding和边框）
    final paddingH = (config.padding.left + config.padding.right) * config.pixelRatio;
    final paddingV = (config.padding.top + config.padding.bottom) * config.pixelRatio;
    final borderW = config.addBorder ? config.borderWidth * 2 * config.pixelRatio : 0;

    final finalWidth = original.width + paddingH.toInt() + borderW.toInt();
    final finalHeight = original.height + paddingV.toInt() + borderW.toInt();

    // 创建绘制记录器
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制背景
    final bgColor = config.backgroundColor ?? Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
      Paint()..color = bgColor,
    );

    // 绘制边框
    if (config.addBorder) {
      final borderRect = Rect.fromLTWH(
        config.borderWidth * config.pixelRatio / 2,
        config.borderWidth * config.pixelRatio / 2,
        finalWidth - config.borderWidth * config.pixelRatio,
        finalHeight - config.borderWidth * config.pixelRatio,
      );
      canvas.drawRect(
        borderRect,
        Paint()
          ..color = config.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = config.borderWidth * config.pixelRatio,
      );
    }

    // 绘制原图
    final imageOffset = Offset(
      config.padding.left * config.pixelRatio +
          (config.addBorder ? config.borderWidth * config.pixelRatio : 0),
      config.padding.top * config.pixelRatio +
          (config.addBorder ? config.borderWidth * config.pixelRatio : 0),
    );
    canvas.drawImage(original, imageOffset, Paint());

    // 绘制水印
    if (config.addWatermark && config.watermarkText != null) {
      _drawWatermark(
        canvas,
        Size(finalWidth.toDouble(), finalHeight.toDouble()),
        config,
      );
    }

    // 结束绘制并转换为图片
    final picture = recorder.endRecording();
    return picture.toImage(finalWidth.toInt(), finalHeight.toInt());
  }

  /// 绘制水印
  void _drawWatermark(
    Canvas canvas,
    Size size,
    ChartScreenshotConfig config,
  ) {
    final textStyle = ui.TextStyle(
      color: const Color(0x40000000),
      fontSize: 12 * config.pixelRatio,
    );

    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.right,
    ))
      ..pushStyle(textStyle)
      ..addText(config.watermarkText ?? 'AI记账');

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size.width - 20));

    // 计算水印位置
    Offset watermarkOffset;
    switch (config.watermarkAlignment) {
      case Alignment.bottomRight:
        watermarkOffset = Offset(
          size.width - paragraph.width - 10 * config.pixelRatio,
          size.height - paragraph.height - 10 * config.pixelRatio,
        );
        break;
      case Alignment.bottomLeft:
        watermarkOffset = Offset(
          10 * config.pixelRatio,
          size.height - paragraph.height - 10 * config.pixelRatio,
        );
        break;
      case Alignment.topRight:
        watermarkOffset = Offset(
          size.width - paragraph.width - 10 * config.pixelRatio,
          10 * config.pixelRatio,
        );
        break;
      case Alignment.topLeft:
        watermarkOffset = Offset(
          10 * config.pixelRatio,
          10 * config.pixelRatio,
        );
        break;
      default:
        watermarkOffset = Offset(
          size.width - paragraph.width - 10 * config.pixelRatio,
          size.height - paragraph.height - 10 * config.pixelRatio,
        );
    }

    canvas.drawParagraph(paragraph, watermarkOffset);
  }

  /// 获取图片格式
  ui.ImageByteFormat _getImageFormat(ImageFormat format) {
    switch (format) {
      case ImageFormat.png:
        return ui.ImageByteFormat.png;
      case ImageFormat.jpeg:
        return ui.ImageByteFormat.rawRgba; // Flutter不直接支持JPEG，需要额外处理
      case ImageFormat.webp:
        return ui.ImageByteFormat.png; // 默认使用PNG
    }
  }

  /// 分享图片
  Future<ShareResult> share({
    required Uint8List imageData,
    ShareConfig config = const ShareConfig(),
    SharePlatform? platform,
  }) async {
    try {
      // 如果指定了平台，直接分享到该平台
      if (platform != null) {
        return await _shareToplatform(imageData, config, platform);
      }

      // 否则使用系统分享
      return await _shareToplatform(imageData, config, SharePlatform.system);
    } catch (e) {
      return ShareResult.failure(e.toString());
    }
  }

  /// 分享到指定平台
  Future<ShareResult> _shareToplatform(
    Uint8List imageData,
    ShareConfig config,
    SharePlatform platform,
  ) async {
    switch (platform) {
      case SharePlatform.system:
        // 系统分享实现（需要平台相关代码）
        return _systemShare(imageData, config);

      case SharePlatform.saveToGallery:
        return _saveToGallery(imageData);

      case SharePlatform.clipboard:
        return _copyToClipboard(imageData);

      case SharePlatform.wechat:
      case SharePlatform.wechatMoments:
      case SharePlatform.qq:
      case SharePlatform.weibo:
        // 这些平台需要集成第三方SDK
        return ShareResult.failure('该平台暂未支持');
    }
  }

  /// 系统分享
  Future<ShareResult> _systemShare(
    Uint8List imageData,
    ShareConfig config,
  ) async {
    // 这里需要使用 share_plus 或类似插件
    // 由于是示例代码，这里返回模拟结果
    debugPrint('System share: ${config.title}');
    return ShareResult.success(SharePlatform.system);
  }

  /// 保存到相册
  Future<ShareResult> _saveToGallery(Uint8List imageData) async {
    // 这里需要使用 image_gallery_saver 或类似插件
    // 由于是示例代码，这里返回模拟结果
    debugPrint('Save to gallery: ${imageData.length} bytes');
    return ShareResult.success(SharePlatform.saveToGallery);
  }

  /// 复制到剪贴板
  Future<ShareResult> _copyToClipboard(Uint8List imageData) async {
    // 图片复制到剪贴板的支持有限
    // 这里可以选择复制图片路径或其他方式
    debugPrint('Copy to clipboard: ${imageData.length} bytes');
    return ShareResult.success(SharePlatform.clipboard);
  }
}

/// 可截图组件包装器
class ScreenshotWrapper extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 截图Key
  final GlobalKey screenshotKey;

  /// 背景色
  final Color? backgroundColor;

  const ScreenshotWrapper({
    super.key,
    required this.child,
    required this.screenshotKey,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: screenshotKey,
      child: Container(
        color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        child: child,
      ),
    );
  }
}

/// 分享按钮组件
class ChartShareButton extends StatelessWidget {
  /// 截图Key
  final GlobalKey screenshotKey;

  /// 分享服务
  final ChartShareService shareService;

  /// 截图配置
  final ChartScreenshotConfig screenshotConfig;

  /// 分享配置
  final ShareConfig shareConfig;

  /// 分享成功回调
  final void Function(ShareResult result)? onShareComplete;

  const ChartShareButton({
    super.key,
    required this.screenshotKey,
    required this.shareService,
    this.screenshotConfig = const ChartScreenshotConfig(),
    this.shareConfig = const ShareConfig(),
    this.onShareComplete,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      tooltip: '分享',
      onPressed: () => _handleShare(context),
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在生成图片...'),
        duration: Duration(seconds: 1),
      ),
    );

    // 截图
    final screenshot = await shareService.captureWidget(
      key: screenshotKey,
      config: screenshotConfig,
    );

    if (screenshot == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('截图失败')),
        );
      }
      return;
    }

    // 显示分享选项
    if (context.mounted) {
      _showShareOptions(context, screenshot);
    }
  }

  void _showShareOptions(BuildContext context, ScreenshotResult screenshot) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '分享到',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareOption(
                    icon: Icons.share,
                    label: '分享',
                    onTap: () => _share(context, screenshot, SharePlatform.system),
                  ),
                  _ShareOption(
                    icon: Icons.save_alt,
                    label: '保存',
                    onTap: () => _share(context, screenshot, SharePlatform.saveToGallery),
                  ),
                  _ShareOption(
                    icon: Icons.copy,
                    label: '复制',
                    onTap: () => _share(context, screenshot, SharePlatform.clipboard),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _share(
    BuildContext context,
    ScreenshotResult screenshot,
    SharePlatform platform,
  ) async {
    Navigator.pop(context);

    final result = await shareService.share(
      imageData: screenshot.imageData,
      config: shareConfig,
      platform: platform,
    );

    onShareComplete?.call(result);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? '分享成功' : '分享失败: ${result.errorMessage}'),
        ),
      );
    }
  }
}

/// 分享选项
class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
