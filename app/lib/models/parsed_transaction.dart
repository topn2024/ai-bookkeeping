import '../models/transaction.dart';

/// AI解析的交易记录
class ParsedTransaction {
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String? merchant;
  final String? note;
  final String? category;
  final String originalSmsBody; // 保留原始短信内容

  ParsedTransaction({
    required this.amount,
    required this.type,
    required this.date,
    this.merchant,
    this.note,
    this.category,
    required this.originalSmsBody,
  });

  factory ParsedTransaction.fromJson(Map<String, dynamic> json, String originalSms) {
    return ParsedTransaction(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      merchant: json['merchant'] as String?,
      note: json['note'] as String?,
      category: json['category'] as String?,
      originalSmsBody: originalSms,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'date': date.toIso8601String(),
      'merchant': merchant,
      'note': note,
      'category': category,
      'originalSmsBody': originalSmsBody,
    };
  }

  @override
  String toString() {
    return 'ParsedTransaction(amount: $amount, type: $type, merchant: $merchant, date: $date)';
  }
}
