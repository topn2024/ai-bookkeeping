import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/budget_vault.dart';
import '../models/transaction.dart';
import 'vault_repository.dart';

/// 分类-小金库映射
class CategoryVaultMapping {
  final String id;
  final String categoryId;
  final String vaultId;
  final double confidence; // 映射置信度（0-1）
  final int useCount; // 使用次数
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryVaultMapping({
    required this.id,
    required this.categoryId,
    required this.vaultId,
    this.confidence = 1.0,
    this.useCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'vaultId': vaultId,
      'confidence': confidence,
      'useCount': useCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CategoryVaultMapping.fromMap(Map<String, dynamic> map) {
    return CategoryVaultMapping(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String,
      vaultId: map['vaultId'] as String,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      useCount: map['useCount'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  CategoryVaultMapping copyWith({
    double? confidence,
    int? useCount,
    DateTime? updatedAt,
  }) {
    return CategoryVaultMapping(
      id: id,
      categoryId: categoryId,
      vaultId: vaultId,
      confidence: confidence ?? this.confidence,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// 小金库推荐结果
class VaultRecommendation {
  final BudgetVault vault;
  final double confidence;
  final String reason;
  final RecommendationSource source;

  const VaultRecommendation({
    required this.vault,
    required this.confidence,
    required this.reason,
    required this.source,
  });
}

/// 推荐来源
enum RecommendationSource {
  /// 分类映射
  categoryMapping,

  /// 历史记录
  historyBased,

  /// 商户匹配
  merchantBased,

  /// 金额范围匹配
  amountRangeBased,

  /// 默认推荐
  defaultFallback,
}

/// 交易-小金库自动关联服务
///
/// 根据交易的分类、商户、历史记录等信息
/// 自动推荐并关联小金库
class TransactionVaultLinker {
  final VaultRepository _vaultRepository;
  final Database _db;

  static const String mappingTableName = 'category_vault_mappings';
  static const String historyTableName = 'transaction_vault_history';

  TransactionVaultLinker(this._vaultRepository, this._db);

  /// 创建数据库表
  static Future<void> createTables(Database db) async {
    // 分类-小金库映射表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $mappingTableName (
        id TEXT PRIMARY KEY,
        categoryId TEXT NOT NULL,
        vaultId TEXT NOT NULL,
        confidence REAL DEFAULT 1.0,
        useCount INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        UNIQUE(categoryId, vaultId)
      )
    ''');

    // 交易-小金库历史记录表（用于学习）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $historyTableName (
        id TEXT PRIMARY KEY,
        transactionId TEXT NOT NULL,
        vaultId TEXT NOT NULL,
        categoryId TEXT,
        merchantName TEXT,
        amount REAL NOT NULL,
        wasAutoLinked INTEGER DEFAULT 0,
        wasAccepted INTEGER DEFAULT 1,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mapping_category ON $mappingTableName(categoryId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_category ON $historyTableName(categoryId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_merchant ON $historyTableName(merchantName)');
  }

  /// 根据分类获取推荐小金库
  Future<VaultRecommendation?> suggestVaultForTransaction(
    Transaction transaction,
  ) async {
    // 只处理支出交易
    if (transaction.type != TransactionType.expense) {
      return null;
    }

    // 1. 优先检查分类-小金库映射
    if (transaction.categoryId != null) {
      final mappingResult = await _suggestByMapping(transaction.categoryId!);
      if (mappingResult != null) {
        return mappingResult;
      }
    }

    // 2. 基于历史记录智能推荐
    final historyResult = await _suggestByHistory(transaction);
    if (historyResult != null) {
      return historyResult;
    }

    // 3. 基于商户名称匹配
    if (transaction.merchantName != null) {
      final merchantResult = await _suggestByMerchant(transaction.merchantName!);
      if (merchantResult != null) {
        return merchantResult;
      }
    }

    // 4. 基于金额范围匹配
    final amountResult = await _suggestByAmountRange(transaction.amount);
    if (amountResult != null) {
      return amountResult;
    }

    // 5. 默认推荐弹性支出小金库
    final defaultResult = await _getDefaultFlexibleVault();
    return defaultResult;
  }

  /// 通过分类映射推荐
  Future<VaultRecommendation?> _suggestByMapping(String categoryId) async {
    final mappings = await _db.query(
      mappingTableName,
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'confidence DESC, useCount DESC',
      limit: 1,
    );

    if (mappings.isEmpty) return null;

    final mapping = CategoryVaultMapping.fromMap(mappings.first);
    final vault = await _vaultRepository.getById(mapping.vaultId);

    if (vault == null || !vault.isEnabled) return null;

    return VaultRecommendation(
      vault: vault,
      confidence: mapping.confidence,
      reason: '根据消费分类自动匹配',
      source: RecommendationSource.categoryMapping,
    );
  }

  /// 通过历史记录推荐
  Future<VaultRecommendation?> _suggestByHistory(Transaction transaction) async {
    // 查找相似交易的历史关联
    final history = await _findSimilarTransactionHistory(transaction);

    if (history.isEmpty) return null;

    // 统计各小金库的使用次数
    final vaultCounts = <String, int>{};
    final vaultAcceptance = <String, int>{};

    for (final record in history) {
      final vaultId = record['vaultId'] as String;
      vaultCounts[vaultId] = (vaultCounts[vaultId] ?? 0) + 1;
      if (record['wasAccepted'] == 1) {
        vaultAcceptance[vaultId] = (vaultAcceptance[vaultId] ?? 0) + 1;
      }
    }

    if (vaultCounts.isEmpty) return null;

    // 找到使用次数最多且接受率高的小金库
    String? bestVaultId;
    double bestScore = 0;

    for (final entry in vaultCounts.entries) {
      final acceptanceRate = (vaultAcceptance[entry.key] ?? 0) / entry.value;
      final score = entry.value * acceptanceRate;
      if (score > bestScore) {
        bestScore = score;
        bestVaultId = entry.key;
      }
    }

    if (bestVaultId == null) return null;

    final vault = await _vaultRepository.getById(bestVaultId);
    if (vault == null || !vault.isEnabled) return null;

    final totalCount = vaultCounts[bestVaultId]!;
    final confidence = (totalCount / history.length).clamp(0.5, 0.95);

    return VaultRecommendation(
      vault: vault,
      confidence: confidence,
      reason: '根据历史消费习惯推荐（$totalCount次相似消费）',
      source: RecommendationSource.historyBased,
    );
  }

  /// 查找相似交易历史
  Future<List<Map<String, dynamic>>> _findSimilarTransactionHistory(
    Transaction transaction,
  ) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    // 同分类
    if (transaction.categoryId != null) {
      conditions.add('categoryId = ?');
      args.add(transaction.categoryId);
    }

    // 相似金额（±30%）
    conditions.add('amount BETWEEN ? AND ?');
    args.add(transaction.amount * 0.7);
    args.add(transaction.amount * 1.3);

    if (conditions.isEmpty) return [];

    final results = await _db.query(
      historyTableName,
      where: conditions.join(' OR '),
      whereArgs: args,
      orderBy: 'createdAt DESC',
      limit: 50,
    );

    return results;
  }

  /// 通过商户名称推荐
  Future<VaultRecommendation?> _suggestByMerchant(String merchantName) async {
    final results = await _db.query(
      historyTableName,
      where: 'merchantName = ? AND wasAccepted = 1',
      whereArgs: [merchantName],
      orderBy: 'createdAt DESC',
      limit: 10,
    );

    if (results.isEmpty) return null;

    // 统计该商户最常关联的小金库
    final vaultCounts = <String, int>{};
    for (final record in results) {
      final vaultId = record['vaultId'] as String;
      vaultCounts[vaultId] = (vaultCounts[vaultId] ?? 0) + 1;
    }

    final mostUsedVaultId = vaultCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final vault = await _vaultRepository.getById(mostUsedVaultId);
    if (vault == null || !vault.isEnabled) return null;

    return VaultRecommendation(
      vault: vault,
      confidence: 0.8,
      reason: '在"$merchantName"消费通常使用此小金库',
      source: RecommendationSource.merchantBased,
    );
  }

  /// 通过金额范围推荐
  Future<VaultRecommendation?> _suggestByAmountRange(double amount) async {
    final vaults = await _vaultRepository.getEnabled();

    // 大额消费（>500）优先匹配固定支出
    if (amount > 500) {
      final fixedVaults = vaults.where((v) => v.type == VaultType.fixed).toList();
      if (fixedVaults.isNotEmpty) {
        // 找到有足够余额的固定支出小金库
        final suitableVault = fixedVaults.firstWhere(
          (v) => v.available >= amount,
          orElse: () => fixedVaults.first,
        );
        return VaultRecommendation(
          vault: suitableVault,
          confidence: 0.6,
          reason: '大额消费建议从固定支出预算扣除',
          source: RecommendationSource.amountRangeBased,
        );
      }
    }

    // 小额消费（<50）优先匹配弹性支出
    if (amount < 50) {
      final flexibleVaults =
          vaults.where((v) => v.type == VaultType.flexible).toList();
      if (flexibleVaults.isNotEmpty) {
        final suitableVault = flexibleVaults.firstWhere(
          (v) => v.available >= amount,
          orElse: () => flexibleVaults.first,
        );
        return VaultRecommendation(
          vault: suitableVault,
          confidence: 0.5,
          reason: '日常小额消费',
          source: RecommendationSource.amountRangeBased,
        );
      }
    }

    return null;
  }

  /// 获取默认弹性支出小金库
  Future<VaultRecommendation?> _getDefaultFlexibleVault() async {
    final vaults = await _vaultRepository.getByType(VaultType.flexible);
    final enabledVaults = vaults.where((v) => v.isEnabled).toList();

    if (enabledVaults.isEmpty) return null;

    // 选择余额最多的弹性支出小金库
    enabledVaults.sort((a, b) => b.available.compareTo(a.available));

    return VaultRecommendation(
      vault: enabledVaults.first,
      confidence: 0.3,
      reason: '默认弹性支出预算',
      source: RecommendationSource.defaultFallback,
    );
  }

  /// 交易保存时更新小金库
  Future<void> onTransactionSaved(
    Transaction transaction, {
    bool wasAutoLinked = false,
  }) async {
    if (transaction.vaultId == null || transaction.type != TransactionType.expense) {
      return;
    }

    // 更新小金库花费金额
    await _vaultRepository.updateSpentAmount(
      transaction.vaultId!,
      transaction.amount,
    );

    // 记录历史（用于学习）
    await _recordHistory(
      transactionId: transaction.id,
      vaultId: transaction.vaultId!,
      categoryId: transaction.categoryId,
      merchantName: transaction.merchantName,
      amount: transaction.amount,
      wasAutoLinked: wasAutoLinked,
    );

    // 更新分类映射的使用次数
    if (transaction.categoryId != null) {
      await _updateMappingUseCount(
        transaction.categoryId!,
        transaction.vaultId!,
      );
    }

    // 检查预算状态并发送通知
    final vault = await _vaultRepository.getById(transaction.vaultId!);
    if (vault != null) {
      await _checkAndNotify(vault);
    }
  }

  /// 交易删除时恢复小金库金额
  Future<void> onTransactionDeleted(Transaction transaction) async {
    if (transaction.vaultId == null || transaction.type != TransactionType.expense) {
      return;
    }

    // 恢复小金库金额（减少花费）
    await _vaultRepository.updateSpentAmount(
      transaction.vaultId!,
      -transaction.amount,
    );

    // 删除历史记录
    await _db.delete(
      historyTableName,
      where: 'transactionId = ?',
      whereArgs: [transaction.id],
    );
  }

  /// 交易更新时处理小金库变化
  Future<void> onTransactionUpdated(
    Transaction oldTransaction,
    Transaction newTransaction,
  ) async {
    // 如果小金库变化
    if (oldTransaction.vaultId != newTransaction.vaultId) {
      // 从旧小金库恢复
      if (oldTransaction.vaultId != null) {
        await _vaultRepository.updateSpentAmount(
          oldTransaction.vaultId!,
          -oldTransaction.amount,
        );
      }

      // 更新到新小金库
      if (newTransaction.vaultId != null) {
        await _vaultRepository.updateSpentAmount(
          newTransaction.vaultId!,
          newTransaction.amount,
        );
      }
    } else if (oldTransaction.amount != newTransaction.amount) {
      // 只是金额变化
      if (newTransaction.vaultId != null) {
        final diff = newTransaction.amount - oldTransaction.amount;
        await _vaultRepository.updateSpentAmount(newTransaction.vaultId!, diff);
      }
    }

    // 更新历史记录
    await _db.update(
      historyTableName,
      {
        'vaultId': newTransaction.vaultId,
        'categoryId': newTransaction.categoryId,
        'merchantName': newTransaction.merchantName,
        'amount': newTransaction.amount,
      },
      where: 'transactionId = ?',
      whereArgs: [newTransaction.id],
    );
  }

  /// 记录交易-小金库关联历史
  Future<void> _recordHistory({
    required String transactionId,
    required String vaultId,
    String? categoryId,
    String? merchantName,
    required double amount,
    bool wasAutoLinked = false,
  }) async {
    await _db.insert(
      historyTableName,
      {
        'id': '${DateTime.now().millisecondsSinceEpoch}_$transactionId',
        'transactionId': transactionId,
        'vaultId': vaultId,
        'categoryId': categoryId,
        'merchantName': merchantName,
        'amount': amount,
        'wasAutoLinked': wasAutoLinked ? 1 : 0,
        'wasAccepted': 1, // 默认接受
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新分类映射使用次数
  Future<void> _updateMappingUseCount(String categoryId, String vaultId) async {
    // 尝试更新现有映射
    final updated = await _db.rawUpdate('''
      UPDATE $mappingTableName
      SET useCount = useCount + 1, updatedAt = ?
      WHERE categoryId = ? AND vaultId = ?
    ''', [DateTime.now().millisecondsSinceEpoch, categoryId, vaultId]);

    // 如果没有现有映射，创建新映射
    if (updated == 0) {
      await _db.insert(
        mappingTableName,
        {
          'id': '${categoryId}_$vaultId',
          'categoryId': categoryId,
          'vaultId': vaultId,
          'confidence': 0.5, // 初始置信度较低
          'useCount': 1,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// 检查预算状态并发送通知
  Future<void> _checkAndNotify(BudgetVault vault) async {
    if (vault.isOverSpent) {
      // TODO: 发送超支通知
      // await _notificationService.sendOverspentNotification(vault);
    } else if (vault.usageRate > 0.8) {
      // TODO: 发送低余额警告
      // await _notificationService.sendLowBalanceWarning(vault);
    }
  }

  /// 用户确认/拒绝自动关联
  Future<void> confirmAutoLink(String transactionId, bool accepted) async {
    await _db.update(
      historyTableName,
      {'wasAccepted': accepted ? 1 : 0},
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );

    // 如果被拒绝，降低相关映射的置信度
    if (!accepted) {
      final history = await _db.query(
        historyTableName,
        where: 'transactionId = ?',
        whereArgs: [transactionId],
        limit: 1,
      );

      if (history.isNotEmpty) {
        final categoryId = history.first['categoryId'] as String?;
        final vaultId = history.first['vaultId'] as String;

        if (categoryId != null) {
          await _decreaseMappingConfidence(categoryId, vaultId);
        }
      }
    }
  }

  /// 降低映射置信度
  Future<void> _decreaseMappingConfidence(
    String categoryId,
    String vaultId,
  ) async {
    await _db.rawUpdate('''
      UPDATE $mappingTableName
      SET confidence = MAX(confidence - 0.1, 0.1), updatedAt = ?
      WHERE categoryId = ? AND vaultId = ?
    ''', [DateTime.now().millisecondsSinceEpoch, categoryId, vaultId]);
  }

  /// 手动设置分类-小金库映射
  Future<void> setMapping({
    required String categoryId,
    required String vaultId,
    double confidence = 1.0,
  }) async {
    await _db.insert(
      mappingTableName,
      {
        'id': '${categoryId}_$vaultId',
        'categoryId': categoryId,
        'vaultId': vaultId,
        'confidence': confidence,
        'useCount': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除分类-小金库映射
  Future<void> removeMapping(String categoryId, String vaultId) async {
    await _db.delete(
      mappingTableName,
      where: 'categoryId = ? AND vaultId = ?',
      whereArgs: [categoryId, vaultId],
    );
  }

  /// 获取分类的所有映射
  Future<List<CategoryVaultMapping>> getMappingsForCategory(
    String categoryId,
  ) async {
    final results = await _db.query(
      mappingTableName,
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'confidence DESC',
    );

    return results.map((m) => CategoryVaultMapping.fromMap(m)).toList();
  }

  /// 获取小金库的所有映射
  Future<List<CategoryVaultMapping>> getMappingsForVault(String vaultId) async {
    final results = await _db.query(
      mappingTableName,
      where: 'vaultId = ?',
      whereArgs: [vaultId],
      orderBy: 'useCount DESC',
    );

    return results.map((m) => CategoryVaultMapping.fromMap(m)).toList();
  }

  /// 获取推荐统计
  Future<Map<String, dynamic>> getRecommendationStats() async {
    final total = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM $historyTableName WHERE wasAutoLinked = 1',
    )) ?? 0;

    final accepted = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM $historyTableName WHERE wasAutoLinked = 1 AND wasAccepted = 1',
    )) ?? 0;

    return {
      'totalAutoLinked': total,
      'acceptedCount': accepted,
      'acceptanceRate': total > 0 ? accepted / total : 0.0,
    };
  }

  /// 清理过期的历史记录
  Future<void> cleanupOldHistory({int keepDays = 90}) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: keepDays))
        .millisecondsSinceEpoch;

    await _db.delete(
      historyTableName,
      where: 'createdAt < ?',
      whereArgs: [cutoff],
    );
  }
}
