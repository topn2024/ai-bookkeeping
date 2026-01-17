/// 语音流水线配置
///
/// 集中管理所有可配置参数，便于调优和测试
class PipelineConfig {
  // ==================== 句子缓冲配置 ====================

  /// 句子分隔符
  final List<String> sentenceDelimiters;

  /// 最小句子长度（字符数）
  /// 短于此长度的句子会被合并到下一句
  final int minSentenceLength;

  /// 最大缓冲长度（字符数）
  /// 超过此长度强制输出，防止过长等待
  final int maxBufferLength;

  // ==================== TTS队列配置 ====================

  /// TTS队列最大长度
  /// 限制队列长度防止内存溢出
  final int maxTTSQueueSize;

  /// TTS预取数量
  /// 提前合成的句子数量
  final int ttsPrefetchCount;

  /// TTS合成超时（毫秒）
  final int ttsSynthesisTimeoutMs;

  // ==================== 打断检测配置 ====================

  /// 第1层打断：最小字符数
  final int bargeInLayer1MinChars;

  /// 第1层打断：相似度阈值（低于此值触发打断）
  final double bargeInLayer1Threshold;

  /// 第2层打断：最小字符数
  final int bargeInLayer2MinChars;

  /// 第2层打断：相似度阈值
  final double bargeInLayer2Threshold;

  /// 打断冷却时间（毫秒）
  /// 防止短时间内重复触发打断
  final int bargeInCooldownMs;

  // ==================== 回声过滤配置 ====================

  /// 回声相似度阈值（高于此值判定为回声）
  final double echoSimilarityThreshold;

  /// 回声过滤最小文本长度
  final int echoMinTextLength;

  /// TTS结束后的静默窗口（毫秒）
  final int echoSilenceWindowMs;

  /// VAD检测到语音时的回声阈值（更高，因为用户可能真的在说话）
  final double echoThresholdWithVAD;

  /// 回声过滤后的冷却时间（毫秒）
  /// 防止回声过滤后的短时间内重复触发打断
  final int echoFilterCooldownMs;

  // ==================== 性能优化配置 ====================

  /// 相似度计算节流间隔（毫秒）
  final int similarityThrottleMs;

  /// 是否启用CPU密集计算隔离
  final bool enableComputeIsolate;

  const PipelineConfig({
    // 句子缓冲
    this.sentenceDelimiters = const ['。', '！', '？', '；', '\n'],
    this.minSentenceLength = 4,
    this.maxBufferLength = 200,
    // TTS队列
    this.maxTTSQueueSize = 5,
    this.ttsPrefetchCount = 2,
    this.ttsSynthesisTimeoutMs = 15000,
    // 打断检测（参考chat-companion-app优化）
    this.bargeInLayer1MinChars = 4,
    this.bargeInLayer1Threshold = 0.4,
    this.bargeInLayer2MinChars = 8,
    this.bargeInLayer2Threshold = 0.3,
    this.bargeInCooldownMs = 2000,  // 从1500增加到2000，避免连续误触发
    // 回声过滤（参考chat-companion-app优化）
    this.echoSimilarityThreshold = 0.6,  // 从0.5提高到0.6，更严格的回声判定
    this.echoMinTextLength = 3,
    this.echoSilenceWindowMs = 1500,  // 从500增加到1500，与chat-companion-app一致
    // 回声过滤动态阈值
    this.echoThresholdWithVAD = 0.8,  // VAD检测到语音时，提高阈值（用户可能真的在说话）
    this.echoFilterCooldownMs = 500,  // 回声过滤后的冷却时间
    // 性能优化
    this.similarityThrottleMs = 100,
    this.enableComputeIsolate = false,
  });

  /// 默认配置
  static const defaultConfig = PipelineConfig();

  /// 低延迟配置（牺牲一些准确性换取更快响应）
  static const lowLatencyConfig = PipelineConfig(
    minSentenceLength: 3,
    bargeInLayer1MinChars: 3,
    bargeInLayer1Threshold: 0.5,
    bargeInCooldownMs: 1500,
    echoSilenceWindowMs: 800,
    echoFilterCooldownMs: 300,
    similarityThrottleMs: 50,
  );

  /// 高准确性配置（更严格的阈值，减少误触发）
  /// 参考chat-companion-app的参数优化
  static const highAccuracyConfig = PipelineConfig(
    minSentenceLength: 5,
    bargeInLayer1MinChars: 5,
    bargeInLayer1Threshold: 0.3,
    bargeInLayer2MinChars: 10,
    bargeInLayer2Threshold: 0.2,
    bargeInCooldownMs: 2500,
    echoSimilarityThreshold: 0.5,
    echoThresholdWithVAD: 0.85,
    echoMinTextLength: 4,
    echoSilenceWindowMs: 2000,
    echoFilterCooldownMs: 800,
  );

  /// 调试配置（更宽松的阈值，便于测试）
  static const debugConfig = PipelineConfig(
    bargeInLayer1MinChars: 2,
    bargeInLayer1Threshold: 0.6,
    bargeInCooldownMs: 500,
    echoSimilarityThreshold: 0.7,
    echoThresholdWithVAD: 0.9,
    echoMinTextLength: 2,
    echoFilterCooldownMs: 200,
  );

  /// 复制并修改配置
  PipelineConfig copyWith({
    List<String>? sentenceDelimiters,
    int? minSentenceLength,
    int? maxBufferLength,
    int? maxTTSQueueSize,
    int? ttsPrefetchCount,
    int? ttsSynthesisTimeoutMs,
    int? bargeInLayer1MinChars,
    double? bargeInLayer1Threshold,
    int? bargeInLayer2MinChars,
    double? bargeInLayer2Threshold,
    int? bargeInCooldownMs,
    double? echoSimilarityThreshold,
    int? echoMinTextLength,
    int? echoSilenceWindowMs,
    double? echoThresholdWithVAD,
    int? echoFilterCooldownMs,
    int? similarityThrottleMs,
    bool? enableComputeIsolate,
  }) {
    return PipelineConfig(
      sentenceDelimiters: sentenceDelimiters ?? this.sentenceDelimiters,
      minSentenceLength: minSentenceLength ?? this.minSentenceLength,
      maxBufferLength: maxBufferLength ?? this.maxBufferLength,
      maxTTSQueueSize: maxTTSQueueSize ?? this.maxTTSQueueSize,
      ttsPrefetchCount: ttsPrefetchCount ?? this.ttsPrefetchCount,
      ttsSynthesisTimeoutMs: ttsSynthesisTimeoutMs ?? this.ttsSynthesisTimeoutMs,
      bargeInLayer1MinChars: bargeInLayer1MinChars ?? this.bargeInLayer1MinChars,
      bargeInLayer1Threshold: bargeInLayer1Threshold ?? this.bargeInLayer1Threshold,
      bargeInLayer2MinChars: bargeInLayer2MinChars ?? this.bargeInLayer2MinChars,
      bargeInLayer2Threshold: bargeInLayer2Threshold ?? this.bargeInLayer2Threshold,
      bargeInCooldownMs: bargeInCooldownMs ?? this.bargeInCooldownMs,
      echoSimilarityThreshold: echoSimilarityThreshold ?? this.echoSimilarityThreshold,
      echoMinTextLength: echoMinTextLength ?? this.echoMinTextLength,
      echoSilenceWindowMs: echoSilenceWindowMs ?? this.echoSilenceWindowMs,
      echoThresholdWithVAD: echoThresholdWithVAD ?? this.echoThresholdWithVAD,
      echoFilterCooldownMs: echoFilterCooldownMs ?? this.echoFilterCooldownMs,
      similarityThrottleMs: similarityThrottleMs ?? this.similarityThrottleMs,
      enableComputeIsolate: enableComputeIsolate ?? this.enableComputeIsolate,
    );
  }
}
