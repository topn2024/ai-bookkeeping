/// LLM 意图分类器
///
/// 使用大语言模型进行意图分类、实体提取和情感分析
///
/// 核心职责：
/// - 意图分类：chat / action / hybrid / unknown
/// - 多意图分解：将混合输入拆分为聊天+操作
/// - 实体提取：金额、分类、时间、配置项等
/// - 情感判断：开心 / 沮丧 / 焦虑 / 平静
/// - 聊天响应：生成自然语言对话
///
/// 设计原则：
/// - 只做理解，不执行业务操作
/// - 同一数字根据上下文准确分类（支出/收入/预算/配置）
/// - 支持多意图并行：聊天立即响应，操作后台执行
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../qwen_service.dart';
import 'hybrid_intent_router.dart';
import 'decomposed_intent.dart';

/// LLM 意图分类器
class LLMIntentClassifier {
  final QwenService _qwenService;

  /// 助手人格名称
  final String assistantName;

  LLMIntentClassifier({
    QwenService? qwenService,
    this.assistantName = '小记',
  }) : _qwenService = qwenService ?? QwenService();

  /// 检查LLM是否可用
  bool get isAvailable => _qwenService.isAvailable;

  /// 分类意图
  ///
  /// [input] 用户输入
  /// [contextSummary] 上下文摘要
  Future<IntentResult?> classify(String input, String? contextSummary) async {
    if (!isAvailable) {
      debugPrint('[LLMClassifier] LLM服务不可用');
      return null;
    }

    try {
      final prompt = _buildClassificationPrompt(input, contextSummary);
      final response = await _qwenService.chat(prompt);

      if (response == null || response.isEmpty) {
        debugPrint('[LLMClassifier] LLM响应为空');
        return null;
      }

      return _parseResponse(response, input);
    } catch (e) {
      debugPrint('[LLMClassifier] 分类失败: $e');
      rethrow;
    }
  }

  /// 构建分类提示词
  String _buildClassificationPrompt(String input, String? context) {
    return '''你是"$assistantName"记账助手的意图分类器。分析用户输入，判断意图类型并提取关键信息。

【关键规则】同一个数字在不同语境下含义完全不同：
- "花了/买了/吃了/付了/消费" + 金额 → 支出 (transaction.expense)
- "收到/赚了/入账/工资/奖金/红包/退款/返现" + 金额 → 收入 (transaction.income)
- "转账/转给/给" + 金额 → 转账 (transaction.transfer)
- "预算/限额" + 金额 → 预算配置 (config.budget.*)
- "提醒/闹钟" + 时间 → 提醒配置 (config.reminder.*)
- "改成/调整为/修改" + 金额 → 看上下文判断是修改交易还是修改配置
- "查/查看/多少/统计" → 查询 (query.*)
- "打开/去/跳转" + 页面 → 导航 (navigation.*)

【意图分类】
- chat: 纯聊天，如问候、闲聊、情感倾诉
- action: 功能操作，如记账、查询、导航、配置
- hybrid: 混合意图，如"有点饿，帮我记一下午饭30块"
- unknown: 无法理解

【意图类别详解】
transaction（交易）:
  - expense: 支出（花了、买了、付了、消费）
  - income: 收入（收到、赚了、入账、工资、奖金）
  - transfer: 转账（转给、转账）
  - modify: 修改（改成、修改）
  - delete: 删除（删掉、删除）

config（配置）:
  - budget.monthly: 月度预算
  - budget.category: 分类预算
  - account.default: 默认账户
  - reminder.daily: 每日提醒
  - theme.mode: 主题模式
  （等等，支持136+配置项）

query（查询）:
  - statistics: 统计查询（这个月花了多少）
  - trend: 趋势查询（消费趋势）
  - budget: 预算查询（预算还剩多少）
  - transaction: 交易查询（查看最近的记录）

navigation（导航）:
  - page: 页面跳转（打开统计页面）
  - tab: 标签切换（切换到账本）

${context != null ? '\n【对话上下文】\n$context\n' : ''}

【用户输入】
$input

【输出格式】严格JSON，不要有其他内容：
{
  "type": "chat|action|hybrid|unknown",
  "confidence": 0.0-1.0,
  "intent": {
    "category": "transaction|config|query|navigation|null",
    "action": "expense|income|budget.monthly|statistics|page|...|null",
    "entities": {
      "amount": 数字或null,
      "category": "分类名"或null,
      "time": "时间描述"或null,
      "accountName": "账户名"或null,
      "merchant": "商家"或null,
      "configKey": "配置键"或null,
      "configValue": "配置值"或null,
      "targetPage": "目标页面"或null
    }
  },
  "emotion": "neutral|happy|frustrated|anxious|sad",
  "chat_response": "如果是chat或hybrid，这里是自然语言回复"
}''';
  }

  /// 解析LLM响应
  IntentResult? _parseResponse(String response, String rawInput) {
    try {
      // 尝试提取JSON
      String jsonStr = response;

      // 处理可能的markdown代码块
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!.trim();
      }

      // 尝试找到JSON对象
      final startIndex = jsonStr.indexOf('{');
      final endIndex = jsonStr.lastIndexOf('}');
      if (startIndex >= 0 && endIndex > startIndex) {
        jsonStr = jsonStr.substring(startIndex, endIndex + 1);
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 解析类型
      final typeStr = json['type'] as String? ?? 'unknown';
      final type = _parseRouteType(typeStr);

      // 解析置信度
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;

      // 解析意图
      final intent = json['intent'] as Map<String, dynamic>?;
      final category = intent?['category'] as String?;
      final action = intent?['action'] as String?;
      final entities = _parseEntities(intent?['entities'] as Map<String, dynamic>?);

      // 解析情感
      final emotion = json['emotion'] as String?;

      // 解析聊天响应
      final chatResponse = json['chat_response'] as String?;

      return IntentResult(
        type: type,
        confidence: confidence,
        category: category,
        action: action,
        entities: entities,
        emotion: emotion,
        chatResponse: chatResponse,
        rawInput: rawInput,
        source: RecognitionSource.llm,
      );
    } catch (e) {
      debugPrint('[LLMClassifier] JSON解析失败: $e');
      debugPrint('[LLMClassifier] 原始响应: $response');
      return null;
    }
  }

  /// 解析路由类型
  RouteType _parseRouteType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'chat':
        return RouteType.chat;
      case 'action':
        return RouteType.action;
      case 'hybrid':
        return RouteType.hybrid;
      default:
        return RouteType.unknown;
    }
  }

  /// 解析实体
  Map<String, dynamic> _parseEntities(Map<String, dynamic>? raw) {
    if (raw == null) return {};

    final entities = <String, dynamic>{};

    // 金额
    if (raw['amount'] != null) {
      final amount = raw['amount'];
      if (amount is num) {
        entities['amount'] = amount.toDouble();
      } else if (amount is String) {
        entities['amount'] = double.tryParse(amount);
      }
    }

    // 分类
    if (raw['category'] != null && raw['category'] is String) {
      entities['category'] = raw['category'];
    }

    // 时间
    if (raw['time'] != null && raw['time'] is String) {
      entities['time'] = raw['time'];
      entities['parsedTime'] = _parseTimeReference(raw['time'] as String);
    }

    // 账户名
    if (raw['accountName'] != null && raw['accountName'] is String) {
      entities['accountName'] = raw['accountName'];
    }

    // 商家
    if (raw['merchant'] != null && raw['merchant'] is String) {
      entities['merchant'] = raw['merchant'];
    }

    // 配置键
    if (raw['configKey'] != null && raw['configKey'] is String) {
      entities['configKey'] = raw['configKey'];
    }

    // 配置值
    if (raw['configValue'] != null) {
      entities['configValue'] = raw['configValue'];
    }

    // 目标页面
    if (raw['targetPage'] != null && raw['targetPage'] is String) {
      entities['targetPage'] = raw['targetPage'];
    }

    return entities;
  }

  /// 解析时间引用
  DateTime? _parseTimeReference(String timeStr) {
    final now = DateTime.now();

    if (timeStr.contains('今天') || timeStr.contains('今日')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (timeStr.contains('昨天')) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (timeStr.contains('前天')) {
      return DateTime(now.year, now.month, now.day - 2);
    }
    if (timeStr.contains('本月') || timeStr.contains('这个月')) {
      return DateTime(now.year, now.month, 1);
    }
    if (timeStr.contains('上个月') || timeStr.contains('上月')) {
      return DateTime(now.year, now.month - 1, 1);
    }
    if (timeStr.contains('本周') || timeStr.contains('这周')) {
      final weekday = now.weekday;
      return now.subtract(Duration(days: weekday - 1));
    }

    return null;
  }

  /// 预热连接
  Future<void> warmup() async {
    // 发送一个轻量级请求预热连接
    try {
      await _qwenService.chat('hi').timeout(const Duration(seconds: 2));
    } catch (e) {
      // 忽略预热失败
    }
  }

  /// 测量延迟
  Future<int> measureLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _qwenService.chat('ping').timeout(const Duration(seconds: 5));
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return 5000; // 返回超时时间
    }
  }

  /// 检查可用性
  Future<bool> checkAvailability() async {
    if (!isAvailable) return false;
    try {
      final response = await _qwenService
          .chat('test')
          .timeout(const Duration(seconds: 3));
      return response != null && response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 分解意图分类
  ///
  /// 将用户输入分解为聊天意图和操作意图
  /// - 聊天意图：需要立即响应用户
  /// - 操作意图：可以后台异步执行
  Future<DecomposedIntentResult?> classifyDecomposed(
    String input,
    String? contextSummary,
  ) async {
    if (!isAvailable) {
      debugPrint('[LLMClassifier] LLM服务不可用');
      return null;
    }

    try {
      final prompt = _buildDecomposedPrompt(input, contextSummary);
      final response = await _qwenService.chat(prompt);

      if (response == null || response.isEmpty) {
        debugPrint('[LLMClassifier] LLM响应为空');
        return null;
      }

      return _parseDecomposedResponse(response, input);
    } catch (e) {
      debugPrint('[LLMClassifier] 分解分类失败: $e');
      rethrow;
    }
  }

  /// 构建分解意图提示词
  String _buildDecomposedPrompt(String input, String? context) {
    return '''你是"$assistantName"记账助手的意图分解器。分析用户输入，将其分解为"聊天意图"和"操作意图"。

【核心任务】
用户的一句话可能包含多个意图，需要分开处理：
1. 聊天意图：问候、闲聊、情感表达、询问能力等 → 需要立即回应
2. 操作意图：记账、查询、导航、配置等具体功能 → 可以后台执行

【示例】
输入："陪我聊天吗？打车费15元"
分解：
- 聊天意图："陪我聊天吗？" → 需要立即回应"当然可以陪你聊天呀~"
- 操作意图："打车费15元" → 后台执行记账

输入："今天有点累，记一下午餐30块"
分解：
- 聊天意图："今天有点累" → 需要关心用户
- 操作意图："午餐30块" → 后台执行记账

输入："打车15元"
分解：
- 聊天意图：无
- 操作意图："打车15元" → 执行记账

输入："你好呀"
分解：
- 聊天意图："你好呀" → 需要回应问候
- 操作意图：无

【操作意图类型】
transaction（交易）:
  - expense: 支出（花了、买了、付了、消费、XX多少钱/块/元）
  - income: 收入（收到、赚了、入账、工资、奖金）
  - transfer: 转账（转给、转账）
  - modify: 修改（改成、修改）
  - delete: 删除（删掉、删除）

config（配置）:
  - budget.monthly: 月度预算
  - budget.category: 分类预算
  等其他配置...

query（查询）:
  - statistics: 统计查询（这个月花了多少）
  - trend: 趋势查询
  - budget: 预算查询
  - transaction: 交易查询

navigation（导航）:
  - page: 页面跳转（打开、进入、去）

${context != null ? '\n【对话上下文】\n$context\n' : ''}

【用户输入】
$input

【输出格式】严格JSON，不要有其他内容：
{
  "chat_intent": {
    "has_chat": true/false,
    "text": "聊天相关的原文",
    "emotion": "neutral|happy|frustrated|anxious|sad",
    "suggested_response": "建议的聊天回复（自然、友好、简短）"
  },
  "action_intents": [
    {
      "category": "transaction|config|query|navigation",
      "action": "expense|income|statistics|page|...",
      "entities": {
        "amount": 数字或null,
        "category": "分类名"或null,
        "description": "描述"或null,
        "targetPage": "目标页面"或null
      },
      "original_text": "操作相关的原文",
      "confidence": 0.0-1.0
    }
  ],
  "overall_confidence": 0.0-1.0
}''';
  }

  /// 解析分解意图响应
  DecomposedIntentResult? _parseDecomposedResponse(String response, String rawInput) {
    try {
      // 尝试提取JSON
      String jsonStr = response;

      // 处理可能的markdown代码块
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!.trim();
      }

      // 尝试找到JSON对象
      final startIndex = jsonStr.indexOf('{');
      final endIndex = jsonStr.lastIndexOf('}');
      if (startIndex >= 0 && endIndex > startIndex) {
        jsonStr = jsonStr.substring(startIndex, endIndex + 1);
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 解析聊天意图
      ChatIntent? chatIntent;
      final chatJson = json['chat_intent'] as Map<String, dynamic>?;
      if (chatJson != null && chatJson['has_chat'] == true) {
        chatIntent = ChatIntent(
          text: chatJson['text'] as String? ?? rawInput,
          emotion: chatJson['emotion'] as String?,
          suggestedResponse: chatJson['suggested_response'] as String?,
          needsEmpathy: chatJson['emotion'] == 'frustrated' ||
              chatJson['emotion'] == 'sad' ||
              chatJson['emotion'] == 'anxious',
        );
      }

      // 解析操作意图列表
      final actionIntents = <ActionIntent>[];
      final actionsJson = json['action_intents'] as List<dynamic>?;
      if (actionsJson != null) {
        for (final actionJson in actionsJson) {
          if (actionJson is Map<String, dynamic>) {
            final category = actionJson['category'] as String?;
            final action = actionJson['action'] as String?;
            if (category != null && action != null) {
              actionIntents.add(ActionIntent(
                category: category,
                action: action,
                entities: _parseEntities(actionJson['entities'] as Map<String, dynamic>?),
                originalText: actionJson['original_text'] as String? ?? rawInput,
                confidence: (actionJson['confidence'] as num?)?.toDouble() ?? 0.8,
              ));
            }
          }
        }
      }

      final overallConfidence = (json['overall_confidence'] as num?)?.toDouble() ?? 0.8;

      debugPrint('[LLMClassifier] 分解结果: chat=${chatIntent != null}, actions=${actionIntents.length}');

      return DecomposedIntentResult(
        chatIntent: chatIntent,
        actionIntents: actionIntents,
        rawInput: rawInput,
        confidence: overallConfidence,
        source: RecognitionSource.llm,
      );
    } catch (e) {
      debugPrint('[LLMClassifier] 分解JSON解析失败: $e');
      debugPrint('[LLMClassifier] 原始响应: $response');
      return null;
    }
  }
}

/// 规则意图分类器适配器
///
/// 将现有的规则引擎结果转换为 IntentResult
class RuleIntentClassifierAdapter {
  /// 从 VoiceIntentRouter 的结果转换
  static IntentResult fromVoiceIntentResult(
    String intentType,
    double confidence,
    Map<String, dynamic> entities,
    String rawInput,
  ) {
    // 映射意图类型
    String? category;
    String? action;
    RouteType type = RouteType.action;

    switch (intentType) {
      case 'addTransaction':
        category = IntentCategory.transaction;
        // 根据实体判断是支出还是收入
        if (_isIncomeKeyword(rawInput)) {
          action = 'income';
        } else {
          action = 'expense';
        }
        break;

      case 'deleteTransaction':
        category = IntentCategory.transaction;
        action = 'delete';
        break;

      case 'modifyTransaction':
        category = IntentCategory.transaction;
        action = 'modify';
        break;

      case 'queryTransaction':
        category = IntentCategory.query;
        action = 'statistics';
        break;

      case 'navigateToPage':
        category = IntentCategory.navigation;
        action = 'page';
        break;

      case 'confirmAction':
        category = 'system';
        action = 'confirm';
        break;

      case 'cancelAction':
        category = 'system';
        action = 'cancel';
        break;

      default:
        type = RouteType.unknown;
    }

    return IntentResult(
      type: type,
      confidence: confidence,
      category: category,
      action: action,
      entities: entities,
      rawInput: rawInput,
      source: RecognitionSource.rule,
    );
  }

  /// 检查是否包含收入关键词
  static bool _isIncomeKeyword(String input) {
    const incomeKeywords = [
      '收入',
      '赚了',
      '进账',
      '收到',
      '工资',
      '奖金',
      '入账',
      '捡到',
      '捡了',
      '中奖',
      '返现',
      '退款',
      '红包',
    ];
    return incomeKeywords.any((k) => input.contains(k));
  }
}
