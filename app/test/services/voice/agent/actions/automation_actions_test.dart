import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/automation_actions.dart';

import 'mock_database_service.dart';

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('ScreenRecognitionAction', () {
    late ScreenRecognitionAction action;

    setUp(() {
      action = ScreenRecognitionAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'automation.screenRecognition');
      expect(action.name, '屏幕识别记账');
      expect(action.triggerPatterns, contains('屏幕识别'));
      expect(action.triggerPatterns, contains('截图记账'));
    });

    test('should request image when no imagePath provided', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['needImage'], isTrue);
      expect(result.data?['supportedTypes'], contains('screenshot'));
    });

    test('should return confirmation request when autoCreate is false', () async {
      final result = await action.execute({
        'imagePath': '/path/to/image.jpg',
      });

      expect(result.success, isTrue);
      expect(result.data?['status'], 'needConfirmation');
      expect(result.data?['recognitionResult'], isNotNull);
    });

    test('should auto create when autoCreate is true', () async {
      final result = await action.execute({
        'imagePath': '/path/to/image.jpg',
        'autoCreate': true,
      });

      expect(result.success, isTrue);
      expect(result.data?['status'], 'created');
      expect(result.data?['createdCount'], isNotNull);
    });
  });

  group('AlipayBillSyncAction', () {
    late AlipayBillSyncAction action;

    setUp(() {
      action = AlipayBillSyncAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'automation.alipaySync');
      expect(action.name, '支付宝账单同步');
      expect(action.triggerPatterns, contains('支付宝账单'));
      expect(action.triggerPatterns, contains('导入支付宝'));
    });

    test('should return instructions when no file provided', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['needFile'], isTrue);
      expect(result.data?['instructions'], isA<List>());
    });

    test('should parse bill when file provided', () async {
      final result = await action.execute({
        'filePath': '/path/to/alipay.csv',
      });

      expect(result.success, isTrue);
      expect(result.data?['imported'], isNotNull);
      expect(result.data?['total'], isNotNull);
    });

    test('should skip duplicates by default', () async {
      final result = await action.execute({
        'filePath': '/path/to/alipay.csv',
      });

      expect(result.success, isTrue);
      expect(result.data?['skipped'], greaterThan(0));
    });

    test('should not skip duplicates when disabled', () async {
      final result = await action.execute({
        'filePath': '/path/to/alipay.csv',
        'skipDuplicate': false,
      });

      expect(result.success, isTrue);
      expect(result.data?['skipped'], 0);
    });
  });

  group('WeChatBillSyncAction', () {
    late WeChatBillSyncAction action;

    setUp(() {
      action = WeChatBillSyncAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'automation.wechatSync');
      expect(action.name, '微信账单同步');
      expect(action.triggerPatterns, contains('微信账单'));
      expect(action.triggerPatterns, contains('导入微信'));
    });

    test('should return instructions when no file provided', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['needFile'], isTrue);
      expect(result.data?['instructions'], isA<List>());
    });

    test('should parse bill when file provided', () async {
      final result = await action.execute({
        'filePath': '/path/to/wechat.csv',
      });

      expect(result.success, isTrue);
      expect(result.data?['imported'], isNotNull);
      expect(result.responseText, contains('微信'));
    });
  });

  group('BankBillSyncAction', () {
    late BankBillSyncAction action;

    setUp(() {
      action = BankBillSyncAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'automation.bankSync');
      expect(action.name, '银行账单同步');
      expect(action.triggerPatterns, contains('银行账单'));
      expect(action.triggerPatterns, contains('信用卡账单'));
    });

    test('should return supported banks when no file provided', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['needFile'], isTrue);
      expect(result.data?['supportedBanks'], contains('招商银行'));
      expect(result.data?['supportedFormats'], contains('csv'));
    });

    test('should parse bill when file provided', () async {
      final result = await action.execute({
        'filePath': '/path/to/bank.csv',
      });

      expect(result.success, isTrue);
      expect(result.data?['imported'], isNotNull);
    });

    test('should include bank type in result', () async {
      final result = await action.execute({
        'filePath': '/path/to/bank.csv',
        'bankType': '招商银行',
      });

      expect(result.success, isTrue);
      expect(result.data?['bankType'], '招商银行');
      expect(result.responseText, contains('招商银行'));
    });
  });

  group('EmailBillParseAction', () {
    late EmailBillParseAction action;

    setUp(() {
      action = EmailBillParseAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'automation.emailParse');
      expect(action.name, '邮箱账单解析');
      expect(action.triggerPatterns, contains('邮箱账单'));
      expect(action.triggerPatterns, contains('解析邮件'));
    });

    test('should return setup instructions when no email provided', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['needSetup'], isTrue);
      expect(result.data?['supportedProviders'], contains('Gmail'));
      expect(result.data?['redirectTo'], isNotNull);
    });

    test('should parse email bills when email provided', () async {
      final result = await action.execute({
        'emailAddress': 'user@example.com',
      });

      expect(result.success, isTrue);
      expect(result.data?['emailsParsed'], isNotNull);
      expect(result.data?['transactionsFound'], isNotNull);
    });

    test('should respect custom days parameter', () async {
      final result = await action.execute({
        'emailAddress': 'user@example.com',
        'days': 7,
      });

      expect(result.success, isTrue);
      expect(result.data?['days'], 7);
    });
  });

  group('ScheduledBookkeepingAction', () {
    late ScheduledBookkeepingAction action;

    setUp(() {
      action = ScheduledBookkeepingAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'automation.scheduled');
      expect(action.name, '定时自动记账');
      expect(action.triggerPatterns, contains('定时记账'));
      expect(action.triggerPatterns, contains('自动记账'));
    });

    test('should list rules by default', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['rules'], isA<List>());
      expect(result.data?['count'], isNotNull);
    });

    test('should list rules explicitly', () async {
      final result = await action.execute({'action': 'list'});

      expect(result.success, isTrue);
      expect(result.data?['rules'], isA<List>());
      expect(result.data?['totalMonthly'], isNotNull);
    });

    test('should require name when adding rule', () async {
      final result = await action.execute({
        'action': 'add',
        'amount': 500.0,
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
      expect(result.followUpPrompt, contains('名称'));
    });

    test('should require amount when adding rule', () async {
      final result = await action.execute({
        'action': 'add',
        'name': '健身卡',
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
      expect(result.followUpPrompt, contains('金额'));
    });

    test('should add rule successfully', () async {
      final result = await action.execute({
        'action': 'add',
        'name': '健身卡',
        'amount': 200.0,
      });

      expect(result.success, isTrue);
      expect(result.data?['action'], 'added');
      expect(result.data?['name'], '健身卡');
      expect(result.data?['amount'], 200.0);
      expect(result.data?['frequency'], 'monthly');
    });

    test('should add rule with custom frequency', () async {
      final result = await action.execute({
        'action': 'add',
        'name': '地铁卡',
        'amount': 100.0,
        'frequency': 'weekly',
      });

      expect(result.success, isTrue);
      expect(result.data?['frequency'], 'weekly');
      expect(result.responseText, contains('每周'));
    });

    test('should require name when removing rule', () async {
      final result = await action.execute({
        'action': 'remove',
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
    });

    test('should remove rule successfully', () async {
      final result = await action.execute({
        'action': 'remove',
        'name': '话费',
      });

      expect(result.success, isTrue);
      expect(result.data?['action'], 'removed');
      expect(result.data?['name'], '话费');
    });

    test('should require name when pausing rule', () async {
      final result = await action.execute({
        'action': 'pause',
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
    });

    test('should pause rule successfully', () async {
      final result = await action.execute({
        'action': 'pause',
        'name': '视频会员',
      });

      expect(result.success, isTrue);
      expect(result.data?['action'], 'paused');
      expect(result.data?['name'], '视频会员');
    });
  });
}
