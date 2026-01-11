/// 数据库支持的预生成文案库
library;

import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 数据库支持的预生成文案库（替代硬编码库）
class DatabaseBackedCopyLibrary {
  final String apiBaseUrl;
  final Map<String, List<String>> _localCache = {};
  DateTime? _lastFetchTime;
  final Duration _cacheDuration = const Duration(hours: 1);

  DatabaseBackedCopyLibrary({required this.apiBaseUrl});

  /// 获取文案（优先从本地缓存，缓存过期则从服务器获取）
  Future<String?> getCopy(
    CompanionScene scene,
    EmotionContext emotion,
  ) async {
    final cacheKey = _generateCacheKey(scene, emotion);

    // 检查本地缓存
    if (_isCacheValid() && _localCache.containsKey(cacheKey)) {
      final copies = _localCache[cacheKey]!;
      if (copies.isNotEmpty) {
        return copies[Random().nextInt(copies.length)];
      }
    }

    // 从服务器获取
    try {
      await _fetchFromServer(scene, emotion);

      // 再次尝试从缓存获取
      if (_localCache.containsKey(cacheKey)) {
        final copies = _localCache[cacheKey]!;
        if (copies.isNotEmpty) {
          return copies[Random().nextInt(copies.length)];
        }
      }
    } catch (e) {
      // 如果服务器获取失败，使用降级文案
      return _getFallbackCopy(scene, emotion);
    }

    return null;
  }

  /// 从服务器获取文案
  Future<void> _fetchFromServer(
    CompanionScene scene,
    EmotionContext emotion,
  ) async {
    final url = Uri.parse('$apiBaseUrl/api/v1/companion/messages');
    final response = await http.get(
      url.replace(queryParameters: {
        'scene_type': scene.type.name,
        'emotion_type': emotion.type.name,
        'time_of_day': scene.timeOfDay?.name ?? '',
        'language': 'zh_CN',
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final messages = (data['messages'] as List)
          .map((m) => m['content'] as String)
          .toList();

      final cacheKey = _generateCacheKey(scene, emotion);
      _localCache[cacheKey] = messages;
      _lastFetchTime = DateTime.now();
    } else {
      throw Exception('Failed to fetch messages: ${response.statusCode}');
    }
  }

  /// 检查缓存是否有效
  bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  /// 生成缓存键
  String _generateCacheKey(CompanionScene scene, EmotionContext emotion) {
    return '${scene.type.name}_${emotion.type.name}_${scene.timeOfDay?.name ?? "any"}';
  }

  /// 降级文案（当服务器不可用时使用）
  String? _getFallbackCopy(CompanionScene scene, EmotionContext emotion) {
    // 使用原有的硬编码文案作为降级方案
    final fallbackTemplates = _getFallbackTemplates();
    final sceneCopies = fallbackTemplates[scene.type];
    if (sceneCopies == null) return null;

    var copies = sceneCopies[emotion.type];
    if (copies == null || copies.isEmpty) {
      copies = sceneCopies[EmotionType.friendly] ??
          sceneCopies[EmotionType.encouraging] ??
          sceneCopies.values.firstOrNull;
    }

    if (copies == null || copies.isEmpty) return null;
    return copies[Random().nextInt(copies.length)];
  }

  /// 获取降级文案模板（保留原有硬编码作为降级方案）
  Map<SceneType, Map<EmotionType, List<String>>> _getFallbackTemplates() {
    return {
      SceneType.dailyGreeting: {
        EmotionType.energetic: [
          '{timeGreeting}！新的一天，新的开始，记得记录今天的收支哦～',
          '{timeGreeting}！元气满满的一天开始了，财务管理从点滴做起！',
        ],
        EmotionType.friendly: [
          '{timeGreeting}！又见面啦，让我陪你一起管好钱袋子～',
        ],
        EmotionType.relaxed: [
          '{timeGreeting}！辛苦一天了，记完账就好好休息吧～',
        ],
        EmotionType.caring: [
          '夜深了，还在忙吗？记得照顾好自己～',
        ],
      },
      SceneType.recordCompletion: {
        EmotionType.encouraging: [
          '记录成功！每一笔都是对财务的用心管理～',
          '又完成一笔记录！积少成多，你的理财习惯正在养成中～',
        ],
      },
      // 其他场景的降级文案...
    };
  }

  /// 清除本地缓存
  void clearCache() {
    _localCache.clear();
    _lastFetchTime = null;
  }
}

// 导入原有的类型定义
enum SceneType {
  dailyGreeting,
  recordCompletion,
  streakContinued,
  milestone,
  achievementUnlocked,
  budgetReminder,
  budgetWarning,
  budgetCritical,
  budgetExceeded,
  budgetAchieved,
  moneyAgeImproved,
  moneyAgeStable,
  moneyAgeDeclined,
  returnAfterBreak,
  longTimeNoSee,
  insightDiscovery,
  eveningSummary,
  savingsGoalProgress,
  savingsGoalHalfway,
  savingsGoalAchieved,
  specialDate,
  scheduledReminder,
  userRequested,
}

enum TimeOfDay {
  morning,
  afternoon,
  evening,
  lateNight,
}

enum EmotionType {
  celebrating,
  encouraging,
  friendly,
  caring,
  supportive,
  welcoming,
  energetic,
  relaxed,
  neutral,
  grateful,
  curious,
  forgiving,
  empathetic,
}

enum EmotionIntensity {
  low,
  medium,
  high,
}

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

class EmotionContext {
  final EmotionType type;
  final EmotionIntensity intensity;

  const EmotionContext({
    required this.type,
    required this.intensity,
  });
}
