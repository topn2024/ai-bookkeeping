# 设计文档：重构重复代码

## 1. 本地化服务统一

### 现状分析

```
AccountLocalizationService          CategoryLocalizationService
├── _currentLocale                  ├── _currentLocale           ← 重复
├── _userOverrideLocale             ├── _userOverrideLocale      ← 重复
├── initialize()                    ├── initialize()             ← 重复
├── initializeFromContext()         ├── initializeFromContext()  ← 重复
├── _mapLocaleToSupported()         ├── _mapLocaleToSupported()  ← 重复
├── setLocale()                     ├── setLocale()              ← 重复
├── currentLocale                   ├── currentLocale            ← 重复
├── isUserOverride                  ├── isUserOverride           ← 重复
├── getLocalizedName(Account)       ├── getLocalizedName(Category)  ← 不同
└── getLocalizedDescription()       └── getLocalizedIcon()          ← 不同
```

### 设计方案

```dart
/// 泛型本地化基类
abstract class BaseLocalizationService<T> {
  String _currentLocale = 'zh';
  String? _userOverrideLocale;

  // 共享方法
  Future<void> initialize();
  void initializeFromContext(BuildContext context);
  String _mapLocaleToSupported(String languageCode);
  void setLocale(String locale);
  String get currentLocale;
  bool get isUserOverride;

  // 抽象方法 - 子类实现
  String getLocalizedName(T item);
  Map<String, Map<String, String>> get translations;
}

/// 账户本地化
class AccountLocalizationService extends BaseLocalizationService<Account> {
  @override
  String getLocalizedName(Account account) { ... }

  @override
  Map<String, Map<String, String>> get translations => _accountTranslations;
}

/// 分类本地化
class CategoryLocalizationService extends BaseLocalizationService<Category> {
  @override
  String getLocalizedName(Category category) { ... }

  @override
  Map<String, Map<String, String>> get translations => _categoryTranslations;
}
```

### 迁移策略

1. 创建 `BaseLocalizationService<T>` 抽象类
2. 将共享代码移至基类
3. 修改现有服务继承基类
4. 保持公共 API 不变

---

## 2. 对话框组件框架

### 现状分析

8个对话框组件重复以下模式：

```dart
class XxxDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  static Future<T?> show(BuildContext context, {...}) {
    return showDialog<T>(
      context: context,
      builder: (context) => XxxDialog(...),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          // 标题
          // 内容
          // 按钮行
        ],
      ),
    );
  }
}
```

### 设计方案

```dart
/// 确认对话框配置
class ConfirmationDialogConfig {
  final String title;
  final String? message;
  final Widget? content;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;
  final IconData? icon;
  final bool isDangerous;

  const ConfirmationDialogConfig({...});
}

/// 统一确认对话框
class ConfirmationDialog extends StatelessWidget {
  final ConfirmationDialogConfig config;

  const ConfirmationDialog({required this.config});

  /// 快捷构造器
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDangerous = false,
  }) { ... }

  /// 危险操作对话框
  static Future<bool?> showDangerous(
    BuildContext context, {
    required String title,
    required String message,
  }) { ... }

  /// 带自定义内容的对话框
  static Future<T?> showWithContent<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    required T Function() onConfirm,
  }) { ... }
}
```

### 迁移策略

1. 创建 `ConfirmationDialog` 通用组件
2. 逐个替换现有对话框调用
3. 保留特殊对话框（如需要复杂交互的）

---

## 3. 预算服务整合

### 现状分析

```
adaptive_budget_service.dart
├── BudgetAdjustmentType enum
├── BudgetFlexibility enum
├── AdaptiveBudgetSuggestion class
└── calculateAdaptiveBudget()

smart_budget_service.dart
├── SmartBudgetSuggestion class  ← 与上面类似
└── getSmartSuggestions()

localized_budget_service.dart
├── LocalizedBudgetSuggestion class  ← 与上面类似
└── getLocalizedBudget()

location_enhanced_budget_service.dart
├── LocationBudgetSuggestion class  ← 与上面类似
└── getLocationBudget()
```

### 设计方案

```dart
/// 统一预算建议模型
class BudgetSuggestion {
  final String categoryId;
  final double suggestedAmount;
  final double currentAmount;
  final String reason;
  final BudgetSuggestionSource source;
  final double confidence;
  final Map<String, dynamic>? metadata;

  const BudgetSuggestion({...});
}

/// 建议来源
enum BudgetSuggestionSource {
  adaptive,    // 自适应分析
  smart,       // 智能推荐
  localized,   // 本地化建议
  location,    // 位置感知
  user,        // 用户设置
}

/// 预算建议引擎接口
abstract class BudgetSuggestionStrategy {
  Future<List<BudgetSuggestion>> getSuggestions({
    required String ledgerId,
    required DateTime period,
  });
}

/// 组合策略的主服务
class BudgetSuggestionEngine {
  final List<BudgetSuggestionStrategy> strategies;

  Future<List<BudgetSuggestion>> getSuggestions({...}) async {
    final allSuggestions = <BudgetSuggestion>[];
    for (final strategy in strategies) {
      allSuggestions.addAll(await strategy.getSuggestions(...));
    }
    return _mergeSuggestions(allSuggestions);
  }

  List<BudgetSuggestion> _mergeSuggestions(List<BudgetSuggestion> suggestions) {
    // 按类别合并，选择置信度最高的
  }
}
```

### 迁移策略

1. 创建统一的 `BudgetSuggestion` 模型
2. 将各服务改造为 `BudgetSuggestionStrategy` 实现
3. 创建 `BudgetSuggestionEngine` 组合服务
4. 现有服务保留公共 API，内部调用策略

---

## 4. 语音操作基类

### 现状分析

```dart
// voice_modify_service.dart
class VoiceModifyService {
  final EntityDisambiguationService _disambiguationService;
  SessionContext? _currentSession;
  final List<ModifyOperation> _history = [];
  static const int maxHistorySize = 10;

  // 正则匹配列表
  static final List<RegExp> _modifyPatterns = [...];

  void startSession(SessionContext context) { ... }
  void endSession() { ... }
  bool canUndo() { ... }
  void undo() { ... }
}

// voice_delete_service.dart - 几乎相同结构
class VoiceDeleteService {
  final EntityDisambiguationService _disambiguationService;
  SessionContext? _currentSession;
  final List<DeleteOperation> _history = [];
  static const int maxHistorySize = 10;

  static final List<RegExp> _deletePatterns = [...];

  void startSession(SessionContext context) { ... }
  void endSession() { ... }
  bool canUndo() { ... }
  void undo() { ... }
}
```

### 设计方案

```dart
/// 操作基类
abstract class VoiceOperation {
  DateTime get timestamp;
  bool get canUndo;
  Future<void> undo();
}

/// 语音操作服务基类
abstract class BaseVoiceOperationService<T extends VoiceOperation> {
  final EntityDisambiguationService disambiguationService;
  SessionContext? _currentSession;
  final List<T> _history = [];

  static const int maxHistorySize = 10;

  BaseVoiceOperationService({required this.disambiguationService});

  // 共享会话管理
  void startSession(SessionContext context) {
    _currentSession = context;
    _history.clear();
  }

  void endSession() {
    _currentSession = null;
  }

  SessionContext? get currentSession => _currentSession;

  // 共享历史管理
  void addToHistory(T operation) {
    _history.add(operation);
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
  }

  bool canUndo() => _history.isNotEmpty;

  Future<void> undo() async {
    if (_history.isEmpty) return;
    final operation = _history.removeLast();
    await operation.undo();
  }

  // 抽象方法
  List<RegExp> get patterns;
  Future<T?> processCommand(String command);
}

/// 修改服务
class VoiceModifyService extends BaseVoiceOperationService<ModifyOperation> {
  @override
  List<RegExp> get patterns => _modifyPatterns;

  @override
  Future<ModifyOperation?> processCommand(String command) { ... }
}

/// 删除服务
class VoiceDeleteService extends BaseVoiceOperationService<DeleteOperation> {
  @override
  List<RegExp> get patterns => _deletePatterns;

  @override
  Future<DeleteOperation?> processCommand(String command) { ... }
}
```

---

## 5. 货币格式化统一

### 现状分析

```dart
// locale_format_service.dart
LocaleFormatService.instance.formatCurrency(amount, currency)

// currency.dart
CurrencyInfo.format(amount)

// account.dart
account.formattedBalance  // 内联实现
```

### 设计方案

```dart
/// 统一格式化服务
class FormattingService {
  static final FormattingService instance = FormattingService._();
  FormattingService._();

  String _locale = 'zh_CN';

  void setLocale(String locale) {
    _locale = locale;
  }

  /// 货币格式化
  String formatCurrency(
    double amount, {
    String? currencyCode,
    bool showSymbol = true,
    int? decimalPlaces,
  }) {
    final currency = currencyCode ?? 'CNY';
    final info = CurrencyInfo.fromCode(currency);
    final decimals = decimalPlaces ?? info.decimalPlaces;

    final formatted = amount.toStringAsFixed(decimals);
    if (showSymbol) {
      return '${info.symbol}$formatted';
    }
    return formatted;
  }

  /// 数字格式化（带千位分隔符）
  String formatNumber(double number, {int decimalPlaces = 2}) { ... }

  /// 百分比格式化
  String formatPercentage(double ratio, {int decimalPlaces = 1}) { ... }

  /// 日期格式化
  String formatDate(DateTime date, {String? pattern}) { ... }

  /// 相对时间格式化
  String formatRelativeTime(DateTime date) { ... }
}

// 扩展方法便捷访问
extension DoubleFormattingExtension on double {
  String toCurrency({String? currencyCode}) =>
      FormattingService.instance.formatCurrency(this, currencyCode: currencyCode);

  String toPercentage() =>
      FormattingService.instance.formatPercentage(this);
}
```

---

## 6. 目录结构变更

```
lib/
├── core/
│   ├── base/                      # 新增：基类目录
│   │   ├── base_localization_service.dart
│   │   ├── base_voice_operation_service.dart
│   │   └── base_singleton_service.dart
│   └── formatting/                # 新增：格式化服务
│       └── formatting_service.dart
├── widgets/
│   └── dialogs/
│       ├── confirmation_dialog.dart  # 新增：统一对话框
│       └── dialog_builder.dart       # 新增：对话框构建器
└── services/
    └── budget/
        ├── budget_suggestion.dart       # 新增：统一模型
        ├── budget_suggestion_engine.dart # 新增：组合服务
        └── strategies/                   # 新增：策略实现
            ├── adaptive_strategy.dart
            ├── smart_strategy.dart
            └── location_strategy.dart
```

---

## 7. 测试策略

### 单元测试

每个基类需要独立的单元测试：

```dart
// test/core/base/base_localization_service_test.dart
void main() {
  group('BaseLocalizationService', () {
    test('initialize sets default locale', () { ... });
    test('setLocale updates current locale', () { ... });
    test('_mapLocaleToSupported handles unknown locales', () { ... });
  });
}
```

### 集成测试

验证迁移后行为一致：

```dart
// test/services/localization_migration_test.dart
void main() {
  test('AccountLocalizationService behaves same after refactor', () {
    // 对比重构前后的输出
  });
}
```

---

## 8. 权衡与决策

| 决策 | 选项 | 选择 | 理由 |
|------|------|------|------|
| 对话框模式 | 继承 vs 组合 | 组合 | 更灵活，支持自定义内容 |
| 预算服务 | 合并 vs 策略 | 策略模式 | 保持各服务独立性，易于扩展 |
| 格式化服务 | 单例 vs Provider | 单例+扩展 | 简单场景无需 Provider 开销 |
| 代码生成 | Freezed vs 手写 | 暂不引入 | 避免增加构建复杂性，作为后续提案 |
