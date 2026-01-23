import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 频率检查结果类型
enum FrequencyCheckResultType {
  /// 正常通过
  ok,

  /// 重复输入（已处理过）
  duplicate,

  /// 被节流（请求过于频繁）
  throttled,

  /// 批量模式（有效的批量操作）
  batchMode,

  /// 建议使用UI（多次修改同一笔）
  suggestUI,
}

/// 频率检查结果
class FrequencyCheckResult {
  /// 结果类型
  final FrequencyCheckResultType type;

  /// 响应文本（如果需要）
  final String? response;

  /// 冷却时间（秒）
  final int? cooldownSeconds;

  /// 建议的操作
  final dynamic suggestedAction;

  const FrequencyCheckResult._({
    required this.type,
    this.response,
    this.cooldownSeconds,
    this.suggestedAction,
  });

  /// 正常通过
  factory FrequencyCheckResult.ok() => const FrequencyCheckResult._(
        type: FrequencyCheckResultType.ok,
      );

  /// 重复输入
  factory FrequencyCheckResult.duplicate({required String response}) =>
      FrequencyCheckResult._(
        type: FrequencyCheckResultType.duplicate,
        response: response,
      );

  /// 被节流
  factory FrequencyCheckResult.throttled({
    required String response,
    required int cooldownSeconds,
  }) =>
      FrequencyCheckResult._(
        type: FrequencyCheckResultType.throttled,
        response: response,
        cooldownSeconds: cooldownSeconds,
      );

  /// 批量模式
  factory FrequencyCheckResult.batchMode({required String response}) =>
      FrequencyCheckResult._(
        type: FrequencyCheckResultType.batchMode,
        response: response,
      );

  /// 建议使用UI
  factory FrequencyCheckResult.suggestUI({
    required String response,
    dynamic action,
  }) =>
      FrequencyCheckResult._(
        type: FrequencyCheckResultType.suggestUI,
        response: response,
        suggestedAction: action,
      );

  /// 是否通过
  bool get isOk => type == FrequencyCheckResultType.ok;
}

/// 输入记录
class _InputRecord {
  final String normalizedInput;
  final DateTime timestamp;
  final String? recordId; // 关联的记录ID（如果有）

  const _InputRecord({
    required this.normalizedInput,
    required this.timestamp,
    this.recordId,
  });
}

/// 频率限制器
///
/// 基于设计文档18.12.5.2实现高频重复输入处理
class FrequencyLimiter {
  /// 输入历史（按标准化输入分组）
  final Map<String, List<DateTime>> _inputHistory = {};

  /// 所有输入记录
  final Queue<_InputRecord> _allInputs = Queue();

  /// 记录修改历史（按记录ID分组）
  final Map<String, List<DateTime>> _modificationHistory = {};

  /// 每分钟最大请求数
  static const int _maxRequestsPerMinute = 20;

  /// 重复检测窗口（秒）
  static const Duration _duplicateWindow = Duration(seconds: 3);

  /// 频率检测窗口
  static const Duration _frequencyWindow = Duration(minutes: 1);

  /// 修改检测窗口
  static const Duration _modificationWindow = Duration(minutes: 2);

  /// 修改次数阈值
  static const int _modificationThreshold = 3;

  /// 冷却结束时间（如果正在冷却）
  DateTime? _cooldownUntil;

  // ==================== 公共API ====================

  /// 综合检查所有频率限制
  ///
  /// 返回第一个不通过的检查结果，或者返回ok
  FrequencyCheckResult checkAll(
    String input, {
    String? recordId,
    bool isModification = false,
  }) {
    // 检查是否在冷却期
    if (_isInCooldown()) {
      final remaining = _cooldownUntil!.difference(DateTime.now()).inSeconds;
      return FrequencyCheckResult.throttled(
        response: '稍等一下，${remaining}秒后再试',
        cooldownSeconds: remaining,
      );
    }

    final normalizedInput = _normalizeInput(input);

    // 场景1: 检查重复输入
    final duplicateResult = checkDuplicateInput(normalizedInput);
    if (!duplicateResult.isOk) {
      return duplicateResult;
    }

    // 场景2: 检查高频请求
    final frequencyResult = checkHighFrequency();
    if (!frequencyResult.isOk) {
      return frequencyResult;
    }

    // 场景3: 检查重复修改
    if (isModification && recordId != null) {
      final modificationResult = checkRepeatedModification(recordId);
      if (!modificationResult.isOk) {
        return modificationResult;
      }
    }

    // 记录本次输入
    _recordInput(normalizedInput, recordId: recordId);

    return FrequencyCheckResult.ok();
  }

  /// 场景1: 快速重复相同指令（3秒内）
  FrequencyCheckResult checkDuplicateInput(String normalizedInput) {
    final history = _inputHistory[normalizedInput];
    if (history == null || history.isEmpty) {
      return FrequencyCheckResult.ok();
    }

    final now = DateTime.now();
    final recentDuplicates = history.where(
      (t) => now.difference(t) < _duplicateWindow,
    );

    if (recentDuplicates.isNotEmpty) {
      debugPrint('[FrequencyLimiter] 检测到重复输入: $normalizedInput');
      return FrequencyCheckResult.duplicate(
        response: '收到了，正在处理～',
      );
    }

    return FrequencyCheckResult.ok();
  }

  /// 场景2: 短时间大量不同请求（1分钟超过20次）
  FrequencyCheckResult checkHighFrequency() {
    final now = DateTime.now();
    final recentInputs = _allInputs.where(
      (r) => now.difference(r.timestamp) < _frequencyWindow,
    );

    if (recentInputs.length > _maxRequestsPerMinute) {
      // 检查是否为有效批量记账
      if (_isValidBatchBookkeeping(recentInputs.toList())) {
        return FrequencyCheckResult.batchMode(
          response: '已批量记入${recentInputs.length}笔',
        );
      }

      // 可能是乱输入或攻击，启动冷却
      _cooldownUntil = now.add(const Duration(seconds: 30));
      debugPrint('[FrequencyLimiter] 高频请求，启动30秒冷却');

      return FrequencyCheckResult.throttled(
        response: '请求太频繁了，慢点来～',
        cooldownSeconds: 30,
      );
    }

    return FrequencyCheckResult.ok();
  }

  /// 场景3: 来回修改同一笔记录（短时间超过3次）
  FrequencyCheckResult checkRepeatedModification(String recordId) {
    final history = _modificationHistory[recordId];
    if (history == null || history.isEmpty) {
      return FrequencyCheckResult.ok();
    }

    final now = DateTime.now();
    final recentModifications = history.where(
      (t) => now.difference(t) < _modificationWindow,
    );

    if (recentModifications.length >= _modificationThreshold) {
      debugPrint('[FrequencyLimiter] 重复修改检测: $recordId');
      return FrequencyCheckResult.suggestUI(
        response: '改了好几次了，要不我显示出来你直接改？',
        action: ShowEditUIAction(recordId: recordId),
      );
    }

    return FrequencyCheckResult.ok();
  }

  /// 记录修改操作
  void recordModification(String recordId) {
    final now = DateTime.now();
    _modificationHistory.putIfAbsent(recordId, () => []);
    _modificationHistory[recordId]!.add(now);

    // 清理过期记录
    _cleanupModificationHistory();
  }

  /// 重置冷却状态
  void resetCooldown() {
    _cooldownUntil = null;
  }

  /// 清空所有历史
  void clear() {
    _inputHistory.clear();
    _allInputs.clear();
    _modificationHistory.clear();
    _cooldownUntil = null;
  }

  // ==================== 内部方法 ====================

  /// 检查是否在冷却期
  bool _isInCooldown() {
    if (_cooldownUntil == null) return false;
    if (DateTime.now().isAfter(_cooldownUntil!)) {
      _cooldownUntil = null;
      return false;
    }
    return true;
  }

  /// 标准化输入（去除空格、标点，转小写）
  String _normalizeInput(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\.,!?，。！？、]'), '')
        .trim();
  }

  /// 记录输入
  void _recordInput(String normalizedInput, {String? recordId}) {
    final now = DateTime.now();

    // 记录到分组历史
    _inputHistory.putIfAbsent(normalizedInput, () => []);
    _inputHistory[normalizedInput]!.add(now);

    // 记录到总历史
    _allInputs.add(_InputRecord(
      normalizedInput: normalizedInput,
      timestamp: now,
      recordId: recordId,
    ));

    // 定期清理过期记录
    _cleanupHistory();
  }

  /// 检查是否为有效批量记账
  bool _isValidBatchBookkeeping(List<_InputRecord> inputs) {
    // 有效批量记账的特征：
    // 1. 输入内容各不相同
    // 2. 符合记账格式（包含金额、分类等）
    // 3. 间隔时间较为均匀（非机器人攻击）

    final uniqueInputs = inputs.map((r) => r.normalizedInput).toSet();
    if (uniqueInputs.length < inputs.length * 0.8) {
      // 重复率超过20%，不是有效批量
      return false;
    }

    // 检查是否符合记账格式（包含金额关键词）
    final bookkeepingPatterns = [
      RegExp(r'\d+'), // 包含数字
      RegExp(r'(块|元|￥|\$)'), // 货币单位
      RegExp(r'(花|买|吃|喝|打车|外卖|早餐|午餐|晚餐)'), // 常见记账动词
    ];

    var matchCount = 0;
    for (final input in inputs) {
      for (final pattern in bookkeepingPatterns) {
        if (pattern.hasMatch(input.normalizedInput)) {
          matchCount++;
          break;
        }
      }
    }

    // 至少80%的输入符合记账格式
    if (matchCount < inputs.length * 0.8) {
      return false;
    }

    // 检查时间间隔是否合理（排除机器人攻击）
    if (inputs.length >= 2) {
      final intervals = <Duration>[];
      for (var i = 1; i < inputs.length; i++) {
        intervals.add(inputs[i].timestamp.difference(inputs[i - 1].timestamp));
      }

      // 计算平均间隔
      final avgInterval = intervals.fold<int>(
            0,
            (sum, d) => sum + d.inMilliseconds,
          ) ~/
          intervals.length;

      // 如果平均间隔小于500ms，可能是攻击
      if (avgInterval < 500) {
        debugPrint('[FrequencyLimiter] 间隔过短，疑似攻击: ${avgInterval}ms');
        return false;
      }
    }

    return true;
  }

  /// 获取批量记账摘要
  BatchBookkeepingSummary? getBatchSummary() {
    final now = DateTime.now();
    final recentInputs = _allInputs
        .where((r) => now.difference(r.timestamp) < _frequencyWindow)
        .toList();

    if (recentInputs.length < 3) return null;

    if (!_isValidBatchBookkeeping(recentInputs)) return null;

    // 分析批量记账内容
    var totalAmount = 0.0;
    final categories = <String, int>{};

    for (final input in recentInputs) {
      // 提取金额
      final amountMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(input.normalizedInput);
      if (amountMatch != null) {
        totalAmount += double.tryParse(amountMatch.group(1)!) ?? 0;
      }

      // 识别分类
      final category = _detectCategory(input.normalizedInput);
      if (category != null) {
        categories[category] = (categories[category] ?? 0) + 1;
      }
    }

    return BatchBookkeepingSummary(
      count: recentInputs.length,
      totalAmount: totalAmount,
      categories: categories,
      startTime: recentInputs.first.timestamp,
      endTime: recentInputs.last.timestamp,
    );
  }

  /// 检测分类
  String? _detectCategory(String input) {
    final categoryPatterns = {
      '餐饮': RegExp(r'(吃|喝|早餐|午餐|晚餐|外卖|饭|咖啡|奶茶)'),
      '交通': RegExp(r'(打车|地铁|公交|加油|停车)'),
      '购物': RegExp(r'(买|购|淘宝|京东|超市)'),
      '娱乐': RegExp(r'(电影|游戏|唱歌|健身)'),
      '日用': RegExp(r'(水电|话费|网费|房租)'),
    };

    for (final entry in categoryPatterns.entries) {
      if (entry.value.hasMatch(input)) {
        return entry.key;
      }
    }
    return null;
  }

  /// 清理过期历史记录
  void _cleanupHistory() {
    final now = DateTime.now();
    final cutoff = now.subtract(_frequencyWindow * 2);

    // 清理分组历史
    for (final key in _inputHistory.keys.toList()) {
      _inputHistory[key]!.removeWhere((t) => t.isBefore(cutoff));
      if (_inputHistory[key]!.isEmpty) {
        _inputHistory.remove(key);
      }
    }

    // 清理总历史
    while (_allInputs.isNotEmpty &&
        _allInputs.first.timestamp.isBefore(cutoff)) {
      _allInputs.removeFirst();
    }
  }

  /// 清理修改历史
  void _cleanupModificationHistory() {
    final now = DateTime.now();
    final cutoff = now.subtract(_modificationWindow * 2);

    for (final key in _modificationHistory.keys.toList()) {
      _modificationHistory[key]!.removeWhere((t) => t.isBefore(cutoff));
      if (_modificationHistory[key]!.isEmpty) {
        _modificationHistory.remove(key);
      }
    }
  }
}

/// 显示编辑UI的操作
class ShowEditUIAction {
  final String recordId;

  const ShowEditUIAction({required this.recordId});
}

/// 批量记账摘要
class BatchBookkeepingSummary {
  /// 记账笔数
  final int count;

  /// 总金额
  final double totalAmount;

  /// 分类统计
  final Map<String, int> categories;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  final DateTime endTime;

  const BatchBookkeepingSummary({
    required this.count,
    required this.totalAmount,
    required this.categories,
    required this.startTime,
    required this.endTime,
  });

  /// 获取主要分类
  String? get primaryCategory {
    if (categories.isEmpty) return null;
    return categories.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// 获取摘要文本
  String get summaryText {
    final buffer = StringBuffer();
    buffer.write('批量记入$count笔');

    if (totalAmount > 0) {
      buffer.write('，共${totalAmount.toStringAsFixed(0)}元');
    }

    if (primaryCategory != null) {
      buffer.write('，主要是$primaryCategory');
    }

    return buffer.toString();
  }
}
