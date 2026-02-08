import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_upgrade_service.dart';
import '../core/logger.dart';

/// 后台下载状态
enum BackgroundDownloadStatus {
  idle,       // 空闲
  downloading, // 下载中
  completed,  // 下载完成
  failed,     // 下载失败
  installing, // 安装中
}

/// 后台下载进度回调
typedef DownloadProgressCallback = void Function(int received, int total, double progress);

/// 后台下载服务 - 支持通知栏显示进度，下载完成自动安装
class BackgroundDownloadService {
  static final BackgroundDownloadService _instance = BackgroundDownloadService._internal();
  factory BackgroundDownloadService() => _instance;
  BackgroundDownloadService._internal();

  final Logger _logger = Logger();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 下载通知 ID
  static const int _downloadNotificationId = 1001;
  static const String _channelId = 'app_upgrade';
  static const String _channelName = '应用更新';
  static const String _channelDesc = '显示应用更新下载进度';

  // 状态
  BackgroundDownloadStatus _status = BackgroundDownloadStatus.idle;
  VersionInfo? _currentVersion;
  CancelToken? _cancelToken;
  double _progress = 0;
  String? _downloadedFilePath;
  String? _errorMessage;
  bool _initialized = false;

  // 状态流控制器
  final _statusController = StreamController<BackgroundDownloadStatus>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  // 公开状态
  BackgroundDownloadStatus get status => _status;
  double get progress => _progress;
  VersionInfo? get currentVersion => _currentVersion;
  String? get errorMessage => _errorMessage;
  bool get isDownloading => _status == BackgroundDownloadStatus.downloading;

  // 状态流
  Stream<BackgroundDownloadStatus> get statusStream => _statusController.stream;
  Stream<double> get progressStream => _progressController.stream;

  /// 初始化通知
  Future<void> initialize() async {
    if (_initialized) return;

    // 请求通知权限 (Android 13+)
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        _logger.info('Notification permission: $result', tag: 'BGDownload');
      }
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 创建通知渠道 (Android 8.0+)
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.low, // 低重要性，不会弹出
          showBadge: false,
        ),
      );
    }

    _initialized = true;
    _logger.info('Background download service initialized', tag: 'BGDownload');
  }

  /// 处理通知点击
  void _onNotificationTap(NotificationResponse response) {
    _logger.info('Notification tapped: ${response.payload}', tag: 'BGDownload');

    // 如果下载完成，点击通知触发安装
    if (_status == BackgroundDownloadStatus.completed && _downloadedFilePath != null) {
      _installApk(_downloadedFilePath!);
    }
  }

  /// 开始后台下载
  Future<bool> startDownload(VersionInfo version) async {
    if (_status == BackgroundDownloadStatus.downloading) {
      _logger.warning('Download already in progress', tag: 'BGDownload');
      return false;
    }

    await initialize();

    _currentVersion = version;
    _status = BackgroundDownloadStatus.downloading;
    _progress = 0;
    _errorMessage = null;
    _cancelToken = CancelToken();
    _statusController.add(_status);
    _progressController.add(_progress);

    _logger.info('Starting background download: ${version.versionName}', tag: 'BGDownload');

    // 显示下载开始通知
    await _showProgressNotification(0, '准备下载...');

    // 在 isolate 中下载（避免阻塞 UI）
    final result = await AppUpgradeService().downloadApk(
      version,
      onProgress: (received, total) {
        if (total > 0) {
          _progress = received / total;
          _progressController.add(_progress);

          // 每 5% 更新一次通知，避免频繁更新
          final percentage = (_progress * 100).toInt();
          if (percentage % 5 == 0 || percentage >= 99) {
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
            _showProgressNotification(
              _progress,
              '$receivedMB / $totalMB MB',
            );
          }
        }
      },
      cancelToken: _cancelToken,
    );

    if (result.isSuccess && result.filePath != null) {
      _downloadedFilePath = result.filePath;
      _status = BackgroundDownloadStatus.completed;
      _statusController.add(_status);

      _logger.info('Background download completed', tag: 'BGDownload');

      // 显示下载完成通知
      await _showCompletedNotification();

      // 自动开始安装
      await _installApk(result.filePath!);
      return true;
    } else {
      _status = BackgroundDownloadStatus.failed;
      _errorMessage = result.userMessage;
      _statusController.add(_status);

      _logger.error('Background download failed: ${result.userMessage}', tag: 'BGDownload');

      // 显示下载失败通知
      await _showFailedNotification(result.userMessage);
      return false;
    }
  }

  /// 取消下载
  void cancelDownload() {
    _cancelToken?.cancel();
    _status = BackgroundDownloadStatus.idle;
    _progress = 0;
    _statusController.add(_status);
    _progressController.add(_progress);
    _notifications.cancel(_downloadNotificationId);
    _logger.info('Download cancelled', tag: 'BGDownload');
  }

  /// 显示下载进度通知
  Future<void> _showProgressNotification(double progress, String subtitle) async {
    final percentage = (progress * 100).toInt();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // 进行中的通知，不可滑动删除
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: percentage,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.progress,
    );

    await _notifications.show(
      _downloadNotificationId,
      '正在下载更新 $percentage%',
      subtitle,
      NotificationDetails(android: androidDetails),
      payload: 'downloading',
    );
  }

  /// 显示下载完成通知
  Future<void> _showCompletedNotification() async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.status,
    );

    await _notifications.show(
      _downloadNotificationId,
      '下载完成',
      '点击安装新版本 ${_currentVersion?.versionName ?? ""}',
      NotificationDetails(android: androidDetails),
      payload: 'completed',
    );
  }

  /// 显示下载失败通知
  Future<void> _showFailedNotification(String message) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.error,
    );

    await _notifications.show(
      _downloadNotificationId,
      '下载失败',
      message,
      NotificationDetails(android: androidDetails),
      payload: 'failed',
    );
  }

  /// 安装 APK
  Future<bool> _installApk(String filePath) async {
    _status = BackgroundDownloadStatus.installing;
    _statusController.add(_status);

    _logger.info('Auto-installing APK: $filePath', tag: 'BGDownload');

    final success = await AppUpgradeService().installApk(filePath);

    if (success) {
      _logger.info('APK install dialog opened', tag: 'BGDownload');
    } else {
      _logger.warning('Failed to open APK install dialog', tag: 'BGDownload');
    }

    // 安装对话框打开后，重置状态
    _status = BackgroundDownloadStatus.idle;
    _statusController.add(_status);

    return success;
  }

  /// 重试安装（如果下载完成但安装失败）
  Future<bool> retryInstall() async {
    if (_downloadedFilePath != null && await File(_downloadedFilePath!).exists()) {
      return await _installApk(_downloadedFilePath!);
    }
    return false;
  }

  /// 释放资源
  void dispose() {
    cancelDownload();
    _statusController.close();
    _progressController.close();
  }
}
