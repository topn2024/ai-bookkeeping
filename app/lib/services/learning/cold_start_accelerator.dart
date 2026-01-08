import 'dart:async';

import 'package:flutter/foundation.dart';

import 'unified_self_learning_service.dart';
import '../user_profile_service.dart';
import '../collaborative_learning_service.dart';

/// 冷启动加速服务
///
/// 为新用户快速初始化学习规则，缩短冷启动时间
class ColdStartAccelerator {
  final CollaborativeLearningService _collaborativeService;
  final UserProfileService _profileService;

  // 冷启动配置
  static const int _minTransactionsForProfile = 10;
  static const double _coldStartRuleConfidence = 0.6;

  ColdStartAccelerator({
    required CollaborativeLearningService collaborativeService,
    required UserProfileService profileService,
  })  : _collaborativeService = collaborativeService,
        _profileService = profileService;

  /// 为新用户初始化学习规则
  Future<ColdStartResult> initializeForNewUser(String userId) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1. 尝试获取用户画像
      final profile = await _profileService.getProfile(userId);
      final hasProfile = profile != null && profile.hasEnoughData;

      // 2. 根据画像选择适合的协同规则集
      final ruleSet = await _selectRuleSet(
        hasProfile ? _extractProfileFeatures(profile) : null,
      );

      // 3. 导入规则
      final importedCount = await _importRuleSet(userId, ruleSet);

      stopwatch.stop();

      return ColdStartResult(
        success: true,
        rulesImported: importedCount,
        expectedAccuracy: ruleSet.expectedAccuracy,
        warmUpDays: ruleSet.warmUpDays,
        initializationTime: stopwatch.elapsed,
        profileUsed: hasProfile,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Cold start initialization failed: $e');

      return ColdStartResult(
        success: false,
        rulesImported: 0,
        expectedAccuracy: 0,
        warmUpDays: 14, // 默认预热期
        initializationTime: stopwatch.elapsed,
        profileUsed: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 检查用户是否需要冷启动
  Future<bool> needsColdStart(String userId) async {
    final learningService = UnifiedSelfLearningService();
    final statuses = await learningService.getAllModuleStatus();

    // 如果所有模块都处于冷启动阶段，则需要冷启动
    return statuses.values.every(
      (status) =>
          status.stage == LearningStage.coldStart ||
          status.pendingSamples < _minTransactionsForProfile,
    );
  }

  /// 获取冷启动进度
  Future<ColdStartProgress> getProgress(String userId) async {
    final learningService = UnifiedSelfLearningService();
    final statuses = await learningService.getAllModuleStatus();

    int totalModules = statuses.length;
    int activeModules = statuses.values
        .where((s) => s.stage == LearningStage.active)
        .length;

    int totalSamples = statuses.values.fold(0, (sum, s) => sum + s.pendingSamples);
    int requiredSamples = totalModules * _minTransactionsForProfile;

    return ColdStartProgress(
      overallProgress: totalModules > 0 ? activeModules / totalModules : 0,
      samplesCollected: totalSamples,
      samplesRequired: requiredSamples,
      modulesReady: activeModules,
      modulesTotal: totalModules,
      estimatedDaysRemaining: _estimateDaysRemaining(totalSamples, requiredSamples),
    );
  }

  /// 提取用户画像特征
  Map<String, dynamic> _extractProfileFeatures(UserProfile? profile) {
    if (profile == null) return {};

    return {
      'spending_style': profile.spendingBehavior.style.name,
      'monthly_average': _toAmountRange(profile.spendingBehavior.monthlyAverage),
      'top_categories': profile.spendingBehavior.topCategories,
      'life_phase': profile.lifeStage.phase.name,
      'city_tier': profile.lifeStage.cityTier.name,
    };
  }

  /// 根据特征选择规则集
  Future<CollaborativeRuleSet> _selectRuleSet(
    Map<String, dynamic>? features,
  ) async {
    // 如果有用户特征，尝试获取匹配的规则集
    if (features != null && features.isNotEmpty) {
      try {
        final status = await _collaborativeService.getStatus();
        if (status.isEnabled) {
          // 这里实际会从服务端获取匹配的规则集
          // 简化实现返回默认规则集
        }
      } catch (e) {
        debugPrint('Failed to fetch profile-based rules: $e');
      }
    }

    // 返回默认规则集
    return CollaborativeRuleSet.defaultSet();
  }

  /// 导入规则集
  Future<int> _importRuleSet(String userId, CollaborativeRuleSet ruleSet) async {
    final learningService = UnifiedSelfLearningService();
    int importedCount = 0;

    for (final moduleRules in ruleSet.rulesByModule.entries) {
      final module = learningService.getModule(moduleRules.key);
      if (module == null) continue;

      try {
        await module.importModel(ModelExportData(
          moduleId: moduleRules.key,
          exportedAt: DateTime.now(),
          version: '1.0',
          rules: moduleRules.value,
          metadata: {
            'source': 'cold_start',
            'confidence_factor': _coldStartRuleConfidence,
          },
        ));
        importedCount += moduleRules.value.length;
      } catch (e) {
        debugPrint('Failed to import rules for ${moduleRules.key}: $e');
      }
    }

    return importedCount;
  }

  /// 金额转换为范围
  String _toAmountRange(double amount) {
    if (amount < 3000) return 'low';
    if (amount < 8000) return 'medium';
    if (amount < 15000) return 'high';
    return 'very_high';
  }

  /// 估算剩余天数
  int _estimateDaysRemaining(int current, int required) {
    if (current >= required) return 0;
    // 假设每天平均收集2-3条样本
    final remaining = required - current;
    return (remaining / 2.5).ceil();
  }
}

/// 冷启动结果
class ColdStartResult {
  final bool success;
  final int rulesImported;
  final double expectedAccuracy;
  final int warmUpDays;
  final Duration initializationTime;
  final bool profileUsed;
  final String? errorMessage;

  const ColdStartResult({
    required this.success,
    required this.rulesImported,
    required this.expectedAccuracy,
    required this.warmUpDays,
    required this.initializationTime,
    required this.profileUsed,
    this.errorMessage,
  });

  /// 获取用户友好的结果描述
  String getDescription() {
    if (!success) {
      return '初始化失败，将使用默认设置';
    }

    if (rulesImported == 0) {
      return '已完成初始化，正在学习您的习惯';
    }

    return '已导入$rulesImported条智能规则，预计$warmUpDays天后达到最佳效果';
  }
}

/// 冷启动进度
class ColdStartProgress {
  final double overallProgress; // 0-1
  final int samplesCollected;
  final int samplesRequired;
  final int modulesReady;
  final int modulesTotal;
  final int estimatedDaysRemaining;

  const ColdStartProgress({
    required this.overallProgress,
    required this.samplesCollected,
    required this.samplesRequired,
    required this.modulesReady,
    required this.modulesTotal,
    required this.estimatedDaysRemaining,
  });

  bool get isComplete => overallProgress >= 1.0;

  String getProgressText() {
    final percent = (overallProgress * 100).toInt();
    if (isComplete) {
      return '学习完成！';
    }
    return '学习进度 $percent%';
  }

  String getDetailText() {
    if (isComplete) {
      return '所有智能模块已就绪';
    }
    return '已收集 $samplesCollected / $samplesRequired 条数据，'
        '预计还需 $estimatedDaysRemaining 天';
  }
}

/// 协同规则集
class CollaborativeRuleSet {
  final Map<String, List<Map<String, dynamic>>> rulesByModule;
  final double expectedAccuracy;
  final int warmUpDays;
  final String? targetProfile;

  const CollaborativeRuleSet({
    required this.rulesByModule,
    required this.expectedAccuracy,
    required this.warmUpDays,
    this.targetProfile,
  });

  /// 默认规则集
  factory CollaborativeRuleSet.defaultSet() {
    return CollaborativeRuleSet(
      rulesByModule: {
        'smart_category': _defaultCategoryRules,
        'budget_suggestion': _defaultBudgetRules,
      },
      expectedAccuracy: 0.65,
      warmUpDays: 7,
    );
  }

  /// 默认分类规则
  static const List<Map<String, dynamic>> _defaultCategoryRules = [
    {
      'pattern': '星巴克|瑞幸|MANNER',
      'category': '餐饮-咖啡',
      'confidence': 0.95,
    },
    {
      'pattern': '美团|饿了么',
      'category': '餐饮-外卖',
      'confidence': 0.90,
    },
    {
      'pattern': '滴滴|高德打车|T3出行',
      'category': '交通-打车',
      'confidence': 0.95,
    },
    {
      'pattern': '地铁|公交|轨道交通',
      'category': '交通-公共交通',
      'confidence': 0.90,
    },
    {
      'pattern': '天猫超市|京东超市|盒马',
      'category': '生活-超市',
      'confidence': 0.85,
    },
    {
      'pattern': '中国电信|中国移动|中国联通',
      'category': '生活-通讯',
      'confidence': 0.95,
    },
    {
      'pattern': '水费|电费|燃气费',
      'category': '生活-水电燃',
      'confidence': 0.95,
    },
    {
      'pattern': '优酷|爱奇艺|腾讯视频|Netflix',
      'category': '娱乐-视频会员',
      'confidence': 0.90,
    },
  ];

  /// 默认预算规则
  static const List<Map<String, dynamic>> _defaultBudgetRules = [
    {
      'category': '餐饮',
      'percentage': 0.25,
      'priority': 'high',
    },
    {
      'category': '交通',
      'percentage': 0.10,
      'priority': 'high',
    },
    {
      'category': '生活',
      'percentage': 0.20,
      'priority': 'high',
    },
    {
      'category': '娱乐',
      'percentage': 0.10,
      'priority': 'medium',
    },
    {
      'category': '储蓄',
      'percentage': 0.20,
      'priority': 'high',
    },
  ];
}
