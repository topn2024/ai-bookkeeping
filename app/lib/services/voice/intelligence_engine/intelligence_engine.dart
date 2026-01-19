import 'package:flutter/foundation.dart';
import 'models.dart';
import 'multi_operation_recognizer.dart';
import 'dual_channel_processor.dart';
import 'intelligent_aggregator.dart';
import 'adaptive_conversation_agent.dart';
import '../smart_intent_recognizer.dart' show MultiOperationResult;
import '../adapters/bookkeeping_feedback_adapter.dart';
import '../agent/hybrid_intent_router.dart' show NetworkStatus;

/// 智能语音引擎
///
/// 核心架构：
/// - MultiOperationRecognizer: 多操作识别
/// - DualChannelProcessor: 双通道处理（执行+对话）
/// - IntelligentAggregator: 智能聚合
/// - AdaptiveConversationAgent: 自适应对话
class IntelligenceEngine {
  final OperationAdapter operationAdapter;
  final FeedbackAdapter feedbackAdapter;

  late final MultiOperationRecognizer _recognizer;
  late final DualChannelProcessor _processor;
  late final IntelligentAggregator _aggregator;
  late final AdaptiveConversationAgent _conversationAgent;

  IntelligenceEngine({
    required this.operationAdapter,
    required this.feedbackAdapter,
  }) {
    _recognizer = MultiOperationRecognizer();
    _processor = DualChannelProcessor(
      executionChannel: ExecutionChannel(adapter: operationAdapter),
      conversationChannel: ConversationChannel(adapter: feedbackAdapter),
    );
    _aggregator = IntelligentAggregator(
      onTrigger: (operations) async {
        // 聚合触发回调
        debugPrint('[IntelligenceEngine] 聚合触发: ${operations.length}个操作');
      },
    );
    _conversationAgent = AdaptiveConversationAgent();
  }

  /// 设置网络状态提供者
  ///
  /// 用于SmartIntentRecognizer判断是否使用LLM
  void setNetworkStatusProvider(NetworkStatus? Function()? provider) {
    _recognizer.setNetworkStatusProvider(provider);
    debugPrint('[IntelligenceEngine] 网络状态提供者已${provider != null ? "设置" : "清除"}');
  }

  /// 处理语音输入
  ///
  /// 根据识别结果的四种类型分别处理：
  /// - operation: 执行操作 + 生成反馈
  /// - chat: 直接生成闲聊回复
  /// - clarify: 直接返回澄清问题
  /// - failed: 返回错误信息
  Future<VoiceSessionResult> process(String input) async {
    debugPrint('[IntelligenceEngine] 处理输入: $input');

    try {
      // 1. 多操作识别（5s超时，给LLM足够时间）
      final recognitionResult = await _recognizer.recognize(input).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[IntelligenceEngine] 识别超时，返回失败结果');
          return MultiOperationResult.error('识别超时');
        },
      );

      debugPrint('[IntelligenceEngine] 识别结果: resultType=${recognitionResult.resultType}, '
          'operations=${recognitionResult.operations.length}, '
          'isChat=${recognitionResult.isChat}, '
          'needsClarify=${recognitionResult.needsClarify}');

      // 2. 根据结果类型分别处理
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // 2.1 澄清模式：直接返回澄清问题
      if (recognitionResult.needsClarify) {
        final clarifyQuestion = recognitionResult.clarifyQuestion ?? '请问您具体想要做什么呢？';
        debugPrint('[IntelligenceEngine] 澄清模式: $clarifyQuestion');
        return VoiceSessionResult(
          success: true,
          message: clarifyQuestion,
        );
      }

      // 2.2 闲聊模式：生成闲聊回复
      if (recognitionResult.isChat) {
        debugPrint('[IntelligenceEngine] 闲聊模式');
        // 将用户输入传递给FeedbackAdapter
        if (feedbackAdapter is BookkeepingFeedbackAdapter) {
          (feedbackAdapter as BookkeepingFeedbackAdapter).setLastUserInput(input);
        }
        final responseText = await _processor.conversationChannel.generateResponse(ConversationMode.chat);
        debugPrint('[IntelligenceEngine] 闲聊回复: $responseText');
        return VoiceSessionResult(
          success: true,
          message: responseText,
        );
      }

      // 2.3 失败模式：返回错误信息
      if (!recognitionResult.isSuccess) {
        debugPrint('[IntelligenceEngine] 识别失败: ${recognitionResult.errorMessage}');
        return VoiceSessionResult(
          success: false,
          message: recognitionResult.errorMessage ?? '抱歉，我没有理解您的意思',
        );
      }

      // 2.4 操作模式：执行操作 + 生成反馈
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // 双通道处理
      await _processor.process(recognitionResult);

      // 生成对话响应
      final mode = _conversationAgent.detectMode(
        operations: recognitionResult.operations,
        chatContent: recognitionResult.chatContent,
        input: input,
      );
      debugPrint('[IntelligenceEngine] 对话模式: $mode');

      // 将用户输入传递给FeedbackAdapter（用于mixed模式）
      if (feedbackAdapter is BookkeepingFeedbackAdapter) {
        (feedbackAdapter as BookkeepingFeedbackAdapter).setLastUserInput(input);
      }

      final responseText = await _processor.conversationChannel.generateResponse(mode);

      debugPrint('[IntelligenceEngine] 处理完成: $responseText');

      return VoiceSessionResult(
        success: true,
        message: responseText,
      );
    } catch (e, stack) {
      debugPrint('[IntelligenceEngine] 处理失败: $e\n$stack');

      return VoiceSessionResult(
        success: false,
        message: '抱歉，处理您的请求时出现了问题',
      );
    }
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
  clarify,           // 澄清：反问用户获取更多信息
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
