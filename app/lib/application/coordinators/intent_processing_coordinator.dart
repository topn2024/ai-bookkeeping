/// Intent Processing Coordinator
///
/// 负责意图分析和路由的协调器，从VoiceServiceCoordinator中提取。
/// 遵循单一职责原则，仅处理意图识别、分解和路由。
library;

import 'package:flutter/foundation.dart';

/// 意图类型
enum IntentType {
  /// 记账相关
  addTransaction,
  deleteTransaction,
  modifyTransaction,
  queryTransaction,

  /// 导航相关
  navigation,

  /// 查询相关
  queryStatistics,
  queryBudget,
  queryAccount,

  /// 对话相关
  chat,
  greeting,
  farewell,

  /// 自动化
  automation,

  /// 建议
  advice,

  /// 未知
  unknown,
}

/// 意图置信度级别
enum ConfidenceLevel {
  /// 高置信度 (>=0.8)
  high,

  /// 中置信度 (0.5-0.8)
  medium,

  /// 低置信度 (<0.5)
  low,
}

/// 处理后的意图
class ProcessedIntent {
  final IntentType type;
  final double confidence;
  final Map<String, dynamic> entities;
  final String originalText;
  final bool requiresConfirmation;
  final List<ProcessedIntent>? subIntents;

  const ProcessedIntent({
    required this.type,
    required this.confidence,
    required this.entities,
    required this.originalText,
    this.requiresConfirmation = false,
    this.subIntents,
  });

  /// 是否为多意图
  bool get isMultiIntent => subIntents != null && subIntents!.isNotEmpty;

  /// 置信度级别
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.8) return ConfidenceLevel.high;
    if (confidence >= 0.5) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  /// 获取实体值
  T? getEntity<T>(String key) {
    final value = entities[key];
    if (value is T) return value;
    return null;
  }

  ProcessedIntent copyWith({
    IntentType? type,
    double? confidence,
    Map<String, dynamic>? entities,
    String? originalText,
    bool? requiresConfirmation,
    List<ProcessedIntent>? subIntents,
  }) {
    return ProcessedIntent(
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      entities: entities ?? this.entities,
      originalText: originalText ?? this.originalText,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      subIntents: subIntents ?? this.subIntents,
    );
  }
}

/// 意图处理结果
class IntentProcessingResult {
  final bool success;
  final ProcessedIntent? intent;
  final String? errorMessage;
  final bool needsDisambiguation;
  final List<DisambiguationOption>? disambiguationOptions;

  const IntentProcessingResult._({
    required this.success,
    this.intent,
    this.errorMessage,
    this.needsDisambiguation = false,
    this.disambiguationOptions,
  });

  factory IntentProcessingResult.success(ProcessedIntent intent) {
    return IntentProcessingResult._(
      success: true,
      intent: intent,
    );
  }

  factory IntentProcessingResult.failure(String message) {
    return IntentProcessingResult._(
      success: false,
      errorMessage: message,
    );
  }

  factory IntentProcessingResult.needsDisambiguation(
    List<DisambiguationOption> options,
  ) {
    return IntentProcessingResult._(
      success: false,
      needsDisambiguation: true,
      disambiguationOptions: options,
    );
  }
}

/// 消歧选项
class DisambiguationOption {
  final String id;
  final String label;
  final String description;
  final ProcessedIntent intent;

  const DisambiguationOption({
    required this.id,
    required this.label,
    required this.description,
    required this.intent,
  });
}

/// 意图处理协调器
///
/// 职责：
/// - 解析用户输入识别意图
/// - 分解复合意图为多个子意图
/// - 处理意图消歧
/// - 路由意图到对应处理器
class IntentProcessingCoordinator {
  /// 意图识别器接口
  final IIntentRecognizer _recognizer;

  /// 意图分解器接口
  final IIntentDecomposer? _decomposer;

  /// 实体消歧服务接口
  final IEntityDisambiguationService? _disambiguationService;

  /// 多意图处理配置
  final MultiIntentConfig _config;

  IntentProcessingCoordinator({
    required IIntentRecognizer recognizer,
    IIntentDecomposer? decomposer,
    IEntityDisambiguationService? disambiguationService,
    MultiIntentConfig? config,
  })  : _recognizer = recognizer,
        _decomposer = decomposer,
        _disambiguationService = disambiguationService,
        _config = config ?? MultiIntentConfig.defaultConfig;

  /// 处理用户输入
  ///
  /// 1. 识别基础意图
  /// 2. 尝试分解多意图
  /// 3. 处理实体消歧
  Future<IntentProcessingResult> process(String input) async {
    if (input.trim().isEmpty) {
      return IntentProcessingResult.failure('输入为空');
    }

    debugPrint('[IntentProcessingCoordinator] 处理输入: "$input"');

    try {
      // 1. 基础意图识别
      final baseIntent = await _recognizer.recognize(input);
      debugPrint(
          '[IntentProcessingCoordinator] 基础意图: ${baseIntent.type} (confidence: ${baseIntent.confidence})');

      // 2. 检查是否需要分解多意图
      ProcessedIntent finalIntent = baseIntent;
      if (_decomposer != null && _config.enableMultiIntent) {
        final decomposed = await _tryDecomposeIntent(input, baseIntent);
        if (decomposed != null) {
          finalIntent = decomposed;
          debugPrint(
              '[IntentProcessingCoordinator] 多意图分解: ${decomposed.subIntents?.length ?? 0} 个子意图');
        }
      }

      // 3. 检查是否需要实体消歧
      if (_disambiguationService != null) {
        final disambiguationResult =
            await _checkDisambiguation(finalIntent);
        if (disambiguationResult != null) {
          return disambiguationResult;
        }
      }

      // 4. 检查置信度是否足够
      if (finalIntent.confidence < _config.minConfidence) {
        debugPrint(
            '[IntentProcessingCoordinator] 置信度过低: ${finalIntent.confidence}');
        return IntentProcessingResult.failure(
          '无法确定您的意图，请重新描述',
        );
      }

      return IntentProcessingResult.success(finalIntent);
    } catch (e) {
      debugPrint('[IntentProcessingCoordinator] 处理失败: $e');
      return IntentProcessingResult.failure('意图处理失败: $e');
    }
  }

  /// 尝试分解多意图
  Future<ProcessedIntent?> _tryDecomposeIntent(
    String input,
    ProcessedIntent baseIntent,
  ) async {
    if (_decomposer == null) return null;

    // 检查是否可能包含多意图的关键词
    final hasMultiIntentIndicators = _containsMultiIntentIndicators(input);
    if (!hasMultiIntentIndicators) return null;

    try {
      final subIntents = await _decomposer!.decompose(input);
      if (subIntents.length > 1) {
        return baseIntent.copyWith(
          subIntents: subIntents,
          requiresConfirmation: _config.requireConfirmation,
        );
      }
    } catch (e) {
      debugPrint('[IntentProcessingCoordinator] 意图分解失败: $e');
    }

    return null;
  }

  /// 检查是否包含多意图指示词
  bool _containsMultiIntentIndicators(String input) {
    const indicators = [
      '还有',
      '另外',
      '以及',
      '和',
      '再',
      '又',
      '同时',
      '顺便',
    ];

    for (final indicator in indicators) {
      if (input.contains(indicator)) {
        return true;
      }
    }

    return false;
  }

  /// 检查是否需要实体消歧
  Future<IntentProcessingResult?> _checkDisambiguation(
    ProcessedIntent intent,
  ) async {
    if (_disambiguationService == null) return null;

    final ambiguousEntities =
        await _disambiguationService!.findAmbiguousEntities(intent.entities);

    if (ambiguousEntities.isEmpty) return null;

    final options = <DisambiguationOption>[];
    for (final entity in ambiguousEntities) {
      for (final candidate in entity.candidates) {
        options.add(DisambiguationOption(
          id: candidate.id,
          label: candidate.label,
          description: candidate.description,
          intent: intent.copyWith(
            entities: {
              ...intent.entities,
              entity.key: candidate.value,
            },
          ),
        ));
      }
    }

    return IntentProcessingResult.needsDisambiguation(options);
  }

  /// 解析消歧选择
  ProcessedIntent resolveDisambiguation(
    ProcessedIntent originalIntent,
    DisambiguationOption selectedOption,
  ) {
    return selectedOption.intent;
  }

  /// 验证意图是否完整
  bool isIntentComplete(ProcessedIntent intent) {
    switch (intent.type) {
      case IntentType.addTransaction:
        // 记账意图需要金额和分类
        return intent.entities.containsKey('amount') &&
            intent.entities.containsKey('category');

      case IntentType.deleteTransaction:
      case IntentType.modifyTransaction:
        // 删除/修改需要交易引用
        return intent.entities.containsKey('transactionId') ||
            intent.entities.containsKey('transactionRef');

      case IntentType.navigation:
        // 导航需要目标
        return intent.entities.containsKey('target');

      case IntentType.queryStatistics:
      case IntentType.queryBudget:
      case IntentType.queryAccount:
        // 查询可以无参数
        return true;

      case IntentType.chat:
      case IntentType.greeting:
      case IntentType.farewell:
        return true;

      default:
        return true;
    }
  }

  /// 获取意图缺失的必要实体
  List<String> getMissingEntities(ProcessedIntent intent) {
    final missing = <String>[];

    switch (intent.type) {
      case IntentType.addTransaction:
        if (!intent.entities.containsKey('amount')) {
          missing.add('amount');
        }
        if (!intent.entities.containsKey('category')) {
          missing.add('category');
        }
        break;

      case IntentType.deleteTransaction:
      case IntentType.modifyTransaction:
        if (!intent.entities.containsKey('transactionId') &&
            !intent.entities.containsKey('transactionRef')) {
          missing.add('transactionRef');
        }
        break;

      case IntentType.navigation:
        if (!intent.entities.containsKey('target')) {
          missing.add('target');
        }
        break;

      default:
        break;
    }

    return missing;
  }
}

/// 多意图处理配置
class MultiIntentConfig {
  /// 是否启用多意图识别
  final bool enableMultiIntent;

  /// 最小置信度阈值
  final double minConfidence;

  /// 是否需要用户确认
  final bool requireConfirmation;

  /// 最大子意图数量
  final int maxSubIntents;

  const MultiIntentConfig({
    this.enableMultiIntent = true,
    this.minConfidence = 0.5,
    this.requireConfirmation = true,
    this.maxSubIntents = 5,
  });

  static const defaultConfig = MultiIntentConfig();
}

/// 意图识别器接口
abstract class IIntentRecognizer {
  /// 识别意图
  Future<ProcessedIntent> recognize(String input);
}

/// 意图分解器接口
abstract class IIntentDecomposer {
  /// 分解复合意图
  Future<List<ProcessedIntent>> decompose(String input);
}

/// 实体消歧服务接口
abstract class IEntityDisambiguationService {
  /// 查找歧义实体
  Future<List<AmbiguousEntity>> findAmbiguousEntities(
    Map<String, dynamic> entities,
  );
}

/// 歧义实体
class AmbiguousEntity {
  final String key;
  final List<EntityCandidate> candidates;

  const AmbiguousEntity({
    required this.key,
    required this.candidates,
  });
}

/// 实体候选项
class EntityCandidate {
  final String id;
  final String label;
  final String description;
  final dynamic value;

  const EntityCandidate({
    required this.id,
    required this.label,
    required this.description,
    required this.value,
  });
}

/// 意图到命令的转换器
///
/// 将 ProcessedIntent 转换为操作数据，可用于 CommandFactory
class IntentToCommandConverter {
  /// 将 ProcessedIntent 转换为操作数据
  ///
  /// 返回的 Map 可直接传给 CommandFactory.createFromOperation()
  static Map<String, dynamic>? toOperationData(ProcessedIntent intent) {
    switch (intent.type) {
      case IntentType.addTransaction:
        return {
          'type': 'add_transaction',
          'params': {
            'amount': intent.getEntity<num>('amount'),
            'category': intent.getEntity<String>('category'),
            'type': intent.getEntity<String>('type') ?? 'expense',
            'note': intent.getEntity<String>('note'),
            'merchant': intent.getEntity<String>('merchant'),
            'accountId': intent.getEntity<String>('accountId'),
          },
          'priority': 'deferred',
        };

      case IntentType.deleteTransaction:
        return {
          'type': 'delete',
          'params': {
            'transactionId': intent.getEntity<String>('transactionId') ??
                intent.getEntity<String>('transactionRef'),
            'softDelete': true,
          },
          'priority': 'normal',
        };

      case IntentType.modifyTransaction:
        return {
          'type': 'modify',
          'params': {
            'transactionId': intent.getEntity<String>('transactionId') ??
                intent.getEntity<String>('transactionRef'),
            'amount': intent.getEntity<num>('newAmount'),
            'category': intent.getEntity<String>('newCategory'),
            'note': intent.getEntity<String>('newNote'),
          },
          'priority': 'normal',
        };

      case IntentType.navigation:
        return {
          'type': 'navigate',
          'params': {
            'targetPage': intent.getEntity<String>('target'),
            'route': intent.getEntity<String>('route'),
            'category': intent.getEntity<String>('category'),
            'timeRange': intent.getEntity<String>('timeRange'),
          },
          'priority': 'immediate',
        };

      case IntentType.queryTransaction:
      case IntentType.queryStatistics:
        return {
          'type': 'query',
          'params': {
            'queryType': intent.getEntity<String>('queryType') ?? 'summary',
            'time': intent.getEntity<String>('time') ?? '本月',
            'category': intent.getEntity<String>('category'),
            'transactionType': intent.getEntity<String>('transactionType'),
            'groupBy': intent.getEntity<String>('groupBy'),
            'limit': intent.getEntity<int>('limit'),
          },
          'priority': 'normal',
        };

      case IntentType.chat:
      case IntentType.greeting:
      case IntentType.farewell:
        // 聊天类意图不需要转换为命令
        return null;

      default:
        return null;
    }
  }

  /// 将多个子意图转换为操作数据列表
  static List<Map<String, dynamic>> toOperationDataList(ProcessedIntent intent) {
    final operations = <Map<String, dynamic>>[];

    if (intent.isMultiIntent && intent.subIntents != null) {
      for (final subIntent in intent.subIntents!) {
        final op = toOperationData(subIntent);
        if (op != null) {
          operations.add(op);
        }
      }
    } else {
      final op = toOperationData(intent);
      if (op != null) {
        operations.add(op);
      }
    }

    return operations;
  }

  /// 检查意图是否可以转换为命令
  static bool canConvert(ProcessedIntent intent) {
    switch (intent.type) {
      case IntentType.addTransaction:
      case IntentType.deleteTransaction:
      case IntentType.modifyTransaction:
      case IntentType.navigation:
      case IntentType.queryTransaction:
      case IntentType.queryStatistics:
        return true;
      default:
        return false;
    }
  }
}
