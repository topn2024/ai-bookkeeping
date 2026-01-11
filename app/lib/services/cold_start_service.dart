import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../models/transaction.dart';

/// 冷启动服务
///
/// 处理第一次使用app时的配置问题
/// 核心原则：先用起来，再配置
class ColdStartService {
  final IDatabaseService _db;

  ColdStartService(this._db);

  /// 检查是否冷启动（第一次使用）
  Future<bool> isColdStart() async {
    try {
      final transactions = await _db.getTransactions();
      return transactions.isEmpty;
    } catch (e) {
      // 数据库查询失败时，假设是冷启动
      return true;
    }
  }

  /// 检查是否准备好进行配置
  ///
  /// 条件：至少10笔记录 或 使用7天
  Future<bool> isReadyForConfig() async {
    try {
      final transactions = await _db.getTransactions();

      if (transactions.isEmpty) return false;

      // 检查记录数量
      if (transactions.length >= 10) return true;

      // 检查使用天数
      final firstTransaction = transactions.first;
      final daysUsed = DateTime.now().difference(firstTransaction.date).inDays;

      return daysUsed >= 7;
    } catch (e) {
      // 数据库查询失败时，返回 false
      return false;
    }
  }

  /// 检查是否已显示过配置建议
  Future<bool> hasShownConfigSuggestion() async {
    // TODO: 从数据库读取
    return false;
  }

  /// 标记已显示配置建议
  Future<void> markConfigSuggestionShown() async {
    // TODO: 保存到数据库
  }

  /// 生成智能配置建议
  Future<SmartConfigSuggestion> generateSuggestion() async {
    try {
      final transactions = await _db.getTransactions();

      if (transactions.isEmpty) {
        return SmartConfigSuggestion.defaultConfig();
      }

      return _generateFromTransactions(transactions);
    } catch (e) {
      // 数据库查询失败时，返回默认配置
      return SmartConfigSuggestion.defaultConfig();
    }
  }

  /// 基于交易记录生成建议
  SmartConfigSuggestion _generateFromTransactions(
    List<Transaction> transactions,
  ) {
    // 只看支出
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    if (expenses.isEmpty) {
      return SmartConfigSuggestion.defaultConfig();
    }

    // 计算时间跨度
    final firstDate = expenses.first.date;
    final lastDate = expenses.last.date;
    final days = lastDate.difference(firstDate).inDays + 1;

    // 计算总支出
    final totalExpense = expenses.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    // 计算日均支出
    final dailyAvg = totalExpense / days;

    // 推算月度预算（日均 * 30天 * 1.2倍缓冲）
    final monthlyEstimate = dailyAvg * 30 * 1.2;

    // 向上取整到百位
    final recommended = ((monthlyEstimate / 100).ceil() * 100).toDouble();

    // 生成3个选项
    final higher = ((recommended * 1.3 / 100).ceil() * 100).toDouble();
    final lower = ((recommended * 0.7 / 100).ceil() * 100).toDouble();

    return SmartConfigSuggestion(
      recommended: recommended,
      higher: higher,
      lower: lower,
      basedOnDays: days,
      basedOnTransactions: expenses.length,
      dailyAverage: dailyAvg,
      confidence: _calculateConfidence(days, expenses.length),
    );
  }

  /// 计算建议的置信度
  String _calculateConfidence(int days, int transactionCount) {
    if (days >= 7 && transactionCount >= 15) {
      return 'high';
    } else if (days >= 3 && transactionCount >= 10) {
      return 'medium';
    } else {
      return 'low';
    }
  }

  /// 获取使用天数
  Future<int> getDaysUsed() async {
    try {
      final transactions = await _db.getTransactions();

      if (transactions.isEmpty) return 0;

      final firstDate = transactions.first.date;
      return DateTime.now().difference(firstDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  /// 获取记录数量
  Future<int> getTransactionCount() async {
    try {
      final transactions = await _db.getTransactions();
      return transactions.length;
    } catch (e) {
      return 0;
    }
  }
}

/// 智能配置建议
class SmartConfigSuggestion {
  final double recommended; // 推荐预算
  final double higher; // 更高选项
  final double lower; // 更低选项
  final int basedOnDays; // 基于多少天的数据
  final int basedOnTransactions; // 基于多少笔交易
  final double dailyAverage; // 日均支出
  final String confidence; // 置信度：low/medium/high

  SmartConfigSuggestion({
    required this.recommended,
    required this.higher,
    required this.lower,
    required this.basedOnDays,
    required this.basedOnTransactions,
    required this.dailyAverage,
    required this.confidence,
  });

  /// 默认配置（冷启动时使用）
  factory SmartConfigSuggestion.defaultConfig() {
    return SmartConfigSuggestion(
      recommended: 3000.0,
      higher: 4000.0,
      lower: 2000.0,
      basedOnDays: 0,
      basedOnTransactions: 0,
      dailyAverage: 0,
      confidence: 'low',
    );
  }

  /// 获取说明文字
  String getExplanation() {
    if (basedOnDays == 0) {
      return '系统默认建议';
    }

    if (confidence == 'high') {
      return '根据这$basedOnDays天的花费（日均${dailyAverage.toInt()}元）';
    } else if (confidence == 'medium') {
      return '根据最近的花费情况';
    } else {
      return '初步建议（数据较少）';
    }
  }

  /// 获取置信度描述
  String getConfidenceDescription() {
    switch (confidence) {
      case 'high':
        return '建议准确度：高';
      case 'medium':
        return '建议准确度：中';
      case 'low':
        return '建议准确度：低（建议多用几天）';
      default:
        return '';
    }
  }
}

/// 冷启动状态
class ColdStartState {
  final bool isColdStart;
  final bool isReadyForConfig;
  final bool hasShownSuggestion;
  final int daysUsed;
  final int transactionCount;

  ColdStartState({
    required this.isColdStart,
    required this.isReadyForConfig,
    required this.hasShownSuggestion,
    required this.daysUsed,
    required this.transactionCount,
  });

  /// 是否应该显示配置建议
  bool get shouldShowSuggestion {
    return !isColdStart && isReadyForConfig && !hasShownSuggestion;
  }

  /// 获取状态描述
  String getStatusDescription() {
    if (isColdStart) {
      return '首次使用，先记几笔试试';
    } else if (!isReadyForConfig) {
      return '已使用$daysUsed天，记录$transactionCount笔';
    } else if (!hasShownSuggestion) {
      return '可以设置预算了';
    } else {
      return '配置已完成';
    }
  }
}

/// Provider
final coldStartServiceProvider = Provider<ColdStartService>((ref) {
  return ColdStartService(sl<IDatabaseService>());
});

/// 冷启动状态Provider
final coldStartStateProvider = FutureProvider<ColdStartState>((ref) async {
  final service = ref.watch(coldStartServiceProvider);

  final isColdStart = await service.isColdStart();
  final isReadyForConfig = await service.isReadyForConfig();
  final hasShownSuggestion = await service.hasShownConfigSuggestion();
  final daysUsed = await service.getDaysUsed();
  final transactionCount = await service.getTransactionCount();

  return ColdStartState(
    isColdStart: isColdStart,
    isReadyForConfig: isReadyForConfig,
    hasShownSuggestion: hasShownSuggestion,
    daysUsed: daysUsed,
    transactionCount: transactionCount,
  );
});
