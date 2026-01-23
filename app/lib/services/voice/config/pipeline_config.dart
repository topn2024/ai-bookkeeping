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
    // 打断检测（优化：更快响应，参考chat-companion-app）
    this.bargeInLayer1MinChars = 4,
    this.bargeInLayer1Threshold = 0.5,  // 从0.4提高到0.5，更宽松
    this.bargeInLayer2MinChars = 8,
    this.bargeInLayer2Threshold = 0.4,  // 从0.3提高到0.4，更宽松
    this.bargeInCooldownMs = 1000,  // 从2000减少到1000，更快响应
    // 回声过滤（优化：更宽松，避免误杀用户输入）
    this.echoSimilarityThreshold = 0.7,  // 从0.6提高到0.7，更宽松
    this.echoMinTextLength = 2,  // 从3减少到2
    this.echoSilenceWindowMs = 800,  // 从1500减少到800，更短的静默窗口
    // 回声过滤动态阈值
    this.echoThresholdWithVAD = 0.9,  // 从0.8提高到0.9，VAD模式下几乎不过滤
    this.echoFilterCooldownMs = 200,  // 从500减少到200
    // 性能优化
    this.similarityThrottleMs = 50,  // 从100减少到50，更快检测
    this.enableComputeIsolate = false,
  });

  /// 默认配置
  static const defaultConfig = PipelineConfig();

  /// 低延迟配置（最快响应，适合网络好的场景）
  static const lowLatencyConfig = PipelineConfig(
    minSentenceLength: 2,
    bargeInLayer1MinChars: 3,
    bargeInLayer1Threshold: 0.6,
    bargeInCooldownMs: 500,
    echoSilenceWindowMs: 500,
    echoFilterCooldownMs: 100,
    similarityThrottleMs: 30,
  );

  /// 高准确性配置（减少误触发，适合嘈杂环境）
  static const highAccuracyConfig = PipelineConfig(
    minSentenceLength: 5,
    bargeInLayer1MinChars: 5,
    bargeInLayer1Threshold: 0.4,
    bargeInLayer2MinChars: 10,
    bargeInLayer2Threshold: 0.3,
    bargeInCooldownMs: 1500,
    echoSimilarityThreshold: 0.6,
    echoThresholdWithVAD: 0.8,
    echoMinTextLength: 3,
    echoSilenceWindowMs: 1200,
    echoFilterCooldownMs: 400,
  );

  /// 调试配置（最宽松，几乎不过滤）
  static const debugConfig = PipelineConfig(
    bargeInLayer1MinChars: 2,
    bargeInLayer1Threshold: 0.7,
    bargeInCooldownMs: 300,
    echoSimilarityThreshold: 0.8,
    echoThresholdWithVAD: 0.95,
    echoMinTextLength: 1,
    echoFilterCooldownMs: 100,
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
