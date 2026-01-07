# -*- coding: utf-8 -*-
"""
刷新第15章技术架构设计
1. 修正错误的章节编号（15.12.10.x -> 18.12.10.x）
2. 添加15.6 2.0新模块技术支撑
3. 添加15.7 目标达成检测
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 修正错误的章节编号 ==========
    # 15.12.10.x 应该是 18.12.10.x（在18章语音反馈系统中）
    number_fixes = [
        ('##### 15.12.10.8 情绪应对示例库',
         '##### 18.12.10.8 情绪应对示例库'),
        ('##### 15.12.10.9 系统集成与数据流',
         '##### 18.12.10.9 系统集成与数据流'),
        ('##### 15.12.10.10 目标达成检测',
         '##### 18.12.10.10 目标达成检测'),
    ]

    for old, new in number_fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"Fix number: {old[:40]}... -> {new[:40]}...")
            changes += 1

    # ========== 修复2: 添加15.6 2.0新模块技术支撑 ==========
    # 在15.5.5之后，第16章之前添加
    marker_16_start = '''---

## 16. 智能化技术方案'''

    new_sections = '''### 15.6 2.0新模块技术支撑

#### 15.6.1 家庭账本技术架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       家庭账本技术架构                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【多用户数据隔离】                                                       │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐        │ │
│  │  │  用户A    │   │  用户B    │   │  用户C    │   │  共享区    │        │ │
│  │  │  私有数据  │   │  私有数据  │   │  私有数据  │   │  家庭数据  │        │ │
│  │  └──────────┘   └──────────┘   └──────────┘   └──────────┘        │ │
│  │       │              │              │              │               │ │
│  │       └──────────────┴──────────────┴──────────────┘               │ │
│  │                              │                                      │ │
│  │                              ▼                                      │ │
│  │                    ┌──────────────────┐                            │ │
│  │                    │   权限控制层      │                            │ │
│  │                    │  RBAC + 数据级    │                            │ │
│  │                    └──────────────────┘                            │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  【实时同步机制】                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  成员A编辑 ──→ WebSocket ──→ 服务端 ──→ WebSocket ──→ 成员B接收    │ │
│  │                              ↓                                      │ │
│  │                      CRDT冲突解决                                   │ │
│  │                              ↓                                      │ │
│  │                        最终一致性                                   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

```dart
/// 家庭账本数据层实现
class FamilyLedgerRepository {
  final LocalDatabase _localDb;
  final FamilyApiService _api;
  final WebSocketService _ws;

  /// 数据隔离查询
  Future<List<Transaction>> getTransactions({
    required String familyId,
    required String userId,
    required FamilyRole role,
  }) async {
    // 根据角色返回不同范围的数据
    switch (role) {
      case FamilyRole.owner:
      case FamilyRole.admin:
        // 管理员可见所有数据
        return await _localDb.query(
          'transactions',
          where: 'family_id = ?',
          whereArgs: [familyId],
        );
      case FamilyRole.member:
        // 成员仅可见共享数据和自己的数据
        return await _localDb.query(
          'transactions',
          where: 'family_id = ? AND (is_shared = 1 OR user_id = ?)',
          whereArgs: [familyId, userId],
        );
      case FamilyRole.viewer:
        // 查看者仅可见共享数据
        return await _localDb.query(
          'transactions',
          where: 'family_id = ? AND is_shared = 1',
          whereArgs: [familyId],
        );
    }
  }

  /// 实时同步监听
  void setupRealtimeSync(String familyId) {
    _ws.subscribe('family:$familyId', (event) {
      switch (event.type) {
        case 'transaction_created':
          _handleRemoteCreate(event.data);
          break;
        case 'transaction_updated':
          _handleRemoteUpdate(event.data);
          break;
        case 'transaction_deleted':
          _handleRemoteDelete(event.data);
          break;
      }
    });
  }
}
```

#### 15.6.2 位置智能技术架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       位置智能技术架构                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【位置服务分层】                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  ┌──────────────────┐                                              │ │
│  │  │   应用层          │  场景识别、POI匹配、地理围栏                  │ │
│  │  └────────┬─────────┘                                              │ │
│  │           │                                                         │ │
│  │  ┌────────▼─────────┐                                              │ │
│  │  │   服务层          │  位置缓存、轨迹管理、功耗控制                  │ │
│  │  └────────┬─────────┘                                              │ │
│  │           │                                                         │ │
│  │  ┌────────▼─────────┐                                              │ │
│  │  │   平台层          │  Geolocator、高德SDK、系统定位                │ │
│  │  └──────────────────┘                                              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  【POI匹配策略】                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  位置坐标 ──→ 本地POI缓存 ──→ Hit? ──→ 返回结果                     │ │
│  │                    │                                                │ │
│  │                   Miss                                              │ │
│  │                    │                                                │ │
│  │                    ▼                                                │ │
│  │              高德/百度API ──→ 缓存结果 ──→ 返回结果                  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

```dart
/// 位置智能服务实现
class LocationIntelligenceService {
  final LocationProvider _locationProvider;
  final PoiCache _poiCache;
  final PoiApiService _poiApi;

  /// 智能POI匹配
  Future<PoiResult?> matchPoi(LatLng location) async {
    // 1. 本地缓存查询
    final cached = await _poiCache.findNearby(
      location,
      radiusMeters: 100,
    );
    if (cached != null) return cached;

    // 2. 远程API查询
    final remote = await _poiApi.searchNearby(
      location,
      radius: 100,
      types: ['餐饮', '购物', '交通', '生活服务'],
    );

    if (remote != null) {
      // 缓存结果
      await _poiCache.save(remote);
    }

    return remote;
  }

  /// 场景识别
  Future<SceneType> recognizeScene(LatLng location, DateTime time) async {
    final poi = await matchPoi(location);
    final timeContext = _analyzeTimeContext(time);

    return SceneRecognizer.recognize(
      poi: poi,
      timeContext: timeContext,
      userHistory: await _getUserLocationHistory(),
    );
  }
}
```

#### 15.6.3 语音交互技术架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       语音交互技术架构                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【语音处理流水线】                                                       │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                                                                     │ │
│  │  麦克风 ──→ VAD ──→ ASR ──→ NLU ──→ 意图执行 ──→ TTS ──→ 播放     │ │
│  │   采集     静音     语音    意图      业务       文本     语音      │ │
│  │           检测     识别    理解      处理       合成     输出      │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  【多模态融合】                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                                                                     │ │
│  │   ┌─────────┐   ┌─────────┐   ┌─────────┐                         │ │
│  │   │ 语音输入 │   │ 文字输入 │   │ 图片输入 │                         │ │
│  │   └────┬────┘   └────┬────┘   └────┬────┘                         │ │
│  │        │             │             │                               │ │
│  │        └─────────────┼─────────────┘                               │ │
│  │                      ▼                                             │ │
│  │               ┌───────────┐                                        │ │
│  │               │ 统一NLU   │                                        │ │
│  │               │ 意图理解   │                                        │ │
│  │               └─────┬─────┘                                        │ │
│  │                     ▼                                              │ │
│  │               ┌───────────┐                                        │ │
│  │               │ 业务执行  │                                        │ │
│  │               └───────────┘                                        │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

```dart
/// 语音服务技术实现
class VoiceService {
  final AsrService _asr;
  final NluService _nlu;
  final TtsService _tts;

  /// 语音记账流程
  Stream<VoiceBookingState> processVoiceBooking(Stream<Uint8List> audioStream) async* {
    yield VoiceBookingState.listening();

    // 1. 语音识别（流式）
    String transcription = '';
    await for (final chunk in _asr.streamRecognize(audioStream)) {
      transcription = chunk.text;
      yield VoiceBookingState.recognizing(transcription);
    }

    yield VoiceBookingState.processing();

    // 2. 意图理解
    final intent = await _nlu.parseIntent(transcription);

    // 3. 实体提取
    final entities = await _nlu.extractEntities(transcription, intent);

    // 4. 构建交易
    if (intent == IntentType.addTransaction) {
      final transaction = Transaction(
        amount: entities['amount'] as double,
        category: entities['category'] as String,
        note: entities['note'] as String?,
        date: entities['date'] as DateTime? ?? DateTime.now(),
      );

      yield VoiceBookingState.confirming(transaction);
    }
  }
}
```

#### 15.6.4 习惯培养技术架构

```dart
/// 习惯培养系统技术实现
class HabitTrackingService {
  final LocalDatabase _db;
  final NotificationService _notification;
  final AnalyticsService _analytics;

  /// 习惯数据表结构
  static const habitTableSchema = """
    CREATE TABLE habits (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      target_frequency INTEGER NOT NULL,  -- 每周目标次数
      current_streak INTEGER DEFAULT 0,    -- 当前连续天数
      longest_streak INTEGER DEFAULT 0,    -- 最长连续天数
      last_check_in DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE habit_records (
      id TEXT PRIMARY KEY,
      habit_id TEXT NOT NULL,
      check_in_date DATE NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (habit_id) REFERENCES habits(id)
    );

    CREATE INDEX idx_habit_records_date ON habit_records(habit_id, check_in_date);
  """;

  /// 智能提醒时机计算
  Future<DateTime> calculateOptimalReminderTime(String habitId) async {
    // 分析用户历史打卡时间
    final records = await _db.query(
      'habit_records',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'created_at DESC',
      limit: 30,
    );

    if (records.isEmpty) {
      // 默认提醒时间
      return DateTime.now().copyWith(hour: 20, minute: 0);
    }

    // 统计最常打卡的时间段
    final hourCounts = <int, int>{};
    for (final record in records) {
      final hour = (record['created_at'] as DateTime).hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    final optimalHour = hourCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return DateTime.now().copyWith(hour: optimalHour, minute: 0);
  }

  /// 连续性检测与激励
  Future<StreakResult> checkAndUpdateStreak(String habitId) async {
    final habit = await _getHabit(habitId);
    final today = DateTime.now().toDateOnly();
    final lastCheckIn = habit.lastCheckIn?.toDateOnly();

    if (lastCheckIn == null) {
      // 首次打卡
      return StreakResult(newStreak: 1, isNewRecord: true);
    }

    final daysDiff = today.difference(lastCheckIn).inDays;

    if (daysDiff == 1) {
      // 连续打卡
      final newStreak = habit.currentStreak + 1;
      final isNewRecord = newStreak > habit.longestStreak;

      await _updateStreak(habitId, newStreak, isNewRecord ? newStreak : null);

      return StreakResult(
        newStreak: newStreak,
        isNewRecord: isNewRecord,
      );
    } else if (daysDiff > 1) {
      // 断签，重置连续
      await _updateStreak(habitId, 1, null);
      return StreakResult(newStreak: 1, streakBroken: true);
    }

    // 今天已打卡
    return StreakResult(newStreak: habit.currentStreak, alreadyCheckedIn: true);
  }
}
```

### 15.7 目标达成检测

```dart
/// 技术架构目标检测服务
class TechArchitectureGoalDetector {
  /// 技术架构相关目标
  static const architectureGoals = ArchitectureGoalCriteria(
    // 启动性能
    coldStartTime: DurationTarget(
      target: Duration(seconds: 2),
      measurement: '从点击图标到首屏可交互',
    ),

    // 离线可用率
    offlineAvailability: RateTarget(
      target: 1.0,  // 100%核心功能离线可用
      measurement: '核心功能离线测试通过率',
    ),

    // 同步成功率
    syncSuccessRate: RateTarget(
      target: 0.999,  // 99.9%
      measurement: '同步操作成功次数/总次数',
    ),

    // 数据一致性
    dataConsistency: RateTarget(
      target: 1.0,  // 100%
      measurement: 'CRDT冲突正确解决率',
    ),

    // API响应时间
    apiResponseTime: DurationTarget(
      target: Duration(milliseconds: 500),
      measurement: 'API请求P95延迟',
    ),

    // 缓存命中率
    cacheHitRate: RateTarget(
      target: 0.90,  // 90%
      measurement: 'L1+L2缓存命中率',
    ),
  );

  /// 检测目标达成状态
  Future<ArchitectureGoalStatus> checkGoalStatus() async {
    final status = ArchitectureGoalStatus();

    // 测量冷启动时间
    final coldStart = await _measureColdStartTime();
    status.coldStartTime = GoalCheckResult(
      current: coldStart,
      target: architectureGoals.coldStartTime.target,
      achieved: coldStart <= architectureGoals.coldStartTime.target,
    );

    // 测量离线可用率
    final offlineRate = await _testOfflineAvailability();
    status.offlineAvailability = GoalCheckResult(
      current: offlineRate,
      target: architectureGoals.offlineAvailability.target,
      achieved: offlineRate >= architectureGoals.offlineAvailability.target,
    );

    // 测量同步成功率
    final syncRate = await _calculateSyncSuccessRate();
    status.syncSuccessRate = GoalCheckResult(
      current: syncRate,
      target: architectureGoals.syncSuccessRate.target,
      achieved: syncRate >= architectureGoals.syncSuccessRate.target,
    );

    // 测量缓存命中率
    final cacheRate = await _calculateCacheHitRate();
    status.cacheHitRate = GoalCheckResult(
      current: cacheRate,
      target: architectureGoals.cacheHitRate.target,
      achieved: cacheRate >= architectureGoals.cacheHitRate.target,
    );

    return status;
  }
}
```

| 目标项 | 目标值 | 测量方式 | 优先级 |
|--------|--------|----------|--------|
| 冷启动时间 | <2秒 | 点击到首屏可交互 | P0 |
| 热启动时间 | <0.5秒 | 后台恢复到可交互 | P0 |
| 离线可用率 | 100% | 核心功能离线测试 | P0 |
| 同步成功率 | >=99.9% | 同步操作成功率 | P0 |
| 数据一致性 | 100% | CRDT冲突解决率 | P0 |
| API响应P95 | <500ms | 接口延迟监控 | P1 |
| 缓存命中率 | >=90% | L1+L2命中统计 | P1 |
| 内存占用 | <200MB | 常驻内存监控 | P1 |

---

'''

    if marker_16_start in content and '### 15.6 2.0新模块技术支撑' not in content:
        content = content.replace(marker_16_start, new_sections + marker_16_start)
        print("OK: Added 15.6 and 15.7 sections")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 15 refresh done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
