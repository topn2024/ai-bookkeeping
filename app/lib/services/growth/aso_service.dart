/// ASO (App Store Optimization) 服务
///
/// 提供应用商店优化相关功能，包括关键词管理、描述优化、截图配置等
///
/// 对应实施方案：用户增长体系 - ASO与内容营销准备
library;

// ==================== ASO 配置模型 ====================

/// 应用商店类型
enum AppStore {
  appleAppStore,
  googlePlay,
  huaweiAppGallery,
  xiaomiStore,
  oppoStore,
  vivoStore,
}

/// 应用商店元数据
class AppStoreMetadata {
  final AppStore store;
  final String locale;
  final String appName;
  final String subtitle;
  final String shortDescription;
  final String fullDescription;
  final List<String> keywords;
  final String? promotionalText;
  final String? whatsNew;
  final List<String> screenshotPaths;
  final String? previewVideoPath;

  const AppStoreMetadata({
    required this.store,
    required this.locale,
    required this.appName,
    required this.subtitle,
    required this.shortDescription,
    required this.fullDescription,
    required this.keywords,
    this.promotionalText,
    this.whatsNew,
    this.screenshotPaths = const [],
    this.previewVideoPath,
  });

  Map<String, dynamic> toJson() => {
        'store': store.name,
        'locale': locale,
        'app_name': appName,
        'subtitle': subtitle,
        'short_description': shortDescription,
        'full_description': fullDescription,
        'keywords': keywords,
        'promotional_text': promotionalText,
        'whats_new': whatsNew,
        'screenshot_paths': screenshotPaths,
        'preview_video_path': previewVideoPath,
      };
}

/// 关键词分析结果
class KeywordAnalysis {
  final String keyword;
  final int searchVolume;
  final double difficulty;
  final int currentRank;
  final List<String> relatedKeywords;

  const KeywordAnalysis({
    required this.keyword,
    required this.searchVolume,
    required this.difficulty,
    required this.currentRank,
    this.relatedKeywords = const [],
  });
}

// ==================== ASO 服务 ====================

/// ASO 优化服务
class ASOService {
  static final ASOService _instance = ASOService._internal();
  factory ASOService() => _instance;
  ASOService._internal();

  // 预定义的应用商店元数据
  final Map<String, AppStoreMetadata> _metadata = {};

  /// 初始化
  Future<void> initialize() async {
    _loadDefaultMetadata();
  }

  void _loadDefaultMetadata() {
    // 简体中文 - Apple App Store
    _metadata['zh-Hans_appleAppStore'] = const AppStoreMetadata(
      store: AppStore.appleAppStore,
      locale: 'zh-Hans',
      appName: '鱼记',
      subtitle: '轻松记账，智慧理财',
      shortDescription: '让记账变得简单有趣，AI智能识别，一句话轻松记账',
      fullDescription: '''
【产品特色】

🎯 AI智能识别
- 语音记账：说一句"午饭花了30"，自动识别金额和分类
- 拍照记账：拍摄小票自动识别，告别手动输入
- 智能分类：AI学习您的消费习惯，自动归类更精准

💰 资金年龄分析
- 独创"资金年龄"概念，了解您每一笔钱的存放时间
- 可视化资金流动，发现消费规律
- 智能理财建议，让钱生钱

📊 预算管理
- 灵活设置月度/周度预算
- 实时预算追踪，超支提醒
- 智能预算建议，科学规划支出

📈 数据洞察
- 多维度消费分析报表
- 趋势对比，发现消费变化
- 财务健康度评估

🔒 安全可靠
- 本地数据加密存储
- 支持云端同步备份
- 隐私数据脱敏显示

【适用人群】
- 想要培养记账习惯的年轻人
- 追求高效记账的职场人士
- 关注��庭财务的理财达人
- 希望了解消费规律的用户

【联系我们】
官网：https://aibook.example.com
邮箱：support@aibook.example.com
微信公众号：鱼记
''',
      keywords: [
        '记账',
        '智能记账',
        'AI记账',
        '语音记账',
        '理财',
        '预算',
        '账本',
        '消费记录',
        '财务管理',
        '存钱',
      ],
      promotionalText: '新用户专享7天高级会员！',
      whatsNew: '''
版本 2.0.0 更新内容：

🚀 全新升级
- 全新设计语言，更清爽的界面
- 性能大幅优化，流畅度提升50%

✨ 新功能
- 资金年龄分析：了解每笔钱的"寿命"
- 智能预算建议：AI帮你规划支出
- 账单分享卡片：一键生成精美分享图

🔧 优化改进
- 语音识别准确率提升至95%
- 支持更多银行小票识别
- 图表加载速度优化
''',
      screenshotPaths: [
        'assets/screenshots/zh-Hans/1_home.png',
        'assets/screenshots/zh-Hans/2_add_transaction.png',
        'assets/screenshots/zh-Hans/3_statistics.png',
        'assets/screenshots/zh-Hans/4_budget.png',
        'assets/screenshots/zh-Hans/5_money_age.png',
      ],
    );

    // 英文 - Apple App Store
    _metadata['en_appleAppStore'] = const AppStoreMetadata(
      store: AppStore.appleAppStore,
      locale: 'en',
      appName: 'AI Expense Tracker',
      subtitle: 'Smart Budgeting Made Easy',
      shortDescription:
          'Track expenses effortlessly with AI. Voice input, receipt scanning, smart categorization.',
      fullDescription: '''
【Features】

🎯 AI-Powered Recognition
- Voice Input: Say "lunch 30 dollars" and we'll handle the rest
- Receipt Scanning: Snap a photo, we'll extract the details
- Smart Categories: AI learns your habits for accurate sorting

💰 Money Age Analytics
- Unique "Money Age" concept shows how long your money stays
- Visualize cash flow patterns
- Get personalized saving tips

📊 Budget Management
- Flexible monthly/weekly budgets
- Real-time tracking with alerts
- Smart budget recommendations

📈 Insights & Reports
- Multi-dimensional expense analysis
- Trend comparisons
- Financial health assessment

🔒 Secure & Private
- Local encrypted storage
- Cloud sync backup
- Privacy-focused data masking

【Contact Us】
Website: https://aibook.example.com
Email: support@aibook.example.com
''',
      keywords: [
        'expense tracker',
        'budget',
        'money manager',
        'finance',
        'AI',
        'voice',
        'receipt scanner',
        'savings',
        'personal finance',
        'spending tracker',
      ],
      promotionalText: 'New users get 7 days of Premium free!',
      whatsNew: '''
Version 2.0.0:

🚀 Major Upgrade
- Fresh new design language
- 50% performance improvement

✨ New Features
- Money Age Analytics
- Smart Budget Suggestions
- Shareable Bill Cards

🔧 Improvements
- 95% voice recognition accuracy
- More bank receipts supported
- Faster chart loading
''',
      screenshotPaths: [
        'assets/screenshots/en/1_home.png',
        'assets/screenshots/en/2_add_transaction.png',
        'assets/screenshots/en/3_statistics.png',
        'assets/screenshots/en/4_budget.png',
        'assets/screenshots/en/5_money_age.png',
      ],
    );

    // 简体中文 - Google Play
    _metadata['zh-Hans_googlePlay'] = const AppStoreMetadata(
      store: AppStore.googlePlay,
      locale: 'zh-Hans',
      appName: '鱼记',
      subtitle: '轻松记账，智慧理财',
      shortDescription: '让记账变得简单有趣，AI智能识别，一句话轻松记账',
      fullDescription: '''
鱼记 - 您的私人财务助手

告别繁琐的手动输入，用最自然的方式记录每一笔开支。

【核心功能】
• AI语音记账 - 说一句话完成记账
• 智能拍照识别 - 小票自动录入
• 资金年龄分析 - 了解钱的流动规律
• 智能预算管理 - 科学规划支出
• 可视化报表 - 清晰了解消费结构

【为什么选择我们】
✓ 简单易用，3秒完成记账
✓ AI智能分类，准确率高达95%
✓ 本地加密存储，隐私安全有保障
✓ 离线可用，随时随地记账

立即下载，开启智能记账新体验！
''',
      keywords: [
        '记账',
        '记账软件',
        '账本',
        '理财',
        '预算',
        'AI',
        '语音记账',
        '消费记录',
        '财务管理',
        '省钱',
      ],
    );
  }

  /// 获取指定语言和商店的元数据
  AppStoreMetadata? getMetadata(String locale, AppStore store) {
    return _metadata['${locale}_${store.name}'];
  }

  /// 获取所有元数据
  List<AppStoreMetadata> getAllMetadata() {
    return _metadata.values.toList();
  }

  /// 获取关键词建议
  List<String> getKeywordSuggestions(String locale) {
    final baseKeywords = <String>[];

    switch (locale) {
      case 'zh-Hans':
        baseKeywords.addAll([
          '记账', '记账软件', '记账本', '账本', '智能记账',
          'AI记账', '语音记账', '拍照记账', '理财', '理财助手',
          '预算', '预算管理', '消费记录', '支出管理', '财务管理',
          '存钱', '省钱', '家庭账本', '个人记账', '生活记账',
          '账单', '流水账', '收支', '月度预算', '消费分析',
        ]);
        break;
      case 'en':
        baseKeywords.addAll([
          'expense tracker', 'budget app', 'money manager',
          'finance tracker', 'spending tracker', 'budget planner',
          'personal finance', 'expense manager', 'money tracker',
          'budget tracker', 'savings app', 'bill tracker',
          'receipt scanner', 'AI expense', 'voice expense',
        ]);
        break;
    }

    return baseKeywords;
  }

  /// 分析关键词竞争度（模拟）
  Future<KeywordAnalysis> analyzeKeyword(String keyword, String locale) async {
    // 实际实现中调用ASO分析API
    await Future.delayed(const Duration(milliseconds: 500));

    return KeywordAnalysis(
      keyword: keyword,
      searchVolume: 1000 + keyword.length * 100, // 模拟
      difficulty: 0.3 + (keyword.length % 5) * 0.1, // 模拟
      currentRank: keyword.length * 5, // 模拟
      relatedKeywords: _getRelatedKeywords(keyword, locale),
    );
  }

  List<String> _getRelatedKeywords(String keyword, String locale) {
    // 模拟相关关键词
    if (locale == 'zh-Hans') {
      if (keyword.contains('记账')) {
        return ['手机记账', '在线记账', '免费记账', '简单记账'];
      }
      if (keyword.contains('预算')) {
        return ['月度预算', '家庭预算', '预算规划', '预算控制'];
      }
    }
    return [];
  }

  /// 生成优化的应用描述
  String generateOptimizedDescription({
    required String locale,
    required List<String> targetKeywords,
    required List<String> features,
  }) {
    final buffer = StringBuffer();

    if (locale == 'zh-Hans') {
      buffer.writeln('【产品特色】\n');
      for (final feature in features) {
        buffer.writeln('• $feature');
      }
      buffer.writeln('\n【关键词覆盖】');
      buffer.writeln(targetKeywords.join('、'));
    } else {
      buffer.writeln('【Features】\n');
      for (final feature in features) {
        buffer.writeln('• $feature');
      }
    }

    return buffer.toString();
  }

  /// 获取截图规格建议
  Map<String, dynamic> getScreenshotSpecs(AppStore store) {
    switch (store) {
      case AppStore.appleAppStore:
        return {
          'iPhone_6.7': {'width': 1290, 'height': 2796, 'count': 10},
          'iPhone_6.5': {'width': 1284, 'height': 2778, 'count': 10},
          'iPhone_5.5': {'width': 1242, 'height': 2208, 'count': 10},
          'iPad_12.9': {'width': 2048, 'height': 2732, 'count': 10},
        };
      case AppStore.googlePlay:
        return {
          'phone': {'width': 1080, 'height': 1920, 'count': 8},
          'tablet_7': {'width': 1200, 'height': 1920, 'count': 8},
          'tablet_10': {'width': 1920, 'height': 1200, 'count': 8},
        };
      default:
        return {
          'default': {'width': 1080, 'height': 1920, 'count': 5},
        };
    }
  }

  /// 获取版本更新文案模板
  String getWhatsNewTemplate(String locale, List<String> updates) {
    final buffer = StringBuffer();

    if (locale == 'zh-Hans') {
      buffer.writeln('本次更新：\n');
      for (var i = 0; i < updates.length; i++) {
        buffer.writeln('${i + 1}. ${updates[i]}');
      }
      buffer.writeln('\n感谢您的使用，如有问题请随时反馈！');
    } else {
      buffer.writeln("What's New:\n");
      for (final update in updates) {
        buffer.writeln('• $update');
      }
      buffer.writeln('\nThank you for using our app!');
    }

    return buffer.toString();
  }
}

/// 全局 ASO 服务实例
final asoService = ASOService();
