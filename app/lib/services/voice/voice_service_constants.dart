/// 语音服务统一常量配置
///
/// 集中管理语音相关服务的所有常量，便于统一维护和调整
class VoiceServiceConstants {
  VoiceServiceConstants._();

  // ==================== 缓存大小配置 ====================

  /// 消歧服务最近记录缓存数量
  static const int maxRecentRecords = 10;

  /// 修改服务历史记录缓存数量
  static const int maxModifyHistory = 50;

  /// 删除服务历史记录缓存数量
  static const int maxDeleteHistory = 100;

  // ==================== 时间段配置 ====================

  /// "刚才"的时间范围（小时）
  static const int recentHours = 3;

  /// 默认查询时间范围（天）
  static const int defaultQueryDays = 7;

  /// "上周"的时间范围（天）
  static const int lastWeekDays = 14;

  /// 最近记录判断阈值（小时）
  static const int recentRecordHours = 24;

  // ==================== 置信度阈值 ====================

  /// 消歧最低置信度阈值
  static const double disambiguationMinConfidence = 0.5;

  /// 消歧标准置信度阈值
  static const double disambiguationConfidenceThreshold = 0.7;

  /// 消歧高置信度阈值
  static const double disambiguationHighConfidence = 0.85;

  /// 意图识别置信度阈值
  static const double intentConfidenceThreshold = 0.7;

  // ==================== 金额阈值 ====================

  /// 大额交易阈值（元）
  static const double largeAmountThreshold = 500.0;

  /// 金额显著变化阈值（元）
  static const double significantAmountChange = 200.0;

  /// 金额变化比例阈值
  static const double amountChangeRatio = 0.5;

  // ==================== 输入限制 ====================

  /// 最大输入长度
  static const int maxInputLength = 10000;

  /// 最小有效输入长度
  static const int minInputLength = 2;

  // ==================== 延迟配置 ====================

  /// 延迟操作等待时间（毫秒）
  static const int deferredWaitMs = 2500;

  /// 延迟操作最大等待时间（毫秒）
  static const int maxDeferredWaitMs = 10000;

  /// 聚合窗口时间（毫秒）
  static const int aggregationWindowMs = 2500;

  // ==================== 重试配置 ====================

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 初始重试延迟（毫秒）
  static const int initialRetryDelayMs = 100;

  /// 识别超时时间（秒）
  static const int recognitionTimeoutSeconds = 5;
}
