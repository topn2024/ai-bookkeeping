import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';

/// 导出格式
enum ExportFormat {
  csv,
  // excel, // 需要额外依赖
}

/// 导出选项
class ExportOptions {
  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionType? typeFilter;
  final String? categoryFilter;
  final ExportFormat format;
  final bool includeHeader;
  final String encoding;

  ExportOptions({
    this.startDate,
    this.endDate,
    this.typeFilter,
    this.categoryFilter,
    this.format = ExportFormat.csv,
    this.includeHeader = true,
    this.encoding = 'utf-8',
  });
}

/// 导出结果
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int recordCount;

  ExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.recordCount = 0,
  });
}

/// 数据导出服务
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// 导出交易数据到CSV
  Future<ExportResult> exportTransactions(
    List<Transaction> transactions,
    ExportOptions options,
  ) async {
    try {
      // 过滤交易
      var filtered = _filterTransactions(transactions, options);

      if (filtered.isEmpty) {
        return ExportResult(
          success: false,
          error: '没有符合条件的记录',
          recordCount: 0,
        );
      }

      // 生成CSV内容
      final csvContent = _generateCSV(filtered, options);

      // 保存文件
      final filePath = await _saveFile(csvContent, options.format);

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: filtered.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  List<Transaction> _filterTransactions(
    List<Transaction> transactions,
    ExportOptions options,
  ) {
    return transactions.where((t) {
      // 日期过滤
      if (options.startDate != null && t.date.isBefore(options.startDate!)) {
        return false;
      }
      if (options.endDate != null && t.date.isAfter(options.endDate!)) {
        return false;
      }

      // 类型过滤
      if (options.typeFilter != null && t.type != options.typeFilter) {
        return false;
      }

      // 分类过滤
      if (options.categoryFilter != null && t.category != options.categoryFilter) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String _generateCSV(List<Transaction> transactions, ExportOptions options) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    // 添加BOM以确保Excel正确识别UTF-8
    buffer.write('\uFEFF');

    // 表头
    if (options.includeHeader) {
      buffer.writeln('日期,类型,分类,金额,账户,备注');
    }

    // 数据行
    for (final t in transactions) {
      final typeName = _getTypeName(t.type);
      final categoryName = _getCategoryName(t.category, t.type);
      final accountName = _getAccountName(t.accountId);
      final note = _escapeCSV(t.note ?? '');
      final amount = t.type == TransactionType.expense
          ? '-${t.amount.toStringAsFixed(2)}'
          : t.amount.toStringAsFixed(2);

      buffer.writeln(
        '${dateFormat.format(t.date)},$typeName,$categoryName,$amount,$accountName,$note',
      );
    }

    return buffer.toString();
  }

  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _getTypeName(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
    }
  }

  String _getCategoryName(String categoryId, TransactionType type) {
    final categories = type == TransactionType.expense
        ? DefaultCategories.expenseCategories
        : DefaultCategories.incomeCategories;

    final category = categories.where((c) => c.id == categoryId).firstOrNull;
    return category?.name ?? categoryId;
  }

  String _getAccountName(String accountId) {
    final account = DefaultAccounts.accounts.where((a) => a.id == accountId).firstOrNull;
    return account?.name ?? accountId;
  }

  Future<String> _saveFile(String content, ExportFormat format) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final extension = format == ExportFormat.csv ? 'csv' : 'xlsx';
    final fileName = 'bookkeeping_export_$timestamp.$extension';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    return filePath;
  }

  /// 生成统计报表CSV
  Future<ExportResult> exportStatistics(
    List<Transaction> transactions,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final filtered = transactions.where((t) {
        return !t.date.isBefore(startDate) && !t.date.isAfter(endDate);
      }).toList();

      if (filtered.isEmpty) {
        return ExportResult(
          success: false,
          error: '没有符合条件的记录',
          recordCount: 0,
        );
      }

      // 按分类汇总
      final categoryStats = <String, double>{};
      for (final t in filtered.where((t) => t.type == TransactionType.expense)) {
        categoryStats[t.category] = (categoryStats[t.category] ?? 0) + t.amount;
      }

      // 生成CSV
      final buffer = StringBuffer();
      buffer.write('\uFEFF');
      buffer.writeln('统计报表');
      buffer.writeln('时间范围,${DateFormat('yyyy-MM-dd').format(startDate)} 至 ${DateFormat('yyyy-MM-dd').format(endDate)}');
      buffer.writeln('');

      // 收支汇总
      final totalIncome = filtered
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final totalExpense = filtered
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount);

      buffer.writeln('收支汇总');
      buffer.writeln('项目,金额');
      buffer.writeln('总收入,${totalIncome.toStringAsFixed(2)}');
      buffer.writeln('总支出,${totalExpense.toStringAsFixed(2)}');
      buffer.writeln('结余,${(totalIncome - totalExpense).toStringAsFixed(2)}');
      buffer.writeln('');

      // 分类支出统计
      buffer.writeln('分类支出统计');
      buffer.writeln('分类,金额,占比');

      final sortedCategories = categoryStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedCategories) {
        final categoryName = _getCategoryName(entry.key, TransactionType.expense);
        final percentage = totalExpense > 0
            ? (entry.value / totalExpense * 100).toStringAsFixed(1)
            : '0.0';
        buffer.writeln('$categoryName,${entry.value.toStringAsFixed(2)},$percentage%');
      }

      // 保存文件
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/bookkeeping_stats_$timestamp.csv';

      final file = File(filePath);
      await file.writeAsString(buffer.toString(), encoding: utf8);

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: filtered.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}
