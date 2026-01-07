import 'database_service.dart';
import 'subscription_tracking_service.dart';
import 'latte_factor_analyzer.dart';

/// 洞察类型
enum InsightType {
  /// 订阅过多
  subscriptionOverload,

  /// 周期性消费优化
  recurringExpenseOptimization,

  /// 不必要的费用
  unnecessaryFees,

  /// 更好的替代方案
  betterAlternative,

  /// 高频小额消费
  latteFactor,

  /// 预算超支风险
  budgetOverrunRisk,

  /// 储蓄机会
  savingsOpportunity,

  /// 消费模式异常
  spendingAnomaly,
}

extension InsightTypeExtension on InsightType {
  String get displayName {
    switch (this) {
      case InsightType.subscriptionOverload:
        return '订阅优化';
      case InsightType.recurringExpenseOptimization:
        return '周期消费';
      case InsightType.unnecessaryFees:
        return '费用节省';
      case InsightType.betterAlternative:
        return '更优选择';
      case InsightType.latteFactor:
        return '小额累积';
      case InsightType.budgetOverrunRisk:
        return '预算风险';
      case InsightType.savingsOpportunity:
        return '储蓄机会';
      case InsightType.spendingAnomaly:
        return '消费异常';
    }
  }
}

/// 洞察优先级
enum InsightPriority {
  low,
  medium,
  high,
  urgent,
}

extension InsightPriorityExtension on InsightPriority {
  String get displayName {
    switch (this) {
      case InsightPriority.low:
        return '建议';
      case InsightPriority.medium:
        return '推荐';
      case InsightPriority.high:
        return '重要';
      case InsightPriority.urgent:
        return '紧急';
    }
  }

  int get weight {
    switch (this) {
      case InsightPriority.low:
        return 1;
      case InsightPriority.medium:
        return 2;
      case InsightPriority.high:
        return 3;
      case InsightPriority.urgent:
        return 4;
    }
  }
}

/// 指南来源
enum GuideSource {
  /// 预置缓存
  preCached,

  /// 网络搜索
  webSearch,

  /// LLM生成
  llmGenerated,

  /// 用户贡献
  userContributed,
}

/// 指南类型
enum GuideType {
  /// 订阅取消
  subscriptionCancel,

  /// 费用规避
  feeAvoidance,

  /// 账户注销
  accountClosure,

  /// 套餐降级
  planDowngrade,

  /// 退款申请
  refundRequest,

  /// 替代品切换
  alternativeSwitch,

  /// 优惠申请
  discountApplication,
}

/// 指南步骤
class GuideStep {
  final int order;
  final String instruction;
  final String? imageUrl;
  final String? tip;
  final bool isOptional;

  const GuideStep({
    required this.order,
    required this.instruction,
    this.imageUrl,
    this.tip,
    this.isOptional = false,
  });

  Map<String, dynamic> toMap() => {
    'order': order,
    'instruction': instruction,
    'imageUrl': imageUrl,
    'tip': tip,
    'isOptional': isOptional,
  };

  factory GuideStep.fromMap(Map<String, dynamic> map) => GuideStep(
    order: map['order'] as int,
    instruction: map['instruction'] as String,
    imageUrl: map['imageUrl'] as String?,
    tip: map['tip'] as String?,
    isOptional: map['isOptional'] as bool? ?? false,
  );
}

/// 操作指南
class OperationGuide {
  final String id;
  final GuideType type;
  final String target;
  final String title;
  final List<GuideStep> steps;
  final GuideSource source;
  final String? sourceUrl;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final String? disclaimer;
  final List<String>? warnings;
  final List<String>? alternatives;

  const OperationGuide({
    required this.id,
    required this.type,
    required this.target,
    required this.title,
    required this.steps,
    required this.source,
    this.sourceUrl,
    required this.fetchedAt,
    required this.expiresAt,
    this.disclaimer,
    this.warnings,
    this.alternatives,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingDays => expiresAt.difference(DateTime.now()).inDays;

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.index,
    'target': target,
    'title': title,
    'steps': steps.map((s) => s.toMap()).toList(),
    'source': source.index,
    'sourceUrl': sourceUrl,
    'fetchedAt': fetchedAt.millisecondsSinceEpoch,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
    'disclaimer': disclaimer,
    'warnings': warnings?.join('|'),
    'alternatives': alternatives?.join('|'),
  };
}

/// 消费洞察
class SpendingInsight {
  final String id;
  final InsightType type;
  final String title;
  final String description;
  final InsightPriority priority;
  final double? potentialSavings;
  final List<String> relatedTransactionIds;
  final DateTime createdAt;
  final bool isRead;
  final bool isDismissed;

  const SpendingInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    this.potentialSavings,
    this.relatedTransactionIds = const [],
    required this.createdAt,
    this.isRead = false,
    this.isDismissed = false,
  });

  SpendingInsight copyWith({
    bool? isRead,
    bool? isDismissed,
  }) {
    return SpendingInsight(
      id: id,
      type: type,
      title: title,
      description: description,
      priority: priority,
      potentialSavings: potentialSavings,
      relatedTransactionIds: relatedTransactionIds,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

/// 可操作洞察
class ActionableInsight {
  final SpendingInsight insight;
  final List<OperationGuide> actionGuides;
  final double estimatedSaving;
  final InsightPriority priority;

  const ActionableInsight({
    required this.insight,
    required this.actionGuides,
    required this.estimatedSaving,
    required this.priority,
  });

  bool get hasActionableGuides => actionGuides.isNotEmpty;
  OperationGuide? get primaryGuide =>
      actionGuides.isNotEmpty ? actionGuides.first : null;
}

/// 可操作洞察服务
///
/// 分析用户消费数据，生成可操作的优化建议，
/// 并提供具体的操作指南帮助用户执行。
class ActionableInsightService {
  final DatabaseService _db;
  final SubscriptionTrackingService _subscriptionService;
  final LatteFactorAnalyzer _latteAnalyzer;

  // 预置的操作指南缓存
  final Map<String, OperationGuide> _guideCache = {};

  ActionableInsightService(
    this._db,
    this._subscriptionService,
    this._latteAnalyzer,
  ) {
    _initPreCachedGuides();
  }

  /// 生成所有洞察
  Future<List<ActionableInsight>> generateInsights({String? ledgerId}) async {
    final insights = <ActionableInsight>[];

    // 1. 订阅相关洞察
    final subscriptionInsights = await _generateSubscriptionInsights(ledgerId);
    insights.addAll(subscriptionInsights);

    // 2. 拿铁因子洞察
    final latteInsights = await _generateLatteFactorInsights(ledgerId);
    insights.addAll(latteInsights);

    // 3. 预算风险洞察
    final budgetInsights = await _generateBudgetInsights(ledgerId);
    insights.addAll(budgetInsights);

    // 按优先级排序
    insights.sort((a, b) => b.priority.weight.compareTo(a.priority.weight));

    return insights;
  }

  /// 获取特定洞察的操作指南
  Future<List<OperationGuide>> getOperationGuides(SpendingInsight insight) async {
    switch (insight.type) {
      case InsightType.subscriptionOverload:
        return await _getSubscriptionCancellationGuides(insight);
      case InsightType.recurringExpenseOptimization:
        return await _getRecurringOptimizationGuides(insight);
      case InsightType.unnecessaryFees:
        return await _getFeeAvoidanceGuides(insight);
      case InsightType.betterAlternative:
        return await _getAlternativeGuides(insight);
      default:
        return await _getGenericGuides(insight);
    }
  }

  /// 标记洞察为已读
  Future<void> markAsRead(String insightId) async {
    await _db.rawUpdate('''
      UPDATE spending_insights SET isRead = 1 WHERE id = ?
    ''', [insightId]);
  }

  /// 忽略洞察
  Future<void> dismissInsight(String insightId) async {
    await _db.rawUpdate('''
      UPDATE spending_insights SET isDismissed = 1 WHERE id = ?
    ''', [insightId]);
  }

  /// 记录用户采纳洞察
  Future<void> recordInsightAction({
    required String insightId,
    required String action,
    double? savedAmount,
  }) async {
    await _db.rawInsert('''
      INSERT INTO insight_actions (id, insightId, action, savedAmount, actionAt)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      DateTime.now().millisecondsSinceEpoch.toString(),
      insightId,
      action,
      savedAmount,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  /// 获取洞察统计
  Future<Map<String, dynamic>> getInsightStats({int days = 30}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    // 总洞察数
    final totalResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM spending_insights WHERE createdAt >= ?
    ''', [since]);
    final total = (totalResult.first['count'] as int?) ?? 0;

    // 已采纳的洞察
    final actedResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT insightId) as count FROM insight_actions WHERE actionAt >= ?
    ''', [since]);
    final acted = (actedResult.first['count'] as int?) ?? 0;

    // 节省金额
    final savedResult = await _db.rawQuery('''
      SELECT SUM(savedAmount) as total FROM insight_actions WHERE actionAt >= ?
    ''', [since]);
    final saved = (savedResult.first['total'] as num?)?.toDouble() ?? 0;

    return {
      'totalInsights': total,
      'actedInsights': acted,
      'totalSaved': saved,
      'actionRate': total > 0 ? acted / total : 0,
    };
  }

  // ==================== Private Methods ====================

  Future<List<ActionableInsight>> _generateSubscriptionInsights(String? ledgerId) async {
    final insights = <ActionableInsight>[];

    final wastedSubs = await _subscriptionService.findWastedSubscriptions(
      ledgerId: ledgerId,
    );

    for (final wasted in wastedSubs) {
      final insight = SpendingInsight(
        id: 'sub_${wasted.subscription.merchantName}_${DateTime.now().millisecondsSinceEpoch}',
        type: InsightType.subscriptionOverload,
        title: '可能不需要的订阅',
        description: wasted.suggestion,
        priority: wasted.potentialSavings > 500
            ? InsightPriority.high
            : InsightPriority.medium,
        potentialSavings: wasted.potentialSavings,
        createdAt: DateTime.now(),
      );

      final guides = await _getSubscriptionCancellationGuides(insight);

      insights.add(ActionableInsight(
        insight: insight,
        actionGuides: guides,
        estimatedSaving: wasted.potentialSavings,
        priority: insight.priority,
      ));
    }

    return insights;
  }

  Future<List<ActionableInsight>> _generateLatteFactorInsights(String? ledgerId) async {
    final insights = <ActionableInsight>[];

    final report = await _latteAnalyzer.analyzeLatteFactors(ledgerId: ledgerId);

    if (report.totalYearlyImpact > 1000) {
      final insight = SpendingInsight(
        id: 'latte_${DateTime.now().millisecondsSinceEpoch}',
        type: InsightType.latteFactor,
        title: '小额消费累积',
        description: report.topSuggestion,
        priority: report.totalYearlyImpact > 5000
            ? InsightPriority.high
            : InsightPriority.medium,
        potentialSavings: report.potentialYearlySavings,
        createdAt: DateTime.now(),
      );

      insights.add(ActionableInsight(
        insight: insight,
        actionGuides: [],
        estimatedSaving: report.potentialYearlySavings,
        priority: insight.priority,
      ));
    }

    return insights;
  }

  Future<List<ActionableInsight>> _generateBudgetInsights(String? ledgerId) async {
    // 预算相关洞察（简化实现）
    return [];
  }

  Future<List<OperationGuide>> _getSubscriptionCancellationGuides(
    SpendingInsight insight,
  ) async {
    final guides = <OperationGuide>[];

    // 从缓存获取预置指南
    final target = insight.title;
    if (_guideCache.containsKey(target)) {
      guides.add(_guideCache[target]!);
    }

    // 生成通用取消指南
    if (guides.isEmpty) {
      guides.add(_generateGenericCancellationGuide(target));
    }

    return guides;
  }

  Future<List<OperationGuide>> _getRecurringOptimizationGuides(
    SpendingInsight insight,
  ) async {
    return [];
  }

  Future<List<OperationGuide>> _getFeeAvoidanceGuides(
    SpendingInsight insight,
  ) async {
    return [];
  }

  Future<List<OperationGuide>> _getAlternativeGuides(
    SpendingInsight insight,
  ) async {
    return [];
  }

  Future<List<OperationGuide>> _getGenericGuides(
    SpendingInsight insight,
  ) async {
    return [];
  }

  OperationGuide _generateGenericCancellationGuide(String serviceName) {
    return OperationGuide(
      id: 'guide_${DateTime.now().millisecondsSinceEpoch}',
      type: GuideType.subscriptionCancel,
      target: serviceName,
      title: '如何取消订阅',
      steps: [
        const GuideStep(order: 1, instruction: '打开相关应用或网站'),
        const GuideStep(order: 2, instruction: '进入"我的"或"账户"页面'),
        const GuideStep(order: 3, instruction: '找到"会员"或"订阅"设置'),
        const GuideStep(order: 4, instruction: '选择"取消订阅"或"关闭自动续费"'),
        const GuideStep(order: 5, instruction: '确认取消操作'),
      ],
      source: GuideSource.llmGenerated,
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 14)),
      disclaimer: '此为通用指南，具体操作可能因服务商不同而有所差异',
    );
  }

  void _initPreCachedGuides() {
    // 预置常用服务的取消指南
    _guideCache['爱奇艺'] = OperationGuide(
      id: 'guide_iqiyi',
      type: GuideType.subscriptionCancel,
      target: '爱奇艺',
      title: '如何取消爱奇艺会员自动续费',
      steps: const [
        GuideStep(order: 1, instruction: '打开爱奇艺App'),
        GuideStep(order: 2, instruction: '点击右下角"我的"'),
        GuideStep(order: 3, instruction: '点击"我的VIP会员"'),
        GuideStep(order: 4, instruction: '点击"管理自动续费"'),
        GuideStep(order: 5, instruction: '选择"取消自动续费"'),
        GuideStep(order: 6, instruction: '确认取消'),
      ],
      source: GuideSource.preCached,
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 90)),
    );

    _guideCache['腾讯视频'] = OperationGuide(
      id: 'guide_tencentvideo',
      type: GuideType.subscriptionCancel,
      target: '腾讯视频',
      title: '如何取消腾讯视频VIP自动续费',
      steps: const [
        GuideStep(order: 1, instruction: '打开腾讯视频App'),
        GuideStep(order: 2, instruction: '点击右下角"个人中心"'),
        GuideStep(order: 3, instruction: '点击"我的VIP"'),
        GuideStep(order: 4, instruction: '点击"管理自动续费"'),
        GuideStep(order: 5, instruction: '关闭自动续费开关'),
      ],
      source: GuideSource.preCached,
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 90)),
    );

    _guideCache['网易云音乐'] = OperationGuide(
      id: 'guide_neteasemusic',
      type: GuideType.subscriptionCancel,
      target: '网易云音乐',
      title: '如何取消网易云音乐会员自动续费',
      steps: const [
        GuideStep(order: 1, instruction: '打开网易云音乐App'),
        GuideStep(order: 2, instruction: '点击左上角菜单'),
        GuideStep(order: 3, instruction: '点击"会员中心"'),
        GuideStep(order: 4, instruction: '点击"管理自动续费"'),
        GuideStep(order: 5, instruction: '选择"关闭自动续费"'),
      ],
      source: GuideSource.preCached,
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 90)),
    );
  }
}
