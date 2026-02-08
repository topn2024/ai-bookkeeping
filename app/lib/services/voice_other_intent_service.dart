import 'package:flutter/foundation.dart';

/// "其他"类别意图类型
///
/// 对应设计文档第18.1.2节
enum OtherIntentType {
  /// 帮助请求 - 用户询问如何使用功能
  helpRequest,

  /// 数据查询 - 用户想了解财务数据解读
  dataQuery,

  /// 情感表达 - 用户表达情绪（抱怨、焦虑、开心等）
  emotionalExpression,

  /// 模糊意图 - 意图不明确，需要澄清
  ambiguousIntent,

  /// 超出范围 - 完全不相关的请求
  outOfScope,

  /// 闲聊 - 日常聊天
  chitChat,

  /// 反馈建议 - 用户提供反馈或建议
  feedback,
}

/// 其他意图分析结果
class OtherIntentAnalysis {
  /// 意图类型
  final OtherIntentType type;

  /// 置信度
  final double confidence;

  /// 提取的关键信息
  final Map<String, dynamic>? extractedInfo;

  /// 原始文本
  final String originalText;

  /// 分析时间
  final DateTime analyzedAt;

  const OtherIntentAnalysis({
    required this.type,
    required this.confidence,
    this.extractedInfo,
    required this.originalText,
    required this.analyzedAt,
  });
}

/// 智能响应
class SmartResponse {
  /// 响应类型
  final ResponseType type;

  /// 主要回复文本
  final String primaryText;

  /// 语音播报文本（可能与显示文本不同）
  final String? spokenText;

  /// 建议的后续操作
  final List<SuggestedAction>? suggestedActions;

  /// 相关帮助链接
  final List<HelpLink>? helpLinks;

  /// 是否需要用户确认
  final bool requiresConfirmation;

  /// 情感色彩
  final EmotionalTone tone;

  const SmartResponse({
    required this.type,
    required this.primaryText,
    this.spokenText,
    this.suggestedActions,
    this.helpLinks,
    this.requiresConfirmation = false,
    this.tone = EmotionalTone.neutral,
  });
}

/// 响应类型
enum ResponseType {
  /// 帮助引导
  helpGuide,

  /// 数据解读
  dataInsight,

  /// 情感陪伴
  emotionalSupport,

  /// 澄清询问
  clarification,

  /// 礼貌拒绝
  politeDecline,

  /// 功能推荐
  featureRecommendation,

  /// 直接回答
  directAnswer,
}

/// 情感色彩
enum EmotionalTone {
  /// 中性
  neutral,

  /// 鼓励
  encouraging,

  /// 同理
  empathetic,

  /// 专业
  professional,

  /// 友好
  friendly,

  /// 幽默
  humorous,
}

/// 建议操作
class SuggestedAction {
  /// 操作标签
  final String label;

  /// 操作路由
  final String? route;

  /// 操作类型
  final String actionType;

  /// 参数
  final Map<String, dynamic>? params;

  const SuggestedAction({
    required this.label,
    this.route,
    required this.actionType,
    this.params,
  });
}

/// 帮助链接
class HelpLink {
  final String title;
  final String url;
  final String? description;

  const HelpLink({
    required this.title,
    required this.url,
    this.description,
  });
}

/// "其他"类别意图智能处理服务
///
/// 对应设计文档第18.1.2节
/// 功能：
/// 1. 分析"其他"类别意图的具体类型
/// 2. 提供智能帮助引导
/// 3. 智能数据解读
/// 4. 情感陪伴响应
/// 5. 模糊意图澄清
/// 6. 超出范围处理
///
/// 使用示例：
/// ```dart
/// final service = VoiceOtherIntentService();
/// final analysis = service.analyzeIntent('这个APP怎么用');
/// final response = service.generateResponse(analysis);
/// ```
class VoiceOtherIntentService extends ChangeNotifier {
  /// 帮助请求关键词
  static const List<String> _helpKeywords = [
    '怎么', '如何', '怎样', '能不能', '可以吗', '在哪', '哪里',
    '教我', '帮我', '告诉我', '是什么', '什么是', '介绍', '说明',
  ];

  /// 数据查询关键词
  static const List<String> _dataQueryKeywords = [
    '花了多少', '消费', '支出', '收入', '余额', '预算', '统计',
    '报表', '分析', '趋势', '对比', '排名', '最多', '最少',
  ];

  /// 闲聊关键词
  static const List<String> _chitChatKeywords = [
    '你好', '嗨', '早上好', '晚上好', '谢谢', '再见', '拜拜',
    '你是谁', '叫什么', '天气', '今天', '周末',
  ];

  /// 反馈关键词
  static const List<String> _feedbackKeywords = [
    '建议', '反馈', '希望', '应该', '最好', '能否', '增加',
    '改进', 'bug', '问题', '不好用', '太慢',
  ];

  /// 功能帮助映射
  static const Map<String, _FeatureHelp> _featureHelps = {
    '记账': _FeatureHelp(
      name: '记账',
      description: '您可以通过语音、拍照或手动输入来记录收支',
      route: '/quick-add',
      tips: ['说"记一笔早餐15块"快速记账', '拍照识别小票自动记账', '支持多币种记账'],
    ),
    '预算': _FeatureHelp(
      name: '预算管理',
      description: '设置月度预算，追踪消费情况，避免超支',
      route: '/budget',
      tips: ['说"设置餐饮预算2000"', '预算超支会自动提醒', '支持按分类设置预算'],
    ),
    '统计': _FeatureHelp(
      name: '统计报表',
      description: '查看收支统计、趋势分析、分类占比等',
      route: '/statistics',
      tips: ['说"本月花了多少"查看消费', '支持按周/月/年查看', '可导出PDF报表'],
    ),
    '导入': _FeatureHelp(
      name: '账单导入',
      description: '从微信、支付宝、银行等导入历史账单',
      route: '/import',
      tips: ['支持微信/支付宝账单', '自动识别分类', '智能去重处理'],
    ),
    '钱龄': _FeatureHelp(
      name: '钱龄分析',
      description: '了解您的资金流动效率，优化理财策略',
      route: '/money-age',
      tips: ['钱龄越低说明资金周转越快', '查看各账户资金年龄', '获取优化建议'],
    ),
    '小金库': _FeatureHelp(
      name: '小金库',
      description: '将资金分配到不同用途的虚拟金库中',
      route: '/budget/vault-list',
      tips: ['创建旅游/教育/应急等金库', '设置自动存入规则', '追踪每个金库进度'],
    ),
    '家庭': _FeatureHelp(
      name: '家庭账本',
      description: '与家人共享账本，AA分摊，查看家庭消费',
      route: '/family',
      tips: ['邀请家人加入账本', '支持AA分摊结算', '查看成员消费对比'],
    ),
  };

  /// 情感响应模板
  static const Map<String, List<String>> _emotionalResponses = {
    '焦虑': [
      '我理解您对财务的担忧。让我们一起看看如何改善？',
      '别担心，理财是个循序渐进的过程。我可以帮您分析一下当前的财务状况。',
      '焦虑是正常的，说明您开始重视财务管理了。我们一步一步来。',
    ],
    '开心': [
      '太棒了！看来您的财务管理很有成效！',
      '继续保持这个好势头！要不要看看您的储蓄进度？',
      '您的进步真的很明显！理财习惯正在养成。',
    ],
    '后悔': [
      '每个人都有冲动消费的时候，重要的是从中学习。',
      '没关系，我们可以一起看看如何调整预算来弥补。',
      '要不要开启冲动防护功能？下次消费前会提醒您冷静一下。',
    ],
    '抱怨': [
      '抱歉给您带来不好的体验。能告诉我具体是什么问题吗？',
      '感谢您的反馈，我们会努力改进的。',
      '您的意见对我们很重要，我已经记录下来了。',
    ],
  };

  /// 分析"其他"意图
  OtherIntentAnalysis analyzeIntent(String text) {
    final lowerText = text.toLowerCase();

    // 检查帮助请求
    if (_containsAnyKeyword(lowerText, _helpKeywords)) {
      final feature = _extractFeature(text);
      return OtherIntentAnalysis(
        type: OtherIntentType.helpRequest,
        confidence: 0.85,
        extractedInfo: {'feature': feature},
        originalText: text,
        analyzedAt: DateTime.now(),
      );
    }

    // 检查数据查询
    if (_containsAnyKeyword(lowerText, _dataQueryKeywords)) {
      return OtherIntentAnalysis(
        type: OtherIntentType.dataQuery,
        confidence: 0.8,
        extractedInfo: _extractQueryParams(text),
        originalText: text,
        analyzedAt: DateTime.now(),
      );
    }

    // 检查情感表达
    final emotion = _detectEmotion(lowerText);
    if (emotion != null) {
      return OtherIntentAnalysis(
        type: OtherIntentType.emotionalExpression,
        confidence: 0.75,
        extractedInfo: {'emotion': emotion},
        originalText: text,
        analyzedAt: DateTime.now(),
      );
    }

    // 检查闲聊
    if (_containsAnyKeyword(lowerText, _chitChatKeywords)) {
      return OtherIntentAnalysis(
        type: OtherIntentType.chitChat,
        confidence: 0.9,
        originalText: text,
        analyzedAt: DateTime.now(),
      );
    }

    // 检查反馈
    if (_containsAnyKeyword(lowerText, _feedbackKeywords)) {
      return OtherIntentAnalysis(
        type: OtherIntentType.feedback,
        confidence: 0.8,
        originalText: text,
        analyzedAt: DateTime.now(),
      );
    }

    // 模糊意图
    if (text.length < 10) {
      return OtherIntentAnalysis(
        type: OtherIntentType.ambiguousIntent,
        confidence: 0.6,
        originalText: text,
        analyzedAt: DateTime.now(),
      );
    }

    // 超出范围
    return OtherIntentAnalysis(
      type: OtherIntentType.outOfScope,
      confidence: 0.5,
      originalText: text,
      analyzedAt: DateTime.now(),
    );
  }

  /// 生成智能响应
  SmartResponse generateResponse(OtherIntentAnalysis analysis) {
    switch (analysis.type) {
      case OtherIntentType.helpRequest:
        return _generateHelpResponse(analysis);

      case OtherIntentType.dataQuery:
        return _generateDataQueryResponse(analysis);

      case OtherIntentType.emotionalExpression:
        return _generateEmotionalResponse(analysis);

      case OtherIntentType.ambiguousIntent:
        return _generateClarificationResponse(analysis);

      case OtherIntentType.chitChat:
        return _generateChitChatResponse(analysis);

      case OtherIntentType.feedback:
        return _generateFeedbackResponse(analysis);

      case OtherIntentType.outOfScope:
        return _generateOutOfScopeResponse(analysis);
    }
  }

  /// 生成帮助响应
  SmartResponse _generateHelpResponse(OtherIntentAnalysis analysis) {
    final feature = analysis.extractedInfo?['feature'] as String?;

    if (feature != null && _featureHelps.containsKey(feature)) {
      final help = _featureHelps[feature]!;
      return SmartResponse(
        type: ResponseType.helpGuide,
        primaryText: help.description,
        spokenText: '${help.name}功能${help.description}',
        suggestedActions: [
          SuggestedAction(
            label: '打开${help.name}',
            route: help.route,
            actionType: 'navigate',
          ),
          const SuggestedAction(
            label: '查看更多帮助',
            route: '/help',
            actionType: 'navigate',
          ),
        ],
        helpLinks: [
          HelpLink(
            title: '${help.name}使用教程',
            url: '/help/tutorial/${feature.toLowerCase()}',
          ),
        ],
        tone: EmotionalTone.friendly,
      );
    }

    // 通用帮助
    return const SmartResponse(
      type: ResponseType.helpGuide,
      primaryText: '我可以帮您记账、查看统计、设置预算等。您想做什么？',
      spokenText: '我可以帮您记账、查看统计、设置预算等。请问您想做什么？',
      suggestedActions: [
        SuggestedAction(
          label: '快速记账',
          route: '/quick-add',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '查看统计',
          route: '/statistics',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '预算管理',
          route: '/budget',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '帮助中心',
          route: '/help',
          actionType: 'navigate',
        ),
      ],
      tone: EmotionalTone.friendly,
    );
  }

  /// 生成数据查询响应
  SmartResponse _generateDataQueryResponse(OtherIntentAnalysis analysis) {
    final params = analysis.extractedInfo;
    final timeRange = params?['timeRange'] as String? ?? '本月';
    final category = params?['category'] as String?;

    String primaryText;
    if (category != null) {
      primaryText = '正在为您查询$timeRange$category的消费数据...';
    } else {
      primaryText = '正在为您查询$timeRange的消费数据...';
    }

    return SmartResponse(
      type: ResponseType.dataInsight,
      primaryText: primaryText,
      suggestedActions: [
        SuggestedAction(
          label: '查看详细统计',
          route: '/statistics',
          actionType: 'navigate',
          params: {'timeRange': timeRange, 'category': category},
        ),
        const SuggestedAction(
          label: '查看趋势图',
          route: '/statistics/trend',
          actionType: 'navigate',
        ),
      ],
      tone: EmotionalTone.professional,
    );
  }

  /// 生成情感响应
  SmartResponse _generateEmotionalResponse(OtherIntentAnalysis analysis) {
    final emotion = analysis.extractedInfo?['emotion'] as String? ?? '焦虑';
    final responses = _emotionalResponses[emotion] ?? _emotionalResponses['焦虑']!;
    final response = responses[DateTime.now().millisecond % responses.length];

    List<SuggestedAction>? actions;
    if (emotion == '焦虑' || emotion == '担心') {
      actions = const [
        SuggestedAction(
          label: '查看财务健康评分',
          route: '/habits/health-score',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '制定预算计划',
          route: '/budget',
          actionType: 'navigate',
        ),
      ];
    } else if (emotion == '后悔') {
      actions = const [
        SuggestedAction(
          label: '开启冲动防护',
          route: '/impulse',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '查看消费分析',
          route: '/habits/insights',
          actionType: 'navigate',
        ),
      ];
    }

    return SmartResponse(
      type: ResponseType.emotionalSupport,
      primaryText: response,
      suggestedActions: actions,
      tone: EmotionalTone.empathetic,
    );
  }

  /// 生成澄清响应
  SmartResponse _generateClarificationResponse(OtherIntentAnalysis analysis) {
    return SmartResponse(
      type: ResponseType.clarification,
      primaryText: '我没有完全理解您的意思，您是想：',
      spokenText: '我没有完全理解您的意思，您是想记账、查询还是其他操作？',
      suggestedActions: const [
        SuggestedAction(
          label: '记一笔账',
          route: '/quick-add',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '查看消费',
          route: '/statistics',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '获取帮助',
          route: '/help',
          actionType: 'navigate',
        ),
      ],
      requiresConfirmation: true,
      tone: EmotionalTone.friendly,
    );
  }

  /// 生成闲聊响应
  SmartResponse _generateChitChatResponse(OtherIntentAnalysis analysis) {
    final text = analysis.originalText.toLowerCase();

    if (text.contains('你好') || text.contains('嗨')) {
      return const SmartResponse(
        type: ResponseType.directAnswer,
        primaryText: '您好！我是您的智能记账助手，有什么可以帮您的吗？',
        suggestedActions: [
          SuggestedAction(
            label: '开始记账',
            route: '/quick-add',
            actionType: 'navigate',
          ),
          SuggestedAction(
            label: '查看今日消费',
            route: '/statistics',
            actionType: 'navigate',
          ),
        ],
        tone: EmotionalTone.friendly,
      );
    }

    if (text.contains('谢谢')) {
      return const SmartResponse(
        type: ResponseType.directAnswer,
        primaryText: '不客气！还有什么需要帮助的吗？',
        tone: EmotionalTone.friendly,
      );
    }

    if (text.contains('再见') || text.contains('拜拜')) {
      return const SmartResponse(
        type: ResponseType.directAnswer,
        primaryText: '再见！祝您财务自由！',
        tone: EmotionalTone.friendly,
      );
    }

    if (text.contains('你是谁') || text.contains('叫什么')) {
      return const SmartResponse(
        type: ResponseType.directAnswer,
        primaryText: '我是智能记账助手小智，可以帮您语音记账、查询消费、管理预算等。',
        tone: EmotionalTone.friendly,
      );
    }

    return const SmartResponse(
      type: ResponseType.directAnswer,
      primaryText: '好的，还有什么可以帮您的吗？',
      tone: EmotionalTone.friendly,
    );
  }

  /// 生成反馈响应
  SmartResponse _generateFeedbackResponse(OtherIntentAnalysis analysis) {
    return SmartResponse(
      type: ResponseType.directAnswer,
      primaryText: '感谢您的反馈！我们会认真考虑您的建议。',
      spokenText: '感谢您的宝贵反馈，我们会认真考虑的。',
      suggestedActions: const [
        SuggestedAction(
          label: '提交详细反馈',
          route: '/feedback',
          actionType: 'navigate',
        ),
      ],
      tone: EmotionalTone.professional,
    );
  }

  /// 生成超出范围响应
  SmartResponse _generateOutOfScopeResponse(OtherIntentAnalysis analysis) {
    return const SmartResponse(
      type: ResponseType.politeDecline,
      primaryText: '抱歉，这个问题超出了我的能力范围。我主要可以帮您：',
      spokenText: '抱歉，这个问题我帮不上忙。不过我可以帮您记账、查看消费统计、管理预算等。',
      suggestedActions: [
        SuggestedAction(
          label: '语音记账',
          route: '/voice-input',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '查看消费',
          route: '/statistics',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '预算管理',
          route: '/budget',
          actionType: 'navigate',
        ),
        SuggestedAction(
          label: '帮助中心',
          route: '/help',
          actionType: 'navigate',
        ),
      ],
      tone: EmotionalTone.professional,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 辅助方法
  // ═══════════════════════════════════════════════════════════════

  bool _containsAnyKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  String? _extractFeature(String text) {
    for (final feature in _featureHelps.keys) {
      if (text.contains(feature)) return feature;
    }

    // 同义词映射
    const synonyms = {
      '账': '记账',
      '记录': '记账',
      '消费': '统计',
      '花销': '统计',
      '报告': '统计',
      '账单': '导入',
      '导出': '统计',
      '金库': '小金库',
      '存钱': '小金库',
      '共享': '家庭',
      '分摊': '家庭',
      '资金': '钱龄',
    };

    for (final entry in synonyms.entries) {
      if (text.contains(entry.key)) return entry.value;
    }

    return null;
  }

  Map<String, dynamic>? _extractQueryParams(String text) {
    final params = <String, dynamic>{};

    // 提取时间范围
    const timePatterns = {
      '今天': 'today',
      '昨天': 'yesterday',
      '本周': 'this_week',
      '上周': 'last_week',
      '本月': 'this_month',
      '上月': 'last_month',
      '今年': 'this_year',
      '去年': 'last_year',
    };

    for (final entry in timePatterns.entries) {
      if (text.contains(entry.key)) {
        params['timeRange'] = entry.key;
        break;
      }
    }

    // 提取分类
    const categories = ['餐饮', '交通', '购物', '娱乐', '住房', '通讯', '医疗', '教育'];
    for (final category in categories) {
      if (text.contains(category)) {
        params['category'] = category;
        break;
      }
    }

    return params.isNotEmpty ? params : null;
  }

  String? _detectEmotion(String text) {
    const emotionKeywords = {
      '焦虑': ['焦虑', '担心', '紧张', '压力大', '愁'],
      '开心': ['开心', '高兴', '太好了', '不错', '棒'],
      '后悔': ['后悔', '不该', '冲动', '剁手', '败家'],
      '抱怨': ['烦', '郁闷', '不好用', '垃圾', '差评'],
    };

    for (final entry in emotionKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) return entry.key;
      }
    }

    return null;
  }
}

/// 功能帮助信息
class _FeatureHelp {
  final String name;
  final String description;
  final String route;
  final List<String> tips;

  const _FeatureHelp({
    required this.name,
    required this.description,
    required this.route,
    required this.tips,
  });
}

/// 其他意图学习优化器
///
/// 对应设计文档代码块255
class OtherIntentLearningOptimizer extends ChangeNotifier {
  /// 未识别意图记录
  final List<_UnrecognizedIntent> _unrecognizedIntents = [];

  /// 最大记录数
  static const int maxRecords = 100;

  /// 记录未识别意图
  void recordUnrecognizedIntent(String text, OtherIntentType classifiedAs) {
    _unrecognizedIntents.add(_UnrecognizedIntent(
      text: text,
      classifiedAs: classifiedAs,
      timestamp: DateTime.now(),
    ));

    if (_unrecognizedIntents.length > maxRecords) {
      _unrecognizedIntents.removeAt(0);
    }

    notifyListeners();
  }

  /// 获取高频未识别模式
  List<String> getFrequentUnrecognizedPatterns({int limit = 10}) {
    final patterns = <String, int>{};

    for (final intent in _unrecognizedIntents) {
      // 提取2-gram
      for (var i = 0; i < intent.text.length - 1; i++) {
        final pattern = intent.text.substring(i, i + 2);
        patterns[pattern] = (patterns[pattern] ?? 0) + 1;
      }
    }

    final sorted = patterns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// 获取统计信息
  Map<OtherIntentType, int> getStatistics() {
    final stats = <OtherIntentType, int>{};
    for (final intent in _unrecognizedIntents) {
      stats[intent.classifiedAs] = (stats[intent.classifiedAs] ?? 0) + 1;
    }
    return stats;
  }

  /// 清除记录
  void clear() {
    _unrecognizedIntents.clear();
    notifyListeners();
  }
}

class _UnrecognizedIntent {
  final String text;
  final OtherIntentType classifiedAs;
  final DateTime timestamp;

  const _UnrecognizedIntent({
    required this.text,
    required this.classifiedAs,
    required this.timestamp,
  });
}
