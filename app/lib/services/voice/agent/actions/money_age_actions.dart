import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/transaction.dart';
import '../action_registry.dart';

/// 钱龄查询Action
class MoneyAgeQueryAction extends Action {
  final IDatabaseService databaseService;

  MoneyAgeQueryAction(this.databaseService);

  @override
  String get id => 'moneyAge.query';

  @override
  String get name => '查询钱龄';

  @override
  String get description => '查询钱龄健康度';

  @override
  List<String> get triggerPatterns => [
    '查询钱龄', '钱龄健康度', '查看钱龄',
    '我的钱龄', '钱龄报告',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final transactions = await databaseService.getTransactions();

      final expenseTransactions = transactions
          .where((t) => t.type == TransactionType.expense && t.moneyAge != null)
          .toList();

      if (expenseTransactions.isEmpty) {
        return ActionResult.success(
          responseText: '暂无钱龄数据',
          data: {'averageMoneyAge': 0},
          actionId: id,
        );
      }

      final totalMoneyAge = expenseTransactions.fold(
        0, (sum, t) => sum + (t.moneyAge ?? 0)
      );
      final averageMoneyAge = totalMoneyAge / expenseTransactions.length;

      String healthLevel;
      if (averageMoneyAge < 30) {
        healthLevel = 'health';
      } else if (averageMoneyAge < 60) {
        healthLevel = 'warning';
      } else {
        healthLevel = 'danger';
      }

      return ActionResult.success(
        responseText: '平均钱龄: ${averageMoneyAge.toStringAsFixed(1)}天，健康等级: $healthLevel',
        data: {
          'averageMoneyAge': averageMoneyAge,
          'healthLevel': healthLevel,
          'transactionCount': expenseTransactions.length,
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询钱龄失败: $e', actionId: id);
    }
  }
}

/// 钱龄提醒Action
class MoneyAgeReminderAction extends Action {
  final IDatabaseService databaseService;

  MoneyAgeReminderAction(this.databaseService);

  @override
  String get id => 'moneyAge.reminder';

  @override
  String get name => '钱龄提醒';

  @override
  String get description => '设置钱龄提醒阈值';

  @override
  List<String> get triggerPatterns => [
    '设置钱龄提醒', '钱龄提醒', '钱龄预警',
    '提醒我钱龄', '钱龄超过提醒',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'threshold',
      type: ActionParamType.number,
      required: false,
      defaultValue: 30,
      description: '钱龄阈值（天数）',
    ),
    const ActionParam(
      name: 'enabled',
      type: ActionParamType.boolean,
      required: false,
      defaultValue: true,
      description: '是否启用提醒',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final threshold = (params['threshold'] as num?)?.toInt() ?? 30;
      final enabled = params['enabled'] as bool? ?? true;

      // 这里实际应保存到用户配置
      // 目前返回设置成功的反馈

      if (!enabled) {
        return ActionResult.success(
          responseText: '已关闭钱龄提醒',
          data: {
            'enabled': false,
          },
          actionId: id,
        );
      }

      return ActionResult.success(
        responseText: '已设置钱龄提醒，当钱龄超过${threshold}天时将提醒您',
        data: {
          'enabled': true,
          'threshold': threshold,
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('设置钱龄提醒失败: $e', actionId: id);
    }
  }
}

/// 钱龄报告Action
///
/// 生成详细的钱龄分析报告，包括：
/// - 钱龄分布统计
/// - 按分类的钱龄分析
/// - 钱龄趋势变化
/// - 优化建议
class MoneyAgeReportAction extends Action {
  final IDatabaseService databaseService;

  MoneyAgeReportAction(this.databaseService);

  @override
  String get id => 'moneyAge.report';

  @override
  String get name => '钱龄报告';

  @override
  String get description => '生成详细的钱龄分析报告';

  @override
  List<String> get triggerPatterns => [
    '钱龄报告', '钱龄分析', '钱龄统计',
    '详细钱龄', '钱龄情况',
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
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final days = (params['days'] as num?)?.toInt() ?? 30;
      final startDate = DateTime.now().subtract(Duration(days: days));

      final transactions = await databaseService.queryTransactions(
        startDate: startDate,
        endDate: DateTime.now(),
      );

      // 过滤有钱龄数据的支出交易
      final expenseTransactions = transactions
          .where((t) => t.type == TransactionType.expense)
          .toList();

      if (expenseTransactions.isEmpty) {
        return ActionResult.success(
          responseText: '最近$days天暂无支出记录',
          data: {'hasData': false},
          actionId: id,
        );
      }

      // 分析钱龄分布
      final report = _analyzeMoneyAge(expenseTransactions, days);

      return ActionResult.success(
        responseText: report['summary'] as String,
        data: report,
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('生成钱龄报告失败: $e', actionId: id);
    }
  }

  /// 分析钱龄数据
  Map<String, dynamic> _analyzeMoneyAge(List<Transaction> transactions, int days) {
    // 钱龄分布统计
    int healthyCount = 0;   // 钱龄 < 30天
    int warningCount = 0;   // 钱龄 30-60天
    int dangerCount = 0;    // 钱龄 > 60天
    int noDataCount = 0;    // 无钱龄数据

    double totalMoneyAge = 0;
    int validCount = 0;

    // 按分类统计
    final categoryMoneyAge = <String, List<int>>{};

    for (final t in transactions) {
      final moneyAge = t.moneyAge;

      if (moneyAge == null) {
        noDataCount++;
        continue;
      }

      validCount++;
      totalMoneyAge += moneyAge;

      if (moneyAge < 30) {
        healthyCount++;
      } else if (moneyAge < 60) {
        warningCount++;
      } else {
        dangerCount++;
      }

      // 分类统计
      categoryMoneyAge.putIfAbsent(t.category, () => []);
      categoryMoneyAge[t.category]!.add(moneyAge);
    }

    // 计算平均钱龄
    final avgMoneyAge = validCount > 0 ? totalMoneyAge / validCount : 0.0;

    // 健康评级
    String healthLevel;
    String healthDescription;

    if (avgMoneyAge < 20) {
      healthLevel = 'excellent';
      healthDescription = '优秀';
    } else if (avgMoneyAge < 30) {
      healthLevel = 'healthy';
      healthDescription = '健康';
    } else if (avgMoneyAge < 45) {
      healthLevel = 'warning';
      healthDescription = '需关注';
    } else {
      healthLevel = 'danger';
      healthDescription = '需改善';
    }

    // 找出钱龄最高的分类
    String? worstCategory;
    double worstAvgAge = 0;

    categoryMoneyAge.forEach((category, ages) {
      if (ages.isNotEmpty) {
        final avgAge = ages.reduce((a, b) => a + b) / ages.length;
        if (avgAge > worstAvgAge) {
          worstAvgAge = avgAge;
          worstCategory = category;
        }
      }
    });

    // 生成摘要
    final summaryBuffer = StringBuffer();
    summaryBuffer.write('最近$days天钱龄报告：');
    summaryBuffer.write('平均钱龄${avgMoneyAge.toStringAsFixed(1)}天，');
    summaryBuffer.write('健康等级$healthDescription。');

    if (healthyCount > 0) {
      summaryBuffer.write('健康消费$healthyCount笔');
    }
    if (warningCount > 0) {
      summaryBuffer.write('，需关注$warningCount笔');
    }
    if (dangerCount > 0) {
      summaryBuffer.write('，需改善$dangerCount笔');
    }

    if (worstCategory != null && worstAvgAge > 30) {
      summaryBuffer.write('。$worstCategory类钱龄较高(${worstAvgAge.toStringAsFixed(0)}天)，建议减少该类冲动消费');
    }

    return {
      'summary': summaryBuffer.toString(),
      'hasData': true,
      'days': days,
      'averageMoneyAge': avgMoneyAge,
      'healthLevel': healthLevel,
      'healthDescription': healthDescription,
      'distribution': {
        'healthy': healthyCount,
        'warning': warningCount,
        'danger': dangerCount,
        'noData': noDataCount,
      },
      'totalTransactions': transactions.length,
      'validTransactions': validCount,
      'categoryAnalysis': categoryMoneyAge.map((k, v) => MapEntry(k, {
        'count': v.length,
        'avgAge': v.isNotEmpty ? v.reduce((a, b) => a + b) / v.length : 0,
      })),
      'worstCategory': worstCategory,
      'worstCategoryAvgAge': worstAvgAge,
      'suggestions': _generateSuggestions(healthLevel, worstCategory, worstAvgAge),
    };
  }

  /// 生成优化建议
  List<String> _generateSuggestions(String healthLevel, String? worstCategory, double worstAvgAge) {
    final suggestions = <String>[];

    switch (healthLevel) {
      case 'excellent':
        suggestions.add('继续保持良好的消费习惯');
        break;
      case 'healthy':
        suggestions.add('消费习惯良好，可适当关注高钱龄支出');
        break;
      case 'warning':
        suggestions.add('建议减少冲动消费，控制非必要支出');
        if (worstCategory != null) {
          suggestions.add('特别关注$worstCategory类的消费');
        }
        break;
      case 'danger':
        suggestions.add('钱龄偏高，建议审视消费结构');
        suggestions.add('制定预算计划，避免超支');
        if (worstCategory != null) {
          suggestions.add('建议大幅减少$worstCategory类的支出');
        }
        break;
    }

    return suggestions;
  }
}
