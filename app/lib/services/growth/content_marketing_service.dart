import 'dart:async';
import 'dart:math';

/// 内容营销服务
///
/// 提供理财知识库、记账技巧、用户故事等内容功能
///
/// 对应实施方案：用户增长体系 - ASO与内容营销准备

// ==================== 内容模型 ====================

/// 内容类型
enum ContentType {
  /// 理财小贴士
  financeTip,

  /// 记账技巧
  bookkeepingTrick,

  /// 用户故事
  userStory,

  /// 节日理财
  holidayFinance,

  /// 行业洞察
  industryInsight,
}

/// 内容标签
enum ContentTag {
  budgeting,      // 预算管理
  saving,         // 储蓄技巧
  investment,     // 投资入门
  debtManagement, // 债务管理
  incomeBoost,    // 增收方法
  expenseReduce,  // 节流技巧
  familyFinance,  // 家庭理财
  studentLife,    // 学生理财
  newGraduate,    // 职场新人
  freelancer,     // 自由职业
}

/// 内容项
class ContentItem {
  final String id;
  final ContentType type;
  final String title;
  final String summary;
  final String? content;
  final String? imageUrl;
  final List<ContentTag> tags;
  final DateTime publishedAt;
  final int viewCount;
  final int likeCount;
  final int shareCount;
  final bool isPremium;
  final Map<String, dynamic>? metadata;

  ContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    this.content,
    this.imageUrl,
    this.tags = const [],
    DateTime? publishedAt,
    this.viewCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.isPremium = false,
    this.metadata,
  }) : publishedAt = publishedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'summary': summary,
        'content': content,
        'image_url': imageUrl,
        'tags': tags.map((t) => t.name).toList(),
        'published_at': publishedAt.toIso8601String(),
        'view_count': viewCount,
        'like_count': likeCount,
        'share_count': shareCount,
        'is_premium': isPremium,
        'metadata': metadata,
      };
}

/// 用户故事
class UserStory extends ContentItem {
  final String authorName;
  final String? authorAvatar;
  final String location;
  final int savingAmount;
  final int monthsUsed;
  final String testimonial;

  UserStory({
    required super.id,
    required super.title,
    required super.summary,
    required this.authorName,
    this.authorAvatar,
    required this.location,
    required this.savingAmount,
    required this.monthsUsed,
    required this.testimonial,
    super.imageUrl,
    super.tags,
    super.publishedAt,
    super.viewCount,
    super.likeCount,
    super.shareCount,
    super.metadata,
  }) : super(type: ContentType.userStory);
}

/// 理财技巧卡片
class TipCard {
  final String id;
  final String title;
  final String content;
  final String iconEmoji;
  final String category;
  final List<String> actionItems;
  final String? relatedFeature;

  const TipCard({
    required this.id,
    required this.title,
    required this.content,
    required this.iconEmoji,
    required this.category,
    this.actionItems = const [],
    this.relatedFeature,
  });
}

// ==================== 内容服务 ====================

/// 内容营销服务
class ContentMarketingService {
  static final ContentMarketingService _instance =
      ContentMarketingService._internal();
  factory ContentMarketingService() => _instance;
  ContentMarketingService._internal();

  // 内容库
  final List<ContentItem> _contents = [];
  final List<TipCard> _tipCards = [];
  final List<UserStory> _userStories = [];

  // 用户偏好
  final Set<ContentTag> _userPreferences = {};
  final Set<String> _viewedContentIds = {};
  final Set<String> _likedContentIds = {};

  /// 初始化
  Future<void> initialize() async {
    await _loadBuiltInContent();
    await _loadUserPreferences();
  }

  Future<void> _loadBuiltInContent() async {
    // 加载内置理财技巧卡片
    _tipCards.addAll(_getBuiltInTipCards());

    // 加载内置内容
    _contents.addAll(_getBuiltInContents());
  }

  Future<void> _loadUserPreferences() async {
    // 实际实现中从持久化存储加载
  }

  List<TipCard> _getBuiltInTipCards() {
    return const [
      // 预算技巧
      TipCard(
        id: 'tip_50_30_20',
        title: '50/30/20 法则',
        content: '将收入分配为：50%必要支出，30%个人消费，20%储蓄投资',
        iconEmoji: '💡',
        category: 'budgeting',
        actionItems: ['设置三个预算分类', '每月检查分配比例', '逐步提高储蓄比例'],
        relatedFeature: 'budget',
      ),
      TipCard(
        id: 'tip_envelope',
        title: '信封预算法',
        content: '将每月预算分装到不同"信封"，花完即止',
        iconEmoji: '✉️',
        category: 'budgeting',
        actionItems: ['创建分类预算', '设置预算上限', '追踪每日支出'],
        relatedFeature: 'budget',
      ),

      // 储蓄技巧
      TipCard(
        id: 'tip_pay_yourself_first',
        title: '先储蓄后消费',
        content: '发工资后立即转入储蓄账户，用剩余金额生活',
        iconEmoji: '🏦',
        category: 'saving',
        actionItems: ['设置自动转账', '确定储蓄目标', '追踪储蓄进度'],
        relatedFeature: 'account',
      ),
      TipCard(
        id: 'tip_52_week',
        title: '52周存钱法',
        content: '第1周存1元，第2周存2元...第52周存52元，年末存1378元',
        iconEmoji: '📅',
        category: 'saving',
        actionItems: ['设定每周提醒', '记录存款进度', '完成后给自己奖励'],
        relatedFeature: 'goal',
      ),
      TipCard(
        id: 'tip_spare_change',
        title: '零钱储蓄法',
        content: '消费后将零头存入储蓄账户，积少成多',
        iconEmoji: '🪙',
        category: 'saving',
        actionItems: ['记录每笔消费', '计算四舍五入差额', '定期汇总零钱'],
      ),

      // 记账技巧
      TipCard(
        id: 'tip_daily_record',
        title: '每日随手记',
        content: '养成每天记账习惯，花了就记，不漏不忘',
        iconEmoji: '📝',
        category: 'bookkeeping',
        actionItems: ['设置记账提醒', '使用语音快速记账', '每周回顾'],
        relatedFeature: 'quick_add',
      ),
      TipCard(
        id: 'tip_category_review',
        title: '分类复盘法',
        content: '每月按分类查看支出，找出"隐形杀手"',
        iconEmoji: '📊',
        category: 'bookkeeping',
        actionItems: ['查看分类报表', '标记异常支出', '制定改进计划'],
        relatedFeature: 'statistics',
      ),

      // 节流技巧
      TipCard(
        id: 'tip_24_hour_rule',
        title: '24小时冷静期',
        content: '大额消费前等待24小时，避免冲动购物',
        iconEmoji: '⏰',
        category: 'expense',
        actionItems: ['设置消费提醒', '记录想买的东西', '24小时后再决定'],
      ),
      TipCard(
        id: 'tip_unsubscribe',
        title: '订阅断舍离',
        content: '定期检查订阅服务，取消不常用的',
        iconEmoji: '✂️',
        category: 'expense',
        actionItems: ['列出所有订阅', '评估使用频率', '取消低价值订阅'],
        relatedFeature: 'subscription',
      ),
      TipCard(
        id: 'tip_meal_prep',
        title: '餐饮计划',
        content: '提前规划每周餐食，减少外卖和冲动消费',
        iconEmoji: '🍱',
        category: 'expense',
        actionItems: ['制定周餐计划', '批量采购食材', '追踪餐饮支出'],
      ),

      // 增收技巧
      TipCard(
        id: 'tip_side_hustle',
        title: '发展副业',
        content: '利用技能和爱好开展副业，增加收入来源',
        iconEmoji: '💪',
        category: 'income',
        actionItems: ['评估个人技能', '寻找副业机会', '记录副业收入'],
      ),
      TipCard(
        id: 'tip_cashback',
        title: '善用返现',
        content: '使用返现信用卡和平台，让消费产生回报',
        iconEmoji: '💳',
        category: 'income',
        actionItems: ['选择高返现卡', '了解返现规则', '追踪返现收益'],
      ),
    ];
  }

  List<ContentItem> _getBuiltInContents() {
    return [
      ContentItem(
        id: 'content_emergency_fund',
        type: ContentType.financeTip,
        title: '为什么你需要应急基金',
        summary: '应急基金是财务安全的第一道防线，建议储备3-6个月生活费',
        content: '''
应急基金是指专门用于应对突发状况的储蓄，比如失业、疾病、家电维修等。

**为什么需要应急基金？**
1. 避免因突发状况陷入债务
2. 减轻财务压力和焦虑
3. 保护长期投资不被打断

**应急基金要存多少？**
- 单身/稳定工作：3个月生活费
- 有家庭/自由职业：6个月生活费
- 收入不稳定行业：6-12个月生活费

**如何建立应急基金？**
1. 计算月均生活费
2. 确定目标金额
3. 设置自动定期转账
4. 存入高流动性账户
        ''',
        tags: [ContentTag.saving, ContentTag.budgeting],
      ),
      ContentItem(
        id: 'content_latte_factor',
        type: ContentType.financeTip,
        title: '拿铁因子：小钱的大影响',
        summary: '每天一杯咖啡看似不起眼，一年下来可能超过万元',
        content: '''
"拿铁因子"是著名理财作家大卫·巴赫提出的概念，指那些看似微不足道但长期累积金额惊人的小额支出。

**计算你的拿铁因子**
假设每天一杯30元的咖啡：
- 一周：210元
- 一个月：900元
- 一年：10,950元
- 十年：109,500元（不含利息）

**常见的拿铁因子**
- 外卖配送费
- 视频会员自动续费
- 便利店小零食
- 打车代替公交

**如何处理？**
1. 识别你的拿铁因子
2. 评估是否真正需要
3. 找到更经济的替代方案
4. 将节省的钱转入储蓄
        ''',
        tags: [ContentTag.expenseReduce, ContentTag.saving],
      ),
    ];
  }

  // ==================== 内容获取 ====================

  /// 获取每日技巧卡片
  TipCard? getDailyTip() {
    if (_tipCards.isEmpty) return null;

    // 基于日期选择，确保同一天看到相同的技巧
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _tipCards[dayOfYear % _tipCards.length];
  }

  /// 获取随机技巧卡片
  TipCard? getRandomTip({String? category}) {
    var cards = _tipCards;
    if (category != null) {
      cards = cards.where((c) => c.category == category).toList();
    }
    if (cards.isEmpty) return null;
    return cards[Random().nextInt(cards.length)];
  }

  /// 获取所有技巧卡片
  List<TipCard> getAllTipCards({String? category}) {
    if (category == null) return _tipCards;
    return _tipCards.where((c) => c.category == category).toList();
  }

  /// 获取推荐内容
  List<ContentItem> getRecommendedContents({
    int limit = 10,
    ContentType? type,
  }) {
    var contents = _contents;

    if (type != null) {
      contents = contents.where((c) => c.type == type).toList();
    }

    // 根据用户偏好排序
    contents.sort((a, b) {
      // 未读优先
      final aViewed = _viewedContentIds.contains(a.id) ? 1 : 0;
      final bViewed = _viewedContentIds.contains(b.id) ? 1 : 0;
      if (aViewed != bViewed) return aViewed - bViewed;

      // 标签匹配度
      final aMatchCount = a.tags.where((t) => _userPreferences.contains(t)).length;
      final bMatchCount = b.tags.where((t) => _userPreferences.contains(t)).length;
      if (aMatchCount != bMatchCount) return bMatchCount - aMatchCount;

      // 最新优先
      return b.publishedAt.compareTo(a.publishedAt);
    });

    return contents.take(limit).toList();
  }

  /// 获取用户故事
  List<UserStory> getUserStories({int limit = 10}) {
    return _userStories.take(limit).toList();
  }

  /// 按标签获取内容
  List<ContentItem> getContentsByTag(ContentTag tag, {int limit = 10}) {
    return _contents
        .where((c) => c.tags.contains(tag))
        .take(limit)
        .toList();
  }

  /// 搜索内容
  List<ContentItem> searchContents(String query) {
    final lowerQuery = query.toLowerCase();
    return _contents.where((c) {
      return c.title.toLowerCase().contains(lowerQuery) ||
          c.summary.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ==================== 用户交互 ====================

  /// 记录内容查看
  void recordView(String contentId) {
    _viewedContentIds.add(contentId);
    // 更新查看计数
  }

  /// 记录内容点赞
  void toggleLike(String contentId) {
    if (_likedContentIds.contains(contentId)) {
      _likedContentIds.remove(contentId);
    } else {
      _likedContentIds.add(contentId);
    }
  }

  /// 检查是否已点赞
  bool isLiked(String contentId) {
    return _likedContentIds.contains(contentId);
  }

  /// 更新用户偏好
  void updatePreferences(Set<ContentTag> tags) {
    _userPreferences.clear();
    _userPreferences.addAll(tags);
  }

  /// 添加用户偏好
  void addPreference(ContentTag tag) {
    _userPreferences.add(tag);
  }

  // ==================== 内容管理 ====================

  /// 添加用户故事（UGC）
  Future<void> submitUserStory(UserStory story) async {
    // 实际实现中提交到服务器审核
    _userStories.add(story);
  }

  /// 刷新内容库
  Future<void> refreshContents() async {
    // 实际实现中从服务器获取最新内容
  }

  /// 获取技巧卡片分类列表
  List<String> getTipCategories() {
    return _tipCards.map((c) => c.category).toSet().toList();
  }

  /// 获取内容标签列表
  List<ContentTag> getAvailableTags() {
    final tags = <ContentTag>{};
    for (final content in _contents) {
      tags.addAll(content.tags);
    }
    return tags.toList();
  }

  /// 重置（测试用）
  void reset() {
    _viewedContentIds.clear();
    _likedContentIds.clear();
    _userPreferences.clear();
  }
}

/// 全局内容服务实例
final contentMarketingService = ContentMarketingService();
