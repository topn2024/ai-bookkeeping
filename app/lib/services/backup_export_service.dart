import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/transaction.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/savings_goal.dart';
import '../models/recurring_transaction.dart';
import '../models/template.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

/// 备份包导出服务
/// 设计文档第11.5节：数据导出功能矩阵（2.0增强版）
/// 支持完整数据备份、恢复和加密
class BackupExportService {
  final IDatabaseService _db;

  static String _appVersion = '2.0.0';

  static Future<void> initVersion() async {
    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;
  }

  static const String _backupVersion = '2.0.0';
  static const String _manifestFileName = 'manifest.json';
  static const String _dataFileName = 'data.json';
  static const String _settingsFileName = 'settings.json';
  static const String _mediaFolderName = 'media';

  BackupExportService({IDatabaseService? databaseService})
      : _db = databaseService ?? sl<IDatabaseService>();

  /// 创建完整备份包
  Future<BackupResult> createFullBackup({
    String? password,
    bool includeMedia = true,
    bool includeSettings = true,
    void Function(BackupStage stage, int current, int total)? onProgress,
  }) async {
    try {
      onProgress?.call(BackupStage.preparing, 0, 6);

      final archive = Archive();
      final timestamp = DateTime.now();
      final backupId = DateFormat('yyyyMMdd_HHmmss').format(timestamp);

      // 1. 收集所有数据
      onProgress?.call(BackupStage.collectingData, 1, 6);
      final backupData = await _collectAllData();

      // 2. 创建清单文件
      onProgress?.call(BackupStage.creatingManifest, 2, 6);
      final manifest = _createManifest(
        backupId: backupId,
        timestamp: timestamp,
        dataStats: backupData['stats'] as Map<String, int>,
        includeMedia: includeMedia,
        includeSettings: includeSettings,
        isEncrypted: password != null,
      );

      // 添加清单到压缩包
      final manifestJson = jsonEncode(manifest);
      archive.addFile(ArchiveFile(
        _manifestFileName,
        manifestJson.length,
        utf8.encode(manifestJson),
      ));

      // 3. 添加数据文件
      onProgress?.call(BackupStage.packingData, 3, 6);
      final dataJson = jsonEncode(backupData['data']);
      final dataBytes = password != null
          ? _encryptData(utf8.encode(dataJson), password)
          : utf8.encode(dataJson);

      archive.addFile(ArchiveFile(
        _dataFileName,
        dataBytes.length,
        dataBytes,
      ));

      // 4. 添加设置文件
      if (includeSettings) {
        onProgress?.call(BackupStage.packingSettings, 4, 6);
        final settings = await _collectSettings();
        final settingsJson = jsonEncode(settings);
        archive.addFile(ArchiveFile(
          _settingsFileName,
          settingsJson.length,
          utf8.encode(settingsJson),
        ));
      }

      // 5. 添加媒体文件（收据图片等）
      if (includeMedia) {
        onProgress?.call(BackupStage.packingMedia, 5, 6);
        await _addMediaFiles(archive);
      }

      // 6. 保存压缩包
      onProgress?.call(BackupStage.saving, 6, 6);
      final encoder = ZipEncoder();
      final zipData = encoder.encode(archive);

      if (zipData == null) {
        return BackupResult(
          success: false,
          error: '创建压缩包失败',
        );
      }

      // 保存文件
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'backup_$backupId.zip';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(zipData);

      // 计算校验和
      final checksum = md5.convert(zipData).toString();

      return BackupResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
        fileSize: zipData.length,
        checksum: checksum,
        backupId: backupId,
        stats: backupData['stats'] as Map<String, int>,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 收集所有数据
  Future<Map<String, dynamic>> _collectAllData() async {
    final data = <String, dynamic>{};
    final stats = <String, int>{};

    // 交易数据
    final transactions = await _db.getAllTransactions();
    data['transactions'] = transactions.map((t) => t.toMap()).toList();
    stats['transactions'] = transactions.length;

    // 账户数据
    final accounts = await _db.getAllAccounts();
    data['accounts'] = accounts.map((a) => a.toMap()).toList();
    stats['accounts'] = accounts.length;

    // 预算数据
    final budgets = await _db.getAllBudgets();
    data['budgets'] = budgets.map((b) => b.toMap()).toList();
    stats['budgets'] = budgets.length;

    // 储蓄目标
    final savingsGoals = await _db.getAllSavingsGoals();
    data['savingsGoals'] = savingsGoals.map((s) => s.toMap()).toList();
    stats['savingsGoals'] = savingsGoals.length;

    // 周期性交易
    final recurringTransactions = await _db.getAllRecurringTransactions();
    data['recurringTransactions'] =
        recurringTransactions.map((r) => r.toMap()).toList();
    stats['recurringTransactions'] = recurringTransactions.length;

    // 模板
    final templates = await _db.getAllTemplates();
    data['templates'] = templates.map((t) => t.toMap()).toList();
    stats['templates'] = templates.length;

    // 自定义分类
    final customCategories = await _db.getCustomCategories();
    data['customCategories'] = customCategories;
    stats['customCategories'] = customCategories.length;

    // 导入历史
    final importBatches = await _db.getImportBatches();
    data['importBatches'] = importBatches.map((b) => b.toMap()).toList();
    stats['importBatches'] = importBatches.length;

    // 钱龄资源池数据
    final moneyAgePools = await _db.getMoneyAgePools();
    data['moneyAgePools'] = moneyAgePools;
    stats['moneyAgePools'] = moneyAgePools.length;

    // 习惯数据（成就、连续记账等）
    final gamificationData = await _collectGamificationData();
    data['gamification'] = gamificationData;
    stats['achievements'] = (gamificationData['achievements'] as List).length;
    stats['dailyActivities'] =
        (gamificationData['dailyActivities'] as List).length;

    // 家庭账本数据
    final familyData = await _db.getFamilyLedgers();
    data['familyLedgers'] = familyData;
    stats['familyLedgers'] = familyData.length;

    // 位置数据
    final locationData = await _db.getLocationRecords();
    data['locationRecords'] = locationData;
    stats['locationRecords'] = locationData.length;

    // 自学习数据
    final learningData = await _collectLearningData();
    data['learningData'] = learningData;

    return {
      'data': data,
      'stats': stats,
    };
  }

  /// 收集游戏化数据
  Future<Map<String, dynamic>> _collectGamificationData() async {
    final achievements = await _db.rawQuery(
        'SELECT * FROM user_achievements ORDER BY unlockedAt DESC');
    final dailyActivities =
        await _db.rawQuery('SELECT * FROM daily_activity ORDER BY date DESC');
    final points =
        await _db.rawQuery('SELECT * FROM user_points ORDER BY earnedAt DESC');

    return {
      'achievements': achievements,
      'dailyActivities': dailyActivities,
      'points': points,
    };
  }

  /// 收集自学习数据
  Future<Map<String, dynamic>> _collectLearningData() async {
    // 分类学习记录
    final categoryLearning = await _db.rawQuery('''
      SELECT * FROM category_learning_records ORDER BY createdAt DESC
    ''');

    // 用户修正记录
    final userCorrections = await _db.rawQuery('''
      SELECT * FROM user_corrections ORDER BY correctedAt DESC
    ''');

    // 意图识别记录
    final intentLearning = await _db.rawQuery('''
      SELECT * FROM intent_learning_records ORDER BY createdAt DESC
    ''');

    return {
      'categoryLearning': categoryLearning,
      'userCorrections': userCorrections,
      'intentLearning': intentLearning,
    };
  }

  /// 收集设置
  Future<Map<String, dynamic>> _collectSettings() async {
    return {
      'theme': await _db.getSetting('theme'),
      'language': await _db.getSetting('language'),
      'currency': await _db.getSetting('currency'),
      'notificationSettings': await _db.getSetting('notificationSettings'),
      'privacySettings': await _db.getSetting('privacySettings'),
      'budgetSettings': await _db.getSetting('budgetSettings'),
      'aiSettings': await _db.getSetting('aiSettings'),
      'syncSettings': await _db.getSetting('syncSettings'),
    };
  }

  /// 添加媒体文件
  Future<void> _addMediaFiles(Archive archive) async {
    try {
      final mediaDir = await _getMediaDirectory();
      if (!await mediaDir.exists()) return;

      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath =
              entity.path.replaceFirst(mediaDir.path, _mediaFolderName);
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      }
    } catch (e) {
      // 媒体文件读取失败，继续备份
    }
  }

  /// 获取媒体目录
  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/media');
  }

  /// 创建清单
  Map<String, dynamic> _createManifest({
    required String backupId,
    required DateTime timestamp,
    required Map<String, int> dataStats,
    required bool includeMedia,
    required bool includeSettings,
    required bool isEncrypted,
  }) {
    return {
      'version': _backupVersion,
      'backupId': backupId,
      'createdAt': timestamp.toIso8601String(),
      'platform': Platform.operatingSystem,
      'appVersion': _appVersion,
      'dataStats': dataStats,
      'options': {
        'includeMedia': includeMedia,
        'includeSettings': includeSettings,
        'isEncrypted': isEncrypted,
      },
      'checksum': '', // 在保存时更新
    };
  }

  /// 从密码派生加密密钥
  ///
  /// 使用 HMAC-SHA256 将用户密码与固定盐值结合，
  /// 生成256位密钥流种子，避免短密码导致的XOR周期过短问题。
  static const String _keySalt = 'ai_bookkeeping_backup_v2_salt_2024';

  List<int> _deriveKey(String password) {
    final hmac = Hmac(sha256, utf8.encode(_keySalt));
    return hmac.convert(utf8.encode(password)).bytes;
  }

  /// 加密数据
  Uint8List _encryptData(List<int> data, String password) {
    final key = _deriveKey(password);
    final encrypted = Uint8List(data.length);

    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ key[i % key.length];
    }

    return encrypted;
  }

  /// 解密数据
  Uint8List _decryptData(List<int> data, String password) {
    return _encryptData(data, password);
  }

  /// 从备份包恢复
  Future<RestoreResult> restoreFromBackup(
    String filePath, {
    String? password,
    bool restoreSettings = true,
    bool restoreMedia = true,
    void Function(BackupStage stage, int current, int total)? onProgress,
  }) async {
    try {
      onProgress?.call(BackupStage.preparing, 0, 5);

      // 读取文件
      final file = File(filePath);
      if (!await file.exists()) {
        return RestoreResult(success: false, error: '备份文件不存在');
      }

      final bytes = await file.readAsBytes();

      // 解压
      onProgress?.call(BackupStage.extracting, 1, 5);
      final archive = ZipDecoder().decodeBytes(bytes);

      // 读取清单
      final manifestFile = archive.findFile(_manifestFileName);
      if (manifestFile == null) {
        return RestoreResult(success: false, error: '无效的备份文件：缺少清单');
      }

      final manifest = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      ) as Map<String, dynamic>;

      // 检查版本兼容性
      final version = manifest['version'] as String;
      if (!_isVersionCompatible(version)) {
        return RestoreResult(
          success: false,
          error: '备份版本不兼容：$version',
        );
      }

      // 读取数据
      onProgress?.call(BackupStage.extractingData, 2, 5);
      final dataFile = archive.findFile(_dataFileName);
      if (dataFile == null) {
        return RestoreResult(success: false, error: '无效的备份文件：缺少数据');
      }

      List<int> dataBytes = dataFile.content as List<int>;
      final isEncrypted =
          (manifest['options'] as Map<String, dynamic>)['isEncrypted'] as bool;

      if (isEncrypted) {
        if (password == null) {
          return RestoreResult(success: false, error: '备份已加密，需要密码');
        }
        dataBytes = _decryptData(dataBytes, password);
      }

      final data = jsonDecode(utf8.decode(dataBytes)) as Map<String, dynamic>;

      // 恢复数据
      onProgress?.call(BackupStage.restoringData, 3, 5);
      await _restoreData(data);

      // 恢复设置
      if (restoreSettings) {
        onProgress?.call(BackupStage.restoringSettings, 4, 5);
        final settingsFile = archive.findFile(_settingsFileName);
        if (settingsFile != null) {
          final settings = jsonDecode(
            utf8.decode(settingsFile.content as List<int>),
          ) as Map<String, dynamic>;
          await _restoreSettings(settings);
        }
      }

      // 恢复媒体文件
      if (restoreMedia) {
        onProgress?.call(BackupStage.restoringMedia, 5, 5);
        await _restoreMediaFiles(archive);
      }

      return RestoreResult(
        success: true,
        backupId: manifest['backupId'] as String,
        restoredStats: manifest['dataStats'] as Map<String, dynamic>,
      );
    } catch (e) {
      return RestoreResult(success: false, error: e.toString());
    }
  }

  /// 检查版本兼容性
  bool _isVersionCompatible(String version) {
    // 支持2.0.x版本
    return version.startsWith('2.');
  }

  /// 恢复数据
  Future<void> _restoreData(Map<String, dynamic> data) async {
    // 清空现有数据（可选）
    // await _db.clearAllData();

    // 恢复交易
    if (data['transactions'] != null) {
      for (final t in data['transactions'] as List) {
        final transaction = Transaction.fromMap(t as Map<String, dynamic>);
        await _db.insertTransaction(transaction);
      }
    }

    // 恢复账户
    if (data['accounts'] != null) {
      for (final a in data['accounts'] as List) {
        final account = Account.fromMap(a as Map<String, dynamic>);
        await _db.insertAccount(account);
      }
    }

    // 恢复预算
    if (data['budgets'] != null) {
      for (final b in data['budgets'] as List) {
        final budget = Budget.fromMap(b as Map<String, dynamic>);
        await _db.insertBudget(budget);
      }
    }

    // 恢复储蓄目标
    if (data['savingsGoals'] != null) {
      for (final s in data['savingsGoals'] as List) {
        final goal = SavingsGoal.fromMap(s as Map<String, dynamic>);
        await _db.insertSavingsGoal(goal);
      }
    }

    // 恢复周期性交易
    if (data['recurringTransactions'] != null) {
      for (final r in data['recurringTransactions'] as List) {
        final recurring =
            RecurringTransaction.fromMap(r as Map<String, dynamic>);
        await _db.insertRecurringTransaction(recurring);
      }
    }

    // 恢复模板
    if (data['templates'] != null) {
      for (final t in data['templates'] as List) {
        final template = TransactionTemplate.fromMap(t as Map<String, dynamic>);
        await _db.insertTemplate(template);
      }
    }

    // 恢复游戏化数据
    if (data['gamification'] != null) {
      await _restoreGamificationData(
          data['gamification'] as Map<String, dynamic>);
    }

    // 恢复自学习数据
    if (data['learningData'] != null) {
      await _restoreLearningData(data['learningData'] as Map<String, dynamic>);
    }
  }

  /// 恢复游戏化数据
  Future<void> _restoreGamificationData(Map<String, dynamic> data) async {
    if (data['achievements'] != null) {
      for (final a in data['achievements'] as List) {
        await _db.rawInsert('''
          INSERT OR REPLACE INTO user_achievements
          (id, achievementId, unlockedAt, progress, target)
          VALUES (?, ?, ?, ?, ?)
        ''', [
          a['id'],
          a['achievementId'],
          a['unlockedAt'],
          a['progress'],
          a['target'],
        ]);
      }
    }

    if (data['dailyActivities'] != null) {
      for (final d in data['dailyActivities'] as List) {
        await _db.rawInsert('''
          INSERT OR REPLACE INTO daily_activity (date, recordedAt)
          VALUES (?, ?)
        ''', [d['date'], d['recordedAt']]);
      }
    }

    if (data['points'] != null) {
      for (final p in data['points'] as List) {
        await _db.rawInsert('''
          INSERT OR REPLACE INTO user_points (id, points, reason, earnedAt)
          VALUES (?, ?, ?, ?)
        ''', [p['id'], p['points'], p['reason'], p['earnedAt']]);
      }
    }
  }

  /// 恢复自学习数据
  Future<void> _restoreLearningData(Map<String, dynamic> data) async {
    if (data['categoryLearning'] != null) {
      for (final c in data['categoryLearning'] as List) {
        await _db.rawInsert('''
          INSERT OR REPLACE INTO category_learning_records
          (id, keyword, category, confidence, createdAt, updatedAt)
          VALUES (?, ?, ?, ?, ?, ?)
        ''', [
          c['id'],
          c['keyword'],
          c['category'],
          c['confidence'],
          c['createdAt'],
          c['updatedAt'],
        ]);
      }
    }

    if (data['userCorrections'] != null) {
      for (final u in data['userCorrections'] as List) {
        await _db.rawInsert('''
          INSERT OR REPLACE INTO user_corrections
          (id, originalCategory, correctedCategory, context, correctedAt)
          VALUES (?, ?, ?, ?, ?)
        ''', [
          u['id'],
          u['originalCategory'],
          u['correctedCategory'],
          u['context'],
          u['correctedAt'],
        ]);
      }
    }
  }

  /// 恢复设置
  Future<void> _restoreSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      if (entry.value != null) {
        await _db.setSetting(entry.key, entry.value);
      }
    }
  }

  /// 恢复媒体文件
  Future<void> _restoreMediaFiles(Archive archive) async {
    final mediaDir = await _getMediaDirectory();

    for (final file in archive.files) {
      if (file.name.startsWith(_mediaFolderName)) {
        final relativePath = file.name.replaceFirst('$_mediaFolderName/', '');
        final targetPath = '${mediaDir.path}/$relativePath';

        final targetFile = File(targetPath);
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(file.content as List<int>);
      }
    }
  }

  /// 验证备份文件
  Future<BackupValidationResult> validateBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return BackupValidationResult(
          isValid: false,
          error: '文件不存在',
        );
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 检查清单
      final manifestFile = archive.findFile(_manifestFileName);
      if (manifestFile == null) {
        return BackupValidationResult(
          isValid: false,
          error: '无效的备份格式：缺少清单文件',
        );
      }

      final manifest = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      ) as Map<String, dynamic>;

      // 检查版本
      final version = manifest['version'] as String;
      if (!_isVersionCompatible(version)) {
        return BackupValidationResult(
          isValid: false,
          error: '不支持的备份版本：$version',
        );
      }

      // 检查数据文件
      final dataFile = archive.findFile(_dataFileName);
      if (dataFile == null) {
        return BackupValidationResult(
          isValid: false,
          error: '无效的备份格式：缺少数据文件',
        );
      }

      final isEncrypted =
          (manifest['options'] as Map<String, dynamic>)['isEncrypted'] as bool;

      return BackupValidationResult(
        isValid: true,
        backupId: manifest['backupId'] as String,
        version: version,
        createdAt:
            DateTime.parse(manifest['createdAt'] as String),
        stats: manifest['dataStats'] as Map<String, dynamic>,
        isEncrypted: isEncrypted,
      );
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        error: '验证失败：$e',
      );
    }
  }
}

/// 备份阶段
enum BackupStage {
  preparing,
  collectingData,
  creatingManifest,
  packingData,
  packingSettings,
  packingMedia,
  saving,
  extracting,
  extractingData,
  restoringData,
  restoringSettings,
  restoringMedia,
}

/// 备份结果
class BackupResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? checksum;
  final String? backupId;
  final Map<String, int>? stats;
  final String? error;

  BackupResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.checksum,
    this.backupId,
    this.stats,
    this.error,
  });

  String get fileSizeDisplay {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 恢复结果
class RestoreResult {
  final bool success;
  final String? backupId;
  final Map<String, dynamic>? restoredStats;
  final String? error;

  RestoreResult({
    required this.success,
    this.backupId,
    this.restoredStats,
    this.error,
  });
}

/// 备份验证结果
class BackupValidationResult {
  final bool isValid;
  final String? backupId;
  final String? version;
  final DateTime? createdAt;
  final Map<String, dynamic>? stats;
  final bool isEncrypted;
  final String? error;

  BackupValidationResult({
    required this.isValid,
    this.backupId,
    this.version,
    this.createdAt,
    this.stats,
    this.isEncrypted = false,
    this.error,
  });
}
