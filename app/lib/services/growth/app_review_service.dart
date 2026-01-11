import 'dart:async';

/// 应用商店评价引导服务
///
/// 提供智能评价引导、好评时机检测、评价入口管理等功能
///
/// 对应实施方案：用户增长体系 - NPS监测与口碑优化（第28章）

// ==================== 评价状态模型 ====================

/// 评价状态
enum ReviewStatus {
  /// 未请求过
  notRequested,

  /// 已请求，用户未操作
  requested,

  /// 用户选择稍后
  postponed,

  /// 用户已评价
  reviewed,

  /// 用户拒绝评价
  declined,
}

/// 评价触发条件
class ReviewTriggerCondition {
  /// 最少使用天数
  final int minDaysUsed;

  /// 最少启动次数
  final int minLaunchCount;

  /// 最少交易数量
  final int minTransactions;

  /// 最少正向操作数（如成功记账）
  final int minPositiveActions;

  /// 距离上次请求的最少天数
  final int minDaysSinceLastRequest;

  /// 最大请求次数
  final int maxRequestCount;

  const ReviewTriggerCondition({
    this.minDaysUsed = 7,
    this.minLaunchCount = 5,
    this.minTransactions = 15,
    this.minPositiveActions = 10,
    this.minDaysSinceLastRequest = 30,
    this.maxRequestCount = 3,
  });
}

/// 用户行为数据
class UserBehaviorData {
  final int daysUsed;
  final int launchCount;
  final int transactionCount;
  final int positiveActionCount;
  final DateTime? lastPositiveAction;
  final bool hasRecentError;
  final double? averageSessionDuration;

  const UserBehaviorData({
    this.daysUsed = 0,
    this.launchCount = 0,
    this.transactionCount = 0,
    this.positiveActionCount = 0,
    this.lastPositiveAction,
    this.hasRecentError = false,
    this.averageSessionDuration,
  });

  /// 计算用户满意度评分 (0-100)
  int get satisfactionScore {
    int score = 0;

    // 使用天数贡献
    if (daysUsed >= 30) {
      score += 25;
    } else if (daysUsed >= 14) {
      score += 20;
    } else if (daysUsed >= 7) {
      score += 15;
    }

    // 交易数量贡献
    if (transactionCount >= 50) {
      score += 25;
    } else if (transactionCount >= 20) {
      score += 20;
    } else if (transactionCount >= 10) {
      score += 15;
    }

    // 正向操作贡献
    if (positiveActionCount >= 30) {
      score += 25;
    } else if (positiveActionCount >= 15) {
      score += 20;
    } else if (positiveActionCount >= 5) {
      score += 15;
    }

    // 会话时长贡献
    if (averageSessionDuration != null) {
      if (averageSessionDuration! >= 300) {
        score += 25; // 5分钟+
      } else if (averageSessionDuration! >= 120) {
        score += 20; // 2分钟+
      } else if (averageSessionDuration! >= 60) {
        score += 15; // 1分钟+
      }
    }

    // 错误扣分
    if (hasRecentError) score -= 20;

    return score.clamp(0, 100);
  }
}

// ==================== 评价引导服务 ====================

/// 应用评价引导服务
class AppReviewService {
  static final AppReviewService _instance = AppReviewService._internal();
  factory AppReviewService() => _instance;
  AppReviewService._internal();

  // 状态
  ReviewStatus _status = ReviewStatus.notRequested;
  int _requestCount = 0;
  DateTime? _lastRequestDate;
  DateTime? _installDate;

  // 配置
  ReviewTriggerCondition _condition = const ReviewTriggerCondition();
  UserBehaviorData _behaviorData = const UserBehaviorData();

  // 回调
  void Function()? onShowReviewPrompt;
  void Function(bool accepted)? onReviewDecision;
  void Function()? onReviewCompleted;

  /// 初始化
  Future<void> initialize() async {
    await _loadStoredData();
    _installDate ??= DateTime.now();
  }

  Future<void> _loadStoredData() async {
    // 实际实现中从持久化存储加载
  }

  Future<void> _saveData() async {
    // 实际实现中保存到持久化存储
  }

  /// 更新用户行为数据
  void updateBehaviorData(UserBehaviorData data) {
    _behaviorData = data;
  }

  /// 更新触发条件
  void updateTriggerCondition(ReviewTriggerCondition condition) {
    _condition = condition;
  }

  /// 检查是否应该显示评价请求
  bool shouldRequestReview() {
    // 已经评价过或拒绝过
    if (_status == ReviewStatus.reviewed || _status == ReviewStatus.declined) {
      return false;
    }

    // 达到最大请求次数
    if (_requestCount >= _condition.maxRequestCount) {
      return false;
    }

    // 检查距离上次请求的天数
    if (_lastRequestDate != null) {
      final daysSinceLastRequest =
          DateTime.now().difference(_lastRequestDate!).inDays;
      if (daysSinceLastRequest < _condition.minDaysSinceLastRequest) {
        return false;
      }
    }

    // 检查使用天数
    if (_behaviorData.daysUsed < _condition.minDaysUsed) {
      return false;
    }

    // 检查启动次数
    if (_behaviorData.launchCount < _condition.minLaunchCount) {
      return false;
    }

    // 检查交易数量
    if (_behaviorData.transactionCount < _condition.minTransactions) {
      return false;
    }

    // 检查正向操作数
    if (_behaviorData.positiveActionCount < _condition.minPositiveActions) {
      return false;
    }

    // 检查满意度评分
    if (_behaviorData.satisfactionScore < 70) {
      return false;
    }

    // 最近有错误不请求
    if (_behaviorData.hasRecentError) {
      return false;
    }

    return true;
  }

  /// 检查当前是否是好时机
  bool isGoodMomentForReview() {
    // 刚完成正向操作
    if (_behaviorData.lastPositiveAction != null) {
      final timeSinceAction =
          DateTime.now().difference(_behaviorData.lastPositiveAction!);
      if (timeSinceAction.inSeconds < 30) {
        return true;
      }
    }

    return false;
  }

  /// 请求评价（显示提示）
  Future<void> requestReview() async {
    if (!shouldRequestReview()) return;

    _requestCount++;
    _lastRequestDate = DateTime.now();
    _status = ReviewStatus.requested;

    await _saveData();

    // 触发显示评价提示
    onShowReviewPrompt?.call();
  }

  /// 用户选择评价
  Future<void> userAcceptedReview() async {
    _status = ReviewStatus.reviewed;
    await _saveData();

    onReviewDecision?.call(true);

    // 打开应用商店评价页面
    await _openAppStoreReview();

    onReviewCompleted?.call();
  }

  /// 用户选择稍后
  Future<void> userPostponedReview() async {
    _status = ReviewStatus.postponed;
    await _saveData();

    onReviewDecision?.call(false);
  }

  /// 用户拒绝评价
  Future<void> userDeclinedReview() async {
    _status = ReviewStatus.declined;
    await _saveData();

    onReviewDecision?.call(false);
  }

  /// 打开应用商店评价页面
  Future<void> _openAppStoreReview() async {
    // iOS: 使用 StoreKit 的 in-app review
    // Android: 使用 Google Play In-App Review API
    // 实际实现中调用平台相关代码
  }

  /// 使用系统内置评价弹窗 (iOS StoreKit / Android Play Core)
  Future<bool> requestSystemReview() async {
    if (!shouldRequestReview()) return false;

    _requestCount++;
    _lastRequestDate = DateTime.now();

    await _saveData();

    // 调用系统评价API
    // iOS: SKStoreReviewController.requestReview()
    // Android: ReviewManager.launchReviewFlow()
    return true;
  }

  /// 获取评价状态
  ReviewStatus get status => _status;

  /// 获取请求次数
  int get requestCount => _requestCount;

  /// 获取用户满意度评分
  int get userSatisfactionScore => _behaviorData.satisfactionScore;

  /// 重置（测试用）
  void reset() {
    _status = ReviewStatus.notRequested;
    _requestCount = 0;
    _lastRequestDate = null;
  }
}

// ==================== 成就与徽章服务 ====================

/// 成就类型
enum AchievementType {
  /// 记账相关
  bookkeeping,

  /// 预算相关
  budget,

  /// 存款相关
  saving,

  /// 连续性相关
  streak,

  /// 社交相关
  social,

  /// 里程碑
  milestone,
}

/// 成就定义
class Achievement {
  final String id;
  final String name;
  final String description;
  final AchievementType type;
  final String iconAsset;
  final int requiredValue;
  final bool isSecret;
  final Map<String, dynamic>? metadata;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.iconAsset,
    required this.requiredValue,
    this.isSecret = false,
    this.metadata,
  });
}

/// 用户成就记录
class UserAchievement {
  final String achievementId;
  final DateTime unlockedAt;
  final int value;
  final bool shared;

  UserAchievement({
    required this.achievementId,
    DateTime? unlockedAt,
    required this.value,
    this.shared = false,
  }) : unlockedAt = unlockedAt ?? DateTime.now();
}

/// 成就服务
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  // 成就定义
  final List<Achievement> _achievements = [
    // 记账成就
    const Achievement(
      id: 'first_transaction',
      name: '记账新手',
      description: '完成第一笔记账',
      type: AchievementType.bookkeeping,
      iconAsset: 'assets/achievements/first_transaction.png',
      requiredValue: 1,
    ),
    const Achievement(
      id: 'transactions_10',
      name: '记账爱好者',
      description: '累计记账10笔',
      type: AchievementType.bookkeeping,
      iconAsset: 'assets/achievements/transactions_10.png',
      requiredValue: 10,
    ),
    const Achievement(
      id: 'transactions_100',
      name: '记账达人',
      description: '累计记账100笔',
      type: AchievementType.bookkeeping,
      iconAsset: 'assets/achievements/transactions_100.png',
      requiredValue: 100,
    ),
    const Achievement(
      id: 'transactions_1000',
      name: '记账大师',
      description: '累计记账1000笔',
      type: AchievementType.bookkeeping,
      iconAsset: 'assets/achievements/transactions_1000.png',
      requiredValue: 1000,
    ),

    // 连续记账成就
    const Achievement(
      id: 'streak_7',
      name: '坚持一周',
      description: '连续7天记账',
      type: AchievementType.streak,
      iconAsset: 'assets/achievements/streak_7.png',
      requiredValue: 7,
    ),
    const Achievement(
      id: 'streak_30',
      name: '月度坚持',
      description: '连续30天记账',
      type: AchievementType.streak,
      iconAsset: 'assets/achievements/streak_30.png',
      requiredValue: 30,
    ),
    const Achievement(
      id: 'streak_100',
      name: '百日达人',
      description: '连续100天记账',
      type: AchievementType.streak,
      iconAsset: 'assets/achievements/streak_100.png',
      requiredValue: 100,
    ),
    const Achievement(
      id: 'streak_365',
      name: '年度传奇',
      description: '连续365天记账',
      type: AchievementType.streak,
      iconAsset: 'assets/achievements/streak_365.png',
      requiredValue: 365,
    ),

    // 预算成就
    const Achievement(
      id: 'budget_created',
      name: '预算规划师',
      description: '创建第一个预算',
      type: AchievementType.budget,
      iconAsset: 'assets/achievements/budget_created.png',
      requiredValue: 1,
    ),
    const Achievement(
      id: 'budget_achieved',
      name: '预算守护者',
      description: '连续3个月未超预算',
      type: AchievementType.budget,
      iconAsset: 'assets/achievements/budget_achieved.png',
      requiredValue: 3,
    ),

    // 存款成就
    const Achievement(
      id: 'saving_1000',
      name: '小小储蓄',
      description: '累计存款达到1000元',
      type: AchievementType.saving,
      iconAsset: 'assets/achievements/saving_1000.png',
      requiredValue: 1000,
    ),
    const Achievement(
      id: 'saving_10000',
      name: '万元户',
      description: '累计存款达到10000元',
      type: AchievementType.saving,
      iconAsset: 'assets/achievements/saving_10000.png',
      requiredValue: 10000,
    ),
    const Achievement(
      id: 'saving_100000',
      name: '小金库',
      description: '累计存款达到100000元',
      type: AchievementType.saving,
      iconAsset: 'assets/achievements/saving_100000.png',
      requiredValue: 100000,
    ),

    // 社交成就
    const Achievement(
      id: 'first_invite',
      name: '社交达人',
      description: '成功邀请第一位好友',
      type: AchievementType.social,
      iconAsset: 'assets/achievements/first_invite.png',
      requiredValue: 1,
    ),
    const Achievement(
      id: 'invites_5',
      name: '邀请大使',
      description: '成功邀请5位好友',
      type: AchievementType.social,
      iconAsset: 'assets/achievements/invites_5.png',
      requiredValue: 5,
    ),

    // 隐藏成就
    const Achievement(
      id: 'night_owl',
      name: '夜猫子',
      description: '在凌晨2-4点记账',
      type: AchievementType.milestone,
      iconAsset: 'assets/achievements/night_owl.png',
      requiredValue: 1,
      isSecret: true,
    ),
    const Achievement(
      id: 'early_bird',
      name: '早起鸟',
      description: '在早上5-6点记账',
      type: AchievementType.milestone,
      iconAsset: 'assets/achievements/early_bird.png',
      requiredValue: 1,
      isSecret: true,
    ),
  ];

  // 用户已解锁成就
  final Map<String, UserAchievement> _userAchievements = {};

  // 回调
  void Function(Achievement, UserAchievement)? onAchievementUnlocked;

  /// 获取所有成就
  List<Achievement> getAllAchievements({bool includeSecret = false}) {
    if (includeSecret) return _achievements;
    return _achievements.where((a) => !a.isSecret).toList();
  }

  /// 获取用户已解锁的成就
  List<Achievement> getUnlockedAchievements() {
    return _achievements
        .where((a) => _userAchievements.containsKey(a.id))
        .toList();
  }

  /// 获取用户未解锁的成就
  List<Achievement> getLockedAchievements({bool includeSecret = false}) {
    return _achievements
        .where((a) => !_userAchievements.containsKey(a.id))
        .where((a) => includeSecret || !a.isSecret)
        .toList();
  }

  /// 检查并解锁成就
  Future<List<Achievement>> checkAndUnlock({
    int? transactionCount,
    int? streakDays,
    int? budgetMonthsAchieved,
    double? totalSaving,
    int? inviteCount,
    DateTime? transactionTime,
  }) async {
    final unlockedNow = <Achievement>[];

    for (final achievement in _achievements) {
      if (_userAchievements.containsKey(achievement.id)) continue;

      bool shouldUnlock = false;
      int value = 0;

      switch (achievement.type) {
        case AchievementType.bookkeeping:
          if (transactionCount != null &&
              transactionCount >= achievement.requiredValue) {
            shouldUnlock = true;
            value = transactionCount;
          }
          break;

        case AchievementType.streak:
          if (streakDays != null && streakDays >= achievement.requiredValue) {
            shouldUnlock = true;
            value = streakDays;
          }
          break;

        case AchievementType.budget:
          if (budgetMonthsAchieved != null &&
              budgetMonthsAchieved >= achievement.requiredValue) {
            shouldUnlock = true;
            value = budgetMonthsAchieved;
          }
          break;

        case AchievementType.saving:
          if (totalSaving != null &&
              totalSaving >= achievement.requiredValue) {
            shouldUnlock = true;
            value = totalSaving.toInt();
          }
          break;

        case AchievementType.social:
          if (inviteCount != null &&
              inviteCount >= achievement.requiredValue) {
            shouldUnlock = true;
            value = inviteCount;
          }
          break;

        case AchievementType.milestone:
          if (transactionTime != null) {
            final hour = transactionTime.hour;
            if (achievement.id == 'night_owl' && hour >= 2 && hour < 4) {
              shouldUnlock = true;
              value = 1;
            } else if (achievement.id == 'early_bird' &&
                hour >= 5 &&
                hour < 6) {
              shouldUnlock = true;
              value = 1;
            }
          }
          break;
      }

      if (shouldUnlock) {
        final userAchievement = UserAchievement(
          achievementId: achievement.id,
          value: value,
        );
        _userAchievements[achievement.id] = userAchievement;
        unlockedNow.add(achievement);

        onAchievementUnlocked?.call(achievement, userAchievement);
      }
    }

    return unlockedNow;
  }

  /// 获取成就进度
  double getAchievementProgress(String achievementId, int currentValue) {
    final achievement = _achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw ArgumentError('Achievement not found: $achievementId'),
    );

    if (_userAchievements.containsKey(achievementId)) return 1.0;

    return (currentValue / achievement.requiredValue).clamp(0.0, 1.0);
  }

  /// 标记成就已分享
  void markAsShared(String achievementId) {
    final userAchievement = _userAchievements[achievementId];
    if (userAchievement != null) {
      _userAchievements[achievementId] = UserAchievement(
        achievementId: userAchievement.achievementId,
        unlockedAt: userAchievement.unlockedAt,
        value: userAchievement.value,
        shared: true,
      );
    }
  }

  /// 获取成就完成率
  double get completionRate {
    final total = _achievements.where((a) => !a.isSecret).length;
    final unlocked = _userAchievements.length;
    return total > 0 ? unlocked / total : 0;
  }

  /// 重置（测试用）
  void reset() {
    _userAchievements.clear();
  }
}

/// 全局服务实例
final appReviewService = AppReviewService();
final achievementService = AchievementService();
