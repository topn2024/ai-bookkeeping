import 'dart:convert';
import 'dart:math' as math;

import '../nlu_engine.dart';
import '../voice_service_coordinator.dart' show VoiceIntentType, VoiceSessionContext;
import '../../models/transaction.dart';

/// 语音意图路由器
///
/// 负责分析用户语音输入，识别意图并路由到相应的处理器
///
/// 支持的意图类型：
/// - 删除交易 (delete)
/// - 修改交易 (modify)
/// - 添加交易 (add)
/// - 查询交易 (query)
/// - 页面导航 (navigation)
/// - 确认操作 (confirm)
/// - 取消操作 (cancel)
/// - 澄清选择 (clarify)
class VoiceIntentRouter {
  /// 意图识别的置信度阈值
  static const double _confidenceThreshold = 0.7;

  /// 最大候选意图数量
  static const int _maxCandidates = 3;

  /// 删除意图的关键词模式
  static final _deletePatterns = [
    RegExp(r'删除|删掉|去掉|移除|清除', caseSensitive: false),
    RegExp(r'不要|取消.*记录', caseSensitive: false),
    RegExp(r'撤销|撤回', caseSensitive: false),
  ];

  /// 修改意图的关键词模式
  static final _modifyPatterns = [
    RegExp(r'修改|更改|改成|换成|调整', caseSensitive: false),
    RegExp(r'把.*改', caseSensitive: false),
    RegExp(r'改.*为|改.*成', caseSensitive: false),
    RegExp(r'更新|变更', caseSensitive: false),
  ];

  /// 添加意图的关键词模式
  static final _addPatterns = [
    RegExp(r'添加|新增|记录|记一笔', caseSensitive: false),
    RegExp(r'花了|买了|付了|支付', caseSensitive: false),
    RegExp(r'收入|赚了|进账', caseSensitive: false),
    RegExp(r'记账|记录.*消费', caseSensitive: false),
  ];

  /// 查询意图的关键词模式
  static final _queryPatterns = [
    RegExp(r'查看|查询|显示|统计', caseSensitive: false),
    RegExp(r'多少钱|多少块|总共.*钱', caseSensitive: false),
    RegExp(r'什么时候|哪天|几号', caseSensitive: false),
    RegExp(r'分析|报告|汇总', caseSensitive: false),
  ];

  /// 导航意图的关键词模式
  static final _navigationPatterns = [
    RegExp(r'打开|进入|跳转|切换', caseSensitive: false),
    RegExp(r'返回|回到|退回', caseSensitive: false),
    RegExp(r'页面|界面|菜单', caseSensitive: false),
  ];

  /// 确认意图的关键词模式
  static final _confirmPatterns = [
    RegExp(r'确认|确定|是的|对|好的|可以', caseSensitive: false),
    RegExp(r'同意|没问题|ok|yes', caseSensitive: false),
  ];

  /// 取消意图的关键词模式
  static final _cancelPatterns = [
    RegExp(r'取消|不要|算了|停止', caseSensitive: false),
    RegExp(r'不对|错了|重新', caseSensitive: false),
    RegExp(r'退出|返回|no', caseSensitive: false),
  ];

  /// 澄清意图的关键词模式（选择项目）
  static final _clarifyPatterns = [
    RegExp(r'第.*个|第.*项|第.*条', caseSensitive: false),
    RegExp(r'选择|要.*这个|就是.*那个', caseSensitive: false),
    RegExp(r'[一二三四五六七八九十]|[1-9]', caseSensitive: false),
  ];

  /// 分析语音输入并识别意图
  ///
  /// [input] 用户的语音输入文本
  /// [context] 当前会话上下文，用于优化意图识别
  ///
  /// Returns 包含意图类型、置信度和提取实体的结果
  Future<IntentAnalysisResult> analyzeIntent(
    String input, {
    VoiceSessionContext? context,
  }) async {
    if (input.isEmpty) {
      return IntentAnalysisResult(
        intent: VoiceIntentType.unknown,
        confidence: 0.0,
        rawInput: input,
      );
    }

    // 预处理输入
    final normalizedInput = _normalizeInput(input);

    // 计算各意图的匹配分数
    final intentScores = await _calculateIntentScores(normalizedInput, context);

    // 获取最佳匹配意图
    final bestMatch = _getBestMatch(intentScores);

    // 提取相关实体
    final entities = await _extractEntities(normalizedInput, bestMatch.intent);

    return IntentAnalysisResult(
      intent: bestMatch.intent,
      confidence: bestMatch.score,
      rawInput: input,
      normalizedInput: normalizedInput,
      entities: entities,
      candidateIntents: _getCandidateIntents(intentScores),
      contextBoosted: context != null,
    );
  }

  /// 预处理用户输入
  String _normalizeInput(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')  // 标准化空格
        .replaceAll(RegExp(r'[。，！？：；]'), ' '); // 移除标点符号
  }

  /// 计算各意图的匹配分数
  Future<Map<VoiceIntentType, double>> _calculateIntentScores(
    String input,
    VoiceSessionContext? context,
  ) async {
    final scores = <VoiceIntentType, double>{};

    // 基础模式匹配分数
    scores[VoiceIntentType.deleteTransaction] = _calculatePatternScore(input, _deletePatterns);
    scores[VoiceIntentType.modifyTransaction] = _calculatePatternScore(input, _modifyPatterns);
    scores[VoiceIntentType.addTransaction] = _calculatePatternScore(input, _addPatterns);
    scores[VoiceIntentType.queryTransaction] = _calculatePatternScore(input, _queryPatterns);
    scores[VoiceIntentType.navigateToPage] = _calculatePatternScore(input, _navigationPatterns);
    scores[VoiceIntentType.confirmAction] = _calculatePatternScore(input, _confirmPatterns);
    scores[VoiceIntentType.cancelAction] = _calculatePatternScore(input, _cancelPatterns);
    scores[VoiceIntentType.clarifySelection] = _calculatePatternScore(input, _clarifyPatterns);

    // 上下文增强
    if (context != null) {
      _applyContextBoosting(scores, context);
    }

    // 特殊规则增强
    _applySpecialRules(scores, input);

    return scores;
  }

  /// 计算模式匹配分数
  double _calculatePatternScore(String input, List<RegExp> patterns) {
    double maxScore = 0.0;

    for (final pattern in patterns) {
      final matches = pattern.allMatches(input);
      if (matches.isNotEmpty) {
        // 基础匹配分数
        double score = 0.3;

        // 多次匹配加分
        score += matches.length * 0.1;

        // 匹配长度加分
        final totalMatchLength = matches.fold(0, (sum, match) => sum + match.group(0)!.length);
        score += (totalMatchLength / input.length) * 0.3;

        // 完整词匹配加分
        if (_isCompleteWordMatch(input, matches.first)) {
          score += 0.2;
        }

        maxScore = math.max(maxScore, score);
      }
    }

    return math.min(maxScore, 1.0);
  }

  /// 检查是否为完整词匹配
  bool _isCompleteWordMatch(String input, RegExpMatch match) {
    final start = match.start;
    final end = match.end;

    final isStartBoundary = start == 0 || RegExp(r'\s').hasMatch(input[start - 1]);
    final isEndBoundary = end == input.length || RegExp(r'\s').hasMatch(input[end]);

    return isStartBoundary && isEndBoundary;
  }

  /// 应用上下文增强
  void _applyContextBoosting(
    Map<VoiceIntentType, double> scores,
    VoiceSessionContext context,
  ) {
    const double contextBoost = 0.3;

    switch (context.intentType) {
      case VoiceIntentType.deleteTransaction:
        scores[VoiceIntentType.confirmAction] =
            (scores[VoiceIntentType.confirmAction] ?? 0.0) + contextBoost;
        scores[VoiceIntentType.cancelAction] =
            (scores[VoiceIntentType.cancelAction] ?? 0.0) + contextBoost;
        scores[VoiceIntentType.clarifySelection] =
            (scores[VoiceIntentType.clarifySelection] ?? 0.0) + contextBoost;
        break;

      case VoiceIntentType.modifyTransaction:
        scores[VoiceIntentType.confirmAction] =
            (scores[VoiceIntentType.confirmAction] ?? 0.0) + contextBoost;
        scores[VoiceIntentType.cancelAction] =
            (scores[VoiceIntentType.cancelAction] ?? 0.0) + contextBoost;
        scores[VoiceIntentType.clarifySelection] =
            (scores[VoiceIntentType.clarifySelection] ?? 0.0) + contextBoost;
        break;

      default:
        // 对于其他上下文，不进行特殊增强
        break;
    }
  }

  /// 应用特殊规则增强
  void _applySpecialRules(Map<VoiceIntentType, double> scores, String input) {
    // 金额相关的输入更可能是添加或查询
    if (RegExp(r'\d+(\.\d+)?\s*[元块钱]').hasMatch(input)) {
      if (input.contains('花了') || input.contains('买了') || input.contains('支付')) {
        scores[VoiceIntentType.addTransaction] =
            (scores[VoiceIntentType.addTransaction] ?? 0.0) + 0.2;
      }
    }

    // 时间相关的输入更可能是查询
    if (RegExp(r'今天|昨天|本月|本周|这个月').hasMatch(input)) {
      if (input.contains('多少') || input.contains('统计')) {
        scores[VoiceIntentType.queryTransaction] =
            (scores[VoiceIntentType.queryTransaction] ?? 0.0) + 0.2;
      }
    }

    // 很短的回复更可能是确认或取消
    if (input.length <= 3) {
      if (RegExp(r'^(是|对|好|ok)$').hasMatch(input)) {
        scores[VoiceIntentType.confirmAction] =
            (scores[VoiceIntentType.confirmAction] ?? 0.0) + 0.3;
      } else if (RegExp(r'^(不|错|算了)$').hasMatch(input)) {
        scores[VoiceIntentType.cancelAction] =
            (scores[VoiceIntentType.cancelAction] ?? 0.0) + 0.3;
      }
    }

    // 数字回复更可能是澄清选择
    if (RegExp(r'^[1-9]\d*$').hasMatch(input)) {
      scores[VoiceIntentType.clarifySelection] =
          (scores[VoiceIntentType.clarifySelection] ?? 0.0) + 0.4;
    }
  }

  /// 获取最佳匹配意图
  _IntentScore _getBestMatch(Map<VoiceIntentType, double> scores) {
    VoiceIntentType bestIntent = VoiceIntentType.unknown;
    double bestScore = 0.0;

    scores.forEach((intent, score) {
      if (score > bestScore) {
        bestScore = score;
        bestIntent = intent;
      }
    });

    // 如果最高分数低于阈值，则认为是未知意图
    if (bestScore < _confidenceThreshold) {
      bestIntent = VoiceIntentType.unknown;
      bestScore = 0.0;
    }

    return _IntentScore(bestIntent, bestScore);
  }

  /// 获取候选意图列表
  List<IntentCandidate> _getCandidateIntents(Map<VoiceIntentType, double> scores) {
    final candidates = scores.entries
        .where((entry) => entry.value > 0.1) // 过滤掉分数太低的
        .map((entry) => IntentCandidate(
              intent: entry.key,
              confidence: entry.value,
            ))
        .toList();

    // 按置信度排序
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    // 返回最多3个候选
    return candidates.take(_maxCandidates).toList();
  }

  /// 提取实体信息
  Future<Map<String, dynamic>> _extractEntities(
    String input,
    VoiceIntentType intent,
  ) async {
    final entities = <String, dynamic>{};

    switch (intent) {
      case VoiceIntentType.addTransaction:
        entities.addAll(await _extractTransactionEntities(input));
        break;

      case VoiceIntentType.deleteTransaction:
      case VoiceIntentType.modifyTransaction:
      case VoiceIntentType.queryTransaction:
        entities.addAll(await _extractQueryEntities(input));
        break;

      case VoiceIntentType.navigateToPage:
        entities.addAll(await _extractNavigationEntities(input));
        break;

      case VoiceIntentType.clarifySelection:
        entities.addAll(await _extractSelectionEntities(input));
        break;

      default:
        // 其他意图不需要特殊实体提取
        break;
    }

    return entities;
  }

  /// 提取交易实体
  Future<Map<String, dynamic>> _extractTransactionEntities(String input) async {
    final entities = <String, dynamic>{};

    // 提取金额
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[元块钱]?').firstMatch(input);
    if (amountMatch != null) {
      entities['amount'] = double.tryParse(amountMatch.group(1)!) ?? 0.0;
    }

    // 提取分类
    final categoryKeywords = {
      '餐饮': ['吃', '餐', '饭', '菜', '喝', '咖啡', '茶'],
      '交通': ['打车', '地铁', '公交', '出租车', '滴滴', '油费'],
      '购物': ['买', '购', '商场', '淘宝', '京东', '购物'],
      '娱乐': ['电影', '游戏', 'ktv', '唱歌', '娱乐'],
      '医疗': ['医院', '看病', '药', '体检', '医疗'],
    };

    for (final entry in categoryKeywords.entries) {
      if (entry.value.any((keyword) => input.contains(keyword))) {
        entities['category'] = entry.key;
        break;
      }
    }

    // 提取商家
    final merchantMatch = RegExp(r'在(.{2,10}?)(?:买|吃|花|消费)').firstMatch(input);
    if (merchantMatch != null) {
      entities['merchant'] = merchantMatch.group(1)?.trim();
    }

    return entities;
  }

  /// 提取查询实体
  Future<Map<String, dynamic>> _extractQueryEntities(String input) async {
    final entities = <String, dynamic>{};

    // 提取时间范围
    if (input.contains('今天')) {
      final today = DateTime.now();
      entities['startDate'] = DateTime(today.year, today.month, today.day);
      entities['endDate'] = DateTime(today.year, today.month, today.day, 23, 59, 59);
    } else if (input.contains('昨天')) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      entities['startDate'] = DateTime(yesterday.year, yesterday.month, yesterday.day);
      entities['endDate'] = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    } else if (input.contains('本月') || input.contains('这个月')) {
      final now = DateTime.now();
      entities['startDate'] = DateTime(now.year, now.month, 1);
      entities['endDate'] = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
    }

    // 提取金额范围
    final amountMatch = RegExp(r'超过(\d+)').firstMatch(input);
    if (amountMatch != null) {
      entities['minAmount'] = double.tryParse(amountMatch.group(1)!) ?? 0.0;
    }

    return entities;
  }

  /// 提取导航实体
  Future<Map<String, dynamic>> _extractNavigationEntities(String input) async {
    final entities = <String, dynamic>{};

    final pageKeywords = {
      'home': ['首页', '主页', '主界面'],
      'settings': ['设置', '选项', '配置'],
      'budget': ['预算', '预算中心', '预算页面'],
      'analysis': ['分析', '统计', '报表', '趋势'],
      'account': ['账户', '账号', '个人中心'],
    };

    for (final entry in pageKeywords.entries) {
      if (entry.value.any((keyword) => input.contains(keyword))) {
        entities['targetPage'] = entry.key;
        break;
      }
    }

    return entities;
  }

  /// 提取选择实体
  Future<Map<String, dynamic>> _extractSelectionEntities(String input) async {
    final entities = <String, dynamic>{};

    // 提取数字选择
    final numberMatch = RegExp(r'第?([1-9]\d*)').firstMatch(input);
    if (numberMatch != null) {
      entities['selectionIndex'] = int.tryParse(numberMatch.group(1)!) ?? 1;
    }

    // 提取中文数字
    const chineseNumbers = {
      '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
    };

    for (final entry in chineseNumbers.entries) {
      if (input.contains(entry.key)) {
        entities['selectionIndex'] = entry.value;
        break;
      }
    }

    return entities;
  }

  /// 获取意图的描述
  String getIntentDescription(VoiceIntentType intent) {
    switch (intent) {
      case VoiceIntentType.deleteTransaction:
        return '删除交易记录';
      case VoiceIntentType.modifyTransaction:
        return '修改交易记录';
      case VoiceIntentType.addTransaction:
        return '添加新交易';
      case VoiceIntentType.queryTransaction:
        return '查询交易信息';
      case VoiceIntentType.navigateToPage:
        return '页面导航';
      case VoiceIntentType.confirmAction:
        return '确认操作';
      case VoiceIntentType.cancelAction:
        return '取消操作';
      case VoiceIntentType.clarifySelection:
        return '澄清选择';
      case VoiceIntentType.unknown:
      default:
        return '未知意图';
    }
  }
}

/// 意图分析结果
class IntentAnalysisResult {
  /// 识别到的意图类型
  final VoiceIntentType intent;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 原始输入
  final String rawInput;

  /// 标准化后的输入
  final String? normalizedInput;

  /// 提取的实体信息
  final Map<String, dynamic> entities;

  /// 候选意图列表
  final List<IntentCandidate> candidateIntents;

  /// 是否受到上下文增强
  final bool contextBoosted;

  const IntentAnalysisResult({
    required this.intent,
    required this.confidence,
    required this.rawInput,
    this.normalizedInput,
    this.entities = const {},
    this.candidateIntents = const [],
    this.contextBoosted = false,
  });

  /// 是否为高置信度结果
  bool get isHighConfidence => confidence >= 0.8;

  /// 是否需要确认
  bool get needsConfirmation => confidence < 0.9 && confidence >= 0.6;

  /// 是否为低置信度结果
  bool get isLowConfidence => confidence < 0.6;

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'intent': intent.toString(),
      'confidence': confidence,
      'rawInput': rawInput,
      'normalizedInput': normalizedInput,
      'entities': entities,
      'candidateIntents': candidateIntents.map((c) => c.toJson()).toList(),
      'contextBoosted': contextBoosted,
    };
  }

  @override
  String toString() {
    return 'IntentAnalysisResult(intent: $intent, confidence: ${confidence.toStringAsFixed(2)}, entities: $entities)';
  }
}

/// 候选意图
class IntentCandidate {
  final VoiceIntentType intent;
  final double confidence;

  const IntentCandidate({
    required this.intent,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'intent': intent.toString(),
      'confidence': confidence,
    };
  }
}

/// 内部类：意图分数
class _IntentScore {
  final VoiceIntentType intent;
  final double score;

  const _IntentScore(this.intent, this.score);
}