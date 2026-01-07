import 'package:flutter/material.dart';

/// NPS 调查类型
enum NPSSurveyType {
  /// 整体产品满意度
  overall,

  /// 特定功能满意度
  feature,

  /// 版本更新反馈
  update,

  /// 首次使用体验
  onboarding,

  /// 里程碑触发
  milestone,
}

extension NPSSurveyTypeExtension on NPSSurveyType {
  String get displayName {
    switch (this) {
      case NPSSurveyType.overall:
        return '整体满意度';
      case NPSSurveyType.feature:
        return '功能反馈';
      case NPSSurveyType.update:
        return '版本更新';
      case NPSSurveyType.onboarding:
        return '新用户体验';
      case NPSSurveyType.milestone:
        return '里程碑反馈';
    }
  }
}

/// NPS 评分等级
enum NPSCategory {
  /// 推荐者 (9-10分)
  promoter,

  /// 被动者 (7-8分)
  passive,

  /// 贬损者 (0-6分)
  detractor,
}

extension NPSCategoryExtension on NPSCategory {
  String get displayName {
    switch (this) {
      case NPSCategory.promoter:
        return '推荐者';
      case NPSCategory.passive:
        return '被动者';
      case NPSCategory.detractor:
        return '贬损者';
    }
  }

  Color get color {
    switch (this) {
      case NPSCategory.promoter:
        return Colors.green;
      case NPSCategory.passive:
        return Colors.amber;
      case NPSCategory.detractor:
        return Colors.red;
    }
  }

  /// 根据分数获取分类
  static NPSCategory fromScore(int score) {
    if (score >= 9) return NPSCategory.promoter;
    if (score >= 7) return NPSCategory.passive;
    return NPSCategory.detractor;
  }
}

/// NPS 调查响应
class NPSSurveyResponse {
  final String id;
  final NPSSurveyType surveyType;
  final int score;                    // 0-10 的 NPS 分数
  final String? feedback;             // 用户反馈文本
  final String? featureId;            // 特定功能ID（当surveyType为feature时）
  final String? appVersion;           // 应用版本号
  final Map<String, dynamic>? context; // 调查上下文数据
  final bool isAnonymous;             // 是否匿名提交
  final DateTime submittedAt;
  final DateTime createdAt;

  const NPSSurveyResponse({
    required this.id,
    required this.surveyType,
    required this.score,
    this.feedback,
    this.featureId,
    this.appVersion,
    this.context,
    this.isAnonymous = false,
    required this.submittedAt,
    required this.createdAt,
  });

  /// 获取 NPS 分类
  NPSCategory get category => NPSCategoryExtension.fromScore(score);

  /// 是否为推荐者
  bool get isPromoter => category == NPSCategory.promoter;

  /// 是否为贬损者
  bool get isDetractor => category == NPSCategory.detractor;

  /// 是否提供了反馈
  bool get hasFeedback => feedback != null && feedback!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'surveyType': surveyType.index,
      'score': score,
      'feedback': feedback,
      'featureId': featureId,
      'appVersion': appVersion,
      'context': context?.toString(),
      'isAnonymous': isAnonymous ? 1 : 0,
      'submittedAt': submittedAt.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory NPSSurveyResponse.fromMap(Map<String, dynamic> map) {
    return NPSSurveyResponse(
      id: map['id'] as String,
      surveyType: NPSSurveyType.values[map['surveyType'] as int],
      score: map['score'] as int,
      feedback: map['feedback'] as String?,
      featureId: map['featureId'] as String?,
      appVersion: map['appVersion'] as String?,
      context: null, // TODO: Parse from string if needed
      isAnonymous: map['isAnonymous'] == 1,
      submittedAt: DateTime.fromMillisecondsSinceEpoch(map['submittedAt'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// NPS 调查触发规则
class NPSSurveyTrigger {
  final String id;
  final NPSSurveyType surveyType;
  final String? triggeredBy;          // 触发条件描述
  final int minDaysSinceLastSurvey;   // 距上次调查的最小天数
  final int? minTransactionCount;     // 最小交易数要求
  final int? minUsageDays;            // 最小使用天数要求
  final String? specificFeature;      // 特定功能ID
  final bool isEnabled;
  final DateTime createdAt;

  const NPSSurveyTrigger({
    required this.id,
    required this.surveyType,
    this.triggeredBy,
    required this.minDaysSinceLastSurvey,
    this.minTransactionCount,
    this.minUsageDays,
    this.specificFeature,
    this.isEnabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'surveyType': surveyType.index,
      'triggeredBy': triggeredBy,
      'minDaysSinceLastSurvey': minDaysSinceLastSurvey,
      'minTransactionCount': minTransactionCount,
      'minUsageDays': minUsageDays,
      'specificFeature': specificFeature,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory NPSSurveyTrigger.fromMap(Map<String, dynamic> map) {
    return NPSSurveyTrigger(
      id: map['id'] as String,
      surveyType: NPSSurveyType.values[map['surveyType'] as int],
      triggeredBy: map['triggeredBy'] as String?,
      minDaysSinceLastSurvey: map['minDaysSinceLastSurvey'] as int,
      minTransactionCount: map['minTransactionCount'] as int?,
      minUsageDays: map['minUsageDays'] as int?,
      specificFeature: map['specificFeature'] as String?,
      isEnabled: map['isEnabled'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// NPS 统计摘要
class NPSStatistics {
  final int totalResponses;           // 总响应数
  final int promoterCount;            // 推荐者数
  final int passiveCount;             // 被动者数
  final int detractorCount;           // 贬损者数
  final double npsScore;              // NPS 得分 (-100 ~ 100)
  final double averageScore;          // 平均分数
  final int feedbackCount;            // 有反馈的响应数
  final DateTime? lastSurveyDate;     // 最后调查日期
  final Map<String, double>? npsScoreByFeature; // 各功能 NPS 得分

  const NPSStatistics({
    required this.totalResponses,
    required this.promoterCount,
    required this.passiveCount,
    required this.detractorCount,
    required this.npsScore,
    required this.averageScore,
    required this.feedbackCount,
    this.lastSurveyDate,
    this.npsScoreByFeature,
  });

  /// 推荐者比例
  double get promoterPercentage =>
      totalResponses > 0 ? promoterCount / totalResponses : 0;

  /// 贬损者比例
  double get detractorPercentage =>
      totalResponses > 0 ? detractorCount / totalResponses : 0;

  /// NPS 等级评价
  String get npsGrade {
    if (npsScore >= 70) return '世界级';
    if (npsScore >= 50) return '优秀';
    if (npsScore >= 30) return '良好';
    if (npsScore >= 0) return '一般';
    return '需要改进';
  }

  /// NPS 等级颜色
  Color get npsColor {
    if (npsScore >= 70) return Colors.green.shade700;
    if (npsScore >= 50) return Colors.green;
    if (npsScore >= 30) return Colors.lightGreen;
    if (npsScore >= 0) return Colors.amber;
    return Colors.red;
  }

  factory NPSStatistics.empty() {
    return const NPSStatistics(
      totalResponses: 0,
      promoterCount: 0,
      passiveCount: 0,
      detractorCount: 0,
      npsScore: 0,
      averageScore: 0,
      feedbackCount: 0,
    );
  }

  factory NPSStatistics.calculate(List<NPSSurveyResponse> responses) {
    if (responses.isEmpty) return NPSStatistics.empty();

    final promoters = responses.where((r) => r.isPromoter).length;
    final detractors = responses.where((r) => r.isDetractor).length;
    final total = responses.length;

    final promoterPct = promoters / total * 100;
    final detractorPct = detractors / total * 100;
    final nps = promoterPct - detractorPct;

    final avgScore = responses.map((r) => r.score).reduce((a, b) => a + b) / total;
    final feedbackCount = responses.where((r) => r.hasFeedback).length;

    return NPSStatistics(
      totalResponses: total,
      promoterCount: promoters,
      passiveCount: total - promoters - detractors,
      detractorCount: detractors,
      npsScore: nps,
      averageScore: avgScore,
      feedbackCount: feedbackCount,
      lastSurveyDate: responses.isNotEmpty
          ? responses.map((r) => r.submittedAt).reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    );
  }
}

/// 用户反馈意见
class UserFeedback {
  final String id;
  final FeedbackType type;
  final String content;
  final int? rating;                  // 可选评分 1-5
  final String? category;             // 反馈分类
  final String? screenshotPath;       // 截图路径
  final String? appVersion;
  final Map<String, dynamic>? deviceInfo;
  final FeedbackStatus status;
  final String? adminResponse;        // 管理员回复
  final DateTime? respondedAt;
  final DateTime submittedAt;

  const UserFeedback({
    required this.id,
    required this.type,
    required this.content,
    this.rating,
    this.category,
    this.screenshotPath,
    this.appVersion,
    this.deviceInfo,
    this.status = FeedbackStatus.pending,
    this.adminResponse,
    this.respondedAt,
    required this.submittedAt,
  });

  /// 是否已回复
  bool get hasResponse => adminResponse != null && adminResponse!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'content': content,
      'rating': rating,
      'category': category,
      'screenshotPath': screenshotPath,
      'appVersion': appVersion,
      'deviceInfo': deviceInfo?.toString(),
      'status': status.index,
      'adminResponse': adminResponse,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
      'submittedAt': submittedAt.millisecondsSinceEpoch,
    };
  }

  factory UserFeedback.fromMap(Map<String, dynamic> map) {
    return UserFeedback(
      id: map['id'] as String,
      type: FeedbackType.values[map['type'] as int],
      content: map['content'] as String,
      rating: map['rating'] as int?,
      category: map['category'] as String?,
      screenshotPath: map['screenshotPath'] as String?,
      appVersion: map['appVersion'] as String?,
      deviceInfo: null,
      status: FeedbackStatus.values[map['status'] as int],
      adminResponse: map['adminResponse'] as String?,
      respondedAt: map['respondedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['respondedAt'] as int)
          : null,
      submittedAt: DateTime.fromMillisecondsSinceEpoch(map['submittedAt'] as int),
    );
  }
}

/// 反馈类型
enum FeedbackType {
  /// Bug 报告
  bug,

  /// 功能建议
  suggestion,

  /// 使用问题
  question,

  /// 赞美/好评
  praise,

  /// 其他
  other,
}

extension FeedbackTypeExtension on FeedbackType {
  String get displayName {
    switch (this) {
      case FeedbackType.bug:
        return 'Bug报告';
      case FeedbackType.suggestion:
        return '功能建议';
      case FeedbackType.question:
        return '使用问题';
      case FeedbackType.praise:
        return '赞美好评';
      case FeedbackType.other:
        return '其他';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedbackType.bug:
        return Icons.bug_report;
      case FeedbackType.suggestion:
        return Icons.lightbulb;
      case FeedbackType.question:
        return Icons.help;
      case FeedbackType.praise:
        return Icons.thumb_up;
      case FeedbackType.other:
        return Icons.chat;
    }
  }
}

/// 反馈状态
enum FeedbackStatus {
  /// 待处理
  pending,

  /// 处理中
  processing,

  /// 已回复
  replied,

  /// 已解决
  resolved,

  /// 已关闭
  closed,
}

extension FeedbackStatusExtension on FeedbackStatus {
  String get displayName {
    switch (this) {
      case FeedbackStatus.pending:
        return '待处理';
      case FeedbackStatus.processing:
        return '处理中';
      case FeedbackStatus.replied:
        return '已回复';
      case FeedbackStatus.resolved:
        return '已解决';
      case FeedbackStatus.closed:
        return '已关闭';
    }
  }

  Color get color {
    switch (this) {
      case FeedbackStatus.pending:
        return Colors.grey;
      case FeedbackStatus.processing:
        return Colors.blue;
      case FeedbackStatus.replied:
        return Colors.orange;
      case FeedbackStatus.resolved:
        return Colors.green;
      case FeedbackStatus.closed:
        return Colors.grey.shade700;
    }
  }
}
