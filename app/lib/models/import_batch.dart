/// Import batch status
enum ImportBatchStatus {
  active,   // 有效
  revoked,  // 已撤销
}

/// Represents a batch import operation
class ImportBatch {
  /// Unique batch ID: IMP + timestamp (e.g., IMP20240115103045)
  final String id;

  /// Original file name
  final String fileName;

  /// Detected file format (e.g., wechat_pay, alipay, cmb_bank)
  final String fileFormat;

  /// Total number of records in the file
  final int totalCount;

  /// Number of successfully imported records
  final int importedCount;

  /// Number of skipped records (duplicates)
  final int skippedCount;

  /// Number of failed records
  final int failedCount;

  /// Total expense amount imported
  final double totalExpense;

  /// Total income amount imported
  final double totalIncome;

  /// Start of transaction date range
  final DateTime? dateRangeStart;

  /// End of transaction date range
  final DateTime? dateRangeEnd;

  /// Import timestamp
  final DateTime createdAt;

  /// Batch status
  final ImportBatchStatus status;

  /// Revocation timestamp
  final DateTime? revokedAt;

  /// Error log (JSON string)
  final String? errorLog;

  ImportBatch({
    required this.id,
    required this.fileName,
    required this.fileFormat,
    required this.totalCount,
    required this.importedCount,
    required this.skippedCount,
    this.failedCount = 0,
    this.totalExpense = 0,
    this.totalIncome = 0,
    this.dateRangeStart,
    this.dateRangeEnd,
    DateTime? createdAt,
    this.status = ImportBatchStatus.active,
    this.revokedAt,
    this.errorLog,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Generate a new batch ID
  static String generateId() {
    final now = DateTime.now();
    return 'IMP${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  /// Get display name for file format
  String get fileFormatName {
    switch (fileFormat) {
      case 'wechat_pay':
        return '微信支付';
      case 'alipay':
        return '支付宝';
      case 'cmb_bank':
        return '招商银行';
      case 'icbc_bank':
        return '工商银行';
      case 'abc_bank':
        return '农业银行';
      case 'ccb_bank':
        return '建设银行';
      case 'boc_bank':
        return '中国银行';
      case 'other_bank':
        return '其他银行';
      case 'generic':
        return '通用格式';
      case 'email':
        return '邮箱账单';
      default:
        return fileFormat;
    }
  }

  /// Check if batch is active
  bool get isActive => status == ImportBatchStatus.active;

  /// Check if batch is revoked
  bool get isRevoked => status == ImportBatchStatus.revoked;

  /// Get net amount (income - expense)
  double get netAmount => totalIncome - totalExpense;

  /// Get date range display string
  String get dateRangeDisplay {
    if (dateRangeStart == null || dateRangeEnd == null) {
      return '-';
    }
    final start = '${dateRangeStart!.year}-${dateRangeStart!.month.toString().padLeft(2, '0')}-${dateRangeStart!.day.toString().padLeft(2, '0')}';
    final end = '${dateRangeEnd!.year}-${dateRangeEnd!.month.toString().padLeft(2, '0')}-${dateRangeEnd!.day.toString().padLeft(2, '0')}';
    return '$start 至 $end';
  }

  ImportBatch copyWith({
    String? id,
    String? fileName,
    String? fileFormat,
    int? totalCount,
    int? importedCount,
    int? skippedCount,
    int? failedCount,
    double? totalExpense,
    double? totalIncome,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    DateTime? createdAt,
    ImportBatchStatus? status,
    DateTime? revokedAt,
    String? errorLog,
  }) {
    return ImportBatch(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileFormat: fileFormat ?? this.fileFormat,
      totalCount: totalCount ?? this.totalCount,
      importedCount: importedCount ?? this.importedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      failedCount: failedCount ?? this.failedCount,
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
      dateRangeStart: dateRangeStart ?? this.dateRangeStart,
      dateRangeEnd: dateRangeEnd ?? this.dateRangeEnd,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      revokedAt: revokedAt ?? this.revokedAt,
      errorLog: errorLog ?? this.errorLog,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileFormat': fileFormat,
      'totalCount': totalCount,
      'importedCount': importedCount,
      'skippedCount': skippedCount,
      'failedCount': failedCount,
      'totalExpense': totalExpense,
      'totalIncome': totalIncome,
      'dateRangeStart': dateRangeStart?.millisecondsSinceEpoch,
      'dateRangeEnd': dateRangeEnd?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.index,
      'revokedAt': revokedAt?.millisecondsSinceEpoch,
      'errorLog': errorLog,
    };
  }

  factory ImportBatch.fromMap(Map<String, dynamic> map) {
    return ImportBatch(
      id: map['id'],
      fileName: map['fileName'],
      fileFormat: map['fileFormat'],
      totalCount: map['totalCount'],
      importedCount: map['importedCount'],
      skippedCount: map['skippedCount'],
      failedCount: map['failedCount'] ?? 0,
      totalExpense: (map['totalExpense'] as num?)?.toDouble() ?? 0,
      totalIncome: (map['totalIncome'] as num?)?.toDouble() ?? 0,
      dateRangeStart: map['dateRangeStart'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateRangeStart'])
          : null,
      dateRangeEnd: map['dateRangeEnd'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateRangeEnd'])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      status: ImportBatchStatus.values[map['status'] ?? 0],
      revokedAt: map['revokedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['revokedAt'])
          : null,
      errorLog: map['errorLog'],
    );
  }

  @override
  String toString() {
    return 'ImportBatch(id: $id, fileName: $fileName, format: $fileFormat, '
        'imported: $importedCount/$totalCount, status: $status)';
  }
}
