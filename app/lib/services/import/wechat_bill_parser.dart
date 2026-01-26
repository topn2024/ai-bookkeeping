import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import 'bill_format_detector.dart';
import 'bill_parser.dart';

/// Parser for WeChat Pay bill files (CSV and Excel formats)
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
    '收支': 'direction',  // Alternative without slash
    '金额(元)': 'amount',
    '金额（元）': 'amount',  // Full-width parentheses
    '金额': 'amount',  // Without unit
    '支付方式': 'paymentMethod',
    '当前状态': 'status',
    '交易状态': 'status',  // Alternative name
    '交易单号': 'externalId',
    '商户单号': 'merchantOrderId',
    '备注': 'remark',
  };

  @override
  Future<BillParseResult> parse(Uint8List bytes) async {
    // Try Excel first, then CSV
    try {
      debugPrint('[WechatBillParser] Attempting to parse as Excel');
      final excel = Excel.decodeBytes(bytes);
      debugPrint('[WechatBillParser] Successfully decoded as Excel format');
      return _parseExcel(excel);
    } catch (e) {
      debugPrint('[WechatBillParser] Not Excel format, trying CSV: $e');
      // Not Excel, try CSV
      return _parseCSV(bytes);
    }
  }

  /// Parse Excel format WeChat bill
  Future<BillParseResult> _parseExcel(Excel excel) async {
    final candidates = <ImportCandidate>[];
    final errors = <String>[];
    DateTime? dateRangeStart;
    DateTime? dateRangeEnd;
    Map<String, dynamic>? metadata;

    try {
      debugPrint('[WechatBillParser] Parsing Excel file');

      // Find the first sheet
      if (excel.tables.isEmpty) {
        return BillParseResult(
          candidates: [],
          successCount: 0,
          failedCount: 0,
          errors: ['Excel文件中没有工作表'],
        );
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      debugPrint('[WechatBillParser] Found sheet: $sheetName with ${sheet.rows.length} rows');

      // Convert Excel rows to list of strings for metadata extraction
      final lines = <String>[];
      for (final row in sheet.rows) {
        final line = row.map((cell) => cell?.value?.toString() ?? '').join(',');
        if (line.trim().isNotEmpty) {
          lines.add(line);
        }
      }

      // Extract metadata from header lines
      metadata = _extractMetadata(lines);

      // Find data start line
      int dataStartIndex = -1;
      for (int i = 0; i < sheet.rows.length && i < 20; i++) {
        final row = sheet.rows[i];
        final rowStr = row.map((c) => c?.value?.toString() ?? '').join(',');
        if (rowStr.contains('交易时间') && rowStr.contains('金额')) {
          dataStartIndex = i;
          debugPrint('[WechatBillParser] Found header at row $i');
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

      // Build column index map from header row
      final headerRow = sheet.rows[dataStartIndex];
      final headers = headerRow.map((c) => c?.value?.toString().trim() ?? '').toList();
      final columnIndex = <String, int>{};
      for (int i = 0; i < headers.length; i++) {
        final mappedName = _columnMappings[headers[i]];
        if (mappedName != null) {
          columnIndex[mappedName] = i;
        }
      }

      debugPrint('[WechatBillParser] Headers found: $headers');
      debugPrint('[WechatBillParser] Column mapping: $columnIndex');

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
      for (int i = dataStartIndex + 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final rowValues = row.map((c) => c?.value?.toString().trim() ?? '').toList();

        if (rowValues.every((v) => v.isEmpty)) continue;

        try {
          final candidate = _parseRow(rowValues, columnIndex, i - dataStartIndex - 1);
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
          errors.add('第 ${i + 1} 行解析失败: $e');
        }
      }

      debugPrint('[WechatBillParser] Excel parse complete: ${sheet.rows.length - dataStartIndex - 1} total rows, ${candidates.length} candidates, ${errors.length} errors');

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
      debugPrint('[WechatBillParser] Excel parse error: $e');
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 1,
        errors: ['解析Excel文件失败: $e'],
      );
    }
  }

  /// Parse CSV format WeChat bill
  Future<BillParseResult> _parseCSV(Uint8List bytes) async {
    final candidates = <ImportCandidate>[];
    final errors = <String>[];
    DateTime? dateRangeStart;
    DateTime? dateRangeEnd;
    Map<String, dynamic>? metadata;

    try {
      // Decode content with encoding detection
      String content = _decodeContent(bytes);

      // Normalize line endings (handle both \r\n and \n)
      content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

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

      debugPrint('[WechatBillParser] Headers found: $headers');
      debugPrint('[WechatBillParser] Column mapping: $columnIndex');

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

      debugPrint('[WechatBillParser] Parse complete: ${rows.length - 1} total rows, ${candidates.length} candidates, ${errors.length} errors');

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
    if (dateStr == null) {
      debugPrint('[WechatBillParser] Row $index skipped: date is null');
      return null;
    }
    final date = parseDate(dateStr);
    if (date == null) {
      debugPrint('[WechatBillParser] Row $index skipped: date parse failed for "$dateStr"');
      return null;
    }

    // Parse amount
    final amountStr = getValue('amount');
    if (amountStr == null) {
      debugPrint('[WechatBillParser] Row $index skipped: amount is null');
      return null;
    }
    final amount = parseAmount(amountStr);
    if (amount <= 0) {
      debugPrint('[WechatBillParser] Row $index skipped: amount <= 0 for "$amountStr" (parsed: $amount)');
      return null;
    }

    // Determine transaction type
    final direction = getValue('direction') ?? '';
    final status = getValue('status') ?? '';

    // Skip non-completed transactions
    if (status.contains('已退款') ||
        status.contains('退款成功') ||
        status.contains('已全额退款')) {
      debugPrint('[WechatBillParser] Row $index skipped: refund status "$status"');
      return null;
    }

    // Skip transactions that are not income or expense
    TransactionType type;
    if (direction.contains('支出')) {
      type = TransactionType.expense;
    } else if (direction.contains('收入')) {
      type = TransactionType.income;
    } else if (direction == '/' || direction.contains('不计收支') || direction.isEmpty) {
      // Transfer or not counted - skip these
      debugPrint('[WechatBillParser] Row $index skipped: direction is "$direction" (transfer/not counted)');
      return null;
    } else {
      // Unknown direction, skip
      debugPrint('[WechatBillParser] Row $index skipped: unknown direction "$direction"');
      return null;
    }

    // Get other fields
    final merchant = getValue('merchant');
    final note = getValue('note');
    final remark = getValue('remark');
    final externalId = getValue('externalId');
    final paymentMethod = getValue('paymentMethod');
    final transactionType = getValue('transactionType');

    // Infer category - 组合所有字段（商户、商品、备注、交易类型）以便更准确匹配
    final classificationText = _buildClassificationText(merchant, note, remark, transactionType);
    final category = inferCategory(merchant, classificationText, type);

    // 显示用的备注：优先使用商品，其次备注，最后商户
    final displayNote = note ?? remark ?? merchant;

    return ImportCandidate(
      index: index,
      date: date,
      amount: amount,
      type: type,
      externalId: externalId,
      rawMerchant: merchant,
      note: _buildDisplayNote(displayNote, transactionType),
      rawPaymentMethod: paymentMethod,
      rawStatus: status,
      category: category,
      rawData: {
        'merchant': merchant,
        'note': note,
        'remark': remark,
        'transactionType': transactionType,
        'paymentMethod': paymentMethod,
        'status': status,
      },
    );
  }

  /// 组合所有字段用于分类匹配
  /// 包含：商户、商品、备注、交易类型
  String? _buildClassificationText(String? merchant, String? note, String? remark, String? transactionType) {
    final parts = <String>[];
    if (merchant != null && merchant.isNotEmpty && merchant != '/') {
      parts.add(merchant);
    }
    if (note != null && note.isNotEmpty && note != '/') {
      parts.add(note);
    }
    if (remark != null && remark.isNotEmpty && remark != '/' && remark != note) {
      parts.add(remark);
    }
    if (transactionType != null && transactionType.isNotEmpty && transactionType != '/' && transactionType != note) {
      parts.add(transactionType);
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// 构建显示用的备注
  String? _buildDisplayNote(String? note, String? transactionType) {
    if (note == null && transactionType == null) return null;
    if (note == transactionType) return note;
    if (note != null && transactionType != null) {
      return '$note ($transactionType)';
    }
    return note ?? transactionType;
  }

  /// Decode content with encoding detection (UTF-8 or GBK)
  String _decodeContent(Uint8List bytes) {
    // Remove UTF-8 BOM if present
    Uint8List dataBytes = bytes;
    if (bytes.length > 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      dataBytes = bytes.sublist(3);
      debugPrint('[WechatBillParser] Removed UTF-8 BOM');
    }

    // Try UTF-8 first (strict mode)
    try {
      final content = utf8.decode(dataBytes, allowMalformed: false);
      // Verify the content contains expected Chinese characters
      if (content.contains('交易时间') || content.contains('微信') || content.contains('金额')) {
        debugPrint('[WechatBillParser] Successfully decoded as UTF-8');
        return content;
      }
    } catch (e) {
      debugPrint('[WechatBillParser] UTF-8 decode failed: $e');
    }

    // Try GBK encoding (common for WeChat bills exported on Windows)
    try {
      final content = gbk_bytes.decode(dataBytes);
      if (content.contains('交易时间') || content.contains('微信') || content.contains('金额')) {
        debugPrint('[WechatBillParser] Successfully decoded as GBK');
        return content;
      }
    } catch (e) {
      debugPrint('[WechatBillParser] GBK decode failed: $e');
    }

    // Fallback: UTF-8 with malformed bytes allowed
    debugPrint('[WechatBillParser] Falling back to UTF-8 with allowMalformed');
    return utf8.decode(dataBytes, allowMalformed: true);
  }
}
