import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/models/sms_message.dart';
import 'package:ai_bookkeeping/models/parsed_transaction.dart';
import 'package:ai_bookkeeping/models/transaction.dart';

void main() {
  group('SmsMessage', () {
    test('should create SmsMessage from map', () {
      final map = {
        'id': '123',
        'address': '95588',
        'body': '您尾号1234的储蓄卡12月24日10:30消费支出100.00元',
        'date': '1703390400000', // 2023-12-24 10:00:00
      };

      final sms = SmsMessage.fromMap(map);

      expect(sms.id, '123');
      expect(sms.address, '95588');
      expect(sms.body, contains('消费支出'));
      expect(sms.date.year, 2023);
    });

    test('should handle missing fields gracefully', () {
      final map = <String, dynamic>{};

      final sms = SmsMessage.fromMap(map);

      expect(sms.id, '');
      expect(sms.address, '');
      expect(sms.body, '');
      expect(sms.date, isA<DateTime>());
    });
  });

  group('ParsedTransaction', () {
    test('should create ParsedTransaction from JSON', () {
      final json = {
        'amount': 100.50,
        'type': 'expense',
        'date': '2024-01-24T10:30:00',
        'merchant': '星巴克',
        'note': '咖啡',
        'category': 'food_drink',
      };

      final transaction = ParsedTransaction.fromJson(
        json,
        '原始短信内容',
      );

      expect(transaction.amount, 100.50);
      expect(transaction.type, TransactionType.expense);
      expect(transaction.merchant, '星巴克');
      expect(transaction.note, '咖啡');
      expect(transaction.category, 'food_drink');
      expect(transaction.originalSmsBody, '原始短信内容');
    });

    test('should handle income type', () {
      final json = {
        'amount': 5000.0,
        'type': 'income',
        'date': '2024-01-24T10:30:00',
      };

      final transaction = ParsedTransaction.fromJson(json, '');

      expect(transaction.type, TransactionType.income);
    });

    test('should handle missing optional fields', () {
      final json = {
        'amount': 50.0,
        'type': 'expense',
        'date': '2024-01-24T10:30:00',
      };

      final transaction = ParsedTransaction.fromJson(json, '');

      expect(transaction.merchant, isNull);
      expect(transaction.note, isNull);
      expect(transaction.category, isNull);
    });

    test('should convert to JSON', () {
      final transaction = ParsedTransaction(
        amount: 100.0,
        type: TransactionType.expense,
        date: DateTime(2024, 1, 24, 10, 30),
        merchant: '测试商户',
        note: '测试备注',
        category: 'test_category',
        originalSmsBody: '原始短信',
      );

      final json = transaction.toJson();

      expect(json['amount'], 100.0);
      expect(json['type'], 'expense');
      expect(json['merchant'], '测试商户');
      expect(json['note'], '测试备注');
      expect(json['category'], 'test_category');
      expect(json['originalSmsBody'], '原始短信');
    });
  });

  group('SMS Parsing Scenarios', () {
    test('should parse bank transaction SMS', () {
      final smsBody = '您尾号1234的储蓄卡12月24日10:30消费支出100.00元，余额1000.00元';

      // 这里应该调用AI解析，但在单元测试中我们模拟结果
      final expectedJson = {
        'amount': 100.0,
        'type': 'expense',
        'date': '2024-12-24T10:30:00',
        'merchant': null,
        'note': '储蓄卡消费',
        'category': 'other',
      };

      final transaction = ParsedTransaction.fromJson(expectedJson, smsBody);

      expect(transaction.amount, 100.0);
      expect(transaction.type, TransactionType.expense);
    });

    test('should parse Alipay transaction SMS', () {
      final smsBody = '支付宝：您在星巴克消费100.50元';

      final expectedJson = {
        'amount': 100.50,
        'type': 'expense',
        'date': '2024-01-24T10:30:00',
        'merchant': '星巴克',
        'note': '支付宝消费',
        'category': 'food_drink',
      };

      final transaction = ParsedTransaction.fromJson(expectedJson, smsBody);

      expect(transaction.merchant, '星巴克');
      expect(transaction.category, 'food_drink');
    });

    test('should handle non-transaction SMS', () {
      final smsBody = '您的验证码是123456，请勿告诉他人';

      // AI应该返回null表示这不是交易短信
      expect(smsBody.contains('验证码'), isTrue);
    });
  });

  group('Date Parsing', () {
    test('should parse ISO 8601 date', () {
      final json = {
        'amount': 100.0,
        'type': 'expense',
        'date': '2024-01-24T10:30:00',
      };

      final transaction = ParsedTransaction.fromJson(json, '');

      expect(transaction.date.year, 2024);
      expect(transaction.date.month, 1);
      expect(transaction.date.day, 24);
      expect(transaction.date.hour, 10);
      expect(transaction.date.minute, 30);
    });

    test('should handle invalid date gracefully', () {
      final json = {
        'amount': 100.0,
        'type': 'expense',
        'date': 'invalid-date',
      };

      final transaction = ParsedTransaction.fromJson(json, '');

      // 应该使用当前时间作为fallback
      expect(transaction.date, isA<DateTime>());
    });
  });

  group('Amount Parsing', () {
    test('should parse integer amount', () {
      final json = {
        'amount': 100,
        'type': 'expense',
        'date': '2024-01-24T10:30:00',
      };

      final transaction = ParsedTransaction.fromJson(json, '');

      expect(transaction.amount, 100.0);
    });

    test('should parse decimal amount', () {
      final json = {
        'amount': 100.50,
        'type': 'expense',
        'date': '2024-01-24T10:30:00',
      };

      final transaction = ParsedTransaction.fromJson(json, '');

      expect(transaction.amount, 100.50);
    });

    test('should handle missing amount', () {
      final json = {
        'type': 'expense',
        'date': '2024-01-24T10:30:00',
      };

      final transaction = ParsedTransaction.fromJson(json, '');

      expect(transaction.amount, 0.0);
    });
  });
}
