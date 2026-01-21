/// 语音流水线模块
///
/// 提供流式TTS流水线、VAD打断检测等能力。
/// 回声消除由硬件级 AEC 在音频层处理。
///
/// 使用示例：
/// ```dart
/// final controller = VoicePipelineController(
///   asrEngine: asrEngine,
///   ttsService: ttsService,
///   vadService: vadService,
/// );
///
/// controller.onProcessInput = (userInput, onChunk, onComplete) async {
///   // 调用LLM生成响应
///   await llmService.generateResponse(
///     userInput,
///     onChunk: onChunk,
///     onComplete: onComplete,
///   );
/// };
///
/// await controller.start();
/// ```
library voice_pipeline;

// 配置
export 'config/pipeline_config.dart';

// 检测器
export 'detection/barge_in_detector_v2.dart';

// 追踪器
export 'tracking/response_tracker.dart';

// 流水线组件
export 'pipeline/sentence_buffer.dart';
export 'pipeline/tts_queue_worker.dart';
export 'pipeline/input_pipeline.dart';
export 'pipeline/output_pipeline.dart';
export 'pipeline/voice_pipeline_controller.dart';
