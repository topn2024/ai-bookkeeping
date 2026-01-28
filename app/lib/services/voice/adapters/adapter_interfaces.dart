/// 适配器接口定义
///
/// 定义引擎与外部系统交互的契约：
/// - OperationAdapter: 操作执行适配器
/// - FeedbackAdapter: 反馈生成适配器
library;

import '../intelligence_engine/models.dart';

/// 操作适配器接口
///
/// 负责将 Operation 转换为具体的业务操作执行
/// 不同的业务场景可以实现不同的适配器（如记账、任务管理等）
abstract class OperationAdapter {
  /// 执行操作
  ///
  /// [operation] 待执行的操作
  /// 返回执行结果
  Future<ExecutionResult> execute(Operation operation);

  /// 是否支持该操作类型
  ///
  /// [type] 操作类型
  /// 返回 true 表示支持，false 表示不支持
  bool canHandle(OperationType type);

  /// 适配器名称
  ///
  /// 用于日志和调试
  String get adapterName;
}

/// 反馈适配器接口
///
/// 负责根据对话模式和执行结果生成用户反馈
/// 不同的业务场景可以实现不同的反馈风格
abstract class FeedbackAdapter {
  /// 生成反馈
  ///
  /// [mode] 对话模式
  /// [results] 执行结果列表
  /// [chatContent] 闲聊内容（可选）
  /// 返回生成的反馈文本
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  );

  /// 是否支持该对话模式
  ///
  /// [mode] 对话模式
  /// 返回 true 表示支持，false 表示不支持
  bool supportsMode(ConversationMode mode);

  /// 适配器名称
  ///
  /// 用于日志和调试
  String get adapterName;
}

/// 对话模式
///
/// 定义不同场景下的对话风格
enum ConversationMode {
  /// 闲聊模式
  ///
  /// 默认1-2句，用户要求时可展开（讲故事等）
  chat,

  /// 有诉求的闲聊
  ///
  /// 用户有明确问题，需要详细回答
  chatWithIntent,

  /// 快速记账模式
  ///
  /// 极简反馈，如 "✓ 2笔"
  quickBookkeeping,

  /// 混合模式
  ///
  /// 简短确认 + 操作反馈
  mixed,

  /// 澄清模式
  ///
  /// 反问用户获取更多信息
  clarify,
}
