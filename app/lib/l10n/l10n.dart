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
import 'generated/app_localizations_zh.dart';

export 'generated/app_localizations.dart';

/// BuildContext 扩展，提供便捷的本地化访问
extension L10nExtension on BuildContext {
  /// 获取当前语言的本地化字符串
  ///
  /// 用法: `context.l10n.appName`
  ///
  /// 注意：如果本地化尚未加载，将返回中文默认值
  S get l10n {
    final s = Localizations.of<S>(this, S);
    if (s != null) return s;
    // 本地化尚未加载时，返回中文默认实现
    return SZh();
  }
}
