import 'dart:async';

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
    // 页面导航意图（支持145页语音导航）
    IntentType.navigate: [
      RegExp(r'打开|进入|去|跳转到?|切换到?|显示'),
      RegExp(r'看看|查看|浏览'),
      RegExp(r'返回|回到'),
      RegExp(r'在哪|怎么找|怎么打开'),
      RegExp(r'首页|设置|统计|报表|账户|分类|预算|钱龄|小金库'),
      RegExp(r'语音|AI|导入|导出|帮助|反馈|安全|隐私'),
      RegExp(r'家庭|成员|邀请|习惯|冲动|分享|成就'),
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
  navigate,         // 页面导航（145页语音导航）
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

  /// 是否为页面导航意图
  bool get isNavigateIntent => type == IntentType.navigate;
}

/// 实体类型
enum EntityType {
  amount,       // 金额
  category,     // 分类
  merchant,     // 商家
  item,         // 物品
  description,  // 描述
  account,      // 账户
  person,       // 人物
  date,         // 日期
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

// ═══════════════════════════════════════════════════════════════
// NLU 增强功能
// ═══════════════════════════════════════════════════════════════

/// 多轮对话状态
enum DialogueState {
  /// 初始状态
  initial,

  /// 等待金额
  waitingForAmount,

  /// 等待分类
  waitingForCategory,

  /// 等待确认
  waitingForConfirmation,

  /// 对话完成
  completed,

  /// 对话取消
  cancelled,
}

/// 槽位填充状态
class SlotFillingState {
  /// 对话状态
  final DialogueState state;

  /// 已填充的槽位
  final Map<String, dynamic> filledSlots;

  /// 缺失的槽位
  final List<String> missingSlots;

  /// 当前询问的槽位
  final String? currentSlot;

  /// 置信度
  final double confidence;

  /// 原始意图
  final IntentType? intent;

  const SlotFillingState({
    required this.state,
    this.filledSlots = const {},
    this.missingSlots = const [],
    this.currentSlot,
    this.confidence = 0.0,
    this.intent,
  });

  /// 是否需要用户补充信息
  bool get needsMoreInfo =>
      state == DialogueState.waitingForAmount ||
      state == DialogueState.waitingForCategory;

  /// 是否已完成
  bool get isComplete => state == DialogueState.completed;

  /// 是否已取消
  bool get isCancelled => state == DialogueState.cancelled;

  SlotFillingState copyWith({
    DialogueState? state,
    Map<String, dynamic>? filledSlots,
    List<String>? missingSlots,
    String? currentSlot,
    double? confidence,
    IntentType? intent,
  }) {
    return SlotFillingState(
      state: state ?? this.state,
      filledSlots: filledSlots ?? this.filledSlots,
      missingSlots: missingSlots ?? this.missingSlots,
      currentSlot: currentSlot ?? this.currentSlot,
      confidence: confidence ?? this.confidence,
      intent: intent ?? this.intent,
    );
  }
}

/// 多轮对话管理器
class DialogueManager {
  SlotFillingState _currentState = const SlotFillingState(
    state: DialogueState.initial,
  );

  final NLUEngine _nluEngine;

  DialogueManager({NLUEngine? nluEngine})
      : _nluEngine = nluEngine ?? NLUEngine();

  /// 获取当前对话状态
  SlotFillingState get currentState => _currentState;

  /// 处理用户输入
  Future<DialogueResponse> processInput(String input) async {
    // 检查是否是取消指令
    if (_isCancel(input)) {
      _currentState = const SlotFillingState(
        state: DialogueState.cancelled,
      );
      return DialogueResponse(
        text: '好的，已取消',
        state: _currentState,
        action: DialogueAction.cancelled,
      );
    }

    // 检查是否是确认指令
    if (_currentState.state == DialogueState.waitingForConfirmation) {
      if (_isConfirm(input)) {
        _currentState = _currentState.copyWith(
          state: DialogueState.completed,
        );
        return DialogueResponse(
          text: '已确认记录',
          state: _currentState,
          action: DialogueAction.confirmed,
          transaction: _buildTransaction(),
        );
      } else {
        _currentState = const SlotFillingState(
          state: DialogueState.cancelled,
        );
        return DialogueResponse(
          text: '好的，已取消',
          state: _currentState,
          action: DialogueAction.cancelled,
        );
      }
    }

    // 解析用户输入
    final result = await _nluEngine.parse(input);

    // 根据当前状态处理
    if (_currentState.state == DialogueState.initial) {
      return _handleInitialInput(result);
    } else if (_currentState.needsMoreInfo) {
      return _handleSlotFilling(input, result);
    }

    return DialogueResponse(
      text: '抱歉，我没有理解您的意思',
      state: _currentState,
      action: DialogueAction.needClarification,
    );
  }

  /// 处理初始输入
  DialogueResponse _handleInitialInput(NLUResult result) {
    if (!result.intent.isRecordIntent) {
      // 非记账意图
      return DialogueResponse(
        text: _getIntentResponse(result.intent.type),
        state: _currentState,
        action: DialogueAction.otherIntent,
        nluResult: result,
      );
    }

    // 记账意图，检查必要槽位
    final filledSlots = <String, dynamic>{};
    final missingSlots = <String>[];

    // 检查金额
    if (result.primaryTransaction?.amount != null) {
      filledSlots['amount'] = result.primaryTransaction!.amount;
    } else {
      missingSlots.add('amount');
    }

    // 检查分类
    if (result.primaryTransaction?.category != null) {
      filledSlots['category'] = result.primaryTransaction!.category;
    } else {
      missingSlots.add('category');
    }

    // 检查日期（可选，默认今天）
    filledSlots['date'] = result.primaryTransaction?.date ?? DateTime.now();

    // 检查描述（可选）
    if (result.primaryTransaction?.description != null) {
      filledSlots['description'] = result.primaryTransaction!.description;
    }

    // 检查商家（可选）
    if (result.primaryTransaction?.merchant != null) {
      filledSlots['merchant'] = result.primaryTransaction!.merchant;
    }

    // 类型
    filledSlots['type'] = result.primaryTransaction?.type ?? TransactionType.expense;

    if (missingSlots.isEmpty) {
      // 所有必要槽位已填充，请求确认
      _currentState = SlotFillingState(
        state: DialogueState.waitingForConfirmation,
        filledSlots: filledSlots,
        missingSlots: [],
        confidence: result.confidence,
        intent: result.intent.type,
      );
      return DialogueResponse(
        text: _generateConfirmationPrompt(filledSlots),
        state: _currentState,
        action: DialogueAction.needConfirmation,
      );
    } else {
      // 需要补充信息
      final nextSlot = missingSlots.first;
      _currentState = SlotFillingState(
        state: _getStateForSlot(nextSlot),
        filledSlots: filledSlots,
        missingSlots: missingSlots,
        currentSlot: nextSlot,
        confidence: result.confidence,
        intent: result.intent.type,
      );
      return DialogueResponse(
        text: _getSlotPrompt(nextSlot),
        state: _currentState,
        action: DialogueAction.needMoreInfo,
      );
    }
  }

  /// 处理槽位填充
  DialogueResponse _handleSlotFilling(String input, NLUResult result) {
    final currentSlot = _currentState.currentSlot;
    final filledSlots = Map<String, dynamic>.from(_currentState.filledSlots);
    final missingSlots = List<String>.from(_currentState.missingSlots);

    // 尝试从输入中提取槽位值
    dynamic slotValue;
    if (currentSlot == 'amount') {
      final amount = AmountParser().parse(input);
      slotValue = amount?.value;
    } else if (currentSlot == 'category') {
      final categories = result.entities
          .where((e) => e.type == EntityType.category)
          .map((e) => e.value)
          .toList();
      slotValue = categories.isNotEmpty ? categories.first : input;
    }

    if (slotValue != null) {
      filledSlots[currentSlot!] = slotValue;
      missingSlots.remove(currentSlot);
    } else {
      // 无法提取，使用原始输入
      if (currentSlot == 'category') {
        filledSlots[currentSlot!] = input;
        missingSlots.remove(currentSlot);
      } else {
        return DialogueResponse(
          text: '抱歉，我没有理解。${_getSlotPrompt(currentSlot!)}',
          state: _currentState,
          action: DialogueAction.needMoreInfo,
        );
      }
    }

    if (missingSlots.isEmpty) {
      // 所有槽位已填充，请求确认
      _currentState = SlotFillingState(
        state: DialogueState.waitingForConfirmation,
        filledSlots: filledSlots,
        missingSlots: [],
        confidence: _currentState.confidence,
        intent: _currentState.intent,
      );
      return DialogueResponse(
        text: _generateConfirmationPrompt(filledSlots),
        state: _currentState,
        action: DialogueAction.needConfirmation,
      );
    } else {
      // 继续询问下一个槽位
      final nextSlot = missingSlots.first;
      _currentState = SlotFillingState(
        state: _getStateForSlot(nextSlot),
        filledSlots: filledSlots,
        missingSlots: missingSlots,
        currentSlot: nextSlot,
        confidence: _currentState.confidence,
        intent: _currentState.intent,
      );
      return DialogueResponse(
        text: _getSlotPrompt(nextSlot),
        state: _currentState,
        action: DialogueAction.needMoreInfo,
      );
    }
  }

  /// 重置对话
  void reset() {
    _currentState = const SlotFillingState(
      state: DialogueState.initial,
    );
  }

  /// 构建交易
  ParsedTransaction? _buildTransaction() {
    final slots = _currentState.filledSlots;
    if (slots['amount'] == null) return null;

    return ParsedTransaction(
      type: slots['type'] as TransactionType? ?? TransactionType.expense,
      amount: slots['amount'] as double,
      category: slots['category'] as String?,
      merchant: slots['merchant'] as String?,
      description: slots['description'] as String?,
      date: slots['date'] as DateTime? ?? DateTime.now(),
      confidence: _currentState.confidence,
    );
  }

  bool _isConfirm(String input) {
    final lower = input.toLowerCase();
    return RegExp(r'^(是|对|确认|好的?|可以|没问题|ok|yes)$').hasMatch(lower);
  }

  bool _isCancel(String input) {
    final lower = input.toLowerCase();
    return RegExp(r'^(取消|算了|不要|不用了?|no)$').hasMatch(lower);
  }

  DialogueState _getStateForSlot(String slot) {
    switch (slot) {
      case 'amount':
        return DialogueState.waitingForAmount;
      case 'category':
        return DialogueState.waitingForCategory;
      default:
        return DialogueState.initial;
    }
  }

  String _getSlotPrompt(String slot) {
    switch (slot) {
      case 'amount':
        return '请告诉我金额是多少？';
      case 'category':
        return '请选择消费分类，比如餐饮、交通、购物等';
      default:
        return '请提供更多信息';
    }
  }

  String _generateConfirmationPrompt(Map<String, dynamic> slots) {
    final type = slots['type'] == TransactionType.income ? '收入' : '支出';
    final amount = slots['amount'] as double;
    final category = slots['category'] as String? ?? '未分类';
    final date = slots['date'] as DateTime;
    final dateStr = date.day == DateTime.now().day ? '今天' : '${date.month}月${date.day}日';

    return '确认记录$dateStr$category$type${amount.toStringAsFixed(2)}元，请说"确认"或"取消"';
  }

  String _getIntentResponse(IntentType type) {
    switch (type) {
      case IntentType.queryBalance:
        return '您想查询余额，让我来帮您查看';
      case IntentType.queryExpense:
        return '您想查询消费，让我来帮您统计';
      case IntentType.queryBudget:
        return '您想查看预算情况';
      case IntentType.setBudget:
        return '您想设置预算';
      case IntentType.navigate:
        return '您想打开某个页面';
      default:
        return '我来帮您处理';
    }
  }
}

/// 对话动作
enum DialogueAction {
  /// 需要更多信息
  needMoreInfo,

  /// 需要确认
  needConfirmation,

  /// 已确认
  confirmed,

  /// 已取消
  cancelled,

  /// 需要澄清
  needClarification,

  /// 其他意图
  otherIntent,
}

/// 对话响应
class DialogueResponse {
  /// 响应文本
  final String text;

  /// 对话状态
  final SlotFillingState state;

  /// 对话动作
  final DialogueAction action;

  /// 解析后的交易（如果已完成）
  final ParsedTransaction? transaction;

  /// NLU 结果（如果有）
  final NLUResult? nluResult;

  const DialogueResponse({
    required this.text,
    required this.state,
    required this.action,
    this.transaction,
    this.nluResult,
  });
}

/// 增强实体提取器
///
/// 支持更多实体类型和更精确的提取
class EnhancedEntityExtractor extends EntityExtractor {
  /// 数量词映射
  static const Map<String, int> _quantityWords = {
    '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5,
    '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
    '几': 3, // 默认值
  };

  /// 货币单位
  // ignore: unused_field
  static const Map<String, double> __currencyUnits = {
    '元': 1,
    '块': 1,
    '毛': 0.1,
    '角': 0.1,
    '分': 0.01,
    '万': 10000,
    '千': 1000,
    '百': 100,
  };

  /// 提取所有实体（增强版）
  @override
  Future<List<NLUEntity>> extract(String text) async {
    final entities = await super.extract(text);

    // 提取更多实体类型
    entities.addAll(_extractQuantities(text));
    entities.addAll(_extractPaymentMethods(text));
    entities.addAll(_extractLocations(text));

    return _deduplicateEntities(entities);
  }

  /// 提取数量
  List<NLUEntity> _extractQuantities(String text) {
    final entities = <NLUEntity>[];

    // 匹配 "N个/份/杯" 等
    final pattern = RegExp(r'([一二两三四五六七八九十几\d]+)(个|份|杯|瓶|包|盒|件)');
    for (final match in pattern.allMatches(text)) {
      final quantityStr = match.group(1)!;
      int? quantity;

      if (_quantityWords.containsKey(quantityStr)) {
        quantity = _quantityWords[quantityStr];
      } else {
        quantity = int.tryParse(quantityStr);
      }

      if (quantity != null) {
        entities.add(NLUEntity(
          type: EntityType.description,
          value: '$quantity${match.group(2)}',
          confidence: 0.85,
          startIndex: match.start,
          endIndex: match.end,
        ));
      }
    }

    return entities;
  }

  /// 提取支付方式
  List<NLUEntity> _extractPaymentMethods(String text) {
    final entities = <NLUEntity>[];

    const paymentMethods = [
      '微信', '支付宝', '现金', '银行卡', '信用卡', '花呗', '京东白条',
      'Apple Pay', 'WeChat Pay', 'Alipay',
    ];

    for (final method in paymentMethods) {
      if (text.contains(method)) {
        entities.add(NLUEntity(
          type: EntityType.account,
          value: method,
          confidence: 0.9,
          startIndex: text.indexOf(method),
          endIndex: text.indexOf(method) + method.length,
        ));
      }
    }

    return entities;
  }

  /// 提取地点
  List<NLUEntity> _extractLocations(String text) {
    final entities = <NLUEntity>[];

    // 匹配 "在XX" 模式
    final pattern = RegExp(r'在([^，。、\s]{2,10})');
    for (final match in pattern.allMatches(text)) {
      final location = match.group(1)!;
      // 过滤掉动词
      if (!RegExp(r'^(买|吃|消费|花|付|给|用)').hasMatch(location)) {
        entities.add(NLUEntity(
          type: EntityType.merchant,
          value: location,
          confidence: 0.75,
          startIndex: match.start,
          endIndex: match.end,
        ));
      }
    }

    return entities;
  }
}

/// NLU 结果构建器
///
/// 方便构建 NLU 结果用于测试
class NLUResultBuilder {
  IntentType _intentType = IntentType.unknown;
  double _confidence = 0.5;
  final List<NLUEntity> _entities = [];
  double? _amount;
  DateTime? _date;
  String _rawText = '';

  NLUResultBuilder intent(IntentType type, {double confidence = 0.8}) {
    _intentType = type;
    _confidence = confidence;
    return this;
  }

  NLUResultBuilder addEntity(EntityType type, String value, {double confidence = 0.8}) {
    _entities.add(NLUEntity(
      type: type,
      value: value,
      confidence: confidence,
      startIndex: 0,
      endIndex: value.length,
    ));
    return this;
  }

  NLUResultBuilder amount(double value) {
    _amount = value;
    return this;
  }

  NLUResultBuilder date(DateTime value) {
    _date = value;
    return this;
  }

  NLUResultBuilder rawText(String text) {
    _rawText = text;
    return this;
  }

  NLUResult build() {
    final transactions = <ParsedTransaction>[];

    if (_intentType == IntentType.recordExpense ||
        _intentType == IntentType.recordIncome) {
      if (_amount != null) {
        transactions.add(ParsedTransaction(
          type: _intentType == IntentType.recordIncome
              ? TransactionType.income
              : TransactionType.expense,
          amount: _amount!,
          category: _entities
              .where((e) => e.type == EntityType.category)
              .map((e) => e.value)
              .firstOrNull,
          merchant: _entities
              .where((e) => e.type == EntityType.merchant)
              .map((e) => e.value)
              .firstOrNull,
          date: _date ?? DateTime.now(),
          confidence: _confidence,
        ));
      }
    }

    return NLUResult(
      intent: NLUIntent(type: _intentType, confidence: _confidence),
      entities: _entities,
      transactions: transactions,
      confidence: _confidence,
      rawText: _rawText,
      normalizedText: _rawText.toLowerCase(),
    );
  }
}
