import '../nlu_engine.dart';
import 'voice_intent_router.dart';

/// 多意图处理结果
///
/// 包含从用户输入中解析出的所有意图，按类型分类：
/// - 完整意图：可直接执行
/// - 不完整意图：需要追问补充信息
/// - 导航意图：单独处理
/// - 噪音：被过滤的无关内容
class MultiIntentResult {
  /// 完整意图（可直接执行）
  final List<CompleteIntent> completeIntents;

  /// 不完整意图（需要追问）
  final List<IncompleteIntent> incompleteIntents;

  /// 导航意图（单独处理）
  final NavigationIntent? navigationIntent;

  /// 被过滤的噪音
  final List<String> filteredNoise;

  /// 原始输入
  final String rawInput;

  /// 分句结果
  final List<String> segments;

  const MultiIntentResult({
    required this.completeIntents,
    required this.incompleteIntents,
    this.navigationIntent,
    required this.filteredNoise,
    required this.rawInput,
    required this.segments,
  });

  /// 是否为单意图（向后兼容）
  bool get isSingleIntent =>
      completeIntents.length + incompleteIntents.length +
          (navigationIntent != null ? 1 : 0) ==
      1;

  /// 是否需要用户确认
  bool get needsConfirmation =>
      completeIntents.isNotEmpty || incompleteIntents.isNotEmpty;

  /// 是否有不完整意图需要追问
  bool get needsFollowUp => incompleteIntents.isNotEmpty;

  /// 总意图数量
  int get totalIntentCount =>
      completeIntents.length +
      incompleteIntents.length +
      (navigationIntent != null ? 1 : 0);

  /// 是否为空结果
  bool get isEmpty => totalIntentCount == 0;

  /// 生成确认提示
  String generatePrompt() {
    final buffer = StringBuffer();

    if (completeIntents.isNotEmpty) {
      buffer.writeln('已识别以下记录：');
      for (var i = 0; i < completeIntents.length; i++) {
        final intent = completeIntents[i];
        buffer.writeln('  ${i + 1}. ${intent.description}');
      }
    }

    if (incompleteIntents.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('以下内容需要补充金额：');
      for (var i = 0; i < incompleteIntents.length; i++) {
        final intent = incompleteIntents[i];
        buffer.writeln('  ${i + 1}. ${intent.description}');
      }
    }

    if (navigationIntent != null) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('稍后将打开：${navigationIntent!.targetPageName}');
    }

    if (completeIntents.isNotEmpty || incompleteIntents.isNotEmpty) {
      buffer.writeln();
      if (incompleteIntents.isNotEmpty) {
        buffer.write('请补充金额或说"确认"记录已有内容');
      } else {
        buffer.write('请说"确认"或"取消"');
      }
    }

    return buffer.toString();
  }

  /// 创建空结果
  factory MultiIntentResult.empty(String rawInput) {
    return MultiIntentResult(
      completeIntents: const [],
      incompleteIntents: const [],
      navigationIntent: null,
      filteredNoise: const [],
      rawInput: rawInput,
      segments: const [],
    );
  }

  /// 从单意图创建（向后兼容）
  factory MultiIntentResult.fromSingle(
    IntentAnalysisResult singleResult,
    String rawInput,
  ) {
    // 根据意图类型创建对应的结果
    if (singleResult.entities.containsKey('targetPage')) {
      final targetPage = singleResult.entities['targetPage'];
      // 类型安全检查，避免强制转换异常
      if (targetPage is String && targetPage.isNotEmpty) {
        return MultiIntentResult(
          completeIntents: const [],
          incompleteIntents: const [],
          navigationIntent: NavigationIntent(
            targetPage: targetPage,
            targetPageName: targetPage,
            originalText: rawInput,
          ),
          filteredNoise: const [],
          rawInput: rawInput,
          segments: [rawInput],
        );
      }
    }

    final amount = (singleResult.entities['amount'] as num?)?.toDouble();
    if (amount != null) {
      return MultiIntentResult(
        completeIntents: [
          CompleteIntent(
            type: TransactionIntentType.expense,
            amount: amount,
            category: singleResult.entities['category'] as String?,
            merchant: singleResult.entities['merchant'] as String?,
            description: rawInput,
            originalText: rawInput,
            confidence: singleResult.confidence,
          ),
        ],
        incompleteIntents: const [],
        navigationIntent: null,
        filteredNoise: const [],
        rawInput: rawInput,
        segments: [rawInput],
      );
    }

    // 无法识别为有效意图
    return MultiIntentResult.empty(rawInput);
  }
}

/// 完整意图（可直接执行）
class CompleteIntent {
  /// 意图类型
  final TransactionIntentType type;

  /// 金额
  final double amount;

  /// 分类
  final String? category;

  /// 商家
  final String? merchant;

  /// 描述
  final String? description;

  /// 原始文本
  final String originalText;

  /// 日期时间
  final DateTime? dateTime;

  /// 置信度
  final double confidence;

  const CompleteIntent({
    required this.type,
    required this.amount,
    this.category,
    this.merchant,
    this.description,
    required this.originalText,
    this.dateTime,
    required this.confidence,
  });

  /// 生成描述文本
  String get displayDescription {
    final buffer = StringBuffer();
    if (category != null) {
      buffer.write(category);
      buffer.write(' ');
    }
    buffer.write('${amount.toStringAsFixed(2)}元');
    if (merchant != null) {
      buffer.write(' (');
      buffer.write(merchant);
      buffer.write(')');
    }
    return buffer.toString();
  }
}

/// 不完整意图（需要追问）
class IncompleteIntent {
  /// 意图类型
  final TransactionIntentType type;

  /// 已识别的金额（当有金额但缺分类时使用）
  final double? amount;

  /// 已识别的分类
  final String? category;

  /// 已识别的商家
  final String? merchant;

  /// 描述
  final String? description;

  /// 原始文本
  final String originalText;

  /// 缺失的槽位
  final List<String> missingSlots;

  /// 日期时间
  final DateTime? dateTime;

  /// 置信度
  final double confidence;

  const IncompleteIntent({
    required this.type,
    this.amount,
    this.category,
    this.merchant,
    this.description,
    required this.originalText,
    required this.missingSlots,
    this.dateTime,
    required this.confidence,
  });

  /// 是否缺少金额
  bool get missingAmount => missingSlots.contains('amount');

  /// 生成描述文本
  String get displayDescription {
    final buffer = StringBuffer();
    if (category != null) {
      buffer.write(category);
    } else if (description != null) {
      buffer.write(description);
    } else {
      buffer.write(originalText);
    }
    buffer.write(' - 缺少');
    buffer.write(missingSlots.map(_slotDisplayName).join('、'));
    return buffer.toString();
  }

  String _slotDisplayName(String slot) {
    switch (slot) {
      case 'amount':
        return '金额';
      case 'category':
        return '分类';
      case 'merchant':
        return '商家';
      default:
        return slot;
    }
  }

  /// 补充金额后转为完整意图
  CompleteIntent completeWith({required double amount}) {
    return CompleteIntent(
      type: type,
      amount: amount,
      category: category,
      merchant: merchant,
      description: description,
      originalText: originalText,
      dateTime: dateTime,
      confidence: confidence,
    );
  }

  /// 补充分类后转为完整意图（当有金额但缺分类时使用）
  CompleteIntent completeWithCategory({required String category, String? note}) {
    return CompleteIntent(
      type: type,
      amount: amount ?? 0,
      category: category,
      merchant: merchant,
      description: note ?? description,
      originalText: originalText,
      dateTime: dateTime,
      confidence: confidence,
    );
  }
}

/// 导航意图
class NavigationIntent {
  /// 目标页面路由
  final String targetPage;

  /// 目标页面名称
  final String targetPageName;

  /// 原始文本
  final String originalText;

  const NavigationIntent({
    required this.targetPage,
    required this.targetPageName,
    required this.originalText,
  });
}

/// 交易意图类型
enum TransactionIntentType {
  /// 支出
  expense,

  /// 收入
  income,

  /// 转账
  transfer,
}

/// 分句分析结果
class SegmentAnalysis {
  /// 原始文本片段
  final String text;

  /// 意图分析结果
  final IntentAnalysisResult? intentResult;

  /// 提取的实体
  final List<NLUEntity> entities;

  /// 解析的金额
  final double? amount;

  /// 是否为噪音
  final bool isNoise;

  /// 置信度
  final double confidence;

  /// 识别的分类
  final String? category;

  /// 识别的商家
  final String? merchant;

  /// 识别的日期时间
  final DateTime? dateTime;

  const SegmentAnalysis({
    required this.text,
    this.intentResult,
    required this.entities,
    this.amount,
    required this.isNoise,
    required this.confidence,
    this.category,
    this.merchant,
    this.dateTime,
  });

  /// 是否为完整的记账意图
  bool get isCompleteTransaction => amount != null && !isNoise;

  /// 是否为不完整的记账意图（有动作但无金额）
  bool get isIncompleteTransaction => amount == null && !isNoise && _hasAction;

  /// 是否包含记账动作
  bool get _hasAction {
    final actionVerbs = ['花', '买', '吃', '打车', '坐', '付', '给', '收', '转', '消费', '支出'];
    return actionVerbs.any((v) => text.contains(v));
  }

  /// 是否为导航意图
  bool get isNavigation {
    final navKeywords = ['打开', '进入', '去', '跳转', '切换', '看看', '查看'];
    return navKeywords.any((k) => text.contains(k));
  }
}

/// 意图完整性检查结果
class IntentCompleteness {
  /// 是否完整
  final bool isComplete;

  /// 缺失的槽位
  final List<String> missingSlots;

  /// 置信度
  final double confidence;

  const IntentCompleteness({
    required this.isComplete,
    required this.missingSlots,
    required this.confidence,
  });

  /// 检查记账意图的完整性
  factory IntentCompleteness.checkTransaction(SegmentAnalysis segment) {
    final missingSlots = <String>[];

    if (segment.amount == null) {
      missingSlots.add('amount');
    }

    return IntentCompleteness(
      isComplete: missingSlots.isEmpty,
      missingSlots: missingSlots,
      confidence: segment.confidence,
    );
  }
}

/// 多意图处理配置
class MultiIntentConfig {
  /// 是否启用多意图处理
  final bool enabled;

  /// 噪音过滤置信度阈值
  final double noiseThreshold;

  /// 追问模式：true=批量追问，false=逐个追问
  final bool batchFollowUp;

  /// 最大意图数量
  final int maxIntents;

  /// 是否启用 AI 辅助分解
  final bool enableAIDecomposition;

  const MultiIntentConfig({
    this.enabled = true,
    this.noiseThreshold = 0.3,
    this.batchFollowUp = true,
    this.maxIntents = 5,
    this.enableAIDecomposition = false,
  });

  /// 默认配置
  static const MultiIntentConfig defaultConfig = MultiIntentConfig();
}
