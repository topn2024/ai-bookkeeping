import 'package:flutter/material.dart';

import '../models/resource_pool.dart';

/// 钱龄阶段（用于阶段进度展示）
class MoneyAgeStage {
  /// 阶段ID
  final String id;

  /// 阶段名称
  final String name;

  /// 阶段描述
  final String description;

  /// 阶段图标
  final IconData icon;

  /// 阶段颜色
  final Color color;

  /// 最低天数要求
  final int minDays;

  /// 最高天数（下一阶段的起点）
  final int? maxDays;

  /// 奖励积分
  final int rewardPoints;

  /// 阶段提示/建议
  final List<String> tips;

  const MoneyAgeStage({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.minDays,
    this.maxDays,
    required this.rewardPoints,
    this.tips = const [],
  });

  /// 是否达到此阶段
  bool isAchieved(int days) => days >= minDays;

  /// 在此阶段内的进度（0-1）
  double getProgress(int days) {
    if (days < minDays) return 0;
    if (maxDays == null) return 1;
    if (days >= maxDays!) return 1;
    // 修复：添加maxDays == minDays检查，避免除零
    if (maxDays! == minDays) return 1;
    return (days - minDays) / (maxDays! - minDays);
  }
}

/// 预定义的钱龄阶段
class MoneyAgeStages {
  static const MoneyAgeStage newcomer = MoneyAgeStage(
    id: 'newcomer',
    name: '月光新手',
    description: '刚开始管理财务，每月收入几乎花光',
    icon: Icons.child_care,
    color: Colors.red,
    minDays: 0,
    maxDays: 7,
    rewardPoints: 0,
    tips: [
      '记录每一笔支出，了解钱都花哪了',
      '设置一个小目标：留存1%的收入',
      '使用分类功能追踪消费习惯',
    ],
  );

  static const MoneyAgeStage beginner = MoneyAgeStage(
    id: 'beginner',
    name: '储蓄入门',
    description: '有了基本的资金缓冲，能应对一周的支出',
    icon: Icons.school,
    color: Colors.orange,
    minDays: 7,
    maxDays: 14,
    rewardPoints: 50,
    tips: [
      '继续保持，目标是两周的缓冲',
      '审视非必要支出，找出可以削减的地方',
      '建立自动储蓄习惯',
    ],
  );

  static const MoneyAgeStage intermediate = MoneyAgeStage(
    id: 'intermediate',
    name: '理财进阶',
    description: '有两周以上的资金缓冲，财务初步稳定',
    icon: Icons.trending_up,
    color: Colors.yellow,
    minDays: 14,
    maxDays: 30,
    rewardPoints: 100,
    tips: [
      '开始规划月度预算',
      '建立应急基金账户',
      '尝试零基预算方法',
    ],
  );

  static const MoneyAgeStage stable = MoneyAgeStage(
    id: 'stable',
    name: '财务稳健',
    description: '有一个月以上的资金储备，能从容应对意外',
    icon: Icons.security,
    color: Colors.lightGreen,
    minDays: 30,
    maxDays: 60,
    rewardPoints: 200,
    tips: [
      '考虑建立3-6个月的应急基金',
      '开始了解投资理财',
      '为长期目标做规划',
    ],
  );

  static const MoneyAgeStage advanced = MoneyAgeStage(
    id: 'advanced',
    name: '财务优秀',
    description: '有两个月以上储备，财务状况非常健康',
    icon: Icons.star,
    color: Colors.green,
    minDays: 60,
    maxDays: 90,
    rewardPoints: 300,
    tips: [
      '保持良好习惯',
      '可以适当增加投资比例',
      '帮助家人朋友建立财务意识',
    ],
  );

  static const MoneyAgeStage master = MoneyAgeStage(
    id: 'master',
    name: '财务自由',
    description: '三个月以上储备，可以从容应对各种情况',
    icon: Icons.diamond,
    color: Colors.teal,
    minDays: 90,
    maxDays: null,
    rewardPoints: 500,
    tips: [
      '恭喜达到理想状态！',
      '继续保持这一习惯',
      '考虑更长期的财务规划',
    ],
  );

  /// 所有阶段列表（从低到高排序）
  static const List<MoneyAgeStage> all = [
    newcomer,
    beginner,
    intermediate,
    stable,
    advanced,
    master,
  ];

  /// 根据天数获取当前阶段
  static MoneyAgeStage getStage(int days) {
    for (var i = all.length - 1; i >= 0; i--) {
      if (days >= all[i].minDays) {
        return all[i];
      }
    }
    return newcomer;
  }

  /// 获取下一阶段
  static MoneyAgeStage? getNextStage(int days) {
    for (final stage in all) {
      if (days < stage.minDays) {
        return stage;
      }
    }
    return null;
  }

  /// 获取所有已达成的阶段
  static List<MoneyAgeStage> getAchievedStages(int days) {
    return all.where((stage) => stage.isAchieved(days)).toList();
  }
}

/// 阶段进度信息
class StageProgress {
  /// 当前阶段
  final MoneyAgeStage currentStage;

  /// 下一阶段（如果有）
  final MoneyAgeStage? nextStage;

  /// 当前钱龄天数
  final int currentDays;

  /// 在当前阶段内的进度（0-1）
  final double progressInStage;

  /// 距离下一阶段还需天数
  final int? daysToNextStage;

  /// 已获得的总奖励积分
  final int totalRewardPoints;

  const StageProgress({
    required this.currentStage,
    this.nextStage,
    required this.currentDays,
    required this.progressInStage,
    this.daysToNextStage,
    required this.totalRewardPoints,
  });

  /// 是否已达到最高阶段
  bool get isMaxStage => nextStage == null;

  /// 进度描述
  String get progressDescription {
    if (isMaxStage) {
      return '恭喜，您已达到最高阶段！';
    }
    return '距离「${nextStage!.name}」还需 $daysToNextStage 天';
  }

  factory StageProgress.calculate(int days) {
    final current = MoneyAgeStages.getStage(days);
    final next = MoneyAgeStages.getNextStage(days);

    // 计算已获得的奖励积分
    var totalPoints = 0;
    for (final stage in MoneyAgeStages.all) {
      if (stage.isAchieved(days)) {
        totalPoints += stage.rewardPoints;
      }
    }

    return StageProgress(
      currentStage: current,
      nextStage: next,
      currentDays: days,
      progressInStage: current.getProgress(days),
      daysToNextStage: next != null ? next.minDays - days : null,
      totalRewardPoints: totalPoints,
    );
  }
}

/// 等级详情信息
class LevelDetails {
  /// 等级
  final MoneyAgeLevel level;

  /// 当前天数
  final int currentDays;

  /// 下一等级
  final MoneyAgeLevel? nextLevel;

  /// 距下一等级天数
  final int? daysToNextLevel;

  /// 当前等级内的进度（0-1）
  final double progressInLevel;

  /// 健康状态描述
  final String healthStatus;

  /// 建议列表
  final List<String> suggestions;

  const LevelDetails({
    required this.level,
    required this.currentDays,
    this.nextLevel,
    this.daysToNextLevel,
    required this.progressInLevel,
    required this.healthStatus,
    required this.suggestions,
  });

  /// 是否健康
  bool get isHealthy => currentDays >= 14;

  /// 是否需要警告
  bool get needsWarning => level == MoneyAgeLevel.danger || level == MoneyAgeLevel.warning;

  factory LevelDetails.calculate(int days) {
    final level = _getLevelFromDays(days);
    final nextLevel = _getNextLevel(level);

    // 计算进度
    final currentMin = level.minDays;
    final nextMin = nextLevel?.minDays ?? (days + 30);
    final progress = ((days - currentMin) / (nextMin - currentMin)).clamp(0.0, 1.0);

    // 生成健康状态（区分负钱龄）
    String healthStatus;
    if (days < 0) {
      healthStatus = '透支：已消费超过收入${-days}天的额度';
    } else {
      switch (level) {
        case MoneyAgeLevel.danger:
          healthStatus = '危险：您正在花费刚收到的钱';
          break;
        case MoneyAgeLevel.warning:
          healthStatus = '警告：资金缓冲不足';
          break;
        case MoneyAgeLevel.normal:
          healthStatus = '一般：有基本的资金缓冲';
          break;
        case MoneyAgeLevel.good:
          healthStatus = '良好：财务状况健康';
          break;
        case MoneyAgeLevel.excellent:
          healthStatus = '优秀：财务状况非常稳健';
          break;
        case MoneyAgeLevel.ideal:
          healthStatus = '理想：可以从容应对各种情况';
          break;
      }
    }

    // 生成建议（区分负钱龄）
    final suggestions = days < 0 ? _getNegativeSuggestions(days) : _getSuggestions(level);

    return LevelDetails(
      level: level,
      currentDays: days,
      nextLevel: nextLevel,
      daysToNextLevel: nextLevel != null ? nextLevel.minDays - days : null,
      progressInLevel: progress,
      healthStatus: healthStatus,
      suggestions: suggestions,
    );
  }

  static MoneyAgeLevel _getLevelFromDays(int days) {
    if (days < 7) return MoneyAgeLevel.danger;
    if (days < 14) return MoneyAgeLevel.warning;
    if (days < 30) return MoneyAgeLevel.normal;
    if (days < 60) return MoneyAgeLevel.good;
    if (days < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }

  static MoneyAgeLevel? _getNextLevel(MoneyAgeLevel current) {
    final index = MoneyAgeLevel.values.indexOf(current);
    if (index < MoneyAgeLevel.values.length - 1) {
      return MoneyAgeLevel.values[index + 1];
    }
    return null;
  }

  static List<String> _getSuggestions(MoneyAgeLevel level) {
    switch (level) {
      case MoneyAgeLevel.danger:
        return [
          '建议设置紧急储备金目标',
          '检查是否有可削减的非必要支出',
          '考虑增加收入来源',
          '使用小金库功能强制储蓄',
        ];
      case MoneyAgeLevel.warning:
        return [
          '继续保持储蓄习惯',
          '避免大额冲动消费',
          '为下个月的大额支出提前规划',
          '设置预算提醒',
        ];
      case MoneyAgeLevel.normal:
        return [
          '您的财务状况正在改善',
          '尝试每月额外储蓄10%',
          '建立应急基金目标',
          '开始规划长期财务目标',
        ];
      case MoneyAgeLevel.good:
        return [
          '保持良好的财务习惯',
          '可以考虑增加投资配置',
          '设立更长期的财务目标',
          '审视保险配置是否充足',
        ];
      case MoneyAgeLevel.excellent:
        return [
          '您的财务状况非常优秀',
          '可以考虑多元化投资',
          '帮助家人建立良好财务习惯',
          '规划提前退休或财务自由目标',
        ];
      case MoneyAgeLevel.ideal:
        return [
          '恭喜！您已达到理想的财务状态',
          '继续保持这一优秀习惯',
          '可以考虑财务传承规划',
          '分享您的经验帮助更多人',
        ];
    }
  }

  /// 负钱龄专用建议
  static List<String> _getNegativeSuggestions(int negativeDays) {
    final absdays = -negativeDays;
    return [
      '当前入不敷出，已透支约$absdays天的收入',
      '建议立即审视并削减非必要支出',
      '寻找增加收入的机会',
      '避免任何冲动消费，优先还清透支',
      '使用预算功能严格控制每项开支',
    ];
  }
}

/// 钱龄健康等级判定服务
///
/// 功能：
/// 1. 判定当前钱龄的健康等级
/// 2. 计算阶段进度
/// 3. 提供个性化建议
/// 4. 生成等级变化通知
class MoneyAgeLevelService {
  /// 判定等级
  MoneyAgeLevel determineLevel(int days) {
    if (days < 7) return MoneyAgeLevel.danger;
    if (days < 14) return MoneyAgeLevel.warning;
    if (days < 30) return MoneyAgeLevel.normal;
    if (days < 60) return MoneyAgeLevel.good;
    if (days < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }

  /// 获取等级详情
  LevelDetails getLevelDetails(int days) {
    return LevelDetails.calculate(days);
  }

  /// 获取阶段进度
  StageProgress getStageProgress(int days) {
    return StageProgress.calculate(days);
  }

  /// 获取当前阶段
  MoneyAgeStage getCurrentStage(int days) {
    return MoneyAgeStages.getStage(days);
  }

  /// 获取下一阶段
  MoneyAgeStage? getNextStage(int days) {
    return MoneyAgeStages.getNextStage(days);
  }

  /// 检测等级变化
  LevelChange? detectLevelChange(int oldDays, int newDays) {
    final oldLevel = determineLevel(oldDays);
    final newLevel = determineLevel(newDays);

    if (oldLevel == newLevel) return null;

    final isUpgrade = newLevel.index > oldLevel.index;

    return LevelChange(
      oldLevel: oldLevel,
      newLevel: newLevel,
      oldDays: oldDays,
      newDays: newDays,
      isUpgrade: isUpgrade,
      message: isUpgrade
          ? '恭喜！您的钱龄等级从「${oldLevel.displayName}」升级到「${newLevel.displayName}」！'
          : '注意：您的钱龄等级从「${oldLevel.displayName}」降到「${newLevel.displayName}」',
    );
  }

  /// 获取目标等级所需天数
  int getDaysRequiredForLevel(MoneyAgeLevel targetLevel) {
    return targetLevel.minDays;
  }

  /// 估算达到目标等级的时间
  ///
  /// [currentDays] 当前钱龄
  /// [dailyGrowthRate] 每日增长率（可正可负）
  int? estimateDaysToLevel(
    int currentDays,
    MoneyAgeLevel targetLevel, {
    double dailyGrowthRate = 0.5,
  }) {
    if (currentDays >= targetLevel.minDays) return 0;
    if (dailyGrowthRate <= 0) return null;

    final daysNeeded = targetLevel.minDays - currentDays;
    return (daysNeeded / dailyGrowthRate).ceil();
  }

  /// 生成等级摘要信息
  LevelSummary generateSummary(int days) {
    final level = determineLevel(days);
    final stage = getCurrentStage(days);
    final nextStage = getNextStage(days);
    final details = getLevelDetails(days);

    return LevelSummary(
      level: level,
      stage: stage,
      nextStage: nextStage,
      currentDays: days,
      progressToNextLevel: details.progressInLevel,
      daysToNextLevel: details.daysToNextLevel,
      healthStatus: details.healthStatus,
      primarySuggestion: details.suggestions.isNotEmpty
          ? details.suggestions.first
          : '继续保持当前习惯',
    );
  }
}

/// 等级变化信息
class LevelChange {
  final MoneyAgeLevel oldLevel;
  final MoneyAgeLevel newLevel;
  final int oldDays;
  final int newDays;
  final bool isUpgrade;
  final String message;

  const LevelChange({
    required this.oldLevel,
    required this.newLevel,
    required this.oldDays,
    required this.newDays,
    required this.isUpgrade,
    required this.message,
  });

  /// 变化幅度（等级数）
  int get levelDelta => newLevel.index - oldLevel.index;

  /// 是否需要庆祝
  bool get shouldCelebrate => isUpgrade;

  /// 是否需要警告
  bool get shouldWarn => !isUpgrade && newLevel == MoneyAgeLevel.danger;
}

/// 等级摘要
class LevelSummary {
  final MoneyAgeLevel level;
  final MoneyAgeStage stage;
  final MoneyAgeStage? nextStage;
  final int currentDays;
  final double progressToNextLevel;
  final int? daysToNextLevel;
  final String healthStatus;
  final String primarySuggestion;

  const LevelSummary({
    required this.level,
    required this.stage,
    this.nextStage,
    required this.currentDays,
    required this.progressToNextLevel,
    this.daysToNextLevel,
    required this.healthStatus,
    required this.primarySuggestion,
  });

  /// 是否健康
  bool get isHealthy => currentDays >= 14;

  /// 是否已达最高等级
  bool get isMaxLevel => level == MoneyAgeLevel.ideal;

  /// 进度文本
  String get progressText {
    if (isMaxLevel) return '已达最高等级';
    if (daysToNextLevel == null) return '';
    return '距离下一等级还需 $daysToNextLevel 天';
  }
}

/// 钱龄阶段进度服务（整合到 LevelService 中使用）
class MoneyAgeProgressionService {
  /// 获取当前阶段
  MoneyAgeStage getCurrentStage(int days) {
    return MoneyAgeStages.getStage(days);
  }

  /// 获取下一阶段
  MoneyAgeStage? getNextStage(int days) {
    return MoneyAgeStages.getNextStage(days);
  }

  /// 获取阶段进度
  StageProgress getProgress(int days) {
    return StageProgress.calculate(days);
  }

  /// 获取所有阶段（用于进度展示）
  List<MoneyAgeStage> getAllStages() {
    return MoneyAgeStages.all;
  }

  /// 获取已达成的阶段列表
  List<MoneyAgeStage> getAchievedStages(int days) {
    return MoneyAgeStages.getAchievedStages(days);
  }

  /// 计算总积分
  int calculateTotalPoints(int days) {
    return MoneyAgeStages.getAchievedStages(days)
        .map((s) => s.rewardPoints)
        .fold(0, (a, b) => a + b);
  }
}
