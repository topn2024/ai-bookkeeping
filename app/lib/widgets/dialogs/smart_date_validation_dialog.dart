import 'package:flutter/material.dart';

/// 智能日期校验对话框
/// 原型设计 11.08：日期智能校验
/// - 日期异常提示（无效日期、未来日期、久远日期、凌晨时间）
/// - 日期选择建议
/// - 操作按钮
class SmartDateValidationDialog extends StatelessWidget {
  final DateTime inputDate;
  final DateValidationIssue issue;
  final List<DateTime> suggestions;
  final ValueChanged<DateTime>? onSelectDate;
  final VoidCallback? onDismiss;

  const SmartDateValidationDialog({
    super.key,
    required this.inputDate,
    required this.issue,
    required this.suggestions,
    this.onSelectDate,
    this.onDismiss,
  });

  /// 显示智能日期校验对话框
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime inputDate,
    required DateValidationIssue issue,
    required List<DateTime> suggestions,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => SmartDateValidationDialog(
        inputDate: inputDate,
        issue: issue,
        suggestions: suggestions,
        onSelectDate: (date) => Navigator.pop(context, date),
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题区
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBDEFB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getIssueTitle(issue),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getIssueDescription(issue),
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF1976D2),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 选择按钮
            if (suggestions.isNotEmpty)
              Row(
                children: suggestions.take(2).map((date) {
                  final isFirst = date == suggestions.first;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: isFirst ? 0 : 8),
                      child: SizedBox(
                        height: 44,
                        child: isFirst
                            ? ElevatedButton(
                                onPressed: () => onSelectDate?.call(date),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(_formatDateShort(date)),
                              )
                            : OutlinedButton(
                                onPressed: () => onSelectDate?.call(date),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E88E5),
                                  side: const BorderSide(color: Color(0xFF1E88E5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(_formatDateShort(date)),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // 其他检测示例
            _buildOtherChecksInfo(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherChecksInfo(ThemeData theme) {
    final checks = [
      {'icon': Icons.schedule, 'text': '未来日期提醒（选择了明天）'},
      {'icon': Icons.history, 'text': '久远日期确认（超过30天前）'},
      {'icon': Icons.nightlight, 'text': '凌晨时间确认（3:00 AM）'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '其他智能检测：',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: checks.map((check) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      check['icon'] as IconData,
                      color: const Color(0xFFFF9800),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        check['text'] as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getIssueTitle(DateValidationIssue issue) {
    switch (issue) {
      case DateValidationIssue.invalidDate:
        return '日期需要调整';
      case DateValidationIssue.futureDate:
        return '这是未来的日期';
      case DateValidationIssue.distantPastDate:
        return '这是很久以前的日期';
      case DateValidationIssue.oddTime:
        return '时间有些特别';
    }
  }

  String _getIssueDescription(DateValidationIssue issue) {
    switch (issue) {
      case DateValidationIssue.invalidDate:
        return '${inputDate.month}月没有${inputDate.day}号哦\n是想选 ${_formatDateShort(suggestions.first)} 还是 ${_formatDateShort(suggestions.last)}？';
      case DateValidationIssue.futureDate:
        return '您选择的日期是未来的 ${_formatDate(inputDate)}，确定要使用这个日期吗？';
      case DateValidationIssue.distantPastDate:
        return '您选择的日期是 ${_formatDate(inputDate)}，这已经是30天前了，确定吗？';
      case DateValidationIssue.oddTime:
        return '您选择的时间是凌晨 ${inputDate.hour}:${inputDate.minute.toString().padLeft(2, '0')}，确定是这个时间吗？';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _formatDateShort(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}

/// 日期验证问题类型
enum DateValidationIssue {
  invalidDate,     // 无效日期（如2月30日）
  futureDate,      // 未来日期
  distantPastDate, // 久远日期（超过30天前）
  oddTime,         // 特殊时间（如凌晨）
}

/// 日期验证器
class SmartDateValidator {
  final DateTime date;
  final DateTime now;

  SmartDateValidator({
    required this.date,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  /// 验证日期是否有效
  DateValidationResult validate() {
    // 检查是否是无效日期（这个由DateTime构造函数处理）

    // 检查是否是未来日期
    if (date.isAfter(now)) {
      return DateValidationResult(
        issue: DateValidationIssue.futureDate,
        suggestions: [now, date],
      );
    }

    // 检查是否是久远日期（超过30天前）
    if (now.difference(date).inDays > 30) {
      return DateValidationResult(
        issue: DateValidationIssue.distantPastDate,
        suggestions: [now, date],
      );
    }

    // 检查是否是特殊时间（凌晨0-5点）
    if (date.hour >= 0 && date.hour < 5) {
      final previousDay = date.subtract(const Duration(days: 1));
      final normalizedTime = DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        23,
        59,
      );
      return DateValidationResult(
        issue: DateValidationIssue.oddTime,
        suggestions: [normalizedTime, date],
      );
    }

    return DateValidationResult.valid();
  }

  /// 修正无效日期
  static DateTime correctInvalidDate(int year, int month, int day) {
    // 获取该月的最后一天
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day > lastDay) {
      // 返回该月最后一天或下月第一天
      return DateTime(year, month, lastDay);
    }
    return DateTime(year, month, day);
  }

  /// 获取建议的日期
  static List<DateTime> getSuggestionsForInvalidDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;

    return [
      DateTime(year, month, lastDay), // 该月最后一天
      DateTime(nextYear, nextMonth, 1), // 下月第一天
    ];
  }
}

/// 日期验证结果
class DateValidationResult {
  final bool isValid;
  final DateValidationIssue? issue;
  final List<DateTime> suggestions;

  DateValidationResult({
    this.isValid = false,
    this.issue,
    this.suggestions = const [],
  });

  factory DateValidationResult.valid() {
    return DateValidationResult(isValid: true);
  }
}
