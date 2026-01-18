import 'package:flutter/foundation.dart';
import '../intelligence_engine/intelligence_engine.dart';
import '../intelligence_engine/models.dart';

/// 记账反馈适配器
///
/// 职责：
/// - 实现 FeedbackAdapter 接口
/// - 根据对话模式生成反馈
/// - chat 模式：简短2-3句
/// - chatWithIntent 模式：详细回答
/// - quickBookkeeping 模式：极简"✓ 2笔"
/// - mixed 模式：简短确认+操作反馈
class BookkeepingFeedbackAdapter implements FeedbackAdapter {
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
        return _generateChatFeedback(chatContent);

      case ConversationMode.chatWithIntent:
        return _generateDetailedFeedback(results, chatContent);

      case ConversationMode.quickBookkeeping:
        return _generateQuickFeedback(results);

      case ConversationMode.mixed:
        return _generateMixedFeedback(results, chatContent);
    }
  }

  /// 生成 chat 模式反馈（简短2-3句）
  String _generateChatFeedback(String? chatContent) {
    const templates = [
      '好的，有什么可以帮您的吗？',
      '明白了，需要记账吗？',
      '收到，随时为您服务',
    ];
    return templates[DateTime.now().millisecond % templates.length];
  }

  /// 生成 chatWithIntent 模式反馈（详细回答）
  String _generateDetailedFeedback(
    List<ExecutionResult> results,
    String? chatContent,
  ) {
    if (results.isEmpty) {
      return '我会帮您查询相关信息';
    }

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
}
