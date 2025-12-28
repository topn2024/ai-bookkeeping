import 'transaction_split.dart';

enum TransactionType {
  expense,
  income,
  transfer,
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
    );
  }
}
