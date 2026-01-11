import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/budget/budget_suggestion.dart';

void main() {
  group('BudgetSuggestionSource', () {
    test('应包含所有预期的来源类型', () {
      expect(BudgetSuggestionSource.values.length, 5);
      expect(BudgetSuggestionSource.values, contains(BudgetSuggestionSource.adaptive));
      expect(BudgetSuggestionSource.values, contains(BudgetSuggestionSource.smart));
      expect(BudgetSuggestionSource.values, contains(BudgetSuggestionSource.localized));
      expect(BudgetSuggestionSource.values, contains(BudgetSuggestionSource.location));
      expect(BudgetSuggestionSource.values, contains(BudgetSuggestionSource.custom));
    });
  });

  group('BudgetSuggestion', () {
    final testDate = DateTime(2024, 6, 15, 10, 30);

    group('构造函数', () {
      test('应正确创建预算建议', () {
        final suggestion = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 3000.0,
          reason: '基于历史消费',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.85,
          createdAt: testDate,
        );

        expect(suggestion.categoryId, 'food');
        expect(suggestion.suggestedAmount, 3000.0);
        expect(suggestion.reason, '基于历史消费');
        expect(suggestion.source, BudgetSuggestionSource.adaptive);
        expect(suggestion.confidence, 0.85);
        expect(suggestion.metadata, isNull);
        expect(suggestion.createdAt, testDate);
      });

      test('应支持元数据', () {
        final suggestion = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 3000.0,
          reason: '基于位置',
          source: BudgetSuggestionSource.location,
          confidence: 0.75,
          metadata: {'city': '北京', 'district': '朝阳'},
          createdAt: testDate,
        );

        expect(suggestion.metadata, {'city': '北京', 'district': '朝阳'});
      });
    });

    group('BudgetSuggestion.now 工厂方法', () {
      test('应使用当前时间创建建议', () {
        final before = DateTime.now();

        final suggestion = BudgetSuggestion.now(
          categoryId: 'transport',
          suggestedAmount: 500.0,
          reason: '智能推荐',
          source: BudgetSuggestionSource.smart,
          confidence: 0.9,
        );

        final after = DateTime.now();

        expect(suggestion.createdAt.isAfter(before) || suggestion.createdAt.isAtSameMomentAs(before), isTrue);
        expect(suggestion.createdAt.isBefore(after) || suggestion.createdAt.isAtSameMomentAs(after), isTrue);
      });
    });

    group('fromJson', () {
      test('应正确从 JSON 创建', () {
        final json = {
          'categoryId': 'entertainment',
          'suggestedAmount': 1000.5,
          'reason': '测试原因',
          'source': 'smart',
          'confidence': 0.8,
          'createdAt': '2024-06-15T10:30:00.000',
        };

        final suggestion = BudgetSuggestion.fromJson(json);

        expect(suggestion.categoryId, 'entertainment');
        expect(suggestion.suggestedAmount, 1000.5);
        expect(suggestion.reason, '测试原因');
        expect(suggestion.source, BudgetSuggestionSource.smart);
        expect(suggestion.confidence, 0.8);
        expect(suggestion.createdAt, DateTime(2024, 6, 15, 10, 30));
      });

      test('应处理带元数据的 JSON', () {
        final json = {
          'categoryId': 'food',
          'suggestedAmount': 2000,
          'reason': '测试',
          'source': 'adaptive',
          'confidence': 0.7,
          'metadata': {'key': 'value'},
          'createdAt': '2024-06-15T10:30:00.000',
        };

        final suggestion = BudgetSuggestion.fromJson(json);
        expect(suggestion.metadata, {'key': 'value'});
      });

      test('未知来源应回退到 custom', () {
        final json = {
          'categoryId': 'food',
          'suggestedAmount': 2000,
          'reason': '测试',
          'source': 'unknown_source',
          'confidence': 0.7,
          'createdAt': '2024-06-15T10:30:00.000',
        };

        final suggestion = BudgetSuggestion.fromJson(json);
        expect(suggestion.source, BudgetSuggestionSource.custom);
      });
    });

    group('toJson', () {
      test('应正确转换为 JSON', () {
        final suggestion = BudgetSuggestion(
          categoryId: 'shopping',
          suggestedAmount: 1500.0,
          reason: '购物建议',
          source: BudgetSuggestionSource.localized,
          confidence: 0.65,
          createdAt: testDate,
        );

        final json = suggestion.toJson();

        expect(json['categoryId'], 'shopping');
        expect(json['suggestedAmount'], 1500.0);
        expect(json['reason'], '购物建议');
        expect(json['source'], 'localized');
        expect(json['confidence'], 0.65);
        expect(json['createdAt'], '2024-06-15T10:30:00.000');
        expect(json.containsKey('metadata'), isFalse);
      });

      test('有元数据时应包含在 JSON 中', () {
        final suggestion = BudgetSuggestion(
          categoryId: 'shopping',
          suggestedAmount: 1500.0,
          reason: '购物建议',
          source: BudgetSuggestionSource.localized,
          confidence: 0.65,
          metadata: {'region': 'asia'},
          createdAt: testDate,
        );

        final json = suggestion.toJson();
        expect(json['metadata'], {'region': 'asia'});
      });
    });

    group('copyWith', () {
      late BudgetSuggestion original;

      setUp(() {
        original = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '原始原因',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          metadata: {'key': 'value'},
          createdAt: testDate,
        );
      });

      test('不传参数应返回相同值', () {
        final copy = original.copyWith();

        expect(copy.categoryId, original.categoryId);
        expect(copy.suggestedAmount, original.suggestedAmount);
        expect(copy.reason, original.reason);
        expect(copy.source, original.source);
        expect(copy.confidence, original.confidence);
        expect(copy.metadata, original.metadata);
        expect(copy.createdAt, original.createdAt);
      });

      test('应正确覆盖 categoryId', () {
        final copy = original.copyWith(categoryId: 'transport');
        expect(copy.categoryId, 'transport');
        expect(copy.suggestedAmount, original.suggestedAmount);
      });

      test('应正确覆盖 suggestedAmount', () {
        final copy = original.copyWith(suggestedAmount: 5000.0);
        expect(copy.suggestedAmount, 5000.0);
      });

      test('应正确覆盖 reason', () {
        final copy = original.copyWith(reason: '新原因');
        expect(copy.reason, '新原因');
      });

      test('应正确覆盖 source', () {
        final copy = original.copyWith(source: BudgetSuggestionSource.smart);
        expect(copy.source, BudgetSuggestionSource.smart);
      });

      test('应正确覆盖 confidence', () {
        final copy = original.copyWith(confidence: 0.95);
        expect(copy.confidence, 0.95);
      });

      test('应正确覆盖 metadata', () {
        final copy = original.copyWith(metadata: {'newKey': 'newValue'});
        expect(copy.metadata, {'newKey': 'newValue'});
      });

      test('应正确覆盖 createdAt', () {
        final newDate = DateTime(2025, 1, 1);
        final copy = original.copyWith(createdAt: newDate);
        expect(copy.createdAt, newDate);
      });
    });

    group('toString', () {
      test('应返回可读的字符串', () {
        final suggestion = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        final str = suggestion.toString();

        expect(str, contains('food'));
        expect(str, contains('2000.0'));
        expect(str, contains('adaptive'));
        expect(str, contains('0.8'));
      });
    });

    group('相等性', () {
      test('相同属性应相等', () {
        final s1 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        final s2 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '不同原因',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.9,
          createdAt: DateTime(2025, 1, 1),
        );

        expect(s1, equals(s2));
      });

      test('不同 categoryId 应不相等', () {
        final s1 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        final s2 = BudgetSuggestion(
          categoryId: 'transport',
          suggestedAmount: 2000.0,
          reason: '测试',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        expect(s1, isNot(equals(s2)));
      });

      test('不同 suggestedAmount 应不相等', () {
        final s1 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        final s2 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 3000.0,
          reason: '测试',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        expect(s1, isNot(equals(s2)));
      });

      test('不同 source 应不相等', () {
        final s1 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        final s2 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试',
          source: BudgetSuggestionSource.smart,
          confidence: 0.8,
          createdAt: testDate,
        );

        expect(s1, isNot(equals(s2)));
      });
    });

    group('hashCode', () {
      test('相等对象应有相同 hashCode', () {
        final s1 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试1',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.8,
          createdAt: testDate,
        );

        final s2 = BudgetSuggestion(
          categoryId: 'food',
          suggestedAmount: 2000.0,
          reason: '测试2',
          source: BudgetSuggestionSource.adaptive,
          confidence: 0.9,
          createdAt: DateTime(2025, 1, 1),
        );

        expect(s1.hashCode, equals(s2.hashCode));
      });
    });
  });

  group('BudgetSuggestionStrategy', () {
    test('应能实现策略接口', () {
      final strategy = TestBudgetStrategy();

      expect(strategy.name, '测试策略');
      expect(strategy.sourceType, BudgetSuggestionSource.custom);
    });

    test('getSuggestions 应返回建议列表', () async {
      final strategy = TestBudgetStrategy();
      final suggestions = await strategy.getSuggestions();

      expect(suggestions, isNotEmpty);
      expect(suggestions.first.source, BudgetSuggestionSource.custom);
    });

    test('isAvailable 应返回可用状态', () async {
      final strategy = TestBudgetStrategy();
      expect(await strategy.isAvailable(), isTrue);
    });
  });
}

/// 测试用策略实现
class TestBudgetStrategy implements BudgetSuggestionStrategy {
  @override
  String get name => '测试策略';

  @override
  BudgetSuggestionSource get sourceType => BudgetSuggestionSource.custom;

  @override
  Future<List<BudgetSuggestion>> getSuggestions({
    List<String>? categoryIds,
    Map<String, dynamic>? context,
  }) async {
    return [
      BudgetSuggestion.now(
        categoryId: 'test',
        suggestedAmount: 1000.0,
        reason: '测试建议',
        source: BudgetSuggestionSource.custom,
        confidence: 0.9,
      ),
    ];
  }

  @override
  Future<bool> isAvailable() async => true;
}
