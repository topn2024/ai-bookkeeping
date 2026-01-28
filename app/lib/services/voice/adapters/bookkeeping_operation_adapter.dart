import 'package:flutter/foundation.dart';
import '../../../core/contracts/i_database_service.dart';
import '../../database_service.dart';
import '../../voice_navigation_service.dart';
import '../intelligence_engine/intelligence_engine.dart';
import '../intelligence_engine/models.dart';
import '../../../models/transaction.dart';
import '../query/query_executor.dart';
import '../query/query_result_router.dart';
import '../query/query_models.dart' as query;
import '../../category_localization_service.dart';

/// 记账操作适配器
///
/// 职责：
/// - 实现 OperationAdapter 接口
/// - 处理记账操作（add_transaction）
/// - 处理查询操作（query）
/// - 处理导航操作（navigate）
/// - 处理删除/修改操作（delete/modify）
class BookkeepingOperationAdapter implements OperationAdapter {
  final IDatabaseService _databaseService;
  final VoiceNavigationService _navigationService;
  final QueryExecutor _queryExecutor;
  final QueryResultRouter _queryRouter;

  BookkeepingOperationAdapter({
    IDatabaseService? databaseService,
    VoiceNavigationService? navigationService,
    QueryExecutor? queryExecutor,
    QueryResultRouter? queryRouter,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _navigationService = navigationService ?? VoiceNavigationService(),
        _queryExecutor = queryExecutor ?? QueryExecutor(databaseService: databaseService),
        _queryRouter = queryRouter ?? QueryResultRouter();

  @override
  String get adapterName => 'BookkeepingOperationAdapter';

  @override
  bool canHandle(OperationType type) {
    return [
      OperationType.addTransaction,
      OperationType.query,
      OperationType.navigate,
      OperationType.delete,
      OperationType.modify,
    ].contains(type);
  }

  @override
  Future<ExecutionResult> execute(Operation operation) async {
    debugPrint('[BookkeepingOperationAdapter] 执行操作: ${operation.type}');

    try {
      switch (operation.type) {
        case OperationType.addTransaction:
          return await _addTransaction(operation.params);

        case OperationType.query:
          return await _query(operation.params);

        case OperationType.navigate:
          return await _navigate(operation.params);

        case OperationType.delete:
          return await _delete(operation.params);

        case OperationType.modify:
          return await _modify(operation.params);

        default:
          return ExecutionResult.unsupported();
      }
    } catch (e) {
      debugPrint('[BookkeepingOperationAdapter] 执行失败: $e');
      return ExecutionResult.failure(e.toString());
    }
  }

  /// 添加交易记录
  Future<ExecutionResult> _addTransaction(Map<String, dynamic> params) async {
    final amount = params['amount'] as num?;
    final rawCategory = params['category'] as String? ?? '其他';
    // 规范化分类为标准英文ID（如 '工资' → 'salary'）
    final category = CategoryLocalizationService.instance.normalizeCategoryId(rawCategory);
    final type = params['type'] as String? ?? 'expense';
    final note = params['note'] as String?;
    final accountId = params['accountId'] as String? ?? 'default';

    if (amount == null || amount <= 0) {
      return ExecutionResult.failure('金额无效');
    }

    debugPrint('[BookkeepingOperationAdapter] 添加交易: $amount, $category, $type');

    try {
      // 解析交易类型
      TransactionType transactionType;
      switch (type.toLowerCase()) {
        case 'income':
          transactionType = TransactionType.income;
          break;
        case 'transfer':
          transactionType = TransactionType.transfer;
          break;
        default:
          transactionType = TransactionType.expense;
      }

      // 创建交易对象
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: transactionType,
        amount: amount.toDouble(),
        category: category,
        note: note,
        date: DateTime.now(),
        accountId: accountId,
        source: TransactionSource.voice,
        aiConfidence: params['confidence'] as double? ?? 0.8,
      );

      // 调用 DatabaseService 添加交易
      debugPrint('[BookkeepingOperationAdapter] 准备调用insertTransaction: id=${transaction.id}');
      final insertResult = await _databaseService.insertTransaction(transaction);
      debugPrint('[BookkeepingOperationAdapter] insertTransaction返回: $insertResult');

      return ExecutionResult.success(data: {
        'id': transaction.id,
        'amount': amount,
        'category': category,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[BookkeepingOperationAdapter] 添加交易失败: $e');
      return ExecutionResult.failure('添加交易失败: $e');
    }
  }

  /// 查询
  Future<ExecutionResult> _query(Map<String, dynamic> params) async {
    final queryType = params['queryType'] as String? ?? 'summary';
    final time = params['time'] as String?;
    final period = params['period'] as String?;
    final rawCategory = params['category'] as String?;
    // 规范化分类为标准英文ID（如 '餐饮' → 'food', '交通' → 'transport'）
    final category = rawCategory != null
        ? CategoryLocalizationService.instance.normalizeCategoryId(rawCategory)
        : null;
    final operationId = params['operationId'] as String?;

    debugPrint('[BookkeepingOperationAdapter] 查询: queryType=$queryType, time=$time, period=$period, category=$category (原: $rawCategory), operationId=$operationId');

    try {
      // 1. 解析时间范围
      final timeRange = _parseTimeRange(time, period);
      debugPrint('[BookkeepingOperationAdapter] 时间范围: ${timeRange.startDate} - ${timeRange.endDate}, 显示: ${timeRange.periodText}');

      // 2. 构建QueryRequest
      final queryRequest = _buildQueryRequest(
        queryType: queryType,
        timeRange: timeRange,
        category: category,
        params: params,
      );

      // 3. 执行查询
      final queryResult = await _queryExecutor.execute(queryRequest);
      debugPrint('[BookkeepingOperationAdapter] 查询结果: ${queryResult.transactionCount}笔, 支出${queryResult.totalExpense}, 收入${queryResult.totalIncome}');

      // 4. 路由到合适的响应层级
      final queryResponse = await _queryRouter.route(queryRequest, queryResult);
      debugPrint('[BookkeepingOperationAdapter] 响应层级: ${queryResponse.level}, 复杂度: ${queryResponse.complexityScore}');

      // 5. 返回执行结果
      return ExecutionResult.success(
        data: {
          if (operationId != null) 'operationId': operationId,
          'queryType': queryType,
          'level': queryResponse.level.toString(),
          'complexityScore': queryResponse.complexityScore,
          'responseText': queryResponse.voiceText,
          'totalExpense': queryResult.totalExpense,
          'totalIncome': queryResult.totalIncome,
          'balance': queryResult.balance,
          'transactionCount': queryResult.transactionCount,
          'periodText': queryResult.periodText,
          // Level 2: 卡片数据
          'cardData': queryResponse.cardData != null
              ? {
                  'type': queryResponse.cardData!.cardType.toString(),
                  'primaryValue': queryResponse.cardData!.primaryValue,
                  'secondaryValue': queryResponse.cardData!.secondaryValue,
                  'percentage': queryResponse.cardData!.percentage,
                  'progress': queryResponse.cardData!.progress,
                }
              : null,
          // Level 3: 图表数据
          'chartData': queryResponse.chartData != null
              ? {
                  'type': queryResponse.chartData!.chartType.toString(),
                  'title': queryResponse.chartData!.title,
                  'dataPoints': queryResponse.chartData!.dataPoints
                      .map((p) => {'label': p.label, 'value': p.value})
                      .toList(),
                  'xLabels': queryResponse.chartData!.xLabels,
                  'yLabel': queryResponse.chartData!.yLabel,
                }
              : null,
        },
      );
    } catch (e) {
      debugPrint('[BookkeepingOperationAdapter] 查询失败: $e');
      return ExecutionResult.failure('查询失败: $e');
    }
  }

  /// 构建QueryRequest
  query.QueryRequest _buildQueryRequest({
    required String queryType,
    required _TimeRange timeRange,
    String? category,
    required Map<String, dynamic> params,
  }) {
    // 解析查询类型
    query.QueryType type;
    switch (queryType.toLowerCase()) {
      case 'summary':
      case 'statistics':
        type = query.QueryType.summary;
        break;
      case 'recent':
        type = query.QueryType.recent;
        break;
      case 'trend':
        type = query.QueryType.trend;
        break;
      case 'distribution':
        type = query.QueryType.distribution;
        break;
      case 'comparison':
        type = query.QueryType.comparison;
        break;
      default:
        type = query.QueryType.summary;
    }

    // 解析分组维度
    List<query.GroupByDimension>? groupBy;
    final groupByParam = params['groupBy'] as String?;
    if (groupByParam != null) {
      groupBy = [];
      if (groupByParam.contains('date') || groupByParam.contains('日期')) {
        groupBy.add(query.GroupByDimension.date);
      }
      if (groupByParam.contains('month') || groupByParam.contains('月')) {
        groupBy.add(query.GroupByDimension.month);
      }
      if (groupByParam.contains('category') || groupByParam.contains('分类')) {
        groupBy.add(query.GroupByDimension.category);
      }
    }

    return query.QueryRequest(
      queryType: type,
      timeRange: query.TimeRange(
        startDate: timeRange.startDate,
        endDate: timeRange.endDate,
        periodText: timeRange.periodText,
      ),
      category: category,
      groupBy: groupBy,
      limit: params['limit'] as int?,
    );
  }

  /// 解析时间范围
  _TimeRange _parseTimeRange(String? time, String? period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // 如果有 time 参数，优先使用
    if (time != null && time.isNotEmpty) {
      // 今天/今日
      if (time.contains('今天') || time.contains('今日')) {
        return _TimeRange(today, tomorrow, '今天');
      }
      // 昨天
      if (time.contains('昨天') || time.contains('昨日')) {
        final yesterday = today.subtract(const Duration(days: 1));
        return _TimeRange(yesterday, today, '昨天');
      }
      // 前天
      if (time.contains('前天')) {
        final dayBeforeYesterday = today.subtract(const Duration(days: 2));
        final yesterday = today.subtract(const Duration(days: 1));
        return _TimeRange(dayBeforeYesterday, yesterday, '前天');
      }
      // 最近N天 / 近N天
      final recentDaysMatch = RegExp(r'(?:最近|近)(\d+)天').firstMatch(time);
      if (recentDaysMatch != null) {
        final days = int.parse(recentDaysMatch.group(1)!);
        final startDate = today.subtract(Duration(days: days - 1));
        return _TimeRange(startDate, tomorrow, '最近$days天');
      }
      // 本周/这周
      if (time.contains('本周') || time.contains('这周') || time.contains('这个星期')) {
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        return _TimeRange(weekStart, tomorrow, '本周');
      }
      // 上周/上个星期
      if (time.contains('上周') || time.contains('上个星期') || time.contains('上星期')) {
        final lastWeekStart = today.subtract(Duration(days: now.weekday + 6));
        final lastWeekEnd = today.subtract(Duration(days: now.weekday - 1));
        return _TimeRange(lastWeekStart, lastWeekEnd, '上周');
      }
      // 本月/这个月
      if (time.contains('本月') || time.contains('这个月') || time.contains('这月')) {
        final monthStart = DateTime(now.year, now.month, 1);
        return _TimeRange(monthStart, tomorrow, '本月');
      }
      // 上个月/上月
      if (time.contains('上个月') || time.contains('上月')) {
        final lastMonth = now.month == 1
            ? DateTime(now.year - 1, 12, 1)
            : DateTime(now.year, now.month - 1, 1);
        final thisMonthStart = DateTime(now.year, now.month, 1);
        return _TimeRange(lastMonth, thisMonthStart, '上月');
      }
      // 最近N个月
      final recentMonthsMatch = RegExp(r'(?:最近|近)(\d+)个?月').firstMatch(time);
      if (recentMonthsMatch != null) {
        final months = int.parse(recentMonthsMatch.group(1)!);
        final startMonth = now.month - months + 1;
        final startYear = now.year + (startMonth <= 0 ? -1 : 0);
        final adjustedMonth = startMonth <= 0 ? startMonth + 12 : startMonth;
        final startDate = DateTime(startYear, adjustedMonth, 1);
        return _TimeRange(startDate, tomorrow, '最近$months个月');
      }
      // 今年/本年
      if (time.contains('今年') || time.contains('本年')) {
        final yearStart = DateTime(now.year, 1, 1);
        return _TimeRange(yearStart, tomorrow, '今年');
      }
      // 去年/上一年
      if (time.contains('去年') || time.contains('上一年')) {
        final lastYearStart = DateTime(now.year - 1, 1, 1);
        final thisYearStart = DateTime(now.year, 1, 1);
        return _TimeRange(lastYearStart, thisYearStart, '去年');
      }
      // 全部/所有
      if (time.contains('全部') || time.contains('所有') || time.contains('一共')) {
        return _TimeRange(DateTime(2000), tomorrow, '全部');
      }
    }

    // 如果有 period 参数
    if (period != null && period.isNotEmpty) {
      switch (period.toLowerCase()) {
        case 'day':
        case 'today':
          return _TimeRange(today, tomorrow, '今天');
        case 'week':
          final weekStart = today.subtract(Duration(days: now.weekday - 1));
          return _TimeRange(weekStart, tomorrow, '本周');
        case 'month':
          final monthStart = DateTime(now.year, now.month, 1);
          return _TimeRange(monthStart, tomorrow, '本月');
        case 'year':
          final yearStart = DateTime(now.year, 1, 1);
          return _TimeRange(yearStart, tomorrow, '今年');
      }
    }

    // 默认查询本月
    final monthStart = DateTime(now.year, now.month, 1);
    return _TimeRange(monthStart, tomorrow, '本月');
  }

  /// 导航
  Future<ExecutionResult> _navigate(Map<String, dynamic> params) async {
    final targetPage = params['targetPage'] as String?;
    final route = params['route'] as String?;

    if (targetPage == null && route == null) {
      return ExecutionResult.failure('导航目标未指定');
    }

    debugPrint('[BookkeepingOperationAdapter] 导航: $targetPage, $route');

    // 提取导航参数
    final navigationParams = <String, dynamic>{};
    if (params.containsKey('category')) {
      navigationParams['category'] = params['category'];
    }
    if (params.containsKey('timeRange')) {
      navigationParams['timeRange'] = params['timeRange'];
    }
    if (params.containsKey('source')) {
      navigationParams['source'] = params['source'];
    }
    if (params.containsKey('account')) {
      navigationParams['account'] = params['account'];
    }

    debugPrint('[BookkeepingOperationAdapter] 导航参数: $navigationParams');

    try {
      // 解析路由
      String? finalRoute = route;
      String? pageName = targetPage;

      if (finalRoute == null && targetPage != null) {
        final navigationResult = _navigationService.parseNavigation(targetPage);
        if (navigationResult.success) {
          finalRoute = navigationResult.route;
          pageName = navigationResult.pageName;
        }
      }

      if (finalRoute != null) {
        return ExecutionResult.success(data: {
          'route': finalRoute,
          'targetPage': targetPage,
          'pageName': pageName,
          'navigationParams': navigationParams,  // 传递导航参数
        });
      }

      return ExecutionResult.failure('无法识别导航目标');
    } catch (e) {
      debugPrint('[BookkeepingOperationAdapter] 导航失败: $e');
      return ExecutionResult.failure('导航失败: $e');
    }
  }

  /// 删除
  Future<ExecutionResult> _delete(Map<String, dynamic> params) async {
    final transactionId = params['transactionId'] as String?;

    if (transactionId == null || transactionId.isEmpty) {
      return ExecutionResult.failure('交易ID未指定');
    }

    debugPrint('[BookkeepingOperationAdapter] 删除操作: $transactionId');

    try {
      // 调用 DatabaseService 删除交易
      final result = await _databaseService.deleteTransaction(transactionId);

      if (result > 0) {
        return ExecutionResult.success(data: {
          'deleted': true,
          'transactionId': transactionId,
        });
      } else {
        return ExecutionResult.failure('未找到要删除的交易');
      }
    } catch (e) {
      debugPrint('[BookkeepingOperationAdapter] 删除失败: $e');
      return ExecutionResult.failure('删除失败: $e');
    }
  }

  /// 修改
  Future<ExecutionResult> _modify(Map<String, dynamic> params) async {
    final transactionId = params['transactionId'] as String?;

    if (transactionId == null || transactionId.isEmpty) {
      return ExecutionResult.failure('交易ID未指定');
    }

    debugPrint('[BookkeepingOperationAdapter] 修改操作: $transactionId');

    try {
      // 先获取原交易
      final transactions = await _databaseService.getTransactions();
      final originalTransaction = transactions.firstWhere(
        (t) => t.id == transactionId,
        orElse: () => throw Exception('未找到要修改的交易'),
      );

      // 规范化新分类（如果有）
      final rawCategory = params['category'] as String?;
      final normalizedCategory = rawCategory != null
          ? CategoryLocalizationService.instance.normalizeCategoryId(rawCategory)
          : null;

      // 构建修改后的交易
      final updatedTransaction = Transaction(
        id: originalTransaction.id,
        type: originalTransaction.type,
        amount: (params['amount'] as num?)?.toDouble() ?? originalTransaction.amount,
        category: normalizedCategory ?? originalTransaction.category,
        note: params['note'] as String? ?? originalTransaction.note,
        date: originalTransaction.date,
        accountId: originalTransaction.accountId,
        toAccountId: originalTransaction.toAccountId,
        imageUrl: originalTransaction.imageUrl,
        isSplit: originalTransaction.isSplit,
        splits: originalTransaction.splits,
        isReimbursable: originalTransaction.isReimbursable,
        isReimbursed: originalTransaction.isReimbursed,
        tags: originalTransaction.tags,
        createdAt: originalTransaction.createdAt,
        updatedAt: DateTime.now(),
        source: originalTransaction.source,
        aiConfidence: originalTransaction.aiConfidence,
        sourceFileLocalPath: originalTransaction.sourceFileLocalPath,
        sourceFileServerUrl: originalTransaction.sourceFileServerUrl,
        sourceFileType: originalTransaction.sourceFileType,
        sourceFileSize: originalTransaction.sourceFileSize,
        recognitionRawData: originalTransaction.recognitionRawData,
        sourceFileExpiresAt: originalTransaction.sourceFileExpiresAt,
        externalId: originalTransaction.externalId,
        externalSource: originalTransaction.externalSource,
        importBatchId: originalTransaction.importBatchId,
        rawMerchant: originalTransaction.rawMerchant,
        vaultId: originalTransaction.vaultId,
        location: originalTransaction.location,
        moneyAge: originalTransaction.moneyAge,
        moneyAgeLevel: originalTransaction.moneyAgeLevel,
        resourcePoolId: originalTransaction.resourcePoolId,
        visibility: originalTransaction.visibility,
      );

      // 调用 DatabaseService 修改交易
      final result = await _databaseService.updateTransaction(updatedTransaction);

      if (result > 0) {
        return ExecutionResult.success(data: {
          'modified': true,
          'transactionId': transactionId,
        });
      } else {
        return ExecutionResult.failure('修改失败');
      }
    } catch (e) {
      debugPrint('[BookkeepingOperationAdapter] 修改失败: $e');
      return ExecutionResult.failure('修改失败: $e');
    }
  }
}

/// 时间范围辅助类
class _TimeRange {
  final DateTime startDate;
  final DateTime endDate;
  final String periodText;

  _TimeRange(this.startDate, this.endDate, this.periodText);
}
