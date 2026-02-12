import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../../models/import_candidate.dart';
import '../bill_format_detector.dart';
import '../wechat_bill_parser.dart';
import '../alipay_bill_parser.dart';
import 'email_imap_service.dart';

/// 邮件附件提取与路由
/// 支持直接 CSV 附件和 ZIP 压缩包中的 CSV 文件
class EmailAttachmentExtractor {
  final BillFormatDetector _detector;
  final WechatBillParser _wechatParser;
  final AlipayBillParser _alipayParser;

  EmailAttachmentExtractor({
    BillFormatDetector? detector,
    WechatBillParser? wechatParser,
    AlipayBillParser? alipayParser,
  })  : _detector = detector ?? BillFormatDetector(),
        _wechatParser = wechatParser ?? WechatBillParser(),
        _alipayParser = alipayParser ?? AlipayBillParser();

  /// 从邮件消息中提取附件并解析
  Future<List<ImportCandidate>> extractAndParse(
    EmailMessage message,
    int startIndex,
  ) async {
    final candidates = <ImportCandidate>[];

    // 收集所有 CSV 数据（直接 CSV 附件 + ZIP 中的 CSV）
    final csvFiles = <_CsvFile>[];

    for (final attachment in message.attachments) {
      final lowerName = attachment.filename.toLowerCase();
      if (lowerName.endsWith('.csv')) {
        csvFiles.add(_CsvFile(attachment.filename, attachment.data));
      } else if (lowerName.endsWith('.zip')) {
        final extracted = _extractCsvFromZip(attachment.data);
        csvFiles.addAll(extracted);
      }
    }

    for (final csv in csvFiles) {
      try {
        final parsed = await _parseCsvData(csv.data);

        for (final candidate in parsed) {
          candidates.add(candidate.copyWith(
            index: startIndex + candidates.length,
          ));
        }
      } catch (e) {
        debugPrint('[EmailAttachmentExtractor] 解析 ${csv.filename} 失败: $e');
        continue;
      }
    }

    return candidates;
  }

  /// 从 ZIP 压缩包中提取 CSV 文件
  List<_CsvFile> _extractCsvFromZip(Uint8List zipData) {
    final csvFiles = <_CsvFile>[];
    try {
      final archive = ZipDecoder().decodeBytes(zipData);
      for (final file in archive.files) {
        if (file.isFile && file.name.toLowerCase().endsWith('.csv')) {
          final content = file.content as Uint8List;
          csvFiles.add(_CsvFile(file.name, content));
          debugPrint('[EmailAttachmentExtractor] 从ZIP中提取: ${file.name} (${content.length} bytes)');
        }
      }
    } catch (e) {
      debugPrint('[EmailAttachmentExtractor] ZIP解压失败: $e');
    }
    return csvFiles;
  }

  /// 解析 CSV 数据，自动检测来源并路由到对应解析器
  Future<List<ImportCandidate>> _parseCsvData(Uint8List data) async {
    final formatResult = await _detector.detectFromBytes(data, 'csv');

    switch (formatResult.sourceType) {
      case BillSourceType.wechatPay:
        final result = await _wechatParser.parse(data);
        return result.candidates;
      case BillSourceType.alipay:
        final result = await _alipayParser.parse(data);
        return result.candidates;
      default:
        // 尝试两种解析器
        final wechatResult = await _wechatParser.parse(data);
        if (wechatResult.candidates.isNotEmpty) {
          return wechatResult.candidates;
        }
        final alipayResult = await _alipayParser.parse(data);
        return alipayResult.candidates;
    }
  }
}

class _CsvFile {
  final String filename;
  final Uint8List data;
  _CsvFile(this.filename, this.data);
}
