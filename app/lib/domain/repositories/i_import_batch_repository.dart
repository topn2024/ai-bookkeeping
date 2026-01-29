/// Import Batch Repository Interface
///
/// 定义导入批次实体的仓库接口
library;

import '../../models/import_batch.dart';
import 'i_repository.dart';

/// 导入统计
class ImportStatistics {
  final int totalBatches;
  final int totalRecords;
  final int successfulRecords;
  final int failedRecords;
  final int duplicateRecords;

  const ImportStatistics({
    required this.totalBatches,
    required this.totalRecords,
    required this.successfulRecords,
    required this.failedRecords,
    required this.duplicateRecords,
  });
}

/// 导入批次仓库接口
abstract class IImportBatchRepository extends IRepository<ImportBatch, String> {
  /// 按来源类型查询导入批次
  Future<List<ImportBatch>> findBySource(String source);

  /// 获取指定状态的导入批次
  Future<List<ImportBatch>> findByStatus(ImportStatus status);

  /// 获取指定日期范围的导入批次
  Future<List<ImportBatch>> findByDateRange(DateTime start, DateTime end);

  /// 获取最近的导入批次
  Future<List<ImportBatch>> findRecent({int limit = 10});

  /// 获取导入统计
  Future<ImportStatistics> getStatistics();

  /// 更新批次状态
  Future<void> updateStatus(String batchId, ImportStatus status);

  /// 更新批次处理进度
  Future<void> updateProgress(
    String batchId, {
    int? processedCount,
    int? successCount,
    int? failedCount,
    int? duplicateCount,
  });

  /// 获取批次中的所有记录
  Future<List<ImportRecord>> getRecords(String batchId);

  /// 添加导入记录
  Future<void> addRecord(String batchId, ImportRecord record);

  /// 获取失败的记录
  Future<List<ImportRecord>> getFailedRecords(String batchId);

  /// 获取重复的记录
  Future<List<ImportRecord>> getDuplicateRecords(String batchId);

  /// 重试失败的记录
  Future<void> retryFailed(String batchId);

  /// 取消导入批次
  Future<void> cancel(String batchId);
}

/// 导入状态
enum ImportStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  partiallyCompleted,
}

/// 导入记录
class ImportRecord {
  final String id;
  final String batchId;
  final Map<String, dynamic> rawData;
  final ImportRecordStatus status;
  final String? errorMessage;
  final String? transactionId;
  final DateTime createdAt;

  const ImportRecord({
    required this.id,
    required this.batchId,
    required this.rawData,
    required this.status,
    this.errorMessage,
    this.transactionId,
    required this.createdAt,
  });
}

/// 导入记录状态
enum ImportRecordStatus {
  pending,
  success,
  failed,
  duplicate,
  skipped,
}
