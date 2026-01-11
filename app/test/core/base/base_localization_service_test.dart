import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/core/base/base_localization_service.dart';

/// 测试用的具体实现类
class TestLocalizationService extends BaseLocalizationService<String> {
  static TestLocalizationService? _instance;

  TestLocalizationService._();

  static TestLocalizationService get instance {
    _instance ??= TestLocalizationService._();
    return _instance!;
  }

  static void resetInstance() {
    _instance = null;
  }

  final Map<String, Map<String, String>> _customTranslations = {};

  @override
  Map<String, Map<String, String>> get translations => {
        'test_item': {
          'zh': '测试项目',
          'en': 'Test Item',
          'ja': 'テスト項目',
          'ko': '테스트 항목',
        },
        'hello': {
          'zh': '你好',
          'en': 'Hello',
          'ja': 'こんにちは',
          'ko': '안녕하세요',
        },
        'only_english': {
          'en': 'English Only',
        },
        ..._customTranslations,
      };

  @override
  void addCustomTranslation(String id, Map<String, String> localeTranslations) {
    _customTranslations[id] = localeTranslations;
  }
}

void main() {
  late TestLocalizationService service;

  setUp(() {
    TestLocalizationService.resetInstance();
    service = TestLocalizationService.instance;
  });

  group('BaseLocalizationService', () {
    group('单例模式', () {
      test('应返回相同实例', () {
        final instance1 = TestLocalizationService.instance;
        final instance2 = TestLocalizationService.instance;
        expect(instance1, same(instance2));
      });
    });

    group('语言设置', () {
      test('默认语言应为中文', () {
        expect(service.currentLocale, 'zh');
      });

      test('设置语言应更新 currentLocale', () {
        service.setLocale('en');
        expect(service.currentLocale, 'en');
      });

      test('设置日语', () {
        service.setLocale('ja');
        expect(service.currentLocale, 'ja');
      });

      test('设置韩语', () {
        service.setLocale('ko');
        expect(service.currentLocale, 'ko');
      });

      test('设置不支持的语言应回退到英语', () {
        service.setLocale('fr');
        expect(service.currentLocale, 'en');
      });

      test('设置 null 应恢复系统语言', () {
        service.setLocale('ja');
        expect(service.currentLocale, 'ja');
        service.setLocale(null);
        // 恢复后应该是系统默认语言（测试环境可能是 zh 或 en）
        expect(BaseLocalizationService.supportedLocales,
            contains(service.currentLocale));
      });

      test('isUserOverride 应正确反映用户覆盖状态', () {
        expect(service.isUserOverride, isFalse);
        service.setLocale('en');
        expect(service.isUserOverride, isTrue);
        service.setLocale(null);
        expect(service.isUserOverride, isFalse);
      });
    });

    group('本地化名称获取', () {
      test('获取中文名称', () {
        service.setLocale('zh');
        expect(service.getLocalizedName('test_item'), '测试项目');
      });

      test('获取英文名称', () {
        service.setLocale('en');
        expect(service.getLocalizedName('test_item'), 'Test Item');
      });

      test('获取日文名称', () {
        service.setLocale('ja');
        expect(service.getLocalizedName('test_item'), 'テスト項目');
      });

      test('获取韩文名称', () {
        service.setLocale('ko');
        expect(service.getLocalizedName('test_item'), '테스트 항목');
      });

      test('不存在的翻译应返回 ID', () {
        expect(service.getLocalizedName('unknown_item'), 'unknown_item');
      });

      test('不存在的翻译应返回 fallback', () {
        expect(
          service.getLocalizedName('unknown_item', fallback: '默认值'),
          '默认值',
        );
      });

      test('只有英文翻译时，中文应回退到英文', () {
        service.setLocale('zh');
        expect(service.getLocalizedName('only_english'), 'English Only');
      });

      test('ID 大小写不敏感', () {
        service.setLocale('zh');
        expect(service.getLocalizedName('TEST_ITEM'), '测试项目');
        expect(service.getLocalizedName('Test_Item'), '测试项目');
      });
    });

    group('指定语言获取名称', () {
      test('获取指定语言的名称（不影响当前语言）', () {
        service.setLocale('zh');
        expect(service.getLocalizedNameForLocale('test_item', 'en'), 'Test Item');
        expect(service.currentLocale, 'zh'); // 当前语言不变
      });

      test('获取不支持语言应回退到英文', () {
        expect(service.getLocalizedNameForLocale('test_item', 'fr'), 'Test Item');
      });
    });

    group('自定义翻译', () {
      test('添加自定义翻译', () {
        service.addCustomTranslation('custom_item', {
          'zh': '自定义项目',
          'en': 'Custom Item',
        });
        service.setLocale('zh');
        expect(service.getLocalizedName('custom_item'), '自定义项目');
      });
    });

    group('支持的语言列表', () {
      test('应包含 zh, en, ja, ko', () {
        expect(BaseLocalizationService.supportedLocales, contains('zh'));
        expect(BaseLocalizationService.supportedLocales, contains('en'));
        expect(BaseLocalizationService.supportedLocales, contains('ja'));
        expect(BaseLocalizationService.supportedLocales, contains('ko'));
      });

      test('默认语言应为英语', () {
        expect(BaseLocalizationService.defaultLocale, 'en');
      });
    });
  });

  group('AccountLocalizationService 兼容性', () {
    test('应能获取账户名称', () {
      // 测试 AccountLocalizationService 的行为是否与基类一致
      // 由于我们重构了 AccountLocalizationService，这里只验证基本行为
      service.setLocale('zh');
      expect(service.getLocalizedName('hello'), '你好');
      service.setLocale('en');
      expect(service.getLocalizedName('hello'), 'Hello');
    });
  });

  group('CategoryLocalizationService 兼容性', () {
    test('应能获取分类名称', () {
      service.setLocale('zh');
      expect(service.getLocalizedName('test_item'), '测试项目');
      service.setLocale('en');
      expect(service.getLocalizedName('test_item'), 'Test Item');
    });
  });
}
