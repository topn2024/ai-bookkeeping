import 'package:flutter/foundation.dart';

import '../../../services/collaborative_learning_service.dart';
import '../models/sensitivity_level.dart';
import 'laplacian_noise_generator.dart';
import 'privacy_budget_manager.dart';
import 'sensitivity_calculator.dart';

/// 差分隐私引擎
///
/// 核心差分隐私服务，整合噪声生成、敏感度计算和预算管理。
/// 实现专利算法3：规则噪声注入。
class DifferentialPrivacyEngine {
  final LaplacianNoiseGenerator _noiseGenerator;
  final PrivacyBudgetManager _budgetManager;

  DifferentialPrivacyEngine({
    required PrivacyBudgetManager budgetManager,
    LaplacianNoiseGenerator? noiseGenerator,
  })  : _budgetManager = budgetManager,
        _noiseGenerator = noiseGenerator ?? LaplacianNoiseGenerator();

  /// 预算管理器
  PrivacyBudgetManager get budgetManager => _budgetManager;

  /// 是否可以进行隐私保护操作
  bool get canPerformOperation => !_budgetManager.isExhausted;

  /// 保护单个学习规则（算法3实现）
  ///
  /// 对规则的置信度添加拉普拉斯噪声
  Future<PrivateRule?> protectRule(LearnedRule rule) async {
    if (!canPerformOperation) {
      debugPrint('差分隐私：预算已耗尽，无法保护规则');
      return null;
    }

    // 1. 计算敏感度（置信度范围[0,1]，敏感度=1）
    final sensitivity = SensitivityCalculator.forConfidence();

    // 2. 获取epsilon
    final epsilon = _budgetManager.getEpsilon(SensitivityLevel.medium);

    // 3. 尝试消耗预算
    final canConsume = await _budgetManager.consume(
      epsilon: epsilon,
      level: SensitivityLevel.medium,
      operation: '规则置信度保护: ${rule.pattern.substring(0, rule.pattern.length.clamp(0, 10))}',
    );

    if (!canConsume) {
      return null;
    }

    // 4. 生成拉普拉斯噪声
    final noise = _noiseGenerator.generate(
      sensitivity: sensitivity,
      epsilon: epsilon,
    );

    // 5. 添加噪声并裁剪到[0,1]
    final noisyConfidence = (rule.confidence + noise).clamp(0.0, 1.0);

    return PrivateRule(
      originalId: rule.id,
      type: rule.type,
      patternHash: _hashPattern(rule.pattern),
      category: rule.category,
      noisyConfidence: noisyConfidence,
      originalConfidence: rule.confidence,
      noiseAdded: noise,
      epsilon: epsilon,
      protectedAt: DateTime.now(),
    );
  }

  /// 批量保护学习规则
  ///
  /// 对多个规则进行差分隐私保护
  Future<List<PrivateRule>> protectRules(List<LearnedRule> rules) async {
    if (!canPerformOperation) {
      debugPrint('差分隐私：预算已耗尽，无法保护规则');
      return [];
    }

    final result = <PrivateRule>[];

    for (final rule in rules) {
      final protectedRule = await protectRule(rule);
      if (protectedRule != null) {
        result.add(protectedRule);
      } else {
        // 预算耗尽，停止处理
        debugPrint('差分隐私：预算耗尽，已保护 ${result.length}/${rules.length} 条规则');
        break;
      }
    }

    return result;
  }

  /// 保护数值数据
  ///
  /// [value] 原始数值
  /// [minValue] 数值范围最小值
  /// [maxValue] 数值范围最大值
  /// [level] 敏感度级别
  /// [operation] 操作描述
  Future<double?> protectNumericValue({
    required double value,
    required double minValue,
    required double maxValue,
    required SensitivityLevel level,
    required String operation,
  }) async {
    if (!canPerformOperation) {
      return null;
    }

    final sensitivity = SensitivityCalculator.forNumericValue(
      minValue: minValue,
      maxValue: maxValue,
    );

    final epsilon = _budgetManager.getEpsilon(level);

    final canConsume = await _budgetManager.consume(
      epsilon: epsilon,
      level: level,
      operation: operation,
    );

    if (!canConsume) {
      return null;
    }

    return _noiseGenerator.addNoise(
      value: value,
      sensitivity: sensitivity,
      epsilon: epsilon,
      minValue: minValue,
      maxValue: maxValue,
    );
  }

  /// 保护均值查询
  Future<double?> protectMeanQuery({
    required double mean,
    required double minValue,
    required double maxValue,
    required int recordCount,
    required String operation,
  }) async {
    if (!canPerformOperation) {
      return null;
    }

    final sensitivity = SensitivityCalculator.forMean(
      minValue: minValue,
      maxValue: maxValue,
      recordCount: recordCount,
    );

    final epsilon = _budgetManager.getEpsilon(SensitivityLevel.low);

    final canConsume = await _budgetManager.consume(
      epsilon: epsilon,
      level: SensitivityLevel.low,
      operation: operation,
    );

    if (!canConsume) {
      return null;
    }

    return _noiseGenerator.addNoise(
      value: mean,
      sensitivity: sensitivity,
      epsilon: epsilon,
    );
  }

  /// 保护计数查询
  Future<int?> protectCountQuery({
    required int count,
    required String operation,
  }) async {
    if (!canPerformOperation) {
      return null;
    }

    final sensitivity = SensitivityCalculator.forCount();
    final epsilon = _budgetManager.getEpsilon(SensitivityLevel.low);

    final canConsume = await _budgetManager.consume(
      epsilon: epsilon,
      level: SensitivityLevel.low,
      operation: operation,
    );

    if (!canConsume) {
      return null;
    }

    final noisyCount = _noiseGenerator.addNoise(
      value: count.toDouble(),
      sensitivity: sensitivity,
      epsilon: epsilon,
      minValue: 0,
    );

    return noisyCount.round();
  }

  /// 保护直方图
  Future<Map<String, int>?> protectHistogram({
    required Map<String, int> histogram,
    required String operation,
  }) async {
    if (!canPerformOperation) {
      return null;
    }

    final sensitivity = SensitivityCalculator.forHistogram();
    final epsilon = _budgetManager.getEpsilon(SensitivityLevel.low);

    // 计算总预算消耗
    final totalEpsilon = epsilon * histogram.length;
    if (!_budgetManager.canConsume(totalEpsilon)) {
      debugPrint('差分隐私：预算不足以保护直方图');
      return null;
    }

    final result = <String, int>{};

    for (final entry in histogram.entries) {
      final canConsume = await _budgetManager.consume(
        epsilon: epsilon,
        level: SensitivityLevel.low,
        operation: '$operation: ${entry.key}',
      );

      if (!canConsume) {
        break;
      }

      final noisyCount = _noiseGenerator.addNoise(
        value: entry.value.toDouble(),
        sensitivity: sensitivity,
        epsilon: epsilon,
        minValue: 0,
      );

      result[entry.key] = noisyCount.round();
    }

    return result;
  }

  /// 估计保护操作所需的预算
  double estimateBudgetRequired({
    required int ruleCount,
    SensitivityLevel level = SensitivityLevel.medium,
  }) {
    return _budgetManager.getEpsilon(level) * ruleCount;
  }

  /// 检查是否有足够的预算保护指定数量的规则
  bool hasSufficientBudget({
    required int ruleCount,
    SensitivityLevel level = SensitivityLevel.medium,
  }) {
    final required = estimateBudgetRequired(ruleCount: ruleCount, level: level);
    return _budgetManager.canConsume(required);
  }

  String _hashPattern(String pattern) {
    // 简单的哈希实现，实际应使用加密哈希
    var hash = 0;
    for (var i = 0; i < pattern.length; i++) {
      hash = ((hash << 5) - hash) + pattern.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// 隐私保护后的规则
class PrivateRule {
  /// 原始规则ID
  final String originalId;

  /// 规则类型
  final String type;

  /// 模式哈希（脱敏后）
  final String patternHash;

  /// 分类
  final String category;

  /// 添加噪声后的置信度
  final double noisyConfidence;

  /// 原始置信度（仅用于内部记录，不上传）
  final double originalConfidence;

  /// 添加的噪声量（仅用于内部记录）
  final double noiseAdded;

  /// 使用的 epsilon 值
  final double epsilon;

  /// 保护时间
  final DateTime protectedAt;

  const PrivateRule({
    required this.originalId,
    required this.type,
    required this.patternHash,
    required this.category,
    required this.noisyConfidence,
    required this.originalConfidence,
    required this.noiseAdded,
    required this.epsilon,
    required this.protectedAt,
  });

  /// 转换为可上传的匿名数据
  Map<String, dynamic> toUploadData() {
    return {
      'pattern_hash': patternHash,
      'type': type,
      'category': category,
      'confidence': noisyConfidence,
      // 不包含 originalConfidence, noiseAdded, originalId 等敏感信息
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'originalId': originalId,
      'type': type,
      'patternHash': patternHash,
      'category': category,
      'noisyConfidence': noisyConfidence,
      'originalConfidence': originalConfidence,
      'noiseAdded': noiseAdded,
      'epsilon': epsilon,
      'protectedAt': protectedAt.toIso8601String(),
    };
  }
}

/// 差分隐私保护结果
class DifferentialPrivacyResult<T> {
  /// 保护后的数据
  final T? data;

  /// 是否成功
  final bool success;

  /// 消耗的 epsilon
  final double epsilonConsumed;

  /// 错误信息
  final String? error;

  const DifferentialPrivacyResult({
    this.data,
    required this.success,
    required this.epsilonConsumed,
    this.error,
  });

  factory DifferentialPrivacyResult.success(T data, double epsilon) {
    return DifferentialPrivacyResult(
      data: data,
      success: true,
      epsilonConsumed: epsilon,
    );
  }

  factory DifferentialPrivacyResult.failure(String error) {
    return DifferentialPrivacyResult(
      success: false,
      epsilonConsumed: 0,
      error: error,
    );
  }
}
