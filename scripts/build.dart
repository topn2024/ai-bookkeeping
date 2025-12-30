/// 构建脚本 - 自动更新版本号和编译时间
/// 使用方法: dart run scripts/build.dart [patch|minor|major]
///
/// patch: 1.1.0 -> 1.1.1 (修复bug)
/// minor: 1.1.0 -> 1.2.0 (新功能)
/// major: 1.1.0 -> 2.0.0 (重大更新)

import 'dart:io';

void main(List<String> args) async {
  final versionType = args.isNotEmpty ? args[0] : 'patch';

  print('=== AI智能记账 构建脚本 ===\n');

  // 1. 读取当前版本号
  final pubspecFile = File('app/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('错误: 找不到 app/pubspec.yaml');
    print('请在项目根目录运行此脚本');
    exit(1);
  }

  var pubspecContent = pubspecFile.readAsStringSync();
  final versionMatch = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)').firstMatch(pubspecContent);

  if (versionMatch == null) {
    print('错误: 无法解析版本号');
    exit(1);
  }

  var major = int.parse(versionMatch.group(1)!);
  var minor = int.parse(versionMatch.group(2)!);
  var patch = int.parse(versionMatch.group(3)!);
  var buildNumber = int.parse(versionMatch.group(4)!);

  final oldVersion = '$major.$minor.$patch+$buildNumber';
  print('当前版本: $oldVersion');

  // 2. 更新版本号
  switch (versionType) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
      break;
    case 'minor':
      minor++;
      patch = 0;
      break;
    case 'patch':
    default:
      patch++;
      break;
  }
  buildNumber++;

  final newVersion = '$major.$minor.$patch+$buildNumber';
  print('新版本: $newVersion ($versionType 更新)\n');

  // 3. 更新 pubspec.yaml
  pubspecContent = pubspecContent.replaceFirst(
    RegExp(r'version:\s*\d+\.\d+\.\d+\+\d+'),
    'version: $newVersion',
  );
  pubspecFile.writeAsStringSync(pubspecContent);
  print('✓ 已更新 pubspec.yaml');

  // 4. 生成编译时间信息
  final now = DateTime.now();
  final buildTime = now.toIso8601String();
  final buildTimeFormatted = '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';

  final buildInfoContent = '''
/// 自动生成的构建信息 - 请勿手动修改
/// 生成时间: $buildTimeFormatted

class BuildInfo {
  /// 构建时间 (ISO 8601)
  static const String buildTime = '$buildTime';

  /// 构建时间 (格式化显示)
  static const String buildTimeFormatted = '$buildTimeFormatted';

  /// 版本号
  static const String version = '$major.$minor.$patch';

  /// 构建号
  static const int buildNumber = $buildNumber;

  /// 完整版本
  static const String fullVersion = '$newVersion';
}
''';

  final buildInfoFile = File('app/lib/core/build_info.dart');
  buildInfoFile.writeAsStringSync(buildInfoContent);
  print('✓ 已生成 build_info.dart');

  // 5. 读取构建配置
  final buildConfig = _loadBuildConfig();

  print('\n=== 构建信息 ===');
  print('版本: $newVersion');
  print('编译时间: $buildTimeFormatted');
  print('API配置: ${buildConfig['QWEN_API_KEY'] != null ? '已配置' : '未配置'}');
  print('\n准备构建APK...\n');

  // 6. 构建APK
  final dartDefines = <String>[];
  if (buildConfig['QWEN_API_KEY'] != null) {
    dartDefines.add('--dart-define=QWEN_API_KEY=${buildConfig['QWEN_API_KEY']}');
  }
  if (buildConfig['API_BASE_URL'] != null) {
    dartDefines.add('--dart-define=API_BASE_URL=${buildConfig['API_BASE_URL']}');
  }
  if (buildConfig['ZHIPU_API_KEY'] != null) {
    dartDefines.add('--dart-define=ZHIPU_API_KEY=${buildConfig['ZHIPU_API_KEY']}');
  }

  final result = await Process.run(
    'D:/flutter/bin/flutter.bat',
    ['build', 'apk', '--debug', ...dartDefines],
    workingDirectory: 'app',
    runInShell: true,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode == 0) {
    print('\n=== 构建成功 ===');
    print('APK路径: app/build/app/outputs/flutter-apk/app-debug.apk');
    print('版本: $newVersion');
    print('编译时间: $buildTimeFormatted');
  } else {
    print('\n=== 构建失败 ===');
    exit(1);
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// 加载构建配置
/// 优先从 scripts/build.env 读取，如果不存在则从环境变量读取
Map<String, String?> _loadBuildConfig() {
  final config = <String, String?>{};

  // 尝试从 build.env 文件读取
  final envFile = File('scripts/build.env');
  if (envFile.existsSync()) {
    print('✓ 从 scripts/build.env 读取配置');
    final lines = envFile.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        config[key] = value;
      }
    }
  } else {
    print('! scripts/build.env 不存在，使用环境变量');
    // 从环境变量读取
    config['QWEN_API_KEY'] = Platform.environment['QWEN_API_KEY'];
    config['API_BASE_URL'] = Platform.environment['API_BASE_URL'];
    config['ZHIPU_API_KEY'] = Platform.environment['ZHIPU_API_KEY'];
  }

  return config;
}
