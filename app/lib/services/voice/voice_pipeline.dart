/// 语音流水线模块
///
/// 提供流式TTS流水线、三层打断检测、四层回声防护等能力。
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
export 'detection/similarity_calculator.dart';
export 'detection/echo_filter.dart';
export 'detection/barge_in_detector_v2.dart';

// 追踪器
export 'tracking/response_tracker.dart';

// 流水线组件
export 'pipeline/sentence_buffer.dart';
export 'pipeline/tts_queue_worker.dart';
export 'pipeline/input_pipeline.dart';
export 'pipeline/output_pipeline.dart';
export 'pipeline/voice_pipeline_controller.dart';
