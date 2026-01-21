/// 时机判断器
///
/// 根据对话状态判断是否适合告知用户执行结果
///
/// 判断策略：
/// - 用户主动询问 → immediate（立即告知）
/// - 用户刚说完业务相关话题 → natural（自然融入回复）
/// - 用户沉默/主动话题时机 → onIdle（主动告知）
/// - 用户话题转换 → onTopicShift（适时告知）
/// - 用户深度闲聊/情绪不佳 → defer（暂不告知）
library;

import 'package:flutter/foundation.dart';

import 'result_buffer.dart';

/// 通知时机
enum NotificationTiming {
  /// 立即通知（用户主动询问）
  immediate,

  /// 自然融入（业务相关话题）
  natural,

  /// 空闲时通知（用户沉默）
  onIdle,

  /// 话题转换时通知
  onTopicShift,

  /// 延迟通知（闲聊中/情绪不佳）
  defer,

  /// 压制通知（不通知）
  suppress,
}

/// 时机判断上下文
class TimingContext {
  /// 用户最新输入
  final String? userInput;

  /// 用户是否正在说话（VAD状态）
  final bool isUserSpeaking;

  /// 用户沉默时长（毫秒）
  final int silenceDurationMs;

  /// 是否检测到负面情绪
  final bool isNegativeEmotion;

  /// 是否在闲聊中
  final bool isInChat;

  /// 上一轮对话是否是业务操作
  final bool lastRoundWasOperation;

  /// 待通知结果数量
  final int pendingResultCount;

  /// 待通知结果的最高优先级
  final ResultPriority? highestPriority;

  const TimingContext({
    this.userInput,
    required this.isUserSpeaking,
    required this.silenceDurationMs,
    this.isNegativeEmotion = false,
    this.isInChat = false,
    this.lastRoundWasOperation = false,
    required this.pendingResultCount,
    this.highestPriority,
  });

  @override
  String toString() => 'TimingContext('
      'speaking=$isUserSpeaking, '
      'silence=${silenceDurationMs}ms, '
      'emotion=${isNegativeEmotion ? "negative" : "neutral"}, '
      'chat=$isInChat, '
      'lastOp=$lastRoundWasOperation, '
      'pending=$pendingResultCount)';
}

/// 时机判断结果
class TimingJudgment {
  /// 通知时机
  final NotificationTiming timing;

  /// 原因说明
  final String reason;

  /// 建议的通知前缀（用于不同时机的不同说法）
  final String? notificationPrefix;

  const TimingJudgment({
    required this.timing,
    required this.reason,
    this.notificationPrefix,
  });

  /// 是否应该通知
  bool get shouldNotify =>
      timing == NotificationTiming.immediate ||
      timing == NotificationTiming.natural ||
      timing == NotificationTiming.onIdle ||
      timing == NotificationTiming.onTopicShift;

  @override
  String toString() => 'TimingJudgment($timing, reason: $reason)';
}

/// 时机判断器
class TimingJudge {
  /// 沉默阈值（毫秒）- 超过此时间认为用户沉默
  static const int silenceThresholdMs = 5000;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 询问结果的模式
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 询问结果的模式
  static const _askResultPatterns = <String>[
    '记好了吗',
    '记上了吗',
    '好了吗',
    '完成了吗',
    '弄好了吗',
    '怎么样了',
    '搞定了吗',
    '成功了吗',
    '记了吗',
    '存了吗',
    '保存了吗',
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 通知前缀模板
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _notificationPrefixes = <NotificationTiming, List<String>>{
    NotificationTiming.immediate: [''],
    NotificationTiming.natural: ['', '另外，'],
    NotificationTiming.onIdle: ['对了，', '顺便说一下，'],
    NotificationTiming.onTopicShift: ['刚才的', '之前的'],
  };

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 核心判断逻辑
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 判断通知时机
  TimingJudgment judge(TimingContext context) {
    debugPrint('[TimingJudge] 判断时机: $context');

    // 无待通知结果
    if (context.pendingResultCount == 0) {
      return const TimingJudgment(
        timing: NotificationTiming.suppress,
        reason: '无待通知结果',
      );
    }

    // 1. 用户正在说话 → defer
    if (context.isUserSpeaking) {
      debugPrint('[TimingJudge] 用户正在说话，延迟通知');
      return const TimingJudgment(
        timing: NotificationTiming.defer,
        reason: '用户正在说话',
      );
    }

    // 2. 用户主动询问结果 → immediate
    if (_isAskingResult(context.userInput)) {
      debugPrint('[TimingJudge] 用户询问结果，立即通知');
      return TimingJudgment(
        timing: NotificationTiming.immediate,
        reason: '用户主动询问',
        notificationPrefix: _getPrefix(NotificationTiming.immediate),
      );
    }

    // 3. 用户情绪负面 → defer
    if (context.isNegativeEmotion) {
      debugPrint('[TimingJudge] 检测到负面情绪，延迟通知');
      return const TimingJudgment(
        timing: NotificationTiming.defer,
        reason: '用户情绪负面',
      );
    }

    // 4. 深度闲聊中 → defer（除非是关键优先级）
    if (context.isInChat && context.highestPriority != ResultPriority.critical) {
      debugPrint('[TimingJudge] 闲聊中且非关键，延迟通知');
      return const TimingJudgment(
        timing: NotificationTiming.defer,
        reason: '闲聊中',
      );
    }

    // 5. 用户沉默超过阈值 → onIdle
    if (context.silenceDurationMs >= silenceThresholdMs) {
      debugPrint('[TimingJudge] 用户沉默超过${silenceThresholdMs}ms，空闲时通知');
      return TimingJudgment(
        timing: NotificationTiming.onIdle,
        reason: '用户沉默',
        notificationPrefix: _getPrefix(NotificationTiming.onIdle),
      );
    }

    // 6. 上一轮是操作 → natural
    if (context.lastRoundWasOperation) {
      debugPrint('[TimingJudge] 上一轮是操作，自然融入');
      return TimingJudgment(
        timing: NotificationTiming.natural,
        reason: '业务相关上下文',
        notificationPrefix: _getPrefix(NotificationTiming.natural),
      );
    }

    // 7. 关键优先级强制通知 → onIdle
    if (context.highestPriority == ResultPriority.critical) {
      debugPrint('[TimingJudge] 关键优先级，空闲时通知');
      return TimingJudgment(
        timing: NotificationTiming.onIdle,
        reason: '关键优先级',
        notificationPrefix: _getPrefix(NotificationTiming.onIdle),
      );
    }

    // 8. 默认 → defer
    debugPrint('[TimingJudge] 默认延迟通知');
    return const TimingJudgment(
      timing: NotificationTiming.defer,
      reason: '默认延迟',
    );
  }

  /// 检测用户是否在询问结果
  bool _isAskingResult(String? input) {
    if (input == null || input.isEmpty) return false;

    final normalized = input.replaceAll(RegExp(r'[，。！？、；：,.!?;:\s]+'), '');

    for (final pattern in _askResultPatterns) {
      if (normalized.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// 获取通知前缀
  String _getPrefix(NotificationTiming timing) {
    final prefixes = _notificationPrefixes[timing];
    if (prefixes == null || prefixes.isEmpty) return '';
    return prefixes.first;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 通知文本生成
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 生成通知文本
  ///
  /// [results] 待通知的结果列表
  /// [timing] 通知时机（影响前缀选择）
  String generateNotification(
    List<BufferedResult> results, {
    NotificationTiming timing = NotificationTiming.onIdle,
  }) {
    if (results.isEmpty) return '';

    final prefix = _getPrefix(timing);

    if (results.length == 1) {
      // 单条结果
      final result = results.first;
      final amountStr = result.amount != null ? '${result.amount}元' : '';
      return '$prefix${result.description}$amountStr已经记好了';
    } else {
      // 多条结果
      final descriptions = results.map((r) {
        final amountStr = r.amount != null ? '${r.amount}元' : '';
        return '${r.description}$amountStr';
      }).join('、');

      return '$prefix${results.length}笔记录都已完成：$descriptions';
    }
  }
}
