import 'dart:async';

/// 智能默认值类型
enum SmartDefaultType {
  /// 基于历史最频繁值
  mostFrequent,

  /// 基于最近使用值
  mostRecent,

  /// 基于时间段推荐（如午餐时段推荐餐饮）
  timeBasedRecommendation,

  /// 基于位置推荐
  locationBasedRecommendation,

  /// 基于机器学习预测
  mlPrediction,

  /// 基于规则引擎
  ruleEngine,

  /// 用户自定义默认值
  userDefined,
}

/// 默认值置信度
enum ConfidenceLevel {
  /// 高置信度 (≥80%)
  high,

  /// 中置信度 (50%-80%)
  medium,

  /// 低置信度 (<50%)
  low,
}

extension ConfidenceLevelExtension on ConfidenceLevel {
  double get minScore {
    switch (this) {
      case ConfidenceLevel.high:
        return 0.8;
      case ConfidenceLevel.medium:
        return 0.5;
      case ConfidenceLevel.low:
        return 0.0;
    }
  }

  String get displayName {
    switch (this) {
      case ConfidenceLevel.high:
        return '高置信度';
      case ConfidenceLevel.medium:
        return '中置信度';
      case ConfidenceLevel.low:
        return '低置信度';
    }
  }
}

/// 智能默认值结果
class SmartDefaultResult<T> {
  /// 推荐的默认值
  final T value;

  /// 默认值类型
  final SmartDefaultType type;

  /// 置信度分数 (0.0 - 1.0)
  final double confidence;

  /// 置信度等级
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.8) return ConfidenceLevel.high;
    if (confidence >= 0.5) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  /// 推荐理由
  final String? reason;

  /// 备选值列表
  final List<T>? alternatives;

  /// 元数据
  final Map<String, dynamic>? metadata;

  const SmartDefaultResult({
    required this.value,
    required this.type,
    required this.confidence,
    this.reason,
    this.alternatives,
    this.metadata,
  });

  /// 是否为高置信度
  bool get isHighConfidence => confidence >= 0.8;

  /// 是否应该静默应用（高置信度时自动应用）
  bool get shouldAutoApply => confidence >= 0.9;

  @override
  String toString() =>
      'SmartDefaultResult($value, type=$type, confidence=${(confidence * 100).toStringAsFixed(0)}%)';
}

/// 字段默认值配置
class FieldDefaultConfig {
  /// 字段名称
  final String fieldName;

  /// 是否启用智能默认
  final bool enableSmartDefault;

  /// 优先使用的默认值类型
  final List<SmartDefaultType> preferredTypes;

  /// 最小置信度要求
  final double minConfidence;

  /// 用户自定义默认值（如果有）
  final dynamic userDefault;

  /// 回退默认值
  final dynamic fallbackDefault;

  /// 是否在低置信度时显示提示
  final bool showHintOnLowConfidence;

  const FieldDefaultConfig({
    required this.fieldName,
    this.enableSmartDefault = true,
    this.preferredTypes = const [
      SmartDefaultType.mostRecent,
      SmartDefaultType.mostFrequent,
    ],
    this.minConfidence = 0.5,
    this.userDefault,
    this.fallbackDefault,
    this.showHintOnLowConfidence = true,
  });
}

/// 使用频率记录
class UsageFrequency<T> {
  final T value;
  int count;
  DateTime lastUsed;

  UsageFrequency({
    required this.value,
    this.count = 1,
    DateTime? lastUsed,
  }) : lastUsed = lastUsed ?? DateTime.now();

  void increment() {
    count++;
    lastUsed = DateTime.now();
  }
}

/// 智能默认值系统
///
/// 核心功能：
/// 1. 基于历史数据推荐默认值
/// 2. 支持多种推荐策略（最近、最频繁、时间段、位置）
/// 3. 置信度评估与显示
/// 4. 用户反馈学习
/// 5. 支持自定义规则
///
/// 对应设计文档：第3.4节 智能默认值系统
///
/// 使用示例：
/// ```dart
/// final service = SmartDefaultService();
///
/// // 获取分类默认值
/// final result = await service.getDefault<String>(
///   fieldName: 'category',
///   context: {'time': DateTime.now(), 'amount': 35.0},
/// );
///
/// if (result.isHighConfidence) {
///   // 自动应用
///   categoryField.value = result.value;
/// } else {
///   // 显示建议
///   showSuggestion(result);
/// }
/// ```
class SmartDefaultService {
  /// 使用频率缓存
  final Map<String, List<UsageFrequency<dynamic>>> _frequencyCache = {};

  /// 最近使用缓存
  final Map<String, List<dynamic>> _recentCache = {};

  /// 用户自定义默认值
  final Map<String, dynamic> _userDefaults = {};

  /// 字段配置
  final Map<String, FieldDefaultConfig> _fieldConfigs = {};

  /// 时间段规则
  final Map<String, Map<String, dynamic>> _timeBasedRules = {};

  /// 最大缓存历史数
  static const int maxHistorySize = 100;

  /// 最近使用缓存数
  static const int maxRecentSize = 10;

  SmartDefaultService() {
    _initDefaultRules();
  }

  /// 初始化默认规则
  void _initDefaultRules() {
    // 时间段 -> 分类推荐规则
    _timeBasedRules['category'] = {
      'morning': '早餐', // 6:00-9:00
      'lunch': '午餐', // 11:00-14:00
      'dinner': '晚餐', // 17:00-21:00
      'night': '夜宵', // 21:00-24:00
      'commute_morning': '交通', // 7:00-9:00
      'commute_evening': '交通', // 17:00-19:00
    };

    // 默认字段配置
    _fieldConfigs['category'] = const FieldDefaultConfig(
      fieldName: 'category',
      enableSmartDefault: true,
      preferredTypes: [
        SmartDefaultType.timeBasedRecommendation,
        SmartDefaultType.mostRecent,
        SmartDefaultType.mostFrequent,
      ],
      minConfidence: 0.6,
    );

    _fieldConfigs['account'] = const FieldDefaultConfig(
      fieldName: 'account',
      enableSmartDefault: true,
      preferredTypes: [
        SmartDefaultType.mostRecent,
        SmartDefaultType.mostFrequent,
      ],
      minConfidence: 0.7,
    );

    _fieldConfigs['amount'] = const FieldDefaultConfig(
      fieldName: 'amount',
      enableSmartDefault: false, // 金额通常不使用默认值
    );
  }

  /// 配置字段默认值策略
  void configureField(FieldDefaultConfig config) {
    _fieldConfigs[config.fieldName] = config;
  }

  /// 设置用户自定义默认值
  void setUserDefault(String fieldName, dynamic value) {
    _userDefaults[fieldName] = value;
  }

  /// 记录使用（用于学习）
  void recordUsage(String fieldName, dynamic value) {
    // 更新频率缓存
    _frequencyCache.putIfAbsent(fieldName, () => []);
    final freqList = _frequencyCache[fieldName]!;

    final existing = freqList.where((f) => f.value == value).toList();
    if (existing.isNotEmpty) {
      existing.first.increment();
    } else {
      freqList.add(UsageFrequency(value: value));
    }

    // 限制缓存大小
    if (freqList.length > maxHistorySize) {
      freqList.sort((a, b) => a.count.compareTo(b.count));
      freqList.removeAt(0);
    }

    // 更新最近使用缓存
    _recentCache.putIfAbsent(fieldName, () => []);
    final recentList = _recentCache[fieldName]!;
    recentList.remove(value);
    recentList.insert(0, value);

    if (recentList.length > maxRecentSize) {
      recentList.removeLast();
    }
  }

  /// 获取智能默认值
  Future<SmartDefaultResult<T>?> getDefault<T>({
    required String fieldName,
    Map<String, dynamic>? context,
  }) async {
    final config = _fieldConfigs[fieldName];

    // 如果禁用智能默认，返回null
    if (config != null && !config.enableSmartDefault) {
      if (config.userDefault != null) {
        return SmartDefaultResult<T>(
          value: config.userDefault as T,
          type: SmartDefaultType.userDefined,
          confidence: 1.0,
          reason: '用户自定义默认值',
        );
      }
      return null;
    }

    // 检查用户自定义默认值
    if (_userDefaults.containsKey(fieldName)) {
      return SmartDefaultResult<T>(
        value: _userDefaults[fieldName] as T,
        type: SmartDefaultType.userDefined,
        confidence: 1.0,
        reason: '您设置的默认值',
      );
    }

    // 按优先级尝试各种策略
    final preferredTypes =
        config?.preferredTypes ?? [SmartDefaultType.mostRecent, SmartDefaultType.mostFrequent];

    for (final type in preferredTypes) {
      final result = await _tryGetDefault<T>(fieldName, type, context);
      if (result != null && result.confidence >= (config?.minConfidence ?? 0.5)) {
        return result;
      }
    }

    // 返回回退默认值
    if (config?.fallbackDefault != null) {
      return SmartDefaultResult<T>(
        value: config!.fallbackDefault as T,
        type: SmartDefaultType.ruleEngine,
        confidence: 0.3,
        reason: '系统默认值',
      );
    }

    return null;
  }

  /// 尝试获取特定类型的默认值
  Future<SmartDefaultResult<T>?> _tryGetDefault<T>(
    String fieldName,
    SmartDefaultType type,
    Map<String, dynamic>? context,
  ) async {
    switch (type) {
      case SmartDefaultType.mostRecent:
        return _getMostRecent<T>(fieldName);

      case SmartDefaultType.mostFrequent:
        return _getMostFrequent<T>(fieldName);

      case SmartDefaultType.timeBasedRecommendation:
        return _getTimeBasedRecommendation<T>(fieldName, context);

      case SmartDefaultType.locationBasedRecommendation:
        return _getLocationBasedRecommendation<T>(fieldName, context);

      case SmartDefaultType.userDefined:
        if (_userDefaults.containsKey(fieldName)) {
          return SmartDefaultResult<T>(
            value: _userDefaults[fieldName] as T,
            type: SmartDefaultType.userDefined,
            confidence: 1.0,
          );
        }
        return null;

      default:
        return null;
    }
  }

  /// 获取最近使用的值
  SmartDefaultResult<T>? _getMostRecent<T>(String fieldName) {
    final recentList = _recentCache[fieldName];
    if (recentList == null || recentList.isEmpty) return null;

    final value = recentList.first as T;
    final confidence = 0.7 + (0.2 * (1 / (recentList.length)));

    return SmartDefaultResult<T>(
      value: value,
      type: SmartDefaultType.mostRecent,
      confidence: confidence.clamp(0.0, 1.0),
      reason: '您最近使用过',
      alternatives: recentList.length > 1 ? recentList.sublist(1).cast<T>() : null,
    );
  }

  /// 获取最频繁使用的值
  SmartDefaultResult<T>? _getMostFrequent<T>(String fieldName) {
    final freqList = _frequencyCache[fieldName];
    if (freqList == null || freqList.isEmpty) return null;

    // 按频率排序
    freqList.sort((a, b) => b.count.compareTo(a.count));
    final top = freqList.first;

    // 计算置信度（基于使用次数和总次数的比例）
    final totalCount = freqList.fold<int>(0, (sum, f) => sum + f.count);
    final confidence = (top.count / totalCount).clamp(0.3, 0.95);

    return SmartDefaultResult<T>(
      value: top.value as T,
      type: SmartDefaultType.mostFrequent,
      confidence: confidence,
      reason: '您常用的选项（使用${top.count}次）',
      alternatives:
          freqList.length > 1 ? freqList.sublist(1, min(4, freqList.length)).map((f) => f.value as T).toList() : null,
      metadata: {
        'usage_count': top.count,
        'total_count': totalCount,
      },
    );
  }

  /// 基于时间段的推荐
  SmartDefaultResult<T>? _getTimeBasedRecommendation<T>(
    String fieldName,
    Map<String, dynamic>? context,
  ) {
    final rules = _timeBasedRules[fieldName];
    if (rules == null) return null;

    final now = context?['time'] as DateTime? ?? DateTime.now();
    final hour = now.hour;

    String? timeSlot;
    double confidence = 0.6;

    // 判断时间段
    if (hour >= 6 && hour < 9) {
      timeSlot = 'morning';
      confidence = 0.7;
    } else if (hour >= 11 && hour < 14) {
      timeSlot = 'lunch';
      confidence = 0.8;
    } else if (hour >= 17 && hour < 21) {
      timeSlot = 'dinner';
      confidence = 0.75;
    } else if (hour >= 21 || hour < 2) {
      timeSlot = 'night';
      confidence = 0.65;
    }

    // 通勤时段特殊处理
    if ((hour >= 7 && hour < 9) || (hour >= 17 && hour < 19)) {
      final isWeekday = now.weekday >= 1 && now.weekday <= 5;
      if (isWeekday) {
        timeSlot = hour < 12 ? 'commute_morning' : 'commute_evening';
        confidence = 0.6;
      }
    }

    if (timeSlot == null || !rules.containsKey(timeSlot)) return null;

    return SmartDefaultResult<T>(
      value: rules[timeSlot] as T,
      type: SmartDefaultType.timeBasedRecommendation,
      confidence: confidence,
      reason: _getTimeSlotReason(timeSlot),
      metadata: {
        'time_slot': timeSlot,
        'hour': hour,
      },
    );
  }

  /// 获取时间段推荐理由
  String _getTimeSlotReason(String timeSlot) {
    switch (timeSlot) {
      case 'morning':
        return '早餐时间，通常是餐饮消费';
      case 'lunch':
        return '午餐时间，猜您在用餐';
      case 'dinner':
        return '晚餐时间，猜您在用餐';
      case 'night':
        return '夜间消费，可能是夜宵';
      case 'commute_morning':
      case 'commute_evening':
        return '通勤时段，可能是交通消费';
      default:
        return '基于时间推荐';
    }
  }

  /// 基于位置的推荐
  ///
  /// 需要位置服务集成后才能提供完整推荐。当前依赖调用方通过 context
  /// 传入 'locationCategory' (如 'restaurant', 'supermarket') 来提供基础推荐。
  SmartDefaultResult<T>? _getLocationBasedRecommendation<T>(
    String fieldName,
    Map<String, dynamic>? context,
  ) {
    final location = context?['location'];
    if (location == null) return null;

    // 如果调用方已通过 context 提供了 POI 分类信息，直接使用
    final locationCategory = context?['locationCategory'] as String?;
    if (locationCategory != null && fieldName == 'category') {
      const poiToCategoryMap = {
        'restaurant': '餐饮',
        'cafe': '餐饮',
        'supermarket': '购物',
        'mall': '购物',
        'hospital': '医疗',
        'pharmacy': '医疗',
        'gas_station': '交通',
        'parking': '交通',
        'gym': '运动',
        'cinema': '娱乐',
        'hotel': '住宿',
      };

      final category = poiToCategoryMap[locationCategory];
      if (category != null) {
        return SmartDefaultResult<T>(
          value: category as T,
          type: SmartDefaultType.locationBasedRecommendation,
          confidence: 0.65,
          reason: '根据您当前所在位置推荐',
          metadata: {
            'locationCategory': locationCategory,
          },
        );
      }
    }

    return null;
  }

  /// 清除历史数据
  void clearHistory(String? fieldName) {
    if (fieldName != null) {
      _frequencyCache.remove(fieldName);
      _recentCache.remove(fieldName);
    } else {
      _frequencyCache.clear();
      _recentCache.clear();
    }
  }

  /// 获取字段的使用统计
  Map<String, dynamic> getUsageStats(String fieldName) {
    final freqList = _frequencyCache[fieldName] ?? [];
    final recentList = _recentCache[fieldName] ?? [];

    return {
      'total_records': freqList.fold<int>(0, (sum, f) => sum + f.count),
      'unique_values': freqList.length,
      'recent_values': recentList.length,
      'top_values': freqList.take(5).map((f) => {'value': f.value, 'count': f.count}).toList(),
    };
  }
}

/// 辅助函数
int min(int a, int b) => a < b ? a : b;
