import 'package:flutter/foundation.dart';

import '../user_profile_service.dart';
import 'memory/conversation_memory.dart';

/// 对话学习服务
///
/// 从对话历史中学习用户偏好，更新用户画像
/// 实现千人千面的个性化体验
class ConversationLearningService {
  /// 用户画像服务
  final UserProfileService? _profileService;

  /// 学习到的偏好缓存
  final Map<String, LearnedPreference> _learnedPreferences = {};

  /// 消费模式分析器
  final SpendingPatternAnalyzer _spendingAnalyzer = SpendingPatternAnalyzer();

  /// 对话风格分析器
  final DialogStyleAnalyzer _dialogStyleAnalyzer = DialogStyleAnalyzer();

  ConversationLearningService({
    UserProfileService? profileService,
  }) : _profileService = profileService;

  // ==================== 公共API ====================

  /// 从对话轮次学习
  Future<void> learnFromTurn(ConversationTurn turn) async {
    // 分析用户输入中的偏好信号
    _analyzeUserInput(turn.userInput);

    // 如果有操作结果，分析消费模式
    if (turn.action != null) {
      _analyzeAction(turn.action!);
    }

    // 分析用户对响应的反应（如果有后续输入）
    _analyzeResponseReaction(turn);
  }

  /// 从完整会话学习
  Future<void> learnFromSession(List<ConversationTurn> turns) async {
    if (turns.isEmpty) return;

    debugPrint('[ConversationLearning] 从${turns.length}轮对话中学习');

    for (final turn in turns) {
      await learnFromTurn(turn);
    }

    // 会话结束时进行总结性学习
    _summarizeSessionLearning(turns);
  }

  /// 获取学习到的偏好
  Map<String, LearnedPreference> get learnedPreferences =>
      Map.unmodifiable(_learnedPreferences);

  /// 获取推荐的对话风格
  VoiceDialogStyle? getRecommendedDialogStyle() {
    return _dialogStyleAnalyzer.recommendedStyle;
  }

  /// 获取推荐的主动话题
  List<String> getRecommendedTopics() {
    final topics = <String>[];

    // 基于消费模式推荐
    final spendingInsights = _spendingAnalyzer.getInsights();
    if (spendingInsights.isNotEmpty) {
      topics.addAll(spendingInsights);
    }

    // 基于用户兴趣推荐
    final interests = _learnedPreferences['interests'];
    if (interests != null && interests.confidence > 0.7) {
      topics.add('你最近好像对${interests.value}比较关注');
    }

    return topics;
  }

  /// 持久化学习结果
  ///
  /// 当前版本仅记录日志，完整持久化需要扩展UserProfileService
  Future<void> persistLearning(String userId) async {
    if (_profileService == null) {
      debugPrint('[ConversationLearning] 未配置画像服务，跳过持久化');
      return;
    }

    // 构建对话偏好（用于日志记录和未来持久化）
    final conversationPrefs = {
      'likesProactiveChat': _learnedPreferences['likesProactive']?.value == 'true',
      'silenceToleranceSeconds': _parseSilenceTolerance(),
      'favoriteTopics': _extractFavoriteTopics(),
      'prefersQuickConfirm': _learnedPreferences['quickConfirm']?.value == 'true',
    };

    debugPrint('[ConversationLearning] 学习结果: $conversationPrefs');
    debugPrint('[ConversationLearning] 用户ID: $userId - 学习结果已记录（内存中）');

    // TODO: 当UserProfileService扩展支持updateConversationPreferences时启用
    // await _profileService!.updateConversationPreferences(userId, conversationPrefs);
  }

  /// 清除学习数据
  void clearLearning() {
    _learnedPreferences.clear();
    _spendingAnalyzer.clear();
    _dialogStyleAnalyzer.clear();
  }

  // ==================== 内部方法 ====================

  /// 分析用户输入
  void _analyzeUserInput(String input) {
    // 检测用户是否喜欢简洁交互
    if (_isShortInput(input)) {
      _updatePreference('quickConfirm', 'true', 0.1);
    }

    // 检测用户是否喜欢详细描述
    if (_isDetailedInput(input)) {
      _updatePreference('detailedResponse', 'true', 0.1);
    }

    // 检测情感倾向
    final sentiment = _detectSentiment(input);
    if (sentiment != null) {
      _dialogStyleAnalyzer.addSentimentSample(sentiment);
    }

    // 检测常用表达
    _extractCommonPhrases(input);
  }

  /// 分析操作
  void _analyzeAction(VoiceAction action) {
    // 记录到消费模式分析器
    _spendingAnalyzer.addAction(action);

    // 分析操作类型偏好
    _updatePreference('preferredAction_${action.type}', 'true', 0.1);
  }

  /// 分析用户对响应的反应
  void _analyzeResponseReaction(ConversationTurn turn) {
    // 如果用户立即纠正，说明响应可能不准确
    if (_isCorrection(turn.userInput)) {
      _updatePreference('needsMoreConfirm', 'true', 0.2);
    }

    // 如果用户表示满意
    if (_isPositiveFeedback(turn.userInput)) {
      _updatePreference('satisfiedWithStyle', 'true', 0.15);
    }
  }

  /// 会话总结学习
  void _summarizeSessionLearning(List<ConversationTurn> turns) {
    // 计算平均输入长度
    final avgLength = turns
            .map((t) => t.userInput.length)
            .reduce((a, b) => a + b) /
        turns.length;

    if (avgLength < 10) {
      _updatePreference('prefersShortInput', 'true', 0.3);
    } else if (avgLength > 30) {
      _updatePreference('prefersDetailedInput', 'true', 0.3);
    }

    // 分析会话节奏
    _analyzeSessionPace(turns);
  }

  /// 分析会话节奏
  void _analyzeSessionPace(List<ConversationTurn> turns) {
    if (turns.length < 2) return;

    // 检测是否是快节奏用户（连续多次快速输入）
    var fastPaceCount = 0;
    for (var i = 1; i < turns.length; i++) {
      final interval = turns[i].timestamp.difference(turns[i - 1].timestamp);
      if (interval.inSeconds < 5) {
        fastPaceCount++;
      }
    }

    if (fastPaceCount > turns.length / 2) {
      _updatePreference('fastPaceUser', 'true', 0.2);
    }
  }

  /// 更新偏好
  void _updatePreference(String key, String value, double confidenceDelta) {
    final existing = _learnedPreferences[key];
    if (existing == null) {
      _learnedPreferences[key] = LearnedPreference(
        key: key,
        value: value,
        confidence: confidenceDelta,
        lastUpdated: DateTime.now(),
      );
    } else {
      _learnedPreferences[key] = LearnedPreference(
        key: key,
        value: value,
        confidence: (existing.confidence + confidenceDelta).clamp(0.0, 1.0),
        lastUpdated: DateTime.now(),
      );
    }
  }

  bool _isShortInput(String input) => input.length < 15;
  bool _isDetailedInput(String input) => input.length > 40;

  String? _detectSentiment(String input) {
    if (RegExp(r'(谢谢|不错|好的|棒|很好)').hasMatch(input)) {
      return 'positive';
    }
    if (RegExp(r'(不是|不对|错了|算了)').hasMatch(input)) {
      return 'negative';
    }
    return null;
  }

  bool _isCorrection(String input) {
    return RegExp(r'(不是|不对|错了|改成|改为)').hasMatch(input);
  }

  bool _isPositiveFeedback(String input) {
    return RegExp(r'(谢谢|好的|不错|很好|棒|对)').hasMatch(input);
  }

  void _extractCommonPhrases(String input) {
    // 提取用户常用的表达方式
    final phrases = <String>[];

    // 检测常用的记账表达
    if (RegExp(r'记一?笔').hasMatch(input)) {
      phrases.add('记一笔');
    }
    if (RegExp(r'花了|花费').hasMatch(input)) {
      phrases.add('花了');
    }
    if (RegExp(r'买了|购买').hasMatch(input)) {
      phrases.add('买了');
    }

    for (final phrase in phrases) {
      _updatePreference('commonPhrase_$phrase', 'true', 0.1);
    }
  }

  int _parseSilenceTolerance() {
    final pref = _learnedPreferences['fastPaceUser'];
    if (pref != null && pref.value == 'true' && pref.confidence > 0.5) {
      return 3; // 快节奏用户，较短的沉默容忍度
    }
    return 5; // 默认
  }

  List<String> _extractFavoriteTopics() {
    final topics = <String>[];

    // 从消费模式中提取
    final categories = _spendingAnalyzer.getTopCategories();
    topics.addAll(categories);

    return topics;
  }
}

/// 学习到的偏好
class LearnedPreference {
  /// 偏好键
  final String key;

  /// 偏好值
  final String value;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 最后更新时间
  final DateTime lastUpdated;

  const LearnedPreference({
    required this.key,
    required this.value,
    required this.confidence,
    required this.lastUpdated,
  });
}

/// 消费模式分析器
class SpendingPatternAnalyzer {
  final List<VoiceAction> _actions = [];
  final Map<String, int> _categoryCount = {};

  void addAction(VoiceAction action) {
    _actions.add(action);

    // 统计分类
    final category = action.data['category'] as String?;
    if (category != null) {
      _categoryCount[category] = (_categoryCount[category] ?? 0) + 1;
    }
  }

  /// 获取消费洞察
  List<String> getInsights() {
    final insights = <String>[];

    if (_actions.isEmpty) return insights;

    // 分析消费频率
    final expenseCount = _actions.where((a) => a.type == 'expense').length;
    final incomeCount = _actions.where((a) => a.type == 'income').length;

    if (expenseCount > 5) {
      insights.add('今天记了不少支出呢');
    }

    if (incomeCount > 0) {
      insights.add('有收入进账，不错哦');
    }

    // 分析常用分类
    if (_categoryCount.isNotEmpty) {
      final topCategory = _categoryCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      insights.add('你经常在$topCategory上花费');
    }

    return insights;
  }

  /// 获取高频分类
  List<String> getTopCategories({int limit = 3}) {
    if (_categoryCount.isEmpty) return [];

    final sorted = _categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  void clear() {
    _actions.clear();
    _categoryCount.clear();
  }
}

/// 对话风格分析器
class DialogStyleAnalyzer {
  final List<String> _sentimentSamples = [];
  VoiceDialogStyle? _recommendedStyle;

  void addSentimentSample(String sentiment) {
    _sentimentSamples.add(sentiment);
    _updateRecommendation();
  }

  void _updateRecommendation() {
    if (_sentimentSamples.length < 3) return;

    final positiveCount =
        _sentimentSamples.where((s) => s == 'positive').length;
    final negativeCount =
        _sentimentSamples.where((s) => s == 'negative').length;

    final positiveRatio = positiveCount / _sentimentSamples.length;
    final negativeRatio = negativeCount / _sentimentSamples.length;

    if (positiveRatio > 0.7) {
      _recommendedStyle = VoiceDialogStyle.playful;
    } else if (negativeRatio > 0.5) {
      // 负面情绪较多，使用支持鼓励风格
      _recommendedStyle = VoiceDialogStyle.supportive;
    } else if (positiveRatio < 0.3) {
      _recommendedStyle = VoiceDialogStyle.supportive;
    } else {
      _recommendedStyle = VoiceDialogStyle.casual;
    }
  }

  VoiceDialogStyle? get recommendedStyle => _recommendedStyle;

  void clear() {
    _sentimentSamples.clear();
    _recommendedStyle = null;
  }
}

/// 语音对话风格
enum VoiceDialogStyle {
  /// 专业正式
  professional,

  /// 活泼俏皮
  playful,

  /// 支持鼓励
  supportive,

  /// 数据驱动
  dataFocused,

  /// 随意轻松
  casual,

  /// 中性默认
  neutral,
}
