import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// 功能ID
typedef FeatureId = String;

/// 功能使用记录
class FeatureUsageRecord {
  /// 功能ID
  final FeatureId featureId;

  /// 使用时间
  final DateTime timestamp;

  /// 使用时长（毫秒）
  final int durationMs;

  /// 操作步骤数
  final int stepCount;

  /// 是否成功完成
  final bool completed;

  /// 上下文信息
  final Map<String, dynamic>? context;

  const FeatureUsageRecord({
    required this.featureId,
    required this.timestamp,
    this.durationMs = 0,
    this.stepCount = 1,
    this.completed = true,
    this.context,
  });

  Map<String, dynamic> toJson() => {
    'featureId': featureId,
    'timestamp': timestamp.toIso8601String(),
    'durationMs': durationMs,
    'stepCount': stepCount,
    'completed': completed,
    'context': context,
  };

  factory FeatureUsageRecord.fromJson(Map<String, dynamic> json) {
    return FeatureUsageRecord(
      featureId: json['featureId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationMs: json['durationMs'] as int? ?? 0,
      stepCount: json['stepCount'] as int? ?? 1,
      completed: json['completed'] as bool? ?? true,
      context: json['context'] as Map<String, dynamic>?,
    );
  }
}

/// 功能权重数据
class FeatureWeight {
  /// 功能ID
  final FeatureId featureId;

  /// 使用频率权重（0-1）
  final double frequencyWeight;

  /// 最近使用权重（0-1）
  final double recencyWeight;

  /// 完成率权重（0-1）
  final double completionWeight;

  /// 效率权重（0-1，基于时长和步骤）
  final double efficiencyWeight;

  /// 综合权重
  double get totalWeight =>
      frequencyWeight * 0.4 +
      recencyWeight * 0.3 +
      completionWeight * 0.2 +
      efficiencyWeight * 0.1;

  /// 使用次数
  final int usageCount;

  /// 最后使用时间
  final DateTime? lastUsed;

  const FeatureWeight({
    required this.featureId,
    this.frequencyWeight = 0,
    this.recencyWeight = 0,
    this.completionWeight = 0,
    this.efficiencyWeight = 0,
    this.usageCount = 0,
    this.lastUsed,
  });

  FeatureWeight copyWith({
    double? frequencyWeight,
    double? recencyWeight,
    double? completionWeight,
    double? efficiencyWeight,
    int? usageCount,
    DateTime? lastUsed,
  }) {
    return FeatureWeight(
      featureId: featureId,
      frequencyWeight: frequencyWeight ?? this.frequencyWeight,
      recencyWeight: recencyWeight ?? this.recencyWeight,
      completionWeight: completionWeight ?? this.completionWeight,
      efficiencyWeight: efficiencyWeight ?? this.efficiencyWeight,
      usageCount: usageCount ?? this.usageCount,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  String toString() =>
      'FeatureWeight($featureId: total=${totalWeight.toStringAsFixed(2)}, '
      'freq=${frequencyWeight.toStringAsFixed(2)}, '
      'rec=${recencyWeight.toStringAsFixed(2)}, '
      'comp=${completionWeight.toStringAsFixed(2)}, '
      'eff=${efficiencyWeight.toStringAsFixed(2)})';
}

/// 功能分组
class FeatureGroup {
  /// 分组ID
  final String groupId;

  /// 分组名称
  final String name;

  /// 功能ID列表
  final List<FeatureId> featureIds;

  /// 分组优先级
  final int priority;

  const FeatureGroup({
    required this.groupId,
    required this.name,
    required this.featureIds,
    this.priority = 0,
  });
}

/// 功能使用权重模型
///
/// 核心功能：
/// 1. 记录功能使用情况
/// 2. 计算功能权重
/// 3. 智能排序功能显示
/// 4. 预测用户下一步操作
/// 5. 优化操作效率
///
/// 对应设计文档：第3章 操作效率模型
///
/// 使用示例：
/// ```dart
/// final model = FeatureUsageWeightModel();
///
/// // 记录功能使用
/// model.recordUsage(FeatureUsageRecord(
///   featureId: 'add_transaction',
///   timestamp: DateTime.now(),
///   durationMs: 3000,
///   completed: true,
/// ));
///
/// // 获取推荐排序
/// final sortedFeatures = model.getSortedFeatures(['add', 'view', 'report']);
/// ```
class FeatureUsageWeightModel extends ChangeNotifier {
  /// 使用记录列表
  final List<FeatureUsageRecord> _records = [];

  /// 功能权重缓存
  final Map<FeatureId, FeatureWeight> _weights = {};

  /// 功能分组
  final List<FeatureGroup> _groups = [];

  /// 最大记录数
  static const int maxRecords = 1000;

  /// 权重衰减因子（最近使用）
  static const double recencyDecayFactor = 0.95;

  /// 时间窗口（天）
  static const int timeWindowDays = 30;

  FeatureUsageWeightModel();

  /// 所有功能权重
  Map<FeatureId, FeatureWeight> get weights => Map.unmodifiable(_weights);

  /// 记录功能使用
  void recordUsage(FeatureUsageRecord record) {
    _records.add(record);

    // 限制记录数量
    while (_records.length > maxRecords) {
      _records.removeAt(0);
    }

    // 更新权重
    _updateWeight(record.featureId);
    notifyListeners();
  }

  /// 批量记录使用
  void recordBatchUsage(List<FeatureUsageRecord> records) {
    _records.addAll(records);

    while (_records.length > maxRecords) {
      _records.removeAt(0);
    }

    final affectedFeatures = records.map((r) => r.featureId).toSet();
    for (final featureId in affectedFeatures) {
      _updateWeight(featureId);
    }
    notifyListeners();
  }

  /// 更新功能权重
  void _updateWeight(FeatureId featureId) {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: timeWindowDays));

    // 获取该功能在时间窗口内的记录
    final featureRecords = _records
        .where((r) =>
            r.featureId == featureId && r.timestamp.isAfter(windowStart))
        .toList();

    if (featureRecords.isEmpty) {
      _weights[featureId] = FeatureWeight(featureId: featureId);
      return;
    }

    // 计算频率权重
    final totalRecords = _records
        .where((r) => r.timestamp.isAfter(windowStart))
        .length;
    final frequencyWeight = totalRecords > 0
        ? featureRecords.length / totalRecords
        : 0.0;

    // 计算最近使用权重
    final lastRecord = featureRecords.last;
    final daysSinceLastUse = now.difference(lastRecord.timestamp).inDays;
    final recencyWeight = math.pow(recencyDecayFactor, daysSinceLastUse).toDouble();

    // 计算完成率权重
    final completedCount = featureRecords.where((r) => r.completed).length;
    final completionWeight = featureRecords.isNotEmpty
        ? completedCount / featureRecords.length
        : 0.0;

    // 计算效率权重（基于平均时长和步骤）
    final avgDuration = featureRecords.fold<double>(
            0, (sum, r) => sum + r.durationMs) /
        featureRecords.length;
    final avgSteps = featureRecords.fold<double>(
            0, (sum, r) => sum + r.stepCount) /
        featureRecords.length;
    // 假设理想时长3秒，理想步骤3步
    final durationEfficiency = math.min(3000 / math.max(avgDuration, 1000), 1.0);
    final stepEfficiency = math.min(3 / math.max(avgSteps, 1), 1.0);
    final efficiencyWeight = (durationEfficiency + stepEfficiency) / 2;

    _weights[featureId] = FeatureWeight(
      featureId: featureId,
      frequencyWeight: frequencyWeight.clamp(0.0, 1.0),
      recencyWeight: recencyWeight.clamp(0.0, 1.0),
      completionWeight: completionWeight.clamp(0.0, 1.0),
      efficiencyWeight: efficiencyWeight.clamp(0.0, 1.0),
      usageCount: featureRecords.length,
      lastUsed: lastRecord.timestamp,
    );
  }

  /// 获取功能权重
  FeatureWeight getWeight(FeatureId featureId) {
    return _weights[featureId] ?? FeatureWeight(featureId: featureId);
  }

  /// 获取排序后的功能列表
  List<FeatureId> getSortedFeatures(List<FeatureId> featureIds) {
    final sorted = List<FeatureId>.from(featureIds);
    sorted.sort((a, b) {
      final weightA = getWeight(a).totalWeight;
      final weightB = getWeight(b).totalWeight;
      return weightB.compareTo(weightA);
    });
    return sorted;
  }

  /// 获取推荐功能（按权重排序的前N个）
  List<FeatureId> getRecommendedFeatures({
    required List<FeatureId> candidates,
    int count = 5,
  }) {
    return getSortedFeatures(candidates).take(count).toList();
  }

  /// 预测下一个可能使用的功能
  FeatureId? predictNextFeature(List<FeatureId> candidates) {
    if (candidates.isEmpty) return null;

    final sorted = getSortedFeatures(candidates);
    return sorted.isNotEmpty ? sorted.first : candidates.first;
  }

  /// 获取功能使用统计
  Map<String, dynamic> getUsageStats(FeatureId featureId) {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: timeWindowDays));

    final featureRecords = _records
        .where((r) =>
            r.featureId == featureId && r.timestamp.isAfter(windowStart))
        .toList();

    if (featureRecords.isEmpty) {
      return {
        'usageCount': 0,
        'avgDuration': 0,
        'avgSteps': 0,
        'completionRate': 0,
        'lastUsed': null,
      };
    }

    return {
      'usageCount': featureRecords.length,
      'avgDuration': featureRecords.fold<double>(
              0, (sum, r) => sum + r.durationMs) /
          featureRecords.length,
      'avgSteps': featureRecords.fold<double>(
              0, (sum, r) => sum + r.stepCount) /
          featureRecords.length,
      'completionRate': featureRecords.where((r) => r.completed).length /
          featureRecords.length,
      'lastUsed': featureRecords.last.timestamp,
    };
  }

  /// 添加功能分组
  void addGroup(FeatureGroup group) {
    _groups.add(group);
    _groups.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// 获取分组内排序后的功能
  List<FeatureId> getSortedFeaturesInGroup(String groupId) {
    final group = _groups.firstWhere(
      (g) => g.groupId == groupId,
      orElse: () => FeatureGroup(groupId: groupId, name: '', featureIds: []),
    );
    return getSortedFeatures(group.featureIds);
  }

  /// 清除历史记录
  void clearRecords() {
    _records.clear();
    _weights.clear();
    notifyListeners();
  }

  /// 导出数据
  Map<String, dynamic> export() {
    return {
      'records': _records.map((r) => r.toJson()).toList(),
      'exportTime': DateTime.now().toIso8601String(),
    };
  }

  /// 导入数据
  void import(Map<String, dynamic> data) {
    final recordsData = data['records'] as List<dynamic>?;
    if (recordsData != null) {
      _records.clear();
      _records.addAll(
        recordsData.map((r) => FeatureUsageRecord.fromJson(r as Map<String, dynamic>)),
      );

      // 重新计算所有权重
      final allFeatures = _records.map((r) => r.featureId).toSet();
      for (final featureId in allFeatures) {
        _updateWeight(featureId);
      }
      notifyListeners();
    }
  }
}

/// 渐进式复杂度服务
///
/// 核心功能：
/// 1. 根据用户熟练度展示功能
/// 2. 新手/进阶/专家模式
/// 3. 功能解锁机制
/// 4. 引导提示管理
///
/// 对应设计文档：第3章 渐进式复杂度功能展示
class ProgressiveDisclosureService extends ChangeNotifier {
  /// 功能使用权重模型
  final FeatureUsageWeightModel? _usageModel;

  /// 用户熟练度等级
  UserExpertiseLevel _expertiseLevel = UserExpertiseLevel.novice;

  /// 已解锁的功能
  final Set<FeatureId> _unlockedFeatures = {};

  /// 功能解锁条件
  final Map<FeatureId, FeatureUnlockCondition> _unlockConditions = {};

  /// 功能复杂度等级
  final Map<FeatureId, FeatureComplexityLevel> _featureComplexity = {};

  /// 已显示的提示
  final Set<String> _shownTips = {};

  ProgressiveDisclosureService({
    FeatureUsageWeightModel? usageModel,
  }) : _usageModel = usageModel {
    _usageModel?.addListener(_onUsageChanged);
  }

  UserExpertiseLevel get expertiseLevel => _expertiseLevel;
  Set<FeatureId> get unlockedFeatures => Set.unmodifiable(_unlockedFeatures);

  /// 监听使用变化
  void _onUsageChanged() {
    _checkUnlockConditions();
    _updateExpertiseLevel();
  }

  /// 设置功能复杂度
  void setFeatureComplexity(
    FeatureId featureId,
    FeatureComplexityLevel level,
  ) {
    _featureComplexity[featureId] = level;
  }

  /// 设置解锁条件
  void setUnlockCondition(
    FeatureId featureId,
    FeatureUnlockCondition condition,
  ) {
    _unlockConditions[featureId] = condition;
  }

  /// 检查功能是否可见
  bool isFeatureVisible(FeatureId featureId) {
    // 已解锁的功能始终可见
    if (_unlockedFeatures.contains(featureId)) {
      return true;
    }

    // 检查复杂度等级
    final complexity = _featureComplexity[featureId] ?? FeatureComplexityLevel.basic;

    switch (_expertiseLevel) {
      case UserExpertiseLevel.novice:
        return complexity == FeatureComplexityLevel.basic;
      case UserExpertiseLevel.intermediate:
        return complexity == FeatureComplexityLevel.basic ||
            complexity == FeatureComplexityLevel.intermediate;
      case UserExpertiseLevel.expert:
        return true;
    }
  }

  /// 获取可见功能列表
  List<FeatureId> getVisibleFeatures(List<FeatureId> allFeatures) {
    return allFeatures.where((f) => isFeatureVisible(f)).toList();
  }

  /// 手动解锁功能
  void unlockFeature(FeatureId featureId) {
    _unlockedFeatures.add(featureId);
    notifyListeners();
  }

  /// 检查解锁条件
  void _checkUnlockConditions() {
    if (_usageModel == null) return;

    for (final entry in _unlockConditions.entries) {
      if (_unlockedFeatures.contains(entry.key)) continue;

      final condition = entry.value;
      final stats = _usageModel.getUsageStats(condition.prerequisiteFeature);
      final usageCount = stats['usageCount'] as int;

      if (usageCount >= condition.requiredUsageCount) {
        _unlockedFeatures.add(entry.key);
      }
    }
  }

  /// 更新熟练度等级
  void _updateExpertiseLevel() {
    if (_usageModel == null) return;

    final weights = _usageModel.weights;
    final totalUsage = weights.values.fold<int>(0, (sum, w) => sum + w.usageCount);

    // 基于总使用次数判断熟练度
    if (totalUsage < 20) {
      _expertiseLevel = UserExpertiseLevel.novice;
    } else if (totalUsage < 100) {
      _expertiseLevel = UserExpertiseLevel.intermediate;
    } else {
      _expertiseLevel = UserExpertiseLevel.expert;
    }

    notifyListeners();
  }

  /// 手动设置熟练度等级
  void setExpertiseLevel(UserExpertiseLevel level) {
    _expertiseLevel = level;
    notifyListeners();
  }

  /// 检查是否应该显示提示
  bool shouldShowTip(String tipId) {
    return !_shownTips.contains(tipId);
  }

  /// 标记提示已显示
  void markTipShown(String tipId) {
    _shownTips.add(tipId);
  }

  /// 重置提示状态
  void resetTips() {
    _shownTips.clear();
  }

  /// 获取功能引导内容
  FeatureGuide? getFeatureGuide(FeatureId featureId) {
    // 只为新手提供引导
    if (_expertiseLevel != UserExpertiseLevel.novice) {
      return null;
    }

    // 检查是否已显示过
    if (_shownTips.contains('guide_$featureId')) {
      return null;
    }

    // 返回预定义的引导内容
    return _featureGuides[featureId];
  }

  /// 预定义的功能引导
  static final Map<FeatureId, FeatureGuide> _featureGuides = {
    'add_transaction': FeatureGuide(
      featureId: 'add_transaction',
      title: '添加交易',
      description: '点击底部的加号按钮，快速记录一笔消费或收入',
      steps: ['点击 + 按钮', '输入金额', '选择分类', '保存'],
    ),
    'view_report': FeatureGuide(
      featureId: 'view_report',
      title: '查看报表',
      description: '在报表页面可以查看您的消费趋势和分类占比',
      steps: ['点击底部报表图标', '选择时间范围', '查看各类图表'],
    ),
  };

  @override
  void dispose() {
    _usageModel?.removeListener(_onUsageChanged);
    super.dispose();
  }
}

/// 用户熟练度等级
enum UserExpertiseLevel {
  /// 新手
  novice,

  /// 进阶
  intermediate,

  /// 专家
  expert,
}

/// 功能复杂度等级
enum FeatureComplexityLevel {
  /// 基础
  basic,

  /// 中级
  intermediate,

  /// 高级
  advanced,
}

/// 功能解锁条件
class FeatureUnlockCondition {
  /// 前置功能
  final FeatureId prerequisiteFeature;

  /// 需要的使用次数
  final int requiredUsageCount;

  /// 自定义条件
  final bool Function()? customCondition;

  const FeatureUnlockCondition({
    required this.prerequisiteFeature,
    this.requiredUsageCount = 5,
    this.customCondition,
  });
}

/// 功能引导内容
class FeatureGuide {
  /// 功能ID
  final FeatureId featureId;

  /// 标题
  final String title;

  /// 描述
  final String description;

  /// 步骤
  final List<String> steps;

  /// 图片URL
  final String? imageUrl;

  const FeatureGuide({
    required this.featureId,
    required this.title,
    required this.description,
    this.steps = const [],
    this.imageUrl,
  });
}
