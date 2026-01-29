/// Prompt Builder
///
/// 基于配置构建 LLM Prompt 的服务。
/// 与 IntentConfigLoader 配合使用，支持动态更新 Prompt。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'intent_config_loader.dart';

/// Prompt 构建器
///
/// 职责：
/// - 从配置加载 Prompt 模板
/// - 动态构建完整的 Prompt
/// - 支持变量替换
class PromptBuilder {
  /// 配置加载器
  final IntentConfigLoader _configLoader;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 缓存的城市名
  String _cityName = '深圳';

  PromptBuilder({IntentConfigLoader? configLoader})
      : _configLoader = configLoader ?? IntentConfigLoader.instance;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _configLoader.loadAll();
    _isInitialized = true;
    debugPrint('[PromptBuilder] 初始化完成');
  }

  /// 设置城市名
  void setCityName(String cityName) {
    _cityName = cityName;
  }

  /// 构建多操作 Prompt
  String buildMultiOperationPrompt({
    required String input,
    String? pageContext,
    List<Map<String, String>>? conversationHistory,
    String? pageList,
  }) {
    if (!_isInitialized) {
      debugPrint('[PromptBuilder] 警告：未初始化，使用默认配置');
    }

    return _configLoader.buildPrompt(
      input: input,
      pageContext: pageContext,
      historyContext: _buildHistoryContext(conversationHistory),
      pageList: pageList,
      cityName: _cityName,
    );
  }

  /// 构建单意图 Prompt（兼容旧版）
  String buildSingleIntentPrompt({
    required String input,
    String? pageContext,
    List<Map<String, String>>? conversationHistory,
    String? pageList,
  }) {
    final config = _configLoader.config;
    final template = _configLoader.promptTemplate;

    final buffer = StringBuffer();

    // 系统角色
    buffer.writeln(template.systemRole);

    // 对话历史
    final historyContext = _buildHistoryContext(conversationHistory);
    if (historyContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('【对话历史（用于理解上下文）】');
      buffer.writeln(historyContext);
    }

    // 用户输入
    buffer.writeln();
    buffer.writeln('【当前用户输入】$input');
    buffer.writeln('【页面上下文】${pageContext ?? '首页'}');

    // 意图类型说明
    buffer.writeln();
    buffer.writeln(_getSingleIntentTypes());

    // 规则说明
    buffer.writeln();
    buffer.writeln(_getSingleIntentRules());

    // 分类列表
    buffer.writeln();
    buffer.writeln(template.categories);

    // 页面列表
    if (pageList != null && pageList.isNotEmpty) {
      buffer.writeln('【常用页面】$pageList');
    }

    // 查询参数说明
    buffer.writeln();
    buffer.writeln(_getQueryParamsDocs());

    // 示例
    buffer.writeln();
    buffer.writeln(_getSingleIntentExamples());

    buffer.writeln();
    buffer.writeln('只返回JSON，不要其他内容：');

    return buffer.toString();
  }

  /// 构建对话历史上下文
  String _buildHistoryContext(List<Map<String, String>>? conversationHistory) {
    if (conversationHistory == null || conversationHistory.isEmpty) {
      return '';
    }

    // 只取最近 6 条（3 轮对话）
    final recentHistory = conversationHistory.length > 6
        ? conversationHistory.sublist(conversationHistory.length - 6)
        : conversationHistory;

    return recentHistory.map((h) {
      final role = h['role'] == 'user' ? '用户' : '助手';
      return '$role: ${h['content']}';
    }).join('\n');
  }

  /// 获取单意图类型说明
  String _getSingleIntentTypes() {
    return '''
【意图类型】
- add_transaction: 记账（明确要求记录一笔支出/收入，必须同时有金额AND分类/用途）
- navigate: 导航（打开某页面）
- query: 查询统计（查看账单、统计数据）
- modify: 修改记录
- delete: 删除记录
- confirm: 确认
- cancel: 取消
- clarify: 需要澄清（信息不完整，需要反问用户）
- chat: 闲聊对话''';
  }

  /// 获取单意图规则
  String _getSingleIntentRules() {
    return '''
【重要：query意图的判断规则 - 优先级高于clarify】
以下情况必须返回query意图（查询统计）：
1. 询问消费金额："今天花了多少钱"、"这周花了多少"、"本月消费多少" → query
2. 询问统计数据："最近花了多少"、"上个月开销多少"、"今年总共花了多少" → query
3. 包含时间词+花费询问：只要同时包含时间词和花费询问词，就是query意图
4. 上下文延续查询：如果对话历史中刚刚进行了消费查询，用户说分类名称则是继续查询该分类 → query

【重要：clarify意图的判断规则】
注意：clarify仅用于不完整的【记账】指令，不适用于查询！
1. 单独的金额没有说明用途："50元"、"三十块" → clarify
2. 单独的分类没有金额："餐饮"、"交通" → clarify
3. 不完整的记账指令："帮我记一下"、"记账" → clarify

【重要：chat意图的判断规则】
1. 询问助手能力："你会记账吗"、"你能帮我做什么"
2. 问候语："你好"、"早上好"
3. 闲聊请求："讲个故事"、"讲个笑话"
4. 提问求助："怎么记账"、"如何使用"
5. 表达感谢/告别："谢谢"、"再见"''';
  }

  /// 获取查询参数说明
  String _getQueryParamsDocs() {
    return '''
【查询参数说明（intent为query时必填）】
- queryType: 查询类型（必填）
  * "summary" - 汇总统计（如"花了多少钱"）
  * "recent" - 最近记录（如"最近的消费"）
  * "trend" - 趋势分析（如"消费趋势"）
  * "distribution" - 分布统计（如"各分类占比"）
  * "comparison" - 对比分析（如"比上月多还是少"）
- time: 时间范围（必填）
  * 今天、昨天、本周、上周、本月、上月、今年等
  * 如果用户没说时间，默认使用"本月"
- category: 分类筛选（可选）
- transactionType: 交易类型筛选（可选，expense/income）''';
  }

  /// 获取单意图示例
  String _getSingleIntentExamples() {
    return '''
【示例】
输入："今天花了多少"
输出：{"intent":"query","confidence":0.9,"entities":{"queryType":"summary","time":"今天"}}

输入："早餐15块"
输出：{"intent":"add_transaction","confidence":0.9,"entities":{"amount":15,"category":"餐饮","type":"expense","note":"早餐"}}

输入："你好"
输出：{"intent":"chat","confidence":0.9,"entities":{}}

输入："50元"
输出：{"intent":"clarify","confidence":0.8,"entities":{"amount":50,"clarify_question":"请说明这笔钱是什么消费"}}''';
  }

  /// 根据关键词查找分类
  String? findCategory(String text, {bool isIncome = false}) {
    final config = _configLoader.config;

    if (isIncome) {
      return config.findIncomeCategory(text);
    }
    return config.findExpenseCategory(text);
  }

  /// 规范化备注
  String normalizeNote(String note) {
    return _configLoader.config.normalizeNote(note);
  }

  /// 移除停顿词
  String removeFillerWords(String text) {
    return _configLoader.config.removeFillerWords(text);
  }

  /// 获取 LLM 配置
  LLMConfig get llmConfig => _configLoader.config.llmConfig;
}

/// Prompt 构建器单例
class PromptBuilderInstance {
  static PromptBuilder? _instance;

  static PromptBuilder get instance => _instance ??= PromptBuilder();

  static Future<void> initialize() async {
    await instance.initialize();
  }
}
