import '../models/category.dart';
import '../services/category_localization_service.dart';

/// Category 模型扩展
///
/// 提供本地化相关的扩展方法，将服务依赖从模型中分离出来。
extension CategoryLocalizationExtension on Category {
  /// 获取本地化的分类名称
  ///
  /// 根据设备区域自动选择语言（中文/英文/日文/韩文）。
  /// 自定义分类使用原始名称。
  String get localizedName {
    if (isCustom) return name;
    return CategoryLocalizationService.instance.getCategoryName(id);
  }

  /// 获取指定语言的分类名称
  String getNameForLocale(String locale) {
    if (isCustom) return name;
    return CategoryLocalizationService.instance.getCategoryNameForLocale(id, locale);
  }
}
