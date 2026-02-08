import 'dart:math';
import 'package:flutter/foundation.dart';

/// 情绪化响应服务
///
/// 根据用户情绪和上下文调整语音响应的话术和语气
/// - 情绪检测：通过用户行为模式和输入内容判断情绪
/// - 话术适配：根据情绪选择合适的响应话术
/// - 语气调整：调整TTS参数实现情感化表达
class EmotionalResponseService {
  /// 当前检测到的用户情绪
  UserEmotion _currentEmotion = UserEmotion.neutral;

  /// 情绪历史（用于趋势分析）
  final List<EmotionRecord> _emotionHistory = [];

  /// 连续错误次数（用于检测困惑情绪）
  int _consecutiveErrors = 0;

  /// 连续成功次数（用于检测积极情绪）
  int _consecutiveSuccesses = 0;

  /// 随机数生成器（用于话术变化）
  final _random = Random();

  /// 获取当前用户情绪
  UserEmotion get currentEmotion => _currentEmotion;

  // ═══════════════════════════════════════════════════════════════
  // 情绪检测
  // ═══════════════════════════════════════════════════════════════

  /// 分析用户输入，更新情绪状态
  void analyzeUserInput(String input, {bool wasSuccessful = true}) {
    // 更新成功/失败计数
    if (wasSuccessful) {
      _consecutiveSuccesses++;
      _consecutiveErrors = 0;
    } else {
      _consecutiveErrors++;
      _consecutiveSuccesses = 0;
    }

    // 检测情绪关键词
    final emotion = _detectEmotionFromInput(input);

    // 综合判断情绪
    _currentEmotion = _determineOverallEmotion(emotion, wasSuccessful);

    // 记录情绪历史
    _emotionHistory.add(EmotionRecord(
      emotion: _currentEmotion,
      timestamp: DateTime.now(),
      trigger: input,
    ));

    // 保持历史在合理范围
    if (_emotionHistory.length > 50) {
      _emotionHistory.removeRange(0, _emotionHistory.length - 50);
    }

    debugPrint('[EmotionalResponse] 检测到情绪: $_currentEmotion');
  }

  /// 从输入文本检测情绪
  UserEmotion _detectEmotionFromInput(String input) {
    final normalizedInput = input.toLowerCase();

    // 消极情绪关键词
    const negativeKeywords = [
      '不对', '错了', '不是', '烦', '烦死了', '搞什么', '什么鬼',
      '怎么回事', '又错了', '不行', '不好用', '垃圾', '差劲',
    ];

    // 困惑情绪关键词
    const confusedKeywords = [
      '什么', '为什么', '怎么', '不明白', '不懂', '什么意思',
      '再说一遍', '没听懂', '搞不清', '迷糊',
    ];

    // 积极情绪关键词
    const positiveKeywords = [
      '太好了', '不错', '可以', '好的', '行', '棒', '厉害',
      '谢谢', '感谢', '辛苦了', '好厉害',
    ];

    // 急躁情绪关键词
    const impatientKeywords = [
      '快点', '赶紧', '快', '速度', '急', '等不及', '马上',
    ];

    // 检测各类情绪
    for (final keyword in negativeKeywords) {
      if (normalizedInput.contains(keyword)) {
        return UserEmotion.negative;
      }
    }

    for (final keyword in confusedKeywords) {
      if (normalizedInput.contains(keyword)) {
        return UserEmotion.confused;
      }
    }

    for (final keyword in positiveKeywords) {
      if (normalizedInput.contains(keyword)) {
        return UserEmotion.positive;
      }
    }

    for (final keyword in impatientKeywords) {
      if (normalizedInput.contains(keyword)) {
        return UserEmotion.impatient;
      }
    }

    return UserEmotion.neutral;
  }

  /// 综合判断整体情绪
  UserEmotion _determineOverallEmotion(UserEmotion detectedEmotion, bool wasSuccessful) {
    // 连续错误导致困惑/沮丧
    if (_consecutiveErrors >= 3) {
      return UserEmotion.confused;
    }

    if (_consecutiveErrors >= 5) {
      return UserEmotion.negative;
    }

    // 连续成功带来积极情绪
    if (_consecutiveSuccesses >= 3 && wasSuccessful) {
      return UserEmotion.positive;
    }

    // 使用检测到的情绪
    if (detectedEmotion != UserEmotion.neutral) {
      return detectedEmotion;
    }

    // 默认中性
    return UserEmotion.neutral;
  }

  // ═══════════════════════════════════════════════════════════════
  // 情绪化响应生成
  // ═══════════════════════════════════════════════════════════════

  /// 获取情绪化的响应文本
  ///
  /// [baseMessage] 原始消息
  /// [context] 上下文信息
  String getEmotionalResponse(String baseMessage, {ResponseContext? context}) {
    final style = _getResponseStyle(_currentEmotion);

    // 添加情绪化的开头
    String prefix = '';
    if (style.prefixes.isNotEmpty) {
      prefix = style.prefixes[_random.nextInt(style.prefixes.length)];
    }

    // 添加情绪化的结尾
    String suffix = '';
    if (style.suffixes.isNotEmpty && _random.nextDouble() > 0.5) {
      suffix = style.suffixes[_random.nextInt(style.suffixes.length)];
    }

    // 组合消息
    String result = baseMessage;
    if (prefix.isNotEmpty) {
      result = '$prefix$result';
    }
    if (suffix.isNotEmpty) {
      result = '$result$suffix';
    }

    return result;
  }

  /// 获取成功记账的情绪化响应
  String getSuccessResponse({required double amount, String? category}) {
    final variants = _successResponseVariants[_currentEmotion] ??
        _successResponseVariants[UserEmotion.neutral]!;

    final template = variants[_random.nextInt(variants.length)];

    return template
        .replaceAll('{amount}', amount.toStringAsFixed(2))
        .replaceAll('{category}', category ?? '');
  }

  /// 获取错误提示的情绪化响应
  String getErrorResponse(String errorType) {
    final variants = _errorResponseVariants[_currentEmotion] ??
        _errorResponseVariants[UserEmotion.neutral]!;

    final template = variants[_random.nextInt(variants.length)];

    return template.replaceAll('{error}', _getErrorDescription(errorType));
  }

  /// 获取引导提示的情绪化响应
  String getGuidanceResponse(String guidanceType) {
    final variants = _guidanceResponseVariants[_currentEmotion] ??
        _guidanceResponseVariants[UserEmotion.neutral]!;

    final template = variants[_random.nextInt(variants.length)];

    return template.replaceAll('{guide}', _getGuidanceContent(guidanceType));
  }

  // ═══════════════════════════════════════════════════════════════
  // TTS 参数调整
  // ═══════════════════════════════════════════════════════════════

  /// 获取情绪化的 TTS 参数
  TTSParameters getTTSParameters() {
    switch (_currentEmotion) {
      case UserEmotion.positive:
        return const TTSParameters(
          speechRate: 1.1,  // 稍快，轻快感
          pitch: 1.1,       // 稍高，上扬语调
          volume: 1.0,
        );

      case UserEmotion.negative:
        return const TTSParameters(
          speechRate: 0.9,  // 稍慢，关切感
          pitch: 0.95,      // 稍低，稳重感
          volume: 0.95,
        );

      case UserEmotion.confused:
        return const TTSParameters(
          speechRate: 0.85, // 较慢，清晰感
          pitch: 1.0,
          volume: 1.0,
        );

      case UserEmotion.impatient:
        return const TTSParameters(
          speechRate: 1.15, // 较快，高效感
          pitch: 1.0,
          volume: 1.0,
        );

      case UserEmotion.neutral:
        return const TTSParameters(
          speechRate: 1.0,
          pitch: 1.0,
          volume: 1.0,
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 响应风格配置
  // ═══════════════════════════════════════════════════════════════

  /// 获取响应风格
  ResponseStyle _getResponseStyle(UserEmotion emotion) {
    switch (emotion) {
      case UserEmotion.positive:
        return const ResponseStyle(
          prefixes: ['太棒了！', '真不错！', '好的呀，', ''],
          suffixes: ['继续保持！', '棒棒的！', ''],
          tone: 'cheerful',
        );

      case UserEmotion.negative:
        return const ResponseStyle(
          prefixes: ['理解您的心情，', '别着急，', '没关系，', ''],
          suffixes: ['我来帮您解决。', '让我来帮您。', ''],
          tone: 'caring',
        );

      case UserEmotion.confused:
        return const ResponseStyle(
          prefixes: ['让我来一步步引导您，', '别担心，', '我来详细解释一下，', ''],
          suffixes: ['如果还有疑问可以继续问我。', ''],
          tone: 'patient',
        );

      case UserEmotion.impatient:
        return const ResponseStyle(
          prefixes: ['好的，', '马上，', ''],
          suffixes: ['', ''],
          tone: 'efficient',
        );

      case UserEmotion.neutral:
        return const ResponseStyle(
          prefixes: ['好的，', '嗯，', ''],
          suffixes: ['', '还需要什么帮助吗？'],
          tone: 'normal',
        );
    }
  }

  /// 成功响应变体
  static const Map<UserEmotion, List<String>> _successResponseVariants = {
    UserEmotion.positive: [
      '太棒了！已记录{amount}元{category}',
      '好的呀，记好了！{category}{amount}元',
      '记录好了！{amount}元{category}，继续加油！',
    ],
    UserEmotion.negative: [
      '已帮您记录{amount}元{category}',
      '好的，{category}{amount}元已记好',
      '记录完成，{amount}元{category}',
    ],
    UserEmotion.confused: [
      '已经帮您记录好了：{category}{amount}元',
      '记录成功！这笔{category}消费{amount}元已保存',
      '好的，我已经帮您记录了{amount}元的{category}消费',
    ],
    UserEmotion.impatient: [
      '记好了，{amount}元',
      '已记录{category}{amount}元',
      '{amount}元{category}，完成',
    ],
    UserEmotion.neutral: [
      '已记录{category}消费{amount}元',
      '好的，{amount}元{category}已记好',
      '记录完成：{category}{amount}元',
    ],
  };

  /// 错误响应变体
  static const Map<UserEmotion, List<String>> _errorResponseVariants = {
    UserEmotion.positive: [
      '哎呀，{error}，再试一次吧',
      '小问题，{error}，换个方式试试',
    ],
    UserEmotion.negative: [
      '抱歉给您带来不便，{error}',
      '非常抱歉，{error}，我来帮您解决',
    ],
    UserEmotion.confused: [
      '没关系，{error}。让我来帮您，您可以这样说...',
      '{error}。别担心，我来一步步引导您',
    ],
    UserEmotion.impatient: [
      '{error}，请重试',
      '{error}',
    ],
    UserEmotion.neutral: [
      '抱歉，{error}',
      '{error}，请重试',
    ],
  };

  /// 引导响应变体
  static const Map<UserEmotion, List<String>> _guidanceResponseVariants = {
    UserEmotion.positive: [
      '好问题！{guide}',
      '当然可以！{guide}',
    ],
    UserEmotion.negative: [
      '我来帮您，{guide}',
      '别着急，{guide}',
    ],
    UserEmotion.confused: [
      '让我详细说明一下，{guide}',
      '一步一步来，首先{guide}',
    ],
    UserEmotion.impatient: [
      '{guide}',
      '简单说，{guide}',
    ],
    UserEmotion.neutral: [
      '{guide}',
      '好的，{guide}',
    ],
  };

  /// 获取错误描述
  String _getErrorDescription(String errorType) {
    const descriptions = {
      'not_understood': '我没有完全理解您的意思',
      'amount_missing': '请告诉我金额是多少',
      'network_error': '网络连接有点问题',
      'permission_denied': '需要您授权麦克风权限',
      'timeout': '响应超时了',
    };
    return descriptions[errorType] ?? '遇到了一些问题';
  }

  /// 获取引导内容
  String _getGuidanceContent(String guidanceType) {
    const contents = {
      'how_to_record': '您可以说"花了30块吃午餐"这样的话来记账',
      'how_to_query': '说"这个月花了多少"可以查看统计',
      'how_to_delete': '说"删掉上一笔"可以删除记录',
      'how_to_modify': '说"把上一笔改成50"可以修改金额',
    };
    return contents[guidanceType] ?? '有什么可以帮您的？';
  }

  // ═══════════════════════════════════════════════════════════════
  // 时段感知问候
  // ═══════════════════════════════════════════════════════════════

  /// 获取时段问候语
  String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 9) {
      return _morningGreetings[_random.nextInt(_morningGreetings.length)];
    } else if (hour >= 9 && hour < 12) {
      return _forenoonGreetings[_random.nextInt(_forenoonGreetings.length)];
    } else if (hour >= 12 && hour < 14) {
      return _noonGreetings[_random.nextInt(_noonGreetings.length)];
    } else if (hour >= 14 && hour < 18) {
      return _afternoonGreetings[_random.nextInt(_afternoonGreetings.length)];
    } else if (hour >= 18 && hour < 22) {
      return _eveningGreetings[_random.nextInt(_eveningGreetings.length)];
    } else {
      return _nightGreetings[_random.nextInt(_nightGreetings.length)];
    }
  }

  static const _morningGreetings = [
    '早上好！新的一天，记账从现在开始',
    '早安！今天也要好好记账哦',
    '早上好呀！准备好记录今天的消费了吗',
  ];

  static const _forenoonGreetings = [
    '上午好！有什么需要记录的吗',
    '您好！需要帮您记账吗',
  ];

  static const _noonGreetings = [
    '中午好！午餐花了多少要记录吗',
    '中午好！吃过饭了吗',
  ];

  static const _afternoonGreetings = [
    '下午好！需要我帮您做什么',
    '下午好！有什么可以帮您的',
  ];

  static const _eveningGreetings = [
    '晚上好！今天的消费都记录了吗',
    '晚上好！来看看今天花了多少吧',
  ];

  static const _nightGreetings = [
    '夜深了，有什么需要记录的吗',
    '这么晚还在记账，注意休息哦',
  ];

  /// 重置情绪状态
  void reset() {
    _currentEmotion = UserEmotion.neutral;
    _consecutiveErrors = 0;
    _consecutiveSuccesses = 0;
    _emotionHistory.clear();
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

/// 用户情绪类型
enum UserEmotion {
  positive,   // 积极/高兴
  negative,   // 消极/不满
  confused,   // 困惑
  impatient,  // 急躁
  neutral,    // 中性
}

/// 情绪记录
class EmotionRecord {
  final UserEmotion emotion;
  final DateTime timestamp;
  final String trigger;

  EmotionRecord({
    required this.emotion,
    required this.timestamp,
    required this.trigger,
  });
}

/// 响应风格
class ResponseStyle {
  final List<String> prefixes;
  final List<String> suffixes;
  final String tone;

  const ResponseStyle({
    required this.prefixes,
    required this.suffixes,
    required this.tone,
  });
}

/// 响应上下文
class ResponseContext {
  final String? operation;
  final bool? wasSuccessful;
  final Map<String, dynamic>? data;

  ResponseContext({
    this.operation,
    this.wasSuccessful,
    this.data,
  });
}

/// TTS 参数
class TTSParameters {
  final double speechRate;
  final double pitch;
  final double volume;

  const TTSParameters({
    required this.speechRate,
    required this.pitch,
    required this.volume,
  });
}
