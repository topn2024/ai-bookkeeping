/// 安全确认服务
///
/// 为语音操作提供分级确认机制，保护用户数据安全
///
/// 确认级别：
/// - Level 1: 轻量确认（语音确认即可）- 单笔小额，24小时内
/// - Level 2: 标准确认（语音或屏幕确认）- 大额或历史记录
/// - Level 3: 严格确认（必须屏幕点击）- 批量操作
/// - Level 4: 禁止语音（必须手动操作）- 高风险操作
library;

import 'package:flutter/foundation.dart';
import '../entity_disambiguation_service.dart';

/// 确认级别
enum ConfirmationLevel {
  /// Level 0: 无需确认
  none,

  /// Level 1: 轻量确认（语音确认即可）
  /// 适用于：单笔小额（<100元），24小时内的记录
  light,

  /// Level 2: 标准确认（语音或屏幕确认）
  /// 适用于：大额（≥100元）或历史记录
  standard,

  /// Level 3: 严格确认（必须屏幕点击）
  /// 适用于：批量删除（≥2笔），敏感操作
  strict,

  /// Level 4: 禁止语音（必须手动操作）
  /// 适用于：清空回收站、删除账本等高风险操作
  voiceProhibited,
}

/// 确认结果
class ConfirmationResult {
  /// 确认级别
  final ConfirmationLevel level;

  /// 是否允许通过语音确认
  final bool allowVoiceConfirm;

  /// 是否需要屏幕确认
  final bool requireScreenConfirm;

  /// 确认提示消息
  final String confirmPrompt;

  /// 是否被阻止（Level 4）
  final bool isBlocked;

  /// 阻止原因
  final String? blockReason;

  /// 重定向路由（被阻止时）
  final String? redirectRoute;

  /// 附加数据
  final Map<String, dynamic>? data;

  const ConfirmationResult({
    required this.level,
    required this.allowVoiceConfirm,
    required this.requireScreenConfirm,
    required this.confirmPrompt,
    this.isBlocked = false,
    this.blockReason,
    this.redirectRoute,
    this.data,
  });

  /// 创建无需确认的结果
  factory ConfirmationResult.noConfirmNeeded() {
    return const ConfirmationResult(
      level: ConfirmationLevel.none,
      allowVoiceConfirm: true,
      requireScreenConfirm: false,
      confirmPrompt: '',
    );
  }

  /// 创建轻量确认结果
  factory ConfirmationResult.light({
    required String prompt,
    Map<String, dynamic>? data,
  }) {
    return ConfirmationResult(
      level: ConfirmationLevel.light,
      allowVoiceConfirm: true,
      requireScreenConfirm: false,
      confirmPrompt: prompt,
      data: data,
    );
  }

  /// 创建标准确认结果
  factory ConfirmationResult.standard({
    required String prompt,
    Map<String, dynamic>? data,
  }) {
    return ConfirmationResult(
      level: ConfirmationLevel.standard,
      allowVoiceConfirm: true,
      requireScreenConfirm: true,
      confirmPrompt: prompt,
      data: data,
    );
  }

  /// 创建严格确认结果
  factory ConfirmationResult.strict({
    required String prompt,
    Map<String, dynamic>? data,
  }) {
    return ConfirmationResult(
      level: ConfirmationLevel.strict,
      allowVoiceConfirm: false,
      requireScreenConfirm: true,
      confirmPrompt: prompt,
      data: data,
    );
  }

  /// 创建禁止语音的结果
  factory ConfirmationResult.blocked({
    required String reason,
    required String redirectRoute,
  }) {
    return ConfirmationResult(
      level: ConfirmationLevel.voiceProhibited,
      allowVoiceConfirm: false,
      requireScreenConfirm: false,
      confirmPrompt: reason,
      isBlocked: true,
      blockReason: reason,
      redirectRoute: redirectRoute,
    );
  }
}

/// 安全确认服务
class SafetyConfirmationService {
  /// 高风险操作模式（Level 4 - 禁止语音执行）
  static final List<RegExp> _highRiskPatterns = [
    RegExp(r'清空回收站'),
    RegExp(r'删除账本'),
    RegExp(r'删除账户'),
    RegExp(r'删除所有数据'),
    RegExp(r'清除全部'),
    RegExp(r'重置'),
    RegExp(r'清空全部'),
    RegExp(r'删除全部'),
  ];

  /// 批量删除模式（Level 3 - 严格确认）
  static final List<RegExp> _batchDeletePatterns = [
    RegExp(r'删[除掉]?(所有|全部|这些)(.{1,10}?)'),
    RegExp(r'删[除掉]?(今天|昨天|上周|本月|上月)(所有|全部)?(.{1,10}?)?'),
    RegExp(r'清空(.{1,10}?)'),
    RegExp(r'批量删[除掉]?'),
  ];

  /// 小金额阈值（元）
  static const double _smallAmountThreshold = 100.0;

  /// 大金额阈值（元）
  static const double _largeAmountThreshold = 500.0;

  /// 近期记录时间阈值（小时）
  static const int _recentHoursThreshold = 24;

  SafetyConfirmationService();

  // ═══════════════════════════════════════════════════════════════
  // 删除操作确认
  // ═══════════════════════════════════════════════════════════════

  /// 评估删除操作的确认级别
  ///
  /// [userInput] 用户输入文本
  /// [records] 待删除的记录列表
  /// Returns 确认结果
  ConfirmationResult evaluateDeleteConfirmation(
    String userInput,
    List<TransactionRecord> records,
  ) {
    debugPrint('[SafetyConfirmation] 评估删除确认: ${records.length}条记录');

    // 1. 检查高风险操作（Level 4）
    if (_isHighRiskOperation(userInput)) {
      final route = _getHighRiskRedirectRoute(userInput);
      debugPrint('[SafetyConfirmation] 高风险操作，禁止语音执行');
      return ConfirmationResult.blocked(
        reason: '这是高风险操作，无法通过语音完成。请在设置中手动操作。',
        redirectRoute: route,
      );
    }

    // 2. 检查批量删除（Level 3）
    if (_isBatchDelete(userInput) || records.length >= 2) {
      final totalAmount = records.fold<double>(0, (sum, r) => sum + r.amount);
      debugPrint('[SafetyConfirmation] 批量删除，需要屏幕确认');
      return ConfirmationResult.strict(
        prompt: '检测到批量删除请求。共${records.length}笔记录，'
            '总计¥${totalAmount.toStringAsFixed(2)}。\n'
            '批量删除需要在屏幕上确认，请点击确认按钮。',
        data: {
          'recordCount': records.length,
          'totalAmount': totalAmount,
          'isBatch': true,
        },
      );
    }

    // 3. 单条记录的确认级别评估
    if (records.isEmpty) {
      return ConfirmationResult.noConfirmNeeded();
    }

    final record = records.first;
    final level = _determineSingleDeleteLevel(record);

    switch (level) {
      case ConfirmationLevel.none:
        return ConfirmationResult.noConfirmNeeded();

      case ConfirmationLevel.light:
        return ConfirmationResult.light(
          prompt: '确定删除${record.description ?? record.category}'
              '¥${record.amount.toStringAsFixed(2)}吗？说"确认"或"取消"',
          data: {'recordId': record.id, 'amount': record.amount},
        );

      case ConfirmationLevel.standard:
        return ConfirmationResult.standard(
          prompt: '这是一笔较大金额的历史记录。'
              '确定要删除${record.description ?? record.category}'
              '¥${record.amount.toStringAsFixed(2)}吗？',
          data: {'recordId': record.id, 'amount': record.amount},
        );

      default:
        return ConfirmationResult.light(
          prompt: '确定删除这条记录吗？',
        );
    }
  }

  /// 检测是否是高风险操作
  bool _isHighRiskOperation(String text) {
    return _highRiskPatterns.any((p) => p.hasMatch(text));
  }

  /// 检测是否是批量删除
  bool _isBatchDelete(String text) {
    return _batchDeletePatterns.any((p) => p.hasMatch(text));
  }

  /// 获取高风险操作重定向路由
  String _getHighRiskRedirectRoute(String text) {
    if (text.contains('回收站')) return '/recycle-bin';
    if (text.contains('账本')) return '/ledger-settings';
    if (text.contains('账户')) return '/account-settings';
    return '/settings';
  }

  /// 确定单条删除的确认级别
  ConfirmationLevel _determineSingleDeleteLevel(TransactionRecord record) {
    final now = DateTime.now();
    final recordAge = now.difference(record.date);
    final isRecentRecord = recordAge.inHours < _recentHoursThreshold;

    // 小额近期记录：Level 1
    if (record.amount < _smallAmountThreshold && isRecentRecord) {
      debugPrint('[SafetyConfirmation] 小额近期记录，轻量确认');
      return ConfirmationLevel.light;
    }

    // 大额或历史记录：Level 2
    debugPrint('[SafetyConfirmation] 大额或历史记录，标准确认');
    return ConfirmationLevel.standard;
  }

  // ═══════════════════════════════════════════════════════════════
  // 修改操作确认
  // ═══════════════════════════════════════════════════════════════

  /// 评估修改操作的确认级别
  ///
  /// [record] 原始记录
  /// [modifications] 修改内容
  /// Returns 确认结果
  ConfirmationResult evaluateModifyConfirmation(
    TransactionRecord record,
    Map<String, dynamic> modifications,
  ) {
    debugPrint('[SafetyConfirmation] 评估修改确认: ${modifications.keys.join(", ")}');

    final level = _determineModifyLevel(record, modifications);

    switch (level) {
      case ConfirmationLevel.none:
        return ConfirmationResult.noConfirmNeeded();

      case ConfirmationLevel.light:
        return ConfirmationResult.light(
          prompt: _generateModifyPrompt(record, modifications, level),
          data: {
            'recordId': record.id,
            'modifications': modifications,
          },
        );

      case ConfirmationLevel.standard:
        return ConfirmationResult.standard(
          prompt: _generateModifyPrompt(record, modifications, level),
          data: {
            'recordId': record.id,
            'modifications': modifications,
          },
        );

      case ConfirmationLevel.strict:
        return ConfirmationResult.strict(
          prompt: _generateModifyPrompt(record, modifications, level),
          data: {
            'recordId': record.id,
            'modifications': modifications,
          },
        );

      case ConfirmationLevel.voiceProhibited:
        return ConfirmationResult.blocked(
          reason: '此操作需要在屏幕上手动确认',
          redirectRoute: '/transaction/${record.id}',
        );
    }
  }

  /// 确定修改操作的确认级别
  ConfirmationLevel _determineModifyLevel(
    TransactionRecord record,
    Map<String, dynamic> modifications,
  ) {
    // 类型变更（支出→收入等）始终需要严格确认
    if (modifications.containsKey('transactionType')) {
      debugPrint('[SafetyConfirmation] 类型变更，严格确认');
      return ConfirmationLevel.strict;
    }

    final now = DateTime.now();
    final recordAge = now.difference(record.date);
    final isRecentRecord = recordAge.inHours < _recentHoursThreshold;

    // 检查金额变更
    if (modifications.containsKey('amount')) {
      final newAmount = (modifications['amount'] as num).toDouble();
      final diff = (newAmount - record.amount).abs();
      final changeRatio = record.amount > 0 ? diff / record.amount : 1.0;

      // 大额交易（新金额超过500元）需要标准确认
      if (newAmount >= _largeAmountThreshold) {
        debugPrint('[SafetyConfirmation] 大额修改，标准确认');
        return ConfirmationLevel.standard;
      }

      // 金额变化超过200元需要标准确认
      if (diff >= 200) {
        debugPrint('[SafetyConfirmation] 大幅金额变更，标准确认');
        return ConfirmationLevel.standard;
      }

      // 金额变化超过50%且超过50元需要标准确认
      if (changeRatio > 0.5 && diff >= 50) {
        debugPrint('[SafetyConfirmation] 金额变更超过50%，标准确认');
        return ConfirmationLevel.standard;
      }

      // 历史记录（超过24小时）的金额修改需要标准确认
      if (!isRecentRecord && diff >= 20) {
        debugPrint('[SafetyConfirmation] 历史记录金额修改，标准确认');
        return ConfirmationLevel.standard;
      }
    }

    // 日期跨度超过7天需要标准确认
    if (modifications.containsKey('date')) {
      final newDate = modifications['date'] is DateTime
          ? modifications['date'] as DateTime
          : DateTime.parse(modifications['date'].toString());
      final dateDiff = newDate.difference(record.date).inDays.abs();
      if (dateDiff > 7) {
        debugPrint('[SafetyConfirmation] 日期跨度大，标准确认');
        return ConfirmationLevel.standard;
      }
    }

    // 多字段修改需要标准确认
    if (modifications.length > 1) {
      debugPrint('[SafetyConfirmation] 多字段修改，标准确认');
      return ConfirmationLevel.standard;
    }

    // 历史记录的任何修改需要轻量确认
    if (!isRecentRecord) {
      debugPrint('[SafetyConfirmation] 历史记录修改，轻量确认');
      return ConfirmationLevel.light;
    }

    // 小额近期记录的简单修改，无需确认
    debugPrint('[SafetyConfirmation] 简单修改，无需确认');
    return ConfirmationLevel.none;
  }

  /// 生成修改确认提示
  String _generateModifyPrompt(
    TransactionRecord record,
    Map<String, dynamic> modifications,
    ConfirmationLevel level,
  ) {
    final description = record.description ?? record.category ?? '记录';
    final amountStr = '¥${record.amount.toStringAsFixed(2)}';

    switch (level) {
      case ConfirmationLevel.none:
        return '';

      case ConfirmationLevel.light:
        // 轻量确认
        if (modifications.length == 1) {
          final entry = modifications.entries.first;
          return '确认将$description的${_getFieldName(entry.key)}改为${_formatValue(entry.key, entry.value)}吗？';
        }
        return '确认修改$description $amountStr吗？';

      case ConfirmationLevel.standard:
        // 标准确认：强调金额或变更幅度
        if (modifications.containsKey('amount')) {
          final newAmount = modifications['amount'];
          return '这是一笔较大金额的修改。'
              '确定要将$description的金额从$amountStr改为¥${(newAmount as num).toStringAsFixed(2)}吗？';
        }
        return '这条记录已有一段时间。确定要修改$description $amountStr吗？';

      case ConfirmationLevel.strict:
        // 严格确认：敏感操作
        if (modifications.containsKey('transactionType')) {
          final newType = modifications['transactionType'];
          return '注意：您正在更改交易类型为$newType，这可能影响统计。请在屏幕上确认此操作。';
        }
        return '这是一个敏感操作，请在屏幕上确认修改$description $amountStr。';

      case ConfirmationLevel.voiceProhibited:
        return '此操作需要在屏幕上手动确认';
    }
  }

  /// 获取字段中文名
  String _getFieldName(String field) {
    const fieldNames = {
      'amount': '金额',
      'category': '分类',
      'subCategory': '子分类',
      'description': '备注',
      'note': '备注',
      'date': '日期',
      'account': '账户',
      'tags': '标签',
      'transactionType': '类型',
      'type': '类型',
      'merchant': '商家',
    };
    return fieldNames[field] ?? field;
  }

  /// 格式化值显示
  String _formatValue(String field, dynamic value) {
    if (field == 'amount' && value is num) {
      return '¥${value.toStringAsFixed(2)}';
    }
    if (field == 'date' && value is DateTime) {
      return '${value.month}月${value.day}日';
    }
    return value.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // 确认词检测
  // ═══════════════════════════════════════════════════════════════

  /// 检查是否是确认词
  bool isConfirmation(String text) {
    const confirmWords = [
      '确认',
      '确定',
      '是的',
      '好的',
      '删除',
      '删吧',
      '改吧',
      '可以',
      '没问题',
      '对',
      'yes',
      'ok',
    ];
    final lowerText = text.toLowerCase();
    return confirmWords.any((w) => lowerText.contains(w));
  }

  /// 检查是否是取消词
  bool isCancellation(String text) {
    const cancelWords = [
      '取消',
      '不要',
      '算了',
      '不删',
      '别删',
      '不改',
      '别改',
      '放弃',
      'no',
      'cancel',
    ];
    final lowerText = text.toLowerCase();
    return cancelWords.any((w) => lowerText.contains(w));
  }

  /// 检查确认级别是否允许语音确认
  bool canConfirmByVoice(ConfirmationLevel level) {
    return level == ConfirmationLevel.none ||
        level == ConfirmationLevel.light ||
        level == ConfirmationLevel.standard;
  }
}

/// 支持的修改字段
class ModifyFields {
  /// 金额
  static const String amount = 'amount';

  /// 分类
  static const String category = 'category';

  /// 子分类
  static const String subCategory = 'subCategory';

  /// 备注/描述
  static const String description = 'description';

  /// 日期
  static const String date = 'date';

  /// 账户
  static const String account = 'account';

  /// 标签
  static const String tags = 'tags';

  /// 交易类型
  static const String transactionType = 'transactionType';

  /// 所有支持的字段
  static const List<String> all = [
    amount,
    category,
    subCategory,
    description,
    date,
    account,
    tags,
    transactionType,
  ];

  /// 检查是否是有效字段
  static bool isValid(String field) => all.contains(field);

  /// 获取字段中文名
  static String getName(String field) {
    const names = {
      amount: '金额',
      category: '分类',
      subCategory: '子分类',
      description: '备注',
      date: '日期',
      account: '账户',
      tags: '标签',
      transactionType: '类型',
    };
    return names[field] ?? field;
  }
}
