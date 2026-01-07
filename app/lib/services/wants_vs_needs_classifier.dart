import 'database_service.dart';

/// 消费必要性分类
enum SpendingNecessity {
  /// 必需品 - 生存必需
  need,

  /// 想要品 - 提升生活质量
  want,

  /// 可能必需 - 介于两者之间
  maybeNeed,

  /// 浪费 - 完全不必要
  waste,
}

extension SpendingNecessityExtension on SpendingNecessity {
  String get displayName {
    switch (this) {
      case SpendingNecessity.need:
        return '必需';
      case SpendingNecessity.want:
        return '想要';
      case SpendingNecessity.maybeNeed:
        return '可能必需';
      case SpendingNecessity.waste:
        return '浪费';
    }
  }

  String get icon {
    switch (this) {
      case SpendingNecessity.need:
        return '✅';
      case SpendingNecessity.want:
        return '💭';
      case SpendingNecessity.maybeNeed:
        return '🤔';
      case SpendingNecessity.waste:
        return '❌';
    }
  }

  String get description {
    switch (this) {
      case SpendingNecessity.need:
        return '生活必需品，如食物、住房、医疗等';
      case SpendingNecessity.want:
        return '提升生活质量但非必需，如娱乐、升级款等';
      case SpendingNecessity.maybeNeed:
        return '可能必需，需要根据具体情况判断';
      case SpendingNecessity.waste:
        return '完全不必要的支出，应该避免';
    }
  }

  /// 建议预算占比
  double get suggestedBudgetRatio {
    switch (this) {
      case SpendingNecessity.need:
        return 0.50; // 50% for needs
      case SpendingNecessity.want:
        return 0.30; // 30% for wants
      case SpendingNecessity.maybeNeed:
        return 0.10; // 10% flexible
      case SpendingNecessity.waste:
        return 0.00; // 0% for waste
    }
  }
}

/// 分类结果
class ClassificationResult {
  final String transactionId;
  final SpendingNecessity classification;
  final double confidence; // 0.0 - 1.0
  final String reason;
  final bool isUserOverride; // 用户是否手动修正
  final DateTime classifiedAt;

  const ClassificationResult({
    required this.transactionId,
    required this.classification,
    required this.confidence,
    required this.reason,
    this.isUserOverride = false,
    required this.classifiedAt,
  });

  Map<String, dynamic> toMap() => {
        'transactionId': transactionId,
        'classification': classification.index,
        'confidence': confidence,
        'reason': reason,
        'isUserOverride': isUserOverride ? 1 : 0,
        'classifiedAt': classifiedAt.millisecondsSinceEpoch,
      };

  factory ClassificationResult.fromMap(Map<String, dynamic> map) =>
      ClassificationResult(
        transactionId: map['transactionId'] as String,
        classification:
            SpendingNecessity.values[map['classification'] as int],
        confidence: (map['confidence'] as num).toDouble(),
        reason: map['reason'] as String,
        isUserOverride: (map['isUserOverride'] as int?) != 0,
        classifiedAt:
            DateTime.fromMillisecondsSinceEpoch(map['classifiedAt'] as int),
      );
}

/// 分类规则
class ClassificationRule {
  final String id;
  final String categoryId;
  final String? merchantPattern;
  final String? descriptionPattern;
  final SpendingNecessity defaultClassification;
  final double? amountThreshold; // 金额超过此值可能降级
  final int priority; // 规则优先级

  const ClassificationRule({
    required this.id,
    required this.categoryId,
    this.merchantPattern,
    this.descriptionPattern,
    required this.defaultClassification,
    this.amountThreshold,
    this.priority = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'merchantPattern': merchantPattern,
        'descriptionPattern': descriptionPattern,
        'defaultClassification': defaultClassification.index,
        'amountThreshold': amountThreshold,
        'priority': priority,
      };

  factory ClassificationRule.fromMap(Map<String, dynamic> map) =>
      ClassificationRule(
        id: map['id'] as String,
        categoryId: map['categoryId'] as String,
        merchantPattern: map['merchantPattern'] as String?,
        descriptionPattern: map['descriptionPattern'] as String?,
        defaultClassification:
            SpendingNecessity.values[map['defaultClassification'] as int],
        amountThreshold: (map['amountThreshold'] as num?)?.toDouble(),
        priority: map['priority'] as int? ?? 0,
      );
}

/// 消费比例分析
class NeedsWantsAnalysis {
  final double needsAmount;
  final double wantsAmount;
  final double maybeNeedsAmount;
  final double wasteAmount;
  final double totalAmount;
  final double needsRatio;
  final double wantsRatio;
  final bool isHealthy; // 是否符合50/30/20原则
  final String advice;

  const NeedsWantsAnalysis({
    required this.needsAmount,
    required this.wantsAmount,
    required this.maybeNeedsAmount,
    required this.wasteAmount,
    required this.totalAmount,
    required this.needsRatio,
    required this.wantsRatio,
    required this.isHealthy,
    required this.advice,
  });

  double get savingsRatio => 1.0 - needsRatio - wantsRatio;
}

/// "想要"与"需要"分类器
///
/// 帮助用户区分消费是真正需要还是冲动想要：
/// - 自动分类交易
/// - 学习用户偏好
/// - 提供消费比例分析
/// - 基于50/30/20法则给出建议
class WantsVsNeedsClassifier {
  final DatabaseService _db;

  WantsVsNeedsClassifier(this._db);

  /// 预定义的分类规则
  static const Map<String, SpendingNecessity> _categoryDefaults = {
    // 必需品类别
    'food_grocery': SpendingNecessity.need,
    'housing_rent': SpendingNecessity.need,
    'housing_mortgage': SpendingNecessity.need,
    'utilities': SpendingNecessity.need,
    'healthcare': SpendingNecessity.need,
    'insurance': SpendingNecessity.need,
    'transportation_commute': SpendingNecessity.need,
    'education_required': SpendingNecessity.need,
    'childcare': SpendingNecessity.need,

    // 想要品类别
    'food_restaurant': SpendingNecessity.want,
    'food_delivery': SpendingNecessity.want,
    'entertainment': SpendingNecessity.want,
    'shopping_clothing': SpendingNecessity.want,
    'shopping_electronics': SpendingNecessity.want,
    'travel': SpendingNecessity.want,
    'subscription': SpendingNecessity.want,
    'hobby': SpendingNecessity.want,
    'beauty': SpendingNecessity.want,
    'gifts': SpendingNecessity.maybeNeed,

    // 可能浪费类别
    'gambling': SpendingNecessity.waste,
    'lottery': SpendingNecessity.waste,
  };

  /// 商户模式映射
  static const Map<String, SpendingNecessity> _merchantPatterns = {
    '医院': SpendingNecessity.need,
    '药店': SpendingNecessity.need,
    '超市': SpendingNecessity.need,
    '菜市场': SpendingNecessity.need,
    '水电煤': SpendingNecessity.need,
    '房租': SpendingNecessity.need,

    '奶茶': SpendingNecessity.want,
    '咖啡': SpendingNecessity.want,
    '电影': SpendingNecessity.want,
    'KTV': SpendingNecessity.want,
    '游戏': SpendingNecessity.want,
    '直播': SpendingNecessity.maybeNeed,
  };

  /// 分类单笔交易
  Future<ClassificationResult> classifyTransaction({
    required String transactionId,
    required String? categoryId,
    required double amount,
    required String? merchant,
    required String? description,
  }) async {
    // 检查是否有用户历史覆盖
    final override = await _getUserOverride(transactionId);
    if (override != null) {
      return override;
    }

    // 检查是否有相似交易的用户分类
    final learned = await _getLearnedClassification(
      categoryId: categoryId,
      merchant: merchant,
      amount: amount,
    );
    if (learned != null) {
      return learned.copyWith(transactionId: transactionId);
    }

    // 基于规则分类
    SpendingNecessity classification = SpendingNecessity.maybeNeed;
    String reason = '默认分类';
    double confidence = 0.5;

    // 1. 先检查类别默认值
    if (categoryId != null && _categoryDefaults.containsKey(categoryId)) {
      classification = _categoryDefaults[categoryId]!;
      reason = '基于消费类别';
      confidence = 0.8;
    }

    // 2. 检查商户模式
    if (merchant != null) {
      for (final pattern in _merchantPatterns.entries) {
        if (merchant.contains(pattern.key)) {
          classification = pattern.value;
          reason = '基于商户特征';
          confidence = 0.85;
          break;
        }
      }
    }

    // 3. 检查描述
    if (description != null) {
      for (final pattern in _merchantPatterns.entries) {
        if (description.contains(pattern.key)) {
          classification = pattern.value;
          reason = '基于消费描述';
          confidence = 0.75;
          break;
        }
      }
    }

    // 4. 金额调整：高额消费可能需要重新考虑
    if (amount > 500 && classification == SpendingNecessity.want) {
      classification = SpendingNecessity.maybeNeed;
      reason += '，大额消费需确认';
      confidence *= 0.9;
    }

    final result = ClassificationResult(
      transactionId: transactionId,
      classification: classification,
      confidence: confidence,
      reason: reason,
      classifiedAt: DateTime.now(),
    );

    // 保存分类结果
    await _saveClassification(result);

    return result;
  }

  /// 批量分类
  Future<List<ClassificationResult>> classifyTransactions(
    List<Map<String, dynamic>> transactions,
  ) async {
    final results = <ClassificationResult>[];

    for (final tx in transactions) {
      final result = await classifyTransaction(
        transactionId: tx['id'] as String,
        categoryId: tx['categoryId'] as String?,
        amount: (tx['amount'] as num).toDouble(),
        merchant: tx['merchant'] as String?,
        description: tx['description'] as String?,
      );
      results.add(result);
    }

    return results;
  }

  /// 用户手动修正分类
  Future<void> overrideClassification({
    required String transactionId,
    required SpendingNecessity classification,
    String? reason,
  }) async {
    final result = ClassificationResult(
      transactionId: transactionId,
      classification: classification,
      confidence: 1.0,
      reason: reason ?? '用户手动分类',
      isUserOverride: true,
      classifiedAt: DateTime.now(),
    );

    await _saveClassification(result);

    // 学习用户偏好
    await _learnFromOverride(transactionId, classification);
  }

  /// 获取交易分类
  Future<ClassificationResult?> getClassification(String transactionId) async {
    final results = await _db.rawQuery('''
      SELECT * FROM transaction_classifications WHERE transactionId = ?
    ''', [transactionId]);

    if (results.isEmpty) return null;
    return ClassificationResult.fromMap(results.first);
  }

  /// 分析消费比例
  Future<NeedsWantsAnalysis> analyzeSpendingRatio({
    required int year,
    required int month,
  }) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    // 获取月度消费
    final transactions = await _db.rawQuery('''
      SELECT t.id, t.amount, t.categoryId, t.merchant, t.description,
             c.classification
      FROM transactions t
      LEFT JOIN transaction_classifications c ON t.id = c.transactionId
      WHERE t.date >= ? AND t.date <= ? AND t.type = 'expense'
    ''', [
      startOfMonth.millisecondsSinceEpoch,
      endOfMonth.millisecondsSinceEpoch,
    ]);

    double needsAmount = 0;
    double wantsAmount = 0;
    double maybeNeedsAmount = 0;
    double wasteAmount = 0;

    for (final tx in transactions) {
      final amount = (tx['amount'] as num).toDouble();
      final classificationIndex = tx['classification'] as int?;

      SpendingNecessity classification;
      if (classificationIndex != null) {
        classification = SpendingNecessity.values[classificationIndex];
      } else {
        // 未分类的交易，进行即时分类
        final result = await classifyTransaction(
          transactionId: tx['id'] as String,
          categoryId: tx['categoryId'] as String?,
          amount: amount,
          merchant: tx['merchant'] as String?,
          description: tx['description'] as String?,
        );
        classification = result.classification;
      }

      switch (classification) {
        case SpendingNecessity.need:
          needsAmount += amount;
          break;
        case SpendingNecessity.want:
          wantsAmount += amount;
          break;
        case SpendingNecessity.maybeNeed:
          maybeNeedsAmount += amount;
          break;
        case SpendingNecessity.waste:
          wasteAmount += amount;
          break;
      }
    }

    final totalAmount = needsAmount + wantsAmount + maybeNeedsAmount + wasteAmount;
    final needsRatio = totalAmount > 0 ? needsAmount / totalAmount : 0.0;
    final wantsRatio = totalAmount > 0 ? wantsAmount / totalAmount : 0.0;

    // 判断是否健康（基于50/30/20法则）
    final isHealthy = needsRatio <= 0.55 && wantsRatio <= 0.35;

    // 生成建议
    String advice;
    if (isHealthy) {
      advice = '消费结构健康，继续保持！';
    } else if (needsRatio > 0.55) {
      advice = '必需品支出占比过高（${(needsRatio * 100).toStringAsFixed(0)}%），建议检查是否有优化空间';
    } else if (wantsRatio > 0.35) {
      advice = '非必需品支出偏高（${(wantsRatio * 100).toStringAsFixed(0)}%），可以适当控制想要类消费';
    } else if (wasteAmount > 0) {
      advice = '存在浪费性支出￥${wasteAmount.toStringAsFixed(0)}，建议避免此类消费';
    } else {
      advice = '消费结构良好';
    }

    return NeedsWantsAnalysis(
      needsAmount: needsAmount,
      wantsAmount: wantsAmount,
      maybeNeedsAmount: maybeNeedsAmount,
      wasteAmount: wasteAmount,
      totalAmount: totalAmount,
      needsRatio: needsRatio,
      wantsRatio: wantsRatio,
      isHealthy: isHealthy,
      advice: advice,
    );
  }

  /// 获取需要用户确认的分类
  Future<List<ClassificationResult>> getPendingConfirmations() async {
    final results = await _db.rawQuery('''
      SELECT * FROM transaction_classifications
      WHERE classification = ? AND isUserOverride = 0
      ORDER BY classifiedAt DESC
      LIMIT 20
    ''', [SpendingNecessity.maybeNeed.index]);

    return results.map((m) => ClassificationResult.fromMap(m)).toList();
  }

  /// 获取分类统计
  Future<Map<SpendingNecessity, int>> getClassificationStats({
    int days = 30,
  }) async {
    final since =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    final results = await _db.rawQuery('''
      SELECT classification, COUNT(*) as count
      FROM transaction_classifications
      WHERE classifiedAt >= ?
      GROUP BY classification
    ''', [since]);

    final stats = <SpendingNecessity, int>{};
    for (final row in results) {
      final classification =
          SpendingNecessity.values[row['classification'] as int];
      stats[classification] = row['count'] as int;
    }

    return stats;
  }

  /// 添加自定义规则
  Future<void> addCustomRule(ClassificationRule rule) async {
    await _db.rawInsert('''
      INSERT OR REPLACE INTO classification_rules
      (id, categoryId, merchantPattern, descriptionPattern,
       defaultClassification, amountThreshold, priority)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      rule.id,
      rule.categoryId,
      rule.merchantPattern,
      rule.descriptionPattern,
      rule.defaultClassification.index,
      rule.amountThreshold,
      rule.priority,
    ]);
  }

  /// 获取自定义规则
  Future<List<ClassificationRule>> getCustomRules() async {
    final results = await _db.rawQuery('''
      SELECT * FROM classification_rules ORDER BY priority DESC
    ''');

    return results.map((m) => ClassificationRule.fromMap(m)).toList();
  }

  // 私有方法

  Future<void> _saveClassification(ClassificationResult result) async {
    await _db.rawInsert('''
      INSERT OR REPLACE INTO transaction_classifications
      (transactionId, classification, confidence, reason, isUserOverride, classifiedAt)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      result.transactionId,
      result.classification.index,
      result.confidence,
      result.reason,
      result.isUserOverride ? 1 : 0,
      result.classifiedAt.millisecondsSinceEpoch,
    ]);
  }

  Future<ClassificationResult?> _getUserOverride(String transactionId) async {
    final results = await _db.rawQuery('''
      SELECT * FROM transaction_classifications
      WHERE transactionId = ? AND isUserOverride = 1
    ''', [transactionId]);

    if (results.isEmpty) return null;
    return ClassificationResult.fromMap(results.first);
  }

  Future<ClassificationResult?> _getLearnedClassification({
    String? categoryId,
    String? merchant,
    double? amount,
  }) async {
    if (merchant == null) return null;

    // 查找相同商户的用户分类历史
    final results = await _db.rawQuery('''
      SELECT tc.* FROM transaction_classifications tc
      JOIN transactions t ON tc.transactionId = t.id
      WHERE t.merchant = ? AND tc.isUserOverride = 1
      ORDER BY tc.classifiedAt DESC
      LIMIT 1
    ''', [merchant]);

    if (results.isEmpty) return null;
    return ClassificationResult.fromMap(results.first);
  }

  Future<void> _learnFromOverride(
    String transactionId,
    SpendingNecessity classification,
  ) async {
    // 获取交易详情
    final txResults = await _db.rawQuery('''
      SELECT * FROM transactions WHERE id = ?
    ''', [transactionId]);

    if (txResults.isEmpty) return;

    final tx = txResults.first;
    final merchant = tx['merchant'] as String?;
    final categoryId = tx['categoryId'] as String?;

    // 如果有商户信息，创建学习规则
    if (merchant != null && merchant.isNotEmpty) {
      final ruleId = 'learned_${DateTime.now().millisecondsSinceEpoch}';
      await addCustomRule(ClassificationRule(
        id: ruleId,
        categoryId: categoryId ?? '',
        merchantPattern: merchant,
        defaultClassification: classification,
        priority: 10, // 学习的规则优先级较高
      ));
    }
  }
}

extension on ClassificationResult {
  ClassificationResult copyWith({String? transactionId}) {
    return ClassificationResult(
      transactionId: transactionId ?? this.transactionId,
      classification: classification,
      confidence: confidence,
      reason: reason,
      isUserOverride: isUserOverride,
      classifiedAt: classifiedAt,
    );
  }
}
