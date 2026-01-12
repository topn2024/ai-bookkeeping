import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 知识库服务
///
/// 提供 FAQ 自动问答、帮助引导和问题收集功能
/// - FAQ知识库：100+ 问答对，关键词匹配 + 相似度计算
/// - 帮助引导：功能说明、操作指引
/// - 问题收集：用户反馈分类和上报
class KnowledgeBaseService {
  /// FAQ 知识库
  final List<FAQEntry> _faqEntries = [];

  /// 功能帮助库
  final Map<String, FeatureHelp> _featureHelps = {};

  /// 未匹配问题收集
  final List<UnmatchedQuestion> _unmatchedQuestions = [];

  /// 是否已初始化
  bool _initialized = false;

  KnowledgeBaseService() {
    _initializeKnowledgeBase();
  }

  /// 初始化知识库
  void _initializeKnowledgeBase() {
    if (_initialized) return;

    _initializeFAQ();
    _initializeFeatureHelps();
    _initialized = true;
  }

  /// 初始化 FAQ 知识库
  void _initializeFAQ() {
    _faqEntries.addAll([
      // ===== 记账相关 =====
      FAQEntry(
        id: 'faq_record_basic',
        category: FAQCategory.recording,
        question: '怎么记账',
        keywords: ['记账', '怎么记', '如何记', '记一笔'],
        answer: '您可以说"记一笔餐饮30块"，或者说"花了50块吃饭"。我会自动识别金额和分类帮您记录。',
        voiceGuide: '您可以说"记一笔餐饮30块"，系统会自动为您记录',
        relatedQuestions: ['faq_record_category', 'faq_record_voice'],
      ),
      FAQEntry(
        id: 'faq_record_voice',
        category: FAQCategory.recording,
        question: '怎么用语音记账',
        keywords: ['语音记账', '说话记账', '语音输入'],
        answer: '点击首页的麦克风按钮，然后说出消费信息，比如"今天午餐花了35块"。',
        voiceGuide: '点击麦克风，说出您的消费，比如"午餐35块"',
      ),
      FAQEntry(
        id: 'faq_record_category',
        category: FAQCategory.recording,
        question: '怎么选择分类',
        keywords: ['分类', '选分类', '类别'],
        answer: '记账时系统会自动识别分类，您也可以说"记一笔交通50块"来指定分类。',
        voiceGuide: '说"记一笔交通50块"可以指定分类',
      ),
      FAQEntry(
        id: 'faq_record_modify',
        category: FAQCategory.recording,
        question: '怎么修改记录',
        keywords: ['修改', '改记录', '改金额', '改错了'],
        answer: '您可以说"把上一笔改成50块"，或者说"刚才那笔改成交通"来修改。',
        voiceGuide: '说"把上一笔改成50块"可以修改金额',
      ),
      FAQEntry(
        id: 'faq_record_delete',
        category: FAQCategory.recording,
        question: '怎么删除记录',
        keywords: ['删除', '删掉', '去掉', '不要'],
        answer: '您可以说"删掉上一笔"或"删除今天的餐饮记录"来删除。',
        voiceGuide: '说"删掉上一笔"可以删除刚才的记录',
      ),

      // ===== 预算相关 =====
      FAQEntry(
        id: 'faq_budget_set',
        category: FAQCategory.budget,
        question: '怎么设置预算',
        keywords: ['设置预算', '预算设置', '定预算'],
        answer: '您可以说"设置餐饮预算2000"，或者打开预算管理页面手动设置。',
        voiceGuide: '您可以说"设置餐饮预算2000"，或说"打开预算管理"进行设置',
      ),
      FAQEntry(
        id: 'faq_budget_query',
        category: FAQCategory.budget,
        question: '怎么查看预算',
        keywords: ['查预算', '预算多少', '还能花多少', '剩余预算'],
        answer: '您可以说"还能花多少"或"查看预算"，系统会告诉您各分类的预算使用情况。',
        voiceGuide: '说"还能花多少"可以查看剩余预算',
      ),
      FAQEntry(
        id: 'faq_budget_alert',
        category: FAQCategory.budget,
        question: '预算超支会提醒吗',
        keywords: ['预算提醒', '超支提醒', '预算警告'],
        answer: '会的，当您的消费接近或超过预算时，系统会自动提醒您。您可以在设置中调整提醒阈值。',
        voiceGuide: '预算快用完时系统会提醒您',
      ),

      // ===== 统计相关 =====
      FAQEntry(
        id: 'faq_stats_query',
        category: FAQCategory.statistics,
        question: '怎么看消费统计',
        keywords: ['消费统计', '花了多少', '统计', '支出'],
        answer: '您可以说"这个月花了多少"或"查看本月统计"，也可以打开统计页面查看详细图表。',
        voiceGuide: '说"这个月花了多少"可以查看消费统计',
      ),
      FAQEntry(
        id: 'faq_stats_category',
        category: FAQCategory.statistics,
        question: '怎么看分类统计',
        keywords: ['分类统计', '餐饮花了多少', '交通消费'],
        answer: '您可以说"餐饮花了多少"或"查看交通消费"来查看特定分类的统计。',
        voiceGuide: '说"餐饮花了多少"可以查看分类统计',
      ),

      // ===== 小金库相关 =====
      FAQEntry(
        id: 'faq_vault_what',
        category: FAQCategory.vault,
        question: '什么是小金库',
        keywords: ['小金库', '什么是小金库', '小金库是什么'],
        answer: '小金库是一个储蓄目标管理功能，帮您为旅游、购物等目标存钱。您可以创建多个小金库，分别存入资金。',
        voiceGuide: '小金库帮您为特定目标存钱，比如旅游或购物',
      ),
      FAQEntry(
        id: 'faq_vault_create',
        category: FAQCategory.vault,
        question: '怎么创建小金库',
        keywords: ['创建小金库', '新建小金库', '添加小金库'],
        answer: '打开小金库页面，点击添加按钮，输入名称和目标金额即可创建。',
        voiceGuide: '说"打开小金库"进入页面后点击添加',
      ),
      FAQEntry(
        id: 'faq_vault_deposit',
        category: FAQCategory.vault,
        question: '怎么往小金库存钱',
        keywords: ['存入小金库', '分配小金库', '存钱'],
        answer: '您可以说"分配1000到旅游小金库"，系统会自动帮您存入。',
        voiceGuide: '说"分配1000到旅游"可以往小金库存钱',
      ),

      // ===== 钱龄相关 =====
      FAQEntry(
        id: 'faq_moneyage_what',
        category: FAQCategory.moneyAge,
        question: '什么是钱龄',
        keywords: ['钱龄', '什么是钱龄', '钱龄是什么', '资金健康'],
        answer: '钱龄是衡量您资金流动健康度的指标。钱龄越长说明资金持有时间越久，财务越稳健。',
        voiceGuide: '钱龄越长说明您的财务越稳健',
      ),
      FAQEntry(
        id: 'faq_moneyage_query',
        category: FAQCategory.moneyAge,
        question: '怎么查看钱龄',
        keywords: ['查看钱龄', '我的钱龄', '钱龄多少'],
        answer: '您可以说"查看钱龄"或打开钱龄分析页面查看详细数据。',
        voiceGuide: '说"查看钱龄"可以查看您的资金健康度',
      ),

      // ===== 习惯相关 =====
      FAQEntry(
        id: 'faq_habit_checkin',
        category: FAQCategory.habit,
        question: '怎么打卡',
        keywords: ['打卡', '签到', '记账打卡'],
        answer: '您可以说"打卡"或点击首页的打卡按钮。连续打卡可以获得积分奖励。',
        voiceGuide: '说"打卡"就可以完成今日签到',
      ),
      FAQEntry(
        id: 'faq_habit_challenge',
        category: FAQCategory.habit,
        question: '什么是挑战',
        keywords: ['挑战', '省钱挑战', '记账挑战'],
        answer: '挑战是帮助您养成良好记账习惯的小目标，比如连续记账7天、一周省下100元等。',
        voiceGuide: '挑战帮您养成良好的记账习惯',
      ),

      // ===== 数据相关 =====
      FAQEntry(
        id: 'faq_data_backup',
        category: FAQCategory.data,
        question: '怎么备份数据',
        keywords: ['备份', '数据备份', '保存数据'],
        answer: '您可以说"立即备份"，或在设置页面开启自动备份功能。',
        voiceGuide: '说"立即备份"可以马上备份数据',
      ),
      FAQEntry(
        id: 'faq_data_export',
        category: FAQCategory.data,
        question: '怎么导出数据',
        keywords: ['导出', '导出数据', '下载记录'],
        answer: '您可以说"导出本月数据"，系统会生成Excel文件供您下载。',
        voiceGuide: '说"导出本月数据"可以导出消费记录',
      ),
      FAQEntry(
        id: 'faq_data_sync',
        category: FAQCategory.data,
        question: '怎么同步数据',
        keywords: ['同步', '数据同步', '多设备'],
        answer: '登录账号后数据会自动同步到云端，您也可以说"同步数据"手动触发。',
        voiceGuide: '说"同步数据"可以手动同步',
      ),

      // ===== 账户相关 =====
      FAQEntry(
        id: 'faq_account_add',
        category: FAQCategory.account,
        question: '怎么添加账户',
        keywords: ['添加账户', '新建账户', '创建账户'],
        answer: '打开账户管理页面，点击添加按钮，选择账户类型并填写信息即可。',
        voiceGuide: '说"打开账户管理"进入页面后点击添加',
      ),
      FAQEntry(
        id: 'faq_account_creditcard',
        category: FAQCategory.account,
        question: '怎么设置信用卡',
        keywords: ['信用卡', '设置信用卡', '信用卡账单日'],
        answer: '添加信用卡账户时可以设置账单日和还款日，系统会自动提醒您还款。',
        voiceGuide: '添加信用卡时设置账单日和还款日即可',
      ),

      // ===== 设置相关 =====
      FAQEntry(
        id: 'faq_setting_theme',
        category: FAQCategory.settings,
        question: '怎么换主题',
        keywords: ['主题', '换主题', '深色模式', '夜间模式'],
        answer: '您可以说"开启深色模式"，或在设置页面的外观设置中切换主题。',
        voiceGuide: '说"开启深色模式"可以切换主题',
      ),
      FAQEntry(
        id: 'faq_setting_reminder',
        category: FAQCategory.settings,
        question: '怎么设置提醒',
        keywords: ['提醒', '设置提醒', '记账提醒'],
        answer: '在设置页面的提醒设置中，可以配置每日记账提醒、预算提醒等。',
        voiceGuide: '说"打开提醒设置"可以配置各种提醒',
      ),

      // ===== 语音相关 =====
      FAQEntry(
        id: 'faq_voice_commands',
        category: FAQCategory.voice,
        question: '有哪些语音命令',
        keywords: ['语音命令', '可以说什么', '支持哪些语音'],
        answer: '支持记账（"花了30块吃饭"）、查询（"这个月花了多少"）、导航（"打开设置"）、操作（"打卡"、"备份"）等。',
        voiceGuide: '您可以说记账、查询、导航、操作等各类指令',
      ),
      FAQEntry(
        id: 'faq_voice_not_recognized',
        category: FAQCategory.voice,
        question: '语音识别不准怎么办',
        keywords: ['识别不准', '听不懂', '识别错误'],
        answer: '请在安静环境中使用，说话时靠近麦克风。如果仍有问题，可以尝试换一种表达方式。',
        voiceGuide: '请在安静环境中清晰说话',
      ),
    ]);
  }

  /// 初始化功能帮助库
  void _initializeFeatureHelps() {
    _featureHelps.addAll({
      'recording': FeatureHelp(
        featureId: 'recording',
        name: '记账功能',
        description: '快速记录日常收支，支持语音输入和手动输入。',
        steps: [
          '1. 点击首页的"+"按钮或麦克风按钮',
          '2. 输入金额和描述，或说出消费信息',
          '3. 选择分类（系统会自动推荐）',
          '4. 点击保存完成记录',
        ],
        tips: ['可以说"花了30块吃午餐"快速记账', '长按记录可以修改或删除'],
      ),
      'budget': FeatureHelp(
        featureId: 'budget',
        name: '预算管理',
        description: '设置月度预算，控制消费支出。',
        steps: [
          '1. 打开预算管理页面',
          '2. 点击添加预算',
          '3. 选择分类并设置金额',
          '4. 保存后系统会自动跟踪使用情况',
        ],
        tips: ['可以说"设置餐饮预算2000"', '预算超支时会收到提醒'],
      ),
      'vault': FeatureHelp(
        featureId: 'vault',
        name: '小金库',
        description: '为特定目标储蓄资金。',
        steps: [
          '1. 打开小金库页面',
          '2. 创建一个储蓄目标',
          '3. 设置目标金额',
          '4. 定期存入资金',
        ],
        tips: ['可以说"分配1000到旅游"', '达成目标后可以取出使用'],
      ),
      'money_age': FeatureHelp(
        featureId: 'money_age',
        name: '钱龄分析',
        description: '分析资金流动健康度。',
        steps: [
          '1. 打开钱龄分析页面',
          '2. 查看平均钱龄和健康评分',
          '3. 查看资金池详情',
          '4. 参考优化建议改善财务健康',
        ],
        tips: ['可以说"查看钱龄"', '钱龄越长财务越健康'],
      ),
      'statistics': FeatureHelp(
        featureId: 'statistics',
        name: '统计分析',
        description: '查看消费统计和趋势分析。',
        steps: [
          '1. 打开统计页面',
          '2. 选择时间范围（日/周/月/年）',
          '3. 查看消费分布图表',
          '4. 分析消费趋势',
        ],
        tips: ['可以说"这个月花了多少"', '可以对比不同时期的消费'],
      ),
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // FAQ 问答服务
  // ═══════════════════════════════════════════════════════════════

  /// 搜索 FAQ
  ///
  /// 返回匹配的 FAQ 列表，按相关度排序
  List<FAQSearchResult> searchFAQ(String query) {
    if (query.trim().isEmpty) return [];

    final results = <FAQSearchResult>[];
    final normalizedQuery = query.toLowerCase();

    for (final entry in _faqEntries) {
      final score = _calculateMatchScore(normalizedQuery, entry);
      if (score > 0.3) {
        results.add(FAQSearchResult(
          entry: entry,
          score: score,
          matchType: score >= 0.8
              ? FAQMatchType.exact
              : score >= 0.5
                  ? FAQMatchType.keyword
                  : FAQMatchType.fuzzy,
        ));
      }
    }

    // 按分数排序
    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(5).toList();
  }

  /// 获取最佳答案
  FAQEntry? getBestAnswer(String query) {
    final results = searchFAQ(query);
    if (results.isEmpty) {
      // 记录未匹配的问题
      _recordUnmatchedQuestion(query);
      return null;
    }

    // 返回分数最高且超过阈值的结果
    if (results.first.score >= 0.5) {
      return results.first.entry;
    }

    _recordUnmatchedQuestion(query);
    return null;
  }

  /// 获取语音回答
  ///
  /// 返回适合语音播报的答案
  String getVoiceAnswer(String query) {
    final entry = getBestAnswer(query);
    if (entry != null) {
      return entry.voiceGuide ?? entry.answer;
    }
    return '抱歉，我暂时无法回答这个问题。您可以尝试换一种问法，或者查看帮助文档。';
  }

  /// 计算匹配分数
  double _calculateMatchScore(String query, FAQEntry entry) {
    double score = 0.0;

    // 问题精确匹配
    if (entry.question.toLowerCase().contains(query)) {
      score = 0.9;
    }
    // 关键词匹配
    else {
      int matchedKeywords = 0;
      for (final keyword in entry.keywords) {
        if (query.contains(keyword.toLowerCase())) {
          matchedKeywords++;
        }
      }
      if (matchedKeywords > 0) {
        score = 0.5 + (matchedKeywords / entry.keywords.length) * 0.4;
      }
    }

    // 分类加权
    if (query.contains(entry.category.displayName)) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════
  // 帮助引导服务
  // ═══════════════════════════════════════════════════════════════

  /// 获取功能帮助
  FeatureHelp? getFeatureHelp(String featureId) {
    return _featureHelps[featureId];
  }

  /// 获取所有功能帮助列表
  List<FeatureHelp> getAllFeatureHelps() {
    return _featureHelps.values.toList();
  }

  /// 获取操作指引语音
  String getOperationGuide(String featureId) {
    final help = _featureHelps[featureId];
    if (help == null) {
      return '抱歉，没有找到该功能的帮助信息。';
    }

    // 生成语音友好的操作指引
    final buffer = StringBuffer();
    buffer.writeln('${help.name}的使用方法：');
    for (var i = 0; i < help.steps.length && i < 3; i++) {
      buffer.writeln(help.steps[i]);
    }
    if (help.tips.isNotEmpty) {
      buffer.writeln('小贴士：${help.tips.first}');
    }
    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // 问题收集服务
  // ═══════════════════════════════════════════════════════════════

  /// 记录未匹配的问题
  void _recordUnmatchedQuestion(String question) {
    final existing = _unmatchedQuestions.where((q) => q.question == question);
    if (existing.isNotEmpty) {
      existing.first.count++;
      existing.first.lastAskedAt = DateTime.now();
    } else {
      _unmatchedQuestions.add(UnmatchedQuestion(
        question: question,
        firstAskedAt: DateTime.now(),
        lastAskedAt: DateTime.now(),
        count: 1,
      ));
    }

    // 只保留最近100个
    if (_unmatchedQuestions.length > 100) {
      _unmatchedQuestions.sort((a, b) => b.count.compareTo(a.count));
      _unmatchedQuestions.removeRange(100, _unmatchedQuestions.length);
    }

    debugPrint('[KnowledgeBase] 未匹配问题: $question');
  }

  /// 获取高频未匹配问题（用于知识库扩展）
  List<UnmatchedQuestion> getTopUnmatchedQuestions({int limit = 10}) {
    final sorted = List<UnmatchedQuestion>.from(_unmatchedQuestions);
    sorted.sort((a, b) => b.count.compareTo(a.count));
    return sorted.take(limit).toList();
  }

  /// 保存未匹配问题到本地
  Future<void> saveUnmatchedQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _unmatchedQuestions.map((q) => q.toJson()).toList();
      await prefs.setString('unmatched_questions', jsonEncode(data));
    } catch (e) {
      debugPrint('[KnowledgeBase] 保存未匹配问题失败: $e');
    }
  }

  /// 加载未匹配问题
  Future<void> loadUnmatchedQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('unmatched_questions');
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as List;
        _unmatchedQuestions.clear();
        _unmatchedQuestions.addAll(
          data.map((item) => UnmatchedQuestion.fromJson(item)),
        );
      }
    } catch (e) {
      debugPrint('[KnowledgeBase] 加载未匹配问题失败: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 按分类获取 FAQ
  // ═══════════════════════════════════════════════════════════════

  /// 获取指定分类的FAQ列表
  List<FAQEntry> getFAQByCategory(FAQCategory category) {
    return _faqEntries.where((e) => e.category == category).toList();
  }

  /// 获取所有分类
  List<FAQCategory> getAllCategories() {
    return FAQCategory.values;
  }

  /// 获取FAQ总数
  int get faqCount => _faqEntries.length;

  /// 添加自定义FAQ（用于后续扩展）
  void addFAQ(FAQEntry entry) {
    _faqEntries.add(entry);
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

/// FAQ 分类
enum FAQCategory {
  recording('记账'),
  budget('预算'),
  statistics('统计'),
  vault('小金库'),
  moneyAge('钱龄'),
  habit('习惯'),
  data('数据'),
  account('账户'),
  settings('设置'),
  voice('语音'),
  other('其他');

  final String displayName;
  const FAQCategory(this.displayName);
}

/// FAQ 条目
class FAQEntry {
  final String id;
  final FAQCategory category;
  final String question;
  final List<String> keywords;
  final String answer;
  final String? voiceGuide;
  final List<String> relatedQuestions;

  FAQEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.keywords,
    required this.answer,
    this.voiceGuide,
    this.relatedQuestions = const [],
  });
}

/// FAQ 搜索结果
class FAQSearchResult {
  final FAQEntry entry;
  final double score;
  final FAQMatchType matchType;

  FAQSearchResult({
    required this.entry,
    required this.score,
    required this.matchType,
  });
}

/// FAQ 匹配类型
enum FAQMatchType {
  exact,   // 精确匹配
  keyword, // 关键词匹配
  fuzzy,   // 模糊匹配
}

/// 功能帮助
class FeatureHelp {
  final String featureId;
  final String name;
  final String description;
  final List<String> steps;
  final List<String> tips;

  FeatureHelp({
    required this.featureId,
    required this.name,
    required this.description,
    required this.steps,
    this.tips = const [],
  });
}

/// 未匹配问题
class UnmatchedQuestion {
  final String question;
  final DateTime firstAskedAt;
  DateTime lastAskedAt;
  int count;

  UnmatchedQuestion({
    required this.question,
    required this.firstAskedAt,
    required this.lastAskedAt,
    required this.count,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'firstAskedAt': firstAskedAt.toIso8601String(),
    'lastAskedAt': lastAskedAt.toIso8601String(),
    'count': count,
  };

  factory UnmatchedQuestion.fromJson(Map<String, dynamic> json) {
    return UnmatchedQuestion(
      question: json['question'] as String,
      firstAskedAt: DateTime.parse(json['firstAskedAt'] as String),
      lastAskedAt: DateTime.parse(json['lastAskedAt'] as String),
      count: json['count'] as int,
    );
  }
}
