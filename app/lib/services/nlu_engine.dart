import 'dart:async';

import 'package:flutter/foundation.dart';

/// 自然语言理解引擎
/// 解析用户输入，提取记账意图和实体
class NLUEngine {
  final IntentClassifier _intentClassifier;
  final EntityExtractor _entityExtractor;
  final ContextManager _contextManager;
  final AmountParser _amountParser;
  final DateTimeParser _dateTimeParser;

  NLUEngine({
    IntentClassifier? intentClassifier,
    EntityExtractor? entityExtractor,
    ContextManager? contextManager,
  })  : _intentClassifier = intentClassifier ?? IntentClassifier(),
        _entityExtractor = entityExtractor ?? EntityExtractor(),
        _contextManager = contextManager ?? ContextManager(),
        _amountParser = AmountParser(),
        _dateTimeParser = DateTimeParser();

  /// 解析用户输入
  Future<NLUResult> parse(
    String text, {
    NLUContext? context,
  }) async {
    // 1. 预处理文本
    final normalizedText = _normalizeText(text);

    // 2. 意图识别
    final intent = await _intentClassifier.classify(normalizedText);

    // 3. 实体提取
    final entities = await _entityExtractor.extract(normalizedText);

    // 4. 金额解析
    final amount = _amountParser.parse(normalizedText);

    // 5. 时间解析
    final dateTime = _dateTimeParser.parse(normalizedText);

    // 6. 上下文补全
    final completedEntities = _contextManager.completeEntities(
      entities,
      context: context,
    );

    // 7. 构建交易列表
    final transactions = _buildTransactions(
      intent: intent,
      entities: completedEntities,
      amount: amount,
      dateTime: dateTime,
    );

    return NLUResult(
      intent: intent,
      entities: completedEntities,
      transactions: transactions,
      confidence: _calculateConfidence(intent, completedEntities),
      rawText: text,
      normalizedText: normalizedText,
    );
  }

  /// 文本预处理
  String _normalizeText(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  /// 构建交易列表
  List<ParsedTransaction> _buildTransactions({
    required NLUIntent intent,
    required List<NLUEntity> entities,
    required ParsedAmount? amount,
    required ParsedDateTime? dateTime,
  }) {
    if (intent.type != IntentType.recordExpense &&
        intent.type != IntentType.recordIncome &&
        intent.type != IntentType.recordTransfer) {
      return [];
    }

    // 提取关键实体
    final category = entities
        .where((e) => e.type == EntityType.category)
        .firstOrNull;
    final merchant = entities
        .where((e) => e.type == EntityType.merchant)
        .firstOrNull;
    final description = entities
        .where((e) => e.type == EntityType.description)
        .firstOrNull;

    if (amount == null) {
      return []; // 没有金额无法记账
    }

    return [
      ParsedTransaction(
        type: intent.type == IntentType.recordIncome
            ? TransactionType.income
            : intent.type == IntentType.recordTransfer
                ? TransactionType.transfer
                : TransactionType.expense,
        amount: amount.value,
        category: category?.value,
        merchant: merchant?.value,
        description: description?.value ?? _generateDescription(entities),
        date: dateTime?.dateTime ?? DateTime.now(),
        confidence: intent.confidence,
      ),
    ];
  }

  /// 生成描述
  String _generateDescription(List<NLUEntity> entities) {
    final parts = <String>[];
    for (final entity in entities) {
      if (entity.type == EntityType.item ||
          entity.type == EntityType.description) {
        parts.add(entity.value);
      }
    }
    return parts.join(' ');
  }

  /// 计算整体置信度
  double _calculateConfidence(NLUIntent intent, List<NLUEntity> entities) {
    if (entities.isEmpty) return intent.confidence * 0.5;

    final entityConfidence =
        entities.map((e) => e.confidence).reduce((a, b) => a + b) /
            entities.length;

    return (intent.confidence + entityConfidence) / 2;
  }
}

/// 意图分类器
class IntentClassifier {
  /// 记账相关意图模式
  static final Map<IntentType, List<RegExp>> _intentPatterns = {
    IntentType.recordExpense: [
      RegExp(r'花了|花费|支出|买了|消费|付了|给了'),
      RegExp(r'(\d+)块|(\d+)元'),
    ],
    IntentType.recordIncome: [
      RegExp(r'收入|收到|工资|奖金|入账|进账|赚了'),
    ],
    IntentType.recordTransfer: [
      RegExp(r'转账|转给|转到'),
    ],
    IntentType.queryBalance: [
      RegExp(r'余额|还剩|剩余|多少钱'),
    ],
    IntentType.queryExpense: [
      RegExp(r'花了多少|支出多少|消费了|统计'),
    ],
    IntentType.queryBudget: [
      RegExp(r'预算|还能花|剩多少'),
    ],
    IntentType.setBudget: [
      RegExp(r'设置预算|预算设为|预算改成'),
    ],
    IntentType.queryMoneyAge: [
      RegExp(r'钱龄|资金年龄|财务健康'),
    ],
  };

  /// 分类意图
  Future<NLUIntent> classify(String text) async {
    IntentType bestIntent = IntentType.unknown;
    double bestScore = 0;

    for (final entry in _intentPatterns.entries) {
      int matchCount = 0;
      for (final pattern in entry.value) {
        if (pattern.hasMatch(text)) {
          matchCount++;
        }
      }
      if (matchCount > 0) {
        final score = matchCount / entry.value.length;
        if (score > bestScore) {
          bestScore = score;
          bestIntent = entry.key;
        }
      }
    }

    // 默认为记账支出
    if (bestIntent == IntentType.unknown && _hasAmount(text)) {
      bestIntent = IntentType.recordExpense;
      bestScore = 0.6;
    }

    return NLUIntent(
      type: bestIntent,
      confidence: bestScore.clamp(0.0, 1.0),
    );
  }

  bool _hasAmount(String text) {
    return RegExp(r'\d+').hasMatch(text);
  }
}

/// 实体提取器
class EntityExtractor {
  /// 实体提取模式
  static final Map<EntityType, List<RegExp>> _entityPatterns = {
    EntityType.category: [
      RegExp(r'(餐饮|早餐|午餐|晚餐|外卖|美食)'),
      RegExp(r'(交通|打车|地铁|公交|加油|停车)'),
      RegExp(r'(购物|淘宝|京东|超市|商场)'),
      RegExp(r'(居住|房租|水费|电费|物业)'),
      RegExp(r'(娱乐|电影|游戏|旅游)'),
      RegExp(r'(医疗|医院|药店|看病)'),
      RegExp(r'(教育|学费|培训|书籍)'),
    ],
    EntityType.merchant: [
      RegExp(r'在(.{2,10})(买|吃|消费|花)'),
      RegExp(r'(美团|饿了么|滴滴|支付宝|微信)'),
      RegExp(r'(肯德基|麦当劳|星巴克|瑞幸)'),
    ],
    EntityType.item: [
      RegExp(r'买了?(.{1,10}?)(\d+|花了)'),
      RegExp(r'(一杯|一个|一份)(.{1,6})'),
    ],
  };

  /// 类目映射表
  static const Map<String, String> _categoryMapping = {
    '早餐': '餐饮',
    '午餐': '餐饮',
    '晚餐': '餐饮',
    '外卖': '餐饮',
    '美食': '餐饮',
    '打车': '交通',
    '地铁': '交通',
    '公交': '交通',
    '加油': '交通',
    '停车': '交通',
    '淘宝': '购物',
    '京东': '购物',
    '超市': '购物',
    '商场': '购物',
    '房租': '居住',
    '水费': '居住',
    '电费': '居住',
    '物业': '居住',
    '电影': '娱乐',
    '游戏': '娱乐',
    '旅游': '娱乐',
    '医院': '医疗',
    '药店': '医疗',
    '看病': '医疗',
    '学费': '教育',
    '培训': '教育',
    '书籍': '教育',
  };

  /// 提取实体
  Future<List<NLUEntity>> extract(String text) async {
    final entities = <NLUEntity>[];

    for (final entry in _entityPatterns.entries) {
      for (final pattern in entry.value) {
        final matches = pattern.allMatches(text);
        for (final match in matches) {
          String value = match.group(1) ?? match.group(0) ?? '';

          // 类目映射
          if (entry.key == EntityType.category) {
            value = _categoryMapping[value] ?? value;
          }

          if (value.isNotEmpty) {
            entities.add(NLUEntity(
              type: entry.key,
              value: value,
              confidence: 0.8,
              startIndex: match.start,
              endIndex: match.end,
            ));
          }
        }
      }
    }

    // 去重
    return _deduplicateEntities(entities);
  }

  List<NLUEntity> _deduplicateEntities(List<NLUEntity> entities) {
    final seen = <String, NLUEntity>{};
    for (final entity in entities) {
      final key = '${entity.type}_${entity.value}';
      if (!seen.containsKey(key) ||
          seen[key]!.confidence < entity.confidence) {
        seen[key] = entity;
      }
    }
    return seen.values.toList();
  }
}

/// 金额解析器
class AmountParser {
  /// 解析金额
  ParsedAmount? parse(String text) {
    // 匹配数字金额
    final patterns = [
      RegExp(r'(\d+\.?\d*)\s*[元块]'),
      RegExp(r'[花费支出消费付了给了买了]\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.?\d*)\s*[毛角]'),
      RegExp(r'(\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final valueStr = match.group(1);
        if (valueStr != null) {
          final value = double.tryParse(valueStr);
          if (value != null && value > 0) {
            // 处理"毛/角"单位
            final isDecimal = text.contains('毛') || text.contains('角');
            return ParsedAmount(
              value: isDecimal ? value / 10 : value,
              confidence: 0.9,
              rawText: match.group(0) ?? '',
            );
          }
        }
      }
    }

    return null;
  }
}

/// 日期时间解析器
class DateTimeParser {
  /// 解析日期时间
  ParsedDateTime? parse(String text) {
    final now = DateTime.now();

    // 相对日期
    if (text.contains('今天')) {
      return ParsedDateTime(
        dateTime: now,
        confidence: 0.95,
        isRelative: true,
      );
    }
    if (text.contains('昨天')) {
      return ParsedDateTime(
        dateTime: now.subtract(const Duration(days: 1)),
        confidence: 0.95,
        isRelative: true,
      );
    }
    if (text.contains('前天')) {
      return ParsedDateTime(
        dateTime: now.subtract(const Duration(days: 2)),
        confidence: 0.95,
        isRelative: true,
      );
    }

    // 上周/上个月
    if (text.contains('上周')) {
      return ParsedDateTime(
        dateTime: now.subtract(const Duration(days: 7)),
        confidence: 0.8,
        isRelative: true,
      );
    }
    if (text.contains('上个月')) {
      return ParsedDateTime(
        dateTime: DateTime(now.year, now.month - 1, now.day),
        confidence: 0.8,
        isRelative: true,
      );
    }

    // 具体日期 (MM月DD日)
    final datePattern = RegExp(r'(\d{1,2})月(\d{1,2})[日号]?');
    final dateMatch = datePattern.firstMatch(text);
    if (dateMatch != null) {
      final month = int.tryParse(dateMatch.group(1) ?? '');
      final day = int.tryParse(dateMatch.group(2) ?? '');
      if (month != null && day != null) {
        return ParsedDateTime(
          dateTime: DateTime(now.year, month, day),
          confidence: 0.9,
          isRelative: false,
        );
      }
    }

    // 时间段（早上/中午/晚上）
    if (text.contains('早上') || text.contains('早餐')) {
      return ParsedDateTime(
        dateTime: DateTime(now.year, now.month, now.day, 8),
        confidence: 0.7,
        isRelative: true,
      );
    }
    if (text.contains('中午') || text.contains('午餐')) {
      return ParsedDateTime(
        dateTime: DateTime(now.year, now.month, now.day, 12),
        confidence: 0.7,
        isRelative: true,
      );
    }
    if (text.contains('晚上') || text.contains('晚餐')) {
      return ParsedDateTime(
        dateTime: DateTime(now.year, now.month, now.day, 19),
        confidence: 0.7,
        isRelative: true,
      );
    }

    return null;
  }
}

/// 上下文管理器
class ContextManager {
  NLUContext? _currentContext;

  /// 更新上下文
  void updateContext(NLUContext context) {
    _currentContext = context;
  }

  /// 补全实体（使用上下文信息）
  List<NLUEntity> completeEntities(
    List<NLUEntity> entities, {
    NLUContext? context,
  }) {
    final effectiveContext = context ?? _currentContext;
    if (effectiveContext == null) return entities;

    final result = List<NLUEntity>.from(entities);

    // 如果没有类目，使用上下文中的默认类目
    final hasCategory = entities.any((e) => e.type == EntityType.category);
    if (!hasCategory && effectiveContext.defaultCategory != null) {
      result.add(NLUEntity(
        type: EntityType.category,
        value: effectiveContext.defaultCategory!,
        confidence: 0.6,
        startIndex: 0,
        endIndex: 0,
        fromContext: true,
      ));
    }

    return result;
  }

  /// 清除上下文
  void clearContext() {
    _currentContext = null;
  }
}

// ==================== 数据模型 ====================

/// NLU解析结果
class NLUResult {
  final NLUIntent intent;
  final List<NLUEntity> entities;
  final List<ParsedTransaction> transactions;
  final double confidence;
  final String rawText;
  final String normalizedText;

  const NLUResult({
    required this.intent,
    required this.entities,
    required this.transactions,
    required this.confidence,
    required this.rawText,
    required this.normalizedText,
  });

  /// 是否成功解析出交易
  bool get hasTransactions => transactions.isNotEmpty;

  /// 获取主要交易
  ParsedTransaction? get primaryTransaction =>
      transactions.isNotEmpty ? transactions.first : null;
}

/// 意图类型
enum IntentType {
  recordExpense,    // 记录支出
  recordIncome,     // 记录收入
  recordTransfer,   // 记录转账
  queryBalance,     // 查询余额
  queryExpense,     // 查询支出
  queryBudget,      // 查询预算
  setBudget,        // 设置预算
  queryMoneyAge,    // 查询钱龄
  deleteRecord,     // 删除记录
  modifyRecord,     // 修改记录
  unknown,          // 未知意图
}

/// 意图
class NLUIntent {
  final IntentType type;
  final double confidence;

  const NLUIntent({
    required this.type,
    required this.confidence,
  });

  bool get isRecordIntent =>
      type == IntentType.recordExpense ||
      type == IntentType.recordIncome ||
      type == IntentType.recordTransfer;

  bool get isQueryIntent =>
      type == IntentType.queryBalance ||
      type == IntentType.queryExpense ||
      type == IntentType.queryBudget ||
      type == IntentType.queryMoneyAge;
}

/// 实体类型
enum EntityType {
  category,     // 分类
  merchant,     // 商家
  item,         // 物品
  description,  // 描述
  account,      // 账户
  person,       // 人物
}

/// 实体
class NLUEntity {
  final EntityType type;
  final String value;
  final double confidence;
  final int startIndex;
  final int endIndex;
  final bool fromContext;

  const NLUEntity({
    required this.type,
    required this.value,
    required this.confidence,
    required this.startIndex,
    required this.endIndex,
    this.fromContext = false,
  });
}

/// 解析后的金额
class ParsedAmount {
  final double value;
  final double confidence;
  final String rawText;

  const ParsedAmount({
    required this.value,
    required this.confidence,
    required this.rawText,
  });
}

/// 解析后的日期时间
class ParsedDateTime {
  final DateTime dateTime;
  final double confidence;
  final bool isRelative;

  const ParsedDateTime({
    required this.dateTime,
    required this.confidence,
    required this.isRelative,
  });
}

/// NLU上下文
class NLUContext {
  final String? defaultCategory;
  final String? defaultAccount;
  final String? lastMerchant;
  final DateTime? referenceDate;

  const NLUContext({
    this.defaultCategory,
    this.defaultAccount,
    this.lastMerchant,
    this.referenceDate,
  });
}

/// 解析后的交易
class ParsedTransaction {
  final TransactionType type;
  final double amount;
  final String? category;
  final String? merchant;
  final String? description;
  final DateTime date;
  final double confidence;

  const ParsedTransaction({
    required this.type,
    required this.amount,
    this.category,
    this.merchant,
    this.description,
    required this.date,
    required this.confidence,
  });
}

/// 交易类型
enum TransactionType {
  expense,
  income,
  transfer,
}
