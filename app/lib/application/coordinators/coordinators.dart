/// Coordinators
///
/// 导出所有协调器，便于统一导入
///
/// 协调器架构：
/// - VoiceRecognitionCoordinator: 语音识别生命周期管理
/// - IntentProcessingCoordinator: 意图分析和路由
/// - TransactionOperationCoordinator: 交易CRUD操作
/// - NavigationCoordinator: 页面导航
/// - ConversationCoordinator: 对话上下文管理
/// - FeedbackCoordinator: 语音/视觉反馈
library;

export 'voice_recognition_coordinator.dart';
export 'intent_processing_coordinator.dart';
export 'transaction_operation_coordinator.dart';
export 'navigation_coordinator.dart';
export 'conversation_coordinator.dart';
export 'feedback_coordinator.dart';
