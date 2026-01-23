/// 智能引擎数据模型
library;

import '../smart_intent_recognizer.dart' show OperationType;

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

/// 单个操作的执行结果（带描述信息）
class OperationResultItem {
  final int index;
  final String description;
  final bool isSuccess;
  final String? errorMessage;
  final double? amount;
  final OperationType? operationType;

  const OperationResultItem({
    required this.index,
    required this.description,
    required this.isSuccess,
    this.errorMessage,
    this.amount,
    this.operationType,
  });

  @override
  String toString() {
    if (isSuccess) {
      return '$description';
    } else {
      return '$description(${errorMessage ?? "失败"})';
    }
  }
}

/// 操作执行报告
///
/// 聚合多个操作的执行结果，生成用户友好的反馈消息
class OperationExecutionReport {
  final List<OperationResultItem> results;

  OperationExecutionReport(this.results);

  /// 成功的操作数量
  int get successCount => results.where((r) => r.isSuccess).length;

  /// 失败的操作数量
  int get failureCount => results.where((r) => !r.isSuccess).length;

  /// 总操作数量
  int get totalCount => results.length;

  /// 是否全部成功
  bool get isAllSuccess => failureCount == 0 && totalCount > 0;

  /// 是否全部失败
  bool get isAllFailed => successCount == 0 && totalCount > 0;

  /// 是否部分成功
  bool get isPartialSuccess => successCount > 0 && failureCount > 0;

  /// 成功的操作列表
  List<OperationResultItem> get successItems =>
      results.where((r) => r.isSuccess).toList();

  /// 失败的操作列表
  List<OperationResultItem> get failedItems =>
      results.where((r) => !r.isSuccess).toList();

  /// 生成用户友好的反馈消息
  String toUserFriendlyMessage() {
    if (totalCount == 0) {
      return '没有需要处理的操作';
    }

    // 全部成功
    if (isAllSuccess) {
      if (totalCount == 1) {
        return '已记录${results.first.description}';
      } else {
        return '已记录${totalCount}笔';
      }
    }

    // 全部失败
    if (isAllFailed) {
      if (totalCount == 1) {
        final item = results.first;
        return '记录失败: ${item.errorMessage ?? "未知错误"}';
      } else {
        return '${totalCount}笔记录都失败了，请稍后重试';
      }
    }

    // 部分成功
    final successDescriptions = successItems.map((r) => r.description).join('、');
    final failedDescriptions = failedItems
        .map((r) => '${r.description}(${r.errorMessage ?? "失败"})')
        .join('、');

    return '已记录: $successDescriptions；失败: $failedDescriptions';
  }

  /// 生成简短的确认消息（用于快速反馈）
  String toQuickAcknowledgment() {
    if (isAllSuccess) {
      if (totalCount == 1) {
        return '好的';
      } else {
        return '好的，${totalCount}笔';
      }
    }

    if (isAllFailed) {
      return '抱歉，记录失败';
    }

    return '${successCount}笔成功，${failureCount}笔失败';
  }

  @override
  String toString() {
    return 'OperationExecutionReport(total: $totalCount, success: $successCount, failed: $failureCount)';
  }
}
