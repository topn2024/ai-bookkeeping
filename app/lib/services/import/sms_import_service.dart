import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import 'sms_reader_service.dart';
import 'sms_parser_service.dart';
import 'duplicate_scorer.dart';

/// 短信导入服务
/// 协调整个短信导入流程
class SmsImportService {
  final SmsReaderService _readerService;
  final SmsParserService _parserService;
  final DuplicateScorer _duplicateScorer;

  SmsImportService({
    SmsReaderService? readerService,
    SmsParserService? parserService,
    DuplicateScorer? duplicateScorer,
  })  : _readerService = readerService ?? SmsReaderService(),
        _parserService = parserService ?? SmsParserService(),
        _duplicateScorer = duplicateScorer ?? DuplicateScorer();

  /// 检查短信权限
  Future<bool> checkPermission() async {
    return await _readerService.checkPermission();
  }

  /// 申请短信权限
  Future<bool> requestPermission() async {
    return await _readerService.requestPermission();
  }

  /// 执行短信导入
  ///
  /// [startDate] 开始时间
  /// [endDate] 结束时间
  /// [useSenderFilter] 是否使用发件人过滤
  /// [onProgress] 进度回调 (stage, current, total)
  ///   stage: 'reading' | 'parsing' | 'checking'
  Future<List<ImportCandidate>> importSms({
    required DateTime startDate,
    required DateTime endDate,
    bool useSenderFilter = true,
    Function(String stage, int current, int total)? onProgress,
  }) async {
    // 阶段1: 读取短信
    onProgress?.call('reading', 0, 100);

    final senderFilter = useSenderFilter ? _readerService.getPaymentSenders() : null;

    final messages = await _readerService.readSms(
      startDate: startDate,
      endDate: endDate,
      senderFilter: senderFilter,
      onProgress: (current, total) {
        onProgress?.call('reading', current, total);
      },
    );

    if (messages.isEmpty) {
      return [];
    }

    // 阶段2: AI解析
    onProgress?.call('parsing', 0, messages.length);

    final parsedResults = await _parserService.parseBatch(
      messages,
      onProgress: (current, total) {
        onProgress?.call('parsing', current, total);
      },
    );

    // 过滤掉null（非交易短信）和无效金额，并转换为ImportCandidate
    final candidates = <ImportCandidate>[];
    int skippedCount = 0;
    for (int i = 0; i < parsedResults.length; i++) {
      final result = parsedResults[i];
      if (result != null) {
        // 过滤无效金额（金额为0或负数）
        if (result.amount <= 0) {
          skippedCount++;
          print('[SmsImportService] 跳过无效交易 #$i: 金额=${result.amount}, 商户=${result.merchant}');
          continue;
        }
        final candidate = _parserService.toImportCandidate(result, candidates.length);
        if (candidate != null) {
          candidates.add(candidate);
        } else {
          skippedCount++;
        }
      }
    }

    if (skippedCount > 0) {
      print('[SmsImportService] 已过滤 $skippedCount 条无效交易（金额<=0）');
    }

    if (candidates.isEmpty) {
      return [];
    }

    // 阶段3: 重复检测
    onProgress?.call('checking', 0, candidates.length);

    await _duplicateScorer.checkDuplicates(
      candidates,
      externalSource: ExternalSource.sms,
      onProgress: (current, total) {
        onProgress?.call('checking', current, total);
      },
    );

    return candidates;
  }

  /// 获取常见支付平台发件人列表
  List<String> getPaymentSenders() {
    return _readerService.getPaymentSenders();
  }
}
