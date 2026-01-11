import '../models/account.dart';
import '../services/account_localization_service.dart';

/// Account 模型扩展
///
/// 提供本地化相关的扩展方法，将服务依赖从模型中分离出来。
extension AccountLocalizationExtension on Account {
  /// 获取本地化的账户名称
  ///
  /// 对于系统默认账户，返回当前语言的翻译。
  /// 对于用户自定义账户，返回原始名称。
  String get localizedName {
    if (isCustom) return name;
    return AccountLocalizationService.instance.getAccountName(id, originalName: name);
  }

  /// 获取指定语言的账户名称
  String getNameForLocale(String locale) {
    if (isCustom) return name;
    return AccountLocalizationService.instance.getAccountNameForLocale(
      id,
      locale,
      originalName: name,
    );
  }
}
