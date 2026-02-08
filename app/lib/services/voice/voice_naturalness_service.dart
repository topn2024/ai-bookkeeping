import 'dart:math';

/// 语音自然度服务
///
/// 职责：
/// - 管理响应变体，避免机械重复
/// - 添加拟声词和语气词
/// - 根据场景调整语气风格
class VoiceNaturalnessService {
  final Random _random = Random();

  /// 最近使用的响应索引，避免重复
  final Map<String, int> _lastUsedVariantIndex = {};

  // ==================== 响应变体 ====================

  /// 成功确认响应变体
  static const List<String> _successVariants = [
    '好的，记下了',
    '记好了',
    '收到',
    'OK，已记录',
    '好嘞，搞定了',
  ];

  /// 记账成功响应变体
  static const List<String> _bookkeepingSuccessVariants = [
    '记好啦！',
    '已经帮你记下了',
    '好的，记录完成',
    '搞定！',
    '记上了',
  ];

  /// 查询响应变体
  static const List<String> _queryVariants = [
    '让我看看...',
    '查一下...',
    '稍等，看看...',
    '好的，我查查...',
  ];

  /// 确认询问变体
  static const List<String> _confirmVariants = [
    '你是说',
    '确认一下，是',
    '我理解的是',
    '是这样吗：',
  ];

  /// 错误提示变体
  static const List<String> _errorVariants = [
    '抱歉，出了点问题',
    '哎呀，有点小状况',
    '不好意思，遇到了一些问题',
    '嗯...好像不太对',
  ];

  /// 没听清变体
  static const List<String> _unclearVariants = [
    '没听清，再说一次？',
    '刚才没听清楚，麻烦再说一遍？',
    '嗯？再说一次呗',
    '不好意思，没听清',
  ];

  /// 引导继续变体
  static const List<String> _continueVariants = [
    '还有其他要记的吗？',
    '还有吗？',
    '继续吧，我听着呢',
    '还有别的吗？',
  ];

  /// 结束语变体
  static const List<String> _goodbyeVariants = [
    '好的，有需要随时叫我',
    '拜拜～',
    '下次再聊',
    '好的，再见',
    '有事叫我哦',
  ];

  /// 问候语变体（根据时段）
  Map<String, List<String>> get _greetingVariants => {
        'morning': [
          '早上好！今天想记点什么？',
          '早！有什么需要帮忙的吗？',
          '早安～要记账吗？',
        ],
        'afternoon': [
          '下午好！有什么可以帮你？',
          '嗨～要记账吗？',
          '下午好，随时为你服务',
        ],
        'evening': [
          '晚上好！今天花了多少呀？',
          '晚上好～有什么要记的吗？',
          '嗨，晚上好！',
        ],
        'night': [
          '这么晚还在记账，辛苦啦',
          '夜深了，有什么要记的？',
          '晚安前来记一笔？',
        ],
      };

  // ==================== 公共API ====================

  /// 获取成功确认响应
  String getSuccessResponse() {
    return _getVariant('success', _successVariants);
  }

  /// 获取记账成功响应
  String getBookkeepingSuccessResponse({
    double? amount,
    String? category,
    bool isExpense = true,
  }) {
    final base = _getVariant('bookkeeping', _bookkeepingSuccessVariants);

    // 根据金额大小添加评价
    if (amount != null) {
      if (amount >= 1000) {
        return '$base 大手笔哦～';
      } else if (amount >= 500) {
        return '$base';
      } else if (amount <= 10) {
        return '$base 精打细算！';
      }
    }

    return base;
  }

  /// 获取查询响应
  String getQueryResponse() {
    return _getVariant('query', _queryVariants);
  }

  /// 获取确认询问响应
  String getConfirmResponse(String content) {
    final prefix = _getVariant('confirm', _confirmVariants);
    return '$prefix $content？';
  }

  /// 获取错误响应
  String getErrorResponse() {
    return _getVariant('error', _errorVariants);
  }

  /// 获取没听清响应
  String getUnclearResponse() {
    return _getVariant('unclear', _unclearVariants);
  }

  /// 获取引导继续响应
  String getContinueResponse() {
    return _getVariant('continue', _continueVariants);
  }

  /// 获取结束语响应
  String getGoodbyeResponse() {
    return _getVariant('goodbye', _goodbyeVariants);
  }

  /// 获取问候语响应
  String getGreetingResponse() {
    final timeOfDay = _getTimeOfDay();
    final variants = _greetingVariants[timeOfDay] ?? _greetingVariants['afternoon']!;
    return _getVariant('greeting_$timeOfDay', variants);
  }

  /// 添加自然语气
  ///
  /// 在响应前添加适当的语气词
  String addNaturalTone(String response, NaturalToneType type) {
    switch (type) {
      case NaturalToneType.thinking:
        final prefixes = ['嗯...', '让我想想...', ''];
        return '${prefixes[_random.nextInt(prefixes.length)]}$response';

      case NaturalToneType.agreeing:
        final prefixes = ['好的，', '嗯，', '行，', ''];
        return '${prefixes[_random.nextInt(prefixes.length)]}$response';

      case NaturalToneType.surprised:
        final prefixes = ['哇，', '哦？', ''];
        return '${prefixes[_random.nextInt(prefixes.length)]}$response';

      case NaturalToneType.sympathetic:
        final prefixes = ['理解，', '嗯嗯，', ''];
        return '${prefixes[_random.nextInt(prefixes.length)]}$response';

      case NaturalToneType.encouraging:
        final suffixes = ['', '加油！', '继续保持～'];
        return '$response${suffixes[_random.nextInt(suffixes.length)]}';

      case NaturalToneType.neutral:
        return response;
    }
  }

  /// 根据情感调整响应
  String adjustForEmotion(String response, EmotionalContext emotion) {
    switch (emotion) {
      case EmotionalContext.happy:
        // 添加积极语气
        if (!response.endsWith('！') && !response.endsWith('～')) {
          return '$response～';
        }
        return response;

      case EmotionalContext.concerned:
        // 添加关切语气
        return response.replaceAll('。', '。');

      case EmotionalContext.neutral:
        return response;

      case EmotionalContext.encouraging:
        // 添加鼓励语气
        final encouragements = ['不错！', '很好！', ''];
        return '${encouragements[_random.nextInt(encouragements.length)]}$response';
    }
  }

  // ==================== 内部方法 ====================

  /// 获取变体，避免重复
  String _getVariant(String key, List<String> variants) {
    if (variants.isEmpty) return '';
    if (variants.length == 1) return variants[0];

    final lastIndex = _lastUsedVariantIndex[key] ?? -1;

    // 生成不同于上次的随机索引
    int newIndex;
    do {
      newIndex = _random.nextInt(variants.length);
    } while (newIndex == lastIndex && variants.length > 1);

    _lastUsedVariantIndex[key] = newIndex;
    return variants[newIndex];
  }

  /// 获取当前时段
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 18) {
      return 'afternoon';
    } else if (hour >= 18 && hour < 22) {
      return 'evening';
    } else {
      return 'night';
    }
  }

  /// 清除历史记录
  void clearHistory() {
    _lastUsedVariantIndex.clear();
  }
}

/// 自然语气类型
enum NaturalToneType {
  /// 思考中
  thinking,

  /// 同意
  agreeing,

  /// 惊讶
  surprised,

  /// 同情/理解
  sympathetic,

  /// 鼓励
  encouraging,

  /// 中性
  neutral,
}

/// 情感上下文
enum EmotionalContext {
  /// 开心/积极
  happy,

  /// 关切
  concerned,

  /// 中性
  neutral,

  /// 鼓励
  encouraging,
}

/// TTS情感参数
class TTSEmotionParams {
  /// 语速（0.5-2.0，1.0为正常）
  final double speed;

  /// 音调（0.5-2.0，1.0为正常）
  final double pitch;

  /// 音量（0.0-1.0）
  final double volume;

  /// 情感类型
  final String? emotion;

  const TTSEmotionParams({
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.emotion,
  });

  /// 成功确认参数（轻快上扬）
  static const TTSEmotionParams success = TTSEmotionParams(
    speed: 1.1,
    pitch: 1.05,
    emotion: 'happy',
  );

  /// 错误提示参数（关切语气）
  static const TTSEmotionParams error = TTSEmotionParams(
    speed: 0.95,
    pitch: 0.98,
    emotion: 'concerned',
  );

  /// 询问确认参数（疑问语调）
  static const TTSEmotionParams questioning = TTSEmotionParams(
    speed: 1.0,
    pitch: 1.08,
    emotion: 'questioning',
  );

  /// 播报数字参数（清晰稳定）
  static const TTSEmotionParams informative = TTSEmotionParams(
    speed: 0.9,
    pitch: 1.0,
    emotion: 'neutral',
  );

  /// 闲聊参数（自然轻松）
  static const TTSEmotionParams casual = TTSEmotionParams(
    speed: 1.05,
    pitch: 1.02,
    emotion: 'friendly',
  );

  /// 根据响应类型获取参数
  static TTSEmotionParams fromResponseType(ResponseEmotionType type) {
    switch (type) {
      case ResponseEmotionType.success:
        return success;
      case ResponseEmotionType.error:
        return error;
      case ResponseEmotionType.questioning:
        return questioning;
      case ResponseEmotionType.informative:
        return informative;
      case ResponseEmotionType.casual:
        return casual;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'speed': speed,
      'pitch': pitch,
      'volume': volume,
      if (emotion != null) 'emotion': emotion,
    };
  }
}

/// 响应情感类型
enum ResponseEmotionType {
  /// 成功确认
  success,

  /// 错误提示
  error,

  /// 询问确认
  questioning,

  /// 信息播报
  informative,

  /// 闲聊
  casual,
}
