import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 伙伴化文案生成服务
///
/// 功能：
/// 1. 场景识别与情感分析
/// 2. 动态文案生成与缓存
/// 3. 预生成文案库（离线支持）
/// 4. 个性化文案风格
/// 5. 频率控制与用户偏好
class CompanionCopywritingService {
  final SceneRecognizer _sceneRecognizer;
  final EmotionAnalyzer _emotionAnalyzer;
  final CopywritingCachePool _cachePool;
  final PreGeneratedCopyLibrary _copyLibrary;
  final CompanionPreferences _preferences;

  CompanionCopywritingService({
    SceneRecognizer? sceneRecognizer,
    EmotionAnalyzer? emotionAnalyzer,
    CopywritingCachePool? cachePool,
    PreGeneratedCopyLibrary? copyLibrary,
    CompanionPreferences? preferences,
  })  : _sceneRecognizer = sceneRecognizer ?? SceneRecognizer(),
        _emotionAnalyzer = emotionAnalyzer ?? EmotionAnalyzer(),
        _cachePool = cachePool ?? CopywritingCachePool(),
        _copyLibrary = copyLibrary ?? PreGeneratedCopyLibrary(),
        _preferences = preferences ?? CompanionPreferences();

  /// 生成伙伴化文案
  Future<CompanionMessage?> generateMessage({
    required CompanionTrigger trigger,
    Map<String, dynamic>? context,
    String? userId,
  }) async {
    // 1. 检查用户偏好（是否开启、是否静音模式）
    if (!await _preferences.isCompanionEnabled(userId)) {
      return null;
    }

    if (await _preferences.isQuietMode(userId)) {
      return null;
    }

    // 2. 识别场景
    final scene = await _sceneRecognizer.recognize(trigger, context);

    // 3. 分析情感倾向
    final emotion = await _emotionAnalyzer.analyze(scene, context);

    // 4. 尝试从缓存获取
    final cachedMessage = _cachePool.get(scene, emotion);
    if (cachedMessage != null) {
      return cachedMessage.copyWith(
        generatedAt: DateTime.now(),
        isFromCache: true,
      );
    }

    // 5. 从预生成库获取
    final copy = _copyLibrary.getCopy(scene, emotion);
    if (copy == null) {
      debugPrint('No copy found for scene: ${scene.type}, emotion: ${emotion.type}');
      return null;
    }

    // 6. 个性化处理
    final personalizedCopy = await _personalizeCopy(copy, context, userId);

    // 7. 创建消息
    final message = CompanionMessage(
      id: _generateMessageId(),
      content: personalizedCopy,
      scene: scene,
      emotion: emotion,
      trigger: trigger,
      generatedAt: DateTime.now(),
      priority: _calculatePriority(scene, emotion),
    );

    // 8. 加入缓存
    _cachePool.put(scene, emotion, message);

    return message;
  }

  /// 获取欢迎语
  Future<CompanionMessage?> getWelcomeMessage({
    String? userId,
    DateTime? lastActiveTime,
  }) async {
    final daysSinceLastActive = lastActiveTime != null
        ? DateTime.now().difference(lastActiveTime).inDays
        : 0;

    CompanionScene scene;
    if (daysSinceLastActive == 0) {
      scene = CompanionScene(
        type: SceneType.dailyGreeting,
        timeOfDay: _getTimeOfDay(),
      );
    } else if (daysSinceLastActive <= 3) {
      scene = CompanionScene(
        type: SceneType.returnAfterBreak,
        metadata: {'daysSinceLastActive': daysSinceLastActive},
      );
    } else {
      scene = CompanionScene(
        type: SceneType.longTimeNoSee,
        metadata: {'daysSinceLastActive': daysSinceLastActive},
      );
    }

    return generateMessage(
      trigger: CompanionTrigger.appOpen,
      context: {
        'scene': scene,
        'daysSinceLastActive': daysSinceLastActive,
      },
      userId: userId,
    );
  }

  /// 获取记账完成鼓励语
  Future<CompanionMessage?> getRecordCompletionMessage({
    required double amount,
    required String category,
    int? consecutiveDays,
    String? userId,
  }) async {
    final scene = CompanionScene(
      type: SceneType.recordCompletion,
      metadata: {
        'amount': amount,
        'category': category,
        'consecutiveDays': consecutiveDays,
      },
    );

    return generateMessage(
      trigger: CompanionTrigger.recordComplete,
      context: {
        'scene': scene,
        'amount': amount,
        'category': category,
        'consecutiveDays': consecutiveDays,
      },
      userId: userId,
    );
  }

  /// 获取预算预警文案
  Future<CompanionMessage?> getBudgetAlertMessage({
    required String vaultName,
    required double remaining,
    required double total,
    required int daysLeft,
    String? userId,
  }) async {
    final usagePercent = (total - remaining) / total;

    SceneType sceneType;
    if (usagePercent >= 1.0) {
      sceneType = SceneType.budgetExceeded;
    } else if (usagePercent >= 0.9) {
      sceneType = SceneType.budgetCritical;
    } else if (usagePercent >= 0.8) {
      sceneType = SceneType.budgetWarning;
    } else {
      sceneType = SceneType.budgetReminder;
    }

    final scene = CompanionScene(
      type: sceneType,
      metadata: {
        'vaultName': vaultName,
        'remaining': remaining,
        'total': total,
        'usagePercent': usagePercent,
        'daysLeft': daysLeft,
      },
    );

    return generateMessage(
      trigger: CompanionTrigger.budgetAlert,
      context: {
        'scene': scene,
        'vaultName': vaultName,
        'remaining': remaining,
        'total': total,
        'daysLeft': daysLeft,
      },
      userId: userId,
    );
  }

  /// 获取钱龄变化文案
  Future<CompanionMessage?> getMoneyAgeMessage({
    required double previousAge,
    required double currentAge,
    required String healthLevel,
    String? userId,
  }) async {
    final change = currentAge - previousAge;

    SceneType sceneType;
    if (change < -5) {
      sceneType = SceneType.moneyAgeImproved;
    } else if (change > 5) {
      sceneType = SceneType.moneyAgeDeclined;
    } else {
      sceneType = SceneType.moneyAgeStable;
    }

    final scene = CompanionScene(
      type: sceneType,
      metadata: {
        'previousAge': previousAge,
        'currentAge': currentAge,
        'change': change,
        'healthLevel': healthLevel,
      },
    );

    return generateMessage(
      trigger: CompanionTrigger.moneyAgeChange,
      context: {
        'scene': scene,
        'previousAge': previousAge,
        'currentAge': currentAge,
        'healthLevel': healthLevel,
      },
      userId: userId,
    );
  }

  /// 获取成就达成文案
  Future<CompanionMessage?> getAchievementMessage({
    required String achievementId,
    required String achievementName,
    required String description,
    String? userId,
  }) async {
    final scene = CompanionScene(
      type: SceneType.achievementUnlocked,
      metadata: {
        'achievementId': achievementId,
        'achievementName': achievementName,
        'description': description,
      },
    );

    return generateMessage(
      trigger: CompanionTrigger.achievement,
      context: {
        'scene': scene,
        'achievementName': achievementName,
      },
      userId: userId,
    );
  }

  /// 个性化文案处理
  Future<String> _personalizeCopy(
    String copy,
    Map<String, dynamic>? context,
    String? userId,
  ) async {
    var result = copy;

    // 替换变量
    if (context != null) {
      context.forEach((key, value) {
        result = result.replaceAll('{$key}', value.toString());
      });
    }

    // 获取用户称呼
    final nickname = await _preferences.getNickname(userId);
    if (nickname != null) {
      result = result.replaceAll('{nickname}', nickname);
    } else {
      result = result.replaceAll('{nickname}', '');
      result = result.replaceAll('，{nickname}', '');
    }

    // 时间相关替换
    result = result.replaceAll('{timeGreeting}', _getTimeGreeting());

    return result.trim();
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }

  TimeOfDay _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 6) return TimeOfDay.lateNight;
    if (hour < 12) return TimeOfDay.morning;
    if (hour < 18) return TimeOfDay.afternoon;
    if (hour < 22) return TimeOfDay.evening;
    return TimeOfDay.lateNight;
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  MessagePriority _calculatePriority(CompanionScene scene, EmotionContext emotion) {
    // 成就和里程碑优先级最高
    if (scene.type == SceneType.achievementUnlocked ||
        scene.type == SceneType.milestone) {
      return MessagePriority.high;
    }

    // 预算超支需要关注
    if (scene.type == SceneType.budgetExceeded ||
        scene.type == SceneType.budgetCritical) {
      return MessagePriority.high;
    }

    // 鼓励和正面反馈中等优先级
    if (emotion.type == EmotionType.encouraging ||
        emotion.type == EmotionType.celebrating) {
      return MessagePriority.medium;
    }

    return MessagePriority.low;
  }
}

// ==================== 场景识别器 ====================

/// 场景识别器
class SceneRecognizer {
  /// 识别当前场景
  Future<CompanionScene> recognize(
    CompanionTrigger trigger,
    Map<String, dynamic>? context,
  ) async {
    // 如果上下文中已有场景，直接返回
    if (context?['scene'] is CompanionScene) {
      return context!['scene'] as CompanionScene;
    }

    // 根据触发器推断场景
    switch (trigger) {
      case CompanionTrigger.appOpen:
        return _recognizeAppOpenScene(context);
      case CompanionTrigger.recordComplete:
        return _recognizeRecordScene(context);
      case CompanionTrigger.budgetAlert:
        return _recognizeBudgetScene(context);
      case CompanionTrigger.budgetAchieved:
        return CompanionScene(type: SceneType.budgetAchieved, metadata: context);
      case CompanionTrigger.moneyAgeChange:
        return _recognizeMoneyAgeScene(context);
      case CompanionTrigger.achievement:
        return CompanionScene(type: SceneType.achievementUnlocked);
      case CompanionTrigger.milestone:
        return CompanionScene(type: SceneType.milestone);
      case CompanionTrigger.streak:
        return _recognizeStreakScene(context);
      case CompanionTrigger.insight:
        return CompanionScene(type: SceneType.insightDiscovery);
      case CompanionTrigger.savingsGoal:
        return _recognizeSavingsGoalScene(context);
      case CompanionTrigger.specialDate:
        return CompanionScene(type: SceneType.specialDate, metadata: context);
      case CompanionTrigger.scheduled:
        return _recognizeScheduledScene(context);
      case CompanionTrigger.manual:
        return CompanionScene(type: SceneType.userRequested);
    }
  }

  CompanionScene _recognizeSavingsGoalScene(Map<String, dynamic>? context) {
    final progress = context?['progress'] as double? ?? 0;

    if (progress >= 1.0) {
      return CompanionScene(type: SceneType.savingsGoalAchieved, metadata: context);
    } else if (progress >= 0.5) {
      return CompanionScene(type: SceneType.savingsGoalHalfway, metadata: context);
    }

    return CompanionScene(type: SceneType.savingsGoalProgress, metadata: context);
  }

  CompanionScene _recognizeScheduledScene(Map<String, dynamic>? context) {
    final scheduleType = context?['scheduleType'] as String?;

    if (scheduleType == 'evening') {
      return CompanionScene(type: SceneType.eveningSummary, metadata: context);
    }

    return CompanionScene(type: SceneType.scheduledReminder, metadata: context);
  }

  CompanionScene _recognizeAppOpenScene(Map<String, dynamic>? context) {
    final hour = DateTime.now().hour;
    TimeOfDay timeOfDay;

    if (hour < 6) {
      timeOfDay = TimeOfDay.lateNight;
    } else if (hour < 12) {
      timeOfDay = TimeOfDay.morning;
    } else if (hour < 18) {
      timeOfDay = TimeOfDay.afternoon;
    } else if (hour < 22) {
      timeOfDay = TimeOfDay.evening;
    } else {
      timeOfDay = TimeOfDay.lateNight;
    }

    return CompanionScene(
      type: SceneType.dailyGreeting,
      timeOfDay: timeOfDay,
      metadata: context,
    );
  }

  CompanionScene _recognizeRecordScene(Map<String, dynamic>? context) {
    final consecutiveDays = context?['consecutiveDays'] as int? ?? 0;

    if (consecutiveDays >= 30) {
      return CompanionScene(
        type: SceneType.milestone,
        metadata: {'type': 'streak', 'days': consecutiveDays},
      );
    } else if (consecutiveDays >= 7) {
      return CompanionScene(
        type: SceneType.streakContinued,
        metadata: {'days': consecutiveDays},
      );
    }

    return CompanionScene(
      type: SceneType.recordCompletion,
      metadata: context,
    );
  }

  CompanionScene _recognizeBudgetScene(Map<String, dynamic>? context) {
    final usagePercent = context?['usagePercent'] as double? ?? 0;

    if (usagePercent >= 1.0) {
      return CompanionScene(type: SceneType.budgetExceeded, metadata: context);
    } else if (usagePercent >= 0.9) {
      return CompanionScene(type: SceneType.budgetCritical, metadata: context);
    } else if (usagePercent >= 0.8) {
      return CompanionScene(type: SceneType.budgetWarning, metadata: context);
    }

    return CompanionScene(type: SceneType.budgetReminder, metadata: context);
  }

  CompanionScene _recognizeMoneyAgeScene(Map<String, dynamic>? context) {
    final change = context?['change'] as double? ?? 0;

    if (change < -5) {
      return CompanionScene(type: SceneType.moneyAgeImproved, metadata: context);
    } else if (change > 5) {
      return CompanionScene(type: SceneType.moneyAgeDeclined, metadata: context);
    }

    return CompanionScene(type: SceneType.moneyAgeStable, metadata: context);
  }

  CompanionScene _recognizeStreakScene(Map<String, dynamic>? context) {
    final days = context?['days'] as int? ?? 0;

    if (days == 7 || days == 30 || days == 100 || days == 365) {
      return CompanionScene(
        type: SceneType.milestone,
        metadata: {'type': 'streak', 'days': days},
      );
    }

    return CompanionScene(
      type: SceneType.streakContinued,
      metadata: context,
    );
  }
}

// ==================== 情感分析器 ====================

/// 情感分析器
class EmotionAnalyzer {
  /// 分析情感倾向
  Future<EmotionContext> analyze(
    CompanionScene scene,
    Map<String, dynamic>? context,
  ) async {
    // 根据场景类型确定基础情感
    switch (scene.type) {
      // 积极场景 - 庆祝
      case SceneType.achievementUnlocked:
      case SceneType.milestone:
        return EmotionContext(
          type: EmotionType.celebrating,
          intensity: EmotionIntensity.high,
        );

      // 积极场景 - 鼓励
      case SceneType.recordCompletion:
      case SceneType.streakContinued:
      case SceneType.moneyAgeImproved:
        return EmotionContext(
          type: EmotionType.encouraging,
          intensity: EmotionIntensity.medium,
        );

      // 中性场景 - 友好
      case SceneType.dailyGreeting:
      case SceneType.moneyAgeStable:
      case SceneType.scheduledReminder:
        return _analyzeGreetingEmotion(scene);

      // 关注场景 - 关心
      case SceneType.budgetWarning:
      case SceneType.budgetReminder:
        return EmotionContext(
          type: EmotionType.caring,
          intensity: EmotionIntensity.medium,
        );

      // 紧急场景 - 担忧但支持
      case SceneType.budgetCritical:
      case SceneType.budgetExceeded:
      case SceneType.moneyAgeDeclined:
        return EmotionContext(
          type: EmotionType.supportive,
          intensity: EmotionIntensity.high,
        );

      // 回归场景 - 温暖
      case SceneType.returnAfterBreak:
      case SceneType.longTimeNoSee:
        return EmotionContext(
          type: EmotionType.welcoming,
          intensity: EmotionIntensity.medium,
        );

      default:
        return EmotionContext(
          type: EmotionType.neutral,
          intensity: EmotionIntensity.low,
        );
    }
  }

  EmotionContext _analyzeGreetingEmotion(CompanionScene scene) {
    // 根据时间段调整情感
    switch (scene.timeOfDay) {
      case TimeOfDay.morning:
        return EmotionContext(
          type: EmotionType.energetic,
          intensity: EmotionIntensity.medium,
        );
      case TimeOfDay.afternoon:
        return EmotionContext(
          type: EmotionType.friendly,
          intensity: EmotionIntensity.low,
        );
      case TimeOfDay.evening:
        return EmotionContext(
          type: EmotionType.relaxed,
          intensity: EmotionIntensity.low,
        );
      case TimeOfDay.lateNight:
        return EmotionContext(
          type: EmotionType.caring,
          intensity: EmotionIntensity.medium,
        );
      default:
        return EmotionContext(
          type: EmotionType.friendly,
          intensity: EmotionIntensity.low,
        );
    }
  }
}

// ==================== 文案缓存池 ====================

/// 动态文案缓存池
class CopywritingCachePool {
  final Map<String, _CachedMessage> _cache = {};
  final int maxSize;
  final Duration ttl;

  CopywritingCachePool({
    this.maxSize = 100,
    this.ttl = const Duration(hours: 1),
  });

  String _generateKey(CompanionScene scene, EmotionContext emotion) {
    return '${scene.type.name}_${emotion.type.name}_${scene.timeOfDay?.name ?? "any"}';
  }

  CompanionMessage? get(CompanionScene scene, EmotionContext emotion) {
    final key = _generateKey(scene, emotion);
    final cached = _cache[key];

    if (cached == null) return null;

    // 检查是否过期
    if (DateTime.now().difference(cached.cachedAt) > ttl) {
      _cache.remove(key);
      return null;
    }

    // 随机决定是否使用缓存（避免重复）
    if (Random().nextDouble() > 0.7) {
      return null;
    }

    return cached.message;
  }

  void put(CompanionScene scene, EmotionContext emotion, CompanionMessage message) {
    // 清理过期缓存
    _cleanExpired();

    // 检查容量
    if (_cache.length >= maxSize) {
      _evictOldest();
    }

    final key = _generateKey(scene, emotion);
    _cache[key] = _CachedMessage(
      message: message,
      cachedAt: DateTime.now(),
    );
  }

  void _cleanExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, cached) => now.difference(cached.cachedAt) > ttl);
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.cachedAt.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.cachedAt;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  void clear() {
    _cache.clear();
  }
}

class _CachedMessage {
  final CompanionMessage message;
  final DateTime cachedAt;

  _CachedMessage({
    required this.message,
    required this.cachedAt,
  });
}

// ==================== 预生成文案库 ====================

/// 预生成文案库（支持离线使用）
class PreGeneratedCopyLibrary {
  // 文案库 - 按场景和情感组织
  static const Map<SceneType, Map<EmotionType, List<String>>> _copyLibrary = {
    // 每日问候
    SceneType.dailyGreeting: {
      EmotionType.energetic: [
        '{timeGreeting}！新的一天，新的开始，记得记录今天的收支哦～',
        '{timeGreeting}！元气满满的一天开始了，财务管理从点滴做起！',
        '{timeGreeting}！今天也要做一个精打细算的理财达人！',
      ],
      EmotionType.friendly: [
        '{timeGreeting}！又见面啦，让我陪你一起管好钱袋子～',
        '{timeGreeting}！我在这里等你记账呢，有什么新的消费吗？',
      ],
      EmotionType.relaxed: [
        '{timeGreeting}！辛苦一天了，记完账就好好休息吧～',
        '{timeGreeting}！来记录一下今天的消费，然后放松一下～',
      ],
      EmotionType.caring: [
        '夜深了，还在忙吗？记得照顾好自己，财务的事明天再说也行～',
        '这么晚还在记账，真是勤劳！不过也别太累了哦～',
      ],
    },

    // 记账完成
    SceneType.recordCompletion: {
      EmotionType.encouraging: [
        '记录成功！每一笔都是对财务的用心管理～',
        '又完成一笔记录！积少成多，你的理财习惯正在养成中～',
        '太棒了！坚持记账的你，一定能实现财务目标！',
        '记账完成！你离财务自由又近了一步～',
        '好的！这笔消费已经记下了，继续保持这个好习惯！',
      ],
      EmotionType.celebrating: [
        '完美！连续记账{consecutiveDays}天了，给自己点个赞！',
        '厉害！你已经是记账小能手了，继续加油！',
      ],
    },

    // 连续记账
    SceneType.streakContinued: {
      EmotionType.encouraging: [
        '连续记账{days}天！坚持就是胜利，继续保持！',
        '已经坚持{days}天了，你的自律让人佩服！',
        '{days}天的坚持，你的理财习惯正在扎根！',
      ],
      EmotionType.celebrating: [
        '哇！连续{days}天记账，你太厉害了！',
        '恭喜！{days}天的坚持，你已经是理财达人了！',
      ],
    },

    // 里程碑
    SceneType.milestone: {
      EmotionType.celebrating: [
        '重大里程碑！连续记账{days}天，这是了不起的成就！',
        '太棒了！{days}天的坚持，你创造了属于自己的记录！',
        '恭喜达成{days}天连续记账成就！你是最棒的！',
      ],
    },

    // 成就解锁
    SceneType.achievementUnlocked: {
      EmotionType.celebrating: [
        '叮！解锁新成就「{achievementName}」！你真是太厉害了！',
        '恭喜获得「{achievementName}」成就！继续加油！',
        '成就达成！「{achievementName}」已收入囊中！',
      ],
    },

    // 预算提醒
    SceneType.budgetReminder: {
      EmotionType.caring: [
        '{vaultName}预算还剩{remaining}元，本月还有{daysLeft}天，合理安排哦～',
        '温馨提示：{vaultName}预算剩余{remaining}元，继续保持理性消费～',
      ],
    },

    // 预算预警
    SceneType.budgetWarning: {
      EmotionType.caring: [
        '{vaultName}预算已用80%，剩余{remaining}元，注意控制一下～',
        '注意！{vaultName}预算快用完了，还有{daysLeft}天，悠着点花～',
      ],
      EmotionType.supportive: [
        '{vaultName}预算使用较多，我们一起想办法省一省？',
      ],
    },

    // 预算紧急
    SceneType.budgetCritical: {
      EmotionType.supportive: [
        '{vaultName}预算只剩{remaining}元了，最后{daysLeft}天，我们一起加油！',
        '预算紧张了，但别担心，我帮你想想办法～',
      ],
    },

    // 预算超支
    SceneType.budgetExceeded: {
      EmotionType.supportive: [
        '{vaultName}预算超支了，不过没关系，我们下个月调整一下～',
        '超支了也别灰心，重要的是发现问题并改进，我陪你一起！',
        '这个月{vaultName}超了一点，下个月我们一起努力控制～',
      ],
    },

    // 钱龄提升
    SceneType.moneyAgeImproved: {
      EmotionType.encouraging: [
        '太棒了！你的钱龄从{previousAge}天降到了{currentAge}天，钱更有活力了！',
        '钱龄降低了！说明你的资金周转更健康了，继续保持！',
        '进步明显！钱龄改善意味着你的理财更有效率了～',
      ],
      EmotionType.celebrating: [
        '恭喜！钱龄大幅提升，你的财务状况越来越好了！',
      ],
    },

    // 钱龄稳定
    SceneType.moneyAgeStable: {
      EmotionType.friendly: [
        '钱龄保持稳定，当前{currentAge}天，财务状况良好～',
        '钱龄平稳，说明你的收支管理得不错！',
      ],
    },

    // 钱龄下降
    SceneType.moneyAgeDeclined: {
      EmotionType.supportive: [
        '钱龄上升了一些，可能最近开销大了，我们一起看看怎么优化？',
        '钱龄变化是正常的，重要的是了解原因并做出调整～',
        '别担心钱龄波动，这是很正常的，我们可以一起分析一下～',
      ],
    },

    // 久别重逢
    SceneType.returnAfterBreak: {
      EmotionType.welcoming: [
        '好久不见！{daysSinceLastActive}天了，欢迎回来继续记账之旅～',
        '终于等到你回来了！不管多久，我都在这里等你～',
        '欢迎回来！让我们一起继续财务管理的旅程吧！',
      ],
    },

    // 长时间未见
    SceneType.longTimeNoSee: {
      EmotionType.welcoming: [
        '哇，{daysSinceLastActive}天没见了！欢迎回来！让我们重新开始吧～',
        '好久不见！不管离开多久，重新开始永远不晚～',
        '终于回来了！我一直在这里等你，准备好继续了吗？',
      ],
    },

    // 洞察发现
    SceneType.insightDiscovery: {
      EmotionType.encouraging: [
        '发现一个有趣的洞察！你的消费模式在悄悄改变呢～',
        '我发现了一些值得关注的消费趋势，要看看吗？',
      ],
      EmotionType.curious: [
        '嘿，我发现了一些有趣的数据，想不想看看？',
        '你的消费数据里藏着一些小秘密，要揭晓吗？',
      ],
    },

    // 晚间总结（新增）
    SceneType.eveningSummary: {
      EmotionType.relaxed: [
        '今天辛苦了！来看看今天的收支情况吧～',
        '一天结束了，让我们回顾一下今天的财务状况～',
        '晚上好！今天花了{todaySpent}元，一起看看明细？',
      ],
      EmotionType.caring: [
        '忙碌的一天结束了，记得好好休息～今天的账已经帮你整理好了',
        '夜深了，今天的财务小结已准备好，明天继续加油！',
      ],
    },

    // 预算达成（新增）
    SceneType.budgetAchieved: {
      EmotionType.celebrating: [
        '太厉害了！这个月{vaultName}预算完美达成！',
        '恭喜！你成功守住了{vaultName}的预算，这是了不起的成就！',
        '月末预算达成！你的自律让人佩服，继续保持！',
      ],
      EmotionType.encouraging: [
        '预算达成！每一次坚持都是对未来的投资～',
        '这个月的预算管理做得很棒，给自己点个赞！',
      ],
    },

    // 储蓄进度更新（新增）
    SceneType.savingsGoalProgress: {
      EmotionType.encouraging: [
        '「{goalName}」又进了一步！当前进度{progress}%，继续加油！',
        '储蓄目标稳步推进中，你做得很好！',
      ],
    },

    // 储蓄目标50%（新增）
    SceneType.savingsGoalHalfway: {
      EmotionType.celebrating: [
        '「{goalName}」已经完成一半了！胜利在望，继续冲！',
        '储蓄目标过半！你离梦想越来越近了～',
        '太棒了！{goalName}进度50%，坚持就是胜利！',
      ],
      EmotionType.encouraging: [
        '半程达成！每一分钱都在为你的目标努力～',
      ],
    },

    // 储蓄目标达成（新增）
    SceneType.savingsGoalAchieved: {
      EmotionType.celebrating: [
        '梦想成真！「{goalName}」储蓄目标达成！是时候奖励自己了！',
        '恭喜！{goalName}存满啦！你的坚持终于有了回报！',
        '太棒了！储蓄目标100%完成，你真的做到了！',
      ],
      EmotionType.grateful: [
        '感谢你的坚持，{goalName}目标达成！这一路走来不容易～',
      ],
    },

    // 特殊日期（新增）
    SceneType.specialDate: {
      EmotionType.celebrating: [
        '生日快乐！愿你的财富和快乐一样多～',
        '今天是特别的日子，祝你一切顺利！',
        '节日快乐！感谢有你的陪伴～',
      ],
      EmotionType.grateful: [
        '又是一年，感谢你一直以来的信任和陪伴！',
        '在这个特别的日子，感谢你选择让我陪伴你的理财之路～',
      ],
    },
  };

  /// 获取文案
  String? getCopy(CompanionScene scene, EmotionContext emotion) {
    final sceneCopies = _copyLibrary[scene.type];
    if (sceneCopies == null) return null;

    // 尝试精确匹配
    var copies = sceneCopies[emotion.type];

    // 如果没有精确匹配，尝试相近情感
    if (copies == null || copies.isEmpty) {
      copies = sceneCopies[EmotionType.friendly] ??
          sceneCopies[EmotionType.encouraging] ??
          sceneCopies.values.firstOrNull;
    }

    if (copies == null || copies.isEmpty) return null;

    // 随机选择一条
    return copies[Random().nextInt(copies.length)];
  }

  /// 获取所有场景类型
  List<SceneType> getAvailableScenes() {
    return _copyLibrary.keys.toList();
  }

  /// 获取场景的可用情感类型
  List<EmotionType> getAvailableEmotions(SceneType scene) {
    return _copyLibrary[scene]?.keys.toList() ?? [];
  }
}

// ==================== 用户偏好 ====================

/// 伙伴化用户偏好
class CompanionPreferences {
  final Map<String, _UserPreference> _preferences = {};

  /// 是否启用伙伴化功能
  Future<bool> isCompanionEnabled(String? userId) async {
    final pref = _getOrCreate(userId);
    return pref.enabled;
  }

  /// 是否静音模式
  Future<bool> isQuietMode(String? userId) async {
    final pref = _getOrCreate(userId);

    // 检查是否在静音时段
    if (pref.quietHoursStart != null && pref.quietHoursEnd != null) {
      final now = DateTime.now();
      final currentHour = now.hour;

      if (pref.quietHoursStart! <= pref.quietHoursEnd!) {
        // 同一天内的时段
        if (currentHour >= pref.quietHoursStart! &&
            currentHour < pref.quietHoursEnd!) {
          return true;
        }
      } else {
        // 跨午夜的时段
        if (currentHour >= pref.quietHoursStart! ||
            currentHour < pref.quietHoursEnd!) {
          return true;
        }
      }
    }

    return pref.quietMode;
  }

  /// 获取用户昵称
  Future<String?> getNickname(String? userId) async {
    return _getOrCreate(userId).nickname;
  }

  /// 设置启用状态
  Future<void> setEnabled(String? userId, bool enabled) async {
    _getOrCreate(userId).enabled = enabled;
  }

  /// 设置静音模式
  Future<void> setQuietMode(String? userId, bool quietMode) async {
    _getOrCreate(userId).quietMode = quietMode;
  }

  /// 设置静音时段
  Future<void> setQuietHours(String? userId, int? start, int? end) async {
    final pref = _getOrCreate(userId);
    pref.quietHoursStart = start;
    pref.quietHoursEnd = end;
  }

  /// 设置昵称
  Future<void> setNickname(String? userId, String? nickname) async {
    _getOrCreate(userId).nickname = nickname;
  }

  /// 设置文案风格
  Future<void> setCopyStyle(String? userId, CopyStyle style) async {
    _getOrCreate(userId).copyStyle = style;
  }

  _UserPreference _getOrCreate(String? userId) {
    final key = userId ?? '_default';
    return _preferences.putIfAbsent(key, () => _UserPreference());
  }
}

class _UserPreference {
  bool enabled = true;
  bool quietMode = false;
  int? quietHoursStart; // 0-23
  int? quietHoursEnd;   // 0-23
  String? nickname;
  CopyStyle copyStyle = CopyStyle.friendly;
}

/// 文案风格
enum CopyStyle {
  friendly,    // 友好型
  formal,      // 正式型
  humorous,    // 幽默型
  minimal,     // 简洁型
}

// ==================== 数据模型 ====================

/// 伙伴化消息
class CompanionMessage {
  final String id;
  final String content;
  final CompanionScene scene;
  final EmotionContext emotion;
  final CompanionTrigger trigger;
  final DateTime generatedAt;
  final MessagePriority priority;
  final bool isFromCache;
  final Map<String, dynamic>? metadata;

  const CompanionMessage({
    required this.id,
    required this.content,
    required this.scene,
    required this.emotion,
    required this.trigger,
    required this.generatedAt,
    this.priority = MessagePriority.medium,
    this.isFromCache = false,
    this.metadata,
  });

  CompanionMessage copyWith({
    String? id,
    String? content,
    CompanionScene? scene,
    EmotionContext? emotion,
    CompanionTrigger? trigger,
    DateTime? generatedAt,
    MessagePriority? priority,
    bool? isFromCache,
    Map<String, dynamic>? metadata,
  }) {
    return CompanionMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      scene: scene ?? this.scene,
      emotion: emotion ?? this.emotion,
      trigger: trigger ?? this.trigger,
      generatedAt: generatedAt ?? this.generatedAt,
      priority: priority ?? this.priority,
      isFromCache: isFromCache ?? this.isFromCache,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// 伙伴场景
class CompanionScene {
  final SceneType type;
  final TimeOfDay? timeOfDay;
  final Map<String, dynamic>? metadata;

  const CompanionScene({
    required this.type,
    this.timeOfDay,
    this.metadata,
  });
}

/// 场景类型
enum SceneType {
  // 问候场景
  dailyGreeting,       // 每日问候
  eveningSummary,      // 晚间总结（新增）
  returnAfterBreak,    // 短暂离开后回归
  longTimeNoSee,       // 长时间未见

  // 记账场景
  recordCompletion,    // 记账完成
  streakContinued,     // 连续记账

  // 成就场景
  achievementUnlocked, // 成就解锁
  milestone,           // 里程碑达成

  // 预算场景
  budgetReminder,      // 预算提醒
  budgetWarning,       // 预算预警 (80%)
  budgetCritical,      // 预算紧急 (90%)
  budgetExceeded,      // 预算超支
  budgetAchieved,      // 预算达成（新增）

  // 钱龄场景
  moneyAgeImproved,    // 钱龄提升
  moneyAgeStable,      // 钱龄稳定
  moneyAgeDeclined,    // 钱龄下降

  // 储蓄目标场景（新增）
  savingsGoalProgress, // 储蓄进度更新
  savingsGoalHalfway,  // 储蓄目标50%
  savingsGoalAchieved, // 储蓄目标达成

  // 洞察场景
  insightDiscovery,    // AI洞察发现

  // 特殊日期场景（新增）
  specialDate,         // 特殊日期（生日/纪念日/节日）

  // 其他场景
  scheduledReminder,   // 定时提醒
  userRequested,       // 用户主动触发
}

/// 时段
enum TimeOfDay {
  morning,
  afternoon,
  evening,
  lateNight,
}

/// 情感上下文
class EmotionContext {
  final EmotionType type;
  final EmotionIntensity intensity;

  const EmotionContext({
    required this.type,
    required this.intensity,
  });
}

/// 情感类型
enum EmotionType {
  celebrating,   // 庆祝 - 成就达成、目标完成
  encouraging,   // 鼓励 - 正向激励进步
  friendly,      // 友好 - 日常交互
  caring,        // 关心 - 主动关注用户状态
  supportive,    // 支持 - 困难时给予情感支持
  welcoming,     // 欢迎 - 回归用户
  energetic,     // 有活力 - 早间问候
  relaxed,       // 放松 - 晚间交互
  neutral,       // 中性 - 一般信息
  grateful,      // 感恩（新增）- 感谢用户使用/反馈
  curious,       // 好奇（新增）- 引导新功能探索
  forgiving,     // 宽容（新增）- 对失误包容
  empathetic,    // 共情（新增）- 理解用户处境
}

/// 情感强度
enum EmotionIntensity {
  low,
  medium,
  high,
}

/// 伙伴触发器
enum CompanionTrigger {
  appOpen,         // 打开应用
  recordComplete,  // 记账完成
  budgetAlert,     // 预算预警
  budgetAchieved,  // 预算达成（新增）
  moneyAgeChange,  // 钱龄变化
  achievement,     // 成就解锁
  milestone,       // 里程碑达成
  streak,          // 连续记录
  insight,         // 洞察发现
  savingsGoal,     // 储蓄目标事件（新增）
  specialDate,     // 特殊日期（新增）
  scheduled,       // 定时触发
  manual,          // 手动触发
}

/// 消息优先级
enum MessagePriority {
  low,
  medium,
  high,
}
