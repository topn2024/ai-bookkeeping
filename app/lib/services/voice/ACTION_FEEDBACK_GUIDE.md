# 语音操作反馈使用指南

## 📋 概述

语音助手的每次操作都应该有明确、详细的反馈，让用户知道具体做了什么。

**原则**:
- ✅ 事事有反馈
- ✅ 有闭环
- ✅ 告诉用户做了什么，而不是将要做什么
- ✅ 成功/失败都要明确说明
- ✅ 以聊天形式呈现，简洁清晰

## 🔧 使用方法

### 1. 导入服务

```dart
import '../services/voice/action_feedback_service.dart';
```

### 2. 记账操作反馈

#### ❌ 错误示范

```dart
// 不要这样做：只说"好的"
_addAssistantMessage("好的，我来帮你记录这几笔");
```

#### ✅ 正确示范

```dart
// 执行记账操作后，收集结果
final results = <TransactionResult>[];

for (var intent in intents) {
  try {
    // 执行记账
    final transaction = await _databaseService.addTransaction(...);

    // 记录成功结果
    results.add(TransactionResult.success(
      type: TransactionType.expense,
      amount: intent.amount,
      category: intent.category,
      merchant: intent.merchant,
      description: intent.description,
      transactionId: transaction.id,
    ));
  } catch (e) {
    // 记录失败结果
    results.add(TransactionResult.failure(
      type: TransactionType.expense,
      amount: intent.amount,
      errorMessage: e.toString(),
    ));
  }
}

// 使用反馈服务生成详细反馈
final feedbackService = VoiceActionFeedbackService.instance;
final feedbackText = feedbackService.generateTransactionFeedback(results);

// 添加到聊天历史，包含详细的metadata
_addAssistantMessage(
  feedbackText,
  metadata: {
    'action_type': 'add_transaction',
    'results': results.map((r) => {
      'success': r.success,
      'type': r.type == TransactionType.expense ? 'expense' : 'income',
      'amount': r.amount,
      'category': r.category,
      'merchant': r.merchant,
      'description': r.description,
      'error_message': r.errorMessage,
    }).toList(),
  },
);
```

### 3. 实际效果对比

#### 用户说: "早餐花了15块，午餐30块，买水果花了50"

**❌ 旧的反馈**:
```
助手: "好的，我来帮你记录这三笔"
```
用户不知道是否真的记录了，记录的内容是什么。

**✅ 新的反馈**:
```
助手: "✓ 已成功记录 3 笔：

1. 支出 ¥15.00 · 餐饮 · 早餐
2. 支出 ¥30.00 · 餐饮 · 午餐
3. 支出 ¥50.00 · 食品 · 水果"
```
用户清楚知道每笔都记录了，金额、分类都正确。

### 4. 部分失败的情况

```dart
// 假设有3笔，2笔成功，1笔失败
final results = [
  TransactionResult.success(
    type: TransactionType.expense,
    amount: 15.0,
    category: '餐饮',
  ),
  TransactionResult.failure(
    type: TransactionType.expense,
    amount: 30.0,
    errorMessage: '分类识别失败',
  ),
  TransactionResult.success(
    type: TransactionType.expense,
    amount: 50.0,
    category: '食品',
  ),
];

final feedback = feedbackService.generateTransactionFeedback(results);
// 输出: "✓ 成功 2 笔，失败 1 笔：
//       1. 支出 ¥15.00 · 餐饮
//       2. 失败: 分类识别失败
//       3. 支出 ¥50.00 · 食品"
```

## 📊 其他操作类型

### 修改操作

```dart
final feedback = feedbackService.generateModifyFeedback(
  success: true,
  originalInfo: '支出 ¥50.00 · 餐饮',
  modifiedInfo: '支出 ¥55.00 · 餐饮 · 加了小费',
);

_addAssistantMessage(feedback, metadata: {...});
```

### 删除操作

```dart
final feedback = feedbackService.generateDeleteFeedback(
  success: true,
  deletedCount: 2,
  deletedInfo: '今天的餐饮支出',
);

_addAssistantMessage(feedback, metadata: {...});
```

### 查询操作

```dart
final feedback = feedbackService.generateQueryFeedback(
  success: true,
  result: '本月餐饮支出 ¥1,234.56，占总支出的 35.2%',
);

_addAssistantMessage(feedback, metadata: {...});
```

### 预算查询

```dart
final feedback = feedbackService.generateBudgetFeedback(
  categoryOrTotal: '餐饮',
  budgetAmount: 2000.0,
  usedAmount: 1234.56,
  remainingAmount: 765.44,
  usagePercentage: 61.7,
);

_addAssistantMessage(feedback, metadata: {...});
```

## 🎯 关键要点

1. **永远不要说 "好的，我来..."**
   - 用户说完后，已经完成操作，直接告知结果

2. **多笔操作要逐一反馈**
   - 3笔记账 = 明确告知3笔的状态
   - 不能含糊其辞

3. **失败也要有反馈**
   - 明确说明哪笔失败
   - 说明失败原因

4. **metadata要完整**
   - 包含所有操作结果
   - 用于UI渲染详细卡片

5. **保持文字简洁**
   - 提炼要点
   - 以聊天风格呈现
   - 不要冗长

## 📝 metadata 格式规范

```dart
// 单笔操作（兼容旧格式）
metadata: {
  'success': true,
  'amount': 50.0,
  'category': '餐饮',
  'merchant': '肯德基',
}

// 多笔操作（新格式）
metadata: {
  'action_type': 'add_transaction', // 操作类型
  'results': [
    {
      'success': true,
      'type': 'expense', // 'expense' 或 'income'
      'amount': 15.0,
      'category': '餐饮',
      'merchant': null,
      'description': '早餐',
      'error_message': null,
    },
    {
      'success': false,
      'type': 'expense',
      'amount': 30.0,
      'error_message': '金额过大，请确认',
    },
  ],
}
```

## 🚀 集成到现有代码

在 `voice_service_coordinator.dart` 或处理语音命令的地方：

```dart
import 'voice/action_feedback_service.dart';

class VoiceServiceCoordinator {
  final _feedbackService = VoiceActionFeedbackService.instance;

  Future<void> _executeAddTransaction(List<Intent> intents) async {
    // 1. 执行操作，收集结果
    final results = <TransactionResult>[];

    for (var intent in intents) {
      // ... 执行记账
      results.add(...);
    }

    // 2. 生成反馈
    final feedback = _feedbackService.generateTransactionFeedback(results);

    // 3. 添加到聊天历史
    _addAssistantMessage(
      feedback,
      metadata: {
        'action_type': 'add_transaction',
        'results': results.map((r) => r.toJson()).toList(),
      },
    );
  }
}
```

## ✅ 检查清单

在实现每个语音操作时，确保：

- [ ] 执行操作后收集了所有结果
- [ ] 使用 `VoiceActionFeedbackService` 生成反馈文本
- [ ] metadata 包含完整的操作结果
- [ ] 成功和失败都有明确反馈
- [ ] 多笔操作逐一说明
- [ ] 文字简洁、符合聊天风格
- [ ] 测试各种场景（全成功、部分失败、全失败）

---

**更新时间**: 2026-01-12
**负责人**: AI Assistant
**相关文件**:
- `app/lib/services/voice/action_feedback_service.dart`
- `app/lib/pages/voice_chat_page.dart`
