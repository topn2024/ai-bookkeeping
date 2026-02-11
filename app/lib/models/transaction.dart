import '../services/category_localization_service.dart';
import 'transaction_split.dart';
import 'transaction_location.dart';

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
  sms,          // 短信导入
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

  // === 2.0新增：小金库关联 ===
  final String? vaultId;              // 关联的小金库ID（零基预算系统）

  // === 2.0新增：位置信息 ===
  final TransactionLocation? location; // 交易发生位置信息

  // === 2.0新增：钱龄相关 ===
  final int? moneyAge;                // 该笔消费的钱龄（天数，仅支出有值）
  final String? moneyAgeLevel;        // 钱龄健康等级: health/warning/danger
  final String? resourcePoolId;       // 关联的资源池ID

  // === 2.0新增：可见性控制（家庭账本） ===
  final int visibility;               // 0: private, 1: all_members, 2: admins_only

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
    this.vaultId,
    this.location,
    this.moneyAge,
    this.moneyAgeLevel,
    this.resourcePoolId,
    this.visibility = 1,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 获取拆分项的分类摘要显示
  String get splitCategorySummary {
    if (!isSplit || splits == null || splits!.isEmpty) {
      return category.localizedCategoryName;
    }
    if (splits!.length == 1) {
      return splits!.first.category.localizedCategoryName;
    }
    return '${splits!.first.category.localizedCategoryName} 等${splits!.length}项';
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
    String? vaultId,
    TransactionLocation? location,
    int? moneyAge,
    String? moneyAgeLevel,
    String? resourcePoolId,
    int? visibility,
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
      vaultId: vaultId ?? this.vaultId,
      location: location ?? this.location,
      moneyAge: moneyAge ?? this.moneyAge,
      moneyAgeLevel: moneyAgeLevel ?? this.moneyAgeLevel,
      resourcePoolId: resourcePoolId ?? this.resourcePoolId,
      visibility: visibility ?? this.visibility,
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
      'vaultId': vaultId,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'placeName': location?.placeName,
      'address': location?.address,
      'locationType': location?.locationType?.index,
      'moneyAge': moneyAge,
      'moneyAgeLevel': moneyAgeLevel,
      'resourcePoolId': resourcePoolId,
      'visibility': visibility,
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
      vaultId: map['vaultId'],
      location: map['latitude'] != null && map['longitude'] != null
          ? TransactionLocation(
              latitude: (map['latitude'] as num).toDouble(),
              longitude: (map['longitude'] as num).toDouble(),
              placeName: map['placeName'],
              address: map['address'],
              locationType: map['locationType'] != null
                  ? LocationType.values[map['locationType'] as int]
                  : null,
            )
          : null,
      moneyAge: map['moneyAge'] as int?,
      moneyAgeLevel: map['moneyAgeLevel'] as String?,
      resourcePoolId: map['resourcePoolId'] as String?,
      visibility: map['visibility'] as int? ?? 1,
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
      case ExternalSource.sms:
        return '短信导入';
    }
  }

  // === 2.0新增辅助方法 ===

  /// 是否关联了小金库
  bool get hasVault => vaultId != null;

  /// 是否有位置信息
  bool get hasLocation => location != null;

  /// 是否有钱龄信息
  bool get hasMoneyAge => moneyAge != null;

  /// 是否为支出类型
  bool get isExpense => type == TransactionType.expense;

  /// 是否为收入类型
  bool get isIncome => type == TransactionType.income;

  /// 是否为转账类型
  bool get isTransfer => type == TransactionType.transfer;

  // === 兼容性别名 ===

  /// 分类ID（category的别名）
  String get categoryId => category;

  /// 分类名称（category的别名）
  String get categoryName => category;

  /// 描述（note的别名）
  String? get description => note;

  /// 商户名称（从note中提取或返回null）
  String? get merchantName => null;

  /// 位置信息（location的别名）
  TransactionLocation? get locationInfo => location;
}
