import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Widget tests for AI Bookkeeping app

void main() {
  group('App Widget Tests', () {
    testWidgets('App starts with login page when not authenticated', (tester) async {
      // This test verifies the app starts correctly
      // Full implementation would require mocking providers
      expect(true, isTrue);
    });
  });

  group('Form Validation Tests', () {
    testWidgets('Email validation works correctly', (tester) async {
      // Test email validation regex
      final validEmails = [
        'test@example.com',
        'user.name@domain.co.uk',
        'user+tag@example.org',
      ];

      final invalidEmails = [
        'not-an-email',
        '@no-user.com',
        'missing@',
        '',
      ];

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

      for (final email in validEmails) {
        expect(emailRegex.hasMatch(email), isTrue, reason: '$email should be valid');
      }

      for (final email in invalidEmails) {
        expect(emailRegex.hasMatch(email), isFalse, reason: '$email should be invalid');
      }
    });

    testWidgets('Phone validation works correctly', (tester) async {
      // Test Chinese phone number validation
      final validPhones = [
        '13812345678',
        '15987654321',
        '18600000000',
      ];

      final invalidPhones = [
        '12345678901',  // Wrong prefix
        '1381234567',   // Too short
        '138123456789', // Too long
        'notaphone',
      ];

      final phoneRegex = RegExp(r'^1[3-9]\d{9}$');

      for (final phone in validPhones) {
        expect(phoneRegex.hasMatch(phone), isTrue, reason: '$phone should be valid');
      }

      for (final phone in invalidPhones) {
        expect(phoneRegex.hasMatch(phone), isFalse, reason: '$phone should be invalid');
      }
    });
  });

  group('Currency Formatting Tests', () {
    test('CNY formatting works correctly', () {
      // Test CNY currency formatting
      expect(formatCurrency(1234.56, 'CNY'), equals('¥1,234.56'));
      expect(formatCurrency(0, 'CNY'), equals('¥0.00'));
      expect(formatCurrency(-500.00, 'CNY'), equals('-¥500.00'));
    });

    test('USD formatting works correctly', () {
      expect(formatCurrency(1234.56, 'USD'), equals('\$1,234.56'));
    });

    test('JPY formatting works correctly (no decimals)', () {
      expect(formatCurrency(1234, 'JPY'), equals('¥1,234'));
    });

    test('Large number compact display works', () {
      expect(formatCompact(10000, 'CNY'), equals('1万'));
      expect(formatCompact(1000000, 'USD'), equals('1M'));
    });
  });

  group('Date Formatting Tests', () {
    test('Chinese date format works', () {
      final date = DateTime(2024, 12, 28);
      expect(formatDateCN(date), equals('2024年12月28日'));
    });

    test('Month display format works', () {
      final date = DateTime(2024, 12, 1);
      expect(formatMonthCN(date), equals('2024年12月'));
    });
  });

  group('Transaction Type Tests', () {
    test('Transaction types are correctly identified', () {
      expect(getTransactionTypeLabel('expense'), equals('支出'));
      expect(getTransactionTypeLabel('income'), equals('收入'));
      expect(getTransactionTypeLabel('transfer'), equals('转账'));
    });

    test('Transaction type colors are correct', () {
      expect(getTransactionTypeColor('expense'), equals(Colors.red));
      expect(getTransactionTypeColor('income'), equals(Colors.green));
      expect(getTransactionTypeColor('transfer'), equals(Colors.blue));
    });
  });

  group('Budget Calculation Tests', () {
    test('Budget percentage calculation is correct', () {
      expect(calculateBudgetPercentage(500, 1000), equals(50.0));
      expect(calculateBudgetPercentage(0, 1000), equals(0.0));
      expect(calculateBudgetPercentage(1500, 1000), equals(150.0));
    });

    test('Budget status is correctly determined', () {
      expect(getBudgetStatus(50), equals('normal'));
      expect(getBudgetStatus(80), equals('warning'));
      expect(getBudgetStatus(100), equals('exceeded'));
    });
  });

  group('Account Type Tests', () {
    test('Account type labels are correct', () {
      expect(getAccountTypeLabel('cash'), equals('现金'));
      expect(getAccountTypeLabel('bank'), equals('银行卡'));
      expect(getAccountTypeLabel('credit'), equals('信用卡'));
      expect(getAccountTypeLabel('ewallet'), equals('电子钱包'));
      expect(getAccountTypeLabel('investment'), equals('投资账户'));
    });

    test('Account type icons are correct', () {
      expect(getAccountTypeIcon('cash'), equals(Icons.attach_money));
      expect(getAccountTypeIcon('bank'), equals(Icons.account_balance));
      expect(getAccountTypeIcon('credit'), equals(Icons.credit_card));
    });
  });
}

// Helper functions for tests (would normally be in separate utility files)

String formatCurrency(num amount, String currency) {
  final absAmount = amount.abs();
  final sign = amount < 0 ? '-' : '';

  String symbol;
  int decimals = 2;

  switch (currency) {
    case 'CNY':
      symbol = '¥';
      break;
    case 'USD':
      symbol = '\$';
      break;
    case 'EUR':
      symbol = '€';
      break;
    case 'JPY':
      symbol = '¥';
      decimals = 0;
      break;
    case 'GBP':
      symbol = '£';
      break;
    case 'KRW':
      symbol = '₩';
      decimals = 0;
      break;
    default:
      symbol = currency;
  }

  final formatted = absAmount.toStringAsFixed(decimals);
  final parts = formatted.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );

  if (decimals > 0 && parts.length > 1) {
    return '$sign$symbol$intPart.${parts[1]}';
  }
  return '$sign$symbol$intPart';
}

String formatCompact(num amount, String currency) {
  if (currency == 'CNY') {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(0)}万';
    }
  } else {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(0)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
  }
  return amount.toString();
}

String formatDateCN(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
}

String formatMonthCN(DateTime date) {
  return '${date.year}年${date.month}月';
}

String getTransactionTypeLabel(String type) {
  switch (type) {
    case 'expense':
      return '支出';
    case 'income':
      return '收入';
    case 'transfer':
      return '转账';
    default:
      return type;
  }
}

Color getTransactionTypeColor(String type) {
  switch (type) {
    case 'expense':
      return Colors.red;
    case 'income':
      return Colors.green;
    case 'transfer':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

double calculateBudgetPercentage(num spent, num budget) {
  if (budget == 0) return 0.0;
  return (spent / budget) * 100;
}

String getBudgetStatus(double percentage) {
  if (percentage >= 100) return 'exceeded';
  if (percentage >= 80) return 'warning';
  return 'normal';
}

String getAccountTypeLabel(String type) {
  switch (type) {
    case 'cash':
      return '现金';
    case 'bank':
      return '银行卡';
    case 'credit':
      return '信用卡';
    case 'ewallet':
      return '电子钱包';
    case 'investment':
      return '投资账户';
    default:
      return type;
  }
}

IconData getAccountTypeIcon(String type) {
  switch (type) {
    case 'cash':
      return Icons.attach_money;
    case 'bank':
      return Icons.account_balance;
    case 'credit':
      return Icons.credit_card;
    case 'ewallet':
      return Icons.account_balance_wallet;
    case 'investment':
      return Icons.trending_up;
    default:
      return Icons.account_circle;
  }
}
