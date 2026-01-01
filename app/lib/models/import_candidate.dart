import 'transaction.dart';

/// Import action for a candidate
enum ImportAction {
  import_,  // Will be imported
  skip,     // Will be skipped
  pending,  // Waiting for user confirmation
}

/// Duplicate detection level
enum DuplicateLevel {
  exact,   // 100分, 确定重复 (external ID match)
  high,    // 85-99分, 高度疑似
  medium,  // 60-84分, 可能重复
  low,     // 40-59分, 轻微相似
  none,    // <40分, 新交易
}

/// Duplicate check result
class DuplicateCheckResult {
  /// Similarity score (0-100)
  final int score;

  /// Duplicate level
  final DuplicateLevel level;

  /// Match reason description
  final String reason;

  /// Matched existing transaction (if any)
  final Transaction? matchedTransaction;

  /// Score breakdown
  final Map<String, int>? scoreBreakdown;

  DuplicateCheckResult({
    required this.score,
    required this.level,
    required this.reason,
    this.matchedTransaction,
    this.scoreBreakdown,
  });

  /// Get level display text
  String get levelText {
    switch (level) {
      case DuplicateLevel.exact:
        return '确定重复';
      case DuplicateLevel.high:
        return '高度疑似';
      case DuplicateLevel.medium:
        return '可能重复';
      case DuplicateLevel.low:
        return '轻微相似';
      case DuplicateLevel.none:
        return '新交易';
    }
  }

  /// Get level color (for UI)
  /// Returns: red=0, orange=1, yellow=2, green=3
  int get levelColorIndex {
    switch (level) {
      case DuplicateLevel.exact:
        return 0; // Red
      case DuplicateLevel.high:
        return 0; // Red
      case DuplicateLevel.medium:
        return 1; // Orange
      case DuplicateLevel.low:
        return 2; // Yellow
      case DuplicateLevel.none:
        return 3; // Green
    }
  }

  /// Factory for no duplicate
  factory DuplicateCheckResult.noDuplicate() {
    return DuplicateCheckResult(
      score: 0,
      level: DuplicateLevel.none,
      reason: '新交易',
    );
  }

  /// Factory for exact match
  factory DuplicateCheckResult.exactMatch(Transaction matched) {
    return DuplicateCheckResult(
      score: 100,
      level: DuplicateLevel.exact,
      reason: '交易单号完全匹配',
      matchedTransaction: matched,
    );
  }

  @override
  String toString() {
    return 'DuplicateCheckResult(score: $score, level: $level, reason: $reason)';
  }
}

/// Represents a candidate transaction to be imported
class ImportCandidate {
  /// Row index in the source file (0-based)
  final int index;

  /// Transaction date
  final DateTime date;

  /// Transaction amount (always positive)
  final double amount;

  /// Transaction type
  final TransactionType type;

  /// External transaction ID (from the bill)
  final String? externalId;

  /// Raw merchant name from the bill
  final String? rawMerchant;

  /// Note or product description
  final String? note;

  /// Raw payment method from the bill
  final String? rawPaymentMethod;

  /// Raw transaction status from the bill
  final String? rawStatus;

  /// Inferred category ID
  String? category;

  /// Mapped account ID
  String? accountId;

  /// Duplicate check result
  DuplicateCheckResult? duplicateResult;

  /// Import action
  ImportAction action;

  /// Whether this candidate has been edited by user
  bool isEdited;

  /// Original raw data from the bill (for reference)
  final Map<String, dynamic>? rawData;

  ImportCandidate({
    required this.index,
    required this.date,
    required this.amount,
    required this.type,
    this.externalId,
    this.rawMerchant,
    this.note,
    this.rawPaymentMethod,
    this.rawStatus,
    this.category,
    this.accountId,
    this.duplicateResult,
    this.action = ImportAction.pending,
    this.isEdited = false,
    this.rawData,
  });

  /// Get display amount (with sign)
  double get displayAmount {
    return type == TransactionType.expense ? -amount : amount;
  }

  /// Get formatted amount string
  String get amountText {
    final sign = type == TransactionType.expense ? '-' : '+';
    return '$sign¥${amount.toStringAsFixed(2)}';
  }

  /// Check if this candidate is marked for import
  bool get willImport => action == ImportAction.import_;

  /// Check if this candidate is marked to skip
  bool get willSkip => action == ImportAction.skip;

  /// Check if this candidate is pending confirmation
  bool get isPending => action == ImportAction.pending;

  /// Check if this is a duplicate (any level)
  bool get isDuplicate =>
      duplicateResult != null && duplicateResult!.level != DuplicateLevel.none;

  /// Check if this is an exact duplicate
  bool get isExactDuplicate =>
      duplicateResult != null && duplicateResult!.level == DuplicateLevel.exact;

  /// Check if this is a high duplicate
  bool get isHighDuplicate =>
      duplicateResult != null && duplicateResult!.level == DuplicateLevel.high;

  /// Check if this needs user confirmation
  bool get needsConfirmation =>
      duplicateResult != null &&
      (duplicateResult!.level == DuplicateLevel.medium ||
          duplicateResult!.level == DuplicateLevel.high);

  /// Get default action based on duplicate level
  ImportAction get defaultAction {
    if (duplicateResult == null) return ImportAction.import_;

    switch (duplicateResult!.level) {
      case DuplicateLevel.exact:
        return ImportAction.skip;
      case DuplicateLevel.high:
        return ImportAction.skip;
      case DuplicateLevel.medium:
        return ImportAction.pending;
      case DuplicateLevel.low:
        return ImportAction.import_;
      case DuplicateLevel.none:
        return ImportAction.import_;
    }
  }

  /// Apply default action based on duplicate check
  void applyDefaultAction() {
    action = defaultAction;
  }

  /// Convert to Transaction for importing
  Transaction toTransaction({
    required String id,
    required String batchId,
    required ExternalSource? externalSource,
  }) {
    return Transaction(
      id: id,
      type: type,
      amount: amount,
      category: category ?? 'other',
      note: note,
      date: date,
      accountId: accountId ?? 'default',
      source: TransactionSource.import_,
      externalId: externalId,
      externalSource: externalSource,
      importBatchId: batchId,
      rawMerchant: rawMerchant,
    );
  }

  ImportCandidate copyWith({
    int? index,
    DateTime? date,
    double? amount,
    TransactionType? type,
    String? externalId,
    String? rawMerchant,
    String? note,
    String? rawPaymentMethod,
    String? rawStatus,
    String? category,
    String? accountId,
    DuplicateCheckResult? duplicateResult,
    ImportAction? action,
    bool? isEdited,
    Map<String, dynamic>? rawData,
  }) {
    return ImportCandidate(
      index: index ?? this.index,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      externalId: externalId ?? this.externalId,
      rawMerchant: rawMerchant ?? this.rawMerchant,
      note: note ?? this.note,
      rawPaymentMethod: rawPaymentMethod ?? this.rawPaymentMethod,
      rawStatus: rawStatus ?? this.rawStatus,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      duplicateResult: duplicateResult ?? this.duplicateResult,
      action: action ?? this.action,
      isEdited: isEdited ?? this.isEdited,
      rawData: rawData ?? this.rawData,
    );
  }

  @override
  String toString() {
    return 'ImportCandidate(index: $index, date: $date, amount: $amount, '
        'type: $type, merchant: $rawMerchant, action: $action)';
  }
}

/// Summary of import candidates
class ImportCandidateSummary {
  final int totalCount;
  final int newCount;
  final int possibleDuplicateCount;
  final int highDuplicateCount;
  final int exactDuplicateCount;
  final int toImportCount;
  final int toSkipCount;
  final double totalExpense;
  final double totalIncome;

  ImportCandidateSummary({
    required this.totalCount,
    required this.newCount,
    required this.possibleDuplicateCount,
    required this.highDuplicateCount,
    required this.exactDuplicateCount,
    required this.toImportCount,
    required this.toSkipCount,
    this.totalExpense = 0,
    this.totalIncome = 0,
  });

  factory ImportCandidateSummary.fromCandidates(List<ImportCandidate> candidates) {
    int newCount = 0;
    int possibleCount = 0;
    int highCount = 0;
    int exactCount = 0;
    int toImport = 0;
    int toSkip = 0;
    double expense = 0;
    double income = 0;

    for (final c in candidates) {
      if (c.duplicateResult == null || c.duplicateResult!.level == DuplicateLevel.none) {
        newCount++;
      } else {
        switch (c.duplicateResult!.level) {
          case DuplicateLevel.medium:
          case DuplicateLevel.low:
            possibleCount++;
            break;
          case DuplicateLevel.high:
            highCount++;
            break;
          case DuplicateLevel.exact:
            exactCount++;
            break;
          case DuplicateLevel.none:
            break;
        }
      }

      if (c.action == ImportAction.import_) {
        toImport++;
        if (c.type == TransactionType.expense) {
          expense += c.amount;
        } else if (c.type == TransactionType.income) {
          income += c.amount;
        }
      } else if (c.action == ImportAction.skip) {
        toSkip++;
      }
    }

    return ImportCandidateSummary(
      totalCount: candidates.length,
      newCount: newCount,
      possibleDuplicateCount: possibleCount,
      highDuplicateCount: highCount,
      exactDuplicateCount: exactCount,
      toImportCount: toImport,
      toSkipCount: toSkip,
      totalExpense: expense,
      totalIncome: income,
    );
  }

  /// Total duplicate count (all levels)
  int get duplicateCount => possibleDuplicateCount + highDuplicateCount + exactDuplicateCount;

  /// Pending count (not yet decided)
  int get pendingCount => totalCount - toImportCount - toSkipCount;
}
