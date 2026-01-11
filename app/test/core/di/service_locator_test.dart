import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/core/di/service_locator.dart';
import 'package:ai_bookkeeping/core/contracts/i_database_service.dart';
import 'package:ai_bookkeeping/core/contracts/i_http_service.dart';
import 'package:ai_bookkeeping/core/contracts/i_secure_storage_service.dart';

/// 模拟安全存储服务
class MockSecureStorageService implements ISecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> saveAuthToken(String token) async => _storage['auth_token'] = token;
  @override
  Future<String?> getAuthToken() async => _storage['auth_token'];
  @override
  Future<void> deleteAuthToken() async => _storage.remove('auth_token');
  @override
  Future<void> saveRefreshToken(String token) async => _storage['refresh_token'] = token;
  @override
  Future<String?> getRefreshToken() async => _storage['refresh_token'];
  @override
  Future<void> deleteRefreshToken() async => _storage.remove('refresh_token');
  @override
  Future<void> saveUserId(String userId) async => _storage['user_id'] = userId;
  @override
  Future<String?> getUserId() async => _storage['user_id'];
  @override
  Future<void> saveApiKey(String key) async => _storage['api_key'] = key;
  @override
  Future<String?> getApiKey() async => _storage['api_key'];
  @override
  Future<void> saveEncryptionKey(String key) async => _storage['encryption_key'] = key;
  @override
  Future<String?> getEncryptionKey() async => _storage['encryption_key'];
  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
  @override
  Future<String?> read(String key) async => _storage[key];
  @override
  Future<void> delete(String key) async => _storage.remove(key);
  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);
  @override
  Future<void> writeJson(String key, Map<String, dynamic> json) async {
    _storage[key] = json.toString();
  }
  @override
  Future<Map<String, dynamic>?> readJson(String key) async => null;
  @override
  Future<void> deleteAll() async => _storage.clear();
  @override
  Future<Map<String, String>> readAll() async => Map.from(_storage);
  @override
  Future<void> clearOnLogout() async {
    _storage.remove('auth_token');
    _storage.remove('refresh_token');
    _storage.remove('user_id');
  }
}

void main() {
  group('ServiceLocator', () {
    setUp(() async {
      // 每个测试前重置服务定位器
      await resetServiceLocator();
    });

    tearDown(() async {
      // 清理
      await resetServiceLocator();
    });

    test('initServiceLocator 应该成功初始化', () async {
      expect(isServiceLocatorInitialized, isFalse);

      await initServiceLocator();

      expect(isServiceLocatorInitialized, isTrue);
    });

    test('重复调用 initServiceLocator 应该安全', () async {
      await initServiceLocator();
      await initServiceLocator(); // 不应抛出异常

      expect(isServiceLocatorInitialized, isTrue);
    });

    test('resetServiceLocator 应该重置初始化状态', () async {
      await initServiceLocator();
      expect(isServiceLocatorInitialized, isTrue);

      await resetServiceLocator();
      expect(isServiceLocatorInitialized, isFalse);
    });

    test('注册的服务应该可以通过 sl 获取', () async {
      await initServiceLocator();

      // 验证基础设施服务已注册
      expect(sl.isRegistered<IDatabaseService>(), isTrue);
      expect(sl.isRegistered<IHttpService>(), isTrue);
      expect(sl.isRegistered<ISecureStorageService>(), isTrue);
    });

    test('registerMockService 应该替换已注册的服务', () async {
      await initServiceLocator();

      // 创建模拟服务
      final mockStorage = MockSecureStorageService();

      // 注册模拟服务
      registerMockService<ISecureStorageService>(mockStorage);

      // 验证获取的是模拟服务
      final service = sl<ISecureStorageService>();
      expect(service, equals(mockStorage));
    });

    test('模拟服务应该正常工作', () async {
      await initServiceLocator();

      // 创建并注册模拟服务
      final mockStorage = MockSecureStorageService();
      registerMockService<ISecureStorageService>(mockStorage);

      // 使用模拟服务
      final service = sl<ISecureStorageService>();
      await service.saveAuthToken('test-token');

      final token = await service.getAuthToken();
      expect(token, equals('test-token'));
    });

    test('sl 获取未注册的服务应该抛出异常', () async {
      // 不初始化，直接尝试获取服务
      expect(
        () => sl<ISecureStorageService>(),
        throwsA(isA<Error>()),
      );
    });

    test('懒加载服务应该在首次访问时创建', () async {
      await initServiceLocator();

      // 服务应该在首次访问时创建
      // 这个测试验证 registerLazySingleton 正确工作
      final service1 = sl<ISecureStorageService>();
      final service2 = sl<ISecureStorageService>();

      // 应该是同一个实例
      expect(identical(service1, service2), isTrue);
    });
  });

  group('MockSecureStorageService', () {
    late MockSecureStorageService mockService;

    setUp(() {
      mockService = MockSecureStorageService();
    });

    test('应该正确存储和读取 Token', () async {
      await mockService.saveAuthToken('auth-123');
      await mockService.saveRefreshToken('refresh-456');

      expect(await mockService.getAuthToken(), equals('auth-123'));
      expect(await mockService.getRefreshToken(), equals('refresh-456'));
    });

    test('clearOnLogout 应该清除敏感数据', () async {
      await mockService.saveAuthToken('auth-123');
      await mockService.saveRefreshToken('refresh-456');
      await mockService.saveUserId('user-789');
      await mockService.write('other-key', 'other-value');

      await mockService.clearOnLogout();

      expect(await mockService.getAuthToken(), isNull);
      expect(await mockService.getRefreshToken(), isNull);
      expect(await mockService.getUserId(), isNull);
      // 其他数据应该保留
      expect(await mockService.read('other-key'), equals('other-value'));
    });

    test('containsKey 应该正确检测键存在', () async {
      expect(await mockService.containsKey('test-key'), isFalse);

      await mockService.write('test-key', 'test-value');

      expect(await mockService.containsKey('test-key'), isTrue);
    });

    test('deleteAll 应该清除所有数据', () async {
      await mockService.write('key1', 'value1');
      await mockService.write('key2', 'value2');

      await mockService.deleteAll();

      final all = await mockService.readAll();
      expect(all.isEmpty, isTrue);
    });
  });
}
