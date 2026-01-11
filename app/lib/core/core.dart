// 核心模块导出
//
// 此文件导出所有核心功能模块，便于统一引用

// 基础设施
export 'api_client.dart';
export 'build_info.dart';
export 'config.dart';
export 'logger.dart';
export 'result.dart';
export 'summary.dart';

// 依赖注入
export 'di/service_locator.dart';

// 服务契约（接口）
export 'contracts/contracts.dart';

// 格式化服务
export 'formatting/formatting_service.dart';

// 基类
export 'base/base_localization_service.dart';
export 'base/base_voice_operation_service.dart';
