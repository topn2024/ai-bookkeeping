import 'dart:math';

import 'user_profile_service.dart';

/// 画像驱动对话服务
///
/// 基于用户画像生成个性化的对话回复
class ProfileDrivenDialogService {
  final UserProfileService _profileService;

  ProfileDrivenDialogService({required UserProfileService profileService})
      : _profileService = profileService;

  /// 生成个性化回复
  Future<PersonalizedResponse> generateResponse({
    required String userId,
    required String intent,
    required Map<String, dynamic> data,
  }) async {
    // 获取用户画像
    final profile = await _profileService.getProfile(userId);

    // 根据画像选择对话风格
    final style = _selectDialogStyle(profile);

    // 根据意图生成回复
    final response = _generateResponseByIntent(intent, data, profile, style);

    return PersonalizedResponse(
      text: response.text,
      tone: response.tone,
      shouldSpeak: response.shouldSpeak,
      suggestions: response.suggestions,
      style: style,
      profileUsed: profile != null,
    );
  }

  /// 选择对话风格
  DialogStyle _selectDialogStyle(UserProfile? profile) {
    if (profile == null) {
      return DialogStyle.neutral;
    }

    final personality = profile.personalityTraits.spendingPersonality;

    switch (personality) {
      case SpendingPersonality.frugalRational:
        return DialogStyle.professional;
      case SpendingPersonality.enjoymentOriented:
        return DialogStyle.playful;
      case SpendingPersonality.anxiousWorrier:
        return DialogStyle.supportive;
      case SpendingPersonality.goalDriven:
        return DialogStyle.dataFocused;
      case SpendingPersonality.casualBuddhist:
        return DialogStyle.casual;
    }
  }

  /// 根据意图生成回复
  _ResponseBuilder _generateResponseByIntent(
    String intent,
    Map<String, dynamic> data,
    UserProfile? profile,
    DialogStyle style,
  ) {
    switch (intent) {
      case 'query_spending':
        return _buildSpendingQueryResponse(data, profile, style);
      case 'query_budget':
        return _buildBudgetQueryResponse(data, profile, style);
      case 'record_expense':
        return _buildRecordExpenseResponse(data, profile, style);
      case 'query_goal':
        return _buildGoalQueryResponse(data, profile, style);
      case 'greeting':
        return _buildGreetingResponse(profile, style);
      default:
        return _buildDefaultResponse(style);
    }
  }

  /// 消费查询回复
  _ResponseBuilder _buildSpendingQueryResponse(
    Map<String, dynamic> data,
    UserProfile? profile,
    DialogStyle style,
  ) {
    final amount = data['amount'] as double? ?? 0;
    final period = data['period'] as String? ?? '本月';
    final comparison = data['comparison'] as double?; // 与上期相比的变化百分比

    String text;
    List<String> suggestions = [];

    switch (style) {
      case DialogStyle.professional:
        text = '$period总支出¥${amount.toStringAsFixed(0)}';
        if (comparison != null) {
          final change = comparison >= 0 ? '增长' : '下降';
          text += '，较上期$change${comparison.abs().toStringAsFixed(1)}%';
        }
        if (profile?.lifeStage.currentFocus != null) {
          text += '。按当前节奏，${profile!.lifeStage.currentFocus}指日可待';
        }
        suggestions = ['查看消费明细', '查看分类统计'];
        break;

      case DialogStyle.playful:
        text = '$period花了¥${amount.toStringAsFixed(0)}';
        if (comparison != null && comparison < 0) {
          text += '，比上期省了${comparison.abs().toStringAsFixed(0)}%，厉害了！';
        } else if (comparison != null && comparison > 10) {
          text += '，钱包君表示压力有点大~';
        }
        suggestions = ['看看都买了啥', '给我打打气'];
        break;

      case DialogStyle.supportive:
        text = '$period支出是¥${amount.toStringAsFixed(0)}';
        if (comparison != null && comparison > 0) {
          text += '，稍微超了一点点，不过没关系，整体还在可控范围内';
        } else {
          text += '，控制得很好，继续保持';
        }
        suggestions = ['帮我分析下', '有什么建议'];
        break;

      case DialogStyle.dataFocused:
        text = '$period消费¥${amount.toStringAsFixed(0)}';
        if (comparison != null) {
          text += '，环比${comparison >= 0 ? '+' : ''}${comparison.toStringAsFixed(1)}%';
        }
        final dailyAvg = amount / 30;
        text += '，日均¥${dailyAvg.toStringAsFixed(0)}';
        suggestions = ['查看趋势图', '对比预算'];
        break;

      case DialogStyle.casual:
        text = '$period花了${amount.toStringAsFixed(0)}块';
        suggestions = ['还行吧', '了解更多'];
        break;

      case DialogStyle.neutral:
        text = '$period支出¥${amount.toStringAsFixed(0)}';
        suggestions = ['查看详情'];
        break;
    }

    return _ResponseBuilder(
      text: text,
      tone: _getTone(style),
      shouldSpeak: true,
      suggestions: suggestions,
    );
  }

  /// 预算查询回复
  _ResponseBuilder _buildBudgetQueryResponse(
    Map<String, dynamic> data,
    UserProfile? profile,
    DialogStyle style,
  ) {
    final budgetTotal = data['budget_total'] as double? ?? 0;
    final spent = data['spent'] as double? ?? 0;
    final remaining = budgetTotal - spent;
    final usageRate = budgetTotal > 0 ? spent / budgetTotal : 0;
    final daysRemaining = data['days_remaining'] as int? ?? 15;

    String text;
    List<String> suggestions = [];

    if (usageRate > 1) {
      // 超支情况
      switch (style) {
        case DialogStyle.professional:
          text = '预算已超支¥${(spent - budgetTotal).toStringAsFixed(0)}，建议调整后续支出计划';
          break;
        case DialogStyle.playful:
          text = '预算超了，不过也不是第一次了对吧~';
          break;
        case DialogStyle.supportive:
          text = '预算稍微超了一点，这个月可能需要稍微注意一下';
          break;
        default:
          text = '预算已超支¥${(spent - budgetTotal).toStringAsFixed(0)}';
      }
      suggestions = ['查看超支原因', '调整预算'];
    } else if (usageRate > 0.8) {
      // 接近用完
      switch (style) {
        case DialogStyle.professional:
          text = '预算已用${(usageRate * 100).toStringAsFixed(0)}%，剩余¥${remaining.toStringAsFixed(0)}可用$daysRemaining天';
          break;
        case DialogStyle.playful:
          text = '预算快见底啦，还剩¥${remaining.toStringAsFixed(0)}要撑$daysRemaining天';
          break;
        case DialogStyle.supportive:
          text = '预算用得差不多了，剩余的¥${remaining.toStringAsFixed(0)}建议谨慎使用';
          break;
        default:
          text = '预算剩余¥${remaining.toStringAsFixed(0)}';
      }
      suggestions = ['查看消费建议', '查看分类消费'];
    } else {
      // 正常情况
      switch (style) {
        case DialogStyle.professional:
          text = '预算执行良好，已用${(usageRate * 100).toStringAsFixed(0)}%，剩余¥${remaining.toStringAsFixed(0)}';
          break;
        case DialogStyle.playful:
          text = '预算还有¥${remaining.toStringAsFixed(0)}，可以稍微放松一下~';
          break;
        case DialogStyle.supportive:
          text = '做得很好！预算还剩¥${remaining.toStringAsFixed(0)}，继续保持';
          break;
        case DialogStyle.dataFocused:
          text = '预算使用率${(usageRate * 100).toStringAsFixed(1)}%，剩余¥${remaining.toStringAsFixed(0)}，日均可用¥${(remaining / daysRemaining).toStringAsFixed(0)}';
          break;
        default:
          text = '预算剩余¥${remaining.toStringAsFixed(0)}';
      }
      suggestions = ['查看分类详情'];
    }

    return _ResponseBuilder(
      text: text,
      tone: _getTone(style),
      shouldSpeak: true,
      suggestions: suggestions,
    );
  }

  /// 记账回复
  _ResponseBuilder _buildRecordExpenseResponse(
    Map<String, dynamic> data,
    UserProfile? profile,
    DialogStyle style,
  ) {
    final amount = data['amount'] as double? ?? 0;
    final category = data['category'] as String? ?? '其他';
    final merchant = data['merchant'] as String?;

    String text;

    switch (style) {
      case DialogStyle.professional:
        text = '已记录${merchant ?? category}消费¥${amount.toStringAsFixed(0)}';
        break;
      case DialogStyle.playful:
        text = '记好啦！${amount > 100 ? '大手笔哦~' : ''}';
        break;
      case DialogStyle.supportive:
        text = '已记录，今天的消费都在掌控中';
        break;
      case DialogStyle.dataFocused:
        text = '已记录¥${amount.toStringAsFixed(0)}至$category';
        break;
      case DialogStyle.casual:
        text = '记了';
        break;
      case DialogStyle.neutral:
        text = '记账成功';
        break;
    }

    return _ResponseBuilder(
      text: text,
      tone: _getTone(style),
      shouldSpeak: true,
      suggestions: ['继续记账', '查看今日消费'],
    );
  }

  /// 目标查询回复
  _ResponseBuilder _buildGoalQueryResponse(
    Map<String, dynamic> data,
    UserProfile? profile,
    DialogStyle style,
  ) {
    final goalName = data['goal_name'] as String? ?? '储蓄目标';
    final targetAmount = data['target_amount'] as double? ?? 0;
    final currentAmount = data['current_amount'] as double? ?? 0;
    final progress = targetAmount > 0 ? currentAmount / targetAmount : 0;

    String text;

    switch (style) {
      case DialogStyle.professional:
        text = '$goalName进度${(progress * 100).toStringAsFixed(1)}%，已存¥${currentAmount.toStringAsFixed(0)}';
        break;
      case DialogStyle.playful:
        if (progress >= 0.8) {
          text = '太棒了！$goalName快达成了，冲鸭！';
        } else if (progress >= 0.5) {
          text = '$goalName已经过半啦，加油！';
        } else {
          text = '$goalName刚起步，慢慢来~';
        }
        break;
      case DialogStyle.supportive:
        text = '$goalName已经完成${(progress * 100).toStringAsFixed(0)}%了，你很努力';
        break;
      case DialogStyle.dataFocused:
        final remaining = targetAmount - currentAmount;
        text = '$goalName: ¥${currentAmount.toStringAsFixed(0)}/¥${targetAmount.toStringAsFixed(0)} (${(progress * 100).toStringAsFixed(1)}%)，还差¥${remaining.toStringAsFixed(0)}';
        break;
      default:
        text = '$goalName进度${(progress * 100).toStringAsFixed(0)}%';
    }

    return _ResponseBuilder(
      text: text,
      tone: _getTone(style),
      shouldSpeak: true,
      suggestions: ['查看目标详情', '调整目标'],
    );
  }

  /// 问候回复
  _ResponseBuilder _buildGreetingResponse(
    UserProfile? profile,
    DialogStyle style,
  ) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? '早上好' : (hour < 18 ? '下午好' : '晚上好');

    String text;

    switch (style) {
      case DialogStyle.playful:
        final greetings = [
          '$timeGreeting！今天打算记点什么？',
          '来啦~有什么需要记录的吗？',
          '你好呀！准备好管理钱钱了吗？',
        ];
        text = greetings[Random().nextInt(greetings.length)];
        break;
      case DialogStyle.supportive:
        text = '$timeGreeting！有什么我可以帮你的吗？';
        break;
      case DialogStyle.professional:
        text = '$timeGreeting，请问需要什么帮助？';
        break;
      case DialogStyle.casual:
        text = '在呢~';
        break;
      default:
        text = '$timeGreeting！';
    }

    return _ResponseBuilder(
      text: text,
      tone: _getTone(style),
      shouldSpeak: true,
      suggestions: ['记一笔', '查看今日消费', '查看预算'],
    );
  }

  /// 默认回复
  _ResponseBuilder _buildDefaultResponse(DialogStyle style) {
    return _ResponseBuilder(
      text: '好的，还有什么需要帮助的吗？',
      tone: _getTone(style),
      shouldSpeak: true,
      suggestions: ['记账', '查询', '帮助'],
    );
  }

  /// 获取语气
  ResponseTone _getTone(DialogStyle style) {
    switch (style) {
      case DialogStyle.professional:
        return ResponseTone.formal;
      case DialogStyle.playful:
        return ResponseTone.enthusiastic;
      case DialogStyle.supportive:
        return ResponseTone.warm;
      case DialogStyle.dataFocused:
        return ResponseTone.neutral;
      case DialogStyle.casual:
        return ResponseTone.casual;
      case DialogStyle.neutral:
        return ResponseTone.neutral;
    }
  }

  /// 获取LLM系统提示词
  Future<String> getSystemPrompt(String userId) async {
    final profile = await _profileService.getProfile(userId);
    if (profile == null) {
      return _defaultSystemPrompt;
    }

    return '''
你是一个智能记账助手，请根据以下用户画像调整你的回复风格：

${profile.toPromptSummary()}

回复要求：
1. 根据用户的沟通偏好调整语气
2. 避免提及用户的敏感话题
3. 如果用户有近期关注的目标，适当关联
4. 保持简洁，每次回复不超过50字
5. 语气${_getStyleDescription(profile.personalityTraits.spendingPersonality)}
''';
  }

  String _getStyleDescription(SpendingPersonality personality) {
    switch (personality) {
      case SpendingPersonality.frugalRational:
        return '专业、肯定，强调节省成效';
      case SpendingPersonality.enjoymentOriented:
        return '轻松幽默，温和提醒';
      case SpendingPersonality.anxiousWorrier:
        return '温暖安抚，正向引导';
      case SpendingPersonality.goalDriven:
        return '数据驱动，进度追踪';
      case SpendingPersonality.casualBuddhist:
        return '简洁直接，不强制建议';
    }
  }

  static const String _defaultSystemPrompt = '''
你是一个友好的智能记账助手。
回复要求：
1. 保持简洁，每次回复不超过50字
2. 语气友好自然
3. 关注用户的财务健康
''';
}

/// 对话风格
enum DialogStyle {
  professional, // 专业正式
  playful, // 轻松幽默
  supportive, // 温暖支持
  dataFocused, // 数据驱动
  casual, // 随意简洁
  neutral, // 中性
}

/// 回复语气
enum ResponseTone {
  formal, // 正式
  enthusiastic, // 热情
  warm, // 温暖
  neutral, // 中性
  casual, // 随意
}

/// 个性化回复
class PersonalizedResponse {
  final String text;
  final ResponseTone tone;
  final bool shouldSpeak;
  final List<String> suggestions;
  final DialogStyle style;
  final bool profileUsed;

  const PersonalizedResponse({
    required this.text,
    required this.tone,
    required this.shouldSpeak,
    required this.suggestions,
    required this.style,
    required this.profileUsed,
  });
}

/// 内部响应构建器
class _ResponseBuilder {
  final String text;
  final ResponseTone tone;
  final bool shouldSpeak;
  final List<String> suggestions;

  const _ResponseBuilder({
    required this.text,
    required this.tone,
    required this.shouldSpeak,
    required this.suggestions,
  });
}
