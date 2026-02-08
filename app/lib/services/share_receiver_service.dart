import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 分享接收服务
///
/// 处理从其他应用分享过来的图片（如微信/支付宝账单截图）
/// 支持 Android 和 iOS 平台
class ShareReceiverService extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('com.example.ai_bookkeeping/share');
  static const EventChannel _eventChannel =
      EventChannel('com.example.ai_bookkeeping/share_events');

  /// 单例实例
  static final ShareReceiverService _instance = ShareReceiverService._internal();
  factory ShareReceiverService() => _instance;
  ShareReceiverService._internal();

  /// 待处理的分享图片路径
  List<String> _pendingImages = [];

  /// 分享事件流订阅
  StreamSubscription<dynamic>? _eventSubscription;

  /// 分享图片回调
  void Function(List<String> imagePaths)? onImagesReceived;

  /// 是否已初始化
  bool _initialized = false;

  /// 待处理的分享图片
  List<String> get pendingImages => List.unmodifiable(_pendingImages);

  /// 是否有待处理的分享内容
  bool get hasPendingSharedContent => _pendingImages.isNotEmpty;

  /// 初始化服务
  Future<void> init() async {
    if (_initialized) return;

    // 监听分享事件流
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleShareEvent,
      onError: (error) {
        debugPrint('ShareReceiverService: 事件流错误: $error');
      },
    );

    // 检查是否有启动时的分享内容
    await checkInitialShare();

    _initialized = true;
  }

  /// 检查启动时的分享内容
  Future<void> checkInitialShare() async {
    try {
      final List<dynamic>? images = await _channel.invokeMethod('getSharedImages');
      if (images != null && images.isNotEmpty) {
        _pendingImages = images.cast<String>();
        notifyListeners();
        onImagesReceived?.call(_pendingImages);
      }
    } catch (e) {
      debugPrint('ShareReceiverService: 获取分享内容失败: $e');
    }
  }

  /// 处理分享事件
  void _handleShareEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      if (type == 'images') {
        final paths = (event['paths'] as List?)?.cast<String>() ?? [];
        if (paths.isNotEmpty) {
          _pendingImages = paths;
          notifyListeners();
          onImagesReceived?.call(_pendingImages);
        }
      }
    }
  }

  /// 获取并清除待处理的分享图片
  Future<List<String>> consumePendingImages() async {
    final images = List<String>.from(_pendingImages);
    _pendingImages = [];

    try {
      await _channel.invokeMethod('clearSharedImages');
    } catch (e) {
      debugPrint('ShareReceiverService: 清除分享内容失败: $e');
    }

    notifyListeners();
    return images;
  }

  /// 清除待处理的分享内容
  Future<void> clearPendingImages() async {
    _pendingImages = [];

    try {
      await _channel.invokeMethod('clearSharedImages');
    } catch (e) {
      debugPrint('ShareReceiverService: 清除分享内容失败: $e');
    }

    notifyListeners();
  }

  /// 验证图片文件是否存在
  Future<List<String>> validateImages(List<String> paths) async {
    final validPaths = <String>[];
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        validPaths.add(path);
      }
    }
    return validPaths;
  }

  /// 释放资源
  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// 分享内容类型
enum SharedContentType {
  /// 图片（截图、照片）
  image,

  /// 文本
  text,

  /// 文件
  file,
}

/// 分享内容
class SharedContent {
  /// 内容类型
  final SharedContentType type;

  /// 文件路径列表（图片或文件）
  final List<String>? filePaths;

  /// 文本内容
  final String? text;

  /// 接收时间
  final DateTime receivedAt;

  SharedContent({
    required this.type,
    this.filePaths,
    this.text,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// 是否为图片分享
  bool get isImage => type == SharedContentType.image;

  /// 是否有效
  bool get isValid {
    switch (type) {
      case SharedContentType.image:
      case SharedContentType.file:
        return filePaths != null && filePaths!.isNotEmpty;
      case SharedContentType.text:
        return text != null && text!.isNotEmpty;
    }
  }
}
