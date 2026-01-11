import 'package:flutter/foundation.dart';

/// 智能语音反馈与客服系统
///
/// 对应设计文档第18.10节
/// 功能：
/// 1. 反馈类型识别
/// 2. 情绪识别与应对
/// 3. 智能知识库匹配
/// 4. 问题工单生成
/// 5. 答复质量评估

// ==================== 反馈类型与情绪 ====================

/// 反馈类型
enum FeedbackType {
  /// Bug反馈
  bugReport,

  /// 功能建议
  featureSuggestion,

  /// 体验问题
  experienceIssue,

  /// 问题咨询
  questionInquiry,

  /// 投诉抱怨
  complaint,

  /// 表扬鼓励
  praise,

  /// 一般反馈
  general,
}

/// 情绪类型
enum EmotionType {
  /// 满意
  satisfied,

  /// 中性
  neutral,

  /// 困惑
  confused,

  /// 不满
  dissatisfied,

  /// 愤怒
  angry,

  /// 焦虑
  anxious,

  /// 开心
  happy,
}

/// 紧急度
enum UrgencyLevel {
  /// 紧急
  urgent,

  /// 重要
  important,

  /// 一般
  normal,

  /// 低优先级
  low,
}

// ==================== 数据模型 ====================

/// 反馈分析结果
class FeedbackAnalysis {
  /// 反馈类型
  final FeedbackType type;

  /// 情绪类型
  final EmotionType emotion;

  /// 情绪强度 (0-1)
  final double emotionIntensity;

  /// 紧急度
  final UrgencyLevel urgency;

  /// 关键词列表
  final List<String> keywords;

  /// 相关功能
  final String? relatedFeature;

  /// 置信度
  final double confidence;

  /// 原始文本
  final String originalText;

  /// 分析时间
  final DateTime analyzedAt;

  const FeedbackAnalysis({
    required this.type,
    required this.emotion,
    required this.emotionIntensity,
    required this.urgency,
    required this.keywords,
    this.relatedFeature,
    required this.confidence,
    required this.originalText,
    required this.analyzedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'emotion': emotion.name,
        'emotion_intensity': emotionIntensity,
        'urgency': urgency.name,
        'keywords': keywords,
        'related_feature': relatedFeature,
        'confidence': confidence,
        'original_text': originalText,
        'analyzed_at': analyzedAt.toIso8601String(),
      };
}

/// 知识库匹配结果
class KnowledgeMatch {
  /// 匹配的问题ID
  final String questionId;

  /// 问题标题
  final String title;

  /// 答案内容
  final String answer;

  /// 相关度 (0-1)
  final double relevance;

  /// 分类
  final String category;

  /// 相关链接
  final List<String>? relatedLinks;

  const KnowledgeMatch({
    required this.questionId,
    required this.title,
    required this.answer,
    required this.relevance,
    required this.category,
    this.relatedLinks,
  });
}

/// 情绪应对策略
class EmotionStrategy {
  /// 开场风格
  final String openingStyle;

  /// 语气建议
  final List<String> toneGuidelines;

  /// 推荐关键词
  final List<String> recommendedKeywords;

  /// 避免关键词
  final List<String> avoidKeywords;

  /// 是否需要升级人工
  final bool shouldEscalate;

  const EmotionStrategy({
    required this.openingStyle,
    required this.toneGuidelines,
    required this.recommendedKeywords,
    required this.avoidKeywords,
    this.shouldEscalate = false,
  });
}

/// 工单
class FeedbackTicket {
  /// 工单ID
  final String ticketId;

  /// 用户ID
  final String userId;

  /// 反馈分析
  final FeedbackAnalysis analysis;

  /// 自动回复内容
  final String? autoReply;

  /// 工单状态
  final TicketStatus status;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 用户满意度评分 (1-5)
  final int? satisfactionScore;

  /// 处理人
  final String? assignedTo;

  /// SLA截止时间
  final DateTime? slaDueTime;

  const FeedbackTicket({
    required this.ticketId,
    required this.userId,
    required this.analysis,
    this.autoReply,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.satisfactionScore,
    this.assignedTo,
    this.slaDueTime,
  });

  FeedbackTicket copyWith({
    TicketStatus? status,
    String? autoReply,
    int? satisfactionScore,
    String? assignedTo,
  }) {
    return FeedbackTicket(
      ticketId: ticketId,
      userId: userId,
      analysis: analysis,
      autoReply: autoReply ?? this.autoReply,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      satisfactionScore: satisfactionScore ?? this.satisfactionScore,
      assignedTo: assignedTo ?? this.assignedTo,
      slaDueTime: slaDueTime,
    );
  }
}

/// 工单状态
enum TicketStatus {
  /// 新建
  created,

  /// 已自动回复
  autoReplied,

  /// 待处理
  pending,

  /// 处理中
  inProgress,

  /// 已解决
  resolved,

  /// 已关闭
  closed,
}

/// 智能回复
class SmartReply {
  /// 回复文本
  final String text;

  /// 语音播报文本
  final String? spokenText;

  /// 情感色彩
  final EmotionType tone;

  /// 建议操作
  final List<SuggestedFeedbackAction>? suggestedActions;

  /// 后续问题建议
  final List<String>? followUpQuestions;

  /// 是否需要人工介入
  final bool needsHumanIntervention;

  const SmartReply({
    required this.text,
    this.spokenText,
    required this.tone,
    this.suggestedActions,
    this.followUpQuestions,
    this.needsHumanIntervention = false,
  });
}

/// 建议操作
class SuggestedFeedbackAction {
  final String label;
  final String actionType;
  final String? route;
  final Map<String, dynamic>? params;

  const SuggestedFeedbackAction({
    required this.label,
    required this.actionType,
    this.route,
    this.params,
  });
}

// ==================== 服务实现 ====================

/// 语音反馈与客服服务
///
/// 对应设计文档第18.10节
class VoiceFeedbackService extends ChangeNotifier {
  final KnowledgeBaseService _knowledgeBase;
  final EmotionAnalyzer _emotionAnalyzer;
  final TicketManager _ticketManager;

  // 工单缓存
  final Map<String, FeedbackTicket> _ticketCache = {};

  VoiceFeedbackService({
    KnowledgeBaseService? knowledgeBase,
    EmotionAnalyzer? emotionAnalyzer,
    TicketManager? ticketManager,
  })  : _knowledgeBase = knowledgeBase ?? KnowledgeBaseService(),
        _emotionAnalyzer = emotionAnalyzer ?? EmotionAnalyzer(),
        _ticketManager = ticketManager ?? TicketManager();

  /// 处理用户反馈
  Future<SmartReply> handleFeedback({
    required String userId,
    required String input,
    Map<String, dynamic>? context,
  }) async {
    // 1. 分析反馈
    final analysis = analyzeFeedback(input);

    // 2. 获取情绪应对策略
    final strategy = _emotionAnalyzer.getStrategy(analysis.emotion);

    // 3. 知识库检索
    final matches = await _knowledgeBase.search(
      query: input,
      keywords: analysis.keywords,
      category: analysis.relatedFeature,
    );

    // 4. 生成智能回复
    final reply = _generateReply(analysis, strategy, matches);

    // 5. 创建工单
    final ticket = await _ticketManager.createTicket(
      userId: userId,
      analysis: analysis,
      autoReply: reply.text,
    );

    _ticketCache[ticket.ticketId] = ticket;
    notifyListeners();

    return reply;
  }

  /// 分析反馈
  FeedbackAnalysis analyzeFeedback(String text) {
    final lowerText = text.toLowerCase();

    // 检测反馈类型
    final type = _detectFeedbackType(lowerText);

    // 检测情绪
    final emotionResult = _emotionAnalyzer.analyze(text);

    // 检测紧急度
    final urgency = _detectUrgency(lowerText, emotionResult.emotion);

    // 提取关键词
    final keywords = _extractKeywords(text);

    // 检测相关功能
    final relatedFeature = _detectRelatedFeature(lowerText);

    return FeedbackAnalysis(
      type: type,
      emotion: emotionResult.emotion,
      emotionIntensity: emotionResult.intensity,
      urgency: urgency,
      keywords: keywords,
      relatedFeature: relatedFeature,
      confidence: emotionResult.confidence,
      originalText: text,
      analyzedAt: DateTime.now(),
    );
  }

  /// 检测反馈类型
  FeedbackType _detectFeedbackType(String text) {
    // Bug相关
    if (_containsAny(text, ['bug', '崩溃', '闪退', '报错', '出错', '无法', '失败', '卡死'])) {
      return FeedbackType.bugReport;
    }

    // 功能建议
    if (_containsAny(text, ['建议', '希望', '能不能', '最好', '应该', '增加', '添加'])) {
      return FeedbackType.featureSuggestion;
    }

    // 体验问题
    if (_containsAny(text, ['难用', '复杂', '找不到', '不方便', '不好用', '麻烦'])) {
      return FeedbackType.experienceIssue;
    }

    // 咨询
    if (_containsAny(text, ['怎么', '如何', '在哪', '是什么', '为什么'])) {
      return FeedbackType.questionInquiry;
    }

    // 投诉
    if (_containsAny(text, ['投诉', '差评', '垃圾', '骗人', '坑'])) {
      return FeedbackType.complaint;
    }

    // 表扬
    if (_containsAny(text, ['好用', '很棒', '喜欢', '感谢', '赞', '好评'])) {
      return FeedbackType.praise;
    }

    return FeedbackType.general;
  }

  /// 检测紧急度
  UrgencyLevel _detectUrgency(String text, EmotionType emotion) {
    // 愤怒情绪提高紧急度
    if (emotion == EmotionType.angry) {
      return UrgencyLevel.urgent;
    }

    // 关键词检测
    if (_containsAny(text, ['紧急', '立刻', '马上', '急', '崩溃', '数据丢失'])) {
      return UrgencyLevel.urgent;
    }

    if (_containsAny(text, ['重要', '关键', '严重', '无法使用'])) {
      return UrgencyLevel.important;
    }

    if (_containsAny(text, ['建议', '希望', '可以考虑'])) {
      return UrgencyLevel.low;
    }

    return UrgencyLevel.normal;
  }

  /// 提取关键词
  List<String> _extractKeywords(String text) {
    final keywords = <String>[];

    // 功能关键词
    const features = [
      '记账', '预算', '统计', '报表', '分类', '账户', '同步', '备份',
      '导入', '导出', '语音', '识别', '钱龄', '小金库', '家庭', '提醒',
    ];

    for (final feature in features) {
      if (text.contains(feature)) {
        keywords.add(feature);
      }
    }

    // 操作关键词
    const actions = [
      '添加', '删除', '修改', '查看', '设置', '打开', '关闭',
    ];

    for (final action in actions) {
      if (text.contains(action)) {
        keywords.add(action);
      }
    }

    return keywords;
  }

  /// 检测相关功能
  String? _detectRelatedFeature(String text) {
    const featureMap = {
      '记账': 'transaction',
      '预算': 'budget',
      '统计': 'statistics',
      '报表': 'report',
      '分类': 'category',
      '账户': 'account',
      '同步': 'sync',
      '备份': 'backup',
      '导入': 'import',
      '导出': 'export',
      '语音': 'voice',
      '识别': 'recognition',
      '钱龄': 'money_age',
      '小金库': 'vault',
      '家庭': 'family',
    };

    for (final entry in featureMap.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// 生成智能回复
  SmartReply _generateReply(
    FeedbackAnalysis analysis,
    EmotionStrategy strategy,
    List<KnowledgeMatch> matches,
  ) {
    final buffer = StringBuffer();
    List<SuggestedFeedbackAction>? actions;
    List<String>? followUpQuestions;
    var needsHuman = false;

    // 根据情绪选择开场
    buffer.write(_getEmotionOpening(analysis.emotion, strategy));

    // 根据反馈类型生成主体内容
    switch (analysis.type) {
      case FeedbackType.bugReport:
        buffer.write('\n\n我已经记录下这个问题，技术团队会尽快排查。');
        if (analysis.relatedFeature != null) {
          buffer.write('问题涉及${analysis.relatedFeature}功能。');
        }
        actions = [
          const SuggestedFeedbackAction(
            label: '查看问题状态',
            actionType: 'navigate',
            route: '/feedback/status',
          ),
          const SuggestedFeedbackAction(
            label: '提交详细描述',
            actionType: 'navigate',
            route: '/feedback/detail',
          ),
        ];
        needsHuman = analysis.urgency == UrgencyLevel.urgent;
        break;

      case FeedbackType.featureSuggestion:
        buffer.write('\n\n感谢您的宝贵建议！我们会认真评估并考虑在后续版本中实现。');
        actions = [
          const SuggestedFeedbackAction(
            label: '查看功能规划',
            actionType: 'navigate',
            route: '/roadmap',
          ),
          const SuggestedFeedbackAction(
            label: '参与功能投票',
            actionType: 'navigate',
            route: '/feature-vote',
          ),
        ];
        break;

      case FeedbackType.experienceIssue:
        buffer.write('\n\n');
        if (matches.isNotEmpty) {
          buffer.write('针对您遇到的问题，这里有一些解决方案：\n');
          buffer.write(matches.first.answer);
        } else {
          buffer.write('我理解这给您带来了不便。我们会持续优化使用体验。');
        }
        actions = [
          const SuggestedFeedbackAction(
            label: '查看帮助中心',
            actionType: 'navigate',
            route: '/help',
          ),
        ];
        break;

      case FeedbackType.questionInquiry:
        buffer.write('\n\n');
        if (matches.isNotEmpty) {
          buffer.write(matches.first.answer);
          followUpQuestions = ['还有其他问题吗？', '这个解答对您有帮助吗？'];
        } else {
          buffer.write('这个问题我需要进一步确认，稍后会有专人回复您。');
          needsHuman = true;
        }
        actions = [
          const SuggestedFeedbackAction(
            label: '查看更多帮助',
            actionType: 'navigate',
            route: '/help',
          ),
        ];
        break;

      case FeedbackType.complaint:
        buffer.write('\n\n非常抱歉给您带来不好的体验。我们会认真对待您的反馈并尽快改进。');
        needsHuman = true;
        actions = [
          const SuggestedFeedbackAction(
            label: '联系客服',
            actionType: 'contact',
            route: '/customer-service',
          ),
        ];
        break;

      case FeedbackType.praise:
        buffer.write('\n\n您的认可是我们最大的动力！我们会继续努力做得更好。');
        actions = [
          const SuggestedFeedbackAction(
            label: '分享给朋友',
            actionType: 'share',
          ),
          const SuggestedFeedbackAction(
            label: '给个好评',
            actionType: 'rate',
          ),
        ];
        break;

      case FeedbackType.general:
        buffer.write('\n\n感谢您的反馈，我们会认真对待每一条建议。');
        break;
    }

    return SmartReply(
      text: buffer.toString(),
      tone: analysis.emotion,
      suggestedActions: actions,
      followUpQuestions: followUpQuestions,
      needsHumanIntervention: needsHuman,
    );
  }

  /// 获取情绪化开场白
  String _getEmotionOpening(EmotionType emotion, EmotionStrategy strategy) {
    switch (emotion) {
      case EmotionType.angry:
        return '非常理解您的心情，这确实让人着急。';
      case EmotionType.anxious:
        return '别担心，让我来帮您解决这个问题。';
      case EmotionType.dissatisfied:
        return '抱歉给您带来了不好的体验。';
      case EmotionType.confused:
        return '我来为您解答。';
      case EmotionType.happy:
      case EmotionType.satisfied:
        return '很高兴您有好的体验！';
      case EmotionType.neutral:
        return '感谢您的反馈。';
    }
  }

  /// 收集满意度评价
  Future<void> collectSatisfaction({
    required String ticketId,
    required int score,
    String? comment,
  }) async {
    final ticket = _ticketCache[ticketId];
    if (ticket != null) {
      _ticketCache[ticketId] = ticket.copyWith(
        satisfactionScore: score,
        status: TicketStatus.closed,
      );
      notifyListeners();
    }
  }

  /// 获取工单
  FeedbackTicket? getTicket(String ticketId) => _ticketCache[ticketId];

  /// 获取所有工单
  List<FeedbackTicket> getAllTickets() => _ticketCache.values.toList();

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}

// ==================== 知识库服务 ====================

/// 知识库服务
class KnowledgeBaseService {
  /// 知识库条目
  static final List<_KnowledgeEntry> _entries = [
    _KnowledgeEntry(
      id: 'faq_001',
      title: '如何记账',
      answer: '您可以通过以下方式记账：\n1. 点击首页"+"按钮手动记账\n2. 说"记一笔XX元"语音记账\n3. 拍照识别小票自动记账',
      keywords: ['记账', '添加', '记录'],
      category: 'transaction',
    ),
    _KnowledgeEntry(
      id: 'faq_002',
      title: '如何设置预算',
      answer: '设置预算的步骤：\n1. 进入"预算"页面\n2. 点击要设置的分类\n3. 输入预算金额并保存\n\n您也可以说"设置餐饮预算2000元"来快速设置。',
      keywords: ['预算', '设置', '限额'],
      category: 'budget',
    ),
    _KnowledgeEntry(
      id: 'faq_003',
      title: '如何导入账单',
      answer: '导入账单的步骤：\n1. 从微信/支付宝导出账单文件\n2. 在APP中点击"导入"\n3. 选择账单文件\n4. 确认导入信息',
      keywords: ['导入', '账单', '微信', '支付宝'],
      category: 'import',
    ),
    _KnowledgeEntry(
      id: 'faq_004',
      title: '数据同步失败',
      answer: '同步失败可能的原因：\n1. 网络连接不稳定\n2. 服务器暂时维护\n3. 本地数据与云端冲突\n\n建议：检查网络后重试，或在"设置-同步"中手动同步。',
      keywords: ['同步', '失败', '网络'],
      category: 'sync',
    ),
    _KnowledgeEntry(
      id: 'faq_005',
      title: '什么是钱龄',
      answer: '钱龄是衡量您资金流动效率的指标。钱龄越低，说明您的资金周转越快、使用效率越高。您可以在"钱龄"页面查看详细分析和优化建议。',
      keywords: ['钱龄', '资金', '效率'],
      category: 'money_age',
    ),
    _KnowledgeEntry(
      id: 'faq_006',
      title: '如何创建小金库',
      answer: '创建小金库的步骤：\n1. 进入"预算"页面\n2. 点击"创建小金库"\n3. 输入名称、目标金额\n4. 设置自动存入规则（可选）',
      keywords: ['小金库', '创建', '存钱'],
      category: 'vault',
    ),
    _KnowledgeEntry(
      id: 'faq_007',
      title: '如何邀请家人',
      answer: '邀请家人加入账本：\n1. 进入"家庭账本"\n2. 点击"邀请成员"\n3. 分享邀请链接或二维码\n\n您也可以说"邀请家人"来快速生成邀请。',
      keywords: ['家庭', '邀请', '成员', '共享'],
      category: 'family',
    ),
    _KnowledgeEntry(
      id: 'faq_008',
      title: '语音识别不准确',
      answer: '提高语音识别准确率的建议：\n1. 在安静环境中使用\n2. 清晰地说出金额和分类\n3. 使用标准表达，如"花了35买早餐"\n4. 在设置中开启"语音识别优化"',
      keywords: ['语音', '识别', '不准', '不对'],
      category: 'voice',
    ),
  ];

  /// 搜索知识库
  Future<List<KnowledgeMatch>> search({
    required String query,
    List<String>? keywords,
    String? category,
  }) async {
    final matches = <KnowledgeMatch>[];
    final lowerQuery = query.toLowerCase();

    for (final entry in _entries) {
      var relevance = 0.0;

      // 标题匹配
      if (entry.title.toLowerCase().contains(lowerQuery)) {
        relevance += 0.4;
      }

      // 关键词匹配
      for (final keyword in entry.keywords) {
        if (lowerQuery.contains(keyword) ||
            (keywords?.contains(keyword) ?? false)) {
          relevance += 0.2;
        }
      }

      // 分类匹配
      if (category != null && entry.category == category) {
        relevance += 0.3;
      }

      if (relevance > 0.3) {
        matches.add(KnowledgeMatch(
          questionId: entry.id,
          title: entry.title,
          answer: entry.answer,
          relevance: relevance.clamp(0.0, 1.0),
          category: entry.category,
        ));
      }
    }

    // 按相关度排序
    matches.sort((a, b) => b.relevance.compareTo(a.relevance));

    return matches.take(3).toList();
  }
}

class _KnowledgeEntry {
  final String id;
  final String title;
  final String answer;
  final List<String> keywords;
  final String category;

  const _KnowledgeEntry({
    required this.id,
    required this.title,
    required this.answer,
    required this.keywords,
    required this.category,
  });
}

// ==================== 情绪分析器 ====================

/// 情绪分析器
class EmotionAnalyzer {
  /// 情绪关键词映射
  static const Map<EmotionType, List<String>> _emotionKeywords = {
    EmotionType.angry: ['气死', '愤怒', '什么破', '垃圾', '太差', '坑人', '骗子'],
    EmotionType.anxious: ['担心', '焦虑', '着急', '紧张', '害怕', '不安'],
    EmotionType.dissatisfied: ['不满', '失望', '难用', '差劲', '不好'],
    EmotionType.confused: ['不懂', '不明白', '不理解', '怎么回事', '为什么'],
    EmotionType.happy: ['开心', '高兴', '太好了', '棒', '赞'],
    EmotionType.satisfied: ['不错', '挺好', '满意', '好用', '方便'],
  };

  /// 情绪应对策略
  static const Map<EmotionType, EmotionStrategy> _strategies = {
    EmotionType.angry: EmotionStrategy(
      openingStyle: '理解共情',
      toneGuidelines: ['温和', '正式', '避免转折词'],
      recommendedKeywords: ['理解', '抱歉', '一定', '马上'],
      avoidKeywords: ['但是', '不过', '其实'],
      shouldEscalate: true,
    ),
    EmotionType.anxious: EmotionStrategy(
      openingStyle: '安抚引导',
      toneGuidelines: ['温暖', '耐心', '给予信心'],
      recommendedKeywords: ['别担心', '没关系', '一步步', '帮您'],
      avoidKeywords: ['必须', '应该', '问题'],
    ),
    EmotionType.dissatisfied: EmotionStrategy(
      openingStyle: '诚恳致歉',
      toneGuidelines: ['诚恳', '负责', '解决导向'],
      recommendedKeywords: ['抱歉', '改进', '解决', '帮助'],
      avoidKeywords: ['您误解了', '不是这样'],
    ),
    EmotionType.confused: EmotionStrategy(
      openingStyle: '耐心解答',
      toneGuidelines: ['清晰', '有条理', '循序渐进'],
      recommendedKeywords: ['首先', '然后', '简单来说', '举例'],
      avoidKeywords: ['很简单', '显而易见'],
    ),
    EmotionType.happy: EmotionStrategy(
      openingStyle: '积极回应',
      toneGuidelines: ['热情', '轻松', '互动'],
      recommendedKeywords: ['太好了', '继续', '更好'],
      avoidKeywords: [],
    ),
    EmotionType.satisfied: EmotionStrategy(
      openingStyle: '感谢肯定',
      toneGuidelines: ['感谢', '谦逊', '持续改进'],
      recommendedKeywords: ['感谢', '继续努力', '更好'],
      avoidKeywords: [],
    ),
    EmotionType.neutral: EmotionStrategy(
      openingStyle: '专业友好',
      toneGuidelines: ['专业', '友好', '高效'],
      recommendedKeywords: ['您好', '感谢', '帮助'],
      avoidKeywords: [],
    ),
  };

  /// 分析情绪
  EmotionAnalysisResult analyze(String text) {
    final lowerText = text.toLowerCase();
    var detectedEmotion = EmotionType.neutral;
    var maxScore = 0.0;

    for (final entry in _emotionKeywords.entries) {
      var score = 0.0;
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          score += 1.0 / entry.value.length;
        }
      }
      if (score > maxScore) {
        maxScore = score;
        detectedEmotion = entry.key;
      }
    }

    // 计算情绪强度
    final intensity = _calculateIntensity(lowerText, detectedEmotion);

    return EmotionAnalysisResult(
      emotion: detectedEmotion,
      intensity: intensity,
      confidence: maxScore > 0 ? (0.5 + maxScore * 0.5) : 0.5,
    );
  }

  /// 计算情绪强度
  double _calculateIntensity(String text, EmotionType emotion) {
    var intensity = 0.5;

    // 强调词增加强度
    if (text.contains('非常') || text.contains('特别') || text.contains('太')) {
      intensity += 0.2;
    }

    // 感叹号增加强度
    final exclamationCount = '!！'.split('').where((c) => text.contains(c)).length;
    intensity += exclamationCount * 0.1;

    // 重复词增加强度
    if (RegExp(r'(.)\1{2,}').hasMatch(text)) {
      intensity += 0.1;
    }

    return intensity.clamp(0.0, 1.0);
  }

  /// 获取情绪应对策略
  EmotionStrategy getStrategy(EmotionType emotion) {
    return _strategies[emotion] ?? _strategies[EmotionType.neutral]!;
  }
}

/// 情绪分析结果
class EmotionAnalysisResult {
  final EmotionType emotion;
  final double intensity;
  final double confidence;

  const EmotionAnalysisResult({
    required this.emotion,
    required this.intensity,
    required this.confidence,
  });
}

// ==================== 工单管理器 ====================

/// 工单管理器
class TicketManager {
  final Map<String, FeedbackTicket> _tickets = {};
  int _ticketCounter = 0;

  /// 创建工单
  Future<FeedbackTicket> createTicket({
    required String userId,
    required FeedbackAnalysis analysis,
    String? autoReply,
  }) async {
    _ticketCounter++;
    final now = DateTime.now();
    final ticketId =
        'FB-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${_ticketCounter.toString().padLeft(4, '0')}';

    // 根据紧急度计算SLA
    DateTime? slaDueTime;
    switch (analysis.urgency) {
      case UrgencyLevel.urgent:
        slaDueTime = now.add(const Duration(hours: 4));
        break;
      case UrgencyLevel.important:
        slaDueTime = now.add(const Duration(hours: 24));
        break;
      case UrgencyLevel.normal:
        slaDueTime = now.add(const Duration(hours: 48));
        break;
      case UrgencyLevel.low:
        slaDueTime = now.add(const Duration(days: 7));
        break;
    }

    final ticket = FeedbackTicket(
      ticketId: ticketId,
      userId: userId,
      analysis: analysis,
      autoReply: autoReply,
      status: autoReply != null ? TicketStatus.autoReplied : TicketStatus.created,
      createdAt: now,
      updatedAt: now,
      slaDueTime: slaDueTime,
    );

    _tickets[ticketId] = ticket;
    return ticket;
  }

  /// 更新工单状态
  Future<FeedbackTicket?> updateTicketStatus(
    String ticketId,
    TicketStatus status,
  ) async {
    final ticket = _tickets[ticketId];
    if (ticket != null) {
      final updated = ticket.copyWith(status: status);
      _tickets[ticketId] = updated;
      return updated;
    }
    return null;
  }

  /// 分配工单
  Future<FeedbackTicket?> assignTicket(
    String ticketId,
    String assignee,
  ) async {
    final ticket = _tickets[ticketId];
    if (ticket != null) {
      final updated = ticket.copyWith(
        assignedTo: assignee,
        status: TicketStatus.inProgress,
      );
      _tickets[ticketId] = updated;
      return updated;
    }
    return null;
  }

  /// 获取待处理工单
  List<FeedbackTicket> getPendingTickets() {
    return _tickets.values
        .where((t) =>
            t.status == TicketStatus.created ||
            t.status == TicketStatus.pending)
        .toList();
  }

  /// 获取超时工单
  List<FeedbackTicket> getOverdueTickets() {
    final now = DateTime.now();
    return _tickets.values
        .where((t) =>
            t.slaDueTime != null &&
            t.slaDueTime!.isBefore(now) &&
            t.status != TicketStatus.resolved &&
            t.status != TicketStatus.closed)
        .toList();
  }
}

// ==================== 答复质量评估 ====================

/// 答复质量评估服务
class ReplyQualityService {
  /// 评估指标
  final List<_QualityMetric> _metrics = [];

  /// 记录评价
  void recordFeedback({
    required String ticketId,
    required int satisfactionScore,
    required bool wasHelpful,
    String? comment,
  }) {
    _metrics.add(_QualityMetric(
      ticketId: ticketId,
      score: satisfactionScore,
      wasHelpful: wasHelpful,
      comment: comment,
      timestamp: DateTime.now(),
    ));
  }

  /// 获取平均满意度
  double getAverageSatisfaction() {
    if (_metrics.isEmpty) return 0;
    final total = _metrics.fold(0, (sum, m) => sum + m.score);
    return total / _metrics.length;
  }

  /// 获取帮助率
  double getHelpfulRate() {
    if (_metrics.isEmpty) return 0;
    final helpful = _metrics.where((m) => m.wasHelpful).length;
    return helpful / _metrics.length;
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    return {
      'total_feedbacks': _metrics.length,
      'average_satisfaction': getAverageSatisfaction(),
      'helpful_rate': getHelpfulRate(),
      'score_distribution': _getScoreDistribution(),
    };
  }

  Map<int, int> _getScoreDistribution() {
    final distribution = <int, int>{};
    for (final metric in _metrics) {
      distribution[metric.score] = (distribution[metric.score] ?? 0) + 1;
    }
    return distribution;
  }
}

class _QualityMetric {
  final String ticketId;
  final int score;
  final bool wasHelpful;
  final String? comment;
  final DateTime timestamp;

  const _QualityMetric({
    required this.ticketId,
    required this.score,
    required this.wasHelpful,
    this.comment,
    required this.timestamp,
  });
}
