import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync.dart' as sync_models;
import 'server_sync_service.dart';
import 'http_service.dart';
import 'database_service.dart';

/// 自动同步服务
///
/// 功能：
/// 1. 自动触发同步（数据变更后）
/// 2. 网络重试（指数退避策略）
/// 3. 行为数据上传（始终开启）
class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  final ServerSyncService _serverSync = ServerSyncService();
  final HttpService _http = HttpService();
  final DatabaseService _db = DatabaseService();

  // 同步状态
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isOnline = true;
  sync_models.SyncSettings _settings = const sync_models.SyncSettings();

  // 重试配置
  static const int _maxRetries = 5;
  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);
  int _currentRetryCount = 0;
  Timer? _retryTimer;

  // 同步防抖
  Timer? _syncDebounceTimer;
  static const Duration _syncDebounceDelay = Duration(seconds: 2);

  // 网络监听
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // 同步状态流
  final _syncStatusController = StreamController<sync_models.SyncStatus>.broadcast();
  Stream<sync_models.SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 加载设置
    await _loadSettings();

    // 检查网络状态
    await _checkConnectivity();

    // 监听网络变化
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    _isInitialized = true;

    // 如果在线且有待同步数据，立即触发同步
    if (_isOnline && _settings.enabled && _settings.syncPrivateData) {
      _scheduleSyncWithDebounce();
    }
  }

  /// 加载同步设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('sync_settings');
      if (settingsJson != null) {
        // 简单解析，实际应用中使用 JSON
        _settings = const sync_models.SyncSettings();
      }
    } catch (e) {
      _settings = const sync_models.SyncSettings();
    }
  }

  /// 更新同步设置
  Future<void> updateSettings(sync_models.SyncSettings settings) async {
    _settings = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_settings', settings.toMap().toString());
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 检查网络连接
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
  }

  /// 网络状态变化回调
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;

    // 网络恢复时，触发同步
    if (!wasOnline && _isOnline) {
      _currentRetryCount = 0;  // 重置重试计数
      _scheduleSyncWithDebounce();
    }
  }

  /// 标记数据已更改，触发同步
  ///
  /// 这个方法应该在 CRUD 操作后调用
  void markDataChanged() {
    if (!_settings.enabled || !_settings.syncPrivateData) return;
    _scheduleSyncWithDebounce();
  }

  /// 防抖触发同步
  void _scheduleSyncWithDebounce() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounceDelay, () {
      performSync();
    });
  }

  /// 执行同步
  Future<SyncResult?> performSync({bool force = false}) async {
    // 检查是否可以同步
    if (_isSyncing) return null;
    if (!_isOnline && !force) {
      _syncStatusController.add(sync_models.SyncStatus.offline);
      return null;
    }
    if (!_settings.enabled && !force) return null;
    if (!_settings.syncPrivateData && !force) return null;

    _isSyncing = true;
    _syncStatusController.add(sync_models.SyncStatus.syncing);

    try {
      final result = await _serverSync.performSync();

      if (result.success) {
        _currentRetryCount = 0;
        _retryTimer?.cancel();
        _syncStatusController.add(sync_models.SyncStatus.success);
        return result;
      } else {
        // 同步失败，安排重试
        _scheduleRetry();
        _syncStatusController.add(sync_models.SyncStatus.failed);
        return result;
      }
    } catch (e) {
      // 同步异常，安排重试
      _scheduleRetry();
      _syncStatusController.add(sync_models.SyncStatus.failed);
      return SyncResult(
        success: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// 安排重试（指数退避）
  void _scheduleRetry() {
    if (_currentRetryCount >= _maxRetries) {
      // 达到最大重试次数，等待网络恢复或手动触发
      return;
    }

    _retryTimer?.cancel();

    // 计算延迟：5s, 10s, 20s, 40s, 80s (最大5分钟)
    final delay = Duration(
      milliseconds: (_initialRetryDelay.inMilliseconds * (1 << _currentRetryCount))
          .clamp(0, _maxRetryDelay.inMilliseconds),
    );

    _currentRetryCount++;

    _retryTimer = Timer(delay, () {
      if (_isOnline) {
        performSync();
      }
    });
  }

  /// 上传行为数据（始终开启，不受隐私设置影响）
  ///
  /// 行为数据包括：
  /// - 应用启动/退出
  /// - 功能使用频率
  /// - 错误日志
  Future<void> uploadBehaviorData(Map<String, dynamic> data) async {
    if (!_isOnline) return;

    try {
      await _http.post('/analytics/behavior', data: {
        'events': [data],
        'timestamp': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
      });
    } catch (e) {
      // 行为数据上传失败不重试，静默失败
    }
  }

  /// 记录用户行为事件
  Future<void> trackEvent(String eventName, {Map<String, dynamic>? properties}) async {
    await uploadBehaviorData({
      'event': eventName,
      'properties': properties ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 强制同步（忽略设置）
  Future<SyncResult?> forceSync() async {
    return performSync(force: true);
  }

  /// 获取待同步数量
  Future<int> getPendingSyncCount() async {
    try {
      final stats = await _db.getSyncStatistics();
      return stats['pending'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 获取当前设置
  sync_models.SyncSettings get settings => _settings;

  /// 是否在线
  bool get isOnline => _isOnline;

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  /// 释放资源
  void dispose() {
    _syncDebounceTimer?.cancel();
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
}
