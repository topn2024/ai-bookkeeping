import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/budget/budget_suggestion.dart';
import 'package:ai_bookkeeping/services/budget/budget_suggestion_engine.dart';

void main() {
  group('BudgetSuggestionEngine', () {
    late BudgetSuggestionEngine engine;

    setUp(() {
      engine = BudgetSuggestionEngine([]);
    });

    group('构造函数', () {
      test('应接受空策略列表', () {
        final engine = BudgetSuggestionEngine([]);
        expect(engine.strategies, isEmpty);
      });

      test('应接受多个策略', () {
        final engine = BudgetSuggestionEngine([
          MockStrategy(BudgetSuggestionSource.adaptive),
          MockStrategy(BudgetSuggestionSource.smart),
        ]);
        expect(engine.strategies.length, 2);
      });

      test('应允许自定义优先级权重', () {
        final customWeights = {
          BudgetSuggestionSource.adaptive: 0.5,
          BudgetSuggestionSource.smart: 1.0,
        };

        final engine = BudgetSuggestionEngine(
          [],
          priorityWeights: customWeights,
        );

        expect(engine, isNotNull);
      });
    });

    group('strategies', () {
      test('应返回不可修改的策略列表', () {
        final engine = BudgetSuggestionEngine([
          MockStrategy(BudgetSuggestionSource.adaptive),
        ]);

        expect(() => engine.strategies.add(MockStrategy(BudgetSuggestionSource.smart)),
            throwsUnsupportedError);
      });
    });

    group('addStrategy', () {
      test('应添加新策略', () {
        engine.addStrategy(MockStrategy(BudgetSuggestionSource.adaptive));
        expect(engine.strategies.length, 1);
      });

      test('应允许添加多个策略', () {
        engine.addStrategy(MockStrategy(BudgetSuggestionSource.adaptive));
        engine.addStrategy(MockStrategy(BudgetSuggestionSource.smart));
        expect(engine.strategies.length, 2);
      });
    });

    group('removeStrategy', () {
      test('应移除指定来源的策略', () {
        engine.addStrategy(MockStrategy(BudgetSuggestionSource.adaptive));
        engine.addStrategy(MockStrategy(BudgetSuggestionSource.smart));

        engine.removeStrategy(BudgetSuggestionSource.adaptive);
        expect(engine.strategies.length, 1);
        expect(engine.strategies.first.sourceType, BudgetSuggestionSource.smart);
      });

      test('移除不存在的策略不应抛出异常', () {
        expect(() => engine.removeStrategy(BudgetSuggestionSource.adaptive), returnsNormally);
      });
    });

    group('isStrategyAvailable', () {
      test('不存在的策略应返回 false', () async {
        final result = await engine.isStrategyAvailable(BudgetSuggestionSource.adaptive);
        expect(result, isFalse);
      });

      test('可用策略应返回 true', () async {
        engine.addStrategy(MockStrategy(BudgetSuggestionSource.adaptive, isAvailable: true));
        final result = await engine.isStrategyAvailable(BudgetSuggestionSource.adaptive);
        expect(result, isTrue);
      });

      test('不可用策略应返回 false', () async {
        engine.addStrategy(MockStrategy(BudgetSuggestionSource.adaptive, isAvailable: false));
        final result = await engine.isStrategyAvailable(BudgetSuggestionSource.adaptive);
        expect(result, isFalse);
      });
    });

    group('getSuggestions', () {
      test('无策略时应返回空列表', () async {
        final result = await engine.getSuggestions();
        expect(result, isEmpty);
      });

      test('应聚合所有策略的建议', () async {
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          suggestions: [
            _createSuggestion('food', 1000, BudgetSuggestionSource.adaptive),
          ],
        ));
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.smart,
          suggestions: [
            _createSuggestion('transport', 500, BudgetSuggestionSource.smart),
          ],
        ));

        final result = await engine.getSuggestions();
        expect(result.length, 2);
      });

      test('不可用策略应被跳过', () async {
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          isAvailable: false,
          suggestions: [
            _createSuggestion('food', 1000, BudgetSuggestionSource.adaptive),
          ],
        ));
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.smart,
          isAvailable: true,
          suggestions: [
            _createSuggestion('transport', 500, BudgetSuggestionSource.smart),
          ],
        ));

        final result = await engine.getSuggestions();
        expect(result.length, 1);
        expect(result.first.categoryId, 'transport');
      });

      test('策略执行失败应被忽略', () async {
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          shouldThrow: true,
        ));
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.smart,
          suggestions: [
            _createSuggestion('food', 1000, BudgetSuggestionSource.smart),
          ],
        ));

        final result = await engine.getSuggestions();
        expect(result.length, 1);
      });

      test('应按分类 ID 排序', () async {
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          suggestions: [
            _createSuggestion('transport', 500, BudgetSuggestionSource.adaptive),
            _createSuggestion('food', 1000, BudgetSuggestionSource.adaptive),
            _createSuggestion('entertainment', 800, BudgetSuggestionSource.adaptive),
          ],
        ));

        final result = await engine.getSuggestions();
        expect(result[0].categoryId, 'entertainment');
        expect(result[1].categoryId, 'food');
        expect(result[2].categoryId, 'transport');
      });

      test('应传递 categoryIds 参数', () async {
        List<String>? receivedCategoryIds;
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          onGetSuggestions: ({categoryIds, context}) {
            receivedCategoryIds = categoryIds;
          },
        ));

        await engine.getSuggestions(categoryIds: ['food', 'transport']);
        expect(receivedCategoryIds, ['food', 'transport']);
      });

      test('应传递 context 参数', () async {
        Map<String, dynamic>? receivedContext;
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          onGetSuggestions: ({categoryIds, context}) {
            receivedContext = context;
          },
        ));

        await engine.getSuggestions(context: {'key': 'value'});
        expect(receivedContext, {'key': 'value'});
      });
    });

    group('_mergeSuggestions', () {
      test('同一分类应合并，选择置信度高的', () async {
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          suggestions: [
            _createSuggestion('food', 1000, BudgetSuggestionSource.adaptive, confidence: 0.8),
          ],
        ));
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.smart,
          suggestions: [
            _createSuggestion('food', 1500, BudgetSuggestionSource.smart, confidence: 0.9),
          ],
        ));

        final result = await engine.getSuggestions();
        expect(result.length, 1);
        // smart 策略权重 0.9 * 0.9 = 0.81 > adaptive 权重 1.0 * 0.8 = 0.8
        expect(result.first.suggestedAmount, 1500);
      });

      test('优先级权重应影响合并结果', () async {
        final customEngine = BudgetSuggestionEngine(
          [
            MockStrategy(
              BudgetSuggestionSource.adaptive,
              suggestions: [
                _createSuggestion('food', 1000, BudgetSuggestionSource.adaptive, confidence: 0.7),
              ],
            ),
            MockStrategy(
              BudgetSuggestionSource.smart,
              suggestions: [
                _createSuggestion('food', 1500, BudgetSuggestionSource.smart, confidence: 0.9),
              ],
            ),
          ],
          priorityWeights: {
            BudgetSuggestionSource.adaptive: 2.0, // 提高 adaptive 权重
            BudgetSuggestionSource.smart: 0.5,
          },
        );

        final result = await customEngine.getSuggestions();
        expect(result.length, 1);
        // adaptive: 0.7 * 2.0 = 1.4 > smart: 0.9 * 0.5 = 0.45
        expect(result.first.suggestedAmount, 1000);
      });
    });

    group('getSuggestionsFromStrategy', () {
      test('应返回指定策略的建议', () async {
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.adaptive,
          suggestions: [
            _createSuggestion('food', 1000, BudgetSuggestionSource.adaptive),
          ],
        ));
        engine.addStrategy(MockStrategy(
          BudgetSuggestionSource.smart,
          suggestions: [
            _createSuggestion('transport', 500, BudgetSuggestionSource.smart),
          ],
        ));

        final result = await engine.getSuggestionsFromStrategy(
          BudgetSuggestionSource.adaptive,
        );

        expect(result.length, 1);
        expect(result.first.categoryId, 'food');
      });

      test('策略不存在应抛出异常', () async {
        expect(
          () => engine.getSuggestionsFromStrategy(BudgetSuggestionSource.adaptive),
          throwsArgumentError,
        );
      });
    });
  });
}

BudgetSuggestion _createSuggestion(
  String categoryId,
  double amount,
  BudgetSuggestionSource source, {
  double confidence = 0.8,
}) {
  return BudgetSuggestion.now(
    categoryId: categoryId,
    suggestedAmount: amount,
    reason: '测试建议',
    source: source,
    confidence: confidence,
  );
}

/// Mock 策略实现
class MockStrategy implements BudgetSuggestionStrategy {
  final BudgetSuggestionSource _sourceType;
  final bool _isAvailable;
  final List<BudgetSuggestion> _suggestions;
  final bool _shouldThrow;
  final void Function({List<String>? categoryIds, Map<String, dynamic>? context})? onGetSuggestions;

  MockStrategy(
    this._sourceType, {
    bool isAvailable = true,
    List<BudgetSuggestion>? suggestions,
    bool shouldThrow = false,
    this.onGetSuggestions,
  })  : _isAvailable = isAvailable,
        _suggestions = suggestions ?? [],
        _shouldThrow = shouldThrow;

  @override
  String get name => 'Mock ${_sourceType.name}';

  @override
  BudgetSuggestionSource get sourceType => _sourceType;

  @override
  Future<List<BudgetSuggestion>> getSuggestions({
    List<String>? categoryIds,
    Map<String, dynamic>? context,
  }) async {
    onGetSuggestions?.call(categoryIds: categoryIds, context: context);
    if (_shouldThrow) {
      throw Exception('测试异常');
    }
    return _suggestions;
  }

  @override
  Future<bool> isAvailable() async => _isAvailable;
}
