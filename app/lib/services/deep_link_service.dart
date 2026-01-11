import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 深度链接类型
enum DeepLinkType {
  voice,  // 语音记账
  add,    // 手动记账
  stats,  // 统计页面
  unknown,
}

/// 深度链接数据
class DeepLinkData {
  final DeepLinkType type;
  final Map<String, String> parameters;
  final String rawUri;

  DeepLinkData({
    required this.type,
    required this.parameters,
    required this.rawUri,
  });

  @override
  String toString() => 'DeepLinkData(type: $type, parameters: $parameters, rawUri: $rawUri)';
}

/// 深度链接服务
///
/// 处理 aibook:// 格式的深度链接:
/// - aibook://voice - 打开语音记账
/// - aibook://add - 打开手动记账
/// - aibook://stats - 打开统计页面
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('com.example.ai_bookkeeping/deep_link');
  static const EventChannel _eventChannel =
      EventChannel('com.example.ai_bookkeeping/deep_link_events');

  /// 深度链接事件流
  final StreamController<DeepLinkData> _linkController =
      StreamController<DeepLinkData>.broadcast();
  Stream<DeepLinkData> get onDeepLink => _linkController.stream;

  StreamSubscription? _eventSubscription;
  bool _initialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 监听深度链接事件
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is String) {
          final linkData = _parseDeepLink(data);
          if (linkData != null) {
            debugPrint('DeepLinkService: Received deep link: $linkData');
            _linkController.add(linkData);
          }
        }
      },
      onError: (error) {
        debugPrint('DeepLinkService: Error receiving deep link: $error');
      },
    );

    // 检查启动时的深度链接
    await _checkInitialLink();

    debugPrint('DeepLinkService: Initialized');
  }

  /// 检查初始深度链接
  Future<DeepLinkData?> _checkInitialLink() async {
    try {
      final String? initialLink = await _methodChannel.invokeMethod('getInitialLink');
      if (initialLink != null) {
        final linkData = _parseDeepLink(initialLink);
        if (linkData != null) {
          debugPrint('DeepLinkService: Initial deep link: $linkData');
          _linkController.add(linkData);
          return linkData;
        }
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error checking initial link: $e');
    }
    return null;
  }

  /// 解析深度链接
  DeepLinkData? _parseDeepLink(String uri) {
    try {
      final parsedUri = Uri.parse(uri);

      if (parsedUri.scheme != 'aibook') {
        return null;
      }

      final type = _getDeepLinkType(parsedUri.host);
      final parameters = parsedUri.queryParameters;

      return DeepLinkData(
        type: type,
        parameters: Map<String, String>.from(parameters),
        rawUri: uri,
      );
    } catch (e) {
      debugPrint('DeepLinkService: Error parsing deep link: $e');
      return null;
    }
  }

  /// 获取深度链接类型
  DeepLinkType _getDeepLinkType(String host) {
    switch (host) {
      case 'voice':
        return DeepLinkType.voice;
      case 'add':
        return DeepLinkType.add;
      case 'stats':
        return DeepLinkType.stats;
      default:
        return DeepLinkType.unknown;
    }
  }

  /// 清除待处理的深度链接
  Future<void> clearPendingLink() async {
    try {
      await _methodChannel.invokeMethod('clearPendingLink');
    } catch (e) {
      debugPrint('DeepLinkService: Error clearing pending link: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _eventSubscription?.cancel();
    _linkController.close();
    _initialized = false;
  }
}
