import 'transaction_split.dart';

enum TransactionType {
  expense,
  income,
  transfer,
}

/// Source of transaction creation
enum TransactionSource {
  manual,  // 0: Manual input
  image,   // 1: Image recognition (receipt scanning)
  voice,   // 2: Voice recognition
  email,   // 3: Email bill parsing
  import_,  // 4: Batch import from bill files (use import_ to avoid keyword conflict)
}

/// External source for imported transactions
enum ExternalSource {
  wechatPay,    // 微信支付
  alipay,       // 支付宝
  cmbBank,      // 招商银行
  icbcBank,     // 工商银行
  abcBank,      // 农业银行
  ccbBank,      // 建设银行
  bocBank,      // 中国银行
  otherBank,    // 其他银行
  generic,      // 通用格式
}

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String? subcategory;
  final String? note;
  final DateTime date;
  final String accountId;
  final String? toAccountId; // For transfers
  final String? imageUrl;
  final bool isSplit; // 是否为拆分交易
  final List<TransactionSplit>? splits; // 拆分项列表
  final bool isReimbursable; // 是否可报销
  final bool isReimbursed;   // 是否已报销
  final List<String>? tags;  // 标签列表
  final DateTime createdAt;
  final DateTime updatedAt;

  // Source file fields for AI recognition
  final TransactionSource source; // 来源: 手动/图片/语音/邮件/导入
  final double? aiConfidence;     // AI识别置信度 (0-1)
  final String? sourceFileLocalPath;  // 本地源文件路径
  final String? sourceFileServerUrl;  // 服务器源文件URL
  final String? sourceFileType;       // 文件MIME类型
  final int? sourceFileSize;          // 文件大小(bytes)
  final String? recognitionRawData;   // AI识别原始响应JSON
  final DateTime? sourceFileExpiresAt; // 源文件过期时间

  // Batch import fields
  final String? externalId;           // 外部交易号(微信/支付宝/银行流水号)
  final ExternalSource? externalSource; // 外部来源标识
  final String? importBatchId;        // 导入批次ID(用于批量回滚)
  final String? rawMerchant;          // 原始商户名(用于AI分类学习)

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    this.note,
    required this.date,
    required this.accountId,
    this.toAccountId,
    this.imageUrl,
    this.isSplit = false,
    this.splits,
    this.isReimbursable = false,
    this.isReimbursed = false,
    this.tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.source = TransactionSource.manual,
    this.aiConfidence,
    this.sourceFileLocalPath,
    this.sourceFileServerUrl,
    this.sourceFileType,
    this.sourceFileSize,
    this.recognitionRawData,
    this.sourceFileExpiresAt,
    this.externalId,
    this.externalSource,
    this.importBatchId,
    this.rawMerchant,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 获取拆分项的分类摘要显示
  String get splitCategorySummary {
    if (!isSplit || splits == null || splits!.isEmpty) {
      return category;
    }
    if (splits!.length == 1) {
      return splits!.first.category;
    }
    return '${splits!.first.category} 等${splits!.length}项';
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? category,
    String? subcategory,
    String? note,
    DateTime? date,
    String? accountId,
    String? toAccountId,
    String? imageUrl,
    bool? isSplit,
    List<TransactionSplit>? splits,
    bool? isReimbursable,
    bool? isReimbursed,
    List<String>? tags,
    TransactionSource? source,
    double? aiConfidence,
    String? sourceFileLocalPath,
    String? sourceFileServerUrl,
    String? sourceFileType,
    int? sourceFileSize,
    String? recognitionRawData,
    DateTime? sourceFileExpiresAt,
    String? externalId,
    ExternalSource? externalSource,
    String? importBatchId,
    String? rawMerchant,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      note: note ?? this.note,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      imageUrl: imageUrl ?? this.imageUrl,
      isSplit: isSplit ?? this.isSplit,
      splits: splits ?? this.splits,
      isReimbursable: isReimbursable ?? this.isReimbursable,
      isReimbursed: isReimbursed ?? this.isReimbursed,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      source: source ?? this.source,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      sourceFileLocalPath: sourceFileLocalPath ?? this.sourceFileLocalPath,
      sourceFileServerUrl: sourceFileServerUrl ?? this.sourceFileServerUrl,
      sourceFileType: sourceFileType ?? this.sourceFileType,
      sourceFileSize: sourceFileSize ?? this.sourceFileSize,
      recognitionRawData: recognitionRawData ?? this.recognitionRawData,
      sourceFileExpiresAt: sourceFileExpiresAt ?? this.sourceFileExpiresAt,
      externalId: externalId ?? this.externalId,
      externalSource: externalSource ?? this.externalSource,
      importBatchId: importBatchId ?? this.importBatchId,
      rawMerchant: rawMerchant ?? this.rawMerchant,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'note': note,
      'date': date.toIso8601String(),
      'accountId': accountId,
      'toAccountId': toAccountId,
      'imageUrl': imageUrl,
      'isSplit': isSplit ? 1 : 0,
      'isReimbursable': isReimbursable ? 1 : 0,
      'isReimbursed': isReimbursed ? 1 : 0,
      'tags': tags?.join(','),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'source': source.index,
      'aiConfidence': aiConfidence,
      'sourceFileLocalPath': sourceFileLocalPath,
      'sourceFileServerUrl': sourceFileServerUrl,
      'sourceFileType': sourceFileType,
      'sourceFileSize': sourceFileSize,
      'recognitionRawData': recognitionRawData,
      'sourceFileExpiresAt': sourceFileExpiresAt?.toIso8601String(),
      'externalId': externalId,
      'externalSource': externalSource?.index,
      'importBatchId': importBatchId,
      'rawMerchant': rawMerchant,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map, {List<TransactionSplit>? splits}) {
    return Transaction(
      id: map['id'],
      type: TransactionType.values[map['type']],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'],
      subcategory: map['subcategory'],
      note: map['note'],
      date: DateTime.parse(map['date']),
      accountId: map['accountId'],
      toAccountId: map['toAccountId'],
      imageUrl: map['imageUrl'],
      isSplit: map['isSplit'] == 1,
      splits: splits,
      isReimbursable: map['isReimbursable'] == 1,
      isReimbursed: map['isReimbursed'] == 1,
      tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      source: map['source'] != null
          ? TransactionSource.values[map['source'] as int]
          : TransactionSource.manual,
      aiConfidence: map['aiConfidence'] != null
          ? (map['aiConfidence'] as num).toDouble()
          : null,
      sourceFileLocalPath: map['sourceFileLocalPath'],
      sourceFileServerUrl: map['sourceFileServerUrl'],
      sourceFileType: map['sourceFileType'],
      sourceFileSize: map['sourceFileSize'] as int?,
      recognitionRawData: map['recognitionRawData'],
      sourceFileExpiresAt: map['sourceFileExpiresAt'] != null
          ? DateTime.parse(map['sourceFileExpiresAt'])
          : null,
      externalId: map['externalId'],
      externalSource: map['externalSource'] != null
          ? ExternalSource.values[map['externalSource'] as int]
          : null,
      importBatchId: map['importBatchId'],
      rawMerchant: map['rawMerchant'],
    );
  }

  /// Check if source file is available (local or server)
  bool get hasSourceFile {
    return sourceFileLocalPath != null || sourceFileServerUrl != null;
  }

  /// Check if source file has expired
  bool get isSourceFileExpired {
    if (sourceFileExpiresAt == null) return false;
    return DateTime.now().isAfter(sourceFileExpiresAt!);
  }

  /// Get the source file path (prefer local, fallback to server URL)
  String? get sourceFilePath {
    return sourceFileLocalPath ?? sourceFileServerUrl;
  }

  /// Check if source is from image recognition
  bool get isFromImage => source == TransactionSource.image;

  /// Check if source is from voice recognition
  bool get isFromVoice => source == TransactionSource.voice;

  /// Check if source is from batch import
  bool get isFromImport => source == TransactionSource.import_;

  /// Get external source display name
  String? get externalSourceName {
    if (externalSource == null) return null;
    switch (externalSource!) {
      case ExternalSource.wechatPay:
        return '微信支付';
      case ExternalSource.alipay:
        return '支付宝';
      case ExternalSource.cmbBank:
        return '招商银行';
      case ExternalSource.icbcBank:
        return '工商银行';
      case ExternalSource.abcBank:
        return '农业银行';
      case ExternalSource.ccbBank:
        return '建设银行';
      case ExternalSource.bocBank:
        return '中国银行';
      case ExternalSource.otherBank:
        return '其他银行';
      case ExternalSource.generic:
        return '通用导入';
    }
  }
}
