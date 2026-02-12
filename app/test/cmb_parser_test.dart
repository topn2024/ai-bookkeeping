import 'dart:io';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;

void main() {
  final html = File('/tmp/cmb_bill.html').readAsStringSync();
  print('HTML length: ${html.length}');
  
  final document = html_parser.parse(html);
  
  // 提取账单周期
  final text = document.body?.text ?? '';
  final periodMatch = RegExp(r'(\d{4}/\d{2}/\d{2})\s*-\s*(\d{4}/\d{2}/\d{2})').firstMatch(text);
  print('Bill period: ${periodMatch?.group(0)}');
  
  // 遍历所有 FONT 元素
  final allFonts = document.querySelectorAll('font');
  print('Total FONT elements: ${allFonts.length}');
  
  String currentSection = '';
  int txnCount = 0;
  int yenFontCount = 0;
  
  for (final font in allFonts) {
    final fontText = font.text.replaceAll('\u00A0', ' ').trim();
    
    // 检测区块标题
    if (fontText == '还款' || fontText == '退款' || fontText == '消费' || fontText == '预借现金') {
      final parent = font.parent;
      if (parent != null && (parent.localName == 'strong' || font.querySelector('strong') != null ||
          parent.querySelector('strong') != null)) {
        currentSection = fontText;
        continue;
      }
      if (font.children.any((e) => e.localName == 'strong') || font.innerHtml.contains('<strong>') ||
          font.innerHtml.contains('<STRONG>')) {
        currentSection = fontText;
        continue;
      }
    }
    
    // 检测金额
    if (fontText.contains('¥') || fontText.contains('\u00A5')) {
      yenFontCount++;
      final amountMatch = RegExp(r'[¥\u00A5][\s\u00A0]*(-?[\d,]+\.\d{2})').firstMatch(fontText);
      if (amountMatch != null) {
        final amountStr = amountMatch.group(1)!;
        final amount = double.tryParse(amountStr.replaceAll(',', ''));
        if (amount == null || amount == 0) continue;
        
        // 找商户名
        var tr = font.parent;
        while (tr != null && tr.localName != 'tr') {
          tr = tr.parent;
        }
        if (tr == null) continue;
        
        String? merchantName;
        final tds = tr.querySelectorAll('td');
        for (final td in tds) {
          final tdText = td.text.replaceAll('\u00A0', ' ').trim();
          if (tdText.isEmpty) continue;
          if (tdText.contains('¥') || tdText.contains('\u00A5')) continue;
          if (RegExp(r'^[\d,.\s-]+$').hasMatch(tdText)) continue;
          if (tdText.length >= 2) {
            // 简化的 isSummaryRow 检查
            const exactTitles = ['还款', '退款', '消费', '预借现金'];
            if (exactTitles.contains(tdText.trim())) continue;
            const summaryKeywords = [
              '本期应还', '最低还款额', '信用额度', '可用额度',
              '到期日', '账单日', '本期账单', '上期', '积分',
              '取现额度', '合计', '月账单', '尊敬的', '先生', '您好',
            ];
            if (summaryKeywords.any((k) => tdText.contains(k))) continue;
            if (RegExp(r'^\d{4}/\d{2}/\d{2}\s*-\s*\d{4}/\d{2}/\d{2}$').hasMatch(tdText.trim())) continue;
            if (tdText.trim().length < 3) continue;
            merchantName = tdText;
            break;
          }
        }
        
        if (merchantName != null) {
          txnCount++;
          if (txnCount <= 10) {
            print('  [$txnCount] [$currentSection] $merchantName -> ¥$amount');
          }
        }
      }
    }
  }
  
  print('\nYen FONT elements: $yenFontCount');
  print('Transactions found: $txnCount');
}
