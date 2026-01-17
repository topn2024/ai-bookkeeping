import 'package:flutter/foundation.dart';

/// 结束意图类型
enum EndIntentType {
  /// 显式结束（"好了"、"谢谢"等）
  explicit,

  /// 隐式结束（连续无响应）
  implicit,

  /// 超时结束
  timeout,
}

/// 结束检测结果
class EndDetectionResult {
  /// 是否检测到结束意图
  final bool shouldEnd;

  /// 结束意图类型
  final EndIntentType? type;

  /// 置信度
  final double confidence;

  /// 检测到的关键词（如果有）
  final String? keyword;

  /// 建议的结束语
  final String? suggestedResponse;

  const EndDetectionResult({
    required this.shouldEnd,
    this.type,
    this.confidence = 0.0,
    this.keyword,
    this.suggestedResponse,
  });

  factory EndDetectionResult.notEnd() => const EndDetectionResult(
        shouldEnd: false,
      );

  factory EndDetectionResult.explicitEnd({
    required String keyword,
    required double confidence,
    String? suggestedResponse,
  }) =>
      EndDetectionResult(
        shouldEnd: true,
        type: EndIntentType.explicit,
        confidence: confidence,
        keyword: keyword,
        suggestedResponse: suggestedResponse,
      );

  factory EndDetectionResult.implicitEnd({
    required double confidence,
    String? suggestedResponse,
  }) =>
      EndDetectionResult(
        shouldEnd: true,
        type: EndIntentType.implicit,
        confidence: confidence,
        suggestedResponse: suggestedResponse,
      );

  factory EndDetectionResult.timeoutEnd() => const EndDetectionResult(
        shouldEnd: true,
        type: EndIntentType.timeout,
        confidence: 1.0,
        suggestedResponse: '好的，有需要随时叫我～',
      );
}

/// 对话结束检测器
///
/// 检测用户结束对话的意图并提供优雅关闭
///
/// 检测方式：
/// - 显式结束: "好了"、"没了"、"谢谢"、"拜拜"等关键词
/// - 隐式结束: 连续两轮用户无响应
/// - 超时结束: 长时间无交互
class ConversationEndDetector {
  /// 配置
  final EndDetectorConfig config;

  /// 连续无响应轮次计数
  int _noResponseCount = 0;

  /// 最后交互时间
  DateTime? _lastInteractionTime;

  ConversationEndDetector({EndDetectorConfig? config})
      : config = config ?? const EndDetectorConfig();

  // ==================== 公共API ====================

  /// 连续无响应次数
  int get noResponseCount => _noResponseCount;

  /// 检测用户输入是否表示结束意图
  EndDetectionResult detectEndIntent(String userInput) {
    final normalizedInput = _normalizeInput(userInput);

    // 重置无响应计数（用户有输入）
    _noResponseCount = 0;
    _lastInteractionTime = DateTime.now();

    // 检测显式结束关键词
    for (final pattern in _endPatterns) {
      if (pattern.matches(normalizedInput)) {
        debugPrint('[EndDetector] 检测到显式结束: ${pattern.keyword}');
        return EndDetectionResult.explicitEnd(
          keyword: pattern.keyword,
          confidence: pattern.confidence,
          suggestedResponse: _getEndResponse(pattern.responseType),
        );
      }
    }

    return EndDetectionResult.notEnd();
  }

  /// 记录用户无响应
  ///
  /// 当用户在追问后没有响应时调用
  EndDetectionResult recordNoResponse() {
    _noResponseCount++;
    debugPrint('[EndDetector] 无响应计数: $_noResponseCount');

    if (_noResponseCount >= config.maxNoResponseRounds) {
      return EndDetectionResult.implicitEnd(
        confidence: 0.8,
        suggestedResponse: '好的，有需要随时叫我～',
      );
    }

    return EndDetectionResult.notEnd();
  }

  /// 检查是否超时
  EndDetectionResult checkTimeout() {
    if (_lastInteractionTime == null) {
      return EndDetectionResult.notEnd();
    }

    final elapsed = DateTime.now().difference(_lastInteractionTime!);
    if (elapsed > config.sessionTimeout) {
      debugPrint('[EndDetector] 会话超时');
      return EndDetectionResult.timeoutEnd();
    }

    return EndDetectionResult.notEnd();
  }

  /// 重置状态
  void reset() {
    _noResponseCount = 0;
    _lastInteractionTime = DateTime.now();
    debugPrint('[EndDetector] 状态已重置');
  }

  /// 标记用户有响应
  void markUserResponded() {
    _noResponseCount = 0;
    _lastInteractionTime = DateTime.now();
  }

  // ==================== 内部方法 ====================

  /// 标准化输入
  String _normalizeInput(String input) {
    return input.toLowerCase().trim();
  }

  /// 获取结束响应
  String _getEndResponse(EndResponseType type) {
    switch (type) {
      case EndResponseType.thanks:
        return _thanksResponses[DateTime.now().millisecond % _thanksResponses.length];
      case EndResponseType.bye:
        return _byeResponses[DateTime.now().millisecond % _byeResponses.length];
      case EndResponseType.done:
        return _doneResponses[DateTime.now().millisecond % _doneResponses.length];
      case EndResponseType.neutral:
        return '好的，有需要随时叫我～';
    }
  }

  /// 结束关键词模式
  static final List<EndPattern> _endPatterns = [
    // 感谢类
    EndPattern(keyword: '谢谢', confidence: 0.9, responseType: EndResponseType.thanks),
    EndPattern(keyword: '感谢', confidence: 0.9, responseType: EndResponseType.thanks),
    EndPattern(keyword: '多谢', confidence: 0.9, responseType: EndResponseType.thanks),
    EndPattern(keyword: '谢啦', confidence: 0.9, responseType: EndResponseType.thanks),

    // 告别类
    EndPattern(keyword: '拜拜', confidence: 0.95, responseType: EndResponseType.bye),
    EndPattern(keyword: '再见', confidence: 0.95, responseType: EndResponseType.bye),
    EndPattern(keyword: '拜', confidence: 0.8, responseType: EndResponseType.bye),
    EndPattern(keyword: '88', confidence: 0.8, responseType: EndResponseType.bye),
    EndPattern(keyword: 'bye', confidence: 0.8, responseType: EndResponseType.bye),

    // 完成类
    EndPattern(keyword: '好了', confidence: 0.85, responseType: EndResponseType.done),
    EndPattern(keyword: '没了', confidence: 0.9, responseType: EndResponseType.done),
    EndPattern(keyword: '没有了', confidence: 0.9, responseType: EndResponseType.done),
    EndPattern(keyword: '就这些', confidence: 0.85, responseType: EndResponseType.done),
    EndPattern(keyword: '就这样', confidence: 0.85, responseType: EndResponseType.done),
    EndPattern(keyword: '可以了', confidence: 0.85, responseType: EndResponseType.done),
    EndPattern(keyword: '行了', confidence: 0.8, responseType: EndResponseType.done),
    EndPattern(keyword: '够了', confidence: 0.8, responseType: EndResponseType.done),
    EndPattern(keyword: '完了', confidence: 0.8, responseType: EndResponseType.done),
    EndPattern(keyword: '结束', confidence: 0.9, responseType: EndResponseType.done),
  ];

  /// 感谢回复
  static const List<String> _thanksResponses = [
    '不客气～有需要随时叫我！',
    '应该的～随时为你服务！',
    '不用谢～',
  ];

  /// 告别回复
  static const List<String> _byeResponses = [
    '拜拜～',
    '下次见～',
    '再见，有需要随时叫我！',
  ];

  /// 完成回复
  static const List<String> _doneResponses = [
    '好的，有需要随时叫我～',
    '好的～',
    '收到，随时待命！',
  ];
}

/// 结束检测器配置
class EndDetectorConfig {
  /// 最大无响应轮次（超过则认为隐式结束）
  final int maxNoResponseRounds;

  /// 会话超时时间
  final Duration sessionTimeout;

  const EndDetectorConfig({
    this.maxNoResponseRounds = 2,
    this.sessionTimeout = const Duration(minutes: 5),
  });
}

/// 结束关键词模式
class EndPattern {
  final String keyword;
  final double confidence;
  final EndResponseType responseType;

  const EndPattern({
    required this.keyword,
    required this.confidence,
    required this.responseType,
  });

  bool matches(String input) {
    return input.contains(keyword);
  }
}

/// 结束响应类型
enum EndResponseType {
  thanks,
  bye,
  done,
  neutral,
}
