import 'dart:convert';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';

/// 分类自学习辅助类
/// 用于在导入时查询和记录学习数据
class CategoryLearningHelper {
  static CategoryLearningHelper? _instance;
  static CategoryLearningHelper get instance {
    _instance ??= CategoryLearningHelper._();
    return _instance!;
  }

  CategoryLearningHelper._();

  IDatabaseService? _db;

  // 内存缓存
  final Map<String, _LearningRecord> _keywordCache = {};
  final Map<String, _LearningRecord> _merchantCache = {};
  bool _initialized = false;

  /// 初始化，加载学习数据到内存
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _db = sl<IDatabaseService>();
      await _loadLearningData();
      _initialized = true;
    } catch (e) {
      // 如果初始化失败，不影响正常使用
      _initialized = true;
    }
  }

  /// 加载学习数据
  Future<void> _loadLearningData() async {
    if (_db == null) return;

    try {
      // 加载关键词学习数据
      final keywordRecords = await _db!.rawQuery('''
        SELECT keyword, category, confidence, learnCount
        FROM category_learning_records
        WHERE confidence >= 0.5
        ORDER BY confidence DESC, learnCount DESC
      ''');

      for (final record in keywordRecords) {
        final keyword = (record['keyword'] as String).toLowerCase();
        _keywordCache[keyword] = _LearningRecord(
          category: record['category'] as String,
          confidence: (record['confidence'] as num).toDouble(),
          learnCount: record['learnCount'] as int? ?? 1,
        );
      }

      // 加载商户学习数据
      final merchantRecords = await _db!.rawQuery('''
        SELECT merchant, category, confidence, learnCount
        FROM merchant_learning_records
        WHERE confidence >= 0.5
        ORDER BY confidence DESC, learnCount DESC
      ''');

      for (final record in merchantRecords) {
        final merchant = (record['merchant'] as String).toLowerCase();
        _merchantCache[merchant] = _LearningRecord(
          category: record['category'] as String,
          confidence: (record['confidence'] as num).toDouble(),
          learnCount: record['learnCount'] as int? ?? 1,
        );
      }
    } catch (e) {
      // 表可能不存在，忽略错误
    }
  }

  /// 刷新学习数据
  Future<void> refresh() async {
    _keywordCache.clear();
    _merchantCache.clear();
    _initialized = false;
    await initialize();
  }

  /// 根据商户名查询学习到的分类
  String? getLearnedCategoryByMerchant(String? merchant) {
    if (merchant == null || merchant.isEmpty) return null;

    final key = merchant.toLowerCase().trim();
    final record = _merchantCache[key];

    if (record != null && record.confidence >= 0.6) {
      return record.category;
    }
    return null;
  }

  /// 根据关键词查询学习到的分类
  String? getLearnedCategoryByKeyword(String? text) {
    if (text == null || text.isEmpty) return null;

    final lowerText = text.toLowerCase();

    // 按置信度和学习次数排序后遍历
    final sortedEntries = _keywordCache.entries.toList()
      ..sort((a, b) {
        final confCompare = b.value.confidence.compareTo(a.value.confidence);
        if (confCompare != 0) return confCompare;
        return b.value.learnCount.compareTo(a.value.learnCount);
      });

    for (final entry in sortedEntries) {
      if (entry.value.confidence >= 0.6 && lowerText.contains(entry.key)) {
        return entry.value.category;
      }
    }
    return null;
  }

  /// 综合查询学习到的分类
  /// 优先商户精确匹配，其次关键词匹配
  String? getLearnedCategory(String? merchant, String? note) {
    // 1. 先尝试商户精确匹配
    final merchantCategory = getLearnedCategoryByMerchant(merchant);
    if (merchantCategory != null) {
      return merchantCategory;
    }

    // 2. 再尝试关键词匹配
    final combinedText = '${merchant ?? ''} ${note ?? ''}'.trim();
    return getLearnedCategoryByKeyword(combinedText);
  }

  /// 记录用户的分类修正（学习）
  Future<void> recordCorrection({
    required String? merchant,
    required String? note,
    required String originalCategory,
    required String correctedCategory,
    String? source,
  }) async {
    if (originalCategory == correctedCategory) return;
    if (_db == null) {
      try {
        _db = sl<IDatabaseService>();
      } catch (e) {
        return;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. 记录修正日志
      await _db!.rawInsert('''
        INSERT INTO user_corrections
        (id, originalCategory, correctedCategory, context, source, correctedAt)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        now.toString(),
        originalCategory,
        correctedCategory,
        jsonEncode({
          'note': note,
          'merchant': merchant,
        }),
        source ?? 'import',
        now,
      ]);

      // 2. 从商户名学习（如果商户名有意义）
      if (merchant != null && merchant.trim().isNotEmpty && merchant.length >= 2) {
        await _learnFromMerchant(merchant.trim(), correctedCategory, now);
      }

      // 3. 从备注中提取关键词学习
      if (note != null && note.trim().isNotEmpty) {
        await _learnFromNote(note.trim(), correctedCategory, source, now);
      }
    } catch (e) {
      // 学习失败不影响正常使用
    }
  }

  /// 从商户名学习
  Future<void> _learnFromMerchant(String merchant, String category, int now) async {
    final key = merchant.toLowerCase();
    final existing = _merchantCache[key];

    if (existing != null) {
      if (existing.category == category) {
        // 同样的分类，增加置信度
        final newConfidence = (existing.confidence + 0.1).clamp(0.0, 1.0);
        final newCount = existing.learnCount + 1;

        await _db!.rawUpdate('''
          UPDATE merchant_learning_records
          SET confidence = ?, learnCount = ?, updatedAt = ?
          WHERE merchant = ?
        ''', [newConfidence, newCount, now, merchant]);

        _merchantCache[key] = _LearningRecord(
          category: category,
          confidence: newConfidence,
          learnCount: newCount,
        );
      } else {
        // 不同分类，降低原有置信度或替换
        if (existing.confidence < 0.6 || existing.learnCount < 3) {
          await _db!.rawUpdate('''
            UPDATE merchant_learning_records
            SET category = ?, confidence = 0.6, learnCount = 1, updatedAt = ?
            WHERE merchant = ?
          ''', [category, now, merchant]);

          _merchantCache[key] = _LearningRecord(
            category: category,
            confidence: 0.6,
            learnCount: 1,
          );
        }
      }
    } else {
      // 新记录
      await _db!.rawInsert('''
        INSERT INTO merchant_learning_records
        (id, merchant, category, confidence, learnCount, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', ['m_$now', merchant, category, 0.6, 1, now, now]);

      _merchantCache[key] = _LearningRecord(
        category: category,
        confidence: 0.6,
        learnCount: 1,
      );
    }
  }

  /// 从备注中提取关键词学习
  Future<void> _learnFromNote(String note, String category, String? source, int now) async {
    // 提取有意义的关键词（2-6个字符）
    final keywords = _extractKeywords(note);

    for (final keyword in keywords) {
      final key = keyword.toLowerCase();
      final existing = _keywordCache[key];

      if (existing != null) {
        if (existing.category == category) {
          final newConfidence = (existing.confidence + 0.05).clamp(0.0, 1.0);
          final newCount = existing.learnCount + 1;

          await _db!.rawUpdate('''
            UPDATE category_learning_records
            SET confidence = ?, learnCount = ?, updatedAt = ?
            WHERE keyword = ?
          ''', [newConfidence, newCount, now, keyword]);

          _keywordCache[key] = _LearningRecord(
            category: category,
            confidence: newConfidence,
            learnCount: newCount,
          );
        }
      } else {
        await _db!.rawInsert('''
          INSERT INTO category_learning_records
          (id, keyword, category, confidence, learnCount, source, createdAt, updatedAt)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', ['k_$now${keyword.hashCode}', keyword, category, 0.5, 1, source, now, now]);

        _keywordCache[key] = _LearningRecord(
          category: category,
          confidence: 0.5,
          learnCount: 1,
        );
      }
    }
  }

  /// 提取有意义的关键词
  List<String> _extractKeywords(String text) {
    final keywords = <String>[];

    // 按空格和常见分隔符分割
    final parts = text.split(RegExp(r'[\s,，、:：\-/]+'));

    for (final part in parts) {
      final trimmed = part.trim();
      // 保留 2-10 个字符的词
      if (trimmed.length >= 2 && trimmed.length <= 10) {
        // 过滤纯数字和常见无意义词
        if (!RegExp(r'^\d+$').hasMatch(trimmed) &&
            !_isCommonWord(trimmed)) {
          keywords.add(trimmed);
        }
      }
    }

    return keywords.take(3).toList(); // 最多取3个关键词
  }

  /// 判断是否是常见无意义词
  bool _isCommonWord(String word) {
    const commonWords = {
      '商户消费', '消费', '支付', '付款', '转账', '收款', '充值',
      '二维码', '扫码', '订单', '交易', '账单', '明细',
      'payment', 'transfer', 'order', 'bill',
    };
    return commonWords.contains(word.toLowerCase());
  }

  /// 获取学习统计
  Future<Map<String, int>> getStats() async {
    return {
      'keywordRules': _keywordCache.length,
      'merchantRules': _merchantCache.length,
    };
  }
}

class _LearningRecord {
  final String category;
  final double confidence;
  final int learnCount;

  _LearningRecord({
    required this.category,
    required this.confidence,
    required this.learnCount,
  });
}
