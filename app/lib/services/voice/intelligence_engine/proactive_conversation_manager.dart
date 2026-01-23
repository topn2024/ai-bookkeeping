import 'dart:async';
import 'package:flutter/foundation.dart';

/// 主动对话管理器
///
/// 职责：
/// - 5秒无输入 → 主动发起话题
/// - 连续3次用户不回应 → 结束对话
/// - 30秒总计无响应 → 结束对话
/// - 用户拒绝检测和退出机制
class ProactiveConversationManager {
  final ProactiveTopicGenerator topicGenerator;
  final ProactiveMessageCallback onProactiveMessage;

  /// 会话结束回调（连续3次不回应或30秒无响应）
  VoidCallback? onSessionEnd;

  // 计时器
  Timer? _silenceTimer; // 5秒静默计时器
  Timer? _totalSilenceTimer; // 30秒总计无响应计时器

  // 状态
  ProactiveState _state = ProactiveState.idle;

  // 计数器
  int _proactiveCount = 0; // 连续主动发起次数（用户不回应）

  // 配置
  static const int _silenceTimeoutMs = 5000; // 5秒静默后主动发起话题
  static const int _maxProactiveCount = 3; // 连续3次不回应则结束
  static const int _maxTotalSilenceMs = 30000; // 30秒总计无响应则结束

  // 是否已禁用
  bool _proactiveDisabled = false;

  ProactiveConversationManager({
    required this.topicGenerator,
    required this.onProactiveMessage,
    this.onSessionEnd,
  });

  /// 启动静默监听
  void startSilenceMonitoring() {
    if (_proactiveDisabled) {
      debugPrint('[ProactiveConversationManager] 主动对话已禁用');
      return;
    }

    debugPrint('[ProactiveConversationManager] 启动静默监听: ${_silenceTimeoutMs}ms (已主动$_proactiveCount次)');
    _state = ProactiveState.waiting;

    // 启动5秒静默计时器
    // 注意：Timer 回调中的异步操作需要用 catchError 捕获错误
    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      Duration(milliseconds: _silenceTimeoutMs),
      () {
        // 检查是否已禁用或状态已改变（计时器回调可能在状态变化后触发）
        if (_proactiveDisabled) {
          debugPrint('[ProactiveConversationManager] 计时器触发时已禁用，跳过');
          return;
        }
        if (_state != ProactiveState.waiting) {
          debugPrint('[ProactiveConversationManager] 计时器触发时状态非waiting($_state)，跳过');
          return;
        }
        debugPrint('[ProactiveConversationManager] 5秒静默超时，触发主动对话');
        // 使用 catchError 确保异步错误被捕获
        _triggerProactiveMessage().catchError((e, s) {
          debugPrint('[ProactiveConversationManager] 触发主动对话失败: $e');
        });
      },
    );

    // 首次启动时，同时启动30秒总计无响应计时器
    if (_totalSilenceTimer == null) {
      debugPrint('[ProactiveConversationManager] 启动30秒总计无响应计时器');
      _totalSilenceTimer = Timer(
        Duration(milliseconds: _maxTotalSilenceMs),
        () {
          // 检查是否已禁用（计时器回调可能在禁用后触发）
          if (_proactiveDisabled) {
            debugPrint('[ProactiveConversationManager] 30秒计时器触发时已禁用，跳过');
            return;
          }
          debugPrint('[ProactiveConversationManager] 30秒总计无响应，结束对话');
          _triggerSessionEnd();
        },
      );
    }
  }

  /// 重置计时器
  ///
  /// [isUserInitiated] 是否由用户主动输入触发
  /// - true: 用户真实输入，重置计数和30秒计时器
  /// - false: 系统延迟响应（如deferred操作完成），重置30秒计时器和计数
  ///
  /// 关键设计决策：
  /// - 无论是用户输入还是系统响应，都应该重置30秒总计时器
  /// - 系统给出响应后，用户需要时间消化，不应该继续倒计时
  /// - 系统响应（如延迟记账结果）也是新内容，用户需要时间回应
  /// - 因此无论哪种情况都重置 _proactiveCount，给用户公平的回应机会
  void resetTimer({bool isUserInitiated = true}) {
    if (isUserInitiated) {
      debugPrint('[ProactiveConversationManager] 用户主动输入，重置所有计时器和计数');
    } else {
      debugPrint('[ProactiveConversationManager] 系统响应，重置所有计时器和计数');
    }

    // 无论是用户输入还是系统响应，都重置连续主动次数
    // 因为系统响应也是新内容，用户需要时间回应
    if (_proactiveCount > 0) {
      debugPrint('[ProactiveConversationManager] 重置连续主动次数: $_proactiveCount → 0');
      _proactiveCount = 0;
    }

    // 无论哪种情况，都取消所有计时器并重新开始
    // 这确保了系统响应后，用户有足够时间来回应
    _silenceTimer?.cancel();
    _totalSilenceTimer?.cancel();
    _totalSilenceTimer = null; // 设为null，startSilenceMonitoring会重建

    _state = ProactiveState.idle;

    // 重新启动监听
    startSilenceMonitoring();
  }

  /// 停止监听
  void stopMonitoring() {
    debugPrint('[ProactiveConversationManager] 停止监听');
    _silenceTimer?.cancel();
    _totalSilenceTimer?.cancel();
    _totalSilenceTimer = null;
    _state = ProactiveState.idle;
  }

  /// 触发主动对话
  ///
  /// 使用 try-finally 确保状态始终正确恢复到 idle
  Future<void> _triggerProactiveMessage() async {
    // 检查是否已经超过最大次数（5秒超时后触发）
    if (_proactiveCount >= _maxProactiveCount) {
      debugPrint('[ProactiveConversationManager] 连续${_maxProactiveCount}次无回应，结束对话');
      _triggerSessionEnd();
      return;
    }

    _state = ProactiveState.generating;
    _proactiveCount++;

    debugPrint('[ProactiveConversationManager] 生成主动话题 ($_proactiveCount/$_maxProactiveCount)');

    try {
      String? topic;
      try {
        // 生成话题
        topic = await topicGenerator.generateTopic();
      } catch (e) {
        debugPrint('[ProactiveConversationManager] 生成话题失败: $e');
      }

      if (topic != null) {
        _state = ProactiveState.speaking;
        debugPrint('[ProactiveConversationManager] 主动话题，长度: ${topic.length}');

        // 回调通知（单独 try-catch 确保状态始终能恢复）
        try {
          onProactiveMessage(topic);
        } catch (e) {
          debugPrint('[ProactiveConversationManager] 主动消息回调失败: $e');
        }
      }
    } finally {
      // 无论成功还是失败，都确保状态恢复到 idle
      _state = ProactiveState.idle;

      // 继续监听下一个5秒（即使已经3次，也给用户最后机会回应）
      debugPrint('[ProactiveConversationManager] 继续监听，等待用户回应');
      startSilenceMonitoring();
    }
  }

  /// 触发会话结束
  void _triggerSessionEnd() {
    debugPrint('[ProactiveConversationManager] 触发会话结束');
    stopMonitoring();
    _state = ProactiveState.stopped;
    onSessionEnd?.call();
  }

  /// 检测用户拒绝
  bool detectRejection(String input) {
    const rejectionKeywords = [
      '不用了', '别说了', '安静', '闭嘴', '不要',
      '停止', '别烦我', '不需要',
    ];

    final hasRejection = rejectionKeywords.any((keyword) => input.contains(keyword));

    if (hasRejection) {
      debugPrint('[ProactiveConversationManager] 检测到用户拒绝');
      _proactiveDisabled = true;
      stopMonitoring();
    }

    return hasRejection;
  }

  /// 重新启用主动对话
  void enable() {
    debugPrint('[ProactiveConversationManager] 重新启用主动对话');
    _proactiveDisabled = false;
    _proactiveCount = 0;
    startSilenceMonitoring();
  }

  /// 禁用主动对话
  void disable() {
    debugPrint('[ProactiveConversationManager] 禁用主动对话');
    _proactiveDisabled = true;
    stopMonitoring();
  }

  /// 获取当前状态
  ProactiveState get state => _state;

  /// 获取主动次数
  int get proactiveCount => _proactiveCount;

  /// 是否已禁用
  bool get isDisabled => _proactiveDisabled;

  /// 是否已达到最大主动次数
  bool get hasReachedMaxCount => _proactiveCount >= _maxProactiveCount;

  /// 手动增加主动次数（外部触发主动对话时使用）
  void incrementProactiveCount() {
    if (_proactiveCount < _maxProactiveCount) {
      _proactiveCount++;
      debugPrint('[ProactiveConversationManager] 主动次数增加: $_proactiveCount/$_maxProactiveCount');
    }
  }

  /// 重置状态（新会话时调用）
  void resetForNewSession() {
    debugPrint('[ProactiveConversationManager] 重置会话状态');
    _proactiveCount = 0;
    _proactiveDisabled = false;
    _state = ProactiveState.idle;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _totalSilenceTimer?.cancel();
    _totalSilenceTimer = null;
  }

  /// 清理资源
  void dispose() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _totalSilenceTimer?.cancel();
    _totalSilenceTimer = null;
  }
}

/// 主动对话状态
enum ProactiveState {
  idle,       // 空闲
  waiting,    // 等待中
  generating, // 生成话题中
  speaking,   // 播放中
  stopped,    // 已停止（会话结束）
}

/// 主动话题生成器接口
abstract class ProactiveTopicGenerator {
  /// 生成话题
  Future<String?> generateTopic();
}

/// 主动消息回调
typedef ProactiveMessageCallback = void Function(String message);

/// 简单的预设话题生成器
///
/// 根据时间和上下文选择合适的话题
class SimpleTopicGenerator implements ProactiveTopicGenerator {
  int _topicIndex = 0;

  /// 预设话题列表
  static const List<String> _defaultTopics = [
    '需要我帮你记一笔账吗？',
    '要查看今天的消费情况吗？',
    '还在吗？需要帮忙吗？',
  ];

  /// 早晨话题
  static const List<String> _morningTopics = [
    '早上好！要记录一下早餐花销吗？',
    '新的一天开始了，需要帮你记账吗？',
    '还在吗？',
  ];

  /// 中午话题
  static const List<String> _noonTopics = [
    '午餐吃了吗？要记一笔吗？',
    '中午好！需要记录午餐消费吗？',
    '还在吗？',
  ];

  /// 晚上话题
  static const List<String> _eveningTopics = [
    '今天的账记完了吗？要查看今日消费吗？',
    '晚上好！要回顾一下今天的支出吗？',
    '还在吗？',
  ];

  @override
  Future<String?> generateTopic() async {
    final hour = DateTime.now().hour;
    List<String> topics;

    if (hour >= 6 && hour < 10) {
      topics = _morningTopics;
    } else if (hour >= 11 && hour < 14) {
      topics = _noonTopics;
    } else if (hour >= 18 && hour < 22) {
      topics = _eveningTopics;
    } else {
      topics = _defaultTopics;
    }

    // 轮换话题（确保不超出范围）
    final topic = topics[_topicIndex % topics.length];
    _topicIndex++;

    return topic;
  }

  /// 重置话题索引
  void reset() {
    _topicIndex = 0;
  }
}
