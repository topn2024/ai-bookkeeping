import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/budget_vault.dart';
import '../models/transaction.dart';
import 'vault_repository.dart';

/// 学习数据来源
enum LearningSource {
  /// 历史消费数据
  historicalSpending,

  /// 用户反馈
  userFeedback,

  /// 预算执行结果
  budgetExecution,

  /// 季节性模式
  seasonalPattern,

  /// 外部数据（如物价指数）
  externalData,
}

/// 用户反馈类型
enum FeedbackType {
  /// 预算太高
  budgetTooHigh,

  /// 预算太低
  budgetTooLow,

  /// 类目不需要
  categoryNotNeeded,

  /// 需要新类目
  needNewCategory,

  /// 建议有用
  suggestionHelpful,

  /// 建议无用
  suggestionNotHelpful,
}

/// 用户反馈记录
class UserFeedback {
  final String id;
  final FeedbackType type;
  final String? categoryId;
  final String? vaultId;
  final double? suggestedAmount;
  final String? comment;
  final DateTime createdAt;

  const UserFeedback({
    required this.id,
    required this.type,
    this.categoryId,
    this.vaultId,
    this.suggestedAmount,
    this.comment,
    required this.createdAt,
  });
}

/// 学习后的预算调整
class LearnedBudgetAdjustment {
  final String categoryId;
  final String categoryName;
  final double originalAmount;
  final double adjustedAmount;
  final double adjustmentFactor; // 调整系数（1.0 = 不变）
  final String reason;
  final double confidence;
  final List<LearningSource> sources;

  const LearnedBudgetAdjustment({
    required this.categoryId,
    required this.categoryName,
    required this.originalAmount,
    required this.adjustedAmount,
    required this.adjustmentFactor,
    required this.reason,
    required this.confidence,
    required this.sources,
  });

  double get change => adjustedAmount - originalAmount;
  bool get isIncrease => adjustmentFactor > 1;
  bool get isDecrease => adjustmentFactor < 1;
  bool get isNoChange => adjustmentFactor == 1;
}

/// 学习模型状态
class LearningModelState {
  final int trainedSamples;
  final DateTime? lastTrainedAt;
  final double modelAccuracy;
  final Map<String, double> categoryWeights;
  final Map<int, double> seasonalFactors; // 月份 -> 季节因子

  const LearningModelState({
    required this.trainedSamples,
    this.lastTrainedAt,
    required this.modelAccuracy,
    required this.categoryWeights,
    required this.seasonalFactors,
  });

  factory LearningModelState.initial() {
    return const LearningModelState(
      trainedSamples: 0,
      modelAccuracy: 0.5,
      categoryWeights: {},
      seasonalFactors: {},
    );
  }
}

/// 预算执行评估
class BudgetExecutionEvaluation {
  final String vaultId;
  final String vaultName;
  final double allocatedAmount;
  final double spentAmount;
  final double usageRate;
  final ExecutionGrade grade;
  final String evaluation;
  final LearnedBudgetAdjustment? suggestedAdjustment;

  const BudgetExecutionEvaluation({
    required this.vaultId,
    required this.vaultName,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.usageRate,
    required this.grade,
    required this.evaluation,
    this.suggestedAdjustment,
  });
}

/// 执行评级
enum ExecutionGrade {
  /// 优秀（使用70-90%）
  excellent,

  /// 良好（使用50-70% 或 90-100%）
  good,

  /// 需改进（使用<50% 或 超支）
  needsImprovement,
}

/// 自学习预算建议服务
///
/// 基于历史数据、用户反馈和预算执行情况，
/// 动态调整预算建议，提供个性化的预算优化方案
class SelfLearningBudgetService {
  final Database _db;
  final VaultRepository _vaultRepo;

  // 学习模型状态
  LearningModelState _modelState = LearningModelState.initial();

  // 用户反馈记录
  final List<UserFeedback> _feedbacks = [];

  // 历史执行数据
  final List<_MonthlyExecution> _executionHistory = [];

  // 学习参数
  static const double _learningRate = 0.1; // 学习率
  static const int _minSamplesForLearning = 3; // 最小学习样本数
  static const double _confidenceThreshold = 0.6; // 置信度阈值

  SelfLearningBudgetService(this._db, this._vaultRepo);

  /// 获取学习后的预算建议
  Future<List<LearnedBudgetAdjustment>> getLearnedSuggestions() async {
    final adjustments = <LearnedBudgetAdjustment>[];
    final vaults = await _vaultRepo.getEnabled();

    for (final vault in vaults) {
      final adjustment = await _calculateAdjustment(vault);
      if (adjustment != null) {
        adjustments.add(adjustment);
      }
    }

    // 按调整幅度排序
    adjustments.sort((a, b) =>
        (b.adjustmentFactor - 1).abs().compareTo((a.adjustmentFactor - 1).abs()));

    return adjustments;
  }

  /// 记录用户反馈
  Future<void> recordFeedback({
    required FeedbackType type,
    String? categoryId,
    String? vaultId,
    double? suggestedAmount,
    String? comment,
  }) async {
    final feedback = UserFeedback(
      id: 'feedback_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      categoryId: categoryId,
      vaultId: vaultId,
      suggestedAmount: suggestedAmount,
      comment: comment,
      createdAt: DateTime.now(),
    );

    _feedbacks.add(feedback);

    // 触发增量学习
    await _incrementalLearn(feedback);
  }

  /// 评估预算执行情况
  Future<List<BudgetExecutionEvaluation>> evaluateBudgetExecution() async {
    final evaluations = <BudgetExecutionEvaluation>[];
    final vaults = await _vaultRepo.getEnabled();

    for (final vault in vaults) {
      final grade = _gradeExecution(vault.usageRate, vault.type);
      final evaluation = _generateEvaluation(vault, grade);
      final adjustment = await _calculateAdjustment(vault);

      evaluations.add(BudgetExecutionEvaluation(
        vaultId: vault.id,
        vaultName: vault.name,
        allocatedAmount: vault.allocatedAmount,
        spentAmount: vault.spentAmount,
        usageRate: vault.usageRate,
        grade: grade,
        evaluation: evaluation,
        suggestedAdjustment: adjustment,
      ));
    }

    return evaluations;
  }

  /// 训练学习模型
  Future<void> trainModel() async {
    // 获取历史数据
    final historicalData = await _getHistoricalData();
    if (historicalData.length < _minSamplesForLearning) {
      return; // 数据不足
    }

    // 更新类目权重
    final categoryWeights = <String, double>{};
    for (final data in historicalData) {
      for (final entry in data.categorySpending.entries) {
        final current = categoryWeights[entry.key] ?? 0;
        categoryWeights[entry.key] = current + entry.value;
      }
    }

    // 归一化权重
    final total = categoryWeights.values.fold(0.0, (a, b) => a + b);
    if (total > 0) {
      categoryWeights.updateAll((key, value) => value / total);
    }

    // 计算季节因子
    final seasonalFactors = _calculateSeasonalFactors(historicalData);

    // 评估模型准确度
    final accuracy = _evaluateModelAccuracy(historicalData);

    // 更新模型状态
    _modelState = LearningModelState(
      trainedSamples: historicalData.length,
      lastTrainedAt: DateTime.now(),
      modelAccuracy: accuracy,
      categoryWeights: categoryWeights,
      seasonalFactors: seasonalFactors,
    );
  }

  /// 获取学习洞察
  Future<List<LearningInsight>> getLearningInsights() async {
    final insights = <LearningInsight>[];
    final vaults = await _vaultRepo.getEnabled();

    // 分析超支模式
    final overspentVaults = vaults.where((v) => v.isOverSpent).toList();
    if (overspentVaults.length >= 2) {
      insights.add(LearningInsight(
        type: InsightType.pattern,
        title: '发现超支模式',
        description: '${overspentVaults.map((v) => v.name).join("、")}经常超支，'
            '建议重新评估这些类目的预算设置。',
        confidence: 0.8,
        actionable: true,
      ));
    }

    // 分析闲置预算
    final underusedVaults = vaults.where((v) =>
        v.type == VaultType.flexible && v.usageRate < 0.3).toList();
    if (underusedVaults.isNotEmpty) {
      final totalUnused = underusedVaults.fold(
        0.0,
        (sum, v) => sum + (v.allocatedAmount - v.spentAmount),
      );
      insights.add(LearningInsight(
        type: InsightType.optimization,
        title: '发现闲置预算',
        description: '${underusedVaults.length}个小金库使用率低于30%，'
            '共有¥${totalUnused.toStringAsFixed(0)}可调配到其他用途。',
        confidence: 0.7,
        actionable: true,
      ));
    }

    // 分析储蓄率
    final savingsVaults = vaults.where((v) => v.type == VaultType.savings);
    final savingsTotal = savingsVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final totalAllocated = vaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final savingsRate = totalAllocated > 0 ? savingsTotal / totalAllocated : 0;

    if (savingsRate < 0.15) {
      insights.add(LearningInsight(
        type: InsightType.recommendation,
        title: '储蓄率偏低',
        description: '当前储蓄占比仅${(savingsRate * 100).toStringAsFixed(1)}%，'
            '建议提高到15%以上以建立财务缓冲。',
        confidence: 0.9,
        actionable: true,
      ));
    }

    // 季节性提醒
    final currentMonth = DateTime.now().month;
    final seasonalFactor = _modelState.seasonalFactors[currentMonth] ?? 1.0;
    if (seasonalFactor > 1.1) {
      insights.add(LearningInsight(
        type: InsightType.seasonal,
        title: '本月消费高峰',
        description: '历史数据显示本月消费通常较高，'
            '建议预留${((seasonalFactor - 1) * 100).toStringAsFixed(0)}%的额外预算。',
        confidence: 0.6,
        actionable: false,
      ));
    }

    return insights;
  }

  /// 获取模型状态
  LearningModelState getModelState() => _modelState;

  /// 预测下月预算需求
  Future<Map<String, double>> predictNextMonthBudget() async {
    final predictions = <String, double>{};
    final vaults = await _vaultRepo.getEnabled();

    final nextMonth = (DateTime.now().month % 12) + 1;
    final seasonalFactor = _modelState.seasonalFactors[nextMonth] ?? 1.0;

    for (final vault in vaults) {
      // 基于历史使用率预测
      double baseAmount = vault.targetAmount;

      // 如果经常超支，增加预算
      if (vault.usageRate > 1.0) {
        baseAmount *= 1.1;
      }
      // 如果经常剩余，减少预算
      else if (vault.usageRate < 0.5) {
        baseAmount *= 0.9;
      }

      // 应用季节因子
      if (vault.type == VaultType.flexible) {
        baseAmount *= seasonalFactor;
      }

      predictions[vault.id] = baseAmount;
    }

    return predictions;
  }

  /// 自动优化预算配置
  Future<BudgetOptimizationResult> autoOptimizeBudget() async {
    final adjustments = await getLearnedSuggestions();
    final optimizations = <BudgetOptimization>[];

    // 找出需要减少的预算
    final decreaseAdjustments = adjustments.where((a) => a.isDecrease).toList();
    final totalDecrease = decreaseAdjustments.fold(
      0.0,
      (sum, a) => sum + a.change.abs(),
    );

    // 找出需要增加的预算
    final increaseAdjustments = adjustments.where((a) => a.isIncrease).toList();

    // 重新分配
    var available = totalDecrease;
    for (final increase in increaseAdjustments) {
      if (available <= 0) break;

      final actualIncrease = min(increase.change, available);
      optimizations.add(BudgetOptimization(
        categoryId: increase.categoryId,
        categoryName: increase.categoryName,
        action: OptimizationAction.increase,
        amount: actualIncrease,
        reason: increase.reason,
      ));
      available -= actualIncrease;
    }

    for (final decrease in decreaseAdjustments) {
      optimizations.add(BudgetOptimization(
        categoryId: decrease.categoryId,
        categoryName: decrease.categoryName,
        action: OptimizationAction.decrease,
        amount: decrease.change.abs(),
        reason: decrease.reason,
      ));
    }

    // 剩余资金建议转入储蓄
    if (available > 0) {
      optimizations.add(BudgetOptimization(
        categoryId: 'savings',
        categoryName: '储蓄',
        action: OptimizationAction.increase,
        amount: available,
        reason: '闲置预算建议转入储蓄',
      ));
    }

    return BudgetOptimizationResult(
      optimizations: optimizations,
      totalOptimized: totalDecrease,
      estimatedSavings: available,
      confidence: _modelState.modelAccuracy,
    );
  }

  // ==================== 私有方法 ====================

  /// 计算单个小金库的调整建议
  Future<LearnedBudgetAdjustment?> _calculateAdjustment(BudgetVault vault) async {
    final sources = <LearningSource>[];
    var adjustmentFactor = 1.0;
    var confidence = 0.5;
    String reason;

    // 1. 基于历史使用率调整
    if (vault.usageRate > 1.1) {
      // 经常超支，建议增加
      adjustmentFactor = 1 + (vault.usageRate - 1) * 0.5;
      sources.add(LearningSource.historicalSpending);
      reason = '历史超支${((vault.usageRate - 1) * 100).toStringAsFixed(0)}%，建议增加预算';
      confidence = 0.7;
    } else if (vault.usageRate < 0.4 && vault.type == VaultType.flexible) {
      // 使用率低，建议减少
      adjustmentFactor = 0.8;
      sources.add(LearningSource.historicalSpending);
      reason = '历史使用率仅${(vault.usageRate * 100).toStringAsFixed(0)}%，建议减少预算';
      confidence = 0.6;
    } else {
      return null; // 不需要调整
    }

    // 2. 基于用户反馈调整
    final relevantFeedbacks = _feedbacks.where(
      (f) => f.vaultId == vault.id || f.categoryId == vault.categoryId,
    ).toList();

    for (final feedback in relevantFeedbacks) {
      switch (feedback.type) {
        case FeedbackType.budgetTooHigh:
          adjustmentFactor *= 0.9;
          sources.add(LearningSource.userFeedback);
          break;
        case FeedbackType.budgetTooLow:
          adjustmentFactor *= 1.1;
          sources.add(LearningSource.userFeedback);
          break;
        default:
          break;
      }
    }

    // 3. 应用季节因子
    final currentMonth = DateTime.now().month;
    final seasonalFactor = _modelState.seasonalFactors[currentMonth] ?? 1.0;
    if (vault.type == VaultType.flexible && (seasonalFactor - 1).abs() > 0.05) {
      adjustmentFactor *= seasonalFactor;
      sources.add(LearningSource.seasonalPattern);
    }

    // 限制调整幅度
    adjustmentFactor = adjustmentFactor.clamp(0.7, 1.5);

    return LearnedBudgetAdjustment(
      categoryId: vault.categoryId ?? vault.id,
      categoryName: vault.name,
      originalAmount: vault.targetAmount,
      adjustedAmount: vault.targetAmount * adjustmentFactor,
      adjustmentFactor: adjustmentFactor,
      reason: reason,
      confidence: confidence,
      sources: sources,
    );
  }

  /// 增量学习
  Future<void> _incrementalLearn(UserFeedback feedback) async {
    // 根据反馈类型调整模型
    switch (feedback.type) {
      case FeedbackType.budgetTooHigh:
        if (feedback.categoryId != null) {
          final current = _modelState.categoryWeights[feedback.categoryId] ?? 1.0;
          _modelState = LearningModelState(
            trainedSamples: _modelState.trainedSamples + 1,
            lastTrainedAt: DateTime.now(),
            modelAccuracy: _modelState.modelAccuracy,
            categoryWeights: {
              ..._modelState.categoryWeights,
              feedback.categoryId!: current * (1 - _learningRate),
            },
            seasonalFactors: _modelState.seasonalFactors,
          );
        }
        break;
      case FeedbackType.budgetTooLow:
        if (feedback.categoryId != null) {
          final current = _modelState.categoryWeights[feedback.categoryId] ?? 1.0;
          _modelState = LearningModelState(
            trainedSamples: _modelState.trainedSamples + 1,
            lastTrainedAt: DateTime.now(),
            modelAccuracy: _modelState.modelAccuracy,
            categoryWeights: {
              ..._modelState.categoryWeights,
              feedback.categoryId!: current * (1 + _learningRate),
            },
            seasonalFactors: _modelState.seasonalFactors,
          );
        }
        break;
      default:
        break;
    }
  }

  /// 获取历史数据
  Future<List<_MonthlyExecution>> _getHistoricalData() async {
    // 查询最近6个月的执行数据
    final results = <_MonthlyExecution>[];
    final now = DateTime.now();

    for (var i = 1; i <= 6; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final transactions = await _db.rawQuery('''
        SELECT categoryId, SUM(amount) as total
        FROM transactions
        WHERE type = ? AND date >= ? AND date <= ?
        GROUP BY categoryId
      ''', [
        TransactionType.expense.index,
        month.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch,
      ]);

      final categorySpending = <String, double>{};
      for (final tx in transactions) {
        final categoryId = tx['categoryId'] as String?;
        if (categoryId != null) {
          categorySpending[categoryId] = (tx['total'] as num).toDouble();
        }
      }

      if (categorySpending.isNotEmpty) {
        results.add(_MonthlyExecution(
          month: month,
          categorySpending: categorySpending,
        ));
      }
    }

    return results;
  }

  /// 计算季节因子
  Map<int, double> _calculateSeasonalFactors(List<_MonthlyExecution> data) {
    final monthlyTotals = <int, List<double>>{};

    for (final execution in data) {
      final month = execution.month.month;
      final total = execution.categorySpending.values.fold(0.0, (a, b) => a + b);
      monthlyTotals.putIfAbsent(month, () => []).add(total);
    }

    // 计算平均值
    final overallAverage = data.map((e) =>
        e.categorySpending.values.fold(0.0, (a, b) => a + b)
    ).fold(0.0, (a, b) => a + b) / data.length;

    final factors = <int, double>{};
    for (final entry in monthlyTotals.entries) {
      final monthAverage = entry.value.reduce((a, b) => a + b) / entry.value.length;
      factors[entry.key] = overallAverage > 0 ? monthAverage / overallAverage : 1.0;
    }

    return factors;
  }

  /// 评估模型准确度
  double _evaluateModelAccuracy(List<_MonthlyExecution> data) {
    if (data.length < 2) return 0.5;

    // 简单评估：预测误差率
    var totalError = 0.0;
    var count = 0;

    for (var i = 1; i < data.length; i++) {
      final predicted = data[i - 1].categorySpending;
      final actual = data[i].categorySpending;

      for (final category in actual.keys) {
        final p = predicted[category] ?? 0;
        final a = actual[category]!;
        if (a > 0) {
          totalError += ((p - a).abs() / a);
          count++;
        }
      }
    }

    final averageError = count > 0 ? totalError / count : 0.5;
    return (1 - averageError).clamp(0.3, 0.95);
  }

  /// 评估预算执行
  ExecutionGrade _gradeExecution(double usageRate, VaultType type) {
    if (type == VaultType.savings) {
      // 储蓄目标：进度越高越好
      if (usageRate >= 0.9) return ExecutionGrade.excellent;
      if (usageRate >= 0.6) return ExecutionGrade.good;
      return ExecutionGrade.needsImprovement;
    }

    // 支出类：70-90%使用率为最佳
    if (usageRate >= 0.7 && usageRate <= 0.9) {
      return ExecutionGrade.excellent;
    }
    if (usageRate >= 0.5 && usageRate <= 1.0) {
      return ExecutionGrade.good;
    }
    return ExecutionGrade.needsImprovement;
  }

  /// 生成评估文案
  String _generateEvaluation(BudgetVault vault, ExecutionGrade grade) {
    final usagePercent = (vault.usageRate * 100).toStringAsFixed(0);

    switch (grade) {
      case ExecutionGrade.excellent:
        return '${vault.name}预算执行优秀，使用率$usagePercent%，配置合理';
      case ExecutionGrade.good:
        return '${vault.name}预算执行良好，使用率$usagePercent%';
      case ExecutionGrade.needsImprovement:
        if (vault.usageRate > 1) {
          return '${vault.name}超支${((vault.usageRate - 1) * 100).toStringAsFixed(0)}%，建议增加预算或控制消费';
        } else {
          return '${vault.name}使用率仅$usagePercent%，预算可能设置过高';
        }
    }
  }
}

/// 月度执行数据
class _MonthlyExecution {
  final DateTime month;
  final Map<String, double> categorySpending;

  const _MonthlyExecution({
    required this.month,
    required this.categorySpending,
  });
}

/// 学习洞察
class LearningInsight {
  final InsightType type;
  final String title;
  final String description;
  final double confidence;
  final bool actionable;

  const LearningInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    required this.actionable,
  });
}

/// 洞察类型
enum InsightType {
  pattern,
  optimization,
  recommendation,
  seasonal,
  anomaly,
}

/// 预算优化结果
class BudgetOptimizationResult {
  final List<BudgetOptimization> optimizations;
  final double totalOptimized;
  final double estimatedSavings;
  final double confidence;

  const BudgetOptimizationResult({
    required this.optimizations,
    required this.totalOptimized,
    required this.estimatedSavings,
    required this.confidence,
  });
}

/// 单项优化
class BudgetOptimization {
  final String categoryId;
  final String categoryName;
  final OptimizationAction action;
  final double amount;
  final String reason;

  const BudgetOptimization({
    required this.categoryId,
    required this.categoryName,
    required this.action,
    required this.amount,
    required this.reason,
  });
}

/// 优化动作
enum OptimizationAction {
  increase,
  decrease,
  redistribute,
}
