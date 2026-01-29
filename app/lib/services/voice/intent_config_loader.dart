/// Intent Config Loader
///
/// 负责加载意图识别配置文件的服务。
/// 从 assets/config 目录加载 YAML 配置文件。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// 意图识别配置
class IntentRecognitionConfig {
  /// 支出分类关键词映射
  final Map<String, List<String>> expenseCategories;

  /// 收入分类关键词映射
  final Map<String, List<String>> incomeCategories;

  /// 商户映射规则
  final Map<String, dynamic> merchantRules;

  /// 备注规范化规则
  final Map<String, List<String>> noteNormalization;

  /// 停顿词
  final List<String> fillerWords;

  /// 查询类型定义
  final Map<String, dynamic> queryTypes;

  /// 时间关键词映射
  final Map<String, List<String>> timeKeywords;

  /// LLM 配置
  final LLMConfig llmConfig;

  /// 页面路由映射
  final Map<String, String> pageRoutes;

  const IntentRecognitionConfig({
    required this.expenseCategories,
    required this.incomeCategories,
    required this.merchantRules,
    required this.noteNormalization,
    required this.fillerWords,
    required this.queryTypes,
    required this.timeKeywords,
    required this.llmConfig,
    required this.pageRoutes,
  });

  /// 默认配置
  static const defaultConfig = IntentRecognitionConfig(
    expenseCategories: {},
    incomeCategories: {},
    merchantRules: {},
    noteNormalization: {},
    fillerWords: [],
    queryTypes: {},
    timeKeywords: {},
    llmConfig: LLMConfig.defaultConfig,
    pageRoutes: {},
  );

  /// 根据关键词查找支出分类
  String? findExpenseCategory(String keyword) {
    for (final entry in expenseCategories.entries) {
      if (entry.value.any((k) => keyword.contains(k))) {
        return entry.key;
      }
    }
    return null;
  }

  /// 根据关键词查找收入分类
  String? findIncomeCategory(String keyword) {
    for (final entry in incomeCategories.entries) {
      if (entry.value.any((k) => keyword.contains(k))) {
        return entry.key;
      }
    }
    return null;
  }

  /// 规范化备注
  String normalizeNote(String note) {
    for (final entry in noteNormalization.entries) {
      for (final pattern in entry.value) {
        if (note.contains(pattern)) {
          return note.replaceAll(pattern, entry.key);
        }
      }
    }
    return note;
  }

  /// 移除停顿词
  String removeFillerWords(String text) {
    var result = text;
    for (final filler in fillerWords) {
      result = result.replaceAll(filler, '');
    }
    return result.trim();
  }
}

/// LLM 配置
class LLMConfig {
  final int timeoutMs;
  final double minConfidenceForLearning;
  final double minConfidenceForDirectUse;
  final int progressiveFeedbackDelayMs;
  final String progressiveFeedbackMessage;

  const LLMConfig({
    required this.timeoutMs,
    required this.minConfidenceForLearning,
    required this.minConfidenceForDirectUse,
    required this.progressiveFeedbackDelayMs,
    required this.progressiveFeedbackMessage,
  });

  static const defaultConfig = LLMConfig(
    timeoutMs: 5000,
    minConfidenceForLearning: 0.85,
    minConfidenceForDirectUse: 0.7,
    progressiveFeedbackDelayMs: 2000,
    progressiveFeedbackMessage: '正在思考...',
  );
}

/// Prompt 模板配置
class PromptTemplateConfig {
  final String systemRole;
  final String coreRules;
  final String resultTypes;
  final String operationTypes;
  final String queryTypeDocs;
  final String parameterDocs;
  final String categories;

  const PromptTemplateConfig({
    required this.systemRole,
    required this.coreRules,
    required this.resultTypes,
    required this.operationTypes,
    required this.queryTypeDocs,
    required this.parameterDocs,
    required this.categories,
  });

  static const defaultConfig = PromptTemplateConfig(
    systemRole: '你是一个记账助手，请理解用户输入并返回JSON。',
    coreRules: '',
    resultTypes: '',
    operationTypes: '',
    queryTypeDocs: '',
    parameterDocs: '',
    categories: '',
  );
}

/// 示例配置
class ExamplesConfig {
  final List<IntentExample> addTransactionBasic;
  final List<IntentExample> addTransactionSemantic;
  final List<IntentExample> addTransactionMultiple;
  final List<IntentExample> addTransactionTransport;
  final List<IntentExample> addTransactionIncome;
  final List<IntentExample> clarifyExamples;
  final List<IntentExample> queryExamples;
  final List<IntentExample> navigateExamples;
  final List<IntentExample> chatExamples;

  const ExamplesConfig({
    required this.addTransactionBasic,
    required this.addTransactionSemantic,
    required this.addTransactionMultiple,
    required this.addTransactionTransport,
    required this.addTransactionIncome,
    required this.clarifyExamples,
    required this.queryExamples,
    required this.navigateExamples,
    required this.chatExamples,
  });

  /// 获取所有示例
  List<IntentExample> get allExamples => [
        ...addTransactionBasic,
        ...addTransactionSemantic,
        ...addTransactionMultiple,
        ...addTransactionTransport,
        ...addTransactionIncome,
        ...clarifyExamples,
        ...queryExamples,
        ...navigateExamples,
        ...chatExamples,
      ];

  static const defaultConfig = ExamplesConfig(
    addTransactionBasic: [],
    addTransactionSemantic: [],
    addTransactionMultiple: [],
    addTransactionTransport: [],
    addTransactionIncome: [],
    clarifyExamples: [],
    queryExamples: [],
    navigateExamples: [],
    chatExamples: [],
  );
}

/// 意图示例
class IntentExample {
  final String input;
  final Map<String, dynamic> output;

  const IntentExample({
    required this.input,
    required this.output,
  });

  /// 生成示例字符串（用于 Prompt）
  String toPromptString() {
    return '输入："$input"\n输出：${jsonEncode(output)}';
  }
}

/// 意图配置加载器
class IntentConfigLoader {
  static IntentConfigLoader? _instance;
  static IntentConfigLoader get instance => _instance ??= IntentConfigLoader._();

  IntentConfigLoader._();

  IntentRecognitionConfig? _config;
  PromptTemplateConfig? _promptTemplate;
  ExamplesConfig? _examples;

  bool _isLoaded = false;

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 获取配置
  IntentRecognitionConfig get config => _config ?? IntentRecognitionConfig.defaultConfig;

  /// 获取 Prompt 模板
  PromptTemplateConfig get promptTemplate => _promptTemplate ?? PromptTemplateConfig.defaultConfig;

  /// 获取示例
  ExamplesConfig get examples => _examples ?? ExamplesConfig.defaultConfig;

  /// 加载所有配置
  Future<void> loadAll() async {
    if (_isLoaded) return;

    try {
      await Future.wait([
        _loadConfig(),
        _loadPromptTemplate(),
        _loadExamples(),
      ]);
      _isLoaded = true;
      debugPrint('[IntentConfigLoader] 配置加载完成');
    } catch (e) {
      debugPrint('[IntentConfigLoader] 配置加载失败: $e');
      // 使用默认配置
      _config = IntentRecognitionConfig.defaultConfig;
      _promptTemplate = PromptTemplateConfig.defaultConfig;
      _examples = ExamplesConfig.defaultConfig;
    }
  }

  /// 加载主配置
  Future<void> _loadConfig() async {
    try {
      final yamlString = await rootBundle.loadString(
        'assets/config/intent_recognition_config.yaml',
      );
      final yaml = loadYaml(yamlString) as YamlMap;

      _config = IntentRecognitionConfig(
        expenseCategories: _parseStringListMap(yaml['expense_categories']),
        incomeCategories: _parseStringListMap(yaml['income_categories']),
        merchantRules: _yamlMapToMap(yaml['merchant_rules']),
        noteNormalization: _parseStringListMap(yaml['note_normalization']),
        fillerWords: _parseStringList(yaml['filler_words']),
        queryTypes: _yamlMapToMap(yaml['query_types']),
        timeKeywords: _parseStringListMap(yaml['time_keywords']),
        llmConfig: _parseLLMConfig(yaml['llm_config']),
        pageRoutes: _parseStringMap(yaml['page_routes']),
      );
    } catch (e) {
      debugPrint('[IntentConfigLoader] 加载主配置失败: $e');
      rethrow;
    }
  }

  /// 加载 Prompt 模板
  Future<void> _loadPromptTemplate() async {
    try {
      final yamlString = await rootBundle.loadString(
        'assets/config/intent_prompt_template.yaml',
      );
      final yaml = loadYaml(yamlString) as YamlMap;

      _promptTemplate = PromptTemplateConfig(
        systemRole: yaml['system_role'] as String? ?? '',
        coreRules: yaml['core_rules'] as String? ?? '',
        resultTypes: yaml['result_types'] as String? ?? '',
        operationTypes: yaml['operation_types'] as String? ?? '',
        queryTypeDocs: yaml['query_type_docs'] as String? ?? '',
        parameterDocs: yaml['parameter_docs'] as String? ?? '',
        categories: yaml['categories'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[IntentConfigLoader] 加载 Prompt 模板失败: $e');
      rethrow;
    }
  }

  /// 加载示例
  Future<void> _loadExamples() async {
    try {
      final yamlString = await rootBundle.loadString(
        'assets/config/intent_examples.yaml',
      );
      final yaml = loadYaml(yamlString) as YamlMap;

      _examples = ExamplesConfig(
        addTransactionBasic: _parseExamples(yaml['add_transaction_basic']),
        addTransactionSemantic: _parseExamples(yaml['add_transaction_semantic']),
        addTransactionMultiple: _parseExamples(yaml['add_transaction_multiple']),
        addTransactionTransport: _parseExamples(yaml['add_transaction_transport']),
        addTransactionIncome: _parseExamples(yaml['add_transaction_income']),
        clarifyExamples: _parseExamples(yaml['clarify_examples']),
        queryExamples: _parseExamples(yaml['query_examples']),
        navigateExamples: _parseExamples(yaml['navigate_examples']),
        chatExamples: _parseExamples(yaml['chat_examples']),
      );
    } catch (e) {
      debugPrint('[IntentConfigLoader] 加载示例失败: $e');
      rethrow;
    }
  }

  /// 构建完整的 Prompt
  String buildPrompt({
    required String input,
    String? pageContext,
    String? historyContext,
    String? pageList,
    String cityName = '深圳',
  }) {
    final template = promptTemplate;
    final config = this.config;

    final buffer = StringBuffer();

    // 系统角色
    buffer.writeln(template.systemRole);

    // 对话历史
    if (historyContext != null && historyContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('【对话历史 - 用于理解上下文和关联交易】');
      buffer.writeln(historyContext);
    }

    // 核心规则
    buffer.writeln();
    buffer.writeln(template.coreRules);

    // 分类关键词映射
    buffer.writeln();
    buffer.writeln('2. 【重要】支出分类关键词映射（type="expense"，默认）：');
    for (final entry in config.expenseCategories.entries) {
      buffer.writeln('   - ${entry.key}：${entry.value.join('、')}');
    }

    buffer.writeln();
    buffer.writeln('3. 【重要】收入分类关键词映射（type="income"）：');
    for (final entry in config.incomeCategories.entries) {
      buffer.writeln('   - ${entry.key}：${entry.value.join('、')}');
    }

    // 用户输入和页面上下文
    buffer.writeln();
    buffer.writeln('【用户输入】$input');
    buffer.writeln('【页面上下文】${pageContext ?? '首页'}');

    // 结果类型和操作类型
    buffer.writeln();
    buffer.writeln(template.resultTypes);
    buffer.writeln();
    buffer.writeln(template.operationTypes);
    buffer.writeln();
    buffer.writeln(template.queryTypeDocs);

    // 参数说明（替换城市变量）
    buffer.writeln();
    buffer.writeln(template.parameterDocs.replaceAll('{city_name}', cityName));

    // 分类列表
    buffer.writeln();
    buffer.writeln(template.categories);

    // 页面列表
    if (pageList != null && pageList.isNotEmpty) {
      buffer.writeln('【常用页面】$pageList');
    }

    // 示例
    buffer.writeln();
    buffer.writeln('【示例】');
    for (final example in examples.allExamples.take(20)) {
      buffer.writeln(example.toPromptString().replaceAll('{city_name}', cityName));
      buffer.writeln();
    }

    buffer.writeln('只返回JSON：');

    return buffer.toString();
  }

  // ==================== 解析辅助方法 ====================

  Map<String, List<String>> _parseStringListMap(dynamic yaml) {
    if (yaml == null) return {};
    final map = <String, List<String>>{};
    if (yaml is YamlMap) {
      for (final entry in yaml.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is YamlList) {
          map[key] = value.map((e) => e.toString()).toList();
        }
      }
    }
    return map;
  }

  Map<String, String> _parseStringMap(dynamic yaml) {
    if (yaml == null) return {};
    final map = <String, String>{};
    if (yaml is YamlMap) {
      for (final entry in yaml.entries) {
        map[entry.key.toString()] = entry.value.toString();
      }
    }
    return map;
  }

  List<String> _parseStringList(dynamic yaml) {
    if (yaml == null) return [];
    if (yaml is YamlList) {
      return yaml.map((e) => e.toString()).toList();
    }
    return [];
  }

  Map<String, dynamic> _yamlMapToMap(dynamic yaml) {
    if (yaml == null) return {};
    if (yaml is YamlMap) {
      return _convertYamlMap(yaml);
    }
    return {};
  }

  Map<String, dynamic> _convertYamlMap(YamlMap yaml) {
    final map = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is YamlMap) {
        map[key] = _convertYamlMap(value);
      } else if (value is YamlList) {
        map[key] = _convertYamlList(value);
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  List<dynamic> _convertYamlList(YamlList yaml) {
    return yaml.map((e) {
      if (e is YamlMap) {
        return _convertYamlMap(e);
      } else if (e is YamlList) {
        return _convertYamlList(e);
      } else {
        return e;
      }
    }).toList();
  }

  LLMConfig _parseLLMConfig(dynamic yaml) {
    if (yaml == null) return LLMConfig.defaultConfig;
    if (yaml is YamlMap) {
      return LLMConfig(
        timeoutMs: yaml['timeout_ms'] as int? ?? 5000,
        minConfidenceForLearning:
            (yaml['min_confidence_for_learning'] as num?)?.toDouble() ?? 0.85,
        minConfidenceForDirectUse:
            (yaml['min_confidence_for_direct_use'] as num?)?.toDouble() ?? 0.7,
        progressiveFeedbackDelayMs:
            yaml['progressive_feedback_delay_ms'] as int? ?? 2000,
        progressiveFeedbackMessage:
            yaml['progressive_feedback_message'] as String? ?? '正在思考...',
      );
    }
    return LLMConfig.defaultConfig;
  }

  List<IntentExample> _parseExamples(dynamic yaml) {
    if (yaml == null) return [];
    if (yaml is YamlList) {
      return yaml.map((e) {
        if (e is YamlMap) {
          return IntentExample(
            input: e['input'] as String? ?? '',
            output: _yamlMapToMap(e['output']),
          );
        }
        return const IntentExample(input: '', output: {});
      }).toList();
    }
    return [];
  }
}
