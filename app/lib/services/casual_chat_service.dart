import 'dart:math';

import 'user_profile_service.dart';

/// 闲聊对话服务
///
/// 处理非记账场景的轻松对话，基于用户画像提供个性化回复
class CasualChatService {
  final UserProfileService? _profileService;
  final Random _random = Random();

  // 安全边界：不回复的话题
  static const _sensitiveTopic = [
    '政治',
    '宗教',
    '敏感',
    '争议',
    '投资建议',
    '理财产品',
    '股票推荐',
    '法律咨询',
    '医疗建议',
  ];

  CasualChatService({UserProfileService? profileService})
      : _profileService = profileService;

  /// 处理闲聊输入
  Future<CasualChatResponse> handleCasualChat({
    required String userId,
    required String input,
    CasualChatContext? context,
  }) async {
    // 1. 检测意图
    final intent = _detectChatIntent(input);

    // 2. 安全边界检查
    if (_containsSensitiveTopic(input)) {
      return CasualChatResponse(
        text: '这个话题我不太懂，不过记账的事找我准没错~',
        intent: CasualChatIntent.outOfScope,
        shouldContinue: true,
        suggestions: ['记一笔', '查看消费'],
      );
    }

    // 3. 获取用户画像（如果有profileService的话）
    UserProfile? profile;
    if (_profileService != null) {
      profile = await _profileService.getProfile(userId);
    }

    // 4. 生成回复
    return _generateResponse(intent, input, profile, context);
  }

  /// 检测闲聊意图
  CasualChatIntent _detectChatIntent(String input) {
    final lowerInput = input.toLowerCase();

    // 问候
    if (_matchesAny(lowerInput, ['你好', '早上好', '下午好', '晚上好', '在吗', 'hi', 'hello', '嗨'])) {
      return CasualChatIntent.greeting;
    }

    // 心情分享
    if (_matchesAny(lowerInput, ['开心', '高兴', '难过', '伤心', '累', '烦', '郁闷', '无聊'])) {
      return CasualChatIntent.moodSharing;
    }

    // 发工资
    if (_matchesAny(lowerInput, ['发工资', '发薪', '到账'])) {
      return CasualChatIntent.payday;
    }

    // 财务吐槽
    if (_matchesAny(lowerInput, ['没钱', '穷', '月光', '存不下钱', '花太多', '超支'])) {
      return CasualChatIntent.financialVenting;
    }

    // 寻求鼓励
    if (_matchesAny(lowerInput, ['是不是', '怎么办', '该不该', '有没有问题'])) {
      return CasualChatIntent.seekingEncouragement;
    }

    // 询问能力
    if (_matchesAny(lowerInput, ['你能', '你会', '可以', '你是谁', '你叫什么'])) {
      return CasualChatIntent.askingAbility;
    }

    // 感谢
    if (_matchesAny(lowerInput, ['谢谢', '感谢', '多谢', '谢啦'])) {
      return CasualChatIntent.thanks;
    }

    // 再见
    if (_matchesAny(lowerInput, ['再见', '拜拜', '88', '晚安', '下次见'])) {
      return CasualChatIntent.goodbye;
    }

    return CasualChatIntent.general;
  }

  bool _matchesAny(String input, List<String> patterns) {
    return patterns.any((p) => input.contains(p));
  }

  bool _containsSensitiveTopic(String input) {
    return _sensitiveTopic.any((topic) => input.contains(topic));
  }

  /// 生成回复
  CasualChatResponse _generateResponse(
    CasualChatIntent intent,
    String input,
    UserProfile? profile,
    CasualChatContext? context,
  ) {
    switch (intent) {
      case CasualChatIntent.greeting:
        return _handleGreeting(profile);

      case CasualChatIntent.moodSharing:
        return _handleMoodSharing(input, profile);

      case CasualChatIntent.payday:
        return _handlePayday(profile);

      case CasualChatIntent.financialVenting:
        return _handleFinancialVenting(input, profile);

      case CasualChatIntent.seekingEncouragement:
        return _handleSeekingEncouragement(input, profile);

      case CasualChatIntent.askingAbility:
        return _handleAskingAbility();

      case CasualChatIntent.thanks:
        return _handleThanks(profile);

      case CasualChatIntent.goodbye:
        return _handleGoodbye(profile);

      case CasualChatIntent.general:
      case CasualChatIntent.outOfScope:
        return _handleGeneral(profile);
    }
  }

  CasualChatResponse _handleGreeting(UserProfile? profile) {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour >= 5 && hour < 12) {
      timeGreeting = '早上好';
    } else if (hour >= 12 && hour < 18) {
      timeGreeting = '下午好';
    } else {
      timeGreeting = '晚上好';
    }

    final greetings = [
      '$timeGreeting！今天想记点什么呀？',
      '你好呀~有什么需要帮忙的吗？',
      '在呢在呢~准备好理财了吗？',
      '$timeGreeting！我是你的记账小助手~',
    ];

    return CasualChatResponse(
      text: greetings[_random.nextInt(greetings.length)],
      intent: CasualChatIntent.greeting,
      shouldContinue: true,
      suggestions: ['记一笔', '查看今日消费', '查看预算'],
    );
  }

  CasualChatResponse _handleMoodSharing(String input, UserProfile? profile) {
    final isPositive = _matchesAny(input, ['开心', '高兴', '棒', '好']);
    final isTired = _matchesAny(input, ['累', '辛苦', '疲惫']);

    if (isPositive) {
      final responses = [
        '开心就好！要不要记一笔庆祝消费？',
        '好心情要保持住哦~',
        '能感受到你的好心情！',
      ];
      return CasualChatResponse(
        text: responses[_random.nextInt(responses.length)],
        intent: CasualChatIntent.moodSharing,
        shouldContinue: true,
        suggestions: ['记一笔', '查看本月消费'],
      );
    }

    if (isTired) {
      return CasualChatResponse(
        text: '辛苦了~记账的事交给我，你休息一下',
        intent: CasualChatIntent.moodSharing,
        shouldContinue: true,
        suggestions: ['帮我记账', '查看消费'],
      );
    }

    // 负面情绪
    final responses = [
      '理解你的心情~需要聊聊吗？',
      '没事的，明天会更好',
      '有什么我可以帮忙的吗？',
    ];
    return CasualChatResponse(
      text: responses[_random.nextInt(responses.length)],
      intent: CasualChatIntent.moodSharing,
      shouldContinue: true,
      suggestions: ['看看我的财务状况', '设个小目标'],
    );
  }

  CasualChatResponse _handlePayday(UserProfile? profile) {
    final responses = [
      '恭喜发工资！要不要看看这个月的预算计划？',
      '发薪日快乐！是时候规划一下这笔钱的去处了~',
      '钱钱到账啦！先存一点再花哦~',
    ];

    return CasualChatResponse(
      text: responses[_random.nextInt(responses.length)],
      intent: CasualChatIntent.payday,
      shouldContinue: true,
      suggestions: ['设置本月预算', '查看储蓄目标', '记录收入'],
    );
  }

  CasualChatResponse _handleFinancialVenting(String input, UserProfile? profile) {
    // 基于画像调整回复
    final hasProfile = profile != null;
    final savingsRate = profile?.financialFeatures.savingsRate ?? 0;

    String response;
    List<String> suggestions;

    if (_matchesAny(input, ['月光', '存不下钱'])) {
      if (hasProfile && savingsRate > 10) {
        response = '其实你的储蓄率还不错的，${savingsRate.toStringAsFixed(0)}%呢！';
        suggestions = ['看看储蓄详情', '设个储蓄目标'];
      } else {
        response = '存钱确实不容易，要不要一起想想办法？';
        suggestions = ['分析消费习惯', '设置零钱目标'];
      }
    } else if (_matchesAny(input, ['花太多', '超支'])) {
      response = '理解你的心情~要看看钱都花哪了吗？';
      suggestions = ['查看消费分析', '设置预算提醒'];
    } else {
      response = '财务压力确实会让人焦虑，我们一步步来改善吧';
      suggestions = ['查看财务状况', '获取建议'];
    }

    return CasualChatResponse(
      text: response,
      intent: CasualChatIntent.financialVenting,
      shouldContinue: true,
      suggestions: suggestions,
    );
  }

  CasualChatResponse _handleSeekingEncouragement(String input, UserProfile? profile) {
    // 根据具体问题提供数据支持的回答
    if (_matchesAny(input, ['花太多'])) {
      final hasProfile = profile != null;
      if (hasProfile) {
        final monthlyAvg = profile.spendingBehavior.monthlyAverage;
        return CasualChatResponse(
          text: '让我看看...你月均消费¥${monthlyAvg.toStringAsFixed(0)}，在同龄人中算正常水平',
          intent: CasualChatIntent.seekingEncouragement,
          shouldContinue: true,
          suggestions: ['查看详细分析', '对比同龄人'],
        );
      }
    }

    return CasualChatResponse(
      text: '让我帮你分析分析，用数据说话~',
      intent: CasualChatIntent.seekingEncouragement,
      shouldContinue: true,
      suggestions: ['查看消费分析', '查看财务报告'],
    );
  }

  CasualChatResponse _handleAskingAbility() {
    final responses = [
      '我是你的记账小助手，可以帮你记账、查账、管预算、追目标~',
      '记账、查账、分析消费、设置预算...这些我都行！',
      '我专门负责帮你管理钱钱，有什么需要尽管说~',
    ];

    return CasualChatResponse(
      text: responses[_random.nextInt(responses.length)],
      intent: CasualChatIntent.askingAbility,
      shouldContinue: true,
      suggestions: ['记一笔', '查看消费', '设置预算'],
    );
  }

  CasualChatResponse _handleThanks(UserProfile? profile) {
    final responses = [
      '不客气~有需要随时找我',
      '应该的~继续加油理财哦',
      '能帮到你就好~',
    ];

    return CasualChatResponse(
      text: responses[_random.nextInt(responses.length)],
      intent: CasualChatIntent.thanks,
      shouldContinue: true,
      suggestions: ['继续记账', '查看报告'],
    );
  }

  CasualChatResponse _handleGoodbye(UserProfile? profile) {
    final hour = DateTime.now().hour;
    String farewell;

    if (hour >= 22 || hour < 5) {
      farewell = '晚安~明天继续记账哦';
    } else {
      farewell = '再见~记得常来记账呀';
    }

    return CasualChatResponse(
      text: farewell,
      intent: CasualChatIntent.goodbye,
      shouldContinue: false,
      suggestions: [],
    );
  }

  CasualChatResponse _handleGeneral(UserProfile? profile) {
    final todaySpending = profile?.spendingBehavior.monthlyAverage ?? 0;
    // ignore: unused_local_variable
    final dailyAvg = todaySpending / 30;

    final responses = [
      '这个我不太懂，但我知道你今天还没记账哦~',
      '这超出我的能力范围了...要记账吗？',
      '嗯...记账的事问我准没错！',
    ];

    return CasualChatResponse(
      text: responses[_random.nextInt(responses.length)],
      intent: CasualChatIntent.general,
      shouldContinue: true,
      suggestions: ['记一笔', '查看消费', '帮助'],
    );
  }

  /// 判断是否需要移交给LLM处理
  bool shouldEscalateToLLM(String input, CasualChatIntent intent) {
    // 复杂问题或无法识别的意图可以移交给LLM
    return intent == CasualChatIntent.general && input.length > 20;
  }
}

/// 闲聊意图
enum CasualChatIntent {
  greeting, // 问候
  moodSharing, // 心情分享
  payday, // 发工资
  financialVenting, // 财务吐槽
  seekingEncouragement, // 寻求鼓励
  askingAbility, // 询问能力
  thanks, // 感谢
  goodbye, // 再见
  general, // 一般闲聊
  outOfScope, // 超出范围
}

/// 闲聊上下文
class CasualChatContext {
  final List<String> recentMessages;
  final CasualChatIntent? lastIntent;
  final DateTime? lastInteractionTime;

  const CasualChatContext({
    this.recentMessages = const [],
    this.lastIntent,
    this.lastInteractionTime,
  });
}

/// 闲聊回复
class CasualChatResponse {
  final String text;
  final CasualChatIntent intent;
  final bool shouldContinue;
  final List<String> suggestions;
  final bool shouldEscalateToLLM;

  const CasualChatResponse({
    required this.text,
    required this.intent,
    required this.shouldContinue,
    required this.suggestions,
    this.shouldEscalateToLLM = false,
  });
}
