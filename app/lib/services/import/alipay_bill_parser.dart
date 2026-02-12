import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import 'bill_format_detector.dart';
import 'bill_parser.dart';

/// Parser for Alipay bill CSV files
class AlipayBillParser extends BillParser {
  @override
  BillSourceType get sourceType => BillSourceType.alipay;

  @override
  ExternalSource get externalSource => ExternalSource.alipay;

  /// Alipay bill column mappings
  static const _columnMappings = {
    '交易创建时间': 'date',
    '交易时间': 'date',
    '付款时间': 'paymentTime',
    '最近修改时间': 'modifiedTime',
    '交易来源地': 'source',
    '类型': 'transactionType',
    '交易对方': 'merchant',
    '商品名称': 'note',
    '金额（元）': 'amount',
    '金额(元)': 'amount',
    '金额': 'amount',  // Without unit
    '收/支': 'direction',
    '收支': 'direction',  // Alternative without slash
    '交易状态': 'status',
    '服务费（元）': 'fee',
    '服务费(元)': 'fee',  // Half-width parentheses
    '成功退款（元）': 'refund',
    '成功退款(元)': 'refund',  // Half-width parentheses
    '备注': 'remark',
    '资金状态': 'fundStatus',
    '交易订单号': 'externalId',
    '商家订单号': 'merchantOrderId',
  };

  @override
  Future<BillParseResult> parse(Uint8List bytes) async {
    final candidates = <ImportCandidate>[];
    final errors = <String>[];
    DateTime? dateRangeStart;
    DateTime? dateRangeEnd;
    Map<String, dynamic>? metadata;

    try {
      // Try different encodings (Alipay typically uses GBK)
      String content;
      // Remove UTF-8 BOM if present
      Uint8List dataBytes = bytes;
      if (bytes.length > 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        dataBytes = bytes.sublist(3);
      }
      try {
        // Try UTF-8 first (strict mode)
        final decoded = utf8.decode(dataBytes, allowMalformed: false);
        // Verify content has expected Chinese characters
        if (decoded.contains('交易') || decoded.contains('支付宝') || decoded.contains('金额')) {
          content = decoded;
        } else {
          // UTF-8 decoded but no Chinese content recognized, try GBK
          content = gbk_bytes.decode(dataBytes);
        }
      } catch (e) {
        // UTF-8 failed, use GBK (Alipay's default encoding)
        try {
          content = gbk_bytes.decode(dataBytes);
        } catch (e2) {
          // Last resort
          content = utf8.decode(dataBytes, allowMalformed: true);
        }
      }

      // Check for BOM
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }

      // Split into lines
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

      // Extract metadata from header lines
      metadata = _extractMetadata(lines);

      // Find data start line
      int dataStartIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if ((lines[i].contains('交易创建时间') || lines[i].contains('交易时间')) &&
            lines[i].contains('金额')) {
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

      debugPrint('[AlipayBillParser] Headers found: $headers');
      debugPrint('[AlipayBillParser] Column mapping: $columnIndex');

      // Validate required columns
      if (!columnIndex.containsKey('date') || !columnIndex.containsKey('amount')) {
        return BillParseResult(
          candidates: [],
          successCount: 0,
          failedCount: 0,
          errors: ['缺少必要的列: 交易时间、金额'],
        );
      }

      // Parse data rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        // Skip footer lines (usually start with special characters)
        final firstCell = row[0]?.toString().trim() ?? '';
        if (firstCell.startsWith('-') ||
            firstCell.startsWith('=') ||
            firstCell.isEmpty) {
          continue;
        }

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

      debugPrint('[AlipayBillParser] Parse complete: ${rows.length - 1} total rows, ${candidates.length} candidates, ${errors.length} errors');

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
      // Extract account
      if (line.contains('账号')) {
        final match = RegExp(r'账号[：:]\s*\[?([^\]\n,]+)').firstMatch(line);
        if (match != null) {
          metadata['account'] = match.group(1)?.replaceAll(']', '').trim();
        }
      }

      // Extract date range
      if (line.contains('起始日期') && line.contains('终止日期')) {
        final startMatch = RegExp(r'起始日期[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
        final endMatch = RegExp(r'终止日期[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
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
    if (dateStr == null) {
      debugPrint('[AlipayBillParser] Row $index skipped: date is null');
      return null;
    }
    final date = parseDate(dateStr);
    if (date == null) {
      debugPrint('[AlipayBillParser] Row $index skipped: date parse failed for "$dateStr"');
      return null;
    }

    // Parse amount
    final amountStr = getValue('amount');
    if (amountStr == null) {
      debugPrint('[AlipayBillParser] Row $index skipped: amount is null');
      return null;
    }
    final amount = parseAmount(amountStr);
    if (amount <= 0) {
      debugPrint('[AlipayBillParser] Row $index skipped: amount <= 0 for "$amountStr" (parsed: $amount)');
      return null;
    }

    // Get status
    final status = getValue('status') ?? '';
    final fundStatus = getValue('fundStatus') ?? '';

    // Skip pending or failed transactions
    if (status.contains('等待') ||
        status.contains('关闭') ||
        status.contains('失败') ||
        fundStatus.contains('未到账')) {
      debugPrint('[AlipayBillParser] Row $index skipped: pending/failed status "$status" / "$fundStatus"');
      return null;
    }

    // Skip refunds (handled separately)
    if (status.contains('退款成功') || status.contains('已退款')) {
      debugPrint('[AlipayBillParser] Row $index skipped: refund status "$status"');
      return null;
    }

    // Determine transaction type
    final direction = getValue('direction') ?? '';
    final transactionType = getValue('transactionType') ?? '';

    TransactionType type;
    if (direction.contains('支出') || direction.contains('-')) {
      type = TransactionType.expense;
    } else if (direction.contains('收入') || direction.contains('+')) {
      type = TransactionType.income;
    } else if (direction.contains('不计收支') || direction == '/' || direction.isEmpty) {
      // Not counted as income/expense - skip
      debugPrint('[AlipayBillParser] Row $index skipped: direction is "$direction" (not counted)');
      return null;
    } else if (transactionType.contains('收入') ||
        transactionType.contains('转入') ||
        transactionType.contains('退款')) {
      type = TransactionType.income;
    } else if (transactionType.contains('支出') ||
        transactionType.contains('转出') ||
        transactionType.contains('付款') ||
        transactionType.contains('消费')) {
      type = TransactionType.expense;
    } else {
      // Default to expense
      type = TransactionType.expense;
    }

    // Get other fields
    final merchant = getValue('merchant');
    final note = getValue('note') ?? getValue('remark') ?? merchant;
    final externalId = getValue('externalId');

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
      rawStatus: status,
      category: category,
      rawData: {
        'merchant': merchant,
        'note': note,
        'transactionType': transactionType,
        'status': status,
        'fundStatus': fundStatus,
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
