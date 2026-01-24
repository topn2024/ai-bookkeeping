# 短信导入中的分类推断复用方案

## 现有分类推断能力

系统中存在多个分类推断服务：

### 1. BillParser.inferCategory（基础规则引擎）
**位置**：`app/lib/services/import/bill_parser.dart`

**特点**：
- 500+行的关键词规则匹配
- 基于商户名和备注的文本匹配
- 支持中英文关键词
- 优先级规则（具体 > 一般）
- 返回标准分类ID

**示例**：
```dart
String inferCategory(String? merchant, String? note, TransactionType type) {
  final text = '${merchant ?? ''} ${note ?? ''}'.toLowerCase();

  if (text.contains('星巴克') || text.contains('瑞幸') || text.contains('coffee')) {
    return 'food_drink';
  }
  if (text.contains('滴滴') || text.contains('打车') || text.contains('taxi')) {
    return 'transport_taxi';
  }
  // ... 500+ 行规则
}
```

### 2. SmartCategoryService（四层混合策略）
**位置**：`app/lib/services/smart_category_service.dart`

**特点**：
- 第一层：商家历史匹配（置信度最高）
- 第二层：关键词规则匹配
- 第三层：本地ML模型
- 第四层：大模型语义理解（兜底）

**优势**：
- 更智能，考虑历史记录
- 多层策略，准确率更高
- 支持学习用户习惯

### 3. CategorySuggestionService（AI分类建议）
**位置**：`app/lib/services/ai/category_suggestion_service.dart`

**特点**：
- 基于AI的分类建议
- 考虑上下文和语义
- 可能需要网络请求

## 短信导入的分类推断需求

### 场景分析

短信导入有两个分类推断时机：

#### 时机1：AI解析时（推荐）
```
SmsParserService.parseBatch()
  ↓
AI解析短信 → 返回JSON
{
  "amount": 45.0,
  "type": "expense",
  "merchant": "星巴克",
  "note": "咖啡消费",
  "category": "food_drink"  ← AI直接推断分类
}
  ↓
转换为ImportCandidate
```

**优势**：
- AI可以理解上下文语义
- 一次性完成解析和分类
- 减少额外处理步骤

#### 时机2：转换ImportCandidate时（备选）
```
SmsParserService.toImportCandidate()
  ↓
ParsedTransaction {
  merchant: "星巴克",
  note: "咖啡消费",
  category: null  ← AI未返回分类
}
  ↓
调用 BillParser.inferCategory()  ← 本地规则推断
  ↓
ImportCandidate {
  category: "food_drink"
}
```

**优势**：
- 不依赖AI分类准确性
- 使用成熟的规则引擎
- 完全本地处理

## 复用方案对比

### 方案A：AI直接分类 + 规则兜底（推荐）

```dart
class SmsParserService {
  final AIService _aiService;

  ImportCandidate toImportCandidate(
    ParsedTransaction transaction,
    String ledgerId,
  ) {
    // 1. 优先使用AI返回的分类
    String category = transaction.category ?? '';

    // 2. 如果AI未返回分类，使用规则引擎
    if (category.isEmpty) {
      category = BillParser.inferCategory(
        transaction.merchant,
        transaction.note,
        transaction.type,
      );
    }

    return ImportCandidate(
      // ...
      category: category,
    );
  }
}
```

**优势**：
- ✅ 充分利用AI的语义理解能力
- ✅ 规则引擎作为兜底，保证有分类
- ✅ 实现简单，复用现有代码
- ✅ 无需额外网络请求

**劣势**：
- ❌ AI分类可能不准确
- ❌ 无法利用用户历史习惯

### 方案B：完全使用规则引擎

```dart
class SmsParserService {
  ImportCandidate toImportCandidate(
    ParsedTransaction transaction,
    String ledgerId,
  ) {
    // 忽略AI返回的分类，完全使用规则引擎
    final category = BillParser.inferCategory(
      transaction.merchant,
      transaction.note,
      transaction.type,
    );

    return ImportCandidate(
      // ...
      category: category,
    );
  }
}
```

**优势**：
- ✅ 与文件导入保持一致
- ✅ 规则成熟稳定
- ✅ 完全本地处理

**劣势**：
- ❌ 浪费AI的分类能力
- ❌ 规则引擎可能覆盖不全

### 方案C：使用SmartCategoryService（最智能）

```dart
class SmsParserService {
  final SmartCategoryService _smartCategoryService;

  Future<ImportCandidate> toImportCandidate(
    ParsedTransaction transaction,
    String ledgerId,
  ) async {
    // 使用四层混合策略
    final categoryResult = await _smartCategoryService.inferCategory(
      merchant: transaction.merchant,
      note: transaction.note,
      amount: transaction.amount,
      type: transaction.type,
      date: transaction.date,
    );

    return ImportCandidate(
      // ...
      category: categoryResult.categoryId,
    );
  }
}
```

**优势**：
- ✅ 最智能，考虑历史记录
- ✅ 多层策略，准确率最高
- ✅ 可以学习用户习惯

**劣势**：
- ❌ 需要异步处理（性能影响）
- ❌ 依赖更多服务
- ❌ 可能需要网络请求（第四层）

### 方案D：混合方案（AI + SmartCategory）

```dart
class SmsParserService {
  final SmartCategoryService _smartCategoryService;

  Future<ImportCandidate> toImportCandidate(
    ParsedTransaction transaction,
    String ledgerId,
  ) async {
    String category;

    // 1. 优先使用AI返回的分类
    if (transaction.category != null && transaction.category!.isNotEmpty) {
      category = transaction.category!;
    } else {
      // 2. 使用SmartCategoryService推断
      final result = await _smartCategoryService.inferCategory(
        merchant: transaction.merchant,
        note: transaction.note,
        amount: transaction.amount,
        type: transaction.type,
        date: transaction.date,
      );
      category = result.categoryId;
    }

    return ImportCandidate(
      // ...
      category: category,
    );
  }
}
```

**优势**：
- ✅ 结合AI和智能服务的优势
- ✅ 准确率最高
- ✅ 可以学习用户习惯

**劣势**：
- ❌ 实现复杂
- ❌ 性能开销大

## 推荐方案

### 🎯 推荐：方案A（AI直接分类 + 规则兜底）

**理由**：
1. **简单高效**：实现简单，性能好
2. **充分利用AI**：AI已经在解析短信，顺便返回分类
3. **有兜底保障**：规则引擎确保总有分类
4. **与现有架构一致**：文件导入也是在解析时推断分类

**实现代码**：
```dart
class SmsParserService {
  final AIService _aiService;

  // AI Prompt中要求返回分类
  String _buildPrompt(List<SmsMessage> messages) {
    return '''
你是一个专业的交易记录解析助手。请从以下短信中提取交易信息，返回JSON数组格式。

短信列表：
${messages.map((m) => '${m.address}: ${m.body}').join('\n')}

要求：
- 只提取交易相关的短信，忽略验证码、广告等
- 每条交易包含：
  - amount（金额）
  - type（income/expense）
  - date（ISO格式）
  - merchant（商户名）
  - note（备注）
  - category（分类ID，如food_drink、transport_taxi等）← 要求AI返回分类
- 如果短信不包含交易信息，返回null
- 返回格式：[{...}, {...}, null, ...]
''';
  }

  ImportCandidate toImportCandidate(
    ParsedTransaction transaction,
    String ledgerId,
  ) {
    // 1. 优先使用AI返回的分类
    String category = transaction.category ?? '';

    // 2. 如果AI未返回分类或分类无效，使用规则引擎兜底
    if (category.isEmpty || !_isValidCategory(category)) {
      category = BillParser.inferCategory(
        transaction.merchant,
        transaction.note,
        transaction.type,
      );
    }

    return ImportCandidate(
      id: const Uuid().v4(),
      ledgerId: ledgerId,
      amount: transaction.amount,
      type: transaction.type,
      date: transaction.date,
      merchant: transaction.merchant,
      note: transaction.note,
      category: category,  // 使用推断的分类
      source: '短信导入',
      sourceNote: transaction.originalSmsBody,
      action: ImportAction.import_,
    );
  }

  // 验证分类ID是否有效
  bool _isValidCategory(String categoryId) {
    // 可以查询数据库或使用预定义列表
    return categoryId.isNotEmpty && !categoryId.startsWith('unknown');
  }
}
```

### 可选增强：用户可在预览页面修改分类

由于复用了ImportPreviewPage，用户可以：
1. 查看AI推断的分类
2. 如果不准确，手动修改
3. 系统可以学习用户的修改（未来优化）

## 复用方式总结

| 方案 | 复用组件 | 时机 | 性能 | 准确率 | 推荐度 |
|------|---------|------|------|--------|--------|
| A. AI+规则兜底 | BillParser.inferCategory | 转换时 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| B. 完全规则 | BillParser.inferCategory | 转换时 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| C. SmartCategory | SmartCategoryService | 转换时 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| D. AI+SmartCategory | 两者 | 转换时 | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

## 实施建议

### 第一阶段（MVP）
- 实现方案A：AI直接分类 + 规则兜底
- 在AI Prompt中要求返回category字段
- 使用BillParser.inferCategory作为兜底

### 第二阶段（优化）
- 收集用户修改分类的数据
- 分析AI分类的准确率
- 考虑是否升级到SmartCategoryService

### 第三阶段（智能化）
- 实现短信分类学习
- 根据用户历史习惯优化分类
- 可能引入SmartCategoryService

## 结论

**分类推断功能完全可以复用**，推荐使用**方案A（AI直接分类 + 规则兜底）**：

✅ **复用BillParser.inferCategory**：
- 作为兜底机制
- 确保总有分类
- 与文件导入保持一致

✅ **充分利用AI能力**：
- AI在解析时顺便推断分类
- 减少额外处理步骤
- 提高整体准确率

✅ **用户可修正**：
- 复用ImportPreviewPage
- 用户可手动修改分类
- 为未来学习优化留下空间

这种方案既简单高效，又充分复用了现有代码，是最佳选择。
