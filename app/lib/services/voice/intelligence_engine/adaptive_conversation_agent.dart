import 'package:flutter/foundation.dart';
import 'intelligence_engine.dart';
import 'models.dart';

/// 自适应对话代理
///
/// 职责：
/// - 对话模式检测（chat/chatWithIntent/quickBookkeeping/mixed）
/// - 根据模式生成不同风格响应
/// - 与 LLMResponseGenerator 集成
class AdaptiveConversationAgent {
  /// 检测对话模式
  ConversationMode detectMode({
    required String input,
    required List<Operation> operations,
    String? chatContent,
  }) {
    debugPrint('[AdaptiveConversationAgent] 检测对话模式');
    debugPrint('  - 操作数量: ${operations.length}');
    debugPrint('  - 对话内容: $chatContent');

    // 无操作 + 无疑问词 → chat
    if (operations.isEmpty && !_hasQuestionWords(input)) {
      debugPrint('  → chat 模式（闲聊）');
      return ConversationMode.chat;
    }

    // 无操作 + 有疑问词 → chatWithIntent
    if (operations.isEmpty && _hasQuestionWords(input)) {
      debugPrint('  → chatWithIntent 模式（有诉求的闲聊）');
      return ConversationMode.chatWithIntent;
    }

    // 多操作（≥2）+ 无疑问词 → quickBookkeeping
    if (operations.length >= 2 && !_hasQuestionWords(input)) {
      debugPrint('  → quickBookkeeping 模式（快速记账）');
      return ConversationMode.quickBookkeeping;
    }

    // 有操作 + 有对话内容 → mixed
    if (operations.isNotEmpty && (chatContent != null || _hasQuestionWords(input))) {
      debugPrint('  → mixed 模式（混合）');
      return ConversationMode.mixed;
    }

    // 默认：chatWithIntent
    debugPrint('  → chatWithIntent 模式（默认）');
    return ConversationMode.chatWithIntent;
  }

  /// 检查是否包含疑问词
  bool _hasQuestionWords(String input) {
    const questionWords = [
      '吗', '呢', '怎么', '为什么', '多少', '哪', '什么',
      '如何', '能不能', '可以', '是否', '有没有',
    ];

    return questionWords.any((word) => input.contains(word));
  }

  /// 生成响应（模板模式，实际生成由 FeedbackAdapter 完成）
  String generateTemplateResponse({
    required ConversationMode mode,
    required List<ExecutionResult> results,
    String? chatContent,
  }) {
    debugPrint('[AdaptiveConversationAgent] 生成模板响应, 模式: $mode');

    switch (mode) {
      case ConversationMode.chat:
        return _generateChatResponse();

      case ConversationMode.chatWithIntent:
        return _generateChatWithIntentResponse(results, chatContent);

      case ConversationMode.quickBookkeeping:
        return _generateQuickBookkeepingResponse(results);

      case ConversationMode.mixed:
        return _generateMixedResponse(results, chatContent);

      case ConversationMode.clarify:
        // clarify 模式由 IntelligenceEngine 直接处理，这里作为防御性编程
        return chatContent ?? '请问您具体想要做什么呢？';
    }
  }

  /// 生成 chat 模式响应（降级模板，实际由ChatEngine处理）
  ///
  /// 日常闲聊默认1-2句，用户要求讲故事/详细解释时可展开3-5句
  String _generateChatResponse() {
    const templates = [
      '好的，有什么可以帮您的吗？',
      '明白了，需要记账吗？',
      '收到，随时为您服务',
    ];
    return templates[DateTime.now().millisecond % templates.length];
  }

  /// 生成 chatWithIntent 模式响应（详细回答）
  String _generateChatWithIntentResponse(
    List<ExecutionResult> results,
    String? chatContent,
  ) {
    if (results.isEmpty) {
      return '我会帮您查询相关信息';
    }

    final successCount = results.where((r) => r.success).length;
    return '已为您处理 $successCount 项操作，详细信息如下...';
  }

  /// 生成 quickBookkeeping 模式响应（极简"✓ 2笔"）
  String _generateQuickBookkeepingResponse(List<ExecutionResult> results) {
    final successCount = results.where((r) => r.success).length;
    return '✓ $successCount笔';
  }

  /// 生成 mixed 模式响应（简短确认+操作反馈）
  String _generateMixedResponse(
    List<ExecutionResult> results,
    String? chatContent,
  ) {
    final successCount = results.where((r) => r.success).length;
    final base = '已记录 $successCount 笔';

    if (chatContent != null && chatContent.isNotEmpty) {
      return '$base，关于您的问题...';
    }

    return base;
  }

  /// 获取响应长度限制
  ///
  /// 注意：chat模式上限较高，以支持用户要求讲故事等场景
  ResponseLengthLimit getLengthLimit(ConversationMode mode) {
    switch (mode) {
      case ConversationMode.chat:
        return ResponseLengthLimit(min: 10, max: 100);  // 支持展开回复
      case ConversationMode.chatWithIntent:
        return ResponseLengthLimit(min: 30, max: 100);
      case ConversationMode.quickBookkeeping:
        return ResponseLengthLimit(min: 5, max: 10);
      case ConversationMode.mixed:
        return ResponseLengthLimit(min: 20, max: 50);
      case ConversationMode.clarify:
        return ResponseLengthLimit(min: 15, max: 40);
    }
  }
}

/// 响应长度限制
class ResponseLengthLimit {
  final int min;
  final int max;

  ResponseLengthLimit({required this.min, required this.max});
}
