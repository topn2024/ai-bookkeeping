import 'dart:async';

/// Mock 服务集合
///
/// 提供所有核心服务的 Mock 实现，用于单元测试和 Widget 测试
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== Mock 数据库服务 ====================

/// Mock 数据库服务
class MockDatabaseService {
  final Map<String, Map<String, dynamic>> _transactions = {};
  final Map<String, Map<String, dynamic>> _accounts = {};
  final Map<String, Map<String, dynamic>> _categories = {};
  final Map<String, Map<String, dynamic>> _budgets = {};

  /// 重置所有数据
  void reset() {
    _transactions.clear();
    _accounts.clear();
    _categories.clear();
    _budgets.clear();
  }

  // 交易操作
  Future<void> insertTransaction(Map<String, dynamic> transaction) async {
    _transactions[transaction['id']] = transaction;
  }

  Future<Map<String, dynamic>?> getTransaction(String id) async {
    return _transactions[id];
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    return _transactions.values.toList();
  }

  Future<void> updateTransaction(Map<String, dynamic> transaction) async {
    _transactions[transaction['id']] = transaction;
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.remove(id);
  }

  // 账户操作
  Future<void> insertAccount(Map<String, dynamic> account) async {
    _accounts[account['id']] = account;
  }

  Future<Map<String, dynamic>?> getAccount(String id) async {
    return _accounts[id];
  }

  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    return _accounts.values.toList();
  }

  Future<void> updateAccount(Map<String, dynamic> account) async {
    _accounts[account['id']] = account;
  }

  Future<void> deleteAccount(String id) async {
    _accounts.remove(id);
  }

  // 分类操作
  Future<void> insertCategory(Map<String, dynamic> category) async {
    _categories[category['id']] = category;
  }

  Future<Map<String, dynamic>?> getCategory(String id) async {
    return _categories[id];
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    return _categories.values.toList();
  }

  // 预算操作
  Future<void> insertBudget(Map<String, dynamic> budget) async {
    _budgets[budget['id']] = budget;
  }

  Future<Map<String, dynamic>?> getBudget(String id) async {
    return _budgets[id];
  }

  Future<List<Map<String, dynamic>>> getAllBudgets() async {
    return _budgets.values.toList();
  }
}

// ==================== Mock HTTP 服务 ====================

/// Mock HTTP 响应
class MockHttpResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  final Map<String, String> headers;
  final Duration? delay;

  MockHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
    this.delay,
  });

  factory MockHttpResponse.success(Map<String, dynamic> body) =>
      MockHttpResponse(statusCode: 200, body: body);

  factory MockHttpResponse.error(int statusCode, String message) =>
      MockHttpResponse(statusCode: statusCode, body: {'error': message});

  factory MockHttpResponse.notFound() =>
      MockHttpResponse.error(404, 'Not found');

  factory MockHttpResponse.serverError() =>
      MockHttpResponse.error(500, 'Internal server error');
}

/// Mock HTTP 服务
class MockHttpService {
  final Map<String, MockHttpResponse> _responses = {};
  final List<Map<String, dynamic>> _requestHistory = [];

  bool _shouldFail = false;
  Duration _defaultDelay = Duration.zero;

  /// 设置 Mock 响应
  void setResponse(String endpoint, MockHttpResponse response) {
    _responses[endpoint] = response;
  }

  /// 设置默认延迟
  void setDefaultDelay(Duration delay) {
    _defaultDelay = delay;
  }

  /// 设置是否失败
  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  /// 获取请求历史
  List<Map<String, dynamic>> get requestHistory => List.unmodifiable(_requestHistory);

  /// 清除请求历史
  void clearHistory() {
    _requestHistory.clear();
  }

  /// 重置
  void reset() {
    _responses.clear();
    _requestHistory.clear();
    _shouldFail = false;
    _defaultDelay = Duration.zero;
  }

  /// 模拟 GET 请求
  Future<MockHttpResponse> get(String endpoint, {Map<String, String>? headers}) async {
    return _handleRequest('GET', endpoint, headers: headers);
  }

  /// 模拟 POST 请求
  Future<MockHttpResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _handleRequest('POST', endpoint, body: body, headers: headers);
  }

  /// 模拟 PUT 请求
  Future<MockHttpResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _handleRequest('PUT', endpoint, body: body, headers: headers);
  }

  /// 模拟 DELETE 请求
  Future<MockHttpResponse> delete(String endpoint, {Map<String, String>? headers}) async {
    return _handleRequest('DELETE', endpoint, headers: headers);
  }

  Future<MockHttpResponse> _handleRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    // 记录请求
    _requestHistory.add({
      'method': method,
      'endpoint': endpoint,
      'body': body,
      'headers': headers,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 检查是否应该失败
    if (_shouldFail) {
      throw Exception('Mock network failure');
    }

    // 获取响应
    final response = _responses[endpoint] ?? MockHttpResponse.notFound();

    // 应用延迟
    final delay = response.delay ?? _defaultDelay;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    return response;
  }
}

// ==================== Mock 安全存储服务 ====================

/// Mock 安全存储服务
class MockSecureStorageService {
  final Map<String, String> _storage = {};

  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  Future<String?> read(String key) async {
    return _storage[key];
  }

  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  Future<void> deleteAll() async {
    _storage.clear();
  }

  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }

  void reset() {
    _storage.clear();
  }
}

// ==================== Mock AI 服务 ====================

/// Mock AI 服务
class MockAIService {
  final Map<String, Map<String, dynamic>> _recognitionResults = {};
  bool _shouldFail = false;
  Duration _delay = const Duration(milliseconds: 100);

  /// 设置识别结果
  void setRecognitionResult(String input, Map<String, dynamic> result) {
    _recognitionResults[input] = result;
  }

  /// 设置是否失败
  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  /// 设置延迟
  void setDelay(Duration delay) {
    _delay = delay;
  }

  /// 识别交易
  Future<Map<String, dynamic>> recognizeTransaction(String input) async {
    await Future.delayed(_delay);

    if (_shouldFail) {
      throw Exception('AI recognition failed');
    }

    return _recognitionResults[input] ?? {
      'type': 'expense',
      'amount': 100.0,
      'category': 'other',
      'description': input,
      'confidence': 0.8,
    };
  }

  /// 分类建议
  Future<List<String>> suggestCategories(String description) async {
    await Future.delayed(_delay);

    if (_shouldFail) {
      throw Exception('AI suggestion failed');
    }

    return ['餐饮', '交通', '购物', '其他'];
  }

  void reset() {
    _recognitionResults.clear();
    _shouldFail = false;
    _delay = const Duration(milliseconds: 100);
  }
}

// ==================== Mock 同步服务 ====================

/// Mock 同步服务
class MockSyncService {
  bool _isSyncing = false;
  bool _shouldFail = false;
  DateTime? _lastSyncTime;
  final List<String> _syncedIds = [];

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<String> get syncedIds => List.unmodifiable(_syncedIds);

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  Future<void> sync() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      if (_shouldFail) {
        throw Exception('Sync failed');
      }

      _lastSyncTime = DateTime.now();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncItem(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (_shouldFail) {
      throw Exception('Sync item failed');
    }

    _syncedIds.add(id);
  }

  void reset() {
    _isSyncing = false;
    _shouldFail = false;
    _lastSyncTime = null;
    _syncedIds.clear();
  }
}

// ==================== Mock 通知服务 ====================

/// Mock 通知
class MockNotification {
  final String id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final Map<String, dynamic>? payload;

  MockNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.payload,
  });
}

/// Mock 通知服务
class MockNotificationService {
  final List<MockNotification> _notifications = [];
  final List<MockNotification> _shownNotifications = [];

  List<MockNotification> get scheduledNotifications =>
      List.unmodifiable(_notifications);
  List<MockNotification> get shownNotifications =>
      List.unmodifiable(_shownNotifications);

  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? payload,
  }) async {
    _notifications.add(MockNotification(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      payload: payload,
    ));
  }

  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    _shownNotifications.add(MockNotification(
      id: id,
      title: title,
      body: body,
      scheduledTime: DateTime.now(),
      payload: payload,
    ));
  }

  Future<void> cancelNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
  }

  Future<void> cancelAllNotifications() async {
    _notifications.clear();
  }

  void reset() {
    _notifications.clear();
    _shownNotifications.clear();
  }
}

// ==================== Mock 分析服务 ====================

/// Mock 分析事件
class MockAnalyticsEvent {
  final String name;
  final Map<String, dynamic>? parameters;
  final DateTime timestamp;

  MockAnalyticsEvent({
    required this.name,
    this.parameters,
    required this.timestamp,
  });
}

/// Mock 分析服务
class MockAnalyticsService {
  final List<MockAnalyticsEvent> _events = [];
  String? _userId;
  final Map<String, dynamic> _userProperties = {};

  List<MockAnalyticsEvent> get events => List.unmodifiable(_events);
  String? get userId => _userId;
  Map<String, dynamic> get userProperties => Map.unmodifiable(_userProperties);

  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    _events.add(MockAnalyticsEvent(
      name: name,
      parameters: parameters,
      timestamp: DateTime.now(),
    ));
  }

  void setUserId(String? userId) {
    _userId = userId;
  }

  void setUserProperty(String name, dynamic value) {
    _userProperties[name] = value;
  }

  /// 获取特定事件
  List<MockAnalyticsEvent> getEventsByName(String name) {
    return _events.where((e) => e.name == name).toList();
  }

  /// 验证事件是否被记录
  bool hasEvent(String name, {Map<String, dynamic>? parameters}) {
    return _events.any((e) {
      if (e.name != name) return false;
      if (parameters != null) {
        for (final entry in parameters.entries) {
          if (e.parameters?[entry.key] != entry.value) return false;
        }
      }
      return true;
    });
  }

  void reset() {
    _events.clear();
    _userId = null;
    _userProperties.clear();
  }
}

// ==================== 测试容器 ====================

/// 测试服务容器
class TestServiceContainer {
  final mockDatabase = MockDatabaseService();
  final mockHttp = MockHttpService();
  final mockSecureStorage = MockSecureStorageService();
  final mockAI = MockAIService();
  final mockSync = MockSyncService();
  final mockNotification = MockNotificationService();
  final mockAnalytics = MockAnalyticsService();

  /// 重置所有服务
  void resetAll() {
    mockDatabase.reset();
    mockHttp.reset();
    mockSecureStorage.reset();
    mockAI.reset();
    mockSync.reset();
    mockNotification.reset();
    mockAnalytics.reset();
  }

  /// 设置所有服务为失败模式
  void setAllToFail(bool shouldFail) {
    mockHttp.setShouldFail(shouldFail);
    mockAI.setShouldFail(shouldFail);
    mockSync.setShouldFail(shouldFail);
  }
}

/// 全局测试容器
final testContainer = TestServiceContainer();
