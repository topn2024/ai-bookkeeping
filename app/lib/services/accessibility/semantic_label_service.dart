import 'package:flutter/semantics.dart';

/// 语义化标签类型
enum SemanticType {
  /// 金额
  amount,

  /// 日期
  date,

  /// 百分比
  percentage,

  /// 按钮
  button,

  /// 图标
  icon,

  /// 图表
  chart,

  /// 列表项
  listItem,

  /// 输入框
  input,

  /// 状态
  status,

  /// 进度
  progress,

  /// 导航
  navigation,

  /// 标题
  heading,

  /// 提示
  hint,

  /// 错误
  error,

  /// 成功
  success,

  /// 警告
  warning,
}

/// 语义化标签优先级
enum SemanticPriority {
  /// 低优先级 - 补充信息
  low,

  /// 中优先级 - 重要信息
  medium,

  /// 高优先级 - 关键信息
  high,

  /// 紧急 - 需要立即关注
  urgent,
}

/// 语义化标签配置
class SemanticConfig {
  /// 是否启用详细模式
  final bool verboseMode;

  /// 货币符号
  final String currencySymbol;

  /// 是否启用语音提示音
  final bool enableSoundFeedback;

  /// 日期格式
  final String dateFormat;

  const SemanticConfig({
    this.verboseMode = false,
    this.currencySymbol = '元',
    this.enableSoundFeedback = true,
    this.dateFormat = 'yyyy年M月d日',
  });
}

/// 语义化标签服务
/// 提供完善的屏幕阅读器支持，生成清晰、准确的语义化标签
class SemanticLabelService {
  static final SemanticLabelService _instance =
      SemanticLabelService._internal();
  factory SemanticLabelService() => _instance;
  SemanticLabelService._internal();

  /// 当前配置
  SemanticConfig _config = const SemanticConfig();

  /// 标签缓存，避免重复计算
  final Map<String, String> _labelCache = {};

  /// 最大缓存数量
  static const int _maxCacheSize = 500;

  /// 更新配置
  void updateConfig(SemanticConfig config) {
    _config = config;
    _labelCache.clear(); // 配置变更时清空缓存
  }

  /// 获取当前配置
  SemanticConfig get config => _config;

  /// 清空缓存
  void clearCache() {
    _labelCache.clear();
  }

  // ==================== 金额相关语义 ====================

  /// 生成金额语义标签
  String amountLabel(double amount, {String? currency, bool? isIncome}) {
    final curr = currency ?? _config.currencySymbol;
    final absAmount = amount.abs();
    final formattedAmount = _formatAmount(absAmount);

    if (isIncome != null) {
      return isIncome ? '收入$formattedAmount$curr' : '支出$formattedAmount$curr';
    }

    if (amount >= 0) {
      return '收入$formattedAmount$curr';
    }
    return '支出$formattedAmount$curr';
  }

  /// 格式化金额（添加千位分隔符）
  String _formatAmount(double amount) {
    if (amount >= 10000) {
      final wan = amount / 10000;
      if (wan == wan.truncate()) {
        return '${wan.truncate()}万';
      }
      return '${wan.toStringAsFixed(2)}万';
    }
    if (amount == amount.truncate()) {
      return amount.truncate().toString();
    }
    return amount.toStringAsFixed(2);
  }

  /// 生成余额语义标签
  String balanceLabel(double balance, {String? accountName}) {
    final formattedBalance = _formatAmount(balance.abs());
    final balanceText = balance >= 0
        ? '余额$formattedBalance${_config.currencySymbol}'
        : '欠款$formattedBalance${_config.currencySymbol}';

    if (accountName != null) {
      return '$accountName，$balanceText';
    }
    return balanceText;
  }

  /// 生成预算语义标签
  String budgetLabel({
    required String category,
    required double spent,
    required double total,
  }) {
    final percentage = total > 0 ? (spent / total * 100) : 0;
    final remaining = total - spent;
    final spentText = _formatAmount(spent);
    final totalText = _formatAmount(total);
    final remainingText = _formatAmount(remaining.abs());

    String statusText;
    if (remaining > 0) {
      statusText = '剩余$remainingText${_config.currencySymbol}';
    } else if (remaining < 0) {
      statusText = '超支$remainingText${_config.currencySymbol}';
    } else {
      statusText = '已用完';
    }

    if (_config.verboseMode) {
      return '$category预算，已使用$spentText${_config.currencySymbol}，'
          '共$totalText${_config.currencySymbol}，'
          '使用${percentage.toStringAsFixed(0)}%，$statusText';
    }

    return '$category，$statusText，使用${percentage.toStringAsFixed(0)}%';
  }

  // ==================== 百分比相关语义 ====================

  /// 生成百分比语义标签
  String percentageLabel(double value, {String? context}) {
    final prefix = context ?? '占比';
    final formattedValue = value.toStringAsFixed(1);
    return '$prefix百分之$formattedValue';
  }

  /// 生成进度语义标签
  String progressLabel({
    required double current,
    required double total,
    String? context,
  }) {
    final percentage = total > 0 ? (current / total * 100) : 0;
    final contextText = context ?? '进度';

    if (percentage >= 100) {
      return '$contextText已完成';
    } else if (percentage <= 0) {
      return '$contextText未开始';
    }

    return '$contextText${percentage.toStringAsFixed(0)}%';
  }

  // ==================== 日期时间相关语义 ====================

  /// 生成日期语义标签
  String dateLabel(DateTime date, {bool includeWeekday = false}) {
    final weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = targetDate.difference(today).inDays;

    String dateText;
    if (difference == 0) {
      dateText = '今天';
    } else if (difference == -1) {
      dateText = '昨天';
    } else if (difference == 1) {
      dateText = '明天';
    } else if (difference == -2) {
      dateText = '前天';
    } else if (difference == 2) {
      dateText = '后天';
    } else if (date.year == now.year) {
      dateText = '${date.month}月${date.day}日';
    } else {
      dateText = '${date.year}年${date.month}月${date.day}日';
    }

    if (includeWeekday && difference.abs() > 2) {
      dateText += '，${weekdays[date.weekday % 7]}';
    }

    return dateText;
  }

  /// 生成时间语义标签
  String timeLabel(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    String period;
    if (hour < 6) {
      period = '凌晨';
    } else if (hour < 12) {
      period = '上午';
    } else if (hour < 14) {
      period = '中午';
    } else if (hour < 18) {
      period = '下午';
    } else {
      period = '晚上';
    }

    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    if (minute == 0) {
      return '$period$displayHour点整';
    }
    return '$period$displayHour点$minute分';
  }

  /// 生成日期时间语义标签
  String dateTimeLabel(DateTime dateTime) {
    return '${dateLabel(dateTime)}，${timeLabel(dateTime)}';
  }

  /// 生成时间范围语义标签
  String dateRangeLabel(DateTime start, DateTime end) {
    final startText = dateLabel(start);
    final endText = dateLabel(end);

    if (startText == endText) {
      return startText;
    }

    return '从$startText到$endText';
  }

  // ==================== 交易相关语义 ====================

  /// 生成交易语义标签
  String transactionLabel({
    required String category,
    required double amount,
    required DateTime date,
    String? merchant,
    String? note,
  }) {
    final amountText = amountLabel(amount);
    final dateText = dateLabel(date);

    final parts = <String>[category];

    if (merchant != null && merchant.isNotEmpty) {
      parts.add(merchant);
    }

    parts.add(amountText);
    parts.add(dateText);

    if (_config.verboseMode && note != null && note.isNotEmpty) {
      parts.add('备注：$note');
    }

    return parts.join('，');
  }

  /// 生成交易列表项语义标签
  String transactionListItemLabel({
    required int index,
    required int total,
    required String category,
    required double amount,
    required DateTime date,
  }) {
    final positionText = '第${index + 1}条，共$total条';
    final transactionText = transactionLabel(
      category: category,
      amount: amount,
      date: date,
    );

    return '$positionText，$transactionText';
  }

  // ==================== 钱龄相关语义 ====================

  /// 生成钱龄语义标签
  String moneyAgeLabel(double days) {
    if (days < 1) {
      return '钱龄不足一天';
    } else if (days < 7) {
      return '钱龄${days.toStringAsFixed(1)}天';
    } else if (days < 30) {
      final weeks = (days / 7).floor();
      return '钱龄约$weeks周';
    } else if (days < 365) {
      final months = (days / 30).floor();
      return '钱龄约$months个月';
    } else {
      final years = (days / 365).floor();
      final remainingMonths = ((days % 365) / 30).floor();
      if (remainingMonths > 0) {
        return '钱龄约$years年$remainingMonths个月';
      }
      return '钱龄约$years年';
    }
  }

  /// 生成钱龄健康状态语义标签
  String moneyAgeHealthLabel(double days, {double? target}) {
    final ageText = moneyAgeLabel(days);
    String healthStatus;

    if (days >= 30) {
      healthStatus = '非常健康';
    } else if (days >= 14) {
      healthStatus = '较为健康';
    } else if (days >= 7) {
      healthStatus = '一般';
    } else {
      healthStatus = '需要关注';
    }

    if (target != null) {
      final progress = (days / target * 100).clamp(0, 100);
      return '$ageText，状态$healthStatus，目标完成${progress.toStringAsFixed(0)}%';
    }

    return '$ageText，状态$healthStatus';
  }

  // ==================== 图表相关语义 ====================

  /// 生成饼图语义标签
  String pieChartLabel({
    required String title,
    required List<MapEntry<String, double>> segments,
  }) {
    if (segments.isEmpty) {
      return '$title，暂无数据';
    }

    final total = segments.fold<double>(0, (sum, e) => sum + e.value);
    final descriptions = segments.take(3).map((segment) {
      final percentage = total > 0 ? (segment.value / total * 100) : 0;
      return '${segment.key}占${percentage.toStringAsFixed(0)}%';
    }).toList();

    if (segments.length > 3) {
      descriptions.add('等${segments.length}项');
    }

    return '$title，${descriptions.join('，')}';
  }

  /// 生成趋势图语义标签
  String trendChartLabel({
    required String title,
    required List<double> values,
    required String timeRange,
  }) {
    if (values.isEmpty) {
      return '$title，$timeRange，暂无数据';
    }

    final first = values.first;
    final last = values.last;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);

    String trendText;
    if (last > first) {
      final increase = ((last - first) / first * 100).abs();
      trendText = '上升${increase.toStringAsFixed(0)}%';
    } else if (last < first) {
      final decrease = ((first - last) / first * 100).abs();
      trendText = '下降${decrease.toStringAsFixed(0)}%';
    } else {
      trendText = '持平';
    }

    return '$title，$timeRange，趋势$trendText，'
        '最高${_formatAmount(max)}${_config.currencySymbol}，'
        '最低${_formatAmount(min)}${_config.currencySymbol}';
  }

  // ==================== 状态相关语义 ====================

  /// 生成状态语义标签
  String statusLabel(
    String status, {
    SemanticPriority priority = SemanticPriority.medium,
  }) {
    String priorityPrefix = '';
    switch (priority) {
      case SemanticPriority.urgent:
        priorityPrefix = '紧急，';
        break;
      case SemanticPriority.high:
        priorityPrefix = '重要，';
        break;
      case SemanticPriority.medium:
      case SemanticPriority.low:
        break;
    }
    return '$priorityPrefix$status';
  }

  /// 生成错误语义标签
  String errorLabel(String message, {String? suggestion}) {
    if (suggestion != null) {
      return '错误，$message，建议$suggestion';
    }
    return '错误，$message';
  }

  /// 生成成功语义标签
  String successLabel(String message) {
    return '成功，$message';
  }

  /// 生成警告语义标签
  String warningLabel(String message) {
    return '警告，$message';
  }

  // ==================== 导航相关语义 ====================

  /// 生成列表位置语义标签
  String listPositionLabel(int index, int total, {String? itemType}) {
    final type = itemType ?? '项';
    return '第${index + 1}$type，共$total$type';
  }

  /// 生成页面标题语义标签
  String pageTitleLabel(String title, {int? unreadCount}) {
    if (unreadCount != null && unreadCount > 0) {
      return '$title，$unreadCount条未读';
    }
    return title;
  }

  /// 生成标签页语义标签
  String tabLabel(String name, int index, int total, {bool isSelected = false}) {
    final selectedText = isSelected ? '，已选中' : '';
    return '$name标签页，第${index + 1}个，共$total个$selectedText';
  }

  // ==================== 表单相关语义 ====================

  /// 生成输入框语义标签
  String inputFieldLabel({
    required String label,
    String? value,
    String? hint,
    bool isRequired = false,
    String? errorMessage,
  }) {
    final parts = <String>[label];

    if (isRequired) {
      parts.add('必填');
    }

    if (value != null && value.isNotEmpty) {
      parts.add('当前值$value');
    } else if (hint != null) {
      parts.add(hint);
    }

    if (errorMessage != null) {
      parts.add('错误：$errorMessage');
    }

    return parts.join('，');
  }

  /// 生成按钮语义标签
  String buttonLabel(String label, {bool isEnabled = true, String? hint}) {
    final parts = <String>[label];

    if (!isEnabled) {
      parts.add('已禁用');
    }

    if (hint != null) {
      parts.add(hint);
    }

    return parts.join('，');
  }

  // ==================== 小金库/预算相关语义 ====================

  /// 生成小金库语义标签
  String vaultLabel({
    required String name,
    required double balance,
    required double allocated,
    String? icon,
  }) {
    final balanceText = _formatAmount(balance);
    final allocatedText = _formatAmount(allocated);
    final percentage = allocated > 0 ? (balance / allocated * 100) : 0;

    return '$name小金库，余额$balanceText${_config.currencySymbol}，'
        '分配$allocatedText${_config.currencySymbol}，'
        '剩余${percentage.toStringAsFixed(0)}%';
  }

  // ==================== 成就/习惯相关语义 ====================

  /// 生成成就语义标签
  String achievementLabel({
    required String name,
    required String description,
    required bool isUnlocked,
    DateTime? unlockedAt,
  }) {
    if (isUnlocked) {
      final dateText = unlockedAt != null ? '，${dateLabel(unlockedAt)}解锁' : '';
      return '$name成就，已解锁$dateText，$description';
    }
    return '$name成就，未解锁，$description';
  }

  /// 生成连续记账语义标签
  String streakLabel(int days) {
    if (days == 0) {
      return '尚未开始连续记账';
    } else if (days == 1) {
      return '已连续记账1天';
    } else if (days < 7) {
      return '已连续记账$days天';
    } else if (days < 30) {
      final weeks = days ~/ 7;
      final remainingDays = days % 7;
      if (remainingDays > 0) {
        return '已连续记账$weeks周$remainingDays天';
      }
      return '已连续记账$weeks周';
    } else {
      final months = days ~/ 30;
      return '已连续记账超过$months个月';
    }
  }

  // ==================== 工具方法 ====================

  /// 创建带缓存的语义标签
  String cachedLabel(String key, String Function() generator) {
    if (_labelCache.containsKey(key)) {
      return _labelCache[key]!;
    }

    // 缓存满时清除最旧的条目
    if (_labelCache.length >= _maxCacheSize) {
      final keysToRemove = _labelCache.keys.take(_maxCacheSize ~/ 2).toList();
      for (final k in keysToRemove) {
        _labelCache.remove(k);
      }
    }

    final label = generator();
    _labelCache[key] = label;
    return label;
  }

  /// 合并多个语义标签
  String combineLabels(List<String> labels, {String separator = '，'}) {
    return labels.where((l) => l.isNotEmpty).join(separator);
  }

  /// 生成自定义操作语义描述
  SemanticsProperties customSemanticsProperties({
    required String label,
    String? hint,
    String? value,
    bool? isButton,
    bool? isEnabled,
    bool? isSelected,
    bool? isChecked,
    bool? isExpanded,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return SemanticsProperties(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      enabled: isEnabled,
      selected: isSelected,
      checked: isChecked,
      expanded: isExpanded,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
