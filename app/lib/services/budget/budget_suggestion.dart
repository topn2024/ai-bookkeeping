/// 预算建议来源
enum BudgetSuggestionSource {
  /// 自适应预算（基于历史消费趋势）
  adaptive,

  /// 智能预算（AI 推荐）
  smart,

  /// 本地化预算（地区消费水平）
  localized,

  /// 位置感知预算（当前位置周边消费习惯）
  location,

  /// 用户自定义
  custom,
}

/// 统一预算建议模型
///
/// 替代各服务的独立模型，提供统一的预算建议数据结构
class BudgetSuggestion {
  /// 分类 ID
  final String categoryId;

  /// 建议金额
  final double suggestedAmount;

  /// 建议原因/说明
  final String reason;

  /// 建议来源
  final BudgetSuggestionSource source;

  /// 置信度（0.0 - 1.0）
  final double confidence;

  /// 元数据（可选，存储额外信息）
  final Map<String, dynamic>? metadata;

  /// 创建时间
  final DateTime createdAt;

  const BudgetSuggestion({
    required this.categoryId,
    required this.suggestedAmount,
    required this.reason,
    required this.source,
    required this.confidence,
    this.metadata,
    required this.createdAt,
  });

  /// 从 JSON 创建
  factory BudgetSuggestion.fromJson(Map<String, dynamic> json) {
    return BudgetSuggestion(
      categoryId: json['categoryId'] as String,
      suggestedAmount: (json['suggestedAmount'] as num).toDouble(),
      reason: json['reason'] as String,
      source: BudgetSuggestionSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => BudgetSuggestionSource.custom,
      ),
      confidence: (json['confidence'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'suggestedAmount': suggestedAmount,
      'reason': reason,
      'source': source.name,
      'confidence': confidence,
      if (metadata != null) 'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 创建当前时间的建议
  factory BudgetSuggestion.now({
    required String categoryId,
    required double suggestedAmount,
    required String reason,
    required BudgetSuggestionSource source,
    required double confidence,
    Map<String, dynamic>? metadata,
  }) {
    return BudgetSuggestion(
      categoryId: categoryId,
      suggestedAmount: suggestedAmount,
      reason: reason,
      source: source,
      confidence: confidence,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
  }

  /// 复制并修改部分字段
  BudgetSuggestion copyWith({
    String? categoryId,
    double? suggestedAmount,
    String? reason,
    BudgetSuggestionSource? source,
    double? confidence,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return BudgetSuggestion(
      categoryId: categoryId ?? this.categoryId,
      suggestedAmount: suggestedAmount ?? this.suggestedAmount,
      reason: reason ?? this.reason,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'BudgetSuggestion(categoryId: $categoryId, suggestedAmount: $suggestedAmount, source: ${source.name}, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BudgetSuggestion &&
        other.categoryId == categoryId &&
        other.suggestedAmount == suggestedAmount &&
        other.source == source;
  }

  @override
  int get hashCode =>
      categoryId.hashCode ^ suggestedAmount.hashCode ^ source.hashCode;
}

/// 预算建议策略接口
///
/// 所有预算服务必须实现此接口以提供建议
abstract class BudgetSuggestionStrategy {
  /// 策略名称
  String get name;

  /// 策略来源类型
  BudgetSuggestionSource get sourceType;

  /// 获取预算建议
  ///
  /// [categoryIds] 需要建议的分类列表，null 表示所有分类
  /// [context] 可选的上下文信息
  Future<List<BudgetSuggestion>> getSuggestions({
    List<String>? categoryIds,
    Map<String, dynamic>? context,
  });

  /// 策略是否可用
  ///
  /// 例如位置策略需要定位权限
  Future<bool> isAvailable();

  /// 获取数据不足原因（当策略不可用时）
  ///
  /// 返回 null 表示策略可用或不需要额外数据
  Future<String?> getDataInsufficiencyReason() async {
    return null;
  }
}

/// 数据不足警告
class DataInsufficiencyWarning {
  /// 策略来源
  final BudgetSuggestionSource source;

  /// 策略名称
  final String strategyName;

  /// 不足原因
  final String reason;

  const DataInsufficiencyWarning({
    required this.source,
    required this.strategyName,
    required this.reason,
  });
}

/// 预算建议结果（包含建议和数据不足警告）
class BudgetSuggestionResult {
  /// 预算建议列表
  final List<BudgetSuggestion> suggestions;

  /// 数据不足警告列表
  final List<DataInsufficiencyWarning> warnings;

  const BudgetSuggestionResult({
    required this.suggestions,
    required this.warnings,
  });

  /// 是否有数据不足警告
  bool get hasWarnings => warnings.isNotEmpty;

  /// 是否所有策略都不可用
  bool get allStrategiesUnavailable => suggestions.isEmpty && warnings.isNotEmpty;
}

