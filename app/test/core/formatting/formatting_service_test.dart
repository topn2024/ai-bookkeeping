import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ai_bookkeeping/core/formatting/formatting_service.dart';

void main() {
  late FormattingService service;

  setUpAll(() async {
    // 初始化日期格式化所需的本地化数据
    await initializeDateFormatting('zh_CN', null);
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('ja_JP', null);
    await initializeDateFormatting('ko_KR', null);
    await initializeDateFormatting('zh_TW', null);
  });

  setUp(() {
    service = FormattingService.instance;
    // 重置为默认语言
    service.setLocale(AppLanguage.zhCN);
  });

  group('FormattingService', () {
    group('单例模式', () {
      test('应返回相同实例', () {
        final instance1 = FormattingService.instance;
        final instance2 = FormattingService.instance;
        expect(instance1, same(instance2));
      });
    });

    group('货币格式化 formatCurrency', () {
      test('格式化人民币金额', () {
        service.setLocale(AppLanguage.zhCN);
        final result = service.formatCurrency(1234.56, currencyCode: 'CNY');
        expect(result, '¥1,234.56');
      });

      test('格式化美元金额', () {
        final result = service.formatCurrency(1234.56, currencyCode: 'USD');
        expect(result, '\$1,234.56');
      });

      test('不显示货币符号', () {
        final result = service.formatCurrency(1234.56, showSymbol: false);
        expect(result, '1,234.56');
      });

      test('自定义小数位数', () {
        service.setLocale(AppLanguage.zhCN);
        final result = service.formatCurrency(1234.56, decimalPlaces: 0);
        expect(result, '¥1,235');
      });

      test('自定义小数位数 - 0位四舍五入', () {
        final result = service.formatCurrency(1234.44, decimalPlaces: 0, showSymbol: false);
        expect(result, '1,234');
      });

      test('自定义小数位数 - 1位', () {
        final result = service.formatCurrency(1234.56, decimalPlaces: 1, showSymbol: false);
        expect(result, '1,234.6');
      });

      test('日元格式化（无小数）', () {
        final result = service.formatCurrency(1234.56, currencyCode: 'JPY');
        expect(result, '¥1,235');
      });

      test('越南盾格式化（符号在后）', () {
        final result = service.formatCurrency(1234.0, currencyCode: 'VND');
        expect(result, '1,234₫');
      });
    });

    group('数字格式化 formatNumber', () {
      test('格式化大数字', () {
        final result = service.formatNumber(1234567.89);
        expect(result, '1,234,567.89');
      });

      test('格式化整数', () {
        final result = service.formatNumber(1234567.0, decimalPlaces: 0);
        expect(result, '1,234,567');
      });

      test('格式化小数', () {
        final result = service.formatNumber(1234.5, decimalPlaces: 3);
        expect(result, '1,234.500');
      });
    });

    group('百分比格式化 formatPercentage', () {
      test('格式化比例为百分比', () {
        final result = service.formatPercentage(0.1234);
        expect(result, contains('12'));
        expect(result, contains('%'));
      });

      test('格式化 100%', () {
        final result = service.formatPercentage(1.0);
        expect(result, contains('100'));
        expect(result, contains('%'));
      });

      test('格式化 0%', () {
        final result = service.formatPercentage(0.0);
        expect(result, contains('0'));
        expect(result, contains('%'));
      });
    });

    group('日期格式化 formatDate', () {
      test('格式化日期 - 中文', () {
        service.setLocale(AppLanguage.zhCN);
        final date = DateTime(2024, 1, 15);
        final result = service.formatDate(date);
        expect(result, contains('2024'));
        expect(result, contains('1'));
        expect(result, contains('15'));
      });

      test('格式化日期 - 英文', () {
        service.setLocale(AppLanguage.en);
        final date = DateTime(2024, 1, 15);
        final result = service.formatDate(date);
        expect(result, contains('2024'));
        expect(result, contains('Jan'));
        expect(result, contains('15'));
      });
    });

    group('相对时间格式化 formatRelativeTime', () {
      test('格式化刚刚', () {
        service.setLocale(AppLanguage.zhCN);
        final now = DateTime.now();
        final result = service.formatRelativeTime(now);
        expect(result, '刚刚');
      });

      test('格式化分钟前', () {
        service.setLocale(AppLanguage.zhCN);
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        final result = service.formatRelativeTime(fiveMinutesAgo);
        expect(result, '5分钟前');
      });

      test('格式化小时前', () {
        service.setLocale(AppLanguage.zhCN);
        final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
        final result = service.formatRelativeTime(twoHoursAgo);
        expect(result, '2小时前');
      });

      test('格式化天前', () {
        service.setLocale(AppLanguage.zhCN);
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        final result = service.formatRelativeTime(threeDaysAgo);
        expect(result, '3天前');
      });
    });
  });

  group('DoubleFormattingExtension', () {
    setUp(() {
      FormattingService.instance.setLocale(AppLanguage.zhCN);
    });

    test('toCurrency 扩展方法', () {
      final result = 99.9.toCurrency();
      expect(result, '¥99.90');
    });

    test('toCurrency 指定货币', () {
      final result = 99.9.toCurrency(currencyCode: 'USD');
      expect(result, '\$99.90');
    });

    test('toCurrency 不显示符号', () {
      final result = 99.9.toCurrency(showSymbol: false);
      expect(result, '99.90');
    });

    test('toFormattedNumber 扩展方法', () {
      final result = 1234567.89.toFormattedNumber();
      expect(result, '1,234,567.89');
    });

    test('toPercentage 扩展方法', () {
      final result = 0.1234.toPercentage();
      expect(result, contains('12'));
    });

    test('toCompactNumber 扩展方法 - 中文万', () {
      FormattingService.instance.setLocale(AppLanguage.zhCN);
      final result = 12345.0.toCompactNumber();
      expect(result, contains('万'));
    });

    test('toCompactNumber 扩展方法 - 英文K', () {
      FormattingService.instance.setLocale(AppLanguage.en);
      final result = 1500.0.toCompactNumber();
      expect(result, contains('K'));
    });
  });

  group('IntFormattingExtension', () {
    setUp(() {
      FormattingService.instance.setLocale(AppLanguage.zhCN);
    });

    test('toCurrency 扩展方法', () {
      final result = 100.toCurrency();
      expect(result, '¥100.00');
    });

    test('toFormattedNumber 扩展方法', () {
      final result = 1234567.toFormattedNumber();
      expect(result, '1,234,567');
    });
  });

  group('DateTimeFormattingExtension', () {
    setUp(() {
      FormattingService.instance.setLocale(AppLanguage.zhCN);
    });

    test('toFormattedDate 扩展方法', () {
      final date = DateTime(2024, 1, 15);
      final result = date.toFormattedDate();
      expect(result, contains('2024'));
    });

    test('toRelativeTime 扩展方法', () {
      final now = DateTime.now();
      final result = now.toRelativeTime();
      expect(result, '刚刚');
    });
  });

  group('语言切换', () {
    test('切换到英文', () {
      service.setLocale(AppLanguage.en);
      expect(service.currentLocale, AppLanguage.en);
      expect(service.defaultCurrencyCode, 'USD');
    });

    test('切换到日文', () {
      service.setLocale(AppLanguage.ja);
      expect(service.currentLocale, AppLanguage.ja);
      expect(service.defaultCurrencyCode, 'JPY');
    });

    test('切换到韩文', () {
      service.setLocale(AppLanguage.ko);
      expect(service.currentLocale, AppLanguage.ko);
      expect(service.defaultCurrencyCode, 'KRW');
    });
  });

  group('货币信息查询', () {
    test('获取支持的货币列表', () {
      final currencies = service.supportedCurrencies;
      expect(currencies, isNotEmpty);
      expect(currencies.any((c) => c.code == 'CNY'), isTrue);
      expect(currencies.any((c) => c.code == 'USD'), isTrue);
    });

    test('获取货币信息', () {
      final cny = service.getCurrencyInfo('CNY');
      expect(cny, isNotNull);
      expect(cny!.symbol, '¥');
      expect(cny.decimalDigits, 2);
    });

    test('获取不存在的货币返回null', () {
      final result = service.getCurrencyInfo('INVALID');
      expect(result, isNull);
    });
  });
}
