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

  const TransactionWithLocation({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.position,
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
    // 按位置聚类交易
    final patterns = <LocationPattern>[];
    // TODO: 实现位置聚类分析逻辑
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

    // TODO: 分析通勤消费模式
    // 识别通勤路线上的重复消费

    return suggestions;
  }

  List<SavingSuggestion> _generateCategoryConsolidationSuggestions(
    List<LocationPattern> patterns,
  ) {
    final suggestions = <SavingSuggestion>[];

    // TODO: 分析分类消费分散度
    // 建议集中采购以获得优惠

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

  const LocationPattern({
    required this.location,
    required this.locationName,
    required this.frequency,
    required this.averageAmount,
    required this.totalAmount,
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

      routes.add(CommuteRoute(
        id: 'home_to_office',
        start: home.center,
        end: office.center,
        name: '家 → 公司',
        frequency: commuteTx.length,
        averageTime: 30.0, // TODO: 实际计算
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
    final monthlyAvgCost = route.totalCost / 1; // TODO: 计算实际月数
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
