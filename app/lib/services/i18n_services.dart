/// 国际化服务统一导出
///
/// 包含应用所需的所有国际化相关服务
///
/// 使用方式:
/// ```dart
/// import 'package:ai_bookkeeping/services/i18n_services.dart';
///
/// // 格式化货币
/// final formatted = LocaleFormatService.instance.formatCurrency(1234.56);
///
/// // 格式化日期
/// final dateStr = LocaleFormatService.instance.formatDate(DateTime.now());
///
/// // 检查 RTL
/// final isRTL = context.isRTL;
///
/// // 检测国际化目标达成
/// final report = I18nGoalDetectionService.instance.checkAllGoals();
/// ```
library;

export 'locale_format_service.dart';
export 'rtl_support_service.dart';
export 'translation_quality_service.dart';
export 'i18n_goal_detection_service.dart';
export 'category_localization_service.dart';
export 'account_localization_service.dart';
