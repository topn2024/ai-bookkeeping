import 'dart:async';

import '../models/common_types.dart';
import 'location_service.dart' hide CityTier, CityTierExtension, CityInfo, CityLocation,
  CityLocationService, UserHomeLocationService, CrossRegionSpendingService, CrossRegionResult;
import 'location_data_services.dart' hide CityTier, CityTierExtension, CityInfo, CityLocation;
import 'location_business_services.dart';
import 'geofence_background_service.dart';

/// 位置增强预算服务
/// 对应设计文档第14章 - 第4层：系统集成服务
///
/// 这是位置智能化的集成服务层，整合：
/// 1. LocalizedBudgetService - 本地化类目推荐
/// 2. LocalizedAmountService - 本地化金额建议
/// 3. GeofenceAlertService - 地理围栏提醒
/// 4. CrossRegionSpendingService - 异地消费识别
///
/// 实现位置智能化集成全景图的核心功能

// ========== 预算建议数据模型 ==========

/// 增强的预算建议
class EnhancedBudgetRecommendation {
  final String categoryId;
  final String categoryName;
  final double suggestedAmount;
  final double minAmount;
  final double maxAmount;
  final CityTier cityTier;
  final String cityName;
  final String reasoning;
  final List<String> tips;
  final bool isTemporaryLocation;

  const EnhancedBudgetRecommendation({
    required this.categoryId,
    required this.categoryName,
    required this.suggestedAmount,
    required this.minAmount,
    required this.maxAmount,
    required this.cityTier,
    required this.cityName,
    required this.reasoning,
    required this.tips,
    required this.isTemporaryLocation,
  });
}

/// 位置感知预算分析
class LocationAwareBudgetAnalysis {
  final double totalBudget;
  final double dailyBudget;
  final double temporaryBudget;
  final Map<String, double> categoryBudgets;
  final List<BudgetAlert> alerts;
  final List<String> recommendations;

  const LocationAwareBudgetAnalysis({
    required this.totalBudget,
    required this.dailyBudget,
    required this.temporaryBudget,
    required this.categoryBudgets,
    required this.alerts,
    required this.recommendations,
  });
}

/// 预算警报
class BudgetAlert {
  final BudgetAlertType type;
  final String title;
  final String message;
  final double amount;
  final double budgetLimit;
  final String? locationName;

  const BudgetAlert({
    required this.type,
    required this.title,
    required this.message,
    required this.amount,
    required this.budgetLimit,
    this.locationName,
  });
}

/// 预算警报类型
enum BudgetAlertType {
  geofenceWarning,    // 围栏警告
  overBudget,         // 超预算
  temporarySpending,  // 临时消费
  crossRegion,        // 跨区域
}

// ========== 本地化预算服务 ==========

/// 本地化类目信息
class LocalizedCategory {
  final String categoryId;
  final String name;
  final double suggestedPercentage;
  final int priority;

  const LocalizedCategory({
    required this.categoryId,
    required this.name,
    required this.suggestedPercentage,
    required this.priority,
  });
}

/// 本地化预算服务
class LocalizedBudgetService {
  Future<List<LocalizedCategory>> getLocalizedCategories({
    required CityTier cityTier,
  }) async {
    // 基于城市级别返回本地化类目建议
    switch (cityTier) {
      case CityTier.tier1:
      case CityTier.newTier1:
        return _getTier1Categories();
      case CityTier.tier2:
        return _getTier2Categories();
      default:
        return _getDefaultCategories();
    }
  }

  List<LocalizedCategory> _getTier1Categories() => const [
    LocalizedCategory(categoryId: 'food', name: '餐饮', suggestedPercentage: 0.20, priority: 1),
    LocalizedCategory(categoryId: 'transport', name: '交通', suggestedPercentage: 0.15, priority: 2),
    LocalizedCategory(categoryId: 'housing', name: '住房', suggestedPercentage: 0.30, priority: 3),
    LocalizedCategory(categoryId: 'entertainment', name: '娱乐', suggestedPercentage: 0.10, priority: 4),
    LocalizedCategory(categoryId: 'shopping', name: '购物', suggestedPercentage: 0.10, priority: 5),
    LocalizedCategory(categoryId: 'utilities', name: '生活缴费', suggestedPercentage: 0.05, priority: 6),
    LocalizedCategory(categoryId: 'other', name: '其他', suggestedPercentage: 0.10, priority: 7),
  ];

  List<LocalizedCategory> _getTier2Categories() => const [
    LocalizedCategory(categoryId: 'food', name: '餐饮', suggestedPercentage: 0.25, priority: 1),
    LocalizedCategory(categoryId: 'housing', name: '住房', suggestedPercentage: 0.25, priority: 2),
    LocalizedCategory(categoryId: 'transport', name: '交通', suggestedPercentage: 0.10, priority: 3),
    LocalizedCategory(categoryId: 'entertainment', name: '娱乐', suggestedPercentage: 0.10, priority: 4),
    LocalizedCategory(categoryId: 'shopping', name: '购物', suggestedPercentage: 0.10, priority: 5),
    LocalizedCategory(categoryId: 'utilities', name: '生活缴费', suggestedPercentage: 0.05, priority: 6),
    LocalizedCategory(categoryId: 'other', name: '其他', suggestedPercentage: 0.15, priority: 7),
  ];

  List<LocalizedCategory> _getDefaultCategories() => const [
    LocalizedCategory(categoryId: 'food', name: '餐饮', suggestedPercentage: 0.30, priority: 1),
    LocalizedCategory(categoryId: 'housing', name: '住房', suggestedPercentage: 0.20, priority: 2),
    LocalizedCategory(categoryId: 'transport', name: '交通', suggestedPercentage: 0.08, priority: 3),
    LocalizedCategory(categoryId: 'entertainment', name: '娱乐', suggestedPercentage: 0.10, priority: 4),
    LocalizedCategory(categoryId: 'shopping', name: '购物', suggestedPercentage: 0.10, priority: 5),
    LocalizedCategory(categoryId: 'utilities', name: '生活缴费', suggestedPercentage: 0.05, priority: 6),
    LocalizedCategory(categoryId: 'other', name: '其他', suggestedPercentage: 0.17, priority: 7),
  ];
}

// ========== 位置增强预算服务 ==========

/// 位置增强预算服务
/// 整合所有位置智能化能力，提供统一的预算管理接口
class LocationEnhancedBudgetService {
  final LocalizedBudgetService _localizedBudgetService;
  final LocalizedAmountService _amountService;
  final CrossRegionSpendingService _crossRegionService;
  final CityLocationService _cityService;
  final GeofenceBackgroundService? _geofenceService;

  LocationEnhancedBudgetService({
    LocalizedBudgetService? localizedBudgetService,
    LocalizedAmountService? amountService,
    CrossRegionSpendingService? crossRegionService,
    CityLocationService? cityService,
    GeofenceBackgroundService? geofenceService,
  })  : _localizedBudgetService = localizedBudgetService ?? LocalizedBudgetService(),
        _amountService = amountService ?? LocalizedAmountService(),
        _crossRegionService = crossRegionService ?? CrossRegionSpendingService(),
        _cityService = cityService ?? CityLocationService(),
        _geofenceService = geofenceService;

  /// 获取增强的预算建议
  /// 结合位置、城市级别、用户历史消费给出智能预算建议
  Future<List<EnhancedBudgetRecommendation>> getEnhancedBudgetRecommendations({
    Position? currentPosition,
    List<String>? categoryIds,
  }) async {
    final recommendations = <EnhancedBudgetRecommendation>[];

    // 1. 获取当前城市信息
    CityInfo? currentCity;
    if (currentPosition != null) {
      currentCity = await _cityService.identifyCity(currentPosition);
    }
    currentCity ??= await _cityService.getCurrentCity();

    final cityTier = currentCity?.tier ?? CityTier.tier3;
    final cityName = currentCity?.name ?? '当前城市';

    // 2. 检测是否在临时位置（异地）
    bool isTemporary = false;
    if (currentPosition != null) {
      isTemporary = await _crossRegionService.isTemporarySpending(currentPosition);
    }

    // 3. 获取本地化类目建议
    final localizedCategories = await _localizedBudgetService.getLocalizedCategories(
      cityTier: cityTier,
    );

    // 4. 为每个类目生成增强建议
    final categoriesToProcess = categoryIds ??
        localizedCategories.map((c) => c.categoryId).toList();

    for (final categoryId in categoriesToProcess) {
      final category = localizedCategories.firstWhere(
        (c) => c.categoryId == categoryId,
        orElse: () => localizedCategories.first,
      );

      // 获取本地化金额建议
      final amountSuggestion = await _amountService.getSuggestedAmount(
        categoryId: categoryId,
        categoryName: category.name,
        currentPosition: currentPosition,
      );

      // 生成提示
      final tips = _generateTips(
        category: category,
        cityTier: cityTier,
        isTemporary: isTemporary,
      );

      // 如果是临时位置，调整预算范围
      var suggestedAmount = amountSuggestion.avgAmount;
      var minAmount = amountSuggestion.suggestedMin;
      var maxAmount = amountSuggestion.suggestedMax;

      if (isTemporary) {
        // 临时消费建议更宽松（+20%）
        suggestedAmount *= 1.2;
        minAmount *= 1.2;
        maxAmount *= 1.2;
      }

      recommendations.add(EnhancedBudgetRecommendation(
        categoryId: categoryId,
        categoryName: category.name,
        suggestedAmount: suggestedAmount,
        minAmount: minAmount,
        maxAmount: maxAmount,
        cityTier: cityTier,
        cityName: cityName,
        reasoning: _generateReasoning(
          categoryName: category.name,
          cityName: cityName,
          cityTier: cityTier,
          isTemporary: isTemporary,
        ),
        tips: tips,
        isTemporaryLocation: isTemporary,
      ));
    }

    return recommendations;
  }

  /// 分析位置感知预算状况
  /// 提供日常预算和临时预算的分离分析
  Future<LocationAwareBudgetAnalysis> analyzeBudget({
    required double totalBudget,
    required List<TransactionWithLocation> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final alerts = <BudgetAlert>[];
    final recommendations = <String>[];

    // 1. 获取跨区域统计
    final crossRegionStats = await _crossRegionService.getStatistics(
      transactions: transactions,
      startDate: startDate,
      endDate: endDate,
    );

    // 2. 计算日常预算和临时预算分配
    // 建议：85% 日常预算，15% 临时预算
    final dailyBudget = totalBudget * 0.85;
    final temporaryBudget = totalBudget * 0.15;

    final actualDailySpending = crossRegionStats.localAmount;
    final actualTemporarySpending =
        crossRegionStats.crossCityAmount + crossRegionStats.crossProvinceAmount;

    // 3. 检查预算超支情况
    if (actualDailySpending > dailyBudget) {
      alerts.add(BudgetAlert(
        type: BudgetAlertType.overBudget,
        title: '日常预算超支',
        message: '您的日常消费已超出预算 ${((actualDailySpending - dailyBudget) / dailyBudget * 100).toStringAsFixed(1)}%',
        amount: actualDailySpending,
        budgetLimit: dailyBudget,
      ));

      recommendations.add('建议审查日常开支，寻找可优化的消费项目');
    }

    if (actualTemporarySpending > temporaryBudget) {
      alerts.add(BudgetAlert(
        type: BudgetAlertType.temporarySpending,
        title: '临时消费超支',
        message: '异地消费已超出临时预算 ${((actualTemporarySpending - temporaryBudget) / temporaryBudget * 100).toStringAsFixed(1)}%',
        amount: actualTemporarySpending,
        budgetLimit: temporaryBudget,
      ));

      recommendations.add('异地消费较多，建议提前规划旅行预算');
    }

    // 4. 分析跨区域消费比例
    if (crossRegionStats.temporaryAmountRatio > 0.3) {
      recommendations.add(
        '异地消费占比${(crossRegionStats.temporaryAmountRatio * 100).toStringAsFixed(1)}%，'
        '建议关注是否有不必要的差旅支出'
      );
    }

    // 5. 按类目分析预算（简化版）
    final categoryBudgets = <String, double>{};
    // TODO: 实现更详细的类目预算分析

    return LocationAwareBudgetAnalysis(
      totalBudget: totalBudget,
      dailyBudget: dailyBudget,
      temporaryBudget: temporaryBudget,
      categoryBudgets: categoryBudgets,
      alerts: alerts,
      recommendations: recommendations,
    );
  }

  /// 检查位置相关预算警报
  /// 结合地理围栏和实时位置，提供主动预算提醒
  Future<List<BudgetAlert>> checkLocationAlerts({
    required Position currentPosition,
    required Map<String, double> categoryBudgets,
    required Map<String, double> categorySpending,
  }) async {
    final alerts = <BudgetAlert>[];

    // 1. 检查地理围栏警报
    if (_geofenceService != null) {
      final geofences = _geofenceService.activeGeofences;

      for (final geofence in geofences) {
        final centerPosition = Position(
          latitude: geofence.center.latitude,
          longitude: geofence.center.longitude,
          timestamp: DateTime.now(),
        );
        final distance = currentPosition.distanceTo(centerPosition);

        if (distance <= geofence.radius) {
          // 在围栏内，检查相关类目预算
          final categoryId = geofence.metadata['categoryId'] as String?;
          if (categoryId != null) {
            final budget = categoryBudgets[categoryId] ?? 0.0;
            final spending = categorySpending[categoryId] ?? 0.0;

            if (spending >= budget * 0.8) {
              alerts.add(BudgetAlert(
                type: BudgetAlertType.geofenceWarning,
                title: '预算警告',
                message: '您已进入${geofence.name}，该区域相关类目预算已使用${(spending / budget * 100).toStringAsFixed(0)}%',
                amount: spending,
                budgetLimit: budget,
                locationName: geofence.name,
              ));
            }
          }
        }
      }
    }

    // 2. 检查跨区域消费警报
    final crossRegionStatus = await _crossRegionService.detectCrossRegion(currentPosition);
    if (crossRegionStatus.isTemporary) {
      alerts.add(BudgetAlert(
        type: BudgetAlertType.crossRegion,
        title: crossRegionStatus.displayName,
        message: '检测到${crossRegionStatus.displayName}，注意控制临时消费预算',
        amount: 0.0,
        budgetLimit: 0.0,
      ));
    }

    return alerts;
  }

  /// 获取位置优化建议
  /// 基于消费模式和位置分析，提供预算优化建议
  Future<List<String>> getOptimizationSuggestions({
    required List<TransactionWithLocation> transactions,
    Position? currentPosition,
  }) async {
    final suggestions = <String>[];

    // 1. 获取跨区域统计
    final stats = await _crossRegionService.getStatistics(
      transactions: transactions,
    );

    // 2. 分析异地消费模式
    if (stats.temporaryRatio > 0.2) {
      suggestions.add(
        '您有${(stats.temporaryRatio * 100).toStringAsFixed(0)}%的交易发生在异地，'
        '考虑为出差旅行单独设置预算'
      );
    }

    // 3. 城市级别建议
    if (currentPosition != null) {
      final currentCity = await _cityService.identifyCity(currentPosition);
      final homeCity = await _cityService.getHomeCity();

      if (currentCity != null && homeCity != null && currentCity.code != homeCity.code) {
        final costDiff = currentCity.tier.costOfLivingMultiplier /
                        homeCity.tier.costOfLivingMultiplier;

        if (costDiff > 1.2) {
          suggestions.add(
            '当前城市（${currentCity.name}）生活成本比常驻地高约${((costDiff - 1) * 100).toStringAsFixed(0)}%，'
            '建议相应调整预算'
          );
        } else if (costDiff < 0.8) {
          suggestions.add(
            '当前城市（${currentCity.name}）生活成本比常驻地低约${((1 - costDiff) * 100).toStringAsFixed(0)}%，'
            '这是省钱的好机会'
          );
        }
      }
    }

    // 4. 地理围栏建议
    if (_geofenceService != null) {
      final geofences = _geofenceService.activeGeofences;
      if (geofences.isEmpty) {
        suggestions.add('建议设置地理围栏，在进入高消费区域时自动提醒');
      }
    }

    return suggestions;
  }

  /// 创建智能预算方案
  /// 基于位置、城市级别、用户偏好自动生成预算方案
  Future<SmartBudgetPlan> createSmartBudgetPlan({
    required double totalBudget,
    Position? currentPosition,
    List<TransactionWithLocation>? historicalTransactions,
  }) async {
    // 1. 获取当前城市信息
    CityInfo? currentCity;
    if (currentPosition != null) {
      currentCity = await _cityService.identifyCity(currentPosition);
    }
    currentCity ??= await _cityService.getCurrentCity();

    final cityTier = currentCity?.tier ?? CityTier.tier3;

    // 2. 获取本地化类目建议
    final localizedCategories = await _localizedBudgetService.getLocalizedCategories(
      cityTier: cityTier,
    );

    // 3. 为每个类目分配预算
    final categoryAllocations = <CategoryBudgetAllocation>[];

    // 计算总权重
    final totalWeight = localizedCategories.fold<double>(
      0.0,
      (sum, category) => sum + category.priority,
    );

    // 分配预算（85%用于日常预算）
    final dailyBudget = totalBudget * 0.85;

    for (final category in localizedCategories) {
      // 按优先级权重分配
      final allocation = dailyBudget * (category.priority / totalWeight);

      // 获取金额建议用于验证
      final amountSuggestion = await _amountService.getSuggestedAmount(
        categoryId: category.categoryId,
        categoryName: category.name,
        currentPosition: currentPosition,
      );

      categoryAllocations.add(CategoryBudgetAllocation(
        categoryId: category.categoryId,
        categoryName: category.name,
        allocatedAmount: allocation,
        suggestedMin: amountSuggestion.suggestedMin,
        suggestedMax: amountSuggestion.suggestedMax,
        reasoning: '基于${currentCity?.name ?? '当前城市'}的消费水平和类目优先级',
      ));
    }

    // 4. 临时预算（15%）
    final temporaryBudget = totalBudget * 0.15;

    return SmartBudgetPlan(
      totalBudget: totalBudget,
      dailyBudget: dailyBudget,
      temporaryBudget: temporaryBudget,
      cityTier: cityTier,
      cityName: currentCity?.name ?? '未知',
      categoryAllocations: categoryAllocations,
      createdAt: DateTime.now(),
    );
  }

  // ========== 私有辅助方法 ==========

  List<String> _generateTips({
    required LocalizedCategory category,
    required CityTier cityTier,
    required bool isTemporary,
  }) {
    final tips = <String>[];

    // 城市级别相关提示
    switch (cityTier) {
      case CityTier.tier1:
        tips.add('一线城市消费水平较高，建议精打细算');
        break;
      case CityTier.newTier1:
        tips.add('新一线城市消费水平较高，注意预算控制');
        break;
      case CityTier.tier2:
        tips.add('二线城市性价比较好，可适当享受');
        break;
      case CityTier.tier3:
      case CityTier.tier4Plus:
        tips.add('当地消费水平适中，预算较为充裕');
        break;
      case CityTier.overseas:
        tips.add('海外消费需注意汇率和额外费用');
        break;
      case CityTier.unknown:
        break;
    }

    // 临时位置提示
    if (isTemporary) {
      tips.add('异地消费，建议保留收据便于后续整理');
    }

    // 类目特定提示
    if (category.name.contains('餐饮') || category.categoryId.contains('food')) {
      tips.add('可关注团购优惠和工作日特价');
    } else if (category.name.contains('交通') || category.categoryId.contains('transport')) {
      tips.add('考虑办理月卡或充值优惠');
    } else if (category.name.contains('购物') || category.categoryId.contains('shopping')) {
      tips.add('大额消费建议货比三家');
    }

    return tips;
  }

  String _generateReasoning({
    required String categoryName,
    required String cityName,
    required CityTier cityTier,
    required bool isTemporary,
  }) {
    final buffer = StringBuffer();

    buffer.write('基于$cityName（${cityTier.displayName}）的消费水平');

    if (isTemporary) {
      buffer.write('，考虑到您当前处于异地，预算适当放宽20%');
    }

    buffer.write('，为$categoryName类目推荐的预算范围');

    return buffer.toString();
  }
}

// ========== 智能预算方案 ==========

/// 类目预算分配
class CategoryBudgetAllocation {
  final String categoryId;
  final String categoryName;
  final double allocatedAmount;
  final double suggestedMin;
  final double suggestedMax;
  final String reasoning;

  const CategoryBudgetAllocation({
    required this.categoryId,
    required this.categoryName,
    required this.allocatedAmount,
    required this.suggestedMin,
    required this.suggestedMax,
    required this.reasoning,
  });
}

/// 智能预算方案
class SmartBudgetPlan {
  final double totalBudget;
  final double dailyBudget;
  final double temporaryBudget;
  final CityTier cityTier;
  final String cityName;
  final List<CategoryBudgetAllocation> categoryAllocations;
  final DateTime createdAt;

  const SmartBudgetPlan({
    required this.totalBudget,
    required this.dailyBudget,
    required this.temporaryBudget,
    required this.cityTier,
    required this.cityName,
    required this.categoryAllocations,
    required this.createdAt,
  });

  /// 获取某个类目的预算分配
  CategoryBudgetAllocation? getAllocationForCategory(String categoryId) {
    try {
      return categoryAllocations.firstWhere((a) => a.categoryId == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// 验证预算方案是否合理
  bool validate() {
    // 1. 检查预算总和
    final categoryTotal = categoryAllocations.fold<double>(
      0.0,
      (sum, allocation) => sum + allocation.allocatedAmount,
    );

    final calculatedTotal = categoryTotal + temporaryBudget;

    // 允许1%的误差
    if ((calculatedTotal - totalBudget).abs() / totalBudget > 0.01) {
      return false;
    }

    // 2. 检查每个类目是否在建议范围内（允许超出，仅警告）
    for (final allocation in categoryAllocations) {
      if (allocation.allocatedAmount < allocation.suggestedMin * 0.5 ||
          allocation.allocatedAmount > allocation.suggestedMax * 2.0) {
        // 超出合理范围太多
        return false;
      }
    }

    return true;
  }
}
