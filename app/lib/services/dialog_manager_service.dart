import 'dart:async';

/// 对话式记账助手服务
///
/// 功能：
/// 1. 多轮对话管理
/// 2. 意图识别与槽位填充
/// 3. 上下文理解
/// 4. 智能追问缺失信息
class DialogManagerService {
  final List<DialogTurn> _history = [];
  PendingTransaction? _pendingTransaction;
  ConversationState _state = ConversationState.idle;
  final DialogTransactionRepository _transactionRepo;
  final DialogCategoryRepository _categoryRepo;

  DialogManagerService({
    required DialogTransactionRepository transactionRepo,
    required DialogCategoryRepository categoryRepo,
  })  : _transactionRepo = transactionRepo,
        _categoryRepo = categoryRepo;

  /// 获取对话历史
  List<DialogTurn> get history => List.unmodifiable(_history);

  /// 获取当前状态
  ConversationState get state => _state;

  /// 处理用户输入
  Future<AssistantResponse> processInput(String input) async {
    if (input.trim().isEmpty) {
      return AssistantResponse(
        message: '请告诉我您想做什么',
        suggestions: ['记一笔消费', '查看本月消费', '帮助'],
      );
    }

    _history.add(DialogTurn(role: DialogRole.user, content: input));

    AssistantResponse response;

    switch (_state) {
      case ConversationState.idle:
        response = await _handleNewInput(input);
        break;

      case ConversationState.waitingAmount:
        response = await _handleAmountInput(input);
        break;

      case ConversationState.waitingCategory:
        response = await _handleCategoryInput(input);
        break;

      case ConversationState.waitingDate:
        response = await _handleDateInput(input);
        break;

      case ConversationState.waitingDescription:
        response = await _handleDescriptionInput(input);
        break;

      case ConversationState.waitingConfirmation:
        response = await _handleConfirmation(input);
        break;

      case ConversationState.waitingQueryClarification:
        response = await _handleQueryClarification(input);
        break;
    }

    _history.add(DialogTurn(role: DialogRole.assistant, content: response.message));

    return response;
  }

  /// 处理新输入
  Future<AssistantResponse> _handleNewInput(String input) async {
    // 解析用户意图
    final intent = _parseIntent(input);

    switch (intent.type) {
      case IntentType.addExpense:
        return await _startAddExpense(intent);

      case IntentType.addIncome:
        return await _startAddIncome(intent);

      case IntentType.query:
        return await _handleQuery(intent);

      case IntentType.report:
        return await _generateReport(intent);

      case IntentType.help:
        return _showHelp();

      case IntentType.cancel:
        return _handleCancel();

      case IntentType.unknown:
        return AssistantResponse(
          message: '我可以帮您记账、查询消费、生成报告。请告诉我您想做什么？',
          suggestions: ['记一笔消费', '查看本月消费', '生成月度报告'],
        );
    }
  }

  /// 解析用户意图
  ParsedIntent _parseIntent(String input) {
    final lowerInput = input.toLowerCase();

    // 取消意图
    if (RegExp(r'取消|算了|不要了|返回').hasMatch(lowerInput)) {
      return ParsedIntent(type: IntentType.cancel);
    }

    // 帮助意图
    if (RegExp(r'帮助|怎么用|help|可以做什么').hasMatch(lowerInput)) {
      return ParsedIntent(type: IntentType.help);
    }

    // 报告意图
    if (RegExp(r'报告|报表|统计|分析').hasMatch(lowerInput)) {
      return ParsedIntent(type: IntentType.report);
    }

    // 查询意图
    if (RegExp(r'查|看|多少|花了|消费了|支出|有几笔').hasMatch(lowerInput)) {
      return ParsedIntent(
        type: IntentType.query,
        dateRange: _parseDateRange(input),
        category: _parseCategory(input),
      );
    }

    // 收入意图
    if (RegExp(r'收入|工资|入账|进账|到账|赚了|收到').hasMatch(lowerInput)) {
      return ParsedIntent(
        type: IntentType.addIncome,
        amount: _parseAmount(input),
        description: _parseDescription(input),
        date: _parseDate(input),
      );
    }

    // 支出意图（默认）
    if (RegExp(r'花了|消费|买了|付了|支出|吃了|打车|记|支付').hasMatch(lowerInput) ||
        _parseAmount(input) != null) {
      return ParsedIntent(
        type: IntentType.addExpense,
        amount: _parseAmount(input),
        category: _parseCategory(input),
        description: _parseDescription(input),
        date: _parseDate(input),
      );
    }

    return ParsedIntent(type: IntentType.unknown);
  }

  /// 解析金额
  double? _parseAmount(String input) {
    // 匹配：100元、100块、100、¥100、￥100
    final patterns = [
      RegExp(r'[¥￥]\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*[元块]'),
      RegExp(r'(?:花了|消费|付了|支出|买了)\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:块钱|元钱)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }

    // 尝试直接匹配数字
    final numberMatch = RegExp(r'\b(\d+(?:\.\d{1,2})?)\b').firstMatch(input);
    if (numberMatch != null) {
      final value = double.tryParse(numberMatch.group(1)!);
      if (value != null && value > 0) {
        return value;
      }
    }

    return null;
  }

  /// 解析分类
  String? _parseCategory(String input) {
    const categoryKeywords = {
      '餐饮': ['餐饮', '吃饭', '外卖', '午餐', '晚餐', '早餐', '食堂', '饭'],
      '交通': ['交通', '打车', '地铁', '公交', '加油', '滴滴', '出租'],
      '购物': ['购物', '买东西', '淘宝', '京东', '超市', '买'],
      '娱乐': ['娱乐', '电影', '游戏', 'ktv', '玩'],
      '居住': ['房租', '水电', '物业', '房贷'],
      '医疗': ['看病', '医院', '药', '医疗'],
      '教育': ['学费', '培训', '课程', '教育'],
      '通讯': ['话费', '流量', '手机', '通讯'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (input.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// 解析描述
  String? _parseDescription(String input) {
    // 尝试提取消费描述
    final patterns = [
      RegExp(r'(?:买了?|吃了?|消费|花在|用于)\s*([^\d¥￥元块]+?)(?:\d|$)'),
      RegExp(r'在([^\d¥￥元块]+?)(?:消费|花|吃|买)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        final desc = match.group(1)!.trim();
        if (desc.isNotEmpty && desc.length < 50) {
          return desc;
        }
      }
    }

    return null;
  }

  /// 解析日期
  DateTime? _parseDate(String input) {
    final now = DateTime.now();

    if (input.contains('今天') || input.contains('今日')) {
      return now;
    }

    if (input.contains('昨天') || input.contains('昨日')) {
      return now.subtract(const Duration(days: 1));
    }

    if (input.contains('前天')) {
      return now.subtract(const Duration(days: 2));
    }

    // 匹配具体日期：X月X日
    final dateMatch = RegExp(r'(\d{1,2})月(\d{1,2})[日号]?').firstMatch(input);
    if (dateMatch != null) {
      final month = int.parse(dateMatch.group(1)!);
      final day = int.parse(dateMatch.group(2)!);
      return DateTime(now.year, month, day);
    }

    return null;
  }

  /// 解析时间范围
  DateRange? _parseDateRange(String input) {
    final now = DateTime.now();

    if (RegExp(r'今天|今日').hasMatch(input)) {
      return DateRange(
        start: DateTime(now.year, now.month, now.day),
        end: now,
      );
    }

    if (RegExp(r'本月|这个月').hasMatch(input)) {
      return DateRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
    }

    if (RegExp(r'上个月').hasMatch(input)) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return DateRange(
        start: lastMonth,
        end: DateTime(now.year, now.month, 0),
      );
    }

    return null;
  }

  /// 开始添加消费
  Future<AssistantResponse> _startAddExpense(ParsedIntent intent) async {
    _pendingTransaction = PendingTransaction(
      type: TransactionType.expense,
      amount: intent.amount,
      category: intent.category,
      description: intent.description,
      date: intent.date ?? DateTime.now(),
    );

    return await _checkAndAskNextField();
  }

  /// 开始添加收入
  Future<AssistantResponse> _startAddIncome(ParsedIntent intent) async {
    _pendingTransaction = PendingTransaction(
      type: TransactionType.income,
      amount: intent.amount,
      category: '收入',
      description: intent.description,
      date: intent.date ?? DateTime.now(),
    );

    return await _checkAndAskNextField();
  }

  /// 检查并询问下一个缺失字段
  Future<AssistantResponse> _checkAndAskNextField() async {
    final tx = _pendingTransaction!;

    // 检查金额
    if (tx.amount == null || tx.amount == 0) {
      _state = ConversationState.waitingAmount;
      return AssistantResponse(
        message: '好的，这笔${tx.type == TransactionType.expense ? '消费' : '收入'}是多少钱？',
        expectingType: ExpectingType.amount,
      );
    }

    // 检查分类（仅支出需要）
    if (tx.type == TransactionType.expense && tx.category == null) {
      _state = ConversationState.waitingCategory;
      final categories = await _categoryRepo.getAllExpenseCategories();
      return AssistantResponse(
        message: '请选择分类：',
        suggestions: categories.take(6).map((c) => c.name).toList(),
        expectingType: ExpectingType.category,
      );
    }

    // 所有信息齐全，请求确认
    return _requestConfirmation();
  }

  /// 处理金额输入
  Future<AssistantResponse> _handleAmountInput(String input) async {
    final amount = _parseAmount(input);

    if (amount == null || amount <= 0) {
      return AssistantResponse(
        message: '请输入有效的金额，例如：100 或 100元',
        expectingType: ExpectingType.amount,
      );
    }

    _pendingTransaction = _pendingTransaction!.copyWith(amount: amount);
    return await _checkAndAskNextField();
  }

  /// 处理分类输入
  Future<AssistantResponse> _handleCategoryInput(String input) async {
    // 先尝试解析分类
    var category = _parseCategory(input);

    // 如果没有匹配到，尝试精确匹配分类名
    if (category == null) {
      final categories = await _categoryRepo.getAllExpenseCategories();
      for (final cat in categories) {
        if (cat.name == input.trim()) {
          category = cat.name;
          break;
        }
      }
    }

    if (category == null) {
      final categories = await _categoryRepo.getAllExpenseCategories();
      return AssistantResponse(
        message: '请选择一个有效的分类：',
        suggestions: categories.take(6).map((c) => c.name).toList(),
        expectingType: ExpectingType.category,
      );
    }

    _pendingTransaction = _pendingTransaction!.copyWith(category: category);
    return await _checkAndAskNextField();
  }

  /// 处理日期输入
  Future<AssistantResponse> _handleDateInput(String input) async {
    final date = _parseDate(input);

    if (date == null) {
      return AssistantResponse(
        message: '请输入有效的日期，例如：今天、昨天、1月15日',
        expectingType: ExpectingType.date,
      );
    }

    _pendingTransaction = _pendingTransaction!.copyWith(date: date);
    return await _checkAndAskNextField();
  }

  /// 处理描述输入
  Future<AssistantResponse> _handleDescriptionInput(String input) async {
    _pendingTransaction = _pendingTransaction!.copyWith(description: input.trim());
    return await _checkAndAskNextField();
  }

  /// 请求确认
  AssistantResponse _requestConfirmation() {
    _state = ConversationState.waitingConfirmation;
    final tx = _pendingTransaction!;

    final dateStr = '${tx.date.month}月${tx.date.day}日';

    return AssistantResponse(
      message: '''
确认记录以下${tx.type == TransactionType.expense ? '消费' : '收入'}？
• 金额：¥${tx.amount!.toStringAsFixed(2)}
• 分类：${tx.category ?? '未分类'}
• 描述：${tx.description ?? '无'}
• 日期：$dateStr
''',
      suggestions: ['确认', '修改金额', '修改分类', '取消'],
      expectingType: ExpectingType.confirmation,
    );
  }

  /// 处理确认
  Future<AssistantResponse> _handleConfirmation(String input) async {
    if (RegExp(r'确认|是的?|对|好的?|ok|没问题').hasMatch(input.toLowerCase())) {
      // 保存交易
      await _saveTransaction();
      _reset();

      return AssistantResponse(
        message: '已记录！还有其他需要记录的吗？',
        suggestions: ['继续记账', '查看今日消费', '不用了'],
      );
    }

    if (RegExp(r'取消|算了|不要').hasMatch(input)) {
      _reset();
      return AssistantResponse(
        message: '已取消。还需要帮助吗？',
        suggestions: ['记一笔消费', '查看消费', '不用了'],
      );
    }

    if (input.contains('修改金额')) {
      _state = ConversationState.waitingAmount;
      return AssistantResponse(
        message: '请输入新的金额：',
        expectingType: ExpectingType.amount,
      );
    }

    if (input.contains('修改分类')) {
      _state = ConversationState.waitingCategory;
      final categories = await _categoryRepo.getAllExpenseCategories();
      return AssistantResponse(
        message: '请选择新的分类：',
        suggestions: categories.take(6).map((c) => c.name).toList(),
        expectingType: ExpectingType.category,
      );
    }

    if (input.contains('修改日期')) {
      _state = ConversationState.waitingDate;
      return AssistantResponse(
        message: '请输入新的日期：',
        suggestions: ['今天', '昨天', '前天'],
        expectingType: ExpectingType.date,
      );
    }

    return AssistantResponse(
      message: '请回复"确认"保存，或"取消"放弃',
      suggestions: ['确认', '取消'],
      expectingType: ExpectingType.confirmation,
    );
  }

  /// 处理查询
  Future<AssistantResponse> _handleQuery(ParsedIntent intent) async {
    try {
      final dateRange = intent.dateRange ?? DateRange(
        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
        end: DateTime.now(),
      );

      final total = await _transactionRepo.sumByFilter(
        dateRange: dateRange,
        categoryName: intent.category,
      );

      final count = await _transactionRepo.countByFilter(
        dateRange: dateRange,
        categoryName: intent.category,
      );

      String message;
      if (intent.category != null) {
        message = '${intent.category}类消费共¥${total.toStringAsFixed(2)}，$count笔';
      } else {
        message = '共消费¥${total.toStringAsFixed(2)}，$count笔';
      }

      return AssistantResponse(
        message: message,
        suggestions: ['查看明细', '查看其他分类', '记一笔'],
      );
    } catch (e) {
      return AssistantResponse(
        message: '查询失败，请稍后重试',
        suggestions: ['重新查询', '记一笔消费'],
      );
    }
  }

  /// 处理查询澄清
  Future<AssistantResponse> _handleQueryClarification(String input) async {
    _state = ConversationState.idle;
    return await _handleNewInput(input);
  }

  /// 生成报告
  Future<AssistantResponse> _generateReport(ParsedIntent intent) async {
    return AssistantResponse(
      message: '正在生成报告...',
      suggestions: ['本月报告', '上月报告', '年度报告'],
    );
  }

  /// 显示帮助
  AssistantResponse _showHelp() {
    return AssistantResponse(
      message: '''
我可以帮您：
• 记账：说"午餐花了30元"
• 查询：说"本月消费多少"
• 报告：说"生成月度报告"

有什么需要帮助的吗？
''',
      suggestions: ['记一笔消费', '查看本月消费', '生成报告'],
    );
  }

  /// 处理取消
  AssistantResponse _handleCancel() {
    if (_pendingTransaction != null) {
      _reset();
      return AssistantResponse(
        message: '已取消当前操作。还需要帮助吗？',
        suggestions: ['记一笔消费', '查看消费', '不用了'],
      );
    }
    return AssistantResponse(
      message: '没有需要取消的操作。有什么可以帮您的吗？',
      suggestions: ['记一笔消费', '查看消费'],
    );
  }

  /// 保存交易
  Future<void> _saveTransaction() async {
    if (_pendingTransaction == null) return;

    await _transactionRepo.save(DialogTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _pendingTransaction!.type,
      amount: _pendingTransaction!.amount!,
      category: _pendingTransaction!.category,
      description: _pendingTransaction!.description,
      date: _pendingTransaction!.date,
    ));
  }

  /// 重置状态
  void _reset() {
    _pendingTransaction = null;
    _state = ConversationState.idle;
  }

  /// 清空对话历史
  void clearHistory() {
    _history.clear();
    _reset();
  }
}

// ==================== 数据模型 ====================

/// 对话状态
enum ConversationState {
  idle, // 空闲
  waitingAmount, // 等待金额
  waitingCategory, // 等待分类
  waitingDate, // 等待日期
  waitingDescription, // 等待描述
  waitingConfirmation, // 等待确认
  waitingQueryClarification, // 等待查询澄清
}

/// 意图类型
enum IntentType {
  addExpense, // 添加支出
  addIncome, // 添加收入
  query, // 查询
  report, // 生成报告
  help, // 帮助
  cancel, // 取消
  unknown, // 未知
}

/// 期望输入类型
enum ExpectingType {
  amount, // 金额
  category, // 分类
  date, // 日期
  description, // 描述
  confirmation, // 确认
  freeText, // 自由文本
}

/// 交易类型
enum TransactionType {
  expense, // 支出
  income, // 收入
}

/// 对话角色
enum DialogRole {
  user, // 用户
  assistant, // 助手
}

/// 对话轮次
class DialogTurn {
  final DialogRole role;
  final String content;
  final DateTime timestamp;

  DialogTurn({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 解析后的意图
class ParsedIntent {
  final IntentType type;
  final double? amount;
  final String? category;
  final String? description;
  final DateTime? date;
  final DateRange? dateRange;

  const ParsedIntent({
    required this.type,
    this.amount,
    this.category,
    this.description,
    this.date,
    this.dateRange,
  });
}

/// 助手响应
class AssistantResponse {
  final String message;
  final List<String>? suggestions;
  final ExpectingType? expectingType;
  final Map<String, dynamic>? data;

  const AssistantResponse({
    required this.message,
    this.suggestions,
    this.expectingType,
    this.data,
  });
}

/// 待处理交易
class PendingTransaction {
  final TransactionType type;
  final double? amount;
  final String? category;
  final String? description;
  final DateTime date;

  const PendingTransaction({
    required this.type,
    this.amount,
    this.category,
    this.description,
    required this.date,
  });

  PendingTransaction copyWith({
    TransactionType? type,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
  }) {
    return PendingTransaction(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }
}

/// 时间范围
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});
}

/// 对话交易
class DialogTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String? category;
  final String? description;
  final DateTime date;

  const DialogTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.category,
    this.description,
    required this.date,
  });
}

/// 对话分类
class DialogCategory {
  final String id;
  final String name;

  const DialogCategory({required this.id, required this.name});
}

/// 交易仓库接口
abstract class DialogTransactionRepository {
  Future<void> save(DialogTransaction transaction);
  Future<double> sumByFilter({DateRange? dateRange, String? categoryName});
  Future<int> countByFilter({DateRange? dateRange, String? categoryName});
}

/// 分类仓库接口
abstract class DialogCategoryRepository {
  Future<List<DialogCategory>> getAllExpenseCategories();
  Future<List<DialogCategory>> getAllIncomeCategories();
}
