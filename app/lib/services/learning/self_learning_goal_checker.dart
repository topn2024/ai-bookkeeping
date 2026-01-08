import 'package:flutter/foundation.dart';

import 'unified_self_learning_service.dart';

/// 目标检查接口
abstract class GoalChecker {
  String get goalId;
  Future<GoalCheckResult> check();
}

/// 目标检查结果
class GoalCheckResult {
  final String goalId;
  final bool passed;
  final List<GoalCheckItem> items;
  final DateTime checkedAt;
  final String? summary;

  const GoalCheckResult({
    required this.goalId,
    required this.passed,
    required this.items,
    required this.checkedAt,
    this.summary,
  });

  /// 获取通过的检查项数量
  int get passedCount => items.where((i) => i.passed).length;

  /// 获取通过率
  double get passRate => items.isEmpty ? 0 : passedCount / items.length;

  /// 生成报告文本
  String toReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== 目标检查报告: $goalId ===');
    buffer.writeln('检查时间: $checkedAt');
    buffer.writeln('整体结果: ${passed ? "通过" : "未通过"}');
    buffer.writeln('通过率: ${(passRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('');

    for (final item in items) {
      final status = item.passed ? '✓' : '✗';
      buffer.writeln('$status ${item.name}');
      buffer.writeln('  目标: ${item.target}');
      buffer.writeln('  实际: ${item.actual}');
      if (item.detail != null) {
        buffer.writeln('  详情: ${item.detail}');
      }
    }

    if (summary != null) {
      buffer.writeln('');
      buffer.writeln('总结: $summary');
    }

    return buffer.toString();
  }
}

/// 单个检查项
class GoalCheckItem {
  final String name;
  final String target;
  final String actual;
  final bool passed;
  final String? detail;

  const GoalCheckItem({
    required this.name,
    required this.target,
    required this.actual,
    required this.passed,
    this.detail,
  });
}

/// 自学习系统目标检测服务
class SelfLearningGoalChecker implements GoalChecker {
  final UnifiedSelfLearningService _service;

  // 配置阈值
  final double _targetOverallAccuracy;
  final double _targetModuleAccuracy;
  final int _targetMinRules;
  final int _targetMinSamples;

  SelfLearningGoalChecker({
    UnifiedSelfLearningService? service,
    double targetOverallAccuracy = 0.80,
    double targetModuleAccuracy = 0.75,
    int targetMinRules = 50,
    int targetMinSamples = 100,
  })  : _service = service ?? UnifiedSelfLearningService(),
        _targetOverallAccuracy = targetOverallAccuracy,
        _targetModuleAccuracy = targetModuleAccuracy,
        _targetMinRules = targetMinRules,
        _targetMinSamples = targetMinSamples;

  @override
  String get goalId => 'self_learning_effectiveness';

  @override
  Future<GoalCheckResult> check() async {
    final report = await _service.getOverallReport();
    final statuses = await _service.getAllModuleStatus();
    final checks = <GoalCheckItem>[];

    // 1. 检查整体准确率
    checks.add(GoalCheckItem(
      name: '整体学习准确率',
      target: '>= ${(_targetOverallAccuracy * 100).toStringAsFixed(0)}%',
      actual: '${(report.overallAccuracy * 100).toStringAsFixed(1)}%',
      passed: report.overallAccuracy >= _targetOverallAccuracy,
      detail: report.overallAccuracy < _targetOverallAccuracy
          ? '还需提升${((_targetOverallAccuracy - report.overallAccuracy) * 100).toStringAsFixed(1)}%'
          : null,
    ));

    // 2. 检查规则生成数量
    checks.add(GoalCheckItem(
      name: '已学习规则数',
      target: '>= $_targetMinRules',
      actual: '${report.totalRules}',
      passed: report.totalRules >= _targetMinRules,
      detail: report.totalRules < _targetMinRules
          ? '还需生成${_targetMinRules - report.totalRules}条规则'
          : null,
    ));

    // 3. 检查样本数量
    checks.add(GoalCheckItem(
      name: '学习样本数',
      target: '>= $_targetMinSamples',
      actual: '${report.totalSamples}',
      passed: report.totalSamples >= _targetMinSamples,
      detail: report.totalSamples < _targetMinSamples
          ? '还需${_targetMinSamples - report.totalSamples}个样本'
          : null,
    ));

    // 4. 检查各模块状态
    int activeModules = 0;
    int totalModules = statuses.length;

    for (final entry in statuses.entries) {
      if (entry.value.stage == LearningStage.active) {
        activeModules++;
      }
    }

    checks.add(GoalCheckItem(
      name: '活跃模块数',
      target: '所有模块活跃',
      actual: '$activeModules/$totalModules',
      passed: activeModules == totalModules,
      detail: activeModules < totalModules
          ? '${totalModules - activeModules}个模块未激活'
          : null,
    ));

    // 5. 检查各模块准确率
    for (final entry in report.moduleMetrics.entries) {
      final moduleId = entry.key;
      final metrics = entry.value;
      final moduleName = _getModuleName(moduleId);

      checks.add(GoalCheckItem(
        name: '$moduleName模块准确率',
        target: '>= ${(_targetModuleAccuracy * 100).toStringAsFixed(0)}%',
        actual: '${(metrics.accuracy * 100).toStringAsFixed(1)}%',
        passed: metrics.accuracy >= _targetModuleAccuracy,
        detail: metrics.accuracy < _targetModuleAccuracy
            ? '需提升${((_targetModuleAccuracy - metrics.accuracy) * 100).toStringAsFixed(1)}%'
            : null,
      ));
    }

    // 6. 检查冷启动状态
    final coldStartModules = statuses.values
        .where((s) => s.stage == LearningStage.coldStart)
        .length;

    checks.add(GoalCheckItem(
      name: '冷启动完成',
      target: '无模块处于冷启动',
      actual: coldStartModules == 0 ? '已完成' : '$coldStartModules个模块冷启动中',
      passed: coldStartModules == 0,
    ));

    // 生成总结
    final passedItems = checks.where((c) => c.passed).length;
    final summary = _generateSummary(
      passedItems,
      checks.length,
      report.overallAccuracy,
      report.totalRules,
    );

    return GoalCheckResult(
      goalId: goalId,
      passed: checks.every((c) => c.passed),
      items: checks,
      checkedAt: DateTime.now(),
      summary: summary,
    );
  }

  String _getModuleName(String moduleId) {
    switch (moduleId) {
      case 'smart_category':
        return '智能分类';
      case 'anomaly_detection':
        return '异常检测';
      case 'intent_recognition':
        return '意图识别';
      case 'budget_suggestion':
        return '预算建议';
      case 'search_learning':
        return '搜索学习';
      case 'dialogue_learning':
        return '对话学习';
      default:
        return moduleId;
    }
  }

  String _generateSummary(
    int passedItems,
    int totalItems,
    double accuracy,
    int rules,
  ) {
    if (passedItems == totalItems) {
      return '自学习系统运行良好，所有目标均已达成。';
    }

    final buffer = StringBuffer();
    buffer.write('自学习系统完成度${(passedItems / totalItems * 100).toStringAsFixed(0)}%。');

    if (accuracy < _targetOverallAccuracy) {
      buffer.write('建议继续收集用户反馈以提升准确率。');
    }

    if (rules < _targetMinRules) {
      buffer.write('规则数量不足，系统仍在学习阶段。');
    }

    return buffer.toString();
  }
}

/// 综合目标检查服务
class ComprehensiveGoalCheckService {
  final List<GoalChecker> _checkers;

  ComprehensiveGoalCheckService({List<GoalChecker>? checkers})
      : _checkers = checkers ?? [];

  /// 注册目标检查器
  void registerChecker(GoalChecker checker) {
    _checkers.add(checker);
  }

  /// 运行所有检查
  Future<ComprehensiveCheckResult> runAllChecks() async {
    final results = <GoalCheckResult>[];

    for (final checker in _checkers) {
      try {
        final result = await checker.check();
        results.add(result);
      } catch (e) {
        debugPrint('Goal check failed for ${checker.goalId}: $e');
      }
    }

    return ComprehensiveCheckResult(
      results: results,
      checkedAt: DateTime.now(),
    );
  }

  /// 检查特定目标
  Future<GoalCheckResult?> checkGoal(String goalId) async {
    final checker = _checkers.firstWhere(
      (c) => c.goalId == goalId,
      orElse: () => throw Exception('Goal checker not found: $goalId'),
    );
    return checker.check();
  }
}

/// 综合检查结果
class ComprehensiveCheckResult {
  final List<GoalCheckResult> results;
  final DateTime checkedAt;

  const ComprehensiveCheckResult({
    required this.results,
    required this.checkedAt,
  });

  /// 所有目标是否通过
  bool get allPassed => results.every((r) => r.passed);

  /// 通过的目标数量
  int get passedCount => results.where((r) => r.passed).length;

  /// 总体通过率
  double get overallPassRate =>
      results.isEmpty ? 0 : passedCount / results.length;

  /// 生成综合报告
  String toReport() {
    final buffer = StringBuffer();
    buffer.writeln('====== 综合目标检查报告 ======');
    buffer.writeln('检查时间: $checkedAt');
    buffer.writeln('检查目标数: ${results.length}');
    buffer.writeln('通过目标数: $passedCount');
    buffer.writeln(
        '整体通过率: ${(overallPassRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('');

    for (final result in results) {
      buffer.writeln('--- ${result.goalId} ---');
      buffer.writeln('状态: ${result.passed ? "通过" : "未通过"}');
      buffer.writeln('检查项: ${result.passedCount}/${result.items.length} 通过');
      if (result.summary != null) {
        buffer.writeln('总结: ${result.summary}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

/// 学习效果趋势分析
class LearningTrendAnalyzer {
  final List<LearningEffectReport> _historicalReports;

  LearningTrendAnalyzer(this._historicalReports);

  /// 计算准确率趋势
  LearningTrend analyzeAccuracyTrend() {
    if (_historicalReports.length < 2) {
      return LearningTrend(
        direction: TrendDirection.stable,
        changeRate: 0,
        confidence: 0,
      );
    }

    final recentAccuracy = _historicalReports.last.overallAccuracy;
    final previousAccuracy =
        _historicalReports[_historicalReports.length - 2].overallAccuracy;
    final changeRate = recentAccuracy - previousAccuracy;

    TrendDirection direction;
    if (changeRate > 0.05) {
      direction = TrendDirection.improving;
    } else if (changeRate < -0.05) {
      direction = TrendDirection.declining;
    } else {
      direction = TrendDirection.stable;
    }

    return LearningTrend(
      direction: direction,
      changeRate: changeRate,
      confidence: 0.8,
    );
  }

  /// 计算规则增长趋势
  LearningTrend analyzeRuleGrowthTrend() {
    if (_historicalReports.length < 2) {
      return LearningTrend(
        direction: TrendDirection.stable,
        changeRate: 0,
        confidence: 0,
      );
    }

    final recentRules = _historicalReports.last.totalRules;
    final previousRules =
        _historicalReports[_historicalReports.length - 2].totalRules;
    final changeRate = previousRules > 0
        ? (recentRules - previousRules) / previousRules
        : recentRules.toDouble();

    TrendDirection direction;
    if (changeRate > 0.1) {
      direction = TrendDirection.improving;
    } else if (changeRate < 0) {
      direction = TrendDirection.declining;
    } else {
      direction = TrendDirection.stable;
    }

    return LearningTrend(
      direction: direction,
      changeRate: changeRate,
      confidence: 0.7,
    );
  }
}

/// 学习趋势
class LearningTrend {
  final TrendDirection direction;
  final double changeRate;
  final double confidence;

  const LearningTrend({
    required this.direction,
    required this.changeRate,
    required this.confidence,
  });

  String get description {
    switch (direction) {
      case TrendDirection.improving:
        return '持续改善中 (+${(changeRate * 100).toStringAsFixed(1)}%)';
      case TrendDirection.declining:
        return '有所下降 (${(changeRate * 100).toStringAsFixed(1)}%)';
      case TrendDirection.stable:
        return '保持稳定';
    }
  }
}

/// 趋势方向
enum TrendDirection {
  improving, // 改善中
  stable, // 稳定
  declining, // 下降中
}
