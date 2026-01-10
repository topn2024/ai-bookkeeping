import 'multi_intent_models.dart';

/// 噪音过滤器
///
/// 过滤语音输入中与记账/导航无关的内容，
/// 保留有效的意图片段。
class NoiseFilter {
  /// 过滤配置
  final NoiseFilterConfig config;

  NoiseFilter({this.config = const NoiseFilterConfig()});

  /// 动作动词列表（表示有效意图）
  static final _actionVerbs = [
    // 消费动作
    '花', '买', '吃', '喝', '打车', '坐车', '付', '给', '消费', '支出',
    // 收入动作
    '收', '赚', '收入', '进账', '到账',
    // 转账动作
    '转', '转账', '汇', '充值', '存', '取',
    // 导航动作
    '打开', '进入', '去', '跳转', '切换', '看看', '查看', '查询',
    // 记录动作
    '记', '记录', '记一笔', '加一笔', '添加',
  ];

  /// 纯状态描述模式（需要过滤）
  static final _statePatterns = [
    // 社交活动（无金额信息）
    RegExp(r'^(见了?|和|跟|陪).*(朋友|同事|人|客户|家人)'),
    // 纯地点到达（无消费）
    RegExp(r'^(去了?|到了?)[^花买吃喝付消费]+$'),
    // 纯状态描述
    RegExp(r'^(很|非常|特别|挺).*(开心|累|忙|好)'),
    // 闲聊内容
    RegExp(r'^(聊了?|说了?|谈了?).*(很久|一会|半天)'),
    // 纯时间表达（无动作）
    RegExp(r'^(今天|昨天|明天|上午|下午)$'),
  ];

  /// 高优先级关键词（即使短也保留）
  static final _highPriorityKeywords = [
    '元', '块', '块钱', '毛', '分',
    '打开', '查看', '看看',
    '确认', '取消', '是的', '对的', '不', '算了',
  ];

  /// 过滤分析结果列表
  ///
  /// 返回过滤后的结果和被过滤的噪音列表
  FilterResult filter(List<SegmentAnalysis> segments) {
    final validSegments = <SegmentAnalysis>[];
    final filteredNoise = <String>[];

    for (final segment in segments) {
      if (isNoise(segment)) {
        filteredNoise.add(segment.text);
      } else {
        validSegments.add(segment);
      }
    }

    return FilterResult(
      validSegments: validSegments,
      filteredNoise: filteredNoise,
    );
  }

  /// 判断片段是否为噪音
  bool isNoise(SegmentAnalysis segment) {
    final text = segment.text;

    // 1. 高优先级关键词直接保留
    if (_hasHighPriorityKeyword(text)) {
      return false;
    }

    // 2. 置信度低于阈值
    if (segment.confidence < config.confidenceThreshold) {
      return true;
    }

    // 3. 有金额的片段保留
    if (segment.amount != null) {
      return false;
    }

    // 4. 无动作动词
    if (!_hasActionVerb(text)) {
      return true;
    }

    // 5. 匹配纯状态描述模式
    if (_matchesStatePattern(text)) {
      return true;
    }

    // 6. 过短且无明确意图
    if (text.length < config.minTextLength && !_hasExplicitIntent(text)) {
      return true;
    }

    return false;
  }

  /// 简单判断文本是否为噪音（不需要完整分析结果）
  bool isNoiseText(String text, {double confidence = 1.0}) {
    // 创建临时分析结果进行判断
    final segment = SegmentAnalysis(
      text: text,
      entities: const [],
      isNoise: false,
      confidence: confidence,
    );
    return isNoise(segment);
  }

  /// 检查是否有高优先级关键词
  bool _hasHighPriorityKeyword(String text) {
    return _highPriorityKeywords.any((kw) => text.contains(kw));
  }

  /// 检查是否有动作动词
  bool _hasActionVerb(String text) {
    return _actionVerbs.any((verb) => text.contains(verb));
  }

  /// 检查是否匹配状态描述模式
  bool _matchesStatePattern(String text) {
    return _statePatterns.any((pattern) => pattern.hasMatch(text));
  }

  /// 检查是否有明确意图
  bool _hasExplicitIntent(String text) {
    // 有数字通常表示金额
    if (RegExp(r'\d').hasMatch(text)) {
      return true;
    }

    // 导航关键词
    final navKeywords = ['打开', '进入', '查看', '看看'];
    if (navKeywords.any((k) => text.contains(k))) {
      return true;
    }

    // 确认/取消意图
    final confirmKeywords = ['确认', '取消', '是', '不', '好的', '算了'];
    if (confirmKeywords.any((k) => text.contains(k))) {
      return true;
    }

    return false;
  }

  /// 计算片段的意图强度分数
  ///
  /// 用于在边界情况下辅助判断
  double calculateIntentScore(String text) {
    var score = 0.0;

    // 有金额表达 +0.5
    if (RegExp(r'\d+(\.\d+)?(元|块|毛|分)?').hasMatch(text)) {
      score += 0.5;
    }

    // 有动作动词 +0.3
    if (_hasActionVerb(text)) {
      score += 0.3;
    }

    // 有高优先级关键词 +0.2
    if (_hasHighPriorityKeyword(text)) {
      score += 0.2;
    }

    // 匹配状态模式 -0.3
    if (_matchesStatePattern(text)) {
      score -= 0.3;
    }

    // 过短 -0.2
    if (text.length < 5) {
      score -= 0.2;
    }

    return score.clamp(0.0, 1.0);
  }
}

/// 过滤结果
class FilterResult {
  /// 有效的片段
  final List<SegmentAnalysis> validSegments;

  /// 被过滤的噪音文本
  final List<String> filteredNoise;

  const FilterResult({
    required this.validSegments,
    required this.filteredNoise,
  });

  /// 有效片段数量
  int get validCount => validSegments.length;

  /// 噪音数量
  int get noiseCount => filteredNoise.length;

  /// 过滤率
  double get filterRate {
    final total = validCount + noiseCount;
    if (total == 0) return 0.0;
    return noiseCount / total;
  }
}

/// 噪音过滤配置
class NoiseFilterConfig {
  /// 置信度阈值（低于此值视为噪音）
  final double confidenceThreshold;

  /// 最小文本长度（低于此值需要有明确意图才保留）
  final int minTextLength;

  /// 是否启用状态模式过滤
  final bool enableStatePatternFilter;

  /// 是否启用动作动词检查
  final bool enableActionVerbCheck;

  const NoiseFilterConfig({
    this.confidenceThreshold = 0.3,
    this.minTextLength = 3,
    this.enableStatePatternFilter = true,
    this.enableActionVerbCheck = true,
  });
}
