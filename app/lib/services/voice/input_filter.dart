/// 输入预过滤器
///
/// 在意图识别前对用户输入进行快速分类（<10ms，纯规则）
/// 过滤无意义输入，减少不必要的 LLM 调用
///
/// 分类类型：
/// - noise: 语气词、填充词 → 静默忽略
/// - emotion: 情绪表达 → 情感关怀回复
/// - feedback: 用户反馈（确认/取消/犹豫/重复）→ 相应处理
/// - processable: 可处理内容 → 进入意图识别
library;

import 'package:flutter/foundation.dart';

/// 输入分类类型
enum InputCategory {
  /// 噪音：语气词、填充词（嗯、啊、那个...）
  noise,

  /// 情绪表达：重复字符、情感词（啊啊啊、呜呜呜、哈哈哈）
  emotion,

  /// 用户反馈：确认、取消、犹豫、重复请求
  feedback,

  /// 可处理内容：需要进入意图识别的输入
  processable,
}

/// 反馈类型
enum FeedbackType {
  /// 确认（好的、嗯嗯、可以、行）
  confirm,

  /// 取消（不要、算了、取消）
  cancel,

  /// 犹豫（等等、稍等、让我想想）
  hesitate,

  /// 重复请求（什么、啥、再说一遍）
  repeat,
}

/// 情绪类型
enum EmotionType {
  /// 正面情绪（哈哈哈、开心）
  positive,

  /// 负面情绪（呜呜呜、难过）
  negative,

  /// 惊讶（哇、天哪）
  surprise,

  /// 沮丧（啊啊啊、烦死了）
  frustration,
}

/// 输入过滤结果
class InputFilterResult {
  /// 分类类型
  final InputCategory category;

  /// 反馈类型（仅当 category == feedback 时有效）
  final FeedbackType? feedbackType;

  /// 情绪类型（仅当 category == emotion 时有效）
  final EmotionType? emotionType;

  /// 建议的回复（用于 emotion 和部分 feedback 场景）
  final String? suggestedResponse;

  /// 原始输入
  final String originalInput;

  const InputFilterResult({
    required this.category,
    this.feedbackType,
    this.emotionType,
    this.suggestedResponse,
    required this.originalInput,
  });

  /// 是否需要静默处理
  bool get shouldBeSilent => category == InputCategory.noise;

  /// 是否需要进入意图识别
  bool get shouldProcess => category == InputCategory.processable;

  @override
  String toString() {
    final parts = ['InputFilterResult(category: $category'];
    if (feedbackType != null) parts.add('feedbackType: $feedbackType');
    if (emotionType != null) parts.add('emotionType: $emotionType');
    if (suggestedResponse != null) parts.add('response: "$suggestedResponse"');
    parts.add('input: "$originalInput")');
    return parts.join(', ');
  }
}

/// 输入预过滤器
///
/// 使用纯规则实现，确保 <10ms 的响应时间
class InputFilter {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 噪音模式（语气词、填充词）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 纯语气词（完全匹配）
  static const _noiseExactPatterns = <String>{
    '嗯',
    '啊',
    '哦',
    '呃',
    '额',
    '噢',
    '唔',
    '嗷',
    '诶',
    '呀',
    '哎',
    '唉',
    '喂',
    '嘿',
    '咦',
    '嘛',
    '呢',
    '吧',
    '啦',
    '哇',
    '咳',
  };

  /// 填充词模式（前缀匹配）
  static const _noisePrefixPatterns = <String>[
    '那个',
    '这个',
    '就是',
    '然后',
    '所以',
    '嗯嗯嗯',
    '啊啊啊啊啊啊', // 超长的纯语气词也是噪音
  ];

  /// 填充词模式（完全匹配，带省略号）
  static const _noiseFillerPatterns = <String>{
    '那个...',
    '这个...',
    '就是...',
    '然后...',
    '嗯...',
    '啊...',
  };

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 反馈模式
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 确认模式
  static const _confirmPatterns = <String>{
    '好的',
    '好',
    '行',
    '可以',
    '没问题',
    '对',
    '是的',
    '确定',
    '确认',
    '嗯嗯',
    '嗯好',
    '好嘞',
    '行吧',
    '可以的',
    '好啊',
    '对的',
    'ok',
    'OK',
    '好滴',
    '收到',
  };

  /// 取消模式
  static const _cancelPatterns = <String>{
    '不要',
    '不用',
    '算了',
    '取消',
    '不了',
    '不',
    '别',
    '不行',
    '不可以',
    '停',
    '停止',
    '不对',
    '错了',
    '撤销',
    '删掉',
    '不要了',
    '算了吧',
  };

  /// 犹豫模式
  static const _hesitatePatterns = <String>{
    '等等',
    '稍等',
    '等一下',
    '让我想想',
    '我想想',
    '想一下',
    '考虑一下',
    '等会儿',
    '慢着',
    '先等等',
  };

  /// 重复请求模式
  static const _repeatPatterns = <String>{
    '什么',
    '啥',
    '再说一遍',
    '没听清',
    '听不清',
    '再说一次',
    '你说什么',
    '说啥',
    '没听到',
    '重复一下',
    '请重复',
  };

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 情绪模式
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 重复字符检测正则（同一字符重复3次以上）
  static final _repeatedCharPattern = RegExp(r'(.)\1{2,}');

  /// 正面情绪词
  static const _positiveEmotionWords = <String>{
    '哈哈',
    '嘻嘻',
    '呵呵',
    '开心',
    '高兴',
    '太好了',
    '太棒了',
    '耶',
    '赞',
  };

  /// 负面情绪词
  static const _negativeEmotionWords = <String>{
    '呜呜',
    '唉',
    '难过',
    '伤心',
    '郁闷',
    '烦',
    '累',
    '好累',
    '好烦',
  };

  /// 惊讶情绪词
  static const _surpriseEmotionWords = <String>{
    '哇',
    '天哪',
    '天啊',
    '我的天',
    '不会吧',
    '真的吗',
    '厉害',
  };

  /// 沮丧情绪词
  static const _frustrationEmotionWords = <String>{
    '烦死了',
    '气死了',
    '崩溃',
    '受不了',
    '无语',
    '服了',
    '醉了',
  };

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 情绪回复模板
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _emotionResponses = <EmotionType, List<String>>{
    EmotionType.positive: [
      '看起来心情不错呀',
      '心情很好的样子',
      '开心就好',
    ],
    EmotionType.negative: [
      '怎么了？',
      '有什么不开心的吗？',
      '发生什么事了？',
    ],
    EmotionType.surprise: [
      '是不是发现什么了？',
      '有什么新发现吗？',
    ],
    EmotionType.frustration: [
      '深呼吸，慢慢来',
      '别着急，我们一步步来',
      '有什么需要帮忙的吗？',
    ],
  };

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 核心过滤逻辑
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 过滤输入
  ///
  /// 按优先级检测：noise > feedback > emotion > processable
  InputFilterResult filter(String input) {
    final trimmed = input.trim();
    final normalized = _normalize(trimmed);

    debugPrint('[InputFilter] 处理输入: "$trimmed" (normalized: "$normalized")');

    // 1. 检测噪音（最优先，因为最常见且最简单）
    if (_isNoise(normalized, trimmed)) {
      debugPrint('[InputFilter] 分类: noise');
      return InputFilterResult(
        category: InputCategory.noise,
        originalInput: input,
      );
    }

    // 2. 检测反馈（用户确认/取消等优先于情绪）
    final feedbackResult = _detectFeedback(normalized);
    if (feedbackResult != null) {
      debugPrint('[InputFilter] 分类: feedback (${feedbackResult.$1})');
      return InputFilterResult(
        category: InputCategory.feedback,
        feedbackType: feedbackResult.$1,
        suggestedResponse: feedbackResult.$2,
        originalInput: input,
      );
    }

    // 3. 检测情绪
    final emotionResult = _detectEmotion(normalized, trimmed);
    if (emotionResult != null) {
      debugPrint('[InputFilter] 分类: emotion (${emotionResult.$1})');
      return InputFilterResult(
        category: InputCategory.emotion,
        emotionType: emotionResult.$1,
        suggestedResponse: emotionResult.$2,
        originalInput: input,
      );
    }

    // 4. 默认：可处理内容
    debugPrint('[InputFilter] 分类: processable');
    return InputFilterResult(
      category: InputCategory.processable,
      originalInput: input,
    );
  }

  /// 标准化输入（去除标点、转小写）
  String _normalize(String input) {
    return input
        // ignore: unnecessary_string_escapes
        .replaceAll(RegExp(r"[，。！？、；：""'',.!?;:\s]+"), '')
        .toLowerCase();
  }

  /// 检测是否为噪音
  bool _isNoise(String normalized, String original) {
    // 空输入
    if (normalized.isEmpty) return true;

    // 太短（1-2个字符的纯语气词）
    if (normalized.length <= 2 && _noiseExactPatterns.contains(normalized)) {
      return true;
    }

    // 完全匹配噪音模式
    if (_noiseExactPatterns.contains(normalized)) return true;
    if (_noiseFillerPatterns.contains(original)) return true;

    // 前缀匹配（短句填充词）
    for (final prefix in _noisePrefixPatterns) {
      if (normalized == prefix || (normalized.startsWith(prefix) && normalized.length <= prefix.length + 3)) {
        return true;
      }
    }

    // 纯重复语气词（如"嗯嗯嗯嗯"）
    if (_isRepeatedInterjection(normalized)) return true;

    return false;
  }

  /// 检测是否为重复语气词
  bool _isRepeatedInterjection(String input) {
    if (input.length < 2) return false;

    // 检查是否全是同一个语气词的重复
    final firstChar = input[0];
    if (_noiseExactPatterns.contains(firstChar)) {
      return input.split('').every((c) => c == firstChar);
    }

    return false;
  }

  /// 检测反馈类型
  (FeedbackType, String?)? _detectFeedback(String normalized) {
    // 确认
    if (_confirmPatterns.contains(normalized)) {
      return (FeedbackType.confirm, null);
    }

    // 取消
    if (_cancelPatterns.contains(normalized)) {
      return (FeedbackType.cancel, '好的，取消了');
    }

    // 犹豫
    if (_hesitatePatterns.contains(normalized)) {
      return (FeedbackType.hesitate, '好的，想好了告诉我');
    }

    // 重复请求
    if (_repeatPatterns.contains(normalized)) {
      return (FeedbackType.repeat, null); // 重复上一句，由调用方处理
    }

    return null;
  }

  /// 检测情绪类型
  (EmotionType, String)? _detectEmotion(String normalized, String original) {
    // 检测重复字符模式（如"啊啊啊啊啊"）
    if (_repeatedCharPattern.hasMatch(normalized)) {
      final match = _repeatedCharPattern.firstMatch(normalized)!;
      final repeatedChar = match.group(1)!;
      final repeatCount = match.group(0)!.length;

      // 只有重复3次以上才算情绪表达
      if (repeatCount >= 3) {
        // 根据重复的字符判断情绪
        if (['哈', '嘻', '呵'].contains(repeatedChar)) {
          return (EmotionType.positive, _getRandomResponse(EmotionType.positive));
        }
        if (['呜', '呵'].contains(repeatedChar)) {
          return (EmotionType.negative, _getRandomResponse(EmotionType.negative));
        }
        if (['啊', '呃'].contains(repeatedChar)) {
          return (EmotionType.frustration, _getRandomResponse(EmotionType.frustration));
        }
      }
    }

    // 检测情绪词
    for (final word in _positiveEmotionWords) {
      if (normalized.contains(word)) {
        return (EmotionType.positive, _getRandomResponse(EmotionType.positive));
      }
    }

    for (final word in _negativeEmotionWords) {
      if (normalized.contains(word)) {
        return (EmotionType.negative, _getRandomResponse(EmotionType.negative));
      }
    }

    for (final word in _surpriseEmotionWords) {
      if (normalized.contains(word)) {
        return (EmotionType.surprise, _getRandomResponse(EmotionType.surprise));
      }
    }

    for (final word in _frustrationEmotionWords) {
      if (normalized.contains(word)) {
        return (EmotionType.frustration, _getRandomResponse(EmotionType.frustration));
      }
    }

    return null;
  }

  /// 获取随机情绪回复
  String _getRandomResponse(EmotionType type) {
    final responses = _emotionResponses[type] ?? ['有什么需要帮忙的吗？'];
    // 简单起见，总是返回第一个（实际可以用随机）
    return responses.first;
  }
}
