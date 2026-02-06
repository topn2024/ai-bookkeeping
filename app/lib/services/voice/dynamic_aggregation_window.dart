/// 动态聚合窗口
///
/// 实现滑动窗口机制，每次 ASR 返回时重置计时器
/// 根据语义分析动态调整等待时间
///
/// 等待时间策略：
/// - 检测到连接词（还有、另外）→ 延长至 2000ms
/// - 完整交易 + VAD停顿 > 500ms → 缩短至 800ms
/// - 以逗号结尾（列举模式）→ 延长至 2000ms
/// - 默认 → 1200ms
/// - 最大等待时间兜底 → 5000ms
library;

import 'package:flutter/foundation.dart';

/// 等待时间常量
class AggregationTiming {
  /// 最小等待时间（完整交易+明确停顿）
  static const int minWaitMs = 800;

  /// 默认等待时间
  static const int defaultWaitMs = 1200;

  /// 延长等待时间（连接词/列举模式）
  static const int extendedWaitMs = 2000;

  /// 最大等待时间兜底
  static const int maxWaitMs = 5000;

  /// VAD停顿阈值（用于判断用户是否已停顿足够时间）
  static const int vadPauseThresholdMs = 500;

  AggregationTiming._();
}

/// 聚合上下文（用于计算等待时间）
class AggregationContext {
  /// 当前文本
  final String text;

  /// 用户是否正在说话（VAD状态）
  final bool isUserSpeaking;

  /// 自上次语音结束的时间（毫秒）
  final int? msSinceLastSpeechEnd;

  /// 缓冲区中已有的句子数量
  final int bufferedSentenceCount;

  /// 累计等待时间（毫秒）
  final int cumulativeWaitMs;

  const AggregationContext({
    required this.text,
    required this.isUserSpeaking,
    this.msSinceLastSpeechEnd,
    required this.bufferedSentenceCount,
    required this.cumulativeWaitMs,
  });
}

/// 等待时间计算结果
class WaitTimeResult {
  /// 计算出的等待时间（毫秒）
  final int waitTimeMs;

  /// 是否强制触发（超过最大等待时间）
  final bool forceProcess;

  /// 原因说明（用于调试）
  final String reason;

  const WaitTimeResult({
    required this.waitTimeMs,
    this.forceProcess = false,
    required this.reason,
  });

  @override
  String toString() => 'WaitTimeResult($waitTimeMs ms, force=$forceProcess, reason=$reason)';
}

/// 动态聚合窗口
///
/// 根据语义分析动态调整等待时间，优化多笔交易录入体验
class DynamicAggregationWindow {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 语义特征检测模式
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 连接词模式（表示用户还要继续说）
  static const _connectorPatterns = <String>[
    '还有',
    '另外',
    '以及',
    '再就是',
    '然后',
    '接着',
    '还',
    '再',
    '和',
    '跟',
    '加上',
  ];

  /// 未完成信号（结尾词）
  static const _incompleteEndingPatterns = <String>[
    '还有',
    '另外',
    '以及',
    '然后',
    '接着',
    '花了',  // "鼠标花了" - 缺少金额
    '花',    // "花" - 缺少金额
    '买了',  // "买了" - 缺少内容
    '买',    // "买" - 缺少内容
    '用了',  // "用了" - 缺少金额
    '用',    // "用" - 缺少金额
    '花费',  // "花费" - 缺少金额
    '消费',  // "消费" - 缺少金额
    '支出',  // "支出" - 缺少金额
    '收入',  // "收入" - 缺少金额
    '赚了',  // "赚了" - 缺少金额
  ];

  /// 结束信号（用户表示说完了）
  static const _endSignalPatterns = <String>[
    '就这些',
    '没了',
    '完了',
    '好了',
    '记吧',
    '就这样',
    '结束',
    '就这么多',
    '没有了',
  ];

  /// 金额模式（检测是否包含金额）
  static final _amountPattern = RegExp(r'\d+(\.\d+)?(元|块|毛|角|分)?');

  /// 分类词模式（检测是否包含分类信息）
  static final _categoryPattern = RegExp(
    r'(早餐|午餐|晚餐|早饭|午饭|晚饭|吃饭|打车|出租车|地铁|公交|交通|买菜|超市|购物|水果|饮料|咖啡|奶茶|外卖|快递|话费|充值|医疗|药|水电|房租|工资|收入)',
  );

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 核心计算逻辑
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 计算等待时间
  WaitTimeResult calculateWaitTime(AggregationContext context) {
    final text = context.text.trim();

    debugPrint('[DynamicAggregationWindow] 计算等待时间: '
        'text="$text", '
        'speaking=${context.isUserSpeaking}, '
        'pauseMs=${context.msSinceLastSpeechEnd}, '
        'buffered=${context.bufferedSentenceCount}, '
        'cumulative=${context.cumulativeWaitMs}ms');

    // 0. 用户正在说话时，使用最大等待时间
    //    这是最重要的规则：用户还在说话，绝对不能提前触发处理
    if (context.isUserSpeaking) {
      debugPrint('[DynamicAggregationWindow] 用户正在说话，使用最大等待时间');
      return const WaitTimeResult(
        waitTimeMs: AggregationTiming.maxWaitMs,
        reason: '用户正在说话',
      );
    }

    // 1. 最大等待时间兜底
    if (context.cumulativeWaitMs >= AggregationTiming.maxWaitMs) {
      debugPrint('[DynamicAggregationWindow] 超过最大等待时间，强制处理');
      return const WaitTimeResult(
        waitTimeMs: 0,
        forceProcess: true,
        reason: '超过最大等待时间(${AggregationTiming.maxWaitMs}ms)',
      );
    }

    // 2. 检测连接词（延长等待）
    if (_hasConnectorAtEnd(text)) {
      debugPrint('[DynamicAggregationWindow] 检测到连接词，延长等待');
      return const WaitTimeResult(
        waitTimeMs: AggregationTiming.extendedWaitMs,
        reason: '检测到连接词',
      );
    }

    // 3. 检测列举模式（以逗号结尾且包含金额）
    if (_isListingMode(text)) {
      debugPrint('[DynamicAggregationWindow] 检测到列举模式，延长等待');
      return const WaitTimeResult(
        waitTimeMs: AggregationTiming.extendedWaitMs,
        reason: '列举模式（逗号结尾+金额）',
      );
    }

    // 3.5 检测结束信号（用户明确表示说完了）
    if (_hasEndSignal(text)) {
      debugPrint('[DynamicAggregationWindow] 检测到结束信号，缩短等待');
      return const WaitTimeResult(
        waitTimeMs: AggregationTiming.minWaitMs,
        reason: '用户结束信号',
      );
    }

    // 3.6 检测"有分类词但无金额"（如"今天的早餐"）
    //     用户可能需要更长时间思考金额，给4秒等待
    //     这是最常见的不完整记账意图，需要足够的时间让用户思考并补充金额
    if (_hasCategoryWithoutAmount(text)) {
      debugPrint('[DynamicAggregationWindow] 检测到分类词但无金额，延长等待4秒');
      return const WaitTimeResult(
        waitTimeMs: 4000,  // 4秒，给用户足够时间思考金额
        reason: '分类词无金额（等待用户补充）',
      );
    }

    // 3.7 检测记账意图（有金额但无结束信号，可能还有后续）
    if (_hasBookkeepingIntent(text)) {
      debugPrint('[DynamicAggregationWindow] 检测到记账意图，延长等待以收集后续');
      return const WaitTimeResult(
        waitTimeMs: AggregationTiming.extendedWaitMs,
        reason: '记账意图（可能还有后续）',
      );
    }

    // 4. 检测完整交易（缩短等待）
    if (_isCompleteTransaction(text)) {
      // 如果用户已停顿足够时间，使用最小等待
      final pauseMs = context.msSinceLastSpeechEnd ?? 0;
      if (!context.isUserSpeaking && pauseMs >= AggregationTiming.vadPauseThresholdMs) {
        debugPrint('[DynamicAggregationWindow] 完整交易+足够停顿，缩短等待');
        return const WaitTimeResult(
          waitTimeMs: AggregationTiming.minWaitMs,
          reason: '完整交易+VAD停顿>${AggregationTiming.vadPauseThresholdMs}ms',
        );
      }
    }

    // 5. 默认等待时间
    debugPrint('[DynamicAggregationWindow] 使用默认等待时间');
    return const WaitTimeResult(
      waitTimeMs: AggregationTiming.defaultWaitMs,
      reason: '默认等待',
    );
  }

  /// 检测文本末尾是否有连接词
  bool _hasConnectorAtEnd(String text) {
    final normalized = text.replaceAll(RegExp(r'[，。！？、；：,.!?;:\s]+$'), '');

    for (final connector in _incompleteEndingPatterns) {
      if (normalized.endsWith(connector)) {
        return true;
      }
    }

    return false;
  }

  /// 检测是否为列举模式
  bool _isListingMode(String text) {
    // 以逗号结尾
    if (!text.endsWith(',') && !text.endsWith('，')) {
      return false;
    }

    // 包含金额
    return _amountPattern.hasMatch(text);
  }

  /// 检测是否为完整交易
  bool _isCompleteTransaction(String text) {
    // 包含金额
    if (!_amountPattern.hasMatch(text)) {
      return false;
    }

    // 包含分类
    if (!_categoryPattern.hasMatch(text)) {
      return false;
    }

    // 不以连接词结尾
    if (_hasConnectorAtEnd(text)) {
      return false;
    }

    return true;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 辅助方法
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 检测文本中是否包含连接词（用于判断用户是否要继续说）
  bool hasConnector(String text) {
    for (final connector in _connectorPatterns) {
      if (text.contains(connector)) {
        return true;
      }
    }
    return false;
  }

  /// 估计文本中的交易数量
  int estimateTransactionCount(String text) {
    final matches = _amountPattern.allMatches(text);
    return matches.length;
  }

  /// 记账请求短语（用户表示要记账，但还没说金额）
  static const _bookkeepingRequestPatterns = <String>[
    '帮我记',
    '记一笔',
    '记两笔',
    '记三笔',
    '记几笔',
    '记笔账',
    '记个账',
    '记账',
    '帮我寄',  // ASR可能误识别"记"为"寄"
    '寄一笔',
    '寄两笔',
    '寄笔账',
  ];

  /// 检测是否有记账意图（包含金额、记账请求短语、或分类词但无金额）
  bool _hasBookkeepingIntent(String text) {
    // 1. 包含数字金额
    if (_amountPattern.hasMatch(text)) {
      return true;
    }

    // 2. 包含记账请求短语（用户说"帮我记两笔账"但还没说具体金额）
    for (final pattern in _bookkeepingRequestPatterns) {
      if (text.contains(pattern)) {
        return true;
      }
    }

    // 3. 包含分类词但没有金额（如"今天的早餐"、"午餐"）
    //    这是不完整的记账意图，用户很可能还要继续说金额
    //    注意：这种情况需要更长的等待时间，在 calculateWaitTime 中特殊处理
    if (_categoryPattern.hasMatch(text)) {
      debugPrint('[DynamicAggregationWindow] 检测到分类词但无金额，等待用户补充');
      return true;
    }

    return false;
  }

  /// 检测是否有结束信号（用户明确表示说完了）
  bool _hasEndSignal(String text) {
    for (final signal in _endSignalPatterns) {
      if (text.contains(signal)) {
        return true;
      }
    }
    return false;
  }

  /// 检测是否有分类词但没有金额
  /// 这种情况用户很可能还要继续说金额，需要更长的等待时间
  bool _hasCategoryWithoutAmount(String text) {
    // 必须有分类词
    if (!_categoryPattern.hasMatch(text)) {
      return false;
    }
    // 必须没有金额
    if (_amountPattern.hasMatch(text)) {
      return false;
    }
    return true;
  }
}
