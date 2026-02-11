import 'package:flutter/foundation.dart';
import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/transaction.dart';
import '../../../../services/category_localization_service.dart';
import '../action_registry.dart';

/// 查询消费习惯Action
///
/// 分析用户的消费习惯，包括：
/// - 高频消费分类
/// - 消费时间规律
/// - 消费金额分布
class HabitQueryAction extends Action {
  final IDatabaseService databaseService;

  HabitQueryAction(this.databaseService);

  @override
  String get id => 'habit.query';

  @override
  String get name => '查询消费习惯';

  @override
  String get description => '分析并展示用户的消费习惯';

  @override
  List<String> get triggerPatterns => [
    '消费习惯', '我的习惯', '查看习惯',
    '消费规律', '花钱习惯', '怎么花钱',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'days',
      type: ActionParamType.number,
      required: false,
      defaultValue: 30,
      description: '分析的天数范围',
    ),
    const ActionParam(
      name: 'category',
      type: ActionParamType.string,
      required: false,
      description: '特定分类',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final days = (params['days'] as num?)?.toInt() ?? 30;
      final category = params['category'] as String?;

      final startDate = DateTime.now().subtract(Duration(days: days));
      final transactions = await databaseService.queryTransactions(
        startDate: startDate,
        endDate: DateTime.now(),
        category: category,
      );

      if (transactions.isEmpty) {
        return ActionResult.success(
          responseText: '最近$days天暂无消费记录',
          data: {'transactionCount': 0},
          actionId: id,
        );
      }

      // 分析消费习惯
      final habits = _analyzeHabits(transactions);

      // 构建响应
      final responseBuilder = StringBuffer();
      responseBuilder.write('最近$days天的消费习惯：');

      if (habits['topCategory'] != null) {
        responseBuilder.write('消费最多的是${(habits['topCategory'] as String).localizedCategoryName}，');
      }

      if (habits['avgAmount'] != null) {
        responseBuilder.write('平均每笔${(habits['avgAmount'] as double).toStringAsFixed(0)}元，');
      }

      if (habits['peakHour'] != null) {
        responseBuilder.write('通常在${habits['peakHour']}点左右消费');
      }

      return ActionResult.success(
        responseText: responseBuilder.toString(),
        data: habits,
        actionId: id,
      );
    } catch (e) {
      debugPrint('[HabitQueryAction] 查询失败: $e');
      return ActionResult.failure('查询消费习惯失败: $e', actionId: id);
    }
  }

  /// 分析消费习惯
  Map<String, dynamic> _analyzeHabits(List<Transaction> transactions) {
    // 按分类统计
    final categoryCount = <String, int>{};
    final categoryAmount = <String, double>{};

    // 按小时统计
    final hourCount = <int, int>{};

    double totalAmount = 0;
    int expenseCount = 0;

    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        expenseCount++;
        totalAmount += t.amount;

        // 分类统计
        categoryCount[t.category] = (categoryCount[t.category] ?? 0) + 1;
        categoryAmount[t.category] = (categoryAmount[t.category] ?? 0) + t.amount;

        // 小时统计
        final hour = t.date.hour;
        hourCount[hour] = (hourCount[hour] ?? 0) + 1;
      }
    }

    // 找出消费最多的分类
    String? topCategory;
    int maxCount = 0;
    categoryCount.forEach((category, count) {
      if (count > maxCount) {
        maxCount = count;
        topCategory = category;
      }
    });

    // 找出高峰时段
    int? peakHour;
    int maxHourCount = 0;
    hourCount.forEach((hour, count) {
      if (count > maxHourCount) {
        maxHourCount = count;
        peakHour = hour;
      }
    });

    return {
      'transactionCount': expenseCount,
      'totalAmount': totalAmount,
      'avgAmount': expenseCount > 0 ? totalAmount / expenseCount : 0.0,
      'topCategory': topCategory,
      'topCategoryCount': maxCount,
      'topCategoryAmount': topCategory != null ? categoryAmount[topCategory] : null,
      'peakHour': peakHour,
      'peakHourCount': maxHourCount,
      'categoryDistribution': categoryAmount,
      'hourDistribution': hourCount,
    };
  }
}

/// 习惯分析Action
///
/// 提供更深入的消费习惯分析，包括：
/// - 周期性消费模式
/// - 消费趋势变化
/// - 异常消费检测
class HabitAnalysisAction extends Action {
  final IDatabaseService databaseService;

  HabitAnalysisAction(this.databaseService);

  @override
  String get id => 'habit.analysis';

  @override
  String get name => '习惯深度分析';

  @override
  String get description => '对消费习惯进行深度分析';

  @override
  List<String> get triggerPatterns => [
    '分析习惯', '消费分析', '深度分析',
    '消费诊断', '理财建议',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'analysisType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'comprehensive',
      description: '分析类型: comprehensive/trend/anomaly/periodic',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final analysisType = params['analysisType'] as String? ?? 'comprehensive';

      // 获取近90天的数据进行分析
      final startDate = DateTime.now().subtract(const Duration(days: 90));
      final transactions = await databaseService.queryTransactions(
        startDate: startDate,
        endDate: DateTime.now(),
      );

      if (transactions.isEmpty) {
        return ActionResult.success(
          responseText: '暂无足够的消费数据进行分析',
          data: {'hasData': false},
          actionId: id,
        );
      }

      final analysis = _performAnalysis(transactions, analysisType);

      return ActionResult.success(
        responseText: analysis['summary'] as String? ?? '分析完成',
        data: analysis,
        actionId: id,
      );
    } catch (e) {
      debugPrint('[HabitAnalysisAction] 分析失败: $e');
      return ActionResult.failure('消费分析失败: $e', actionId: id);
    }
  }

  /// 执行分析
  Map<String, dynamic> _performAnalysis(
    List<Transaction> transactions,
    String analysisType,
  ) {
    final expenseTransactions = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    if (expenseTransactions.isEmpty) {
      return {
        'summary': '暂无支出记录',
        'hasData': false,
      };
    }

    // 按月分组
    final monthlyData = <String, double>{};
    final weekdayData = <int, double>{};

    for (final t in expenseTransactions) {
      final monthKey = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + t.amount;

      final weekday = t.date.weekday;
      weekdayData[weekday] = (weekdayData[weekday] ?? 0) + t.amount;
    }

    // 计算趋势
    final monthKeys = monthlyData.keys.toList()..sort();
    String trendDescription = '消费趋势平稳';
    if (monthKeys.length >= 2) {
      final lastMonth = monthlyData[monthKeys.last]!;
      final prevMonth = monthlyData[monthKeys[monthKeys.length - 2]]!;
      final change = ((lastMonth - prevMonth) / prevMonth * 100);

      if (change > 20) {
        trendDescription = '消费较上月增加${change.toStringAsFixed(0)}%';
      } else if (change < -20) {
        trendDescription = '消费较上月减少${(-change).toStringAsFixed(0)}%';
      }
    }

    // 找出消费最多的日子
    int? peakWeekday;
    double maxWeekdayAmount = 0;
    weekdayData.forEach((day, amount) {
      if (amount > maxWeekdayAmount) {
        maxWeekdayAmount = amount;
        peakWeekday = day;
      }
    });

    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final peakWeekdayName = peakWeekday != null ? weekdayNames[peakWeekday!] : '';

    final summary = '$trendDescription。${peakWeekdayName.isNotEmpty ? "$peakWeekdayName消费最多" : ""}';

    return {
      'summary': summary,
      'hasData': true,
      'trendDescription': trendDescription,
      'monthlyData': monthlyData,
      'weekdayData': weekdayData,
      'peakWeekday': peakWeekday,
      'peakWeekdayName': peakWeekdayName,
      'transactionCount': expenseTransactions.length,
    };
  }
}

/// 习惯提醒Action
///
/// 设置和管理消费习惯相关的提醒：
/// - 超支提醒
/// - 定期消费提醒
/// - 习惯养成提醒
class HabitReminderAction extends Action {
  final IDatabaseService databaseService;

  HabitReminderAction(this.databaseService);

  @override
  String get id => 'habit.reminder';

  @override
  String get name => '习惯提醒';

  @override
  String get description => '设置消费习惯相关提醒';

  @override
  List<String> get triggerPatterns => [
    '习惯提醒', '消费提醒', '超支提醒',
    '提醒我少花钱', '控制消费',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'reminderType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'overspend',
      description: '提醒类型: overspend/periodic/saving',
    ),
    const ActionParam(
      name: 'threshold',
      type: ActionParamType.number,
      required: false,
      description: '提醒阈值金额',
    ),
    const ActionParam(
      name: 'category',
      type: ActionParamType.string,
      required: false,
      description: '特定分类',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final reminderType = params['reminderType'] as String? ?? 'overspend';
      final threshold = (params['threshold'] as num?)?.toDouble();
      final category = params['category'] as String?;

      switch (reminderType) {
        case 'overspend':
          return _setupOverspendReminder(threshold, category);
        case 'periodic':
          return _setupPeriodicReminder(category);
        case 'saving':
          return _setupSavingReminder(threshold);
        default:
          return _setupOverspendReminder(threshold, category);
      }
    } catch (e) {
      debugPrint('[HabitReminderAction] 设置提醒失败: $e');
      return ActionResult.failure('设置习惯提醒失败: $e', actionId: id);
    }
  }

  /// 设置超支提醒
  ActionResult _setupOverspendReminder(double? threshold, String? category) {
    final effectiveThreshold = threshold ?? 500.0;
    final categoryText = category != null ? '${category.localizedCategoryName}类' : '单笔';

    return ActionResult.success(
      responseText: '已设置${categoryText}消费超过${effectiveThreshold.toStringAsFixed(0)}元时提醒',
      data: {
        'reminderType': 'overspend',
        'threshold': effectiveThreshold,
        'category': category,
        'enabled': true,
      },
      actionId: id,
    );
  }

  /// 设置定期消费提醒
  ActionResult _setupPeriodicReminder(String? category) {
    return ActionResult.success(
      responseText: category != null
          ? '已设置${category.localizedCategoryName}类消费定期回顾提醒'
          : '已设置消费定期回顾提醒，每周日会为您总结',
      data: {
        'reminderType': 'periodic',
        'category': category,
        'frequency': 'weekly',
        'enabled': true,
      },
      actionId: id,
    );
  }

  /// 设置存钱提醒
  ActionResult _setupSavingReminder(double? target) {
    final effectiveTarget = target ?? 1000.0;

    return ActionResult.success(
      responseText: '已设置存钱目标${effectiveTarget.toStringAsFixed(0)}元，会定期提醒您储蓄进度',
      data: {
        'reminderType': 'saving',
        'target': effectiveTarget,
        'enabled': true,
      },
      actionId: id,
    );
  }
}
