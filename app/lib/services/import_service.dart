import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../utils/amount_validator.dart';

/// @deprecated Use [BatchImportService] from 'import/batch_import_service.dart' instead.
/// This service is kept for backward compatibility but will be removed in a future version.
///
/// 导入结果
class ImportResult {
  final bool success;
  final String? error;
  final int totalRows;
  final int successCount;
  final int failedCount;
  final List<String> errors;
  final List<Transaction> transactions;

  ImportResult({
    required this.success,
    this.error,
    this.totalRows = 0,
    this.successCount = 0,
    this.failedCount = 0,
    this.errors = const [],
    this.transactions = const [],
  });
}

/// 导入预览项
class ImportPreviewItem {
  final int rowNumber;
  final DateTime? date;
  final TransactionType? type;
  final String? category;
  final double? amount;
  final String? account;
  final String? note;
  final bool isValid;
  final String? error;

  ImportPreviewItem({
    required this.rowNumber,
    this.date,
    this.type,
    this.category,
    this.amount,
    this.account,
    this.note,
    required this.isValid,
    this.error,
  });
}

/// 数据导入服务
class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  final _uuid = const Uuid();

  /// 解析CSV文件并预览
  Future<List<ImportPreviewItem>> previewCSV(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString(encoding: utf8);
    return _parseCSV(content);
  }

  /// 解析CSV内容
  List<ImportPreviewItem> _parseCSV(String content) {
    final lines = const LineSplitter().convert(content);
    final items = <ImportPreviewItem>[];

    // 跳过BOM和空行
    int startIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 移除BOM
      final cleanLine = line.startsWith('\uFEFF') ? line.substring(1) : line;

      // 检测是否为表头
      if (_isHeaderRow(cleanLine)) {
        startIndex = i + 1;
        break;
      }
      startIndex = i;
      break;
    }

    // 检查是否第一行是表头
    if (startIndex < lines.length) {
      final firstLine = lines[startIndex].trim();
      final cleanFirst = firstLine.startsWith('\uFEFF') ? firstLine.substring(1) : firstLine;
      if (_isHeaderRow(cleanFirst)) {
        startIndex++;
      }
    }

    // 解析数据行
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final item = _parseRow(i + 1, line);
      items.add(item);
    }

    return items;
  }

  bool _isHeaderRow(String line) {
    final lower = line.toLowerCase();
    return lower.contains('日期') ||
           lower.contains('date') ||
           lower.contains('类型') ||
           lower.contains('type');
  }

  ImportPreviewItem _parseRow(int rowNumber, String line) {
    try {
      final fields = _splitCSVLine(line);

      if (fields.length < 4) {
        return ImportPreviewItem(
          rowNumber: rowNumber,
          isValid: false,
          error: '列数不足，至少需要4列（日期、类型、分类、金额）',
        );
      }

      // 解析日期
      final date = _parseDate(fields[0]);
      if (date == null) {
        return ImportPreviewItem(
          rowNumber: rowNumber,
          isValid: false,
          error: '无法解析日期: ${fields[0]}',
        );
      }

      // 解析类型
      final type = _parseType(fields[1]);
      if (type == null) {
        return ImportPreviewItem(
          rowNumber: rowNumber,
          isValid: false,
          error: '无法识别类型: ${fields[1]}',
        );
      }

      // 解析分类
      final category = fields[2].trim();

      // 解析金额
      final amount = _parseAmount(fields[3]);
      if (amount == null || amount == 0) {
        return ImportPreviewItem(
          rowNumber: rowNumber,
          isValid: false,
          error: '无法解析金额: ${fields[3]}',
        );
      }

      // 解析账户（可选）
      final account = fields.length > 4 ? fields[4].trim() : null;

      // 解析备注（可选）
      final note = fields.length > 5 ? fields[5].trim() : null;

      return ImportPreviewItem(
        rowNumber: rowNumber,
        date: date,
        type: type,
        category: category,
        amount: amount.abs(),
        account: account,
        note: note,
        isValid: true,
      );
    } catch (e) {
      return ImportPreviewItem(
        rowNumber: rowNumber,
        isValid: false,
        error: '解析错误: $e',
      );
    }
  }

  List<String> _splitCSVLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // 跳过转义的引号
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString().trim());

    return fields;
  }

  DateTime? _parseDate(String value) {
    final cleanValue = value.trim();

    // 尝试多种日期格式
    final formats = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy/MM/dd HH:mm',
      'yyyy/MM/dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(cleanValue);
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  TransactionType? _parseType(String value) {
    final cleanValue = value.trim().toLowerCase();

    if (cleanValue == '支出' || cleanValue == 'expense') {
      return TransactionType.expense;
    } else if (cleanValue == '收入' || cleanValue == 'income') {
      return TransactionType.income;
    } else if (cleanValue == '转账' || cleanValue == 'transfer') {
      return TransactionType.transfer;
    }

    return null;
  }

  double? _parseAmount(String value) {
    final cleanValue = value.trim()
        .replaceAll(',', '')
        .replaceAll('¥', '')
        .replaceAll('\$', '')
        .replaceAll(' ', '');

    final amount = double.tryParse(cleanValue);
    if (amount == null || amount.isNaN || amount.isInfinite) return null;

    // 验证金额范围，防止导入异常值
    if (amount > AmountValidator.maxAmount) {
      return null; // 超出范围的金额视为无效
    }

    return amount;
  }

  /// 将预览项转换为交易记录
  List<Transaction> convertToTransactions(List<ImportPreviewItem> items) {
    final transactions = <Transaction>[];

    for (final item in items) {
      if (!item.isValid) continue;

      // 查找或创建分类ID
      final categoryId = _findCategoryId(item.category!, item.type!);

      // 查找或使用默认账户ID
      final accountId = _findAccountId(item.account);

      final transaction = Transaction(
        id: _uuid.v4(),
        type: item.type!,
        amount: item.amount!,
        category: categoryId,
        accountId: accountId,
        date: item.date!,
        note: item.note,
      );

      transactions.add(transaction);
    }

    return transactions;
  }

  String _findCategoryId(String categoryName, TransactionType type) {
    final categories = type == TransactionType.expense
        ? DefaultCategories.expenseCategories
        : DefaultCategories.incomeCategories;

    // 尝试按名称匹配
    final matched = categories.where(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
    ).firstOrNull;

    if (matched != null) {
      return matched.id;
    }

    // 使用默认分类
    if (type == TransactionType.expense) {
      return 'other_expense';
    } else if (type == TransactionType.income) {
      return 'other_income';
    }

    return 'other';
  }

  String _findAccountId(String? accountName) {
    if (accountName == null || accountName.isEmpty) {
      return 'cash'; // 默认现金账户
    }

    // 尝试按名称匹配
    final matched = DefaultAccounts.accounts.where(
      (a) => a.name.toLowerCase() == accountName.toLowerCase(),
    ).firstOrNull;

    if (matched != null) {
      return matched.id;
    }

    // 返回默认账户
    return 'cash';
  }

  /// 导入交易记录
  Future<ImportResult> importTransactions(String filePath) async {
    try {
      final previews = await previewCSV(filePath);

      if (previews.isEmpty) {
        return ImportResult(
          success: false,
          error: '文件为空或格式不正确',
        );
      }

      final validItems = previews.where((p) => p.isValid).toList();
      final invalidItems = previews.where((p) => !p.isValid).toList();

      if (validItems.isEmpty) {
        return ImportResult(
          success: false,
          error: '没有有效的记录可导入',
          totalRows: previews.length,
          failedCount: invalidItems.length,
          errors: invalidItems.map((i) => '第${i.rowNumber}行: ${i.error}').toList(),
        );
      }

      final transactions = convertToTransactions(validItems);

      return ImportResult(
        success: true,
        totalRows: previews.length,
        successCount: validItems.length,
        failedCount: invalidItems.length,
        errors: invalidItems.map((i) => '第${i.rowNumber}行: ${i.error}').toList(),
        transactions: transactions,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        error: '导入失败: $e',
      );
    }
  }
}
