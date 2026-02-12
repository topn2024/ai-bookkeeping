import 'dart:async';

import '../models/common_types.dart';
import 'location_service.dart' hide CityTier, CityTierExtension, CityInfo, CityLocation,
  CityLocationService, UserHomeLocationService;
import 'location_data_services.dart' hide CityTier, CityTierExtension, CityInfo, CityLocation;

/// 位置业务分析服务集合
/// 对应设计文档第14.2节 - 第3层：业务分析服务
///
/// 包含四个核心服务：
/// 1. LocalizedAmountService - 本地化金额建议
/// 2. CrossRegionSpendingService - 异地消费识别
/// 3. SavingSuggestionService - 省钱建议
/// 4. CommuteAnalysisService - 通勤分析

// ========== 1. 本地化金额建议服务 ==========

/// 消费类别金额建议
class CategoryAmountSuggestion {
  final String categoryId;
  final String categoryName;
  final double suggestedMin;
  final double suggestedMax;
  final double avgAmount;
  final CityTier cityTier;
  final String reasoning;

  const CategoryAmountSuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.suggestedMin,
    required this.suggestedMax,
    required this.avgAmount,
    required this.cityTier,
    required this.reasoning,
  });
}

/// 本地化金额建议服务
/// 对应设计文档第14.5节
class LocalizedAmountService {
  final CityLocationService _cityService;

  // 各城市级别的基础金额参考
  static const Map<String, Map<CityTier, double>> _baseAmounts = {
    'food': {
      CityTier.tier1: 50.0,
      CityTier.tier2: 35.0,
      CityTier.tier3: 25.0,
      CityTier.tier4Plus: 20.0,
    },
    'transport': {
      CityTier.tier1: 30.0,
      CityTier.tier2: 20.0,
      CityTier.tier3: 15.0,
      CityTier.tier4Plus: 10.0,
    },
    'shopping': {
      CityTier.tier1: 200.0,
      CityTier.tier2: 150.0,
      CityTier.tier3: 100.0,
      CityTier.tier4Plus: 80.0,
    },
    'entertainment': {
      CityTier.tier1: 150.0,
      CityTier.tier2: 100.0,
      CityTier.tier3: 80.0,
      CityTier.tier4Plus: 60.0,
    },
  };

  LocalizedAmountService({
    CityLocationService? cityService,
  }) : _cityService = cityService ?? CityLocationService();

  /// 获取本地化金额建议
  Future<CategoryAmountSuggestion> getSuggestedAmount({
    required String categoryId,
    required String categoryName,
    Position? currentPosition,
  }) async {
    // 获取当前城市
    CityInfo? city;
    if (currentPosition != null) {
      city = await _cityService.identifyCity(currentPosition);
    }
    city ??= await _cityService.getCurrentCity();

    final cityTier = city?.tier ?? CityTier.tier3;

    // 获取基础金额
    final baseAmount = _getBaseAmount(categoryId, cityTier);

    // 计算建议范围（±30%）
    final suggestedMin = baseAmount * 0.7;
    final suggestedMax = baseAmount * 1.3;

    final reasoning = _generateReasoning(categoryName, cityTier, city?.name);

    return CategoryAmountSuggestion(
      categoryId: categoryId,
      categoryName: categoryName,
      suggestedMin: suggestedMin,
      suggestedMax: suggestedMax,
      avgAmount: baseAmount,
      cityTier: cityTier,
      reasoning: reasoning,
    );
  }

  /// 批量获取金额建议
  Future<List<CategoryAmountSuggestion>> getBatchSuggestions({
    required List<Map<String, String>> categories,
    Position? currentPosition,
  }) async {
    final suggestions = <CategoryAmountSuggestion>[];

    for (final category in categories) {
      final suggestion = await getSuggestedAmount(
        categoryId: category['id']!,
        categoryName: category['name']!,
        currentPosition: currentPosition,
      );
      suggestions.add(suggestion);
    }

    return suggestions;
  }

  double _getBaseAmount(String categoryId, CityTier tier) {
    // 尝试从预定义数据中获取
    for (final entry in _baseAmounts.entries) {
      if (categoryId.toLowerCase().contains(entry.key)) {
        return entry.value[tier] ?? 50.0;
      }
    }

    // 默认值
    return 50.0 * tier.costOfLivingMultiplier;
  }

  String _generateReasoning(String categoryName, CityTier tier, String? cityName) {
    final city = cityName ?? tier.displayName;
    return '基于$city的消费水平，$categoryName类目建议金额';
  }
}

// ========== 2. 异地消费识别服务 ==========

/// 跨区域状态
enum CrossRegionStatus {
  local,      // 本地
  crossCity,  // 跨城市
  crossProvince, // 跨省
  overseas,   // 海外（未来扩展）
}

extension CrossRegionStatusExtension on CrossRegionStatus {
  String get displayName {
    switch (this) {
      case CrossRegionStatus.local:
        return '本地消费';
      case CrossRegionStatus.crossCity:
        return '跨城市消费';
      case CrossRegionStatus.crossProvince:
        return '跨省消费';
      case CrossRegionStatus.overseas:
        return '海外消费';
    }
  }

  bool get isTemporary => this != CrossRegionStatus.local;
}

/// 异地消费识别服务
/// 对应设计文档第14.6节
class CrossRegionSpendingService {
  final CityLocationService _cityService;
  final UserHomeLocationService _homeService;

  CrossRegionSpendingService({
    CityLocationService? cityService,
    UserHomeLocationService? homeService,
  })  : _cityService = cityService ?? CityLocationService(),
        _homeService = homeService ?? UserHomeLocationService();

  /// 检测跨区域状态
  Future<CrossRegionStatus> detectCrossRegion(Position position) async {
    // 1. 检查是否在常驻地点附近
    final nearHome = await _homeService.isNearHomeLocation(position);
    if (nearHome != null) {
      return CrossRegionStatus.local;
    }

    // 2. 检查是否在不同城市
    final inDifferentCity = await _cityService.isInDifferentCity(position);
    if (!inDifferentCity) {
      return CrossRegionStatus.local;
    }

    // 3. 识别当前城市
    final currentCity = await _cityService.identifyCity(position);
    final homeCity = await _cityService.getHomeCity();

    if (currentCity == null || homeCity == null) {
      return CrossRegionStatus.crossCity;
    }

    // 4. 判断是跨城市还是跨省
    if (currentCity.province != homeCity.province) {
      return CrossRegionStatus.crossProvince;
    }

    return CrossRegionStatus.crossCity;
  }

  /// 判断是否是临时消费
  Future<bool> isTemporarySpending(Position position) async {
    final status = await detectCrossRegion(position);
    return status.isTemporary;
  }

  /// 获取跨区域消费统计
  Future<CrossRegionStatistics> getStatistics({
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

    int localCount = 0;
    int crossCityCount = 0;
    int crossProvinceCount = 0;
    double localAmount = 0.0;
    double crossCityAmount = 0.0;
    double crossProvinceAmount = 0.0;

    for (final tx in filteredTx) {
      final status = await detectCrossRegion(tx.position);

      switch (status) {
        case CrossRegionStatus.local:
          localCount++;
          localAmount += tx.amount;
          break;
        case CrossRegionStatus.crossCity:
          crossCityCount++;
          crossCityAmount += tx.amount;
          break;
        case CrossRegionStatus.crossProvince:
          crossProvinceCount++;
          crossProvinceAmount += tx.amount;
          break;
        default:
          break;
      }
    }

    return CrossRegionStatistics(
      totalCount: filteredTx.length,
      localCount: localCount,
      crossCityCount: crossCityCount,
      crossProvinceCount: crossProvinceCount,
      localAmount: localAmount,
      crossCityAmount: crossCityAmount,
      crossProvinceAmount: crossProvinceAmount,
    );
  }
}

/// 带位置的交易
class TransactionWithLocation {
  final String id;
  final double amount;
  final DateTime timestamp;
  final Position position;
  final String? categoryId;

  const TransactionWithLocation({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.position,
    this.categoryId,
  });
}

/// 跨区域统计
class CrossRegionStatistics {
  final int totalCount;
  final int localCount;
  final int crossCityCount;
  final int crossProvinceCount;
  final double localAmount;
  final double crossCityAmount;
  final double crossProvinceAmount;

  const CrossRegionStatistics({
    required this.totalCount,
    required this.localCount,
    required this.crossCityCount,
    required this.crossProvinceCount,
    required this.localAmount,
    required this.crossCityAmount,
    required this.crossProvinceAmount,
  });

  double get temporaryRatio =>
      totalCount > 0 ? (crossCityCount + crossProvinceCount) / totalCount : 0.0;

  double get temporaryAmountRatio =>
      (localAmount + crossCityAmount + crossProvinceAmount) > 0
          ? (crossCityAmount + crossProvinceAmount) /
              (localAmount + crossCityAmount + crossProvinceAmount)
          : 0.0;
}

// ========== 3. 省钱建议服务 ==========

/// 省钱建议类型
enum SavingSuggestionType {
  alternativeLocation, // 替代地点
  commuteOptimization, // 通勤优化
  categoryConsolidation, // 分类整合
  timingOptimization, // 时机优化
}

/// 省钱建议
class SavingSuggestion {
  final SavingSuggestionType type;
  final String title;
  final String description;
  final double potentialSaving; // 潜在节省金额
  final String actionable; // 可执行的建议

  const SavingSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.potentialSaving,
    required this.actionable,
  });
}

/// 省钱建议服务
/// 对应设计文档第14.8节
class SavingSuggestionService {
  // ignore: unused_field
  final CityLocationService __cityService;

  SavingSuggestionService({
    CityLocationService? cityService,
  }) : __cityService = cityService ?? CityLocationService();

  /// 生成省钱建议
  Future<List<SavingSuggestion>> generateSuggestions({
    required List<TransactionWithLocation> transactions,
    required Position? currentPosition,
  }) async {
    final suggestions = <SavingSuggestion>[];

    // 1. 分析位置消费模式
    final locationPatterns = await _analyzeLocationPatterns(transactions);

    // 2. 生成替代地点建议
    suggestions.addAll(await _generateAlternativeLocationSuggestions(locationPatterns));

    // 3. 生成通勤优化建议
    suggestions.addAll(await _generateCommuteOptimizationSuggestions(transactions));

    // 4. 生成分类整合建议
    suggestions.addAll(_generateCategoryConsolidationSuggestions(locationPatterns));

    return suggestions;
  }

  Future<List<LocationPattern>> _analyzeLocationPatterns(
    List<TransactionWithLocation> transactions,
  ) async {
    if (transactions.isEmpty) return [];

    // 按位置聚类交易（200m半径内视为同一地点）
    const clusterRadiusMeters = 200.0;
    final clusters = <List<TransactionWithLocation>>[];
    final assigned = List<bool>.filled(transactions.length, false);

    for (int i = 0; i < transactions.length; i++) {
      if (assigned[i]) continue;

      final cluster = <TransactionWithLocation>[transactions[i]];
      assigned[i] = true;

      for (int j = i + 1; j < transactions.length; j++) {
        if (assigned[j]) continue;

        final distance = transactions[i].position.distanceTo(
          transactions[j].position,
        );
        if (distance <= clusterRadiusMeters) {
          cluster.add(transactions[j]);
          assigned[j] = true;
        }
      }

      clusters.add(cluster);
    }

    // 将每个聚类转换为 LocationPattern
    final patterns = <LocationPattern>[];
    for (final cluster in clusters) {
      if (cluster.isEmpty) continue;

      // 计算聚类中心点
      double sumLat = 0, sumLon = 0;
      double totalAmount = 0;
      for (final tx in cluster) {
        sumLat += tx.position.latitude;
        sumLon += tx.position.longitude;
        totalAmount += tx.amount;
      }

      final centerLat = sumLat / cluster.length;
      final centerLon = sumLon / cluster.length;
      final averageAmount = totalAmount / cluster.length;

      // 取聚类中最常见的 categoryId 作为代表
      String? dominantCategory;
      final categoryCounts = <String, int>{};
      for (final tx in cluster) {
        if (tx.categoryId != null) {
          categoryCounts[tx.categoryId!] =
              (categoryCounts[tx.categoryId!] ?? 0) + 1;
        }
      }
      if (categoryCounts.isNotEmpty) {
        dominantCategory = categoryCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }

      patterns.add(LocationPattern(
        location: Position(
          latitude: centerLat,
          longitude: centerLon,
          timestamp: cluster.last.timestamp,
        ),
        locationName:
            '${centerLat.toStringAsFixed(4)},${centerLon.toStringAsFixed(4)}',
        frequency: cluster.length,
        averageAmount: averageAmount,
        totalAmount: totalAmount,
        categoryId: dominantCategory,
      ));
    }

    // 按频率降序排列，高频地点优先
    patterns.sort((a, b) => b.frequency.compareTo(a.frequency));

    return patterns;
  }

  Future<List<SavingSuggestion>> _generateAlternativeLocationSuggestions(
    List<LocationPattern> patterns,
  ) async {
    final suggestions = <SavingSuggestion>[];

    for (final pattern in patterns) {
      if (pattern.averageAmount > 50 && pattern.frequency > 5) {
        suggestions.add(SavingSuggestion(
          type: SavingSuggestionType.alternativeLocation,
          title: '发现更实惠的替代地点',
          description: '您经常在${pattern.locationName}消费，'
              '附近有其他选择可能更实惠',
          potentialSaving: pattern.averageAmount * 0.2 * pattern.frequency,
          actionable: '尝试附近其他商家，可能节省20%费用',
        ));
      }
    }

    return suggestions;
  }

  Future<List<SavingSuggestion>> _generateCommuteOptimizationSuggestions(
    List<TransactionWithLocation> transactions,
  ) async {
    final suggestions = <SavingSuggestion>[];

    // 筛选交通类消费交易
    final transportTransactions = transactions.where((tx) {
      final cat = tx.categoryId?.toLowerCase() ?? '';
      return cat.contains('transport') ||
          cat.contains('commute') ||
          cat.contains('traffic') ||
          cat.contains('taxi') ||
          cat.contains('bus') ||
          cat.contains('subway') ||
          cat.contains('metro');
    }).toList();

    if (transportTransactions.isEmpty) return suggestions;

    // 按日期分组，识别重复通勤模式
    final dayGroups = <String, List<TransactionWithLocation>>{};
    for (final tx in transportTransactions) {
      final dayKey =
          '${tx.timestamp.year}-${tx.timestamp.month}-${tx.timestamp.day}';
      dayGroups.putIfAbsent(dayKey, () => []).add(tx);
    }

    // 统计通勤天数和总花费
    final commuteDays = dayGroups.length;
    final totalCommuteCost = transportTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount,
    );
    final avgDailyCost =
        commuteDays > 0 ? totalCommuteCost / commuteDays : 0.0;

    // 如果有持续的日常通勤消费，建议优化
    if (commuteDays >= 5 && avgDailyCost > 10) {
      final monthlyEstimate = avgDailyCost * 22; // 按22个工作日估算
      final potentialSaving = monthlyEstimate * 0.15; // 预估可节省15%

      suggestions.add(SavingSuggestion(
        type: SavingSuggestionType.commuteOptimization,
        title: '通勤交通费用优化',
        description: '过去 $commuteDays 天您的日均交通花费为'
            '${avgDailyCost.toStringAsFixed(1)}元，'
            '月度预估约${monthlyEstimate.toStringAsFixed(0)}元',
        potentialSaving: potentialSaving,
        actionable: '建议办理公交/地铁月卡或通勤套餐，预计每月节省'
            '${potentialSaving.toStringAsFixed(0)}元',
      ));
    }

    // 如果经常使用打车，建议降级出行方式
    final taxiTransactions = transportTransactions.where((tx) {
      final cat = tx.categoryId?.toLowerCase() ?? '';
      return cat.contains('taxi');
    }).toList();

    if (taxiTransactions.length >= 10) {
      final taxiTotal = taxiTransactions.fold<double>(
        0.0,
        (sum, tx) => sum + tx.amount,
      );
      final avgTaxiCost = taxiTotal / taxiTransactions.length;

      suggestions.add(SavingSuggestion(
        type: SavingSuggestionType.commuteOptimization,
        title: '减少打车次数',
        description: '您共打车${taxiTransactions.length}次，'
            '平均每次${avgTaxiCost.toStringAsFixed(1)}元',
        potentialSaving: taxiTotal * 0.5,
        actionable: '将部分打车出行替换为公共交通，预计可节省50%交通费用',
      ));
    }

    return suggestions;
  }

  List<SavingSuggestion> _generateCategoryConsolidationSuggestions(
    List<LocationPattern> patterns,
  ) {
    final suggestions = <SavingSuggestion>[];

    // 按分类聚合位置模式
    final categoryPatterns = <String, List<LocationPattern>>{};
    for (final pattern in patterns) {
      final category = pattern.categoryId;
      if (category != null && category.isNotEmpty) {
        categoryPatterns.putIfAbsent(category, () => []).add(pattern);
      }
    }

    // 找到在3个以上不同地点消费的分类
    for (final entry in categoryPatterns.entries) {
      final categoryId = entry.key;
      final locations = entry.value;

      if (locations.length >= 3) {
        // 计算该分类的总消费金额
        final totalSpent = locations.fold<double>(
          0.0,
          (sum, p) => sum + p.totalAmount,
        );

        // 找到该分类中平均单价最低的地点
        final cheapest = locations.reduce(
          (a, b) => a.averageAmount <= b.averageAmount ? a : b,
        );

        // 如果把所有消费集中到最便宜的地点，可以节省的金额
        final totalFrequency = locations.fold<int>(
          0,
          (sum, p) => sum + p.frequency,
        );
        final consolidatedCost = cheapest.averageAmount * totalFrequency;
        final potentialSaving = totalSpent - consolidatedCost;

        if (potentialSaving > 0) {
          suggestions.add(SavingSuggestion(
            type: SavingSuggestionType.categoryConsolidation,
            title: '集中$categoryId类消费',
            description: '您在${locations.length}个不同地点进行了$categoryId类消费，'
                '总计${totalSpent.toStringAsFixed(0)}元',
            potentialSaving: potentialSaving,
            actionable: '建议将$categoryId类消费集中在'
                '${cheapest.locationName}附近，该地点平均消费最低'
                '（${cheapest.averageAmount.toStringAsFixed(1)}元/次），'
                '预计可节省${potentialSaving.toStringAsFixed(0)}元',
          ));
        }
      }
    }

    // 按潜在节省金额降序排列
    suggestions.sort((a, b) => b.potentialSaving.compareTo(a.potentialSaving));

    return suggestions;
  }
}

/// 位置消费模式
class LocationPattern {
  final Position location;
  final String locationName;
  final int frequency;
  final double averageAmount;
  final double totalAmount;
  final String? categoryId;

  const LocationPattern({
    required this.location,
    required this.locationName,
    required this.frequency,
    required this.averageAmount,
    required this.totalAmount,
    this.categoryId,
  });
}

// ========== 4. 通勤分析服务 ==========

/// 通勤路线
class CommuteRoute {
  final String id;
  final Position start;
  final Position end;
  final String name;
  final int frequency; // 使用频率
  final double averageTime; // 平均通勤时间（分钟）
  final double totalCost; // 总花费

  const CommuteRoute({
    required this.id,
    required this.start,
    required this.end,
    required this.name,
    required this.frequency,
    required this.averageTime,
    required this.totalCost,
  });
}

/// 通勤消费分析
class CommuteAnalysis {
  final CommuteRoute route;
  final double monthlyAvgCost;
  final double costPerTrip;
  final List<TransactionWithLocation> commuteTransactions;
  final List<String> suggestions;

  const CommuteAnalysis({
    required this.route,
    required this.monthlyAvgCost,
    required this.costPerTrip,
    required this.commuteTransactions,
    required this.suggestions,
  });
}

/// 通勤分析服务
/// 对应设计文档第14.8节
class CommuteAnalysisService {
  final UserHomeLocationService _homeService;

  CommuteAnalysisService({
    UserHomeLocationService? homeService,
  }) : _homeService = homeService ?? UserHomeLocationService();

  /// 分析通勤模式
  Future<List<CommuteRoute>> analyzeCommutePatterns({
    required List<TransactionWithLocation> transactions,
  }) async {
    final routes = <CommuteRoute>[];

    // 1. 获取家和公司位置
    final homeLocations = await _homeService.getHomeLocations();
    final home = homeLocations.firstWhere(
      (loc) => loc.type == HomeLocationType.home,
      orElse: () => homeLocations.first,
    );
    final office = homeLocations.firstWhere(
      (loc) => loc.type == HomeLocationType.office,
      orElse: () => homeLocations.last,
    );

    // 2. 识别通勤交易
    final commuteTx = _identifyCommuteTransactions(transactions, home, office);

    // 3. 构建通勤路线
    if (commuteTx.isNotEmpty) {
      final totalCost = commuteTx.fold<double>(
        0.0,
        (sum, tx) => sum + tx.amount,
      );

      final averageTime = _estimateAverageCommuteTime(commuteTx);

      routes.add(CommuteRoute(
        id: 'home_to_office',
        start: home.center,
        end: office.center,
        name: '家 → 公司',
        frequency: commuteTx.length,
        averageTime: averageTime,
        totalCost: totalCost,
      ));
    }

    return routes;
  }

  /// 生成通勤优化建议
  Future<CommuteAnalysis> analyzeCommute({
    required CommuteRoute route,
    required List<TransactionWithLocation> transactions,
  }) async {
    // Calculate actual month count from the transaction date range
    int monthCount = 1;
    if (transactions.length >= 2) {
      final sortedDates = transactions
          .map((tx) => tx.timestamp)
          .toList()
        ..sort();
      final firstDate = sortedDates.first;
      final lastDate = sortedDates.last;
      final daySpan = lastDate.difference(firstDate).inDays;
      monthCount = (daySpan / 30).ceil();
      if (monthCount < 1) monthCount = 1;
    }
    final monthlyAvgCost = route.totalCost / monthCount;
    final costPerTrip = route.frequency > 0 ? route.totalCost / route.frequency : 0.0;

    final suggestions = <String>[];

    // 生成优化建议
    if (costPerTrip > 20) {
      suggestions.add('考虑办理月卡或优惠套餐，可节省15-20%');
    }

    if (route.frequency > 40) {
      suggestions.add('通勤频率较高，建议选择固定路线以获得稳定价格');
    }

    return CommuteAnalysis(
      route: route,
      monthlyAvgCost: monthlyAvgCost,
      costPerTrip: costPerTrip,
      commuteTransactions: transactions,
      suggestions: suggestions,
    );
  }

  /// Estimate average commute time in minutes from transaction timestamps.
  ///
  /// Groups commute transactions by date. On days with 2+ commute transactions,
  /// treats the time gap between the first and second transaction as a commute
  /// duration estimate. Returns the average of all such estimates.
  /// When insufficient data is available, defaults to 30 minutes.
  double _estimateAverageCommuteTime(List<TransactionWithLocation> commuteTx) {
    // Group transactions by date
    final dayGroups = <String, List<TransactionWithLocation>>{};
    for (final tx in commuteTx) {
      final dayKey =
          '${tx.timestamp.year}-${tx.timestamp.month}-${tx.timestamp.day}';
      dayGroups.putIfAbsent(dayKey, () => []).add(tx);
    }

    final commuteGapsMinutes = <double>[];

    for (final dayTxs in dayGroups.values) {
      if (dayTxs.length < 2) continue;

      // Sort by timestamp within the day
      dayTxs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // The gap between the first two commute transactions on a day
      // approximates a single commute duration
      final gapMinutes =
          dayTxs[1].timestamp.difference(dayTxs[0].timestamp).inMinutes.abs();

      // Only count reasonable commute durations (5-180 minutes)
      if (gapMinutes >= 5 && gapMinutes <= 180) {
        commuteGapsMinutes.add(gapMinutes.toDouble());
      }
    }

    if (commuteGapsMinutes.isEmpty) {
      // Default when data is insufficient to calculate actual commute time
      return 30.0;
    }

    final totalMinutes =
        commuteGapsMinutes.reduce((sum, val) => sum + val);
    return totalMinutes / commuteGapsMinutes.length;
  }

  List<TransactionWithLocation> _identifyCommuteTransactions(
    List<TransactionWithLocation> transactions,
    HomeLocation home,
    HomeLocation office,
  ) {
    final commuteTx = <TransactionWithLocation>[];

    for (final tx in transactions) {
      // 判断是否在通勤路线上（简化版：距离家或公司较近）
      final distanceToHome = tx.position.distanceTo(home.center);
      final distanceToOffice = tx.position.distanceTo(office.center);

      if (distanceToHome < 1000 || distanceToOffice < 1000) {
        commuteTx.add(tx);
      }
    }

    return commuteTx;
  }
}
