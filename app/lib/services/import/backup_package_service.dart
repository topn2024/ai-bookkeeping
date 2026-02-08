import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';
import '../gamification_service.dart';
import 'import_learning_service.dart';

/// 备份包服务
/// 设计文档第11章：批量导入导出 - 备份包格式
/// 支持完整数据打包导出和导入，包含交易、学习数据、习惯、位置等
class BackupPackageService {
  final IDatabaseService _db;
  final GamificationService _gamification;
  final ImportLearningService _learning;

  BackupPackageService({
    IDatabaseService? databaseService,
    GamificationService? gamificationService,
    ImportLearningService? learningService,
  })  : _db = databaseService ?? sl<IDatabaseService>(),
        _gamification = gamificationService ?? GamificationService(databaseService ?? sl<IDatabaseService>()),
        _learning = learningService ?? ImportLearningService(databaseService: databaseService ?? sl<IDatabaseService>());

  /// 创建完整备份包
  /// 返回备份包文件路径
  Future<BackupPackageResult> createBackupPackage({
    BackupPackageOptions? options,
    void Function(String stage, int progress, int total)? onProgress,
  }) async {
    final opts = options ?? BackupPackageOptions();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final packageId = 'backup_$timestamp';

    try {
      // 创建临时目录
      onProgress?.call('preparing', 0, 100);
      final tempDir = await getTemporaryDirectory();
      final packageDir = Directory('${tempDir.path}/$packageId');
      await packageDir.create(recursive: true);

      final packageData = <String, dynamic>{
        'metadata': {},
        'transactions': null,
        'learning': null,
        'habits': null,
        'locations': null,
      };

      // 1. 元数据
      onProgress?.call('metadata', 10, 100);
      packageData['metadata'] = {
        'version': '2.0',
        'packageId': packageId,
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': '2.0.0', // TODO: 从配置获取
        'deviceInfo': await _getDeviceInfo(),
        'options': opts.toJson(),
      };

      // 2. 交易数据
      if (opts.includeTransactions) {
        onProgress?.call('transactions', 20, 100);
        packageData['transactions'] = await _exportTransactions(opts);
      }

      // 3. 学习数据
      if (opts.includeLearningData) {
        onProgress?.call('learning', 40, 100);
        packageData['learning'] = await _learning.exportLearningData();
      }

      // 4. 习惯数据
      if (opts.includeHabits) {
        onProgress?.call('habits', 60, 100);
        packageData['habits'] = await _exportHabitsData();
      }

      // 5. 位置数据
      if (opts.includeLocations) {
        onProgress?.call('locations', 80, 100);
        packageData['locations'] = await _exportLocationData(opts);
      }

      // 6. 账本配置数据
      if (opts.includeBookSettings) {
        onProgress?.call('settings', 85, 100);
        packageData['bookSettings'] = await _exportBookSettings();
      }

      // 写入JSON文件
      onProgress?.call('writing', 90, 100);
      final jsonFile = File('${packageDir.path}/package.json');
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(packageData),
      );

      // 创建README
      final readmeFile = File('${packageDir.path}/README.txt');
      await readmeFile.writeAsString(_generateReadme(packageData));

      // 压缩为zip
      onProgress?.call('compressing', 95, 100);
      final outputDir = await getApplicationDocumentsDirectory();
      final zipPath = '${outputDir.path}/backups/$packageId.abpkg';

      // 确保备份目录存在
      await Directory('${outputDir.path}/backups').create(recursive: true);

      // 压缩
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addDirectory(packageDir);
      encoder.close();

      // 删除临时目录
      await packageDir.delete(recursive: true);

      onProgress?.call('completed', 100, 100);

      // 计算统计信息
      final stats = BackupStats(
        totalSize: await File(zipPath).length(),
        transactionCount: packageData['transactions']?['count'] ?? 0,
        learningRecords: packageData['learning']?['categoryLearning']?.length ?? 0,
        habitRecords: packageData['habits']?['achievements']?.length ?? 0,
        locationCount: packageData['locations']?['count'] ?? 0,
      );

      return BackupPackageResult(
        success: true,
        packagePath: zipPath,
        packageId: packageId,
        stats: stats,
      );
    } catch (e) {
      return BackupPackageResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 恢复备份包
  Future<RestoreResult> restoreBackupPackage(
    String packagePath, {
    RestoreOptions? options,
    void Function(String stage, int progress, int total)? onProgress,
  }) async {
    final opts = options ?? RestoreOptions();

    try {
      onProgress?.call('extracting', 0, 100);

      // 解压
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}');
      await extractDir.create(recursive: true);

      final bytes = await File(packagePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final extractPath = '${extractDir.path}/$filename';
          File(extractPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }

      // 读取package.json
      onProgress?.call('reading', 10, 100);
      final jsonFile = File('${extractDir.path}/package.json');
      final jsonContent = await jsonFile.readAsString();
      final packageData = json.decode(jsonContent) as Map<String, dynamic>;

      // 验证版本兼容性
      final version = packageData['metadata']?['version'] as String?;
      if (version == null || !_isVersionCompatible(version)) {
        throw Exception('备份包版本不兼容：$version');
      }

      final stats = RestoreStats(
        transactionRestored: 0,
        learningRestored: 0,
        habitsRestored: 0,
        locationsRestored: 0,
        errors: [],
      );

      // 恢复交易数据
      if (opts.restoreTransactions && packageData['transactions'] != null) {
        onProgress?.call('transactions', 20, 100);
        try {
          final count = await _restoreTransactions(packageData['transactions']);
          stats.transactionRestored = count;
        } catch (e) {
          stats.errors.add('恢复交易失败: $e');
        }
      }

      // 恢复学习数据
      if (opts.restoreLearningData && packageData['learning'] != null) {
        onProgress?.call('learning', 40, 100);
        try {
          await _learning.importLearningData(packageData['learning']);
          stats.learningRestored = (packageData['learning']['categoryLearning'] as List?)?.length ?? 0;
        } catch (e) {
          stats.errors.add('恢复学习数据失败: $e');
        }
      }

      // 恢复习惯数据
      if (opts.restoreHabits && packageData['habits'] != null) {
        onProgress?.call('habits', 60, 100);
        try {
          final count = await _restoreHabitsData(packageData['habits']);
          stats.habitsRestored = count;
        } catch (e) {
          stats.errors.add('恢复习惯数据失败: $e');
        }
      }

      // 恢复位置数据
      if (opts.restoreLocations && packageData['locations'] != null) {
        onProgress?.call('locations', 80, 100);
        try {
          final count = await _restoreLocationData(packageData['locations']);
          stats.locationsRestored = count;
        } catch (e) {
          stats.errors.add('恢复位置数据失败: $e');
        }
      }

      // 清理临时文件
      await extractDir.delete(recursive: true);

      onProgress?.call('completed', 100, 100);

      return RestoreResult(
        success: true,
        stats: stats,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        error: e.toString(),
        stats: RestoreStats(errors: [e.toString()]),
      );
    }
  }

  /// 导出交易数据
  Future<Map<String, dynamic>> _exportTransactions(BackupPackageOptions opts) async {
    final transactions = await _db.rawQuery('''
      SELECT * FROM transactions
      WHERE date >= ? AND date <= ?
      ORDER BY date DESC
    ''', [opts.startDate.millisecondsSinceEpoch, opts.endDate.millisecondsSinceEpoch]);

    return {
      'count': transactions.length,
      'data': transactions,
    };
  }

  /// 导出习惯数据
  Future<Map<String, dynamic>> _exportHabitsData() async {
    final achievements = await _gamification.getUnlockedAchievements();
    final streakStats = await _gamification.getStreakStats();
    final level = await _gamification.getUserLevel();

    return {
      'achievements': achievements.map((a) => {
        'achievementId': a.achievementId,
        'unlockedAt': a.unlockedAt.toIso8601String(),
        'progress': a.progress,
      }).toList(),
      'streakStats': {
        'currentStreak': streakStats.currentStreak,
        'longestStreak': streakStats.longestStreak,
        'totalDaysRecorded': streakStats.totalDaysRecorded,
      },
      'level': {
        'level': level.level,
        'currentPoints': level.currentPoints,
      },
    };
  }

  /// 导出位置数据
  Future<Map<String, dynamic>> _exportLocationData(BackupPackageOptions opts) async {
    final locations = await _db.rawQuery('''
      SELECT t.id, t.date, t.amount, t.category, t.note,
             tl.latitude, tl.longitude, tl.address, tl.poiName, tl.poiType
      FROM transactions t
      LEFT JOIN transaction_locations tl ON t.id = tl.transactionId
      WHERE tl.latitude IS NOT NULL
        AND t.date >= ? AND t.date <= ?
    ''', [opts.startDate.millisecondsSinceEpoch, opts.endDate.millisecondsSinceEpoch]);

    return {
      'count': locations.length,
      'data': locations,
    };
  }

  /// 导出账本设置
  Future<Map<String, dynamic>> _exportBookSettings() async {
    final categories = await _db.rawQuery('SELECT * FROM categories');
    final accounts = await _db.rawQuery('SELECT * FROM accounts');

    return {
      'categories': categories,
      'accounts': accounts,
    };
  }

  /// 恢复交易数据
  Future<int> _restoreTransactions(Map<String, dynamic> data) async {
    final transactions = data['data'] as List;
    for (final t in transactions) {
      await _db.rawInsert('''
        INSERT OR REPLACE INTO transactions
        (id, ledgerId, type, amount, category, subcategory, accountId,
         date, note, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        t['id'],
        t['ledgerId'],
        t['type'],
        t['amount'],
        t['category'],
        t['subcategory'],
        t['accountId'],
        t['date'],
        t['note'],
        t['createdAt'],
        t['updatedAt'],
      ]);
    }
    return transactions.length;
  }

  /// 恢复习惯数据
  Future<int> _restoreHabitsData(Map<String, dynamic> data) async {
    final achievements = data['achievements'] as List?;
    if (achievements != null) {
      for (final a in achievements) {
        await _db.rawInsert('''
          INSERT OR REPLACE INTO user_achievements
          (achievementId, unlockedAt, progress)
          VALUES (?, ?, ?)
        ''', [
          a['achievementId'],
          DateTime.parse(a['unlockedAt'] as String).millisecondsSinceEpoch,
          a['progress'],
        ]);
      }
      return achievements.length;
    }
    return 0;
  }

  /// 恢复位置数据
  Future<int> _restoreLocationData(Map<String, dynamic> data) async {
    final locations = data['data'] as List;
    for (final loc in locations) {
      await _db.rawInsert('''
        INSERT OR REPLACE INTO transaction_locations
        (transactionId, latitude, longitude, address, poiName, poiType)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        loc['id'],
        loc['latitude'],
        loc['longitude'],
        loc['address'],
        loc['poiName'],
        loc['poiType'],
      ]);
    }
    return locations.length;
  }

  /// 获取设备信息
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
    };
  }

  /// 生成README
  String _generateReadme(Map<String, dynamic> packageData) {
    final meta = packageData['metadata'] as Map<String, dynamic>;
    final buffer = StringBuffer();

    buffer.writeln('AI智能记账 - 备份包');
    buffer.writeln('=' * 50);
    buffer.writeln('');
    buffer.writeln('包ID: ${meta['packageId']}');
    buffer.writeln('创建时间: ${meta['createdAt']}');
    buffer.writeln('应用版本: ${meta['appVersion']}');
    buffer.writeln('');
    buffer.writeln('包含内容:');
    if (packageData['transactions'] != null) {
      buffer.writeln('- 交易记录: ${packageData['transactions']['count']} 笔');
    }
    if (packageData['learning'] != null) {
      buffer.writeln('- 学习数据: 已包含');
    }
    if (packageData['habits'] != null) {
      buffer.writeln('- 习惯数据: 已包含');
    }
    if (packageData['locations'] != null) {
      buffer.writeln('- 位置数据: ${packageData['locations']['count']} 条');
    }
    buffer.writeln('');
    buffer.writeln('恢复说明:');
    buffer.writeln('1. 在APP中选择"数据管理" > "恢复备份"');
    buffer.writeln('2. 选择此备份包文件(.abpkg)');
    buffer.writeln('3. 根据提示完成恢复');

    return buffer.toString();
  }

  /// 检查版本兼容性
  bool _isVersionCompatible(String version) {
    // 简单的版本检查，可以扩展
    return version.startsWith('2.') || version == '1.9';
  }

  /// 列出所有备份包
  Future<List<BackupPackageInfo>> listBackupPackages() async {
    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final backupsDir = Directory('${outputDir.path}/backups');

      if (!await backupsDir.exists()) {
        return [];
      }

      final packages = <BackupPackageInfo>[];

      await for (final file in backupsDir.list()) {
        if (file is File && file.path.endsWith('.abpkg')) {
          final stat = await file.stat();
          final fileName = file.path.split('/').last.split('\\').last;

          packages.add(BackupPackageInfo(
            fileName: fileName,
            filePath: file.path,
            fileSize: stat.size,
            createdAt: stat.modified,
          ));
        }
      }

      // 按时间倒序排列
      packages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return packages;
    } catch (e) {
      return [];
    }
  }

  /// 删除备份包
  Future<bool> deleteBackupPackage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// 备份包选项
class BackupPackageOptions {
  final bool includeTransactions;
  final bool includeLearningData;
  final bool includeHabits;
  final bool includeLocations;
  final bool includeBookSettings;
  final DateTime startDate;
  final DateTime endDate;

  BackupPackageOptions({
    this.includeTransactions = true,
    this.includeLearningData = true,
    this.includeHabits = true,
    this.includeLocations = true,
    this.includeBookSettings = true,
    DateTime? startDate,
    DateTime? endDate,
  })  : startDate = startDate ?? DateTime(2000),
        endDate = endDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'includeTransactions': includeTransactions,
        'includeLearningData': includeLearningData,
        'includeHabits': includeHabits,
        'includeLocations': includeLocations,
        'includeBookSettings': includeBookSettings,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
}

/// 恢复选项
class RestoreOptions {
  final bool restoreTransactions;
  final bool restoreLearningData;
  final bool restoreHabits;
  final bool restoreLocations;
  final bool restoreBookSettings;
  final bool mergeMode; // true: 合并，false: 覆盖

  RestoreOptions({
    this.restoreTransactions = true,
    this.restoreLearningData = true,
    this.restoreHabits = true,
    this.restoreLocations = true,
    this.restoreBookSettings = false,
    this.mergeMode = true,
  });
}

/// 备份结果
class BackupPackageResult {
  final bool success;
  final String? packagePath;
  final String? packageId;
  final BackupStats? stats;
  final String? error;

  BackupPackageResult({
    required this.success,
    this.packagePath,
    this.packageId,
    this.stats,
    this.error,
  });
}

/// 备份统计
class BackupStats {
  final int totalSize;
  final int transactionCount;
  final int learningRecords;
  final int habitRecords;
  final int locationCount;

  BackupStats({
    required this.totalSize,
    required this.transactionCount,
    required this.learningRecords,
    required this.habitRecords,
    required this.locationCount,
  });

  String get totalSizeDisplay {
    if (totalSize < 1024) {
      return '$totalSize B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// 恢复结果
class RestoreResult {
  final bool success;
  final RestoreStats stats;
  final String? error;

  RestoreResult({
    required this.success,
    required this.stats,
    this.error,
  });
}

/// 恢复统计
class RestoreStats {
  int transactionRestored;
  int learningRestored;
  int habitsRestored;
  int locationsRestored;
  List<String> errors;

  RestoreStats({
    this.transactionRestored = 0,
    this.learningRestored = 0,
    this.habitsRestored = 0,
    this.locationsRestored = 0,
    List<String>? errors,
  }) : errors = errors ?? [];
}

/// 备份包信息
class BackupPackageInfo {
  final String fileName;
  final String filePath;
  final int fileSize;
  final DateTime createdAt;

  BackupPackageInfo({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.createdAt,
  });

  String get fileSizeDisplay {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get createdAtDisplay {
    return DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
  }
}
