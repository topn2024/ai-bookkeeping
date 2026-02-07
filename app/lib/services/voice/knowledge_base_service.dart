import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 知识库服务
///
/// 提供 FAQ 自动问答、帮助引导和问题收集功能
/// - FAQ知识库：从 assets/help/faq.json 加载
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

  /// 是否正在初始化
  bool _initializing = false;

  KnowledgeBaseService();

  /// 异步初始化知识库
  ///
  /// 从 assets/help/faq.json 加载FAQ数据
  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      await _loadFAQFromAsset();
      _initializeFeatureHelps();
      _initialized = true;
      debugPrint('[KnowledgeBaseService] 初始化完成，加载了 ${_faqEntries.length} 条FAQ');
    } catch (e) {
      debugPrint('[KnowledgeBaseService] 初始化失败: $e');
    } finally {
      _initializing = false;
    }
  }

  /// 从asset加载FAQ
  Future<void> _loadFAQFromAsset() async {
    try {
      final jsonString = await rootBundle.loadString('assets/help/faq.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final entries = jsonData['entries'] as List<dynamic>;

      _faqEntries.clear();
      for (final item in entries) {
        final entry = FAQEntry.fromJson(item as Map<String, dynamic>);
        _faqEntries.add(entry);
      }

      debugPrint('[KnowledgeBaseService] 从faq.json加载了 ${_faqEntries.length} 条FAQ');
    } catch (e) {
      debugPrint('[KnowledgeBaseService] 加载FAQ失败: $e');
      rethrow;
    }
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

    // 同步检查，如果未初始化则返回空
    if (!_initialized) {
      debugPrint('[KnowledgeBaseService] 警告：知识库未初始化');
      return [];
    }

    final results = <FAQSearchResult>[];
    final normalizedQuery = query.toLowerCase();
    FAQSearchResult? exactMatch;

    for (final entry in _faqEntries) {
      final score = _calculateMatchScore(normalizedQuery, entry);
      if (score > 0.3) {
        final result = FAQSearchResult(
          entry: entry,
          score: score,
          matchType: score >= 0.8
              ? FAQMatchType.exact
              : score >= 0.5
                  ? FAQMatchType.keyword
                  : FAQMatchType.fuzzy,
        );
        results.add(result);

        // 早期终止：找到精确匹配时，只需再找几个相关的
        if (score >= 0.9 && exactMatch == null) {
          exactMatch = result;
        }
      }

      // 如果已找到精确匹配且结果数足够，提前退出
      if (exactMatch != null && results.length >= 5) {
        break;
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
    if (entry.questionLower.contains(query)) {
      score = 0.9;
    }
    // 关键词匹配
    else {
      int matchedKeywords = 0;
      for (final keyword in entry.keywordsLower) {
        if (query.contains(keyword)) {
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

  /// 是否已初始化
  bool get isInitialized => _initialized;
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
  navigation('导航'),
  general('通用'),
  other('其他');

  final String displayName;
  const FAQCategory(this.displayName);

  /// 从字符串解析分类
  static FAQCategory fromString(String value) {
    return FAQCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FAQCategory.other,
    );
  }
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

  /// 预计算的小写版本（用于搜索优化）
  late final String _questionLower;
  late final List<String> _keywordsLower;

  FAQEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.keywords,
    required this.answer,
    this.voiceGuide,
    this.relatedQuestions = const [],
  }) {
    // 预计算小写版本，避免每次搜索都转换
    _questionLower = question.toLowerCase();
    _keywordsLower = keywords.map((k) => k.toLowerCase()).toList();
  }

  /// 从JSON创建FAQEntry
  factory FAQEntry.fromJson(Map<String, dynamic> json) {
    return FAQEntry(
      id: json['id'] as String,
      category: FAQCategory.fromString(json['category'] as String),
      question: json['question'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      answer: json['answer'] as String,
      voiceGuide: json['voiceGuide'] as String?,
      relatedQuestions: json['relatedQuestions'] != null
          ? (json['relatedQuestions'] as List<dynamic>).cast<String>()
          : const [],
    );
  }

  /// 获取预计算的小写问题
  String get questionLower => _questionLower;

  /// 获取预计算的小写关键词
  List<String> get keywordsLower => _keywordsLower;
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
