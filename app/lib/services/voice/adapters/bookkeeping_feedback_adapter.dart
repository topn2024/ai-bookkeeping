import 'package:flutter/foundation.dart';
import '../intelligence_engine/intelligence_engine.dart';
import '../intelligence_engine/models.dart';
import '../llm_response_generator.dart';
import '../../casual_chat_service.dart';
import '../../category_localization_service.dart';

/// 记账反馈适配器
///
/// 职责：
/// - 实现 FeedbackAdapter 接口
/// - 根据对话模式生成反馈
/// - 所有模式默认使用LLM生成自然语言回复
/// - LLM失败时降级到模板回复
class BookkeepingFeedbackAdapter implements FeedbackAdapter {
  final CasualChatService _casualChatService;
  final LLMResponseGenerator _llmGenerator = LLMResponseGenerator.instance;

  /// 最近的用户输入（用于生成回复）
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
        return await _generateDetailedFeedback(results, chatContent);

      case ConversationMode.quickBookkeeping:
        return await _generateQuickFeedback(results);

      case ConversationMode.mixed:
        return await _generateMixedFeedback(results, chatContent);

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
      final message = await _llmGenerator.generateCasualChatResponse(
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

  /// 生成 chatWithIntent 模式反馈（使用LLM生成详细回答）
  Future<String> _generateDetailedFeedback(
    List<ExecutionResult> results,
    String? chatContent,
  ) async {
    if (results.isEmpty) {
      return '我会帮您查询相关信息';
    }

    // 检查是否有查询结果
    final queryResult = _findQueryResult(results);
    if (queryResult != null) {
      return await _generateLLMQueryResponse(queryResult);
    }

    // 检查是否有导航结果
    final navResult = _findNavigationResult(results);
    if (navResult != null) {
      return await _generateLLMNavigationResponse(navResult);
    }

    // 默认：记账操作反馈
    return await _generateLLMTransactionResponse(results);
  }

  /// 生成 quickBookkeeping 模式反馈（使用LLM生成简洁回复）
  Future<String> _generateQuickFeedback(List<ExecutionResult> results) async {
    final successCount = results.where((r) => r.success).length;

    if (successCount == 0) {
      return '记账失败了，请再试一次';
    }

    // 使用LLM生成自然语言回复
    return await _generateLLMTransactionResponse(results, brief: true);
  }

  /// 生成 mixed 模式反馈（使用LLM生成混合回复）
  Future<String> _generateMixedFeedback(
    List<ExecutionResult> results,
    String? chatContent,
  ) async {
    if (results.isEmpty) {
      return '操作失败，请重试';
    }

    // 检查是否有查询结果
    final queryResult = _findQueryResult(results);
    if (queryResult != null) {
      return await _generateLLMQueryResponse(queryResult);
    }

    // 检查是否有导航结果
    final navResult = _findNavigationResult(results);
    if (navResult != null) {
      return await _generateLLMNavigationResponse(navResult);
    }

    // 默认：记账操作反馈
    return await _generateLLMTransactionResponse(results);
  }

  /// 使用LLM生成交易操作回复
  Future<String> _generateLLMTransactionResponse(
    List<ExecutionResult> results, {
    bool brief = false,
  }) async {
    final successResults = results.where((r) => r.success).toList();
    final failureCount = results.length - successResults.length;

    if (successResults.isEmpty) {
      return failureCount > 0 ? '记账失败了，请再试一次' : '没有需要处理的操作';
    }

    // 提取交易信息
    final transactions = <TransactionInfo>[];
    for (final result in successResults) {
      if (result.data != null) {
        final data = result.data!;
        transactions.add(TransactionInfo(
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          category: data['category'] as String? ?? '其他',
          description: data['note'] as String?,
          isIncome: data['type'] == 'income',
        ));
      }
    }

    // 如果没有提取到交易信息，使用通用回复
    if (transactions.isEmpty) {
      final count = successResults.length;
      return await _generateGenericOperationResponse(count, failureCount, brief);
    }

    try {
      // 使用LLM生成自然语言回复
      final response = await _llmGenerator.generateTransactionResponse(
        transactions: transactions,
        userInput: _lastUserInput ?? '',
      );

      // 如果有失败的操作，追加提示
      if (failureCount > 0) {
        return '$response，另外有$failureCount笔没记上';
      }

      return response;
    } catch (e) {
      debugPrint('[BookkeepingFeedbackAdapter] LLM交易回复失败: $e，使用模板');
      return _fallbackTransactionResponse(transactions, failureCount, brief);
    }
  }

  /// 使用LLM生成查询结果回复
  Future<String> _generateLLMQueryResponse(ExecutionResult result) async {
    final data = result.data!;

    // 优先使用 responseText（由 BookkeepingOperationAdapter 生成的用户友好响应）
    final responseText = data['responseText'] as String?;
    if (responseText != null && responseText.isNotEmpty) {
      // 对已有的响应文本进行LLM美化
      try {
        final beautified = await _llmGenerator.generateResponse(
          action: '查询',
          result: responseText,
          success: true,
          userInput: _lastUserInput,
        );
        return beautified;
      } catch (e) {
        debugPrint('[BookkeepingFeedbackAdapter] LLM美化失败: $e');
        return responseText;
      }
    }

    // 使用模板格式化
    return _formatQueryResult(result);
  }

  /// 使用LLM生成导航回复
  Future<String> _generateLLMNavigationResponse(ExecutionResult result) async {
    final data = result.data!;
    final pageName = data['pageName'] as String?;
    final targetPage = data['targetPage'] as String?;
    final displayName = pageName ?? targetPage ?? '目标页面';

    try {
      final response = await _llmGenerator.generateResponse(
        action: '导航',
        result: '跳转到$displayName',
        success: true,
        userInput: _lastUserInput,
      );
      return response;
    } catch (e) {
      debugPrint('[BookkeepingFeedbackAdapter] LLM导航回复失败: $e');
      return '好的，正在跳转到$displayName';
    }
  }

  /// 生成通用操作回复（LLM）
  Future<String> _generateGenericOperationResponse(
    int successCount,
    int failureCount,
    bool brief,
  ) async {
    final resultDesc = failureCount > 0
        ? '成功处理$successCount项，$failureCount项失败'
        : '成功处理$successCount项操作';

    try {
      final response = await _llmGenerator.generateResponse(
        action: '操作',
        result: resultDesc,
        success: failureCount == 0,
        userInput: _lastUserInput,
      );
      return response;
    } catch (e) {
      debugPrint('[BookkeepingFeedbackAdapter] LLM通用回复失败: $e');
      if (brief) {
        return failureCount > 0 ? '记了$successCount笔，$failureCount笔失败' : '记了$successCount笔';
      }
      return failureCount > 0
          ? '已为您处理$successCount项操作，$failureCount项失败'
          : '已为您成功处理$successCount项操作';
    }
  }

  /// 交易回复降级模板
  String _fallbackTransactionResponse(
    List<TransactionInfo> transactions,
    int failureCount,
    bool brief,
  ) {
    if (transactions.isEmpty) {
      return '操作完成';
    }

    if (brief) {
      // 简短模式
      final total = transactions.fold<double>(0, (sum, t) => sum + t.amount);
      if (transactions.length == 1) {
        final t = transactions.first;
        return '记了${t.category.localizedCategoryName}${t.amount.toStringAsFixed(0)}元';
      }
      return '记了${transactions.length}笔，共${total.toStringAsFixed(0)}元';
    }

    // 详细模式
    if (transactions.length == 1) {
      final t = transactions.first;
      final noteStr = t.description != null ? '，${t.description}' : '';
      return '好的，已记录${t.category.localizedCategoryName}${t.isIncome ? "收入" : "支出"}${t.amount.toStringAsFixed(0)}元$noteStr';
    }

    final expenseTotal = transactions
        .where((t) => !t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final incomeTotal = transactions
        .where((t) => t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final parts = <String>[];
    if (expenseTotal > 0) {
      parts.add('支出${expenseTotal.toStringAsFixed(0)}元');
    }
    if (incomeTotal > 0) {
      parts.add('收入${incomeTotal.toStringAsFixed(0)}元');
    }

    return '好的，已记录${transactions.length}笔，${parts.join("、")}';
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

  /// 格式化查询结果（降级模板）
  String _formatQueryResult(ExecutionResult result) {
    final data = result.data!;
    final queryType = data['queryType'] as String?;

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

  /// 格式化金额（移除不必要的小数位）
  String _formatAmount(num amount) {
    if (amount == amount.toInt()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}
