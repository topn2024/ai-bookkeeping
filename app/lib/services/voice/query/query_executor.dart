/// 查询执行器
///
/// 负责执行实际的数据库查询并返回QueryResult
/// 委托给QueryCalculator执行计算，利用其缓存和策略模式
library;

import 'package:flutter/foundation.dart';
import '../../../core/contracts/i_database_service.dart';
import '../../database_service.dart';
import 'query_models.dart';
import 'query_calculator.dart';

/// 查询执行器
///
/// 作为查询系统的入口，委托给QueryCalculator执行实际计算
class QueryExecutor {
  final IDatabaseService _databaseService;
  final QueryCalculator _queryCalculator;

  QueryExecutor({
    IDatabaseService? databaseService,
    QueryCalculator? queryCalculator,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _queryCalculator = queryCalculator ?? QueryCalculator(DatabaseService());

  /// 执行查询
  ///
  /// 委托给QueryCalculator执行计算，利用其：
  /// - 缓存机制（5分钟有效期）
  /// - 策略模式（不同查询类型使用不同策略）
  /// - 数据采样（最大1000个数据点）
  /// - 时间范围验证（最大365天）
  Future<QueryResult> execute(QueryRequest request) async {
    debugPrint('[QueryExecutor] 执行查询: type=${request.queryType}, '
        'timeRange=${request.timeRange?.periodText}, '
        'category=${request.category}');

    try {
      // 委托给QueryCalculator执行计算
      final result = await _queryCalculator.calculate(request);

      debugPrint('[QueryExecutor] 查询完成: '
          'expense=${result.totalExpense}, '
          'income=${result.totalIncome}, '
          'count=${result.transactionCount}');

      return result;
    } catch (e) {
      debugPrint('[QueryExecutor] 查询失败: $e');
      rethrow;
    }
  }
}
