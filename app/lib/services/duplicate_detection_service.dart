import '../models/transaction.dart';

/// 重复检测结果
class DuplicateCheckResult {
  /// 是否发现潜在重复
  final bool hasPotentialDuplicate;

  /// 潜在重复的交易列表
  final List<Transaction> potentialDuplicates;

  /// 重复类型描述
  final String? duplicateReason;

  /// 相似度评分 (0-100)
  final int similarityScore;

  const DuplicateCheckResult({
    required this.hasPotentialDuplicate,
    this.potentialDuplicates = const [],
    this.duplicateReason,
    this.similarityScore = 0,
  });

  static const noDuplicate = DuplicateCheckResult(
    hasPotentialDuplicate: false,
  );
}

/// 重复交易检测服务
///
/// 重复判定核心原则：
/// 1. 时间是最重要的因素 - 不同天的相同消费不是重复（如每天买早餐）
/// 2. 只有同一天且时间非常接近的相似交易才可能是重复
/// 3. 金额+分类+备注相似只是辅助判断条件
class DuplicateDetectionService {
  /// 检测配置
  static const int _strictTimeMinutes = 10;    // 严格时间差阈值（分钟）- 极可能重复
  static const int _looseTimeMinutes = 60;     // 宽松时间差阈值（分钟）- 可能重复
  static const int _maxTimeMinutes = 120;      // 最大时间差（分钟）- 超过则不认为是重复
  static const double _amountTolerance = 0.01; // 金额容差（用于浮点数比较）

  /// 检查新交易是否与现有交易重复
  ///
  /// [newTransaction] 要检查的新交易
  /// [existingTransactions] 现有交易列表
  /// [checkTimeRange] 检查的时间范围（默认检查当天）
  static DuplicateCheckResult checkDuplicate(
    Transaction newTransaction,
    List<Transaction> existingTransactions, {
    Duration checkTimeRange = const Duration(hours: 12),
  }) {
    if (existingTransactions.isEmpty) {
      return DuplicateCheckResult.noDuplicate;
    }

    final potentialDuplicates = <Transaction>[];
    int highestScore = 0;
    String? reason;

    // 只检查同一天的交易 - 不同天的相同消费不是重复
    final sameDayTransactions = existingTransactions.where((t) {
      return _isSameDay(t.date, newTransaction.date);
    }).toList();

    if (sameDayTransactions.isEmpty) {
      return DuplicateCheckResult.noDuplicate;
    }

    for (final existing in sameDayTransactions) {
      final result = _calculateSimilarity(newTransaction, existing);

      if (result.score >= 70) { // 提高相似度阈值
        potentialDuplicates.add(existing);
        if (result.score > highestScore) {
          highestScore = result.score;
          reason = result.reason;
        }
      }
    }

    if (potentialDuplicates.isEmpty) {
      return DuplicateCheckResult.noDuplicate;
    }

    // 按相似度排序
    potentialDuplicates.sort((a, b) {
      final scoreA = _calculateSimilarity(newTransaction, a).score;
      final scoreB = _calculateSimilarity(newTransaction, b).score;
      return scoreB.compareTo(scoreA);
    });

    return DuplicateCheckResult(
      hasPotentialDuplicate: true,
      potentialDuplicates: potentialDuplicates,
      duplicateReason: reason,
      similarityScore: highestScore,
    );
  }

  /// 计算两笔交易的相似度
  ///
  /// 评分标准（总分100分，阈值70分）：
  /// - 时间接近：0-35分（核心条件，时间差>2小时直接返回0）
  /// - 金额相同：25分
  /// - 分类相同：15分
  /// - 备注相似：15分
  /// - 账户相同：5分
  /// - 类型相同：5分
  static _SimilarityResult _calculateSimilarity(
    Transaction newTx,
    Transaction existingTx,
  ) {
    int score = 0;
    final reasons = <String>[];

    // 1. 时间接近是核心条件 - 时间差超过2小时不认为是重复
    final timeDiff = newTx.date.difference(existingTx.date).abs();
    if (timeDiff.inMinutes > _maxTimeMinutes) {
      // 时间差太大，即使其他条件相同也不是重复
      // 例如：早上买早餐15元，晚上又买了15元的东西，不是重复
      return _SimilarityResult(score: 0, reason: null);
    }

    // 时间评分（核心权重）
    if (timeDiff.inMinutes <= _strictTimeMinutes) {
      score += 35;
      reasons.add('时间非常接近(${timeDiff.inMinutes}分钟内)');
    } else if (timeDiff.inMinutes <= _looseTimeMinutes) {
      score += 25;
      reasons.add('时间接近(${timeDiff.inMinutes}分钟内)');
    } else {
      score += 15;
      reasons.add('同一天(相隔${timeDiff.inMinutes}分钟)');
    }

    // 2. 金额相同 (+25分)
    if ((newTx.amount - existingTx.amount).abs() < _amountTolerance) {
      score += 25;
      reasons.add('金额相同');
    }

    // 3. 分类相同 (+15分)
    if (newTx.category == existingTx.category) {
      score += 15;
      reasons.add('分类相同');
    }

    // 4. 备注相似 (+15分) - 备注相同是强信号
    if (_isNoteSimilar(newTx.note, existingTx.note)) {
      score += 15;
      reasons.add('备注相似');
    }

    // 5. 账户相同 (+5分)
    if (newTx.accountId == existingTx.accountId) {
      score += 5;
    }

    // 6. 类型相同 (+5分)
    if (newTx.type == existingTx.type) {
      score += 5;
    }

    // 判断重复等级
    if (score >= 85) {
      return _SimilarityResult(
        score: score,
        reason: '极可能重复: ${reasons.join(', ')}',
      );
    } else if (score >= 70) {
      return _SimilarityResult(
        score: score,
        reason: '疑似重复: ${reasons.join(', ')}',
      );
    }

    return _SimilarityResult(score: score, reason: null);
  }

  /// 检查是否是同一天
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 检查备注是否相似
  static bool _isNoteSimilar(String? a, String? b) {
    // 两个都为空不算相似（没有信息）
    if (a == null || b == null) return false;
    if (a.isEmpty || b.isEmpty) return false;

    if (a == b) return true;

    // 忽略大小写和空格比较
    final normalizedA = a.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final normalizedB = b.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    if (normalizedA == normalizedB) return true;

    // 检查是否包含关系（至少3个字符才检查）
    if (normalizedA.length >= 3 && normalizedB.length >= 3) {
      if (normalizedA.contains(normalizedB) || normalizedB.contains(normalizedA)) {
        return true;
      }
    }

    return false;
  }

  /// 快速检查是否需要详细检测
  /// 用于性能优化，先快速排除明显不重复的情况
  static bool needsDetailedCheck(
    Transaction newTransaction,
    List<Transaction> existingTransactions,
  ) {
    // 只有同一天、相同金额、时间接近的交易才需要详细检查
    final today = newTransaction.date;
    return existingTransactions.any((t) {
      if (!_isSameDay(t.date, today)) return false;

      final timeDiff = newTransaction.date.difference(t.date).abs();
      if (timeDiff.inMinutes > _maxTimeMinutes) return false;

      return (t.amount - newTransaction.amount).abs() < _amountTolerance &&
          t.type == newTransaction.type;
    });
  }
}

class _SimilarityResult {
  final int score;
  final String? reason;

  _SimilarityResult({required this.score, this.reason});
}
