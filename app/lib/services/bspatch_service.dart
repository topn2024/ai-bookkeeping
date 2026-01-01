import 'dart:io';
import 'package:flutter/services.dart';
import '../core/logger.dart';

/// bspatch 补丁结果
class PatchResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;

  PatchResult._({
    required this.success,
    this.outputPath,
    this.errorMessage,
  });

  factory PatchResult.success(String outputPath) {
    return PatchResult._(success: true, outputPath: outputPath);
  }

  factory PatchResult.failure(String error) {
    return PatchResult._(success: false, errorMessage: error);
  }

  @override
  String toString() {
    if (success) {
      return 'PatchResult.success(outputPath: $outputPath)';
    } else {
      return 'PatchResult.failure(error: $errorMessage)';
    }
  }
}

/// bspatch 原生服务
///
/// 提供增量更新的补丁应用功能
class BsPatchService {
  static final BsPatchService _instance = BsPatchService._internal();
  factory BsPatchService() => _instance;
  BsPatchService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.example.ai_bookkeeping/bspatch');

  final Logger _logger = Logger();

  /// 检查平台是否支持 bspatch
  bool get isSupported => Platform.isAndroid;

  /// 获取当前安装的 APK 路径
  Future<String?> getCurrentApkPath() async {
    if (!isSupported) {
      _logger.warning('bspatch not supported on this platform', tag: 'BsPatch');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<String>('getCurrentApkPath');
      _logger.debug('Current APK path: $result', tag: 'BsPatch');
      return result;
    } on PlatformException catch (e) {
      _logger.error('Failed to get APK path: ${e.message}', tag: 'BsPatch');
      return null;
    } catch (e) {
      _logger.error('Unexpected error getting APK path: $e', tag: 'BsPatch');
      return null;
    }
  }

  /// 应用补丁文件
  ///
  /// [patchPath] 补丁文件路径
  /// [outputPath] 输出 APK 路径
  /// [expectedMd5] 预期的输出文件 MD5（可选，用于验证）
  Future<PatchResult> applyPatch({
    required String patchPath,
    required String outputPath,
    String? expectedMd5,
  }) async {
    if (!isSupported) {
      return PatchResult.failure('Platform not supported');
    }

    try {
      _logger.info(
        'Applying patch: $patchPath -> $outputPath',
        tag: 'BsPatch',
      );

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'applyPatch',
        {
          'patch': patchPath,
          'output': outputPath,
          'expectedMd5': expectedMd5,
        },
      );

      if (result == null) {
        return PatchResult.failure('No result from native code');
      }

      final success = result['success'] as bool? ?? false;
      if (success) {
        final outputPath = result['outputPath'] as String?;
        if (outputPath != null) {
          _logger.info('Patch applied successfully: $outputPath', tag: 'BsPatch');
          return PatchResult.success(outputPath);
        }
        return PatchResult.failure('Output path not returned');
      } else {
        final error = result['error'] as String? ?? 'Unknown error';
        _logger.error('Patch failed: $error', tag: 'BsPatch');
        return PatchResult.failure(error);
      }
    } on PlatformException catch (e) {
      _logger.error('Platform exception: ${e.message}', tag: 'BsPatch');
      return PatchResult.failure(e.message ?? 'Platform error');
    } catch (e) {
      _logger.error('Unexpected error: $e', tag: 'BsPatch');
      return PatchResult.failure('Unexpected error: $e');
    }
  }

  /// 计算文件 MD5
  Future<String?> calculateMd5(String filePath) async {
    if (!isSupported) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'calculateMd5',
        {'filePath': filePath},
      );
      return result;
    } on PlatformException catch (e) {
      _logger.error('Failed to calculate MD5: ${e.message}', tag: 'BsPatch');
      return null;
    } catch (e) {
      _logger.error('Unexpected error calculating MD5: $e', tag: 'BsPatch');
      return null;
    }
  }

  /// 完整的增量更新流程
  ///
  /// 1. 获取当前 APK 路径
  /// 2. 应用补丁
  /// 3. 验证 MD5
  /// 4. 返回新 APK 路径
  Future<PatchResult> performIncrementalUpdate({
    required String patchPath,
    required String targetVersion,
    String? expectedMd5,
    String? outputDir,
  }) async {
    if (!isSupported) {
      return PatchResult.failure('Incremental update not supported on this platform');
    }

    _logger.info(
      'Starting incremental update to $targetVersion',
      tag: 'BsPatch',
    );

    // 验证补丁文件存在
    final patchFile = File(patchPath);
    if (!await patchFile.exists()) {
      return PatchResult.failure('Patch file not found: $patchPath');
    }

    // 确定输出路径
    String outputPath;
    if (outputDir != null) {
      outputPath = '$outputDir/ai_bookkeeping_$targetVersion.apk';
    } else {
      // 使用补丁文件所在目录
      final patchDir = patchFile.parent.path;
      outputPath = '$patchDir/ai_bookkeeping_$targetVersion.apk';
    }

    // 删除已存在的输出文件
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    // 应用补丁
    return await applyPatch(
      patchPath: patchPath,
      outputPath: outputPath,
      expectedMd5: expectedMd5,
    );
  }
}
