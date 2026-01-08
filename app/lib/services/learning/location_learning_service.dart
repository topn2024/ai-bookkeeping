import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

// ==================== 位置学习数据模型 ====================

/// 位置上下文
class LocationContext {
  final double latitude;
  final double longitude;
  final SceneType sceneType;
  final String? sceneName;
  final String? poiType;
  final SceneType? previousScene;
  final Duration? travelDuration;

  const LocationContext({
    required this.latitude,
    required this.longitude,
    required this.sceneType,
    this.sceneName,
    this.poiType,
    this.previousScene,
    this.travelDuration,
  });
}

/// 场景类型
enum SceneType {
  home, // 家
  office, // 办公室
  mall, // 商场
  restaurant, // 餐厅
  supermarket, // 超市
  hospital, // 医院
  school, // 学校
  entertainment, // 娱乐场所
  transport, // 交通枢纽
  outdoor, // 户外
  unknown, // 未知
}

/// 模式类型
enum PatternType {
  locationCategory, // 位置-分类关联
  locationAmount, // 位置-金额模式
  commuteRoute, // 通勤路线
  frequentPlace, // 常去地点
  timeLocationCategory, // 时间-位置-分类
}

/// 学习的模式
class LearnedPattern {
  final String id;
  final PatternType type;
  final Map<String, dynamic> features;
  final int frequency;
  final double confidence;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  LearnedPattern({
    required this.id,
    required this.type,
    required this.features,
    required this.frequency,
    required this.confidence,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastSeenAt = lastSeenAt ?? DateTime.now();

  LearnedPattern copyWith({int? frequency, DateTime? lastSeenAt}) {
    return LearnedPattern(
      id: id,
      type: type,
      features: features,
      frequency: frequency ?? this.frequency,
      confidence: confidence,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

/// 位置建议
class LocationSuggestion {
  final String? suggestedCategory;
  final double? suggestedAmount;
  final double confidence;
  final String? reason;

  const LocationSuggestion({
    this.suggestedCategory,
    this.suggestedAmount,
    required this.confidence,
    this.reason,
  });

  factory LocationSuggestion.none() {
    return const LocationSuggestion(confidence: 0);
  }

  bool get hasSuggestion => suggestedCategory != null || suggestedAmount != null;
}

/// 简化的交易数据
class TransactionWithLocation {
  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final LocationContext? location;

  const TransactionWithLocation({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.location,
  });
}

// ==================== 位置智能服务接口 ====================

/// 位置智能服务接口
abstract class LocationIntelligenceService {
  Future<LocationContext> analyzeLocation(LocationContext location);
}

/// 模拟位置智能服务
class MockLocationIntelligenceService implements LocationIntelligenceService {
  @override
  Future<LocationContext> analyzeLocation(LocationContext location) async {
    // 模拟：根据坐标推断场景类型
    return location;
  }
}

// ==================== 模式存储 ====================

/// 模式存储接口
abstract class PatternStore {
  Future<void> savePattern(LearnedPattern pattern);
  Future<List<LearnedPattern>> getPatterns({
    PatternType? type,
    Map<String, dynamic>? filter,
  });
  Future<void> updatePattern(LearnedPattern pattern);
}

/// 内存模式存储
class InMemoryPatternStore implements PatternStore {
  final List<LearnedPattern> _patterns = [];

  @override
  Future<void> savePattern(LearnedPattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<List<LearnedPattern>> getPatterns({
    PatternType? type,
    Map<String, dynamic>? filter,
  }) async {
    var result = _patterns.toList();

    if (type != null) {
      result = result.where((p) => p.type == type).toList();
    }

    if (filter != null && filter.isNotEmpty) {
      result = result.where((p) {
        for (final entry in filter.entries) {
          if (p.features[entry.key] != entry.value) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    return result;
  }

  @override
  Future<void> updatePattern(LearnedPattern pattern) async {
    final index = _patterns.indexWhere((p) => p.id == pattern.id);
    if (index >= 0) {
      _patterns[index] = pattern;
    }
  }

  void clear() => _patterns.clear();
  int get patternCount => _patterns.length;
}

// ==================== 位置智能与自学习系统集成 ====================

/// 位置智能与自学习系统集成
class LocationLearningService {
  final LocationIntelligenceService _locationService;
  final PatternStore _patternStore;

  LocationLearningService({
    LocationIntelligenceService? locationService,
    PatternStore? patternStore,
  })  : _locationService = locationService ?? MockLocationIntelligenceService(),
        _patternStore = patternStore ?? InMemoryPatternStore();

  /// 学习用户位置消费模式
  Future<void> learnLocationPatterns(TransactionWithLocation tx) async {
    if (tx.location == null) return;

    final context = await _locationService.analyzeLocation(tx.location!);

    // 1. 学习场景-类目关联
    await _recordPattern(
      PatternType.locationCategory,
      features: {
        'scene_type': context.sceneType.name,
        'category': tx.category,
        'amount_range': _getAmountRange(tx.amount),
        'time_of_day': _getTimeOfDay(tx.date),
      },
    );

    // 2. 学习位置-金额模式
    await _recordPattern(
      PatternType.locationAmount,
      features: {
        'poi_type': context.poiType ?? context.sceneType.name,
        'average_amount': tx.amount,
        'frequency': 1,
      },
    );

    // 3. 学习移动模式（通勤识别）
    if (await _isCommuteTime(tx.date)) {
      await _recordPattern(
        PatternType.commuteRoute,
        features: {
          'from': context.previousScene?.name,
          'to': context.sceneType.name,
          'duration': context.travelDuration?.inMinutes,
        },
      );
    }

    // 4. 学习时间-位置-分类模式
    await _recordPattern(
      PatternType.timeLocationCategory,
      features: {
        'hour': tx.date.hour,
        'day_of_week': tx.date.weekday,
        'scene_type': context.sceneType.name,
        'category': tx.category,
      },
    );

    debugPrint('Learned location pattern for scene: ${context.sceneType.name}');
  }

  /// 记录模式
  Future<void> _recordPattern(
    PatternType type, {
    required Map<String, dynamic> features,
  }) async {
    // 检查是否已有相似模式
    final existingPatterns = await _patternStore.getPatterns(
      type: type,
      filter: _getFilterFromFeatures(type, features),
    );

    if (existingPatterns.isNotEmpty) {
      // 更新现有模式
      final existing = existingPatterns.first;
      await _patternStore.updatePattern(
        existing.copyWith(
          frequency: existing.frequency + 1,
          lastSeenAt: DateTime.now(),
        ),
      );
    } else {
      // 创建新模式
      await _patternStore.savePattern(LearnedPattern(
        id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        features: features,
        frequency: 1,
        confidence: 0.5,
      ));
    }
  }

  Map<String, dynamic> _getFilterFromFeatures(
    PatternType type,
    Map<String, dynamic> features,
  ) {
    switch (type) {
      case PatternType.locationCategory:
        return {
          'scene_type': features['scene_type'],
          'category': features['category'],
        };
      case PatternType.locationAmount:
        return {'poi_type': features['poi_type']};
      case PatternType.commuteRoute:
        return {
          'from': features['from'],
          'to': features['to'],
        };
      case PatternType.timeLocationCategory:
        return {
          'hour': features['hour'],
          'scene_type': features['scene_type'],
        };
      default:
        return {};
    }
  }

  /// 基于学习结果提供位置建议
  Future<LocationSuggestion> getLearnedSuggestion(
    LocationContext context,
  ) async {
    // 获取该场景的历史模式
    final patterns = await _patternStore.getPatterns(
      type: PatternType.locationCategory,
      filter: {'scene_type': context.sceneType.name},
    );

    if (patterns.isEmpty) {
      return LocationSuggestion.none();
    }

    // 找出最常见的类目
    final categoryGroups = groupBy(
      patterns,
      (p) => p.features['category'] as String,
    );

    final topCategory = categoryGroups.entries
        .reduce((a, b) => a.value.length > b.value.length ? a : b)
        .key;

    // 获取金额模式
    final amountPatterns = await _patternStore.getPatterns(
      type: PatternType.locationAmount,
      filter: {'poi_type': context.poiType ?? context.sceneType.name},
    );

    double? avgAmount;
    if (amountPatterns.isNotEmpty) {
      final amounts = amountPatterns
          .map((p) => (p.features['average_amount'] as num).toDouble())
          .toList();
      avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    }

    final confidence = patterns.length / 10.0; // 基于样本数的置信度

    return LocationSuggestion(
      suggestedCategory: topCategory,
      suggestedAmount: avgAmount,
      confidence: confidence.clamp(0.0, 1.0),
      reason: '基于您在${context.sceneName ?? context.sceneType.name}的'
          '${patterns.length}次消费记录',
    );
  }

  /// 获取时间+位置组合建议
  Future<LocationSuggestion> getTimeLocationSuggestion(
    LocationContext context,
    DateTime time,
  ) async {
    final patterns = await _patternStore.getPatterns(
      type: PatternType.timeLocationCategory,
      filter: {
        'hour': time.hour,
        'scene_type': context.sceneType.name,
      },
    );

    if (patterns.isEmpty) {
      // 回退到纯位置建议
      return getLearnedSuggestion(context);
    }

    final categoryGroups = groupBy(
      patterns,
      (p) => p.features['category'] as String,
    );

    final topCategory = categoryGroups.entries
        .reduce((a, b) => a.value.length > b.value.length ? a : b)
        .key;

    return LocationSuggestion(
      suggestedCategory: topCategory,
      confidence: (patterns.length / 5.0).clamp(0.0, 1.0),
      reason: '基于您在${_getTimeOfDay(time)}时段在此地的消费习惯',
    );
  }

  /// 获取常去地点列表
  Future<List<FrequentPlace>> getFrequentPlaces() async {
    final patterns = await _patternStore.getPatterns(
      type: PatternType.locationCategory,
    );

    // 按场景类型分组并统计
    final sceneGroups = groupBy(
      patterns,
      (p) => p.features['scene_type'] as String,
    );

    return sceneGroups.entries
        .map((e) => FrequentPlace(
              sceneType: SceneType.values.firstWhere(
                (s) => s.name == e.key,
                orElse: () => SceneType.unknown,
              ),
              visitCount: e.value.fold(0, (sum, p) => sum + p.frequency),
              topCategories: _getTopCategories(e.value),
            ))
        .toList()
      ..sort((a, b) => b.visitCount.compareTo(a.visitCount));
  }

  List<String> _getTopCategories(List<LearnedPattern> patterns) {
    final categoryGroups = groupBy(
      patterns,
      (p) => p.features['category'] as String,
    );

    final sorted = categoryGroups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return sorted.take(3).map((e) => e.key).toList();
  }

  /// 获取通勤模式
  Future<CommutePattern?> getCommutePattern() async {
    final patterns = await _patternStore.getPatterns(
      type: PatternType.commuteRoute,
    );

    if (patterns.length < 5) return null;

    // 找出最常见的通勤路线
    final routeGroups = groupBy(
      patterns,
      (p) => '${p.features['from']}_${p.features['to']}',
    );

    final topRoute = routeGroups.entries
        .reduce((a, b) => a.value.length > b.value.length ? a : b);

    final avgDuration = topRoute.value
        .where((p) => p.features['duration'] != null)
        .map((p) => (p.features['duration'] as int))
        .fold(0, (a, b) => a + b);

    return CommutePattern(
      fromScene: topRoute.value.first.features['from'] as String?,
      toScene: topRoute.value.first.features['to'] as String?,
      frequency: topRoute.value.length,
      averageDuration: topRoute.value.isEmpty
          ? null
          : Duration(minutes: avgDuration ~/ topRoute.value.length),
    );
  }

  // ==================== 辅助方法 ====================

  String _getAmountRange(double amount) {
    if (amount < 20) return '0-20';
    if (amount < 50) return '20-50';
    if (amount < 100) return '50-100';
    if (amount < 200) return '100-200';
    if (amount < 500) return '200-500';
    return '500+';
  }

  String _getTimeOfDay(DateTime date) {
    final hour = date.hour;
    if (hour >= 6 && hour < 9) return '早晨';
    if (hour >= 9 && hour < 12) return '上午';
    if (hour >= 12 && hour < 14) return '午间';
    if (hour >= 14 && hour < 18) return '下午';
    if (hour >= 18 && hour < 21) return '晚间';
    return '深夜';
  }

  Future<bool> _isCommuteTime(DateTime date) async {
    final hour = date.hour;
    final dayOfWeek = date.weekday;

    // 工作日的通勤时间
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      // 早高峰 7:00-9:30 或 晚高峰 17:00-20:00
      return (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 20);
    }

    return false;
  }
}

// ==================== 辅助数据类 ====================

/// 常去地点
class FrequentPlace {
  final SceneType sceneType;
  final int visitCount;
  final List<String> topCategories;

  const FrequentPlace({
    required this.sceneType,
    required this.visitCount,
    required this.topCategories,
  });
}

/// 通勤模式
class CommutePattern {
  final String? fromScene;
  final String? toScene;
  final int frequency;
  final Duration? averageDuration;

  const CommutePattern({
    this.fromScene,
    this.toScene,
    required this.frequency,
    this.averageDuration,
  });
}
