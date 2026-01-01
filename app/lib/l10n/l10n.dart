/// 统一的本地化访问入口
///
/// 使用方式:
/// ```dart
/// import 'package:ai_bookkeeping/l10n/l10n.dart';
///
/// // 在Widget中使用
/// Text(context.l10n.appName);
/// Text(context.l10n.save);
/// ```
library;

import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// BuildContext 扩展，提供便捷的本地化访问
extension L10nExtension on BuildContext {
  /// 获取当前语言的本地化字符串
  ///
  /// 用法: `context.l10n.appName`
  S get l10n => S.of(this);
}
