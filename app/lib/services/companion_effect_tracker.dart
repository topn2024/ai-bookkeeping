import 'package:flutter/foundation.dart';

import 'companion_copywriting_service.dart';

/// 伙伴化效果追踪服务
///
/// 功能：
/// 1. 消息展示与交互追踪
/// 2. 用户反馈收集
/// 3. 效果指标计算
/// 4. A/B测试支持
class CompanionEffectTracker {
  static final CompanionEffectTracker _instance = CompanionEffectTracker._internal();
  factory CompanionEffectTracker() => _instance;
  CompanionEffectTracker._internal();

  final List<MessageInteraction> _interactions = [];
  final Map<String, MessageMetrics> _metricsCache = {};

  /// 记录消息展示
  void trackImpression(CompanionMessage message) {
    _interactions.add(MessageInteraction(
      messageId: message.id,
      type: InteractionType.impression,
      timestamp: DateTime.now(),
      sceneType: message.scene.type,
      emotionType: message.emotion.type,
    ));
    debugPrint('EffectTracker: Impression tracked for ${message.id}');
  }

  /// 记录用户点击
  void trackClick(CompanionMessage message) {
    _interactions.add(MessageInteraction(
      messageId: message.id,
      type: InteractionType.click,
      timestamp: DateTime.now(),
      sceneType: message.scene.type,
      emotionType: message.emotion.type,
    ));
  }

  /// 记录用户关闭
  void trackDismiss(CompanionMessage message, DismissReason reason) {
    _interactions.add(MessageInteraction(
      messageId: message.id,
      type: InteractionType.dismiss,
      timestamp: DateTime.now(),
      sceneType: message.scene.type,
      emotionType: message.emotion.type,
      metadata: {'reason': reason.name},
    ));
  }

  /// 记录用户反馈
  void trackFeedback(CompanionMessage message, UserFeedback feedback) {
    _interactions.add(MessageInteraction(
      messageId: message.id,
      type: InteractionType.feedback,
      timestamp: DateTime.now(),
      sceneType: message.scene.type,
      emotionType: message.emotion.type,
      metadata: {
        'rating': feedback.rating,
        'helpful': feedback.helpful,
        'comment': feedback.comment,
      },
    ));
  }

  /// 获取场景效果指标
  MessageMetrics getSceneMetrics(SceneType sceneType) {
    final key = 'scene_${sceneType.name}';
    if (_metricsCache.containsKey(key)) {
      return _metricsCache[key]!;
    }

    final sceneInteractions = _interactions
        .where((i) => i.sceneType == sceneType)
        .toList();

    final metrics = _calculateMetrics(sceneInteractions);
    _metricsCache[key] = metrics;
    return metrics;
  }

  /// 获取情感类型效果指标
  MessageMetrics getEmotionMetrics(EmotionType emotionType) {
    final key = 'emotion_${emotionType.name}';
    if (_metricsCache.containsKey(key)) {
      return _metricsCache[key]!;
    }

    final emotionInteractions = _interactions
        .where((i) => i.emotionType == emotionType)
        .toList();

    final metrics = _calculateMetrics(emotionInteractions);
    _metricsCache[key] = metrics;
    return metrics;
  }

  /// 获取整体效果指标
  MessageMetrics getOverallMetrics() {
    return _calculateMetrics(_interactions);
  }

  MessageMetrics _calculateMetrics(List<MessageInteraction> interactions) {
    final impressions = interactions
        .where((i) => i.type == InteractionType.impression)
        .length;
    final clicks = interactions
        .where((i) => i.type == InteractionType.click)
        .length;
    final dismisses = interactions
        .where((i) => i.type == InteractionType.dismiss)
        .length;
    final feedbacks = interactions
        .where((i) => i.type == InteractionType.feedback)
        .toList();

    double avgRating = 0;
    int helpfulCount = 0;

    for (final fb in feedbacks) {
      final rating = fb.metadata?['rating'] as int?;
      final helpful = fb.metadata?['helpful'] as bool?;
      if (rating != null) avgRating += rating;
      if (helpful == true) helpfulCount++;
    }

    if (feedbacks.isNotEmpty) {
      avgRating /= feedbacks.length;
    }

    return MessageMetrics(
      impressionCount: impressions,
      clickCount: clicks,
      dismissCount: dismisses,
      feedbackCount: feedbacks.length,
      clickThroughRate: impressions > 0 ? clicks / impressions : 0,
      dismissRate: impressions > 0 ? dismisses / impressions : 0,
      averageRating: avgRating,
      helpfulRate: feedbacks.isNotEmpty ? helpfulCount / feedbacks.length : 0,
    );
  }

  /// 清除缓存
  void clearCache() {
    _metricsCache.clear();
  }

  /// 导出数据（用于分析）
  List<Map<String, dynamic>> exportData() {
    return _interactions.map((i) => {
      'messageId': i.messageId,
      'type': i.type.name,
      'timestamp': i.timestamp.toIso8601String(),
      'sceneType': i.sceneType.name,
      'emotionType': i.emotionType.name,
      'metadata': i.metadata,
    }).toList();
  }
}

/// 消息交互记录
class MessageInteraction {
  final String messageId;
  final InteractionType type;
  final DateTime timestamp;
  final SceneType sceneType;
  final EmotionType emotionType;
  final Map<String, dynamic>? metadata;

  MessageInteraction({
    required this.messageId,
    required this.type,
    required this.timestamp,
    required this.sceneType,
    required this.emotionType,
    this.metadata,
  });
}

/// 交互类型
enum InteractionType {
  impression,  // 展示
  click,       // 点击
  dismiss,     // 关闭
  feedback,    // 反馈
}

/// 关闭原因
enum DismissReason {
  userClose,    // 用户主动关闭
  timeout,      // 超时自动关闭
  navigation,   // 页面跳转
  newMessage,   // 新消息替换
}

/// 用户反馈
class UserFeedback {
  final int? rating;      // 1-5评分
  final bool? helpful;    // 是否有帮助
  final String? comment;  // 文字反馈

  UserFeedback({this.rating, this.helpful, this.comment});
}

/// 消息效果指标
class MessageMetrics {
  final int impressionCount;
  final int clickCount;
  final int dismissCount;
  final int feedbackCount;
  final double clickThroughRate;
  final double dismissRate;
  final double averageRating;
  final double helpfulRate;

  MessageMetrics({
    required this.impressionCount,
    required this.clickCount,
    required this.dismissCount,
    required this.feedbackCount,
    required this.clickThroughRate,
    required this.dismissRate,
    required this.averageRating,
    required this.helpfulRate,
  });

  @override
  String toString() {
    return 'Metrics(impressions: $impressionCount, CTR: ${(clickThroughRate * 100).toStringAsFixed(1)}%, '
        'rating: ${averageRating.toStringAsFixed(1)})';
  }
}
