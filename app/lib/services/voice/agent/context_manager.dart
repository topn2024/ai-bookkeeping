/// 上下文管理器
///
/// 增强型对话上下文管理，支持指代消解和时间引用
///
/// 核心功能：
/// - 对话历史管理
/// - 交易引用追踪
/// - 指代词消解（它、这笔、那个）
/// - 时间引用解析（昨天、刚才、上个月）
/// - 上下文摘要生成
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../category_localization_service.dart';
import '../conversation_context.dart';

/// 引用类型
enum ReferenceType {
  /// 交易引用
  transaction,

  /// 时间引用
  time,

  /// 分类引用
  category,

  /// 账户引用
  account,

  /// 未知
  unknown,
}

/// 消解后的引用
class ResolvedReference {
  /// 引用类型
  final ReferenceType type;

  /// 引用值
  final dynamic value;

  /// 置信度
  final double confidence;

  const ResolvedReference({
    required this.type,
    required this.value,
    this.confidence = 1.0,
  });
}

/// 时间范围
class TimeRange {
  final DateTime start;
  final DateTime end;

  const TimeRange({required this.start, required this.end});

  @override
  String toString() =>
      'TimeRange(${start.toIso8601String()} - ${end.toIso8601String()})';
}

/// 增强型上下文管理器
class ContextManager {
  /// 基础对话上下文
  final ConversationContext _baseContext;

  /// 最近的交易引用
  TransactionReference? _lastTransaction;

  /// 最近查询的分类
  String? _lastCategory;

  /// 最近的时间范围
  TimeRange? _lastTimeRange;

  /// 待确认的操作ID
  String? _pendingActionId;

  /// 待确认的交易ID
  String? _pendingTransactionId;

  /// 用户画像
  UserProfile _userProfile = UserProfile();

  /// 持久化键
  static const String _storageKey = 'agent_context';

  ContextManager({
    ConversationContext? baseContext,
  }) : _baseContext = baseContext ?? ConversationContext();

  /// 获取基础上下文
  ConversationContext get baseContext => _baseContext;

  /// 获取最近的交易引用
  TransactionReference? get lastTransaction => _lastTransaction;

  /// 获取最近的分类
  String? get lastCategory => _lastCategory;

  /// 获取对话历史
  List<ConversationTurn> get history => _baseContext.history;

  // ═══════════════════════════════════════════════════════════════════════════
  // 会话管理
  // ═══════════════════════════════════════════════════════════════════════════

  /// 开始新会话
  void startSession() {
    _baseContext.startSession();
    _pendingActionId = null;
    _pendingTransactionId = null;
  }

  /// 结束会话
  void endSession() {
    _baseContext.endSession();
    _pendingActionId = null;
    _pendingTransactionId = null;
  }

  /// 添加用户输入
  void addUserInput(String text) {
    _baseContext.addUserInput(text);
  }

  /// 添加助手响应
  void addAgentResponse(String text, {TransactionReference? transactionRef}) {
    _baseContext.addAssistantResponse(text, transactionRef: transactionRef);
    if (transactionRef != null) {
      _lastTransaction = transactionRef;
    }
  }

  /// 设置最近的交易引用
  void setLastTransaction(TransactionReference ref) {
    _lastTransaction = ref;
    _lastCategory = ref.category;
  }

  /// 设置待确认的操作
  void setPendingAction(String actionId, {String? transactionId}) {
    _pendingActionId = actionId;
    _pendingTransactionId = transactionId;
  }

  /// 清除待确认的操作
  void clearPendingAction() {
    _pendingActionId = null;
    _pendingTransactionId = null;
  }

  /// 获取待确认的操作ID
  String? get pendingActionId => _pendingActionId;

  /// 获取待确认的交易ID
  String? get pendingTransactionId => _pendingTransactionId;

  // ═══════════════════════════════════════════════════════════════════════════
  // 指代消解
  // ═══════════════════════════════════════════════════════════════════════════

  /// 消解指代引用
  ///
  /// 将"它"、"这笔"、"那个"等代词解析为具体实体
  ResolvedReference? resolveReference(String text) {
    // 交易指代词
    if (_containsTransactionReference(text)) {
      if (_lastTransaction != null) {
        return ResolvedReference(
          type: ReferenceType.transaction,
          value: _lastTransaction,
          confidence: 0.9,
        );
      }

      // 如果有待确认的交易
      if (_pendingTransactionId != null) {
        return ResolvedReference(
          type: ReferenceType.transaction,
          value: _pendingTransactionId,
          confidence: 0.85,
        );
      }
    }

    // 时间指代词
    final timeRef = _resolveTimeReference(text);
    if (timeRef != null) {
      return ResolvedReference(
        type: ReferenceType.time,
        value: timeRef,
        confidence: 0.95,
      );
    }

    // 分类指代
    if (_lastCategory != null && _containsCategoryReference(text)) {
      return ResolvedReference(
        type: ReferenceType.category,
        value: _lastCategory,
        confidence: 0.8,
      );
    }

    return null;
  }

  /// 检查是否包含交易指代词
  bool _containsTransactionReference(String text) {
    const transactionRefs = [
      '它',
      '这笔',
      '那笔',
      '这个',
      '那个',
      '刚才那笔',
      '刚刚那笔',
      '上一笔',
    ];
    return transactionRefs.any((ref) => text.contains(ref));
  }

  /// 检查是否包含分类指代
  bool _containsCategoryReference(String text) {
    const categoryRefs = ['同类', '一样的', '相同的', '这类'];
    return categoryRefs.any((ref) => text.contains(ref));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 时间引用解析
  // ═══════════════════════════════════════════════════════════════════════════

  /// 解析时间引用
  TimeRange? _resolveTimeReference(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 相对时间表达
    if (text.contains('刚才') || text.contains('刚刚')) {
      return TimeRange(
        start: now.subtract(const Duration(minutes: 30)),
        end: now,
      );
    }

    if (text.contains('今天') || text.contains('今日')) {
      return TimeRange(
        start: today,
        end: today.add(const Duration(days: 1, seconds: -1)),
      );
    }

    if (text.contains('昨天')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return TimeRange(
        start: yesterday,
        end: today.subtract(const Duration(seconds: 1)),
      );
    }

    if (text.contains('前天')) {
      final dayBeforeYesterday = today.subtract(const Duration(days: 2));
      return TimeRange(
        start: dayBeforeYesterday,
        end: today.subtract(const Duration(days: 1, seconds: 1)),
      );
    }

    if (text.contains('本周') || text.contains('这周')) {
      final weekStart = today.subtract(Duration(days: now.weekday - 1));
      return TimeRange(start: weekStart, end: now);
    }

    if (text.contains('上周')) {
      final lastWeekStart =
          today.subtract(Duration(days: now.weekday - 1 + 7));
      final lastWeekEnd = lastWeekStart.add(const Duration(days: 6));
      return TimeRange(start: lastWeekStart, end: lastWeekEnd);
    }

    if (text.contains('本月') || text.contains('这个月')) {
      return TimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
    }

    if (text.contains('上个月') || text.contains('上月')) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      return TimeRange(start: lastMonth, end: lastMonthEnd);
    }

    if (text.contains('今年')) {
      return TimeRange(
        start: DateTime(now.year, 1, 1),
        end: now,
      );
    }

    if (text.contains('去年')) {
      return TimeRange(
        start: DateTime(now.year - 1, 1, 1),
        end: DateTime(now.year - 1, 12, 31),
      );
    }

    // 最近N天
    final recentDaysMatch = RegExp(r'最近(\d+)天').firstMatch(text);
    if (recentDaysMatch != null) {
      final days = int.parse(recentDaysMatch.group(1)!);
      return TimeRange(
        start: today.subtract(Duration(days: days - 1)),
        end: now,
      );
    }

    return null;
  }

  /// 解析并更新时间范围
  TimeRange? parseAndSetTimeRange(String text) {
    final range = _resolveTimeReference(text);
    if (range != null) {
      _lastTimeRange = range;
    }
    return range;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 上下文摘要
  // ═══════════════════════════════════════════════════════════════════════════

  /// 生成上下文摘要（供LLM使用）
  String generateSummary() {
    final parts = <String>[];

    // 最近对话
    if (_baseContext.history.isNotEmpty) {
      final recentHistory = _baseContext.history.take(4).map((turn) {
        final role = turn.role == ConversationRole.user ? '用户' : '助手';
        return '$role: ${turn.content}';
      }).join('\n');
      parts.add('【最近对话】\n$recentHistory');
    }

    // 最近交易
    if (_lastTransaction != null) {
      parts.add(
          '【最近交易】${_lastTransaction!.category.localizedCategoryName} ${_lastTransaction!.amount}元');
    }

    // 最近时间范围
    if (_lastTimeRange != null) {
      parts.add('【查询范围】${_formatTimeRange(_lastTimeRange!)}');
    }

    // 待确认操作
    if (_pendingActionId != null) {
      parts.add('【待确认】操作: $_pendingActionId');
    }

    // 用户偏好
    if (_userProfile.frequentCategories.isNotEmpty) {
      parts.add('【常用分类】${_userProfile.frequentCategories.take(3).join("、")}');
    }

    return parts.join('\n\n');
  }

  /// 格式化时间范围
  String _formatTimeRange(TimeRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 今天
    if (range.start.year == today.year &&
        range.start.month == today.month &&
        range.start.day == today.day) {
      return '今天';
    }

    // 昨天
    final yesterday = today.subtract(const Duration(days: 1));
    if (range.start.year == yesterday.year &&
        range.start.month == yesterday.month &&
        range.start.day == yesterday.day) {
      return '昨天';
    }

    // 本月
    if (range.start.year == now.year &&
        range.start.month == now.month &&
        range.start.day == 1) {
      return '本月';
    }

    return '${range.start.month}月${range.start.day}日 - ${range.end.month}月${range.end.day}日';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 用户画像
  // ═══════════════════════════════════════════════════════════════════════════

  /// 更新用户画像
  void updateUserProfile({
    String? category,
    double? amount,
    String? merchant,
  }) {
    if (category != null) {
      _userProfile.addCategory(category);
    }
    if (amount != null) {
      _userProfile.addAmount(amount);
    }
    if (merchant != null) {
      _userProfile.addMerchant(merchant);
    }
  }

  /// 获取用户画像
  UserProfile get userProfile => _userProfile;

  // ═══════════════════════════════════════════════════════════════════════════
  // 持久化
  // ═══════════════════════════════════════════════════════════════════════════

  /// 保存到本地
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'lastCategory': _lastCategory,
        'userProfile': _userProfile.toJson(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[ContextManager] 保存失败: $e');
    }
  }

  /// 从本地加载
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_storageKey);
      if (dataStr != null) {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        _lastCategory = data['lastCategory'] as String?;
        if (data['userProfile'] != null) {
          _userProfile = UserProfile.fromJson(
              data['userProfile'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ContextManager] 加载失败: $e');
    }
  }

  /// 清除所有数据
  Future<void> clear() async {
    _baseContext.endSession();
    _lastTransaction = null;
    _lastCategory = null;
    _lastTimeRange = null;
    _pendingActionId = null;
    _pendingTransactionId = null;
    _userProfile = UserProfile();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('[ContextManager] 清除失败: $e');
    }
  }
}

/// 用户画像
class UserProfile {
  /// 常用分类（按频率排序）
  final Map<String, int> _categoryFrequency = {};

  /// 常用商家
  final Map<String, int> _merchantFrequency = {};

  /// 消费金额历史（用于异常检测）
  final List<double> _amountHistory = [];

  /// 最大历史记录
  static const int _maxHistory = 50;

  UserProfile();

  /// 添加分类记录
  void addCategory(String category) {
    _categoryFrequency[category] = (_categoryFrequency[category] ?? 0) + 1;
  }

  /// 添加商家记录
  void addMerchant(String merchant) {
    _merchantFrequency[merchant] = (_merchantFrequency[merchant] ?? 0) + 1;
  }

  /// 添加金额记录
  void addAmount(double amount) {
    _amountHistory.add(amount);
    if (_amountHistory.length > _maxHistory) {
      _amountHistory.removeAt(0);
    }
  }

  /// 获取常用分类
  List<String> get frequentCategories {
    final sorted = _categoryFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  /// 获取常用商家
  List<String> get frequentMerchants {
    final sorted = _merchantFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  /// 获取平均消费金额
  double get averageAmount {
    if (_amountHistory.isEmpty) return 0;
    return _amountHistory.reduce((a, b) => a + b) / _amountHistory.length;
  }

  /// 检测金额是否异常（超过平均值的2倍）
  bool isAmountUnusual(double amount) {
    if (_amountHistory.length < 5) return amount > 500; // 数据不足时使用固定阈值
    return amount > averageAmount * 2;
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'categoryFrequency': _categoryFrequency,
        'merchantFrequency': _merchantFrequency,
        'amountHistory': _amountHistory,
      };

  /// 从JSON创建
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = UserProfile();
    if (json['categoryFrequency'] != null) {
      profile._categoryFrequency.addAll(
        (json['categoryFrequency'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
      );
    }
    if (json['merchantFrequency'] != null) {
      profile._merchantFrequency.addAll(
        (json['merchantFrequency'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
      );
    }
    if (json['amountHistory'] != null) {
      profile._amountHistory.addAll(
        (json['amountHistory'] as List).map((e) => (e as num).toDouble()),
      );
    }
    return profile;
  }
}
