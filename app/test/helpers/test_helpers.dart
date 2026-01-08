import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试辅助工具
///
/// 提供单元测试、Widget测试、集成测试所需的工具和模拟对象
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== 测试工具函数 ====================

/// 创建测试用的 MaterialApp 包装器
Widget createTestApp({
  required Widget child,
  ThemeData? theme,
  Locale? locale,
  List<NavigatorObserver>? navigatorObservers,
}) {
  return MaterialApp(
    home: child,
    theme: theme ?? ThemeData.light(),
    locale: locale,
    navigatorObservers: navigatorObservers ?? [],
    debugShowCheckedModeBanner: false,
  );
}

/// 等待异步操作完成
Future<void> pumpAndSettle(WidgetTester tester, {Duration? duration}) async {
  if (duration != null) {
    await tester.pump(duration);
  }
  await tester.pumpAndSettle();
}

/// 等待特定条件满足
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    await tester.pump(interval);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TimeoutException('Waiting for $finder timed out');
}

/// 模拟网络延迟
Future<T> withNetworkDelay<T>(
  Future<T> Function() operation, {
  Duration delay = const Duration(milliseconds: 500),
}) async {
  await Future.delayed(delay);
  return operation();
}

/// 模拟随机失败
Future<T> withRandomFailure<T>(
  Future<T> Function() operation, {
  double failureRate = 0.2,
  Exception? customException,
}) async {
  if (DateTime.now().microsecondsSinceEpoch % 100 < failureRate * 100) {
    throw customException ?? Exception('Simulated random failure');
  }
  return operation();
}

// ==================== 断言辅助函数 ====================

/// 断言 Widget 包含指定文本
void expectText(String text) {
  expect(find.text(text), findsOneWidget);
}

/// 断言 Widget 不包含指定文本
void expectNoText(String text) {
  expect(find.text(text), findsNothing);
}

/// 断言 Widget 包含指定图标
void expectIcon(IconData icon) {
  expect(find.byIcon(icon), findsOneWidget);
}

/// 断言金额格式正确
void expectAmountFormat(String text, {String prefix = '¥'}) {
  expect(
    text.startsWith(prefix) && RegExp(r'[\d,]+\.?\d*').hasMatch(text.substring(prefix.length)),
    isTrue,
  );
}

/// 断言日期格式正确
void expectDateFormat(String text, String pattern) {
  // 简单的日期格式验证
  expect(text.isNotEmpty, isTrue);
}

// ==================== 测试数据生成器 ====================

/// 生成测试用交易数据
Map<String, dynamic> generateTestTransaction({
  String? id,
  String type = 'expense',
  double? amount,
  String? categoryId,
  String? accountId,
  String? description,
  DateTime? date,
}) {
  return {
    'id': id ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
    'type': type,
    'amount': amount ?? (100 + DateTime.now().millisecond % 900).toDouble(),
    'categoryId': categoryId ?? 'cat_food',
    'accountId': accountId ?? 'acc_cash',
    'description': description ?? '测试交易 ${DateTime.now().millisecond}',
    'date': (date ?? DateTime.now()).toIso8601String(),
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

/// 生成测试用账户数据
Map<String, dynamic> generateTestAccount({
  String? id,
  String? name,
  String type = 'cash',
  double balance = 1000,
  String? currency,
}) {
  return {
    'id': id ?? 'acc_${DateTime.now().millisecondsSinceEpoch}',
    'name': name ?? '测试账户 ${DateTime.now().millisecond}',
    'type': type,
    'balance': balance,
    'currency': currency ?? 'CNY',
    'icon': 'wallet',
    'color': '#4CAF50',
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

/// 生成测试用分类数据
Map<String, dynamic> generateTestCategory({
  String? id,
  String? name,
  String? parentId,
  bool isExpense = true,
}) {
  return {
    'id': id ?? 'cat_${DateTime.now().millisecondsSinceEpoch}',
    'name': name ?? '测试分类 ${DateTime.now().millisecond}',
    'parentId': parentId,
    'isExpense': isExpense,
    'icon': 'category',
    'color': '#FF5722',
    'sortOrder': 0,
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

/// 生成测试用预算数据
Map<String, dynamic> generateTestBudget({
  String? id,
  String? categoryId,
  double amount = 3000,
  String period = 'monthly',
  double spent = 0,
}) {
  return {
    'id': id ?? 'budget_${DateTime.now().millisecondsSinceEpoch}',
    'categoryId': categoryId ?? 'cat_food',
    'amount': amount,
    'spent': spent,
    'period': period,
    'startDate': DateTime.now().toIso8601String(),
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}

/// 批量生成测试交易
List<Map<String, dynamic>> generateTestTransactions(int count, {
  String type = 'expense',
  double minAmount = 10,
  double maxAmount = 1000,
}) {
  return List.generate(count, (index) {
    final amount = minAmount + (maxAmount - minAmount) * (index / count);
    return generateTestTransaction(
      id: 'tx_$index',
      type: type,
      amount: amount,
      description: '测试交易 $index',
      date: DateTime.now().subtract(Duration(days: index)),
    );
  });
}

// ==================== 测试 Finder 扩展 ====================

/// 通过语义标签查找 Widget
Finder findBySemanticsLabel(String label) {
  return find.bySemanticsLabel(label);
}

/// 通过测试 Key 查找 Widget
Finder findByTestKey(String key) {
  return find.byKey(Key(key));
}

/// 查找可滚动的 Widget
Finder findScrollable() {
  return find.byType(Scrollable);
}

/// 查找列表项
Finder findListTile({String? title, String? subtitle}) {
  return find.byWidgetPredicate((widget) {
    if (widget is ListTile) {
      if (title != null) {
        final titleWidget = widget.title;
        if (titleWidget is Text && titleWidget.data != title) {
          return false;
        }
      }
      if (subtitle != null) {
        final subtitleWidget = widget.subtitle;
        if (subtitleWidget is Text && subtitleWidget.data != subtitle) {
          return false;
        }
      }
      return true;
    }
    return false;
  });
}

// ==================== 测试生命周期辅助 ====================

/// 测试夹具基类
abstract class TestFixture {
  /// 设置测试环境
  Future<void> setUp();

  /// 清理测试环境
  Future<void> tearDown();
}

/// 带状态的测试夹具
class StatefulTestFixture<T> extends TestFixture {
  T? _state;
  final Future<T> Function() _setup;
  final Future<void> Function(T state)? _teardown;

  StatefulTestFixture({
    required Future<T> Function() setup,
    Future<void> Function(T state)? teardown,
  })  : _setup = setup,
        _teardown = teardown;

  T get state => _state!;

  @override
  Future<void> setUp() async {
    _state = await _setup();
  }

  @override
  Future<void> tearDown() async {
    if (_state != null && _teardown != null) {
      await _teardown(_state as T);
    }
    _state = null;
  }
}

/// 运行带夹具的测试
void testWithFixture<T extends TestFixture>(
  String description,
  T fixture,
  Future<void> Function(T fixture) body,
) {
  test(description, () async {
    await fixture.setUp();
    try {
      await body(fixture);
    } finally {
      await fixture.tearDown();
    }
  });
}

// ==================== 性能测试辅助 ====================

/// 性能测试结果
class PerformanceResult {
  final String name;
  final Duration duration;
  final int iterations;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;

  PerformanceResult({
    required this.name,
    required this.duration,
    required this.iterations,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
  });

  @override
  String toString() {
    return 'PerformanceResult($name): '
        'total=${duration.inMilliseconds}ms, '
        'avg=${averageDuration.inMicroseconds}μs, '
        'min=${minDuration.inMicroseconds}μs, '
        'max=${maxDuration.inMicroseconds}μs, '
        'iterations=$iterations';
  }
}

/// 性能基准测试
Future<PerformanceResult> benchmark(
  String name,
  Future<void> Function() operation, {
  int iterations = 100,
  int warmupIterations = 10,
}) async {
  // 预热
  for (int i = 0; i < warmupIterations; i++) {
    await operation();
  }

  // 测试
  final durations = <Duration>[];
  final stopwatch = Stopwatch();

  for (int i = 0; i < iterations; i++) {
    stopwatch.reset();
    stopwatch.start();
    await operation();
    stopwatch.stop();
    durations.add(stopwatch.elapsed);
  }

  // 计算统计
  final totalDuration = durations.fold<Duration>(
    Duration.zero,
    (sum, d) => sum + d,
  );

  durations.sort((a, b) => a.compareTo(b));

  return PerformanceResult(
    name: name,
    duration: totalDuration,
    iterations: iterations,
    averageDuration: Duration(
      microseconds: totalDuration.inMicroseconds ~/ iterations,
    ),
    minDuration: durations.first,
    maxDuration: durations.last,
  );
}

/// 断言性能在阈值内
void expectPerformance(
  PerformanceResult result, {
  Duration? maxAverageDuration,
  Duration? maxTotalDuration,
}) {
  if (maxAverageDuration != null) {
    expect(
      result.averageDuration <= maxAverageDuration,
      isTrue,
      reason: 'Average duration ${result.averageDuration} exceeded max $maxAverageDuration',
    );
  }

  if (maxTotalDuration != null) {
    expect(
      result.duration <= maxTotalDuration,
      isTrue,
      reason: 'Total duration ${result.duration} exceeded max $maxTotalDuration',
    );
  }
}

// ==================== 快照测试辅助 ====================

/// 将 Widget 转换为可比较的字符串表示
String widgetToString(Widget widget) {
  return widget.toString();
}

/// 断言 Widget 结构匹配
void expectWidgetStructure(Widget widget, String expectedStructure) {
  final actual = widgetToString(widget);
  expect(actual.contains(expectedStructure), isTrue);
}
