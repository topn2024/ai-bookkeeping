import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../qwen_service.dart';
import 'voice_intent_router.dart';
import 'multi_intent_models.dart';

/// 统一意图理解服务
///
/// 所有语音输入的唯一入口，采用LLM优先架构：
/// 1. 规则快速匹配（高置信度常见模式，可选优化）
/// 2. LLM深度理解（主要路径）
/// 3. 上下文融合
/// 4. 多意图分解
///
/// 设计理念：像人一样理解，而不是像机器一样匹配
class UnifiedIntentService {
  final QwenService _qwenService;
  final VoiceIntentRouter _ruleRouter;

  /// 对话上下文
  DialogueContext _context = DialogueContext();

  /// 规则缓存命中阈值
  static const double _ruleCacheThreshold = 0.95;

  /// LLM高置信度阈值（用于学习）
  static const double _llmLearnThreshold = 0.9;

  UnifiedIntentService({
    QwenService? qwenService,
    VoiceIntentRouter? ruleRouter,
  })  : _qwenService = qwenService ?? QwenService(),
        _ruleRouter = ruleRouter ?? VoiceIntentRouter();

  /// 理解用户输入
  ///
  /// 这是所有语音命令的唯一入口点
  ///
  /// [userInput] 用户的语音识别文本
  /// [pageContext] 当前页面上下文
  /// [forceAI] 强制使用AI（跳过规则匹配）
  ///
  /// 处理流程：
  /// 1. 检查规则缓存（高频模式）
  /// 2. 若缓存未命中或置信度低，调用LLM
  /// 3. 融合对话上下文（指代消解、省略补全）
  /// 4. 返回结构化的意图结果
  Future<UnifiedIntentResult> understand(
    String userInput, {
    PageContextInfo? pageContext,
    bool forceAI = false,
  }) async {
    if (userInput.trim().isEmpty) {
      return UnifiedIntentResult.error('输入为空');
    }

    debugPrint('[UnifiedIntent] 开始理解: $userInput');

    // 步骤1: 尝试规则快速匹配（可选优化）
    if (!forceAI) {
      final ruleResult = await _tryRuleMatch(userInput);
      if (ruleResult != null && ruleResult.confidence >= _ruleCacheThreshold) {
        debugPrint('[UnifiedIntent] 规则匹配成功，置信度: ${ruleResult.confidence}');
        return ruleResult;
      }
    }

    // 步骤2: LLM深度理解（主要路径）
    try {
      final llmResult = await _llmUnderstand(userInput, pageContext);

      // 步骤3: 融合对话上下文
      final enrichedResult = _enrichWithContext(llmResult);

      // 步骤4: 更新对话上下文
      _updateContext(userInput, enrichedResult);

      debugPrint('[UnifiedIntent] LLM理解成功: ${enrichedResult.intents.length}个意图');
      return enrichedResult;
    } catch (e) {
      debugPrint('[UnifiedIntent] LLM理解失败: $e');

      // 降级到规则匹配
      final fallbackResult = await _tryRuleMatch(userInput, allowLowConfidence: true);
      if (fallbackResult != null) {
        debugPrint('[UnifiedIntent] 降级到规则匹配');
        return fallbackResult;
      }

      return UnifiedIntentResult.error('无法理解您的输入，请换一种说法试试');
    }
  }

  /// 尝试规则快速匹配
  Future<UnifiedIntentResult?> _tryRuleMatch(
    String input, {
    bool allowLowConfidence = false,
  }) async {
    try {
      final result = await _ruleRouter.analyzeIntent(input);

      if (result.type == VoiceIntentType.unknown) {
        return null;
      }

      final confidence = result.confidence;
      if (!allowLowConfidence && confidence < _ruleCacheThreshold) {
        return null;
      }

      return UnifiedIntentResult(
        intents: [
          IntentItem(
            type: _mapVoiceIntentType(result.type),
            confidence: confidence,
            entities: _extractEntities(result),
            isComplete: _checkCompleteness(result),
            originalText: input,
          ),
        ],
        needsClarification: false,
        source: IntentSource.rule,
      );
    } catch (e) {
      return null;
    }
  }

  /// LLM深度理解
  Future<UnifiedIntentResult> _llmUnderstand(
    String input,
    PageContextInfo? pageContext,
  ) async {
    final prompt = _buildPrompt(input, pageContext);

    final response = await _qwenService.chat(prompt);

    if (response == null || response.isEmpty) {
      throw Exception('LLM返回空结果');
    }

    return _parseResponse(response, input);
  }

  /// 构建LLM Prompt
  String _buildPrompt(String input, PageContextInfo? pageContext) {
    final contextSection = _buildContextSection(pageContext);
    final historySection = _buildHistorySection();

    return '''
你是一个智能记账助手，请理解用户的语音输入并返回结构化的JSON结果。

【用户输入】
$input

【当前上下文】
$contextSection

【对话历史】
$historySection

【你的任务】
1. 识别用户的意图（可能有多个意图，如"记早餐15块，再打开预算页面"）
2. 提取关键实体信息（金额、分类、商家、日期等）
3. 判断信息是否完整
4. 如果信息不完整或有歧义，生成自然的追问
5. 理解指代词（如"那笔"、"刚才的"、"它"）

【支持的意图类型】
- add_transaction: 添加交易记录（需要金额，分类可推断）
- delete_transaction: 删除交易记录
- modify_transaction: 修改交易记录
- query_transaction: 查询交易记录/统计
- navigate: 页面导航（设置、预算、统计、账户、账本等）
- confirm: 确认操作
- cancel: 取消操作
- correct: 纠正之前的操作（如"不对，是50"、"改成交通"）

【分类参考】
餐饮、交通、购物、娱乐、居住、医疗、教育、通讯、服装、日用、其他

【页面参考】
首页、设置、配置、预算、统计、报表、账户、账本、分类、小金库、钱龄

【返回JSON格式】
{
  "intents": [
    {
      "type": "意图类型",
      "confidence": 0.0-1.0的置信度,
      "entities": {
        "amount": 金额数字或null,
        "category": "分类名称或null",
        "merchant": "商家名称或null",
        "date": "日期描述或null",
        "description": "描述或null",
        "target_page": "目标页面或null",
        "reference": "指代词或null（如那笔、它）"
      },
      "is_complete": true或false,
      "missing_info": ["缺失的信息列表"],
      "original_text": "对应的原文片段"
    }
  ],
  "needs_clarification": true或false,
  "clarification_question": "自然的追问（如果需要）",
  "suggested_response": "建议的回复"
}

【重要规则】
1. 金额必须是数字，中文数字要转换（三十五→35）
2. 分类要从参考列表中选择最匹配的
3. 如果用户说的是模糊表达（如"花了点钱"），标记为不完整并追问
4. 如果有指代词，提取出来放到reference字段
5. 多个意图要分开识别，每个意图单独一个对象

请返回JSON：''';
  }

  /// 构建上下文描述
  String _buildContextSection(PageContextInfo? pageContext) {
    final parts = <String>[];

    if (pageContext != null) {
      parts.add('当前页面: ${pageContext.pageName}');
      if (pageContext.additionalInfo != null) {
        parts.add('页面信息: ${pageContext.additionalInfo}');
      }
    }

    if (_context.lastTransaction != null) {
      final tx = _context.lastTransaction!;
      parts.add('上一笔交易: ${tx.category} ${tx.amount}元');
    }

    if (_context.pendingOperation != null) {
      parts.add('待确认操作: ${_context.pendingOperation}');
    }

    return parts.isEmpty ? '无' : parts.join('\n');
  }

  /// 构建历史对话描述
  String _buildHistorySection() {
    if (_context.recentTurns.isEmpty) {
      return '无';
    }

    return _context.recentTurns
        .take(3)
        .map((t) => '用户: ${t.userInput}\n助手: ${t.response}')
        .join('\n\n');
  }

  /// 解析LLM响应
  UnifiedIntentResult _parseResponse(String response, String originalInput) {
    try {
      // 提取JSON
      final jsonStr = _extractJson(response);
      if (jsonStr == null) {
        throw Exception('无法提取JSON');
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final intentsJson = json['intents'] as List<dynamic>? ?? [];
      final intents = intentsJson.map((i) => _parseIntent(i)).toList();

      return UnifiedIntentResult(
        intents: intents,
        needsClarification: json['needs_clarification'] as bool? ?? false,
        clarificationQuestion: json['clarification_question'] as String?,
        suggestedResponse: json['suggested_response'] as String?,
        source: IntentSource.llm,
      );
    } catch (e) {
      debugPrint('[UnifiedIntent] 解析响应失败: $e');
      throw Exception('解析LLM响应失败');
    }
  }

  /// 提取JSON字符串
  String? _extractJson(String response) {
    final jsonStart = response.indexOf('{');
    final jsonEnd = response.lastIndexOf('}');

    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
      return null;
    }

    return response.substring(jsonStart, jsonEnd + 1);
  }

  /// 解析单个意图
  IntentItem _parseIntent(dynamic json) {
    final map = json as Map<String, dynamic>;
    final entities = map['entities'] as Map<String, dynamic>? ?? {};

    return IntentItem(
      type: _parseIntentType(map['type'] as String? ?? 'unknown'),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      entities: IntentEntities(
        amount: _parseAmount(entities['amount']),
        category: entities['category'] as String?,
        merchant: entities['merchant'] as String?,
        date: entities['date'] as String?,
        description: entities['description'] as String?,
        targetPage: entities['target_page'] as String?,
        reference: entities['reference'] as String?,
      ),
      isComplete: map['is_complete'] as bool? ?? true,
      missingInfo: (map['missing_info'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      originalText: map['original_text'] as String? ?? '',
    );
  }

  /// 解析金额
  double? _parseAmount(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
    }
    return null;
  }

  /// 解析意图类型
  IntentType _parseIntentType(String type) {
    switch (type.toLowerCase()) {
      case 'add_transaction':
        return IntentType.addTransaction;
      case 'delete_transaction':
        return IntentType.deleteTransaction;
      case 'modify_transaction':
        return IntentType.modifyTransaction;
      case 'query_transaction':
        return IntentType.queryTransaction;
      case 'navigate':
        return IntentType.navigate;
      case 'confirm':
        return IntentType.confirm;
      case 'cancel':
        return IntentType.cancel;
      case 'correct':
        return IntentType.correct;
      default:
        return IntentType.unknown;
    }
  }

  /// 映射旧意图类型
  IntentType _mapVoiceIntentType(VoiceIntentType type) {
    switch (type) {
      case VoiceIntentType.addTransaction:
        return IntentType.addTransaction;
      case VoiceIntentType.deleteTransaction:
        return IntentType.deleteTransaction;
      case VoiceIntentType.modifyTransaction:
        return IntentType.modifyTransaction;
      case VoiceIntentType.queryTransaction:
        return IntentType.queryTransaction;
      case VoiceIntentType.navigateToPage:
        return IntentType.navigate;
      case VoiceIntentType.confirmAction:
        return IntentType.confirm;
      case VoiceIntentType.cancelAction:
        return IntentType.cancel;
      default:
        return IntentType.unknown;
    }
  }

  /// 从规则结果提取实体
  IntentEntities _extractEntities(IntentAnalysisResult result) {
    return IntentEntities(
      amount: result.entities['amount'] as double?,
      category: result.entities['category'] as String?,
      merchant: result.entities['merchant'] as String?,
      targetPage: result.entities['targetPage'] as String?,
    );
  }

  /// 检查意图完整性
  bool _checkCompleteness(IntentAnalysisResult result) {
    if (result.type == VoiceIntentType.addTransaction) {
      return result.entities['amount'] != null;
    }
    return true;
  }

  /// 融合上下文信息
  UnifiedIntentResult _enrichWithContext(UnifiedIntentResult result) {
    final enrichedIntents = result.intents.map((intent) {
      // 解析指代词
      if (intent.entities.reference != null && _context.lastTransaction != null) {
        return intent.copyWith(
          resolvedReference: _context.lastTransaction,
        );
      }
      return intent;
    }).toList();

    return result.copyWith(intents: enrichedIntents);
  }

  /// 更新对话上下文
  void _updateContext(String input, UnifiedIntentResult result) {
    // 添加到对话历史
    _context.recentTurns.add(DialogueTurn(
      userInput: input,
      response: result.suggestedResponse ?? '',
      timestamp: DateTime.now(),
    ));

    // 保持最近5轮
    if (_context.recentTurns.length > 5) {
      _context.recentTurns.removeAt(0);
    }
  }

  /// 记录最近执行的交易（用于指代消解）
  void recordTransaction(TransactionInfo transaction) {
    _context.lastTransaction = transaction;
  }

  /// 设置待确认操作
  void setPendingOperation(String? operation) {
    _context.pendingOperation = operation;
  }

  /// 清除上下文
  void clearContext() {
    _context = DialogueContext();
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

/// 统一意图理解结果
class UnifiedIntentResult {
  /// 识别到的意图列表
  final List<IntentItem> intents;

  /// 是否需要追问
  final bool needsClarification;

  /// 追问问题
  final String? clarificationQuestion;

  /// 建议的回复
  final String? suggestedResponse;

  /// 结果来源
  final IntentSource source;

  /// 错误信息
  final String? errorMessage;

  const UnifiedIntentResult({
    required this.intents,
    this.needsClarification = false,
    this.clarificationQuestion,
    this.suggestedResponse,
    this.source = IntentSource.llm,
    this.errorMessage,
  });

  factory UnifiedIntentResult.error(String message) {
    return UnifiedIntentResult(
      intents: [],
      errorMessage: message,
      source: IntentSource.error,
    );
  }

  bool get isSuccess => errorMessage == null && intents.isNotEmpty;

  bool get hasMultipleIntents => intents.length > 1;

  IntentItem? get primaryIntent => intents.isNotEmpty ? intents.first : null;

  UnifiedIntentResult copyWith({
    List<IntentItem>? intents,
    bool? needsClarification,
    String? clarificationQuestion,
    String? suggestedResponse,
  }) {
    return UnifiedIntentResult(
      intents: intents ?? this.intents,
      needsClarification: needsClarification ?? this.needsClarification,
      clarificationQuestion: clarificationQuestion ?? this.clarificationQuestion,
      suggestedResponse: suggestedResponse ?? this.suggestedResponse,
      source: source,
      errorMessage: errorMessage,
    );
  }
}

/// 单个意图
class IntentItem {
  final IntentType type;
  final double confidence;
  final IntentEntities entities;
  final bool isComplete;
  final List<String> missingInfo;
  final String originalText;

  /// 解析后的指代对象
  final TransactionInfo? resolvedReference;

  const IntentItem({
    required this.type,
    required this.confidence,
    required this.entities,
    this.isComplete = true,
    this.missingInfo = const [],
    this.originalText = '',
    this.resolvedReference,
  });

  IntentItem copyWith({
    TransactionInfo? resolvedReference,
  }) {
    return IntentItem(
      type: type,
      confidence: confidence,
      entities: entities,
      isComplete: isComplete,
      missingInfo: missingInfo,
      originalText: originalText,
      resolvedReference: resolvedReference ?? this.resolvedReference,
    );
  }
}

/// 意图实体
class IntentEntities {
  final double? amount;
  final String? category;
  final String? merchant;
  final String? date;
  final String? description;
  final String? targetPage;
  final String? reference;

  const IntentEntities({
    this.amount,
    this.category,
    this.merchant,
    this.date,
    this.description,
    this.targetPage,
    this.reference,
  });
}

/// 意图类型
enum IntentType {
  addTransaction,
  deleteTransaction,
  modifyTransaction,
  queryTransaction,
  navigate,
  confirm,
  cancel,
  correct,
  unknown,
}

/// 意图来源
enum IntentSource {
  rule,   // 规则匹配
  llm,    // LLM理解
  error,  // 错误
}

/// 对话上下文
class DialogueContext {
  /// 最近的交易（用于指代消解）
  TransactionInfo? lastTransaction;

  /// 待确认的操作
  String? pendingOperation;

  /// 最近的对话轮次
  final List<DialogueTurn> recentTurns = [];
}

/// 对话轮次
class DialogueTurn {
  final String userInput;
  final String response;
  final DateTime timestamp;

  const DialogueTurn({
    required this.userInput,
    required this.response,
    required this.timestamp,
  });
}

/// 交易信息（简化版，用于上下文）
class TransactionInfo {
  final String id;
  final double amount;
  final String category;
  final String? description;

  const TransactionInfo({
    required this.id,
    required this.amount,
    required this.category,
    this.description,
  });
}

/// 页面上下文信息
class PageContextInfo {
  final String pageName;
  final String? additionalInfo;

  const PageContextInfo({
    required this.pageName,
    this.additionalInfo,
  });
}
