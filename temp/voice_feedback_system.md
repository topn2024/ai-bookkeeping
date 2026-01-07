#### 15.12.10 智能语音反馈与客服系统

本模块实现通过语音收集用户反馈、智能分类问题、自动回复常见问题、情绪识别与应对、以及反馈闭环管理的完整客服系统。

##### 15.12.10.0 系统架构全景图

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        智能语音反馈与客服系统 - 架构全景图                                   │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              用户语音输入                                         │   │
│  │                    "这个功能太难用了" / "怎么设置预算"                              │   │
│  └───────────────────────────────────┬─────────────────────────────────────────────┘   │
│                                      │                                                  │
│                                      ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                           多维度智能分析引擎                                       │   │
│  ├───────────────┬───────────────┬───────────────┬───────────────┬─────────────────┤   │
│  │   意图识别     │   类型分类     │   情绪识别     │   紧急度判断   │   上下文理解    │   │
│  │               │               │               │               │                 │   │
│  │  • 问题咨询    │  • 功能问题    │  • 积极/满意   │  • 紧急       │  • 历史会话     │   │
│  │  • 功能建议    │  • 体验问题    │  • 中性/困惑   │  • 重要       │  • 用户画像     │   │
│  │  • Bug反馈    │  • 性能问题    │  • 消极/不满   │  • 一般       │  • 使用场景     │   │
│  │  • 投诉抱怨    │  • 建议优化    │  • 愤怒/焦虑   │  • ��         │  • 设备信息     │   │
│  └───────────────┴───────────────┴───────────────┴───────────────┴─────────────────┘   │
│                                      │                                                  │
│                    ┌─────────────────┼─────────────────┐                               │
│                    │                 │                 │                               │
│                    ▼                 ▼                 ▼                               │
│  ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐              │
│  │   智能知识库匹配     │ │   情绪化应对策略     │ │   问题工单生成       │              │
│  │                     │ │                     │ │                     │              │
│  │  • 帮助文档检索      │ │  • 共情式开场        │ │  • 自动分类标签      │              │
│  │  • FAQ精准匹配       │ │  • 语气调整          │ │  • 优先级设定        │              │
│  │  • 相似问题推荐      │ │  • 安抚话术          │ │  • 指派规则          │              │
│  │  • 操作指引生成      │ │  • 升级判断          │ │  • SLA时效          │              │
│  └──────────┬──────────┘ └──────────┬──────────┘ └──────────┬──────────┘              │
│             │                       │                       │                          │
│             └───────────────────────┼───────────────────────┘                          │
│                                     ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                           智能响应生成器                                          │   │
│  │                                                                                   │   │
│  │   输入: 用户问题 + 情绪状态 + 知识匹配结果 + 历史上下文                             │   │
│  │   输出: 个性化、情感化、准确的回复内容                                              │   │
│  │                                                                                   │   │
│  └───────────────────────────────────┬─────────────────────────────────────────────┘   │
│                                      │                                                  │
│                                      ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                           反馈闭环管理系统                                         │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                   │   │
│  │  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌─────────────┐  │   │
│  │  │  回复满意度    │───→│  答复质量评估  │───→│  策略自动优化  │───→│  知识库更新  │  │   │
│  │  │    收集       │    │    分析       │    │    迭代       │    │    扩充     │  │   │
│  │  └───────────────┘    └───────────────┘    └───────────────┘    └─────────────┘  │   │
│  │                                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.10.1 反馈类型与情绪识别

```dart
/// 反馈类型枚举
enum FeedbackType {
  // === 问题类 ===
  question,           // 功能咨询：怎么用、在哪里
  bugReport,          // Bug反馈：出错、闪退、数据丢失
  performanceIssue,   // 性能问题：卡顿、慢、耗电
  dataIssue,          // 数据问题：同步失败、数据不对

  // === 建议类 ===
  featureRequest,     // 功能建议：希望增加xxx功能
  uiSuggestion,       // 界面建议：希望界面xxx
  experienceSuggestion, // 体验建议：操作不方便

  // === 情绪类 ===
  complaint,          // 投诉抱怨：不满意、太差了
  praise,             // 表扬称赞：好用、喜欢

  // === 其他 ===
  general,            // 一般反馈
  unknown,            // 未识别
}

/// 情绪类型枚举
enum EmotionType {
  positive,           // 积极：满意、开心、感谢
  neutral,            // 中性：平静、询问
  confused,           // 困惑：不理解、不会用
  frustrated,         // 沮丧：失望、无奈
  angry,              // 愤怒：生气、不满
  anxious,            // 焦虑：着急、担心
  sarcastic,          // 讽刺：阴阳怪气
}

/// 紧急程度枚举
enum UrgencyLevel {
  critical,           // 紧急：数据丢失、无法使用
  high,               // 重要：核心功能异常
  medium,             // 一般：非核心功能问题
  low,                // 低：建议、咨询
}

/// 反馈分析结果
class FeedbackAnalysis {
  final FeedbackType type;
  final EmotionType emotion;
  final UrgencyLevel urgency;
  final double emotionIntensity;      // 情绪强度 0-1
  final List<String> keywords;        // 关键词
  final String? relatedFeature;       // 相关功能模块
  final Map<String, dynamic> context; // 上下文信息

  FeedbackAnalysis({
    required this.type,
    required this.emotion,
    required this.urgency,
    required this.emotionIntensity,
    required this.keywords,
    this.relatedFeature,
    this.context = const {},
  });
}

/// 反馈分析引擎
class FeedbackAnalysisEngine {
  final LLMService _llmService;

  /// 情绪识别关键词库
  static const Map<EmotionType, List<String>> _emotionKeywords = {
    EmotionType.positive: [
      '好用', '喜欢', '太棒了', '感谢', '不错', '方便', '赞', '厉害',
      '满意', '推荐', '五星', '完美', '优秀',
    ],
    EmotionType.neutral: [
      '请问', '怎么', '如何', '可以吗', '在哪', '是什么',
    ],
    EmotionType.confused: [
      '不懂', '不理解', '不会', '看不懂', '不知道', '不明白', '迷惑',
      '搞不清', '弄不明白',
    ],
    EmotionType.frustrated: [
      '失望', '无奈', '算了', '放弃', '不想用了', '太麻烦',
      '受不了', '崩溃',
    ],
    EmotionType.angry: [
      '垃圾', '太差', '什么玩意', '坑人', '骗子', '退款', '卸载',
      '差评', '投诉', '举报', '愤怒', '气死',
    ],
    EmotionType.anxious: [
      '急', '着急', '马上', '立刻', '紧急', '快点', '等不了',
      '担心', '害怕', '丢了',
    ],
    EmotionType.sarcastic: [
      '呵呵', '真厉害', '牛逼啊', '服了', '佩服', '高明',
    ],
  };

  /// 问题类型识别关键词
  static const Map<FeedbackType, List<String>> _typeKeywords = {
    FeedbackType.question: [
      '怎么', '如何', '在哪', '哪里', '为什么', '是什么', '能不能',
      '可以吗', '请问', '教我',
    ],
    FeedbackType.bugReport: [
      '出错', '报错', '闪退', '崩溃', '打不开', '用不了', '失败',
      'bug', '问题', '异常', '卡死',
    ],
    FeedbackType.performanceIssue: [
      '卡', '慢', '卡顿', '加载慢', '耗电', '发热', '内存', '占用',
    ],
    FeedbackType.dataIssue: [
      '数据丢失', '同步失败', '数据不对', '记录没了', '金额错误',
      '不同步', '数据错乱',
    ],
    FeedbackType.featureRequest: [
      '希望', '建议', '能不能加', '要是有', '如果能', '最好能',
      '需要', '想要', '缺少',
    ],
    FeedbackType.complaint: [
      '投诉', '举报', '退款', '差评', '太差', '垃圾', '骗人',
    ],
    FeedbackType.praise: [
      '好评', '五星', '推荐', '太好用', '很棒', '喜欢',
    ],
  };

  /// 分析用户反馈
  Future<FeedbackAnalysis> analyzeFeedback(String text) async {
    // 1. 规则匹配快速识别
    final ruleResult = _ruleBasedAnalysis(text);

    // 2. LLM深度分析
    final llmResult = await _llmService.analyzeFeedback(
      text: text,
      feedbackTypes: FeedbackType.values.map((e) => e.name).toList(),
      emotionTypes: EmotionType.values.map((e) => e.name).toList(),
    );

    // 3. 综合判断
    return FeedbackAnalysis(
      type: _mergeTypeResult(ruleResult.type, llmResult.type),
      emotion: _mergeEmotionResult(ruleResult.emotion, llmResult.emotion),
      urgency: _calculateUrgency(ruleResult, llmResult),
      emotionIntensity: llmResult.emotionIntensity,
      keywords: llmResult.keywords,
      relatedFeature: llmResult.relatedFeature,
      context: {
        'originalText': text,
        'analysisTime': DateTime.now().toIso8601String(),
        'confidence': llmResult.confidence,
      },
    );
  }

  /// 规则匹配分析
  _RuleAnalysisResult _ruleBasedAnalysis(String text) {
    // 情绪识别
    EmotionType emotion = EmotionType.neutral;
    int maxEmotionScore = 0;

    for (final entry in _emotionKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) score++;
      }
      if (score > maxEmotionScore) {
        maxEmotionScore = score;
        emotion = entry.key;
      }
    }

    // 类型识别
    FeedbackType type = FeedbackType.general;
    int maxTypeScore = 0;

    for (final entry in _typeKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) score++;
      }
      if (score > maxTypeScore) {
        maxTypeScore = score;
        type = entry.key;
      }
    }

    return _RuleAnalysisResult(type: type, emotion: emotion);
  }

  /// 计算紧急程度
  UrgencyLevel _calculateUrgency(
    _RuleAnalysisResult ruleResult,
    _LLMAnalysisResult llmResult,
  ) {
    // 数据丢失、无法使用 → 紧急
    if (ruleResult.type == FeedbackType.dataIssue ||
        llmResult.keywords.any((k) => ['丢失', '没了', '用不了'].contains(k))) {
      return UrgencyLevel.critical;
    }

    // Bug、愤怒情绪 → 重要
    if (ruleResult.type == FeedbackType.bugReport ||
        ruleResult.emotion == EmotionType.angry) {
      return UrgencyLevel.high;
    }

    // 困惑、沮丧 → 一般
    if (ruleResult.emotion == EmotionType.confused ||
        ruleResult.emotion == EmotionType.frustrated) {
      return UrgencyLevel.medium;
    }

    // 建议、咨询 → 低
    return UrgencyLevel.low;
  }
}
```

##### 15.12.10.2 情绪化应对策略

```dart
/// 情绪应对策略生成器
class EmotionalResponseStrategy {

  /// 根据情绪生成应对策略
  static ResponseStrategy getStrategy(FeedbackAnalysis analysis) {
    return ResponseStrategy(
      openingStyle: _getOpeningStyle(analysis.emotion, analysis.emotionIntensity),
      toneAdjustment: _getToneAdjustment(analysis.emotion),
      responseTemplate: _getResponseTemplate(analysis),
      followUpAction: _getFollowUpAction(analysis),
      escalationNeeded: _needsEscalation(analysis),
    );
  }

  /// 开场白风格
  static OpeningStyle _getOpeningStyle(EmotionType emotion, double intensity) {
    switch (emotion) {
      case EmotionType.angry:
        if (intensity > 0.7) {
          return OpeningStyle(
            style: '诚恳道歉',
            templates: [
              '非常抱歉给您带来了不好的体验，我完全理解您的心情。',
              '真的很抱歉让您遇到这样的问题，您的反馈对我们非常重要。',
              '首先向您表达深深的歉意，我们非常重视您反馈的问题。',
            ],
          );
        }
        return OpeningStyle(
          style: '理解共情',
          templates: [
            '理解您的心情，遇到这样的问题确实让人着急。',
            '感谢您的反馈，我来帮您看看这个问题。',
          ],
        );

      case EmotionType.anxious:
        return OpeningStyle(
          style: '快速响应',
          templates: [
            '别担心，我来帮您解决这个问题。',
            '我已经收到您的反馈，马上为您处理。',
            '请放心，这个问题我们可以解决。',
          ],
        );

      case EmotionType.frustrated:
        return OpeningStyle(
          style: '温暖鼓励',
          templates: [
            '理解您的感受，让我们一起来解决这个问题。',
            '别灰心，这个问题其实不难解决。',
            '感谢您的耐心，我来帮您想办法。',
          ],
        );

      case EmotionType.confused:
        return OpeningStyle(
          style: '耐心引导',
          templates: [
            '没关系，这个功能确实需要了解一下，我来给您详细说明。',
            '这是个好问题，让我来帮您解答。',
            '别着急，我来一步步教您怎么操作。',
          ],
        );

      case EmotionType.positive:
        return OpeningStyle(
          style: '热情回应',
          templates: [
            '太高兴您喜欢我们的产品！',
            '感谢您的认可，这是对我们最大的鼓励！',
            '谢谢您的好评，我们会继续努力！',
          ],
        );

      case EmotionType.sarcastic:
        return OpeningStyle(
          style: '真诚面对',
          templates: [
            '感谢您的反馈，我们确实还有很多需要改进的地方。',
            '您说得对，这方面我们做得还不够好，正在努力改进。',
          ],
        );

      default:
        return OpeningStyle(
          style: '标准问候',
          templates: [
            '您好，感谢您的反馈。',
            '收到您的消息，我来为您解答。',
          ],
        );
    }
  }

  /// 语气调整建议
  static ToneAdjustment _getToneAdjustment(EmotionType emotion) {
    switch (emotion) {
      case EmotionType.angry:
        return ToneAdjustment(
          speed: 'slower',           // 语速放慢
          formality: 'formal',       // 正式
          warmth: 'high',            // 高温暖度
          directness: 'moderate',    // 适度直接
          avoidWords: ['但是', '不过', '其实'],  // 避免转折词
          useWords: ['抱歉', '理解', '一定', '马上'],
        );

      case EmotionType.anxious:
        return ToneAdjustment(
          speed: 'normal',
          formality: 'casual',       // 轻松
          warmth: 'high',
          directness: 'high',        // 直接给方案
          avoidWords: ['可能', '也许', '大概'],
          useWords: ['放心', '马上', '立刻', '已经'],
        );

      case EmotionType.confused:
        return ToneAdjustment(
          speed: 'slower',
          formality: 'casual',
          warmth: 'medium',
          directness: 'low',         // 循序渐进
          avoidWords: ['简单', '很容易', '应该知道'],
          useWords: ['首先', '然后', '接下来', '这样'],
        );

      case EmotionType.positive:
        return ToneAdjustment(
          speed: 'normal',
          formality: 'casual',
          warmth: 'high',
          directness: 'moderate',
          avoidWords: [],
          useWords: ['谢谢', '很高兴', '期待'],
        );

      default:
        return ToneAdjustment(
          speed: 'normal',
          formality: 'casual',
          warmth: 'medium',
          directness: 'moderate',
          avoidWords: [],
          useWords: [],
        );
    }
  }

  /// 判断是否需要升级处理
  static bool _needsEscalation(FeedbackAnalysis analysis) {
    // 紧急问题
    if (analysis.urgency == UrgencyLevel.critical) return true;

    // 高强度负面情绪
    if (analysis.emotion == EmotionType.angry &&
        analysis.emotionIntensity > 0.8) return true;

    // 投诉类型
    if (analysis.type == FeedbackType.complaint) return true;

    // 数据安全问题
    if (analysis.type == FeedbackType.dataIssue &&
        analysis.keywords.any((k) => ['丢失', '泄露', '安全'].contains(k))) {
      return true;
    }

    return false;
  }
}

/// 开场白风格
class OpeningStyle {
  final String style;
  final List<String> templates;

  OpeningStyle({required this.style, required this.templates});

  String getRandomTemplate() {
    return templates[DateTime.now().millisecond % templates.length];
  }
}

/// 语气调整
class ToneAdjustment {
  final String speed;
  final String formality;
  final String warmth;
  final String directness;
  final List<String> avoidWords;
  final List<String> useWords;

  ToneAdjustment({
    required this.speed,
    required this.formality,
    required this.warmth,
    required this.directness,
    required this.avoidWords,
    required this.useWords,
  });
}

/// 应对策略
class ResponseStrategy {
  final OpeningStyle openingStyle;
  final ToneAdjustment toneAdjustment;
  final String responseTemplate;
  final String followUpAction;
  final bool escalationNeeded;

  ResponseStrategy({
    required this.openingStyle,
    required this.toneAdjustment,
    required this.responseTemplate,
    required this.followUpAction,
    required this.escalationNeeded,
  });
}
```

##### 15.12.10.3 智能知识库系统

```dart
/// 知识库管理系统
/// 将设计文档、帮助文档、FAQ等整理为可检索的知识库
class KnowledgeBaseService {
  final VectorDBService _vectorDB;
  final LLMService _llmService;

  /// 知识来源类型
  static const knowledgeSources = {
    'design_doc': '设计文档',
    'help_doc': '帮助文档',
    'faq': '常见问题',
    'feature_list': '功能清单',
    'release_notes': '更新日志',
    'user_manual': '用户手册',
    'troubleshooting': '故障排除',
    'best_practices': '最佳实践',
  };

  /// 知识条目结构
  /// 从设计文档中自动提取并结构化
  static const knowledgeSchema = {
    'feature': {
      'name': '功能名称',
      'description': '功能描述',
      'howToUse': '使用方法',
      'relatedFeatures': '相关功能',
      'tips': '使用技巧',
      'commonIssues': '常见问题',
    },
    'faq': {
      'question': '问题',
      'answer': '答案',
      'category': '分类',
      'keywords': '关键词',
      'relatedQuestions': '相关问题',
    },
    'troubleshooting': {
      'symptom': '问题症状',
      'cause': '可能原因',
      'solution': '解决方案',
      'steps': '操作步骤',
    },
  };

  /// 从设计文档自动构建知识库
  Future<void> buildKnowledgeBase() async {
    // 1. 解析设计文档
    final designDoc = await _parseDesignDocument('app_v2_design.md');

    // 2. 提取功能知识
    final features = await _extractFeatureKnowledge(designDoc);

    // 3. 生成FAQ
    final faqs = await _generateFAQFromFeatures(features);

    // 4. 生成故障排除指南
    final troubleshooting = await _generateTroubleshootingGuide(features);

    // 5. 向量化存储
    await _vectorDB.indexDocuments([
      ...features.map((f) => f.toDocument()),
      ...faqs.map((f) => f.toDocument()),
      ...troubleshooting.map((t) => t.toDocument()),
    ]);
  }

  /// 智能搜索知识
  Future<List<KnowledgeItem>> searchKnowledge({
    required String query,
    FeedbackType? feedbackType,
    int limit = 5,
  }) async {
    // 1. 关键词提取
    final keywords = await _llmService.extractKeywords(query);

    // 2. 向量相似度搜索
    final vectorResults = await _vectorDB.search(
      query: query,
      limit: limit * 2,
    );

    // 3. 关键词精确匹配
    final keywordResults = await _searchByKeywords(keywords);

    // 4. 根据反馈类型过滤
    final filtered = _filterByFeedbackType(
      [...vectorResults, ...keywordResults],
      feedbackType,
    );

    // 5. 排序去重
    return _rankAndDeduplicate(filtered, query).take(limit).toList();
  }

  /// 生成智能回复
  Future<SmartReply> generateReply({
    required String userQuery,
    required FeedbackAnalysis analysis,
    required List<KnowledgeItem> knowledge,
  }) async {
    // 获取情绪应对策略
    final strategy = EmotionalResponseStrategy.getStrategy(analysis);

    // 构建上下文
    final context = {
      'userQuery': userQuery,
      'emotion': analysis.emotion.name,
      'emotionIntensity': analysis.emotionIntensity,
      'feedbackType': analysis.type.name,
      'openingStyle': strategy.openingStyle.style,
      'toneAdjustment': strategy.toneAdjustment,
      'knowledgeItems': knowledge.map((k) => k.toMap()).toList(),
    };

    // LLM生成回复
    final reply = await _llmService.generateCustomerServiceReply(
      context: context,
      systemPrompt: _buildSystemPrompt(strategy),
    );

    return SmartReply(
      content: reply.content,
      confidence: reply.confidence,
      sources: knowledge.map((k) => k.source).toList(),
      followUpQuestions: reply.suggestedFollowUps,
      needsEscalation: strategy.escalationNeeded || reply.confidence < 0.6,
    );
  }

  /// 构建系统提示词
  String _buildSystemPrompt(ResponseStrategy strategy) {
    return '''
你是AI智能记账的客服助手。请根据以下策略回复用户：

## 开场风格
${strategy.openingStyle.style}

## 语气要求
- 语速：${strategy.toneAdjustment.speed}
- 正式度：${strategy.toneAdjustment.formality}
- 温暖度：${strategy.toneAdjustment.warmth}
- 直接度：${strategy.toneAdjustment.directness}
- 避免使用：${strategy.toneAdjustment.avoidWords.join('、')}
- 建议使用：${strategy.toneAdjustment.useWords.join('、')}

## 回复原则
1. 先共情，再解决问题
2. 给出具体的操作步骤
3. 如果不确定，诚实告知并提供替代方案
4. 结尾询问是否还有其他问题

## 禁止事项
1. 不要推卸责任
2. 不要使用机械化模板语言
3. 不要忽视用户的情绪
''';
  }
}

/// 知识条目
class KnowledgeItem {
  final String id;
  final String type;           // feature, faq, troubleshooting
  final String title;
  final String content;
  final String source;         // 来源文档
  final List<String> keywords;
  final double relevanceScore;
  final Map<String, dynamic> metadata;

  KnowledgeItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.source,
    required this.keywords,
    this.relevanceScore = 0,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'title': title,
    'content': content,
    'source': source,
    'keywords': keywords,
  };
}

/// 智能回复
class SmartReply {
  final String content;
  final double confidence;
  final List<String> sources;
  final List<String> followUpQuestions;
  final bool needsEscalation;

  SmartReply({
    required this.content,
    required this.confidence,
    required this.sources,
    required this.followUpQuestions,
    required this.needsEscalation,
  });
}
```

##### 15.12.10.4 问题工单系统

```dart
/// 问题工单服务
class FeedbackTicketService {
  final ApiService _apiService;
  final LocalStorage _localStorage;

  /// 创建反馈工单
  Future<FeedbackTicket> createTicket({
    required String userId,
    required String content,
    required FeedbackAnalysis analysis,
    SmartReply? autoReply,
  }) async {
    final ticket = FeedbackTicket(
      id: generateTicketId(),
      userId: userId,
      content: content,
      type: analysis.type,
      emotion: analysis.emotion,
      urgency: analysis.urgency,
      status: TicketStatus.open,
      autoReplyContent: autoReply?.content,
      autoReplyConfidence: autoReply?.confidence ?? 0,
      needsHumanReview: autoReply?.needsEscalation ?? true,
      createdAt: DateTime.now(),
      metadata: {
        'emotionIntensity': analysis.emotionIntensity,
        'keywords': analysis.keywords,
        'relatedFeature': analysis.relatedFeature,
        'deviceInfo': await _getDeviceInfo(),
        'appVersion': await _getAppVersion(),
      },
    );

    // 上报到服务器
    await _apiService.post('/feedback/tickets', ticket.toJson());

    // 本地缓存
    await _localStorage.saveTicket(ticket);

    return ticket;
  }

  /// 批量同步未上报的工单
  Future<void> syncPendingTickets() async {
    final pending = await _localStorage.getPendingTickets();
    for (final ticket in pending) {
      try {
        await _apiService.post('/feedback/tickets', ticket.toJson());
        await _localStorage.markTicketSynced(ticket.id);
      } catch (e) {
        debugPrint('Failed to sync ticket ${ticket.id}: $e');
      }
    }
  }
}

/// 反馈工单
class FeedbackTicket {
  final String id;
  final String userId;
  final String content;
  final FeedbackType type;
  final EmotionType emotion;
  final UrgencyLevel urgency;
  final TicketStatus status;
  final String? autoReplyContent;
  final double autoReplyConfidence;
  final bool needsHumanReview;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? assignedTo;
  final List<TicketReply> replies;
  final Map<String, dynamic> metadata;
  final UserSatisfaction? satisfaction;

  FeedbackTicket({
    required this.id,
    required this.userId,
    required this.content,
    required this.type,
    required this.emotion,
    required this.urgency,
    required this.status,
    this.autoReplyContent,
    this.autoReplyConfidence = 0,
    this.needsHumanReview = false,
    required this.createdAt,
    this.resolvedAt,
    this.assignedTo,
    this.replies = const [],
    this.metadata = const {},
    this.satisfaction,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'content': content,
    'type': type.name,
    'emotion': emotion.name,
    'urgency': urgency.name,
    'status': status.name,
    'autoReplyContent': autoReplyContent,
    'autoReplyConfidence': autoReplyConfidence,
    'needsHumanReview': needsHumanReview,
    'createdAt': createdAt.toIso8601String(),
    'metadata': metadata,
  };
}

/// 工单状态
enum TicketStatus {
  open,           // 新建
  autoReplied,    // 已自动回复
  pending,        // 等待人工处理
  inProgress,     // 处理中
  resolved,       // 已解决
  closed,         // 已关闭
  reopened,       // 重新打开
}

/// 用户满意度
class UserSatisfaction {
  final int rating;           // 1-5星
  final bool helpful;         // 是否有帮助
  final String? comment;      // 评价内容
  final DateTime ratedAt;

  UserSatisfaction({
    required this.rating,
    required this.helpful,
    this.comment,
    required this.ratedAt,
  });
}
```

##### 15.12.10.5 答复质量评估与优化

```dart
/// 答复质量评估服务
class ReplyQualityService {
  final ApiService _apiService;
  final LLMService _llmService;

  /// 评估维度
  static const evaluationDimensions = {
    'accuracy': '准确性 - 回答是否正确解决了用户问题',
    'relevance': '相关性 - 回答是否切题',
    'completeness': '完整性 - 回答是否全面',
    'empathy': '共情度 - 是否体现了对用户情绪的理解',
    'actionability': '可操作性 - 是否给出了具体的操作步骤',
    'clarity': '清晰度 - 表达是否清晰易懂',
  };

  /// 收集用户满意度反馈
  Future<void> collectSatisfaction({
    required String ticketId,
    required int rating,
    required bool helpful,
    String? comment,
  }) async {
    await _apiService.post('/feedback/satisfaction', {
      'ticketId': ticketId,
      'rating': rating,
      'helpful': helpful,
      'comment': comment,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 定期分析回复质量
  Future<QualityAnalysisReport> analyzeReplyQuality({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. 获取时间段内的所有工单
    final tickets = await _apiService.get('/feedback/tickets', params: {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'hasAutoReply': true,
    });

    // 2. 按类型分组分析
    final analysisResults = <FeedbackType, TypeAnalysis>{};

    for (final type in FeedbackType.values) {
      final typeTickets = tickets.where((t) => t.type == type).toList();
      if (typeTickets.isEmpty) continue;

      analysisResults[type] = await _analyzeTypeQuality(typeTickets);
    }

    // 3. 识别问题模式
    final patterns = await _identifyProblemPatterns(tickets);

    // 4. 生成优化建议
    final suggestions = await _generateOptimizationSuggestions(
      analysisResults,
      patterns,
    );

    return QualityAnalysisReport(
      period: DateRange(start: startDate, end: endDate),
      totalTickets: tickets.length,
      overallSatisfaction: _calculateOverallSatisfaction(tickets),
      typeAnalysis: analysisResults,
      problemPatterns: patterns,
      optimizationSuggestions: suggestions,
    );
  }

  /// 分析特定类型的回复质量
  Future<TypeAnalysis> _analyzeTypeQuality(List<FeedbackTicket> tickets) async {
    final withSatisfaction = tickets.where((t) => t.satisfaction != null).toList();

    // 满意度统计
    final avgRating = withSatisfaction.isEmpty ? 0.0 :
        withSatisfaction.map((t) => t.satisfaction!.rating).average;

    final helpfulRate = withSatisfaction.isEmpty ? 0.0 :
        withSatisfaction.where((t) => t.satisfaction!.helpful).length /
        withSatisfaction.length;

    // 自动回复成功率
    final autoReplySuccess = tickets.where((t) =>
        t.autoReplyConfidence > 0.7 &&
        (t.satisfaction?.helpful ?? false)
    ).length / tickets.length;

    // 升级率
    final escalationRate = tickets.where((t) => t.needsHumanReview).length /
        tickets.length;

    // 常见问题提取
    final commonIssues = await _extractCommonIssues(tickets);

    // 低分回复分析
    final lowRatedReplies = withSatisfaction
        .where((t) => t.satisfaction!.rating <= 2)
        .toList();
    final lowRatedAnalysis = await _analyzeLowRatedReplies(lowRatedReplies);

    return TypeAnalysis(
      totalCount: tickets.length,
      avgRating: avgRating,
      helpfulRate: helpfulRate,
      autoReplySuccessRate: autoReplySuccess,
      escalationRate: escalationRate,
      commonIssues: commonIssues,
      lowRatedAnalysis: lowRatedAnalysis,
    );
  }

  /// 识别问题模式
  Future<List<ProblemPattern>> _identifyProblemPatterns(
    List<FeedbackTicket> tickets,
  ) async {
    // 使用LLM分析工单内容，识别反复出现的问题模式
    final contents = tickets.map((t) => t.content).toList();

    final patterns = await _llmService.identifyPatterns(
      texts: contents,
      minOccurrence: 3,  // 至少出现3次
    );

    return patterns.map((p) => ProblemPattern(
      pattern: p.description,
      frequency: p.count,
      examples: p.examples,
      suggestedAction: p.suggestedAction,
    )).toList();
  }

  /// 生成优化建议
  Future<List<OptimizationSuggestion>> _generateOptimizationSuggestions(
    Map<FeedbackType, TypeAnalysis> typeAnalysis,
    List<ProblemPattern> patterns,
  ) async {
    final suggestions = <OptimizationSuggestion>[];

    // 1. 基于低满意度类型生成建议
    for (final entry in typeAnalysis.entries) {
      if (entry.value.avgRating < 3.5) {
        suggestions.add(OptimizationSuggestion(
          type: SuggestionType.improveReply,
          target: entry.key.name,
          description: '${entry.key.name}类型的回复满意度较低(${entry.value.avgRating.toStringAsFixed(1)}分)，'
              '建议优化该类型的回复策略',
          priority: entry.value.avgRating < 3.0 ? 'high' : 'medium',
          actions: entry.value.lowRatedAnalysis.suggestedImprovements,
        ));
      }
    }

    // 2. 基于高频问题模式生成建议
    for (final pattern in patterns.where((p) => p.frequency >= 5)) {
      suggestions.add(OptimizationSuggestion(
        type: SuggestionType.addKnowledge,
        target: pattern.pattern,
        description: '发现高频问题模式：${pattern.pattern}，出现${pattern.frequency}次',
        priority: 'high',
        actions: [
          '在知识库中添加针对性解答',
          '考虑在帮助文档中增加相关说明',
          pattern.suggestedAction,
        ],
      ));
    }

    // 3. 基于升级率生成建议
    final highEscalationTypes = typeAnalysis.entries
        .where((e) => e.value.escalationRate > 0.5)
        .toList();

    for (final entry in highEscalationTypes) {
      suggestions.add(OptimizationSuggestion(
        type: SuggestionType.improveAutoReply,
        target: entry.key.name,
        description: '${entry.key.name}类型的工单升级率过高(${(entry.value.escalationRate * 100).toStringAsFixed(0)}%)，'
            '建议增强自动回复能力',
        priority: 'medium',
        actions: [
          '扩充该类型的知识库内容',
          '优化意图识别准确度',
          '增加更多回复模板',
        ],
      ));
    }

    return suggestions;
  }

  /// 自动应用优化
  Future<void> applyOptimizations(List<OptimizationSuggestion> suggestions) async {
    for (final suggestion in suggestions.where((s) => s.autoApplicable)) {
      switch (suggestion.type) {
        case SuggestionType.addKnowledge:
          // 自动生成知识条目
          await _autoGenerateKnowledge(suggestion);
          break;

        case SuggestionType.improveReply:
          // 调整回复策略参数
          await _adjustReplyStrategy(suggestion);
          break;

        case SuggestionType.improveAutoReply:
          // 更新自动回复规则
          await _updateAutoReplyRules(suggestion);
          break;
      }
    }
  }
}

/// 质量分析报告
class QualityAnalysisReport {
  final DateRange period;
  final int totalTickets;
  final double overallSatisfaction;
  final Map<FeedbackType, TypeAnalysis> typeAnalysis;
  final List<ProblemPattern> problemPatterns;
  final List<OptimizationSuggestion> optimizationSuggestions;

  QualityAnalysisReport({
    required this.period,
    required this.totalTickets,
    required this.overallSatisfaction,
    required this.typeAnalysis,
    required this.problemPatterns,
    required this.optimizationSuggestions,
  });
}

/// 类型分析
class TypeAnalysis {
  final int totalCount;
  final double avgRating;
  final double helpfulRate;
  final double autoReplySuccessRate;
  final double escalationRate;
  final List<String> commonIssues;
  final LowRatedAnalysis lowRatedAnalysis;

  TypeAnalysis({
    required this.totalCount,
    required this.avgRating,
    required this.helpfulRate,
    required this.autoReplySuccessRate,
    required this.escalationRate,
    required this.commonIssues,
    required this.lowRatedAnalysis,
  });
}

/// 问题模式
class ProblemPattern {
  final String pattern;
  final int frequency;
  final List<String> examples;
  final String suggestedAction;

  ProblemPattern({
    required this.pattern,
    required this.frequency,
    required this.examples,
    required this.suggestedAction,
  });
}

/// 优化建议
class OptimizationSuggestion {
  final SuggestionType type;
  final String target;
  final String description;
  final String priority;
  final List<String> actions;
  final bool autoApplicable;

  OptimizationSuggestion({
    required this.type,
    required this.target,
    required this.description,
    required this.priority,
    required this.actions,
    this.autoApplicable = false,
  });
}

enum SuggestionType {
  addKnowledge,     // 添加知识
  improveReply,     // 优化回复
  improveAutoReply, // 提升自动回复
  escalateToAdmin,  // 升级给管理员
}
```

##### 15.12.10.6 管理员工单系统

```dart
/// 管理员工单处理服务（后端API）
class AdminTicketService {
  /// 获取待处理工单列表
  Future<List<FeedbackTicket>> getPendingTickets({
    UrgencyLevel? urgency,
    FeedbackType? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    // 优先级排序：紧急度 > 情绪强度 > 创建时间
    return await _queryTickets(
      status: [TicketStatus.pending, TicketStatus.open],
      urgency: urgency,
      type: type,
      orderBy: ['urgency DESC', 'emotionIntensity DESC', 'createdAt ASC'],
      page: page,
      pageSize: pageSize,
    );
  }

  /// 智能分配工单
  Future<void> autoAssignTickets() async {
    final pendingTickets = await getPendingTickets();
    final availableAdmins = await _getAvailableAdmins();

    for (final ticket in pendingTickets) {
      // 根据问题类型匹配专长管理员
      final bestAdmin = _findBestAdmin(ticket, availableAdmins);

      if (bestAdmin != null) {
        await assignTicket(ticket.id, bestAdmin.id);
      }
    }
  }

  /// 生成系统问题单
  /// 当知识库无法回答且无法自动解决时
  Future<SystemIssue> createSystemIssue({
    required String ticketId,
    required String description,
    required String suggestedSolution,
  }) async {
    final issue = SystemIssue(
      id: generateIssueId(),
      sourceTicketId: ticketId,
      type: _classifyIssueType(description),
      description: description,
      suggestedSolution: suggestedSolution,
      status: IssueStatus.open,
      priority: _calculateIssuePriority(ticketId),
      createdAt: DateTime.now(),
    );

    await _saveSystemIssue(issue);

    // 通知管理员
    await _notifyAdmins(issue);

    return issue;
  }

  /// 从解决的问题中学习
  Future<void> learnFromResolution({
    required String ticketId,
    required String resolution,
    required bool addToKnowledge,
  }) async {
    if (addToKnowledge) {
      final ticket = await _getTicket(ticketId);

      // 生成新的知识条目
      final knowledge = KnowledgeItem(
        id: generateKnowledgeId(),
        type: 'faq',
        title: _generateTitle(ticket.content),
        content: resolution,
        source: 'admin_resolution',
        keywords: await _extractKeywords(ticket.content),
      );

      await _knowledgeService.addKnowledge(knowledge);
    }
  }
}

/// 系统问题单
class SystemIssue {
  final String id;
  final String sourceTicketId;
  final IssueType type;
  final String description;
  final String suggestedSolution;
  final IssueStatus status;
  final String priority;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolution;

  SystemIssue({
    required this.id,
    required this.sourceTicketId,
    required this.type,
    required this.description,
    required this.suggestedSolution,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
  });
}

enum IssueType {
  bugFix,           // 需要修复的Bug
  featureGap,       // 功能缺失
  documentationGap, // 文档缺失
  knowledgeGap,     // 知识库缺失
  uxIssue,          // 用户体验问题
}

enum IssueStatus {
  open,
  inProgress,
  resolved,
  wontFix,
}
```

##### 15.12.10.7 语音反馈交互流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        语音反馈完整交互流程                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  用户: "这个预算功能太难用了，我设置了半天都没成功，真是气死人了！"               │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         Step 1: 多维度分析                               │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │  • 类型: 功能问题 (bugReport/experienceSuggestion)                       │   │
│  │  • 情绪: 愤怒 (angry), 强度: 0.75                                        │   │
│  │  • 紧急度: 中等 (medium)                                                 │   │
│  │  • 关键词: [预算, 功能, 难用, 设置, 失败]                                  │   │
│  │  • 相关功能: budget_management                                           │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         Step 2: 知识库检索                               │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │  检索结果:                                                               │   │
│  │  1. [FAQ] 如何设置分类预算 (相关度: 0.92)                                 │   │
│  │  2. [Troubleshooting] 预算设置常见问题 (相关度: 0.88)                     │   │
│  │  3. [Feature] 预算管理功能说明 (相关度: 0.85)                             │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         Step 3: 情绪应对策略                             │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │  • 开场风格: 理解共情                                                    │   │
│  │  • 语气: 温和、正式、避免转折词                                          │   │
│  │  • 关键词: 理解、抱歉、一定、马上                                         │   │
│  └─────────────────────────────────────��───────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         Step 4: 生成回复                                 │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                         │   │
│  │  AI回复:                                                                │   │
│  │                                                                         │   │
│  │  "理解您的心情，预算设置不成功确实让人着急。让我来帮您解决这个问题。      │   │
│  │                                                                         │   │
│  │   预算设置的正确步骤是：                                                 │   │
│  │   1. 进入【预算】页面                                                   │   │
│  │   2. 点击想要设置的分类（如餐饮）                                        │   │
│  │   3. 在弹出的页面中输入预算金额                                          │   │
│  │   4. 点击【保存】按钮                                                   │   │
│  │                                                                         │   │
│  │   常见问题：如果保存时提示失败，请检查：                                  │   │
│  │   • 金额是否为正数                                                      │   │
│  │   • 网络是否正常连接                                                    │   │
│  │                                                                         │   │
│  │   您可以按照这个步骤再试一次，或者告诉我具体是哪一步出了问题，            │   │
│  │   我来帮您进一步排查。"                                                  │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         Step 5: 后续跟进                                 │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │  • 创建工单: #FB-20260103-0042                                          │   │
│  │  • 工单状态: 已自动回复                                                  │   │
│  │  • 满意度收集: 等待用户反馈                                              │   │
│  │  • 后续提问建议: ["还有哪一步不清楚？", "问题解决了吗？"]                 │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.10.8 情绪应对示例库

| 用户情绪 | 用户表达示例 | AI应对策略 | AI回复示例 |
|---------|------------|-----------|-----------|
| **愤怒** | "什么垃圾软件，数据都丢了！" | 诚恳道歉+快速响应+解决方案 | "非常抱歉给您带来这么糟糕的体验！数据对您非常重要，我完全理解您现在的心情。请您先别担心，让我马上帮您看看能否恢复数据..." |
| **焦虑** | "急！我的记录找不到了怎么办" | 安抚+确定性承诺+快速方案 | "别担心，记录很可能还在。请您按以下步骤检查：1. 看看是否切换了时间筛选... 2. 检查是否在其他账户... 我们一定能找到！" |
| **沮丧** | "算了，这功能我学不会" | 温暖鼓励+简化引导+陪伴 | "别灰心！这个功能确实需要熟悉一下，但其实很简单。让我用最简单的方式教您，就三步，保证您能学会..." |
| **困惑** | "这个钱龄是啥意思啊，看不懂" | 耐心解释+类比说明+举例 | "钱龄其实很好理解，就像食物有保质期一样。比如您今天花的100块，可能是上个月15号发的工资，那这笔钱的'年龄'就是15天。钱龄越短说明您的资金周转越健康..." |
| **讽刺** | "这预算功能设计得真'好'啊" | 真诚接受+承认不足+改进承诺 | "感谢您的反馈，看得出预算功能确实没有达到您的期望。能具体说说是哪里让您觉得不好用吗？您的意见对我们改进非常重要。" |
| **积极** | "这个语音记账太方便了！" | 热情回应+引导深入使用 | "太高兴您喜欢语音记账！除了单笔记账，您还可以说'早餐15，午餐30，晚餐50'一次记多笔哦，更方便！" |

##### 15.12.10.9 系统集成与数据流

| 集成系统 | 数据流向 | 用途 |
|---------|---------|------|
| **知识库系统** | 设计文档 → 知识库 → 智能回复 | 自动生成帮助内容，支撑智能问答 |
| **工单系统** | 用户反馈 → 工单 → 管理后台 | 问题追踪与闭环管理 |
| **质量评估系统** | 满意度数据 → 分析报告 → 优化建议 | 持续改进回复质量 |
| **用户画像系统** | 历史交互 → 用户画像 → 个性化回复 | 提供更贴合用户的服务 |
| **运营监控系统** | 工单统计 → 监控大盘 → 告警 | 及时发现问题趋势 |

##### 15.12.10.10 目标达成检测

```dart
/// 智能反馈系统验收标准
class VoiceFeedbackAcceptanceCriteria {
  /// 功能完整性
  static final functionalChecks = {
    '反馈收集': [
      '支持语音反馈输入',
      '自动转文字并存储',
      '支持追加说明和图片',
    ],
    '智能分析': [
      '反馈类型自动分类准确率 > 85%',
      '情绪识别准确率 > 80%',
      '紧急程度判断合理',
    ],
    '智能回复': [
      '知识库匹配率 > 70%',
      '回复相关性 > 80%',
      '情绪应对策略正确应用',
    ],
    '工单管理': [
      '工单自动创建和分类',
      '优先级自动设定',
      '状态流转完整',
    ],
    '质量优化': [
      '满意度数据收集完整',
      '定期生成质量分析报告',
      '优化建议可执行',
    ],
  };

  /// 性能指标
  static final performanceMetrics = {
    '反馈分析延迟': '< 2秒',
    '知识检索延迟': '< 1秒',
    '回复生成延迟': '< 3秒',
    '端到端响应时间': '< 5秒',
  };

  /// 质量指标
  static final qualityMetrics = {
    '自动回复满意度': '> 3.5分 (5分制)',
    '自动回复有效率': '> 60%',  // 用户认为有帮助的比例
    '人工升级率': '< 30%',       // 需要人工介入的比例
    '问题解决率': '> 80%',       // 首次回复即解决的比例
  };
}
```
