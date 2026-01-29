/// Managers
///
/// 导出所有 Manager 类，便于统一导入
///
/// Manager 架构（从 GlobalVoiceAssistantManager 提取）：
/// - AudioRecordingManager: 音频录制管理
/// - VADManager: 语音活动检测
/// - BargeInManager: 打断检测
/// - ConversationHistoryManager: 对话历史管理
/// - TTSManager: 文本转语音管理
/// - NetworkStatusManager: 网络状态监控
/// - PipelineManager: 语音处理流水线管理
library;

export 'audio_recording_manager.dart';
export 'vad_manager.dart';
export 'barge_in_manager.dart';
export 'conversation_history_manager.dart';
export 'tts_manager.dart';
export 'network_status_manager.dart';
export 'pipeline_manager.dart';
