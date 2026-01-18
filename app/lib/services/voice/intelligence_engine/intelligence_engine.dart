import 'package:flutter/foundation.dart';
import 'models.dart';

/// 智能语音引擎
///
/// 核心架构：
/// - MultiOperationRecognizer: 多操作识别
/// - DualChannelProcessor: 双通道处理（执行+对话）
/// - IntelligentAggregator: 智能聚合
/// - AdaptiveConversationAgent: 自适应对话
/// - ProactiveConversationManager: 主动对话
class IntelligenceEngine {
  final OperationAdapter operationAdapter;
  final FeedbackAdapter feedbackAdapter;

  IntelligenceEngine({
    required this.operationAdapter,
    required this.feedbackAdapter,
  });

  /// 处理语音输入
  Future<VoiceSessionResult> process(String input) async {
    debugPrint('[IntelligenceEngine] 处理输入: $input');

    // TODO: 实现完整的处理流程
    // 1. MultiOperationRecognizer 识别
    // 2. DualChannelProcessor 分发
    // 3. 返回结果

    throw UnimplementedError('IntelligenceEngine.process() 尚未实现');
  }
}

/// 操作适配器接口
abstract class OperationAdapter {
  /// 执行操作
  Future<ExecutionResult> execute(Operation operation);

  /// 是否支持该操作类型
  bool canHandle(OperationType type);

  /// 适配器名称
  String get adapterName;
}

/// 反馈适配器接口
abstract class FeedbackAdapter {
  /// 生成反馈
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  );

  /// 是否支持该对话模式
  bool supportsMode(ConversationMode mode);

  /// 适配器名称
  String get adapterName;
}

/// 对话模式
enum ConversationMode {
  chat,              // 闲聊：简短2-3句
  chatWithIntent,    // 有诉求的闲聊：详细回答
  quickBookkeeping,  // 快速记账：极简"✓ 2笔"
  mixed,             // 混合：简短确认+操作反馈
}

/// 语音会话结果（临时占位，后续会完善）
class VoiceSessionResult {
  final bool success;
  final String? message;

  const VoiceSessionResult({
    required this.success,
    this.message,
  });
}
