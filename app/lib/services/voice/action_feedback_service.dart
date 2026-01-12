import '../../models/transaction.dart' as model;

/// 语音操作反馈服务
///
/// 为语音助手的操作生成详细、清晰的反馈信息
/// 原则：事事有反馈，有闭环，让用户知道具体做了什么
class VoiceActionFeedbackService {
  /// 单例模式
  static final VoiceActionFeedbackService _instance = VoiceActionFeedbackService._();
  static VoiceActionFeedbackService get instance => _instance;
  VoiceActionFeedbackService._();

  /// 生成记账成功反馈
  ///
  /// 不再说"好的，我来帮你记录"，而是明确告知已记录的内容
  String generateTransactionFeedback(List<TransactionResult> results) {
    if (results.isEmpty) {
      return '未能识别到有效的记账信息，请再说一次';
    }

    final buffer = StringBuffer();
    final successCount = results.where((r) => r.success).length;
    final failureCount = results.length - successCount;

    // 总体反馈
    if (successCount > 0 && failureCount == 0) {
      if (results.length == 1) {
        buffer.writeln('✓ 已成功记录：');
      } else {
        buffer.writeln('✓ 已成功记录 $successCount 笔：');
      }
    } else if (successCount > 0 && failureCount > 0) {
      buffer.writeln('✓ 成功 $successCount 笔，失败 $failureCount 笔：');
    } else {
      buffer.writeln('✗ 记录失败：');
    }

    buffer.writeln();

    // 详细列表
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final index = results.length > 1 ? '${i + 1}. ' : '';

      if (result.success) {
        buffer.write('$index${result.type == model.TransactionType.expense ? "支出" : "收入"} ');
        buffer.write('¥${result.amount.toStringAsFixed(2)}');

        if (result.category != null) {
          buffer.write(' · ${result.category}');
        }

        if (result.merchant != null) {
          buffer.write(' · ${result.merchant}');
        }

        if (result.description != null && result.description!.isNotEmpty) {
          buffer.write(' · ${result.description}');
        }

        buffer.writeln();
      } else {
        buffer.write('$index失败: ${result.errorMessage ?? "未知错误"}');
        buffer.writeln();
      }
    }

    return buffer.toString().trim();
  }

  /// 生成修改成功反馈
  String generateModifyFeedback({
    required bool success,
    String? originalInfo,
    String? modifiedInfo,
    String? errorMessage,
  }) {
    if (success) {
      final buffer = StringBuffer();
      buffer.writeln('✓ 修改成功：');
      buffer.writeln();

      if (originalInfo != null) {
        buffer.writeln('原记录: $originalInfo');
      }

      if (modifiedInfo != null) {
        buffer.writeln('新记录: $modifiedInfo');
      }

      return buffer.toString().trim();
    } else {
      return '✗ 修改失败: ${errorMessage ?? "未知错误"}';
    }
  }

  /// 生成删除成功反馈
  String generateDeleteFeedback({
    required bool success,
    int? deletedCount,
    String? deletedInfo,
    String? errorMessage,
  }) {
    if (success) {
      final buffer = StringBuffer();

      if (deletedCount != null && deletedCount > 1) {
        buffer.writeln('✓ 已删除 $deletedCount 笔记录');
      } else {
        buffer.write('✓ 已删除记录');
        if (deletedInfo != null) {
          buffer.write(': $deletedInfo');
        }
        buffer.writeln();
      }

      return buffer.toString().trim();
    } else {
      return '✗ 删除失败: ${errorMessage ?? "未找到匹配的记录"}';
    }
  }

  /// 生成查询结果反馈
  String generateQueryFeedback({
    required bool success,
    String? queryType,
    String? result,
    String? errorMessage,
  }) {
    if (success && result != null) {
      return result;
    } else {
      return '✗ 查询失败: ${errorMessage ?? "未找到相关数据"}';
    }
  }

  /// 生成导航反馈
  String generateNavigationFeedback({
    required bool success,
    String? targetPage,
    String? errorMessage,
  }) {
    if (success && targetPage != null) {
      return '✓ 已打开「$targetPage」页面';
    } else {
      return '✗ 导航失败: ${errorMessage ?? "未找到目标页面"}';
    }
  }

  /// 生成批量操作反馈
  String generateBatchFeedback({
    required int totalCount,
    required int successCount,
    required int failureCount,
    required String operationType,
    List<String>? failureReasons,
  }) {
    final buffer = StringBuffer();

    if (successCount == totalCount) {
      buffer.writeln('✓ 全部$operationType成功 ($totalCount 笔)');
    } else if (successCount > 0) {
      buffer.writeln('部分$operationType成功:');
      buffer.writeln('✓ 成功: $successCount 笔');
      buffer.writeln('✗ 失败: $failureCount 笔');

      if (failureReasons != null && failureReasons.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('失败原因:');
        for (var i = 0; i < failureReasons.length && i < 3; i++) {
          buffer.writeln('• ${failureReasons[i]}');
        }
        if (failureReasons.length > 3) {
          buffer.writeln('• ... 等共 ${failureReasons.length} 个错误');
        }
      }
    } else {
      buffer.writeln('✗ $operationType全部失败 ($totalCount 笔)');

      if (failureReasons != null && failureReasons.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('失败原因:');
        for (var reason in failureReasons.take(3)) {
          buffer.writeln('• $reason');
        }
      }
    }

    return buffer.toString().trim();
  }

  /// 生成预算查询反馈
  String generateBudgetFeedback({
    required String categoryOrTotal,
    required double budgetAmount,
    required double usedAmount,
    required double remainingAmount,
    required double usagePercentage,
  }) {
    final buffer = StringBuffer();
    final status = usagePercentage > 100
        ? '⚠️ 已超支'
        : usagePercentage > 80
            ? '⚠️ 即将超支'
            : '✓ 良好';

    buffer.writeln('$categoryOrTotal预算情况 $status');
    buffer.writeln();
    buffer.writeln('预算金额: ¥${budgetAmount.toStringAsFixed(2)}');
    buffer.writeln('已使用: ¥${usedAmount.toStringAsFixed(2)} (${usagePercentage.toStringAsFixed(1)}%)');
    buffer.writeln('剩余: ¥${remainingAmount.toStringAsFixed(2)}');

    return buffer.toString().trim();
  }

  /// 格式化金额显示
  String formatAmount(double amount) {
    return '¥${amount.toStringAsFixed(2)}';
  }

  /// 格式化日期显示
  String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '今天';
    } else if (targetDate == yesterday) {
      return '昨天';
    } else if (now.difference(date).inDays < 7) {
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}

/// 交易操作结果
class TransactionResult {
  final bool success;
  final model.TransactionType type;
  final double amount;
  final String? category;
  final String? merchant;
  final String? description;
  final DateTime? date;
  final String? errorMessage;
  final String? transactionId;

  const TransactionResult({
    required this.success,
    required this.type,
    required this.amount,
    this.category,
    this.merchant,
    this.description,
    this.date,
    this.errorMessage,
    this.transactionId,
  });

  factory TransactionResult.success({
    required model.TransactionType type,
    required double amount,
    String? category,
    String? merchant,
    String? description,
    DateTime? date,
    String? transactionId,
  }) {
    return TransactionResult(
      success: true,
      type: type,
      amount: amount,
      category: category,
      merchant: merchant,
      description: description,
      date: date,
      transactionId: transactionId,
    );
  }

  factory TransactionResult.failure({
    required model.TransactionType type,
    required double amount,
    String? errorMessage,
  }) {
    return TransactionResult(
      success: false,
      type: type,
      amount: amount,
      errorMessage: errorMessage,
    );
  }
}
