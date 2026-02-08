import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 智能分类服务 - 四层混合策略
///
/// 第一层：商家历史匹配（置信度最高）
/// 第二层：关键词规则匹配
/// 第三层：本地ML模型
/// 第四层：大模型语义理解（兜底）
class SmartCategoryService {
  final CategoryRepository _categoryRepo;
  final TransactionRepository _transactionRepo;
  final LLMService _llmService;
  final LocalMLService _localML;

  SmartCategoryService({
    required CategoryRepository categoryRepo,
    required TransactionRepository transactionRepo,
    LLMService? llmService,
    LocalMLService? localML,
  })  : _categoryRepo = categoryRepo,
        _transactionRepo = transactionRepo,
        _llmService = llmService ?? LLMService(),
        _localML = localML ?? LocalMLService();

  /// 关键词映射表（规则引擎 - 第二层）
  static const Map<String, List<String>> _keywordMap = {
    '餐饮': [
      '早餐', '午餐', '晚餐', '外卖', '美团', '饿了么', '堂食',
      '火锅', '烧烤', '奶茶', '咖啡', '面包', '蛋糕', '小吃',
      '食堂', '便当', '快餐', '自助餐', '下午茶',
    ],
    '交通': [
      '打车', '滴滴', '地铁', '公交', '加油', '停车', '高铁',
      '机票', '高速费', '过路费', '出租车', '顺风车', '共享单车',
      'ETC', '火车票', '汽车票',
    ],
    '购物': [
      '淘宝', '京东', '拼多多', '超市', '商场', '天猫', '苏宁',
      '百货', '便利店', '网购', '代购', '闲鱼', '唯品会',
    ],
    '居住': [
      '房租', '水费', '电费', '燃气', '物业', '暖气', '宽带',
      '网费', '房贷', '维修', '家具', '家电', '装修',
    ],
    '娱乐': [
      '电影', '游戏', 'KTV', '演出', '旅游', '门票', '景区',
      '酒店', '民宿', '演唱会', '话剧', '展览', '健身',
    ],
    '医疗': [
      '医院', '药店', '挂号', '体检', '看病', '门诊', '住院',
      '药费', '检查', '化验', '手术', '保健品',
    ],
    '教育': [
      '学费', '培训', '课程', '书籍', '考试', '报名费', '教材',
      '补习', '网课', '证书', '辅导',
    ],
    '通讯': [
      '话费', '流量', '充值', '手机', '电话费', '套餐',
    ],
    '服饰': [
      '衣服', '鞋子', '包包', '配饰', '服装', '鞋', '帽子',
      '围巾', '手套', '内衣',
    ],
    '美容': [
      '理发', '美发', '美甲', '护肤', '化妆品', '美容院',
      'spa', '按摩',
    ],
    '人情': [
      '红包', '礼金', '份子钱', '送礼', '请客', '聚餐',
    ],
    '投资': [
      '理财', '基金', '股票', '定期', '存款', '保险',
    ],
    '工资': [
      '工资', '薪资', '薪水', '月薪', '奖金', '年终奖', '提成',
    ],
    '兼职': [
      '兼职', '副业', '外快', '稿费', '佣金',
    ],
    '转账': [
      '转账', '汇款', '还款', '借款',
    ],
  };

  /// 推荐分类（四层策略）
  Future<List<CategorySuggestion>> suggestCategories({
    required String description,
    required double amount,
    String? merchant,
    DateTime? date,
  }) async {
    final suggestions = <CategorySuggestion>[];

    // ========== 第一层：商家历史匹配（置信度最高） ==========
    if (merchant != null && merchant.isNotEmpty) {
      final merchantSuggestion = await _matchByMerchantHistory(merchant);
      if (merchantSuggestion != null) {
        suggestions.add(merchantSuggestion);
      }
    }

    // ========== 第二层：关键词规则匹配 ==========
    final keywordMatch = _matchByKeywords(description);
    if (keywordMatch != null) {
      final category = await _categoryRepo.findByName(keywordMatch.categoryName);
      if (category != null) {
        final isDuplicate = suggestions.any((s) => s.category.id == category.id);
        if (!isDuplicate) {
          suggestions.add(CategorySuggestion(
            category: category,
            confidence: 0.75,
            reason: '包含关键词"${keywordMatch.matchedKeyword}"',
            source: SuggestionSource.keywordMatch,
          ));
        }
      }
    }

    // ========== 第三层：本地ML模型 ==========
    try {
      final mlResult = await _localML.classifyTransaction(
        description: description,
        amount: amount,
        dayOfWeek: date?.weekday,
        hourOfDay: date?.hour,
      );

      if (mlResult.confidence > 0.6) {
        final category = await _categoryRepo.getById(mlResult.categoryId);
        if (category != null) {
          final isDuplicate = suggestions.any((s) => s.category.id == category.id);
          if (!isDuplicate) {
            suggestions.add(CategorySuggestion(
              category: category,
              confidence: mlResult.confidence * 0.85,
              reason: '本地AI分析',
              source: SuggestionSource.localML,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Local ML classification failed: $e');
    }

    // ========== 第四层：大模型语义理解（兜底） ==========
    final maxConfidence = suggestions.isEmpty
        ? 0.0
        : suggestions.map((s) => s.confidence).reduce(max);

    if (maxConfidence < 0.75) {
      try {
        final llmResult = await _llmService.classifyExpense(
          description: description,
          amount: amount,
          merchant: merchant,
          availableCategories: await _categoryRepo.getAllExpenseCategories(),
        );

        if (llmResult != null && llmResult.confidence > 0.5) {
          final isDuplicate =
              suggestions.any((s) => s.category.id == llmResult.category.id);
          if (!isDuplicate) {
            suggestions.add(CategorySuggestion(
              category: llmResult.category,
              confidence: llmResult.confidence,
              reason: llmResult.explanation,
              source: SuggestionSource.llmAnalysis,
            ));
          }
        }
      } catch (e) {
        debugPrint('LLM classification failed: $e');
      }
    }

    // 去重并按置信度排序
    return _deduplicateAndSort(suggestions);
  }

  /// 商家历史匹配
  Future<CategorySuggestion?> _matchByMerchantHistory(String merchant) async {
    final history = await _transactionRepo.findByMerchant(merchant, limit: 20);
    if (history.length < 3) return null;

    final categoryVotes = <String, int>{};
    for (final tx in history) {
      if (tx.categoryId != null) {
        categoryVotes[tx.categoryId!] = (categoryVotes[tx.categoryId!] ?? 0) + 1;
      }
    }

    if (categoryVotes.isEmpty) return null;

    final topEntry =
        categoryVotes.entries.reduce((a, b) => a.value > b.value ? a : b);
    final frequency = topEntry.value / history.length;

    if (frequency < 0.6) return null;

    final category = await _categoryRepo.getById(topEntry.key);
    if (category == null) return null;

    return CategorySuggestion(
      category: category,
      confidence: 0.85 + frequency * 0.1,
      reason: '在"$merchant"的消费通常记为${category.name}',
      source: SuggestionSource.merchantHistory,
    );
  }

  /// 关键词匹配（正则支持）
  KeywordMatchResult? _matchByKeywords(String description) {
    final lowerDesc = description.toLowerCase();

    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        final pattern = RegExp(keyword, caseSensitive: false);
        if (pattern.hasMatch(lowerDesc)) {
          return KeywordMatchResult(
            categoryName: entry.key,
            matchedKeyword: keyword,
          );
        }
      }
    }
    return null;
  }

  /// 去重并按置信度排序
  List<CategorySuggestion> _deduplicateAndSort(
      List<CategorySuggestion> suggestions) {
    final seen = <String, CategorySuggestion>{};

    for (final suggestion in suggestions) {
      final key = suggestion.category.id;
      if (!seen.containsKey(key) ||
          seen[key]!.confidence < suggestion.confidence) {
        seen[key] = suggestion;
      }
    }

    final result = seen.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return result.take(5).toList();
  }

  /// 记录用户反馈（用于学习）
  Future<void> recordFeedback({
    required String transactionId,
    required String originalCategoryId,
    required String correctedCategoryId,
    required String merchant,
    required String description,
    required double amount,
  }) async {
    // 记录反馈到数据库，用于后续模型训练
    debugPrint(
      'Feedback recorded: $transactionId '
      '$originalCategoryId -> $correctedCategoryId',
    );
  }
}

/// 分类建议
class CategorySuggestion {
  final Category category;
  final double confidence;
  final String reason;
  final SuggestionSource source;

  const CategorySuggestion({
    required this.category,
    required this.confidence,
    required this.reason,
    required this.source,
  });
}

/// 建议来源枚举
enum SuggestionSource {
  merchantHistory, // 商家历史
  keywordMatch,    // 关键词匹配
  localML,         // 本地ML模型
  llmAnalysis,     // 大模型分析
  amountPattern,   // 金额模式
  timePattern,     // 时间模式
  locationContext, // 位置上下文
}

/// 关键词匹配结果
class KeywordMatchResult {
  final String categoryName;
  final String matchedKeyword;

  const KeywordMatchResult({
    required this.categoryName,
    required this.matchedKeyword,
  });
}

/// 分类数据模型
class Category {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final CategoryType type;
  final String? parentId;

  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.type,
    this.parentId,
  });
}

enum CategoryType {
  expense,
  income,
  transfer,
}

/// 交易数据模型（简化版）
class TransactionRecord {
  final String id;
  final String? categoryId;
  final String? merchant;
  final double amount;
  final DateTime date;

  const TransactionRecord({
    required this.id,
    this.categoryId,
    this.merchant,
    required this.amount,
    required this.date,
  });
}

/// 分类仓库接口
abstract class CategoryRepository {
  Future<Category?> getById(String id);
  Future<Category?> findByName(String name);
  Future<List<Category>> getAllExpenseCategories();
  Future<List<Category>> getAllIncomeCategories();
}

/// 交易仓库接口
abstract class TransactionRepository {
  Future<List<TransactionRecord>> findByMerchant(String merchant, {int limit});
}

/// 本地ML服务
class LocalMLService {
  bool _isInitialized = false;

  /// 初始化模型
  Future<void> initialize() async {
    if (_isInitialized) return;
    // 加载TFLite模型
    await Future.delayed(const Duration(milliseconds: 500));
    _isInitialized = true;
  }

  /// 分类交易
  Future<MLClassificationResult> classifyTransaction({
    required String description,
    required double amount,
    int? dayOfWeek,
    int? hourOfDay,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 模拟ML分类结果
    // 实际实现需要调用TFLite模型
    await Future.delayed(const Duration(milliseconds: 100));

    // 基于简单规则模拟
    String categoryId = 'other';
    double confidence = 0.5;

    if (description.contains('餐') || description.contains('吃')) {
      categoryId = 'food';
      confidence = 0.7;
    } else if (description.contains('车') || description.contains('交通')) {
      categoryId = 'transport';
      confidence = 0.7;
    } else if (description.contains('买') || description.contains('购')) {
      categoryId = 'shopping';
      confidence = 0.65;
    }

    // 时间特征增强
    if (hourOfDay != null) {
      if ((hourOfDay >= 7 && hourOfDay <= 9) ||
          (hourOfDay >= 11 && hourOfDay <= 13) ||
          (hourOfDay >= 18 && hourOfDay <= 20)) {
        if (categoryId == 'food') {
          confidence += 0.1;
        }
      }
    }

    return MLClassificationResult(
      categoryId: categoryId,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }
}

/// ML分类结果
class MLClassificationResult {
  final String categoryId;
  final double confidence;

  const MLClassificationResult({
    required this.categoryId,
    required this.confidence,
  });
}

/// LLM服务
class LLMService {
  /// 使用大模型进行分类
  Future<LLMClassificationResult?> classifyExpense({
    required String description,
    required double amount,
    String? merchant,
    required List<Category> availableCategories,
  }) async {
    if (availableCategories.isEmpty) return null;

    // 模拟LLM调用
    // 实际实现需要调用通义千问或其他LLM API
    await Future.delayed(const Duration(milliseconds: 300));

    // 简单模拟：选择第一个匹配的分类
    for (final category in availableCategories) {
      if (description.contains(category.name)) {
        return LLMClassificationResult(
          category: category,
          confidence: 0.7,
          explanation: '语义分析匹配"${category.name}"',
        );
      }
    }

    // 默认返回第一个分类
    return LLMClassificationResult(
      category: availableCategories.first,
      confidence: 0.5,
      explanation: 'AI推荐',
    );
  }
}

/// LLM分类结果
class LLMClassificationResult {
  final Category category;
  final double confidence;
  final String explanation;

  const LLMClassificationResult({
    required this.category,
    required this.confidence,
    required this.explanation,
  });
}
