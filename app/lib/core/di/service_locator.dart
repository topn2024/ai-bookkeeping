/// 服务定位器 - 管理应用程序的依赖注入
///
/// 使用 get_it 包实现服务定位器模式，支持：
/// - 单例服务注册
/// - 工厂服务注册
/// - 懒加载服务
/// - 服务替换（用于测试）
library;

import 'package:get_it/get_it.dart';

import '../contracts/i_database_service.dart';
import '../contracts/i_http_service.dart';
import '../contracts/i_secure_storage_service.dart';
import '../../services/database_service.dart';
import '../../services/http_service.dart';
import '../../services/secure_storage_service.dart';
import '../../repositories/contracts/contracts.dart';
import '../../repositories/impl/impl.dart';

/// 全局服务定位器实例
final sl = GetIt.instance;

/// 服务定位器是否已初始化
bool _isInitialized = false;

/// 检查服务定位器是否已初始化
bool get isServiceLocatorInitialized => _isInitialized;

/// 初始化服务定位器
///
/// 注册所有核心服务到服务定位器。
/// 应在应用启动时调用一次。
///
/// 示例:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initServiceLocator();
///   runApp(MyApp());
/// }
/// ```
Future<void> initServiceLocator() async {
  if (_isInitialized) {
    return;
  }

  // 注册基础设施层服务
  await _registerInfrastructureServices();

  // 注册数据访问层 (Repository)
  _registerRepositories();

  _isInitialized = true;
}

/// 注册基础设施层服务
Future<void> _registerInfrastructureServices() async {
  // 数据库服务
  sl.registerLazySingleton<IDatabaseService>(
    () => DatabaseService(),
  );

  // HTTP 服务
  sl.registerLazySingleton<IHttpService>(
    () => HttpService(),
  );

  // 安全存储服务
  sl.registerLazySingleton<ISecureStorageService>(
    () => SecureStorageService(),
  );
}

/// 注册数据访问层 (Repository)
void _registerRepositories() {
  // 交易 Repository
  sl.registerLazySingleton<ITransactionRepository>(
    () => TransactionRepository(sl<IDatabaseService>()),
  );

  // 账户 Repository
  sl.registerLazySingleton<IAccountRepository>(
    () => AccountRepository(sl<IDatabaseService>()),
  );

  // 预算 Repository
  sl.registerLazySingleton<IBudgetRepository>(
    () => BudgetRepository(sl<IDatabaseService>()),
  );

  // 分类 Repository
  sl.registerLazySingleton<ICategoryRepository>(
    () => CategoryRepository(sl<IDatabaseService>()),
  );
}

/// 重置服务定位器（仅用于测试）
///
/// 清除所有已注册的服务，允许重新初始化。
/// 警告：仅在测试环境中使用。
Future<void> resetServiceLocator() async {
  await sl.reset();
  _isInitialized = false;
}

/// 注册测试用的模拟服务
///
/// 用于单元测试时替换真实服务实现。
///
/// 示例:
/// ```dart
/// setUp(() async {
///   await resetServiceLocator();
///   registerMockService<IDatabaseService>(MockDatabaseService());
/// });
/// ```
void registerMockService<T extends Object>(T mockService) {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(mockService);
}
