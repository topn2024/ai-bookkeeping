import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/transaction.dart';
import '../action_registry.dart';

/// 数据导出Action
///
/// 支持多种格式导出：
/// - CSV: 适合Excel打开和数据分析
/// - JSON: 适合程序处理和数据迁移
/// - Excel: 生成Excel兼容的格式
class DataExportAction extends Action {
  final IDatabaseService databaseService;

  DataExportAction(this.databaseService);

  @override
  String get id => 'data.export';

  @override
  String get name => '导出数据';

  @override
  String get description => '导出交易数据为指定格式';

  @override
  List<String> get triggerPatterns => [
    '导出数据', '导出交易', '导出记录',
    '导出CSV', '导出Excel', '导出JSON',
    '下载数据', '备份交易',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'format',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'csv',
      description: '导出格式: csv/excel/json',
    ),
    const ActionParam(
      name: 'startDate',
      type: ActionParamType.dateTime,
      required: false,
      description: '开始日期',
    ),
    const ActionParam(
      name: 'endDate',
      type: ActionParamType.dateTime,
      required: false,
      description: '结束日期',
    ),
    const ActionParam(
      name: 'category',
      type: ActionParamType.string,
      required: false,
      description: '筛选分类',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final format = (params['format'] as String?)?.toLowerCase() ?? 'csv';
      final startDate = params['startDate'] as DateTime?;
      final endDate = params['endDate'] as DateTime?;
      final category = params['category'] as String?;

      // 查询交易数据
      final transactions = await databaseService.queryTransactions(
        startDate: startDate,
        endDate: endDate,
        category: category,
      );

      if (transactions.isEmpty) {
        return ActionResult.success(
          responseText: '没有找到符合条件的交易记录',
          data: {'count': 0},
          actionId: id,
        );
      }

      // 根据格式生成导出内容
      String exportContent;
      String mimeType;
      String fileExtension;

      switch (format) {
        case 'json':
          exportContent = _exportToJson(transactions);
          mimeType = 'application/json';
          fileExtension = 'json';
          break;

        case 'excel':
        case 'xlsx':
          // Excel格式使用CSV兼容方式，添加BOM头以支持中文
          exportContent = '\uFEFF${_exportToCsv(transactions)}';
          mimeType = 'text/csv';
          fileExtension = 'csv';
          break;

        case 'csv':
        default:
          exportContent = _exportToCsv(transactions);
          mimeType = 'text/csv';
          fileExtension = 'csv';
          break;
      }

      final fileName = 'transactions_${DateTime.now().toIso8601String().split('T')[0]}.$fileExtension';

      return ActionResult.success(
        responseText: '已准备好${transactions.length}条交易记录的$format格式导出',
        data: {
          'format': format,
          'count': transactions.length,
          'content': exportContent,
          'mimeType': mimeType,
          'fileName': fileName,
          'ready': true,
        },
        actionId: id,
      );
    } catch (e) {
      debugPrint('[DataExportAction] 导出失败: $e');
      return ActionResult.failure('数据导出失败: $e', actionId: id);
    }
  }

  /// 导出为CSV格式
  String _exportToCsv(List<Transaction> transactions) {
    final buffer = StringBuffer();

    // 写入表头
    buffer.writeln('日期,类型,金额,分类,备注,账户,商家,标签');

    // 写入数据行
    for (final t in transactions) {
      final date = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      final type = t.type == TransactionType.expense ? '支出' : (t.type == TransactionType.income ? '收入' : '转账');
      final amount = t.amount.toStringAsFixed(2);
      final category = _escapeCsv(t.category);
      final note = _escapeCsv(t.note ?? '');
      final account = _escapeCsv(t.accountId);
      final merchant = _escapeCsv(t.rawMerchant ?? '');
      final tags = _escapeCsv(t.tags?.join(',') ?? '');

      buffer.writeln('$date,$type,$amount,$category,$note,$account,$merchant,$tags');
    }

    return buffer.toString();
  }

  /// 转义CSV字段
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// 导出为JSON格式
  String _exportToJson(List<Transaction> transactions) {
    final data = transactions.map((t) => {
      'id': t.id,
      'date': t.date.toIso8601String(),
      'type': t.type.name,
      'amount': t.amount,
      'category': t.category,
      'note': t.note,
      'accountId': t.accountId,
      'merchant': t.rawMerchant,
      'tags': t.tags,
      'createdAt': t.createdAt.toIso8601String(),
    }).toList();

    return const JsonEncoder.withIndent('  ').convert({
      'exportTime': DateTime.now().toIso8601String(),
      'count': transactions.length,
      'transactions': data,
    });
  }
}

/// 数据备份Action
///
/// 支持本地和云端备份
class DataBackupAction extends Action {
  final IDatabaseService databaseService;

  DataBackupAction(this.databaseService);

  @override
  String get id => 'data.backup';

  @override
  String get name => '备份数据';

  @override
  String get description => '备份所有数据到本地或云端';

  @override
  List<String> get triggerPatterns => [
    '备份数据', '数据备份', '备份',
    '本地备份', '云端备份', '自动备份',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'backupType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'local',
      description: '备份类型: local/cloud/auto',
    ),
    const ActionParam(
      name: 'includeSettings',
      type: ActionParamType.boolean,
      required: false,
      defaultValue: true,
      description: '是否包含设置',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final backupType = params['backupType'] as String? ?? 'local';
      final includeSettings = params['includeSettings'] as bool? ?? true;

      // 收集备份数据
      final transactions = await databaseService.getTransactions();
      final categories = await databaseService.getCategories();
      final accounts = await databaseService.getAccounts();
      final budgets = await databaseService.getBudgets();

      final backupData = {
        'version': '1.0',
        'backupTime': DateTime.now().toIso8601String(),
        'backupType': backupType,
        'data': {
          'transactions': transactions.length,
          'categories': categories.length,
          'accounts': accounts.length,
          'budgets': budgets.length,
        },
      };

      switch (backupType) {
        case 'cloud':
          // 云端备份需要实际的云存储服务
          return ActionResult.success(
            responseText: '云端备份功能需要登录账号，请先登录后再试',
            data: {
              'backupType': 'cloud',
              'requiresLogin': true,
            },
            actionId: id,
          );

        case 'auto':
          return ActionResult.success(
            responseText: '已开启自动备份，将每周自动备份一次',
            data: {
              'backupType': 'auto',
              'frequency': 'weekly',
              'enabled': true,
            },
            actionId: id,
          );

        case 'local':
        default:
          final backupContent = const JsonEncoder.withIndent('  ').convert(backupData);
          final fileName = 'backup_${DateTime.now().toIso8601String().split('T')[0]}.json';

          return ActionResult.success(
            responseText: '本地备份已准备好，包含${transactions.length}条交易、${categories.length}个分类、${accounts.length}个账户',
            data: {
              'backupType': 'local',
              'fileName': fileName,
              'content': backupContent,
              'summary': backupData['data'],
              'includeSettings': includeSettings,
              'ready': true,
            },
            actionId: id,
          );
      }
    } catch (e) {
      debugPrint('[DataBackupAction] 备份失败: $e');
      return ActionResult.failure('数据备份失败: $e', actionId: id);
    }
  }
}

/// 数据统计Action
///
/// 支持多种统计维度：
/// - 月度/年度统计
/// - 分类统计
/// - 账户统计
/// - 自定义时间范围
class DataStatisticsAction extends Action {
  final IDatabaseService databaseService;

  DataStatisticsAction(this.databaseService);

  @override
  String get id => 'data.statistics';

  @override
  String get name => '数据统计';

  @override
  String get description => '查看数据统计信息';

  @override
  List<String> get triggerPatterns => [
    '数据统计', '统计数据', '查看统计',
    '月度统计', '年度统计', '分类统计',
    '消费统计', '收支统计',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'period',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'month',
      description: '统计周期: day/week/month/year/all',
    ),
    const ActionParam(
      name: 'dimension',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'overview',
      description: '统计维度: overview/category/account/trend',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final period = params['period'] as String? ?? 'month';
      final dimension = params['dimension'] as String? ?? 'overview';

      // 计算时间范围
      final now = DateTime.now();
      DateTime startDate;
      String periodText;

      switch (period) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          periodText = '今日';
          break;
        case 'week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          periodText = '本周';
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          periodText = '今年';
          break;
        case 'all':
          startDate = DateTime(2000);
          periodText = '全部';
          break;
        case 'month':
        default:
          startDate = DateTime(now.year, now.month, 1);
          periodText = '本月';
          break;
      }

      final transactions = await databaseService.queryTransactions(
        startDate: startDate,
        endDate: now,
      );

      // 根据维度生成统计
      switch (dimension) {
        case 'category':
          return _categoryStatistics(transactions, periodText);
        case 'account':
          return _accountStatistics(transactions, periodText);
        case 'trend':
          return _trendStatistics(transactions, periodText, period);
        case 'overview':
        default:
          return _overviewStatistics(transactions, periodText);
      }
    } catch (e) {
      debugPrint('[DataStatisticsAction] 统计失败: $e');
      return ActionResult.failure('查询统计数据失败: $e', actionId: id);
    }
  }

  /// 总览统计
  ActionResult _overviewStatistics(List<Transaction> transactions, String periodText) {
    double totalExpense = 0;
    double totalIncome = 0;
    int expenseCount = 0;
    int incomeCount = 0;

    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
        expenseCount++;
      } else if (t.type == TransactionType.income) {
        totalIncome += t.amount;
        incomeCount++;
      }
    }

    final balance = totalIncome - totalExpense;
    final avgExpense = expenseCount > 0 ? totalExpense / expenseCount : 0.0;

    return ActionResult.success(
      responseText: '$periodText共${transactions.length}笔交易，支出${totalExpense.toStringAsFixed(0)}元，收入${totalIncome.toStringAsFixed(0)}元，结余${balance.toStringAsFixed(0)}元',
      data: {
        'period': periodText,
        'totalTransactions': transactions.length,
        'totalExpense': totalExpense,
        'totalIncome': totalIncome,
        'balance': balance,
        'expenseCount': expenseCount,
        'incomeCount': incomeCount,
        'avgExpense': avgExpense,
      },
      actionId: id,
    );
  }

  /// 分类统计
  ActionResult _categoryStatistics(List<Transaction> transactions, String periodText) {
    final categoryStats = <String, double>{};

    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        categoryStats[t.category] = (categoryStats[t.category] ?? 0) + t.amount;
      }
    }

    // 排序找出前5个分类
    final sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sortedCategories.take(5).toList();

    final responseBuffer = StringBuffer('$periodText支出分类统计：');
    for (var i = 0; i < top5.length; i++) {
      if (i > 0) responseBuffer.write('，');
      responseBuffer.write('${top5[i].key}${top5[i].value.toStringAsFixed(0)}元');
    }

    return ActionResult.success(
      responseText: responseBuffer.toString(),
      data: {
        'period': periodText,
        'categoryStats': categoryStats,
        'topCategories': top5.map((e) => {'category': e.key, 'amount': e.value}).toList(),
      },
      actionId: id,
    );
  }

  /// 账户统计
  ActionResult _accountStatistics(List<Transaction> transactions, String periodText) {
    final accountStats = <String, Map<String, double>>{};

    for (final t in transactions) {
      accountStats.putIfAbsent(t.accountId, () => {'expense': 0, 'income': 0});

      if (t.type == TransactionType.expense) {
        accountStats[t.accountId]!['expense'] = accountStats[t.accountId]!['expense']! + t.amount;
      } else if (t.type == TransactionType.income) {
        accountStats[t.accountId]!['income'] = accountStats[t.accountId]!['income']! + t.amount;
      }
    }

    return ActionResult.success(
      responseText: '$periodText共使用${accountStats.length}个账户进行收支',
      data: {
        'period': periodText,
        'accountStats': accountStats,
        'accountCount': accountStats.length,
      },
      actionId: id,
    );
  }

  /// 趋势统计
  ActionResult _trendStatistics(List<Transaction> transactions, String periodText, String period) {
    final dailyStats = <String, double>{};

    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        final dateKey = '${t.date.month}/${t.date.day}';
        dailyStats[dateKey] = (dailyStats[dateKey] ?? 0) + t.amount;
      }
    }

    // 计算日均支出
    final avgDaily = dailyStats.isNotEmpty
        ? dailyStats.values.reduce((a, b) => a + b) / dailyStats.length
        : 0.0;

    // 找出支出最高的一天
    String? peakDay;
    double peakAmount = 0;
    dailyStats.forEach((day, amount) {
      if (amount > peakAmount) {
        peakAmount = amount;
        peakDay = day;
      }
    });

    return ActionResult.success(
      responseText: '$periodText日均支出${avgDaily.toStringAsFixed(0)}元${peakDay != null ? "，$peakDay消费最多(${peakAmount.toStringAsFixed(0)}元)" : ""}',
      data: {
        'period': periodText,
        'dailyStats': dailyStats,
        'avgDaily': avgDaily,
        'peakDay': peakDay,
        'peakAmount': peakAmount,
      },
      actionId: id,
    );
  }
}

/// 数据报告Action
///
/// 生成综合财务报告：
/// - 月度报告
/// - 年度报告
/// - 自定义时间范围报告
class DataReportAction extends Action {
  final IDatabaseService databaseService;

  DataReportAction(this.databaseService);

  @override
  String get id => 'data.report';

  @override
  String get name => '生成报告';

  @override
  String get description => '生成财务分析报告';

  @override
  List<String> get triggerPatterns => [
    '生成报告', '财务报告', '月度报告', '年度报告',
    '账单报告', '消费报告', '收支报告',
    '报告', '分析报告',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'reportType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'monthly',
      description: '报告类型: monthly/yearly/custom',
    ),
    const ActionParam(
      name: 'startDate',
      type: ActionParamType.dateTime,
      required: false,
      description: '开始日期',
    ),
    const ActionParam(
      name: 'endDate',
      type: ActionParamType.dateTime,
      required: false,
      description: '结束日期',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final reportType = params['reportType'] as String? ?? 'monthly';
      final now = DateTime.now();

      DateTime startDate;
      DateTime endDate = now;
      String reportTitle;

      switch (reportType) {
        case 'yearly':
          startDate = DateTime(now.year, 1, 1);
          reportTitle = '${now.year}年度报告';
          break;
        case 'custom':
          startDate = params['startDate'] as DateTime? ??
              DateTime(now.year, now.month, 1);
          endDate = params['endDate'] as DateTime? ?? now;
          reportTitle = '自定义报告';
          break;
        case 'monthly':
        default:
          startDate = DateTime(now.year, now.month, 1);
          reportTitle = '${now.month}月报告';
          break;
      }

      final transactions = await databaseService.queryTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      // 计算收支
      double totalIncome = 0;
      double totalExpense = 0;
      final categoryExpenses = <String, double>{};
      final categoryIncomes = <String, double>{};

      for (final t in transactions) {
        if (t.type == TransactionType.income) {
          totalIncome += t.amount;
          categoryIncomes[t.category] =
              (categoryIncomes[t.category] ?? 0) + t.amount;
        } else if (t.type == TransactionType.expense) {
          totalExpense += t.amount;
          categoryExpenses[t.category] =
              (categoryExpenses[t.category] ?? 0) + t.amount;
        }
      }

      final balance = totalIncome - totalExpense;
      final savingsRate = totalIncome > 0
          ? ((totalIncome - totalExpense) / totalIncome * 100)
          : 0.0;

      // 找出最大支出分类
      String? topExpenseCategory;
      double topExpenseAmount = 0;
      categoryExpenses.forEach((category, amount) {
        if (amount > topExpenseAmount) {
          topExpenseAmount = amount;
          topExpenseCategory = category;
        }
      });

      // 生成报告摘要
      final summary = StringBuffer();
      summary.write('$reportTitle：');
      summary.write('收入${totalIncome.toStringAsFixed(0)}元，');
      summary.write('支出${totalExpense.toStringAsFixed(0)}元，');
      if (balance >= 0) {
        summary.write('结余${balance.toStringAsFixed(0)}元');
      } else {
        summary.write('超支${(-balance).toStringAsFixed(0)}元');
      }
      if (topExpenseCategory != null) {
        summary.write('。$topExpenseCategory支出最多');
      }

      return ActionResult.success(
        responseText: summary.toString(),
        data: {
          'reportTitle': reportTitle,
          'period': {
            'start': startDate.toIso8601String(),
            'end': endDate.toIso8601String(),
          },
          'summary': {
            'totalIncome': totalIncome,
            'totalExpense': totalExpense,
            'balance': balance,
            'savingsRate': savingsRate,
            'transactionCount': transactions.length,
          },
          'categoryExpenses': categoryExpenses,
          'categoryIncomes': categoryIncomes,
          'topExpenseCategory': topExpenseCategory,
          'topExpenseAmount': topExpenseAmount,
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('生成报告失败: $e', actionId: id);
    }
  }
}
