# 去重检测Bug修复说明

## 🐛 问题描述

**用户报告**: 去重检测页面显示的重复数据始终相同，无论导入什么文件都一样。

## 🔍 问题分析

通过代码审查发现，`app/lib/pages/import/duplicate_detection_page.dart` 中使用了**硬编码的假数据**：

### 问题代码 (第46-94行)

```dart
void _initializeData() {
  // 模拟去重检测结果
  final total = widget.transactions.length;
  _confirmedCount = (total * 0.08).round();
  _suspectedCount = (total * 0.12).round();
  _newCount = total - _confirmedCount - _suspectedCount;

  // 模拟疑似重复数据 - 硬编码！
  _suspectedDuplicates = [
    DuplicateItem(
      merchant: '星巴克',
      amount: 38.00,
      date: DateTime.now().subtract(const Duration(days: 1)),
      similarity: 92,
      // ...
    ),
    // ... 更多假数据
  ];
}
```

### 问题原因

1. 页面完全没有调用真实的去重检测服务
2. 直接返回硬编码的"星巴克"、"美团外卖"等假数据
3. 导致无论导入什么文件，显示的重复项都完全一样

### 实际情况

系统已经有完善的去重检测服务 (`DuplicateDetectionService`)，但去重检测页面没有使用它！

## ✅ 解决方案

### 1. 集成真实的去重检测服务

**修改内容:**

```dart
// 导入必要的依赖
import 'package:uuid/uuid.dart';
import '../../models/transaction.dart';
import '../../services/duplicate_detection_service.dart';
import '../../providers/database_provider.dart';
```

### 2. 实现真实的去重检测逻辑

```dart
/// 执行真实的去重检测
Future<void> _performDuplicateDetection() async {
  try {
    final db = ref.read(databaseProvider);

    // 获取现有交易
    final existingTransactions = await db.getTransactions();

    final suspectedList = <DuplicateItem>[];
    final confirmedList = <DuplicateItem>[];

    // 对每笔导入的交易进行去重检测
    for (final imported in widget.transactions) {
      // 转换为Transaction对象
      final newTransaction = Transaction(
        id: const Uuid().v4(),
        type: imported.amount > 0 ? TransactionType.income : TransactionType.expense,
        amount: imported.amount.abs(),
        category: imported.category ?? 'other',
        accountId: 'temp_account',
        date: imported.date,
        note: imported.merchant,
        createdAt: DateTime.now(),
      );

      // 执行去重检测
      final result = DuplicateDetectionService.checkDuplicate(
        newTransaction,
        existingTransactions,
      );

      if (result.hasPotentialDuplicate && result.potentialDuplicates.isNotEmpty) {
        final existing = result.potentialDuplicates.first;
        final duplicateItem = DuplicateItem(
          merchant: imported.merchant,
          amount: imported.amount,
          date: imported.date,
          similarity: result.similarityScore,
          existingMerchant: existing.note ?? '未命名',
          existingAmount: existing.amount,
          existingDate: existing.date,
        );

        // 根据相似度分类
        if (result.similarityScore >= 85) {
          // 85分以上为确定重复
          confirmedList.add(duplicateItem);
        } else if (result.similarityScore >= 55) {
          // 55-84分为疑似重复
          suspectedList.add(duplicateItem);
        }
      }
    }

    setState(() {
      _suspectedDuplicates = suspectedList;
      _confirmedDuplicates = confirmedList;
      _suspectedCount = suspectedList.length;
      _confirmedCount = confirmedList.length;
      _newCount = widget.transactions.length - _suspectedCount - _confirmedCount;
      _isLoading = false;
    });
  } catch (e) {
    debugPrint('去重检测失败: $e');
    setState(() {
      _isLoading = false;
      _newCount = widget.transactions.length;
    });
  }
}
```

### 3. 添加加载状态

```dart
// 添加加载状态
bool _isLoading = true;

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('正在检测重复交易...'),
              ],
            ),
          )
        : // ... 原有内容
  );
}
```

## 🎯 修复效果

### 修复前
- ❌ 显示硬编码的假数据
- ❌ 星巴克、美团外卖等固定内容
- ❌ 无论导入什么文件，重复项都一样

### 修复后
- ✅ 使用真实的去重检测算法
- ✅ 根据实际导入的交易内容检测
- ✅ 与现有数据库中的交易进行比对
- ✅ 按相似度分类（55-84分疑似，85+分确定）
- ✅ 显示真实的重复检测结果

## 📊 去重检测算法说明

### 评分标准 (DuplicateDetectionService)

| 检测项 | 分数 | 说明 |
|--------|------|------|
| 外部ID匹配 | 100分 | 交易单号完全匹配 |
| 金额相同 | 35分 | 必要条件 |
| 时间接近 | 10-20分 | ≤5分钟20分，≤30分钟15分，≤2小时10分 |
| 分类相同 | 15分 | 完全相同15分，同级分类8分 |
| 备注相似 | 20分 | 语义相似度 |
| 类型相同 | 10分 | 收入/支出类型 |
| 账户相同 | 5分 | 同一账户 |

### 判定阈值

- **85分以上**: 确定重复
- **55-84分**: 疑似重复
- **55分以下**: 不重复

### 核心原则

1. **时间是最重要因素** - 只检查同一天的交易
2. **时间差超过2小时不算重复** - 避免误判日常重复消费
3. **多维度综合评分** - 金额、时间、分类、备注等

## 📝 测试建议

### 测试场景1: 真实重复
导入包含重复交易的文件：
- 同一天
- 相同金额
- 时间接近
- **预期**: 显示在"确定重复"或"疑似重复"中

### 测试场景2: 非重复
导入完全不同的交易：
- 不同日期或金额
- **预期**: 显示在"新交易"中

### 测试场景3: 日常重复消费
导入每天的早餐等固定支出：
- 每天相同金额
- 不同日期
- **预期**: 显示在"新交易"中（不误判为重复）

## 🔧 相关文件

- **修复文件**: `app/lib/pages/import/duplicate_detection_page.dart`
- **去重服务**: `app/lib/services/duplicate_detection_service.dart`
- **评分器**: `app/lib/services/import/enhanced_duplicate_scorer.dart`

## 📅 修复时间

**日期**: 2026-01-28
**版本**: 2.0.13+59

---

**修复状态**: ✅ 已完成
**测试状态**: ⏳ 待用户验证
