import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../models/transaction.dart';

/// Supported bill file formats
enum BillFileFormat {
  csv,
  excel,
  ofx,
  qif,
  tsv,
  json,
  unknown,
}

/// Detected bill source type
enum BillSourceType {
  wechatPay,
  alipay,
  cmbBank,
  icbcBank,
  abcBank,
  ccbBank,
  bocBank,
  otherBank,
  generic,
  unknown,
}

/// Result of bill format detection
class BillFormatResult {
  final BillFileFormat format;
  final BillSourceType sourceType;
  final String? encoding;
  final String? dateRange;
  final int? estimatedRecordCount;
  final List<String>? headers;
  final List<List<dynamic>>? previewRows;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  BillFormatResult({
    required this.format,
    required this.sourceType,
    this.encoding,
    this.dateRange,
    this.estimatedRecordCount,
    this.headers,
    this.previewRows,
    this.errorMessage,
    this.metadata,
  });

  bool get isSuccess => errorMessage == null;
  bool get isRecognized => sourceType != BillSourceType.unknown;

  /// 识别置信度 (0.0-1.0)
  double get confidence {
    if (!isSuccess) return 0.0;
    if (!isRecognized) return 0.0;
    // 基础置信度
    var score = 0.5;
    // 有头部信息加分
    if (headers != null && headers!.isNotEmpty) score += 0.2;
    // 有预览行加分
    if (previewRows != null && previewRows!.isNotEmpty) score += 0.2;
    // 有日期范围加分
    if (dateRange != null) score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  /// Alias for estimatedRecordCount
  int? get recordCount => estimatedRecordCount;

  /// Get display name for the file format
  String get formatName {
    switch (format) {
      case BillFileFormat.csv:
        return 'CSV';
      case BillFileFormat.excel:
        return 'Excel';
      case BillFileFormat.ofx:
        return 'OFX';
      case BillFileFormat.qif:
        return 'QIF';
      case BillFileFormat.tsv:
        return 'TSV';
      case BillFileFormat.json:
        return 'JSON';
      case BillFileFormat.unknown:
        return '未知';
    }
  }

  /// Get external source from bill source type
  ExternalSource? get externalSource {
    switch (sourceType) {
      case BillSourceType.wechatPay:
        return ExternalSource.wechatPay;
      case BillSourceType.alipay:
        return ExternalSource.alipay;
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
      case BillSourceType.generic:
        return ExternalSource.generic;
      case BillSourceType.unknown:
        return null;
    }
  }

  /// Get display name for the source type
  String get sourceTypeName {
    switch (sourceType) {
      case BillSourceType.wechatPay:
        return '微信支付账单';
      case BillSourceType.alipay:
        return '支付宝账单';
      case BillSourceType.cmbBank:
        return '招商银行流水';
      case BillSourceType.icbcBank:
        return '工商银行流水';
      case BillSourceType.abcBank:
        return '农业银行流水';
      case BillSourceType.ccbBank:
        return '建设银行流水';
      case BillSourceType.bocBank:
        return '中国银行流水';
      case BillSourceType.otherBank:
        return '银行流水';
      case BillSourceType.generic:
        return '通用表格';
      case BillSourceType.unknown:
        return '未知格式';
    }
  }

  /// Get format file type ID for storage
  String get formatId {
    switch (sourceType) {
      case BillSourceType.wechatPay:
        return 'wechat_pay';
      case BillSourceType.alipay:
        return 'alipay';
      case BillSourceType.cmbBank:
        return 'cmb_bank';
      case BillSourceType.icbcBank:
        return 'icbc_bank';
      case BillSourceType.abcBank:
        return 'abc_bank';
      case BillSourceType.ccbBank:
        return 'ccb_bank';
      case BillSourceType.bocBank:
        return 'boc_bank';
      case BillSourceType.otherBank:
        return 'other_bank';
      case BillSourceType.generic:
        return 'generic';
      case BillSourceType.unknown:
        return 'unknown';
    }
  }
}

/// Service to detect bill file format and source
class BillFormatDetector {
  /// Detect format from file path
  Future<BillFormatResult> detectFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return BillFormatResult(
        format: BillFileFormat.unknown,
        sourceType: BillSourceType.unknown,
        errorMessage: '文件不存在',
      );
    }

    final bytes = await file.readAsBytes();
    final extension = filePath.toLowerCase().split('.').last;

    return detectFromBytes(bytes, extension);
  }

  /// Detect format from bytes and file extension
  Future<BillFormatResult> detectFromBytes(
    Uint8List bytes,
    String extension,
  ) async {
    try {
      // Determine file format from extension
      final format = _getFormatFromExtension(extension);

      switch (format) {
        case BillFileFormat.csv:
        case BillFileFormat.tsv:
          return await _detectCsvFormat(bytes, format);
        case BillFileFormat.excel:
          return await _detectExcelFormat(bytes);
        case BillFileFormat.ofx:
          return _detectOfxFormat(bytes);
        case BillFileFormat.qif:
          return _detectQifFormat(bytes);
        case BillFileFormat.json:
          return _detectJsonFormat(bytes);
        case BillFileFormat.unknown:
          return BillFormatResult(
            format: BillFileFormat.unknown,
            sourceType: BillSourceType.unknown,
            errorMessage: '不支持的文件格式: .$extension',
          );
      }
    } catch (e) {
      return BillFormatResult(
        format: BillFileFormat.unknown,
        sourceType: BillSourceType.unknown,
        errorMessage: '解析文件失败: $e',
      );
    }
  }

  BillFileFormat _getFormatFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'csv':
        return BillFileFormat.csv;
      case 'xlsx':
      case 'xls':
        return BillFileFormat.excel;
      case 'ofx':
        return BillFileFormat.ofx;
      case 'qif':
        return BillFileFormat.qif;
      case 'tsv':
        return BillFileFormat.tsv;
      case 'json':
        return BillFileFormat.json;
      default:
        return BillFileFormat.unknown;
    }
  }

  /// Detect CSV format and source type
  Future<BillFormatResult> _detectCsvFormat(
    Uint8List bytes,
    BillFileFormat format,
  ) async {
    // Try different encodings
    String? content;
    String? encoding;

    // Try UTF-8 with BOM first (WeChat uses this)
    if (bytes.length > 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      try {
        content = utf8.decode(bytes.sublist(3));
        encoding = 'UTF-8-BOM';
      } catch (e) {
        // Continue to try other encodings
      }
    }

    // Try UTF-8
    if (content == null) {
      try {
        content = utf8.decode(bytes);
        encoding = 'UTF-8';
      } catch (e) {
        // Continue to try GBK/GB2312
      }
    }

    // Try GBK/GB2312 (Alipay uses this)
    if (content == null) {
      try {
        // Simple GBK decode - in real app would use a proper GBK decoder
        content = _decodeGbk(bytes);
        encoding = 'GBK';
      } catch (e) {
        return BillFormatResult(
          format: format,
          sourceType: BillSourceType.unknown,
          errorMessage: '无法识别文件编码',
        );
      }
    }

    if (content.isEmpty) {
      return BillFormatResult(
        format: format,
        sourceType: BillSourceType.unknown,
        errorMessage: '文件内容为空',
      );
    }

    // Parse CSV
    final delimiter = format == BillFileFormat.tsv ? '\t' : ',';
    final converter = CsvToListConverter(
      fieldDelimiter: delimiter,
      shouldParseNumbers: false,
      eol: '\n',
    );

    // Split lines and filter empty ones
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Detect source type from content
    final sourceType = _detectCsvSourceType(lines);

    // Find data header line
    final headerInfo = _findDataHeaders(lines, sourceType);

    List<List<dynamic>>? rows;
    List<String>? headers;
    int? recordCount;
    String? dateRange;
    Map<String, dynamic>? metadata;

    if (headerInfo != null) {
      final dataLines = lines.sublist(headerInfo['headerIndex'] as int);
      if (dataLines.isNotEmpty) {
        rows = converter.convert(dataLines.join('\n'));
        if (rows.isNotEmpty) {
          headers = rows[0].map((e) => e.toString().trim()).toList();
          recordCount = rows.length - 1; // Exclude header row

          // Get preview rows (max 5)
          final previewRows =
              rows.length > 6 ? rows.sublist(1, 6) : rows.sublist(1);

          // Extract date range from metadata lines
          dateRange = _extractDateRange(lines, sourceType);

          // Extract metadata
          metadata = _extractMetadata(lines, sourceType);

          return BillFormatResult(
            format: format,
            sourceType: sourceType,
            encoding: encoding,
            dateRange: dateRange,
            estimatedRecordCount: recordCount,
            headers: headers,
            previewRows: previewRows,
            metadata: metadata,
          );
        }
      }
    }

    return BillFormatResult(
      format: format,
      sourceType: sourceType,
      encoding: encoding,
      errorMessage: '无法解析CSV数据',
    );
  }

  /// Detect source type from CSV lines
  BillSourceType _detectCsvSourceType(List<String> lines) {
    final firstLines = lines.take(10).join('\n').toLowerCase();

    // WeChat Pay detection
    if (firstLines.contains('微信支付') ||
        firstLines.contains('wechat') ||
        firstLines.contains('微信昵称')) {
      return BillSourceType.wechatPay;
    }

    // Alipay detection
    if (firstLines.contains('支付宝') ||
        firstLines.contains('alipay') ||
        firstLines.contains('交易记录明细')) {
      return BillSourceType.alipay;
    }

    // China Merchants Bank
    if (firstLines.contains('招商银行') ||
        firstLines.contains('cmb') ||
        firstLines.contains('招行')) {
      return BillSourceType.cmbBank;
    }

    // ICBC
    if (firstLines.contains('工商银行') ||
        firstLines.contains('icbc') ||
        firstLines.contains('工行')) {
      return BillSourceType.icbcBank;
    }

    // ABC
    if (firstLines.contains('农业银行') ||
        firstLines.contains('abc') ||
        firstLines.contains('农行')) {
      return BillSourceType.abcBank;
    }

    // CCB
    if (firstLines.contains('建设银行') ||
        firstLines.contains('ccb') ||
        firstLines.contains('建行')) {
      return BillSourceType.ccbBank;
    }

    // BOC
    if (firstLines.contains('中国银行') ||
        firstLines.contains('boc') ||
        firstLines.contains('中行')) {
      return BillSourceType.bocBank;
    }

    // Generic bank detection
    if (firstLines.contains('银行') ||
        firstLines.contains('流水') ||
        firstLines.contains('bank')) {
      return BillSourceType.otherBank;
    }

    // Check if it looks like a financial record
    if (_looksLikeFinancialData(lines)) {
      return BillSourceType.generic;
    }

    return BillSourceType.unknown;
  }

  /// Check if data looks like financial records
  bool _looksLikeFinancialData(List<String> lines) {
    final commonHeaders = [
      '日期', '时间', '金额', '类型', '分类', '收支', '支出', '收入',
      '交易', '备注', '商户', 'date', 'time', 'amount', 'type'
    ];

    for (final line in lines.take(10)) {
      final lower = line.toLowerCase();
      int matchCount = 0;
      for (final header in commonHeaders) {
        if (lower.contains(header.toLowerCase())) {
          matchCount++;
        }
      }
      if (matchCount >= 2) return true;
    }
    return false;
  }

  /// Find the data header row
  Map<String, dynamic>? _findDataHeaders(
    List<String> lines,
    BillSourceType sourceType,
  ) {
    // WeChat Pay: Look for line with "交易时间,交易类型,..."
    if (sourceType == BillSourceType.wechatPay) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('交易时间') && lines[i].contains('金额')) {
          return {'headerIndex': i, 'headers': lines[i].split(',')};
        }
      }
    }

    // Alipay: Look for line with "交易创建时间,..."
    if (sourceType == BillSourceType.alipay) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('交易创建时间') || lines[i].contains('交易时间')) {
          return {'headerIndex': i, 'headers': lines[i].split(',')};
        }
      }
    }

    // Generic: Find first line that looks like headers
    for (int i = 0; i < lines.length && i < 20; i++) {
      final line = lines[i];
      if (_looksLikeHeaderLine(line)) {
        return {'headerIndex': i, 'headers': line.split(',')};
      }
    }

    return null;
  }

  bool _looksLikeHeaderLine(String line) {
    final headers = ['日期', '时间', '金额', '类型', '摘要', '备注', '商户', '收支'];
    int matchCount = 0;
    for (final h in headers) {
      if (line.contains(h)) matchCount++;
    }
    return matchCount >= 2;
  }

  /// Extract date range from metadata
  String? _extractDateRange(List<String> lines, BillSourceType sourceType) {
    if (sourceType == BillSourceType.wechatPay) {
      for (final line in lines.take(10)) {
        if (line.contains('起始时间') && line.contains('终止时间')) {
          // Extract dates from format like "起始时间：[2024-01-01 00:00:00] 终止时间：[2024-01-31 23:59:59]"
          final startMatch = RegExp(r'起始时间[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
          final endMatch = RegExp(r'终止时间[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
          if (startMatch != null && endMatch != null) {
            return '${startMatch.group(1)} 至 ${endMatch.group(1)}';
          }
        }
      }
    }

    if (sourceType == BillSourceType.alipay) {
      for (final line in lines.take(10)) {
        if (line.contains('起始日期') && line.contains('终止日期')) {
          final startMatch = RegExp(r'起始日期[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
          final endMatch = RegExp(r'终止日期[：:]\s*\[?(\d{4}-\d{2}-\d{2})').firstMatch(line);
          if (startMatch != null && endMatch != null) {
            return '${startMatch.group(1)} 至 ${endMatch.group(1)}';
          }
        }
      }
    }

    return null;
  }

  /// Extract metadata from file header
  Map<String, dynamic>? _extractMetadata(
    List<String> lines,
    BillSourceType sourceType,
  ) {
    final metadata = <String, dynamic>{};

    if (sourceType == BillSourceType.wechatPay) {
      for (final line in lines.take(10)) {
        if (line.contains('微信昵称')) {
          final match = RegExp(r'微信昵称[：:]\s*\[?([^\]\n]+)').firstMatch(line);
          if (match != null) {
            metadata['nickname'] = match.group(1)?.replaceAll(']', '').trim();
          }
        }
      }
    }

    if (sourceType == BillSourceType.alipay) {
      for (final line in lines.take(10)) {
        if (line.contains('账号')) {
          final match = RegExp(r'账号[：:]\s*\[?([^\]\n]+)').firstMatch(line);
          if (match != null) {
            metadata['account'] = match.group(1)?.replaceAll(']', '').trim();
          }
        }
      }
    }

    return metadata.isEmpty ? null : metadata;
  }

  /// Detect Excel format
  Future<BillFormatResult> _detectExcelFormat(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        return BillFormatResult(
          format: BillFileFormat.excel,
          sourceType: BillSourceType.unknown,
          errorMessage: 'Excel文件没有数据表',
        );
      }

      // Get first sheet
      final firstSheet = excel.tables.values.first;
      if (firstSheet.rows.isEmpty) {
        return BillFormatResult(
          format: BillFileFormat.excel,
          sourceType: BillSourceType.unknown,
          errorMessage: '数据表为空',
        );
      }

      // Convert to string lines for detection
      final lines = firstSheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').join(','))
          .toList();

      final sourceType = _detectCsvSourceType(lines);
      final headerInfo = _findDataHeaders(lines, sourceType);

      if (headerInfo != null) {
        final headerIndex = headerInfo['headerIndex'] as int;
        final rows = firstSheet.rows.sublist(headerIndex);
        final headers = rows.isNotEmpty
            ? rows[0].map((c) => c?.value?.toString().trim() ?? '').toList()
            : null;
        final recordCount = rows.length - 1;
        final previewRows = rows.length > 6
            ? rows.sublist(1, 6).map((r) => r.map((c) => c?.value).toList()).toList()
            : rows.sublist(1).map((r) => r.map((c) => c?.value).toList()).toList();

        return BillFormatResult(
          format: BillFileFormat.excel,
          sourceType: sourceType,
          estimatedRecordCount: recordCount,
          headers: headers,
          previewRows: previewRows,
        );
      }

      return BillFormatResult(
        format: BillFileFormat.excel,
        sourceType: sourceType,
        errorMessage: '无法找到数据表头',
      );
    } catch (e) {
      return BillFormatResult(
        format: BillFileFormat.excel,
        sourceType: BillSourceType.unknown,
        errorMessage: '解析Excel失败: $e',
      );
    }
  }

  /// Detect OFX format
  BillFormatResult _detectOfxFormat(Uint8List bytes) {
    try {
      final content = utf8.decode(bytes);

      // Check for OFX markers
      if (!content.contains('<OFX>') && !content.contains('<ofx>')) {
        return BillFormatResult(
          format: BillFileFormat.ofx,
          sourceType: BillSourceType.unknown,
          errorMessage: '不是有效的OFX文件',
        );
      }

      // Count transactions
      final transactionCount = '<STMTTRN>'.allMatches(content).length;

      return BillFormatResult(
        format: BillFileFormat.ofx,
        sourceType: BillSourceType.otherBank,
        estimatedRecordCount: transactionCount,
        metadata: {'format': 'OFX/QFX'},
      );
    } catch (e) {
      return BillFormatResult(
        format: BillFileFormat.ofx,
        sourceType: BillSourceType.unknown,
        errorMessage: '解析OFX失败: $e',
      );
    }
  }

  /// Detect QIF format
  BillFormatResult _detectQifFormat(Uint8List bytes) {
    try {
      final content = utf8.decode(bytes);

      // QIF files start with !Type: or have D/T/M/P/N entries
      if (!content.contains('!Type:') &&
          !RegExp(r'^[DTMPN]', multiLine: true).hasMatch(content)) {
        return BillFormatResult(
          format: BillFileFormat.qif,
          sourceType: BillSourceType.unknown,
          errorMessage: '不是有效的QIF文件',
        );
      }

      // Count transactions (separated by ^)
      final transactionCount = '^'.allMatches(content).length;

      return BillFormatResult(
        format: BillFileFormat.qif,
        sourceType: BillSourceType.generic,
        estimatedRecordCount: transactionCount,
        metadata: {'format': 'Quicken QIF'},
      );
    } catch (e) {
      return BillFormatResult(
        format: BillFileFormat.qif,
        sourceType: BillSourceType.unknown,
        errorMessage: '解析QIF失败: $e',
      );
    }
  }

  /// Detect JSON format
  BillFormatResult _detectJsonFormat(Uint8List bytes) {
    try {
      final content = utf8.decode(bytes);
      final data = jsonDecode(content);

      if (data is List) {
        return BillFormatResult(
          format: BillFileFormat.json,
          sourceType: BillSourceType.generic,
          estimatedRecordCount: data.length,
          previewRows: data.take(5).toList().cast<List<dynamic>>(),
        );
      } else if (data is Map) {
        // Look for transactions array in the map
        final transactions = data['transactions'] ??
            data['records'] ??
            data['data'] ??
            data['items'];
        if (transactions is List) {
          return BillFormatResult(
            format: BillFileFormat.json,
            sourceType: BillSourceType.generic,
            estimatedRecordCount: transactions.length,
            metadata: data.keys.where((k) => k != 'transactions' && k != 'records' && k != 'data' && k != 'items').fold<Map<String, dynamic>>({}, (m, k) {
              m[k] = data[k];
              return m;
            }),
          );
        }
      }

      return BillFormatResult(
        format: BillFileFormat.json,
        sourceType: BillSourceType.unknown,
        errorMessage: '无法识别JSON结构',
      );
    } catch (e) {
      return BillFormatResult(
        format: BillFileFormat.json,
        sourceType: BillSourceType.unknown,
        errorMessage: '解析JSON失败: $e',
      );
    }
  }

  /// Simple GBK decoder (fallback)
  String _decodeGbk(Uint8List bytes) {
    // This is a simplified approach - in production, use a proper GBK codec
    // For now, try latin1 as a fallback which preserves the bytes
    try {
      return latin1.decode(bytes);
    } catch (e) {
      // Last resort: just interpret as string with replacement
      return String.fromCharCodes(bytes);
    }
  }
}
