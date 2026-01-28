import 'package:flutter/foundation.dart';
import '../smart_intent_recognizer.dart';
import '../network_monitor.dart' show NetworkStatus;

/// 多操作识别器
///
/// 职责：
/// - 调用 SmartIntentRecognizer.recognizeMultiOperation()
/// - 解析 operations 数组和 chat_content
/// - 分类操作优先级
/// - 过滤噪音内容
class MultiOperationRecognizer {
  final SmartIntentRecognizer _recognizer;

  MultiOperationRecognizer({
    SmartIntentRecognizer? recognizer,
  }) : _recognizer = recognizer ?? SmartIntentRecognizer();

  /// 设置网络状态提供者
  void setNetworkStatusProvider(NetworkStatus? Function()? provider) {
    _recognizer.networkStatusProvider = provider;
  }

  /// 识别多操作
  Future<MultiOperationResult> recognize(
    String input, {
    String? pageContext,
    List<Map<String, String>>? conversationHistory,
  }) async {
    debugPrint('[MultiOperationRecognizer] 识别输入: $input');

    // 调用 SmartIntentRecognizer 的多操作识别
    final result = await _recognizer.recognizeMultiOperation(
      input,
      pageContext: pageContext,
      conversationHistory: conversationHistory,
    );

    if (!result.isSuccess) {
      debugPrint('[MultiOperationRecognizer] 识别失败: ${result.errorMessage}');
      return result;
    }

    // 过滤噪音内容
    final filteredOperations = _filterNoiseOperations(result.operations);

    // 清理 chat_content 中的噪音
    final cleanedChatContent = _cleanChatContent(result.chatContent);

    debugPrint('[MultiOperationRecognizer] 识别成功: ${filteredOperations.length}个操作');

    return MultiOperationResult(
      resultType: result.resultType,
      operations: filteredOperations,
      chatContent: cleanedChatContent,
      clarifyQuestion: result.clarifyQuestion,
      confidence: result.confidence,
      source: result.source,
      originalInput: result.originalInput,
    );
  }

  /// 过滤噪音操作
  List<Operation> _filterNoiseOperations(List<Operation> operations) {
    return operations.where((op) {
      // 过滤未知类型的操作
      if (op.type == OperationType.unknown) {
        debugPrint('[MultiOperationRecognizer] 过滤未知操作: $op');
        return false;
      }

      // 过滤无效参数的操作
      if (op.type == OperationType.addTransaction) {
        final amount = op.params['amount'];
        if (amount == null || amount <= 0) {
          debugPrint('[MultiOperationRecognizer] 过滤无效金额操作: $op');
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// 清理对话内容中的噪音
  String? _cleanChatContent(String? chatContent) {
    if (chatContent == null || chatContent.trim().isEmpty) {
      return null;
    }

    // 移除常见的噪音词
    final noisePatterns = [
      '顺便',
      '对了',
      '还有',
      '另外',
      '然后',
    ];

    String cleaned = chatContent.trim();
    for (final pattern in noisePatterns) {
      cleaned = cleaned.replaceAll(pattern, '').trim();
    }

    // 如果清理后为空，返回 null
    if (cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}
