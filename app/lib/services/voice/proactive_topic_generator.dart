import 'dart:math';

import 'package:flutter/foundation.dart';

import 'memory/conversation_memory.dart';

/// 主动话题类型
enum ProactiveTopicType {
  /// 执行结果反馈
  resultFeedback,

  /// 提醒类
  reminder,

  /// 引导类
  guidance,

  /// 闲聊类
  casual,

  /// 关怀类
  caring,
}

/// 主动话题
class ProactiveTopic {
  /// 话题类型
  final ProactiveTopicType type;

  /// 话题文本
  final String text;

  /// 优先级（越高越优先）
  final int priority;

  /// 触发条件
  final String? triggerCondition;

  /// 关联数据
  final Map<String, dynamic>? data;

  const ProactiveTopic({
    required this.type,
    required this.text,
    this.priority = 0,
    this.triggerCondition,
    this.data,
  });
}

/// 主动话题生成器
///
/// 基于用户画像和对话上下文生成主动发起的话题
///
/// 话题类型：
/// - 确认类: "刚才那笔记录好了哦"（执行结果反馈）
/// - 提醒类: "今天还没记早餐呢"
/// - 引导类: "还有其他要记的吗？"
/// - 闲聊类: "今天花得不多呀"
class ProactiveTopicGenerator {
  /// 配置
  final ProactiveTopicConfig config;

  /// 待反馈的操作结果
  final List<PendingFeedback> _pendingFeedbacks = [];

  /// 随机数生成器
  final _random = Random();

  ProactiveTopicGenerator({ProactiveTopicConfig? config})
      : config = config ?? const ProactiveTopicConfig();

  // ==================== 公共API ====================

  /// 是否有待反馈的结果
  bool get hasPendingFeedback => _pendingFeedbacks.isNotEmpty;

  /// 添加待反馈的操作结果
  void addPendingFeedback(PendingFeedback feedback) {
    _pendingFeedbacks.add(feedback);
    debugPrint('[ProactiveTopicGenerator] 添加待反馈: ${feedback.type}');
  }

  /// 生成主动话题
  ///
  /// 根据当前上下文和用户画像生成合适的主动话题
  Future<ProactiveTopic?> generateTopic({
    ConversationMemory? memory,
    UserProfileSummary? userProfile,
    TimeContext? timeContext,
  }) async {
    debugPrint('[ProactiveTopicGenerator] 生成主动话题');

    // 优先级1: 待反馈的操作结果
    if (_pendingFeedbacks.isNotEmpty) {
      final feedback = _pendingFeedbacks.removeAt(0);
      return _generateResultFeedbackTopic(feedback, userProfile);
    }

    // 优先级2: 基于时间的提醒
    if (timeContext != null) {
      final reminderTopic = _generateReminderTopic(timeContext, userProfile);
      if (reminderTopic != null) return reminderTopic;
    }

    // 优先级3: 引导类话题
    if (memory != null && memory.turnCount > 0) {
      return _generateGuidanceTopic(memory, userProfile);
    }

    // 优先级4: 闲聊类话题
    if (userProfile != null && userProfile.likesProactiveChat) {
      return _generateCasualTopic(userProfile, timeContext);
    }

    // 默认: 简单引导
    return _getDefaultGuidanceTopic();
  }

  /// 清除所有待反馈
  void clearPendingFeedbacks() {
    _pendingFeedbacks.clear();
  }

  // ==================== 内部方法 ====================

  /// 生成执行结果反馈话题
  ProactiveTopic _generateResultFeedbackTopic(
    PendingFeedback feedback,
    UserProfileSummary? userProfile,
  ) {
    final style = userProfile?.dialogStyle ?? DialogStyle.neutral;

    String text;
    switch (feedback.type) {
      case FeedbackType.bookkeepingSuccess:
        text = _getBookkeepingSuccessText(feedback, style);
        break;
      case FeedbackType.modifySuccess:
        text = _getModifySuccessText(feedback, style);
        break;
      case FeedbackType.deleteSuccess:
        text = _getDeleteSuccessText(style);
        break;
      case FeedbackType.queryResult:
        text = _getQueryResultText(feedback, style);
        break;
    }

    return ProactiveTopic(
      type: ProactiveTopicType.resultFeedback,
      text: text,
      priority: 10,
      data: feedback.data,
    );
  }

  /// 生成提醒类话题
  ProactiveTopic? _generateReminderTopic(
    TimeContext timeContext,
    UserProfileSummary? userProfile,
  ) {
    // 早餐时间提醒
    if (timeContext.hour >= 7 && timeContext.hour <= 9) {
      if (_random.nextDouble() < 0.3) {
        return const ProactiveTopic(
          type: ProactiveTopicType.reminder,
          text: '早上好～吃早餐了吗？',
          priority: 5,
        );
      }
    }

    // 午餐时间提醒
    if (timeContext.hour >= 11 && timeContext.hour <= 13) {
      if (_random.nextDouble() < 0.3) {
        return const ProactiveTopic(
          type: ProactiveTopicType.reminder,
          text: '中午了，午餐记了吗？',
          priority: 5,
        );
      }
    }

    // 晚餐时间提醒
    if (timeContext.hour >= 17 && timeContext.hour <= 19) {
      if (_random.nextDouble() < 0.3) {
        return const ProactiveTopic(
          type: ProactiveTopicType.reminder,
          text: '晚饭时间到了～',
          priority: 5,
        );
      }
    }

    return null;
  }

  /// 生成引导类话题
  ProactiveTopic _generateGuidanceTopic(
    ConversationMemory memory,
    UserProfileSummary? userProfile,
  ) {
    final lastAction = memory.lastAction;

    // 如果刚完成记账，询问是否还有其他
    if (lastAction != null && lastAction.isBookkeeping) {
      final texts = [
        '还有其他要记的吗？',
        '还有别的吗？',
        '继续？',
      ];
      return ProactiveTopic(
        type: ProactiveTopicType.guidance,
        text: texts[_random.nextInt(texts.length)],
        priority: 3,
      );
    }

    return _getDefaultGuidanceTopic();
  }

  /// 生成闲聊类话题
  ProactiveTopic? _generateCasualTopic(
    UserProfileSummary userProfile,
    TimeContext? timeContext,
  ) {
    // 基于用户特征生成个性化话题
    if (userProfile.spendingLevel == SpendingLevel.frugal) {
      final texts = [
        '今天花得不多呀，继续保持～',
        '省钱小能手就是你！',
      ];
      return ProactiveTopic(
        type: ProactiveTopicType.casual,
        text: texts[_random.nextInt(texts.length)],
        priority: 1,
      );
    }

    return null;
  }

  /// 获取默认引导话题
  ProactiveTopic _getDefaultGuidanceTopic() {
    final texts = [
      '有什么需要帮忙的吗？',
      '要记账吗？',
      '有什么可以帮你的？',
    ];
    return ProactiveTopic(
      type: ProactiveTopicType.guidance,
      text: texts[_random.nextInt(texts.length)],
      priority: 1,
    );
  }

  /// 获取记账成功文本
  String _getBookkeepingSuccessText(PendingFeedback feedback, DialogStyle style) {
    final amount = feedback.data?['amount'];
    final category = feedback.data?['category'];

    switch (style) {
      case DialogStyle.playful:
        if (amount != null) {
          return '记好啦！${category ?? ''}花了$amount块～';
        }
        return '记好啦！';
      case DialogStyle.professional:
        return '已记录。';
      case DialogStyle.supportive:
        return '好的，帮你记下了～';
      default:
        return '记录好了。';
    }
  }

  /// 获取修改成功文本
  String _getModifySuccessText(PendingFeedback feedback, DialogStyle style) {
    switch (style) {
      case DialogStyle.playful:
        return '改好啦～';
      case DialogStyle.professional:
        return '已修改。';
      default:
        return '修改好了。';
    }
  }

  /// 获取删除成功文本
  String _getDeleteSuccessText(DialogStyle style) {
    switch (style) {
      case DialogStyle.playful:
        return '删掉啦～';
      case DialogStyle.professional:
        return '已删除。';
      default:
        return '删除了。';
    }
  }

  /// 获取查询结果文本
  String _getQueryResultText(PendingFeedback feedback, DialogStyle style) {
    final result = feedback.data?['result'] ?? '没有找到相关记录';
    return result.toString();
  }
}

/// 主动话题配置
class ProactiveTopicConfig {
  /// 是否启用提醒类话题
  final bool enableReminders;

  /// 是否启用闲聊类话题
  final bool enableCasualChat;

  /// 提醒类话题概率
  final double reminderProbability;

  const ProactiveTopicConfig({
    this.enableReminders = true,
    this.enableCasualChat = true,
    this.reminderProbability = 0.3,
  });
}

/// 待反馈信息
class PendingFeedback {
  final FeedbackType type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  PendingFeedback({
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 反馈类型
enum FeedbackType {
  bookkeepingSuccess,
  modifySuccess,
  deleteSuccess,
  queryResult,
}

/// 时间上下文
class TimeContext {
  final int hour;
  final int minute;
  final int dayOfWeek;
  final bool isWeekend;

  TimeContext({
    required this.hour,
    required this.minute,
    required this.dayOfWeek,
  }) : isWeekend = dayOfWeek == 6 || dayOfWeek == 7;

  factory TimeContext.now() {
    final now = DateTime.now();
    return TimeContext(
      hour: now.hour,
      minute: now.minute,
      dayOfWeek: now.weekday,
    );
  }
}

/// 用户画像摘要（用于话题生成）
class UserProfileSummary {
  final DialogStyle dialogStyle;
  final SpendingLevel spendingLevel;
  final bool likesProactiveChat;
  final List<String> favoriteTopics;

  const UserProfileSummary({
    this.dialogStyle = DialogStyle.neutral,
    this.spendingLevel = SpendingLevel.moderate,
    this.likesProactiveChat = true,
    this.favoriteTopics = const [],
  });
}

/// 对话风格
enum DialogStyle {
  professional,
  playful,
  supportive,
  dataFocused,
  casual,
  neutral,
}

/// 消费水平
enum SpendingLevel {
  frugal,
  moderate,
  generous,
}
