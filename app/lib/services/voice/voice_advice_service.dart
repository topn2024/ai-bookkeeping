/// 语音建议服务
///
/// 职责：
/// - 统一管理所有建议生成逻辑
/// - 复用现有建议服务（AdviceService、ActionableInsightService等）
/// - 将建议内容转换为语音友好的格式
///
/// 架构设计：
/// - 策略模式：不同建议类型使用不同的生成策略
/// - 适配器模式：适配现有服务输出为语音格式
/// - 依赖注入：便于测试和扩展
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/contracts/i_database_service.dart';
import '../../models/transaction.dart';
import 'llm_response_generator.dart';

/// 建议类型
enum AdviceCategory {
  insight,   // 消费洞察
  budget,    // 预算建议
  saving,    // 储蓄建议
  feature,   // 功能推荐
  spending,  // 消费分析
  general,   // 通用建议
}

/// 建议结果
class VoiceAdviceResult {
  /// 建议类型
  final AdviceCategory category;

  /// 语音播报文本
  final String spokenText;

  /// 结构化数据（可选，用于UI展示）
  final Map<String, dynamic>? data;

  /// 是否来自 LLM
  final bool isLLMGenerated;

  const VoiceAdviceResult({
    required this.category,
    required this.spokenText,
    this.data,
    this.isLLMGenerated = false,
  });
}

/// 建议生成策略接口
abstract class AdviceStrategy {
  /// 策略名称
  String get name;

  /// 支持的建议类型
  AdviceCategory get category;

  /// 生成建议
  Future<VoiceAdviceResult> generate({
    required String userInput,
    Map<String, dynamic>? context,
  });
}

/// 语音建议服务
///
/// 统一入口，协调各个建议生成策略
class VoiceAdviceService {
  final IDatabaseService _databaseService;
  final Map<AdviceCategory, AdviceStrategy> _strategies = {};

  VoiceAdviceService({
    required IDatabaseService databaseService,
  }) : _databaseService = databaseService {
    _registerDefaultStrategies();
  }

  /// 注册默认策略
  void _registerDefaultStrategies() {
    registerStrategy(InsightAdviceStrategy(_databaseService));
    registerStrategy(BudgetAdviceStrategy());
    registerStrategy(SavingAdviceStrategy());
    registerStrategy(FeatureAdviceStrategy());
    registerStrategy(SpendingAdviceStrategy());
    registerStrategy(GeneralAdviceStrategy());
  }

  /// 注册策略
  void registerStrategy(AdviceStrategy strategy) {
    _strategies[strategy.category] = strategy;
  }

  /// 根据用户输入生成建议
  Future<VoiceAdviceResult> generateAdvice(String userInput) async {
    final category = classifyAdviceType(userInput);
    return generateAdviceByCategory(category, userInput);
  }

  /// 根据类型生成建议
  Future<VoiceAdviceResult> generateAdviceByCategory(
    AdviceCategory category,
    String userInput,
  ) async {
    final strategy = _strategies[category];
    if (strategy == null) {
      return _getFallbackAdvice(category);
    }

    try {
      return await strategy.generate(userInput: userInput);
    } catch (e) {
      debugPrint('[VoiceAdviceService] 生成建议失败: $e');
      return _getFallbackAdvice(category);
    }
  }

  /// 分类建议类型
  AdviceCategory classifyAdviceType(String input) {
    // 洞察分析
    if (RegExp(r'洞察|趋势|报告|哪里.*多|什么.*多|花.*多').hasMatch(input)) {
      return AdviceCategory.insight;
    }
    // 预算建议
    if (RegExp(r'预算|怎么设|设置.*预算|预算.*建议').hasMatch(input)) {
      return AdviceCategory.budget;
    }
    // 储蓄建议
    if (RegExp(r'存钱|储蓄|存.*多|怎么存|存款').hasMatch(input)) {
      return AdviceCategory.saving;
    }
    // 功能推荐
    if (RegExp(r'功能|推荐.*功能|什么功能|用什么').hasMatch(input)) {
      return AdviceCategory.feature;
    }
    // 消费分析
    if (RegExp(r'消费|支出|花费|省钱|省|优化|减少|分析').hasMatch(input)) {
      return AdviceCategory.spending;
    }
    return AdviceCategory.general;
  }

  /// 兜底建议
  VoiceAdviceResult _getFallbackAdvice(AdviceCategory category) {
    return VoiceAdviceResult(
      category: category,
      spokenText: '让我想想...您可以尝试设置预算来控制支出，或者查看消费分析了解自己的消费习惯。',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 具体策略实现
// ═══════════════════════════════════════════════════════════════

/// 消费洞察策略
class InsightAdviceStrategy implements AdviceStrategy {
  final IDatabaseService _databaseService;

  InsightAdviceStrategy(this._databaseService);

  @override
  String get name => '消费洞察';

  @override
  AdviceCategory get category => AdviceCategory.insight;

  @override
  Future<VoiceAdviceResult> generate({
    required String userInput,
    Map<String, dynamic>? context,
  }) async {
    // 添加超时控制，防止数据库查询阻塞
    List<Transaction> transactions;
    try {
      transactions = await _databaseService.getTransactions()
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[InsightAdviceStrategy] 数据库查询超时');
      return VoiceAdviceResult(
        category: category,
        spokenText: '数据加载较慢，请稍后再试。',
      );
    } catch (e) {
      debugPrint('[InsightAdviceStrategy] 数据库查询失败: $e');
      return VoiceAdviceResult(
        category: category,
        spokenText: '获取数据失败，请稍后再试。',
      );
    }

    final now = DateTime.now();
    final thisMonth = transactions.where((t) =>
        t.date.year == now.year && t.date.month == now.month).toList();

    if (thisMonth.isEmpty) {
      return VoiceAdviceResult(
        category: category,
        spokenText: '本月还没有消费记录，开始记账后我可以帮您分析消费习惯。',
      );
    }

    // 按分类统计支出
    final categorySpending = <String, double>{};
    for (final t in thisMonth) {
      if (t.type == TransactionType.expense) {
        categorySpending[t.category] = (categorySpending[t.category] ?? 0) + t.amount;
      }
    }

    if (categorySpending.isEmpty) {
      return VoiceAdviceResult(
        category: category,
        spokenText: '本月支出记录较少，继续记录后我能给出更准确的分析。',
      );
    }

    // 找出花费最多的分类
    final sorted = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final total = categorySpending.values.reduce((a, b) => a + b);
    final percentage = (top.value / total * 100).toStringAsFixed(0);

    return VoiceAdviceResult(
      category: category,
      spokenText: '本月您在${top.key}上花费最多，共${top.value.toStringAsFixed(0)}元，'
          '占总支出的$percentage%。建议关注这个分类的支出。',
      data: {
        'topCategory': top.key,
        'amount': top.value,
        'percentage': percentage,
        'totalExpense': total,
      },
    );
  }
}

/// 预算建议策略
class BudgetAdviceStrategy implements AdviceStrategy {
  static const _tips = [
    '建议按"50-30-20"法则分配预算：50%用于必需支出，30%用于个人需求，20%用于储蓄。',
    '设置预算时，先从大类开始，比如餐饮、交通、娱乐，每月初根据实际情况调整。',
    '建议总预算控制在月收入的70%以内，留出30%用于储蓄和应急。',
    '刚开始设置预算可以先宽松一些，逐步收紧，避免过于严格导致难以坚持。',
    '建议为每个主要分类设置独立预算，这样更容易追踪和控制支出。',
  ];

  @override
  String get name => '预算建议';

  @override
  AdviceCategory get category => AdviceCategory.budget;

  @override
  Future<VoiceAdviceResult> generate({
    required String userInput,
    Map<String, dynamic>? context,
  }) async {
    final tip = _tips[DateTime.now().millisecond % _tips.length];
    return VoiceAdviceResult(
      category: category,
      spokenText: tip,
    );
  }
}

/// 储蓄建议策略
class SavingAdviceStrategy implements AdviceStrategy {
  static const _tips = [
    '建议采用"先存后花"的策略，每月工资到账后先转一部分到储蓄账户。',
    '可以设置自动转账，每月固定存入一定金额，养成存钱习惯。',
    '尝试"52周存钱法"：第一周存10元，第二周存20元，依次递增。',
    '设立具体的储蓄目标，比如旅游基金、应急基金，有目标更容易坚持。',
    '检查固定支出，看看有没有可以取消的订阅或会员服务。',
    '建议建立3-6个月生活费的应急基金，作为财务安全垫。',
  ];

  @override
  String get name => '储蓄建议';

  @override
  AdviceCategory get category => AdviceCategory.saving;

  @override
  Future<VoiceAdviceResult> generate({
    required String userInput,
    Map<String, dynamic>? context,
  }) async {
    final tip = _tips[DateTime.now().millisecond % _tips.length];
    return VoiceAdviceResult(
      category: category,
      spokenText: tip,
    );
  }
}

/// 功能推荐策略
class FeatureAdviceStrategy implements AdviceStrategy {
  static const _features = [
    '推荐您试试「预算管理」功能，可以帮您控制每月支出，避免超支。',
    '「消费分析」功能可以帮您了解钱都花在哪里，发现省钱机会。',
    '试试「语音记账」功能，说一句话就能记账，方便又快捷。',
    '「定时提醒」功能可以提醒您每天记账，养成好习惯。',
    '「账单导入」功能可以自动同步支付宝、微信账单，省去手动录入。',
  ];

  @override
  String get name => '功能推荐';

  @override
  AdviceCategory get category => AdviceCategory.feature;

  @override
  Future<VoiceAdviceResult> generate({
    required String userInput,
    Map<String, dynamic>? context,
  }) async {
    final feature = _features[DateTime.now().millisecond % _features.length];
    return VoiceAdviceResult(
      category: category,
      spokenText: feature,
    );
  }
}

/// 消费分析策略（使用LLM）
class SpendingAdviceStrategy implements AdviceStrategy {
  static const _fallbackTip = '建议您关注高频小额消费，比如奶茶、外卖等，这些看似不起眼但累积起来可能很可观。';

  @override
  String get name => '消费分析';

  @override
  AdviceCategory get category => AdviceCategory.spending;

  @override
  Future<VoiceAdviceResult> generate({
    required String userInput,
    Map<String, dynamic>? context,
  }) async {
    try {
      final llmGenerator = LLMResponseGenerator.instance;
      final response = await llmGenerator.generateCasualChatResponse(
        userInput: '作为理财助手，给用户一条简短实用的省钱或消费优化建议，2句话即可，要具体可操作。',
      );
      return VoiceAdviceResult(
        category: category,
        spokenText: response,
        isLLMGenerated: true,
      );
    } catch (e) {
      debugPrint('[SpendingAdviceStrategy] LLM生成失败: $e');
      return VoiceAdviceResult(
        category: category,
        spokenText: _fallbackTip,
      );
    }
  }
}

/// 通用建议策略（使用LLM）
class GeneralAdviceStrategy implements AdviceStrategy {
  static const _fallbackTips = [
    '记账是理财的第一步，坚持记录每一笔支出，了解自己的消费习惯。',
    '建议设置预算，把每月支出控制在收入的70%以内，留出储蓄空间。',
    '定期回顾消费记录，找出不必要的支出，逐步优化消费结构。',
    '可以尝试"三分法"：收入的50%用于必要支出，30%用于想要的东西，20%用于储蓄。',
  ];

  @override
  String get name => '通用建议';

  @override
  AdviceCategory get category => AdviceCategory.general;

  @override
  Future<VoiceAdviceResult> generate({
    required String userInput,
    Map<String, dynamic>? context,
  }) async {
    try {
      final llmGenerator = LLMResponseGenerator.instance;
      final response = await llmGenerator.generateCasualChatResponse(
        userInput: '作为理财助手，针对"$userInput"给出简短实用的建议，2-3句话即可。',
      );
      return VoiceAdviceResult(
        category: category,
        spokenText: response,
        isLLMGenerated: true,
      );
    } catch (e) {
      debugPrint('[GeneralAdviceStrategy] LLM生成失败: $e');
      final tip = _fallbackTips[DateTime.now().millisecond % _fallbackTips.length];
      return VoiceAdviceResult(
        category: category,
        spokenText: tip,
      );
    }
  }
}
