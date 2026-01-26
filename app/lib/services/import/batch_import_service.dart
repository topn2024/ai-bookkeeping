import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../models/import_batch.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';
import 'bill_format_detector.dart';
import 'bill_parser.dart';
import 'wechat_bill_parser.dart';
import 'alipay_bill_parser.dart';
import 'generic_bank_parser.dart';
import 'duplicate_scorer.dart';

/// Import progress callback
typedef ImportProgressCallback = void Function(
  ImportStage stage,
  int current,
  int total,
  String? message,
);

/// Import stages
enum ImportStage {
  detecting,    // Detecting file format
  parsing,      // Parsing file content
  categorizing, // Categorizing transactions
  deduplicating, // Checking for duplicates
  importing,    // Importing transactions
  completed,    // Import completed
}

/// Result of batch import operation
class BatchImportResult {
  final ImportBatch batch;
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final List<String> errors;
  final double totalExpense;
  final double totalIncome;

  BatchImportResult({
    required this.batch,
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    this.errors = const [],
    this.totalExpense = 0,
    this.totalIncome = 0,
  });

  bool get isSuccess => failedCount == 0 && successCount > 0;
}

/// Service to handle batch import of bill files
class BatchImportService {
  final IDatabaseService _databaseService;
  final BillFormatDetector _formatDetector;
  final DuplicateScorer _duplicateScorer;
  final Uuid _uuid = const Uuid();

  // Parsed data (cached for preview)
  BillFormatResult? _lastFormatResult;
  List<ImportCandidate>? _lastCandidates;
  String? _lastFileName;

  BatchImportService({
    IDatabaseService? databaseService,
  })  : _databaseService = databaseService ?? sl<IDatabaseService>(),
        _formatDetector = BillFormatDetector(),
        _duplicateScorer = DuplicateScorer(
          databaseService: databaseService ?? sl<IDatabaseService>(),
        );

  /// Get last format detection result
  BillFormatResult? get lastFormatResult => _lastFormatResult;

  /// Get last parsed candidates
  List<ImportCandidate>? get lastCandidates => _lastCandidates;

  /// Get last file name
  String? get lastFileName => _lastFileName;

  /// Detect file format from file path
  Future<BillFormatResult> detectFormat(String filePath) async {
    _lastFileName = filePath.split('/').last.split('\\').last;
    _lastFormatResult = await _formatDetector.detectFromFile(filePath);
    return _lastFormatResult!;
  }

  /// Detect file format from bytes
  Future<BillFormatResult> detectFormatFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    _lastFileName = fileName;
    final extension = fileName.split('.').last;
    _lastFormatResult = await _formatDetector.detectFromBytes(bytes, extension);
    return _lastFormatResult!;
  }

  /// Parse bill file and return candidates for preview
  Future<BillParseResult> parseFile(
    String filePath, {
    ImportProgressCallback? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 1,
        errors: ['文件不存在'],
      );
    }

    final bytes = await file.readAsBytes();
    final fileName = filePath.split('/').last.split('\\').last;
    return parseBytes(bytes, fileName, onProgress: onProgress);
  }

  /// Parse bill bytes and return candidates for preview
  Future<BillParseResult> parseBytes(
    Uint8List bytes,
    String fileName, {
    ImportProgressCallback? onProgress,
  }) async {
    // Detect format if not already done
    if (_lastFormatResult == null || _lastFileName != fileName) {
      onProgress?.call(ImportStage.detecting, 0, 1, '正在识别文件格式...');
      await detectFormatFromBytes(bytes, fileName);
    }

    if (_lastFormatResult == null || !_lastFormatResult!.isSuccess) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 1,
        errors: [_lastFormatResult?.errorMessage ?? '无法识别文件格式'],
      );
    }

    // Get appropriate parser
    final parser = _getParser(_lastFormatResult!.sourceType);
    if (parser == null) {
      return BillParseResult(
        candidates: [],
        successCount: 0,
        failedCount: 1,
        errors: ['不支持的账单格式: ${_lastFormatResult!.sourceTypeName}'],
      );
    }

    // Parse file
    onProgress?.call(ImportStage.parsing, 0, 1, '正在解析账单数据...');
    final parseResult = await parser.parse(bytes);

    if (!parseResult.hasPartialSuccess) {
      return parseResult;
    }

    // Check for duplicates
    onProgress?.call(ImportStage.deduplicating, 0, parseResult.candidates.length, '正在检查重复交易...');
    await _duplicateScorer.checkDuplicates(
      parseResult.candidates,
      externalSource: _lastFormatResult!.externalSource,
      onProgress: (current, total) {
        onProgress?.call(ImportStage.deduplicating, current, total, '正在检查重复交易... ($current/$total)');
      },
    );

    _lastCandidates = parseResult.candidates;

    return parseResult;
  }

  /// Get parser for source type
  BillParser? _getParser(BillSourceType sourceType) {
    switch (sourceType) {
      case BillSourceType.wechatPay:
        return WechatBillParser();
      case BillSourceType.alipay:
        return AlipayBillParser();
      case BillSourceType.cmbBank:
      case BillSourceType.icbcBank:
      case BillSourceType.abcBank:
      case BillSourceType.ccbBank:
      case BillSourceType.bocBank:
      case BillSourceType.otherBank:
        return GenericBankParser(sourceType: sourceType);
      case BillSourceType.generic:
        return GenericBankParser(sourceType: BillSourceType.generic);
      case BillSourceType.sms:
        // 短信导入使用 SmsImportService 单独处理，不需要解析器
        return null;
      case BillSourceType.unknown:
        return null;
    }
  }

  /// Execute the import with the current candidates
  Future<BatchImportResult> executeImport({
    String? defaultAccountId,
    ImportProgressCallback? onProgress,
  }) async {
    if (_lastCandidates == null || _lastCandidates!.isEmpty) {
      return BatchImportResult(
        batch: ImportBatch(
          id: ImportBatch.generateId(),
          fileName: _lastFileName ?? 'unknown',
          fileFormat: 'unknown',
          totalCount: 0,
          importedCount: 0,
          skippedCount: 0,
        ),
        successCount: 0,
        skippedCount: 0,
        failedCount: 1,
        errors: ['没有待导入的交易'],
      );
    }

    final batchId = ImportBatch.generateId();
    final candidates = _lastCandidates!;
    final errors = <String>[];

    // Filter candidates to import
    final toImport = candidates.where((c) => c.action == ImportAction.import_).toList();
    final toSkip = candidates.where((c) => c.action == ImportAction.skip).toList();

    if (toImport.isEmpty) {
      return BatchImportResult(
        batch: ImportBatch(
          id: batchId,
          fileName: _lastFileName ?? 'unknown',
          fileFormat: _lastFormatResult?.formatId ?? 'unknown',
          totalCount: candidates.length,
          importedCount: 0,
          skippedCount: toSkip.length,
        ),
        successCount: 0,
        skippedCount: toSkip.length,
        failedCount: 0,
      );
    }

    onProgress?.call(ImportStage.importing, 0, toImport.length, '正在导入交易...');

    // Convert candidates to transactions
    final transactions = <Transaction>[];
    double totalExpense = 0;
    double totalIncome = 0;
    DateTime? dateRangeStart;
    DateTime? dateRangeEnd;

    for (int i = 0; i < toImport.length; i++) {
      final candidate = toImport[i];

      try {
        final transaction = candidate.toTransaction(
          id: _uuid.v4(),
          batchId: batchId,
          externalSource: _lastFormatResult?.externalSource,
        ).copyWith(
          accountId: candidate.accountId ?? defaultAccountId ?? 'default',
        );

        transactions.add(transaction);

        // Calculate totals
        if (transaction.type == TransactionType.expense) {
          totalExpense += transaction.amount;
        } else if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        }

        // Track date range
        if (dateRangeStart == null || transaction.date.isBefore(dateRangeStart)) {
          dateRangeStart = transaction.date;
        }
        if (dateRangeEnd == null || transaction.date.isAfter(dateRangeEnd)) {
          dateRangeEnd = transaction.date;
        }

        onProgress?.call(
          ImportStage.importing,
          i + 1,
          toImport.length,
          '正在导入交易... (${i + 1}/${toImport.length})',
        );
      } catch (e) {
        errors.add('导入第 ${candidate.index + 1} 条记录失败: $e');
      }
    }

    // Batch insert transactions
    try {
      await _databaseService.batchInsertTransactions(transactions);
    } catch (e) {
      return BatchImportResult(
        batch: ImportBatch(
          id: batchId,
          fileName: _lastFileName ?? 'unknown',
          fileFormat: _lastFormatResult?.formatId ?? 'unknown',
          totalCount: candidates.length,
          importedCount: 0,
          skippedCount: toSkip.length,
          failedCount: toImport.length,
        ),
        successCount: 0,
        skippedCount: toSkip.length,
        failedCount: toImport.length,
        errors: ['批量导入失败: $e'],
      );
    }

    // Create and save import batch record
    final batch = ImportBatch(
      id: batchId,
      fileName: _lastFileName ?? 'unknown',
      fileFormat: _lastFormatResult?.formatId ?? 'unknown',
      totalCount: candidates.length,
      importedCount: transactions.length,
      skippedCount: toSkip.length,
      failedCount: errors.length,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      dateRangeStart: dateRangeStart,
      dateRangeEnd: dateRangeEnd,
    );

    await _databaseService.insertImportBatch(batch);

    onProgress?.call(ImportStage.completed, transactions.length, toImport.length, '导入完成');

    // Clear cached data
    _lastCandidates = null;
    _lastFormatResult = null;
    _lastFileName = null;

    return BatchImportResult(
      batch: batch,
      successCount: transactions.length,
      skippedCount: toSkip.length,
      failedCount: errors.length,
      errors: errors,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
    );
  }

  /// Get import history
  Future<List<ImportBatch>> getImportHistory() async {
    return await _databaseService.getImportBatches();
  }

  /// Get active import batches
  Future<List<ImportBatch>> getActiveImportBatches() async {
    return await _databaseService.getActiveImportBatches();
  }

  /// Revoke an import batch
  Future<void> revokeImportBatch(String batchId) async {
    await _databaseService.revokeImportBatch(batchId);
  }

  /// Get transactions by batch ID
  Future<List<Transaction>> getTransactionsByBatchId(String batchId) async {
    return await _databaseService.getTransactionsByBatchId(batchId);
  }

  /// Clear cached parse results
  void clearCache() {
    _lastCandidates = null;
    _lastFormatResult = null;
    _lastFileName = null;
  }

  /// Set candidates directly (for non-file imports like SMS)
  void setCandidates(List<ImportCandidate> candidates, {String? fileName}) {
    _lastCandidates = candidates;
    _lastFileName = fileName;
  }

  /// Update candidate action
  void updateCandidateAction(int index, ImportAction action) {
    if (_lastCandidates != null && index < _lastCandidates!.length) {
      _lastCandidates![index] = _lastCandidates![index].copyWith(action: action);
    }
  }

  /// Batch update candidate actions
  void batchUpdateCandidateActions(List<int> indices, ImportAction action) {
    if (_lastCandidates == null) return;
    for (final index in indices) {
      if (index < _lastCandidates!.length) {
        _lastCandidates![index] = _lastCandidates![index].copyWith(action: action);
      }
    }
  }

  /// Update candidate category
  void updateCandidateCategory(int index, String category) {
    if (_lastCandidates != null && index < _lastCandidates!.length) {
      _lastCandidates![index] = _lastCandidates![index].copyWith(
        category: category,
        isEdited: true,
      );
    }
  }

  /// Update candidate account
  void updateCandidateAccount(int index, String accountId) {
    if (_lastCandidates != null && index < _lastCandidates!.length) {
      _lastCandidates![index] = _lastCandidates![index].copyWith(
        accountId: accountId,
        isEdited: true,
      );
    }
  }

  /// Get import summary
  ImportCandidateSummary? getSummary() {
    if (_lastCandidates == null) return null;
    return ImportCandidateSummary.fromCandidates(_lastCandidates!);
  }

  /// Apply smart action - skip high duplicates, import others
  void applySmartActions() {
    if (_lastCandidates == null) return;

    for (int i = 0; i < _lastCandidates!.length; i++) {
      final candidate = _lastCandidates![i];
      if (candidate.duplicateResult != null) {
        final level = candidate.duplicateResult!.level;
        if (level == DuplicateLevel.exact || level == DuplicateLevel.high) {
          _lastCandidates![i] = candidate.copyWith(action: ImportAction.skip);
        } else {
          _lastCandidates![i] = candidate.copyWith(action: ImportAction.import_);
        }
      } else {
        _lastCandidates![i] = candidate.copyWith(action: ImportAction.import_);
      }
    }
  }

  /// Skip all duplicates (any level)
  void skipAllDuplicates() {
    if (_lastCandidates == null) return;

    for (int i = 0; i < _lastCandidates!.length; i++) {
      final candidate = _lastCandidates![i];
      if (candidate.isDuplicate) {
        _lastCandidates![i] = candidate.copyWith(action: ImportAction.skip);
      } else {
        _lastCandidates![i] = candidate.copyWith(action: ImportAction.import_);
      }
    }
  }

  /// Import all candidates
  void importAll() {
    if (_lastCandidates == null) return;

    for (int i = 0; i < _lastCandidates!.length; i++) {
      _lastCandidates![i] = _lastCandidates![i].copyWith(action: ImportAction.import_);
    }
  }
}
