/// 交易拆分项 - 用于将一笔交易拆分到多个分类
class TransactionSplit {
  final String id;
  final String transactionId; // 关联的主交易ID
  final String category;
  final String? subcategory;
  final double amount;
  final String? note;

  TransactionSplit({
    required this.id,
    required this.transactionId,
    required this.category,
    this.subcategory,
    required this.amount,
    this.note,
  });

  TransactionSplit copyWith({
    String? id,
    String? transactionId,
    String? category,
    String? subcategory,
    double? amount,
    String? note,
  }) {
    return TransactionSplit(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'category': category,
      'subcategory': subcategory,
      'amount': amount,
      'note': note,
    };
  }

  factory TransactionSplit.fromMap(Map<String, dynamic> map) {
    return TransactionSplit(
      id: map['id'] as String,
      transactionId: map['transactionId'] as String,
      category: map['category'] as String,
      subcategory: map['subcategory'] as String?,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}
