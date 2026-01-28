/// 智能语音引擎配置类
///
/// 统一管理引擎相关的所有常量配置，避免硬编码分散在各处
class EngineConfig {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Deferred 操作相关配置
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Deferred 操作等待时间（毫秒）
  /// 延长到 2500ms 以收集连续记账（如"早餐15，午餐20"）
  static const int deferredWaitMs = 2500;

  /// Deferred 操作最大等待时间（毫秒）
  /// 即使用户持续输入，也会在此时间后强制执行
  static const int maxDeferredWaitMs = 10000;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 执行通道相关配置
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 操作聚合窗口时间（毫秒）
  /// 与 deferredWaitMs 保持一致
  static const int aggregationWindowMs = 2500;

  /// 队列容量限制
  static const int maxQueueSize = 10;

  /// 锁等待超时时间（秒）
  static const int lockTimeoutSeconds = 30;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 网络重试相关配置
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 初始重试延迟（毫秒）
  static const int initialRetryDelayMs = 100;

  /// 识别超时时间（秒）
  static const int recognitionTimeoutSeconds = 5;

  // 禁止实例化
  EngineConfig._();
}
