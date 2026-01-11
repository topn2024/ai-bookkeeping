import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../core/contracts/i_http_service.dart';

/// Backup metadata
class BackupInfo {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int backupType;
  // 基础数据统计
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int bookCount;
  final int budgetCount;
  // 扩展数据统计
  final int creditCardCount;
  final int debtCount;
  final int savingsGoalCount;
  final int billReminderCount;
  final int recurringCount;
  // 其他
  final int size;
  final String? deviceName;
  final String? deviceId;
  final String? appVersion;
  final DateTime createdAt;

  BackupInfo({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.backupType,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.bookCount,
    required this.budgetCount,
    this.creditCardCount = 0,
    this.debtCount = 0,
    this.savingsGoalCount = 0,
    this.billReminderCount = 0,
    this.recurringCount = 0,
    required this.size,
    this.deviceName,
    this.deviceId,
    this.appVersion,
    required this.createdAt,
  });

  factory BackupInfo.fromJson(Map<String, dynamic> json) {
    return BackupInfo(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      backupType: json['backup_type'] as int,
      transactionCount: json['transaction_count'] as int,
      accountCount: json['account_count'] as int,
      categoryCount: json['category_count'] as int,
      bookCount: json['book_count'] as int,
      budgetCount: json['budget_count'] as int,
      creditCardCount: (json['credit_card_count'] as int?) ?? 0,
      debtCount: (json['debt_count'] as int?) ?? 0,
      savingsGoalCount: (json['savings_goal_count'] as int?) ?? 0,
      billReminderCount: (json['bill_reminder_count'] as int?) ?? 0,
      recurringCount: (json['recurring_count'] as int?) ?? 0,
      size: json['size'] as int,
      deviceName: json['device_name'] as String?,
      deviceId: json['device_id'] as String?,
      appVersion: json['app_version'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get backupTypeName => backupType == 0 ? '手动备份' : '自动备份';

  /// 总数据项数
  int get totalItems =>
      transactionCount +
      accountCount +
      categoryCount +
      bookCount +
      budgetCount +
      creditCardCount +
      debtCount +
      savingsGoalCount +
      billReminderCount +
      recurringCount;
}

/// Restore result
class RestoreResult {
  final bool success;
  final String message;
  final Map<String, int> restoredCounts;

  RestoreResult({
    required this.success,
    required this.message,
    required this.restoredCounts,
  });

  factory RestoreResult.fromJson(Map<String, dynamic> json) {
    return RestoreResult(
      success: json['success'] as bool,
      message: json['message'] as String,
      restoredCounts: Map<String, int>.from(json['restored_counts'] ?? {}),
    );
  }
}

/// Cloud backup service
class BackupService {
  static final BackupService _instance = BackupService._internal();

  /// 通过服务定位器获取依赖
  IHttpService get _http => sl<IHttpService>();
  IDatabaseService get _db => sl<IDatabaseService>();

  factory BackupService() => _instance;

  BackupService._internal();

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String deviceName = 'Unknown';
    String deviceId = 'unknown';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = '${iosInfo.name} (${iosInfo.model})';
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
    }

    return {
      'device_name': deviceName,
      'device_id': deviceId,
      'app_version': packageInfo.version,
    };
  }

  /// 从本地数据库获取所有备份数据
  Future<Map<String, dynamic>> _getLocalBackupData() async {
    final db = await _db.database;

    // 基础数据
    final transactions = await db.query('transactions');
    final accounts = await db.query('accounts');
    final categories = await db.query('categories');
    final ledgers = await db.query('ledgers');
    final budgets = await db.query('budgets');

    // 扩展数据
    final creditCards = await db.query('credit_cards');
    final debts = await db.query('debts');
    final debtPayments = await db.query('debt_payments');
    final savingsGoals = await db.query('savings_goals');
    final savingsDeposits = await db.query('savings_deposits');
    final billReminders = await db.query('bill_reminders');
    final recurringTransactions = await db.query('recurring_transactions');
    final budgetCarryovers = await db.query('budget_carryovers');
    final zeroBasedAllocations = await db.query('zero_based_allocations');

    return {
      // 基础数据
      'transactions': transactions,
      'accounts': accounts,
      'categories': categories,
      'books': ledgers, // 服务器端用books
      'budgets': budgets,
      // 扩展数据
      'credit_cards': creditCards,
      'debts': debts,
      'debt_payments': debtPayments,
      'savings_goals': savingsGoals,
      'savings_deposits': savingsDeposits,
      'bill_reminders': billReminders,
      'recurring_transactions': recurringTransactions,
      'budget_carryovers': budgetCarryovers,
      'zero_based_allocations': zeroBasedAllocations,
    };
  }

  /// Create a new backup with local data
  Future<BackupInfo> createBackup({
    required String name,
    String? description,
    int backupType = 0,
  }) async {
    final deviceInfo = await _getDeviceInfo();
    final localData = await _getLocalBackupData();

    final response = await _http.post('/backup', data: {
      'name': name,
      'description': description,
      'backup_type': backupType,
      'device_name': deviceInfo['device_name'],
      'device_id': deviceInfo['device_id'],
      'app_version': deviceInfo['app_version'],
      'data': localData, // 上传本地数据
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return BackupInfo.fromJson(response.data);
    } else {
      throw Exception('创建备份失败: ${response.statusMessage}');
    }
  }

  /// List all backups
  Future<List<BackupInfo>> listBackups() async {
    final response = await _http.get('/backup');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final backups = (data['backups'] as List)
          .map((b) => BackupInfo.fromJson(b as Map<String, dynamic>))
          .toList();
      return backups;
    } else {
      throw Exception('获取备份列表失败: ${response.statusMessage}');
    }
  }

  /// Get a specific backup with full data
  Future<Map<String, dynamic>> getBackupData(String backupId) async {
    final response = await _http.get('/backup/$backupId');

    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      throw Exception('备份不存在');
    } else {
      throw Exception('获取备份失败: ${response.statusMessage}');
    }
  }

  /// Get a specific backup info
  Future<BackupInfo> getBackup(String backupId) async {
    final response = await _http.get('/backup/$backupId');

    if (response.statusCode == 200) {
      return BackupInfo.fromJson(response.data);
    } else if (response.statusCode == 404) {
      throw Exception('备份不存在');
    } else {
      throw Exception('获取备份失败: ${response.statusMessage}');
    }
  }

  /// Restore from a backup to local database
  Future<RestoreResult> restoreBackup(String backupId, {bool clearExisting = false}) async {
    // 1. 从服务器获取备份数据
    final backupData = await getBackupData(backupId);
    final data = backupData['data'] as Map<String, dynamic>;

    final db = await _db.database;
    final restoredCounts = <String, int>{};

    try {
      await db.transaction((txn) async {
        // 2. 如果需要清除现有数据
        if (clearExisting) {
          await txn.delete('transactions');
          await txn.delete('accounts');
          await txn.delete('categories');
          await txn.delete('ledgers');
          await txn.delete('budgets');
          await txn.delete('credit_cards');
          await txn.delete('debts');
          await txn.delete('debt_payments');
          await txn.delete('savings_goals');
          await txn.delete('savings_deposits');
          await txn.delete('bill_reminders');
          await txn.delete('recurring_transactions');
          await txn.delete('budget_carryovers');
          await txn.delete('zero_based_allocations');
        }

        // 3. 恢复数据（按依赖顺序）
        // 账本
        final books = data['books'] as List? ?? [];
        for (final book in books) {
          await txn.insert('ledgers', Map<String, dynamic>.from(book),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['books'] = books.length;

        // 账户
        final accounts = data['accounts'] as List? ?? [];
        for (final account in accounts) {
          await txn.insert('accounts', Map<String, dynamic>.from(account),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['accounts'] = accounts.length;

        // 分类
        final categories = data['categories'] as List? ?? [];
        for (final category in categories) {
          await txn.insert('categories', Map<String, dynamic>.from(category),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['categories'] = categories.length;

        // 预算
        final budgets = data['budgets'] as List? ?? [];
        for (final budget in budgets) {
          await txn.insert('budgets', Map<String, dynamic>.from(budget),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['budgets'] = budgets.length;

        // 交易
        final transactions = data['transactions'] as List? ?? [];
        for (final tx in transactions) {
          await txn.insert('transactions', Map<String, dynamic>.from(tx),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['transactions'] = transactions.length;

        // 信用卡
        final creditCards = data['credit_cards'] as List? ?? [];
        for (final card in creditCards) {
          await txn.insert('credit_cards', Map<String, dynamic>.from(card),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['credit_cards'] = creditCards.length;

        // 债务
        final debts = data['debts'] as List? ?? [];
        for (final debt in debts) {
          await txn.insert('debts', Map<String, dynamic>.from(debt),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['debts'] = debts.length;

        // 债务还款记录
        final debtPayments = data['debt_payments'] as List? ?? [];
        for (final payment in debtPayments) {
          await txn.insert('debt_payments', Map<String, dynamic>.from(payment),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['debt_payments'] = debtPayments.length;

        // 储蓄目标
        final savingsGoals = data['savings_goals'] as List? ?? [];
        for (final goal in savingsGoals) {
          await txn.insert('savings_goals', Map<String, dynamic>.from(goal),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['savings_goals'] = savingsGoals.length;

        // 储蓄存款记录
        final savingsDeposits = data['savings_deposits'] as List? ?? [];
        for (final deposit in savingsDeposits) {
          await txn.insert('savings_deposits', Map<String, dynamic>.from(deposit),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['savings_deposits'] = savingsDeposits.length;

        // 账单提醒
        final billReminders = data['bill_reminders'] as List? ?? [];
        for (final reminder in billReminders) {
          await txn.insert('bill_reminders', Map<String, dynamic>.from(reminder),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['bill_reminders'] = billReminders.length;

        // 周期交易
        final recurringTransactions = data['recurring_transactions'] as List? ?? [];
        for (final recurring in recurringTransactions) {
          await txn.insert('recurring_transactions', Map<String, dynamic>.from(recurring),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['recurring_transactions'] = recurringTransactions.length;

        // 预算结转
        final budgetCarryovers = data['budget_carryovers'] as List? ?? [];
        for (final carryover in budgetCarryovers) {
          await txn.insert('budget_carryovers', Map<String, dynamic>.from(carryover),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['budget_carryovers'] = budgetCarryovers.length;

        // 零基预算分配
        final zeroBasedAllocations = data['zero_based_allocations'] as List? ?? [];
        for (final allocation in zeroBasedAllocations) {
          await txn.insert('zero_based_allocations', Map<String, dynamic>.from(allocation),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        restoredCounts['zero_based_allocations'] = zeroBasedAllocations.length;
      });

      return RestoreResult(
        success: true,
        message: '数据恢复成功',
        restoredCounts: restoredCounts,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        message: '恢复失败: $e',
        restoredCounts: {},
      );
    }
  }

  /// Delete a backup
  Future<void> deleteBackup(String backupId) async {
    final response = await _http.delete('/backup/$backupId');

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw Exception('备份不存在');
      } else {
        throw Exception('删除备份失败: ${response.statusMessage}');
      }
    }
  }

  /// Create a backup with auto-generated name
  Future<BackupInfo> createAutoBackup() async {
    final now = DateTime.now();
    final name = '自动备份 ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return createBackup(
      name: name,
      description: '自动备份',
      backupType: 1,
    );
  }
}
