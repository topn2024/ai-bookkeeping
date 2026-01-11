import 'dart:math';

/// 对话上下文管理
///
/// 管理语音对话的上下文信息，实现：
/// 1. 多轮对话历史记忆
/// 2. 代词指代理解
/// 3. 时间相对引用
/// 4. 自然语言响应生成
class ConversationContext {
  /// 对话历史
  final List<ConversationTurn> _history = [];

  /// 最大历史轮数
  final int maxHistoryTurns;

  /// 当前会话ID
  String? _sessionId;

  /// 最后一次交易引用
  TransactionReference? _lastTransactionRef;

  /// 随机数生成器（用于响应变体选择）
  final Random _random = Random();

  ConversationContext({this.maxHistoryTurns = 5});

  /// 开始新会话
  void startSession() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _history.clear();
    _lastTransactionRef = null;
  }

  /// 结束会话
  void endSession() {
    _sessionId = null;
    _history.clear();
    _lastTransactionRef = null;
  }

  /// 添加用户输入
  void addUserInput(String text) {
    _history.add(ConversationTurn(
      role: ConversationRole.user,
      content: text,
      timestamp: DateTime.now(),
    ));
    _trimHistory();
  }

  /// 添加助手响应
  void addAssistantResponse(String text, {TransactionReference? transactionRef}) {
    _history.add(ConversationTurn(
      role: ConversationRole.assistant,
      content: text,
      timestamp: DateTime.now(),
    ));

    if (transactionRef != null) {
      _lastTransactionRef = transactionRef;
    }

    _trimHistory();
  }

  /// 裁剪历史
  void _trimHistory() {
    while (_history.length > maxHistoryTurns * 2) {
      _history.removeAt(0);
    }
  }

  /// 获取对话历史
  List<ConversationTurn> get history => List.unmodifiable(_history);

  /// 获取最后一次交易引用
  TransactionReference? get lastTransactionRef => _lastTransactionRef;

  // ==================== 代词理解 ====================

  /// 解析代词引用
  ///
  /// 将"它"、"这笔"、"那个"等代词解析为具体引用
  String? resolveReference(String text) {
    // 检测代词
    final pronounPatterns = [
      RegExp(r'(删掉|修改|取消)(它|这笔|那笔|这个|那个)'),
      RegExp(r'(改成|改为)(\d+)'),
      RegExp(r'把(它|这笔|那笔)'),
    ];

    for (final pattern in pronounPatterns) {
      if (pattern.hasMatch(text)) {
        if (_lastTransactionRef != null) {
          return _lastTransactionRef!.id;
        }
      }
    }

    return null;
  }

  /// 检查是否是继续请求
  bool isContinueRequest(String text) {
    final continuePatterns = [
      '继续',
      '接着说',
      '然后呢',
      '说下去',
      '继续说',
    ];
    return continuePatterns.any((p) => text.contains(p));
  }

  /// 检查是否是纠正请求
  bool isCorrectionRequest(String text) {
    final correctionPatterns = [
      RegExp(r'^不是'),
      RegExp(r'^不对'),
      RegExp(r'^错了'),
      RegExp(r'^我说的是'),
      RegExp(r'^应该是'),
    ];
    return correctionPatterns.any((p) => p.hasMatch(text));
  }

  // ==================== 时间理解 ====================

  /// 解析时间引用
  DateTime? resolveTimeReference(String text) {
    final now = DateTime.now();

    // 相对时间
    if (text.contains('刚才') || text.contains('刚刚')) {
      // 返回最近5分钟内
      return now.subtract(const Duration(minutes: 5));
    }

    if (text.contains('上一笔') || text.contains('上次')) {
      if (_lastTransactionRef != null) {
        return _lastTransactionRef!.date;
      }
    }

    // 具体时间
    final timePatterns = {
      '今天': now,
      '昨天': now.subtract(const Duration(days: 1)),
      '前天': now.subtract(const Duration(days: 2)),
      '这周': _getStartOfWeek(now),
      '上周': _getStartOfWeek(now.subtract(const Duration(days: 7))),
      '这个月': DateTime(now.year, now.month, 1),
      '上个月': DateTime(now.year, now.month - 1, 1),
    };

    for (final entry in timePatterns.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  // ==================== 自然语言响应 ====================

  /// 生成自然的确认响应
  String generateConfirmResponse() {
    final variants = [
      '好的，已经记录了',
      '嗯，记好了',
      '好，帮你记下了',
      '记录好了',
      '嗯嗯，搞定了',
    ];
    return variants[_random.nextInt(variants.length)];
  }

  /// 生成自然的错误响应
  String generateErrorResponse(String? specificError) {
    if (specificError != null) {
      return '抱歉，$specificError';
    }

    final variants = [
      '抱歉，出了点问题',
      '哎呀，没成功，再试一次好吗',
      '不好意思，处理时遇到了问题',
    ];
    return variants[_random.nextInt(variants.length)];
  }

  /// 生成自然的询问响应
  String generateAskResponse(String question) {
    final prefixes = [
      '请问',
      '那',
      '嗯',
      '',
    ];
    return '${prefixes[_random.nextInt(prefixes.length)]}$question';
  }

  /// 生成跟进建议
  String? generateFollowUp({
    required double amount,
    required String category,
    bool isLargeAmount = false,
  }) {
    if (isLargeAmount) {
      return '这笔消费比平时大不少呢，确定没问题吗？';
    }

    // 根据时间生成跟进
    final hour = DateTime.now().hour;
    if (hour >= 11 && hour <= 13) {
      if (category != '餐饮') {
        return '午餐记了吗？';
      }
    } else if (hour >= 18 && hour <= 20) {
      if (category != '餐饮') {
        return '晚餐记了吗？';
      }
    }

    // 随机决定是否跟进
    if (_random.nextDouble() < 0.3) {
      final variants = [
        '还有其他要记的吗？',
        '还有别的吗？',
        '还需要记什么吗？',
      ];
      return variants[_random.nextInt(variants.length)];
    }

    return null;
  }

  /// 获取时段问候语
  String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      final variants = ['早上好', '上午好', '早啊'];
      return variants[_random.nextInt(variants.length)];
    } else if (hour >= 12 && hour < 14) {
      final variants = ['中午好', '午安'];
      return variants[_random.nextInt(variants.length)];
    } else if (hour >= 14 && hour < 18) {
      final variants = ['下午好', '午后好'];
      return variants[_random.nextInt(variants.length)];
    } else if (hour >= 18 && hour < 22) {
      final variants = ['晚上好', '晚好'];
      return variants[_random.nextInt(variants.length)];
    } else {
      return '夜深了';
    }
  }

  /// 生成等待提示
  String generateWaitingPrompt() {
    final variants = [
      '让我看看...',
      '稍等一下...',
      '正在处理...',
      '好，我来查一下...',
    ];
    return variants[_random.nextInt(variants.length)];
  }

  /// 生成打断后的恢复提示
  String generateInterruptRecovery() {
    final variants = [
      '好的，请说',
      '嗯，你说',
      '我听着呢',
    ];
    return variants[_random.nextInt(variants.length)];
  }
}

// ==================== 数据模型 ====================

/// 对话角色
enum ConversationRole {
  user,
  assistant,
}

/// 对话轮次
class ConversationTurn {
  final ConversationRole role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ConversationTurn({
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });
}

/// 交易引用
class TransactionReference {
  final String id;
  final double amount;
  final String category;
  final DateTime date;

  TransactionReference({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
  });
}

/// 响应模板
class ResponseTemplate {
  /// 记账成功响应模板
  static String recordSuccess({
    required double amount,
    required String category,
    bool useNaturalStyle = true,
  }) {
    if (useNaturalStyle) {
      final templates = [
        '好的，帮你记了$category${_formatAmount(amount)}',
        '嗯，$category${_formatAmount(amount)}，记下了',
        '记好了，$category${_formatAmount(amount)}',
      ];
      return templates[Random().nextInt(templates.length)];
    }
    return '已记录$category支出${_formatAmount(amount)}';
  }

  /// 查询结果响应模板
  static String queryResult({
    required String period,
    required double total,
    required int count,
  }) {
    final templates = [
      '$period一共花了${_formatAmount(total)}，共$count笔',
      '$period消费${_formatAmount(total)}，$count笔记录',
    ];
    return templates[Random().nextInt(templates.length)];
  }

  /// 格式化金额
  static String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return '${amount.truncate()}块';
    }
    return '${amount.toStringAsFixed(2)}元';
  }
}
