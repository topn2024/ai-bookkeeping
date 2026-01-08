import 'dart:async';

/// NPS调查服务
///
/// 提供Net Promoter Score调查功能，包括智能触发、数据采集、用户分群等
///
/// 对应实施方案：用户增长体系 - NPS监测与口碑优化（第28章）

// ==================== NPS 模型定义 ====================

/// NPS 评分类型
enum NPSCategory {
  /// 推荐者 (9-10分)
  promoter,

  /// 被动者 (7-8分)
  passive,

  /// 贬损者 (0-6分)
  detractor,
}

/// NPS 调查结果
class NPSSurveyResult {
  final String id;
  final String? userId;
  final int score;
  final String? feedback;
  final DateTime timestamp;
  final Map<String, dynamic>? context;
  final String? appVersion;
  final int? daysUsed;
  final int? transactionCount;

  NPSSurveyResult({
    required this.id,
    this.userId,
    required this.score,
    this.feedback,
    DateTime? timestamp,
    this.context,
    this.appVersion,
    this.daysUsed,
    this.transactionCount,
  }) : timestamp = timestamp ?? DateTime.now();

  NPSCategory get category {
    if (score >= 9) return NPSCategory.promoter;
    if (score >= 7) return NPSCategory.passive;
    return NPSCategory.detractor;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'score': score,
        'feedback': feedback,
        'timestamp': timestamp.toIso8601String(),
        'context': context,
        'app_version': appVersion,
        'days_used': daysUsed,
        'transaction_count': transactionCount,
        'category': category.name,
      };

  factory NPSSurveyResult.fromJson(Map<String, dynamic> json) {
    return NPSSurveyResult(
      id: json['id'],
      userId: json['user_id'],
      score: json['score'],
      feedback: json['feedback'],
      timestamp: DateTime.parse(json['timestamp']),
      context: json['context'],
      appVersion: json['app_version'],
      daysUsed: json['days_used'],
      transactionCount: json['transaction_count'],
    );
  }
}

/// NPS 统计数据
class NPSStatistics {
  final int totalResponses;
  final int promoterCount;
  final int passiveCount;
  final int detractorCount;
  final double npsScore;
  final double averageScore;
  final DateTime? lastSurveyDate;

  NPSStatistics({
    required this.totalResponses,
    required this.promoterCount,
    required this.passiveCount,
    required this.detractorCount,
    required this.npsScore,
    required this.averageScore,
    this.lastSurveyDate,
  });

  factory NPSStatistics.empty() => NPSStatistics(
        totalResponses: 0,
        promoterCount: 0,
        passiveCount: 0,
        detractorCount: 0,
        npsScore: 0,
        averageScore: 0,
      );

  factory NPSStatistics.fromResults(List<NPSSurveyResult> results) {
    if (results.isEmpty) return NPSStatistics.empty();

    int promoters = 0, passives = 0, detractors = 0;
    double totalScore = 0;

    for (final result in results) {
      totalScore += result.score;
      switch (result.category) {
        case NPSCategory.promoter:
          promoters++;
          break;
        case NPSCategory.passive:
          passives++;
          break;
        case NPSCategory.detractor:
          detractors++;
          break;
      }
    }

    final total = results.length;
    final nps = ((promoters - detractors) / total) * 100;

    return NPSStatistics(
      totalResponses: total,
      promoterCount: promoters,
      passiveCount: passives,
      detractorCount: detractors,
      npsScore: nps,
      averageScore: totalScore / total,
      lastSurveyDate: results.last.timestamp,
    );
  }
}

/// 触发条件配置
class NPSTriggerConfig {
  /// 最少使用天数
  final int minDaysUsed;

  /// 最少交易数量
  final int minTransactions;

  /// 距离上次调查的最少天数
  final int minDaysSinceLastSurvey;

  /// 每日最大显示次数
  final int maxDailyShows;

  /// 触发时机
  final Set<NPSTriggerMoment> triggerMoments;

  const NPSTriggerConfig({
    this.minDaysUsed = 7,
    this.minTransactions = 10,
    this.minDaysSinceLastSurvey = 90,
    this.maxDailyShows = 1,
    this.triggerMoments = const {
      NPSTriggerMoment.afterPositiveAction,
      NPSTriggerMoment.afterMilestone,
    },
  });
}

/// 触发时机
enum NPSTriggerMoment {
  /// 正向操作后（如成功记账）
  afterPositiveAction,

  /// 达成里程碑后
  afterMilestone,

  /// 应用启动时
  onAppLaunch,

  /// 完成特定功能后
  afterFeatureComplete,

  /// 手动触发
  manual,
}

// ==================== NPS 调查服务 ====================

/// NPS 调查服务
class NPSSurveyService {
  static final NPSSurveyService _instance = NPSSurveyService._internal();
  factory NPSSurveyService() => _instance;
  NPSSurveyService._internal();

  // 配置
  NPSTriggerConfig _config = const NPSTriggerConfig();
  bool _enabled = true;

  // 状态
  final List<NPSSurveyResult> _results = [];
  DateTime? _lastSurveyDate;
  DateTime? _lastShowDate;
  int _todayShowCount = 0;
  String? _currentUserId;

  // 用户行为数据
  int _daysUsed = 0;
  int _transactionCount = 0;
  String _appVersion = '2.0.0';

  // 回调
  void Function(NPSSurveyResult)? onSurveyCompleted;
  void Function(NPSCategory)? onCategoryDetermined;

  /// 初始化服务
  Future<void> initialize({
    NPSTriggerConfig? config,
    String? userId,
    String? appVersion,
  }) async {
    if (config != null) _config = config;
    _currentUserId = userId;
    if (appVersion != null) _appVersion = appVersion;

    // 加载历史数据
    await _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    // 实际实现中从持久化存储加载
  }

  /// 更新用户行为数据
  void updateUserBehavior({
    int? daysUsed,
    int? transactionCount,
  }) {
    if (daysUsed != null) _daysUsed = daysUsed;
    if (transactionCount != null) _transactionCount = transactionCount;
  }

  /// 检查是否应该显示调查
  bool shouldShowSurvey({
    NPSTriggerMoment moment = NPSTriggerMoment.afterPositiveAction,
  }) {
    if (!_enabled) return false;

    // 检查触发时机
    if (!_config.triggerMoments.contains(moment)) return false;

    // 检查使用天数
    if (_daysUsed < _config.minDaysUsed) return false;

    // 检查交易数量
    if (_transactionCount < _config.minTransactions) return false;

    // 检查距离上次调查的天数
    if (_lastSurveyDate != null) {
      final daysSinceLast = DateTime.now().difference(_lastSurveyDate!).inDays;
      if (daysSinceLast < _config.minDaysSinceLastSurvey) return false;
    }

    // 检查今日显示次数
    final today = DateTime.now();
    if (_lastShowDate != null &&
        _lastShowDate!.year == today.year &&
        _lastShowDate!.month == today.month &&
        _lastShowDate!.day == today.day) {
      if (_todayShowCount >= _config.maxDailyShows) return false;
    } else {
      _todayShowCount = 0;
    }

    return true;
  }

  /// 记录调查显示
  void recordSurveyShown() {
    _lastShowDate = DateTime.now();
    _todayShowCount++;
  }

  /// 提交调查结果
  Future<void> submitSurvey({
    required int score,
    String? feedback,
    Map<String, dynamic>? context,
  }) async {
    final result = NPSSurveyResult(
      id: 'nps_${DateTime.now().millisecondsSinceEpoch}',
      userId: _currentUserId,
      score: score,
      feedback: feedback,
      context: context,
      appVersion: _appVersion,
      daysUsed: _daysUsed,
      transactionCount: _transactionCount,
    );

    _results.add(result);
    _lastSurveyDate = DateTime.now();

    // 触发回调
    onSurveyCompleted?.call(result);
    onCategoryDetermined?.call(result.category);

    // 持久化存储
    await _saveResult(result);

    // 上报到服务器
    await _uploadResult(result);
  }

  Future<void> _saveResult(NPSSurveyResult result) async {
    // 实际实现中保存到本地存储
  }

  Future<void> _uploadResult(NPSSurveyResult result) async {
    // 实际实现中上传到服务器
  }

  /// 获取统计数据
  NPSStatistics getStatistics() {
    return NPSStatistics.fromResults(_results);
  }

  /// 获取用户分群
  NPSCategory? getUserCategory() {
    if (_results.isEmpty) return null;
    return _results.last.category;
  }

  /// 获取分群相关的后续动作建议
  List<String> getCategoryActions(NPSCategory category) {
    switch (category) {
      case NPSCategory.promoter:
        return [
          'invite_friends',      // 邀请好友
          'share_achievement',   // 分享成就
          'write_review',        // 撰写评价
          'join_community',      // 加入社区
        ];
      case NPSCategory.passive:
        return [
          'feature_survey',      // 功能调研
          'usage_tips',          // 使用技巧
          'premium_trial',       // 高级功能试用
        ];
      case NPSCategory.detractor:
        return [
          'feedback_form',       // 详细反馈表
          'support_contact',     // 客服联系
          'issue_report',        // 问题报告
        ];
    }
  }

  /// 根据评分获取后续问题
  String getFollowUpQuestion(int score) {
    if (score >= 9) {
      return '太棒了！是什么让您如此喜爱这款应用？';
    } else if (score >= 7) {
      return '感谢您的反馈！有什么可以让我们做得更好的地方吗？';
    } else {
      return '很抱歉没有达到您的期望。请告诉我们哪些方面需要改进？';
    }
  }

  /// 获取评分对应的感谢语
  String getThankYouMessage(int score) {
    if (score >= 9) {
      return '感谢您的认可！您的支持是我们前进的动力 ❤️';
    } else if (score >= 7) {
      return '感谢您的反馈！我们会努力做得更好';
    } else {
      return '感谢您的宝贵意见，我们会认真改进';
    }
  }

  /// 启用/禁用调查
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// 更新配置
  void updateConfig(NPSTriggerConfig config) {
    _config = config;
  }

  /// 重置（测试用）
  void reset() {
    _results.clear();
    _lastSurveyDate = null;
    _lastShowDate = null;
    _todayShowCount = 0;
  }
}

/// 全局 NPS 服务实例
final npsSurveyService = NPSSurveyService();
