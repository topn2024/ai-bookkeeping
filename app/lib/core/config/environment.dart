import 'package:flutter/foundation.dart';

/// 应用运行环境
enum AppEnvironment {
  /// 开发环境
  development,

  /// 预发布环境
  staging,

  /// 生产环境
  production,
}

/// 环境配置
class EnvironmentConfig {
  /// 当前环境
  static AppEnvironment get current {
    // 通过编译时变量确定环境
    const envString = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'production',
    );

    switch (envString.toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.development;
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
      default:
        return AppEnvironment.production;
    }
  }

  /// 是否为开发环境
  static bool get isDevelopment => current == AppEnvironment.development;

  /// 是否为预发布环境
  static bool get isStaging => current == AppEnvironment.staging;

  /// 是否为生产环境
  static bool get isProduction => current == AppEnvironment.production;

  /// 是否启用调试日志
  static bool get enableDebugLogs => kDebugMode || isDevelopment;

  /// 是否启用详细错误信息
  static bool get showDetailedErrors => kDebugMode || isDevelopment;

  /// 环境名称（用于显示）
  static String get name {
    switch (current) {
      case AppEnvironment.development:
        return '开发环境';
      case AppEnvironment.staging:
        return '预发布环境';
      case AppEnvironment.production:
        return '生产环境';
    }
  }

  /// 环境简称
  static String get shortName {
    switch (current) {
      case AppEnvironment.development:
        return 'DEV';
      case AppEnvironment.staging:
        return 'STG';
      case AppEnvironment.production:
        return 'PROD';
    }
  }
}
