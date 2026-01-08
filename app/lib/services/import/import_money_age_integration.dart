import '../money_age_rebuild_service.dart';
import '../database_service.dart';
import 'batch_import_service.dart';

/// Service to trigger money age recalculation after import (第11章导入后钱龄自动重算)
class ImportMoneyAgeIntegration {
  final DatabaseService _databaseService;
  final MoneyAgeRebuildService _moneyAgeRebuildService;

  ImportMoneyAgeIntegration({
    DatabaseService? databaseService,
    MoneyAgeRebuildService? moneyAgeRebuildService,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _moneyAgeRebuildService = moneyAgeRebuildService ?? MoneyAgeRebuildService();

  /// Execute import with automatic money age recalculation
  Future<BatchImportResultWithMoneyAge> executeImportWithMoneyAgeRecalc(
    BatchImportService importService, {
    String? defaultAccountId,
    ImportProgressCallback? onProgress,
  }) async {
    // Execute the import
    final result = await importService.executeImport(
      defaultAccountId: defaultAccountId,
      onProgress: onProgress,
    );

    if (!result.isSuccess || result.successCount == 0) {
      return BatchImportResultWithMoneyAge(
        importResult: result,
        moneyAgeRecalculated: false,
        moneyAgeError: null,
      );
    }

    // Trigger money age recalculation for affected date range
    try {
      final batch = result.batch;
      if (batch.dateRangeStart != null) {
        onProgress?.call(
          ImportStage.completed,
          result.successCount,
          result.successCount,
          '正在重新计算钱龄...',
        );

        // Rebuild money age from the earliest imported date
        await _moneyAgeRebuildService.rebuildFromDate(batch.dateRangeStart!);

        return BatchImportResultWithMoneyAge(
          importResult: result,
          moneyAgeRecalculated: true,
          moneyAgeError: null,
        );
      }
    } catch (e) {
      return BatchImportResultWithMoneyAge(
        importResult: result,
        moneyAgeRecalculated: false,
        moneyAgeError: '钱龄重算失败: $e',
      );
    }

    return BatchImportResultWithMoneyAge(
      importResult: result,
      moneyAgeRecalculated: false,
      moneyAgeError: null,
    );
  }

  /// Manually trigger money age recalculation for a batch
  Future<void> recalculateMoneyAgeForBatch(String batchId) async {
    final transactions = await _databaseService.getTransactionsByBatchId(batchId);
    if (transactions.isEmpty) return;

    // Find earliest date
    DateTime? earliestDate;
    for (final tx in transactions) {
      if (earliestDate == null || tx.date.isBefore(earliestDate)) {
        earliestDate = tx.date;
      }
    }

    if (earliestDate != null) {
      await _moneyAgeRebuildService.rebuildFromDate(earliestDate);
    }
  }
}

/// Extended import result with money age status
class BatchImportResultWithMoneyAge {
  final BatchImportResult importResult;
  final bool moneyAgeRecalculated;
  final String? moneyAgeError;

  BatchImportResultWithMoneyAge({
    required this.importResult,
    required this.moneyAgeRecalculated,
    this.moneyAgeError,
  });

  bool get isFullSuccess => importResult.isSuccess && moneyAgeRecalculated;
}
