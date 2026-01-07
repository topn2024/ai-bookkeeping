#### 15.12.1.2 "其他"类别意图智能处理

在语音意图识别中，"其他"类别往往包含丰富的用户需求，需要智能化处理而非简单忽略。

##### 15.12.1.2.1 其他意图分类体系

```dart
/// 其他意图细分类型
enum OtherIntentType {
  helpGuidance,        // 帮助引导：如何使用某功能
  feedback,            // 反馈问题：报告bug、建议改进
  featureInquiry,      // 功能咨询：询问是否支持某功能
  dataInterpretation,  // 数据解读：请求解释统计数据
  emotionalExpression, // 情感表达：抱怨、赞美、吐槽
  casualChat,          // 闲聊互动：日常问候、闲聊
  confirmation,        // 确认澄清：对上一步操作的确认
  contextSupplement,   // 上下文补充：补充之前的信息
  ambiguous,           // 模糊意图：无法明确分类
  outOfScope,          // 超出范围：完全不相关的请求
}

/// 其他意图处理服务
class OtherIntentHandlingService {
  final IntelligentHelpService _helpService;
  final FeedbackCollectionService _feedbackService;
  final DataInterpretationService _dataService;
  final EmotionalCompanionService _emotionalService;
  final AmbiguousIntentClarifier _clarifier;

  /// 处理其他类别意图
  Future<OtherIntentResult> handleOtherIntent({
    required String userInput,
    required VoiceContext context,
  }) async {
    // 1. 细分类型识别
    final subType = await _classifyOtherIntent(userInput, context);

    // 2. 根据类型分发处理
    switch (subType) {
      case OtherIntentType.helpGuidance:
        return await _helpService.provideGuidance(userInput, context);

      case OtherIntentType.feedback:
        return await _feedbackService.collectFeedback(userInput, context);

      case OtherIntentType.featureInquiry:
        return await _handleFeatureInquiry(userInput);

      case OtherIntentType.dataInterpretation:
        return await _dataService.interpretData(userInput, context);

      case OtherIntentType.emotionalExpression:
        return await _emotionalService.respondToEmotion(userInput, context);

      case OtherIntentType.casualChat:
        return await _handleCasualChat(userInput, context);

      case OtherIntentType.confirmation:
        return await _handleConfirmation(userInput, context);

      case OtherIntentType.contextSupplement:
        return await _handleContextSupplement(userInput, context);

      case OtherIntentType.ambiguous:
        return await _clarifier.clarifyIntent(userInput, context);

      case OtherIntentType.outOfScope:
        return await _handleOutOfScope(userInput);
    }
  }

  /// 细分类型识别
  Future<OtherIntentType> _classifyOtherIntent(
    String input,
    VoiceContext context,
  ) async {
    // 规则优先匹配
    final ruleResult = _matchByRules(input);
    if (ruleResult != null) return ruleResult;

    // 上下文推断
    final contextResult = _inferFromContext(input, context);
    if (contextResult != null) return contextResult;

    // LLM 分类
    return await _classifyByLLM(input, context);
  }

  /// 规则匹配
  OtherIntentType? _matchByRules(String input) {
    final lowerInput = input.toLowerCase();

    // 帮助引导关键词
    if (_matchPatterns(lowerInput, [
      r'怎么(用|使用|操作)',
      r'如何.*(记账|设置|添加)',
      r'教我.*',
      r'.*在哪里',
      r'怎样才能.*',
    ])) {
      return OtherIntentType.helpGuidance;
    }

    // 反馈问题关键词
    if (_matchPatterns(lowerInput, [
      r'(bug|问题|错误|故障)',
      r'不能(用|工作)',
      r'建议.*',
      r'希望.*(增加|改进)',
      r'反馈.*',
    ])) {
      return OtherIntentType.feedback;
    }

    // 功能咨询关键词
    if (_matchPatterns(lowerInput, [
      r'(能不能|可以|支持).*(做|实现)',
      r'有没有.*功能',
      r'是否支持.*',
    ])) {
      return OtherIntentType.featureInquiry;
    }

    // 数据解读关键词
    if (_matchPatterns(lowerInput, [
      r'(为什么|怎么).*(这么多|这么少|增加|减少)',
      r'.*是什么意思',
      r'帮我(分析|解读|看看)',
      r'这个数据.*',
    ])) {
      return OtherIntentType.dataInterpretation;
    }

    // 情感表达关键词
    if (_matchPatterns(lowerInput, [
      r'(太棒了|真好|谢谢|感谢)',
      r'(烦死了|好烦|讨厌)',
      r'(哭了|穷了|破产了)',
      r'又超支了',
    ])) {
      return OtherIntentType.emotionalExpression;
    }

    return null;
  }
}
```

##### 15.12.1.2.2 智能帮助引导

```dart
/// 智能帮助服务
class IntelligentHelpService {
  final HelpKnowledgeBase _knowledgeBase;
  final ContextualHelpGenerator _helpGenerator;
  final UserBehaviorAnalyzer _behaviorAnalyzer;

  /// 提供智能帮助
  Future<OtherIntentResult> provideGuidance(
    String query,
    VoiceContext context,
  ) async {
    // 1. 理解用户问题
    final helpIntent = await _parseHelpIntent(query);

    // 2. 查找相关帮助内容
    final helpArticles = await _knowledgeBase.search(
      query: helpIntent.topic,
      userLevel: await _behaviorAnalyzer.getUserProficiency(),
    );

    // 3. 根据用户水平生成个性化回复
    final response = await _helpGenerator.generateResponse(
      question: query,
      articles: helpArticles,
      userContext: context,
      style: _determineResponseStyle(context),
    );

    // 4. 提供操作引导
    if (response.hasActionableSteps) {
      return OtherIntentResult.guidedAction(
        message: response.text,
        steps: response.steps,
        quickActions: response.quickActions,
        relatedTopics: response.relatedTopics,
      );
    }

    return OtherIntentResult.informational(
      message: response.text,
      learnMore: helpArticles.map((a) => a.title).toList(),
    );
  }

  /// 确定回复风格
  HelpResponseStyle _determineResponseStyle(VoiceContext context) {
    // 新用户：详细步骤
    if (context.user.isNewUser) {
      return HelpResponseStyle.detailed;
    }
    // 重复问题：简洁回答 + 相关链接
    if (context.hasAskedBefore) {
      return HelpResponseStyle.concise;
    }
    // 默认：平衡模式
    return HelpResponseStyle.balanced;
  }
}

/// 帮助知识库
class HelpKnowledgeBase {
  final Map<String, List<HelpArticle>> _categoryIndex;
  final SemanticSearchEngine _semanticSearch;

  /// 功能帮助映射
  static const Map<String, HelpTopic> featureHelpMap = {
    '语音记账': HelpTopic(
      title: '语音记账使用指南',
      shortAnswer: '您可以直接说"花了50元吃饭"来快速记账',
      steps: [
        '点击首页的麦克风按钮',
        '说出您的消费，如"午餐花了30元"',
        '确认识别结果后点击保存',
      ],
      tips: ['可以说多笔账目，如"早餐10元，午餐25元"'],
      relatedFeatures: ['拍照记账', '模板记账'],
    ),
    '预算设置': HelpTopic(
      title: '如何设置预算',
      shortAnswer: '在"我的"页面找到"预算管理"，点击添加预算',
      steps: [
        '进入"我的"页面',
        '点击"预算管理"',
        '选择"添加预算"',
        '设置类别、金额和周期',
      ],
      tips: ['建议先从大类预算开始，逐步细化'],
      relatedFeatures: ['小金库', '超支提醒'],
    ),
    // ... 更多功能帮助
  };

  /// 搜索帮助内容
  Future<List<HelpArticle>> search({
    required String query,
    required UserProficiency userLevel,
  }) async {
    // 1. 关键词匹配
    final keywordResults = _matchByKeywords(query);

    // 2. 语义搜索
    final semanticResults = await _semanticSearch.search(query);

    // 3. 合并去重，根据用户水平排序
    return _mergeAndRank(
      keywordResults,
      semanticResults,
      userLevel,
    );
  }
}
```

##### 15.12.1.2.3 智能数据解读

```dart
/// 智能数据解读服务
class IntelligentDataInterpreter {
  final StatisticsService _statsService;
  final TrendAnalyzer _trendAnalyzer;
  final LLMService _llm;

  /// 解读用户询问的数据
  Future<OtherIntentResult> interpretData(
    String query,
    VoiceContext context,
  ) async {
    // 1. 识别用户关心的数据维度
    final dataFocus = await _identifyDataFocus(query);

    // 2. 获取相关数据
    final data = await _fetchRelevantData(dataFocus, context);

    // 3. 生成智能解读
    final interpretation = await _generateInterpretation(
      query: query,
      data: data,
      userContext: context,
    );

    return OtherIntentResult.dataInsight(
      message: interpretation.summary,
      highlights: interpretation.keyPoints,
      visualizations: interpretation.suggestedCharts,
      actionSuggestions: interpretation.recommendations,
    );
  }

  /// 识别数据焦点
  Future<DataFocus> _identifyDataFocus(String query) async {
    // 时间维度识别
    final timeRange = _extractTimeRange(query);

    // 类别维度识别
    final categories = _extractCategories(query);

    // 问题类型识别
    final questionType = _identifyQuestionType(query);

    return DataFocus(
      timeRange: timeRange,
      categories: categories,
      questionType: questionType,
    );
  }

  /// 问题类型
  QuestionType _identifyQuestionType(String query) {
    if (query.contains(RegExp(r'为什么.*(多|少|高|低)'))) {
      return QuestionType.causation;  // 原因分析
    }
    if (query.contains(RegExp(r'(对比|比较|和.*比)'))) {
      return QuestionType.comparison;  // 对比分析
    }
    if (query.contains(RegExp(r'(趋势|变化|走势)'))) {
      return QuestionType.trend;  // 趋势分析
    }
    if (query.contains(RegExp(r'(构成|占比|分布)'))) {
      return QuestionType.composition;  // 构成分析
    }
    return QuestionType.general;  // 一般性查询
  }

  /// 生成智能解读
  Future<DataInterpretation> _generateInterpretation({
    required String query,
    required FinancialData data,
    required VoiceContext userContext,
  }) async {
    // 构建解读提示
    final prompt = '''
分析以下财务数据并回答用户问题：

用户问题：$query

数据概要：
- 时间范围：${data.timeRange}
- 总支出：${data.totalExpense}
- 总收入：${data.totalIncome}
- 主要类别分布：${data.categoryBreakdown}
- 同比变化：${data.yearOverYear}
- 环比变化：${data.monthOverMonth}

请提供：
1. 简洁的回答（2-3句话）
2. 3个关键数据点
3. 1-2个可行的建议
''';

    final response = await _llm.generate(prompt);
    return DataInterpretation.fromLLMResponse(response);
  }
}

/// 数据解读示例对话
const dataInterpretationExamples = '''
用户：为什么这个月花这么多？
AI：本月总支出12,580元，比上月增加了35%。主要原因是：
   1. 购物类别支出4,200元（双十一促销）
   2. 餐饮类别支出2,100元（比平时多800元）
   建议：可以设置购物预算提醒，避免冲动消费。

用户：我的钱都花哪去了？
AI：过去30天的支出分布如下：
   餐饮 28% (2,450元)
   住房 25% (2,180元)
   购物 20% (1,750元)
   交通 12% (1,050元)
   其他 15% (1,310元)
   餐饮占比最高，可以考虑多在家做饭节省开支。
''';
```

##### 15.12.1.2.4 情感陪伴响应

```dart
/// 情感陪伴服务
class EmotionalCompanionService {
  final SentimentAnalyzer _sentimentAnalyzer;
  final MotivationEngine _motivationEngine;
  final UserMoodTracker _moodTracker;

  /// 响应用户情感表达
  Future<OtherIntentResult> respondToEmotion(
    String input,
    VoiceContext context,
  ) async {
    // 1. 情感分析
    final sentiment = await _sentimentAnalyzer.analyze(input);

    // 2. 记录用户情绪（用于长期关怀）
    await _moodTracker.recordMood(
      userId: context.userId,
      sentiment: sentiment,
      trigger: input,
    );

    // 3. 生成情感响应
    final response = await _generateEmotionalResponse(
      sentiment: sentiment,
      input: input,
      context: context,
    );

    // 4. 可能的行动建议
    final suggestions = await _generateActionableSuggestions(
      sentiment: sentiment,
      context: context,
    );

    return OtherIntentResult.emotional(
      message: response,
      tone: sentiment.dominantEmotion,
      suggestions: suggestions,
    );
  }

  /// 生成情感响应
  Future<String> _generateEmotionalResponse({
    required SentimentResult sentiment,
    required String input,
    required VoiceContext context,
  }) async {
    switch (sentiment.dominantEmotion) {
      case Emotion.frustrated:
        return _handleFrustration(input, context);

      case Emotion.anxious:
        return _handleAnxiety(input, context);

      case Emotion.happy:
        return _handleHappiness(input, context);

      case Emotion.sad:
        return _handleSadness(input, context);

      case Emotion.surprised:
        return _handleSurprise(input, context);

      default:
        return _handleNeutral(input, context);
    }
  }

  /// 处理沮丧情绪（如超支）
  Future<String> _handleFrustration(String input, VoiceContext context) async {
    // 检查是否与财务相关
    if (_isFinanceRelated(input)) {
      final encouragement = await _motivationEngine.getEncouragement(
        situation: 'budget_exceeded',
        userHistory: context.userHistory,
      );

      return '''
${encouragement.empathy}

${encouragement.perspective}

${encouragement.actionTip}
''';
    }

    return '我理解您的心情。有什么我可以帮您的吗？';
  }
}

/// 激励引擎
class MotivationEngine {
  /// 获取鼓励话语
  Future<Encouragement> getEncouragement({
    required String situation,
    required UserHistory userHistory,
  }) async {
    switch (situation) {
      case 'budget_exceeded':
        final progress = userHistory.budgetAdherence;
        if (progress > 0.7) {
          return Encouragement(
            empathy: '超支确实让人沮丧，但别太自责。',
            perspective: '其实您本月有${(progress * 100).toInt()}%的时间都控制得很好！',
            actionTip: '要不要看看哪些消费可以调整？我可以帮您分析。',
          );
        } else {
          return Encouragement(
            empathy: '理财是个渐进的过程，每个人都会遇到挑战。',
            perspective: '重要的是您在关注自己的财务状况，这已经是很好的开始了。',
            actionTip: '要不要一起设定一个更容易达成的小目标？',
          );
        }

      case 'savings_achieved':
        return Encouragement(
          empathy: '太棒了！',
          perspective: '您的坚持得到了回报，储蓄目标达成！',
          actionTip: '要不要设定下一个更有挑战的目标？',
        );

      default:
        return Encouragement.default_();
    }
  }
}

/// 情感响应示例
const emotionalResponseExamples = '''
用户：又超支了，烦死了
AI：超支确实让人沮丧，但别太自责。
    其实您本月有85%的时间都控制得很好呢！
    要不要看看是哪笔消费超出预期？我可以帮您分析一下。

用户：这个月终于没超支！
AI：太棒了！您的预算控制做得很好！
    本月节省了320元，继续保持！
    要不要把省下的钱转入储蓄目标？

用户：感觉自己好穷啊
AI：理财是个循序渐进的过程，您能关注自己的财务状况已经很棒了。
    其实从数据看，您本月的储蓄率是15%，比上月提高了3%呢。
    要不要一起看看还有哪些可以优化的地方？
''';
```

##### 15.12.1.2.5 模糊意图澄清

```dart
/// 模糊意图澄清服务
class AmbiguousIntentClarifier {
  final ContextInferenceEngine _contextEngine;
  final IntentCandidateGenerator _candidateGenerator;

  /// 澄清模糊意图
  Future<OtherIntentResult> clarifyIntent(
    String input,
    VoiceContext context,
  ) async {
    // 1. 生成可能的意图候选
    final candidates = await _candidateGenerator.generate(
      input: input,
      context: context,
    );

    // 2. 如果有高置信度候选，直接确认
    if (candidates.first.confidence > 0.7) {
      return OtherIntentResult.clarification(
        message: '您是想${candidates.first.description}吗？',
        suggestedIntent: candidates.first,
        alternatives: candidates.skip(1).take(2).toList(),
      );
    }

    // 3. 多个候选，提供选择
    if (candidates.length >= 2) {
      return OtherIntentResult.multiChoice(
        message: '请问您想要：',
        options: candidates.take(4).map((c) => ClarificationOption(
          label: c.shortLabel,
          description: c.description,
          action: c.action,
        )).toList(),
      );
    }

    // 4. 无法理解，礼貌询问
    return OtherIntentResult.askForClarification(
      message: '抱歉，我不太理解您的意思。您可以换个方式描述一下吗？',
      hints: _generateHints(context),
    );
  }

  /// 生成提示
  List<String> _generateHints(VoiceContext context) {
    final hints = <String>[];

    // 基于最近操作
    if (context.lastAction != null) {
      hints.add('继续${context.lastAction.description}');
    }

    // 常用功能提示
    hints.addAll([
      '记一笔账',
      '查看本月支出',
      '设置预算',
    ]);

    return hints.take(3).toList();
  }
}

/// 上下文推断引擎
class ContextInferenceEngine {
  /// 从上下文推断可能的意图
  Future<List<IntentCandidate>> inferFromContext({
    required String ambiguousInput,
    required VoiceContext context,
  }) async {
    final candidates = <IntentCandidate>[];

    // 1. 基于对话历史推断
    if (context.lastQuestion != null) {
      // 可能是对上一个问题的回答
      candidates.add(IntentCandidate(
        type: IntentType.answerToPreviousQuestion,
        confidence: 0.6,
        description: '回答"${context.lastQuestion}"',
      ));
    }

    // 2. 基于待确认操作推断
    if (context.pendingConfirmation != null) {
      candidates.add(IntentCandidate(
        type: IntentType.confirmation,
        confidence: _isAffirmative(ambiguousInput) ? 0.8 : 0.3,
        description: '确认${context.pendingConfirmation}',
      ));
    }

    // 3. 基于时间/位置上下文推断
    final timeBasedIntent = _inferFromTimeContext(context);
    if (timeBasedIntent != null) {
      candidates.add(timeBasedIntent);
    }

    return candidates..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  /// 判断是否是肯定回答
  bool _isAffirmative(String input) {
    return RegExp(r'^(是|对|好|可以|确认|没问题|OK|嗯)').hasMatch(input);
  }
}
```

##### 15.12.1.2.6 超出范围处理

```dart
/// 超出范围请求处理
class OutOfScopeHandler {
  final FeatureCapabilityMap _capabilities;
  final PoliteDeclineGenerator _declineGenerator;

  /// 处理超出范围的请求
  Future<OtherIntentResult> handleOutOfScope(String input) async {
    // 1. 识别用户真实需求
    final userNeed = await _identifyUnderlyingNeed(input);

    // 2. 检查是否有相关功能可以部分满足
    final relatedFeatures = _findRelatedFeatures(userNeed);

    // 3. 生成礼貌的回复
    if (relatedFeatures.isNotEmpty) {
      return OtherIntentResult.partialCapability(
        message: '抱歉，我暂时不能${userNeed.description}，不过我可以帮您：',
        alternatives: relatedFeatures,
      );
    }

    // 4. 完全无法满足
    return OtherIntentResult.decline(
      message: await _declineGenerator.generate(
        request: input,
        tone: DeclineTone.friendly,
      ),
      whatICanDo: _capabilities.getTopFeatures(5),
    );
  }

  /// 查找相关功能
  List<FeatureAlternative> _findRelatedFeatures(UserNeed need) {
    final alternatives = <FeatureAlternative>[];

    // 示例：用户问天气，推荐消费建议
    if (need.category == 'weather') {
      alternatives.add(FeatureAlternative(
        feature: '消费建议',
        description: '虽然不能查天气，但可以根据季节给您消费建议',
        action: () => _openSeasonalAdvice(),
      ));
    }

    // 示例：用户问导航，推荐附近消费记录
    if (need.category == 'navigation') {
      alternatives.add(FeatureAlternative(
        feature: '附近消费',
        description: '可以查看您在这个区域的历史消费记录',
        action: () => _openNearbyExpenses(),
      ));
    }

    return alternatives;
  }
}

/// 礼貌拒绝生成器
class PoliteDeclineGenerator {
  /// 生成礼貌的拒绝回复
  Future<String> generate({
    required String request,
    required DeclineTone tone,
  }) async {
    final templates = {
      DeclineTone.friendly: [
        '不好意思，这个我还不太会呢~ 不过记账方面我很在行！',
        '这个超出我的能力范围了，我是专注于帮您理财的小助手哦。',
        '抱歉这个帮不了您，但如果是记账、预算方面的事，随时找我！',
      ],
      DeclineTone.professional: [
        '抱歉，该功能暂不支持。我可以帮您处理记账、预算等财务相关事务。',
        '这超出了应用的服务范围。如需财务管理帮助，我很乐意协助。',
      ],
    };

    final options = templates[tone] ?? templates[DeclineTone.friendly]!;
    return options[DateTime.now().millisecond % options.length];
  }
}
```

##### 15.12.1.2.7 其他意图学习优化

```dart
/// 其他意图学习服务
class OtherIntentLearningService {
  final LocalLearningStore _localStore;
  final GlobalPatternAggregator _globalAggregator;

  /// 从"其他"意图中学习
  Future<void> learnFromOtherIntent({
    required String input,
    required OtherIntentType classifiedType,
    required UserFeedback feedback,
  }) async {
    // 1. 如果分类正确，强化模式
    if (feedback.isCorrect) {
      await _reinforcePattern(input, classifiedType);
    }

    // 2. 如果分类错误，学习正确映射
    if (feedback.correctedType != null) {
      await _learnCorrection(input, feedback.correctedType!);
    }

    // 3. 发现新的意图模式
    if (feedback.suggestedNewType != null) {
      await _reportNewPattern(input, feedback.suggestedNewType!);
    }
  }

  /// 强化正确模式
  Future<void> _reinforcePattern(String input, OtherIntentType type) async {
    // 提取特征
    final features = _extractFeatures(input);

    // 更新本地模式权重
    await _localStore.reinforcePattern(
      features: features,
      intentType: type,
      weight: 1.0,
    );

    // 上报用于全局学习（脱敏）
    await _globalAggregator.reportPattern(
      patternHash: _hashPattern(features),
      intentType: type,
    );
  }

  /// 学习纠正
  Future<void> _learnCorrection(String input, OtherIntentType correctType) async {
    final features = _extractFeatures(input);

    // 记录纠正样本
    await _localStore.addCorrectionSample(
      features: features,
      correctType: correctType,
    );

    // 达到阈值后更新规则
    final correctionCount = await _localStore.getCorrectionCount(
      features: features,
      correctType: correctType,
    );

    if (correctionCount >= 3) {
      await _updateLocalRule(features, correctType);
    }
  }

  /// 将频繁出现的"其他"意图升级为新类型
  Future<void> _considerPromotingToNewType() async {
    // 分析最近30天的"ambiguous"分类
    final ambiguousPatterns = await _localStore.getFrequentAmbiguous(
      days: 30,
      minCount: 10,
    );

    for (final pattern in ambiguousPatterns) {
      // 如果某个模式频繁出现且用户最终都做了相同操作
      if (pattern.outcomeConsistency > 0.8) {
        // 建议升级为显式意图类型
        await _suggestNewIntentType(pattern);
      }
    }
  }
}
```
