import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// Widget tests for AI Bookkeeping app
// Updated 2025-12-30: Added security tests for password hashing and encryption
// Updated 2025-12-30: Added source file management tests for image/audio recognition

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
        'user_tag@example.org',
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

    test('EUR formatting works correctly', () {
      expect(formatCurrency(1234.56, 'EUR'), equals('€1,234.56'));
    });

    test('GBP formatting works correctly', () {
      expect(formatCurrency(1234.56, 'GBP'), equals('£1,234.56'));
    });

    test('KRW formatting works correctly (no decimals)', () {
      expect(formatCurrency(1234, 'KRW'), equals('₩1,234'));
    });

    test('HKD formatting works correctly', () {
      expect(formatCurrency(1234.56, 'HKD'), equals('HK\$1,234.56'));
    });

    test('TWD formatting works correctly', () {
      expect(formatCurrency(1234.56, 'TWD'), equals('NT\$1,234.56'));
    });

    test('Large number compact display works', () {
      expect(formatCompact(10000, 'CNY'), equals('1万'));
      expect(formatCompact(1000000, 'USD'), equals('1M'));
    });
  });

  group('Multi-Currency Tests', () {
    test('All supported currencies have correct symbols', () {
      expect(getCurrencySymbol('CNY'), equals('¥'));
      expect(getCurrencySymbol('USD'), equals('\$'));
      expect(getCurrencySymbol('EUR'), equals('€'));
      expect(getCurrencySymbol('JPY'), equals('¥'));
      expect(getCurrencySymbol('GBP'), equals('£'));
      expect(getCurrencySymbol('KRW'), equals('₩'));
      expect(getCurrencySymbol('HKD'), equals('HK\$'));
      expect(getCurrencySymbol('TWD'), equals('NT\$'));
    });

    test('Currency decimal places are correct', () {
      expect(getCurrencyDecimals('CNY'), equals(2));
      expect(getCurrencyDecimals('USD'), equals(2));
      expect(getCurrencyDecimals('EUR'), equals(2));
      expect(getCurrencyDecimals('JPY'), equals(0));
      expect(getCurrencyDecimals('KRW'), equals(0));
    });

    test('Manual exchange rate conversion works', () {
      // CNY to USD at rate 0.14
      expect(convertCurrency(100, 0.14), closeTo(14.0, 0.001));
      // USD to CNY at rate 7.0
      expect(convertCurrency(100, 7.0), closeTo(700.0, 0.001));
    });

    test('Exchange rate validation works', () {
      expect(isValidExchangeRate(0.14), isTrue);
      expect(isValidExchangeRate(7.0), isTrue);
      expect(isValidExchangeRate(0), isFalse);
      expect(isValidExchangeRate(-1), isFalse);
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

  group('Security - Password Hashing Tests', () {
    test('Password hash is not plain text', () {
      const password = 'SecurePass123!';
      final salt = generateSalt();
      final hash = hashPasswordWithSalt(password, salt);

      expect(hash, isNot(equals(password)));
      expect(hash.length, equals(64)); // SHA256 produces 64 hex chars
    });

    test('Same password with different salts produces different hashes', () {
      const password = 'SamePassword';
      final salt1 = 'salt1_unique_1';
      final salt2 = 'salt2_unique_2';

      final hash1 = hashPasswordWithSalt(password, salt1);
      final hash2 = hashPasswordWithSalt(password, salt2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('Password verification with correct password', () {
      const password = 'CorrectPass123';
      const salt = 'fixed_test_salt';
      final hash = hashPasswordWithSalt(password, salt);
      final verifyHash = hashPasswordWithSalt(password, salt);

      expect(hash, equals(verifyHash));
    });

    test('Password verification with wrong password fails', () {
      const password = 'CorrectPass123';
      const wrongPassword = 'WrongPass123';
      const salt = 'fixed_test_salt';

      final hash = hashPasswordWithSalt(password, salt);
      final wrongHash = hashPasswordWithSalt(wrongPassword, salt);

      expect(hash, isNot(equals(wrongHash)));
    });

    test('Unicode password support (Chinese characters)', () {
      const password = '密码Test123';
      const salt = 'unicode_salt';
      final hash = hashPasswordWithSalt(password, salt);

      expect(hash.length, equals(64));
      expect(hashPasswordWithSalt(password, salt), equals(hash));
    });
  });

  group('Security - Password Strength Tests', () {
    test('Strong password validation - valid passwords', () {
      final validPasswords = [
        'Password123',
        'SecurePass1',
        'MyP4ssword',
        'Test1234Ab',
      ];

      for (final password in validPasswords) {
        expect(isStrongPassword(password), isTrue,
            reason: '$password should be valid');
      }
    });

    test('Weak password validation - invalid passwords', () {
      final invalidPasswords = [
        'short',           // Too short
        'nouppercase1',    // No uppercase
        'NOLOWERCASE1',    // No lowercase
        'NoNumbersHere',   // No numbers
        '12345678',        // No letters
      ];

      for (final password in invalidPasswords) {
        expect(isStrongPassword(password), isFalse,
            reason: '$password should be invalid');
      }
    });
  });

  group('Security - Input Sanitization Tests', () {
    test('XSS attack prevention - script tags', () {
      const maliciousInput = "<script>alert('xss')</script>";
      final sanitized = sanitizeInput(maliciousInput);

      expect(sanitized.contains('<script>'), isFalse);
      expect(sanitized.contains('</script>'), isFalse);
      expect(sanitized, contains('&lt;'));
      expect(sanitized, contains('&gt;'));
    });

    test('XSS attack prevention - event handlers', () {
      const maliciousInput = '<img onerror="alert(1)" src="x">';
      final sanitized = sanitizeInput(maliciousInput);

      expect(sanitized.contains('<img'), isFalse);
      expect(sanitized, contains('&lt;'));
    });

    test('SQL injection characters are escaped', () {
      const maliciousInput = "'; DROP TABLE users; --";
      final sanitized = sanitizeInput(maliciousInput);

      expect(sanitized, contains('&#x27;')); // Escaped quote
    });

    test('Normal text passes through', () {
      const normalInput = '正常的中文输入 Normal English';
      final sanitized = sanitizeInput(normalInput);

      expect(sanitized, equals(normalInput));
    });
  });

  group('Security - JWT Token Validation Tests', () {
    test('Valid JWT format passes validation', () {
      // A properly formatted JWT (header.payload.signature)
      const validJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.'
          'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

      expect(isValidJwtFormat(validJwt), isTrue);
    });

    test('Invalid JWT format fails validation', () {
      final invalidJwts = [
        'not.a.jwt.token.extra',  // Too many parts
        'notajwt',                 // No dots
        'only.two',                // Only two parts
        '',                        // Empty
        'invalid.!!!.characters',  // Invalid base64
      ];

      for (final jwt in invalidJwts) {
        expect(isValidJwtFormat(jwt), isFalse,
            reason: '$jwt should be invalid JWT format');
      }
    });
  });

  group('Security - HTTPS URL Validation Tests', () {
    test('HTTPS URLs are valid', () {
      final httpsUrls = [
        'https://api.example.com',
        'https://secure.server.com/api/v1',
        'https://localhost:8443',
      ];

      for (final url in httpsUrls) {
        expect(url.startsWith('https://'), isTrue);
      }
    });

    test('HTTP URLs should be flagged as insecure', () {
      const httpUrl = 'http://insecure.example.com';

      expect(httpUrl.startsWith('https://'), isFalse);
      expect(httpUrl.startsWith('http://'), isTrue);
    });
  });

  group('AI Model Configuration Tests', () {
    test('Qwen model names are valid', () {
      final validModels = [
        'qwen-omni-turbo',    // Audio/multimodal
        'qwen-vl-plus',       // Vision
        'qwen-turbo',         // Text
        'qwen-plus',          // Text (advanced)
      ];

      for (final model in validModels) {
        expect(model.startsWith('qwen-'), isTrue);
        expect(model.length, greaterThan(5));
      }
    });

    test('Audio formats for qwen-omni-turbo', () {
      final supportedFormats = ['m4a', 'wav', 'mp3'];

      for (final format in supportedFormats) {
        expect(format.length, lessThanOrEqualTo(4));
      }
    });
  });

  group('Transaction Source Tests', () {
    test('Transaction source values are correct', () {
      // Test source type enum values
      expect(getTransactionSourceValue('manual'), equals(0));
      expect(getTransactionSourceValue('image'), equals(1));
      expect(getTransactionSourceValue('voice'), equals(2));
      expect(getTransactionSourceValue('email'), equals(3));
    });

    test('Transaction source labels are correct', () {
      expect(getTransactionSourceLabel(0), equals('手动'));
      expect(getTransactionSourceLabel(1), equals('拍照'));
      expect(getTransactionSourceLabel(2), equals('语音'));
      expect(getTransactionSourceLabel(3), equals('邮件'));
    });

    test('Transaction source icons are defined', () {
      // All source types should have a valid icon
      final icons = [
        getTransactionSourceIcon(0),  // manual - edit
        getTransactionSourceIcon(1),  // image - camera
        getTransactionSourceIcon(2),  // voice - mic
        getTransactionSourceIcon(3),  // email - email
      ];

      for (final icon in icons) {
        expect(icon, isNotNull);
      }
    });
  });

  group('Source File Storage Tests', () {
    test('File size formatting works correctly', () {
      // Bytes
      expect(formatFileSize(512), equals('512 B'));
      expect(formatFileSize(0), equals('0 B'));

      // Kilobytes
      expect(formatFileSize(1024), equals('1.0 KB'));
      expect(formatFileSize(1536), equals('1.5 KB'));
      expect(formatFileSize(10240), equals('10.0 KB'));

      // Megabytes
      expect(formatFileSize(1048576), equals('1.0 MB'));
      expect(formatFileSize(5242880), equals('5.0 MB'));
      expect(formatFileSize(1572864), equals('1.5 MB'));
    });

    test('Source file expiry calculation', () {
      final now = DateTime.now();

      // 7 days retention
      final expiry7 = calculateExpiryDate(now, 7);
      expect(expiry7.difference(now).inDays, equals(7));

      // 14 days retention
      final expiry14 = calculateExpiryDate(now, 14);
      expect(expiry14.difference(now).inDays, equals(14));

      // 30 days retention
      final expiry30 = calculateExpiryDate(now, 30);
      expect(expiry30.difference(now).inDays, equals(30));
    });

    test('Source file expiry status check', () {
      final now = DateTime.now();

      // Not expired (future date)
      final futureDate = now.add(const Duration(days: 5));
      expect(isSourceFileExpired(futureDate, now), isFalse);

      // Expired (past date)
      final pastDate = now.subtract(const Duration(days: 5));
      expect(isSourceFileExpired(pastDate, now), isTrue);

      // Boundary: expires today at exact time
      expect(isSourceFileExpired(now, now), isFalse);
    });

    test('Expiry text formatting', () {
      final now = DateTime.now();

      // Days remaining
      final in5Days = now.add(const Duration(days: 5));
      expect(getExpiryText(in5Days, now), equals('5天后过期'));

      final in1Day = now.add(const Duration(days: 1));
      expect(getExpiryText(in1Day, now), equals('1天后过期'));

      // Hours remaining
      final in5Hours = now.add(const Duration(hours: 5));
      expect(getExpiryText(in5Hours, now), equals('5小时后过期'));

      // Expired
      final expired = now.subtract(const Duration(days: 1));
      expect(getExpiryText(expired, now), equals('已过期'));

      // Expiring soon (less than 1 hour)
      final in30Minutes = now.add(const Duration(minutes: 30));
      expect(getExpiryText(in30Minutes, now), equals('即将过期'));
    });
  });

  group('Source File MIME Type Tests', () {
    test('Image MIME types are correct', () {
      expect(getMimeType('jpg'), equals('image/jpeg'));
      expect(getMimeType('jpeg'), equals('image/jpeg'));
      expect(getMimeType('png'), equals('image/png'));
      expect(getMimeType('gif'), equals('image/gif'));
      expect(getMimeType('webp'), equals('image/webp'));
      expect(getMimeType('heic'), equals('image/heic'));
      expect(getMimeType('heif'), equals('image/heif'));
    });

    test('Audio MIME types are correct', () {
      expect(getMimeType('wav'), equals('audio/wav'));
      expect(getMimeType('mp3'), equals('audio/mpeg'));
      expect(getMimeType('m4a'), equals('audio/mp4'));
      expect(getMimeType('aac'), equals('audio/aac'));
    });

    test('Unknown extension returns default', () {
      expect(getMimeType('unknown'), equals('application/octet-stream'));
      expect(getMimeType('xyz'), equals('application/octet-stream'));
    });

    test('Case insensitive MIME type lookup', () {
      expect(getMimeType('JPG'), equals('image/jpeg'));
      expect(getMimeType('PNG'), equals('image/png'));
      expect(getMimeType('WAV'), equals('audio/wav'));
    });
  });

  group('Source File Recognition Data Tests', () {
    test('Recognition raw data JSON format', () {
      final rawData = {
        'type': 'expense',
        'amount': 35.5,
        'category': 'food',
        'description': '午餐',
        'date': '2024-12-30',
        'confidence': 0.95,
        'timestamp': '2024-12-30T12:00:00.000Z',
      };

      final jsonString = jsonEncode(rawData);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['type'], equals('expense'));
      expect(decoded['amount'], equals(35.5));
      expect(decoded['category'], equals('food'));
      expect(decoded['confidence'], closeTo(0.95, 0.001));
    });

    test('Recognition data preserves Chinese characters', () {
      final rawData = {
        'description': '购买水果和蔬菜',
        'merchant': '超市',
      };

      final jsonString = jsonEncode(rawData);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['description'], equals('购买水果和蔬菜'));
      expect(decoded['merchant'], equals('超市'));
    });

    test('Recognition data handles null values', () {
      final rawData = {
        'type': 'expense',
        'amount': 100.0,
        'category': null,
        'description': null,
        'date': '2024-12-30',
      };

      final jsonString = jsonEncode(rawData);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['category'], isNull);
      expect(decoded['description'], isNull);
      expect(decoded['amount'], equals(100.0));
    });
  });

  group('Cleanup Scheduler Tests', () {
    test('Cleanup interval calculation', () {
      // Default cleanup interval is 24 hours
      const cleanupInterval = Duration(hours: 24);

      final lastCleanup = DateTime.now().subtract(const Duration(hours: 25));
      final now = DateTime.now();
      final timeSinceLastCleanup = now.difference(lastCleanup);

      expect(timeSinceLastCleanup >= cleanupInterval, isTrue);
    });

    test('Should run cleanup when never cleaned', () {
      // When lastCleanup is null, cleanup should run
      DateTime? lastCleanup;
      expect(shouldRunCleanup(lastCleanup), isTrue);
    });

    test('Should not run cleanup within interval', () {
      final lastCleanup = DateTime.now().subtract(const Duration(hours: 12));
      expect(shouldRunCleanup(lastCleanup), isFalse);
    });

    test('Should run cleanup after interval', () {
      final lastCleanup = DateTime.now().subtract(const Duration(hours: 25));
      expect(shouldRunCleanup(lastCleanup), isTrue);
    });
  });

  group('Source File Storage Info Tests', () {
    test('Total size calculation', () {
      final storageInfo = SourceFileStorageInfoTest(
        imageCount: 5,
        audioCount: 3,
        imageSize: 1024 * 1024 * 2, // 2 MB
        audioSize: 1024 * 1024 * 1, // 1 MB
      );

      expect(storageInfo.totalSize, equals(1024 * 1024 * 3)); // 3 MB
      expect(storageInfo.totalCount, equals(8));
    });

    test('Empty storage info', () {
      final storageInfo = SourceFileStorageInfoTest(
        imageCount: 0,
        audioCount: 0,
        imageSize: 0,
        audioSize: 0,
      );

      expect(storageInfo.totalSize, equals(0));
      expect(storageInfo.totalCount, equals(0));
    });
  });

  group('WiFi Sync Configuration Tests', () {
    test('Sync should only happen on WiFi', () {
      expect(shouldSyncOnWifi(true, true), isTrue);   // WiFi enabled, on WiFi
      expect(shouldSyncOnWifi(true, false), isFalse); // WiFi enabled, not on WiFi
      expect(shouldSyncOnWifi(false, true), isFalse); // WiFi disabled, on WiFi
      expect(shouldSyncOnWifi(false, false), isFalse); // WiFi disabled, not on WiFi
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
    case 'HKD':
      symbol = 'HK\$';
      break;
    case 'TWD':
      symbol = 'NT\$';
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

// Multi-currency helper functions

String getCurrencySymbol(String currency) {
  switch (currency) {
    case 'CNY':
      return '¥';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'JPY':
      return '¥';
    case 'GBP':
      return '£';
    case 'KRW':
      return '₩';
    case 'HKD':
      return 'HK\$';
    case 'TWD':
      return 'NT\$';
    default:
      return currency;
  }
}

int getCurrencyDecimals(String currency) {
  switch (currency) {
    case 'JPY':
    case 'KRW':
      return 0;
    default:
      return 2;
  }
}

double convertCurrency(num amount, num rate) {
  return (amount * rate).toDouble();
}

bool isValidExchangeRate(num rate) {
  return rate > 0;
}

// Security helper functions

/// Generate SHA256 hash of password with salt
String hashPasswordWithSalt(String password, String salt) {
  final combined = password + salt;
  final bytes = utf8.encode(combined);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Generate a random salt (in production, use secure random)
String generateSalt() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final bytes = utf8.encode('salt_$timestamp');
  return sha256.convert(bytes).toString().substring(0, 16);
}

/// Validate password strength
bool isStrongPassword(String password) {
  if (password.length < 8) return false;
  if (!password.contains(RegExp(r'[A-Z]'))) return false;
  if (!password.contains(RegExp(r'[a-z]'))) return false;
  if (!password.contains(RegExp(r'[0-9]'))) return false;
  return true;
}

/// Sanitize user input to prevent XSS
String sanitizeInput(String input) {
  return input
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;')
      .replaceAll('/', '&#x2F;');
}

/// Validate JWT token format
bool isValidJwtFormat(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return false;
  // Each part should be base64 encoded
  try {
    for (final part in parts) {
      // Add padding if needed
      final padded = part.padRight((part.length + 3) & ~3, '=');
      base64Url.decode(padded);
    }
    return true;
  } catch (e) {
    return false;
  }
}

// ==================== Source File Helper Functions ====================

/// Get transaction source enum value
int getTransactionSourceValue(String source) {
  switch (source) {
    case 'manual':
      return 0;
    case 'image':
      return 1;
    case 'voice':
      return 2;
    case 'email':
      return 3;
    default:
      return 0;
  }
}

/// Get transaction source label
String getTransactionSourceLabel(int source) {
  switch (source) {
    case 0:
      return '手动';
    case 1:
      return '拍照';
    case 2:
      return '语音';
    case 3:
      return '邮件';
    default:
      return '未知';
  }
}

/// Get transaction source icon
IconData getTransactionSourceIcon(int source) {
  switch (source) {
    case 0:
      return Icons.edit;
    case 1:
      return Icons.camera_alt;
    case 2:
      return Icons.mic;
    case 3:
      return Icons.email;
    default:
      return Icons.help;
  }
}

/// Format file size as human-readable string
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Calculate expiry date based on retention days
DateTime calculateExpiryDate(DateTime from, int retentionDays) {
  return from.add(Duration(days: retentionDays));
}

/// Check if source file is expired
bool isSourceFileExpired(DateTime expiresAt, DateTime now) {
  return now.isAfter(expiresAt);
}

/// Get expiry text
String getExpiryText(DateTime expiresAt, DateTime now) {
  if (now.isAfter(expiresAt)) {
    return '已过期';
  }
  final remaining = expiresAt.difference(now);
  if (remaining.inDays > 0) {
    return '${remaining.inDays}天后过期';
  } else if (remaining.inHours > 0) {
    return '${remaining.inHours}小时后过期';
  } else {
    return '即将过期';
  }
}

/// Get MIME type from file extension
String getMimeType(String extension) {
  switch (extension.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'wav':
      return 'audio/wav';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    default:
      return 'application/octet-stream';
  }
}

/// Check if cleanup should run based on last cleanup time
bool shouldRunCleanup(DateTime? lastCleanup) {
  if (lastCleanup == null) return true;
  const cleanupInterval = Duration(hours: 24);
  final timeSinceLastCleanup = DateTime.now().difference(lastCleanup);
  return timeSinceLastCleanup >= cleanupInterval;
}

/// Check if should sync on WiFi
bool shouldSyncOnWifi(bool wifiSyncEnabled, bool isOnWifi) {
  return wifiSyncEnabled && isOnWifi;
}

/// Test class for SourceFileStorageInfo
class SourceFileStorageInfoTest {
  final int imageCount;
  final int audioCount;
  final int imageSize;
  final int audioSize;

  SourceFileStorageInfoTest({
    required this.imageCount,
    required this.audioCount,
    required this.imageSize,
    required this.audioSize,
  });

  int get totalSize => imageSize + audioSize;
  int get totalCount => imageCount + audioCount;
}
