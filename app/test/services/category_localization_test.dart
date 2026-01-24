import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/models/category.dart';
import 'package:ai_bookkeeping/services/category_localization_service.dart';

void main() {
  group('Category Localization - 容错性测试', () {
    late CategoryLocalizationService service;

    setUp(() {
      service = CategoryLocalizationService.instance;
      // 明确设置为中文
      service.setLocale('zh');
    });

    test('应该正确处理标准的小写分类ID', () {
      final category = DefaultCategories.findById('food');
      expect(category, isNotNull);
      expect(category!.id, 'food');

      final localizedName = service.getCategoryName('food');
      expect(localizedName, '餐饮');
    });

    test('应该正确处理大写的分类ID', () {
      final category = DefaultCategories.findById('Food');
      expect(category, isNotNull);
      expect(category!.id, 'food');

      final localizedName = service.getCategoryName('Food');
      expect(localizedName, '餐饮');
    });

    test('应该正确处理混合大小写的分类ID', () {
      final category = DefaultCategories.findById('FoOd');
      expect(category, isNotNull);
      expect(category!.id, 'food');

      final localizedName = service.getCategoryName('FoOd');
      expect(localizedName, '餐饮');
    });

    test('应该正确处理英文全称', () {
      final category = DefaultCategories.findById('Food & Dining');
      expect(category, isNotNull);
      expect(category!.id, 'food');

      final localizedName = service.getCategoryName('Food & Dining');
      expect(localizedName, '餐饮');
    });

    test('应该正确处理中文名称', () {
      final category = DefaultCategories.findById('餐饮');
      expect(category, isNotNull);
      expect(category!.id, 'food');

      final localizedName = service.getCategoryName('餐饮');
      expect(localizedName, '餐饮');
    });

    test('应该正确处理 Transportation', () {
      final category = DefaultCategories.findById('Transportation');
      expect(category, isNotNull);
      expect(category!.id, 'transport');

      final localizedName = service.getCategoryName('Transportation');
      expect(localizedName, '交通');
    });

    test('应该正确处理 Shopping', () {
      final category = DefaultCategories.findById('Shopping');
      expect(category, isNotNull);
      expect(category!.id, 'shopping');

      final localizedName = service.getCategoryName('Shopping');
      expect(localizedName, '购物');
    });

    test('应该正确处理 Entertainment', () {
      final category = DefaultCategories.findById('Entertainment');
      expect(category, isNotNull);
      expect(category!.id, 'entertainment');

      final localizedName = service.getCategoryName('Entertainment');
      expect(localizedName, '娱乐');
    });

    test('应该正确处理 Medical/Healthcare', () {
      final category1 = DefaultCategories.findById('Medical');
      expect(category1, isNotNull);
      expect(category1!.id, 'medical');

      final category2 = DefaultCategories.findById('Healthcare');
      expect(category2, isNotNull);
      expect(category2!.id, 'medical');

      final localizedName = service.getCategoryName('Healthcare');
      expect(localizedName, '医疗');
    });

    test('应该正确处理收入分类', () {
      final category = DefaultCategories.findById('Salary');
      expect(category, isNotNull);
      expect(category!.id, 'salary');

      final localizedName = service.getCategoryName('Salary');
      expect(localizedName, '工资');
    });

    test('应该正确处理 Other', () {
      // 'Other' 应该映射到 'other_expense'
      final category = DefaultCategories.findById('Other');
      expect(category, isNotNull);
      expect(category!.id, 'other_expense');

      final localizedName = service.getCategoryName('Other');
      expect(localizedName, '其他');
    });

    test('应该正确处理不存在的分类', () {
      final category = DefaultCategories.findById('NonExistentCategory');
      // 找不到分类时返回 null
      expect(category, isNull);

      // 本地化服务应该返回原始值或美化后的值
      final localizedName = service.getCategoryName('NonExistentCategory');
      // 至少不应该崩溃
      expect(localizedName, isNotNull);
    });

    test('应该正确处理空字符串', () {
      final category = DefaultCategories.findById('');
      expect(category, isNull);

      final localizedName = service.getCategoryName('');
      expect(localizedName, '');
    });

    test('应该正确处理带空格的分类ID', () {
      final category = DefaultCategories.findById(' food ');
      expect(category, isNotNull);
      expect(category!.id, 'food');

      final localizedName = service.getCategoryName(' food ');
      expect(localizedName, '餐饮');
    });
  });

  group('Category Localization - 多语言测试', () {
    late CategoryLocalizationService service;

    setUp(() {
      service = CategoryLocalizationService.instance;
    });

    test('应该正确返回英文名称', () {
      service.setLocale('en');
      final localizedName = service.getCategoryName('food');
      expect(localizedName, 'Food & Dining');
    });

    test('应该正确返回中文名称', () {
      service.setLocale('zh');
      final localizedName = service.getCategoryName('food');
      expect(localizedName, '餐饮');
    });

    test('应该正确返回日文名称', () {
      service.setLocale('ja');
      final localizedName = service.getCategoryName('food');
      expect(localizedName, '食費');
    });

    test('应该正确返回韩文名称', () {
      service.setLocale('ko');
      final localizedName = service.getCategoryName('food');
      expect(localizedName, '식비');
    });
  });

  group('Category findByName - 测试', () {
    test('应该通过中文名称查找分类', () {
      final category = DefaultCategories.findByName('餐饮');
      expect(category, isNotNull);
      expect(category!.id, 'food');
    });

    test('应该通过英文名称查找分类', () {
      final category = DefaultCategories.findByName('Food & Dining');
      expect(category, isNotNull);
      expect(category!.id, 'food');
    });

    test('应该通过英文名称查找分类（大小写不敏感）', () {
      final category = DefaultCategories.findByName('FOOD');
      expect(category, isNotNull);
      expect(category!.id, 'food');
    });
  });
}
