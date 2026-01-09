import 'dart:async';

import 'package:flutter/foundation.dart';

/// 实体消歧服务
///
/// 对应设计文档第18.11.1节：实体消歧引擎
/// 核心差异化特性：解决"昨天那笔"、"上一笔"等指代表达
///
/// 功能特性：
/// 1. 指代识别：时间指代、顺序指代、描述指代、金额指代、混合指代
/// 2. 候选记录检索：基于指代条件构建查询
/// 3. 消歧决策：高置信度直接执行 vs 追问澄清
/// 4. 上下文推理：结合对话历史提高准确率
class EntityDisambiguationService extends ChangeNotifier {
  /// 当前会话的上下文
  DisambiguationContext? _currentContext;

  /// 最近操作的记录（用于"刚才那笔"等指代）
  final List<RecentRecord> _recentRecords = [];

  /// 最大保留记录数
  static const int maxRecentRecords = 10;

  // ═══════════════════════════════════════════════════════════════
  // 指代类型定义
  // ═══════════════════════════════════════════════════════════════

  /// 指代模式
  static final Map<ReferenceType, List<RegExp>> _referencePatterns = {
    // 时间指代
    ReferenceType.time: [
      RegExp(r'今天'),
      RegExp(r'昨天'),
      RegExp(r'前天'),
      RegExp(r'上周'),
      RegExp(r'上个月'),
      RegExp(r'刚才'),
      RegExp(r'刚刚'),
      RegExp(r'最近'),
      RegExp(r'(\d+)月(\d+)[日号]?'),
      RegExp(r'(\d+)(分钟|小时|天)前'),
    ],
    // 顺序指代
    ReferenceType.order: [
      RegExp(r'那笔'),
      RegExp(r'这笔'),
      RegExp(r'上一笔'),
      RegExp(r'最后一笔'),
      RegExp(r'第一笔'),
      RegExp(r'第(\d+)笔'),
      RegExp(r'最新的'),
      RegExp(r'最早的'),
    ],
    // 描述指代
    ReferenceType.description: [
      RegExp(r'(早餐|午餐|晚餐|外卖|夜宵)'),
      RegExp(r'(打车|地铁|公交|加油|停车)'),
      RegExp(r'(超市|淘宝|京东|购物)'),
      RegExp(r'(电影|游戏|旅游|娱乐)'),
      RegExp(r'(工资|奖金|收入|入账)'),
    ],
    // 金额指代
    ReferenceType.amount: [
      RegExp(r'(\d+\.?\d*)(块|元)?(那笔|的)?'),
      RegExp(r'最大的'),
      RegExp(r'最小的'),
      RegExp(r'最贵的'),
      RegExp(r'最便宜的'),
    ],
    // 商家指代
    ReferenceType.merchant: [
      RegExp(r'(肯德基|麦当劳|星巴克|瑞幸)'),
      RegExp(r'(美团|饿了么|滴滴)'),
      RegExp(r'在(.{2,8})的'),
    ],
  };

  // ═══════════════════════════════════════════════════════════════
  // 核心消歧流程
  // ═══════════════════════════════════════════════════════════════

  /// 解析用户输入中的实体指代
  Future<DisambiguationResult> disambiguate(
    String userInput, {
    required TransactionQueryCallback queryCallback,
    DisambiguationContext? context,
  }) async {
    // Step 1: 指代识别
    final references = _detectReferences(userInput);
    if (references.isEmpty) {
      return DisambiguationResult.noReference();
    }

    // Step 2: 构建查询条件
    final queryConditions = _buildQueryConditions(references, context);

    // Step 3: 候选记录检索
    final candidates = await queryCallback(queryConditions);
    if (candidates.isEmpty) {
      return DisambiguationResult.noMatch(references);
    }

    // Step 4: 计算置信度并排序
    final scoredCandidates = _scoreCandidates(candidates, references, context);

    // Step 5: 消歧决策
    return _makeDecision(scoredCandidates, references);
  }

  /// 检测指代词
  List<DetectedReference> _detectReferences(String text) {
    final references = <DetectedReference>[];
    final lowerText = text.toLowerCase();

    for (final entry in _referencePatterns.entries) {
      for (final pattern in entry.value) {
        final matches = pattern.allMatches(lowerText);
        for (final match in matches) {
          references.add(DetectedReference(
            type: entry.key,
            rawText: match.group(0) ?? '',
            startIndex: match.start,
            endIndex: match.end,
            capturedGroups: _extractGroups(match),
          ));
        }
      }
    }

    references.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    return references;
  }

  List<String?> _extractGroups(RegExpMatch match) {
    final groups = <String?>[];
    for (var i = 0; i <= match.groupCount; i++) {
      groups.add(match.group(i));
    }
    return groups;
  }

  /// 构建查询条件
  QueryConditions _buildQueryConditions(
    List<DetectedReference> references,
    DisambiguationContext? context,
  ) {
    DateTime? startDate;
    DateTime? endDate;
    String? categoryHint;
    String? merchantHint;
    double? amountHint;
    double? amountMin;
    double? amountMax;
    int? orderIndex;
    OrderDirection? orderDirection;

    final now = DateTime.now();

    for (final ref in references) {
      switch (ref.type) {
        case ReferenceType.time:
          final timeRange = _parseTimeReference(ref, now);
          startDate = timeRange.start;
          endDate = timeRange.end;
          break;
        case ReferenceType.order:
          final orderInfo = _parseOrderReference(ref);
          orderIndex = orderInfo.index;
          orderDirection = orderInfo.direction;
          break;
        case ReferenceType.description:
          categoryHint = _parseCategoryReference(ref);
          break;
        case ReferenceType.amount:
          final amountInfo = _parseAmountReference(ref);
          amountHint = amountInfo.exactAmount;
          amountMin = amountInfo.minAmount;
          amountMax = amountInfo.maxAmount;
          break;
        case ReferenceType.merchant:
          merchantHint = _parseMerchantReference(ref);
          break;
      }
    }

    if (context != null) {
      startDate ??= context.defaultStartDate;
      endDate ??= context.defaultEndDate;
    }

    startDate ??= now.subtract(const Duration(days: 7));
    endDate ??= now;

    return QueryConditions(
      startDate: startDate,
      endDate: endDate,
      categoryHint: categoryHint,
      merchantHint: merchantHint,
      amountHint: amountHint,
      amountMin: amountMin,
      amountMax: amountMax,
      orderIndex: orderIndex,
      orderDirection: orderDirection ?? OrderDirection.latest,
      limit: 5,
    );
  }

  /// 解析时间指代
  DateTimeRange _parseTimeReference(DetectedReference ref, DateTime now) {
    final text = ref.rawText;

    if (text.contains('今天')) {
      final today = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
    }
    if (text.contains('昨天')) {
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      return DateTimeRange(start: yesterday, end: yesterday.add(const Duration(days: 1)));
    }
    if (text.contains('前天')) {
      final dayBefore = DateTime(now.year, now.month, now.day - 2);
      return DateTimeRange(start: dayBefore, end: dayBefore.add(const Duration(days: 1)));
    }
    if (text.contains('上周')) {
      return DateTimeRange(
        start: now.subtract(const Duration(days: 14)),
        end: now.subtract(const Duration(days: 7)),
      );
    }
    if (text.contains('上个月')) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final thisMonth = DateTime(now.year, now.month, 1);
      return DateTimeRange(start: lastMonth, end: thisMonth);
    }
    if (text.contains('刚才') || text.contains('刚刚')) {
      return DateTimeRange(start: now.subtract(const Duration(minutes: 30)), end: now);
    }
    if (text.contains('最近')) {
      return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    }

    final agoMatch = RegExp(r'(\d+)(分钟|小时|天)前').firstMatch(text);
    if (agoMatch != null) {
      final value = int.tryParse(agoMatch.group(1) ?? '') ?? 1;
      final unit = agoMatch.group(2);
      Duration duration;
      switch (unit) {
        case '分钟':
          duration = Duration(minutes: value);
          break;
        case '小时':
          duration = Duration(hours: value);
          break;
        case '天':
          duration = Duration(days: value);
          break;
        default:
          duration = Duration.zero;
      }
      return DateTimeRange(
        start: now.subtract(duration).subtract(const Duration(hours: 1)),
        end: now.subtract(duration).add(const Duration(hours: 1)),
      );
    }

    final dateMatch = RegExp(r'(\d+)月(\d+)[日号]?').firstMatch(text);
    if (dateMatch != null) {
      final month = int.tryParse(dateMatch.group(1) ?? '') ?? now.month;
      final day = int.tryParse(dateMatch.group(2) ?? '') ?? now.day;
      final specificDate = DateTime(now.year, month, day);
      return DateTimeRange(start: specificDate, end: specificDate.add(const Duration(days: 1)));
    }

    return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
  }

  /// 解析顺序指代
  OrderInfo _parseOrderReference(DetectedReference ref) {
    final text = ref.rawText;

    if (text.contains('上一笔') || text.contains('最后一笔') || text.contains('最新')) {
      return const OrderInfo(index: 0, direction: OrderDirection.latest);
    }
    if (text.contains('第一笔') || text.contains('最早')) {
      return const OrderInfo(index: 0, direction: OrderDirection.earliest);
    }

    final indexMatch = RegExp(r'第(\d+)笔').firstMatch(text);
    if (indexMatch != null) {
      final index = int.tryParse(indexMatch.group(1) ?? '') ?? 1;
      return OrderInfo(index: index - 1, direction: OrderDirection.latest);
    }

    return const OrderInfo(index: 0, direction: OrderDirection.latest);
  }

  /// 解析分类指代
  String? _parseCategoryReference(DetectedReference ref) {
    final text = ref.rawText;
    const categoryMap = {
      '早餐': '餐饮', '午餐': '餐饮', '晚餐': '餐饮', '外卖': '餐饮', '夜宵': '餐饮',
      '打车': '交通', '地铁': '交通', '公交': '交通', '加油': '交通', '停车': '交通',
      '超市': '购物', '淘宝': '购物', '京东': '购物', '购物': '购物',
      '电影': '娱乐', '游戏': '娱乐', '旅游': '娱乐', '娱乐': '娱乐',
      '工资': '收入', '奖金': '收入', '收入': '收入', '入账': '收入',
    };

    for (final entry in categoryMap.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return text;
  }

  /// 解析金额指代
  AmountInfo _parseAmountReference(DetectedReference ref) {
    final text = ref.rawText;

    if (text.contains('最大') || text.contains('最贵')) {
      return const AmountInfo(sortByAmount: true, ascending: false);
    }
    if (text.contains('最小') || text.contains('最便宜')) {
      return const AmountInfo(sortByAmount: true, ascending: true);
    }

    final amountMatch = RegExp(r'(\d+\.?\d*)').firstMatch(text);
    if (amountMatch != null) {
      final amount = double.tryParse(amountMatch.group(1) ?? '');
      if (amount != null) {
        return AmountInfo(exactAmount: amount);
      }
    }

    return const AmountInfo();
  }

  /// 解析商家指代
  String? _parseMerchantReference(DetectedReference ref) {
    final text = ref.rawText;
    const knownMerchants = ['肯德基', '麦当劳', '星巴克', '瑞幸', '美团', '饿了么', '滴滴'];
    for (final merchant in knownMerchants) {
      if (text.contains(merchant)) return merchant;
    }

    final inMatch = RegExp(r'在(.{2,8})的').firstMatch(text);
    if (inMatch != null) return inMatch.group(1);

    return null;
  }

  /// 计算候选记录置信度
  List<ScoredCandidate> _scoreCandidates(
    List<TransactionRecord> candidates,
    List<DetectedReference> references,
    DisambiguationContext? context,
  ) {
    final scored = <ScoredCandidate>[];

    for (final candidate in candidates) {
      double score = 0.0; // 从0开始，只有匹配才加分

      for (final ref in references) {
        switch (ref.type) {
          case ReferenceType.time:
            score += 0.2;
            break;
          case ReferenceType.description:
            final categoryHint = _parseCategoryReference(ref);
            if (candidate.category?.contains(categoryHint ?? '') == true ||
                candidate.description?.contains(ref.rawText) == true) {
              score += 0.4; // 描述匹配很重要，提高权重
            }
            break;
          case ReferenceType.amount:
            final amountInfo = _parseAmountReference(ref);
            if (amountInfo.exactAmount != null) {
              final diff = (candidate.amount - amountInfo.exactAmount!).abs();
              if (diff < 1) {
                score += 0.5; // 金额精确匹配很重要
              } else if (diff < 5) score += 0.3;
            }
            break;
          case ReferenceType.merchant:
            final merchantHint = _parseMerchantReference(ref);
            if (candidate.merchant?.contains(merchantHint ?? '') == true) {
              score += 0.3;
            }
            break;
          case ReferenceType.order:
            break;
        }
      }

      if (_recentRecords.any((r) => r.transactionId == candidate.id)) {
        score += 0.2;
      }

      if (context?.lastMentionedRecordId == candidate.id) {
        score += 0.3;
      }

      scored.add(ScoredCandidate(record: candidate, confidence: score.clamp(0.0, 1.0)));
    }

    scored.sort((a, b) => b.confidence.compareTo(a.confidence));
    return scored;
  }

  /// 消歧决策
  DisambiguationResult _makeDecision(
    List<ScoredCandidate> candidates,
    List<DetectedReference> references,
  ) {
    if (candidates.isEmpty) {
      return DisambiguationResult.noMatch(references);
    }

    final best = candidates.first;
    final second = candidates.length > 1 ? candidates[1] : null;

    // 如果最佳匹配的置信度太低（< 0.7），直接告诉用户没有找到
    if (best.confidence < 0.7) {
      return DisambiguationResult.noMatch(references);
    }

    // 高置信度且明显优于第二名，直接解析
    if (best.confidence >= 0.85 && (second == null || second.confidence < 0.5)) {
      return DisambiguationResult.resolved(
        record: best.record,
        confidence: best.confidence,
        references: references,
      );
    }

    // 有多个候选且第二名置信度也不错，需要澄清（只显示置信度 >= 0.7 的）
    final qualifiedCandidates = candidates.where((c) => c.confidence >= 0.7).take(3).toList();
    if (qualifiedCandidates.length > 1 && second != null && second.confidence >= 0.7) {
      return DisambiguationResult.needClarification(
        candidates: qualifiedCandidates,
        references: references,
        clarificationPrompt: _generateClarificationPrompt(qualifiedCandidates),
      );
    }

    // 中等置信度，需要确认
    if (best.confidence >= 0.7) {
      return DisambiguationResult.resolved(
        record: best.record,
        confidence: best.confidence,
        references: references,
        needConfirmation: true,
      );
    }

    // 置信度不足，要求更多信息
    return DisambiguationResult.noMatch(references);
  }

  /// 生成澄清提示
  String _generateClarificationPrompt(List<ScoredCandidate> candidates) {
    final buffer = StringBuffer('找到${candidates.length}笔相似记录，您要操作哪一笔？\n');
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      buffer.writeln('${i + 1}. ${c.record.description ?? c.record.category} '
          '¥${c.record.amount.toStringAsFixed(2)} '
          '${_formatDate(c.record.date)}');
    }
    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays == 0) return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.month}月${date.day}日';
  }

  // ═══════════════════════════════════════════════════════════════
  // 上下文管理
  // ═══════════════════════════════════════════════════════════════

  /// 记录最近操作的记录
  void recordRecentOperation(TransactionRecord record) {
    _recentRecords.removeWhere((r) => r.transactionId == record.id);
    _recentRecords.insert(0, RecentRecord(transactionId: record.id, timestamp: DateTime.now()));
    if (_recentRecords.length > maxRecentRecords) _recentRecords.removeLast();
    notifyListeners();
  }

  /// 更新消歧上下文
  void updateContext(DisambiguationContext context) {
    _currentContext = context;
    notifyListeners();
  }

  /// 清除上下文
  void clearContext() {
    _currentContext = null;
    notifyListeners();
  }

  /// 用户选择澄清
  Future<DisambiguationResult> handleClarification(
    String userInput,
    List<ScoredCandidate> candidates,
  ) async {
    final lowerInput = userInput.toLowerCase();

    final indexMatch = RegExp(r'(\d+)').firstMatch(lowerInput);
    if (indexMatch != null) {
      final index = int.tryParse(indexMatch.group(1) ?? '') ?? 0;
      if (index > 0 && index <= candidates.length) {
        final selected = candidates[index - 1];
        return DisambiguationResult.resolved(record: selected.record, confidence: 1.0, references: []);
      }
    }

    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      if (c.record.description != null && lowerInput.contains(c.record.description!.toLowerCase())) {
        return DisambiguationResult.resolved(record: c.record, confidence: 0.95, references: []);
      }
      if (c.record.category != null && lowerInput.contains(c.record.category!.toLowerCase())) {
        return DisambiguationResult.resolved(record: c.record, confidence: 0.9, references: []);
      }
    }

    return DisambiguationResult.needMoreInfo(references: [], prompt: '没有理解您的选择，请说"第几个"或描述具体特征');
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据类型定义
// ═══════════════════════════════════════════════════════════════

enum ReferenceType { time, order, description, amount, merchant }

class DetectedReference {
  final ReferenceType type;
  final String rawText;
  final int startIndex;
  final int endIndex;
  final List<String?> capturedGroups;

  const DetectedReference({
    required this.type,
    required this.rawText,
    required this.startIndex,
    required this.endIndex,
    this.capturedGroups = const [],
  });
}

class QueryConditions {
  final DateTime startDate;
  final DateTime endDate;
  final String? categoryHint;
  final String? merchantHint;
  final double? amountHint;
  final double? amountMin;
  final double? amountMax;
  final int? orderIndex;
  final OrderDirection orderDirection;
  final int limit;

  const QueryConditions({
    required this.startDate,
    required this.endDate,
    this.categoryHint,
    this.merchantHint,
    this.amountHint,
    this.amountMin,
    this.amountMax,
    this.orderIndex,
    this.orderDirection = OrderDirection.latest,
    this.limit = 5,
  });
}

enum OrderDirection { latest, earliest }

class OrderInfo {
  final int index;
  final OrderDirection direction;
  const OrderInfo({required this.index, required this.direction});
}

class AmountInfo {
  final double? exactAmount;
  final double? minAmount;
  final double? maxAmount;
  final bool sortByAmount;
  final bool ascending;

  const AmountInfo({
    this.exactAmount,
    this.minAmount,
    this.maxAmount,
    this.sortByAmount = false,
    this.ascending = false,
  });
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}

class TransactionRecord {
  final String id;
  final double amount;
  final String? category;
  final String? subCategory;
  final String? merchant;
  final String? description;
  final DateTime date;
  final String? account;
  final List<String> tags;
  final String type;

  const TransactionRecord({
    required this.id,
    required this.amount,
    this.category,
    this.subCategory,
    this.merchant,
    this.description,
    required this.date,
    this.account,
    this.tags = const [],
    this.type = 'expense',
  });
}

class ScoredCandidate {
  final TransactionRecord record;
  final double confidence;
  const ScoredCandidate({required this.record, required this.confidence});
}

class DisambiguationResult {
  final DisambiguationStatus status;
  final TransactionRecord? resolvedRecord;
  final double confidence;
  final List<ScoredCandidate> candidates;
  final List<DetectedReference> references;
  final String? clarificationPrompt;
  final bool needConfirmation;

  const DisambiguationResult({
    required this.status,
    this.resolvedRecord,
    this.confidence = 0,
    this.candidates = const [],
    this.references = const [],
    this.clarificationPrompt,
    this.needConfirmation = false,
  });

  factory DisambiguationResult.noReference() => const DisambiguationResult(status: DisambiguationStatus.noReference);

  factory DisambiguationResult.noMatch(List<DetectedReference> refs) => DisambiguationResult(
    status: DisambiguationStatus.noMatch,
    references: refs,
  );

  factory DisambiguationResult.resolved({
    required TransactionRecord record,
    required double confidence,
    required List<DetectedReference> references,
    bool needConfirmation = false,
  }) => DisambiguationResult(
    status: DisambiguationStatus.resolved,
    resolvedRecord: record,
    confidence: confidence,
    references: references,
    needConfirmation: needConfirmation,
  );

  factory DisambiguationResult.needClarification({
    required List<ScoredCandidate> candidates,
    required List<DetectedReference> references,
    required String clarificationPrompt,
  }) => DisambiguationResult(
    status: DisambiguationStatus.needClarification,
    candidates: candidates,
    references: references,
    clarificationPrompt: clarificationPrompt,
  );

  factory DisambiguationResult.needMoreInfo({
    required List<DetectedReference> references,
    required String prompt,
  }) => DisambiguationResult(
    status: DisambiguationStatus.needMoreInfo,
    references: references,
    clarificationPrompt: prompt,
  );

  bool get isResolved => status == DisambiguationStatus.resolved;
  bool get needsClarification => status == DisambiguationStatus.needClarification;
  bool get needsMoreInfo => status == DisambiguationStatus.needMoreInfo;
}

enum DisambiguationStatus { noReference, noMatch, resolved, needClarification, needMoreInfo }

class DisambiguationContext {
  final String? lastMentionedRecordId;
  final DateTime? defaultStartDate;
  final DateTime? defaultEndDate;
  final String? defaultCategory;
  final Map<String, dynamic> customData;

  const DisambiguationContext({
    this.lastMentionedRecordId,
    this.defaultStartDate,
    this.defaultEndDate,
    this.defaultCategory,
    this.customData = const {},
  });
}

class RecentRecord {
  final String transactionId;
  final DateTime timestamp;
  const RecentRecord({required this.transactionId, required this.timestamp});
}

typedef TransactionQueryCallback = Future<List<TransactionRecord>> Function(QueryConditions conditions);
