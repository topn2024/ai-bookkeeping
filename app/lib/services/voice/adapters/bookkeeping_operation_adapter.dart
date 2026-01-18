import 'package:flutter/foundation.dart';
import '../../database_service.dart';
import '../../voice_navigation_service.dart';
import '../intelligence_engine/intelligence_engine.dart';
import '../intelligence_engine/models.dart';

/// 记账操作适配器
///
/// 职责：
/// - 实现 OperationAdapter 接口
/// - 处理记账操作（add_transaction）
/// - 处理查询操作（query）
/// - 处理导航操作（navigate）
/// - 处理删除/修改操作（delete/modify）
class BookkeepingOperationAdapter implements OperationAdapter {
  final DatabaseService _databaseService;
  final VoiceNavigationService _navigationService;

  BookkeepingOperationAdapter({
    DatabaseService? databaseService,
    VoiceNavigationService? navigationService,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _navigationService = navigationService ?? VoiceNavigationService();

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
    final category = params['category'] as String? ?? '其他';
    final type = params['type'] as String? ?? 'expense';

    if (amount == null || amount <= 0) {
      return ExecutionResult.failure('金额无效');
    }

    debugPrint('[BookkeepingOperationAdapter] 添加交易: $amount, $category, $type');

    // TODO: 实际调用 DatabaseService 添加交易
    // await _databaseService.addTransaction(...);

    return ExecutionResult.success(data: {
      'amount': amount,
      'category': category,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 查询
  Future<ExecutionResult> _query(Map<String, dynamic> params) async {
    final queryType = params['queryType'] as String? ?? 'summary';

    debugPrint('[BookkeepingOperationAdapter] 查询: $queryType');

    // TODO: 实际调用 DatabaseService 查询
    // final result = await _databaseService.query(...);

    return ExecutionResult.success(data: {
      'queryType': queryType,
      'result': '查询结果占位',
    });
  }

  /// 导航
  Future<ExecutionResult> _navigate(Map<String, dynamic> params) async {
    final targetPage = params['targetPage'] as String?;
    final route = params['route'] as String?;

    if (targetPage == null && route == null) {
      return ExecutionResult.failure('导航目标未指定');
    }

    debugPrint('[BookkeepingOperationAdapter] 导航: $targetPage, $route');

    // TODO: 实际调用导航服务
    // await _navigationService.navigateTo(...);

    return ExecutionResult.success(data: {
      'targetPage': targetPage,
      'route': route,
    });
  }

  /// 删除
  Future<ExecutionResult> _delete(Map<String, dynamic> params) async {
    debugPrint('[BookkeepingOperationAdapter] 删除操作');

    // TODO: 实际调用 DatabaseService 删除
    // await _databaseService.deleteTransaction(...);

    return ExecutionResult.success(data: {
      'deleted': true,
    });
  }

  /// 修改
  Future<ExecutionResult> _modify(Map<String, dynamic> params) async {
    debugPrint('[BookkeepingOperationAdapter] 修改操作');

    // TODO: 实际调用 DatabaseService 修改
    // await _databaseService.modifyTransaction(...);

    return ExecutionResult.success(data: {
      'modified': true,
    });
  }
}
