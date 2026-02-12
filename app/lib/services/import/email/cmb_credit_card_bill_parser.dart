import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../../../models/import_candidate.dart';
import '../../../models/transaction.dart';
import '../bill_parser.dart';
import '../bill_format_detector.dart';
import 'email_imap_service.dart';

/// 招商银行信用卡 HTML 账单解析器
class CmbCreditCardBillParser extends BillParser {
  @override
  BillSourceType get sourceType => BillSourceType.cmbBank;

  @override
  ExternalSource get externalSource => ExternalSource.cmbBank;

  @override
  Future<BillParseResult> parse(Uint8List bytes) async {
    try {
      final htmlContent = String.fromCharCodes(bytes);
      final candidates = _parseHtmlContent(htmlContent, 0);

      DateTime? dateStart;
      DateTime? dateEnd;
      if (candidates.isNotEmpty) {
        final dates = candidates.map((c) => c.date).toList()..sort();
        dateStart = dates.first;
        dateEnd = dates.last;
      }

      return BillParseResult(
        candidates: candidates,
        successCount: candidates.length,
        failedCount: 0,
        dateRangeStart: dateStart,
        dateRangeEnd: dateEnd,
      );
    } catch (e) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 1,
        errors: ['解析招行信用卡账单失败: $e'],
      );
    }
  }

  /// 从邮件消息中解析 HTML 账单
  Future<List<ImportCandidate>> parseHtmlBill(
    EmailMessage message,
    int startIndex,
  ) async {
    if (message.htmlBody == null || message.htmlBody!.isEmpty) {
      return [];
    }
    return _parseHtmlContent(message.htmlBody!, startIndex);
  }

  List<ImportCandidate> _parseHtmlContent(String htmlContent, int startIndex) {
    final document = html_parser.parse(htmlContent);
    final candidates = <ImportCandidate>[];

    // 查找包含交易明细的表格
    final tables = document.querySelectorAll('table');
    for (final table in tables) {
      final result = _tryParseTable(table, startIndex + candidates.length);
      if (result.isNotEmpty) {
        candidates.addAll(result);
      }
    }

    return candidates;
  }

  List<ImportCandidate> _tryParseTable(Element table, int startIndex) {
    final rows = table.querySelectorAll('tr');
    if (rows.length < 2) return [];

    // 查找表头行
    int headerRowIndex = -1;
    Map<String, int>? columnMap;

    for (int i = 0; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td, th');
      final headerTexts = cells.map((c) => c.text.trim()).toList();
      final map = _detectColumns(headerTexts);
      if (map != null) {
        headerRowIndex = i;
        columnMap = map;
        break;
      }
    }

    if (headerRowIndex < 0 || columnMap == null) return [];

    final candidates = <ImportCandidate>[];

    // 解析数据行
    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td, th');
      final cellTexts = cells.map((c) => c.text.trim()).toList();

      if (cellTexts.length < 3) continue;

      final candidate = _parseRow(cellTexts, columnMap, startIndex + candidates.length);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    return candidates;
  }

  /// 检测列映射
  Map<String, int>? _detectColumns(List<String> headers) {
    final map = <String, int>{};

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].replaceAll(RegExp(r'\s+'), '');

      if (h.contains('交易日') || h.contains('交易日期')) {
        map['transDate'] = i;
      } else if (h.contains('记账日') || h.contains('记账日期')) {
        map['postDate'] = i;
      } else if (h.contains('交易摘要') || h.contains('摘要') || h.contains('交易说明') || h.contains('商户')) {
        map['description'] = i;
      } else if (h.contains('人民币金额') || h.contains('金额') || h.contains('交易金额')) {
        map['amount'] = i;
      } else if (h.contains('卡号') || h.contains('末四位')) {
        map['cardSuffix'] = i;
      }
    }

    // 至少需要日期和金额
    if ((map.containsKey('transDate') || map.containsKey('postDate')) &&
        map.containsKey('amount')) {
      return map;
    }
    return null;
  }

  ImportCandidate? _parseRow(
    List<String> cells,
    Map<String, int> columnMap,
    int index,
  ) {
    try {
      // 解析日期
      String? dateStr;
      if (columnMap.containsKey('transDate') && columnMap['transDate']! < cells.length) {
        dateStr = cells[columnMap['transDate']!];
      } else if (columnMap.containsKey('postDate') && columnMap['postDate']! < cells.length) {
        dateStr = cells[columnMap['postDate']!];
      }

      if (dateStr == null || dateStr.isEmpty) return null;
      final date = _parseCmbDate(dateStr);
      if (date == null) return null;

      // 解析金额
      if (!columnMap.containsKey('amount') || columnMap['amount']! >= cells.length) {
        return null;
      }
      final amountStr = cells[columnMap['amount']!];
      final amount = parseAmount(amountStr);
      if (amount == 0) return null;

      // 正数=支出, 负数=退款/还款(收入)
      final isNegative = amountStr.contains('-') || amountStr.contains('−');
      final type = isNegative ? TransactionType.income : TransactionType.expense;
      final absAmount = amount.abs();

      // 解析描述
      String? description;
      if (columnMap.containsKey('description') && columnMap['description']! < cells.length) {
        description = cells[columnMap['description']!].trim();
      }

      // 推断分类
      final category = inferCategory(description, null, type);

      // 卡号后四位
      String? cardSuffix;
      if (columnMap.containsKey('cardSuffix') && columnMap['cardSuffix']! < cells.length) {
        cardSuffix = cells[columnMap['cardSuffix']!].trim();
      }

      return ImportCandidate(
        index: index,
        date: date,
        amount: absAmount,
        type: type,
        rawMerchant: description,
        note: cardSuffix != null ? '卡号末四位: $cardSuffix' : null,
        category: category,
        rawPaymentMethod: '招商银行信用卡',
      );
    } catch (e) {
      return null;
    }
  }

  /// 解析招行账单日期格式
  /// 常见格式: "01/15", "2024/01/15", "01月15日"
  DateTime? _parseCmbDate(String dateStr) {
    final cleaned = dateStr.trim();

    // "2024/01/15" 或 "2024-01-15"
    final fullMatch = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})').firstMatch(cleaned);
    if (fullMatch != null) {
      return DateTime(
        int.parse(fullMatch.group(1)!),
        int.parse(fullMatch.group(2)!),
        int.parse(fullMatch.group(3)!),
      );
    }

    // "01/15" 格式（短日期，假设当前年份）
    final shortMatch = RegExp(r'^(\d{1,2})[/-](\d{1,2})$').firstMatch(cleaned);
    if (shortMatch != null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        int.parse(shortMatch.group(1)!),
        int.parse(shortMatch.group(2)!),
      );
    }

    // "01月15日" 格式
    final cnMatch = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(cleaned);
    if (cnMatch != null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        int.parse(cnMatch.group(1)!),
        int.parse(cnMatch.group(2)!),
      );
    }

    // 降级到基类方法
    return parseDate(cleaned);
  }
}
