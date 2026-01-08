import 'dart:convert';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import '../database_service.dart';

/// 导入自学习优化服务
/// 设计文档第11.6节：系统集成 - 批量导入学习
/// 记录用户在导入过程中的分类修正，优化后续导入的分类准确性
class ImportLearningService {
  final DatabaseService _db;

  // 内存缓存
  final Map<String, CategoryLearningRecord> _categoryCache = {};
  final Map<String, MerchantLearningRecord> _merchantCache = {};

  ImportLearningService({DatabaseService? databaseService})
      : _db = databaseService ?? DatabaseService();

  /// 初始化，加载学习数据到内存
  Future<void> initialize() async {
    await _loadCategoryLearning();
    await _loadMerchantLearning();
  }

  /// 加载分类学习数据
  Future<void> _loadCategoryLearning() async {
    final records = await _db.rawQuery('''
      SELECT * FROM category_learning_records
      WHERE confidence >= 0.5
      ORDER BY updatedAt DESC
    ''');

    for (final record in records) {
      final keyword = record['keyword'] as String;
      _categoryCache[keyword.toLowerCase()] = CategoryLearningRecord(
        id: record['id'] as String,
        keyword: keyword,
        category: record['category'] as String,
        confidence: record['confidence'] as double,
        learnCount: record['learnCount'] as int? ?? 1,
        source: record['source'] as String?,
      );
    }
  }

  /// 加载商户学习数据
  Future<void> _loadMerchantLearning() async {
    final records = await _db.rawQuery('''
      SELECT * FROM merchant_learning_records
      WHERE confidence >= 0.5
      ORDER BY updatedAt DESC
    ''');

    for (final record in records) {
      final merchant = record['merchant'] as String;
      _merchantCache[merchant.toLowerCase()] = MerchantLearningRecord(
        id: record['id'] as String,
        merchant: merchant,
        category: record['category'] as String,
        confidence: record['confidence'] as double,
        learnCount: record['learnCount'] as int? ?? 1,
      );
    }
  }

  /// 记录用户修正
  /// 当用户在导入预览中修改分类时调用
  Future<void> recordUserCorrection({
    required ImportCandidate original,
    required String correctedCategory,
    required String source, // 来源：wechat, alipay, bank等
  }) async {
    if (original.category == correctedCategory) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. 记录修正日志
    await _db.rawInsert('''
      INSERT INTO user_corrections
      (id, originalCategory, correctedCategory, context, source, correctedAt)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      now.toString(),
      original.category,
      correctedCategory,
      jsonEncode({
        'note': original.note,
        'merchant': original.rawMerchant,
        'amount': original.amount,
      }),
      source,
      now,
    ]);

    // 2. 从备注学习
    if (original.note != null && original.note!.isNotEmpty) {
      await _learnFromNote(original.note!, correctedCategory, source);
    }

    // 3. 从商户学习
    if (original.rawMerchant != null && original.rawMerchant!.isNotEmpty) {
      await _learnFromMerchant(original.rawMerchant!, correctedCategory);
    }
  }

  /// 从备注学习分类
  Future<void> _learnFromNote(
    String note,
    String category,
    String source,
  ) async {
    // 提取关键词
    final keywords = _extractKeywords(note);

    for (final keyword in keywords) {
      if (keyword.length < 2) continue;

      final key = keyword.toLowerCase();
      final existing = _categoryCache[key];

      if (existing != null && existing.category == category) {
        // 相同分类，增加置信度
        final newConfidence = _calculateNewConfidence(
          existing.confidence,
          existing.learnCount,
          true,
        );
        final newCount = existing.learnCount + 1;

        await _db.rawUpdate('''
          UPDATE category_learning_records
          SET confidence = ?, learnCount = ?, updatedAt = ?
          WHERE id = ?
        ''', [newConfidence, newCount, DateTime.now().millisecondsSinceEpoch, existing.id]);

        _categoryCache[key] = existing.copyWith(
          confidence: newConfidence,
          learnCount: newCount,
        );
      } else if (existing != null && existing.category != category) {
        // 不同分类，需要判断是否替换
        final newConfidence = _calculateNewConfidence(
          existing.confidence,
          existing.learnCount,
          false,
        );

        if (newConfidence < 0.3) {
          // 置信度过低，替换为新分类
          await _db.rawUpdate('''
            UPDATE category_learning_records
            SET category = ?, confidence = 0.6, learnCount = 1, updatedAt = ?, source = ?
            WHERE id = ?
          ''', [category, DateTime.now().millisecondsSinceEpoch, source, existing.id]);

          _categoryCache[key] = existing.copyWith(
            category: category,
            confidence: 0.6,
            learnCount: 1,
            source: source,
          );
        } else {
          // 降低置信度
          await _db.rawUpdate('''
            UPDATE category_learning_records
            SET confidence = ?, updatedAt = ?
            WHERE id = ?
          ''', [newConfidence, DateTime.now().millisecondsSinceEpoch, existing.id]);

          _categoryCache[key] = existing.copyWith(confidence: newConfidence);
        }
      } else {
        // 新关键词
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        await _db.rawInsert('''
          INSERT INTO category_learning_records
          (id, keyword, category, confidence, learnCount, source, createdAt, updatedAt)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [id, keyword, category, 0.6, 1, source, DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch]);

        _categoryCache[key] = CategoryLearningRecord(
          id: id,
          keyword: keyword,
          category: category,
          confidence: 0.6,
          learnCount: 1,
          source: source,
        );
      }
    }
  }

  /// 从商户学习分类
  Future<void> _learnFromMerchant(String merchant, String category) async {
    final key = merchant.toLowerCase();
    final existing = _merchantCache[key];

    if (existing != null && existing.category == category) {
      // 增加置信度
      final newConfidence = _calculateNewConfidence(
        existing.confidence,
        existing.learnCount,
        true,
      );
      final newCount = existing.learnCount + 1;

      await _db.rawUpdate('''
        UPDATE merchant_learning_records
        SET confidence = ?, learnCount = ?, updatedAt = ?
        WHERE id = ?
      ''', [newConfidence, newCount, DateTime.now().millisecondsSinceEpoch, existing.id]);

      _merchantCache[key] = existing.copyWith(
        confidence: newConfidence,
        learnCount: newCount,
      );
    } else if (existing != null && existing.category != category) {
      // 不同分类
      final newConfidence = _calculateNewConfidence(
        existing.confidence,
        existing.learnCount,
        false,
      );

      if (newConfidence < 0.3) {
        await _db.rawUpdate('''
          UPDATE merchant_learning_records
          SET category = ?, confidence = 0.7, learnCount = 1, updatedAt = ?
          WHERE id = ?
        ''', [category, DateTime.now().millisecondsSinceEpoch, existing.id]);

        _merchantCache[key] = existing.copyWith(
          category: category,
          confidence: 0.7,
          learnCount: 1,
        );
      } else {
        await _db.rawUpdate('''
          UPDATE merchant_learning_records
          SET confidence = ?, updatedAt = ?
          WHERE id = ?
        ''', [newConfidence, DateTime.now().millisecondsSinceEpoch, existing.id]);

        _merchantCache[key] = existing.copyWith(confidence: newConfidence);
      }
    } else {
      // 新商户
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await _db.rawInsert('''
        INSERT INTO merchant_learning_records
        (id, merchant, category, confidence, learnCount, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [id, merchant, category, 0.7, 1, DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch]);

      _merchantCache[key] = MerchantLearningRecord(
        id: id,
        merchant: merchant,
        category: category,
        confidence: 0.7,
        learnCount: 1,
      );
    }
  }

  /// 根据学习数据预测分类
  Future<CategoryPrediction?> predictCategory({
    String? note,
    String? merchant,
    double? amount,
    TransactionType? type,
  }) async {
    final predictions = <CategoryPrediction>[];

    // 1. 商户匹配（最高优先级）
    if (merchant != null && merchant.isNotEmpty) {
      final merchantRecord = _merchantCache[merchant.toLowerCase()];
      if (merchantRecord != null && merchantRecord.confidence >= 0.5) {
        predictions.add(CategoryPrediction(
          category: merchantRecord.category,
          confidence: merchantRecord.confidence * 1.2, // 商户权重更高
          source: PredictionSource.merchant,
          matchedKeyword: merchant,
        ));
      }
    }

    // 2. 备注关键词匹配
    if (note != null && note.isNotEmpty) {
      final keywords = _extractKeywords(note);
      for (final keyword in keywords) {
        final record = _categoryCache[keyword.toLowerCase()];
        if (record != null && record.confidence >= 0.5) {
          predictions.add(CategoryPrediction(
            category: record.category,
            confidence: record.confidence,
            source: PredictionSource.keyword,
            matchedKeyword: keyword,
          ));
        }
      }
    }

    if (predictions.isEmpty) return null;

    // 合并相同分类的预测
    final categoryScores = <String, double>{};
    final categoryKeywords = <String, String>{};

    for (final p in predictions) {
      categoryScores[p.category] =
          (categoryScores[p.category] ?? 0) + p.confidence;
      if (!categoryKeywords.containsKey(p.category)) {
        categoryKeywords[p.category] = p.matchedKeyword ?? '';
      }
    }

    // 选择得分最高的分类
    String bestCategory = '';
    double bestScore = 0;
    for (final entry in categoryScores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestCategory = entry.key;
      }
    }

    return CategoryPrediction(
      category: bestCategory,
      confidence: (bestScore / (predictions.length * 1.2)).clamp(0.0, 1.0),
      source: predictions.first.source,
      matchedKeyword: categoryKeywords[bestCategory],
    );
  }

  /// 批量应用学习结果
  Future<void> applyLearningToCandidates(List<ImportCandidate> candidates) async {
    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];

      // 如果已经有高置信度分类，跳过
      if (candidate.categoryConfidence != null &&
          candidate.categoryConfidence! >= 0.8) {
        continue;
      }

      final prediction = await predictCategory(
        note: candidate.note,
        merchant: candidate.rawMerchant,
        amount: candidate.amount,
        type: candidate.type,
      );

      if (prediction != null &&
          prediction.confidence >
              (candidate.categoryConfidence ?? 0)) {
        candidates[i] = candidate.copyWith(
          category: prediction.category,
          categoryConfidence: prediction.confidence,
          isLearningApplied: true,
        );
      }
    }
  }

  /// 提取关键词
  List<String> _extractKeywords(String text) {
    // 移除常见停用词和标点
    final stopWords = {
      '的', '了', '是', '在', '我', '有', '和', '就', '不', '人', '都', '一',
      '一个', '上', '也', '很', '到', '说', '要', '去', '你', '会', '着',
      '没有', '看', '好', '自己', '这', '买', '卖', '付款', '支付', '消费',
    };

    // 分词（简单实现，实际应用可使用专业分词库）
    final words = text
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9]'), ' ')
        .split(' ')
        .where((w) => w.length >= 2 && !stopWords.contains(w))
        .toList();

    return words;
  }

  /// 计算新置信度
  double _calculateNewConfidence(
    double currentConfidence,
    int learnCount,
    bool isPositive,
  ) {
    // 使用衰减因子，学习次数越多变化越小
    final decayFactor = 1 / (1 + learnCount * 0.1);

    if (isPositive) {
      // 正向反馈，增加置信度
      return (currentConfidence + (1 - currentConfidence) * 0.2 * decayFactor)
          .clamp(0.0, 1.0);
    } else {
      // 负向反馈，降低置信度
      return (currentConfidence - currentConfidence * 0.3 * decayFactor)
          .clamp(0.0, 1.0);
    }
  }

  /// 获取学习统计
  Future<LearningStats> getLearningStats() async {
    final categoryCount = _categoryCache.length;
    final merchantCount = _merchantCache.length;

    final corrections = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM user_corrections
    ''');

    final avgConfidence = _categoryCache.isNotEmpty
        ? _categoryCache.values
                .map((r) => r.confidence)
                .reduce((a, b) => a + b) /
            _categoryCache.length
        : 0.0;

    return LearningStats(
      totalKeywords: categoryCount,
      totalMerchants: merchantCount,
      totalCorrections: corrections.first['count'] as int? ?? 0,
      averageConfidence: avgConfidence,
    );
  }

  /// 清除低置信度学习数据
  Future<void> cleanupLowConfidenceRecords({double threshold = 0.3}) async {
    await _db.rawDelete('''
      DELETE FROM category_learning_records WHERE confidence < ?
    ''', [threshold]);

    await _db.rawDelete('''
      DELETE FROM merchant_learning_records WHERE confidence < ?
    ''', [threshold]);

    // 重新加载
    _categoryCache.clear();
    _merchantCache.clear();
    await initialize();
  }

  /// 导出学习数据
  Future<Map<String, dynamic>> exportLearningData() async {
    return {
      'categoryLearning': _categoryCache.values.map((r) => r.toJson()).toList(),
      'merchantLearning': _merchantCache.values.map((r) => r.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 导入学习数据
  Future<void> importLearningData(Map<String, dynamic> data) async {
    final categoryData = data['categoryLearning'] as List?;
    if (categoryData != null) {
      for (final item in categoryData) {
        final record = CategoryLearningRecord.fromJson(item as Map<String, dynamic>);
        await _db.rawInsert('''
          INSERT OR REPLACE INTO category_learning_records
          (id, keyword, category, confidence, learnCount, source, createdAt, updatedAt)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          record.id,
          record.keyword,
          record.category,
          record.confidence,
          record.learnCount,
          record.source,
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
        ]);
      }
    }

    final merchantData = data['merchantLearning'] as List?;
    if (merchantData != null) {
      for (final item in merchantData) {
        final record = MerchantLearningRecord.fromJson(item as Map<String, dynamic>);
        await _db.rawInsert('''
          INSERT OR REPLACE INTO merchant_learning_records
          (id, merchant, category, confidence, learnCount, createdAt, updatedAt)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [
          record.id,
          record.merchant,
          record.category,
          record.confidence,
          record.learnCount,
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
        ]);
      }
    }

    // 重新加载
    await initialize();
  }
}

/// 分类学习记录
class CategoryLearningRecord {
  final String id;
  final String keyword;
  final String category;
  final double confidence;
  final int learnCount;
  final String? source;

  CategoryLearningRecord({
    required this.id,
    required this.keyword,
    required this.category,
    required this.confidence,
    this.learnCount = 1,
    this.source,
  });

  CategoryLearningRecord copyWith({
    String? id,
    String? keyword,
    String? category,
    double? confidence,
    int? learnCount,
    String? source,
  }) {
    return CategoryLearningRecord(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      learnCount: learnCount ?? this.learnCount,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'category': category,
        'confidence': confidence,
        'learnCount': learnCount,
        'source': source,
      };

  factory CategoryLearningRecord.fromJson(Map<String, dynamic> json) {
    return CategoryLearningRecord(
      id: json['id'] as String,
      keyword: json['keyword'] as String,
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      learnCount: json['learnCount'] as int? ?? 1,
      source: json['source'] as String?,
    );
  }
}

/// 商户学习记录
class MerchantLearningRecord {
  final String id;
  final String merchant;
  final String category;
  final double confidence;
  final int learnCount;

  MerchantLearningRecord({
    required this.id,
    required this.merchant,
    required this.category,
    required this.confidence,
    this.learnCount = 1,
  });

  MerchantLearningRecord copyWith({
    String? id,
    String? merchant,
    String? category,
    double? confidence,
    int? learnCount,
  }) {
    return MerchantLearningRecord(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      learnCount: learnCount ?? this.learnCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant': merchant,
        'category': category,
        'confidence': confidence,
        'learnCount': learnCount,
      };

  factory MerchantLearningRecord.fromJson(Map<String, dynamic> json) {
    return MerchantLearningRecord(
      id: json['id'] as String,
      merchant: json['merchant'] as String,
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      learnCount: json['learnCount'] as int? ?? 1,
    );
  }
}

/// 分类预测结果
class CategoryPrediction {
  final String category;
  final double confidence;
  final PredictionSource source;
  final String? matchedKeyword;

  CategoryPrediction({
    required this.category,
    required this.confidence,
    required this.source,
    this.matchedKeyword,
  });
}

/// 预测来源
enum PredictionSource {
  merchant,
  keyword,
  pattern,
  ai,
}

/// 学习统计
class LearningStats {
  final int totalKeywords;
  final int totalMerchants;
  final int totalCorrections;
  final double averageConfidence;

  LearningStats({
    required this.totalKeywords,
    required this.totalMerchants,
    required this.totalCorrections,
    required this.averageConfidence,
  });
}
