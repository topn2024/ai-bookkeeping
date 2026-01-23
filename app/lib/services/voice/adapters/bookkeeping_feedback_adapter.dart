import 'package:flutter/foundation.dart';
import '../intelligence_engine/intelligence_engine.dart';
import '../intelligence_engine/models.dart';
import '../llm_response_generator.dart';
import '../../casual_chat_service.dart';

/// 记账反馈适配器
///
/// 职责：
/// - 实现 FeedbackAdapter 接口
/// - 根据对话模式生成反馈
/// - chat 模式：使用LLM生成智能闲聊回复
/// - chatWithIntent 模式：详细回答
/// - quickBookkeeping 模式：极简"✓ 2笔"
/// - mixed 模式：简短确认+操作反馈
class BookkeepingFeedbackAdapter implements FeedbackAdapter {
  final CasualChatService _casualChatService;

  /// 最近的用户输入（用于chat模式生成回复）
  String? _lastUserInput;

  BookkeepingFeedbackAdapter({
    CasualChatService? casualChatService,
  }) : _casualChatService = casualChatService ?? CasualChatService();

  /// 设置最近的用户输入
  void setLastUserInput(String input) {
    _lastUserInput = input;
  }

  @override
  String get adapterName => 'BookkeepingFeedbackAdapter';

  @override
  bool supportsMode(ConversationMode mode) {
    return true; // 支持所有模式
  }

  @override
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  ) async {
    debugPrint('[BookkeepingFeedbackAdapter] 生成反馈, 模式: $mode');

    switch (mode) {
      case ConversationMode.chat:
        return await _generateChatFeedback(chatContent);

      case ConversationMode.chatWithIntent:
        return _generateDetailedFeedback(results, chatContent);

      case ConversationMode.quickBookkeeping:
        return _generateQuickFeedback(results);

      case ConversationMode.mixed:
        return _generateMixedFeedback(results, chatContent);

      case ConversationMode.clarify:
        // clarify 模式由 IntelligenceEngine 直接处理，这里作为防御性编程
        return chatContent ?? '请问您具体想要做什么呢？';
    }
  }

  /// 生成 chat 模式反馈（使用LLM生成智能回复）
  Future<String> _generateChatFeedback(String? chatContent) async {
    debugPrint('[BookkeepingFeedbackAdapter] 生成chat模式反馈，输入: $_lastUserInput');

    // 如果没有用户输入，返回默认模板
    if (_lastUserInput == null || _lastUserInput!.isEmpty) {
      return '有什么可以帮您的吗？';
    }

    try {
      // 使用CasualChatService检测闲聊意图
      final chatResponse = await _casualChatService.handleCasualChat(
        userId: 'default',
        input: _lastUserInput!,
      );
      final chatIntent = chatResponse.intent.name;

      // 使用LLM生成回复
      final llmGenerator = LLMResponseGenerator.instance;
      final message = await llmGenerator.generateCasualChatResponse(
        userInput: _lastUserInput!,
        chatIntent: chatIntent,
      );

      debugPrint('[BookkeepingFeedbackAdapter] LLM闲聊回复: $message');
      return message;
    } catch (e) {
      debugPrint('[BookkeepingFeedbackAdapter] LLM闲聊失败: $e，使用模板回复');
      // LLM失败时降级到模板
      const templates = [
        '好的，有什么可以帮您的吗？',
        '明白了，需要记账吗？',
        '收到，随时为您服务',
      ];
      return templates[DateTime.now().millisecond % templates.length];
    }
  }

  /// 生成 chatWithIntent 模式反馈（详细回答）
  String _generateDetailedFeedback(
    List<ExecutionResult> results,
    String? chatContent,
  ) {
    if (results.isEmpty) {
      return '我会帮您查询相关信息';
    }

    // 检查是否有查询结果
    final queryResult = _findQueryResult(results);
    if (queryResult != null) {
      return _formatQueryResult(queryResult);
    }

    // 检查是否有导航结果
    final navResult = _findNavigationResult(results);
    if (navResult != null) {
      return _formatNavigationResult(navResult);
    }

    // 默认：记账操作反馈
    final successCount = results.where((r) => r.success).length;
    final failureCount = results.length - successCount;

    if (failureCount > 0) {
      return '已为您处理 $successCount 项操作，$failureCount 项失败，请检查后重试';
    }

    return '已为您成功处理 $successCount 项操作';
  }

  /// 生成 quickBookkeeping 模式反馈（极简"✓ 2笔"）
  String _generateQuickFeedback(List<ExecutionResult> results) {
    final successCount = results.where((r) => r.success).length;

    if (successCount == 0) {
      return '✗ 失败';
    }

    return '✓ $successCount笔';
  }

  /// 生成 mixed 模式反馈（简短确认+操作反馈）
  String _generateMixedFeedback(
    List<ExecutionResult> results,
    String? chatContent,
  ) {
    if (results.isEmpty) {
      return '操作失败，请重试';
    }

    // 检查是否有查询结果
    final queryResult = _findQueryResult(results);
    if (queryResult != null) {
      return _formatQueryResult(queryResult);
    }

    // 检查是否有导航结果
    final navResult = _findNavigationResult(results);
    if (navResult != null) {
      return _formatNavigationResult(navResult);
    }

    // 默认：记账操作反馈
    final successCount = results.where((r) => r.success).length;

    if (successCount == 0) {
      return '操作失败，请重试';
    }

    String base = '已记录 $successCount 笔';

    if (chatContent != null && chatContent.isNotEmpty) {
      // 简化对话内容
      final simplifiedChat = _simplifyChatContent(chatContent);
      if (simplifiedChat.isNotEmpty) {
        base += '，$simplifiedChat';
      }
    }

    return base;
  }

  /// 简化对话内容
  String _simplifyChatContent(String chatContent) {
    // 移除噪音词
    final cleaned = chatContent
        .replaceAll('顺便', '')
        .replaceAll('对了', '')
        .replaceAll('还有', '')
        .replaceAll('另外', '')
        .trim();

    // 限制长度
    if (cleaned.length > 20) {
      return '${cleaned.substring(0, 20)}...';
    }

    return cleaned;
  }

  /// 查找查询结果
  ExecutionResult? _findQueryResult(List<ExecutionResult> results) {
    for (final result in results) {
      if (result.success && result.data != null) {
        final data = result.data!;
        if (data.containsKey('queryType')) {
          return result;
        }
      }
    }
    return null;
  }

  /// 查找导航结果
  ExecutionResult? _findNavigationResult(List<ExecutionResult> results) {
    for (final result in results) {
      if (result.success && result.data != null) {
        final data = result.data!;
        if (data.containsKey('route') || data.containsKey('pageName')) {
          return result;
        }
      }
    }
    return null;
  }

  /// 格式化查询结果
  String _formatQueryResult(ExecutionResult result) {
    final data = result.data!;
    final queryType = data['queryType'] as String?;

    // 优先使用 responseText（由 BookkeepingOperationAdapter 生成的用户友好响应）
    final responseText = data['responseText'] as String?;
    if (responseText != null && responseText.isNotEmpty) {
      debugPrint('[BookkeepingFeedbackAdapter] 使用 responseText: $responseText');
      return responseText;
    }

    debugPrint('[BookkeepingFeedbackAdapter] 无 responseText，使用默认格式化，queryType=$queryType');

    switch (queryType) {
      case 'summary':
      case 'statistics':
        final totalExpense = data['totalExpense'] as num? ?? 0;
        final totalIncome = data['totalIncome'] as num? ?? 0;
        final count = data['transactionCount'] as int? ?? 0;
        final periodText = data['periodText'] as String? ?? '';

        if (count == 0) {
          return periodText.isNotEmpty
              ? '$periodText暂无记账记录'
              : '目前还没有记录任何交易';
        }

        final parts = <String>[];
        if (totalExpense > 0) {
          parts.add('支出 ${_formatAmount(totalExpense)} 元');
        }
        if (totalIncome > 0) {
          parts.add('收入 ${_formatAmount(totalIncome)} 元');
        }
        if (parts.isEmpty) {
          return periodText.isNotEmpty
              ? '$periodText共有 $count 笔交易记录'
              : '共有 $count 笔交易记录';
        }
        return periodText.isNotEmpty
            ? '$periodText${parts.join("，")}'
            : parts.join('，');

      case 'recent':
        final transactions = data['transactions'] as List?;
        final periodText = data['periodText'] as String? ?? '';
        if (transactions == null || transactions.isEmpty) {
          return periodText.isNotEmpty
              ? '$periodText暂无记录'
              : '最近没有交易记录';
        }
        return periodText.isNotEmpty
            ? '$periodText有 ${transactions.length} 笔交易'
            : '最近有 ${transactions.length} 笔交易';

      default:
        final count = data['transactionCount'] as int? ?? 0;
        final periodText = data['periodText'] as String? ?? '';
        return periodText.isNotEmpty
            ? '$periodText有 $count 笔交易记录'
            : '共有 $count 笔交易记录';
    }
  }

  /// 格式化导航结果
  String _formatNavigationResult(ExecutionResult result) {
    final data = result.data!;
    final pageName = data['pageName'] as String?;
    final targetPage = data['targetPage'] as String?;

    final displayName = pageName ?? targetPage ?? '目标页面';
    return '正在跳转到$displayName';
  }

  /// 格式化金额（移除不必要的小数位）
  String _formatAmount(num amount) {
    if (amount == amount.toInt()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}
