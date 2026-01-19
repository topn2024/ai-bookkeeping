/// 智能引擎数据模型
library;

/// 操作（已在 smart_intent_recognizer.dart 中定义，此处重新导出）
export '../smart_intent_recognizer.dart' show Operation, OperationType, OperationPriority;

/// LLM识别结果类型
///
/// 四种情况：
/// - operation: 有操作意图，需要执行
/// - chat: 闲聊/提问，无需操作
/// - clarify: 意图模糊，需要反问澄清
/// - failed: LLM不可用，需要规则兜底（离线场景）
enum RecognitionResultType {
  operation,  // 有操作
  chat,       // 闲聊（无需操作）
  clarify,    // 需要澄清
  failed,     // LLM不可用（离线）
}

/// 执行结果
class ExecutionResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;

  const ExecutionResult({
    required this.success,
    this.data,
    this.error,
  });

  factory ExecutionResult.success({Map<String, dynamic>? data}) {
    return ExecutionResult(success: true, data: data);
  }

  factory ExecutionResult.failure(String error) {
    return ExecutionResult(success: false, error: error);
  }

  factory ExecutionResult.unsupported() {
    return ExecutionResult(success: false, error: '不支持的操作类型');
  }

  @override
  String toString() {
    return 'ExecutionResult(success: $success, error: $error)';
  }
}

/// 对话上下文扩展
class ConversationContextExtension {
  final List<ExecutionResult> executionResults;
  final DateTime lastUpdateTime;

  ConversationContextExtension({
    required this.executionResults,
    required this.lastUpdateTime,
  });

  /// 添加执行结果
  ConversationContextExtension addExecutionResult(ExecutionResult result) {
    return ConversationContextExtension(
      executionResults: [...executionResults, result],
      lastUpdateTime: DateTime.now(),
    );
  }

  /// 获取最近的执行结果
  List<ExecutionResult> getRecentResults({int limit = 10}) {
    if (executionResults.length <= limit) {
      return executionResults;
    }
    return executionResults.sublist(executionResults.length - limit);
  }

  /// 清空执行结果
  ConversationContextExtension clear() {
    return ConversationContextExtension(
      executionResults: [],
      lastUpdateTime: DateTime.now(),
    );
  }
}
