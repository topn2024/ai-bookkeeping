import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';
import '../core/build_info.dart';
import 'app_config_service.dart';

/// 升级事件类型
enum UpgradeEventType {
  /// 检查更新
  checkUpdate,
  /// 发现新版本
  updateFound,
  /// 开始下载
  downloadStart,
  /// 下载进度（每25%上报一次）
  downloadProgress,
  /// 下载完成
  downloadComplete,
  /// 下载失败
  downloadFailed,
  /// 下载取消
  downloadCancelled,
  /// MD5校验失败
  md5Failed,
  /// 开始安装
  installStart,
  /// 安装成功（下次启动时上报）
  installSuccess,
  /// 安装取消
  installCancelled,
  /// 强制更新触发
  forceUpdateTriggered,
  /// 用户跳过更新
  updateSkipped,
  /// 稍后提醒
  remindLater,
}

/// 升级事件数据
class UpgradeEvent {
  final UpgradeEventType type;
  final String fromVersion;
  final String? toVersion;
  final int? downloadProgress;
  final int? downloadSize;
  final int? downloadDuration;
  final String? errorMessage;
  final String? errorCode;
  final DateTime timestamp;
  final Map<String, dynamic>? extra;

  UpgradeEvent({
    required this.type,
    required this.fromVersion,
    this.toVersion,
    this.downloadProgress,
    this.downloadSize,
    this.downloadDuration,
    this.errorMessage,
    this.errorCode,
    this.extra,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'event_type': type.name,
      'from_version': fromVersion,
      'to_version': toVersion,
      'download_progress': downloadProgress,
      'download_size': downloadSize,
      'download_duration_ms': downloadDuration,
      'error_message': errorMessage,
      'error_code': errorCode,
      'timestamp': timestamp.toIso8601String(),
      'extra': extra,
    };
  }
}

/// 升级监控和埋点服务
class UpgradeAnalyticsService {
  static final UpgradeAnalyticsService _instance =
      UpgradeAnalyticsService._internal();
  factory UpgradeAnalyticsService() => _instance;
  UpgradeAnalyticsService._internal();

  final Logger _logger = Logger();

  // 待上报的事件队列（离线缓存）
  final List<UpgradeEvent> _pendingEvents = [];

  // 下载开始时间（用于计算下载耗时）
  DateTime? _downloadStartTime;
  int? _targetVersionCode;
  String? _targetVersionName;

  // 上次上报进度（避免重复上报）
  int _lastReportedProgress = 0;

  // SharedPreferences keys
  static const String _keyPendingEvents = 'upgrade_pending_events';
  static const String _keyLastUpgradeFrom = 'upgrade_last_from_version';
  static const String _keyLastUpgradeTo = 'upgrade_last_to_version';
  static const String _keyPendingInstallReport = 'upgrade_pending_install_report';

  /// 初始化服务
  Future<void> init() async {
    await _loadPendingEvents();
    await _checkPendingInstallReport();
    // 尝试上报待发送的事件
    await _flushPendingEvents();
  }

  /// 检查是否有待上报的安装成功事件
  Future<void> _checkPendingInstallReport() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingReport = prefs.getBool(_keyPendingInstallReport) ?? false;

    if (pendingReport) {
      final fromVersion = prefs.getString(_keyLastUpgradeFrom);
      final toVersion = prefs.getString(_keyLastUpgradeTo);
      final currentVersion = BuildInfo.version;

      // 如果当前版本与目标版本一致，说明安装成功
      if (toVersion != null && currentVersion == toVersion) {
        _logger.info(
          'Detected successful upgrade from $fromVersion to $toVersion',
          tag: 'UpgradeAnalytics',
        );
        await trackEvent(UpgradeEventType.installSuccess,
            toVersion: toVersion,
            extra: {'upgraded_from': fromVersion});
      }

      // 清除待上报标记
      await prefs.remove(_keyPendingInstallReport);
      await prefs.remove(_keyLastUpgradeFrom);
      await prefs.remove(_keyLastUpgradeTo);
    }
  }

  /// 加载本地缓存的待发送事件
  Future<void> _loadPendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getStringList(_keyPendingEvents);
      if (eventsJson != null && eventsJson.isNotEmpty) {
        _logger.debug(
          'Loaded ${eventsJson.length} pending upgrade events',
          tag: 'UpgradeAnalytics',
        );
      }
    } catch (e) {
      _logger.warning('Failed to load pending events: $e', tag: 'UpgradeAnalytics');
    }
  }

  /// 保存待发送事件到本地
  Future<void> _savePendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = _pendingEvents.map((e) => e.toJson().toString()).toList();
      await prefs.setStringList(_keyPendingEvents, eventsJson);
    } catch (e) {
      _logger.warning('Failed to save pending events: $e', tag: 'UpgradeAnalytics');
    }
  }

  /// 获取当前版本
  Future<String> _getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return BuildInfo.version;
    }
  }

  /// 记录升级事件
  Future<void> trackEvent(
    UpgradeEventType type, {
    String? toVersion,
    int? downloadProgress,
    int? downloadSize,
    String? errorMessage,
    String? errorCode,
    Map<String, dynamic>? extra,
  }) async {
    final fromVersion = await _getCurrentVersion();

    // 计算下载耗时
    int? downloadDuration;
    if (type == UpgradeEventType.downloadComplete ||
        type == UpgradeEventType.downloadFailed) {
      if (_downloadStartTime != null) {
        downloadDuration =
            DateTime.now().difference(_downloadStartTime!).inMilliseconds;
      }
    }

    final event = UpgradeEvent(
      type: type,
      fromVersion: fromVersion,
      toVersion: toVersion ?? _targetVersionName,
      downloadProgress: downloadProgress,
      downloadSize: downloadSize,
      downloadDuration: downloadDuration,
      errorMessage: errorMessage,
      errorCode: errorCode,
      extra: extra,
    );

    _logger.info(
      'Tracking upgrade event: ${type.name}, to: $toVersion',
      tag: 'UpgradeAnalytics',
    );

    // 尝试直接上报
    final sent = await _sendEvent(event);
    if (!sent) {
      // 上报失败，加入待发送队列
      _pendingEvents.add(event);
      await _savePendingEvents();
    }
  }

  /// 开始下载时调用
  void onDownloadStart(String targetVersion, int targetVersionCode) {
    _downloadStartTime = DateTime.now();
    _targetVersionName = targetVersion;
    _targetVersionCode = targetVersionCode;
    _lastReportedProgress = 0;

    trackEvent(
      UpgradeEventType.downloadStart,
      toVersion: targetVersion,
    );
  }

  /// 下载进度更新时调用（每25%上报一次）
  void onDownloadProgress(int received, int total) {
    if (total <= 0) return;

    final progress = (received * 100 / total).floor();
    // 每25%上报一次
    final milestone = (progress / 25).floor() * 25;

    if (milestone > _lastReportedProgress && milestone < 100) {
      _lastReportedProgress = milestone;
      trackEvent(
        UpgradeEventType.downloadProgress,
        downloadProgress: milestone,
        downloadSize: total,
      );
    }
  }

  /// 下载完成时调用
  void onDownloadComplete(int fileSize) {
    trackEvent(
      UpgradeEventType.downloadComplete,
      downloadProgress: 100,
      downloadSize: fileSize,
    );
    _downloadStartTime = null;
  }

  /// 下载失败时调用
  void onDownloadFailed(String error, {String? errorCode}) {
    trackEvent(
      UpgradeEventType.downloadFailed,
      errorMessage: error,
      errorCode: errorCode,
    );
    _downloadStartTime = null;
  }

  /// MD5校验失败时调用
  void onMd5Failed(String expected, String actual) {
    trackEvent(
      UpgradeEventType.md5Failed,
      errorMessage: 'MD5 mismatch',
      extra: {
        'expected_md5': expected,
        'actual_md5': actual,
      },
    );
  }

  /// 开始安装时调用
  Future<void> onInstallStart() async {
    final fromVersion = await _getCurrentVersion();

    // 记录待上报的安装成功事件
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPendingInstallReport, true);
    await prefs.setString(_keyLastUpgradeFrom, fromVersion);
    await prefs.setString(_keyLastUpgradeTo, _targetVersionName ?? '');

    trackEvent(UpgradeEventType.installStart);
  }

  /// 用户跳过更新时调用
  void onUpdateSkipped() {
    trackEvent(UpgradeEventType.updateSkipped);
  }

  /// 用户选择稍后提醒时调用
  void onRemindLater() {
    trackEvent(UpgradeEventType.remindLater);
  }

  /// 发送单个事件到服务器
  Future<bool> _sendEvent(UpgradeEvent event) async {
    try {
      final config = AppConfigService().config;
      final dio = Dio(BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      // 配置 SSL
      if (config.skipCertificateVerification) {
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.badCertificateCallback = (cert, host, port) => true;
            return client;
          },
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();

      await dio.post(
        '/app-upgrade/analytics',
        data: {
          ...event.toJson(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'device_model': Platform.localHostname,
          'app_version': packageInfo.version,
          'app_build': packageInfo.buildNumber,
        },
      );

      return true;
    } catch (e) {
      _logger.debug('Failed to send analytics event: $e', tag: 'UpgradeAnalytics');
      return false;
    }
  }

  /// 批量上报待发送的事件
  Future<void> _flushPendingEvents() async {
    if (_pendingEvents.isEmpty) return;

    _logger.debug(
      'Flushing ${_pendingEvents.length} pending events',
      tag: 'UpgradeAnalytics',
    );

    final eventsToSend = List<UpgradeEvent>.from(_pendingEvents);
    final sentEvents = <UpgradeEvent>[];

    for (final event in eventsToSend) {
      if (await _sendEvent(event)) {
        sentEvents.add(event);
      }
    }

    // 移除已发送的事件
    for (final event in sentEvents) {
      _pendingEvents.remove(event);
    }

    if (sentEvents.isNotEmpty) {
      await _savePendingEvents();
      _logger.info(
        'Sent ${sentEvents.length}/${eventsToSend.length} pending events',
        tag: 'UpgradeAnalytics',
      );
    }
  }

  /// 获取升级统计摘要（用于调试）
  Map<String, dynamic> getStats() {
    return {
      'pending_events': _pendingEvents.length,
      'current_download_target': _targetVersionName,
      'download_in_progress': _downloadStartTime != null,
    };
  }
}
