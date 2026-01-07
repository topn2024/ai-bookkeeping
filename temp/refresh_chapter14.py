# -*- coding: utf-8 -*-
"""
刷新第14章地理位置智能化应用
1. 添加14.0设计原则回顾部分
2. 添加14.12与其他系统集成部分
3. 修复章节引用错误
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 添加14.0设计原则回顾 ==========
    old_chapter_start = '''## 14. 地理位置智能化应用

### 14.1 地理位置智能化总览'''

    new_chapter_start = '''## 14. 地理位置智能化应用

### 14.0 设计原则回顾

在深入位置智能化细节之前，让我们回顾本章如何体现2.0版本的核心设计原则：

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      地理位置智能化 - 设计原则矩阵                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  隐私优先    │  │  本地处理    │  │  智能增强    │  │  场景感知    │       │
│  │             │  │             │  │             │  │             │       │
│  │ 最小化采集  │  │ 离线可用    │  │ POI匹配     │  │ 消费场景    │       │
│  │ 用户可控    │  │ 本地缓存    │  │ 区域分析    │  │ 行为理解    │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│         │                │                │                │              │
│         ▼                ▼                ▼                ▼              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  精准预算    │  │  钱龄优化    │  │  省钱建议    │  │  风险预警    │       │
│  │             │  │             │  │             │  │             │       │
│  │ 本地化类目  │  │ 场景分离    │  │ 通勤优化    │  │ 异地检测    │       │
│  │ 城市差异    │  │ 异地识别    │  │ 本地优惠    │  │ 海外消费    │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                            │
│  位置智能化核心理念：                                                        │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │  "隐私至上，本地优先，场景感知，智能增强"                              │   │
│  │                                                                    │   │
│  │   隐私至上 ──→ 最小化采集，用户完全可控，自动清理                      │   │
│  │   本地优先 ──→ 位置数据本地加密存储，离线POI匹配                       │   │
│  │   场景感知 ──→ 智能识别消费场景（商圈/通勤/家附近）                    │   │
│  │   智能增强 ──→ 位置信息增强预算、钱龄、省钱建议                        │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 14.0.1 设计原则在位置智能中的体现

| 设计原则 | 位置应用 | 具体措施 | 效果指标 |
|---------|---------|---------|---------|
| **隐私优先** | 最小化采集 | 仅需要时获取位置，精度分级，自动清理 | 用户投诉率<0.1% |
| **本地处理** | 离线可用 | POI本地缓存，场景识别本地运行 | 离线识别率>80% |
| **智能增强** | 场景分析 | 商圈/通勤/家附近自动识别 | 场景准确率>90% |
| **精准预算** | 本地化推荐 | 城市级别差异化类目和金额 | 预算合理性提升30% |
| **钱龄优化** | 场景分离 | 异地消费不影响本地钱龄评估 | 钱龄准确性提升25% |
| **风险预警** | 异常检测 | 异地/海外消费实时预警 | 风险识别率>95% |

#### 14.0.2 与其他系统的协同关系

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      位置智能化与其他模块的协同关系                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│                        ┌─────────────────────────┐                         │
│                        │   14. 位置智能化         │                         │
│                        │       （本章）           │                         │
│                        └───────────┬─────────────┘                         │
│                                    │                                       │
│        ┌───────────────────────────┼───────────────────────────┐           │
│        │                           │                           │           │
│        ▼                           ▼                           ▼           │
│   ┌──────────┐              ┌──────────┐              ┌──────────┐        │
│   │ 7.钱龄   │              │ 8.预算   │              │ 10.AI    │        │
│   │  系统    │              │  系统    │              │  识别    │        │
│   │ ──────── │              │ ──────── │              │ ──────── │        │
│   │ 场景分离 │              │ 本地化   │              │ 场景上下 │        │
│   │ 异地识别 │              │ 类目推荐 │              │ 文增强   │        │
│   └──────────┘              └──────────┘              └──────────┘        │
│        │                           │                           │           │
│        └───────────────────────────┼───────────────────────────┘           │
│                                    ▼                                       │
│                        ┌─────────────────────────┐                         │
│                        │   12. 数据联动与可视化   │                         │
│                        │   - 位置热力图          │                         │
│                        │   - 区域消费分析        │                         │
│                        └─────────────────────────┘                         │
│                                                                            │
│  ════════════════════════════════════════════════════════════════════════  │
│                           2.0新增协作模块                                   │
│  ════════════════════════════════════════════════════════════════════════  │
│                                                                            │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│   │18.语音   │  │17.自学习 │  │13.家庭   │  │9.习惯    │  │21.安全   │   │
│   │  交互    │  │  系统    │  │  账本    │  │  培养    │  │  隐私    │   │
│   │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │   │
│   │"附近有  │  │位置消费  │  │成员位置  │  │位置打卡  │  │位置数据  │   │
│   │ 优惠吗" │  │模式学习  │  │共享协作  │  │习惯养成  │  │隐私保护  │   │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 14.0.3 目标达成检测

```dart
/// 第14章设计目标达成检测
class Chapter14GoalChecker {
  /// 检查位置智能化设计目标是否达成
  static Future<GoalCheckResult> checkGoals() async {
    final results = <GoalCheck>[];

    // 1. 隐私保护目标
    results.add(GoalCheck(
      goal: '位置数据本地加密存储',
      checker: () => LocationPrivacyService.isEncryptionEnabled(),
      requirement: '必须启用AES-256加密',
    ));

    // 2. 离线可用目标
    results.add(GoalCheck(
      goal: '离线POI匹配可用',
      checker: () => OfflinePoiService.hasLocalCache(),
      requirement: '本地缓存>1000个常用POI',
    ));

    // 3. 场景识别准确率
    results.add(GoalCheck(
      goal: '场景识别准确率>90%',
      checker: () async {
        final stats = await LocationAnalytics.getAccuracyStats();
        return stats.sceneAccuracy >= 0.90;
      },
      requirement: '商圈/通勤/家附近识别准确',
    ));

    // 4. 位置预算应用
    results.add(GoalCheck(
      goal: '本地化预算推荐',
      checker: () => LocationBudgetService.hasCityLevelRecommendation(),
      requirement: '支持城市级别差异化推荐',
    ));

    // 5. 钱龄增强应用
    results.add(GoalCheck(
      goal: '位置感知钱龄计算',
      checker: () => MoneyAgeService.hasLocationAwareness(),
      requirement: '异地消费场景分离',
    ));

    return GoalCheckResult(checks: results);
  }
}
```

### 14.1 地理位置智能化总览'''

    if old_chapter_start in content:
        content = content.replace(old_chapter_start, new_chapter_start)
        print("✓ 修复1: 添加14.0设计原则回顾部分")
        changes += 1
    else:
        print("✗ 修复1: 未找到章节起始位置")

    # ========== 修复2: 修复14.1.1中的章节引用 ==========
    # 修复"第15章职责"应该是"第14章职责"
    old_ref = '''│     │  第15章职责  │     │'''
    new_ref = '''│     │  第14章职责  │     │'''

    if old_ref in content:
        content = content.replace(old_ref, new_ref)
        print("✓ 修复2: 修复第15章职责引用为第14章")
        changes += 1

    # 修复 "第15章钱龄系统"引用
    old_ref2 = '''│  │ 第10章  │              │ 第15章 │'''
    new_ref2 = '''│  │ 第10章  │              │ 第7章  │'''

    if old_ref2 in content:
        content = content.replace(old_ref2, new_ref2)
        print("✓ 修复2b: 修复第15章钱龄系统引用为第7章")
        changes += 1

    old_ref3 = '''│  │AI识别  │◄─────────────│钱龄系统│'''
    new_ref3 = '''│  │AI识别  │◄─────────────│钱龄系统│'''
    # 这个是正确的，不需要修改

    # ========== 修复3: 在14.11之后添加14.12与其他系统集成 ==========
    # 找到第14章结束位置（第15章开始之前）
    chapter15_start = '## 15. 技术架构设计'

    new_section_14_12 = '''### 14.12 与其他系统集成

#### 14.12.1 系统集成概览

位置智能化系统与其他2.0模块的集成采用事件驱动和服务注入两种模式：

```
┌───────────────────────────────��────────────────────────────────────────────┐
│                        位置智能化集成全景图                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                        位置智能化核心                                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │ 位置采集  │  │ POI匹配   │  │ 场景识别  │  │ 隐私过滤  │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘           │  │
│  └───────────────────────────┬─────────────────────────────────────────┘  │
│                              │                                            │
│         ┌────────────────────┼────────────────────┐                       │
│         │                    │                    │                       │
│         ▼                    ▼                    ▼                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                 │
│  │  核心业务    │     │  智能增强    │     │  2.0新增    │                 │
│  │  系统集成    │     │  系统集成    │     │  模块集成    │                 │
│  ├─────────────┤     ├─────────────┤     ├─────────────┤                 │
│  │ • 第7章钱龄 │     │ • 第10章AI  │     │ • 第13章家庭│                 │
│  │ • 第8章预算 │     │ • 第16章智能│     │ • 第17章自学│                 │
│  │ • 第12章可视│     │ • 第19章性能│     │ • 第18章语音│                 │
│  └─────────────┘     └─────────────┘     └─────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 14.12.2 语音交互系统集成

```dart
/// 位置智能与语音交互系统集成
class LocationVoiceService {
  final LocationIntelligenceService _locationService;
  final VoiceRecognitionService _voiceService;

  /// 位置感知语音命令处理
  Future<VoiceCommandResult> processLocationAwareCommand(
    String voiceInput,
  ) async {
    // 获取当前位置上下文
    final locationContext = await _locationService.getCurrentContext();

    // 位置相关语音命令识别
    final patterns = [
      LocationVoicePattern(
        pattern: r'附近有(什么|啥)优惠',
        handler: () => _handleNearbyDeals(locationContext),
      ),
      LocationVoicePattern(
        pattern: r'这里(消费|花了)多少',
        handler: () => _handleLocationSpending(locationContext),
      ),
      LocationVoicePattern(
        pattern: r'(设置|添加).*地点提醒',
        handler: () => _handleGeofenceReminder(voiceInput, locationContext),
      ),
      LocationVoicePattern(
        pattern: r'到(公司|家)(了|附近)',
        handler: () => _handleLocationArrival(locationContext),
      ),
    ];

    for (final pattern in patterns) {
      if (RegExp(pattern.pattern).hasMatch(voiceInput)) {
        return await pattern.handler();
      }
    }

    // 默认处理：添加位置上下文增强
    return VoiceCommandResult(
      success: true,
      locationContext: locationContext,
      suggestion: _generateLocationSuggestion(locationContext),
    );
  }

  /// 处理附近优惠查询
  Future<VoiceCommandResult> _handleNearbyDeals(
    LocationContext context,
  ) async {
    final deals = await _locationService.getNearbyDeals(
      context.coordinates,
      radiusMeters: 500,
    );

    if (deals.isEmpty) {
      return VoiceCommandResult(
        success: true,
        response: '附近暂无发现优惠活动',
      );
    }

    return VoiceCommandResult(
      success: true,
      response: '发现${deals.length}个附近优惠：${deals.first.description}',
      data: deals,
    );
  }

  /// 处理位置消费查询
  Future<VoiceCommandResult> _handleLocationSpending(
    LocationContext context,
  ) async {
    final spending = await _locationService.getLocationSpending(
      context: context.sceneType,
      period: SpendingPeriod.thisMonth,
    );

    return VoiceCommandResult(
      success: true,
      response: '本月在${context.sceneName}消费了${spending.total.toStringAsFixed(0)}元',
      data: spending,
    );
  }
}
```

#### 14.12.3 自学习系统集成

```dart
/// 位置智能与自学习系统集成
class LocationLearningService {
  final LocationIntelligenceService _locationService;
  final SelfLearningService _learningService;

  /// 学习用户位置消费模式
  Future<void> learnLocationPatterns(Transaction tx) async {
    if (tx.location == null) return;

    final context = await _locationService.analyzeLocation(tx.location!);

    // 1. 学习场景-类目关联
    await _learningService.recordPattern(
      PatternType.locationCategory,
      features: {
        'scene_type': context.sceneType.name,
        'category': tx.category,
        'amount_range': _getAmountRange(tx.amount),
        'time_of_day': _getTimeOfDay(tx.date),
      },
    );

    // 2. 学习位置-金额模式
    await _learningService.recordPattern(
      PatternType.locationAmount,
      features: {
        'poi_type': context.poiType,
        'average_amount': tx.amount,
        'frequency': 1,
      },
    );

    // 3. 学习移动模式（通勤识别）
    if (await _isCommuteTime()) {
      await _learningService.recordPattern(
        PatternType.commuteRoute,
        features: {
          'from': context.previousScene?.name,
          'to': context.sceneType.name,
          'duration': context.travelDuration?.inMinutes,
        },
      );
    }
  }

  /// 基于学习结果提供位置建议
  Future<LocationSuggestion> getLearnedSuggestion(
    LocationContext context,
  ) async {
    // 获取该场景的历史模式
    final patterns = await _learningService.getPatterns(
      type: PatternType.locationCategory,
      filter: {'scene_type': context.sceneType.name},
    );

    if (patterns.isEmpty) {
      return LocationSuggestion.none();
    }

    // 找出最常见的类目
    final topCategory = patterns
        .groupBy((p) => p.features['category'])
        .entries
        .reduce((a, b) => a.value.length > b.value.length ? a : b)
        .key;

    // 计算平均金额
    final avgAmount = patterns
        .map((p) => p.features['amount_range'] as double)
        .average;

    return LocationSuggestion(
      suggestedCategory: topCategory,
      suggestedAmount: avgAmount,
      confidence: patterns.length / 10.0, // 基于样本数的置信度
      reason: '基于您在${context.sceneName}的${patterns.length}次消费记录',
    );
  }
}
```

#### 14.12.4 家庭账本系统集成

```dart
/// 位置智能与家庭账本系统集成
class FamilyLocationService {
  final LocationIntelligenceService _locationService;
  final FamilyLedgerService _familyService;

  /// 家庭成员位置共享（需授权）
  Future<FamilyLocationStatus> getFamilyLocationStatus() async {
    final familyId = await _familyService.getCurrentFamilyId();
    if (familyId == null) return FamilyLocationStatus.notInFamily();

    final members = await _familyService.getFamilyMembers(familyId);
    final locationStatus = <MemberLocationStatus>[];

    for (final member in members) {
      if (!member.hasLocationPermission) continue;

      final location = await _locationService.getMemberLocation(member.id);
      if (location != null) {
        locationStatus.add(MemberLocationStatus(
          memberId: member.id,
          memberName: member.name,
          lastLocation: location,
          lastUpdateTime: location.timestamp,
          nearbyDeals: await _locationService.getNearbyDeals(
            location.coordinates,
            radiusMeters: 200,
          ),
        ));
      }
    }

    return FamilyLocationStatus(
      familyId: familyId,
      memberStatuses: locationStatus,
    );
  }

  /// 家庭成员消费位置热力图
  Future<FamilyLocationHeatmap> generateFamilyHeatmap({
    required DateRange period,
    List<String>? memberIds,
  }) async {
    final familyId = await _familyService.getCurrentFamilyId();
    if (familyId == null) throw Exception('Not in family');

    final transactions = await _familyService.getFamilyTransactions(
      familyId: familyId,
      period: period,
      memberIds: memberIds,
    );

    // 按位置聚合
    final locationClusters = <LocationCluster>[];
    for (final tx in transactions.where((t) => t.location != null)) {
      final cluster = locationClusters.firstWhere(
        (c) => c.containsLocation(tx.location!),
        orElse: () {
          final newCluster = LocationCluster(center: tx.location!);
          locationClusters.add(newCluster);
          return newCluster;
        },
      );
      cluster.addTransaction(tx);
    }

    return FamilyLocationHeatmap(
      clusters: locationClusters,
      topSpendingLocations: locationClusters
          .sorted((a, b) => b.totalAmount.compareTo(a.totalAmount))
          .take(5)
          .toList(),
      memberBreakdown: _calculateMemberBreakdown(locationClusters),
    );
  }

  /// 基于位置的家庭消费提醒
  Future<void> setupFamilyLocationReminders() async {
    final familyId = await _familyService.getCurrentFamilyId();
    if (familyId == null) return;

    // 设置家庭共享地点围栏
    final sharedLocations = await _familyService.getSharedLocations(familyId);

    for (final location in sharedLocations) {
      await _locationService.setupGeofence(
        id: 'family_${familyId}_${location.id}',
        center: location.coordinates,
        radiusMeters: location.radius,
        onEnter: (memberId) async {
          // 通知其他家庭成员
          await _familyService.notifyMembers(
            familyId: familyId,
            excludeMemberId: memberId,
            message: '${await _getMemberName(memberId)}到达${location.name}',
          );

          // 显示该地点的家庭预算情况
          final budget = await _familyService.getLocationBudget(
            familyId: familyId,
            locationId: location.id,
          );
          if (budget != null && budget.remainingPercentage < 0.3) {
            await _showBudgetWarning(location, budget);
          }
        },
      );
    }
  }
}
```

#### 14.12.5 习惯培养系统集成

```dart
/// 位置智能与习惯培养系统集成
class LocationHabitService {
  final LocationIntelligenceService _locationService;
  final HabitService _habitService;

  /// 基于位置的习惯打卡
  Future<HabitCheckInResult> locationBasedCheckIn(
    String habitId,
  ) async {
    final habit = await _habitService.getHabit(habitId);
    if (habit == null) throw Exception('Habit not found');

    // 检查是否需要位置验证
    if (habit.requiresLocationVerification) {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        return HabitCheckInResult.failed('无法获取当前位置');
      }

      // 验证是否在指定位置附近
      final distance = _locationService.calculateDistance(
        currentLocation,
        habit.targetLocation!,
      );

      if (distance > habit.locationRadiusMeters) {
        return HabitCheckInResult.failed(
          '您当前不在目标位置附近（距离${distance.toStringAsFixed(0)}米）',
        );
      }
    }

    // 执行打卡
    final result = await _habitService.checkIn(habitId);

    // 记录位置打卡数据
    if (result.success) {
      await _locationService.recordHabitLocation(
        habitId: habitId,
        location: await _locationService.getCurrentLocation(),
        timestamp: DateTime.now(),
      );
    }

    return result;
  }

  /// 创建位置触发的习惯提醒
  Future<void> setupLocationHabitReminder(
    String habitId,
    LocationTrigger trigger,
  ) async {
    final habit = await _habitService.getHabit(habitId);
    if (habit == null) return;

    await _locationService.setupGeofence(
      id: 'habit_$habitId',
      center: trigger.location,
      radiusMeters: trigger.radiusMeters,
      onEnter: (_) async {
        // 检查今日是否已打卡
        final todayStatus = await _habitService.getTodayStatus(habitId);
        if (!todayStatus.isCompleted) {
          await _showHabitReminder(habit, trigger);
        }
      },
    );
  }

  /// 位置消费习惯分析
  Future<LocationHabitAnalysis> analyzeLocationHabits() async {
    final transactions = await _locationService.getRecentTransactionsWithLocation(
      days: 30,
    );

    // 分析重复位置消费模式
    final locationPatterns = <String, LocationPattern>{};

    for (final tx in transactions) {
      final key = '${tx.location!.poiId}_${tx.category}';
      locationPatterns.update(
        key,
        (p) => p.addTransaction(tx),
        ifAbsent: () => LocationPattern(
          poiId: tx.location!.poiId,
          poiName: tx.location!.poiName,
          category: tx.category,
          transactions: [tx],
        ),
      );
    }

    // 识别高频位置消费（可能需要培养控制习惯）
    final frequentPatterns = locationPatterns.values
        .where((p) => p.frequency >= 5) // 月内5次以上
        .toList();

    return LocationHabitAnalysis(
      patterns: frequentPatterns,
      suggestedHabits: _generateHabitSuggestions(frequentPatterns),
      potentialSavings: _calculatePotentialSavings(frequentPatterns),
    );
  }

  /// 生成习惯建议
  List<HabitSuggestion> _generateHabitSuggestions(
    List<LocationPattern> patterns,
  ) {
    final suggestions = <HabitSuggestion>[];

    for (final pattern in patterns) {
      if (pattern.averageAmount > 50 && pattern.frequency >= 10) {
        // 高频高额消费，建议控制
        suggestions.add(HabitSuggestion(
          type: HabitType.spendingLimit,
          title: '控制${pattern.poiName}消费',
          description: '您本月在${pattern.poiName}消费${pattern.frequency}次，'
              '平均每次¥${pattern.averageAmount.toStringAsFixed(0)}',
          suggestedGoal: '每周最多消费${(pattern.frequency / 4).ceil()}次',
          potentialSaving: pattern.totalAmount * 0.3,
        ));
      }
    }

    return suggestions;
  }
}
```

#### 14.12.6 安全隐私系统集成

```dart
/// 位置智能与安全隐私系统集成
class LocationPrivacyService {
  final LocationIntelligenceService _locationService;
  final PrivacyService _privacyService;

  /// 位置数据隐私配置
  static const locationPrivacyConfig = LocationPrivacyConfig(
    // 数据采集
    minAccuracyLevel: LocationAccuracy.approximate, // 默认使用粗略定位
    maxRetentionDays: 30, // 最长保留30天
    autoCleanupEnabled: true,

    // 数据存储
    encryptionEnabled: true,
    encryptionAlgorithm: 'AES-256-GCM',
    localStorageOnly: true, // 默认仅本地存储

    // 数据共享
    requireExplicitConsent: true,
    shareWithFamily: false, // 默认不共享给家庭
    shareWithServer: false, // 默认不上传服务器
  );

  /// 检查位置权限和隐私设���
  Future<LocationPrivacyStatus> checkPrivacyStatus() async {
    final systemPermission = await _locationService.checkPermission();
    final privacySettings = await _privacyService.getLocationSettings();

    return LocationPrivacyStatus(
      systemPermissionGranted: systemPermission.isGranted,
      preciseLocationAllowed: privacySettings.allowPreciseLocation,
      backgroundLocationAllowed: privacySettings.allowBackgroundLocation,
      dataRetentionDays: privacySettings.dataRetentionDays,
      familySharingEnabled: privacySettings.shareFamilyLocation,
      serverUploadEnabled: privacySettings.uploadToServer,
      lastCleanupTime: privacySettings.lastDataCleanup,
    );
  }

  /// 执行位置数据清理
  Future<CleanupResult> cleanupLocationData({
    int? olderThanDays,
    bool includePoiCache = false,
  }) async {
    final retentionDays = olderThanDays ??
        locationPrivacyConfig.maxRetentionDays;

    final cutoffDate = DateTime.now().subtract(
      Duration(days: retentionDays),
    );

    // 清理原始坐标数据
    final coordsDeleted = await _locationService.deleteCoordinatesOlderThan(
      cutoffDate,
    );

    // 清理场景记录
    final scenesDeleted = await _locationService.deleteSceneRecordsOlderThan(
      cutoffDate,
    );

    // 可选：清理POI缓存
    int poiCacheCleared = 0;
    if (includePoiCache) {
      poiCacheCleared = await _locationService.clearPoiCache();
    }

    // 记录清理日志
    await _privacyService.logDataCleanup(
      type: 'location_data',
      itemsDeleted: coordsDeleted + scenesDeleted + poiCacheCleared,
      timestamp: DateTime.now(),
    );

    return CleanupResult(
      coordinatesDeleted: coordsDeleted,
      sceneRecordsDeleted: scenesDeleted,
      poiCacheCleared: poiCacheCleared,
      totalDeleted: coordsDeleted + scenesDeleted + poiCacheCleared,
    );
  }

  /// 导出用户位置数据（GDPR合规）
  Future<LocationDataExport> exportUserLocationData() async {
    final userId = await _privacyService.getCurrentUserId();

    return LocationDataExport(
      userId: userId,
      exportDate: DateTime.now(),
      coordinateHistory: await _locationService.getAllCoordinates(userId),
      sceneHistory: await _locationService.getAllSceneRecords(userId),
      geofences: await _locationService.getUserGeofences(userId),
      privacySettings: await _privacyService.getLocationSettings(),
    );
  }

  /// 删除所有用户位置数据（账户注销时）
  Future<void> deleteAllUserLocationData() async {
    final userId = await _privacyService.getCurrentUserId();

    // 删除所有位置数据
    await _locationService.deleteAllUserData(userId);

    // 删除地理围栏
    await _locationService.removeAllGeofences(userId);

    // 清除POI偏好
    await _locationService.clearPoiPreferences(userId);

    // 记录删除操作
    await _privacyService.logDataDeletion(
      type: 'all_location_data',
      userId: userId,
      timestamp: DateTime.now(),
    );
  }
}
```

---



'''

    if chapter15_start in content:
        # 在第15章之前插入新内容
        content = content.replace(chapter15_start, new_section_14_12 + chapter15_start)
        print("✓ 修复3: 添加14.12与其他系统集成部分（6个子章节）")
        changes += 1
    else:
        print("✗ 修复3: 未找到第15章开始位置")

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 第14章刷新完成，共 {changes} 处修改 =====")
    else:
        print("\n未找到需要修改的内容")

    return changes

if __name__ == '__main__':
    main()
