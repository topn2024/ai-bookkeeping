import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';
import '../core/build_info.dart';
import 'app_config_service.dart';
import 'bspatch_service.dart';

/// APP 升级检查结果
class UpdateCheckResult {
  final bool hasUpdate;
  final bool isForceUpdate;
  final bool hasPatch;
  final String currentVersion;
  final VersionInfo? latestVersion;
  final String? message;

  UpdateCheckResult({
    required this.hasUpdate,
    required this.isForceUpdate,
    this.hasPatch = false,
    required this.currentVersion,
    this.latestVersion,
    this.message,
  });

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResult(
      hasUpdate: json['has_update'] ?? false,
      isForceUpdate: json['is_force_update'] ?? false,
      hasPatch: json['has_patch'] ?? false,
      currentVersion: json['current_version'] ?? '',
      latestVersion: json['latest_version'] != null
          ? VersionInfo.fromJson(json['latest_version'])
          : null,
      message: json['message'],
    );
  }

  /// 是否推荐使用增量更新
  bool get shouldUsePatch => hasPatch && latestVersion?.patch != null;
}

/// 增量包信息
class PatchInfo {
  final String fromVersion;
  final int fromCode;
  final String downloadUrl;
  final int fileSize;
  final String fileMd5;

  PatchInfo({
    required this.fromVersion,
    required this.fromCode,
    required this.downloadUrl,
    required this.fileSize,
    required this.fileMd5,
  });

  factory PatchInfo.fromJson(Map<String, dynamic> json) {
    return PatchInfo(
      fromVersion: json['from_version'] ?? '',
      fromCode: json['from_code'] ?? 0,
      downloadUrl: json['download_url'] ?? '',
      fileSize: json['file_size'] ?? 0,
      fileMd5: json['file_md5'] ?? '',
    );
  }

  /// 格式化文件大小
  String get formattedFileSize {
    final mb = fileSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
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
  final PatchInfo? patch;

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
    this.patch,
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
      patch: json['patch'] != null ? PatchInfo.fromJson(json['patch']) : null,
    );
  }

  /// 是否有增量更新包
  bool get hasPatch => patch != null;

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

/// 下载结果状态
enum DownloadStatus {
  success,
  error,
  md5Failed,
}

/// APK 下载结果
class DownloadResult {
  final DownloadStatus status;
  final String? filePath;
  final String? errorMessage;
  final String? expectedMd5;
  final String? actualMd5;

  DownloadResult._({
    required this.status,
    this.filePath,
    this.errorMessage,
    this.expectedMd5,
    this.actualMd5,
  });

  factory DownloadResult.success(String filePath) {
    return DownloadResult._(
      status: DownloadStatus.success,
      filePath: filePath,
    );
  }

  factory DownloadResult.error(String message) {
    return DownloadResult._(
      status: DownloadStatus.error,
      errorMessage: message,
    );
  }

  factory DownloadResult.md5Failed({
    required String expectedMd5,
    required String actualMd5,
  }) {
    return DownloadResult._(
      status: DownloadStatus.md5Failed,
      errorMessage: '文件校验失败，请重新下载',
      expectedMd5: expectedMd5,
      actualMd5: actualMd5,
    );
  }

  bool get isSuccess => status == DownloadStatus.success;
  bool get isMd5Failed => status == DownloadStatus.md5Failed;
  bool get isError => status == DownloadStatus.error;

  /// 用户友好的错误提示
  String get userMessage {
    switch (status) {
      case DownloadStatus.success:
        return '下载完成';
      case DownloadStatus.md5Failed:
        return '文件校验失败，可能已损坏，请重新下载';
      case DownloadStatus.error:
        return errorMessage ?? '下载失败';
    }
  }
}

/// APP 升级服务
class AppUpgradeService {
  static final AppUpgradeService _instance = AppUpgradeService._internal();
  factory AppUpgradeService() => _instance;
  AppUpgradeService._internal();

  final Logger _logger = Logger();
  UpdateCheckResult? _lastCheckResult;
  DateTime? _lastCheckTime;
  String? _deviceId;

  // 缓存时间：1小时内不重复检查（除非强制）
  static const Duration _cacheExpiry = Duration(hours: 1);

  /// 获取设备 ID（用于灰度发布）
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      // 生成唯一设备 ID
      final platform = Platform.isAndroid ? 'android' : 'ios';
      deviceId = '${DateTime.now().millisecondsSinceEpoch}_$platform';
      await prefs.setString('device_id', deviceId);
    }
    _deviceId = deviceId;
    return deviceId;
  }

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
      final deviceId = await _getDeviceId();

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
          'device_id': deviceId,  // 用于灰度发布
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

  /// 下载 APK（带 MD5 校验和断点续传）
  Future<DownloadResult> downloadApk(
    VersionInfo version, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    bool verifyMd5 = true,
    bool enableResume = true,
  }) async {
    if (version.downloadUrl == null) {
      _logger.error('No download URL available', tag: 'Upgrade');
      return DownloadResult.error('没有可用的下载链接');
    }

    try {
      final config = AppConfigService().config;

      // 构建完整的下载 URL
      String fullDownloadUrl = version.downloadUrl!;
      if (!fullDownloadUrl.startsWith('http')) {
        // 相对路径，需要拼接服务器地址
        // apiBaseUrl 格式: https://160.202.238.29/api/v1
        // 需要提取 https://160.202.238.29
        final baseUri = Uri.parse(config.apiBaseUrl);
        final serverBase = '${baseUri.scheme}://${baseUri.host}${baseUri.port != 80 && baseUri.port != 443 ? ':${baseUri.port}' : ''}';
        fullDownloadUrl = '$serverBase$fullDownloadUrl';
        _logger.info('Constructed full download URL: $fullDownloadUrl', tag: 'Upgrade');
      }
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        _logger.error('Cannot access external storage', tag: 'Upgrade');
        return DownloadResult.error('无法访问存储空间');
      }

      // 创建下载目录
      final downloadDir = Directory('${dir.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final savePath =
          '${downloadDir.path}/ai_bookkeeping_${version.versionName}.apk';
      final tempPath = '$savePath.tmp';

      // 如果完整文件已存在，检查 MD5
      final existingFile = File(savePath);
      if (await existingFile.exists()) {
        if (verifyMd5 && version.fileMd5 != null) {
          final existingMd5 = await _calculateFileMd5(existingFile);
          if (existingMd5 == version.fileMd5!.toLowerCase()) {
            _logger.info('APK already exists and MD5 matches', tag: 'Upgrade');
            return DownloadResult.success(savePath);
          }
        }
        await existingFile.delete();
      }

      // 检查是否有部分下载的文件（断点续传）
      final tempFile = File(tempPath);
      int downloadedBytes = 0;
      bool resuming = false;

      if (enableResume && await tempFile.exists()) {
        downloadedBytes = await tempFile.length();
        // 如果服务器提供了文件大小，检查部分下载是否有效
        if (version.fileSize != null && downloadedBytes < version.fileSize!) {
          resuming = true;
          _logger.info(
            'Resuming download from $downloadedBytes bytes',
            tag: 'Upgrade',
          );
        } else {
          // 部分文件无效，删除重新开始
          await tempFile.delete();
          downloadedBytes = 0;
        }
      }

      // 为大文件下载配置更长的超时和稳健的连接
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10), // 大文件需要更长时间
        sendTimeout: const Duration(seconds: 30),
      ));

      // 配置 HTTP 客户端
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          // 跳过证书验证（如果配置）
          if (config.skipCertificateVerification) {
            client.badCertificateCallback = (cert, host, port) => true;
          }
          // 设置更长的连接超时
          client.connectionTimeout = const Duration(seconds: 30);
          client.idleTimeout = const Duration(minutes: 5);
          return client;
        },
      );

      // 设置断点续传头
      final options = Options();
      if (resuming && downloadedBytes > 0) {
        options.headers = {
          'Range': 'bytes=$downloadedBytes-',
        };
      }

      // 下载到临时文件（带重试机制）
      int retryCount = 0;
      const maxRetries = 3;
      Exception? lastError;

      while (retryCount < maxRetries) {
        try {
          await dio.download(
            fullDownloadUrl,
            tempPath,
            onReceiveProgress: (received, total) {
              // 断点续传时，received 是本次下载的字节数，total 是剩余字节数
              final actualReceived = resuming ? received + downloadedBytes : received;
              final actualTotal = resuming ? total + downloadedBytes : total;
              onProgress?.call(actualReceived, actualTotal);
            },
            cancelToken: cancelToken,
            options: options,
            deleteOnError: false, // 保留部分下载的文件以支持断点续传
          );
          break; // 下载成功，退出重试循环
        } catch (e) {
          lastError = e as Exception;
          retryCount++;
          _logger.warning(
            'Download attempt $retryCount failed: $e',
            tag: 'Upgrade',
          );

          if (retryCount < maxRetries) {
            // 检查已下载的字节数，更新断点续传位置
            final tempFileCheck = File(tempPath);
            if (await tempFileCheck.exists()) {
              downloadedBytes = await tempFileCheck.length();
              resuming = true;
              options.headers = {'Range': 'bytes=$downloadedBytes-'};
              _logger.info(
                'Retrying from $downloadedBytes bytes...',
                tag: 'Upgrade',
              );
            }
            // 等待后重试
            await Future.delayed(Duration(seconds: 2 * retryCount));
          }
        }
      }

      if (retryCount >= maxRetries && lastError != null) {
        throw lastError;
      }

      // 下载完成，重命名临时文件
      if (await tempFile.exists()) {
        await tempFile.rename(savePath);
      }

      _logger.info('APK downloaded to: $savePath', tag: 'Upgrade');

      // MD5 校验
      if (verifyMd5 && version.fileMd5 != null) {
        _logger.info('Verifying APK MD5...', tag: 'Upgrade');
        final downloadedFile = File(savePath);
        final actualMd5 = await _calculateFileMd5(downloadedFile);

        if (actualMd5 != version.fileMd5!.toLowerCase()) {
          _logger.error(
            'MD5 verification failed! Expected: ${version.fileMd5}, Actual: $actualMd5',
            tag: 'Upgrade',
          );
          // 删除损坏的文件和临时文件
          await downloadedFile.delete();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          return DownloadResult.md5Failed(
            expectedMd5: version.fileMd5!,
            actualMd5: actualMd5,
          );
        }

        _logger.info('MD5 verification passed: $actualMd5', tag: 'Upgrade');
      } else {
        _logger.warning('MD5 verification skipped (no MD5 provided)', tag: 'Upgrade');
      }

      return DownloadResult.success(savePath);
    } catch (e) {
      _logger.error('Failed to download APK: $e', tag: 'Upgrade');
      return DownloadResult.error('下载失败: $e');
    }
  }

  /// 计算文件 MD5
  Future<String> _calculateFileMd5(File file) async {
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString().toLowerCase();
  }

  /// 下载 APK（兼容旧接口，返回路径或 null）
  Future<String?> downloadApkSimple(
    VersionInfo version, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final result = await downloadApk(
      version,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return result.isSuccess ? result.filePath : null;
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

  /// 获取下载缓存大小
  Future<int> getDownloadCacheSize() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return 0;

      final downloadDir = Directory('${dir.path}/downloads');
      if (!await downloadDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in downloadDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      _logger.warning('Failed to get download cache size: $e', tag: 'Upgrade');
      return 0;
    }
  }

  /// 获取下载缓存文件列表
  Future<List<FileSystemEntity>> getDownloadCacheFiles() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return [];

      final downloadDir = Directory('${dir.path}/downloads');
      if (!await downloadDir.exists()) return [];

      final files = <FileSystemEntity>[];
      await for (final entity in downloadDir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.apk') || entity.path.endsWith('.tmp') || entity.path.endsWith('.patch'))) {
          files.add(entity);
        }
      }
      return files;
    } catch (e) {
      _logger.warning('Failed to list download cache files: $e', tag: 'Upgrade');
      return [];
    }
  }

  /// 清理下载缓存
  Future<int> clearDownloadCache() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return 0;

      final downloadDir = Directory('${dir.path}/downloads');
      if (!await downloadDir.exists()) return 0;

      int deletedSize = 0;
      await for (final entity in downloadDir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.apk') || entity.path.endsWith('.tmp') || entity.path.endsWith('.patch'))) {
          final size = await entity.length();
          await entity.delete();
          deletedSize += size;
          _logger.info('Deleted cache file: ${entity.path}', tag: 'Upgrade');
        }
      }

      _logger.info('Cleared download cache: ${deletedSize ~/ 1024} KB', tag: 'Upgrade');
      return deletedSize;
    } catch (e) {
      _logger.error('Failed to clear download cache: $e', tag: 'Upgrade');
      return 0;
    }
  }

  /// 下载增量更新包
  ///
  /// 返回下载的补丁文件路径，如果失败返回 null
  Future<DownloadResult> downloadPatch(
    PatchInfo patch, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    bool verifyMd5 = true,
  }) async {
    try {
      final config = AppConfigService().config;

      // 构建完整的下载 URL
      String fullDownloadUrl = patch.downloadUrl;
      if (!fullDownloadUrl.startsWith('http')) {
        final baseUri = Uri.parse(config.apiBaseUrl);
        final serverBase = '${baseUri.scheme}://${baseUri.host}${baseUri.port != 80 && baseUri.port != 443 ? ':${baseUri.port}' : ''}';
        fullDownloadUrl = '$serverBase$fullDownloadUrl';
        _logger.info('Constructed full patch URL: $fullDownloadUrl', tag: 'Upgrade');
      }

      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        _logger.error('Cannot access external storage', tag: 'Upgrade');
        return DownloadResult.error('无法访问存储空间');
      }

      // 创建下载目录
      final downloadDir = Directory('${dir.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final savePath =
          '${downloadDir.path}/patch_${patch.fromVersion}_to_next.patch';

      // 如果补丁文件已存在，验证 MD5
      final existingFile = File(savePath);
      if (await existingFile.exists()) {
        if (verifyMd5 && patch.fileMd5.isNotEmpty) {
          final existingMd5 = await _calculateFileMd5(existingFile);
          if (existingMd5 == patch.fileMd5.toLowerCase()) {
            _logger.info('Patch already exists and MD5 matches', tag: 'Upgrade');
            return DownloadResult.success(savePath);
          }
        }
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
        fullDownloadUrl,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );

      _logger.info('Patch downloaded to: $savePath', tag: 'Upgrade');

      // MD5 校验
      if (verifyMd5 && patch.fileMd5.isNotEmpty) {
        _logger.info('Verifying patch MD5...', tag: 'Upgrade');
        final downloadedFile = File(savePath);
        final actualMd5 = await _calculateFileMd5(downloadedFile);

        if (actualMd5 != patch.fileMd5.toLowerCase()) {
          _logger.error(
            'Patch MD5 verification failed! Expected: ${patch.fileMd5}, Actual: $actualMd5',
            tag: 'Upgrade',
          );
          await downloadedFile.delete();
          return DownloadResult.md5Failed(
            expectedMd5: patch.fileMd5,
            actualMd5: actualMd5,
          );
        }

        _logger.info('Patch MD5 verification passed', tag: 'Upgrade');
      }

      return DownloadResult.success(savePath);
    } catch (e) {
      _logger.error('Failed to download patch: $e', tag: 'Upgrade');
      return DownloadResult.error('补丁下载失败: $e');
    }
  }

  /// 应用增量更新补丁
  ///
  /// 需要补丁文件路径和目标版本
  /// 返回生成的新 APK 路径，如果失败返回 null
  Future<String?> applyPatch({
    required String patchPath,
    required String targetVersion,
    String? expectedMd5,
  }) async {
    try {
      final bspatch = BsPatchService();

      if (!bspatch.isSupported) {
        _logger.warning('bspatch not supported on this platform', tag: 'Upgrade');
        return null;
      }

      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        _logger.error('Cannot access external storage', tag: 'Upgrade');
        return null;
      }

      _logger.info(
        'Applying patch for version $targetVersion',
        tag: 'Upgrade',
      );

      final result = await bspatch.performIncrementalUpdate(
        patchPath: patchPath,
        targetVersion: targetVersion,
        expectedMd5: expectedMd5,
        outputDir: '${dir.path}/downloads',
      );

      if (result.success && result.outputPath != null) {
        _logger.info('Patch applied successfully: ${result.outputPath}', tag: 'Upgrade');
        return result.outputPath;
      } else {
        _logger.error('Patch failed: ${result.errorMessage}', tag: 'Upgrade');
        return null;
      }
    } catch (e) {
      _logger.error('Failed to apply patch: $e', tag: 'Upgrade');
      return null;
    }
  }

  /// 获取当前安装的 APK 路径
  ///
  /// 用于增量更新时作为基础文件
  Future<String?> getCurrentApkPath() async {
    try {
      if (!Platform.isAndroid) return null;

      final bspatch = BsPatchService();
      return await bspatch.getCurrentApkPath();
    } catch (e) {
      _logger.error('Failed to get current APK path: $e', tag: 'Upgrade');
      return null;
    }
  }

  /// 智能下载：优先使用增量更新，失败时回退到全量下载
  Future<DownloadResult> smartDownload(
    VersionInfo version, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    bool preferPatch = true,
  }) async {
    // 如果有增量更新包且用户偏好使用
    if (preferPatch && version.hasPatch) {
      final patch = version.patch!;
      _logger.info(
        'Attempting incremental update from ${patch.fromVersion}',
        tag: 'Upgrade',
      );

      // 检查是否支持增量更新
      final bspatch = BsPatchService();
      if (!bspatch.isSupported) {
        _logger.warning(
          'Platform does not support incremental updates',
          tag: 'Upgrade',
        );
      } else {
        // 下载补丁
        final patchResult = await downloadPatch(
          patch,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

        if (patchResult.isSuccess) {
          // 应用补丁（原生代码会自动获取当前 APK 路径）
          final newApk = await applyPatch(
            patchPath: patchResult.filePath!,
            targetVersion: version.versionName,
            expectedMd5: version.fileMd5,
          );

          if (newApk != null) {
            _logger.info('Incremental update successful', tag: 'Upgrade');
            return DownloadResult.success(newApk);
          }
        }

        _logger.warning(
          'Incremental update failed, falling back to full download',
          tag: 'Upgrade',
        );
      }
    }

    // 回退到全量下载
    return await downloadApk(
      version,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
