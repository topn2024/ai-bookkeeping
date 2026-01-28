/// 分解意图模型
///
/// 将用户输入分解为聊天意图和操作意图，支持：
/// - 聊天意图：立即响应用户
/// - 操作意图：后台异步执行
///
/// 例如："陪我聊天吗？打车费15元"
/// → ChatIntent: "陪我聊天吗？" → 立即响应
/// → ActionIntent: "打车费15元" → 后台执行
library;

import '../network_monitor.dart';

/// 分解意图结果
class DecomposedIntentResult {
  /// 聊天意图（需要立即响应）
  final ChatIntent? chatIntent;

  /// 操作意图列表（后台执行）
  final List<ActionIntent> actionIntents;

  /// 原始输入
  final String rawInput;

  /// 总体置信度
  final double confidence;

  /// 识别来源
  final RecognitionSource source;

  const DecomposedIntentResult({
    this.chatIntent,
    required this.actionIntents,
    required this.rawInput,
    required this.confidence,
    required this.source,
  });

  /// 是否只有聊天意图
  bool get isChatOnly => chatIntent != null && actionIntents.isEmpty;

  /// 是否只有操作意图
  bool get isActionOnly => chatIntent == null && actionIntents.isNotEmpty;

  /// 是否是混合意图
  bool get isHybrid => chatIntent != null && actionIntents.isNotEmpty;

  /// 是否为空（未识别）
  bool get isEmpty => chatIntent == null && actionIntents.isEmpty;

  /// 操作意图数量
  int get actionCount => actionIntents.length;

  /// 创建空结果
  factory DecomposedIntentResult.empty(String rawInput) {
    return DecomposedIntentResult(
      chatIntent: null,
      actionIntents: const [],
      rawInput: rawInput,
      confidence: 0,
      source: RecognitionSource.rule,
    );
  }

  /// 从单一 IntentResult 转换（向后兼容）
  factory DecomposedIntentResult.fromIntentResult(IntentResult result) {
    if (result.type == RouteType.chat) {
      return DecomposedIntentResult(
        chatIntent: ChatIntent(
          text: result.rawInput,
          emotion: result.emotion,
          suggestedResponse: result.chatResponse,
        ),
        actionIntents: const [],
        rawInput: result.rawInput,
        confidence: result.confidence,
        source: result.source,
      );
    }

    if (result.type == RouteType.action) {
      return DecomposedIntentResult(
        chatIntent: null,
        actionIntents: [
          ActionIntent(
            category: result.category ?? 'unknown',
            action: result.action ?? 'unknown',
            entities: result.entities,
            originalText: result.rawInput,
            confidence: result.confidence,
          ),
        ],
        rawInput: result.rawInput,
        confidence: result.confidence,
        source: result.source,
      );
    }

    if (result.type == RouteType.hybrid) {
      // 混合意图：拆分为聊天 + 操作
      return DecomposedIntentResult(
        chatIntent: result.chatResponse != null
            ? ChatIntent(
                text: result.rawInput,
                emotion: result.emotion,
                suggestedResponse: result.chatResponse,
              )
            : null,
        actionIntents: result.action != null
            ? [
                ActionIntent(
                  category: result.category ?? 'transaction',
                  action: result.action!,
                  entities: result.entities,
                  originalText: result.rawInput,
                  confidence: result.confidence,
                ),
              ]
            : const [],
        rawInput: result.rawInput,
        confidence: result.confidence,
        source: result.source,
      );
    }

    return DecomposedIntentResult.empty(result.rawInput);
  }

  @override
  String toString() {
    return 'DecomposedIntentResult(chat: ${chatIntent != null}, actions: ${actionIntents.length}, confidence: ${confidence.toStringAsFixed(2)})';
  }
}

/// 聊天意图
class ChatIntent {
  /// 原始文本
  final String text;

  /// 情感
  final String? emotion;

  /// LLM建议的响应
  final String? suggestedResponse;

  /// 是否需要主动关怀
  final bool needsEmpathy;

  const ChatIntent({
    required this.text,
    this.emotion,
    this.suggestedResponse,
    this.needsEmpathy = false,
  });

  /// 是否有建议响应
  bool get hasSuggestedResponse =>
      suggestedResponse != null && suggestedResponse!.isNotEmpty;

  @override
  String toString() => 'ChatIntent(text: $text, emotion: $emotion)';
}

/// 操作意图
class ActionIntent {
  /// 意图类别 (transaction, config, query, navigation)
  final String category;

  /// 具体行为 (expense, income, budget.monthly, statistics, page, etc.)
  final String action;

  /// 提取的实体
  final Map<String, dynamic> entities;

  /// 原始文本
  final String originalText;

  /// 置信度
  final double confidence;

  /// 优先级 (数值越小优先级越高)
  final int priority;

  const ActionIntent({
    required this.category,
    required this.action,
    required this.entities,
    required this.originalText,
    required this.confidence,
    this.priority = 5,
  });

  /// 完整的意图ID
  String get intentId => '$category.$action';

  /// 是否是交易操作
  bool get isTransaction => category == 'transaction';

  /// 是否是查询操作
  bool get isQuery => category == 'query';

  /// 是否是导航操作
  bool get isNavigation => category == 'navigation';

  /// 是否是配置操作
  bool get isConfig => category == 'config';

  /// 转换为 IntentResult（向后兼容）
  IntentResult toIntentResult() {
    return IntentResult(
      type: RouteType.action,
      confidence: confidence,
      category: category,
      action: action,
      entities: entities,
      rawInput: originalText,
      source: RecognitionSource.llm,
    );
  }

  @override
  String toString() =>
      'ActionIntent(id: $intentId, confidence: ${confidence.toStringAsFixed(2)})';
}

/// 操作执行结果
class ActionExecutionResult {
  /// 操作意图
  final ActionIntent intent;

  /// 是否成功
  final bool success;

  /// 响应文本
  final String? responseText;

  /// 错误信息
  final String? error;

  /// 附加数据
  final Map<String, dynamic>? data;

  /// 执行时间（毫秒）
  final int executionTimeMs;

  const ActionExecutionResult({
    required this.intent,
    required this.success,
    this.responseText,
    this.error,
    this.data,
    required this.executionTimeMs,
  });

  /// 创建成功结果
  factory ActionExecutionResult.success(
    ActionIntent intent, {
    String? responseText,
    Map<String, dynamic>? data,
    int executionTimeMs = 0,
  }) {
    return ActionExecutionResult(
      intent: intent,
      success: true,
      responseText: responseText,
      data: data,
      executionTimeMs: executionTimeMs,
    );
  }

  /// 创建失败结果
  factory ActionExecutionResult.failure(
    ActionIntent intent, {
    String? error,
    int executionTimeMs = 0,
  }) {
    return ActionExecutionResult(
      intent: intent,
      success: false,
      error: error,
      executionTimeMs: executionTimeMs,
    );
  }
}
