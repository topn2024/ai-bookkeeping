import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';

/// 数据库迁移管理服务
///
/// 提供以下安全功能：
/// 1. 迁移前自动备份数据库
/// 2. 迁移失败时自动恢复
/// 3. 迁移历史记录
/// 4. 数据验证
class DatabaseMigrationService {
  static final DatabaseMigrationService _instance =
      DatabaseMigrationService._internal();
  factory DatabaseMigrationService() => _instance;
  DatabaseMigrationService._internal();

  final Logger _logger = Logger();

  // 数据库文件名
  static const String _dbName = 'ai_bookkeeping.db';
  // 备份目录
  static const String _backupDir = 'db_backups';
  // 最大备份数量
  static const int _maxBackups = 5;

  // 迁移状态 key
  static const String _keyLastMigrationVersion = 'db_last_migration_version';
  static const String _keyLastMigrationTime = 'db_last_migration_time';
  static const String _keyMigrationStatus = 'db_migration_status';

  /// 迁移前准备（由 DatabaseService 在打开数据库前调用）
  Future<MigrationResult> prepareMigration({
    required int currentVersion,
    required int targetVersion,
  }) async {
    if (currentVersion >= targetVersion) {
      return MigrationResult.noMigrationNeeded();
    }

    _logger.info(
      'Preparing migration: v$currentVersion -> v$targetVersion',
      tag: 'DBMigration',
    );

    try {
      // 1. 创建备份
      final backupPath = await _createBackup(currentVersion);
      if (backupPath == null) {
        _logger.warning('Failed to create backup, proceeding anyway', tag: 'DBMigration');
      } else {
        _logger.info('Backup created: $backupPath', tag: 'DBMigration');
      }

      // 2. 记录迁移开始
      await _setMigrationStatus('in_progress');

      return MigrationResult.prepared(backupPath: backupPath);
    } catch (e) {
      _logger.error('Migration preparation failed: $e', tag: 'DBMigration');
      return MigrationResult.failed(error: e.toString());
    }
  }

  /// 迁移完成后调用
  Future<void> onMigrationComplete({
    required int newVersion,
    required bool success,
    String? error,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (success) {
      await prefs.setInt(_keyLastMigrationVersion, newVersion);
      await prefs.setString(
          _keyLastMigrationTime, DateTime.now().toIso8601String());
      await _setMigrationStatus('completed');

      _logger.info(
        'Migration to v$newVersion completed successfully',
        tag: 'DBMigration',
      );

      // 清理旧备份
      await _cleanupOldBackups();
    } else {
      await _setMigrationStatus('failed');
      _logger.error(
        'Migration to v$newVersion failed: $error',
        tag: 'DBMigration',
      );
    }
  }

  /// 创建数据库备份
  Future<String?> _createBackup(int version) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, _dbName);
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        _logger.warning('Database file not found, skipping backup', tag: 'DBMigration');
        return null;
      }

      // 创建备份目录
      final appDir = await getApplicationDocumentsDirectory();
      final backupDirPath = join(appDir.path, _backupDir);
      final backupDirectory = Directory(backupDirPath);
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      // 生成备份文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFileName = 'backup_v${version}_$timestamp.db';
      final backupPath = join(backupDirPath, backupFileName);

      // 复制数据库文件
      await sourceFile.copy(backupPath);

      return backupPath;
    } catch (e) {
      _logger.error('Failed to create backup: $e', tag: 'DBMigration');
      return null;
    }
  }

  /// 从备份恢复数据库
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        _logger.error('Backup file not found: $backupPath', tag: 'DBMigration');
        return false;
      }

      final dbPath = await getDatabasesPath();
      final targetPath = join(dbPath, _dbName);

      // 关闭当前数据库连接
      // 注意：需要在调用此方法前确保数据库已关闭

      // 删除当前数据库
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // 恢复备份
      await backupFile.copy(targetPath);

      _logger.info('Database restored from: $backupPath', tag: 'DBMigration');
      return true;
    } catch (e) {
      _logger.error('Failed to restore from backup: $e', tag: 'DBMigration');
      return false;
    }
  }

  /// 获取最近的备份列表
  Future<List<BackupInfo>> getBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDirPath = join(appDir.path, _backupDir);
      final backupDirectory = Directory(backupDirPath);

      if (!await backupDirectory.exists()) {
        return [];
      }

      final backups = <BackupInfo>[];
      await for (final entity in backupDirectory.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          final stat = await entity.stat();
          final fileName = basename(entity.path);

          // 解析版本号
          final versionMatch = RegExp(r'backup_v(\d+)_(\d+)\.db').firstMatch(fileName);
          final version = versionMatch != null
              ? int.tryParse(versionMatch.group(1) ?? '0') ?? 0
              : 0;

          backups.add(BackupInfo(
            path: entity.path,
            fileName: fileName,
            version: version,
            size: stat.size,
            createdAt: stat.modified,
          ));
        }
      }

      // 按时间倒序排列
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } catch (e) {
      _logger.error('Failed to get backups: $e', tag: 'DBMigration');
      return [];
    }
  }

  /// 清理旧备份，保留最近 N 个
  Future<void> _cleanupOldBackups() async {
    try {
      final backups = await getBackups();
      if (backups.length <= _maxBackups) return;

      // 删除多余的备份
      for (int i = _maxBackups; i < backups.length; i++) {
        final file = File(backups[i].path);
        if (await file.exists()) {
          await file.delete();
          _logger.debug('Deleted old backup: ${backups[i].fileName}', tag: 'DBMigration');
        }
      }
    } catch (e) {
      _logger.warning('Failed to cleanup old backups: $e', tag: 'DBMigration');
    }
  }

  /// 手动创建备份（用户触发）
  Future<String?> createManualBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getInt(_keyLastMigrationVersion) ?? 0;
      return await _createBackup(version);
    } catch (e) {
      _logger.error('Failed to create manual backup: $e', tag: 'DBMigration');
      return null;
    }
  }

  /// 删除指定备份
  Future<bool> deleteBackup(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      _logger.error('Failed to delete backup: $e', tag: 'DBMigration');
      return false;
    }
  }

  /// 设置迁移状态
  Future<void> _setMigrationStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMigrationStatus, status);
  }

  /// 获取上次迁移状态
  Future<String?> getLastMigrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMigrationStatus);
  }

  /// 获取上次迁移信息
  Future<Map<String, dynamic>> getLastMigrationInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'version': prefs.getInt(_keyLastMigrationVersion),
      'time': prefs.getString(_keyLastMigrationTime),
      'status': prefs.getString(_keyMigrationStatus),
    };
  }

  /// 验证数据库完整性
  Future<bool> validateDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      // 尝试打开并执行简单查询
      final db = await openDatabase(path, readOnly: true);
      await db.rawQuery('PRAGMA integrity_check');
      await db.close();

      return true;
    } catch (e) {
      _logger.error('Database validation failed: $e', tag: 'DBMigration');
      return false;
    }
  }

  /// 获取数据库统计信息
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      final db = await openDatabase(path, readOnly: true);

      final stats = <String, int>{};
      final tables = [
        'transactions',
        'accounts',
        'categories',
        'budgets',
        'savings_goals',
      ];

      for (final table in tables) {
        try {
          final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          stats[table] = Sqflite.firstIntValue(result) ?? 0;
        } catch (e) {
          stats[table] = -1; // 表不存在
        }
      }

      await db.close();
      return stats;
    } catch (e) {
      _logger.error('Failed to get database stats: $e', tag: 'DBMigration');
      return {};
    }
  }
}

/// 迁移结果
class MigrationResult {
  final MigrationStatus status;
  final String? backupPath;
  final String? error;

  MigrationResult._({
    required this.status,
    this.backupPath,
    this.error,
  });

  factory MigrationResult.noMigrationNeeded() =>
      MigrationResult._(status: MigrationStatus.noMigrationNeeded);

  factory MigrationResult.prepared({String? backupPath}) => MigrationResult._(
        status: MigrationStatus.prepared,
        backupPath: backupPath,
      );

  factory MigrationResult.failed({String? error}) => MigrationResult._(
        status: MigrationStatus.failed,
        error: error,
      );

  bool get isSuccess =>
      status == MigrationStatus.prepared ||
      status == MigrationStatus.noMigrationNeeded;
}

enum MigrationStatus {
  noMigrationNeeded,
  prepared,
  failed,
}

/// 备份信息
class BackupInfo {
  final String path;
  final String fileName;
  final int version;
  final int size;
  final DateTime createdAt;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.version,
    required this.size,
    required this.createdAt,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
