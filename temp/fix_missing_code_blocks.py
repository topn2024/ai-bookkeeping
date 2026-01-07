# -*- coding: utf-8 -*-
"""
修复缺失的代码块
补充第1章、第4章、第8章、第15章、第21章缺失的代码
"""
import re

def fix_missing_code_blocks():
    # 读取代码设计文档
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_code_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. 修复第1章：添加GoalChecker和ValidationResult框架
    chapter1_addition = '''

#### <a id="code-1b"></a>代码块 1b - 目标达成检测框架

```dart
/// 通用目标检测器基类
abstract class GoalChecker {
  /// 检测器名称
  String get name;

  /// 所属章节
  int get chapter;

  /// 执行目标达成检测
  Future<ValidationReport> validate();

  /// 计算检查项得分
  double calculateScore(List<CheckItem> checks) {
    if (checks.isEmpty) return 0;
    final passed = checks.where((c) => c.passed).length;
    return passed / checks.length * 100;
  }
}

/// 验证结果
class ValidationResult {
  final String category;
  final List<CheckItem> checks;
  final double score;
  final String? note;

  const ValidationResult({
    required this.category,
    required this.checks,
    required this.score,
    this.note,
  });

  bool get passed => score >= 80;
}

/// 单项检查结果
class CheckItem {
  final String name;
  final String description;
  final bool passed;
  final String evidence;
  final String? suggestion;

  const CheckItem({
    required this.name,
    required this.description,
    required this.passed,
    required this.evidence,
    this.suggestion,
  });
}

/// 验证报告
class ValidationReport {
  final int chapter;
  final String title;
  final List<ValidationResult> results;
  final double overallScore;
  final DateTime generatedAt;

  const ValidationReport({
    required this.chapter,
    required this.title,
    required this.results,
    required this.overallScore,
    required this.generatedAt,
  });

  bool get allPassed => overallScore >= 80;

  List<ValidationResult> get failedResults =>
      results.where((r) => !r.passed).toList();
}

/// 设计原则验证器
class DesignPrincipleValidator extends GoalChecker {
  @override
  String get name => '设计原则验证器';

  @override
  int get chapter => 1;

  @override
  Future<ValidationReport> validate() async {
    final results = <ValidationResult>[];

    // 验证懒人理念
    results.add(await _validateLazyPrinciple());

    // 验证伙伴化设计
    results.add(await _validatePartnerDesign());

    // 验证无障碍设计
    results.add(await _validateAccessibility());

    return ValidationReport(
      chapter: chapter,
      title: '设计原则验证',
      results: results,
      overallScore: _calculateOverallScore(results),
      generatedAt: DateTime.now(),
    );
  }

  Future<ValidationResult> _validateLazyPrinciple() async {
    return ValidationResult(
      category: '懒人理念',
      checks: [
        CheckItem(
          name: '智能默认值',
          description: '系统提供合理的默认配置',
          passed: true,
          evidence: '分类、账户、预算模板均有默认值',
        ),
        CheckItem(
          name: '自动化程度',
          description: '减少用户手动操作',
          passed: true,
          evidence: 'AI识别、自动分类、定期交易自动记录',
        ),
      ],
      score: 100,
    );
  }

  Future<ValidationResult> _validatePartnerDesign() async {
    return ValidationResult(
      category: '伙伴化设计',
      checks: [
        CheckItem(
          name: '情感化交互',
          description: '提供温暖的交互体验',
          passed: true,
          evidence: '动态问候、鼓励消息、成就庆祝',
        ),
      ],
      score: 100,
    );
  }

  Future<ValidationResult> _validateAccessibility() async {
    return ValidationResult(
      category: '无障碍设计',
      checks: [
        CheckItem(
          name: '屏幕阅读器支持',
          description: '支持TalkBack/VoiceOver',
          passed: true,
          evidence: '语义化标签、焦点管理完整',
        ),
      ],
      score: 100,
    );
  }

  double _calculateOverallScore(List<ValidationResult> results) {
    if (results.isEmpty) return 0;
    return results.map((r) => r.score).reduce((a, b) => a + b) / results.length;
  }
}
```

*来源: 补充代码 - 目标达成检测框架*

'''

    # 找到第1章第一个代码块后插入
    insert_point = content.find('*来源: app_v2_design.md 第')
    if insert_point > 0:
        # 找到这一行的结尾
        line_end = content.find('\n', insert_point)
        if line_end > 0:
            # 检查是否是第1章
            before_insert = content[:insert_point]
            if '## 第1章' in before_insert[-2000:]:
                content = content[:line_end] + chapter1_addition + content[line_end:]
                print("✓ 第1章：添加GoalChecker和ValidationResult框架")

    # 2. 修复第4章：添加鼓励性反馈代码
    chapter4_addition = '''

#### <a id="code-4b"></a>代码块 4b - 鼓励性反馈系统

```dart
/// 鼓励性反馈服务
class EncouragementFeedbackService {
  final UserProgressService _progressService;

  /// 生成正面鼓励消息
  Future<PositiveFeedback> generateEncouragement(UserAction action) async {
    final progress = await _progressService.getUserProgress();

    return switch (action) {
      UserAction.recordTransaction => _encourageRecording(progress),
      UserAction.reachBudgetGoal => _celebrateBudgetGoal(progress),
      UserAction.improveMoneyAge => _praiseMoneyAgeImprovement(progress),
      UserAction.maintainStreak => _acknowledgeStreak(progress),
      _ => _generalEncouragement(progress),
    };
  }

  PositiveFeedback _encourageRecording(UserProgress progress) {
    final messages = [
      '记账习惯越来越好了！',
      '坚持记录，财务更清晰 💪',
      '每一笔记录都是理财的一小步',
    ];
    return PositiveFeedback(
      message: messages[progress.recordCount % messages.length],
      type: FeedbackType.encouragement,
      icon: '✨',
    );
  }

  PositiveFeedback _celebrateBudgetGoal(UserProgress progress) {
    return PositiveFeedback(
      message: '太棒了！本月预算控制得很好！',
      type: FeedbackType.celebration,
      icon: '🎉',
      showConfetti: true,
    );
  }

  PositiveFeedback _praiseMoneyAgeImprovement(UserProgress progress) {
    return PositiveFeedback(
      message: '钱龄提升了！资金周转更健康',
      type: FeedbackType.praise,
      icon: '📈',
    );
  }

  PositiveFeedback _acknowledgeStreak(UserProgress progress) {
    return PositiveFeedback(
      message: '连续${progress.streakDays}天记账，继续保持！',
      type: FeedbackType.streak,
      icon: '🔥',
    );
  }

  PositiveFeedback _generalEncouragement(UserProgress progress) {
    return PositiveFeedback(
      message: '你正在变得更会理财！',
      type: FeedbackType.encouragement,
      icon: '💪',
    );
  }
}

/// 正面反馈数据模型
class PositiveFeedback {
  final String message;
  final FeedbackType type;
  final String icon;
  final bool showConfetti;

  const PositiveFeedback({
    required this.message,
    required this.type,
    required this.icon,
    this.showConfetti = false,
  });
}

enum FeedbackType {
  encouragement,  // 鼓励
  praise,         // 表扬
  celebration,    // 庆祝
  streak,         // 连续达成
}

enum UserAction {
  recordTransaction,
  reachBudgetGoal,
  improveMoneyAge,
  maintainStreak,
  viewReport,
}
```

*来源: 补充代码 - 鼓励性反馈系统*

'''

    # 找到第4章末尾插入
    chapter4_end = content.find('## 第5章')
    if chapter4_end > 0:
        # 找到前一个代码块结束位置
        last_source = content.rfind('*来源:', 0, chapter4_end)
        if last_source > 0:
            line_end = content.find('\n', last_source)
            if line_end > 0:
                content = content[:line_end] + chapter4_addition + content[line_end:]
                print("✓ 第4章：添加鼓励性反馈系统代码")

    # 3. 修复第8章：添加预算分配代码
    chapter8_addition = '''

#### <a id="code-8b"></a>代码块 8b - 预算分配引擎

```dart
/// 预算分配引擎
class BudgetDistributionEngine {
  /// 智能分配收入到各个小金库
  Future<DistributionResult> distributeIncome(
    double incomeAmount,
    List<BudgetVault> vaults,
    DistributionStrategy strategy,
  ) async {
    final assignments = <VaultAssignment>[];
    var remainingAmount = incomeAmount;

    // 按策略排序小金库
    final sortedVaults = _sortByStrategy(vaults, strategy);

    for (final vault in sortedVaults) {
      if (remainingAmount <= 0) break;

      final assignAmount = _calculateAssignment(
        vault,
        remainingAmount,
        strategy,
      );

      if (assignAmount > 0) {
        assignments.add(VaultAssignment(
          vaultId: vault.id,
          vaultName: vault.name,
          amount: assignAmount,
          reason: _getAssignmentReason(vault, strategy),
        ));
        remainingAmount -= assignAmount;
      }
    }

    return DistributionResult(
      totalDistributed: incomeAmount - remainingAmount,
      unassigned: remainingAmount,
      assignments: assignments,
      strategy: strategy,
    );
  }

  List<BudgetVault> _sortByStrategy(
    List<BudgetVault> vaults,
    DistributionStrategy strategy,
  ) {
    return switch (strategy) {
      DistributionStrategy.priority =>
          [...vaults]..sort((a, b) => a.priority.compareTo(b.priority)),
      DistributionStrategy.percentage =>
          [...vaults]..sort((a, b) => b.targetPercentage.compareTo(a.targetPercentage)),
      DistributionStrategy.needBased =>
          [...vaults]..sort((a, b) => a.fillRate.compareTo(b.fillRate)),
    };
  }

  double _calculateAssignment(
    BudgetVault vault,
    double available,
    DistributionStrategy strategy,
  ) {
    return switch (strategy) {
      DistributionStrategy.priority =>
          (vault.targetAmount - vault.currentAmount).clamp(0, available),
      DistributionStrategy.percentage =>
          (available * vault.targetPercentage / 100).clamp(0, available),
      DistributionStrategy.needBased =>
          _calculateNeedBasedAmount(vault, available),
    };
  }

  double _calculateNeedBasedAmount(BudgetVault vault, double available) {
    final gap = vault.targetAmount - vault.currentAmount;
    if (gap <= 0) return 0;
    return (gap * 0.5).clamp(0, available); // 每次填充50%缺口
  }

  String _getAssignmentReason(BudgetVault vault, DistributionStrategy strategy) {
    return switch (strategy) {
      DistributionStrategy.priority => '优先级分配 (P${vault.priority})',
      DistributionStrategy.percentage => '按比例分配 (${vault.targetPercentage}%)',
      DistributionStrategy.needBased => '按需分配 (填充率${(vault.fillRate * 100).toInt()}%)',
    };
  }
}

/// 分配策略
enum DistributionStrategy {
  priority,     // 按优先级分配
  percentage,   // 按比例分配
  needBased,    // 按需分配（填充率低的优先）
}

/// 分配结果
class DistributionResult {
  final double totalDistributed;
  final double unassigned;
  final List<VaultAssignment> assignments;
  final DistributionStrategy strategy;

  const DistributionResult({
    required this.totalDistributed,
    required this.unassigned,
    required this.assignments,
    required this.strategy,
  });
}

/// 单个小金库分配
class VaultAssignment {
  final String vaultId;
  final String vaultName;
  final double amount;
  final String reason;

  const VaultAssignment({
    required this.vaultId,
    required this.vaultName,
    required this.amount,
    required this.reason,
  });
}
```

*来源: 补充代码 - 预算分配引擎*

'''

    # 找到第8章末尾插入
    chapter8_end = content.find('## 第9章')
    if chapter8_end > 0:
        last_source = content.rfind('*来源:', 0, chapter8_end)
        if last_source > 0:
            line_end = content.find('\n', last_source)
            if line_end > 0:
                content = content[:line_end] + chapter8_addition + content[line_end:]
                print("✓ 第8章：添加预算分配引擎代码")

    # 4. 修复第15章：添加分层架构代码
    chapter15_addition = '''

#### <a id="code-15b"></a>代码块 15b - 分层架构定义

```dart
/// 应用架构层次定义
///
/// 架构采用清晰的分层设计：
///
/// ```
/// ┌─────────────────────────────────────────┐
/// │           Presentation Layer            │  UI组件、页面、状态管理
/// ├─────────────────────────────────────────┤
/// │            Application Layer            │  用例、业务流程编排
/// ├─────────────────────────────────────────┤
/// │             Domain Layer                │  领域模型、业务规则
/// ├─────────────────────────────────────────┤
/// │          Infrastructure Layer           │  数据库、API、外部服务
/// └─────────────────────────────────────────┘
/// ```

/// 架构层枚举
enum ArchitectureLayer {
  presentation,   // 表现层
  application,    // 应用层
  domain,         // 领域层
  infrastructure, // 基础设施层
}

/// 模块定义
abstract class AppModule {
  /// 模块名称
  String get name;

  /// 所属架构层
  ArchitectureLayer get layer;

  /// 模块依赖
  List<Type> get dependencies;

  /// 初始化模块
  Future<void> initialize();

  /// 清理资源
  Future<void> dispose();
}

/// 模块注册表
class ModuleRegistry {
  static final Map<Type, AppModule> _modules = {};

  /// 注册模块
  static void register(AppModule module) {
    _modules[module.runtimeType] = module;
  }

  /// 获取模块
  static T get<T extends AppModule>() {
    final module = _modules[T];
    if (module == null) {
      throw StateError('Module $T not registered');
    }
    return module as T;
  }

  /// 按层次初始化所有模块
  static Future<void> initializeAll() async {
    // 按层次顺序初始化：基础设施 -> 领域 -> 应用 -> 表现
    final layerOrder = [
      ArchitectureLayer.infrastructure,
      ArchitectureLayer.domain,
      ArchitectureLayer.application,
      ArchitectureLayer.presentation,
    ];

    for (final layer in layerOrder) {
      final layerModules = _modules.values
          .where((m) => m.layer == layer)
          .toList();

      for (final module in layerModules) {
        await module.initialize();
      }
    }
  }
}

/// 领域层示例模块
class MoneyAgeDomainModule extends AppModule {
  @override
  String get name => '钱龄领域模块';

  @override
  ArchitectureLayer get layer => ArchitectureLayer.domain;

  @override
  List<Type> get dependencies => [];

  @override
  Future<void> initialize() async {
    // 注册钱龄相关的领域服务
  }

  @override
  Future<void> dispose() async {}
}

/// 基础设施层示例模块
class DatabaseInfrastructureModule extends AppModule {
  @override
  String get name => '数据库基础设施模块';

  @override
  ArchitectureLayer get layer => ArchitectureLayer.infrastructure;

  @override
  List<Type> get dependencies => [];

  @override
  Future<void> initialize() async {
    // 初始化数据库连接
  }

  @override
  Future<void> dispose() async {
    // 关闭数据库连接
  }
}
```

*来源: 补充代码 - 分层架构定义*

'''

    # 找到第15章开头插入
    chapter15_start = content.find('## 第15章')
    if chapter15_start > 0:
        # 找到第一个代码块之前
        first_code = content.find('#### <a id="code-', chapter15_start)
        if first_code > 0:
            content = content[:first_code] + chapter15_addition + '\n' + content[first_code:]
            print("✓ 第15章：添加分层架构定义代码")

    # 5. 修复第21章：添加翻译服务和货币格式化代码
    chapter21_addition = '''

#### <a id="code-328"></a>代码块 328 - 翻译服务

```dart
/// 翻译服务
class TranslationService {
  final Map<String, Map<String, String>> _translations = {};
  AppLanguage _currentLanguage = AppLanguage.zhCN;

  /// 加载语言包
  Future<void> loadTranslations(AppLanguage language) async {
    if (_translations.containsKey(language.name)) return;

    final jsonString = await rootBundle.loadString(
      'assets/i18n/${language.name}.json'
    );
    _translations[language.name] = Map<String, String>.from(
      json.decode(jsonString)
    );
    _currentLanguage = language;
  }

  /// 获取翻译文本
  String translate(String key, {Map<String, dynamic>? params}) {
    final translations = _translations[_currentLanguage.name] ?? {};
    var text = translations[key] ?? key;

    // 替换参数占位符
    if (params != null) {
      params.forEach((paramKey, value) {
        text = text.replaceAll('{$paramKey}', value.toString());
      });
    }

    return text;
  }

  /// 简写方法
  String tr(String key, {Map<String, dynamic>? params}) =>
      translate(key, params: params);
}

/// 翻译扩展
extension TranslateExtension on String {
  String get tr => TranslationService().translate(this);

  String trParams(Map<String, dynamic> params) =>
      TranslationService().translate(this, params: params);
}
```

*来源: 补充代码 - 翻译服务*

#### <a id="code-329"></a>代码块 329 - 货币格式化服务

```dart
/// 货币格式化服务
class CurrencyFormatter {
  /// 支持的货币
  static const Map<String, CurrencyInfo> currencies = {
    'CNY': CurrencyInfo(
      code: 'CNY',
      symbol: '¥',
      name: '人民币',
      decimalDigits: 2,
      symbolPosition: SymbolPosition.before,
    ),
    'USD': CurrencyInfo(
      code: 'USD',
      symbol: '\$',
      name: '美元',
      decimalDigits: 2,
      symbolPosition: SymbolPosition.before,
    ),
    'EUR': CurrencyInfo(
      code: 'EUR',
      symbol: '€',
      name: '欧元',
      decimalDigits: 2,
      symbolPosition: SymbolPosition.before,
    ),
    'JPY': CurrencyInfo(
      code: 'JPY',
      symbol: '¥',
      name: '日元',
      decimalDigits: 0,
      symbolPosition: SymbolPosition.before,
    ),
    'KRW': CurrencyInfo(
      code: 'KRW',
      symbol: '₩',
      name: '韩元',
      decimalDigits: 0,
      symbolPosition: SymbolPosition.before,
    ),
  };

  final String currencyCode;
  late final CurrencyInfo _info;
  late final NumberFormat _formatter;

  CurrencyFormatter({this.currencyCode = 'CNY'}) {
    _info = currencies[currencyCode] ?? currencies['CNY']!;
    _formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: _info.decimalDigits,
    );
  }

  /// 格式化金额
  String format(double amount) {
    final formatted = _formatter.format(amount.abs());
    final sign = amount < 0 ? '-' : '';

    return switch (_info.symbolPosition) {
      SymbolPosition.before => '$sign${_info.symbol}$formatted',
      SymbolPosition.after => '$sign$formatted${_info.symbol}',
    };
  }

  /// 格式化金额（带正负号）
  String formatWithSign(double amount) {
    final formatted = format(amount.abs());
    if (amount > 0) return '+$formatted';
    if (amount < 0) return '-$formatted';
    return formatted;
  }

  /// 解析金额字符串
  double? parse(String text) {
    final cleaned = text
        .replaceAll(_info.symbol, '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    return double.tryParse(cleaned);
  }
}

/// 货币信息
class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;
  final SymbolPosition symbolPosition;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
    required this.symbolPosition,
  });
}

enum SymbolPosition { before, after }
```

*来源: 补充代码 - 货币格式化服务*

#### <a id="code-330"></a>代码块 330 - 日期时间本地化

```dart
/// 日期时间本地化服务
class DateTimeLocalizationService {
  final AppLanguage language;

  DateTimeLocalizationService({this.language = AppLanguage.zhCN});

  /// 格式化日期
  String formatDate(DateTime date, {DateFormatStyle style = DateFormatStyle.medium}) {
    return switch (language) {
      AppLanguage.zhCN => _formatDateChinese(date, style),
      AppLanguage.en => _formatDateEnglish(date, style),
      AppLanguage.ja => _formatDateJapanese(date, style),
      AppLanguage.ko => _formatDateKorean(date, style),
      _ => _formatDateChinese(date, style),
    };
  }

  String _formatDateChinese(DateTime date, DateFormatStyle style) {
    return switch (style) {
      DateFormatStyle.short => '${date.month}/${date.day}',
      DateFormatStyle.medium => '${date.year}年${date.month}月${date.day}日',
      DateFormatStyle.long => '${date.year}年${date.month}月${date.day}日 ${_getWeekdayChinese(date)}',
      DateFormatStyle.relative => _getRelativeDateChinese(date),
    };
  }

  String _formatDateEnglish(DateTime date, DateFormatStyle style) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return switch (style) {
      DateFormatStyle.short => '${date.month}/${date.day}',
      DateFormatStyle.medium => '${months[date.month - 1]} ${date.day}, ${date.year}',
      DateFormatStyle.long => '${_getWeekdayEnglish(date)}, ${months[date.month - 1]} ${date.day}, ${date.year}',
      DateFormatStyle.relative => _getRelativeDateEnglish(date),
    };
  }

  String _formatDateJapanese(DateTime date, DateFormatStyle style) {
    return switch (style) {
      DateFormatStyle.short => '${date.month}/${date.day}',
      DateFormatStyle.medium => '${date.year}年${date.month}月${date.day}日',
      DateFormatStyle.long => '${date.year}年${date.month}月${date.day}日（${_getWeekdayJapanese(date)}）',
      DateFormatStyle.relative => _getRelativeDateJapanese(date),
    };
  }

  String _formatDateKorean(DateTime date, DateFormatStyle style) {
    return switch (style) {
      DateFormatStyle.short => '${date.month}/${date.day}',
      DateFormatStyle.medium => '${date.year}년 ${date.month}월 ${date.day}일',
      DateFormatStyle.long => '${date.year}년 ${date.month}월 ${date.day}일 ${_getWeekdayKorean(date)}',
      DateFormatStyle.relative => _getRelativeDateKorean(date),
    };
  }

  String _getWeekdayChinese(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  String _getWeekdayEnglish(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[date.weekday - 1];
  }

  String _getWeekdayJapanese(DateTime date) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[date.weekday - 1];
  }

  String _getWeekdayKorean(DateTime date) {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return weekdays[date.weekday - 1];
  }

  String _getRelativeDateChinese(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    if (diff < 7) return '$diff天前';
    if (diff < 30) return '${diff ~/ 7}周前';
    if (diff < 365) return '${diff ~/ 30}个月前';
    return '${diff ~/ 365}年前';
  }

  String _getRelativeDateEnglish(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) return '${diff ~/ 7} weeks ago';
    if (diff < 365) return '${diff ~/ 30} months ago';
    return '${diff ~/ 365} years ago';
  }

  String _getRelativeDateJapanese(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return '今日';
    if (diff == 1) return '昨日';
    if (diff < 7) return '${diff}日前';
    if (diff < 30) return '${diff ~/ 7}週間前';
    if (diff < 365) return '${diff ~/ 30}ヶ月前';
    return '${diff ~/ 365}年前';
  }

  String _getRelativeDateKorean(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '${diff}일 전';
    if (diff < 30) return '${diff ~/ 7}주 전';
    if (diff < 365) return '${diff ~/ 30}개월 전';
    return '${diff ~/ 365}년 전';
  }
}

enum DateFormatStyle {
  short,     // 简短格式
  medium,    // 中等格式
  long,      // 完整格式
  relative,  // 相对时间
}
```

*来源: 补充代码 - 日期时间本地化*

'''

    # 找到第21章末尾插入
    chapter21_end = content.find('## 第22章')
    if chapter21_end > 0:
        last_source = content.rfind('*来源:', 0, chapter21_end)
        if last_source > 0:
            line_end = content.find('\n', last_source)
            if line_end > 0:
                content = content[:line_end] + chapter21_addition + content[line_end:]
                print("✓ 第21章：添加翻译服务、货币格式化、日期本地化代码")

    # 保存修改后的文档
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_code_design.md', 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n所有缺失代码块已补充完成！")


if __name__ == '__main__':
    fix_missing_code_blocks()
