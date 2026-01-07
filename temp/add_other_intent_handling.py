# -*- coding: utf-8 -*-
"""
为语音意图识别添加"其他"类别的智能化处理方案
"""

OTHER_INTENT_CONTENT = '''

#### 15.12.1.2 "其他"类别意图智能处理

当语音输入无法匹配到明确的记账、配置、导航等意图时，系统需要智能处理这些"其他"类别的请求。

##### 15.12.1.2.1 "其他"类别意图分类

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        "其他"类别意图分类体系                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         可处理的"其他"意图                                │   │
│  │                                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │ 帮助引导    │  │ 反馈问题    │  │ 功能咨询    │  │ 数据解读    │    │   │
│  │  │ • 怎么用    │  │ • 有bug     │  │ • 能不能    │  │ • 为什么    │    │   │
│  │  │ • 教我      │  │ • 不好用    │  │ • 怎么做到  │  │ • 什么意思  │    │   │
│  │  │ • 有什么功能│  │ • 建议改进  │  │ • 支持吗    │  │ • 帮我分析  │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  │                                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │ 情感表达    │  │ 闲聊互动    │  │ 确认澄清    │  │ 上下文补充  │    │   │
│  │  │ • 太棒了    │  │ • 你好      │  │ • 是的/不是 │  │ • 刚才那个  │    │   │
│  │  │ • 好烦啊    │  │ • 你是谁    │  │ • 对/错     │  │ • 还有      │    │   │
│  │  │ • 谢谢      │  │ • 讲个笑话  │  │ • 确定/取消 │  │ • 另外      │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         需要引导的"其他"意图                              │   │
│  │                                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │ 模糊意图    │  │ 超出范围    │  │ 信息不足    │  │ 歧义表达    │    │   │
│  │  │ • 帮我弄下  │  │ • 帮我炒股  │  │ • 记一笔    │  │ • 苹果      │    │   │
│  │  │ • 搞一下    │  │ • 订外卖    │  │ • 多少钱    │  │ • 转账      │    │   │
│  │  │ • 处理下    │  │ • 打游戏    │  │ • 那个      │  │ • 还款      │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.1.2.2 智能意图兜底服务

```dart
/// "其他"类别意图处理服务
class OtherIntentHandlingService {
  final LLMService _llmService;
  final ContextManager _contextManager;
  final HelpKnowledgeBase _helpKB;
  final FeedbackService _feedbackService;
  final EmotionDetector _emotionDetector;

  /// 处理无法明确分类的意图
  Future<OtherIntentResult> handleOtherIntent({
    required String input,
    required VoiceContext context,
  }) async {
    // 1. 细分"其他"意图类型
    final otherType = await _classifyOtherIntent(input, context);

    // 2. 根据类型分发处理
    switch (otherType) {
      case OtherIntentType.helpGuidance:
        return await _handleHelpGuidance(input, context);
      case OtherIntentType.feedback:
        return await _handleFeedback(input, context);
      case OtherIntentType.featureInquiry:
        return await _handleFeatureInquiry(input, context);
      case OtherIntentType.dataInterpretation:
        return await _handleDataInterpretation(input, context);
      case OtherIntentType.emotionalExpression:
        return await _handleEmotionalExpression(input, context);
      case OtherIntentType.casualChat:
        return await _handleCasualChat(input, context);
      case OtherIntentType.confirmation:
        return await _handleConfirmation(input, context);
      case OtherIntentType.contextSupplement:
        return await _handleContextSupplement(input, context);
      case OtherIntentType.ambiguous:
        return await _handleAmbiguousIntent(input, context);
      case OtherIntentType.outOfScope:
        return await _handleOutOfScope(input, context);
    }
  }

  /// 细分"其他"意图类型（LLM辅助）
  Future<OtherIntentType> _classifyOtherIntent(String input, VoiceContext context) async {
    // 规则优先
    final ruleResult = _ruleBasedClassify(input);
    if (ruleResult != null) return ruleResult;

    // LLM 细分
    final prompt = _buildClassificationPrompt(input, context);
    return await _llmService.classifyOtherIntent(prompt);
  }

  /// 规则分类
  OtherIntentType? _ruleBasedClassify(String input) {
    final lowered = input.toLowerCase();

    // 帮助引导
    if (_matchesPatterns(lowered, ['怎么用', '教我', '如何', '怎样', '有什么功能', '使用说明'])) {
      return OtherIntentType.helpGuidance;
    }

    // 反馈问题
    if (_matchesPatterns(lowered, ['bug', '问题', '不好用', '建议', '反馈', '改进', '希望'])) {
      return OtherIntentType.feedback;
    }

    // 功能咨询
    if (_matchesPatterns(lowered, ['能不能', '可以吗', '支持', '有没有', '能否'])) {
      return OtherIntentType.featureInquiry;
    }

    // 数据解读
    if (_matchesPatterns(lowered, ['为什么', '什么意思', '帮我分析', '解释', '看不懂'])) {
      return OtherIntentType.dataInterpretation;
    }

    // 情感表达
    if (_matchesPatterns(lowered, ['谢谢', '太棒了', '好烦', '不开心', '开心', '难过'])) {
      return OtherIntentType.emotionalExpression;
    }

    // 闲聊
    if (_matchesPatterns(lowered, ['你好', '你是谁', '讲个笑话', '聊聊', '无聊'])) {
      return OtherIntentType.casualChat;
    }

    // 确认
    if (_matchesPatterns(lowered, ['是的', '对', '好的', '确定', '不是', '取消', '算了'])) {
      return OtherIntentType.confirmation;
    }

    // 上下文补充
    if (_matchesPatterns(lowered, ['刚才', '那个', '还有', '另外', '补充'])) {
      return OtherIntentType.contextSupplement;
    }

    return null;  // 需要LLM进一步分析
  }
}

/// "其他"意图类型枚举
enum OtherIntentType {
  helpGuidance,        // 帮助引导
  feedback,            // 反馈问题
  featureInquiry,      // 功能咨询
  dataInterpretation,  // 数据解读
  emotionalExpression, // 情感表达
  casualChat,          // 闲聊互动
  confirmation,        // 确认澄清
  contextSupplement,   // 上下文补充
  ambiguous,           // 模糊意图（需引导）
  outOfScope,          // 超出范围
}
```

##### 15.12.1.2.3 帮助引导系统

```dart
/// 智能帮助引导服务
class IntelligentHelpService {
  final HelpKnowledgeBase _helpKB;
  final UserBehaviorAnalyzer _behaviorAnalyzer;
  final LLMService _llmService;

  /// 处理帮助请求
  Future<HelpResponse> handleHelpRequest({
    required String query,
    required VoiceContext context,
  }) async {
    // 1. 分析用户当前状态
    final userState = await _analyzeUserState(context);

    // 2. 智能匹配帮助内容
    final helpContent = await _matchHelpContent(query, userState);

    // 3. 生成个性化引导
    return await _generatePersonalizedGuidance(helpContent, userState);
  }

  /// 分析用户状态
  Future<UserHelpState> _analyzeUserState(VoiceContext context) async {
    return UserHelpState(
      // 用户当前所在页面
      currentPage: context.currentPage,
      // 用户最近的操作序列
      recentActions: context.recentActions,
      // 用户使用经验（新手/熟练）
      experienceLevel: await _behaviorAnalyzer.getExperienceLevel(context.userId),
      // 用户可能卡住的环节
      potentialStuckPoint: _inferStuckPoint(context),
      // 用户之前问过的问题
      previousQuestions: await _getPreviousQuestions(context.userId),
    );
  }

  /// 智能匹配帮助内容
  Future<HelpContent> _matchHelpContent(String query, UserHelpState state) async {
    // 1. 关键词匹配知识库
    final kbResults = await _helpKB.search(query, limit: 5);

    // 2. 根据用户状态过滤和排序
    final contextualResults = _filterByContext(kbResults, state);

    // 3. 如果知识库没有好的匹配，使用LLM生成
    if (contextualResults.isEmpty || contextualResults.first.score < 0.7) {
      return await _llmGenerateHelp(query, state);
    }

    return contextualResults.first;
  }

  /// 生成个性化引导话术
  Future<HelpResponse> _generatePersonalizedGuidance(
    HelpContent content,
    UserHelpState state,
  ) async {
    // 根据用户经验调整话术复杂度
    final verbosity = state.experienceLevel == ExperienceLevel.beginner
        ? VerbosityLevel.detailed
        : VerbosityLevel.concise;

    // 生成语音友好的引导
    final voiceScript = _generateVoiceScript(content, verbosity);

    // 是否需要演示
    final needsDemo = content.type == HelpContentType.howTo &&
        state.experienceLevel == ExperienceLevel.beginner;

    return HelpResponse(
      voiceScript: voiceScript,
      displayContent: content.displayText,
      suggestedActions: content.suggestedActions,
      needsInteractiveDemo: needsDemo,
      followUpQuestions: _generateFollowUpQuestions(content),
    );
  }
}

/// 帮助知识库
class HelpKnowledgeBase {
  /// 结构化帮助内容
  static const Map<String, HelpEntry> _entries = {
    'how_to_record': HelpEntry(
      keywords: ['怎么记账', '如何记账', '记一笔', '添加交易'],
      voiceAnswer: '记账很简单。您可以说"记一笔餐饮35元"，或者点击首页的加号按钮手动输入。',
      detailedAnswer: '记账有三种方式：1. 语音记账，直接说出消费内容；2. 点击+号手动输入；3. 使用快捷模板。',
      relatedTopics: ['voice_recording', 'quick_template', 'category_selection'],
    ),
    'budget_explanation': HelpEntry(
      keywords: ['预算', '怎么设预算', '预算是什么'],
      voiceAnswer: '预算可以帮您控制支出。您可以说"设置餐饮预算2000元"，系统会在您接近预算时提醒您。',
      detailedAnswer: '预算功能支持按分类设置月度预算，系统会追踪您的消费进度，在达到80%时预警。',
      relatedTopics: ['set_budget', 'budget_alert', 'vault_system'],
    ),
    // ... 更多帮助条目
  };
}
```

##### 15.12.1.2.4 智能数据解读

```dart
/// 智能数据解读服务
class IntelligentDataInterpreter {
  final LLMService _llmService;
  final StatsService _statsService;
  final InsightGenerator _insightGenerator;

  /// 处理数据解读请求
  Future<DataInterpretation> interpretData({
    required String query,
    required VoiceContext context,
  }) async {
    // 1. 识别用户想了解的数据维度
    final dataDimension = await _identifyDataDimension(query);

    // 2. 获取相关数据
    final data = await _fetchRelevantData(dataDimension, context);

    // 3. 生成智能解读
    return await _generateInterpretation(query, data, context);
  }

  /// 识别数据维度
  Future<DataDimension> _identifyDataDimension(String query) async {
    final patterns = {
      DataDimension.spending: ['花了', '消费', '支出', '开销'],
      DataDimension.trend: ['趋势', '变化', '走势', '增加', '减少'],
      DataDimension.comparison: ['对比', '比较', '相比', '比上个月'],
      DataDimension.category: ['哪个分类', '什么类型', '主要花在'],
      DataDimension.budget: ['预算', '超支', '剩余'],
      DataDimension.anomaly: ['为什么', '怎么这么多', '异常'],
    };

    for (final entry in patterns.entries) {
      if (entry.value.any((p) => query.contains(p))) {
        return entry.key;
      }
    }

    return DataDimension.general;
  }

  /// 生成智能解读
  Future<DataInterpretation> _generateInterpretation(
    String query,
    DataSnapshot data,
    VoiceContext context,
  ) async {
    // 使用LLM生成自然语言解读
    final prompt = '''
请用口语化的方式解读以下数据，回答用户的问题。

用户问题：$query

相关数据：
- 本月总支出：${data.monthlySpending}元
- 上月同期：${data.lastMonthSpending}元
- 变化：${data.changePercent}%
- 主要分类：${data.topCategories.join('、')}
- 预算使用：${data.budgetUsage}%

请生成：
1. 一句话核心结论
2. 2-3个关键洞察点
3. 一个可操作的建议
''';

    final llmResponse = await _llmService.generate(prompt);

    return DataInterpretation(
      summary: llmResponse.summary,
      insights: llmResponse.insights,
      suggestion: llmResponse.suggestion,
      visualizationType: _suggestVisualization(data),
      followUpQuestions: _generateFollowUpQuestions(data),
    );
  }
}
```

##### 15.12.1.2.5 情感陪伴与正向激励

```dart
/// 情感陪伴服务
class EmotionalCompanionService {
  final EmotionDetector _emotionDetector;
  final MotivationEngine _motivationEngine;
  final LLMService _llmService;

  /// 处理情感表达
  Future<EmotionalResponse> handleEmotionalExpression({
    required String input,
    required VoiceContext context,
  }) async {
    // 1. 识别情绪类型和强度
    final emotion = await _emotionDetector.detect(input);

    // 2. 分析情绪原因（是否与记账相关）
    final emotionContext = await _analyzeEmotionContext(emotion, context);

    // 3. 生成恰当的回应
    return await _generateEmotionalResponse(emotion, emotionContext);
  }

  /// 分析情绪上下文
  Future<EmotionContext> _analyzeEmotionContext(
    DetectedEmotion emotion,
    VoiceContext context,
  ) async {
    // 判断情绪是否与记账/财务相关
    if (emotion.type == EmotionType.negative) {
      // 检查最近是否有预算超支、大额支出等
      final recentEvents = await _getRecentFinancialEvents(context.userId);

      if (recentEvents.hasBudgetOverrun) {
        return EmotionContext(
          relatedToFinance: true,
          trigger: EmotionTrigger.budgetOverrun,
          suggestion: '预算超支是很正常的，我们一起看看怎么调整',
        );
      }

      if (recentEvents.hasLargeExpense) {
        return EmotionContext(
          relatedToFinance: true,
          trigger: EmotionTrigger.largeExpense,
          suggestion: '大额支出确实让人有压力，但记录下来是控制的第一步',
        );
      }
    }

    return EmotionContext(relatedToFinance: false);
  }

  /// 生成情感回应
  Future<EmotionalResponse> _generateEmotionalResponse(
    DetectedEmotion emotion,
    EmotionContext emotionContext,
  ) async {
    switch (emotion.type) {
      case EmotionType.positive:
        return _handlePositiveEmotion(emotion);
      case EmotionType.negative:
        return _handleNegativeEmotion(emotion, emotionContext);
      case EmotionType.grateful:
        return _handleGratefulEmotion(emotion);
      case EmotionType.frustrated:
        return _handleFrustratedEmotion(emotion, emotionContext);
      default:
        return _handleNeutralEmotion(emotion);
    }
  }

  /// 处理积极情绪
  EmotionalResponse _handlePositiveEmotion(DetectedEmotion emotion) {
    final responses = [
      '很高兴您用得开心！继续保持记账的好习惯哦~',
      '太棒了！坚持记账的您真的很棒！',
      '您的坚持一定会有回报的！',
    ];

    return EmotionalResponse(
      voiceScript: _randomPick(responses),
      emotionAcknowledged: true,
      motivationalMessage: await _motivationEngine.getPositiveReinforcement(),
    );
  }

  /// 处理消极情绪（与财务相关）
  EmotionalResponse _handleNegativeEmotion(
    DetectedEmotion emotion,
    EmotionContext context,
  ) {
    if (context.relatedToFinance) {
      // 针对财务相关的消极情绪给予支持
      final supportMessages = {
        EmotionTrigger.budgetOverrun: [
          '预算超支确实让人焦虑，但发现问题是解决问题的第一步。要不要看看是哪些消费导致的？',
          '别太担心，很多人一开始都会超支。重要的是我们在记录、在改进。',
        ],
        EmotionTrigger.largeExpense: [
          '大额支出确实有压力，但有些支出是必要的。我可以帮您分析一下是否合理。',
          '记录下来就是好的开始。要不要设置一个存钱目标来平衡一下？',
        ],
      };

      return EmotionalResponse(
        voiceScript: _randomPick(supportMessages[context.trigger] ?? []),
        emotionAcknowledged: true,
        suggestedAction: context.suggestion,
        offerHelp: true,
      );
    }

    // 非财务相关的消极情绪
    return EmotionalResponse(
      voiceScript: '听起来您心情不太好。如果是记账上遇到了问题，我很乐意帮忙。',
      emotionAcknowledged: true,
      offerHelp: true,
    );
  }
}

/// 正向激励引擎
class MotivationEngine {
  /// 获取正向激励消息
  Future<String> getPositiveReinforcement() async {
    final stats = await _getUserStats();

    if (stats.consecutiveDays >= 7) {
      return '您已经连续记账${stats.consecutiveDays}天了，太厉害了！';
    }

    if (stats.thisMonthSavings > 0) {
      return '这个月您已经省下了${stats.thisMonthSavings}元，继续加油！';
    }

    if (stats.budgetCompliance > 0.9) {
      return '您的预算执行率达到了${(stats.budgetCompliance * 100).toInt()}%，非常棒！';
    }

    return '感谢您使用记账助手，每一笔记录都是理财的好开始！';
  }
}
```

##### 15.12.1.2.6 模糊意图智能澄清

```dart
/// 模糊意图澄清服务
class AmbiguousIntentClarifier {
  final LLMService _llmService;
  final ContextManager _contextManager;

  /// 处理模糊意图
  Future<ClarificationResponse> clarifyAmbiguousIntent({
    required String input,
    required VoiceContext context,
  }) async {
    // 1. 分析可能的意图
    final possibleIntents = await _analyzePossibleIntents(input, context);

    // 2. 如果上下文足够，尝试自动推断
    final inferredIntent = _tryInferFromContext(possibleIntents, context);
    if (inferredIntent != null && inferredIntent.confidence > 0.85) {
      return ClarificationResponse(
        type: ClarificationType.autoInferred,
        inferredIntent: inferredIntent,
        confirmationPrompt: '您是想${inferredIntent.description}吗？',
      );
    }

    // 3. 生成澄清选项
    return ClarificationResponse(
      type: ClarificationType.needsSelection,
      options: _generateClarificationOptions(possibleIntents),
      prompt: _generateClarificationPrompt(input, possibleIntents),
    );
  }

  /// 分析可能的意图
  Future<List<PossibleIntent>> _analyzePossibleIntents(
    String input,
    VoiceContext context,
  ) async {
    // 示例："转账" 可能是：
    // 1. 记一笔转账交易
    // 2. 查看转账记录
    // 3. 设置转账提醒
    // 4. 从账户间转账

    final prompt = '''
用户说："$input"
当前页面：${context.currentPage}
最近操作：${context.recentActions.join('、')}

请分析用户可能的意图，列出所有合理的可能性及其可能性评分（0-1）。
''';

    return await _llmService.analyzePossibleIntents(prompt);
  }

  /// 生成澄清提示
  String _generateClarificationPrompt(String input, List<PossibleIntent> intents) {
    if (intents.length == 2) {
      return '您说的"$input"，是想${intents[0].shortDesc}，还是${intents[1].shortDesc}？';
    }

    if (intents.length <= 4) {
      final options = intents.map((i) => i.shortDesc).join('、');
      return '您是想$options，还是其他的？';
    }

    // 太多可能性，直接问
    return '您说的"$input"具体是想做什么呢？可以说详细一点。';
  }

  /// 生成澄清选项（用于UI展示）
  List<ClarificationOption> _generateClarificationOptions(
    List<PossibleIntent> intents,
  ) {
    return intents.take(4).map((intent) => ClarificationOption(
      label: intent.shortDesc,
      intent: intent.type,
      confidence: intent.confidence,
      icon: _getIntentIcon(intent.type),
    )).toList();
  }
}
```

##### 15.12.1.2.7 超出范围的优雅处理

```dart
/// 超出范围意图处理服务
class OutOfScopeHandler {
  final LLMService _llmService;
  final SimilarFeatureFinder _featureFinder;

  /// 处理超出范围的请求
  Future<OutOfScopeResponse> handleOutOfScope({
    required String input,
    required VoiceContext context,
  }) async {
    // 1. 判断超出范围的类型
    final outOfScopeType = await _classifyOutOfScope(input);

    // 2. 尝试找到相关的可用功能
    final relatedFeatures = await _featureFinder.findRelated(input);

    // 3. 生成友好的回应
    return _generateResponse(outOfScopeType, relatedFeatures, input);
  }

  /// 分类超出范围类型
  Future<OutOfScopeType> _classifyOutOfScope(String input) async {
    // 完全无关（如：帮我订外卖）
    if (_isCompletelyUnrelated(input)) {
      return OutOfScopeType.unrelated;
    }

    // 未来可能支持的功能
    if (_isPotentialFeature(input)) {
      return OutOfScopeType.futureFeature;
    }

    // 需要外部服务（如：帮我转账到银行）
    if (_needsExternalService(input)) {
      return OutOfScopeType.externalService;
    }

    return OutOfScopeType.unclear;
  }

  /// 生成友好回应
  OutOfScopeResponse _generateResponse(
    OutOfScopeType type,
    List<RelatedFeature> relatedFeatures,
    String input,
  ) {
    switch (type) {
      case OutOfScopeType.unrelated:
        return OutOfScopeResponse(
          voiceScript: '抱歉，作为记账助手，我暂时帮不了这个忙。不过我可以帮您记账、分析消费、管理预算哦！',
          suggestedFeatures: _getPopularFeatures(),
        );

      case OutOfScopeType.futureFeature:
        return OutOfScopeResponse(
          voiceScript: '这个功能我们正在规划中，感谢您的建议！目前您可以试试这些类似的功能。',
          suggestedFeatures: relatedFeatures,
          feedbackPrompt: '要把这个需求反馈给开发团队吗？',
        );

      case OutOfScopeType.externalService:
        return OutOfScopeResponse(
          voiceScript: '这个需要在对应的银行或支付App里操作哦。我可以帮您记录这笔交易。',
          suggestedAction: '要记录一笔转账吗？',
        );

      default:
        return OutOfScopeResponse(
          voiceScript: '不太确定您想做什么，您可以说"帮助"来了解我能做的事情。',
          suggestedFeatures: _getPopularFeatures(),
        );
    }
  }
}
```

##### 15.12.1.2.8 "其他"意图自学习

```dart
/// "其他"意图学习服务
class OtherIntentLearningService {

  /// 学习新的"其他"意图模式
  Future<void> learnOtherIntentPattern({
    required String input,
    required OtherIntentType classifiedType,
    required OtherIntentResult result,
    required UserFeedback feedback,
  }) async {
    // 1. 如果用户对分类不满意，记录正确分类
    if (feedback.type == FeedbackType.wrongClassification) {
      await _recordCorrection(input, classifiedType, feedback.correctType);
    }

    // 2. 如果用户对回应满意，强化该模式
    if (feedback.type == FeedbackType.helpful) {
      await _reinforcePattern(input, classifiedType, result);
    }

    // 3. 发现新的常见"其他"意图模式
    await _discoverNewPatterns();
  }

  /// 发现可提升为正式意图的模式
  Future<List<IntentPromotionCandidate>> discoverPromotablePatterns() async {
    // 如果某种"其他"意图请求非常频繁，考虑升级为正式意图
    final frequentPatterns = await _db.getFrequentOtherIntents(
      minFrequency: 100,
      days: 30,
    );

    return frequentPatterns
        .where((p) => p.successRate > 0.8)
        .map((p) => IntentPromotionCandidate(
          pattern: p.pattern,
          currentType: OtherIntentType.values.byName(p.type),
          frequency: p.frequency,
          successRate: p.successRate,
          suggestedNewIntent: _suggestNewIntentType(p),
        ))
        .toList();
  }
}
```

##### 15.12.1.2.9 "其他"意图处理效果预期

| 场景 | 处理方式 | 预期效果 |
|------|----------|----------|
| **帮助引导** | 智能知识库 + 个性化话术 | 首次解决率 85%+ |
| **反馈问题** | 情绪识别 + 工单创建 | 用户满意度 90%+ |
| **数据解读** | LLM生成洞察 | 理解率 80%+ |
| **情感表达** | 情绪陪伴 + 正向激励 | 情感共鸣 85%+ |
| **模糊意图** | 智能澄清 + 上下文推断 | 一次澄清成功率 75%+ |
| **超出范围** | 优雅拒绝 + 功能推荐 | 负面情绪 <10% |

'''

def main():
    # 读取文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查是否已存在
    if '15.12.1.2 "其他"类别意图智能处理' in content:
        print("Other intent handling section already exists, skipping")
        return

    # 查找插入点：在 "#### 15.12.2 语音记账模块" 之前
    marker = '#### 15.12.2 语音记账模块'
    idx = content.find(marker)

    if idx == -1:
        print(f"Error: Cannot find marker '{marker}'")
        return

    # 插入新内容
    before = content[:idx].rstrip()
    after = content[idx:]

    new_content = before + '\n\n' + OTHER_INTENT_CONTENT.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully added other intent handling section!')
    print(f'Old size: {len(content)} characters')
    print(f'New size: {len(new_content)} characters')
    print(f'Added: {len(new_content) - len(content)} characters')

if __name__ == '__main__':
    main()
