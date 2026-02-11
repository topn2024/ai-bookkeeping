import 'package:flutter/foundation.dart';
import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/transaction.dart';
import '../../../../services/category_localization_service.dart';
import '../action_registry.dart';

/// 分享交易记录Action
///
/// 支持分享单笔或多笔交易记录到社交平台
class ShareTransactionAction extends Action {
  final IDatabaseService databaseService;

  ShareTransactionAction(this.databaseService);

  @override
  String get id => 'share.transaction';

  @override
  String get name => '分享交易记录';

  @override
  String get description => '分享一笔或多笔交易记录';

  @override
  List<String> get triggerPatterns => [
    '分享这笔', '分享交易', '分享记录',
    '发给朋友', '分享给',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'transactionId',
      type: ActionParamType.string,
      required: false,
      description: '交易ID',
    ),
    const ActionParam(
      name: 'shareType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'text',
      description: '分享类型: text/image/link',
    ),
    const ActionParam(
      name: 'platform',
      type: ActionParamType.string,
      required: false,
      description: '分享平台: wechat/weibo/clipboard',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final transactionId = params['transactionId'] as String?;
      final shareType = params['shareType'] as String? ?? 'text';
      final platform = params['platform'] as String?;

      Transaction? transaction;
      if (transactionId != null) {
        final transactions = await databaseService.getTransactions();
        transaction = transactions.where((t) => t.id == transactionId).firstOrNull;
      }

      // 如果没有指定交易，获取最近一笔
      if (transaction == null) {
        final recentTransactions = await databaseService.queryTransactions(limit: 1);
        if (recentTransactions.isNotEmpty) {
          transaction = recentTransactions.first;
        }
      }

      if (transaction == null) {
        return ActionResult.failure('没有找到可分享的交易记录', actionId: id);
      }

      // 生成分享内容
      final shareContent = _generateShareContent(transaction, shareType);

      return ActionResult.success(
        responseText: '已准备好分享内容${platform != null ? "，将发送到$platform" : ""}',
        data: {
          'shareContent': shareContent,
          'shareType': shareType,
          'platform': platform,
          'transactionId': transaction.id,
          'ready': true,
        },
        actionId: id,
      );
    } catch (e) {
      debugPrint('[ShareTransactionAction] 分享失败: $e');
      return ActionResult.failure('分享交易记录失败: $e', actionId: id);
    }
  }

  /// 生成分享内容
  String _generateShareContent(Transaction transaction, String shareType) {
    final typeText = transaction.type == TransactionType.expense ? '支出' : '收入';
    final date = '${transaction.date.month}月${transaction.date.day}日';

    final categoryName = transaction.category.localizedCategoryName;
    switch (shareType) {
      case 'text':
        return '【记账打卡】$date$categoryName$typeText${transaction.amount.toStringAsFixed(2)}元${transaction.note != null ? " - ${transaction.note}" : ""}';
      case 'simple':
        return '$typeText: $categoryName ¥${transaction.amount.toStringAsFixed(2)}';
      default:
        return '$categoryName $typeText ${transaction.amount.toStringAsFixed(2)}元';
    }
  }
}

/// 分享统计报告Action
///
/// 生成并分享消费统计报告
class ShareReportAction extends Action {
  final IDatabaseService databaseService;

  ShareReportAction(this.databaseService);

  @override
  String get id => 'share.report';

  @override
  String get name => '分享统计报告';

  @override
  String get description => '生成并分享消费统计报告';

  @override
  List<String> get triggerPatterns => [
    '分享报告', '分享统计', '分享月报',
    '分享消费报告', '晒账单',
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
      description: '报告周期: week/month/year',
    ),
    const ActionParam(
      name: 'reportType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'summary',
      description: '报告类型: summary/detailed/category',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final period = params['period'] as String? ?? 'month';
      final reportType = params['reportType'] as String? ?? 'summary';

      // 计算时间范围
      final now = DateTime.now();
      DateTime startDate;
      String periodText;

      switch (period) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          periodText = '本周';
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          periodText = '今年';
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

      // 计算统计数据
      double totalExpense = 0;
      double totalIncome = 0;
      final categoryExpense = <String, double>{};

      for (final t in transactions) {
        if (t.type == TransactionType.expense) {
          totalExpense += t.amount;
          categoryExpense[t.category] = (categoryExpense[t.category] ?? 0) + t.amount;
        } else if (t.type == TransactionType.income) {
          totalIncome += t.amount;
        }
      }

      // 找出消费最高的分类
      String? topCategory;
      double topCategoryAmount = 0;
      categoryExpense.forEach((category, amount) {
        if (amount > topCategoryAmount) {
          topCategoryAmount = amount;
          topCategory = category;
        }
      });

      // 生成报告内容
      final reportContent = _generateReportContent(
        periodText: periodText,
        totalExpense: totalExpense,
        totalIncome: totalIncome,
        transactionCount: transactions.length,
        topCategory: topCategory,
        topCategoryAmount: topCategoryAmount,
        reportType: reportType,
      );

      return ActionResult.success(
        responseText: '$periodText消费报告已生成，可以分享给朋友',
        data: {
          'reportContent': reportContent,
          'period': period,
          'periodText': periodText,
          'totalExpense': totalExpense,
          'totalIncome': totalIncome,
          'balance': totalIncome - totalExpense,
          'transactionCount': transactions.length,
          'topCategory': topCategory,
          'topCategoryAmount': topCategoryAmount,
          'categoryDistribution': categoryExpense,
        },
        actionId: id,
      );
    } catch (e) {
      debugPrint('[ShareReportAction] 生成报告失败: $e');
      return ActionResult.failure('生成消费报告失败: $e', actionId: id);
    }
  }

  /// 生成报告内容
  String _generateReportContent({
    required String periodText,
    required double totalExpense,
    required double totalIncome,
    required int transactionCount,
    String? topCategory,
    double? topCategoryAmount,
    required String reportType,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📊 $periodText消费报告');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 总支出: ¥${totalExpense.toStringAsFixed(2)}');
    buffer.writeln('💵 总收入: ¥${totalIncome.toStringAsFixed(2)}');
    buffer.writeln('📝 记账次数: $transactionCount笔');

    if (topCategory != null && topCategoryAmount != null) {
      buffer.writeln('🔝 最大支出: $topCategory ¥${topCategoryAmount.toStringAsFixed(2)}');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.write('来自智能记账App');

    return buffer.toString();
  }
}

/// 分享预算信息Action
///
/// 分享预算使用情况和剩余预算
class ShareBudgetAction extends Action {
  final IDatabaseService databaseService;

  ShareBudgetAction(this.databaseService);

  @override
  String get id => 'share.budget';

  @override
  String get name => '分享预算信息';

  @override
  String get description => '分享预算使用情况';

  @override
  List<String> get triggerPatterns => [
    '分享预算', '晒预算', '分享剩余预算',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'category',
      type: ActionParamType.string,
      required: false,
      description: '特定分类的预算',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final category = params['category'] as String?;

      // 获取预算数据
      final budgets = await databaseService.getBudgets();

      if (budgets.isEmpty) {
        return ActionResult.success(
          responseText: '暂未设置预算，无法分享',
          data: {'hasBudget': false},
          actionId: id,
        );
      }

      // 计算预算使用情况
      // 注意：实际使用需要结合交易数据计算已使用金额
      double totalBudget = 0;

      for (final budget in budgets) {
        if (category == null || budget.categoryId == category || budget.name.contains(category)) {
          totalBudget += budget.amount;
        }
      }

      // 获取当月支出来计算已使用金额
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final transactions = await databaseService.queryTransactions(
        startDate: startOfMonth,
        endDate: now,
      );

      double totalSpent = 0;
      for (final t in transactions) {
        if (t.type == TransactionType.expense) {
          if (category == null || t.category == category) {
            totalSpent += t.amount;
          }
        }
      }

      final remaining = totalBudget - totalSpent;
      final usagePercent = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;

      // 生成分享内容
      final shareContent = _generateBudgetShareContent(
        category: category,
        totalBudget: totalBudget,
        totalSpent: totalSpent,
        remaining: remaining,
        usagePercent: usagePercent,
      );

      return ActionResult.success(
        responseText: '预算信息已准备好分享',
        data: {
          'shareContent': shareContent,
          'category': category,
          'totalBudget': totalBudget,
          'totalSpent': totalSpent,
          'remaining': remaining,
          'usagePercent': usagePercent,
        },
        actionId: id,
      );
    } catch (e) {
      debugPrint('[ShareBudgetAction] 分享预算失败: $e');
      return ActionResult.failure('分享预算信息失败: $e', actionId: id);
    }
  }

  /// 生成预算分享内容
  String _generateBudgetShareContent({
    String? category,
    required double totalBudget,
    required double totalSpent,
    required double remaining,
    required double usagePercent,
  }) {
    final categoryText = category ?? '总';
    final emoji = usagePercent < 50 ? '😊' : (usagePercent < 80 ? '😐' : '😰');

    return '''
$emoji ${categoryText}预算使用情况
━━━━━━━━━━━━━━━━
预算: ¥${totalBudget.toStringAsFixed(2)}
已用: ¥${totalSpent.toStringAsFixed(2)} (${usagePercent.toStringAsFixed(1)}%)
剩余: ¥${remaining.toStringAsFixed(2)}
━━━━━━━━━━━━━━━━
来自智能记账App
''';
  }
}
