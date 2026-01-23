/// 构建信息更新脚本
///
/// 在构建前运行此脚本，自动更新 build_info.dart 中的构建时间
///
/// 使用方式:
///   dart run scripts/update_build_info.dart
///   dart run scripts/update_build_info.dart --version=2.1.0 --build-number=52

import 'dart:io';

void main(List<String> args) {
  // 解析命令行参数
  String? version;
  int? buildNumber;
  String buildType = 'Debug';

  for (final arg in args) {
    if (arg.startsWith('--version=')) {
      version = arg.substring('--version='.length);
    } else if (arg.startsWith('--build-number=')) {
      buildNumber = int.tryParse(arg.substring('--build-number='.length));
    } else if (arg.startsWith('--build-type=')) {
      buildType = arg.substring('--build-type='.length);
    }
  }

  // 读取现有配置（如果未指定参数）
  final existingFile = File('lib/core/build_info.dart');
  if (existingFile.existsSync()) {
    final content = existingFile.readAsStringSync();

    if (version == null) {
      final versionMatch = RegExp(r"version = '([^']+)'").firstMatch(content);
      version = versionMatch?.group(1) ?? '1.0.0';
    }

    if (buildNumber == null) {
      final buildNumberMatch = RegExp(r'buildNumber = (\d+)').firstMatch(content);
      buildNumber = int.tryParse(buildNumberMatch?.group(1) ?? '1') ?? 1;
    }
  }

  version ??= '1.0.0';
  buildNumber ??= 1;

  // 获取当前时间
  final now = DateTime.now();
  final isoTime = now.toIso8601String();
  final formatted = '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  final fullVersion = '$version+$buildNumber';

  // 生成文件内容
  final content = '''/// 自动生成的构建信息 - 请勿手动修改
/// 生成时间: $formatted

class BuildInfo {
  /// 构建时间 (ISO 8601)
  static const String buildTime = '$isoTime';

  /// 构建时间 (格式化显示)
  static const String buildTimeFormatted = '$formatted';

  /// 版本号
  static const String version = '$version';

  /// 构建号
  static const int buildNumber = $buildNumber;

  /// 完整版本
  static const String fullVersion = '$fullVersion';

  /// 构建类型 (Debug/Release)
  static const String buildType = '$buildType';

  /// 带类型的完整版本号
  static const String displayVersion = '$version';
}
''';

  // 写入文件
  existingFile.writeAsStringSync(content);

  print('Build info updated:');
  print('  Version: $version');
  print('  Build Number: $buildNumber');
  print('  Build Type: $buildType');
  print('  Build Time: $formatted');
}
