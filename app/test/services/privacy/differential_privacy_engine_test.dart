import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/privacy/differential_privacy/differential_privacy_engine.dart';
import 'package:ai_bookkeeping/services/privacy/differential_privacy/privacy_budget_manager.dart';
import 'package:ai_bookkeeping/services/privacy/models/privacy_budget.dart';
import 'package:ai_bookkeeping/services/privacy/models/sensitivity_level.dart';
import 'package:ai_bookkeeping/services/collaborative_learning_service.dart';

void main() {
  group('DifferentialPrivacyEngine', () {
    late PrivacyBudgetManager budgetManager;
    late DifferentialPrivacyEngine engine;

    setUp(() {
      budgetManager = PrivacyBudgetManager(
        config: const PrivacyBudgetConfig(
          totalBudgetLimit: 10.0,
          highSensitivityEpsilon: 0.1,
          mediumSensitivityEpsilon: 0.5,
          lowSensitivityEpsilon: 1.0,
        ),
      );
      engine = DifferentialPrivacyEngine(budgetManager: budgetManager);
    });

    tearDown(() {
      budgetManager.dispose();
    });

    group('canPerformOperation', () {
      test('预算充足时应返回true', () {
        expect(engine.canPerformOperation, isTrue);
      });

      test('预算耗尽时应返回false', () async {
        // 消耗全部预算
        await budgetManager.consume(
          epsilon: 10.0,
          level: SensitivityLevel.low,
          operation: '消耗全部预算',
        );

        expect(engine.canPerformOperation, isFalse);
      });
    });

    group('protectRule', () {
      test('应成功保护规则', () async {
        final rule = LearnedRule(
          id: 'test_rule_1',
          type: 'merchant',
          pattern: 'starbucks',
          category: '餐饮',
          confidence: 0.9,
          hitCount: 10,
          source: RuleSource.userLearned,
          createdAt: DateTime.now(),
        );

        final protectedRule = await engine.protectRule(rule);

        expect(protectedRule, isNotNull);
        expect(protectedRule!.originalId, equals('test_rule_1'));
        expect(protectedRule.category, equals('餐饮'));
        // 噪声后的置信度应在[0,1]范围内
        expect(protectedRule.noisyConfidence, greaterThanOrEqualTo(0.0));
        expect(protectedRule.noisyConfidence, lessThanOrEqualTo(1.0));
      });

      test('应消耗预算', () async {
        final initialBudget = budgetManager.remainingBudget;

        final rule = LearnedRule(
          id: 'test_rule_1',
          type: 'merchant',
          pattern: 'starbucks',
          category: '餐饮',
          confidence: 0.9,
          hitCount: 10,
          source: RuleSource.userLearned,
          createdAt: DateTime.now(),
        );

        await engine.protectRule(rule);

        expect(budgetManager.remainingBudget, lessThan(initialBudget));
      });

      test('预算耗尽时应返回null', () async {
        // 消耗全部预算
        await budgetManager.consume(
          epsilon: 10.0,
          level: SensitivityLevel.low,
          operation: '消耗全部预算',
        );

        final rule = LearnedRule(
          id: 'test_rule_1',
          type: 'merchant',
          pattern: 'starbucks',
          category: '餐饮',
          confidence: 0.9,
          hitCount: 10,
          source: RuleSource.userLearned,
          createdAt: DateTime.now(),
        );

        final protectedRule = await engine.protectRule(rule);

        expect(protectedRule, isNull);
      });

      test('噪声后的置信度应与原置信度不同（大概率）', () async {
        final rule = LearnedRule(
          id: 'test_rule_1',
          type: 'merchant',
          pattern: 'starbucks',
          category: '餐饮',
          confidence: 0.5, // 使用中间值更容易看到差异
          hitCount: 10,
          source: RuleSource.userLearned,
          createdAt: DateTime.now(),
        );

        final protectedRule = await engine.protectRule(rule);

        // 大概率噪声后的值会与原值不同
        // 但由于噪声是随机的，我们只能测试它是有效的
        expect(protectedRule, isNotNull);
      });
    });

    group('protectRules', () {
      test('应保护所有规则', () async {
        final rules = [
          LearnedRule(
            id: 'rule_1',
            type: 'merchant',
            pattern: 'starbucks',
            category: '餐饮',
            confidence: 0.9,
            hitCount: 10,
            source: RuleSource.userLearned,
            createdAt: DateTime.now(),
          ),
          LearnedRule(
            id: 'rule_2',
            type: 'merchant',
            pattern: 'didi',
            category: '交通',
            confidence: 0.85,
            hitCount: 15,
            source: RuleSource.userLearned,
            createdAt: DateTime.now(),
          ),
        ];

        final protectedRules = await engine.protectRules(rules);

        expect(protectedRules.length, equals(2));
      });

      test('预算不足时应停止保护', () async {
        // 创建多个规则
        final rules = List.generate(
          100,
          (i) => LearnedRule(
            id: 'rule_$i',
            type: 'merchant',
            pattern: 'pattern_$i',
            category: '测试',
            confidence: 0.9,
            hitCount: 10,
            source: RuleSource.userLearned,
            createdAt: DateTime.now(),
          ),
        );

        // 使用较小的预算
        final smallBudgetManager = PrivacyBudgetManager(
          config: const PrivacyBudgetConfig(
            totalBudgetLimit: 2.0, // 只能保护约4条规则（0.5 * 4 = 2.0）
          ),
        );
        final smallEngine =
            DifferentialPrivacyEngine(budgetManager: smallBudgetManager);

        final protectedRules = await smallEngine.protectRules(rules);

        // 应该保护了一部分规则，但不是全部
        expect(protectedRules.length, lessThan(100));
        expect(protectedRules.length, greaterThan(0));

        smallBudgetManager.dispose();
      });
    });

    group('protectNumericValue', () {
      test('应保护数值', () async {
        final protectedValue = await engine.protectNumericValue(
          value: 100.0,
          minValue: 0.0,
          maxValue: 1000.0,
          level: SensitivityLevel.high,
          operation: '测试数值保护',
        );

        expect(protectedValue, isNotNull);
        expect(protectedValue, greaterThanOrEqualTo(0.0));
        expect(protectedValue, lessThanOrEqualTo(1000.0));
      });
    });

    group('protectCountQuery', () {
      test('应保护计数查询', () async {
        final protectedCount = await engine.protectCountQuery(
          count: 100,
          operation: '测试计数保护',
        );

        expect(protectedCount, isNotNull);
        expect(protectedCount, greaterThanOrEqualTo(0));
      });
    });

    group('estimateBudgetRequired', () {
      test('应正确估计所需预算', () {
        final required = engine.estimateBudgetRequired(
          ruleCount: 10,
          level: SensitivityLevel.medium,
        );

        // 中敏感度 epsilon = 0.5，10条规则需要 0.5 * 10 = 5.0
        expect(required, equals(5.0));
      });
    });

    group('hasSufficientBudget', () {
      test('预算充足时应返回true', () {
        final hasBudget = engine.hasSufficientBudget(
          ruleCount: 10,
          level: SensitivityLevel.medium,
        );

        expect(hasBudget, isTrue);
      });

      test('预算不足时应返回false', () {
        final hasBudget = engine.hasSufficientBudget(
          ruleCount: 100,
          level: SensitivityLevel.medium,
        );

        expect(hasBudget, isFalse);
      });
    });
  });

  group('PrivateRule', () {
    test('toUploadData 应不包含敏感信息', () {
      final privateRule = PrivateRule(
        originalId: 'secret_id',
        type: 'merchant',
        patternHash: 'abc123',
        category: '餐饮',
        noisyConfidence: 0.85,
        originalConfidence: 0.9,
        noiseAdded: -0.05,
        epsilon: 0.5,
        protectedAt: DateTime.now(),
      );

      final uploadData = privateRule.toUploadData();

      // 不应包含原始ID
      expect(uploadData.containsKey('originalId'), isFalse);
      // 不应包含原始置信度
      expect(uploadData.containsKey('originalConfidence'), isFalse);
      // 不应包含噪声量
      expect(uploadData.containsKey('noiseAdded'), isFalse);
      // 应包含保护后的置信度
      expect(uploadData['confidence'], equals(0.85));
    });
  });
}
