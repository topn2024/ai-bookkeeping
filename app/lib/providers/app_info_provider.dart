import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/build_info.dart';

/// App information state
class AppInfo {
  final String version;
  final String buildNumber;
  final String appName;
  final String packageName;
  final String buildTime;

  const AppInfo({
    required this.version,
    required this.buildNumber,
    required this.appName,
    required this.packageName,
    required this.buildTime,
  });

  /// Get full version string (e.g., "1.1.0+2")
  String get fullVersion => '$version+$buildNumber';

  /// Get display version (e.g., "v1.1.0 (Build 2)")
  String get displayVersion => 'v$version (Build $buildNumber)';

  /// Default empty state
  static const AppInfo empty = AppInfo(
    version: '...',
    buildNumber: '...',
    appName: 'AI智能记账',
    packageName: '',
    buildTime: '',
  );
}

/// Provider for app information
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return AppInfo(
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
    appName: packageInfo.appName,
    packageName: packageInfo.packageName,
    buildTime: BuildInfo.buildTimeFormatted,
  );
});

/// Synchronous provider that returns cached value or empty state
final appInfoSyncProvider = Provider<AppInfo>((ref) {
  final asyncValue = ref.watch(appInfoProvider);
  return asyncValue.when(
    data: (info) => info,
    loading: () => AppInfo.empty,
    error: (_, _) => AppInfo.empty,
  );
});
