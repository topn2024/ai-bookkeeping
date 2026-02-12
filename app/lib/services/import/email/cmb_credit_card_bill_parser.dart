import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../../../models/import_candidate.dart';
import '../../../models/transaction.dart';
import '../bill_parser.dart';
import '../bill_format_detector.dart';
import 'email_imap_service.dart';

/// 招商银行信用卡 HTML 账单解析器
/// 适配招行电子账单邮件的实际 HTML 格式：
/// - 深度嵌套 TABLE 布局
/// - 金额格式：&yen; -0.26 或 &yen; 100.00
/// - 分类区块：还款 / 退款 / 消费
/// - 日期在账单周期头部，非每行单独日期
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
    debugPrint('[CmbParser] parseHtmlBill: htmlBody=${message.htmlBody != null ? "${message.htmlBody!.length}字符" : "null"}, subject="${message.subject}"');
    if (message.htmlBody == null || message.htmlBody!.isEmpty) {
      debugPrint('[CmbParser] htmlBody 为空，跳过');
      return [];
    }
    return _parseHtmlContent(message.htmlBody!, startIndex);
  }

  List<ImportCandidate> _parseHtmlContent(String htmlContent, int startIndex) {
    // 打印前200字符帮助调试 charset 是否正确解码
    final preview = htmlContent.length > 200 ? htmlContent.substring(0, 200) : htmlContent;
    debugPrint('[CmbParser] HTML前200字符: $preview');

    final document = html_parser.parse(htmlContent);
    final candidates = <ImportCandidate>[];

    // 策略1：从 HTML 文本中提取账单周期
    final billPeriod = _extractBillPeriod(document);
    debugPrint('[CmbParser] 账单周期: $billPeriod');

    // 策略2：查找所有包含 ¥ 金额的 FONT/DIV/TD 元素
    // 招行账单用 &yen; 前缀标记金额
    final transactions = _extractTransactionsFromDom(document, billPeriod);
    debugPrint('[CmbParser] 从DOM提取到 ${transactions.length} 笔交易');

    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final candidate = _buildCandidate(t, startIndex + candidates.length);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    debugPrint('[CmbParser] 最终生成 ${candidates.length} 条候选记录');
    return candidates;
  }

  /// 提取账单周期
  String? _extractBillPeriod(Document document) {
    final text = document.body?.text ?? '';
    // 匹配 "2025/12/18-2026/01/17" 格式
    final match = RegExp(r'(\d{4}/\d{2}/\d{2})\s*-\s*(\d{4}/\d{2}/\d{2})').firstMatch(text);
    return match?.group(0);
  }

  /// 从 DOM 树中提取交易记录
  List<_CmbTransaction> _extractTransactionsFromDom(Document document, String? billPeriod) {
    final transactions = <_CmbTransaction>[];

    // 招行账单把交易分为：还款、退款、消费 等区块
    // 每个区块有一个灰色标题行，然后是交易行
    // 交易行结构：多个 TD，其中一个包含商户名，另一个包含 ¥ 金额

    // 遍历所有 FONT 元素寻找金额
    final allFonts = document.querySelectorAll('font');

    String currentSection = '';  // 当前区块类型

    for (final font in allFonts) {
      final text = font.text.replaceAll('\u00A0', ' ').trim();

      // 检测区块标题
      if (text == '还款' || text == '退款' || text == '消费' || text == '预借现金') {
        // 检查是否是粗体标题
        final parent = font.parent;
        if (parent != null && (parent.localName == 'strong' || font.querySelector('strong') != null ||
            parent.querySelector('strong') != null)) {
          currentSection = text;
          continue;
        }
        // 自身是 STRONG 子元素
        if (font.children.any((e) => e.localName == 'strong') || font.innerHtml.contains('<strong>') ||
            font.innerHtml.contains('<STRONG>')) {
          currentSection = text;
          continue;
        }
      }

      // 检测金额：以 ¥ 或包含 yen 实体的文本
      if (text.contains('¥') || text.contains('\u00A5')) {
        final amountMatch = RegExp(r'[¥\u00A5][\s\u00A0]*(-?[\d,]+\.\d{2})').firstMatch(text);
        if (amountMatch != null) {
          final amountStr = amountMatch.group(1)!;
          final amount = double.tryParse(amountStr.replaceAll(',', ''));
          if (amount == null || amount == 0) continue;

          // 在同一行的 TR 中查找商户名
          final merchantName = _findMerchantInRow(font);
          if (merchantName == null || merchantName.isEmpty) continue;

          // 跳过汇总行（本期应还、信用额度等）
          if (_isSummaryRow(merchantName)) continue;

          // 提取交易日期（MMDD格式，在同一TR的前面TD中）
          final txnDate = _findDateInRow(font, billPeriod);

          debugPrint('[CmbParser] 交易: 商户=$merchantName, 金额=$amount, 区块=$currentSection, 日期=$txnDate');
          transactions.add(_CmbTransaction(
            merchant: merchantName,
            amount: amount,
            section: currentSection,
            billPeriod: billPeriod,
            transactionDate: txnDate,
          ));
        }
      }
    }

    return transactions;
  }

  /// 在金额元素所在的 TR 中查找商户名
  String? _findMerchantInRow(Element amountElement) {
    // 向上查找最近的 TR
    Element? tr = amountElement;
    while (tr != null && tr.localName != 'tr') {
      tr = tr.parent;
    }
    if (tr == null) return null;

    // 获取该 TR 中所有 TD 的文本
    final tds = tr.querySelectorAll('td');
    for (final td in tds) {
      final text = td.text.replaceAll('\u00A0', ' ').trim();
      // 跳过空的、纯数字的、含 ¥ 的（那是金额列）
      if (text.isEmpty) continue;
      if (text.contains('¥') || text.contains('\u00A5')) continue;
      if (RegExp(r'^[\d,.\s-]+$').hasMatch(text)) continue;
      // 这应该是商户名/描述
      if (text.length >= 2 && !_isSummaryRow(text)) {
        return text;
      }
    }
    return null;
  }

  /// 从 TR 中提取交易日期（MMDD 格式）
  DateTime? _findDateInRow(Element amountElement, String? billPeriod) {
    Element? tr = amountElement;
    while (tr != null && tr.localName != 'tr') {
      tr = tr.parent;
    }
    if (tr == null) return null;

    // 账单周期用于推断年份
    int year = DateTime.now().year;
    if (billPeriod != null) {
      final startMatch = RegExp(r'(\d{4})/(\d{2})/(\d{2})').firstMatch(billPeriod);
      if (startMatch != null) {
        year = int.parse(startMatch.group(1)!);
      }
    }

    // 查找 4 位数字的 TD（MMDD 格式）
    final tds = tr.querySelectorAll('td');
    for (final td in tds) {
      final text = td.text.replaceAll('\u00A0', ' ').trim();
      final dateMatch = RegExp(r'^(\d{2})(\d{2})$').firstMatch(text);
      if (dateMatch != null) {
        final month = int.parse(dateMatch.group(1)!);
        final day = int.parse(dateMatch.group(2)!);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
    }
    return null;
  }

  /// 判断是否是汇总行（非交易）
  bool _isSummaryRow(String text) {
    final trimmed = text.trim();
    // 精确匹配区块标题（这些单独出现时是标题，不是交易）
    const exactTitles = ['还款', '退款', '消费', '预借现金'];
    if (exactTitles.contains(trimmed)) return true;

    // 包含汇总关键词的行
    const summaryKeywords = [
      '本期应还', '最低还款额', '信用额度', '可用额度',
      '到期日', '账单日', '本期账单', '上期', '积分',
      '取现额度', '合计', '月账单', '尊敬的', '先生', '您好',
    ];
    if (summaryKeywords.any((k) => trimmed.contains(k))) return true;
    // 过滤账单周期格式 "2024/03/18-2024/04/17"
    if (RegExp(r'^\d{4}/\d{2}/\d{2}\s*-\s*\d{4}/\d{2}/\d{2}$').hasMatch(trimmed)) return true;
    // 过滤过短的无意义文本（如 "CN"）
    if (trimmed.length < 3) return true;
    return false;
  }

  ImportCandidate? _buildCandidate(_CmbTransaction t, int index) {
    try {
      // 根据区块类型判断收支
      TransactionType type;
      if (t.section == '还款' || t.section == '退款') {
        type = TransactionType.income; // 还款/退款是收入方向
      } else {
        // 消费区块：负金额是退款，正金额是支出
        if (t.amount < 0) {
          type = TransactionType.income;
        } else {
          type = TransactionType.expense;
        }
      }

      final absAmount = t.amount.abs();
      if (absAmount == 0) return null;

      // 解析日期：优先使用交易行中的日期，否则用账单周期结束日期
      DateTime date = t.transactionDate ?? DateTime.now();
      if (t.transactionDate == null && t.billPeriod != null) {
        final endMatch = RegExp(r'-\s*(\d{4})/(\d{2})/(\d{2})').firstMatch(t.billPeriod!);
        if (endMatch != null) {
          date = DateTime(
            int.parse(endMatch.group(1)!),
            int.parse(endMatch.group(2)!),
            int.parse(endMatch.group(3)!),
          );
        }
      }

      // 推断分类
      final category = inferCategory(t.merchant, null, type);

      return ImportCandidate(
        index: index,
        date: date,
        amount: absAmount,
        type: type,
        rawMerchant: t.merchant,
        category: category,
        rawPaymentMethod: '招商银行信用卡',
      );
    } catch (e) {
      return null;
    }
  }
}

class _CmbTransaction {
  final String merchant;
  final double amount;
  final String section;
  final String? billPeriod;
  final DateTime? transactionDate;

  _CmbTransaction({
    required this.merchant,
    required this.amount,
    required this.section,
    this.billPeriod,
    this.transactionDate,
  });
}
