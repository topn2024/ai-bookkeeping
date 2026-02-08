import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import 'bill_format_detector.dart';
import 'bill_parser.dart';

/// Generic parser for bank bill CSV/Excel files
///
/// Supports common bank statement formats from major Chinese banks:
/// - CMB (招商银行)
/// - ICBC (工商银行)
/// - ABC (农业银行)
/// - CCB (建设银行)
/// - BOC (中国银行)
/// - And other generic formats
class GenericBankParser extends BillParser {
  final BillSourceType _sourceType;

  GenericBankParser({
    BillSourceType sourceType = BillSourceType.generic,
  }) : _sourceType = sourceType;

  @override
  BillSourceType get sourceType => _sourceType;

  @override
  ExternalSource get externalSource {
    // Map source type to external source
    switch (_sourceType) {
      case BillSourceType.cmbBank:
        return ExternalSource.cmbBank;
      case BillSourceType.icbcBank:
        return ExternalSource.icbcBank;
      case BillSourceType.abcBank:
        return ExternalSource.abcBank;
      case BillSourceType.ccbBank:
        return ExternalSource.ccbBank;
      case BillSourceType.bocBank:
        return ExternalSource.bocBank;
      case BillSourceType.otherBank:
        return ExternalSource.otherBank;
      default:
        return ExternalSource.generic;
    }
  }

  /// Common column name mappings for bank statements
  static const _columnMappings = {
    // Date columns
    '交易日期': 'date',
    '记账日期': 'date',
    '交易时间': 'date',
    '日期': 'date',
    '时间': 'date',
    'Date': 'date',
    'Transaction Date': 'date',

    // Amount columns
    '交易金额': 'amount',
    '金额': 'amount',
    '发生额': 'amount',
    '交易金额(元)': 'amount',
    '交易金额（元）': 'amount',
    '金额(元)': 'amount',
    '金额（元）': 'amount',
    'Amount': 'amount',

    // Income/Expense columns
    '收入': 'income',
    '收入金额': 'income',
    '贷方金额': 'income',
    '贷方发生额': 'income',
    '存入': 'income',
    '存入金额': 'income',
    'Credit': 'income',
    '支出': 'expense',
    '支出金额': 'expense',
    '借方金额': 'expense',
    '借方发生额': 'expense',
    '取出': 'expense',
    '支取金额': 'expense',
    'Debit': 'expense',

    // Description columns
    '摘要': 'note',
    '交易摘要': 'note',
    '备注': 'note',
    '交易说明': 'note',
    '用途': 'note',
    '附言': 'note',
    'Description': 'note',
    'Remarks': 'note',

    // Merchant/Counterparty
    '对方户名': 'merchant',
    '交易对方': 'merchant',
    '对方账户': 'merchant',
    '对方账号': 'merchant',
    '收款方': 'merchant',
    '付款方': 'merchant',
    '对方名称': 'merchant',
    'Payee': 'merchant',
    'Counterparty': 'merchant',

    // Transaction ID
    '交易流水号': 'externalId',
    '流水号': 'externalId',
    '交易序号': 'externalId',
    '凭证号': 'externalId',
    '交易单号': 'externalId',
    'Reference': 'externalId',
    'Transaction ID': 'externalId',

    // Balance
    '余额': 'balance',
    '账户余额': 'balance',
    '本次余额': 'balance',
    'Balance': 'balance',

    // Type
    '交易类型': 'transactionType',
    '收支类型': 'direction',
    '收/支': 'direction',
    '收支': 'direction',
    '类型': 'direction',
    'Type': 'direction',
  };

  @override
  Future<BillParseResult> parse(Uint8List bytes) async {
    // Try Excel first, then CSV
    try {
      final excel = Excel.decodeBytes(bytes);
      return _parseExcel(excel);
    } catch (e) {
      // Not Excel, try CSV
      return _parseCSV(bytes);
    }
  }

  Future<BillParseResult> _parseExcel(Excel excel) async {
    final candidates = <ImportCandidate>[];
    final errors = <String>[];
    DateTime? dateRangeStart;
    DateTime? dateRangeEnd;

    // Get the first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 0,
        errors: ['Excel文件为空'],
      );
    }

    // Find header row
    int headerRowIndex = -1;
    List<String> headers = [];
    for (int i = 0; i < sheet.rows.length && i < 10; i++) {
      final row = sheet.rows[i];
      final rowValues = row.map((c) => c?.value?.toString().trim() ?? '').toList();
      if (_isHeaderRow(rowValues)) {
        headerRowIndex = i;
        headers = rowValues;
        break;
      }
    }

    if (headerRowIndex == -1) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 0,
        errors: ['无法识别表头'],
      );
    }

    // Build column index map
    final columnIndex = _buildColumnIndex(headers);

    // Parse data rows
    for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowValues = row.map((c) => c?.value?.toString().trim() ?? '').toList();

      if (rowValues.every((v) => v.isEmpty)) continue;

      final result = _parseRow(i, rowValues, columnIndex);
      if (result.candidate != null) {
        candidates.add(result.candidate!);

        // Track date range
        final date = result.candidate!.date;
        if (dateRangeStart == null || date.isBefore(dateRangeStart)) {
          dateRangeStart = date;
        }
        if (dateRangeEnd == null || date.isAfter(dateRangeEnd)) {
          dateRangeEnd = date;
        }
      }
      if (result.error != null) {
        errors.add(result.error!);
      }
    }

    return BillParseResult(
      candidates: candidates,
      successCount: candidates.length,
      failedCount: errors.length,
      errors: errors,
      dateRangeStart: dateRangeStart,
      dateRangeEnd: dateRangeEnd,
    );
  }

  Future<BillParseResult> _parseCSV(Uint8List bytes) async {
    final candidates = <ImportCandidate>[];
    final errors = <String>[];
    DateTime? dateRangeStart;
    DateTime? dateRangeEnd;

    try {
      // Try multiple encodings
      String content;
      try {
        // Try UTF-8 with BOM
        if (bytes.length > 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF) {
          content = utf8.decode(bytes.sublist(3));
        } else {
          content = utf8.decode(bytes);
        }
      } catch (e) {
        // Fallback to GBK/GB2312 (common for Chinese bank statements)
        content = String.fromCharCodes(bytes);
      }

      // Split into lines
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        return BillParseResult(
          candidates: [],
          successCount: 0,
          failedCount: 0,
          errors: ['CSV文件为空'],
        );
      }

      // Find header row
      int headerRowIndex = -1;
      List<String> headers = [];
      for (int i = 0; i < lines.length && i < 10; i++) {
        final rowValues = _splitCSVLine(lines[i]);
        if (_isHeaderRow(rowValues)) {
          headerRowIndex = i;
          headers = rowValues;
          break;
        }
      }

      if (headerRowIndex == -1) {
        return BillParseResult(
          candidates: [],
          successCount: 0,
          failedCount: 0,
          errors: ['无法识别表头'],
        );
      }

      // Build column index map
      final columnIndex = _buildColumnIndex(headers);

      // Parse data rows
      for (int i = headerRowIndex + 1; i < lines.length; i++) {
        final rowValues = _splitCSVLine(lines[i]);

        if (rowValues.every((v) => v.isEmpty)) continue;

        final result = _parseRow(i, rowValues, columnIndex);
        if (result.candidate != null) {
          candidates.add(result.candidate!);

          // Track date range
          final date = result.candidate!.date;
          if (dateRangeStart == null || date.isBefore(dateRangeStart)) {
            dateRangeStart = date;
          }
          if (dateRangeEnd == null || date.isAfter(dateRangeEnd)) {
            dateRangeEnd = date;
          }
        }
        if (result.error != null) {
          errors.add(result.error!);
        }
      }

      return BillParseResult(
        candidates: candidates,
        successCount: candidates.length,
        failedCount: errors.length,
        errors: errors,
        dateRangeStart: dateRangeStart,
        dateRangeEnd: dateRangeEnd,
      );
    } catch (e) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 1,
        errors: ['解析CSV失败: $e'],
      );
    }
  }

  /// Check if a row looks like a header row
  bool _isHeaderRow(List<String> row) {
    int matchCount = 0;
    for (final value in row) {
      if (_columnMappings.containsKey(value)) {
        matchCount++;
      }
    }
    // At least 2 known columns to be considered a header
    return matchCount >= 2;
  }

  /// Build column index map from headers
  Map<String, int> _buildColumnIndex(List<String> headers) {
    final columnIndex = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].trim();
      final mappedName = _columnMappings[header];
      if (mappedName != null) {
        columnIndex[mappedName] = i;
      }
    }
    debugPrint('[GenericBankParser] Headers found: $headers');
    debugPrint('[GenericBankParser] Column mapping: $columnIndex');
    return columnIndex;
  }

  /// Split a CSV line respecting quoted fields
  List<String> _splitCSVLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if ((char == ',' || char == '\t') && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  /// Parse a single row of data
  _ParseRowResult _parseRow(
    int rowIndex,
    List<String> values,
    Map<String, int> columnIndex,
  ) {
    try {
      // Get date
      final dateIndex = columnIndex['date'];
      if (dateIndex == null || dateIndex >= values.length) {
        return _ParseRowResult(error: '第${rowIndex + 1}行: 缺少日期');
      }
      final date = parseDate(values[dateIndex]);
      if (date == null) {
        return _ParseRowResult(error: '第${rowIndex + 1}行: 无法解析日期 "${values[dateIndex]}"');
      }

      // Determine amount and type
      double amount = 0;
      TransactionType type = TransactionType.expense;

      // Check for separate income/expense columns
      final incomeIndex = columnIndex['income'];
      final expenseIndex = columnIndex['expense'];

      if (incomeIndex != null && expenseIndex != null) {
        // Separate income and expense columns
        final incomeValue = incomeIndex < values.length ? values[incomeIndex] : '';
        final expenseValue = expenseIndex < values.length ? values[expenseIndex] : '';

        final incomeAmount = parseAmount(incomeValue);
        final expenseAmount = parseAmount(expenseValue);

        if (incomeAmount > 0) {
          amount = incomeAmount;
          type = TransactionType.income;
        } else if (expenseAmount > 0) {
          amount = expenseAmount;
          type = TransactionType.expense;
        }
      } else {
        // Single amount column with direction
        final amountIndex = columnIndex['amount'];
        if (amountIndex != null && amountIndex < values.length) {
          final amountStr = values[amountIndex];
          amount = parseAmount(amountStr);

          // Determine type from direction column or amount sign
          final directionIndex = columnIndex['direction'];
          if (directionIndex != null && directionIndex < values.length) {
            final direction = values[directionIndex].toLowerCase();
            if (direction.contains('收') || direction.contains('入') ||
                direction.contains('credit') || direction.contains('存')) {
              type = TransactionType.income;
            } else {
              type = TransactionType.expense;
            }
          } else if (amountStr.startsWith('-') || amountStr.startsWith('−')) {
            type = TransactionType.expense;
          } else if (amountStr.startsWith('+')) {
            type = TransactionType.income;
          }
        }
      }

      if (amount == 0) {
        return _ParseRowResult(error: '第${rowIndex + 1}行: 金额为0，已跳过');
      }

      // Get note/description
      final noteIndex = columnIndex['note'];
      final note = noteIndex != null && noteIndex < values.length
          ? values[noteIndex]
          : null;

      // Get merchant
      final merchantIndex = columnIndex['merchant'];
      final merchant = merchantIndex != null && merchantIndex < values.length
          ? values[merchantIndex]
          : null;

      // Get external ID
      final externalIdIndex = columnIndex['externalId'];
      final externalId = externalIdIndex != null && externalIdIndex < values.length
          ? values[externalIdIndex]
          : null;

      // Validate that we have at least some meaningful data
      if (note == null && merchant == null) {
        debugPrint('[GenericBankParser] Row ${rowIndex + 1}: No description or merchant, skipping');
        return _ParseRowResult(error: '第${rowIndex + 1}行: 缺少描述信息，已跳过');
      }

      // Infer category
      final category = inferCategory(merchant, note, type);

      final candidate = ImportCandidate(
        index: rowIndex - 1,
        date: date,
        amount: amount,
        type: type,
        category: category,
        note: note?.isNotEmpty == true ? note : merchant,
        rawMerchant: merchant,
        externalId: externalId,
      );

      return _ParseRowResult(candidate: candidate);
    } catch (e) {
      return _ParseRowResult(error: '第${rowIndex + 1}行: 解析错误 - $e');
    }
  }
}

class _ParseRowResult {
  final ImportCandidate? candidate;
  final String? error;

  _ParseRowResult({this.candidate, this.error});
}
