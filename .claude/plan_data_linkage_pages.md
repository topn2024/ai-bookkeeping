# 数据联动页面实施计划

## 概述

根据原型设计文件 `app_v2_full_prototype.html` 的 Section 9，需要实现以下5个数据联动页面：

| 编号 | 页面名称 | 文件名 | 状态 |
|------|---------|--------|------|
| 9.01 | 分类详情 | `category_detail_page.dart` | 待实现 |
| 9.02 | 搜索结果 | `search_result_page.dart` | 待实现 |
| 9.03 | 高级筛选 | `advanced_filter_page.dart` | 待实现 |
| 9.04 | 时间对比 | `period_comparison_page.dart` | 待实现 |
| 9.05 | 标签筛选 | `tag_filter_page.dart` | 待实现 |

## 实施策略

### 前端实现 (Flutter App)

所有页面将遵循现有代码模式：
- 使用 `ConsumerStatefulWidget` + Riverpod 状态管理
- 使用 `ThemeColors` 获取主题颜色
- 复用现有的交易列表组件和卡片样式
- 页面间通过 `Navigator.push` + 参数传递实现导航

---

## 页面 1: 分类详情页 (CategoryDetailPage)

### 功能描述
从统计页面饼图或分类列表点击进入，显示该分类的详细支出情况。

### 原型设计要点
- 顶部：分类颜色标题栏，显示分类名称和图标
- 汇总卡片：本月支出、占比、交易笔数、日均支出
- 趋势图表：该分类最近时期的消费趋势折线/柱状图
- 交易明细：该分类下的所有交易列表（按时间分组）

### 实现细节

```dart
// 路径: app/lib/pages/category_detail_page.dart

class CategoryDetailPage extends ConsumerStatefulWidget {
  final String categoryId;  // 分类ID
  final DateTime? selectedMonth;  // 可选的指定月份

  const CategoryDetailPage({
    super.key,
    required this.categoryId,
    this.selectedMonth,
  });
}
```

### 数据获取
- 从 `transactionProvider` 过滤指定分类的交易
- 计算本月/指定月份的汇总数据
- 生成趋势数据（最近7天或每周）

### 导航入口
- 从 `StatisticsPage` 饼图点击分类扇区
- 从 `StatisticsPage` 分类列表点击分类项

---

## 页面 2: 搜索结果页 (SearchResultPage)

### 功能描述
显示搜索关键词匹配的交易结果，支持高亮显示匹配文字。

### 原型设计要点
- 顶部搜索栏：显示当前搜索词，可修改
- 结果统计：找到 X 条结果
- 交易列表：匹配的交易，高亮显示关键词
- 底部汇总：总计金额

### 实现细节

```dart
// 路径: app/lib/pages/search_result_page.dart

class SearchResultPage extends ConsumerStatefulWidget {
  final String initialKeyword;  // 初始搜索关键词

  const SearchResultPage({
    super.key,
    required this.initialKeyword,
  });
}
```

### 搜索逻辑
- 搜索范围：交易备注、分类名称
- 实时搜索：输入时延迟300ms后自动搜索
- 高亮显示：使用 `RichText` 高亮匹配部分

### 导航入口
- 从 `TransactionListPage` 搜索栏点击后跳转
- 从首页快速搜索入口

---

## 页面 3: 高级筛选页 (AdvancedFilterPage)

### 功能描述
提供多维度筛选条件的独立页面/底部弹窗。

### 原型设计要点
- 时间范围：今天/本月/本季度/本年/自定义
- 金额范围：最小/最大金额输入框
- 分类多选：支出/收入分类的 Chip 多选
- 账户多选：全部/现金/储蓄卡/信用卡
- 类型：全部/支出/收入/转账
- 底部按钮：重置、应用筛选

### 实现细节

```dart
// 路径: app/lib/pages/advanced_filter_page.dart

/// 筛选条件数据模型
class FilterCriteria {
  final DateTimeRange? dateRange;
  final double? minAmount;
  final double? maxAmount;
  final List<String>? categoryIds;
  final List<String>? accountIds;
  final TransactionType? transactionType;

  const FilterCriteria({...});
}

/// 高级筛选组件（可作为页面或底部弹窗使用）
class AdvancedFilterPage extends ConsumerStatefulWidget {
  final FilterCriteria? initialCriteria;
  final Function(FilterCriteria) onApply;

  const AdvancedFilterPage({
    super.key,
    this.initialCriteria,
    required this.onApply,
  });
}
```

### 使用方式
1. 作为底部弹窗：`showModalBottomSheet`
2. 作为独立页面：`Navigator.push`

---

## 页面 4: 时间对比页 (PeriodComparisonPage)

### 功能描述
对比不同时间段的收支情况，提供直观的数据变化分析。

### 原型设计要点
- 对比模式切换：月对比/季对比/年对比
- 双卡片对比：当前 vs 上期 的支出总额
- 差额显示：金额差值、百分比变化、趋势图标
- 分类对比列表：各分类的环比变化

### 实现细节

```dart
// 路径: app/lib/pages/period_comparison_page.dart

enum ComparisonMode { month, quarter, year }

class PeriodComparisonPage extends ConsumerStatefulWidget {
  final ComparisonMode initialMode;

  const PeriodComparisonPage({
    super.key,
    this.initialMode = ComparisonMode.month,
  });
}
```

### 数据计算
- 当前期间 vs 上一期间
- 按分类计算各自的环比变化
- 使用 `fl_chart` 展示对比图表

### 导航入口
- 从 `StatisticsPage` 对比分析入口
- 从首页快速入口

---

## 页面 5: 标签筛选页 (TagFilterPage)

### 功能描述
管理和筛选标签，查看标签下的交易。

### 原型设计要点
- 标签云：常用标签显示（带计数）
- 标签列表：所有标签及其统计
- 点击标签：显示该标签下的交易列表
- 新增标签：添加新标签入口

### 实现细节

```dart
// 路径: app/lib/pages/tag_filter_page.dart

class TagFilterPage extends ConsumerStatefulWidget {
  final String? initialTag;  // 可选的初始选中标签

  const TagFilterPage({
    super.key,
    this.initialTag,
  });
}
```

### 数据来源
- 复用 `tag_statistics_page.dart` 的 Provider
- `allTagsProvider` - 所有标签
- `tagStatisticsProvider` - 标签统计数据

### 与现有页面关系
- `TagStatisticsPage` 已有标签统计功能
- `TagFilterPage` 侧重于筛选和管理
- 两者可共享组件和数据

---

## 共享组件

### 1. 交易列表组件 (已存在)
- `SwipeableTransactionItem` - 可滑动的交易项
- 按日期分组的列表布局

### 2. 新增共享组件

```dart
// 路径: app/lib/widgets/transaction_summary_card.dart
/// 交易汇总卡片（用于分类详情、搜索结果等）
class TransactionSummaryCard extends StatelessWidget {
  final int transactionCount;
  final double totalAmount;
  final double? percentage;
  final double? dailyAverage;
  final Color? color;
}

// 路径: app/lib/widgets/category_trend_chart.dart
/// 分类趋势图表
class CategoryTrendChart extends StatelessWidget {
  final List<TrendDataPoint> data;
  final Color color;
}

// 路径: app/lib/widgets/comparison_card.dart
/// 对比卡片
class ComparisonCard extends StatelessWidget {
  final String label;
  final double currentValue;
  final double previousValue;
}
```

---

## 路由/导航修改

### StatisticsPage 修改
```dart
// 在饼图点击回调中添加导航
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CategoryDetailPage(categoryId: categoryId),
    ),
  );
}
```

### TransactionListPage 修改
```dart
// 搜索栏改为跳转到搜索结果页
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SearchResultPage(initialKeyword: _searchKeyword),
    ),
  );
}

// 高级筛选按钮改为打开筛选页
onPressed: () {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AdvancedFilterPage(
      initialCriteria: _currentCriteria,
      onApply: (criteria) => _applyFilter(criteria),
    ),
  );
}
```

---

## 国际化支持

所有新增页面需要在以下文件添加对应的翻译：
- `app/lib/l10n/app_zh.arb`
- `app/lib/l10n/app_en.arb`
- `app/lib/l10n/app_ja.arb`
- `app/lib/l10n/app_ko.arb`

新增键值示例：
```json
{
  "categoryDetail": "分类详情",
  "searchResult": "搜索结果",
  "advancedFilter": "高级筛选",
  "periodComparison": "时间对比",
  "tagFilter": "标签筛选",
  "foundNResults": "找到 {count} 条结果",
  "totalAmount": "总计金额",
  "comparedToLastPeriod": "相比上期",
  "resetFilter": "重置",
  "applyFilter": "应用筛选"
}
```

---

## 实施顺序

建议按以下顺序实施，确保依赖关系正确：

1. **共享组件** - 先实现复用组件
2. **分类详情页** - 与统计页紧密关联
3. **高级筛选页** - 被多个页面使用
4. **搜索结果页** - 依赖高级筛选
5. **时间对比页** - 独立功能
6. **标签筛选页** - 可复用现有标签统计

---

## 后端支持（如需）

当前实现基于本地数据，无需后端修改。如需服务端支持：
- 搜索API: `GET /api/transactions/search?keyword=xxx`
- 统计API: `GET /api/statistics/category/{id}`
- 对比API: `GET /api/statistics/comparison?period=month`

---

## 测试要点

1. 分类详情：验证数据计算准确性
2. 搜索结果：验证搜索逻辑和高亮显示
3. 高级筛选：验证多条件组合筛选
4. 时间对比：验证环比计算正确性
5. 标签筛选：验证标签统计和交易列表

---

## 预估工作量

| 页面 | 预估代码行数 | 复杂度 |
|------|-------------|--------|
| 共享组件 | ~200行 | 低 |
| 分类详情页 | ~350行 | 中 |
| 搜索结果页 | ~250行 | 低 |
| 高级筛选页 | ~400行 | 中 |
| 时间对比页 | ~400行 | 中 |
| 标签筛选页 | ~300行 | 低 |
| 国际化 | ~50行 | 低 |
| **总计** | ~1950行 | - |
