import 'dart:convert';

import '../qwen_service.dart';
import 'multi_intent_models.dart';

/// AI辅助意图分解器
///
/// 使用大语言模型（如Qwen）对复杂语句进行意图分解，
/// 适用于规则分句器难以处理的复杂场景。
class AIIntentDecomposer {
  final QwenService _qwenService;

  /// 分解配置
  final AIDecomposerConfig config;

  AIIntentDecomposer({
    QwenService? qwenService,
    this.config = const AIDecomposerConfig(),
  }) : _qwenService = qwenService ?? QwenService();

  /// 意图分解提示词
  static const String _decompositionPrompt = '''
你是一个记账助手的意图分解器。请分析用户的语音输入，将其分解为多个独立的操作意图。

【分解规则】
1. 每个记账意图应包含：金额（必需）、分类（可选）、商家（可选）、时间（可选）
2. 导航意图应包含：目标页面
3. 无关信息应标记为噪音
4. 如果某个意图缺少金额，将其标记为不完整

【输出格式】
返回JSON格式：
{
  "intents": [
    {
      "type": "expense|income|transfer|navigation|noise",
      "text": "原始片段文本",
      "amount": 金额数字或null,
      "category": "分类名称或null",
      "merchant": "商家名称或null",
      "time": "时间描述或null",
      "targetPage": "目标页面或null",
      "isComplete": true或false,
      "confidence": 0.0-1.0的置信度
    }
  ],
  "summary": "简短总结"
}

【分类参考】
- 餐饮：吃饭、午餐、晚餐、咖啡、外卖
- 交通：打车、地铁、公交、加油、停车
- 购物：买东西、超市、网购
- 娱乐：电影、游戏、旅游
- 居住：房租、水电
- 医疗：看病、买药

【页面参考】
- 首页、设置、预算、统计、账户、小金库、分类
''';

  /// 使用AI分解复杂语句
  ///
  /// [input] 用户的语音输入
  ///
  /// Returns 分解后的意图列表，如果AI不可用则返回null
  Future<AIDecompositionResult?> decompose(String input) async {
    if (input.trim().isEmpty) {
      return null;
    }

    try {
      // 构建请求
      final prompt = '$_decompositionPrompt\n\n【用户输入】\n$input';

      // 调用Qwen服务
      final response = await _qwenService.chat(prompt);

      if (response == null || response.isEmpty) {
        return null;
      }

      // 解析JSON响应
      return _parseResponse(response, input);
    } catch (e) {
      // AI分解失败，返回null以使用规则分解器
      return null;
    }
  }

  /// 解析AI响应
  AIDecompositionResult? _parseResponse(String response, String originalInput) {
    try {
      // 提取JSON部分
      final jsonStr = _extractJson(response);
      if (jsonStr == null) {
        return null;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final intentsJson = json['intents'] as List<dynamic>?;

      if (intentsJson == null || intentsJson.isEmpty) {
        return null;
      }

      final intents = <AIIntent>[];

      for (final intentJson in intentsJson) {
        final intent = _parseIntent(intentJson as Map<String, dynamic>);
        if (intent != null) {
          intents.add(intent);
        }
      }

      return AIDecompositionResult(
        intents: intents,
        summary: json['summary'] as String?,
        originalInput: originalInput,
      );
    } catch (e) {
      return null;
    }
  }

  /// 提取JSON字符串
  String? _extractJson(String response) {
    // 尝试找到JSON块
    final jsonStart = response.indexOf('{');
    final jsonEnd = response.lastIndexOf('}');

    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
      return null;
    }

    return response.substring(jsonStart, jsonEnd + 1);
  }

  /// 解析单个意图
  AIIntent? _parseIntent(Map<String, dynamic> json) {
    try {
      final typeStr = json['type'] as String?;
      if (typeStr == null) return null;

      final type = _parseIntentType(typeStr);
      final amount = _parseAmount(json['amount']);

      return AIIntent(
        type: type,
        text: json['text'] as String? ?? '',
        amount: amount,
        category: json['category'] as String?,
        merchant: json['merchant'] as String?,
        time: json['time'] as String?,
        targetPage: json['targetPage'] as String?,
        isComplete: json['isComplete'] as bool? ?? (amount != null),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      );
    } catch (e) {
      return null;
    }
  }

  /// 解析意图类型
  AIIntentType _parseIntentType(String type) {
    switch (type.toLowerCase()) {
      case 'expense':
        return AIIntentType.expense;
      case 'income':
        return AIIntentType.income;
      case 'transfer':
        return AIIntentType.transfer;
      case 'navigation':
        return AIIntentType.navigation;
      case 'noise':
        return AIIntentType.noise;
      default:
        return AIIntentType.unknown;
    }
  }

  /// 解析金额
  double? _parseAmount(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
    }
    return null;
  }

  /// 将AI分解结果转换为MultiIntentResult
  MultiIntentResult? toMultiIntentResult(AIDecompositionResult? aiResult) {
    if (aiResult == null || aiResult.intents.isEmpty) {
      return null;
    }

    final completeIntents = <CompleteIntent>[];
    final incompleteIntents = <IncompleteIntent>[];
    NavigationIntent? navigationIntent;
    final filteredNoise = <String>[];

    for (final aiIntent in aiResult.intents) {
      switch (aiIntent.type) {
        case AIIntentType.expense:
        case AIIntentType.income:
        case AIIntentType.transfer:
          if (aiIntent.isComplete && aiIntent.amount != null) {
            completeIntents.add(CompleteIntent(
              type: _mapToTransactionType(aiIntent.type),
              amount: aiIntent.amount!,
              category: aiIntent.category,
              merchant: aiIntent.merchant,
              description: aiIntent.text,
              originalText: aiIntent.text,
              confidence: aiIntent.confidence,
            ));
          } else {
            incompleteIntents.add(IncompleteIntent(
              type: _mapToTransactionType(aiIntent.type),
              category: aiIntent.category,
              merchant: aiIntent.merchant,
              description: aiIntent.text,
              originalText: aiIntent.text,
              missingSlots: aiIntent.amount == null ? ['amount'] : [],
              confidence: aiIntent.confidence,
            ));
          }
          break;

        case AIIntentType.navigation:
          navigationIntent ??= NavigationIntent(
            targetPage: aiIntent.targetPage ?? 'unknown',
            targetPageName: _getPageDisplayName(aiIntent.targetPage),
            originalText: aiIntent.text,
          );
          break;

        case AIIntentType.noise:
          filteredNoise.add(aiIntent.text);
          break;

        case AIIntentType.unknown:
          // 忽略未知类型
          break;
      }
    }

    return MultiIntentResult(
      completeIntents: completeIntents,
      incompleteIntents: incompleteIntents,
      navigationIntent: navigationIntent,
      filteredNoise: filteredNoise,
      rawInput: aiResult.originalInput,
      segments: aiResult.intents.map((i) => i.text).toList(),
    );
  }

  /// 映射到交易类型
  TransactionIntentType _mapToTransactionType(AIIntentType type) {
    switch (type) {
      case AIIntentType.income:
        return TransactionIntentType.income;
      case AIIntentType.transfer:
        return TransactionIntentType.transfer;
      default:
        return TransactionIntentType.expense;
    }
  }

  /// 获取页面显示名称
  String _getPageDisplayName(String? pageId) {
    const pageNames = {
      'home': '首页',
      'settings': '设置',
      'budget': '预算中心',
      'analysis': '统计分析',
      'accounts': '账户管理',
      'piggy_bank': '小金库',
      'transactions': '交易记录',
      'categories': '分类管理',
    };

    return pageNames[pageId] ?? pageId ?? '未知页面';
  }
}

/// AI分解结果
class AIDecompositionResult {
  /// 分解出的意图列表
  final List<AIIntent> intents;

  /// 简短总结
  final String? summary;

  /// 原始输入
  final String originalInput;

  const AIDecompositionResult({
    required this.intents,
    this.summary,
    required this.originalInput,
  });

  /// 完整意图数量
  int get completeCount => intents.where((i) => i.isComplete).length;

  /// 不完整意图数量
  int get incompleteCount => intents.where((i) => !i.isComplete).length;

  /// 噪音数量
  int get noiseCount =>
      intents.where((i) => i.type == AIIntentType.noise).length;
}

/// AI识别的单个意图
class AIIntent {
  /// 意图类型
  final AIIntentType type;

  /// 原始文本片段
  final String text;

  /// 金额
  final double? amount;

  /// 分类
  final String? category;

  /// 商家
  final String? merchant;

  /// 时间描述
  final String? time;

  /// 目标页面（导航意图）
  final String? targetPage;

  /// 是否完整
  final bool isComplete;

  /// 置信度
  final double confidence;

  const AIIntent({
    required this.type,
    required this.text,
    this.amount,
    this.category,
    this.merchant,
    this.time,
    this.targetPage,
    required this.isComplete,
    required this.confidence,
  });
}

/// AI意图类型
enum AIIntentType {
  expense,
  income,
  transfer,
  navigation,
  noise,
  unknown,
}

/// AI分解器配置
class AIDecomposerConfig {
  /// 是否启用
  final bool enabled;

  /// 超时时间（毫秒）
  final int timeoutMs;

  /// 最大重试次数
  final int maxRetries;

  /// 降级到规则分解的阈值（置信度低于此值）
  final double fallbackThreshold;

  const AIDecomposerConfig({
    this.enabled = true,
    this.timeoutMs = 5000,
    this.maxRetries = 1,
    this.fallbackThreshold = 0.5,
  });
}
