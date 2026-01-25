# 剩余的数值计算问题清单

生成时间：2026-01-25

## 概述

本文档列出了系统中尚未修复的数值计算问题。这些问题按严重程度和影响范围分类。

---

## 🔴 高优先级问题（建议尽快修复）

### 1. NPS调查计算 - 空列表和除零风险
**文件**: `lib/models/nps_survey.dart`
**位置**: 第275-279行

**问题**:
```dart
final promoterPct = promoters / total * 100;
final detractorPct = detractors / total * 100;
final nps = promoterPct - detractorPct;

final avgScore = responses.map((r) => r.score).reduce((a, b) => a + b) / total;
```

**风险**:
- 当 `total` 为 0 时会除零
- `reduce()` 在空列表时会抛出异常

**建议修复**:
```dart
if (total == 0) return 0;
final promoterPct = promoters / total * 100;
final detractorPct = detractors / total * 100;
final nps = promoterPct - detractorPct;

final avgScore = responses.isEmpty ? 0 :
    responses.map((r) => r.score).reduce((a, b) => a + b) / total;
```

---

### 2. 拿铁因子分析器 - 多处除零风险
**文件**: `lib/services/latte_factor_analyzer.dart`
**���置**: 第33行, 144行, 206行

**问题**:
```dart
// 第33行
final reduction = (weeklyFrequency - targetWeeklyFrequency) / weeklyFrequency;

// 第144行
final weeklyFrequency = cluster.transactions.length / weeksInPeriod;

// 第206行
final weeklyFrequency = expenses.length / weeksInPeriod;
```

**风险**:
- `weeklyFrequency` 可能为 0，导致第33行除零
- `weeksInPeriod` 计算为 `period * 4.3`，如果 `period` 为 0 则会除零

**建议修复**:
```dart
// 第33行
if (weeklyFrequency == 0) return 0;
final reduction = (weeklyFrequency - targetWeeklyFrequency) / weeklyFrequency;

// 第144行和第206行
if (weeksInPeriod <= 0) return 0;
final weeklyFrequency = cluster.transactions.length / weeksInPeriod;
```

---

### 3. 自适应预算服务 - 多处reduce()风险
**文件**: `lib/services/adaptive_budget_service.dart`
**位置**: 第322行, 326行, 647-648行, 656行

**问题**:
```dart
// 第322行
final avgSpending = history.reduce((a, b) => a + b) / history.length;

// 第326行
final avgRecent = recentMonths.reduce((a, b) => a + b) / recentMonths.length;

// 第647-648行
final avg = history.reduce((a, b) => a + b) / history.length;
final variance = history.map((x) => math.pow(x - avg, 2)).reduce((a, b) => a + b) / history.length;

// 第656行
final deviation = (suggested - avg).abs() / avg;
```

**风险**:
- 多处 `reduce()` 在空列表时会抛出异常
- 第656行当 `avg` 为 0 时会除零

**建议修复**:
```dart
if (history.isEmpty) return 0;
final avgSpending = history.reduce((a, b) => a + b) / history.length;

// 第656行
if (avg == 0) return 0;
final deviation = (suggested - avg).abs() / avg;
```

---

## 🟡 中等优先级问题

### 4. 趋势预测服务 - 社交对比计算
**文件**: `lib/services/social_comparison_service.dart`
**位置**: 第378行, 549行, 555行

**问题**:
```dart
// 第378行
final difference = (userAmount - avgAmount) / avgAmount;

// 第549行
return 50 + ((userValue - avgValue) / (topValue - avgValue) * 45).round();

// 第555行
return 50 + ((avgValue - userValue) / (avgValue - topValue) * 45).round();
```

**风险**:
- 当 `avgAmount` 为 0 时会除零
- 当 `topValue == avgValue` 时会除零

**建议修复**:
```dart
if (avgAmount == 0) return 0;
final difference = (userAmount - avgAmount) / avgAmount;

if (topValue == avgValue) return 50;
return 50 + ((userValue - avgValue) / (topValue - avgValue) * 45).round();
```

---

### 5. 变动收入适配器 - reduce()风险
**文件**: `lib/services/variable_income_adapter.dart`
**位置**: 第378行, 392行

**问题**:
```dart
// 第378行
final average = monthlyIncomes.reduce((a, b) => a + b) / monthlyIncomes.length;

// 第392行
final cv = average > 0 ? stdDev / average : 0.0;
```

**风险**:
- `reduce()` 在空列表时会抛出异常

**建议修复**:
```dart
if (monthlyIncomes.isEmpty) return 0;
final average = monthlyIncomes.reduce((a, b) => a + b) / monthlyIncomes.length;
```

---

### 6. 订阅跟踪服务 - reduce()和除零风险
**文件**: `lib/services/subscription_tracking_service.dart`
**位置**: 第474行, 478行

**问题**:
```dart
// 第474行
final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;

// 第478行
final amountStability = 1.0 / (1.0 + sqrt(amountVariance) / avgAmount);
```

**风险**:
- `reduce()` 在空列表时会抛出异常
- 第478行当 `avgAmount` 为 0 时会除零

**建议修复**:
```dart
if (amounts.isEmpty) return 0;
final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;

if (avgAmount == 0) return 0;
final amountStability = 1.0 / (1.0 + sqrt(amountVariance) / avgAmount);
```

---

### 7. 债务健康卡片 - 除零风险
**文件**: `lib/widgets/debt_health_card.dart`
**位置**: 第88行

**问题**:
```dart
return (remainingAmount / monthlyPayment).ceil();
```

**风险**:
- 当 `monthlyPayment` 为 0 时会除零（虽然有 `<= 0` 检查，但只返回 0，不阻止后续计算）

**建议修复**:
```dart
if (monthlyPayment <= 0) return 0;
return (remainingAmount / monthlyPayment).ceil();
```

---

### 8. 资源池模型 - reduce()风险
**文件**: `lib/models/resource_pool.dart`
**位置**: 第480-481行

**问题**:
```dart
final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
final olderAvg = older.reduce((a, b) => a + b) / older.length;
```

**风险**:
- 虽然有 `isEmpty` 检查，但 `reduce()` 在空列表时会抛出异常

**建议修复**:
```dart
if (recent.isEmpty || older.isEmpty) return TrendDirection.stable;
final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
final olderAvg = older.reduce((a, b) => a + b) / older.length;
```

---

## 🟢 低优先级问题

### 9. 支出热力图页面 - reduce()风险
**文件**: `lib/pages/reports/expense_heatmap_page.dart`
**位置**: 第58行

**问题**:
```dart
: dailyExpense.values.reduce((a, b) => a + b) / dailyExpense.length;
```

**风险**:
- `reduce()` 在空列表时会抛出异常

**建议修复**:
```dart
: dailyExpense.isEmpty ? 0 : dailyExpense.values.reduce((a, b) => a + b) / dailyExpense.length;
```

---

### 10. 承诺进度卡片 - 已有检查但可优化
**文件**: `lib/widgets/commitment_progress_card.dart`
**位置**: 第156-159行

**问题**:
```dart
final totalDays = endDate.difference(startDate).inDays;
final elapsedDays = DateTime.now().difference(startDate).inDays;
// ...
final expectedProgress = elapsedDays / totalDays;
```

**风险**:
- 当 `totalDays` 为 0 时会除零（开始和结束日期相同）
- 已有 `totalDays <= 0` 检查（第158行），但在除法之前

**状态**: 已有部分保护，但可以优化

---

### 11. 钱龄等级服务 - 范围计算
**文件**: `lib/services/money_age_level_service.dart`
**位置**: 第54行

**问题**:
```dart
return (days - minDays) / (maxDays! - minDays);
```

**风险**:
- 当 `maxDays == minDays` 时会除零

**建议修复**:
```dart
if (maxDays == minDays) return 0;
return (days - minDays) / (maxDays! - minDays);
```

---

### 12. 准确度增长服务 - 周数计算
**文件**: `lib/services/accuracy_growth_service.dart`
**位置**: 第206行

**问题**:
```dart
final weeklyImprovement = (last - first) / weeks;
```

**风险**:
- 当 `weeks` 为 0 时会除零（虽然有 `length < 2` 检查，但 `weeks = length - 1` 可能为 0）

**建议修复**:
```dart
if (weeks <= 0) return 0;
final weeklyImprovement = (last - first) / weeks;
```

---

### 13. 预算提供者 - 日均支出计算
**文件**: `lib/providers/budget_provider.dart`
**位置**: 第360行, 430行

**问题**:
```dart
// 第360行
final avgDailyExpense = recentExpenses / 30;

// 第430行
final avgDailyExpense = monthExpenses / daysInMonth;
```

**风险**:
- 虽然后续有 `avgDailyExpense > 0` 检查，但如果 `daysInMonth` 为 0 会除零

**建议修复**:
```dart
if (daysInMonth <= 0) return 0;
final avgDailyExpense = monthExpenses / daysInMonth;
```

---

## 已验证为安全的代码

以下代码已经有适当的边界检查，无需修改：

1. **lib/models/family_leaderboard.dart** (第93-96行) - ✅ 已有零检查
2. **lib/pages/period_comparison_page.dart** (第415行) - ✅ 已有零检查
3. **lib/widgets/peer_comparison_card.dart** (第52行) - ✅ 已有零检查
4. **lib/core/summary.dart** (第109行) - ✅ 已有空列表检查
5. **lib/services/allocation_service.dart** (第751行) - ✅ 已有检查
6. **lib/services/privacy/differential_privacy/sensitivity_calculator.dart** (第37行) - ✅ 已有检查
7. **lib/services/location_business_services.dart** (第316行) - ✅ 已有零检查
8. **lib/widgets/consumption_heatmap.dart** (第210-212行) - ✅ 已有范围检查

---

## 修复优先级建议

### 立即修复（影响核心功能）
1. lib/services/latte_factor_analyzer.dart - 拿铁因子是核心功能
2. lib/services/adaptive_budget_service.dart - 自适应预算是核心功能
3. lib/models/nps_survey.dart - 用户反馈功能

### 近期修复（影响用户体验）
4. lib/services/social_comparison_service.dart - 社交对比功能
5. lib/services/variable_income_adapter.dart - 变动收入处理
6. lib/services/subscription_tracking_service.dart - 订阅跟踪
7. lib/widgets/debt_health_card.dart - 债务管理

### 可延后修复（低频使用或已有部分保护）
8. lib/models/resource_pool.dart
9. lib/pages/reports/expense_heatmap_page.dart
10. lib/widgets/commitment_progress_card.dart
11. lib/services/money_age_level_service.dart
12. lib/services/accuracy_growth_service.dart
13. lib/providers/budget_provider.dart

---

## 通用修复模式

### Pattern 1: reduce() 操作
```dart
// 错误
final avg = list.reduce((a, b) => a + b) / list.length;

// 正确
if (list.isEmpty) return 0;
final avg = list.reduce((a, b) => a + b) / list.length;

// 或者使用 fold
final avg = list.isEmpty ? 0 : list.fold<double>(0, (sum, x) => sum + x) / list.length;
```

### Pattern 2: 除法操作
```dart
// 错误
final result = a / b;

// 正确
if (b == 0) return 0;  // 或其他合适的默认值
final result = a / b;
```

### Pattern 3: 范围计算
```dart
// 错误
final normalized = (value - min) / (max - min);

// 正确
if (max == min) return 0;  // 或 0.5，取决于业务逻辑
final normalized = (value - min) / (max - min);
```

---

## 总结

- **已修复问题**: 8个
- **待修复高优先级**: 3个
- **待修复中优先级**: 8个
- **待修复低优先级**: 5个
- **已验证安全**: 8个

建议优先修复高优先级问题，然后逐步处理中低优先级问题。所有修复都应该添加单元测试覆盖边界情况。
