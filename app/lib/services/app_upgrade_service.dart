import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/logger.dart';
import '../core/build_info.dart';
import 'app_config_service.dart';

/// APP 升级检查结果
class UpdateCheckResult {
  final bool hasUpdate;
  final bool isForceUpdate;
  final String currentVersion;
  final VersionInfo? latestVersion;
  final String? message;

  UpdateCheckResult({
    required this.hasUpdate,
    required this.isForceUpdate,
    required this.currentVersion,
    this.latestVersion,
    this.message,
  });

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResult(
      hasUpdate: json['has_update'] ?? false,
      isForceUpdate: json['is_force_update'] ?? false,
      currentVersion: json['current_version'] ?? '',
      latestVersion: json['latest_version'] != null
          ? VersionInfo.fromJson(json['latest_version'])
          : null,
      message: json['message'],
    );
  }
}

/// 版本信息
class VersionInfo {
  final String versionName;
  final int versionCode;
  final String releaseNotes;
  final String? releaseNotesEn;
  final bool isForceUpdate;
  final String? downloadUrl;
  final int? fileSize;
  final String? fileMd5;
  final DateTime? publishedAt;

  VersionInfo({
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    this.releaseNotesEn,
    required this.isForceUpdate,
    this.downloadUrl,
    this.fileSize,
    this.fileMd5,
    this.publishedAt,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      versionName: json['version_name'] ?? '',
      versionCode: json['version_code'] ?? 0,
      releaseNotes: json['release_notes'] ?? '',
      releaseNotesEn: json['release_notes_en'],
      isForceUpdate: json['is_force_update'] ?? false,
      downloadUrl: json['download_url'],
      fileSize: json['file_size'],
      fileMd5: json['file_md5'],
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'])
          : null,
    );
  }

  /// 获取本地化的更新说明
  String getLocalizedReleaseNotes(String languageCode) {
    if (languageCode == 'en' &&
        releaseNotesEn != null &&
        releaseNotesEn!.isNotEmpty) {
      return releaseNotesEn!;
    }
    return releaseNotes;
  }

  /// 格式化文件大小
  String get formattedFileSize {
    if (fileSize == null) return '';
    final mb = fileSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// 完整版本号
  String get fullVersion => '$versionName+$versionCode';
}

/// APP 升级服务
class AppUpgradeService {
  static final AppUpgradeService _instance = AppUpgradeService._internal();
  factory AppUpgradeService() => _instance;
  AppUpgradeService._internal();

  final Logger _logger = Logger();
  UpdateCheckResult? _lastCheckResult;
  DateTime? _lastCheckTime;

  // 缓存时间：1小时内不重复检查（除非强制）
  static const Duration _cacheExpiry = Duration(hours: 1);

  /// 获取上次检查结果
  UpdateCheckResult? get lastCheckResult => _lastCheckResult;

  /// 是否有更新可用
  bool get hasUpdate => _lastCheckResult?.hasUpdate ?? false;

  /// 是否需要强制更新
  bool get isForceUpdate => _lastCheckResult?.isForceUpdate ?? false;

  /// 检查更新
  Future<UpdateCheckResult> checkUpdate({bool force = false}) async {
    // 检查缓存
    if (!force && _lastCheckResult != null && _lastCheckTime != null) {
      final elapsed = DateTime.now().difference(_lastCheckTime!);
      if (elapsed < _cacheExpiry) {
        _logger.debug('Using cached update check result', tag: 'Upgrade');
        return _lastCheckResult!;
      }
    }

    try {
      final config = AppConfigService().config;
      final packageInfo = await PackageInfo.fromPlatform();

      final dio = Dio(BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
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

      final response = await dio.get(
        '/app-upgrade/check',
        queryParameters: {
          'version_name': packageInfo.version,
          'version_code':
              int.tryParse(packageInfo.buildNumber) ?? BuildInfo.buildNumber,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );

      if (response.statusCode == 200) {
        _lastCheckResult = UpdateCheckResult.fromJson(response.data);
        _lastCheckTime = DateTime.now();

        _logger.info(
          'Update check: hasUpdate=${_lastCheckResult!.hasUpdate}, '
          'force=${_lastCheckResult!.isForceUpdate}',
          tag: 'Upgrade',
        );

        return _lastCheckResult!;
      }
    } catch (e) {
      _logger.warning('Failed to check update: $e', tag: 'Upgrade');
    }

    // 返回无更新结果
    return UpdateCheckResult(
      hasUpdate: false,
      isForceUpdate: false,
      currentVersion: BuildInfo.version,
      message: '检查更新失败',
    );
  }

  /// 下载 APK
  Future<String?> downloadApk(
    VersionInfo version, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (version.downloadUrl == null) {
      _logger.error('No download URL available', tag: 'Upgrade');
      return null;
    }

    try {
      final config = AppConfigService().config;
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        _logger.error('Cannot access external storage', tag: 'Upgrade');
        return null;
      }

      // 创建下载目录
      final downloadDir = Directory('${dir.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final savePath =
          '${downloadDir.path}/ai_bookkeeping_${version.versionName}.apk';

      // 如果文件已存在，先删除
      final existingFile = File(savePath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      final dio = Dio();
      if (config.skipCertificateVerification) {
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.badCertificateCallback = (cert, host, port) => true;
            return client;
          },
        );
      }

      await dio.download(
        version.downloadUrl!,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );

      _logger.info('APK downloaded to: $savePath', tag: 'Upgrade');
      return savePath;
    } catch (e) {
      _logger.error('Failed to download APK: $e', tag: 'Upgrade');
      return null;
    }
  }

  /// 安装 APK
  Future<bool> installApk(String filePath) async {
    try {
      _logger.info('Installing APK from: $filePath', tag: 'Upgrade');

      final result = await OpenFilex.open(filePath);

      if (result.type == ResultType.done) {
        _logger.info('APK install dialog opened', tag: 'Upgrade');
        return true;
      } else {
        _logger.warning(
            'Failed to open APK: ${result.type} - ${result.message}',
            tag: 'Upgrade');
        return false;
      }
    } catch (e) {
      _logger.error('Failed to install APK: $e', tag: 'Upgrade');
      return false;
    }
  }

  /// 在浏览器中打开下载链接
  Future<bool> openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      _logger.error('Failed to open browser: $e', tag: 'Upgrade');
    }
    return false;
  }

  /// 清除缓存的检查结果
  void clearCache() {
    _lastCheckResult = null;
    _lastCheckTime = null;
  }
}
