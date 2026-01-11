import 'package:flutter_test/flutter_test.dart';

/// 钱龄计算服务单元测试
///
/// 覆盖核心钱龄计算逻辑
void main() {
  group('MoneyAgeCalculator Tests', () {
    late MockMoneyAgeCalculator calculator;

    setUp(() {
      calculator = MockMoneyAgeCalculator();
    });

    group('FIFO 钱龄计算', () {
      test('单笔收入单笔支出 - 钱龄等于间隔天数', () {
        // 准备数据：1月1日收入1000元
        calculator.addIncome(
          amount: 1000,
          date: DateTime(2024, 1, 1),
        );

        // 1月11日支出500元，钱龄应为10天
        final result = calculator.calculateExpenseMoneyAge(
          amount: 500,
          date: DateTime(2024, 1, 11),
        );

        expect(result.averageAge, equals(10));
        expect(result.totalAmount, equals(500));
      });

      test('多笔收入单笔支出 - FIFO先进先出', () {
        // 1月1日收入500元
        calculator.addIncome(amount: 500, date: DateTime(2024, 1, 1));
        // 1月5日收入500元
        calculator.addIncome(amount: 500, date: DateTime(2024, 1, 5));

        // 1月11日支出700元
        // 先消耗1月1日的500元（钱龄10天）
        // 再消耗1月5日的200元（钱龄6天）
        final result = calculator.calculateExpenseMoneyAge(
          amount: 700,
          date: DateTime(2024, 1, 11),
        );

        // 加权平均：(500*10 + 200*6) / 700 = 8.86
        expect(result.averageAge, closeTo(8.86, 0.01));
      });

      test('支出超过收入 - 产生负钱龄（预支）', () {
        calculator.addIncome(amount: 500, date: DateTime(2024, 1, 1));

        // 支出1000元，超过收入500元
        final result = calculator.calculateExpenseMoneyAge(
          amount: 1000,
          date: DateTime(2024, 1, 11),
        );

        expect(result.hasDeficit, isTrue);
        expect(result.deficitAmount, equals(500));
      });

      test('无收入直接支出 - 全部为预支', () {
        final result = calculator.calculateExpenseMoneyAge(
          amount: 100,
          date: DateTime(2024, 1, 11),
        );

        expect(result.hasDeficit, isTrue);
        expect(result.deficitAmount, equals(100));
        expect(result.averageAge, equals(0));
      });
    });

    group('钱龄等级计算', () {
      test('钱龄0-7天为"即赚即花"级别', () {
        final level = MoneyAgeLevel.fromDays(5);
        expect(level, equals(MoneyAgeLevel.immediate));
        expect(level.name, equals('即赚即花'));
      });

      test('钱���8-30天为"月光族"级别', () {
        final level = MoneyAgeLevel.fromDays(15);
        expect(level, equals(MoneyAgeLevel.monthly));
        expect(level.name, equals('月光族'));
      });

      test('钱龄31-90天为"季度储蓄"级别', () {
        final level = MoneyAgeLevel.fromDays(60);
        expect(level, equals(MoneyAgeLevel.quarterly));
        expect(level.name, equals('季度储蓄'));
      });

      test('钱龄91-365天为"年度规划"级别', () {
        final level = MoneyAgeLevel.fromDays(180);
        expect(level, equals(MoneyAgeLevel.yearly));
        expect(level.name, equals('年度规划'));
      });

      test('钱龄365天以上为"财务自由"级别', () {
        final level = MoneyAgeLevel.fromDays(500);
        expect(level, equals(MoneyAgeLevel.wealthy));
        expect(level.name, equals('财务自由'));
      });
    });

    group('钱龄趋势分析', () {
      test('计算周钱龄趋势', () {
        // 模拟一周数据
        final weeklyData = [
          MoneyAgeDayData(date: DateTime(2024, 1, 1), averageAge: 10),
          MoneyAgeDayData(date: DateTime(2024, 1, 2), averageAge: 12),
          MoneyAgeDayData(date: DateTime(2024, 1, 3), averageAge: 8),
          MoneyAgeDayData(date: DateTime(2024, 1, 4), averageAge: 15),
          MoneyAgeDayData(date: DateTime(2024, 1, 5), averageAge: 11),
          MoneyAgeDayData(date: DateTime(2024, 1, 6), averageAge: 14),
          MoneyAgeDayData(date: DateTime(2024, 1, 7), averageAge: 13),
        ];

        final trend = MoneyAgeTrendAnalyzer.analyze(weeklyData);

        expect(trend.average, closeTo(11.86, 0.01));
        expect(trend.min, equals(8));
        expect(trend.max, equals(15));
        expect(trend.trend, equals(TrendDirection.up)); // 从10到13，上升趋势
      });

      test('计算月度钱龄对比', () {
        final currentMonth = MoneyAgeMonthData(
          month: DateTime(2024, 2),
          averageAge: 25,
          totalIncome: 10000,
          totalExpense: 8000,
        );

        final previousMonth = MoneyAgeMonthData(
          month: DateTime(2024, 1),
          averageAge: 20,
          totalIncome: 9000,
          totalExpense: 9000,
        );

        final comparison = MoneyAgeComparison.compare(currentMonth, previousMonth);

        expect(comparison.ageChange, equals(5));
        expect(comparison.ageChangePercent, closeTo(25, 0.1));
        expect(comparison.isImproved, isTrue);
      });
    });

    group('钱龄改善建议', () {
      test('低钱龄用户获得储蓄建议', () {
        final suggestions = MoneyAgeSuggestionEngine.getSuggestions(
          averageAge: 5,
          incomePattern: IncomePattern.regular,
          expensePattern: ExpensePattern.highFrequency,
        );

        expect(suggestions.length, greaterThan(0));
        expect(
          suggestions.any((s) => s.type == SuggestionType.increaseSavings),
          isTrue,
        );
      });

      test('高支出频率用户获得支出优化建议', () {
        final suggestions = MoneyAgeSuggestionEngine.getSuggestions(
          averageAge: 10,
          incomePattern: IncomePattern.regular,
          expensePattern: ExpensePattern.highFrequency,
        );

        expect(
          suggestions.any((s) => s.type == SuggestionType.reduceFrequency),
          isTrue,
        );
      });

      test('不稳定收入用户获得收入稳定建议', () {
        final suggestions = MoneyAgeSuggestionEngine.getSuggestions(
          averageAge: 15,
          incomePattern: IncomePattern.irregular,
          expensePattern: ExpensePattern.normal,
        );

        expect(
          suggestions.any((s) => s.type == SuggestionType.stabilizeIncome),
          isTrue,
        );
      });
    });
  });

  group('ResourcePool Tests', () {
    late MockResourcePool pool;

    setUp(() {
      pool = MockResourcePool();
    });

    test('添加收入创建资源', () {
      pool.addResource(
        amount: 1000,
        source: 'salary',
        date: DateTime(2024, 1, 1),
      );

      expect(pool.totalAvailable, equals(1000));
      expect(pool.resourceCount, equals(1));
    });

    test('消耗资源按FIFO顺序', () {
      pool.addResource(amount: 500, source: 'salary', date: DateTime(2024, 1, 1));
      pool.addResource(amount: 500, source: 'bonus', date: DateTime(2024, 1, 15));

      final consumed = pool.consume(amount: 700, date: DateTime(2024, 1, 20));

      expect(consumed.length, equals(2));
      expect(consumed[0].source, equals('salary'));
      expect(consumed[0].amount, equals(500));
      expect(consumed[1].source, equals('bonus'));
      expect(consumed[1].amount, equals(200));
      expect(pool.totalAvailable, equals(300));
    });

    test('资源池快照保存和恢复', () {
      pool.addResource(amount: 1000, source: 'salary', date: DateTime(2024, 1, 1));
      pool.consume(amount: 300, date: DateTime(2024, 1, 10));

      final snapshot = pool.createSnapshot();

      pool.consume(amount: 200, date: DateTime(2024, 1, 15));
      expect(pool.totalAvailable, equals(500));

      pool.restoreFromSnapshot(snapshot);
      expect(pool.totalAvailable, equals(700));
    });
  });
}

// ==================== Mock 类和辅助类 ====================

/// Mock 钱龄计算器
class MockMoneyAgeCalculator {
  final List<IncomeRecord> _incomes = [];
  // ignore: unused_field
  double _availableBalance = 0;

  void addIncome({required double amount, required DateTime date}) {
    _incomes.add(IncomeRecord(amount: amount, date: date, remaining: amount));
    _availableBalance += amount;
  }

  MoneyAgeResult calculateExpenseMoneyAge({
    required double amount,
    required DateTime date,
  }) {
    double totalWeightedAge = 0;
    double consumedAmount = 0;
    double deficitAmount = 0;

    // FIFO 消耗
    for (final income in _incomes) {
      if (consumedAmount >= amount) break;
      if (income.remaining <= 0) continue;

      final toConsume = (income.remaining < amount - consumedAmount)
          ? income.remaining
          : amount - consumedAmount;

      final ageDays = date.difference(income.date).inDays;
      totalWeightedAge += toConsume * ageDays;
      consumedAmount += toConsume;
      income.remaining -= toConsume;
    }

    // 检查是否有赤字
    if (consumedAmount < amount) {
      deficitAmount = amount - consumedAmount;
    }

    final averageAge = consumedAmount > 0 ? totalWeightedAge / consumedAmount : 0.0;

    return MoneyAgeResult(
      averageAge: averageAge.toDouble(),
      totalAmount: amount,
      consumedAmount: consumedAmount,
      deficitAmount: deficitAmount,
    );
  }
}

class IncomeRecord {
  final double amount;
  final DateTime date;
  double remaining;

  IncomeRecord({
    required this.amount,
    required this.date,
    required this.remaining,
  });
}

class MoneyAgeResult {
  final double averageAge;
  final double totalAmount;
  final double consumedAmount;
  final double deficitAmount;

  MoneyAgeResult({
    required this.averageAge,
    required this.totalAmount,
    required this.consumedAmount,
    required this.deficitAmount,
  });

  bool get hasDeficit => deficitAmount > 0;
}

/// 钱龄等级
enum MoneyAgeLevel {
  immediate, // 0-7天
  monthly,   // 8-30天
  quarterly, // 31-90天
  yearly,    // 91-365天
  wealthy,   // 365天以上

  ;

  String get name {
    switch (this) {
      case MoneyAgeLevel.immediate:
        return '即赚即花';
      case MoneyAgeLevel.monthly:
        return '月光族';
      case MoneyAgeLevel.quarterly:
        return '季度储蓄';
      case MoneyAgeLevel.yearly:
        return '年度规划';
      case MoneyAgeLevel.wealthy:
        return '财务自由';
    }
  }

  static MoneyAgeLevel fromDays(int days) {
    if (days <= 7) return MoneyAgeLevel.immediate;
    if (days <= 30) return MoneyAgeLevel.monthly;
    if (days <= 90) return MoneyAgeLevel.quarterly;
    if (days <= 365) return MoneyAgeLevel.yearly;
    return MoneyAgeLevel.wealthy;
  }
}

/// 钱龄日数据
class MoneyAgeDayData {
  final DateTime date;
  final double averageAge;

  MoneyAgeDayData({required this.date, required this.averageAge});
}

/// 趋势方向
enum TrendDirection { up, down, stable }

/// 钱龄趋势分析结果
class MoneyAgeTrendResult {
  final double average;
  final double min;
  final double max;
  final TrendDirection trend;

  MoneyAgeTrendResult({
    required this.average,
    required this.min,
    required this.max,
    required this.trend,
  });
}

/// 钱龄趋势分析器
class MoneyAgeTrendAnalyzer {
  static MoneyAgeTrendResult analyze(List<MoneyAgeDayData> data) {
    if (data.isEmpty) {
      return MoneyAgeTrendResult(
        average: 0,
        min: 0,
        max: 0,
        trend: TrendDirection.stable,
      );
    }

    final ages = data.map((d) => d.averageAge).toList();
    final average = ages.reduce((a, b) => a + b) / ages.length;
    final min = ages.reduce((a, b) => a < b ? a : b);
    final max = ages.reduce((a, b) => a > b ? a : b);

    // 简单趋势判断：比较首尾
    TrendDirection trend;
    final diff = ages.last - ages.first;
    if (diff > 1) {
      trend = TrendDirection.up;
    } else if (diff < -1) {
      trend = TrendDirection.down;
    } else {
      trend = TrendDirection.stable;
    }

    return MoneyAgeTrendResult(
      average: average,
      min: min,
      max: max,
      trend: trend,
    );
  }
}

/// 月度钱龄数据
class MoneyAgeMonthData {
  final DateTime month;
  final double averageAge;
  final double totalIncome;
  final double totalExpense;

  MoneyAgeMonthData({
    required this.month,
    required this.averageAge,
    required this.totalIncome,
    required this.totalExpense,
  });
}

/// 钱龄对比结果
class MoneyAgeComparison {
  final double ageChange;
  final double ageChangePercent;
  final bool isImproved;

  MoneyAgeComparison({
    required this.ageChange,
    required this.ageChangePercent,
    required this.isImproved,
  });

  static MoneyAgeComparison compare(
    MoneyAgeMonthData current,
    MoneyAgeMonthData previous,
  ) {
    final change = current.averageAge - previous.averageAge;
    final percent = previous.averageAge > 0
        ? (change / previous.averageAge) * 100
        : 0.0;

    return MoneyAgeComparison(
      ageChange: change,
      ageChangePercent: percent,
      isImproved: change > 0,
    );
  }
}

/// 收入模式
enum IncomePattern { regular, irregular }

/// 支出模式
enum ExpensePattern { normal, highFrequency, lowFrequency }

/// 建议类型
enum SuggestionType {
  increaseSavings,
  reduceFrequency,
  stabilizeIncome,
  setGoal,
}

/// 钱龄改善建议
class MoneyAgeSuggestion {
  final SuggestionType type;
  final String title;
  final String description;

  MoneyAgeSuggestion({
    required this.type,
    required this.title,
    required this.description,
  });
}

/// 建议引擎
class MoneyAgeSuggestionEngine {
  static List<MoneyAgeSuggestion> getSuggestions({
    required double averageAge,
    required IncomePattern incomePattern,
    required ExpensePattern expensePattern,
  }) {
    final suggestions = <MoneyAgeSuggestion>[];

    // 低钱龄建议
    if (averageAge < 15) {
      suggestions.add(MoneyAgeSuggestion(
        type: SuggestionType.increaseSavings,
        title: '增加储蓄',
        description: '您的钱龄较低，建议每月固定存储一部分收入',
      ));
    }

    // 高支出频率建议
    if (expensePattern == ExpensePattern.highFrequency) {
      suggestions.add(MoneyAgeSuggestion(
        type: SuggestionType.reduceFrequency,
        title: '减少消费频率',
        description: '尝试合并购物，减少冲动消费',
      ));
    }

    // 不稳定收入建议
    if (incomePattern == IncomePattern.irregular) {
      suggestions.add(MoneyAgeSuggestion(
        type: SuggestionType.stabilizeIncome,
        title: '稳定收入',
        description: '建立应急基金，应对收入波动',
      ));
    }

    return suggestions;
  }
}

/// Mock 资源池
class MockResourcePool {
  final List<ResourceItem> _resources = [];

  double get totalAvailable =>
      _resources.fold(0, (sum, r) => sum + r.remaining);

  int get resourceCount => _resources.length;

  void addResource({
    required double amount,
    required String source,
    required DateTime date,
  }) {
    _resources.add(ResourceItem(
      amount: amount,
      source: source,
      date: date,
      remaining: amount,
    ));
  }

  List<ConsumedResource> consume({
    required double amount,
    required DateTime date,
  }) {
    final consumed = <ConsumedResource>[];
    double remaining = amount;

    for (final resource in _resources) {
      if (remaining <= 0) break;
      if (resource.remaining <= 0) continue;

      final toConsume = resource.remaining < remaining
          ? resource.remaining
          : remaining;

      consumed.add(ConsumedResource(
        source: resource.source,
        amount: toConsume,
        age: date.difference(resource.date).inDays,
      ));

      resource.remaining -= toConsume;
      remaining -= toConsume;
    }

    return consumed;
  }

  ResourcePoolSnapshot createSnapshot() {
    return ResourcePoolSnapshot(
      resources: _resources.map((r) => ResourceItem(
        amount: r.amount,
        source: r.source,
        date: r.date,
        remaining: r.remaining,
      )).toList(),
    );
  }

  void restoreFromSnapshot(ResourcePoolSnapshot snapshot) {
    _resources.clear();
    _resources.addAll(snapshot.resources);
  }
}

class ResourceItem {
  final double amount;
  final String source;
  final DateTime date;
  double remaining;

  ResourceItem({
    required this.amount,
    required this.source,
    required this.date,
    required this.remaining,
  });
}

class ConsumedResource {
  final String source;
  final double amount;
  final int age;

  ConsumedResource({
    required this.source,
    required this.amount,
    required this.age,
  });
}

class ResourcePoolSnapshot {
  final List<ResourceItem> resources;

  ResourcePoolSnapshot({required this.resources});
}
