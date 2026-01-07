# -*- coding: utf-8 -*-
"""
刷新第21章国际化与本地化
1. 修复章节编号错误（24.0.x -> 21.0.x）
2. 添加与其他系统的协同关系图
3. 添加21.10与其他系统集成部分
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 修复章节编号错误 ==========
    # 24.0.1 -> 21.0.1
    if '#### 24.0.1 国际化设计原则' in content:
        content = content.replace('#### 24.0.1 国际化设计原则', '#### 21.0.1 国际化设计原则')
        print("✓ 修复1a: 24.0.1 -> 21.0.1")
        changes += 1

    # 24.0.2 -> 21.0.2
    if '#### 24.0.2 2.0版本国际化目标' in content:
        content = content.replace('#### 24.0.2 2.0版本��际化目标', '#### 21.0.2 2.0版本国际化目标')
        print("✓ 修复1b: 24.0.2 -> 21.0.2")
        changes += 1

    # ========== 修复2: 增强21.0设计原则回顾，添加协同关系图 ==========
    old_section = '''### 21.0 设计原则与目标

#### 21.0.1 国际化设计原则

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          国际化设计原则                                      │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │  文化适应性  │    │  一致性体验  ���    │  灵活扩展   │    │  性能优先   │ │
│  │  Cultural   │    │  Consistent │    │  Extensible │    │  Performance│ │
│  │  Adaptation │    │  Experience │    │   Design    │    │    First    │ │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘ │
│       ↓                  ↓                  ↓                  ↓          │
│   尊重不同地区       所有语言版本         易于添加新语言       本地化资源      │
│   的文化习惯         功能体验一致         最小代码改动         按需加载        │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 21.0.2 2.0版本国际化目标'''

    new_section = '''### 21.0 设计原则回顾

在深入国际化与本地化细节之前，让我们回顾本章如何体现2.0版本的核心设计原则：

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      国际化与本地化 - 设计原则矩阵                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  文化适应    │  │  一致体验    │  │  灵活扩展    │  │  性能优先    │       │
│  │             │  │             │  │             │  │             │       │
│  │ 尊重文化    │  │ 功能一致    │  │ 易于扩展    │  │ 按需加载    │       │
│  │ 本地习惯    │  │ 体验统一    │  │ 最小改动    │  │ 懒加载资源  │       │
│  └─────────────┘  └─────────────┘  └──────────���──┘  └─────────────┘       │
│         │                │                │                │              │
│         ▼                ▼                ▼                ▼              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  货币格式    │  │  日期时间    │  │  分类翻译    │  │  AI本地化   │       │
│  │             │  │             │  │             │  │             │       │
│  │ 地区符号    │  │ 地区格式    │  │ 多语言名称  │  │ 语言输出    │       │
│  │ 千分位      │  │ 时区处理    │  │ 图标适配    │  │ 提示词翻译  │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                            │
│  国际化核心理念：                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │  "文化尊重，体验一致，灵活扩展，性能优先"                              │   │
│  │                                                                    │   │
│  │   文化尊重 ──→ 尊重不同地区的语言、货币、日期习惯                       │   │
│  │   体验一致 ──→ 所有语言版本功能完整、体验统一                          │   │
│  │   灵活扩展 ──→ 易于添加新语言，最小代码改动                            │   │
│  │   性能优先 ──→ 语言资源按需加载，不影响启动速度                         │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 21.0.1 设计原则在国际化中的体现

| 设计原则 | 国际化应用 | 具体措施 | 效果指标 |
|---------|---------|---------|---------|
| **文化适应** | 本地化内容 | 货币符号、日期格式、分类名称 | 用户满意度>90% |
| **一致体验** | 功能完整 | 所有语言版本功能相同 | 功能覆盖率100% |
| **灵活扩展** | ARB架构 | 使用Flutter intl标准 | 新语言<1天上线 |
| **性能优先** | 懒加载 | 语言包按需加载 | 启动时间无增加 |
| **AI本地化** | 多语言输出 | AI建议使用用户语言 | AI理解准确率>95% |
| **RTL预留** | 架构支持 | 布局支持RTL扩展 | 阿拉伯语可快速适配 |

#### 21.0.2 与其他系统的协同关系

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      国际化与其他模块的协同关系                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│                        ┌─────────────────────────┐                         │
│                        │   21. 国际化与本地化     │                         │
│                        │       （本章）           │                         │
│                        └───────────┬─────────────┘                         │
│                                    │                                       │
│        ┌──────────────���────────────┼───────────────────────────┐           │
���        │                           │                           │           │
│        ▼                           ▼                           ▼           │
│   ┌──────────┐              ┌──────────┐              ┌──────────┐        │
│   │ 10.AI    │              │ 11.分类   │              │ 20.用户   │        │
│   │  识别    │              │  系统    │              │  体验    │        │
│   │ ──────── │              │ ──────── │              │ ──────── │        │
│   │ AI多语言 │              │ 分类翻译 │              │ UI文本   │        │
│   │ 理解输出 │              │ 图标适配 │              │ 本地化   │        │
│   └──────────┘              └──────────┘              └──────────┘        │
│        │                           │                           │           │
│        └───────────────────────────┼───────────────────────────┘           │
│                                    ▼                                       │
│                        ┌─────────────────────────┐                         │
│                        │   15. 技术架构          │                         │
│                        │   - 资源加载机制        │                         │
│                        │   - 缓存策略            │                         │
│                        └─────────────────────────┘                         │
│                                                                            │
│  ════════════════════════════════════════════════════════════════════════  │
│                           2.0新增协作模块                                   │
│  ════════════════════════════════════════════════════════════════════════  │
│                                                                            │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│   │18.语音   │  │14.位置   │  │13.家庭   │  │9.习惯    │  │28-29.增长│   │
│   │  交互    │  │  智能    │  │  账本    │  │  培养    │  │  体系    │   │
│   │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │   │
│   │语音识别  │  │城市POI   │  │成员名称  │  │成就文案  │  │邀请文案  │   │
│   │多语言    │  │本地化    │  │多语言    │  │多语言    │  │多语言    │   │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 21.0.3 2.0版本国际化目标'''

    if old_section in content:
        content = content.replace(old_section, new_section)
        print("✓ 修复2: 增强21.0设计原则回顾，添加协同关系图")
        changes += 1

    # ========== 修复3: 在21.9之后添加21.10与其他系统集成 ==========
    chapter22_start = '## 22. 安全与隐私'

    new_section_21_10 = '''### 21.10 与其他系统集成

#### 21.10.1 系统集成概览

国际化系统与其他2.0模块的集成确保所有用户界面和内容正确本地化：

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        国际化集成全景图                                      │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                        国际化核心服务                                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │ 语言管理  │  │ 货币格式  │  │ 日期格式  │  │ 资源加载  │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘           │  │
│  └───────────────────────────┬─────────────────────────────────────────┘  │
│                              │                                            │
│         ┌────────────────────┼────────────────────┐                       │
│         │                    │                    │                       │
│         ▼                    ▼                    ▼                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                 │
│  │  UI文本      │     │  数据格式    │     │  AI内容      │                 │
│  │  本地化      │     │  本地化      │     │  本地化      │                 │
│  ├─────────────┤     ├─────────────┤     ├─────────────┤                 │
│  │ • 页面文本   │     │ • 货币显示   │     │ • 语音识别   │                 │
│  │ • 按钮标签   │     │ • 日期显示   │     │ • AI建议     │                 │
│  │ • 提示信息   │     │ • 数字格式   │     │ • 洞察文案   │                 │
│  └─────────────┘     └─────────────┘     └─────────────┘                 │
│                                                                            │
└──────��─────────────────────────────────────────────────────────────────────┘
```

#### 21.10.2 语音交互系统集��

```dart
/// 语音识别多语言集成
class VoiceI18nService {
  final LocaleProvider _localeProvider;
  final VoiceRecognitionService _voiceService;

  /// 获取当前语言的语音识别配置
  VoiceRecognitionConfig getVoiceConfig() {
    final locale = _localeProvider.currentLocale;

    return VoiceRecognitionConfig(
      // 语音识别语言
      recognitionLocale: _mapToRecognitionLocale(locale),

      // 数字表达模式（不同语言数字表达方式不同）
      numberPatterns: _getNumberPatterns(locale),

      // 货币表达模式
      currencyPatterns: _getCurrencyPatterns(locale),

      // 日期表达模式
      datePatterns: _getDatePatterns(locale),
    );
  }

  /// 映射到语音识别支持的语言
  String _mapToRecognitionLocale(Locale locale) {
    final mappings = {
      'zh_CN': 'cmn-Hans-CN',  // 普通话（简体）
      'zh_TW': 'cmn-Hant-TW',  // 普通话（繁体）
      'en': 'en-US',           // 英语
      'ja': 'ja-JP',           // 日语
      'ko': 'ko-KR',           // 韩语
    };
    return mappings[locale.toString()] ?? 'en-US';
  }

  /// 获取数字表达模式
  List<NumberPattern> _getNumberPatterns(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return [
          NumberPattern(regex: r'(\d+)块', multiplier: 1),      // 10块
          NumberPattern(regex: r'(\d+)毛', multiplier: 0.1),    // 5毛
          NumberPattern(regex: r'(\d+)分', multiplier: 0.01),   // 3分
          NumberPattern(regex: r'(\d+)百', multiplier: 100),    // 3百
          NumberPattern(regex: r'(\d+)千', multiplier: 1000),   // 2千
          NumberPattern(regex: r'(\d+)万', multiplier: 10000),  // 1万
        ];
      case 'ja':
        return [
          NumberPattern(regex: r'(\d+)円', multiplier: 1),      // 100円
          NumberPattern(regex: r'(\d+)百円', multiplier: 100),  // 3百円
          NumberPattern(regex: r'(\d+)千円', multiplier: 1000), // 2千円
          NumberPattern(regex: r'(\d+)万円', multiplier: 10000),// 1万円
        ];
      case 'ko':
        return [
          NumberPattern(regex: r'(\d+)원', multiplier: 1),      // 1000원
          NumberPattern(regex: r'(\d+)백원', multiplier: 100),  // 5백원
          NumberPattern(regex: r'(\d+)천원', multiplier: 1000), // 3천원
          NumberPattern(regex: r'(\d+)만원', multiplier: 10000),// 1만원
        ];
      default: // en
        return [
          NumberPattern(regex: r'\$(\d+\.?\d*)', multiplier: 1),
          NumberPattern(regex: r'(\d+\.?\d*)\s*dollars?', multiplier: 1),
          NumberPattern(regex: r'(\d+\.?\d*)\s*cents?', multiplier: 0.01),
        ];
    }
  }

  /// 本地化语音提示
  String getVoicePrompt(VoicePromptType type) {
    final l10n = AppLocalizations.of(_localeProvider.context);

    switch (type) {
      case VoicePromptType.listening:
        return l10n.voiceListening; // "正在聆听..."
      case VoicePromptType.processing:
        return l10n.voiceProcessing; // "AI正在理解..."
      case VoicePromptType.success:
        return l10n.voiceSuccess; // "识别完成"
      case VoicePromptType.error:
        return l10n.voiceError; // "识别失败，请重试"
      case VoicePromptType.hint:
        return l10n.voiceHint; // "试试说：午餐花了25块"
    }
  }
}
```

#### 21.10.3 AI系统集成

```dart
/// AI内容本地化服务
class AILocalizationService {
  final LocaleProvider _localeProvider;
  final AIService _aiService;

  /// 获取本地化的AI提示词
  String getLocalizedPrompt(AIPromptType type, Map<String, dynamic> params) {
    final locale = _localeProvider.currentLocale;
    final template = _getPromptTemplate(type, locale);

    // 替换参数
    var prompt = template;
    params.forEach((key, value) {
      prompt = prompt.replaceAll('{$key}', value.toString());
    });

    return prompt;
  }

  /// 获取提示词模板
  String _getPromptTemplate(AIPromptType type, Locale locale) {
    final templates = _promptTemplates[locale.languageCode] ??
        _promptTemplates['en']!;
    return templates[type] ?? '';
  }

  static const _promptTemplates = {
    'zh': {
      AIPromptType.parseTransaction: '''
请分析以下内容并提取交易信息：
"{input}"

请以JSON格式返回：
- amount: 金额（数字）
- category: 分类（中文）
- description: 描述
- date: 日期（如果提及）
''',
      AIPromptType.generateInsight: '''
基于用户的消费数据生成个性化洞察：
- 本月消费总额：{totalSpending}元
- 主要消费分类：{topCategories}
- 消费趋势：{trend}

请用简洁友好的中文给出2-3条建议。
''',
      AIPromptType.suggestBudget: '''
根据用户的历史消费模式，推荐下月预算分配：
- 月收入：{income}元
- 过去3月平均消费：{avgSpending}元
- 消费分类分布：{categoryDistribution}

请用中文给出预算建议。
''',
    },
    'en': {
      AIPromptType.parseTransaction: '''
Please analyze the following content and extract transaction information:
"{input}"

Return in JSON format:
- amount: Amount (number)
- category: Category (English)
- description: Description
- date: Date (if mentioned)
''',
      AIPromptType.generateInsight: '''
Generate personalized insights based on user spending data:
- Total spending this month: \${totalSpending}
- Top spending categories: {topCategories}
- Spending trend: {trend}

Please provide 2-3 suggestions in concise, friendly English.
''',
      AIPromptType.suggestBudget: '''
Recommend next month's budget allocation based on spending patterns:
- Monthly income: \${income}
- Average spending (past 3 months): \${avgSpending}
- Category distribution: {categoryDistribution}

Please provide budget recommendations in English.
''',
    },
    'ja': {
      AIPromptType.parseTransaction: '''
以下の内容を分析し、取引情報を抽出してください：
「{input}」

JSON形式で返してください：
- amount: 金額（数値）
- category: カテゴリー（日本語）
- description: 説明
- date: 日付（言及されている場合）
''',
    },
    'ko': {
      AIPromptType.parseTransaction: '''
다음 내용을 분석하고 거래 정보를 추출해 주세요:
"{input}"

JSON 형식으로 반환해 주세요:
- amount: 금액 (숫자)
- category: 카테고리 (한국어)
- description: 설명
- date: 날짜 (언급된 경우)
''',
    },
  };

  /// 本地化AI生成的建议
  Future<LocalizedInsight> generateLocalizedInsight(
    InsightData data,
  ) async {
    final prompt = getLocalizedPrompt(
      AIPromptType.generateInsight,
      {
        'totalSpending': data.totalSpending,
        'topCategories': data.topCategories.join(', '),
        'trend': data.trend,
      },
    );

    final response = await _aiService.generate(prompt);

    return LocalizedInsight(
      content: response,
      locale: _localeProvider.currentLocale,
      generatedAt: DateTime.now(),
    );
  }
}
```

#### 21.10.4 分类系统集成

```dart
/// 分类本地化服务
class CategoryLocalizationService {
  final LocaleProvider _localeProvider;

  /// 预设分类的多语言名称
  static const _categoryTranslations = {
    'food': {
      'zh_CN': '餐饮',
      'zh_TW': '餐飲',
      'en': 'Food & Dining',
      'ja': '食費',
      'ko': '식비',
    },
    'transport': {
      'zh_CN': '交通',
      'zh_TW': '交通',
      'en': 'Transportation',
      'ja': '交通費',
      'ko': '교통',
    },
    'shopping': {
      'zh_CN': '购物',
      'zh_TW': '購物',
      'en': 'Shopping',
      'ja': '買い物',
      'ko': '쇼핑',
    },
    'entertainment': {
      'zh_CN': '娱乐',
      'zh_TW': '娛樂',
      'en': 'Entertainment',
      'ja': '娯楽',
      'ko': '오락',
    },
    'healthcare': {
      'zh_CN': '医疗',
      'zh_TW': '醫療',
      'en': 'Healthcare',
      'ja': '医療',
      'ko': '의료',
    },
    'education': {
      'zh_CN': '教育',
      'zh_TW': '教育',
      'en': 'Education',
      'ja': '教育',
      'ko': '교육',
    },
    'housing': {
      'zh_CN': '住房',
      'zh_TW': '住房',
      'en': 'Housing',
      'ja': '住居',
      'ko': '주거',
    },
    'utilities': {
      'zh_CN': '水电煤',
      'zh_TW': '水電瓦斯',
      'en': 'Utilities',
      'ja': '光熱費',
      'ko': '공과금',
    },
  };

  /// 获取本地化的分类名称
  String getLocalizedCategoryName(String categoryKey) {
    final locale = _localeProvider.currentLocale;
    final localeKey = '${locale.languageCode}_${locale.countryCode}';

    final translations = _categoryTranslations[categoryKey];
    if (translations == null) return categoryKey;

    // 优先使用完整locale，fallback到语言代码
    return translations[localeKey] ??
        translations[locale.languageCode] ??
        translations['en'] ??
        categoryKey;
  }

  /// 获取所有本地化分类列表
  List<LocalizedCategory> getAllLocalizedCategories() {
    return _categoryTranslations.entries.map((entry) {
      return LocalizedCategory(
        key: entry.key,
        name: getLocalizedCategoryName(entry.key),
        icon: _getCategoryIcon(entry.key),
      );
    }).toList();
  }

  /// 反向查找：从本地化名称获取分类key
  String? getCategoryKeyFromLocalizedName(String localizedName) {
    final locale = _localeProvider.currentLocale;
    final localeKey = '${locale.languageCode}_${locale.countryCode}';

    for (final entry in _categoryTranslations.entries) {
      final translations = entry.value;
      if (translations[localeKey] == localizedName ||
          translations[locale.languageCode] == localizedName) {
        return entry.key;
      }
    }
    return null;
  }
}
```

#### 21.10.5 货币格式集成

```dart
/// 货币本地化服务
class CurrencyLocalizationService {
  final LocaleProvider _localeProvider;

  /// 支持的货币配置
  static const _currencyConfigs = {
    'CNY': CurrencyConfig(
      code: 'CNY',
      symbol: '¥',
      name: {'zh': '人民币', 'en': 'Chinese Yuan', 'ja': '人民元', 'ko': '중국 위안'},
      decimalDigits: 2,
      symbolPosition: SymbolPosition.before,
      thousandsSeparator: ',',
      decimalSeparator: '.',
    ),
    'USD': CurrencyConfig(
      code: 'USD',
      symbol: '\$',
      name: {'zh': '美元', 'en': 'US Dollar', 'ja': '米ドル', 'ko': '미국 달러'},
      decimalDigits: 2,
      symbolPosition: SymbolPosition.before,
      thousandsSeparator: ',',
      decimalSeparator: '.',
    ),
    'JPY': CurrencyConfig(
      code: 'JPY',
      symbol: '¥',
      name: {'zh': '日元', 'en': 'Japanese Yen', 'ja': '円', 'ko': '일본 엔'},
      decimalDigits: 0, // 日元无小数
      symbolPosition: SymbolPosition.before,
      thousandsSeparator: ',',
      decimalSeparator: '.',
    ),
    'KRW': CurrencyConfig(
      code: 'KRW',
      symbol: '₩',
      name: {'zh': '韩元', 'en': 'Korean Won', 'ja': 'ウォン', 'ko': '원'},
      decimalDigits: 0, // 韩元无小数
      symbolPosition: SymbolPosition.before,
      thousandsSeparator: ',',
      decimalSeparator: '.',
    ),
    'EUR': CurrencyConfig(
      code: 'EUR',
      symbol: '€',
      name: {'zh': '欧元', 'en': 'Euro', 'ja': 'ユーロ', 'ko': '유로'},
      decimalDigits: 2,
      symbolPosition: SymbolPosition.before,
      thousandsSeparator: '.',
      decimalSeparator: ',',
    ),
    'TWD': CurrencyConfig(
      code: 'TWD',
      symbol: 'NT\$',
      name: {'zh': '新台币', 'en': 'Taiwan Dollar', 'ja': '台湾ドル', 'ko': '대만 달러'},
      decimalDigits: 0,
      symbolPosition: SymbolPosition.before,
      thousandsSeparator: ',',
      decimalSeparator: '.',
    ),
    'HKD': CurrencyConfig(
      code: 'HKD',
      symbol: 'HK\$',
      name: {'zh': '港币', 'en': 'Hong Kong Dollar', 'ja': '香港ドル', 'ko': '홍콩 달러'},
      decimalDigits: 2,
      symbolPosition: SymbolPosition.before,
      thousandsSeparator: ',',
      decimalSeparator: '.',
    ),
  };

  /// 格式化货币金额
  String formatCurrency(
    double amount, {
    String? currencyCode,
    bool showSymbol = true,
    bool compact = false,
  }) {
    final code = currencyCode ?? _getDefaultCurrency();
    final config = _currencyConfigs[code] ?? _currencyConfigs['CNY']!;

    String formatted;
    if (compact && amount.abs() >= 10000) {
      formatted = _formatCompact(amount, config);
    } else {
      formatted = _formatStandard(amount, config);
    }

    if (showSymbol) {
      return config.symbolPosition == SymbolPosition.before
          ? '${config.symbol}$formatted'
          : '$formatted${config.symbol}';
    }
    return formatted;
  }

  String _formatStandard(double amount, CurrencyConfig config) {
    final absAmount = amount.abs();
    final intPart = absAmount.truncate();
    final decPart = ((absAmount - intPart) * pow(10, config.decimalDigits))
        .round();

    // 格式化整数部分（加千分位）
    final intStr = intPart.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) {
        buffer.write(config.thousandsSeparator);
      }
      buffer.write(intStr[i]);
    }

    // 添加小数部分
    if (config.decimalDigits > 0) {
      buffer.write(config.decimalSeparator);
      buffer.write(decPart.toString().padLeft(config.decimalDigits, '0'));
    }

    return (amount < 0 ? '-' : '') + buffer.toString();
  }

  String _formatCompact(double amount, CurrencyConfig config) {
    final absAmount = amount.abs();
    final locale = _localeProvider.currentLocale;

    if (locale.languageCode == 'zh' || locale.languageCode == 'ja') {
      if (absAmount >= 100000000) {
        return '${(amount / 100000000).toStringAsFixed(1)}亿';
      } else if (absAmount >= 10000) {
        return '${(amount / 10000).toStringAsFixed(1)}万';
      }
    } else if (locale.languageCode == 'ko') {
      if (absAmount >= 100000000) {
        return '${(amount / 100000000).toStringAsFixed(1)}억';
      } else if (absAmount >= 10000) {
        return '${(amount / 10000).toStringAsFixed(1)}만';
      }
    } else {
      if (absAmount >= 1000000000) {
        return '${(amount / 1000000000).toStringAsFixed(1)}B';
      } else if (absAmount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (absAmount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(1)}K';
      }
    }

    return _formatStandard(amount, config);
  }

  /// 根据用户locale获取默认货币
  String _getDefaultCurrency() {
    final locale = _localeProvider.currentLocale;
    final countryToCurrency = {
      'CN': 'CNY',
      'TW': 'TWD',
      'HK': 'HKD',
      'US': 'USD',
      'JP': 'JPY',
      'KR': 'KRW',
      'GB': 'GBP',
      'DE': 'EUR',
      'FR': 'EUR',
    };
    return countryToCurrency[locale.countryCode] ?? 'CNY';
  }
}
```

#### 21.10.6 日期时间格式集成

```dart
/// 日期时间本地化服务
class DateTimeLocalizationService {
  final LocaleProvider _localeProvider;

  /// 格式化日期
  String formatDate(DateTime date, {DateFormatStyle style = DateFormatStyle.medium}) {
    final locale = _localeProvider.currentLocale;

    switch (style) {
      case DateFormatStyle.short:
        return _formatShortDate(date, locale);
      case DateFormatStyle.medium:
        return _formatMediumDate(date, locale);
      case DateFormatStyle.long:
        return _formatLongDate(date, locale);
      case DateFormatStyle.relative:
        return _formatRelativeDate(date, locale);
    }
  }

  String _formatShortDate(DateTime date, Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return '${date.month}/${date.day}';
      case 'ja':
        return '${date.month}/${date.day}';
      case 'ko':
        return '${date.month}/${date.day}';
      default: // en
        return '${date.month}/${date.day}';
    }
  }

  String _formatMediumDate(DateTime date, Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return '${date.year}年${date.month}月${date.day}日';
      case 'ja':
        return '${date.year}年${date.month}月${date.day}日';
      case 'ko':
        return '${date.year}년 ${date.month}월 ${date.day}일';
      default: // en
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String _formatRelativeDate(DateTime date, Locale locale) {
    final now = DateTime.now();
    final diff = now.difference(date);

    final l10n = AppLocalizations.of(_localeProvider.context);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return l10n.justNow; // "刚刚"
        }
        return l10n.minutesAgo(diff.inMinutes); // "X分钟前"
      }
      return l10n.hoursAgo(diff.inHours); // "X小时前"
    } else if (diff.inDays == 1) {
      return l10n.yesterday; // "昨天"
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays); // "X天前"
    } else if (diff.inDays < 30) {
      return l10n.weeksAgo(diff.inDays ~/ 7); // "X周前"
    } else {
      return _formatMediumDate(date, locale);
    }
  }

  /// 格式化时间
  String formatTime(DateTime time, {bool use24Hour = true}) {
    final locale = _localeProvider.currentLocale;

    if (use24Hour || locale.languageCode == 'zh' || locale.languageCode == 'ja') {
      return '${time.hour.toString().padLeft(2, '0')}:'
             '${time.minute.toString().padLeft(2, '0')}';
    } else {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final period = time.hour < 12 ? 'AM' : 'PM';
      return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
    }
  }

  /// 获取星期几的本地化名称
  String getWeekdayName(int weekday, {bool abbreviated = false}) {
    final locale = _localeProvider.currentLocale;

    final weekdays = _weekdayNames[locale.languageCode] ?? _weekdayNames['en']!;
    final names = abbreviated ? weekdays['short']! : weekdays['full']!;

    return names[weekday - 1]; // weekday: 1=Monday, 7=Sunday
  }

  static const _weekdayNames = {
    'zh': {
      'full': ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
      'short': ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
    },
    'en': {
      'full': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'short': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    },
    'ja': {
      'full': ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'],
      'short': ['月', '火', '水', '木', '金', '土', '日'],
    },
    'ko': {
      'full': ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'],
      'short': ['월', '화', '수', '목', '금', '토', '일'],
    },
  };
}
```

---

'''

    if chapter22_start in content:
        content = content.replace(chapter22_start, new_section_21_10 + chapter22_start)
        print("✓ 修复3: 添加21.10与其他系统集成部分（6个子章节）")
        changes += 1
    else:
        print("✗ 修复3: 未找到第22章开始位置")

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 第21章刷新完成，共 {changes} 处修改 =====")
    else:
        print("\n未找到需要修改的内容")

    return changes

if __name__ == '__main__':
    main()
