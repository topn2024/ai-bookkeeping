/// 聊天引擎
///
/// 处理纯聊天对话，提供自然、有人格的响应
///
/// 核心职责：
/// - 自然语言聊天
/// - 维持助手人格一致性
/// - 适时引导到记账话题
/// - 主动关怀
library;

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../qwen_service.dart';

/// 助手人格配置
class PersonaConfig {
  /// 助手名称
  final String name;

  /// 角色定义
  final String role;

  /// 性格特点
  final List<String> traits;

  /// 说话风格
  final SpeechStyle speechStyle;

  const PersonaConfig({
    required this.name,
    required this.role,
    required this.traits,
    required this.speechStyle,
  });

  /// 默认人格配置
  factory PersonaConfig.defaultConfig() {
    return const PersonaConfig(
      name: '白记',
      role: '智能记账助手',
      traits: ['友好热情', '专业可靠', '适度幽默', '关心用户财务健康'],
      speechStyle: SpeechStyle.defaultStyle,
    );
  }
}

/// 说话风格配置
class SpeechStyle {
  /// 问候语风格
  final GreetingStyle greeting;

  /// 确认语风格
  final List<String> confirmations;

  /// 建议语风格
  final List<String> suggestionPrefixes;

  /// 错误响应风格
  final List<String> errorPrefixes;

  const SpeechStyle({
    required this.greeting,
    required this.confirmations,
    required this.suggestionPrefixes,
    required this.errorPrefixes,
  });

  static const SpeechStyle defaultStyle = SpeechStyle(
    greeting: GreetingStyle.defaultStyle,
    confirmations: ['好的', '嗯嗯', '没问题', '收到', '好~'],
    suggestionPrefixes: ['要不要', '建议', '可以考虑', '或许'],
    errorPrefixes: ['抱歉', '哎呀', '不好意思'],
  );
}

/// 问候语风格
class GreetingStyle {
  final List<String> morning;
  final List<String> noon;
  final List<String> afternoon;
  final List<String> evening;
  final List<String> night;

  const GreetingStyle({
    required this.morning,
    required this.noon,
    required this.afternoon,
    required this.evening,
    required this.night,
  });

  static const GreetingStyle defaultStyle = GreetingStyle(
    morning: ['早上好', '上午好', '早啊'],
    noon: ['中午好', '午安'],
    afternoon: ['下午好', '午后好'],
    evening: ['晚上好', '晚好'],
    night: ['夜深了', '这么晚还在记账呀'],
  );

  /// 获取当前时段的问候语
  String getGreeting() {
    final hour = DateTime.now().hour;
    final random = Random();

    List<String> greetings;
    if (hour >= 5 && hour < 12) {
      greetings = morning;
    } else if (hour >= 12 && hour < 14) {
      greetings = noon;
    } else if (hour >= 14 && hour < 18) {
      greetings = afternoon;
    } else if (hour >= 18 && hour < 22) {
      greetings = evening;
    } else {
      greetings = night;
    }

    return greetings[random.nextInt(greetings.length)];
  }
}

/// 聊天响应
class ChatResponse {
  /// 响应文本
  final String text;

  /// 是否应该语音输出
  final bool shouldSpeak;

  /// 是否包含引导到记账的内容
  final bool hasGuidance;

  /// 情感标签
  final String? emotion;

  const ChatResponse({
    required this.text,
    this.shouldSpeak = true,
    this.hasGuidance = false,
    this.emotion,
  });
}

/// 聊天引擎
class ChatEngine {
  final PersonaConfig _persona;
  final QwenService _qwenService;
  final Random _random = Random();

  /// 预设回复（离线模式使用）
  final Map<String, List<String>> _presetResponses = {
    'greeting': [
      '你好呀！有什么我能帮你的吗？',
      '嗨！今天想记点什么？',
      '你好！需要帮忙记账吗？',
    ],
    'thanks': [
      '不客气~',
      '随时为你服务！',
      '这是我应该做的！',
    ],
    'goodbye': [
      '再见！记得按时记账哦~',
      '拜拜！有需要随时找我~',
      '再见！祝你财务健康！',
    ],
    'unknown': [
      '嗯？没太明白，你是想记账还是查询呢？',
      '不好意思，我没理解，可以再说一次吗？',
      '抱歉没听懂，你可以试着说"记一笔..."',
    ],
    'encouragement': [
      '坚持记账是个好习惯！',
      '你已经连续记账好几天了，很棒！',
      '理财从记账开始，加油！',
    ],
  };

  ChatEngine({
    PersonaConfig? persona,
    QwenService? qwenService,
  })  : _persona = persona ?? PersonaConfig.defaultConfig(),
        _qwenService = qwenService ?? QwenService();

  /// 获取人格配置
  PersonaConfig get persona => _persona;

  /// LLM是否可用
  bool get isLLMAvailable => _qwenService.isAvailable;

  /// 处理聊天输入
  ///
  /// [input] 用户输入
  /// [context] 对话上下文摘要
  /// [emotion] 检测到的情感
  Future<ChatResponse> respond(
    String input, {
    String? context,
    String? emotion,
  }) async {
    final normalizedInput = input.toLowerCase();

    // 检测特殊意图类型（用于LLM提示词增强）
    final intentType = _detectIntentType(normalizedInput);

    // 如果LLM可用，使用LLM生成响应（包括问候、告别等）
    if (isLLMAvailable) {
      try {
        return await _generateLLMResponse(input, context, emotion, intentType: intentType);
      } catch (e) {
        debugPrint('[ChatEngine] LLM响应失败: $e，降级到预设响应');
        // 降级到预设响应
      }
    }

    // LLM不可用或失败，使用预设响应
    return _generatePresetResponseByIntent(input, emotion, intentType);
  }

  /// 检测意图类型
  String? _detectIntentType(String normalizedInput) {
    if (_isGreeting(normalizedInput)) return 'greeting';
    if (_isThanks(normalizedInput)) return 'thanks';
    if (_isGoodbye(normalizedInput)) return 'goodbye';
    return null;
  }

  /// 根据意图类型生成预设响应（降级方案）
  ChatResponse _generatePresetResponseByIntent(String input, String? emotion, String? intentType) {
    switch (intentType) {
      case 'greeting':
        final greeting = _persona.speechStyle.greeting.getGreeting();
        final responses = [
          '$greeting！有什么我能帮你的吗？',
          '$greeting！今天想记点什么？',
          '$greeting！',
        ];
        return ChatResponse(text: responses[_random.nextInt(responses.length)]);

      case 'thanks':
        return ChatResponse(
          text: _presetResponses['thanks']![_random.nextInt(_presetResponses['thanks']!.length)],
        );

      case 'goodbye':
        return ChatResponse(
          text: _presetResponses['goodbye']![_random.nextInt(_presetResponses['goodbye']!.length)],
        );

      default:
        return _generatePresetResponse(input, emotion);
    }
  }

  /// 使用LLM生成响应
  Future<ChatResponse> _generateLLMResponse(
    String input,
    String? context,
    String? emotion, {
    String? intentType,
  }) async {
    final prompt = _buildChatPrompt(input, context, emotion, intentType: intentType);
    final response = await _qwenService.chat(prompt);

    if (response == null || response.isEmpty) {
      throw Exception('LLM响应为空');
    }

    // 清理LLM响应（移除换行符和常见前缀）
    final cleanedResponse = _cleanLLMResponse(response);

    // 检测是否包含引导内容
    final hasGuidance = _containsGuidance(cleanedResponse);

    return ChatResponse(
      text: cleanedResponse,
      hasGuidance: hasGuidance,
      emotion: emotion,
    );
  }

  /// 清理LLM响应
  ///
  /// 移除换行符、多余空白和常见的LLM前缀，防止被TTS错误分割
  String _cleanLLMResponse(String response) {
    var cleaned = response.trim();

    // 移除换行符，用空格替换
    cleaned = cleaned.replaceAll('\n', ' ').replaceAll('\r', ' ');
    // 合并多个空格为一个
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // 移除常见的LLM前缀
    final prefixPatterns = [
      RegExp(r'^(好的|OK|ok)[\s,，:：]*'),
      RegExp(r'^让我(来)?[\s,，]*'),
      RegExp(r'^我来[\s,，]*'),
      RegExp(r'^(下面是|以下是)[\s,，:：]*'),
      RegExp(r'^回复[\s,，:：]*'),
      RegExp(r'^(白记说|${_persona.name}说)[\s,，:：]*'),
    ];
    for (final pattern in prefixPatterns) {
      cleaned = cleaned.replaceFirst(pattern, '');
    }

    return cleaned.trim();
  }

  /// 构建聊天提示词
  String _buildChatPrompt(String input, String? context, String? emotion, {String? intentType}) {
    final emotionHint = emotion != null ? '\n用户当前情绪: $emotion' : '';
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12 ? '上午' : (hour < 18 ? '下午' : '晚上');

    // 根据意图类型添加特殊指导
    String intentGuidance = '';
    switch (intentType) {
      case 'greeting':
        intentGuidance = '''
【特殊场景：用户打招呼】
- 这是对话的开始，用自然、热情的方式回应
- 根据时间段($timeOfDay)选择合适的问候
- 可以主动询问用户需要什么帮助
- 让回复有变化，不要每次都一样
- 示例风格：亲切、自然、有个性''';
        break;
      case 'thanks':
        intentGuidance = '''
【特殊场景：用户表示感谢】
- 用自然、谦虚的方式回应
- 可以表示随时乐意帮忙
- 让回复有变化，不要每次都说"不客气"
- 可以适当加一句关心的话''';
        break;
      case 'goodbye':
        intentGuidance = '''
【特殊场景：用户告别】
- 用温暖、自然的方式道别
- 可以表示期待下次见面
- 让回复有变化，不要每次都说"有需要随时叫我"
- 可以根据时间段给一句关心的话（如晚上提醒早点休息）''';
        break;
    }

    return '''你是"${_persona.name}"，一个${_persona.role}。
性格特点：${_persona.traits.join('、')}

说话风格要求：
- 日常对话简短自然，像朋友聊天，1-2句话为宜
- 如果用户要求讲故事、详细解释、多聊聊等，可以适当展开，3-5句话
- 不要使用emoji
- 如果话题与理财相关，可以适当引导到记账
- 保持一致的人格特点
- 根据用户情绪适当调整语气
- 【重要】让每次回复都有变化，避免重复同样的话
$intentGuidance
${context != null ? '对话背景：\n$context\n' : ''}$emotionHint

用户说：$input

请以"${_persona.name}"的身份自然回应（只输出回复内容，不要加任何前缀）：''';
  }

  /// 生成预设响应
  ChatResponse _generatePresetResponse(String input, String? emotion) {
    // 根据情感调整响应
    if (emotion == 'frustrated' || emotion == 'sad') {
      return ChatResponse(
        text: '有什么我能帮到你的吗？记账也是生活的一部分呢。',
        emotion: emotion,
      );
    }

    if (emotion == 'anxious') {
      return ChatResponse(
        text: '别着急，慢慢来。需要我帮你查查最近的消费吗？',
        emotion: emotion,
      );
    }

    // 默认响应
    return ChatResponse(
      text: _presetResponses['unknown']![_random.nextInt(_presetResponses['unknown']!.length)],
    );
  }

  /// 生成时段问候
  String generateTimeBasedGreeting() {
    return _persona.speechStyle.greeting.getGreeting();
  }

  /// 生成鼓励语
  String generateEncouragement() {
    return _presetResponses['encouragement']![_random.nextInt(_presetResponses['encouragement']!.length)];
  }

  /// 生成跟进建议
  String? generateFollowUp({
    double? amount,
    String? category,
  }) {
    // 大金额提醒
    if (amount != null && amount > 500) {
      return '这笔消费比平时大不少，要检查一下吗？';
    }

    // 根据时间生成跟进
    final hour = DateTime.now().hour;
    if ((hour >= 11 && hour <= 13) || (hour >= 18 && hour <= 20)) {
      if (category != '餐饮' && _random.nextDouble() < 0.3) {
        final meal = hour < 14 ? '午餐' : '晚餐';
        return '$meal记了吗？';
      }
    }

    // 随机跟进
    if (_random.nextDouble() < 0.2) {
      final variants = [
        '还有其他要记的吗？',
        '还有别的吗？',
      ];
      return variants[_random.nextInt(variants.length)];
    }

    return null;
  }

  /// 检测是否包含引导内容
  bool _containsGuidance(String text) {
    const guidanceKeywords = ['记账', '消费', '支出', '收入', '预算', '花了', '买了'];
    return guidanceKeywords.any((k) => text.contains(k));
  }

  /// 检测是否是问候
  bool _isGreeting(String input) {
    const greetings = ['你好', '嗨', 'hi', 'hello', '早上好', '下午好', '晚上好', '早', '嘿'];
    return greetings.any((g) => input.contains(g));
  }

  /// 检测是否是感谢
  bool _isThanks(String input) {
    const thanks = ['谢谢', '感谢', 'thanks', 'thank you', '多谢', '太好了'];
    return thanks.any((t) => input.contains(t));
  }

  /// 检测是否是告别
  bool _isGoodbye(String input) {
    const goodbyes = ['再见', '拜拜', 'bye', 'goodbye', '回见', '走了'];
    return goodbyes.any((g) => input.contains(g));
  }
}
