import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/privacy/differential_privacy/privacy_budget_manager.dart';
import 'package:ai_bookkeeping/services/privacy/models/privacy_budget.dart';
import 'package:ai_bookkeeping/services/privacy/models/sensitivity_level.dart';

void main() {
  group('PrivacyBudgetManager', () {
    late PrivacyBudgetManager manager;

    setUp(() {
      manager = PrivacyBudgetManager(
        config: const PrivacyBudgetConfig(
          totalBudgetLimit: 10.0,
          highSensitivityEpsilon: 0.1,
          mediumSensitivityEpsilon: 0.5,
          lowSensitivityEpsilon: 1.0,
        ),
      );
    });

    tearDown(() {
      manager.dispose();
    });

    group('初始状态', () {
      test('初始时预算不应耗尽', () {
        expect(manager.isExhausted, isFalse);
      });

      test('初始时剩余预算应为100%', () {
        expect(manager.remainingBudgetPercent, equals(100.0));
      });

      test('初始时剩余预算应等于总预算', () {
        expect(manager.remainingBudget, equals(10.0));
      });
    });

    group('getEpsilon', () {
      test('应返回高敏感度的epsilon值', () {
        expect(
          manager.getEpsilon(SensitivityLevel.high),
          equals(0.1),
        );
      });

      test('应返回中敏感度的epsilon值', () {
        expect(
          manager.getEpsilon(SensitivityLevel.medium),
          equals(0.5),
        );
      });

      test('应返回低敏感度的epsilon值', () {
        expect(
          manager.getEpsilon(SensitivityLevel.low),
          equals(1.0),
        );
      });
    });

    group('canConsume', () {
      test('预算充足时应返回true', () {
        expect(manager.canConsume(5.0), isTrue);
      });

      test('预算不足时应返回false', () {
        expect(manager.canConsume(15.0), isFalse);
      });

      test('刚好等于剩余预算时应返回true', () {
        expect(manager.canConsume(10.0), isTrue);
      });
    });

    group('consume', () {
      test('成功消耗预算时应返回true', () async {
        final result = await manager.consume(
          epsilon: 1.0,
          level: SensitivityLevel.medium,
          operation: '测试操作',
        );

        expect(result, isTrue);
        expect(manager.remainingBudget, equals(9.0));
      });

      test('应正确记录消耗历史', () async {
        await manager.consume(
          epsilon: 1.0,
          level: SensitivityLevel.medium,
          operation: '测试操作',
        );

        expect(manager.consumptionHistory.length, equals(1));
        expect(manager.consumptionHistory.first.epsilon, equals(1.0));
        expect(
            manager.consumptionHistory.first.level, equals(SensitivityLevel.medium));
      });

      test('预算不足时应返回false', () async {
        // 先消耗大部分预算
        await manager.consume(
          epsilon: 9.5,
          level: SensitivityLevel.low,
          operation: '大量消耗',
        );

        final result = await manager.consume(
          epsilon: 1.0,
          level: SensitivityLevel.medium,
          operation: '超出预算的操作',
        );

        expect(result, isFalse);
      });

      test('消耗后应更新各级别统计', () async {
        await manager.consume(
          epsilon: 0.1,
          level: SensitivityLevel.high,
          operation: '高敏感操作',
        );
        await manager.consume(
          epsilon: 0.5,
          level: SensitivityLevel.medium,
          operation: '中敏感操作',
        );

        final stats = manager.getLevelStats();
        expect(stats[SensitivityLevel.high]!.consumed, equals(0.1));
        expect(stats[SensitivityLevel.medium]!.consumed, equals(0.5));
      });

      test('预算耗尽后应标记为耗尽状态', () async {
        await manager.consume(
          epsilon: 10.0,
          level: SensitivityLevel.low,
          operation: '消耗全部预算',
        );

        expect(manager.isExhausted, isTrue);
      });

      test('预算耗尽后应拒绝新的消耗请求', () async {
        await manager.consume(
          epsilon: 10.0,
          level: SensitivityLevel.low,
          operation: '消耗全部预算',
        );

        final result = await manager.consume(
          epsilon: 0.1,
          level: SensitivityLevel.high,
          operation: '新操作',
        );

        expect(result, isFalse);
      });
    });

    group('consumeBatch', () {
      test('应正确计算批量消耗', () async {
        final result = await manager.consumeBatch(
          count: 10,
          epsilonPerItem: 0.5,
          level: SensitivityLevel.medium,
          operation: '批量操作',
        );

        expect(result, isTrue);
        expect(manager.remainingBudget, equals(5.0));
      });
    });

    group('reset', () {
      test('应重置预算状态', () async {
        await manager.consume(
          epsilon: 5.0,
          level: SensitivityLevel.low,
          operation: '消耗部分预算',
        );

        await manager.reset();

        expect(manager.isExhausted, isFalse);
        expect(manager.remainingBudget, equals(10.0));
        expect(manager.consumptionHistory, isEmpty);
      });
    });

    group('耗尽回调', () {
      test('预算耗尽时应触发回调', () async {
        var callbackCalled = false;
        manager.addExhaustionListener(() {
          callbackCalled = true;
        });

        await manager.consume(
          epsilon: 10.0,
          level: SensitivityLevel.low,
          operation: '消耗全部预算',
        );

        expect(callbackCalled, isTrue);
      });

      test('移除回调后不应再触发', () async {
        var callbackCalled = false;
        void callback() {
          callbackCalled = true;
        }

        manager.addExhaustionListener(callback);
        manager.removeExhaustionListener(callback);

        await manager.consume(
          epsilon: 10.0,
          level: SensitivityLevel.low,
          operation: '消耗全部预算',
        );

        expect(callbackCalled, isFalse);
      });
    });

    group('getLevelStats', () {
      test('应返回所有级别的统计信息', () async {
        await manager.consume(
          epsilon: 0.1,
          level: SensitivityLevel.high,
          operation: '高敏感操作1',
        );
        await manager.consume(
          epsilon: 0.1,
          level: SensitivityLevel.high,
          operation: '高敏感操作2',
        );

        final stats = manager.getLevelStats();

        expect(stats.length, equals(3));
        expect(stats[SensitivityLevel.high]!.operationCount, equals(2));
        expect(stats[SensitivityLevel.high]!.consumed, equals(0.2));
      });
    });
  });

  group('PrivacyBudgetConfig', () {
    test('默认配置应有正确的值', () {
      const config = PrivacyBudgetConfig.defaultConfig;

      expect(config.highSensitivityEpsilon, equals(0.1));
      expect(config.mediumSensitivityEpsilon, equals(0.5));
      expect(config.lowSensitivityEpsilon, equals(1.0));
      expect(config.totalBudgetLimit, equals(10.0));
    });

    test('copyWith 应正确创建副本', () {
      const config = PrivacyBudgetConfig.defaultConfig;
      final newConfig = config.copyWith(totalBudgetLimit: 20.0);

      expect(newConfig.totalBudgetLimit, equals(20.0));
      expect(newConfig.highSensitivityEpsilon, equals(0.1));
    });

    test('toJson 和 fromJson 应正确序列化', () {
      const config = PrivacyBudgetConfig(
        highSensitivityEpsilon: 0.2,
        totalBudgetLimit: 15.0,
      );

      final json = config.toJson();
      final restored = PrivacyBudgetConfig.fromJson(json);

      expect(restored.highSensitivityEpsilon, equals(0.2));
      expect(restored.totalBudgetLimit, equals(15.0));
    });
  });

  group('PrivacyBudgetState', () {
    test('initial 应创建初始状态', () {
      final state = PrivacyBudgetState.initial();

      expect(state.totalConsumed, equals(0.0));
      expect(state.isExhausted, isFalse);
    });

    test('reset 应重置状态', () {
      final state = PrivacyBudgetState(
        highSensitivityConsumed: 1.0,
        mediumSensitivityConsumed: 2.0,
        lowSensitivityConsumed: 3.0,
        lastResetTime: DateTime.now().subtract(const Duration(days: 1)),
        isExhausted: true,
      );

      final resetState = state.reset();

      expect(resetState.totalConsumed, equals(0.0));
      expect(resetState.isExhausted, isFalse);
    });
  });
}
