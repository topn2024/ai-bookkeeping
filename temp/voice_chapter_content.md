
### 15.12 智能语音交互系统

本节将对话式记账功能从15.7独立出来，并扩展为完整的智能语音交互系统，支持语音记账、语音配置、语音导航和语音查询四大核心能力。

#### 15.12.0 系统架构全景图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      智能语音交互系统 - 架构全景图                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│                              ┌───────────────────┐                              │
│                              │   语音输入层       │                              │
│                              │  VoiceInputLayer  │                              │
│                              └─────────┬─────────┘                              │
│                                        │                                         │
│                                        ▼                                         │
│                        ┌───────────────────────────────┐                        │
│                        │      语音识别服务(ASR)         │                        │
│                        │   支持：讯飞/阿里云/本地识别    │                        │
│                        └───────────────┬───────────────┘                        │
│                                        │                                         │
│                                        ▼                                         │
│                        ┌───────────────────────────────┐                        │
│                        │      意图识别引擎              │                        │
│                        │   IntentRecognitionEngine     │                        │
│                        └───────────────┬───────────────┘                        │
│                                        │                                         │
│         ┌──────────────┬───────────────┼───────────────┬──────────────┐         │
│         │              │               │               │              │         │
│         ▼              ▼               ▼               ▼              ▼         │
│   ┌──────────┐  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐      │
│   │ 语音记账 │  │ 语音配置 │   │ 语音导航 │   │ 语音查询 │   │ 闲聊对话 │      │
│   │          │  │          │   │          │   │          │   │          │      │
│   │ 记一笔   │  │ 改设置   │   │ 打开页面 │   │ 问数据   │   │ 日常交流 │      │
│   │ 多笔记账 │  │ 调参数   │   │ 找功能   │   │ 看报表   │   │ 帮助引导 │      │
│   └────┬─────┘  └────┬─────┘   └────┬─────┘   └────┬─────┘   └────┬─────┘      │
│        │             │              │              │              │             │
│        └─────────────┴──────────────┴──────────────┴──────────────┘             │
│                                     │                                            │
│                                     ▼                                            │
│                        ┌───────────────────────────────┐                        │
│                        │      响应生成与执行            │                        │
│                        │   ResponseGenerator           │                        │
│                        └───────────────────────────────┘                        │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                          核心能力矩阵                                     │   │
│  ├──────────────┬──────────────┬──────────────┬──────────────────────────┤   │
│  │ 语音记账     │ 语音配置     │ 语音导航     │ 语音查询                  │   │
│  ├──────────────┼──────────────┼──────────────┼──────────────────────────┤   │
│  │ 单笔记账     │ 预算设置     │ 页面跳转     │ 消费统计                 │   │
│  │ 多笔批量     │ 分类管理     │ 功能搜索     │ 预算查询                 │   │
│  │ 模板调用     │ 账户配置     │ 快捷操作     │ 钱龄分析                 │   │
│  │ 智能补全     │ 提醒设置     │ 深度链接     │ 趋势预测                 │   │
│  └──────────────┴──────────────┴──────────────┴──────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 15.12.1 意图识别引擎

```dart
/// 语音意图类型枚举
enum VoiceIntentType {
  // ===== 记账相关 =====
  addExpense,           // 添加支出：记一笔、花了、买了
  addIncome,            // 添加收入：收到、入账、工资到了
  addTransfer,          // 转账：从...转到...
  batchRecord,          // 批量记账：记多笔、连续记账
  useTemplate,          // 使用模板：按模板记、常用记账

  // ===== 配置相关 =====
  setBudget,            // 设置预算：把...预算改成...
  setCategory,          // 分类设置：添加/删除/修改分类
  setAccount,           // 账户设置：添加/修改账户
  setReminder,          // 提醒设置：设置/取消提醒
  setVault,             // 小金库设置：创建/调整小金库
  setGeneral,           // 通用设置：主���/语言/通知等

  // ===== 导航相关 =====
  navigateTo,           // 页面导航：打开、去、进入
  searchFunction,       // 功能搜索：找功能、哪里可以
  quickAction,          // 快捷操作：扫一扫、拍照记账

  // ===== 查询相关 =====
  queryExpense,         // 查询消费：花了多少、消费情况
  queryIncome,          // 查询收入：收入多少、赚了多少
  queryBudget,          // 查询预算：预算还剩、超支没
  queryMoneyAge,        // 查询钱龄：资金年龄、持有多久
  queryTrend,           // 查询趋势：趋势如何、变化
  queryReport,          // 查询报告：月报、年报、分析
  queryBalance,         // 查询余额：还剩多少、账户余额

  // ===== 其他 =====
  chat,                 // 闲聊对话
  help,                 // 帮助引导
  cancel,               // 取消操作
  confirm,              // 确认操作
  unknown,              // 未识别意图
}

/// 意图识别引擎 - 双层策略：规则优先 + LLM兜底
class IntentRecognitionEngine {
  final LLMService _llmService;
  final RuleBasedMatcher _ruleMatcher;

  /// 意图识别规则库（优先匹配，零成本）
  static const Map<VoiceIntentType, List<String>> _intentPatterns = {
    // 记账意图
    VoiceIntentType.addExpense: [
      r'(记一笔|记账|花了|买了|支出|消费了|付了|花费)',
      r'(吃饭|打车|购物|买菜|缴费).*([\d\.]+)',
    ],
    VoiceIntentType.addIncome: [
      r'(收到|入账|收入|工资|奖金|到账)',
      r'(发工资|收款|转入).*([\d\.]+)',
    ],
    VoiceIntentType.batchRecord: [
      r'(记多笔|批量记|连续记|一起记)',
    ],

    // 配置意图
    VoiceIntentType.setBudget: [
      r'(设置|修改|调整|把).*(预算).*(改成|设为|调到)',
      r'(预算).*(设|改|调)',
    ],
    VoiceIntentType.setCategory: [
      r'(添加|新增|创建|删除|修改).*(分类|类别)',
    ],
    VoiceIntentType.setReminder: [
      r'(设置|添加|取消|关闭).*(提醒|通知)',
      r'(提醒我|通知我|每天|每周|每月)',
    ],
    VoiceIntentType.setVault: [
      r'(创建|设置|调整).*(小金库|专项资金)',
    ],

    // 导航意图
    VoiceIntentType.navigateTo: [
      r'(打开|去|进入|跳转|看看).*(页面|功能|设置|报表)',
      r'(打开|去).*(首页|账单|预算|统计|设置|我的)',
    ],
    VoiceIntentType.searchFunction: [
      r'(怎么|如何|哪里).*(设置|修改|查看|导出)',
      r'(找|搜索).*(功能|页面)',
    ],
    VoiceIntentType.quickAction: [
      r'(扫一扫|扫码|拍照|语音)',
    ],

    // 查询意图
    VoiceIntentType.queryExpense: [
      r'(这个月|今天|上周|本周).*(花了|消费|支出)',
      r'(花了多少|消费情况|支出统计)',
      r'(餐饮|交通|购物).*(花了|消费)',
    ],
    VoiceIntentType.queryIncome: [
      r'(这个月|今天|上周).*(收入|入账|赚了)',
      r'(收入多少|赚了多少)',
    ],
    VoiceIntentType.queryBudget: [
      r'(预算).*(还剩|剩余|超支|够不够)',
      r'(.*预算).*(情况|多少)',
    ],
    VoiceIntentType.queryMoneyAge: [
      r'(钱龄|资金年龄|持有多久|存了多久)',
      r'(资金).*(结构|分布|健康)',
    ],
    VoiceIntentType.queryTrend: [
      r'(趋势|变化|对比|环比|同比)',
    ],
    VoiceIntentType.queryBalance: [
      r'(还剩|余额|账户).*(多少|情况)',
    ],
  };

  /// 识别用户意图
  Future<VoiceIntent> recognizeIntent(String voiceText) async {
    // ===== 第一层：规则匹配（快速、确定性高、零成本） =====
    final ruleResult = _ruleMatcher.match(voiceText, _intentPatterns);
    if (ruleResult != null && ruleResult.confidence > 0.8) {
      return VoiceIntent(
        type: ruleResult.intentType,
        confidence: ruleResult.confidence,
        entities: ruleResult.entities,
        source: IntentSource.rule,
        rawText: voiceText,
      );
    }

    // ===== 第二层：大模型语义理解（处理复杂表达） =====
    try {
      final llmResult = await _llmService.recognizeVoiceIntent(
        text: voiceText,
        availableIntents: VoiceIntentType.values.map((e) => e.name).toList(),
      );

      if (llmResult.confidence > 0.6) {
        return VoiceIntent(
          type: _parseIntentType(llmResult.intentName),
          confidence: llmResult.confidence,
          entities: llmResult.entities,
          source: IntentSource.llm,
          rawText: voiceText,
        );
      }
    } catch (e) {
      debugPrint('LLM intent recognition failed: $e');
    }

    // ===== 兜底：返回未知意图 =====
    return VoiceIntent(
      type: VoiceIntentType.unknown,
      confidence: 0.0,
      entities: {},
      source: IntentSource.fallback,
      rawText: voiceText,
    );
  }
}

/// 语音意图数据类
class VoiceIntent {
  final VoiceIntentType type;
  final double confidence;
  final Map<String, dynamic> entities;  // 提取的实体：金额、分类、日期等
  final IntentSource source;
  final String rawText;

  VoiceIntent({
    required this.type,
    required this.confidence,
    required this.entities,
    required this.source,
    required this.rawText,
  });
}

enum IntentSource { rule, llm, fallback }
```

#### 15.12.2 语音记账模块

```dart
/// 语音记账服务
class VoiceBookkeepingService {
  final TransactionRepository _transactionRepo;
  final SmartCategoryService _categoryService;
  final EntityExtractor _entityExtractor;

  /// 处理语音记账请求
  Future<VoiceBookkeepingResult> processVoiceBookkeeping({
    required String voiceText,
    required VoiceIntent intent,
  }) async {
    switch (intent.type) {
      case VoiceIntentType.addExpense:
      case VoiceIntentType.addIncome:
        return await _processSingleRecord(voiceText, intent);

      case VoiceIntentType.batchRecord:
        return await _processBatchRecord(voiceText, intent);

      case VoiceIntentType.useTemplate:
        return await _processTemplateRecord(voiceText, intent);

      default:
        return VoiceBookkeepingResult.error('不支持的记账类型');
    }
  }

  /// 处理单笔记账
  Future<VoiceBookkeepingResult> _processSingleRecord(
    String voiceText,
    VoiceIntent intent,
  ) async {
    // 1. 提取实体信息
    final entities = await _entityExtractor.extractFromText(voiceText);

    // 2. 构建交易记录
    final transaction = Transaction(
      id: generateId(),
      type: intent.type == VoiceIntentType.addExpense
          ? TransactionType.expense
          : TransactionType.income,
      amount: entities.amount ?? 0,
      description: entities.description,
      categoryId: entities.categoryId,
      date: entities.date ?? DateTime.now(),
      merchantName: entities.merchantName,
    );

    // 3. 检查必填字段
    final missingFields = _checkMissingFields(transaction);

    if (missingFields.isNotEmpty) {
      // 进入多轮对话模式补全信息
      return VoiceBookkeepingResult.needMoreInfo(
        partialTransaction: transaction,
        missingFields: missingFields,
        prompt: _generatePromptForMissingField(missingFields.first),
      );
    }

    // 4. 智能分类补全（如果没有分类）
    if (transaction.categoryId == null) {
      final suggestions = await _categoryService.suggestCategories(
        description: transaction.description ?? '',
        amount: transaction.amount,
        merchant: transaction.merchantName,
      );

      if (suggestions.isNotEmpty && suggestions.first.confidence > 0.8) {
        transaction = transaction.copyWith(
          categoryId: suggestions.first.category.id,
        );
      } else {
        return VoiceBookkeepingResult.needConfirmCategory(
          partialTransaction: transaction,
          suggestions: suggestions,
        );
      }
    }

    // 5. 请求确认
    return VoiceBookkeepingResult.needConfirmation(
      transaction: transaction,
      summary: _generateTransactionSummary(transaction),
    );
  }

  /// 处理多笔批量记账
  /// 示例："早餐15，午餐28，晚餐45"
  /// 示例："今天花了：打车30，咖啡18，买书50"
  Future<VoiceBookkeepingResult> _processBatchRecord(
    String voiceText,
    VoiceIntent intent,
  ) async {
    final transactions = await _entityExtractor.extractMultipleTransactions(voiceText);

    if (transactions.isEmpty) {
      return VoiceBookkeepingResult.error('未能识别出交易信息，请重新描述');
    }

    // 为每笔交易补全分类
    final processedTransactions = <Transaction>[];
    for (final tx in transactions) {
      final suggestions = await _categoryService.suggestCategories(
        description: tx.description ?? '',
        amount: tx.amount,
      );

      processedTransactions.add(tx.copyWith(
        categoryId: suggestions.isNotEmpty ? suggestions.first.category.id : null,
      ));
    }

    final totalAmount = processedTransactions.fold<double>(0, (sum, tx) => sum + tx.amount);
    return VoiceBookkeepingResult.batchConfirmation(
      transactions: processedTransactions,
      summary: '识别到${processedTransactions.length}笔交易，共计${totalAmount.toStringAsFixed(2)}元',
    );
  }

  /// 确认并保存交易
  Future<VoiceBookkeepingResult> confirmAndSave(Transaction transaction) async {
    try {
      await _transactionRepo.insert(transaction);
      return VoiceBookkeepingResult.success(
        transaction: transaction,
        message: '已记录：${transaction.categoryName} ${transaction.amount.toStringAsFixed(2)}元',
      );
    } catch (e) {
      return VoiceBookkeepingResult.error('保存失败：$e');
    }
  }
}

/// 实体提取器
class EntityExtractor {
  final LLMService _llmService;

  /// 金额提取正则
  static final _amountPatterns = [
    RegExp(r'([0-9]+(?:\.[0-9]{1,2})?)\s*(元|块|块钱)?'),
    RegExp(r'([￥¥])([0-9]+(?:\.[0-9]{1,2})?)'),
  ];

  /// 日期提取规则
  static final Map<String, DateTime Function()> _dateKeywords = {
    '今天': () => DateTime.now(),
    '昨天': () => DateTime.now().subtract(Duration(days: 1)),
    '前天': () => DateTime.now().subtract(Duration(days: 2)),
    '上周': () => DateTime.now().subtract(Duration(days: 7)),
  };

  /// 从文本提取实体
  Future<ExtractedEntities> extractFromText(String text) async {
    // 1. 规则提取金额
    double? amount;
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1) ?? match.group(2);
        amount = double.tryParse(amountStr ?? '');
        break;
      }
    }

    // 2. 规则提取日期
    DateTime? date;
    for (final entry in _dateKeywords.entries) {
      if (text.contains(entry.key)) {
        date = entry.value();
        break;
      }
    }

    // 3. 使用LLM提取复杂实体
    final llmEntities = await _llmService.extractEntities(
      text: text,
      entityTypes: ['description', 'merchant', 'category_hint'],
    );

    return ExtractedEntities(
      amount: amount,
      date: date ?? DateTime.now(),
      description: llmEntities['description'],
      merchantName: llmEntities['merchant'],
      categoryHint: llmEntities['category_hint'],
    );
  }

  /// 提取多笔交易
  Future<List<Transaction>> extractMultipleTransactions(String text) async {
    // 按分隔符拆分
    final segments = text.split(RegExp(r'[,，;；、]'));

    final transactions = <Transaction>[];
    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;

      final entities = await extractFromText(trimmed);
      if (entities.amount != null && entities.amount! > 0) {
        transactions.add(Transaction(
          id: generateId(),
          type: TransactionType.expense,
          amount: entities.amount!,
          description: entities.description ?? trimmed,
          date: entities.date,
        ));
      }
    }

    return transactions;
  }
}
```

#### 15.12.3 智能语音配置模块

```dart
/// 语音配置服务 - 通过语音修改系统配置
class VoiceConfigurationService {
  final BudgetRepository _budgetRepo;
  final CategoryRepository _categoryRepo;
  final VaultRepository _vaultRepo;
  final SettingsRepository _settingsRepo;
  final EntityExtractor _entityExtractor;

  /// 配置项映射表
  static const Map<String, ConfigurableItem> _configurableItems = {
    // 预算相关
    '餐饮预算': ConfigurableItem(type: ConfigType.budget, categoryKey: 'food'),
    '交通预算': ConfigurableItem(type: ConfigType.budget, categoryKey: 'transport'),
    '购物预算': ConfigurableItem(type: ConfigType.budget, categoryKey: 'shopping'),
    '娱乐预算': ConfigurableItem(type: ConfigType.budget, categoryKey: 'entertainment'),
    '总预算': ConfigurableItem(type: ConfigType.budget, categoryKey: 'total'),

    // 提醒相关
    '记账提醒': ConfigurableItem(type: ConfigType.reminder, key: 'bookkeeping'),
    '预算提醒': ConfigurableItem(type: ConfigType.reminder, key: 'budget_alert'),
    '账单提醒': ConfigurableItem(type: ConfigType.reminder, key: 'bill'),

    // 通用设置
    '主题': ConfigurableItem(type: ConfigType.general, key: 'theme'),
    '语言': ConfigurableItem(type: ConfigType.general, key: 'language'),
    '货币': ConfigurableItem(type: ConfigType.general, key: 'currency'),
  };

  /// 处理语音配置请求
  Future<VoiceConfigResult> processVoiceConfig({
    required String voiceText,
    required VoiceIntent intent,
  }) async {
    switch (intent.type) {
      case VoiceIntentType.setBudget:
        return await _processBudgetConfig(voiceText, intent);
      case VoiceIntentType.setCategory:
        return await _processCategoryConfig(voiceText, intent);
      case VoiceIntentType.setReminder:
        return await _processReminderConfig(voiceText, intent);
      case VoiceIntentType.setVault:
        return await _processVaultConfig(voiceText, intent);
      case VoiceIntentType.setGeneral:
        return await _processGeneralConfig(voiceText, intent);
      default:
        return VoiceConfigResult.error('不支持的配置类型');
    }
  }

  /// 处理预算配置
  /// 示例："把餐饮预算改成2000"、"交通预算设为500"
  Future<VoiceConfigResult> _processBudgetConfig(
    String voiceText,
    VoiceIntent intent,
  ) async {
    // 1. 识别要修改的预算类型
    String? targetBudget;
    for (final key in _configurableItems.keys) {
      if (key.contains('预算') && voiceText.contains(key.replaceAll('预算', ''))) {
        targetBudget = key;
        break;
      }
    }

    // 2. 提取目标金额
    final entities = await _entityExtractor.extractFromText(voiceText);
    final newAmount = entities.amount;

    if (targetBudget == null) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '请问您要修改哪个分类的预算？',
        options: ['餐饮', '交通', '购物', '娱乐', '总预算'],
      );
    }

    if (newAmount == null || newAmount <= 0) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '请问您要将$targetBudget设为多少？',
        expectingType: ExpectingType.amount,
      );
    }

    // 3. 获取当前值用于对比
    final configItem = _configurableItems[targetBudget]!;
    final currentBudget = await _budgetRepo.getBudgetByCategory(
      configItem.categoryKey!,
    );

    // 4. 返回确认请求
    return VoiceConfigResult.needConfirmation(
      configType: ConfigType.budget,
      targetKey: targetBudget,
      oldValue: currentBudget?.amount ?? 0,
      newValue: newAmount,
      summary: '将$targetBudget从${currentBudget?.amount ?? 0}元修改为$newAmount元',
    );
  }

  /// 处理分类配置
  /// 示例："添加一个宠物分类"、"删除游戏分类"
  Future<VoiceConfigResult> _processCategoryConfig(
    String voiceText,
    VoiceIntent intent,
  ) async {
    // 识别操作类型：添加、删除、修改
    ConfigOperation operation;
    if (voiceText.contains('添加') || voiceText.contains('新增') || voiceText.contains('创建')) {
      operation = ConfigOperation.add;
    } else if (voiceText.contains('删除') || voiceText.contains('移除')) {
      operation = ConfigOperation.delete;
    } else if (voiceText.contains('修改') || voiceText.contains('改名')) {
      operation = ConfigOperation.modify;
    } else {
      return VoiceConfigResult.needMoreInfo(
        prompt: '您想对分类进行什么操作？',
        options: ['添加新分类', '删除分类', '修改分类名称'],
      );
    }

    // 提取分类名称
    final categoryName = _extractCategoryName(voiceText);

    if (categoryName == null) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '请告诉我分类的名称',
        expectingType: ExpectingType.text,
      );
    }

    return VoiceConfigResult.needConfirmation(
      configType: ConfigType.category,
      operation: operation,
      targetKey: categoryName,
      summary: '${operation.displayName}分类"$categoryName"',
    );
  }

  /// 处理提醒配置
  /// 示例："设置每天晚上8点记账提醒"、"关闭预算提醒"
  Future<VoiceConfigResult> _processReminderConfig(
    String voiceText,
    VoiceIntent intent,
  ) async {
    // 1. 识别提醒类型
    String? reminderType;
    if (voiceText.contains('记账')) {
      reminderType = '记账提醒';
    } else if (voiceText.contains('预算')) {
      reminderType = '预算提醒';
    } else if (voiceText.contains('账单')) {
      reminderType = '账单提醒';
    }

    // 2. 识别操作（开启/关闭/设置时间）
    bool? enabled;
    TimeOfDay? time;

    if (voiceText.contains('关闭') || voiceText.contains('取消')) {
      enabled = false;
    } else if (voiceText.contains('开启') || voiceText.contains('打开')) {
      enabled = true;
    }

    // 提取时间
    final timeMatch = RegExp(r'(\d{1,2})点(\d{0,2})').firstMatch(voiceText);
    if (timeMatch != null) {
      final hour = int.parse(timeMatch.group(1)!);
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      time = TimeOfDay(hour: hour, minute: minute);
      enabled ??= true;
    }

    if (reminderType == null) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '您想设置哪种提醒？',
        options: ['记账提醒', '预算提醒', '账单提醒'],
      );
    }

    String summary;
    if (enabled == false) {
      summary = '关闭$reminderType';
    } else if (time != null) {
      summary = '设置$reminderType，每天${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      summary = '开启$reminderType';
    }

    return VoiceConfigResult.needConfirmation(
      configType: ConfigType.reminder,
      targetKey: reminderType,
      newValue: {'enabled': enabled, 'time': time?.toString()},
      summary: summary,
    );
  }

  /// 处理小金库配置
  /// 示例："创建一个旅游小金库，每月存500"
  Future<VoiceConfigResult> _processVaultConfig(
    String voiceText,
    VoiceIntent intent,
  ) async {
    ConfigOperation operation;
    if (voiceText.contains('创建') || voiceText.contains('新建') || voiceText.contains('添加')) {
      operation = ConfigOperation.add;
    } else if (voiceText.contains('删除') || voiceText.contains('取消')) {
      operation = ConfigOperation.delete;
    } else if (voiceText.contains('调整') || voiceText.contains('修改')) {
      operation = ConfigOperation.modify;
    } else {
      return VoiceConfigResult.needMoreInfo(
        prompt: '您想对小金库进行什么操作？',
        options: ['创建新小金库', '调整现有小金库', '删除小金库'],
      );
    }

    final entities = await _entityExtractor.extractFromText(voiceText);
    final vaultName = _extractVaultName(voiceText);
    final targetAmount = entities.amount;

    if (vaultName == null) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '请告诉我小金库的名称',
        expectingType: ExpectingType.text,
      );
    }

    String summary;
    if (operation == ConfigOperation.add) {
      summary = '创建"$vaultName"小金库';
      if (targetAmount != null) {
        summary += '，每月存入$targetAmount元';
      }
    } else if (operation == ConfigOperation.delete) {
      summary = '删除"$vaultName"小金库';
    } else {
      summary = '调整"$vaultName"小金库设置';
    }

    return VoiceConfigResult.needConfirmation(
      configType: ConfigType.vault,
      operation: operation,
      targetKey: vaultName,
      newValue: {'name': vaultName, 'monthlyAmount': targetAmount},
      summary: summary,
    );
  }
}

/// 配置类型枚举
enum ConfigType { budget, category, reminder, vault, general }

/// 配置操作枚举
enum ConfigOperation {
  add, delete, modify;
  String get displayName => switch (this) {
    add => '添加',
    delete => '删除',
    modify => '修改',
  };
}
```

#### 15.12.4 智能语音导航模块

```dart
/// 语音导航服务 - 通过语音快速导航到目标页面
class VoiceNavigationService {
  final NavigationService _navigationService;

  /// 页面路由映射表
  static const Map<String, NavigationTarget> _navigationTargets = {
    // 主要页面
    '首页': NavigationTarget(route: '/home', displayName: '首页'),
    '主页': NavigationTarget(route: '/home', displayName: '首页'),
    '账单': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '交易': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '明细': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '流水': NavigationTarget(route: '/transactions', displayName: '账单列表'),

    // 预算相关
    '预算': NavigationTarget(route: '/budget', displayName: '预算管理'),
    '小金库': NavigationTarget(route: '/vaults', displayName: '小金库'),
    '零基预算': NavigationTarget(route: '/zero-budget', displayName: '零基预算'),

    // 分析报告
    '统计': NavigationTarget(route: '/stats', displayName: '统计分析'),
    '报表': NavigationTarget(route: '/reports', displayName: '报表'),
    '分析': NavigationTarget(route: '/analysis', displayName: '数据分析'),
    '钱龄': NavigationTarget(route: '/money-age', displayName: '钱龄分析'),
    '资金健康': NavigationTarget(route: '/money-age', displayName: '钱龄分析'),
    '趋势': NavigationTarget(route: '/trends', displayName: '趋势分析'),

    // 设置相关
    '设置': NavigationTarget(route: '/settings', displayName: '设置'),
    '我的': NavigationTarget(route: '/profile', displayName: '我的'),
    '账户': NavigationTarget(route: '/accounts', displayName: '账户管理'),
    '分类': NavigationTarget(route: '/categories', displayName: '分类管理'),
    '数据备份': NavigationTarget(route: '/backup', displayName: '数据备份'),
    '导出数据': NavigationTarget(route: '/export', displayName: '数据导出'),
    '导入数据': NavigationTarget(route: '/import', displayName: '数据导入'),

    // 功能入口
    '记账': NavigationTarget(route: '/add-transaction', displayName: '快速记账'),
    '语音记账': NavigationTarget(route: '/voice-entry', displayName: '语音记账'),
    '拍照记账': NavigationTarget(route: '/camera-entry', displayName: '拍照记账'),
    '扫码': NavigationTarget(route: '/scan', displayName: '扫码'),

    // 习惯与目标
    '习惯': NavigationTarget(route: '/habits', displayName: '习惯培养'),
    '打卡': NavigationTarget(route: '/habits', displayName: '习惯培养'),
    '储蓄目标': NavigationTarget(route: '/savings-goals', displayName: '储蓄目标'),
    '攒钱': NavigationTarget(route: '/savings-goals', displayName: '储蓄目标'),
  };

  /// 功能搜索关键词映射
  static const Map<String, List<String>> _featureKeywords = {
    '/categories': ['怎么添加分类', '如何修改分类', '分类在哪', '管理分类'],
    '/budget': ['怎么设预算', '如何调预算', '预算在哪设置'],
    '/export': ['怎么导出', '如何备份', '数据导出'],
    '/vaults': ['小金库怎么用', '如何创建小金库', '专项资金'],
    '/money-age': ['什么是钱龄', '资金健康度', '钱存了多久'],
  };

  /// 处理语音导航请求
  Future<VoiceNavigationResult> processVoiceNavigation({
    required String voiceText,
    required VoiceIntent intent,
  }) async {
    switch (intent.type) {
      case VoiceIntentType.navigateTo:
        return await _processDirectNavigation(voiceText);
      case VoiceIntentType.searchFunction:
        return await _processFeatureSearch(voiceText);
      case VoiceIntentType.quickAction:
        return await _processQuickAction(voiceText);
      default:
        return VoiceNavigationResult.error('不支持的导航类型');
    }
  }

  /// 处理直接导航
  /// 示例："打开预算页面"、"去设置"、"进入账单"
  Future<VoiceNavigationResult> _processDirectNavigation(String voiceText) async {
    // 直接匹配页面关键词
    for (final entry in _navigationTargets.entries) {
      if (voiceText.contains(entry.key)) {
        return VoiceNavigationResult.navigate(
          target: entry.value,
          message: '正在打开${entry.value.displayName}',
        );
      }
    }

    // 未找到匹配，提供建议
    return VoiceNavigationResult.suggestions(
      message: '没有找到匹配的页面，您是要去这些地方吗？',
      suggestions: [
        _navigationTargets['首页']!,
        _navigationTargets['账单']!,
        _navigationTargets['预算']!,
        _navigationTargets['设置']!,
      ],
    );
  }

  /// 处理功能搜索
  /// 示例："怎么设置预算"、"分类在哪里管理"、"如何导出��据"
  Future<VoiceNavigationResult> _processFeatureSearch(String voiceText) async {
    for (final entry in _featureKeywords.entries) {
      for (final keyword in entry.value) {
        if (voiceText.contains(keyword)) {
          final target = _navigationTargets.values.firstWhere(
            (t) => t.route == entry.key,
            orElse: () => NavigationTarget(route: entry.key, displayName: '相关功能'),
          );

          return VoiceNavigationResult.navigateWithGuide(
            target: target,
            message: '您可以在${target.displayName}中找到该功能',
            guide: _getFeatureGuide(entry.key),
          );
        }
      }
    }

    return VoiceNavigationResult.notFound(
      message: '没有找到相关功能，请尝试其他描述',
    );
  }

  /// 处理快捷操作
  Future<VoiceNavigationResult> _processQuickAction(String voiceText) async {
    if (voiceText.contains('扫') || voiceText.contains('二维码')) {
      return VoiceNavigationResult.quickAction(
        action: QuickActionType.scan,
        message: '正在打开扫码',
      );
    }

    if (voiceText.contains('拍照') || voiceText.contains('相机')) {
      return VoiceNavigationResult.quickAction(
        action: QuickActionType.camera,
        message: '正在打开拍照记账',
      );
    }

    if (voiceText.contains('语音')) {
      return VoiceNavigationResult.quickAction(
        action: QuickActionType.voice,
        message: '正在打开语音记账',
      );
    }

    return VoiceNavigationResult.error('未识别的快捷操作');
  }

  String _getFeatureGuide(String route) {
    final guides = {
      '/categories': '点击右上角的"+"按钮可以添加新分类',
      '/budget': '在预算页面，点击分类卡片可以设置该分类的月度预算',
      '/export': '选择日期范围和导出格式，点击"导出"按钮即可',
      '/vaults': '点击"创建小金库"按钮，设置名称和每月存入金额',
    };
    return guides[route] ?? '';
  }
}

/// 导航目标
class NavigationTarget {
  final String route;
  final String displayName;
  final Map<String, dynamic>? params;

  const NavigationTarget({
    required this.route,
    required this.displayName,
    this.params,
  });
}

/// 快捷操作类型
enum QuickActionType { scan, camera, voice }
```

#### 15.12.5 智能语音查询模块

```dart
/// 语音查询服务 - 通过语音查询各种数据
class VoiceQueryService {
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;
  final MoneyAgeService _moneyAgeService;
  final StatsService _statsService;
  final LLMService _llmService;

  /// 处理语音查询请求
  Future<VoiceQueryResult> processVoiceQuery({
    required String voiceText,
    required VoiceIntent intent,
  }) async {
    switch (intent.type) {
      case VoiceIntentType.queryExpense:
        return await _processExpenseQuery(voiceText, intent);
      case VoiceIntentType.queryIncome:
        return await _processIncomeQuery(voiceText, intent);
      case VoiceIntentType.queryBudget:
        return await _processBudgetQuery(voiceText, intent);
      case VoiceIntentType.queryMoneyAge:
        return await _processMoneyAgeQuery(voiceText, intent);
      case VoiceIntentType.queryTrend:
        return await _processTrendQuery(voiceText, intent);
      case VoiceIntentType.queryBalance:
        return await _processBalanceQuery(voiceText, intent);
      case VoiceIntentType.queryReport:
        return await _processReportQuery(voiceText, intent);
      default:
        return VoiceQueryResult.error('不支持的查询类型');
    }
  }

  /// 处理消费查询
  /// 示例："这个月花了多少"、"今天餐饮消费多少"
  Future<VoiceQueryResult> _processExpenseQuery(
    String voiceText,
    VoiceIntent intent,
  ) async {
    final timeRange = _parseTimeRange(voiceText);
    final category = _parseCategory(voiceText);

    final expenses = await _transactionRepo.getExpenses(
      startDate: timeRange.start,
      endDate: timeRange.end,
      categoryId: category?.id,
    );

    final totalAmount = expenses.fold<double>(0, (sum, tx) => sum + tx.amount);
    final count = expenses.length;

    String response;
    if (category != null) {
      response = '${timeRange.displayName}，${category.name}消费共${totalAmount.toStringAsFixed(2)}元，共$count笔';
    } else {
      response = '${timeRange.displayName}，总消费${totalAmount.toStringAsFixed(2)}元，共$count笔';
    }

    return VoiceQueryResult.success(
      summary: response,
      data: QueryData(
        type: QueryDataType.expense,
        amount: totalAmount,
        count: count,
        timeRange: timeRange,
        category: category,
        details: expenses.take(5).toList(),
      ),
      followUpSuggestions: ['查看明细', '按分类统计', '对比上月'],
    );
  }

  /// 处理预算查询
  /// 示例："餐饮预算还剩多少"、"这个月预算超支没"
  Future<VoiceQueryResult> _processBudgetQuery(
    String voiceText,
    VoiceIntent intent,
  ) async {
    final category = _parseCategory(voiceText);

    if (category != null) {
      final budget = await _budgetRepo.getBudgetByCategory(category.id);
      if (budget == null) {
        return VoiceQueryResult.success(
          summary: '${category.name}还没有设置预算',
          followUpSuggestions: ['设置预算'],
        );
      }

      final spent = await _getSpentAmount(category.id);
      final remaining = budget.amount - spent;
      final usageRate = spent / budget.amount;

      String status;
      if (remaining < 0) {
        status = '已超支${(-remaining).toStringAsFixed(2)}元';
      } else if (usageRate > 0.8) {
        status = '剩余${remaining.toStringAsFixed(2)}元，注意控制';
      } else {
        status = '剩余${remaining.toStringAsFixed(2)}元，使用正常';
      }

      return VoiceQueryResult.success(
        summary: '${category.name}预算${budget.amount.toStringAsFixed(2)}元，已用${spent.toStringAsFixed(2)}元，$status',
        data: QueryData(
          type: QueryDataType.budget,
          budgetAmount: budget.amount,
          spentAmount: spent,
          usageRate: usageRate,
          category: category,
        ),
      );
    } else {
      final totalBudget = await _budgetRepo.getTotalMonthlyBudget();
      final totalSpent = await _transactionRepo.getMonthlyExpenseTotal();
      final remaining = totalBudget - totalSpent;

      return VoiceQueryResult.success(
        summary: '本月总预算${totalBudget.toStringAsFixed(2)}元，已用${totalSpent.toStringAsFixed(2)}元，剩余${remaining.toStringAsFixed(2)}元',
        followUpSuggestions: ['查看分类预算', '调整预算'],
      );
    }
  }

  /// 处理钱龄查询
  /// 示例："我的钱龄情况怎么样"、"资金健康度如何"
  Future<VoiceQueryResult> _processMoneyAgeQuery(
    String voiceText,
    VoiceIntent intent,
  ) async {
    final moneyAgeData = await _moneyAgeService.getCurrentMoneyAge();

    final freshRatio = moneyAgeData.freshMoneyRatio * 100;
    final avgAge = moneyAgeData.averageAge;

    String healthDescription;
    if (moneyAgeData.healthScore >= 80) {
      healthDescription = '非常健康';
    } else if (moneyAgeData.healthScore >= 60) {
      healthDescription = '良好';
    } else if (moneyAgeData.healthScore >= 40) {
      healthDescription = '一般，建议增加储蓄';
    } else {
      healthDescription = '需要关注，建议控制支出';
    }

    return VoiceQueryResult.success(
      summary: '您的资金健康度$healthDescription，评分${moneyAgeData.healthScore.toStringAsFixed(0)}分。平均钱龄${avgAge.toStringAsFixed(1)}天，新鲜资金占比${freshRatio.toStringAsFixed(1)}%',
      data: QueryData(
        type: QueryDataType.moneyAge,
        moneyAgeData: moneyAgeData,
      ),
      followUpSuggestions: ['查看详细分析', '如何改善'],
    );
  }

  /// 处理趋势查询
  /// 示例："消费趋势怎么样"、"和上月对比"
  Future<VoiceQueryResult> _processTrendQuery(
    String voiceText,
    VoiceIntent intent,
  ) async {
    final now = DateTime.now();
    final thisMonth = await _transactionRepo.getMonthlyExpenseTotal(
      year: now.year,
      month: now.month,
    );
    final lastMonth = await _transactionRepo.getMonthlyExpenseTotal(
      year: now.month == 1 ? now.year - 1 : now.year,
      month: now.month == 1 ? 12 : now.month - 1,
    );

    final change = thisMonth - lastMonth;
    final changeRate = lastMonth > 0 ? (change / lastMonth * 100) : 0;

    String trend;
    if (change > 0) {
      trend = '比上月多花了${change.toStringAsFixed(2)}元（+${changeRate.toStringAsFixed(1)}%）';
    } else if (change < 0) {
      trend = '比上月少花了${(-change).toStringAsFixed(2)}元（${changeRate.toStringAsFixed(1)}%）';
    } else {
      trend = '和上月持平';
    }

    return VoiceQueryResult.success(
      summary: '本月已消费${thisMonth.toStringAsFixed(2)}元，$trend',
      followUpSuggestions: ['查看分类对比', '查看趋势图'],
    );
  }

  /// 解析时间范围
  TimeRange _parseTimeRange(String text) {
    final now = DateTime.now();

    if (text.contains('今天')) {
      return TimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: now,
        displayName: '今天',
      );
    }
    if (text.contains('昨天')) {
      final yesterday = now.subtract(Duration(days: 1));
      return TimeRange(
        start: DateTime(yesterday.year, yesterday.month, yesterday.day),
        end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
        displayName: '昨天',
      );
    }
    if (text.contains('本周') || text.contains('这周')) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return TimeRange(
        start: DateTime(weekStart.year, weekStart.month, weekStart.day),
        end: now,
        displayName: '本周',
      );
    }
    if (text.contains('上周')) {
      final lastWeekEnd = now.subtract(Duration(days: now.weekday));
      final lastWeekStart = lastWeekEnd.subtract(Duration(days: 6));
      return TimeRange(
        start: DateTime(lastWeekStart.year, lastWeekStart.month, lastWeekStart.day),
        end: DateTime(lastWeekEnd.year, lastWeekEnd.month, lastWeekEnd.day, 23, 59, 59),
        displayName: '上周',
      );
    }
    if (text.contains('上个月') || text.contains('上月')) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      return TimeRange(
        start: lastMonth,
        end: lastMonthEnd,
        displayName: '上个月',
      );
    }

    // 默认本月
    return TimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
      displayName: '这个月',
    );
  }

  /// 解析分类
  Category? _parseCategory(String text) {
    final categoryKeywords = {
      '餐饮': 'food', '吃饭': 'food',
      '交通': 'transport', '打车': 'transport',
      '购物': 'shopping', '买东西': 'shopping',
      '娱乐': 'entertainment',
      '居住': 'housing', '房租': 'housing',
      '医疗': 'medical', '看病': 'medical',
      '教育': 'education',
    };

    for (final entry in categoryKeywords.entries) {
      if (text.contains(entry.key)) {
        return Category(id: entry.value, name: entry.key);
      }
    }
    return null;
  }
}

/// 时间范围
class TimeRange {
  final DateTime start;
  final DateTime end;
  final String displayName;

  TimeRange({required this.start, required this.end, required this.displayName});
}

/// 查询数据类型
enum QueryDataType { expense, income, budget, moneyAge, trend, balance, report }
```

#### 15.12.6 语音交互会话管理

```dart
/// 语音交互会话管理器
/// 负责管理多轮对话状态、上下文保持和会话恢复
class VoiceSessionManager {
  final IntentRecognitionEngine _intentEngine;
  final VoiceBookkeepingService _bookkeepingService;
  final VoiceConfigurationService _configService;
  final VoiceNavigationService _navigationService;
  final VoiceQueryService _queryService;

  VoiceSessionState _state = VoiceSessionState.idle;
  VoiceContext? _context;
  final List<DialogTurn> _history = [];

  /// 处理语音输入
  Future<VoiceResponse> processVoiceInput(String voiceText) async {
    _history.add(DialogTurn(role: 'user', content: voiceText));

    // 检查是否在多轮对话中
    if (_state != VoiceSessionState.idle && _context != null) {
      return await _handleContextualInput(voiceText);
    }

    // 识别意图
    final intent = await _intentEngine.recognizeIntent(voiceText);

    // 处理通用意图
    if (intent.type == VoiceIntentType.cancel) return _handleCancel();
    if (intent.type == VoiceIntentType.help) return _handleHelp();

    // 根据意图类型分发处理
    return await _dispatchIntent(voiceText, intent);
  }

  /// 分发意图处理
  Future<VoiceResponse> _dispatchIntent(String voiceText, VoiceIntent intent) async {
    // 记账类意图
    if (_isBookkeepingIntent(intent.type)) {
      final result = await _bookkeepingService.processVoiceBookkeeping(
        voiceText: voiceText,
        intent: intent,
      );
      return _handleBookkeepingResult(result);
    }

    // 配置类意图
    if (_isConfigIntent(intent.type)) {
      final result = await _configService.processVoiceConfig(
        voiceText: voiceText,
        intent: intent,
      );
      return _handleConfigResult(result);
    }

    // 导航类意图
    if (_isNavigationIntent(intent.type)) {
      final result = await _navigationService.processVoiceNavigation(
        voiceText: voiceText,
        intent: intent,
      );
      return _handleNavigationResult(result);
    }

    // 查询类意图
    if (_isQueryIntent(intent.type)) {
      final result = await _queryService.processVoiceQuery(
        voiceText: voiceText,
        intent: intent,
      );
      return _handleQueryResult(result);
    }

    // 未识别
    return VoiceResponse(
      message: '抱歉，我没有理解您的意思。您可以说"帮助"了解我能做什么。',
      suggestions: ['记一笔', '查消费', '打开设置', '帮助'],
      state: VoiceResponseState.needInput,
    );
  }

  /// 处理帮助
  VoiceResponse _handleHelp() {
    return VoiceResponse(
      message: '''我可以帮您：
- 记账：说"记一笔"或"花了50吃饭"
- 查询：说"这个月花了多少"或"餐饮预算还剩多少"
- 设置：说"把餐饮预算改成2000"
- 导航：说"打开设置"或"去预��页面"
- 分析：说"钱龄情况"或"消费趋势"

请问您想做什么？''',
      suggestions: ['记一笔', '查消费', '看预算', '打开设置'],
      state: VoiceResponseState.needInput,
    );
  }

  VoiceResponse _handleCancel() {
    _resetSession();
    return VoiceResponse(message: '已取消', state: VoiceResponseState.complete);
  }

  void _resetSession() {
    _state = VoiceSessionState.idle;
    _context = null;
  }

  bool _isBookkeepingIntent(VoiceIntentType type) => [
    VoiceIntentType.addExpense, VoiceIntentType.addIncome,
    VoiceIntentType.addTransfer, VoiceIntentType.batchRecord,
    VoiceIntentType.useTemplate,
  ].contains(type);

  bool _isConfigIntent(VoiceIntentType type) => [
    VoiceIntentType.setBudget, VoiceIntentType.setCategory,
    VoiceIntentType.setAccount, VoiceIntentType.setReminder,
    VoiceIntentType.setVault, VoiceIntentType.setGeneral,
  ].contains(type);

  bool _isNavigationIntent(VoiceIntentType type) => [
    VoiceIntentType.navigateTo, VoiceIntentType.searchFunction,
    VoiceIntentType.quickAction,
  ].contains(type);

  bool _isQueryIntent(VoiceIntentType type) => [
    VoiceIntentType.queryExpense, VoiceIntentType.queryIncome,
    VoiceIntentType.queryBudget, VoiceIntentType.queryMoneyAge,
    VoiceIntentType.queryTrend, VoiceIntentType.queryReport,
    VoiceIntentType.queryBalance,
  ].contains(type);
}

/// 会话状态枚举
enum VoiceSessionState {
  idle, waitingAmount, waitingCategory, waitingConfirmation, waitingConfigValue
}

/// 语音响应状态
enum VoiceResponseState { complete, needInput, needConfirmation, navigating, error }

/// 语音响应
class VoiceResponse {
  final String message;
  final List<String>? suggestions;
  final VoiceResponseState state;
  final dynamic data;

  VoiceResponse({required this.message, this.suggestions, required this.state, this.data});
}
```

#### 15.12.7 语音交互界��设计

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      语音交互界面设计规范                                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │                         语音交互主界面                                   │    │
│  │                                                                         │    │
│  │   ┌────────────────────────────────────────────────────────────┐       │    │
│  │   │                      对话记录区                              │       │    │
│  │   │  ┌──────────────────────────────────────────────────────┐  │       │    │
│  │   │  │ 用户: "记一笔早餐15块"                                  │  │       │    │
│  │   │  └──────────────────────────────────────────────────────┘  │       │    │
│  │   │  ┌──────────────────────────────────────────────────────┐  │       │    │
│  │   │  │ 助手: 好的，已记录：餐饮 15.00元                        │  │       │    │
│  │   │  │       还有其他需要记录的吗？                           │  │       │    │
│  │   │  └──────────────────────────────────────────────────────┘  │       │    │
│  │   │  ┌──────────────────────────────────────────────────────┐  │       │    │
│  │   │  │ 用户: "这个月餐饮花了多少"                              │  │       │    │
│  │   │  └──────────────────────────────────────────────────────┘  │       │    │
│  │   │  ┌───────────────────────────��──────────────────────────┐  │       │    │
│  │   │  │ 助手: 这个月餐饮消费共856.50元，共23笔                  │  │       │    │
│  │   │  │       [查看明细] [按日统计] [对比上月]                  │  │       │    │
│  │   │  └──────────────────────────────────────────────────────┘  │       │    │
│  │   └────────────────────────────────────────────────────────────┘       │    │
│  │                                                                         │    │
│  │   ┌────────────────────────────────────────────────────────────┐       │    │
│  │   │                      快捷建议区                              │       │    │
│  │   │  [记一笔] [查消费] [看预算] [打开设置]                       │       │    │
│  │   └───────────────────────��────────────────────────────────────┘       │    │
│  │                                                                         │    │
│  │   ┌────────────────────────────────────────────────────────────┐       │    │
│  │   │                      语音输入区                              │       │    │
│  │   │                    [ 🎤 按住说话 ]                          │       │    │
│  │   │                      [键盘输入]                             │       │    │
│  │   └────────────────────────────────────────────────────────────┘       │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  【交互状态视觉反馈】                                                            │
│  ┌─────────────────────────���─────────────────────────────────────────────────┐ │
│  │  状态           │  视觉表现                    │  音效                     │ │
│  ├────────────────┼────────────────────────────┼──────────────────────────┤ │
│  │  空闲           │  麦克风图标静止              │  无                       │ │
│  │  录音中         │  波浪动画+麦克风高亮          │  开始提示音               │ │
│  │  识别中         │  转圈加载动画                │  无                       │ │
│  │  AI思考中       │  打字机效果渐显              │  无                       │ │
│  │  等待输入       │  输入框高亮+光标闪烁          │  提示音                   │ │
│  │  操作成功       │  绿色对勾+成功动画            │  成功提示音               │ │
│  │  操作失败       │  红色叉号+震动              │  失败提示音               │ │
│  └───────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 15.12.8 与其他系统的集成

| 集成系统 | 语音能力 | 触发示例 | 输出结果 |
|---------|---------|---------|---------|
| **交易系统** | 语音记账 | "记一笔午餐35" | 创建交易记录 |
| **预算系统** | 预算查询/设置 | "餐饮预算还剩多少" | 预算状态/修改预算 |
| **零基预算** | 小金库配置 | "创建旅游小金库" | 创建小金库 |
| **钱龄系统** | 钱龄查询 | "我的资金健康度" | 钱龄分析报��� |
| **习惯培养** | 打卡提醒 | "设置记账提醒" | 配置提醒 |
| **数据分析** | 统计查询 | "这个月消费趋势" | 趋势分析 |
| **导航系统** | 页面跳转 | "打开设置页面" | 执行导航 |

#### 15.12.9 目标达成检测

```dart
/// 智能语音交互系统验收标准
class VoiceInteractionAcceptanceCriteria {
  /// 功能完整性检查
  static final functionalChecks = {
    '语音记账': [
      '支持单笔语音记账',
      '支持多笔批量记账',
      '自动识别金额、分类、商家',
      '多轮对话补全缺失信息',
    ],
    '语音配置': [
      '支持预算设置',
      '支持分类管理',
      '支持提醒设置',
      '支持小金库配置',
    ],
    '语音导航': [
      '支持页面直接跳转',
      '支持功能搜索',
      '支持快捷操作',
    ],
    '语音查询': [
      '支持消费统计查询',
      '支持预算余额查询',
      '支持钱龄健康查询',
      '支持趋势对比查询',
    ],
  };

  /// 性能指标
  static final performanceMetrics = {
    '语音识别延迟': '< 1秒',
    '意图识别准确率': '> 90%',
    '实体提取准确率': '> 85%',
    '端到端响应时间': '< 3秒',
  };

  /// 用户体验指标
  static final uxMetrics = {
    '一次成功率': '> 80%',  // 用户第一次说就能完成操作
    '多轮对话轮次': '< 3轮',  // 平均对话轮次
    '放弃率': '< 10%',  // 用户中途放弃比例
  };
}
```

