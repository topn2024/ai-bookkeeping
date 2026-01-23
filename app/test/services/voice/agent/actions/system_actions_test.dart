import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/system_actions.dart';

import 'mock_database_service.dart';

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('SystemSettingsAction', () {
    late SystemSettingsAction action;

    setUp(() {
      action = SystemSettingsAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'system.settings');
      expect(action.name, '系统设置');
      expect(action.triggerPatterns, contains('系统设置'));
      expect(action.triggerPatterns, contains('打开设置'));
    });

    test('should return available settings when no key specified', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['needSelection'], isTrue);
      expect(result.data?['availableSettings'], contains('language'));
      expect(result.data?['availableSettings'], contains('notification'));
      expect(result.data?['availableSettings'], contains('privacy'));
      expect(result.data?['availableSettings'], contains('sync'));
    });

    test('should handle language setting', () async {
      final result = await action.execute({
        'settingKey': 'language',
        'settingValue': 'en',
      });

      expect(result.success, isTrue);
      expect(result.data?['settingKey'], 'language');
    });

    test('should handle notification setting', () async {
      final result = await action.execute({
        'settingKey': 'notification',
        'settingValue': 'off',
      });

      expect(result.success, isTrue);
      expect(result.data?['settingKey'], 'notification');
    });

    test('should handle privacy setting', () async {
      final result = await action.execute({
        'settingKey': 'privacy',
      });

      expect(result.success, isTrue);
      expect(result.data?['settingKey'], 'privacy');
    });

    test('should handle sync setting', () async {
      final result = await action.execute({
        'settingKey': 'sync',
        'settingValue': 'auto',
      });

      expect(result.success, isTrue);
      expect(result.data?['settingKey'], 'sync');
    });

    test('should support Chinese setting key names', () async {
      // 语言和同步需要值，隐私直接重定向
      var result = await action.execute({'settingKey': '隐私'});
      expect(result.success, isTrue);
      expect(result.data?['settingKey'], 'privacy');

      // 语言需要提供值
      result = await action.execute({'settingKey': '语言', 'settingValue': '中文'});
      expect(result.success, isTrue);

      // 通知需要提供值
      result = await action.execute({'settingKey': '通知', 'settingValue': '开启'});
      expect(result.success, isTrue);

      // 同步需要提供值
      result = await action.execute({'settingKey': '同步', 'settingValue': '开启'});
      expect(result.success, isTrue);
    });

    test('should return needParams for unknown setting', () async {
      final result = await action.execute({
        'settingKey': 'unknown',
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
      expect(result.followUpPrompt, contains('没有找到'));
    });
  });

  group('SystemAboutAction', () {
    late SystemAboutAction action;

    setUp(() {
      action = SystemAboutAction();
    });

    test('should have correct metadata', () {
      expect(action.id, 'system.about');
      expect(action.name, '关于应用');
      expect(action.triggerPatterns, contains('关于'));
      expect(action.triggerPatterns, contains('版本'));
    });

    test('should return app info with version', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['appName'], isNotNull);
      expect(result.data?['version'], isNotNull);
    });

    test('should return developer info', () async {
      final result = await action.execute({'infoType': 'developer'});

      expect(result.success, isTrue);
      expect(result.data?['developer'], isNotNull);
    });

    test('should return features list', () async {
      final result = await action.execute({'infoType': 'features'});

      expect(result.success, isTrue);
      expect(result.data?['features'], isA<List>());
    });

    test('should return changelog', () async {
      final result = await action.execute({'infoType': 'changelog'});

      expect(result.success, isTrue);
      expect(result.data?['highlights'], isA<List>());
    });
  });

  group('SystemFeedbackAction', () {
    late SystemFeedbackAction action;

    setUp(() {
      action = SystemFeedbackAction();
    });

    test('should have correct metadata', () {
      expect(action.id, 'system.feedback');
      expect(action.name, '用户反馈');
      expect(action.triggerPatterns, contains('反馈'));
    });

    test('should accept feedback content', () async {
      final result = await action.execute({
        'content': '希望增加多币种支持',
      });

      expect(result.success, isTrue);
      expect(result.data?['submitted'], isTrue);
    });

    test('should request content when not provided', () async {
      final result = await action.execute({});

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
    });

    test('should support feedback type', () async {
      final result = await action.execute({
        'content': '应用崩溃了',
        'feedbackType': 'bug',
      });

      expect(result.success, isTrue);
      expect(result.data?['feedbackType'], 'bug');
    });
  });
}
