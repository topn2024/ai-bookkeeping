import 'dart:async';

import 'package:flutter/foundation.dart';

import 'entity_disambiguation_service.dart';

/// 语音修改记录服务
///
/// 对应设计文档第18.11.1节：语音修改记录系统
/// 核心差异化特性：支持通过语音修改任意已有记录
///
/// 功能特性：
/// 1. 解析修改意图：识别用户想修改什么字段
/// 2. 目标记录定位：结合实体消歧引擎定位目标记录
/// 3. 多字段同时修改：支持一次性修改多个字段
/// 4. 修改确认流程：根据修改复杂度决定是否需要确认
/// 5. 修改历史记录：支持撤销和恢复
class VoiceModifyService extends ChangeNotifier {
  final EntityDisambiguationService _disambiguationService;

  /// 当前修改会话上下文
  ModifySessionContext? _currentSession;

  /// 修改历史栈（用于撤销）
  final List<ModifyOperation> _modifyHistory = [];

  /// 最大历史记录数
  static const int maxHistorySize = 50;

  VoiceModifyService({
    EntityDisambiguationService? disambiguationService,
  }) : _disambiguationService =
            disambiguationService ?? EntityDisambiguationService();

  // ═══════════════════════════════════════════════════════════════
  // 修改字段模式定义
  // ═══════════════════════════════════════════════════════════════

  /// 修改字段识别模式
  static final Map<ModifyField, List<RegExp>> _modifyPatterns = {
    // 金额修改
    ModifyField.amount: [
      RegExp(r'(金额)?改[成为]?\s*(\d+\.?\d*)\s*[块元]?'),
      RegExp(r'(金额)?[调改][高低大小]\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.?\d*)\s*[块元]?改[成为]?\s*(\d+\.?\d*)'),
      RegExp(r'把?\s*(\d+\.?\d*)\s*改[成为]?\s*(\d+\.?\d*)'),
    ],
    // 分类修改
    ModifyField.category: [
      RegExp(r'(分类)?改[成为]?\s*(.{1,8}?)(?:分类)?$'),
      RegExp(r'(分类)?换[成为]?\s*(.{1,8}?)(?:分类)?$'),
      RegExp(r'从(.{1,8})改[成为]?\s*(.{1,8})'),
    ],
    // 子分类修改
    ModifyField.subCategory: [
      RegExp(r'子分类改[成为]?\s*(.{1,8})'),
      RegExp(r'改[成为]?(早餐|午餐|晚餐|夜宵|外卖)'),
    ],
    // 备注修改
    ModifyField.description: [
      RegExp(r'备注改[成为]?\s*(.+)'),
      RegExp(r'加个?备注\s*(.+)'),
      RegExp(r'描述改[成为]?\s*(.+)'),
    ],
    // 日期修改
    ModifyField.date: [
      RegExp(r'日期改[成为]?\s*(.+)'),
      RegExp(r'调到?\s*(今天|昨天|前天|上周.?)'),
      RegExp(r'改[成为]?\s*(\d+月\d+[日号])'),
    ],
    // 账户修改
    ModifyField.account: [
      RegExp(r'账户[换改][成为]?\s*(.{1,10})'),
      RegExp(r'从(.{1,10})[换改][成为]?\s*(.{1,10})'),
      RegExp(r'[换改][成用](.{1,10})(?:支付|付款)?'),
    ],
    // 标签修改
    ModifyField.tags: [
      RegExp(r'加个?标签\s*(.{1,10})'),
      RegExp(r'[去删移]掉?(.{1,10})标签'),
      RegExp(r'标签改[成为]?\s*(.{1,10})'),
    ],
    // 类型修改（支出/收入/转账）
    ModifyField.transactionType: [
      RegExp(r'改[成为]?(支出|收入|转账)'),
      RegExp(r'这是(收入|转账)不是支出'),
      RegExp(r'(支出|收入|转账)改[成为]?(支出|收入|转账)'),
    ],
  };

  /// 常用分类名称
  static const Set<String> _knownCategories = {
    '餐饮',
    '交通',
    '购物',
    '娱乐',
    '住房',
    '通讯',
    '医疗',
    '教育',
    '服饰',
    '运动',
    '数码',
    '美容',
    '宠物',
    '社交',
    '旅行',
    '收入',
    '工资',
    '奖金',
    '投资',
  };

  /// 常用账户名称
  static const Set<String> _knownAccounts = {
    '微信',
    '支付宝',
    '现金',
    '银行卡',
    '信用卡',
    '工商银行',
    '建设银行',
    '招商银行',
    '农业银行',
    '交通银行',
    '中国银行',
    '民生银行',
    '浦发银行',
  };

  // ═══════════════════════════════════════════════════════════════
  // 核心修改流程
  // ═══════════════════════════════════════════════════════════════

  /// 处理修改请求
  ///
  /// 完整流程：
  /// 1. 解析修改意图（要改什么字段）
  /// 2. 定位目标记录（使用实体消歧）
  /// 3. 验证修改有效性
  /// 4. 根据复杂度决定确认流程
  /// 5. 执行修改并记录历史
  Future<ModifyResult> processModifyRequest(
    String userInput, {
    required TransactionQueryCallback queryCallback,
    required TransactionUpdateCallback updateCallback,
    ModifySessionContext? context,
  }) async {
    // Step 1: 解析修改意图
    final modifications = _parseModifications(userInput);
    if (modifications.isEmpty) {
      return ModifyResult.noModificationDetected();
    }

    // Step 2: 使用实体消歧定位目标记录
    final disambiguationResult = await _disambiguationService.disambiguate(
      userInput,
      queryCallback: queryCallback,
      context: context?.toDisambiguationContext(),
    );

    // Step 3: 根据消歧结果处理
    switch (disambiguationResult.status) {
      case DisambiguationStatus.noReference:
        // 没有指代词，尝试使用上下文中的当前记录
        if (context?.currentRecord != null) {
          final record = context!.currentRecord!;
          final needConfirm = modifications.length > 1 ||
              _isSignificantChange(record, modifications);
          return await _executeModification(
            record,
            modifications,
            updateCallback,
            needConfirmation: needConfirm,
          );
        }
        return ModifyResult.noTargetSpecified();

      case DisambiguationStatus.noMatch:
        return ModifyResult.noRecordFound(disambiguationResult.references);

      case DisambiguationStatus.resolved:
        // 明确定位到一条记录
        final record = disambiguationResult.resolvedRecord!;
        final needConfirm = disambiguationResult.needConfirmation ||
            modifications.length > 1 ||
            _isSignificantChange(record, modifications);

        return await _executeModification(
          record,
          modifications,
          updateCallback,
          needConfirmation: needConfirm,
        );

      case DisambiguationStatus.needClarification:
        // 需要用户澄清选择哪条记录
        _currentSession = ModifySessionContext(
          pendingModifications: modifications,
          candidateRecords: disambiguationResult.candidates,
          clarificationPrompt: disambiguationResult.clarificationPrompt,
        );
        return ModifyResult.needClarification(
          candidates: disambiguationResult.candidates,
          prompt: disambiguationResult.clarificationPrompt ?? '请选择要修改的记录',
          modifications: modifications,
        );

      case DisambiguationStatus.needMoreInfo:
        return ModifyResult.needMoreInfo(
          prompt: disambiguationResult.clarificationPrompt ?? '请提供更多信息',
        );
    }
  }

  /// 解析修改意图
  List<FieldModification> _parseModifications(String text) {
    final modifications = <FieldModification>[];
    final lowerText = text.toLowerCase();

    for (final entry in _modifyPatterns.entries) {
      for (final pattern in entry.value) {
        final match = pattern.firstMatch(lowerText);
        if (match != null) {
          final modification = _extractModification(entry.key, match, text);
          if (modification != null) {
            modifications.add(modification);
          }
        }
      }
    }

    return modifications;
  }

  /// 提取具体的修改内容
  FieldModification? _extractModification(
    ModifyField field,
    RegExpMatch match,
    String originalText,
  ) {
    switch (field) {
      case ModifyField.amount:
        // 提取金额数值
        for (var i = match.groupCount; i >= 1; i--) {
          final value = double.tryParse(match.group(i) ?? '');
          if (value != null && value > 0) {
            return FieldModification(
              field: field,
              newValue: value,
              rawText: match.group(0) ?? '',
            );
          }
        }
        return null;

      case ModifyField.category:
        final categoryValue = match.group(match.groupCount) ?? match.group(1);
        if (categoryValue != null && categoryValue.isNotEmpty) {
          // 验证是否是有效分类
          final normalizedCategory = _normalizeCategory(categoryValue);
          return FieldModification(
            field: field,
            newValue: normalizedCategory,
            rawText: match.group(0) ?? '',
          );
        }
        return null;

      case ModifyField.subCategory:
        final subCategoryValue = match.group(1);
        if (subCategoryValue != null) {
          return FieldModification(
            field: field,
            newValue: subCategoryValue,
            rawText: match.group(0) ?? '',
          );
        }
        return null;

      case ModifyField.description:
        final descValue = match.group(1);
        if (descValue != null && descValue.isNotEmpty) {
          return FieldModification(
            field: field,
            newValue: descValue.trim(),
            rawText: match.group(0) ?? '',
          );
        }
        return null;

      case ModifyField.date:
        final dateText = match.group(1);
        if (dateText != null) {
          final parsedDate = _parseRelativeDate(dateText);
          if (parsedDate != null) {
            return FieldModification(
              field: field,
              newValue: parsedDate,
              rawText: match.group(0) ?? '',
            );
          }
        }
        return null;

      case ModifyField.account:
        // 提取账户名
        for (var i = match.groupCount; i >= 1; i--) {
          final accountValue = match.group(i);
          if (accountValue != null && _knownAccounts.contains(accountValue)) {
            return FieldModification(
              field: field,
              newValue: accountValue,
              rawText: match.group(0) ?? '',
            );
          }
        }
        // 尝试最后一个捕获组
        final lastGroup = match.group(match.groupCount);
        if (lastGroup != null && lastGroup.isNotEmpty) {
          return FieldModification(
            field: field,
            newValue: lastGroup,
            rawText: match.group(0) ?? '',
          );
        }
        return null;

      case ModifyField.tags:
        final tagValue = match.group(1);
        if (tagValue != null) {
          final isRemove = originalText.contains('去掉') ||
              originalText.contains('删掉') ||
              originalText.contains('移掉');
          return FieldModification(
            field: field,
            newValue: tagValue,
            rawText: match.group(0) ?? '',
            metadata: {'action': isRemove ? 'remove' : 'add'},
          );
        }
        return null;

      case ModifyField.transactionType:
        final typeValue = match.group(match.groupCount) ?? match.group(1);
        if (typeValue != null) {
          return FieldModification(
            field: field,
            newValue: typeValue,
            rawText: match.group(0) ?? '',
          );
        }
        return null;
    }
  }

  /// 标准化分类名称
  String _normalizeCategory(String input) {
    final trimmed = input.trim();
    // 先检查是否是已知分类
    if (_knownCategories.contains(trimmed)) {
      return trimmed;
    }
    // 尝试模糊匹配
    for (final category in _knownCategories) {
      if (category.contains(trimmed) || trimmed.contains(category)) {
        return category;
      }
    }
    return trimmed;
  }

  /// 解析相对日期
  DateTime? _parseRelativeDate(String text) {
    final now = DateTime.now();

    if (text.contains('今天')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (text.contains('昨天')) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (text.contains('前天')) {
      return DateTime(now.year, now.month, now.day - 2);
    }
    if (text.contains('上周一')) {
      return now.subtract(Duration(days: now.weekday + 6));
    }
    if (text.contains('上周二')) {
      return now.subtract(Duration(days: now.weekday + 5));
    }
    if (text.contains('上周三')) {
      return now.subtract(Duration(days: now.weekday + 4));
    }
    if (text.contains('上周四')) {
      return now.subtract(Duration(days: now.weekday + 3));
    }
    if (text.contains('上周五')) {
      return now.subtract(Duration(days: now.weekday + 2));
    }
    if (text.contains('上周六')) {
      return now.subtract(Duration(days: now.weekday + 1));
    }
    if (text.contains('上周日') || text.contains('上周天')) {
      return now.subtract(Duration(days: now.weekday));
    }

    // 解析 "X月X日" 格式
    final dateMatch = RegExp(r'(\d+)月(\d+)[日号]').firstMatch(text);
    if (dateMatch != null) {
      final month = int.tryParse(dateMatch.group(1) ?? '');
      final day = int.tryParse(dateMatch.group(2) ?? '');
      if (month != null && day != null) {
        return DateTime(now.year, month, day);
      }
    }

    return null;
  }

  /// 判断是否是重大变更（需要确认）
  bool _isSignificantChange(
    TransactionRecord record,
    List<FieldModification> modifications,
  ) {
    final level = _determineConfirmLevel(record, modifications);
    // Level 2及以上需要确认
    return level.index >= ModifyConfirmLevel.level2.index;
  }

  /// 确定修改确认级别
  ///
  /// 参考删除服务的4级确认系统：
  /// - Level 1: 轻量确认（小额修改，24小时内记录）
  /// - Level 2: 标准确认（大额修改或历史记录）
  /// - Level 3: 严格确认（敏感操作，如类型变更）
  /// - Level 4: 禁止语音（必须手动操作）
  ModifyConfirmLevel _determineConfirmLevel(
    TransactionRecord record,
    List<FieldModification> modifications,
  ) {
    // 检查是否有敏感字段修改
    for (final mod in modifications) {
      // 类型变更（支出→收入等）始终需要严格确认
      if (mod.field == ModifyField.transactionType) {
        return ModifyConfirmLevel.level3;
      }
    }

    // 计算记录年龄
    final now = DateTime.now();
    final recordAge = now.difference(record.date);
    final isRecentRecord = recordAge.inHours < 24;

    // 检查金额相关变更
    for (final mod in modifications) {
      if (mod.field == ModifyField.amount) {
        final newAmount = mod.newValue as double;
        final diff = (newAmount - record.amount).abs();
        final changeRatio = record.amount > 0 ? diff / record.amount : 1.0;

        // 大额交易（新金额超过500元）需要标准确认
        if (newAmount >= 500) {
          return ModifyConfirmLevel.level2;
        }

        // 金额变化超过200元需要标准确认
        if (diff >= 200) {
          return ModifyConfirmLevel.level2;
        }

        // 金额变化超过50%且超过50元需要标准确认
        if (changeRatio > 0.5 && diff >= 50) {
          return ModifyConfirmLevel.level2;
        }

        // 历史记录（超过24小时）的金额修改需要标准确认
        if (!isRecentRecord && diff >= 20) {
          return ModifyConfirmLevel.level2;
        }
      }

      // 日期跨度超过7天需要标准确认
      if (mod.field == ModifyField.date) {
        final newDate = mod.newValue as DateTime;
        final dateDiff = newDate.difference(record.date).inDays.abs();
        if (dateDiff > 7) {
          return ModifyConfirmLevel.level2;
        }
      }
    }

    // 多字段修改需要标准确认
    if (modifications.length > 1) {
      return ModifyConfirmLevel.level2;
    }

    // 历史记录的任何修改需要轻量确认
    if (!isRecentRecord) {
      return ModifyConfirmLevel.level1;
    }

    // 小额近期记录的简单修改，无需确认
    return ModifyConfirmLevel.none;
  }

  /// 生成修改确认提示
  String _generateConfirmPrompt(
    TransactionRecord record,
    List<FieldModification> modifications,
    ModifyConfirmLevel level,
  ) {
    final description = record.description ?? record.category ?? '记录';
    final amountStr = '¥${record.amount.toStringAsFixed(2)}';

    switch (level) {
      case ModifyConfirmLevel.none:
        return '';

      case ModifyConfirmLevel.level1:
        // 轻量确认
        if (modifications.length == 1) {
          final mod = modifications.first;
          return '确认将$description的${mod.fieldName}改为${mod.displayValue}吗？';
        }
        return '确认修改$description $amountStr吗？';

      case ModifyConfirmLevel.level2:
        // 标准确认：强调金额或变更幅度
        if (modifications.any((m) => m.field == ModifyField.amount)) {
          final amountMod = modifications.firstWhere(
            (m) => m.field == ModifyField.amount,
          );
          return '这是一笔较大金额的修改。'
              '确定要将$description的金额从$amountStr改为${amountMod.displayValue}吗？';
        }
        return '这条记录已有一段时间。确定要修改$description $amountStr吗？';

      case ModifyConfirmLevel.level3:
        // 严格确认：敏感操作
        if (modifications.any((m) => m.field == ModifyField.transactionType)) {
          final typeMod = modifications.firstWhere(
            (m) => m.field == ModifyField.transactionType,
          );
          return '注意：您正在更改交易类型为${typeMod.newValue}，这可能影响统计。请确认此操作。';
        }
        return '这是一个敏感操作，请确认修改$description $amountStr。';

      case ModifyConfirmLevel.level4:
        return '此操作需要在屏幕上手动确认';
    }
  }

  /// 执行修改
  Future<ModifyResult> _executeModification(
    TransactionRecord record,
    List<FieldModification> modifications,
    TransactionUpdateCallback updateCallback, {
    bool needConfirmation = false,
  }) async {
    // 确定确认级别
    final confirmLevel = _determineConfirmLevel(record, modifications);

    // 构建修改预览
    final preview = ModifyPreview(
      originalRecord: record,
      modifications: modifications,
      previewRecord: _applyModifications(record, modifications),
    );

    // 根据确认级别决定是否需要确认
    final shouldConfirm = needConfirmation ||
        confirmLevel.index >= ModifyConfirmLevel.level2.index;

    if (shouldConfirm) {
      // 生成确认提示
      final confirmPrompt = _generateConfirmPrompt(
        record,
        modifications,
        confirmLevel,
      );

      // 保存待确认的修改
      _currentSession = ModifySessionContext(
        currentRecord: record,
        pendingModifications: modifications,
        confirmLevel: confirmLevel,
      );

      return ModifyResult.needConfirmation(
        preview: preview,
        confirmLevel: confirmLevel,
        confirmPrompt: confirmPrompt,
      );
    }

    // 直接执行修改
    return await _doExecuteModification(
      record,
      modifications,
      updateCallback,
    );
  }

  /// 确认并执行修改
  Future<ModifyResult> confirmModification(
    TransactionUpdateCallback updateCallback,
  ) async {
    if (_currentSession == null ||
        _currentSession!.currentRecord == null ||
        _currentSession!.pendingModifications == null) {
      return ModifyResult.error('没有待确认的修改');
    }

    final result = await _doExecuteModification(
      _currentSession!.currentRecord!,
      _currentSession!.pendingModifications!,
      updateCallback,
    );

    _currentSession = null;
    return result;
  }

  /// 取消修改
  void cancelModification() {
    _currentSession = null;
    notifyListeners();
  }

  /// 处理用户澄清选择
  Future<ModifyResult> handleClarificationSelection(
    String userInput,
    TransactionUpdateCallback updateCallback,
  ) async {
    if (_currentSession == null ||
        _currentSession!.candidateRecords == null ||
        _currentSession!.pendingModifications == null) {
      return ModifyResult.error('没有待选择的记录');
    }

    // 使用消歧服务处理用户选择
    final clarificationResult =
        await _disambiguationService.handleClarification(
      userInput,
      _currentSession!.candidateRecords!,
    );

    if (clarificationResult.isResolved && clarificationResult.resolvedRecord != null) {
      final record = clarificationResult.resolvedRecord!;
      final modifications = _currentSession!.pendingModifications!;

      // 清除会话
      _currentSession = null;

      // 检查是否需要确认（多字段修改或重大变更）
      final needConfirm = modifications.length > 1 ||
          _isSignificantChange(record, modifications);

      // 执行修改
      return await _executeModification(
        record,
        modifications,
        updateCallback,
        needConfirmation: needConfirm,
      );
    }

    return ModifyResult.needMoreInfo(
      prompt: clarificationResult.clarificationPrompt ?? '请重新选择',
    );
  }

  /// 实际执行修改操作
  Future<ModifyResult> _doExecuteModification(
    TransactionRecord record,
    List<FieldModification> modifications,
    TransactionUpdateCallback updateCallback,
  ) async {
    try {
      // 保存修改历史（用于撤销）
      final operation = ModifyOperation(
        recordId: record.id,
        originalRecord: record,
        modifications: modifications,
        timestamp: DateTime.now(),
      );
      _addToHistory(operation);

      // 应用修改
      final updatedRecord = _applyModifications(record, modifications);

      // 调用更新回调
      final success = await updateCallback(updatedRecord);

      if (success) {
        // 通知消歧服务记录最近操作
        _disambiguationService.recordRecentOperation(updatedRecord);

        return ModifyResult.success(
          originalRecord: record,
          updatedRecord: updatedRecord,
          modifications: modifications,
        );
      } else {
        // 回滚历史
        _modifyHistory.removeLast();
        return ModifyResult.error('更新记录失败');
      }
    } catch (e) {
      return ModifyResult.error('修改失败: $e');
    }
  }

  /// 应用修改到记录
  TransactionRecord _applyModifications(
    TransactionRecord record,
    List<FieldModification> modifications,
  ) {
    double amount = record.amount;
    String? category = record.category;
    String? subCategory = record.subCategory;
    String? description = record.description;
    DateTime date = record.date;
    String? account = record.account;
    List<String> tags = List.from(record.tags);
    String type = record.type;

    for (final mod in modifications) {
      switch (mod.field) {
        case ModifyField.amount:
          amount = mod.newValue as double;
          break;
        case ModifyField.category:
          category = mod.newValue as String;
          break;
        case ModifyField.subCategory:
          subCategory = mod.newValue as String;
          break;
        case ModifyField.description:
          description = mod.newValue as String;
          break;
        case ModifyField.date:
          date = mod.newValue as DateTime;
          break;
        case ModifyField.account:
          account = mod.newValue as String;
          break;
        case ModifyField.tags:
          final tagValue = mod.newValue as String;
          final action = mod.metadata?['action'] as String? ?? 'add';
          if (action == 'remove') {
            tags.remove(tagValue);
          } else {
            if (!tags.contains(tagValue)) {
              tags.add(tagValue);
            }
          }
          break;
        case ModifyField.transactionType:
          type = mod.newValue as String;
          break;
      }
    }

    return TransactionRecord(
      id: record.id,
      amount: amount,
      category: category,
      subCategory: subCategory,
      merchant: record.merchant,
      description: description,
      date: date,
      account: account,
      tags: tags,
      type: type,
    );
  }

  /// 添加到历史记录
  void _addToHistory(ModifyOperation operation) {
    _modifyHistory.add(operation);
    if (_modifyHistory.length > maxHistorySize) {
      _modifyHistory.removeAt(0);
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // 撤销功能
  // ═══════════════════════════════════════════════════════════════

  /// 获取最近的修改操作
  ModifyOperation? getLastModification() {
    return _modifyHistory.isNotEmpty ? _modifyHistory.last : null;
  }

  /// 获取修改历史
  List<ModifyOperation> getModifyHistory({int limit = 10}) {
    final start =
        _modifyHistory.length > limit ? _modifyHistory.length - limit : 0;
    return _modifyHistory.sublist(start).reversed.toList();
  }

  /// 清除当前会话
  void clearSession() {
    _currentSession = null;
    notifyListeners();
  }

  /// 当前是否有待处理的修改
  bool get hasPendingModification => _currentSession != null;

  /// 释放资源
  @override
  void dispose() {
    _currentSession = null;
    _modifyHistory.clear();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据类型定义
// ═══════════════════════════════════════════════════════════════

/// 可修改的字段
enum ModifyField {
  amount, // 金额
  category, // 分类
  subCategory, // 子分类
  description, // 备注/描述
  date, // 日期
  account, // 账户
  tags, // 标签
  transactionType, // 交易类型
}

/// 修改确认级别
///
/// 参考删除服务的4级确认系统，用于控制修改操作的确认流程
enum ModifyConfirmLevel {
  none, // 无需确认：小额近期记录的简单修改
  level1, // 轻量确认：语音确认即可（历史记录的小额修改）
  level2, // 标准确认：语音或屏幕确认（大额修改、多字段修改）
  level3, // 严格确认：必须屏幕点击（类型变更等敏感操作）
  level4, // 禁止语音：必须手动操作（批量修改等高风险操作）
}

/// 字段修改
class FieldModification {
  final ModifyField field;
  final dynamic newValue;
  final String rawText;
  final Map<String, dynamic>? metadata;

  const FieldModification({
    required this.field,
    required this.newValue,
    required this.rawText,
    this.metadata,
  });

  String get fieldName {
    switch (field) {
      case ModifyField.amount:
        return '金额';
      case ModifyField.category:
        return '分类';
      case ModifyField.subCategory:
        return '子分类';
      case ModifyField.description:
        return '备注';
      case ModifyField.date:
        return '日期';
      case ModifyField.account:
        return '账户';
      case ModifyField.tags:
        return '标签';
      case ModifyField.transactionType:
        return '类型';
    }
  }

  String get displayValue {
    if (field == ModifyField.amount) {
      return '¥${(newValue as double).toStringAsFixed(2)}';
    }
    if (field == ModifyField.date) {
      final date = newValue as DateTime;
      return '${date.month}月${date.day}日';
    }
    return newValue.toString();
  }
}

/// 修改操作记录
class ModifyOperation {
  final String recordId;
  final TransactionRecord originalRecord;
  final List<FieldModification> modifications;
  final DateTime timestamp;

  const ModifyOperation({
    required this.recordId,
    required this.originalRecord,
    required this.modifications,
    required this.timestamp,
  });
}

/// 修改预览
class ModifyPreview {
  final TransactionRecord originalRecord;
  final List<FieldModification> modifications;
  final TransactionRecord previewRecord;

  const ModifyPreview({
    required this.originalRecord,
    required this.modifications,
    required this.previewRecord,
  });

  /// 生成预览文本
  String generatePreviewText() {
    final buffer = StringBuffer();
    buffer.writeln('原记录: ${originalRecord.description ?? originalRecord.category} '
        '¥${originalRecord.amount.toStringAsFixed(2)}');
    buffer.write('修改为: ');

    final changes = <String>[];
    for (final mod in modifications) {
      changes.add('${mod.fieldName}=${mod.displayValue}');
    }
    buffer.write(changes.join(', '));

    return buffer.toString();
  }
}

/// 修改会话上下文
class ModifySessionContext {
  final TransactionRecord? currentRecord;
  final List<FieldModification>? pendingModifications;
  final List<ScoredCandidate>? candidateRecords;
  final String? clarificationPrompt;
  final ModifyConfirmLevel? confirmLevel;

  const ModifySessionContext({
    this.currentRecord,
    this.pendingModifications,
    this.candidateRecords,
    this.clarificationPrompt,
    this.confirmLevel,
  });

  DisambiguationContext? toDisambiguationContext() {
    if (currentRecord == null) return null;
    return DisambiguationContext(
      lastMentionedRecordId: currentRecord!.id,
    );
  }
}

/// 修改结果
class ModifyResult {
  final ModifyResultStatus status;
  final TransactionRecord? originalRecord;
  final TransactionRecord? updatedRecord;
  final List<FieldModification>? modifications;
  final ModifyPreview? preview;
  final List<ScoredCandidate>? candidates;
  final String? prompt;
  final String? errorMessage;
  final ModifyConfirmLevel? confirmLevel;
  final String? confirmPrompt;

  const ModifyResult({
    required this.status,
    this.originalRecord,
    this.updatedRecord,
    this.modifications,
    this.preview,
    this.candidates,
    this.prompt,
    this.errorMessage,
    this.confirmLevel,
    this.confirmPrompt,
  });

  factory ModifyResult.success({
    required TransactionRecord originalRecord,
    required TransactionRecord updatedRecord,
    required List<FieldModification> modifications,
  }) {
    return ModifyResult(
      status: ModifyResultStatus.success,
      originalRecord: originalRecord,
      updatedRecord: updatedRecord,
      modifications: modifications,
    );
  }

  factory ModifyResult.needConfirmation({
    required ModifyPreview preview,
    ModifyConfirmLevel? confirmLevel,
    String? confirmPrompt,
  }) {
    return ModifyResult(
      status: ModifyResultStatus.needConfirmation,
      preview: preview,
      confirmLevel: confirmLevel,
      confirmPrompt: confirmPrompt,
    );
  }

  factory ModifyResult.needClarification({
    required List<ScoredCandidate> candidates,
    required String prompt,
    required List<FieldModification> modifications,
  }) {
    return ModifyResult(
      status: ModifyResultStatus.needClarification,
      candidates: candidates,
      prompt: prompt,
      modifications: modifications,
    );
  }

  factory ModifyResult.needMoreInfo({required String prompt}) {
    return ModifyResult(
      status: ModifyResultStatus.needMoreInfo,
      prompt: prompt,
    );
  }

  factory ModifyResult.noModificationDetected() {
    return const ModifyResult(
      status: ModifyResultStatus.noModificationDetected,
    );
  }

  factory ModifyResult.noTargetSpecified() {
    return const ModifyResult(
      status: ModifyResultStatus.noTargetSpecified,
      prompt: '请说明要修改哪条记录，比如"刚才那笔"或"昨天的午餐"',
    );
  }

  factory ModifyResult.noRecordFound(List<DetectedReference> references) {
    return const ModifyResult(
      status: ModifyResultStatus.noRecordFound,
      prompt: '没有找到匹配的记录，请提供更多信息',
    );
  }

  factory ModifyResult.error(String message) {
    return ModifyResult(
      status: ModifyResultStatus.error,
      errorMessage: message,
    );
  }

  bool get isSuccess => status == ModifyResultStatus.success;
  bool get needsConfirmation => status == ModifyResultStatus.needConfirmation;
  bool get needsClarification => status == ModifyResultStatus.needClarification;
  bool get needsMoreInfo => status == ModifyResultStatus.needMoreInfo;
  bool get isError => status == ModifyResultStatus.error;

  /// 生成语音反馈文本
  String generateFeedbackText() {
    switch (status) {
      case ModifyResultStatus.success:
        if (modifications != null && modifications!.length == 1) {
          final mod = modifications!.first;
          return '好的，已将${mod.fieldName}改为${mod.displayValue}';
        }
        return '修改完成';

      case ModifyResultStatus.needConfirmation:
        // 优先使用带确认级别的提示
        if (confirmPrompt != null && confirmPrompt!.isNotEmpty) {
          return confirmPrompt!;
        }
        return '确认${preview?.generatePreviewText() ?? "修改"}吗？';

      case ModifyResultStatus.needClarification:
        return prompt ?? '请选择要修改的记录';

      case ModifyResultStatus.needMoreInfo:
        return prompt ?? '请提供更多信息';

      case ModifyResultStatus.noModificationDetected:
        return '没有检测到修改内容，您想修改什么？';

      case ModifyResultStatus.noTargetSpecified:
        return prompt ?? '请说明要修改哪条记录';

      case ModifyResultStatus.noRecordFound:
        return prompt ?? '没有找到匹配的记录';

      case ModifyResultStatus.error:
        return errorMessage ?? '修改失败';
    }
  }

  /// 是否需要屏幕确认（严格级别及以上）
  bool get requiresScreenConfirmation =>
      confirmLevel != null &&
      confirmLevel!.index >= ModifyConfirmLevel.level3.index;
}

/// 修改结果状态
enum ModifyResultStatus {
  success, // 修改成功
  needConfirmation, // 需要确认
  needClarification, // 需要澄清选择
  needMoreInfo, // 需要更多信息
  noModificationDetected, // 未检测到修改意图
  noTargetSpecified, // 未指定目标记录
  noRecordFound, // 未找到记录
  error, // 错误
}

/// 交易更新回调
typedef TransactionUpdateCallback = Future<bool> Function(
    TransactionRecord record);
