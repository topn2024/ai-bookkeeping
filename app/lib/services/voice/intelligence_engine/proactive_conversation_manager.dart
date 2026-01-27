import 'dart:async';
import 'package:flutter/foundation.dart';
import 'result_buffer.dart';

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

  /// 声音播放状态查询回调
  /// 返回 true 表示有声音在播放（用户说话 OR TTS播放）
  final bool Function()? isSoundPlaying;

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
    this.isSoundPlaying,
  });

  /// 启动静默监听
  void startSilenceMonitoring() {
    if (_proactiveDisabled) {
      debugPrint('[ProactiveConversationManager] 主动对话已禁用');
      return;
    }

    // 检查是否有声音在播放（用户说话 OR TTS播放）
    if (isSoundPlaying?.call() == true) {
      debugPrint('[ProactiveConversationManager] 有声音在播放，不启动静默监听');
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

/// 智能话题生成器
///
/// 核心功能：
/// - 优先从 ResultBuffer 获取待通知的查询结果
/// - 如果有查询结果，返回用户友好的结果文本
/// - 如果没有查询结果，根据用户偏好和对话风格生成话题
/// - 尊重用户的「不喜欢主动对话」设置
///
/// 设计思想：
/// 查询操作（如"今天花了多少"）是异步执行的，结果存入 ResultBuffer。
/// 当用户静默时，系统通过主动对话机制检索这些结果并告知用户。
class SmartTopicGenerator implements ProactiveTopicGenerator {
  /// 结果缓冲区（用于获取待通知的查询结果）
  final ResultBuffer? _resultBuffer;

  /// 用户偏好
  final UserPreferencesProvider? _preferencesProvider;

  /// LLM服务（用于智能话题生成）
  final LLMServiceProvider? _llmProvider;

  /// 对话上下文提供者（用于获取对话历史和用户习惯）
  final ConversationContextProvider? _contextProvider;

  /// 是否启用LLM生成
  final bool enableLLMGeneration;

  /// LLM生成超时时间（毫秒）
  static const int _llmTimeoutMs = 3000;

  /// 话题索引（用于轮换预设话题）
  int _topicIndex = 0;

  /// 上次使用的话题类型（避免连续重复）
  String? _lastTopicType;

  SmartTopicGenerator({
    ResultBuffer? resultBuffer,
    UserPreferencesProvider? preferencesProvider,
    LLMServiceProvider? llmProvider,
    ConversationContextProvider? contextProvider,
    this.enableLLMGeneration = true,
  })  : _resultBuffer = resultBuffer,
        _preferencesProvider = preferencesProvider,
        _llmProvider = llmProvider,
        _contextProvider = contextProvider;

  @override
  Future<String?> generateTopic() async {
    debugPrint('[SmartTopicGenerator] 生成话题...');

    // 获取用户偏好
    final prefs = _preferencesProvider?.getPreferences();
    final likesProactiveChat = prefs?.likesProactiveChat ?? true;
    final dialogStyle = prefs?.dialogStyle ?? DialogStylePreference.neutral;

    // 1. 优先检查 ResultBuffer 中是否有待通知的查询结果
    final resultBuffer = _resultBuffer;
    if (resultBuffer != null && resultBuffer.hasPendingResults) {
      final pendingResults = resultBuffer.pendingResults;
      debugPrint('[SmartTopicGenerator] 有 ${pendingResults.length} 个待通知结果');

      // 查找第一个查询结果（带有 responseText）
      for (final bufferedResult in pendingResults) {
        final data = bufferedResult.executionResult.data;
        if (data != null) {
          // 优先使用 responseText（由 BookkeepingOperationAdapter 生成）
          final responseText = data['responseText'] as String?;
          if (responseText != null && responseText.isNotEmpty) {
            debugPrint('[SmartTopicGenerator] 找到查询结果: $responseText');

            // 标记为已通知
            resultBuffer.markNotified(bufferedResult.id);

            return responseText;
          }

          // 如果没有 responseText，尝试用 description 构建简单反馈
          if (bufferedResult.description.isNotEmpty) {
            debugPrint('[SmartTopicGenerator] 使用 description: ${bufferedResult.description}');

            // 标记为已通知
            resultBuffer.markNotified(bufferedResult.id);

            // 根据风格调整反馈语
            return _styleText('${bufferedResult.description}已完成', dialogStyle);
          }
        }
      }
    }

    // 2. 检查用户是否喜欢主动对话
    // 如果不喜欢且没有待通知结果，保持静默
    if (!likesProactiveChat) {
      debugPrint('[SmartTopicGenerator] 用户不喜欢主动对话，且无待通知结果，保持静默');
      return null;
    }

    // 3. 尝试使用LLM生成话题（带超时和降级）
    if (enableLLMGeneration && _llmProvider != null && _llmProvider!.isAvailable) {
      debugPrint('[SmartTopicGenerator] 尝试LLM生成话题...');
      final llmTopic = await _tryLLMGeneration(dialogStyle);
      if (llmTopic != null) {
        debugPrint('[SmartTopicGenerator] LLM生成成功: $llmTopic');
        return llmTopic;
      }
      debugPrint('[SmartTopicGenerator] LLM生成失败，降级到规则生成');
    }

    // 4. 没有待通知的查询结果，使用时间相关的预设话题
    debugPrint('[SmartTopicGenerator] 无待通知结果，使用预设话题 (风格: $dialogStyle)');
    return _getTimeBasedTopic(dialogStyle);
  }

  /// 尝试使用LLM生成话题
  /// 带3秒超时，超时或失败返回null
  Future<String?> _tryLLMGeneration(DialogStylePreference style) async {
    try {
      final hour = DateTime.now().hour;
      final timeContext = _getTimeContext(hour);
      final styleDesc = _getStyleDescription(style);

      // 获取对话上下文（如果有）
      final contextSummary = _contextProvider?.getContextSummary();
      final recentAction = _contextProvider?.getRecentActionDescription();

      // 构建上下文部分
      final contextPart = StringBuffer();
      if (recentAction != null && recentAction.isNotEmpty) {
        contextPart.writeln('最近操作：$recentAction');
      }
      if (contextSummary != null && contextSummary.isNotEmpty) {
        contextPart.writeln('对话背景：$contextSummary');
      }

      final prompt = '''你是一个智能记账助手"小白"，正在和用户进行语音对话。
用户当前沉默了5秒，你需要主动发起一个话题。

当前时间：$timeContext
对话风格：$styleDesc
${contextPart.isNotEmpty ? '\n$contextPart' : ''}
请生成一句简短的主动对话（不超过15个字），用于引导用户继续对话。
要求：
- 简洁自然，像朋友聊天
- 与当前时间段相关
- 符合指定的对话风格
- 不要使用表情符号
- 如果有最近操作，可以基于此引导用户

直接输出话题文本，不要加引号或其他格式。''';

      // 使用超时保护
      final result = await Future.any([
        _llmProvider!.generateTopic(prompt),
        Future.delayed(
          const Duration(milliseconds: _llmTimeoutMs),
          () => null,
        ),
      ]);

      // 验证结果
      if (result != null && result.isNotEmpty && result.length <= 30) {
        return result.trim();
      }

      return null;
    } catch (e) {
      debugPrint('[SmartTopicGenerator] LLM生成异常: $e');
      return null;
    }
  }

  /// 获取时间上下文描述
  String _getTimeContext(int hour) {
    if (hour >= 6 && hour < 10) return '早上（6-10点）';
    if (hour >= 10 && hour < 12) return '上午（10-12点）';
    if (hour >= 12 && hour < 14) return '中午（12-14点）';
    if (hour >= 14 && hour < 18) return '下午（14-18点）';
    if (hour >= 18 && hour < 22) return '晚上（18-22点）';
    return '深夜/凌晨';
  }

  /// 获取风格描述
  String _getStyleDescription(DialogStylePreference style) {
    switch (style) {
      case DialogStylePreference.professional:
        return '专业简洁，正式礼貌';
      case DialogStylePreference.playful:
        return '活泼有趣，可以用语气词';
      case DialogStylePreference.supportive:
        return '温暖关怀，体贴用户';
      case DialogStylePreference.casual:
        return '随意轻松，像老朋友';
      default:
        return '自然平衡，不过度热情也不冷淡';
    }
  }

  /// 根据时间和对话风格获取话题
  String _getTimeBasedTopic(DialogStylePreference style) {
    final hour = DateTime.now().hour;
    String topicType;
    List<String> topics;

    if (hour >= 6 && hour < 10) {
      topicType = 'morning';
      topics = _getMorningTopics(style);
    } else if (hour >= 11 && hour < 14) {
      topicType = 'noon';
      topics = _getNoonTopics(style);
    } else if (hour >= 18 && hour < 22) {
      topicType = 'evening';
      topics = _getEveningTopics(style);
    } else {
      topicType = 'default';
      topics = _getDefaultTopics(style);
    }

    // 避免连续使用相同类型的话题
    int index = _topicIndex;
    if (_lastTopicType == topicType && topics.length > 1) {
      index = (_topicIndex + 1) % topics.length;
    }

    final topic = topics[index % topics.length];
    _topicIndex++;
    _lastTopicType = topicType;

    return topic;
  }

  /// 早晨话题（根据风格）
  List<String> _getMorningTopics(DialogStylePreference style) {
    switch (style) {
      case DialogStylePreference.professional:
        return const ['需要记录早餐消费吗？', '早上好，有什么可以帮您？'];
      case DialogStylePreference.playful:
        return const ['早呀~早餐记了没？', '新的一天，记个账呗~'];
      case DialogStylePreference.supportive:
        return const ['早上好！要帮你记录早餐吗？', '新的一天开始了，需要帮忙吗？'];
      case DialogStylePreference.casual:
        return const ['早餐记了吗？', '早，要记账吗？'];
      default:
        return const ['早上好！要记录一下早餐花销吗？', '需要帮你记账吗？'];
    }
  }

  /// 中午话题（根据风格）
  List<String> _getNoonTopics(DialogStylePreference style) {
    switch (style) {
      case DialogStylePreference.professional:
        return const ['需要记录午餐消费吗？', '中午好，有什么可以帮您？'];
      case DialogStylePreference.playful:
        return const ['午饭记了没呀~', '中午啦，记个账？'];
      case DialogStylePreference.supportive:
        return const ['午餐时间到了，要帮你记一笔吗？', '中午好！需要帮忙记账吗？'];
      case DialogStylePreference.casual:
        return const ['午餐记了吗？', '中午，要记账吗？'];
      default:
        return const ['午餐吃了吗？要记一笔吗？', '中午好！需要记录午餐消费吗？'];
    }
  }

  /// 晚上话题（根据风格）
  List<String> _getEveningTopics(DialogStylePreference style) {
    switch (style) {
      case DialogStylePreference.professional:
        return const ['今日账目记录完成了吗？', '晚上好，需要查看今日消费吗？'];
      case DialogStylePreference.playful:
        return const ['今天的账记完了吗~', '晚上好呀，回顾一下今天？'];
      case DialogStylePreference.supportive:
        return const ['辛苦了！今天的账记完了吗？', '晚上好！要回顾一下今天的支出吗？'];
      case DialogStylePreference.casual:
        return const ['今天账记完了吗？', '晚上好，要记账吗？'];
      default:
        return const ['今天的账记完了吗？要查看今日消费吗？', '晚上好！要回顾一下今天的支出吗？'];
    }
  }

  /// 默认话题（根据风格）
  List<String> _getDefaultTopics(DialogStylePreference style) {
    switch (style) {
      case DialogStylePreference.professional:
        return const ['有什么可以帮您的吗？', '需要记账吗？'];
      case DialogStylePreference.playful:
        return const ['有啥要记的吗~', '需要帮忙吗？'];
      case DialogStylePreference.supportive:
        return const ['需要帮你做点什么吗？', '有什么可以帮忙的？'];
      case DialogStylePreference.casual:
        return const ['要记账吗？', '还在吗？'];
      default:
        return const ['需要我帮你记一笔账吗？', '还有什么可以帮您的吗？', '还在吗？'];
    }
  }

  /// 根据风格调整文本
  String _styleText(String text, DialogStylePreference style) {
    switch (style) {
      case DialogStylePreference.playful:
        return '$text~';
      case DialogStylePreference.professional:
        return text.replaceAll('~', '');
      default:
        return text;
    }
  }

  /// 重置话题索引
  void reset() {
    _topicIndex = 0;
    _lastTopicType = null;
  }
}

/// 用户偏好提供者接口
/// 用于获取当前用户的对话偏好设置
abstract class UserPreferencesProvider {
  UserPreferencesData? getPreferences();
}

/// LLM服务提供者接口
/// 用于生成主动对话话题
abstract class LLMServiceProvider {
  /// 是否可用
  bool get isAvailable;

  /// 生成话题
  /// [prompt] 提示词
  /// 返回生成的话题文本，失败返回 null
  Future<String?> generateTopic(String prompt);
}

/// 对话上下文提供者接口
/// 用于获取对话上下文摘要，供LLM话题生成使用
abstract class ConversationContextProvider {
  /// 获取对话上下文摘要
  /// 返回包含最近对话、用户习惯等信息的摘要文本
  String? getContextSummary();

  /// 获取最近的操作描述
  String? getRecentActionDescription();
}

/// 用户偏好数据
class UserPreferencesData {
  /// 是否喜欢主动对话
  final bool likesProactiveChat;

  /// 对话风格
  final DialogStylePreference dialogStyle;

  const UserPreferencesData({
    this.likesProactiveChat = true,
    this.dialogStyle = DialogStylePreference.neutral,
  });
}

/// 对话风格偏好
enum DialogStylePreference {
  professional, // 专业简洁
  playful,      // 活泼有趣
  supportive,   // 温暖支持
  casual,       // 随意轻松
  neutral,      // 中性平衡
}

/// 简单的用户偏好提供者实现
///
/// 用于存储和获取用户的对话偏好设置
/// 支持动态更新偏好
class SimpleUserPreferencesProvider implements UserPreferencesProvider {
  UserPreferencesData _preferences;

  SimpleUserPreferencesProvider({
    bool likesProactiveChat = true,
    DialogStylePreference dialogStyle = DialogStylePreference.neutral,
  }) : _preferences = UserPreferencesData(
          likesProactiveChat: likesProactiveChat,
          dialogStyle: dialogStyle,
        );

  @override
  UserPreferencesData? getPreferences() => _preferences;

  /// 更新偏好设置
  void updatePreferences({
    bool? likesProactiveChat,
    DialogStylePreference? dialogStyle,
  }) {
    _preferences = UserPreferencesData(
      likesProactiveChat: likesProactiveChat ?? _preferences.likesProactiveChat,
      dialogStyle: dialogStyle ?? _preferences.dialogStyle,
    );
    debugPrint('[UserPreferencesProvider] 偏好已更新: likesProactiveChat=${_preferences.likesProactiveChat}, style=${_preferences.dialogStyle}');
  }

  /// 设置是否喜欢主动对话
  void setLikesProactiveChat(bool value) {
    updatePreferences(likesProactiveChat: value);
  }

  /// 设置对话风格
  void setDialogStyle(DialogStylePreference style) {
    updatePreferences(dialogStyle: style);
  }
}
