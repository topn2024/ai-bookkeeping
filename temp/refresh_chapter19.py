# -*- coding: utf-8 -*-
"""
刷新第19章性能设计与优化
1. 修正图中章节引用错误（第16章→第19章）
2. 在19.8之前添加新的19.8资源消耗优化策略（原19.8-19.9顺延）
3. 添加详细的电量优化、后台任务、位置服务功耗控制等内容
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 修正图中章节引用错误 ==========
    ref_fixes = [
        # 修正"第16章 性能设计与优化"为"第19章"
        ('│                        第16章 性能设计与优化                              │',
         '│                        第19章 性能设计与优化                              │'),
    ]

    for old, new in ref_fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"Fix ref: 第16章 -> 第19章")
            changes += 1

    # ========== 修复2: 添加资源消耗优化策略章节 ==========
    # 在19.8之前插入新的资源消耗优化策略
    marker_19_8 = '### 19.8 性能优化检查清单'

    new_section_19_8 = '''### 19.8 资源消耗优化策略

#### 19.8.1 电量消耗优化架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        电量消耗优化架构                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【电量消耗分布】                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  消耗来源          │  典型占比  │  优化目标  │  优化策略             │ │
│  ├────────────────────┼────────────┼────────────┼��──────────────────────┤ │
│  │  屏幕显示          │  40%       │  -         │  系统控制，非应用范畴  │ │
│  │  网络通信          │  25%       │  减少50%   │  请求合并+压缩+缓存   │ │
│  │  位置服务          │  15%       │  减少70%   │  智能采样+地理围栏    │ │
│  │  CPU计算           │  10%       │  减少40%   │  异步+批处理+懒计算   │ │
│  │  后台唤醒          │  10%       │  减少80%   │  合并唤醒+延迟执行    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  【电量等级策略】                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                                                                     │ │
│  │   电量等级          策略调整                                         │ │
│  │   ═══════════════════════════════════════════════════════════════  │ │
│  ��                                                                     │ │
│  │   ┌─────────────┐   ┌─────────────────────────────────────────┐   │ │
│  │   │  高电量     │   │  正常模式: 所有功能正常运行              │   │ │
│  │   │  >50%      │   │  • 位置服务: 高精度持续更新               │   │ │
│  │   │             │   │  • 同步频率: 实时同步                     │   │ │
│  │   │             │   │  • AI服务: 完整功能                       │   │ │
│  │   └─────────────┘   └─────────────────────────────────────────┘   │ │
│  │                                                                     │ │
│  │   ┌─────────────┐   ┌─────────────────────────────────────────┐   │ │
│  │   │  中电量     │   │  节能模式: 非核心功能降级                 │   │ │
│  │   │  20%-50%   │   │  • 位置服务: 低精度+按需更新              │   │ │
│  │   │             │   │  • 同步频率: 每30分钟                     │   │ │
│  │   │             │   │  • AI服务: 本地优先                       │   │ │
│  │   └─────────────┘   └─────────────────────────────────────────┘   │ │
│  │                                                                     │ │
│  │   ┌─────────────┐   ┌─────────────────────────────────────────┐   │ │
│  │   │  低电量     │   │  省电模式: 仅保留核心功能                 │   │ │
│  │   │  <20%      │   │  • 位置服务: 关闭后台位置                 │   │ │
│  │   │             │   │  • 同步频率: 仅WiFi下同步                 │   │ │
│  │   │             │   │  • AI服务: 完全离线模式                   │   │ │
│  │   └─────────────┘   └────────────────────────────────────────��┘   │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
���                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 19.8.2 电量优化实现

```dart
/// 电量管理服务
class BatteryOptimizationService {
  static final BatteryOptimizationService _instance =
      BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  /// 电量等级
  BatteryLevel _currentLevel = BatteryLevel.high;

  /// 电量等级枚举
  enum BatteryLevel { high, medium, low, critical }

  /// 初始化电量监控
  Future<void> initialize() async {
    // 监听电量变化
    Battery().onBatteryStateChanged.listen(_onBatteryChanged);

    // 初始获取电量
    final level = await Battery().batteryLevel;
    _updateBatteryLevel(level);
  }

  /// 电量变化回调
  void _onBatteryChanged(BatteryState state) async {
    if (state == BatteryState.discharging) {
      final level = await Battery().batteryLevel;
      _updateBatteryLevel(level);
    }
  }

  /// 更新电量等级
  void _updateBatteryLevel(int percentage) {
    final newLevel = _calculateLevel(percentage);
    if (newLevel != _currentLevel) {
      _currentLevel = newLevel;
      _applyBatteryStrategy(newLevel);
    }
  }

  /// 计算电量等级
  BatteryLevel _calculateLevel(int percentage) {
    if (percentage > 50) return BatteryLevel.high;
    if (percentage > 20) return BatteryLevel.medium;
    if (percentage > 5) return BatteryLevel.low;
    return BatteryLevel.critical;
  }

  /// 应用电量策略
  void _applyBatteryStrategy(BatteryLevel level) {
    switch (level) {
      case BatteryLevel.high:
        _applyHighBatteryStrategy();
        break;
      case BatteryLevel.medium:
        _applyMediumBatteryStrategy();
        break;
      case BatteryLevel.low:
        _applyLowBatteryStrategy();
        break;
      case BatteryLevel.critical:
        _applyCriticalBatteryStrategy();
        break;
    }
  }

  /// 高电量策略：正常模式
  void _applyHighBatteryStrategy() {
    LocationService().setAccuracy(LocationAccuracy.high);
    LocationService().setUpdateInterval(Duration(seconds: 10));
    SyncService().setFrequency(SyncFrequency.realtime);
    AIService().setMode(AIMode.full);
  }

  /// 中电量策略：节能模式
  void _applyMediumBatteryStrategy() {
    LocationService().setAccuracy(LocationAccuracy.balanced);
    LocationService().setUpdateInterval(Duration(minutes: 1));
    SyncService().setFrequency(SyncFrequency.interval(Duration(minutes: 30)));
    AIService().setMode(AIMode.localFirst);
  }

  /// 低电量策略：省电模式
  void _applyLowBatteryStrategy() {
    LocationService().setAccuracy(LocationAccuracy.low);
    LocationService().disableBackgroundUpdates();
    SyncService().setFrequency(SyncFrequency.wifiOnly);
    AIService().setMode(AIMode.offline);
  }

  /// 极低电量策略：最小功耗
  void _applyCriticalBatteryStrategy() {
    LocationService().disable();
    SyncService().pause();
    AIService().setMode(AIMode.disabled);
    // 仅保留核心记账功能
  }
}
```

#### 19.8.3 位置服务功耗优化

位置服务是移动应用主要耗电来源之一，需要精细控制：

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        位置服务功耗优化策略                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【位置获取模式对比】                                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  获取方式     │  精度      │  功耗    │  适用场景                   │ │
│  ├──────────────┼────────────┼──────────┼─────────────────────────────┤ │
│  │  高精度GPS   │  5-10米    │  高      │  地理围栏触发、精确记账     │ │
│  │  网络定位    │  30-100米  │  中      │  城市内商家识别             │ │
│  │  基站定位    │  100-500米 │  低      │  区域统计、低精度场景       │ │
│  │  被动定位    │  变化大    │  极低    │  利用其他应用定位结果       │ │
│  │  地理围栏    │  50-100米  │  低      │  进入/离开区域检测          │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  【智能位置采样策略】                                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                                                                     │ │
│  │   运动状态检测 ──→ 动态调整采样频率                                  │ │
│  │                                                                     │ │
│  │   ┌───────────────┐                                                │ │
│  │   │   静止状态     │ ──→ 采样间隔: 5分钟                            │ │
│  │   │   (未移动)     │     功耗节省: 90%                              │ │
│  │   └───────────────┘                                                │ │
│  │                                                                     │ │
│  │   ┌───────────────┐                                                │ │
│  │   │   步行/骑行   │ ──→ 采样间隔: 30秒                             │ │
│  │   │   (低速移动)   │     功耗节省: 60%                              │ │
│  │   └───────────────┘                                                │ │
│  │                                                                     │ │
│  │   ┌───────────────┐                                                │ │
│  │   │   驾车/公交   │ ──→ 采样间隔: 10秒                             │ │
│  │   │   (高速移动)   │     功耗节省: 30%                              │ │
│  │   └───────────────┘                                                │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

```dart
/// 智能位置服务
class SmartLocationService {
  /// 运动状态检测
  ActivityType _currentActivity = ActivityType.still;

  /// 位置更新配置
  LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.balanced,
    distanceFilter: 50, // 50米变化才更新
  );

  /// 根据运动状态调整位置策略
  void _adjustLocationStrategy(ActivityType activity) {
    switch (activity) {
      case ActivityType.still:
        // 静止状态：最低功耗
        _settings = LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 200,
        );
        _stopContinuousUpdates();
        _schedulePeriodicUpdate(Duration(minutes: 5));
        break;

      case ActivityType.walking:
      case ActivityType.onBicycle:
        // 低速移动：平衡模式
        _settings = LocationSettings(
          accuracy: LocationAccuracy.balanced,
          distanceFilter: 50,
        );
        _startContinuousUpdates(Duration(seconds: 30));
        break;

      case ActivityType.inVehicle:
        // 高速移动：较高频率
        _settings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        );
        _startContinuousUpdates(Duration(seconds: 10));
        break;
    }
  }

  /// 地理围栏替代持续定位
  Future<void> setupGeofences(List<Geofence> geofences) async {
    // 使用系统地理围栏API，比持续定位节省95%电量
    for (final fence in geofences) {
      await GeofencingClient().addGeofence(
        fence,
        onEnter: (region) => _onEnterRegion(region),
        onExit: (region) => _onExitRegion(region),
      );
    }
  }
}
```

#### 19.8.4 后台任务功耗优化

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        后台任务功耗优化                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【后台任务分类与策略】                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  任务类型      │  执行策略        │  唤醒策略        │  电量影响    │ │
│  ├────────────────┼──────────────────┼──────────────────┼──────────────┤ │
│  │  数据同步      │  批量+合并       │  网络变化触发    │  中          │ │
│  │  提醒通知      │  精确定时        │  闹钟唤醒        │  低          │ │
│  │  位置更新      │  被动+围栏       │  系统回调        │  中→低       │ │
│  │  本地计算      │  延迟批处理      │  充电时执行      │  低          │ │
│  │  缓存清理      │  空闲时执行      │  系统空闲回调    │  极低        │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  【唤醒合并策略】                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                                                                     │ │
│  │   传统方式 (高功耗)           优化方式 (低功耗)                      │ │
│  │   ═════════════════           ═════════════════                     │ │
│  │                                                                     │ │
│  │   时间线:                     时间线:                               │ │
│  │   ├─────────────────┤         ├─────────────────┤                  │ │
│  │   │↑   ↑   ↑   ↑   │         │            ↑    │                  │ │
│  │   │同  位  通  同   │         │      合并唤醒   │                  │ │
│  │   │步  置  知  步   │         │   (所有任务)    │                  │ │
│  │   │                 │         │                 │                  │ │
│  │   唤醒次数: 4次/小时          唤醒次数: 1次/小时                    │ │
│  │   功耗节省: 0%                功耗节省: 75%                         │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

```dart
/// 后台任务管理器
class BackgroundTaskManager {
  /// 任务队列
  final List<BackgroundTask> _pendingTasks = [];

  /// 合并窗口（15分钟内的任务合并执行）
  static const _mergeWindow = Duration(minutes: 15);

  /// 添加后台任务
  void scheduleTask(BackgroundTask task) {
    // 检查是否可以合并到现有任务
    final existingTask = _findMergeableTask(task);
    if (existingTask != null) {
      existingTask.merge(task);
      return;
    }

    _pendingTasks.add(task);
    _scheduleNextWakeup();
  }

  /// 查找可合并的任务
  BackgroundTask? _findMergeableTask(BackgroundTask newTask) {
    return _pendingTasks.firstWhereOrNull(
      (t) => t.type == newTask.type &&
             t.scheduledTime.difference(newTask.scheduledTime).abs() < _mergeWindow
    );
  }

  /// 使用WorkManager调度任务（Android）
  Future<void> _scheduleNextWakeup() async {
    if (_pendingTasks.isEmpty) return;

    final nextTask = _pendingTasks
        .reduce((a, b) => a.scheduledTime.isBefore(b.scheduledTime) ? a : b);

    await Workmanager().registerOneOffTask(
      'merged_background_task',
      'executeBackgroundTasks',
      initialDelay: nextTask.scheduledTime.difference(DateTime.now()),
      constraints: Constraints(
        networkType: nextTask.requiresNetwork
            ? NetworkType.connected
            : NetworkType.not_required,
        requiresBatteryNotLow: nextTask.priority == TaskPriority.low,
        requiresCharging: nextTask.priority == TaskPriority.deferred,
      ),
    );
  }

  /// 执行合并后的任务
  Future<void> executeMergedTasks() async {
    final now = DateTime.now();
    final tasksToExecute = _pendingTasks
        .where((t) => t.scheduledTime.isBefore(now.add(_mergeWindow)))
        .toList();

    // 按优先级排序执行
    tasksToExecute.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    for (final task in tasksToExecute) {
      await task.execute();
      _pendingTasks.remove(task);
    }
  }
}

/// 后台任务优先级
enum TaskPriority {
  immediate,  // 立即执行
  normal,     // 正常执行
  low,        // 低优先级（电量充足时）
  deferred,   // 延迟执行（充电时）
}
```

#### 19.8.5 网络请求电量优化

```dart
/// 网络请求电量优化服务
class NetworkPowerOptimizer {
  /// 请求队列
  final Queue<PendingRequest> _requestQueue = Queue();

  /// 批处理定时器
  Timer? _batchTimer;

  /// 批处理窗口
  static const _batchWindow = Duration(seconds: 5);

  /// 添加请求到队列
  Future<T> enqueueRequest<T>(
    String endpoint,
    Map<String, dynamic> data, {
    RequestPriority priority = RequestPriority.normal,
  }) async {
    final completer = Completer<T>();

    _requestQueue.add(PendingRequest(
      endpoint: endpoint,
      data: data,
      priority: priority,
      completer: completer,
    ));

    // 高优先级立即发送
    if (priority == RequestPriority.immediate) {
      await _flushQueue();
    } else {
      _scheduleBatchSend();
    }

    return completer.future;
  }

  /// 调度批量发送
  void _scheduleBatchSend() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchWindow, _flushQueue);
  }

  /// 批量发送请求
  Future<void> _flushQueue() async {
    if (_requestQueue.isEmpty) return;

    // 按端点分组
    final groupedRequests = <String, List<PendingRequest>>{};
    while (_requestQueue.isNotEmpty) {
      final request = _requestQueue.removeFirst();
      groupedRequests.putIfAbsent(request.endpoint, () => []).add(request);
    }

    // 批量发送
    for (final entry in groupedRequests.entries) {
      if (entry.value.length == 1) {
        // 单个请求
        await _sendSingleRequest(entry.value.first);
      } else {
        // 批量请求
        await _sendBatchRequest(entry.key, entry.value);
      }
    }
  }

  /// 发送批量请求
  Future<void> _sendBatchRequest(
    String endpoint,
    List<PendingRequest> requests,
  ) async {
    try {
      final batchData = requests.map((r) => r.data).toList();
      final responses = await _api.postBatch(endpoint, batchData);

      for (var i = 0; i < requests.length; i++) {
        requests[i].completer.complete(responses[i]);
      }
    } catch (e) {
      for (final request in requests) {
        request.completer.completeError(e);
      }
    }
  }
}

/// 请求优先级
enum RequestPriority {
  immediate,  // 立即发送（不批处理）
  normal,     // 正常批处理
  low,        // 低优先级（可延迟更长时间）
}
```

#### 19.8.6 存储I/O优化

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        存储I/O功耗优化                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【I/O操作功耗影响】                                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  操作类型      │  功耗等级  │  优化策略                             │ │
│  ├────────────────┼────────────┼───────────────────────────────────────┤ │
│  │  频繁小写入    │  高        │  合并写入+延迟刷盘                    │ │
│  │  大文件读写    │  中        │  分块处理+后台执行                    │ │
│  │  数据库操作    │  中        │  事务合并+批量写入                    │ │
│  │  缓存读取      │  低        │  内存优先+LRU淘汰                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  【写入合并策略】                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                                                                     │ │
│  │   单次写入 (高功耗)           批量写入 (低功耗)                      │ │
│  │   ═════════════════           ═════════════════                     │ │
│  │                                                                     │ │
│  │   write(A) → disk             buffer(A)                             │ │
│  │   write(B) → disk      →      buffer(B)                             │ │
│  │   write(C) → disk             buffer(C)                             │ │
│  │                               flush([A,B,C]) → disk                 │ │
│  │                                                                     │ │
│  │   磁盘唤醒: 3次               磁盘唤醒: 1次                          │ │
│  │   功耗节省: 0%                功耗节省: 60%                          │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

```dart
/// 存储写入优化器
class StorageWriteOptimizer {
  /// 写入缓冲区
  final Map<String, List<WriteOperation>> _writeBuffer = {};

  /// 刷盘定时器
  Timer? _flushTimer;

  /// 最大缓冲时间
  static const _maxBufferTime = Duration(seconds: 10);

  /// 最大缓冲大小
  static const _maxBufferSize = 100;

  /// 缓冲写入操作
  Future<void> bufferWrite(String table, Map<String, dynamic> data) async {
    _writeBuffer.putIfAbsent(table, () => []).add(
      WriteOperation(table: table, data: data, timestamp: DateTime.now()),
    );

    // 达到缓冲上限立即刷盘
    if (_writeBuffer[table]!.length >= _maxBufferSize) {
      await _flushTable(table);
    } else {
      _scheduleFlush();
    }
  }

  /// 调度刷盘
  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_maxBufferTime, _flushAll);
  }

  /// 刷盘所有缓冲
  Future<void> _flushAll() async {
    for (final table in _writeBuffer.keys.toList()) {
      await _flushTable(table);
    }
  }

  /// 刷盘单表
  Future<void> _flushTable(String table) async {
    final operations = _writeBuffer.remove(table);
    if (operations == null || operations.isEmpty) return;

    // 批量写入数据库
    await _database.batch((batch) {
      for (final op in operations) {
        batch.insert(table, op.data);
      }
    });
  }
}
```

#### 19.8.7 AI/ML模型功耗优化

```dart
/// AI模型功耗优化服务
class AIModelPowerOptimizer {
  /// 模型加载状态
  bool _modelLoaded = false;

  /// 模型空闲卸载定时器
  Timer? _unloadTimer;

  /// 空闲卸载时间
  static const _idleUnloadTime = Duration(minutes: 5);

  /// 按需加载模型
  Future<void> ensureModelLoaded() async {
    if (_modelLoaded) {
      _resetUnloadTimer();
      return;
    }

    // 检查电量和设备状态
    final battery = await Battery().batteryLevel;
    if (battery < 10) {
      throw LowBatteryException('电量过低，无法加载AI模型');
    }

    await _loadModel();
    _modelLoaded = true;
    _resetUnloadTimer();
  }

  /// 重置卸载定时器
  void _resetUnloadTimer() {
    _unloadTimer?.cancel();
    _unloadTimer = Timer(_idleUnloadTime, _unloadModel);
  }

  /// 卸载模型释放资源
  void _unloadModel() {
    if (!_modelLoaded) return;

    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;

    // 主动请求GC
    // ignore: invalid_use_of_visible_for_testing_member
    WidgetsBinding.instance.platformDispatcher.sendPlatformMessage(
      'flutter/gc', null, (_) {},
    );
  }

  /// 批量推理优化
  Future<List<InferenceResult>> batchInference(
    List<InferenceInput> inputs,
  ) async {
    await ensureModelLoaded();

    // 批量处理比单次处理更节能
    final results = <InferenceResult>[];

    // 分批处理，避免长时间占用CPU
    const batchSize = 10;
    for (var i = 0; i < inputs.length; i += batchSize) {
      final batch = inputs.skip(i).take(batchSize).toList();
      results.addAll(await _runBatchInference(batch));

      // 批次间隔，让CPU休息
      if (i + batchSize < inputs.length) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    return results;
  }
}
```

#### 19.8.8 资源消耗监控指标

| 指标类型 | 指标名称 | 目标值 | 测量方式 |
|---------|---------|--------|---------|
| **电量消耗** | 后台每小时电量 | <1% | 系统电量统计API |
| **电量消耗** | 前台活跃耗电 | <3%/小时 | Battery Historian |
| **CPU占用** | 后台CPU占用 | <2% | 性能监控SDK |
| **CPU占用** | 前台平均CPU | <10% | 性能监控SDK |
| **内存占用** | 常驻内存 | <150MB | 系统内存统计 |
| **网络请求** | 请求合并率 | >60% | 自定义埋点 |
| **位置服务** | 位置更新频率 | 按需动态 | 自定义埋点 |
| **存储I/O** | 写入合并率 | >70% | 自定义埋点 |

---

### 19.9 性能优化检查清单

'''

    # 重新编号19.8->19.9, 19.9->19.10
    renumber_fixes = [
        ('### 19.8 性能优化检查清单', '### 19.9 性能优化检查清单'),
        ('#### 19.8.1 开发阶段检查', '#### 19.9.1 开发阶段检查'),
        ('#### 19.8.2 发布前性能测试', '#### 19.9.2 发布前性能测试'),
        ('### 19.9 与其他章节的集成', '### 19.10 与其他章节的集成'),
        ('#### 19.9.1 性能设计横切关系', '#### 19.10.1 性能设计横切关系'),
        ('#### 19.9.2 章节依赖关系', '#### 19.10.2 章节依赖关系'),
    ]

    if marker_19_8 in content and '### 19.8 资源消耗优化策略' not in content:
        # 先重新编号
        for old, new in renumber_fixes:
            if old in content:
                content = content.replace(old, new)
                print(f"Renumber: {old[:30]}...")
                changes += 1

        # 插入新章节
        content = content.replace('### 19.9 性能优化检查清单', new_section_19_8)
        print("OK: Added 19.8 resource consumption optimization section")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 19 refresh done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
