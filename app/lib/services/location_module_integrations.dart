import 'dart:async';

import 'location_service.dart' hide CityTier, CityTierExtension, CityInfo, CityLocation,
  CityLocationService, UserHomeLocationService, CrossRegionSpendingService, CrossRegionResult;
import 'location_data_services.dart' hide CityTier, CityTierExtension, CityInfo, CityLocation;
import 'location_business_services.dart';
import '../models/common_types.dart';
import 'ai_service.dart';
import 'family_privacy_service.dart';
import '../models/member.dart';

/// 位置智能化跨模块集成服务
/// 整合位置服务与其他系统：AI识别、数据可视化、家庭账本、语音交互、习惯培养
/// 对应设计文档第14章的跨模块集成要求

// ========== 1. 位置增强AI识别集成 ==========

/// 位置感知的AI识别结果
class LocationAwareAIResult {
  final AIRecognitionResult aiResult;
  final Position? location;
  final CityInfo? city;
  final CrossRegionStatus? regionStatus;
  final CategoryAmountSuggestion? amountSuggestion;
  final List<String> locationTips;

  const LocationAwareAIResult({
    required this.aiResult,
    this.location,
    this.city,
    this.regionStatus,
    this.amountSuggestion,
    this.locationTips = const [],
  });
}

/// 位置增强AI识别服务
/// 在AI识别基础上，增加位置上下文信息，提供更智能的金额建议和分类推荐
class LocationEnhancedAIService {
  final AIService _aiService;
  final CityLocationService _cityService;
  final CrossRegionSpendingService _crossRegionService;
  final LocalizedAmountService _amountService;

  LocationEnhancedAIService({
    AIService? aiService,
    CityLocationService? cityService,
    CrossRegionSpendingService? crossRegionService,
    LocalizedAmountService? amountService,
  })  : _aiService = aiService ?? AIService(),
        _cityService = cityService ?? CityLocationService(),
        _crossRegionService = crossRegionService ?? CrossRegionSpendingService(),
        _amountService = amountService ?? LocalizedAmountService();

  /// 位置感知的语音识别
  /// 结合当前位置，提供本地化的金额建议
  Future<LocationAwareAIResult> recognizeVoiceWithLocation(
    String transcribedText,
    Position? currentLocation,
  ) async {
    // 1. 基础AI识别
    final aiResult = await _aiService.recognizeVoice(transcribedText);

    if (!aiResult.success || currentLocation == null) {
      return LocationAwareAIResult(aiResult: aiResult);
    }

    // 2. 获取位置上下文
    final city = await _cityService.identifyCity(currentLocation);
    final regionStatus = await _crossRegionService.detectCrossRegion(currentLocation);

    // 3. 获取本地化金额建议
    CategoryAmountSuggestion? amountSuggestion;
    if (aiResult.category != null) {
      amountSuggestion = await _amountService.getSuggestedAmount(
        categoryId: aiResult.category!,
        categoryName: aiResult.category!,
        currentPosition: currentLocation,
      );
    }

    // 4. 生成位置相关提示
    final tips = _generateLocationTips(
      aiResult: aiResult,
      city: city,
      regionStatus: regionStatus,
      amountSuggestion: amountSuggestion,
    );

    return LocationAwareAIResult(
      aiResult: aiResult,
      location: currentLocation,
      city: city,
      regionStatus: regionStatus,
      amountSuggestion: amountSuggestion,
      locationTips: tips,
    );
  }

  /// 位置感知的图片识别
  /// 结合当前位置，识别商户POI信息
  Future<LocationAwareAIResult> recognizeImageWithLocation(
    dynamic imageFile,
    Position? currentLocation,
  ) async {
    // 基础AI识别
    final aiResult = await _aiService.recognizeImage(imageFile);

    if (!aiResult.success || currentLocation == null) {
      return LocationAwareAIResult(aiResult: aiResult);
    }

    // 获取位置上下文
    final city = await _cityService.identifyCity(currentLocation);
    final regionStatus = await _crossRegionService.detectCrossRegion(currentLocation);

    // 获取本地化金额建议
    CategoryAmountSuggestion? amountSuggestion;
    if (aiResult.category != null) {
      amountSuggestion = await _amountService.getSuggestedAmount(
        categoryId: aiResult.category!,
        categoryName: aiResult.category!,
        currentPosition: currentLocation,
      );
    }

    final tips = _generateLocationTips(
      aiResult: aiResult,
      city: city,
      regionStatus: regionStatus,
      amountSuggestion: amountSuggestion,
    );

    return LocationAwareAIResult(
      aiResult: aiResult,
      location: currentLocation,
      city: city,
      regionStatus: regionStatus,
      amountSuggestion: amountSuggestion,
      locationTips: tips,
    );
  }

  /// 基于位置的智能分类建议
  /// 结合商户位置和消费场景，提供更准确的分类建议
  Future<String?> suggestCategoryWithLocation({
    required String description,
    Position? location,
  }) async {
    // 基础AI分类建议
    var category = await _aiService.suggestCategory(description);

    // 如果有位置信息，可以进一步优化分类
    if (location != null && category != null) {
      // TODO: 可以根据位置的POI类型进一步优化分类
      // 例如：在医院附近 → 倾向于医疗分类
      //      在学校附近 → 倾向于教育分类
    }

    return category;
  }

  List<String> _generateLocationTips({
    required AIRecognitionResult aiResult,
    CityInfo? city,
    CrossRegionStatus? regionStatus,
    CategoryAmountSuggestion? amountSuggestion,
  }) {
    final tips = <String>[];

    // 城市级别提示
    if (city != null) {
      tips.add('当前位置：${city.name}（${city.tier.displayName}）');
    }

    // 跨区域提示
    if (regionStatus != null && regionStatus.isTemporary) {
      tips.add('检测到${regionStatus.displayName}，已自动标记为临时消费');
    }

    // 金额合理性提示
    if (amountSuggestion != null && aiResult.amount != null) {
      final amount = aiResult.amount!;
      if (amount < amountSuggestion.suggestedMin) {
        tips.add('金额略低于当地平均水平（建议：¥${amountSuggestion.suggestedMin.toStringAsFixed(0)}-${amountSuggestion.suggestedMax.toStringAsFixed(0)}）');
      } else if (amount > amountSuggestion.suggestedMax) {
        tips.add('金额略高于当地平均水平（建议：¥${amountSuggestion.suggestedMin.toStringAsFixed(0)}-${amountSuggestion.suggestedMax.toStringAsFixed(0)}）');
      } else {
        tips.add('金额符合当地消费水平');
      }
    }

    return tips;
  }
}

// ========== 2. 位置数据可视化集成 ==========

/// 消费热力图数据点
class LocationHeatmapPoint {
  final Position position;
  final double amount;
  final int frequency;
  final String? categoryId;
  final DateTime timestamp;

  const LocationHeatmapPoint({
    required this.position,
    required this.amount,
    required this.frequency,
    this.categoryId,
    required this.timestamp,
  });
}

/// 区域消费统计
class RegionalSpendingStats {
  final String regionName;
  final CityTier? cityTier;
  final double totalAmount;
  final int transactionCount;
  final double avgAmount;
  final Map<String, double> categoryBreakdown;
  final DateTime startDate;
  final DateTime endDate;

  const RegionalSpendingStats({
    required this.regionName,
    this.cityTier,
    required this.totalAmount,
    required this.transactionCount,
    required this.avgAmount,
    required this.categoryBreakdown,
    required this.startDate,
    required this.endDate,
  });

  double get dailyAverage {
    final days = endDate.difference(startDate).inDays;
    return days > 0 ? totalAmount / days : 0.0;
  }
}

/// 位置数据可视化服务
/// 提供消费热力图、区域分析等可视化数据
class LocationVisualizationService {
  final CityLocationService _cityService;
  // ignore: unused_field
  final CrossRegionSpendingService __crossRegionService;

  LocationVisualizationService({
    CityLocationService? cityService,
    CrossRegionSpendingService? crossRegionService,
  })  : _cityService = cityService ?? CityLocationService(),
        __crossRegionService = crossRegionService ?? CrossRegionSpendingService();

  /// 生成消费热力图数据
  Future<List<LocationHeatmapPoint>> generateHeatmapData({
    required List<TransactionWithLocation> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var filteredTx = transactions;

    // 过滤日期范围
    if (startDate != null) {
      filteredTx = filteredTx.where((tx) => tx.timestamp.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      filteredTx = filteredTx.where((tx) => tx.timestamp.isBefore(endDate)).toList();
    }

    // 按位置聚类（简化版：使用0.01度作为聚类半径，约1公里）
    final clusters = <String, List<TransactionWithLocation>>{};

    for (final tx in filteredTx) {
      // 将位置量化到0.01度精度
      final lat = (tx.position.latitude * 100).round() / 100;
      final lng = (tx.position.longitude * 100).round() / 100;
      final key = '$lat,$lng';

      clusters.putIfAbsent(key, () => []);
      clusters[key]!.add(tx);
    }

    // 转换为热力图数据点
    final heatmapPoints = <LocationHeatmapPoint>[];

    for (final entry in clusters.entries) {
      final txList = entry.value;
      if (txList.isEmpty) continue;

      final totalAmount = txList.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final avgPosition = txList.first.position; // 使用第一个交易的位置代表

      heatmapPoints.add(LocationHeatmapPoint(
        position: avgPosition,
        amount: totalAmount,
        frequency: txList.length,
        timestamp: txList.first.timestamp,
      ));
    }

    // 按金额降序排序
    heatmapPoints.sort((a, b) => b.amount.compareTo(a.amount));

    return heatmapPoints;
  }

  /// 分析区域消费统计
  Future<List<RegionalSpendingStats>> analyzeRegionalSpending({
    required List<TransactionWithLocation> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var filteredTx = transactions;

    // 过滤日期范围
    if (startDate != null) {
      filteredTx = filteredTx.where((tx) => tx.timestamp.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      filteredTx = filteredTx.where((tx) => tx.timestamp.isBefore(endDate)).toList();
    }

    // 按城市分组
    final cityGroups = <String, List<TransactionWithLocation>>{};

    for (final tx in filteredTx) {
      final city = await _cityService.identifyCity(tx.position);
      final cityKey = city?.code ?? 'unknown';

      cityGroups.putIfAbsent(cityKey, () => []);
      cityGroups[cityKey]!.add(tx);
    }

    // 生成区域统计
    final stats = <RegionalSpendingStats>[];

    for (final entry in cityGroups.entries) {
      final _ = entry.key;
      final txList = entry.value;

      if (txList.isEmpty) continue;

      final city = await _cityService.identifyCity(txList.first.position);
      final totalAmount = txList.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final avgAmount = totalAmount / txList.length;

      // 按类目分组（简化版）
      final categoryBreakdown = <String, double>{};

      final actualStartDate = startDate ??
          txList.map((tx) => tx.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
      final actualEndDate = endDate ??
          txList.map((tx) => tx.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);

      stats.add(RegionalSpendingStats(
        regionName: city?.name ?? '未知地区',
        cityTier: city?.tier,
        totalAmount: totalAmount,
        transactionCount: txList.length,
        avgAmount: avgAmount,
        categoryBreakdown: categoryBreakdown,
        startDate: actualStartDate,
        endDate: actualEndDate,
      ));
    }

    // 按总金额降序排序
    stats.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return stats;
  }

  /// 获取消费地点排行
  Future<List<LocationPattern>> getTopSpendingLocations({
    required List<TransactionWithLocation> transactions,
    int limit = 10,
  }) async {
    // 按位置聚类
    final clusters = <String, List<TransactionWithLocation>>{};

    for (final tx in transactions) {
      final lat = (tx.position.latitude * 100).round() / 100;
      final lng = (tx.position.longitude * 100).round() / 100;
      final key = '$lat,$lng';

      clusters.putIfAbsent(key, () => []);
      clusters[key]!.add(tx);
    }

    // 转换为LocationPattern
    final patterns = <LocationPattern>[];

    for (final entry in clusters.entries) {
      final txList = entry.value;
      if (txList.isEmpty) continue;

      final totalAmount = txList.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final avgAmount = totalAmount / txList.length;

      // 获取位置名称
      final city = await _cityService.identifyCity(txList.first.position);
      final locationName = city?.name ?? '未知地点';

      patterns.add(LocationPattern(
        location: txList.first.position,
        locationName: locationName,
        frequency: txList.length,
        averageAmount: avgAmount,
        totalAmount: totalAmount,
      ));
    }

    // 按总金额降序排序，取前N个
    patterns.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return patterns.take(limit).toList();
  }
}

// ========== 3. 家庭账本位置共享集成 ==========

/// 家庭成员位置共享设置
class FamilyLocationSharingSettings {
  final String memberId;
  final String ledgerId;
  final bool enableSharing;
  final LocationSharingLevel sharingLevel;
  final List<String> sharedWithMemberIds;
  final DateTime? lastUpdated;

  const FamilyLocationSharingSettings({
    required this.memberId,
    required this.ledgerId,
    this.enableSharing = false,
    this.sharingLevel = LocationSharingLevel.none,
    this.sharedWithMemberIds = const [],
    this.lastUpdated,
  });
}

/// 位置共享级别
enum LocationSharingLevel {
  none,          // 不共享
  cityOnly,      // 仅共享城市
  approximate,   // 粗略位置（区/县级）
  precise,       // 精确位置
}

extension LocationSharingLevelExtension on LocationSharingLevel {
  String get displayName {
    switch (this) {
      case LocationSharingLevel.none:
        return '不共享';
      case LocationSharingLevel.cityOnly:
        return '仅城市';
      case LocationSharingLevel.approximate:
        return '大致位置';
      case LocationSharingLevel.precise:
        return '精确位置';
    }
  }
}

/// 家庭位置共享服务
/// 管理家庭成员间的位置信息共享
class FamilyLocationSharingService {
  // ignore: unused_field
  final FamilyPrivacyService __privacyService;
  final CityLocationService _cityService;
  // ignore: unused_field
  final UserHomeLocationService __homeService;

  // 成员位置共享设置存储
  final Map<String, FamilyLocationSharingSettings> _sharingSettings = {};

  FamilyLocationSharingService({
    FamilyPrivacyService? privacyService,
    CityLocationService? cityService,
    UserHomeLocationService? homeService,
  })  : __privacyService = privacyService ?? FamilyPrivacyService(),
        _cityService = cityService ?? CityLocationService(),
        __homeService = homeService ?? UserHomeLocationService();

  /// 更新位置共享设置
  Future<FamilyLocationSharingSettings> updateSharingSettings({
    required String memberId,
    required String ledgerId,
    required bool enableSharing,
    required LocationSharingLevel sharingLevel,
    List<String>? sharedWithMemberIds,
  }) async {
    final key = '$memberId:$ledgerId';
    final settings = FamilyLocationSharingSettings(
      memberId: memberId,
      ledgerId: ledgerId,
      enableSharing: enableSharing,
      sharingLevel: sharingLevel,
      sharedWithMemberIds: sharedWithMemberIds ?? [],
      lastUpdated: DateTime.now(),
    );

    _sharingSettings[key] = settings;
    return settings;
  }

  /// 获取位置共享设置
  Future<FamilyLocationSharingSettings?> getSharingSettings({
    required String memberId,
    required String ledgerId,
  }) async {
    final key = '$memberId:$ledgerId';
    return _sharingSettings[key];
  }

  /// 检查是否可以查看成员位置
  Future<bool> canViewMemberLocation({
    required String viewerId,
    required String targetMemberId,
    required String ledgerId,
    required MemberRole viewerRole,
  }) async {
    // 查看自己的位置总是允许
    if (viewerId == targetMemberId) return true;

    // 管理员可以查看所有成员位置
    if (viewerRole == MemberRole.owner || viewerRole == MemberRole.admin) {
      return true;
    }

    // 检查目标成员的共享设置
    final targetSettings = await getSharingSettings(
      memberId: targetMemberId,
      ledgerId: ledgerId,
    );

    if (targetSettings == null || !targetSettings.enableSharing) {
      return false;
    }

    // 检查是否在共享名单中
    if (targetSettings.sharedWithMemberIds.isEmpty) {
      // 空名单表示共享给所有成员
      return true;
    }

    return targetSettings.sharedWithMemberIds.contains(viewerId);
  }

  /// 获取共享的位置信息（根据共享级别脱敏）
  Future<Position?> getSharedLocation({
    required String viewerId,
    required String targetMemberId,
    required String ledgerId,
    required Position actualPosition,
    required MemberRole viewerRole,
  }) async {
    // 检查权限
    final canView = await canViewMemberLocation(
      viewerId: viewerId,
      targetMemberId: targetMemberId,
      ledgerId: ledgerId,
      viewerRole: viewerRole,
    );

    if (!canView) return null;

    // 获取共享设置
    final settings = await getSharingSettings(
      memberId: targetMemberId,
      ledgerId: ledgerId,
    );

    if (settings == null) return null;

    // 根据共享级别返回脱敏后的位置
    switch (settings.sharingLevel) {
      case LocationSharingLevel.none:
        return null;

      case LocationSharingLevel.cityOnly:
        // 返回城市中心点
        final city = await _cityService.identifyCity(actualPosition);
        if (city == null) return null;
        return Position(
          latitude: city.latitude,
          longitude: city.longitude,
          accuracy: 5000, // 5公里精度
          timestamp: DateTime.now(),
        );

      case LocationSharingLevel.approximate:
        // 粗略位置：精度降低到0.01度（约1公里）
        final lat = (actualPosition.latitude * 100).round() / 100;
        final lng = (actualPosition.longitude * 100).round() / 100;
        return Position(
          latitude: lat,
          longitude: lng,
          accuracy: 1000, // 1公里精度
          timestamp: actualPosition.timestamp,
        );

      case LocationSharingLevel.precise:
        // 精确位置
        return actualPosition;
    }
  }

  /// 获取家庭成员的常驻地点（用于显示在家庭地图上）
  Future<List<HomeLocation>> getFamilyHomeLocations({
    required String ledgerId,
    required String viewerId,
    required MemberRole viewerRole,
  }) async {
    final homeLocations = <HomeLocation>[];

    // TODO: 获取所有家庭成员列表
    // 这里需要集成family服务来获取成员列表
    // for each member, check permission and get their home locations

    return homeLocations;
  }
}

// ========== 4. 语音交互位置查询集成 ==========

/// 语音位置查询服务
/// 支持语音询问"附近有什么优惠"、"这里消费多少了"等
class VoiceLocationQueryService {
  final CityLocationService _cityService;
  final CrossRegionSpendingService _crossRegionService;
  final LocalizedAmountService _amountService;
  final SavingSuggestionService _savingService;

  VoiceLocationQueryService({
    CityLocationService? cityService,
    CrossRegionSpendingService? crossRegionService,
    LocalizedAmountService? amountService,
    SavingSuggestionService? savingService,
  })  : _cityService = cityService ?? CityLocationService(),
        _crossRegionService = crossRegionService ?? CrossRegionSpendingService(),
        _amountService = amountService ?? LocalizedAmountService(),
        _savingService = savingService ?? SavingSuggestionService();

  /// 查询当前位置信息
  /// 示例：语音输入"我在哪里"
  Future<String> queryCurrentLocation(Position position) async {
    final city = await _cityService.identifyCity(position);

    if (city == null) {
      return '无法识别当前位置，请确保GPS已开启';
    }

    final regionStatus = await _crossRegionService.detectCrossRegion(position);

    final response = StringBuffer();
    response.write('您当前位于${city.name}（${city.tier.displayName}）');

    if (regionStatus.isTemporary) {
      response.write('，检测到${regionStatus.displayName}');
    }

    return response.toString();
  }

  /// 查询当前位置的消费建议
  /// 示例：语音输入"这里吃饭要多少钱"
  Future<String> queryLocationSpendingAdvice({
    required Position position,
    required String categoryName,
  }) async {
    final city = await _cityService.identifyCity(position);

    if (city == null) {
      return '无法识别当前位置';
    }

    // 简单的类目ID映射
    final categoryId = _guessCategoryId(categoryName);

    final suggestion = await _amountService.getSuggestedAmount(
      categoryId: categoryId,
      categoryName: categoryName,
      currentPosition: position,
    );

    return '在${city.name}，${categoryName}的建议金额是'
        '¥${suggestion.suggestedMin.toStringAsFixed(0)}'
        ' 到 '
        '¥${suggestion.suggestedMax.toStringAsFixed(0)}，'
        '平均约¥${suggestion.avgAmount.toStringAsFixed(0)}';
  }

  /// 查询这里消费了多少
  /// 示例：语音输入"我在这里花了多少钱"
  Future<String> queryLocationSpending({
    required Position position,
    required List<TransactionWithLocation> transactions,
  }) async {
    // 查找附近的交易（500米范围内）
    final nearbyTx = transactions.where((tx) {
      final distance = position.distanceTo(tx.position);
      return distance <= 500;
    }).toList();

    if (nearbyTx.isEmpty) {
      return '附近500米内没有找到消费记录';
    }

    final totalAmount = nearbyTx.fold<double>(0.0, (sum, tx) => sum + tx.amount);

    final city = await _cityService.identifyCity(position);
    final locationName = city?.name ?? '这里';

    return '您在$locationName附近500米内共消费了${nearbyTx.length}笔，'
        '总计¥${totalAmount.toStringAsFixed(2)}';
  }

  /// 查询附近优惠建议
  /// 示例：语音输入"附近有什么优惠"
  Future<String> queryNearbyDeals({
    required Position position,
    required List<TransactionWithLocation> transactions,
  }) async {
    // 生成省钱建议
    final suggestions = await _savingService.generateSuggestions(
      transactions: transactions,
      currentPosition: position,
    );

    if (suggestions.isEmpty) {
      return '暂时没有发现附近的优惠建议';
    }

    // 返回第一条建议
    final firstSuggestion = suggestions.first;
    return '${firstSuggestion.title}：${firstSuggestion.actionable}，'
        '预计可节省¥${firstSuggestion.potentialSaving.toStringAsFixed(0)}';
  }

  String _guessCategoryId(String categoryName) {
    if (categoryName.contains('餐') || categoryName.contains('饭') || categoryName.contains('吃')) {
      return 'food';
    } else if (categoryName.contains('交通') || categoryName.contains('车') || categoryName.contains('路')) {
      return 'transport';
    } else if (categoryName.contains('购物') || categoryName.contains('买')) {
      return 'shopping';
    } else if (categoryName.contains('娱乐') || categoryName.contains('玩')) {
      return 'entertainment';
    }
    return 'other_expense';
  }
}

// ========== 5. 习惯培养位置打卡集成 ==========

/// 位置打卡记录
class LocationCheckIn {
  final String id;
  final String habitId;
  final Position position;
  final CityInfo? city;
  final DateTime timestamp;
  final String? note;

  const LocationCheckIn({
    required this.id,
    required this.habitId,
    required this.position,
    this.city,
    required this.timestamp,
    this.note,
  });
}

/// 习惯培养位置打卡服务
/// 支持通勤省钱习惯、位置打卡等
class HabitLocationCheckInService {
  final CityLocationService _cityService;
  final CommuteAnalysisService _commuteService;

  final Map<String, List<LocationCheckIn>> _checkIns = {};

  HabitLocationCheckInService({
    CityLocationService? cityService,
    CommuteAnalysisService? commuteService,
  })  : _cityService = cityService ?? CityLocationService(),
        _commuteService = commuteService ?? CommuteAnalysisService();

  /// 创建位置打卡
  Future<LocationCheckIn> checkIn({
    required String habitId,
    required Position position,
    String? note,
  }) async {
    final city = await _cityService.identifyCity(position);

    final checkIn = LocationCheckIn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      habitId: habitId,
      position: position,
      city: city,
      timestamp: DateTime.now(),
      note: note,
    );

    _checkIns.putIfAbsent(habitId, () => []);
    _checkIns[habitId]!.add(checkIn);

    return checkIn;
  }

  /// 获取打卡历史
  Future<List<LocationCheckIn>> getCheckInHistory({
    required String habitId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var history = _checkIns[habitId] ?? [];

    if (startDate != null) {
      history = history.where((c) => c.timestamp.isAfter(startDate)).toList();
    }

    if (endDate != null) {
      history = history.where((c) => c.timestamp.isBefore(endDate)).toList();
    }

    return history;
  }

  /// 分析通勤省钱习惯
  /// 检查是否在通勤路线上有不必要的消费
  Future<Map<String, dynamic>> analyzeCommuteHabit({
    required List<TransactionWithLocation> transactions,
  }) async {
    // 分析通勤模式
    final routes = await _commuteService.analyzeCommutePatterns(
      transactions: transactions,
    );

    if (routes.isEmpty) {
      return {
        'hasCommutePattern': false,
        'message': '暂未检测到通勤模式',
      };
    }

    final mainRoute = routes.first;

    // 分析通勤消费
    final analysis = await _commuteService.analyzeCommute(
      route: mainRoute,
      transactions: transactions,
    );

    return {
      'hasCommutePattern': true,
      'route': mainRoute.name,
      'monthlyAvgCost': analysis.monthlyAvgCost,
      'costPerTrip': analysis.costPerTrip,
      'suggestions': analysis.suggestions,
    };
  }

  /// 检查是否完成位置打卡目标
  Future<bool> isCheckInGoalMet({
    required String habitId,
    required int targetCount,
    required Duration period,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(period);

    final history = await getCheckInHistory(
      habitId: habitId,
      startDate: startDate,
      endDate: endDate,
    );

    return history.length >= targetCount;
  }
}
