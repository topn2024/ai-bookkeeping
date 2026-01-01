import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import 'bill_format_detector.dart';
import 'bill_parser.dart';

/// Parser for WeChat Pay bill CSV files
class WechatBillParser extends BillParser {
  @override
  BillSourceType get sourceType => BillSourceType.wechatPay;

  @override
  ExternalSource get externalSource => ExternalSource.wechatPay;

  /// WeChat bill column mappings
  static const _columnMappings = {
    '交易时间': 'date',
    '交易类型': 'transactionType',
    '交易对方': 'merchant',
    '商品': 'note',
    '收/支': 'direction',
    '金额(元)': 'amount',
    '支付方式': 'paymentMethod',
    '当前状态': 'status',
    '交易单号': 'externalId',
    '商户单号': 'merchantOrderId',
    '备注': 'remark',
  };

  @override
  Future<BillParseResult> parse(Uint8List bytes) async {
    final candidates = <ImportCandidate>[];
    final errors = <String>[];
    DateTime? dateRangeStart;
    DateTime? dateRangeEnd;
    Map<String, dynamic>? metadata;

    try {
      // Decode content
      String content;
      if (bytes.length > 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        content = utf8.decode(bytes.sublist(3));
      } else {
        content = utf8.decode(bytes);
      }

      // Split into lines
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

      // Extract metadata from header lines
      metadata = _extractMetadata(lines);

      // Find data start line
      int dataStartIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('交易时间') && lines[i].contains('金额')) {
          dataStartIndex = i;
          break;
        }
      }

      if (dataStartIndex == -1) {
        return BillParseResult(
          candidates: [],
          successCount: 0,
          failedCount: 0,
          errors: ['无法找到数据表头'],
        );
      }

      // Parse CSV data
      final dataLines = lines.sublist(dataStartIndex);
      final csv = const CsvToListConverter(shouldParseNumbers: false);
      final rows = csv.convert(dataLines.join('\n'));

      if (rows.isEmpty) {
        return BillParseResult(
          candidates: [],
          successCount: 0,
          failedCount: 0,
          errors: ['没有交易数据'],
        );
      }

      // Build column index map
      final headers = rows[0].map((e) => e.toString().trim()).toList();
      final columnIndex = <String, int>{};
      for (int i = 0; i < headers.length; i++) {
        final mappedName = _columnMappings[headers[i]];
        if (mappedName != null) {
          columnIndex[mappedName] = i;
        }
      }

      // Validate required columns
      if (!columnIndex.containsKey('date') ||
          !columnIndex.containsKey('amount') ||
          !columnIndex.containsKey('direction')) {
        return BillParseResult(
          candidates: [],
          successCount: 0,
          failedCount: 0,
          errors: ['缺少必要的列: 交易时间、金额、收/支'],
        );
      }

      // Parse data rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        try {
          final candidate = _parseRow(row, columnIndex, i - 1);
          if (candidate != null) {
            candidates.add(candidate);

            // Track date range
            if (dateRangeStart == null || candidate.date.isBefore(dateRangeStart)) {
              dateRangeStart = candidate.date;
            }
            if (dateRangeEnd == null || candidate.date.isAfter(dateRangeEnd)) {
              dateRangeEnd = candidate.date;
            }
          }
        } catch (e) {
          errors.add('第 ${i + dataStartIndex + 1} 行解析失败: $e');
        }
      }

      return BillParseResult(
        candidates: candidates,
        successCount: candidates.length,
        failedCount: errors.length,
        errors: errors,
        dateRangeStart: dateRangeStart,
        dateRangeEnd: dateRangeEnd,
        metadata: metadata,
      );
    } catch (e) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 1,
        errors: ['解析失败: $e'],
      );
    }
  }

  Map<String, dynamic>? _extractMetadata(List<String> lines) {
    final metadata = <String, dynamic>{};

    for (final line in lines.take(10)) {
      // Extract nickname
      if (line.contains('微信昵称')) {
        final match = RegExp(r'微信昵称[：:]\s*\[?([^\]\n,]+)').firstMatch(line);
        if (match != null) {
          metadata['nickname'] = match.group(1)?.replaceAll(']', '').trim();
        }
      }

      // Extract date range
      if (line.contains('起始时间') && line.contains('终止时间')) {
        final startMatch = RegExp(r'起始时间[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
        final endMatch = RegExp(r'终止时间[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
        if (startMatch != null && endMatch != null) {
          metadata['startDate'] = startMatch.group(1);
          metadata['endDate'] = endMatch.group(1);
        }
      }
    }

    return metadata.isEmpty ? null : metadata;
  }

  ImportCandidate? _parseRow(List<dynamic> row, Map<String, int> columnIndex, int index) {
    // Get cell value safely
    String? getValue(String key) {
      final idx = columnIndex[key];
      if (idx == null || idx >= row.length) return null;
      final value = row[idx]?.toString().trim();
      return value?.isEmpty == true ? null : value;
    }

    // Parse date
    final dateStr = getValue('date');
    if (dateStr == null) return null;
    final date = parseDate(dateStr);
    if (date == null) return null;

    // Parse amount
    final amountStr = getValue('amount');
    if (amountStr == null) return null;
    final amount = parseAmount(amountStr);
    if (amount <= 0) return null;

    // Determine transaction type
    final direction = getValue('direction') ?? '';
    final status = getValue('status') ?? '';

    // Skip non-completed transactions
    if (status.contains('已退款') ||
        status.contains('退款成功') ||
        status.contains('已全额退款')) {
      return null;
    }

    // Skip transactions that are not income or expense
    TransactionType type;
    if (direction.contains('支出')) {
      type = TransactionType.expense;
    } else if (direction.contains('收入')) {
      type = TransactionType.income;
    } else if (direction == '/') {
      // Transfer or other - treat as expense for now
      type = TransactionType.expense;
    } else {
      // Unknown direction, skip
      return null;
    }

    // Get other fields
    final merchant = getValue('merchant');
    final note = getValue('note') ?? getValue('remark') ?? merchant;
    final externalId = getValue('externalId');
    final paymentMethod = getValue('paymentMethod');
    final transactionType = getValue('transactionType');

    // Infer category
    final category = inferCategory(merchant, note, type);

    return ImportCandidate(
      index: index,
      date: date,
      amount: amount,
      type: type,
      externalId: externalId,
      rawMerchant: merchant,
      note: _buildNote(note, transactionType),
      rawPaymentMethod: paymentMethod,
      rawStatus: status,
      category: category,
      rawData: {
        'merchant': merchant,
        'note': note,
        'transactionType': transactionType,
        'paymentMethod': paymentMethod,
        'status': status,
      },
    );
  }

  String? _buildNote(String? note, String? transactionType) {
    if (note == null && transactionType == null) return null;
    if (note == transactionType) return note;
    if (note != null && transactionType != null) {
      return '$note ($transactionType)';
    }
    return note ?? transactionType;
  }
}
