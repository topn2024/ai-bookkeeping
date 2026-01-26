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

// 隐私服务
import '../../services/privacy/differential_privacy/privacy_budget_manager.dart';
import '../../services/privacy/differential_privacy/differential_privacy_engine.dart';
import '../../services/privacy/anomaly_detection/malicious_user_tracker.dart';
import '../../services/privacy/anomaly_detection/anomaly_detector.dart';

// 学习服务
import '../../services/learning/voice_intent_learning_service.dart';
import '../../services/learning/anomaly_learning_service.dart';
import '../../services/learning/database_data_stores.dart';
import '../../services/import/category_learning_helper.dart';

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

  // 注册隐私服务
  _registerPrivacyServices();

  // 注册学习服务
  _registerLearningServices();

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

/// 注册隐私服务
void _registerPrivacyServices() {
  // 隐私预算管理器
  sl.registerLazySingleton<PrivacyBudgetManager>(
    () => PrivacyBudgetManager(),
  );

  // 差分隐私引擎
  sl.registerLazySingleton<DifferentialPrivacyEngine>(
    () => DifferentialPrivacyEngine(
      budgetManager: sl<PrivacyBudgetManager>(),
    ),
  );

  // 恶意用户追踪器
  sl.registerLazySingleton<MaliciousUserTracker>(
    () => MaliciousUserTracker(),
  );

  // 异常检测器
  sl.registerLazySingleton<AnomalyDetector>(
    () => AnomalyDetector(
      userTracker: sl<MaliciousUserTracker>(),
    ),
  );
}

/// 注册学习服务
void _registerLearningServices() {
  // 数据库数据存储
  sl.registerLazySingleton<DatabaseIntentDataStore>(
    () => DatabaseIntentDataStore(),
  );

  sl.registerLazySingleton<DatabaseAnomalyDataStore>(
    () => DatabaseAnomalyDataStore(),
  );

  // 意图学习服务
  sl.registerLazySingleton<VoiceIntentLearningService>(
    () => VoiceIntentLearningService(
      dataStore: sl<DatabaseIntentDataStore>(),
    ),
  );

  // 异常学习服务
  sl.registerLazySingleton<AnomalyLearningService>(
    () => AnomalyLearningService(
      dataStore: sl<DatabaseAnomalyDataStore>(),
    ),
  );

  // 分类学习辅助（单例，已有实现）
  sl.registerLazySingleton<CategoryLearningHelper>(
    () => CategoryLearningHelper.instance,
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
