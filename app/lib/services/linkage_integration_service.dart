import 'package:flutter/material.dart';

import 'data_linkage_service.dart';
import '../models/transaction.dart';

/// 数据联动与各系统集成服务
/// 对应设计文档第12.9节：与其他系统的集成
///
/// 核心功能：
/// 1. 与钱龄系统集成
/// 2. 与预算系统集成
/// 3. 与家庭账本集成
/// 4. 与位置智能集成
/// 5. 与语音交互集成
/// 6. 与AI洞察集成
///
/// 使用示例：
/// ```dart
/// final integration = LinkageIntegrationService(
///   linkageService: dataLinkageService,
/// );
///
/// // 从钱龄卡片联动到钱龄详情
/// integration.linkToMoneyAgeDetail(
///   level: 'green',
///   levelName: '绿色钱龄(0-3天)',
/// );
/// ```
class LinkageIntegrationService {
  final DataLinkageService linkageService;

  LinkageIntegrationService({
    required this.linkageService,
  });

  // ========== 钱龄系统集成 (第7章) ==========

  /// 钱龄卡片点击联动
  Future<void> linkToMoneyAgeDetail({
    required String level,
    required String levelName,
    Widget? detailPage,
  }) async {
    await linkageService.onMoneyAgeCardTap(
      level: level,
      levelName: levelName,
      detailPage: detailPage,
    );
  }

  /// 钱龄趋势图数据点联动
  Future<void> linkToMoneyAgeDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required String level,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'moneyage_$level_${startDate.millisecondsSinceEpoch}',
      title: '$level钱龄详情',
      filterValue: {
        'moneyAgeLevel': level,
        'startDate': startDate,
        'endDate': endDate,
      },
      targetPage: detailPage,
    );
  }

  /// 资源池卡片联动
  Future<void> linkToResourcePool({
    required String poolId,
    required String poolName,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'pool_$poolId',
      title: poolName,
      filterValue: {'poolId': poolId},
      targetPage: detailPage,
    );
  }

  // ========== 预算系统集成 (第8章) ==========

  /// 预算概览卡片联动
  Future<void> linkToBudgetDetail({
    required String budgetId,
    required String budgetName,
    Widget? detailPage,
  }) async {
    await linkageService.onBudgetCardTap(
      budgetId: budgetId,
      budgetName: budgetName,
      detailPage: detailPage,
    );
  }

  /// 小金库卡片联动
  Future<void> linkToPiggyBankDetail({
    required String piggyBankId,
    required String piggyBankName,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'piggybank_$piggyBankId',
      title: piggyBankName,
      filterValue: {'piggyBankId': piggyBankId},
      targetPage: detailPage,
    );
  }

  /// 预算执行进度联动
  Future<void> linkToBudgetTransactions({
    required String budgetId,
    required String categoryId,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'budget_trans_$budgetId',
      title: '预算交易明细',
      filterValue: {
        'budgetId': budgetId,
        'categoryId': categoryId,
      },
      targetPage: detailPage,
    );
  }

  // ========== 家庭账本集成 (第13章) ==========

  /// 家庭成员卡片联动
  Future<void> linkToFamilyMemberDetail({
    required String memberId,
    required String memberName,
    Widget? detailPage,
  }) async {
    await linkageService.onFamilyMemberCardTap(
      memberId: memberId,
      memberName: memberName,
      detailPage: detailPage,
    );
  }

  /// 家庭成员对比图联动
  Future<void> linkToFamilyComparison({
    required List<String> memberIds,
    required String comparisonType, // 'spending', 'category', 'trend'
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'family_compare_${memberIds.join("_")}',
      title: '成员对比分析',
      filterValue: {
        'memberIds': memberIds,
        'comparisonType': comparisonType,
      },
      targetPage: detailPage,
    );
  }

  /// 家庭报表联动
  Future<void> linkToFamilyReport({
    required String familyId,
    required DateTime period,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'family_report_$familyId',
      title: '家庭财务报表',
      filterValue: {
        'familyId': familyId,
        'period': period,
      },
      targetPage: detailPage,
    );
  }

  // ========== 位置智能集成 (第14章) ==========

  /// 位置热力图联动
  Future<void> linkToLocationDetail({
    required double latitude,
    required double longitude,
    required String locationName,
    Widget? detailPage,
  }) async {
    await linkageService.onLocationHeatmapTap(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      detailPage: detailPage,
    );
  }

  /// 商圈消费联动
  Future<void> linkToBusinessDistrictDetail({
    required String districtId,
    required String districtName,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'district_$districtId',
      title: districtName,
      filterValue: {'districtId': districtId},
      targetPage: detailPage,
    );
  }

  /// POI消费联动
  Future<void> linkToPoiDetail({
    required String poiId,
    required String poiName,
    required String poiType,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'poi_$poiId',
      title: poiName,
      filterValue: {
        'poiId': poiId,
        'poiType': poiType,
      },
      targetPage: detailPage,
    );
  }

  // ========== 习惯培养集成 (第9章) ==========

  /// 习惯打卡日历联动
  Future<void> linkToHabitDetail({
    required String habitType,
    required DateTime date,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'habit_$habitType_${date.millisecondsSinceEpoch}',
      title: '习惯打卡详情',
      filterValue: {
        'habitType': habitType,
        'date': date,
      },
      targetPage: detailPage,
    );
  }

  /// 成就卡片联动
  Future<void> linkToAchievementDetail({
    required String achievementId,
    required String achievementName,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'achievement_$achievementId',
      title: achievementName,
      filterValue: {'achievementId': achievementId},
      targetPage: detailPage,
    );
  }

  /// 连续记账统计联动
  Future<void> linkToStreakDetail({
    required int currentStreak,
    required int longestStreak,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'streak_detail',
      title: '连续记账详情',
      filterValue: {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      },
      targetPage: detailPage,
    );
  }

  // ========== AI洞察集成 (第10章) ==========

  /// AI洞察卡片联动
  Future<void> linkToInsightDetail({
    required String insightId,
    required String insightType,
    required String title,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'insight_$insightId',
      title: title,
      filterValue: {
        'insightId': insightId,
        'insightType': insightType,
      },
      targetPage: detailPage,
    );
  }

  /// 异常消费联动
  Future<void> linkToAnomalyTransactions({
    required String anomalyType,
    required List<String> transactionIds,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'anomaly_$anomalyType',
      title: '异常消费详情',
      filterValue: {
        'anomalyType': anomalyType,
        'transactionIds': transactionIds,
      },
      targetPage: detailPage,
    );
  }

  /// 消费趋势预测联动
  Future<void> linkToTrendPrediction({
    required String category,
    required String predictionPeriod,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'prediction_$category',
      title: '趋势预测详情',
      filterValue: {
        'category': category,
        'predictionPeriod': predictionPeriod,
      },
      targetPage: detailPage,
    );
  }

  // ========== 语音交互集成 (第18章) ==========

  /// 语音识别记录联动
  Future<void> linkToVoiceRecordDetail({
    required String recordId,
    required String recognizedText,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'voice_$recordId',
      title: '语音识别详情',
      filterValue: {
        'recordId': recordId,
        'recognizedText': recognizedText,
      },
      targetPage: detailPage,
    );
  }

  /// 语音生成的交易联动
  Future<void> linkToVoiceGeneratedTransaction({
    required String transactionId,
    required String voiceRecordId,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'voice_trans_$transactionId',
      title: '语音记账详情',
      filterValue: {
        'transactionId': transactionId,
        'voiceRecordId': voiceRecordId,
      },
      targetPage: detailPage,
    );
  }

  // ========== 自学习系统集成 (第17章) ==========

  /// 个性化推荐联动
  Future<void> linkToPersonalizedRecommendation({
    required String recommendationType,
    required List<String> recommendedCategories,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'recommendation_$recommendationType',
      title: '个性化推荐',
      filterValue: {
        'recommendationType': recommendationType,
        'recommendedCategories': recommendedCategories,
      },
      targetPage: detailPage,
    );
  }

  /// 用户画像联动
  Future<void> linkToUserProfile({
    required String userId,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'profile_$userId',
      title: '用户消费画像',
      filterValue: {'userId': userId},
      targetPage: detailPage,
    );
  }

  // ========== 通用联动方法 ==========

  /// 从交易列表联动到交易详情
  Future<void> linkToTransactionDetail({
    required Transaction transaction,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'transaction_${transaction.id}',
      title: transaction.note ?? '交易详情',
      filterValue: {'transactionId': transaction.id},
      targetPage: detailPage,
    );
  }

  /// 从分类统计联动到分类详情
  Future<void> linkToCategoryStatistics({
    required String categoryId,
    required String categoryName,
    required DateTime startDate,
    required DateTime endDate,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'category_stats_$categoryId',
      title: '$categoryName统计',
      filterValue: {
        'categoryId': categoryId,
        'startDate': startDate,
        'endDate': endDate,
      },
      targetPage: detailPage,
    );
  }

  /// 从账户卡片联动到账户详情
  Future<void> linkToAccountTransactions({
    required String accountId,
    required String accountName,
    Widget? detailPage,
  }) async {
    await linkageService.onAccountCardTap(
      accountId: accountId,
      accountName: accountName,
      detailPage: detailPage,
    );
  }

  /// 从标签联动到标签相关交易
  Future<void> linkToTagTransactions({
    required String tagId,
    required String tagName,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'tag_$tagId',
      title: '#$tagName',
      filterValue: {'tagId': tagId},
      targetPage: detailPage,
    );
  }

  // ========== 复合联动 ==========

  /// 多维度联动（同时应用多个筛选条件）
  Future<void> linkWithMultipleDimensions({
    required String title,
    required Map<String, dynamic> filters,
    Widget? detailPage,
  }) async {
    // 先应用筛选条件
    for (final _ in filters.entries) {
      // 将filter转换为FilterCondition并添加
      // TODO: 根据filter类型创建对应的FilterCondition
    }

    // 然后进行下钻
    await linkageService.drillDown(
      id: 'multi_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      filterValue: filters,
      targetPage: detailPage,
    );
  }

  /// 时间范围对比联动
  Future<void> linkToTimeComparison({
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
    Widget? detailPage,
  }) async {
    await linkageService.drillDown(
      id: 'time_compare',
      title: '时间对比分析',
      filterValue: {
        'period1Start': period1Start,
        'period1End': period1End,
        'period2Start': period2Start,
        'period2End': period2End,
      },
      targetPage: detailPage,
    );
  }
}
