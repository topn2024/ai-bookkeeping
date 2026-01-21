import 'package:flutter/foundation.dart';
import '../../../core/contracts/i_database_service.dart';
import '../../database_service.dart';
import '../../voice_navigation_service.dart';
import '../intelligence_engine/intelligence_engine.dart';
import '../intelligence_engine/models.dart';
import '../../../models/transaction.dart';

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

  BookkeepingOperationAdapter({
    IDatabaseService? databaseService,
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

    debugPrint('[BookkeepingOperationAdapter] 查询: $queryType');

    try {
      // 调用 DatabaseService 查询交易
      final transactions = await _databaseService.getTransactions();

      // 根据查询类型返回不同的结果
      switch (queryType) {
        case 'summary':
          final totalExpense = transactions
              .where((t) => t.type == TransactionType.expense)
              .fold(0.0, (sum, t) => sum + t.amount);
          final totalIncome = transactions
              .where((t) => t.type == TransactionType.income)
              .fold(0.0, (sum, t) => sum + t.amount);

          return ExecutionResult.success(data: {
            'queryType': queryType,
            'totalExpense': totalExpense,
            'totalIncome': totalIncome,
            'balance': totalIncome - totalExpense,
            'transactionCount': transactions.length,
          });

        case 'recent':
          final recentTransactions = transactions.take(10).toList();
          return ExecutionResult.success(data: {
            'queryType': queryType,
            'transactions': recentTransactions.map((t) => {
              'id': t.id,
              'type': t.type.toString(),
              'amount': t.amount,
              'category': t.category,
              'date': t.date.toIso8601String(),
            }).toList(),
          });

        default:
          return ExecutionResult.success(data: {
            'queryType': queryType,
            'transactionCount': transactions.length,
          });
      }
    } catch (e) {
      debugPrint('[BookkeepingOperationAdapter] 查询失败: $e');
      return ExecutionResult.failure('查询失败: $e');
    }
  }

  /// 导航
  Future<ExecutionResult> _navigate(Map<String, dynamic> params) async {
    final targetPage = params['targetPage'] as String?;
    final route = params['route'] as String?;

    if (targetPage == null && route == null) {
      return ExecutionResult.failure('导航目标未指定');
    }

    debugPrint('[BookkeepingOperationAdapter] 导航: $targetPage, $route');

    try {
      // 如果提供了具体的route，直接使用
      if (route != null) {
        return ExecutionResult.success(data: {
          'route': route,
          'targetPage': targetPage,
        });
      }

      // 否则使用VoiceNavigationService解析目标页面
      final navigationResult = _navigationService.parseNavigation(targetPage!);

      if (navigationResult.success) {
        return ExecutionResult.success(data: {
          'route': navigationResult.route,
          'pageName': navigationResult.pageName,
          'confidence': navigationResult.confidence,
        });
      } else {
        return ExecutionResult.failure(
          navigationResult.errorMessage ?? '导航失败'
        );
      }
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

      // 构建修改后的交易
      final updatedTransaction = Transaction(
        id: originalTransaction.id,
        type: originalTransaction.type,
        amount: (params['amount'] as num?)?.toDouble() ?? originalTransaction.amount,
        category: params['category'] as String? ?? originalTransaction.category,
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
