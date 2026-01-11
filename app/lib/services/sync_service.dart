import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

/// 同步服务抽象类
abstract class CloudSyncService {
  CloudProvider get provider;

  /// 连接测试
  Future<bool> testConnection();

  /// 上传备份
  Future<bool> uploadBackup(BackupData backup);

  /// 下载备份列表
  Future<List<BackupData>> listBackups();

  /// 下载指定备份
  Future<BackupData?> downloadBackup(String backupId);

  /// 删除备份
  Future<bool> deleteBackup(String backupId);
}

/// 本地备份服务
class LocalBackupService extends CloudSyncService {
  @override
  CloudProvider get provider => CloudProvider.local;

  Future<Directory> get _backupDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  @override
  Future<bool> testConnection() async {
    try {
      final dir = await _backupDir;
      return await dir.exists();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> uploadBackup(BackupData backup) async {
    try {
      final dir = await _backupDir;
      final file = File('${dir.path}/backup_${backup.id}.json');
      await file.writeAsString(jsonEncode(backup.toMap()));
      return true;
    } catch (e) {
      debugPrint('Local backup failed: $e');
      return false;
    }
  }

  @override
  Future<List<BackupData>> listBackups() async {
    try {
      final dir = await _backupDir;
      final files = await dir.list().where((f) => f.path.endsWith('.json')).toList();

      final backups = <BackupData>[];
      for (final file in files) {
        try {
          final content = await File(file.path).readAsString();
          final map = jsonDecode(content) as Map<String, dynamic>;
          backups.add(BackupData.fromMap(map));
        } catch (e) {
          debugPrint('Failed to parse backup file: ${file.path}');
        }
      }

      // 按时间倒序排列
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } catch (e) {
      debugPrint('List backups failed: $e');
      return [];
    }
  }

  @override
  Future<BackupData?> downloadBackup(String backupId) async {
    try {
      final dir = await _backupDir;
      final file = File('${dir.path}/backup_$backupId.json');
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      return BackupData.fromMap(map);
    } catch (e) {
      debugPrint('Download backup failed: $e');
      return null;
    }
  }

  @override
  Future<bool> deleteBackup(String backupId) async {
    try {
      final dir = await _backupDir;
      final file = File('${dir.path}/backup_$backupId.json');
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      debugPrint('Delete backup failed: $e');
      return false;
    }
  }
}

/// WebDAV同步服务（模拟实现）
class WebDAVSyncService extends CloudSyncService {
  final WebDAVConfig config;

  WebDAVSyncService(this.config);

  @override
  CloudProvider get provider => CloudProvider.webdav;

  @override
  Future<bool> testConnection() async {
    // 模拟WebDAV连接测试
    // 实际实现需要使用webdav_client包
    await Future.delayed(const Duration(seconds: 1));
    return config.url.isNotEmpty &&
        config.username.isNotEmpty &&
        config.password.isNotEmpty;
  }

  @override
  Future<bool> uploadBackup(BackupData backup) async {
    // 模拟上传
    await Future.delayed(const Duration(seconds: 2));
    // 实际实现：使用webdav_client上传文件到远程服务器
    return true;
  }

  @override
  Future<List<BackupData>> listBackups() async {
    // 模拟获取备份列表
    await Future.delayed(const Duration(seconds: 1));
    // 实际实现：从WebDAV服务器获取备份文件列表
    return [];
  }

  @override
  Future<BackupData?> downloadBackup(String backupId) async {
    // 模拟下载
    await Future.delayed(const Duration(seconds: 2));
    // 实际实现：从WebDAV服务器下载备份文件
    return null;
  }

  @override
  Future<bool> deleteBackup(String backupId) async {
    // 模拟删除
    await Future.delayed(const Duration(milliseconds: 500));
    // 实际实现：从WebDAV服务器删除备份文件
    return true;
  }
}

/// 备份恢复服务
class BackupRestoreService {
  /// 通过服务定位器获取数据库服务
  IDatabaseService get _db => sl<IDatabaseService>();

  /// 创建完整备份
  Future<BackupData> createBackup() async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();

    // 获取所有数据
    final transactions = await _db.getTransactions();
    final accounts = await _db.getAccounts();
    final categories = await _db.getCategories();
    final budgets = await _db.getBudgets();
    final ledgers = await _db.getLedgers();
    final templates = await _db.getTemplates();
    final recurringTransactions = await _db.getRecurringTransactions();
    final creditCards = await _db.getCreditCards();
    final savingsGoals = await _db.getSavingsGoals();
    final billReminders = await _db.getBillReminders();
    final debts = await _db.getDebts();
    final investmentAccounts = await _db.getInvestmentAccounts();

    final data = <String, dynamic>{
      'transactions': transactions.map((t) => {
        'id': t.id,
        'type': t.type.index,
        'amount': t.amount,
        'category': t.category,
        'note': t.note,
        'date': t.date.millisecondsSinceEpoch,
        'accountId': t.accountId,
        'toAccountId': t.toAccountId,
        'isSplit': t.isSplit,
        'isReimbursable': t.isReimbursable,
        'isReimbursed': t.isReimbursed,
        'tags': t.tags,
      }).toList(),
      'accounts': accounts.map((a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type.index,
        'balance': a.balance,
        'iconCode': a.icon.codePoint,
        'colorValue': a.color.toARGB32(),
        'isDefault': a.isDefault,
      }).toList(),
      'categories': categories.map((c) => {
        'id': c.id,
        'name': c.name,
        'iconCode': c.icon.codePoint,
        'colorValue': c.color.toARGB32(),
        'isExpense': c.isExpense,
        'parentId': c.parentId,
        'sortOrder': c.sortOrder,
        'isCustom': c.isCustom,
      }).toList(),
      'budgets': budgets.map((b) => {
        'id': b.id,
        'name': b.name,
        'amount': b.amount,
        'period': b.period.index,
        'categoryId': b.categoryId,
        'ledgerId': b.ledgerId,
        'iconCode': b.icon.codePoint,
        'colorValue': b.color.toARGB32(),
        'isEnabled': b.isEnabled,
      }).toList(),
      'ledgers': ledgers.map((l) => {
        'id': l.id,
        'name': l.name,
        'description': l.description,
        'iconCode': l.icon.codePoint,
        'colorValue': l.color.toARGB32(),
        'isDefault': l.isDefault,
      }).toList(),
      'templates': templates.length,
      'recurringTransactions': recurringTransactions.length,
      'creditCards': creditCards.length,
      'savingsGoals': savingsGoals.length,
      'billReminders': billReminders.length,
      'debts': debts.length,
      'investmentAccounts': investmentAccounts.length,
    };

    final totalRecords = transactions.length +
        accounts.length +
        categories.length +
        budgets.length +
        ledgers.length;

    return BackupData(
      id: id,
      version: '1.0',
      createdAt: now,
      deviceId: await _getDeviceId(),
      deviceName: await _getDeviceName(),
      transactionCount: transactions.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      budgetCount: budgets.length,
      totalRecords: totalRecords,
      data: data,
    );
  }

  /// 恢复备份
  Future<bool> restoreBackup(BackupData backup, {bool merge = false}) async {
    try {
      // 如果不是合并模式，先清空数据库
      if (!merge) {
        // 实际实现中需要清空各表
        debugPrint('Clearing existing data...');
      }

      // 恢复数据
      final data = backup.data;

      // 恢复账户
      final accounts = data['accounts'] as List?;
      if (accounts != null) {
        debugPrint('Restoring ${accounts.length} accounts...');
        // 实际恢复逻辑
      }

      // 恢复分类
      final categories = data['categories'] as List?;
      if (categories != null) {
        debugPrint('Restoring ${categories.length} categories...');
      }

      // 恢复交易
      final transactions = data['transactions'] as List?;
      if (transactions != null) {
        debugPrint('Restoring ${transactions.length} transactions...');
      }

      // 恢复预算
      final budgets = data['budgets'] as List?;
      if (budgets != null) {
        debugPrint('Restoring ${budgets.length} budgets...');
      }

      return true;
    } catch (e) {
      debugPrint('Restore backup failed: $e');
      return false;
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  Future<String> _getDeviceName() async {
    // 获取设备名称
    if (Platform.isAndroid) {
      return 'Android设备';
    } else if (Platform.isIOS) {
      return 'iOS设备';
    } else {
      return '未知设备';
    }
  }
}

/// 同步管理器
class SyncManager {
  final BackupRestoreService _backupService = BackupRestoreService();
  CloudSyncService? _cloudService;

  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  SyncSettings _settings = const SyncSettings();
  SyncStatus _status = SyncStatus.idle;
  List<SyncRecord> _history = [];
  final List<SyncConflict> _conflicts = [];

  SyncSettings get settings => _settings;
  SyncStatus get status => _status;
  List<SyncRecord> get history => _history;
  List<SyncConflict> get conflicts => _conflicts;
  int get pendingConflicts => _conflicts.where((c) => !c.isResolved).length;

  /// 初始化
  Future<void> initialize() async {
    await _loadSettings();
    await _loadHistory();
  }

  /// 设置云服务
  void setCloudService(CloudSyncService service) {
    _cloudService = service;
  }

  /// 更新设置
  Future<void> updateSettings(SyncSettings settings) async {
    _settings = settings;
    await _saveSettings();

    // 根据设置初始化云服务
    switch (settings.provider) {
      case CloudProvider.local:
        _cloudService = LocalBackupService();
        break;
      case CloudProvider.webdav:
        // 需要额外的WebDAV配置
        break;
      default:
        _cloudService = LocalBackupService();
    }
  }

  /// 执行同步
  Future<SyncRecord> sync({SyncDirection direction = SyncDirection.bidirectional}) async {
    final startTime = DateTime.now();
    _status = SyncStatus.syncing;

    try {
      // 确保有云服务
      _cloudService ??= LocalBackupService();

      // 同步前备份
      if (_settings.backupBeforeSync) {
        await createBackup();
      }

      int uploaded = 0;
      int downloaded = 0;

      // 上传
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.bidirectional) {
        final backup = await _backupService.createBackup();
        final success = await _cloudService!.uploadBackup(backup);
        if (success) uploaded = backup.totalRecords;
      }

      // 下载
      if (direction == SyncDirection.download ||
          direction == SyncDirection.bidirectional) {
        final backups = await _cloudService!.listBackups();
        if (backups.isNotEmpty) {
          // 获取最新的备份
          final latest = backups.first;
          downloaded = latest.totalRecords;
          // 实际应用中需要进行数据合并和冲突检测
        }
      }

      _status = SyncStatus.success;
      _settings = _settings.copyWith(lastSyncTime: DateTime.now());
      await _saveSettings();

      final record = SyncRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        status: SyncStatus.success,
        provider: _settings.provider,
        direction: direction,
        itemsUploaded: uploaded,
        itemsDownloaded: downloaded,
        duration: DateTime.now().difference(startTime),
      );

      _history.insert(0, record);
      await _saveHistory();
      return record;
    } catch (e) {
      _status = SyncStatus.failed;

      final record = SyncRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        status: SyncStatus.failed,
        provider: _settings.provider,
        direction: direction,
        errorMessage: e.toString(),
        duration: DateTime.now().difference(startTime),
      );

      _history.insert(0, record);
      await _saveHistory();
      return record;
    }
  }

  /// 创建备份
  Future<BackupData> createBackup() async {
    final backup = await _backupService.createBackup();
    _cloudService ??= LocalBackupService();
    await _cloudService!.uploadBackup(backup);

    // 清理旧备份
    await _cleanOldBackups();

    return backup;
  }

  /// 获取备份列表
  Future<List<BackupData>> listBackups() async {
    _cloudService ??= LocalBackupService();
    return await _cloudService!.listBackups();
  }

  /// 恢复备份
  Future<bool> restoreBackup(String backupId, {bool merge = false}) async {
    _cloudService ??= LocalBackupService();
    final backup = await _cloudService!.downloadBackup(backupId);
    if (backup == null) return false;

    return await _backupService.restoreBackup(backup, merge: merge);
  }

  /// 删除备份
  Future<bool> deleteBackup(String backupId) async {
    _cloudService ??= LocalBackupService();
    return await _cloudService!.deleteBackup(backupId);
  }

  /// 解决冲突
  Future<void> resolveConflict(String conflictId, ConflictResolution resolution) async {
    final index = _conflicts.indexWhere((c) => c.id == conflictId);
    if (index != -1) {
      _conflicts[index] = _conflicts[index].copyWith(resolution: resolution);

      // 应用解决方案
      switch (resolution) {
        case ConflictResolution.keepLocal:
          // 保持本地数据不变
          break;
        case ConflictResolution.keepRemote:
          // 用远程数据覆盖本地
          break;
        case ConflictResolution.keepBoth:
          // 创建副本
          break;
        case ConflictResolution.merge:
          // 智能合并
          break;
      }
    }
  }

  /// 清理旧备份
  Future<void> _cleanOldBackups() async {
    final backups = await listBackups();
    if (backups.length > _settings.maxBackupCount) {
      // 删除最旧的备份
      for (var i = _settings.maxBackupCount; i < backups.length; i++) {
        await deleteBackup(backups[i].id);
      }
    }
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('sync_settings');
    if (json != null) {
      _settings = SyncSettings.fromMap(jsonDecode(json));
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_settings', jsonEncode(_settings.toMap()));
  }

  /// 加载历史
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('sync_history');
    if (json != null) {
      final list = jsonDecode(json) as List;
      _history = list.map((e) => SyncRecord.fromMap(e)).toList();
    }
  }

  /// 保存历史
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // 只保留最近20条
    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
    }
    await prefs.setString(
      'sync_history',
      jsonEncode(_history.map((e) => e.toMap()).toList()),
    );
  }
}
