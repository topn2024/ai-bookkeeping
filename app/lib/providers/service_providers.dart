import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/contracts.dart';
import '../repositories/contracts/contracts.dart';

/// 数据库服务 Provider
///
/// 通过服务定位器获取数据库服务实例。
/// 用于依赖注入和测试替换。
final databaseServiceProvider = Provider<IDatabaseService>((ref) {
  return sl<IDatabaseService>();
});

/// HTTP 服务 Provider
///
/// 通过服务定位器获取 HTTP 服务实例。
final httpServiceProvider = Provider<IHttpService>((ref) {
  return sl<IHttpService>();
});

/// 安全存储服务 Provider
///
/// 通过服务定位器获取安全存储服务实例。
final secureStorageServiceProvider = Provider<ISecureStorageService>((ref) {
  return sl<ISecureStorageService>();
});

// ==================== Repository Provider ====================

/// 交易 Repository Provider
final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  return sl<ITransactionRepository>();
});

/// 账户 Repository Provider
final accountRepositoryProvider = Provider<IAccountRepository>((ref) {
  return sl<IAccountRepository>();
});

/// 预算 Repository Provider
final budgetRepositoryProvider = Provider<IBudgetRepository>((ref) {
  return sl<IBudgetRepository>();
});

/// 分类 Repository Provider
final categoryRepositoryProvider = Provider<ICategoryRepository>((ref) {
  return sl<ICategoryRepository>();
});

// ==================== 核心服务 Provider ====================
// 以下 Provider 将在服务实现完成后启用

// /// 交易服务 Provider
// final transactionServiceProvider = Provider<ITransactionService>((ref) {
//   return sl<ITransactionService>();
// });

// /// 账户服务 Provider
// final accountServiceProvider = Provider<IAccountService>((ref) {
//   return sl<IAccountService>();
// });

// /// 预算服务 Provider
// final budgetServiceProvider = Provider<IBudgetService>((ref) {
//   return sl<IBudgetService>();
// });

// /// 分类服务 Provider
// final categoryServiceProvider = Provider<ICategoryService>((ref) {
//   return sl<ICategoryService>();
// });

// /// AI 服务 Provider
// final aiServiceProvider = Provider<IAIService>((ref) {
//   return sl<IAIService>();
// });

// /// 同步服务 Provider
// final syncServiceProvider = Provider<ISyncService>((ref) {
//   return sl<ISyncService>();
// });
