import '../voice_service_coordinator.dart' show VoiceIntentType;
import 'multi_intent_models.dart';
import 'noise_filter.dart';

/// 意图合并器
///
/// 将多个分析结果合并为结构化的 MultiIntentResult，
/// 区分完整意图、不完整意图和导航意图。
class IntentMerger {
  /// 噪音过滤器
  final NoiseFilter _noiseFilter;

  /// 合并配置
  final MergerConfig config;

  IntentMerger({
    NoiseFilter? noiseFilter,
    this.config = const MergerConfig(),
  }) : _noiseFilter = noiseFilter ?? NoiseFilter();

  /// 合并分析结果
  ///
  /// [segments] 批量分析后的片段结果
  /// [rawInput] 原始用户输入
  ///
  /// Returns 合并后的多意图结果
  MultiIntentResult merge(
    List<SegmentAnalysis> segments,
    String rawInput,
  ) {
    // 1. 过滤噪音
    final filterResult = _noiseFilter.filter(segments);
    final validSegments = filterResult.validSegments;
    final filteredNoise = filterResult.filteredNoise;

    // 2. 分类意图
    final completeIntents = <CompleteIntent>[];
    final incompleteIntents = <IncompleteIntent>[];
    NavigationIntent? navigationIntent;

    for (final segment in validSegments) {
      // 检查是否为导航意图
      if (_isNavigationSegment(segment)) {
        // 只保留第一个导航意图
        navigationIntent ??= _createNavigationIntent(segment);
        continue;
      }

      // 检查是否为确认/取消意图（这些在多意图场景下通常不单独处理）
      if (_isConfirmationSegment(segment)) {
        continue;
      }

      // 检查意图完整性
      final completeness = IntentCompleteness.checkTransaction(segment);

      if (completeness.isComplete) {
        completeIntents.add(_createCompleteIntent(segment));
      } else {
        incompleteIntents.add(_createIncompleteIntent(segment, completeness));
      }
    }

    // 3. 合并同类意图（可选）
    final mergedComplete = config.enableMerging
        ? _mergeCompleteIntents(completeIntents)
        : completeIntents;

    // 4. 按优先级排序
    final sortedComplete = _sortByPriority(mergedComplete);
    final sortedIncomplete = _sortIncompleteByConfidence(incompleteIntents);

    return MultiIntentResult(
      completeIntents: sortedComplete,
      incompleteIntents: sortedIncomplete,
      navigationIntent: navigationIntent,
      filteredNoise: filteredNoise,
      rawInput: rawInput,
      segments: segments.map((s) => s.text).toList(),
    );
  }

  /// 检查是否为导航意图
  bool _isNavigationSegment(SegmentAnalysis segment) {
    final text = segment.text;

    // 检查意图分析结果（优先）
    final intentResult = segment.intentResult;
    final isNavIntent = intentResult?.intent == VoiceIntentType.navigateToPage;
    if (isNavIntent) return true;

    // 如果有金额，通常不是导航意图
    if (segment.amount != null && segment.amount! > 0) {
      return false;
    }

    // 如果有消费动作动词，不是导航意图
    final expenseVerbs = ['买', '花', '吃', '喝', '打车', '坐', '付', '消费', '充值'];
    if (expenseVerbs.any((v) => text.contains(v))) {
      return false;
    }

    // 检查导航关键词（"去"需要特殊处理，因为"去买"、"去吃"不是导航）
    final strictNavKeywords = ['打开', '进入', '跳转', '切换', '查看', '看看'];
    if (strictNavKeywords.any((k) => text.contains(k))) {
      return true;
    }

    // "去" 只有在后面跟着页面/地点名词时才是导航
    if (text.contains('去')) {
      final pageKeywords = ['首页', '主页', '设置', '预算', '分析', '统计', '账户', '记录', '分类'];
      if (pageKeywords.any((k) => text.contains(k))) {
        return true;
      }
    }

    return false;
  }

  /// 检查是否为确认/取消意图
  bool _isConfirmationSegment(SegmentAnalysis segment) {
    final intentResult = segment.intentResult;
    if (intentResult == null) return false;

    return intentResult.intent == VoiceIntentType.confirmAction ||
        intentResult.intent == VoiceIntentType.cancelAction;
  }

  /// 创建导航意图
  NavigationIntent _createNavigationIntent(SegmentAnalysis segment) {
    // 提取目标页面
    final targetPage = _extractTargetPage(segment);
    final targetPageName = _getPageDisplayName(targetPage);

    return NavigationIntent(
      targetPage: targetPage,
      targetPageName: targetPageName,
      originalText: segment.text,
    );
  }

  /// 提取目标页面
  String _extractTargetPage(SegmentAnalysis segment) {
    final text = segment.text;

    // 从意图结果中获取
    final intentResult = segment.intentResult;
    if (intentResult != null && intentResult.entities.containsKey('targetPage')) {
      return intentResult.entities['targetPage'] as String;
    }

    // 基于关键词匹配
    final pageKeywords = {
      'home': ['首页', '主页', '主界面'],
      'settings': ['设置', '选项', '配置'],
      'budget': ['预算', '预算中心'],
      'analysis': ['分析', '统计', '报表', '趋势'],
      'accounts': ['账户', '账号'],
      'piggy_bank': ['小金库', '储蓄', '存钱罐'],
      'transactions': ['账单', '交易记录', '记录'],
      'categories': ['分类', '类别'],
    };

    for (final entry in pageKeywords.entries) {
      if (entry.value.any((keyword) => text.contains(keyword))) {
        return entry.key;
      }
    }

    return 'unknown';
  }

  /// 获取页面显示名称
  String _getPageDisplayName(String pageId) {
    const pageNames = {
      'home': '首页',
      'settings': '设置',
      'budget': '预算中心',
      'analysis': '统计分析',
      'accounts': '账户管理',
      'piggy_bank': '小金库',
      'transactions': '交易记录',
      'categories': '分类管理',
      'unknown': '未知页面',
    };

    return pageNames[pageId] ?? pageId;
  }

  /// 创建完整意图
  CompleteIntent _createCompleteIntent(SegmentAnalysis segment) {
    return CompleteIntent(
      type: _inferTransactionType(segment),
      amount: segment.amount!,
      category: segment.category,
      merchant: segment.merchant,
      description: _generateDescription(segment),
      originalText: segment.text,
      dateTime: segment.dateTime,
      confidence: segment.confidence,
    );
  }

  /// 创建不完整意图
  IncompleteIntent _createIncompleteIntent(
    SegmentAnalysis segment,
    IntentCompleteness completeness,
  ) {
    return IncompleteIntent(
      type: _inferTransactionType(segment),
      category: segment.category,
      merchant: segment.merchant,
      description: _generateDescription(segment),
      originalText: segment.text,
      missingSlots: completeness.missingSlots,
      dateTime: segment.dateTime,
      confidence: segment.confidence,
    );
  }

  /// 推断交易类型
  TransactionIntentType _inferTransactionType(SegmentAnalysis segment) {
    final text = segment.text;

    // 收入关键词
    final incomeKeywords = ['收入', '赚', '进账', '到账', '收到', '工资', '奖金', '红包', '捡到', '捡了', '找到钱', '中奖', '返现', '退款'];
    if (incomeKeywords.any((k) => text.contains(k))) {
      return TransactionIntentType.income;
    }

    // 转账关键词
    final transferKeywords = ['转账', '转给', '汇款', '转出', '转入'];
    if (transferKeywords.any((k) => text.contains(k))) {
      return TransactionIntentType.transfer;
    }

    // 默认为支出
    return TransactionIntentType.expense;
  }

  /// 生成描述
  String? _generateDescription(SegmentAnalysis segment) {
    // 优先使用分类 + 商家
    if (segment.category != null && segment.merchant != null) {
      return '${segment.category} - ${segment.merchant}';
    }

    // 只有分类
    if (segment.category != null) {
      return segment.category;
    }

    // 只有商家
    if (segment.merchant != null) {
      return segment.merchant;
    }

    // 使用原始文本的简化版本
    final text = segment.text;
    if (text.length <= 20) {
      return text;
    }

    return null;
  }

  /// 合并同类完整意图
  ///
  /// 例如："早上打车35，晚上打车40" 可以合并为一条交通75元
  /// 但目前保守策略是不合并，保留每条独立记录
  List<CompleteIntent> _mergeCompleteIntents(List<CompleteIntent> intents) {
    if (!config.enableMerging || intents.length < 2) {
      return intents;
    }

    // 按分类分组
    final grouped = <String, List<CompleteIntent>>{};
    for (final intent in intents) {
      final key = intent.category ?? 'other';
      grouped.putIfAbsent(key, () => []).add(intent);
    }

    // 检查是否需要合并
    final result = <CompleteIntent>[];
    for (final entry in grouped.entries) {
      final group = entry.value;

      if (group.length >= 2 && config.mergeSameCategory) {
        // 合并同类意图
        final merged = _mergeSameCategoryIntents(group);
        result.add(merged);
      } else {
        result.addAll(group);
      }
    }

    return result;
  }

  /// 合并同分类的意图
  CompleteIntent _mergeSameCategoryIntents(List<CompleteIntent> intents) {
    final totalAmount = intents.fold(0.0, (sum, i) => sum + i.amount);
    final category = intents.first.category;
    final descriptions = intents.map((i) => i.originalText).join('；');

    return CompleteIntent(
      type: intents.first.type,
      amount: totalAmount,
      category: category,
      merchant: null, // 合并后不保留商家
      description: '合并：$descriptions',
      originalText: descriptions,
      dateTime: intents.first.dateTime,
      confidence: intents.map((i) => i.confidence).reduce((a, b) => a < b ? a : b),
    );
  }

  /// 按优先级排序完整意图
  List<CompleteIntent> _sortByPriority(List<CompleteIntent> intents) {
    // 按置信度和金额排序
    final sorted = List<CompleteIntent>.from(intents);
    sorted.sort((a, b) {
      // 首先按置信度
      final confidenceCompare = b.confidence.compareTo(a.confidence);
      if (confidenceCompare != 0) return confidenceCompare;

      // 其次按金额（大金额优先确认）
      return b.amount.compareTo(a.amount);
    });

    return sorted;
  }

  /// 按置信度排序不完整意图
  List<IncompleteIntent> _sortIncompleteByConfidence(List<IncompleteIntent> intents) {
    final sorted = List<IncompleteIntent>.from(intents);
    sorted.sort((a, b) => b.confidence.compareTo(a.confidence));
    return sorted;
  }
}

/// 合并器配置
class MergerConfig {
  /// 是否启用意图合并
  final bool enableMerging;

  /// 是否合并同分类意图
  final bool mergeSameCategory;

  /// 合并的最小意图数量
  final int minMergeCount;

  /// 是否保留导航意图
  final bool keepNavigationIntent;

  const MergerConfig({
    this.enableMerging = false, // 默认不合并，保留独立记录
    this.mergeSameCategory = false,
    this.minMergeCount = 2,
    this.keepNavigationIntent = true,
  });
}
