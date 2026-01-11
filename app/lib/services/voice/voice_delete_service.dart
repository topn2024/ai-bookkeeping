import 'dart:async';

import 'package:flutter/foundation.dart';

import 'entity_disambiguation_service.dart';

/// 语音删除与安全确认服务
///
/// 对应设计文档第18.11.2节：语音删除与安全确认系统
/// 核心特性：分级确认策略，保护用户数据安全
///
/// 删除确认级别：
/// - Level 1: 轻量确认（单笔小额，24小时内）- 语音确认即可
/// - Level 2: 标准确认（单笔大额/历史记录）- 语音或屏幕确认
/// - Level 3: 严格确认（批量删除）- 必须屏幕点击确认
/// - Level 4: 禁止语音删除（清空回收站、删除账本等）
class VoiceDeleteService extends ChangeNotifier {
  final EntityDisambiguationService _disambiguationService;

  /// 当前删除会话上下文
  DeleteSessionContext? _currentSession;

  /// 删除历史（用于恢复）
  final List<DeleteOperation> _deleteHistory = [];

  /// 最大历史记录数
  static const int maxHistorySize = 100;

  /// 回收站保留天数
  static const int recycleBinRetentionDays = 30;

  VoiceDeleteService({
    EntityDisambiguationService? disambiguationService,
  }) : _disambiguationService =
            disambiguationService ?? EntityDisambiguationService();

  // ═══════════════════════════════════════════════════════════════
  // 删除意图识别模式
  // ═══════════════════════════════════════════════════════════════

  /// 单笔删除模式
  static final List<RegExp> _singleDeletePatterns = [
    RegExp(r'删[除掉]?(刚才|这笔|那笔|上一笔)'),
    RegExp(r'删[除掉]?(今天|昨天|前天)?(.{1,10}?)(那笔|这笔)?'),
    RegExp(r'把(.{1,10}?)删[除掉]?'),
    RegExp(r'去掉(.{1,10}?)'),
    RegExp(r'取消(.{1,10}?)'),
  ];

  /// 批量删除模式
  static final List<RegExp> _batchDeletePatterns = [
    RegExp(r'删[除掉]?(所有|全部|这些)(.{1,10}?)'),
    RegExp(r'删[除掉]?(今天|昨天|上周|本月|上月)(所有|全部)?(.{1,10}?)?'),
    RegExp(r'清空(.{1,10}?)'),
    RegExp(r'批量删[除掉]?'),
  ];

  /// 高风险操作模式（禁止语音执行）
  static final List<RegExp> _highRiskPatterns = [
    RegExp(r'清空回收站'),
    RegExp(r'删除账本'),
    RegExp(r'删除账户'),
    RegExp(r'删除所有数据'),
    RegExp(r'清除全部'),
    RegExp(r'重置'),
  ];

  // ═══════════════════════════════════════════════════════════════
  // 核心删除流程
  // ═══════════════════════════════════════════════════════════════

  /// 处理删除请求
  Future<DeleteResult> processDeleteRequest(
    String userInput, {
    required TransactionQueryCallback queryCallback,
    required TransactionDeleteCallback deleteCallback,
    DeleteSessionContext? context,
  }) async {
    // Step 1: 检查高风险操作
    if (_isHighRiskOperation(userInput)) {
      return DeleteResult.highRiskBlocked(
        message: '这是高风险操作，无法通过语音完成',
        redirectRoute: _getHighRiskRedirectRoute(userInput),
      );
    }

    // Step 2: 判断是单笔还是批量删除
    final deleteType = _detectDeleteType(userInput);

    if (deleteType == DeleteType.batch) {
      return await _processBatchDelete(
        userInput,
        queryCallback: queryCallback,
        deleteCallback: deleteCallback,
      );
    }

    // Step 3: 单笔删除 - 使用实体消歧定位目标
    final disambiguationResult = await _disambiguationService.disambiguate(
      userInput,
      queryCallback: queryCallback,
      context: context?.toDisambiguationContext(),
    );

    // Step 4: 根据消歧结果处理
    switch (disambiguationResult.status) {
      case DisambiguationStatus.noReference:
        if (context?.currentRecord != null) {
          return await _processSingleDelete(
            context!.currentRecord!,
            deleteCallback,
          );
        }
        return DeleteResult.noTargetSpecified();

      case DisambiguationStatus.noMatch:
        return DeleteResult.noRecordFound();

      case DisambiguationStatus.resolved:
        return await _processSingleDelete(
          disambiguationResult.resolvedRecord!,
          deleteCallback,
          needExtraConfirm: disambiguationResult.needConfirmation,
        );

      case DisambiguationStatus.needClarification:
        _currentSession = DeleteSessionContext(
          candidateRecords: disambiguationResult.candidates,
          clarificationPrompt: disambiguationResult.clarificationPrompt,
        );
        return DeleteResult.needClarification(
          candidates: disambiguationResult.candidates,
          prompt: disambiguationResult.clarificationPrompt ?? '请选择要删除的记录',
        );

      case DisambiguationStatus.needMoreInfo:
        return DeleteResult.needMoreInfo(
          prompt: disambiguationResult.clarificationPrompt ?? '请提供更多信息',
        );
    }
  }

  /// 检测是否是高风险操作
  bool _isHighRiskOperation(String text) {
    return _highRiskPatterns.any((p) => p.hasMatch(text));
  }

  /// 获取高风险操作重定向路由
  String _getHighRiskRedirectRoute(String text) {
    if (text.contains('回收站')) return '/recycle-bin';
    if (text.contains('账本')) return '/ledger-settings';
    if (text.contains('账户')) return '/account-settings';
    return '/settings';
  }

  /// 检测删除类型
  DeleteType _detectDeleteType(String text) {
    // 检查批量删除关键词
    if (_batchDeletePatterns.any((p) => p.hasMatch(text))) {
      // 进一步检查是否真的是批量
      if (text.contains('所有') ||
          text.contains('全部') ||
          text.contains('清空') ||
          text.contains('批量')) {
        return DeleteType.batch;
      }
    }
    return DeleteType.single;
  }

  /// 处理单笔删除
  Future<DeleteResult> _processSingleDelete(
    TransactionRecord record,
    TransactionDeleteCallback deleteCallback, {
    bool needExtraConfirm = false,
  }) async {
    // 确定确认级别
    final confirmLevel = _determineConfirmLevel(
      records: [record],
      isBatch: false,
    );

    if (confirmLevel == ConfirmLevel.level1 && !needExtraConfirm) {
      // Level 1: 轻量确认，直接请求语音确认
      _currentSession = DeleteSessionContext(
        targetRecords: [ScoredCandidate(record: record, confidence: 1.0)],
        confirmLevel: confirmLevel,
        awaitingConfirmation: true,
      );
      return DeleteResult.awaitingVoiceConfirmation(
        records: [record],
        confirmLevel: confirmLevel,
        prompt: '确定删除${record.description ?? record.category}'
            '¥${record.amount.toStringAsFixed(2)}吗？说"确认"或"取消"',
      );
    }

    // Level 2: 标准确认，需要语音或屏幕确认
    _currentSession = DeleteSessionContext(
      targetRecords: [ScoredCandidate(record: record, confidence: 1.0)],
      confirmLevel: confirmLevel,
      awaitingConfirmation: true,
    );

    return DeleteResult.awaitingConfirmation(
      records: [record],
      confirmLevel: confirmLevel,
      prompt: _generateConfirmPrompt([record], confirmLevel),
      showScreenConfirm: true,
    );
  }

  /// 处理批量删除
  Future<DeleteResult> _processBatchDelete(
    String userInput, {
    required TransactionQueryCallback queryCallback,
    required TransactionDeleteCallback deleteCallback,
  }) async {
    // 构建查询条件
    final queryConditions = _buildBatchQueryConditions(userInput);

    // 查询匹配的记录
    final records = await queryCallback(queryConditions);

    if (records.isEmpty) {
      return DeleteResult.noRecordFound();
    }

    // 批量删除必须 Level 3 确认（屏幕点击）
    _currentSession = DeleteSessionContext(
      targetRecords: records
          .map((r) => ScoredCandidate(record: r, confidence: 1.0))
          .toList(),
      confirmLevel: ConfirmLevel.level3,
      awaitingConfirmation: true,
    );

    final totalAmount = records.fold<double>(0, (sum, r) => sum + r.amount);

    return DeleteResult.requireScreenConfirmation(
      records: records,
      prompt: '检测到批量删除请求。共${records.length}笔记录，'
          '总计¥${totalAmount.toStringAsFixed(2)}。\n'
          '批量删除需要在屏幕上确认，请点击确认按钮。',
    );
  }

  /// 构建批量查询条件
  QueryConditions _buildBatchQueryConditions(String text) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;
    String? categoryHint;

    // 解析时间范围
    if (text.contains('今天')) {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (text.contains('昨天')) {
      startDate = DateTime(now.year, now.month, now.day - 1);
      endDate = DateTime(now.year, now.month, now.day);
    } else if (text.contains('上周')) {
      startDate = now.subtract(const Duration(days: 14));
      endDate = now.subtract(const Duration(days: 7));
    } else if (text.contains('本月')) {
      startDate = DateTime(now.year, now.month, 1);
    } else if (text.contains('上月')) {
      startDate = DateTime(now.year, now.month - 1, 1);
      endDate = DateTime(now.year, now.month, 1);
    } else {
      startDate = now.subtract(const Duration(days: 30));
    }

    // 解析分类
    const categories = ['餐饮', '交通', '购物', '娱乐', '住房', '通讯', '医疗', '教育'];
    for (final category in categories) {
      if (text.contains(category)) {
        categoryHint = category;
        break;
      }
    }

    return QueryConditions(
      startDate: startDate,
      endDate: endDate,
      categoryHint: categoryHint,
      limit: 100, // 批量删除限制
    );
  }

  /// 确定确认级别
  ConfirmLevel _determineConfirmLevel({
    required List<TransactionRecord> records,
    required bool isBatch,
  }) {
    if (isBatch || records.length >= 2) {
      return ConfirmLevel.level3; // 批量删除
    }

    final record = records.first;
    final now = DateTime.now();
    final recordAge = now.difference(record.date);

    // Level 1: 单笔小额，24小时内
    if (record.amount < 100 && recordAge.inHours < 24) {
      return ConfirmLevel.level1;
    }

    // Level 2: 单笔大额或历史记录
    return ConfirmLevel.level2;
  }

  /// 生成确认提示
  String _generateConfirmPrompt(
    List<TransactionRecord> records,
    ConfirmLevel level,
  ) {
    if (records.length == 1) {
      final record = records.first;
      switch (level) {
        case ConfirmLevel.level1:
          return '确定删除${record.description ?? record.category}'
              '¥${record.amount.toStringAsFixed(2)}吗？说"确认"或"取消"';
        case ConfirmLevel.level2:
          return '这是一笔较大金额的历史记录。'
              '确定要删除${record.description ?? record.category}'
              '¥${record.amount.toStringAsFixed(2)}吗？';
        case ConfirmLevel.level3:
        case ConfirmLevel.level4:
          return '请在屏幕上确认删除操作';
      }
    }

    final totalAmount = records.fold<double>(0, (sum, r) => sum + r.amount);
    return '共${records.length}笔记录，总计¥${totalAmount.toStringAsFixed(2)}。'
        '请在屏幕上确认删除。';
  }

  // ═══════════════════════════════════════════════════════════════
  // 确认与执行
  // ═══════════════════════════════════════════════════════════════

  /// 处理语音确认
  Future<DeleteResult> handleVoiceConfirmation(
    String userInput,
    TransactionDeleteCallback deleteCallback,
  ) async {
    if (_currentSession == null || !_currentSession!.awaitingConfirmation) {
      return DeleteResult.error('没有待确认的删除操作');
    }

    final lowerInput = userInput.toLowerCase();

    // 检查确认
    if (_isConfirmation(lowerInput)) {
      // Level 3 不允许语音确认
      if (_currentSession!.confirmLevel == ConfirmLevel.level3) {
        return DeleteResult.requireScreenConfirmation(
          records: _currentSession!.targetRecords
                  ?.map((s) => s.record)
                  .toList() ??
              [],
          prompt: '批量删除需要在屏幕上点击确认按钮',
        );
      }

      return await _executeDelete(deleteCallback);
    }

    // 检查取消
    if (_isCancellation(lowerInput)) {
      _currentSession = null;
      return DeleteResult.cancelled();
    }

    return DeleteResult.awaitingConfirmation(
      records:
          _currentSession!.targetRecords?.map((s) => s.record).toList() ?? [],
      confirmLevel: _currentSession!.confirmLevel ?? ConfirmLevel.level2,
      prompt: '请说"确认"删除或"取消"',
      showScreenConfirm: true,
    );
  }

  /// 处理屏幕确认（点击按钮）
  Future<DeleteResult> handleScreenConfirmation(
    TransactionDeleteCallback deleteCallback,
  ) async {
    if (_currentSession == null || !_currentSession!.awaitingConfirmation) {
      return DeleteResult.error('没有待确认的删除操作');
    }

    return await _executeDelete(deleteCallback);
  }

  /// 取消删除
  void cancelDelete() {
    _currentSession = null;
    notifyListeners();
  }

  /// 执行删除
  Future<DeleteResult> _executeDelete(
    TransactionDeleteCallback deleteCallback,
  ) async {
    if (_currentSession?.targetRecords == null) {
      return DeleteResult.error('没有待删除的记录');
    }

    final records =
        _currentSession!.targetRecords!.map((s) => s.record).toList();

    try {
      // 保存到删除历史（用于恢复）
      final operation = DeleteOperation(
        records: records,
        timestamp: DateTime.now(),
        expiresAt:
            DateTime.now().add(Duration(days: recycleBinRetentionDays)),
      );
      _addToHistory(operation);

      // 执行删除
      final success = await deleteCallback(records);

      if (success) {
        _currentSession = null;
        notifyListeners();

        final isBatch = records.length > 1;
        return DeleteResult.success(
          deletedRecords: records,
          canRecover: true,
          recoveryDays: recycleBinRetentionDays,
          message: isBatch
              ? '已删除${records.length}笔记录，${recycleBinRetentionDays}天内可在回收站恢复'
              : '已删除，可在回收站恢复',
        );
      } else {
        _deleteHistory.removeLast();
        return DeleteResult.error('删除失败');
      }
    } catch (e) {
      return DeleteResult.error('删除失败: $e');
    }
  }

  bool _isConfirmation(String text) {
    const confirmWords = ['确认', '确定', '是的', '好的', '删除', '删吧', 'yes', 'ok'];
    return confirmWords.any((w) => text.contains(w));
  }

  bool _isCancellation(String text) {
    const cancelWords = ['取消', '不要', '算了', '不删', '别删', '放弃', 'no', 'cancel'];
    return cancelWords.any((w) => text.contains(w));
  }

  /// 处理用户澄清选择
  Future<DeleteResult> handleClarificationSelection(
    String userInput,
    TransactionDeleteCallback deleteCallback,
  ) async {
    if (_currentSession?.candidateRecords == null) {
      return DeleteResult.error('没有待选择的记录');
    }

    final clarificationResult =
        await _disambiguationService.handleClarification(
      userInput,
      _currentSession!.candidateRecords!,
    );

    if (clarificationResult.isResolved && clarificationResult.resolvedRecord != null) {
      _currentSession = null;
      return await _processSingleDelete(
        clarificationResult.resolvedRecord!,
        deleteCallback,
      );
    }

    return DeleteResult.needMoreInfo(
      prompt: clarificationResult.clarificationPrompt ?? '请重新选择',
    );
  }

  /// 添加到删除历史
  void _addToHistory(DeleteOperation operation) {
    _deleteHistory.add(operation);
    if (_deleteHistory.length > maxHistorySize) {
      _deleteHistory.removeAt(0);
    }
    // 清理过期记录
    _deleteHistory.removeWhere((op) => op.isExpired);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // 恢复功能
  // ═══════════════════════════════════════════════════════════════

  /// 获取可恢复的删除记录
  List<DeleteOperation> getRecoverableDeletes({int limit = 20}) {
    return _deleteHistory
        .where((op) => !op.isExpired)
        .toList()
        .reversed
        .take(limit)
        .toList();
  }

  /// 恢复删除的记录
  Future<bool> recoverDelete(
    DeleteOperation operation,
    TransactionRestoreCallback restoreCallback,
  ) async {
    if (operation.isExpired) {
      return false;
    }

    final success = await restoreCallback(operation.records);
    if (success) {
      _deleteHistory.remove(operation);
      notifyListeners();
    }
    return success;
  }

  /// 当前是否有待确认的删除
  bool get hasPendingDelete =>
      _currentSession != null && _currentSession!.awaitingConfirmation;

  /// 获取当前待删除的记录数
  int get pendingDeleteCount =>
      _currentSession?.targetRecords?.length ?? 0;

  /// 释放资源
  @override
  void dispose() {
    _currentSession = null;
    _deleteHistory.clear();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据类型定义
// ═══════════════════════════════════════════════════════════════

/// 删除类型
enum DeleteType {
  single, // 单笔删除
  batch, // 批量删除
}

/// 确认级别
enum ConfirmLevel {
  level1, // 轻量确认：语音确认即可
  level2, // 标准确认：语音或屏幕确认
  level3, // 严格确认：必须屏幕点击
  level4, // 禁止语音：必须手动操作
}

/// 删除会话上下文
class DeleteSessionContext {
  final TransactionRecord? currentRecord;
  final List<ScoredCandidate>? targetRecords;
  final List<ScoredCandidate>? candidateRecords;
  final String? clarificationPrompt;
  final ConfirmLevel? confirmLevel;
  final bool awaitingConfirmation;

  const DeleteSessionContext({
    this.currentRecord,
    this.targetRecords,
    this.candidateRecords,
    this.clarificationPrompt,
    this.confirmLevel,
    this.awaitingConfirmation = false,
  });

  DisambiguationContext? toDisambiguationContext() {
    if (currentRecord == null) return null;
    return DisambiguationContext(
      lastMentionedRecordId: currentRecord!.id,
    );
  }
}

/// 删除操作记录
class DeleteOperation {
  final List<TransactionRecord> records;
  final DateTime timestamp;
  final DateTime expiresAt;

  const DeleteOperation({
    required this.records,
    required this.timestamp,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingDays => expiresAt.difference(DateTime.now()).inDays;

  double get totalAmount =>
      records.fold<double>(0, (sum, r) => sum + r.amount);
}

/// 删除结果
class DeleteResult {
  final DeleteResultStatus status;
  final List<TransactionRecord>? deletedRecords;
  final List<ScoredCandidate>? candidates;
  final ConfirmLevel? confirmLevel;
  final String? prompt;
  final String? message;
  final String? errorMessage;
  final String? redirectRoute;
  final bool showScreenConfirm;
  final bool canRecover;
  final int? recoveryDays;

  const DeleteResult({
    required this.status,
    this.deletedRecords,
    this.candidates,
    this.confirmLevel,
    this.prompt,
    this.message,
    this.errorMessage,
    this.redirectRoute,
    this.showScreenConfirm = false,
    this.canRecover = false,
    this.recoveryDays,
  });

  factory DeleteResult.success({
    required List<TransactionRecord> deletedRecords,
    required bool canRecover,
    int? recoveryDays,
    String? message,
  }) {
    return DeleteResult(
      status: DeleteResultStatus.success,
      deletedRecords: deletedRecords,
      canRecover: canRecover,
      recoveryDays: recoveryDays,
      message: message,
    );
  }

  factory DeleteResult.awaitingVoiceConfirmation({
    required List<TransactionRecord> records,
    required ConfirmLevel confirmLevel,
    required String prompt,
  }) {
    return DeleteResult(
      status: DeleteResultStatus.awaitingVoiceConfirmation,
      deletedRecords: records,
      confirmLevel: confirmLevel,
      prompt: prompt,
      showScreenConfirm: false,
    );
  }

  factory DeleteResult.awaitingConfirmation({
    required List<TransactionRecord> records,
    required ConfirmLevel confirmLevel,
    required String prompt,
    bool showScreenConfirm = true,
  }) {
    return DeleteResult(
      status: DeleteResultStatus.awaitingConfirmation,
      deletedRecords: records,
      confirmLevel: confirmLevel,
      prompt: prompt,
      showScreenConfirm: showScreenConfirm,
    );
  }

  factory DeleteResult.requireScreenConfirmation({
    required List<TransactionRecord> records,
    required String prompt,
  }) {
    return DeleteResult(
      status: DeleteResultStatus.requireScreenConfirmation,
      deletedRecords: records,
      confirmLevel: ConfirmLevel.level3,
      prompt: prompt,
      showScreenConfirm: true,
    );
  }

  factory DeleteResult.needClarification({
    required List<ScoredCandidate> candidates,
    required String prompt,
  }) {
    return DeleteResult(
      status: DeleteResultStatus.needClarification,
      candidates: candidates,
      prompt: prompt,
    );
  }

  factory DeleteResult.needMoreInfo({required String prompt}) {
    return DeleteResult(
      status: DeleteResultStatus.needMoreInfo,
      prompt: prompt,
    );
  }

  factory DeleteResult.noTargetSpecified() {
    return const DeleteResult(
      status: DeleteResultStatus.noTargetSpecified,
      prompt: '请说明要删除哪条记录',
    );
  }

  factory DeleteResult.noRecordFound() {
    return const DeleteResult(
      status: DeleteResultStatus.noRecordFound,
      prompt: '没有找到匹配的记录',
    );
  }

  factory DeleteResult.highRiskBlocked({
    required String message,
    required String redirectRoute,
  }) {
    return DeleteResult(
      status: DeleteResultStatus.highRiskBlocked,
      message: message,
      redirectRoute: redirectRoute,
    );
  }

  factory DeleteResult.cancelled() {
    return const DeleteResult(
      status: DeleteResultStatus.cancelled,
      message: '已取消删除',
    );
  }

  factory DeleteResult.error(String message) {
    return DeleteResult(
      status: DeleteResultStatus.error,
      errorMessage: message,
    );
  }

  bool get isSuccess => status == DeleteResultStatus.success;
  bool get needsConfirmation =>
      status == DeleteResultStatus.awaitingConfirmation ||
      status == DeleteResultStatus.awaitingVoiceConfirmation;
  bool get requiresScreenConfirm =>
      status == DeleteResultStatus.requireScreenConfirmation;
  bool get needsClarification =>
      status == DeleteResultStatus.needClarification;
  bool get isError => status == DeleteResultStatus.error;
  bool get isCancelled => status == DeleteResultStatus.cancelled;
  bool get isBlocked => status == DeleteResultStatus.highRiskBlocked;

  /// 生成语音反馈文本
  String generateFeedbackText() {
    switch (status) {
      case DeleteResultStatus.success:
        return message ?? '删除成功';

      case DeleteResultStatus.awaitingVoiceConfirmation:
      case DeleteResultStatus.awaitingConfirmation:
        return prompt ?? '请确认删除';

      case DeleteResultStatus.requireScreenConfirmation:
        return prompt ?? '请在屏幕上确认删除';

      case DeleteResultStatus.needClarification:
        return prompt ?? '请选择要删除的记录';

      case DeleteResultStatus.needMoreInfo:
        return prompt ?? '请提供更多信息';

      case DeleteResultStatus.noTargetSpecified:
        return prompt ?? '请说明要删除哪条记录';

      case DeleteResultStatus.noRecordFound:
        return prompt ?? '没有找到匹配的记录';

      case DeleteResultStatus.highRiskBlocked:
        return message ?? '此操作无法通过语音完成';

      case DeleteResultStatus.cancelled:
        return message ?? '已取消';

      case DeleteResultStatus.error:
        return errorMessage ?? '删除失败';
    }
  }
}

/// 删除结果状态
enum DeleteResultStatus {
  success, // 删除成功
  awaitingVoiceConfirmation, // 等待语音确认
  awaitingConfirmation, // 等待确认（语音或屏幕）
  requireScreenConfirmation, // 必须屏幕确认
  needClarification, // 需要澄清
  needMoreInfo, // 需要更多信息
  noTargetSpecified, // 未指定目标
  noRecordFound, // 未找到记录
  highRiskBlocked, // 高风险操作被阻止
  cancelled, // 已取消
  error, // 错误
}

/// 交易删除回调
typedef TransactionDeleteCallback = Future<bool> Function(
    List<TransactionRecord> records);

/// 交易恢复回调
typedef TransactionRestoreCallback = Future<bool> Function(
    List<TransactionRecord> records);
