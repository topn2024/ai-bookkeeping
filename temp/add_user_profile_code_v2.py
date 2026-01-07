# -*- coding: utf-8 -*-
"""添加用户画像相关代码块到代码设计文档"""

file_path = 'd:/code/ai-bookkeeping/docs/design/app_v2_code_design.md'

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 用户画像代码块
user_profile_code = '''### 17.6 用户画像分析系统

#### <a id="code-235-1"></a>代码块 235-1

```dart
/// 用户画像数据模型
class UserProfile {
  final String oderId;
  final BasicAttributes basicAttributes;
  final SpendingBehavior spendingBehavior;
  final FinancialFeatures financialFeatures;
  final PersonalityTraits personalityTraits;
  final LifeStage lifeStage;
  final DateTime lastUpdated;
  final int dataConfidence; // 0-100, 数据置信度

  const UserProfile({
    required this.oderId,
    required this.basicAttributes,
    required this.spendingBehavior,
    required this.financialFeatures,
    required this.personalityTraits,
    required this.lifeStage,
    required this.lastUpdated,
    required this.dataConfidence,
  });

  /// 获取画像摘要（用于LLM prompt）
  String toPromptSummary() {
    return \\\'\\\'\\\'
[用户画像]
- 消费性格: \\$\\${personalityTraits.spendingPersonality.label}
- 财务状态: 储蓄率\\$\\${financialFeatures.savingsRate}%, 钱龄\\$\\${financialFeatures.moneyAgeHealth}
- 沟通偏好: \\$\\${personalityTraits.communicationStyle.label}
- 敏感话题: \\$\\${personalityTraits.sensitiveTacics.join('、')}
- 近期关注: \\$\\${lifeStage.currentFocus ?? '无特别关注'}
\\\'\\\'\\\';
  }
}

/// 基础属性
class BasicAttributes {
  final int usageDays;           // 使用天数
  final double dailyRecordRate;  // 日均记账频率
  final ActiveTimeSlot peakActiveTime; // 活跃时段
  final String? deviceInfo;

  const BasicAttributes({
    required this.usageDays,
    required this.dailyRecordRate,
    required this.peakActiveTime,
    this.deviceInfo,
  });
}

enum ActiveTimeSlot { morning, noon, afternoon, evening, lateNight }

/// 消费行为特征
class SpendingBehavior {
  final double monthlyAverage;      // 月均支出
  final List<String> topCategories; // TOP消费类目
  final SpendingStyle style;        // 消费风格
  final double latteFactorRatio;    // 拿铁因子占比
  final double impulseRatio;        // 冲动消费占比
  final PaymentPreference paymentPreference; // 支付偏好

  const SpendingBehavior({
    required this.monthlyAverage,
    required this.topCategories,
    required this.style,
    required this.latteFactorRatio,
    required this.impulseRatio,
    required this.paymentPreference,
  });
}

enum SpendingStyle { frugal, balanced, generous, impulsive }
enum PaymentPreference { online, offline, mixed }

/// 财务特征
class FinancialFeatures {
  final IncomeStability incomeStability;
  final double savingsRate;         // 储蓄率 %
  final String moneyAgeHealth;      // 钱龄健康度
  final double budgetComplianceRate;// 预算达成率
  final double emergencyFundMonths; // 应急金月数
  final DebtLevel debtLevel;

  const FinancialFeatures({
    required this.incomeStability,
    required this.savingsRate,
    required this.moneyAgeHealth,
    required this.budgetComplianceRate,
    required this.emergencyFundMonths,
    required this.debtLevel,
  });
}

enum IncomeStability { stable, variable, irregular }
enum DebtLevel { none, low, moderate, high }

/// 性格特征（推断）
class PersonalityTraits {
  final SpendingPersonality spendingPersonality;
  final DecisionStyle decisionStyle;
  final EmotionalTendency emotionalTendency;
  final CommunicationStyle communicationStyle;
  final double humorAcceptance;     // 幽默接受度 0-1
  final List<String> sensitiveTacics; // 敏感话题

  const PersonalityTraits({
    required this.spendingPersonality,
    required this.decisionStyle,
    required this.emotionalTendency,
    required this.communicationStyle,
    required this.humorAcceptance,
    required this.sensitiveTacics,
  });
}

enum SpendingPersonality {
  frugalRational('节俭理性型'),
  enjoymentOriented('享乐消费型'),
  anxiousWorrier('焦虑担忧型'),
  goalDriven('目标导向型'),
  casualBuddhist('随性佛系型');

  final String label;
  const SpendingPersonality(this.label);
}

enum DecisionStyle { impulsive, cautious, analytical }
enum EmotionalTendency { optimistic, neutral, anxious }
enum CommunicationStyle {
  concise('简洁直接'),
  detailed('详细解释'),
  emotional('情感共鸣');

  final String label;
  const CommunicationStyle(this.label);
}

/// 生活阶段
class LifeStage {
  final LifePhase phase;
  final FamilyStatus familyStatus;
  final CareerType careerType;
  final CityTier cityTier;
  final String? currentFocus; // 近期关注目标

  const LifeStage({
    required this.phase,
    required this.familyStatus,
    required this.careerType,
    required this.cityTier,
    this.currentFocus,
  });
}

enum LifePhase { student, youngProfessional, midCareer, senior }
enum FamilyStatus { single, married, withChildren, emptyNest }
enum CareerType { employed, freelance, entrepreneur, retired }
enum CityTier { tier1, tier2, tier3, other }
```

*来源: 第17章用户画像分析系统*

#### <a id="code-235-2"></a>代码块 235-2

```dart
/// 用户画像分析引擎
class UserProfileAnalyzer {
  final TransactionRepository _transactions;
  final BudgetRepository _budgets;
  final UserActivityLogger _activityLogger;

  UserProfileAnalyzer(this._transactions, this._budgets, this._activityLogger);

  /// 构建完整用户画像
  Future<UserProfile> buildProfile(String oderId) async {
    final transactions = await _transactions.getAll(oderId);
    final budgets = await _budgets.getAll(oderId);
    final activities = await _activityLogger.getActivities(oderId);

    // 并行分析各维度
    final results = await Future.wait([
      _analyzeBasicAttributes(activities),
      _analyzeSpendingBehavior(transactions),
      _analyzeFinancialFeatures(transactions, budgets),
      _inferPersonalityTraits(transactions, activities),
      _inferLifeStage(transactions),
    ]);

    return UserProfile(
      oderId: oderId,
      basicAttributes: results[0] as BasicAttributes,
      spendingBehavior: results[1] as SpendingBehavior,
      financialFeatures: results[2] as FinancialFeatures,
      personalityTraits: results[3] as PersonalityTraits,
      lifeStage: results[4] as LifeStage,
      lastUpdated: DateTime.now(),
      dataConfidence: _calculateConfidence(transactions.length),
    );
  }

  /// 分析消费行为
  Future<SpendingBehavior> _analyzeSpendingBehavior(List<Transaction> txs) async {
    final expenses = txs.where((t) => t.type == TransactionType.expense).toList();
    final monthlyAverage = _calculateMonthlyAverage(expenses);

    // 分析TOP类目
    final categoryStats = <String, double>{};
    for (final tx in expenses) {
      categoryStats[tx.category] = (categoryStats[tx.category] ?? 0) + tx.amount;
    }
    final topCategories = categoryStats.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(3)
        .map((e) => e.key)
        .toList();

    // 分析拿铁因子（小额高频消费）
    final smallExpenses = expenses.where((t) => t.amount < 50).length;
    final latteFactorRatio = expenses.isEmpty ? 0 : smallExpenses / expenses.length;

    // 分析冲动消费
    final impulseRatio = _calculateImpulseRatio(expenses);
    final style = _inferSpendingStyle(monthlyAverage, latteFactorRatio, impulseRatio);

    return SpendingBehavior(
      monthlyAverage: monthlyAverage,
      topCategories: topCategories,
      style: style,
      latteFactorRatio: latteFactorRatio,
      impulseRatio: impulseRatio,
      paymentPreference: PaymentPreference.mixed,
    );
  }

  /// 推断性格特征
  Future<PersonalityTraits> _inferPersonalityTraits(
    List<Transaction> txs,
    List<UserActivity> activities,
  ) async {
    final behavior = await _analyzeSpendingBehavior(txs);

    SpendingPersonality personality;
    if (behavior.latteFactorRatio < 0.1 && behavior.impulseRatio < 0.1) {
      personality = SpendingPersonality.frugalRational;
    } else if (behavior.impulseRatio > 0.3) {
      personality = SpendingPersonality.enjoymentOriented;
    } else {
      personality = SpendingPersonality.goalDriven;
    }

    final avgSessionTime = _calculateAvgSessionTime(activities);
    final communicationStyle = avgSessionTime < 60
        ? CommunicationStyle.concise
        : CommunicationStyle.detailed;

    final sensitiveTacics = <String>[];
    if (behavior.monthlyAverage > 10000) {
      sensitiveTacics.add('大额支出');
    }

    return PersonalityTraits(
      spendingPersonality: personality,
      decisionStyle: behavior.impulseRatio > 0.2
          ? DecisionStyle.impulsive
          : DecisionStyle.cautious,
      emotionalTendency: EmotionalTendency.neutral,
      communicationStyle: communicationStyle,
      humorAcceptance: 0.7,
      sensitiveTacics: sensitiveTacics,
    );
  }

  int _calculateConfidence(int transactionCount) {
    if (transactionCount < 30) return 30;
    if (transactionCount < 100) return 60;
    if (transactionCount < 300) return 80;
    return 95;
  }
}
```

*来源: 第17章用户画像分析系统*

#### <a id="code-235-3"></a>代码块 235-3

```dart
/// 用户画像服务接口
class UserProfileService {
  final UserProfileAnalyzer _analyzer;
  final UserProfileRepository _repository;
  final CacheManager _cache;

  static const _cacheKey = 'user_profile';
  static const _cacheDuration = Duration(hours: 1);

  UserProfileService(this._analyzer, this._repository, this._cache);

  Future<UserProfile?> getProfile(String oderId) async {
    final cached = await _cache.get<UserProfile>('${_cacheKey}_$oderId');
    if (cached != null) return cached;

    var profile = await _repository.get(oderId);
    if (profile == null || _isStale(profile)) {
      profile = await rebuildProfile(oderId);
    }

    if (profile != null) {
      await _cache.set('${_cacheKey}_$oderId', profile, _cacheDuration);
    }
    return profile;
  }

  Future<String> getProfileSummary(String oderId) async {
    final profile = await getProfile(oderId);
    return profile?.toPromptSummary() ?? '暂无用户画像数据';
  }

  Future<ConversationContext> getConversationContext(String oderId) async {
    final profile = await getProfile(oderId);
    if (profile == null) return ConversationContext.defaultContext();

    return ConversationContext(
      toneStyle: _mapPersonalityToTone(profile.personalityTraits),
      humorLevel: profile.personalityTraits.humorAcceptance,
      detailLevel: _mapCommunicationToDetail(profile.personalityTraits.communicationStyle),
      sensitiveTacics: profile.personalityTraits.sensitiveTacics,
      recentFocus: profile.lifeStage.currentFocus,
    );
  }

  Future<UserProfile?> rebuildProfile(String oderId) async {
    try {
      final profile = await _analyzer.buildProfile(oderId);
      await _repository.save(profile);
      return profile;
    } catch (e) {
      return null;
    }
  }

  ToneStyle _mapPersonalityToTone(PersonalityTraits traits) {
    switch (traits.spendingPersonality) {
      case SpendingPersonality.frugalRational: return ToneStyle.professionalPositive;
      case SpendingPersonality.enjoymentOriented: return ToneStyle.playfulHumorous;
      case SpendingPersonality.anxiousWorrier: return ToneStyle.warmReassuring;
      case SpendingPersonality.goalDriven: return ToneStyle.dataDriven;
      case SpendingPersonality.casualBuddhist: return ToneStyle.casualDirect;
    }
  }

  bool _isStale(UserProfile profile) {
    return DateTime.now().difference(profile.lastUpdated) > const Duration(days: 1);
  }
}

class ConversationContext {
  final ToneStyle toneStyle;
  final double humorLevel;
  final DetailLevel detailLevel;
  final List<String> sensitiveTacics;
  final String? recentFocus;

  const ConversationContext({
    required this.toneStyle,
    required this.humorLevel,
    required this.detailLevel,
    required this.sensitiveTacics,
    this.recentFocus,
  });

  factory ConversationContext.defaultContext() => const ConversationContext(
    toneStyle: ToneStyle.warmReassuring,
    humorLevel: 0.5,
    detailLevel: DetailLevel.moderate,
    sensitiveTacics: [],
  );
}

enum ToneStyle { professionalPositive, playfulHumorous, warmReassuring, dataDriven, casualDirect }
enum DetailLevel { minimal, moderate, detailed }
```

*来源: 第17章用户画像分析系统*

### 17.7 画像驱动的智能对话

#### <a id="code-235-4"></a>代码块 235-4

```dart
/// 画像驱动对话服务
class ProfileDrivenDialogService {
  final UserProfileService _profileService;
  final LLMService _llmService;
  final ConversationHistoryService _historyService;

  ProfileDrivenDialogService(this._profileService, this._llmService, this._historyService);

  Future<String> generateResponse({
    required String oderId,
    required String userMessage,
    required DialogIntent intent,
    Map<String, dynamic>? additionalContext,
  }) async {
    final profileContext = await _profileService.getConversationContext(oderId);
    final history = await _historyService.getRecentMessages(oderId, limit: 5);
    final systemPrompt = _buildSystemPrompt(profileContext, intent);

    final response = await _llmService.chat(
      systemPrompt: systemPrompt,
      messages: [
        ...history.map((m) => ChatMessage(role: m.role, content: m.content)),
        ChatMessage(role: 'user', content: userMessage),
      ],
      additionalContext: additionalContext,
    );

    await _historyService.saveMessage(oderId, 'user', userMessage);
    await _historyService.saveMessage(oderId, 'assistant', response);
    return response;
  }

  String _buildSystemPrompt(ConversationContext context, DialogIntent intent) {
    final buffer = StringBuffer();
    buffer.writeln('你是"记账喵"，一个贴心的财务小助手。');
    buffer.writeln();
    buffer.writeln('[用户特征]');
    buffer.writeln('- 沟通风格偏好: ${_describeToneStyle(context.toneStyle)}');
    buffer.writeln('- 幽默接受度: ${(context.humorLevel * 100).toInt()}%');
    buffer.writeln('- 详略偏好: ${_describeDetailLevel(context.detailLevel)}');

    if (context.sensitiveTacics.isNotEmpty) {
      buffer.writeln('- 敏感话题: ${context.sensitiveTacics.join("、")}（需温和处理）');
    }
    if (context.recentFocus != null) {
      buffer.writeln('- 近期关注: ${context.recentFocus}');
    }

    buffer.writeln();
    buffer.writeln('[回复要求]');
    buffer.writeln('- 根据用户特征调整语气和详略程度');
    buffer.writeln('- 涉及敏感话题时温和引导，不要说教');
    buffer.writeln('- 可以适当使用表情，但不要过多');
    buffer.writeln('- 保持积极正向，给予鼓励');
    return buffer.toString();
  }

  String _describeToneStyle(ToneStyle style) {
    switch (style) {
      case ToneStyle.professionalPositive: return '专业肯定，少用表情';
      case ToneStyle.playfulHumorous: return '轻松幽默，可适度调侃';
      case ToneStyle.warmReassuring: return '温暖安抚，多用鼓励';
      case ToneStyle.dataDriven: return '数据驱动，简洁高效';
      case ToneStyle.casualDirect: return '简洁直接，不啰嗦';
    }
  }

  String _describeDetailLevel(DetailLevel level) {
    switch (level) {
      case DetailLevel.minimal: return '只要核心信息';
      case DetailLevel.moderate: return '适中详细程度';
      case DetailLevel.detailed: return '详细解释说明';
    }
  }
}
```

*来源: 第17章画像驱动的智能对话*

#### <a id="code-235-5"></a>代码块 235-5

```dart
/// 闲聊对话服务
class CasualChatService {
  final ProfileDrivenDialogService _dialogService;
  final UserProfileService _profileService;
  final TransactionRepository _transactions;

  CasualChatService(this._dialogService, this._profileService, this._transactions);

  CasualChatIntent identifyIntent(String message) {
    final lowerMessage = message.toLowerCase();

    if (_matchesPatterns(lowerMessage, ['早上好', '晚上好', '你好', '在吗', 'hi', 'hello'])) {
      return CasualChatIntent.greeting;
    }
    if (_matchesPatterns(lowerMessage, ['开心', '高兴', '难过', '伤心', '累', '烦'])) {
      return CasualChatIntent.moodShare;
    }
    if (_matchesPatterns(lowerMessage, ['存不下钱', '为什么', '怎么理财', '月光'])) {
      return CasualChatIntent.financeChat;
    }
    if (_matchesPatterns(lowerMessage, ['是不是花太多', '我很差', '控制不住'])) {
      return CasualChatIntent.seekEncouragement;
    }
    if (_matchesPatterns(lowerMessage, ['钱不够', '太贵', '没钱', '穷'])) {
      return CasualChatIntent.complain;
    }
    return CasualChatIntent.general;
  }

  Future<String> generateChatResponse({
    required String oderId,
    required String userMessage,
  }) async {
    final intent = identifyIntent(userMessage);
    Map<String, dynamic>? financialContext;
    if (intent == CasualChatIntent.seekEncouragement || intent == CasualChatIntent.complain) {
      financialContext = await _getFinancialContext(oderId);
    }

    return _dialogService.generateResponse(
      oderId: oderId,
      userMessage: userMessage,
      intent: DialogIntent.casualChat,
      additionalContext: {
        'casualChatIntent': intent.name,
        'timeOfDay': _getTimeOfDay(),
        if (financialContext != null) ...financialContext,
      },
    );
  }

  Future<Map<String, dynamic>> _getFinancialContext(String oderId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final monthlyExpenses = await _transactions.getExpensesBetween(oderId, startOfMonth, now);
    final total = monthlyExpenses.fold<double>(0, (sum, t) => sum + t.amount);
    return {'monthlySpending': total, 'isWithinBudget': true, 'comparedToLastMonth': '-12%'};
  }

  bool _matchesPatterns(String message, List<String> patterns) => patterns.any(message.contains);
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'lateNight';
    if (hour < 12) return 'morning';
    if (hour < 14) return 'noon';
    if (hour < 18) return 'afternoon';
    if (hour < 22) return 'evening';
    return 'lateNight';
  }
}

enum CasualChatIntent { greeting, moodShare, financeChat, seekEncouragement, complain, general }
```

*来源: 第17章画像驱动的智能对话*

### 17.8 用户画像可视化

#### <a id="code-235-6"></a>代码块 235-6

```dart
/// 用户画像可视化页面
class UserProfilePage extends StatefulWidget {
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profileService = context.read<UserProfileService>();
    final profile = await profileService.getProfile(currentUserId);
    setState(() { _profile = profile; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_profile == null) return const _InsufficientDataView();

    return Scaffold(
      appBar: AppBar(title: const Text('我的财务画像')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _PersonalityTagsCard(profile: _profile!),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _SpendingFeatureCard(profile: _profile!)),
            const SizedBox(width: 16),
            Expanded(child: _FinancialHealthCard(profile: _profile!)),
          ]),
          const SizedBox(height: 16),
          _AbilityRadarChart(profile: _profile!),
          const SizedBox(height: 16),
          _AICommentCard(profile: _profile!),
          const SizedBox(height: 16),
          _PrivacyControlCard(onClear: _clearProfile, onDisable: _disablePersonalization),
        ]),
      ),
    );
  }

  Future<void> _clearProfile() async {
    final confirmed = await showConfirmDialog(
      context, title: '清除画像数据', message: '确定要清除所有画像数据吗？这将重置个性化体验。',
    );
    if (confirmed) {
      await context.read<UserProfileService>().clearProfile(currentUserId);
      setState(() => _profile = null);
    }
  }

  Future<void> _disablePersonalization() async { /* 关闭个性化功能 */ }
}

class _PersonalityTagsCard extends StatelessWidget {
  final UserProfile profile;
  const _PersonalityTagsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tags = _generateTags();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_outline),
            const SizedBox(width: 8),
            Text('财务人格标签', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: tags.map((tag) => Chip(
              label: Text(tag),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )).toList(),
          ),
        ]),
      ),
    );
  }

  List<String> _generateTags() {
    final tags = <String>[profile.personalityTraits.spendingPersonality.label];
    if (profile.financialFeatures.savingsRate > 20) tags.add('储蓄达人');
    if (profile.financialFeatures.budgetComplianceRate > 90) tags.add('预算执行官');
    if (profile.basicAttributes.peakActiveTime == ActiveTimeSlot.morning) tags.add('早起记账族');
    return tags;
  }
}

class _AICommentCard extends StatelessWidget {
  final UserProfile profile;
  const _AICommentCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final comment = _generateAIComment();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.chat_bubble_outline),
            const SizedBox(width: 8),
            Text('AI小助手怎么看你', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(comment, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ]),
      ),
    );
  }

  String _generateAIComment() {
    final personality = profile.personalityTraits.spendingPersonality;
    final topCategory = profile.spendingBehavior.topCategories.firstOrNull ?? '日常消费';
    switch (personality) {
      case SpendingPersonality.frugalRational:
        return '你是一个非常有规划的人！每月都能按时记账，预算执行得很棒。在$topCategory方面有固定偏好，消费很有节制。继续保持！';
      case SpendingPersonality.goalDriven:
        return '你是一个目标明确的人！说明你在为某个目标努力存钱。记住，每一笔节省都是向目标迈进的一步！';
      default:
        return '感谢你一直以来的记账习惯！我会持续关注你的财务状况，为你提供更好的建议。';
    }
  }
}
```

*来源: 第17章用户画像可视化*

### 17.9 目标达成检测

'''

# 查找插入位置
old_text = '### 17.6\n\n#### <a id="code-235"></a>代码块 235'
new_text = user_profile_code + '#### <a id="code-235"></a>代码块 235'

if old_text in content:
    content = content.replace(old_text, new_text)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK: 成功添加用户画像相关代码块（235-1到235-6）')
    print('  - 17.6 用户画像分析系统')
    print('  - 17.7 画像驱动的智能对话')
    print('  - 17.8 用户画像可视化')
    print('  - 17.9 目标达成检测（原17.6）')
else:
    print('ERROR: 未找到目标位置')
    idx = content.find('### 17.6')
    if idx != -1:
        print(f'找到 ### 17.6 位置: {idx}')
        print('内容预览:', repr(content[idx:idx+100]))
