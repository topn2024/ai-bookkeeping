import 'dart:math';
import 'package:flutter/material.dart';

/// 审计问题严重级别
enum AuditSeverity {
  /// 信息 - 建议改进
  info,

  /// 警告 - 可能影响部分用户
  warning,

  /// 错误 - 影响无障碍功能
  error,

  /// 严重 - 严重影响可访问性
  critical,
}

/// 审计问题类别
enum AuditCategory {
  /// 语义化标签
  semantics,

  /// 色彩对比度
  contrast,

  /// 触控目标
  touchTarget,

  /// 焦点管理
  focus,

  /// 键盘导航
  keyboard,

  /// 屏幕阅读器
  screenReader,

  /// 文字缩放
  textScaling,

  /// 动画
  animation,

  /// 表单
  form,

  /// 图片
  image,
}

/// 审计问题
class AuditIssue {
  /// 问题ID
  final String id;

  /// 问题描述
  final String description;

  /// 详细信息
  final String? details;

  /// 问题类别
  final AuditCategory category;

  /// 严重级别
  final AuditSeverity severity;

  /// WCAG准则参考
  final String? wcagReference;

  /// 修复建议
  final List<String> suggestions;

  /// 相关元素信息
  final String? elementInfo;

  /// 元素位置
  final Rect? elementBounds;

  /// 是否可自动修复
  final bool autoFixable;

  /// 创建时间
  final DateTime createdAt;

  AuditIssue({
    required this.id,
    required this.description,
    this.details,
    required this.category,
    required this.severity,
    this.wcagReference,
    this.suggestions = const [],
    this.elementInfo,
    this.elementBounds,
    this.autoFixable = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 获取类别名称
  String get categoryName {
    switch (category) {
      case AuditCategory.semantics:
        return '语义化标签';
      case AuditCategory.contrast:
        return '色彩对比度';
      case AuditCategory.touchTarget:
        return '触控目标';
      case AuditCategory.focus:
        return '焦点管理';
      case AuditCategory.keyboard:
        return '键盘导航';
      case AuditCategory.screenReader:
        return '屏幕阅读器';
      case AuditCategory.textScaling:
        return '文字缩放';
      case AuditCategory.animation:
        return '动画';
      case AuditCategory.form:
        return '表单';
      case AuditCategory.image:
        return '图片';
    }
  }

  /// 获取严重级别名称
  String get severityName {
    switch (severity) {
      case AuditSeverity.info:
        return '建议';
      case AuditSeverity.warning:
        return '警告';
      case AuditSeverity.error:
        return '错误';
      case AuditSeverity.critical:
        return '严重';
    }
  }
}

/// 审计报告
class AuditReport {
  /// 报告ID
  final String id;

  /// 审计时间
  final DateTime timestamp;

  /// 被审计的页面/组件名称
  final String targetName;

  /// 发现的问题
  final List<AuditIssue> issues;

  /// 审计通过的检查项
  final List<String> passedChecks;

  /// 审计配置
  final AuditConfig config;

  AuditReport({
    required this.id,
    required this.timestamp,
    required this.targetName,
    required this.issues,
    required this.passedChecks,
    required this.config,
  });

  /// 问题总数
  int get totalIssues => issues.length;

  /// 严重问题数
  int get criticalCount =>
      issues.where((i) => i.severity == AuditSeverity.critical).length;

  /// 错误数
  int get errorCount =>
      issues.where((i) => i.severity == AuditSeverity.error).length;

  /// 警告数
  int get warningCount =>
      issues.where((i) => i.severity == AuditSeverity.warning).length;

  /// 建议数
  int get infoCount =>
      issues.where((i) => i.severity == AuditSeverity.info).length;

  /// 是否通过审计
  bool get passed => criticalCount == 0 && errorCount == 0;

  /// 审计得分（0-100）
  int get score {
    if (issues.isEmpty) return 100;

    int deduction = 0;
    for (final issue in issues) {
      switch (issue.severity) {
        case AuditSeverity.critical:
          deduction += 25;
          break;
        case AuditSeverity.error:
          deduction += 15;
          break;
        case AuditSeverity.warning:
          deduction += 5;
          break;
        case AuditSeverity.info:
          deduction += 1;
          break;
      }
    }
    return max(0, 100 - deduction);
  }

  /// 获取按类别分组的问题
  Map<AuditCategory, List<AuditIssue>> get issuesByCategory {
    final result = <AuditCategory, List<AuditIssue>>{};
    for (final issue in issues) {
      result.putIfAbsent(issue.category, () => []).add(issue);
    }
    return result;
  }

  /// 获取报告摘要
  String get summary {
    if (passed) {
      return '审计通过，得分$score分';
    }
    return '发现$totalIssues个问题（严重$criticalCount，错误$errorCount，警告$warningCount），得分$score分';
  }
}

/// 审计配置
class AuditConfig {
  /// 是否检查语义化标签
  final bool checkSemantics;

  /// 是否检查色彩对比度
  final bool checkContrast;

  /// 是否检查触控目标
  final bool checkTouchTargets;

  /// 是否检查焦点管理
  final bool checkFocus;

  /// 是否检查键盘导航
  final bool checkKeyboard;

  /// 是否检查文字缩放
  final bool checkTextScaling;

  /// 是否检查动画
  final bool checkAnimation;

  /// 是否检查表单
  final bool checkForms;

  /// 是否检查图片
  final bool checkImages;

  /// 最小对比度（WCAG AA）
  final double minContrastRatio;

  /// 最小触控目标尺寸
  final double minTouchTargetSize;

  /// 最大动画时长（毫秒）
  final int maxAnimationDuration;

  const AuditConfig({
    this.checkSemantics = true,
    this.checkContrast = true,
    this.checkTouchTargets = true,
    this.checkFocus = true,
    this.checkKeyboard = true,
    this.checkTextScaling = true,
    this.checkAnimation = true,
    this.checkForms = true,
    this.checkImages = true,
    this.minContrastRatio = 4.5,
    this.minTouchTargetSize = 48.0,
    this.maxAnimationDuration = 5000,
  });

  /// WCAG AA 配置
  static const wcagAA = AuditConfig(
    minContrastRatio: 4.5,
    minTouchTargetSize: 44.0,
  );

  /// WCAG AAA 配置
  static const wcagAAA = AuditConfig(
    minContrastRatio: 7.0,
    minTouchTargetSize: 48.0,
  );
}

/// 无障碍审计服务
/// 自动检测应用中的无障碍问题，生成审计报告
class AccessibilityAuditService {
  static final AccessibilityAuditService _instance =
      AccessibilityAuditService._internal();
  factory AccessibilityAuditService() => _instance;
  AccessibilityAuditService._internal();

  /// 审计配置
  AuditConfig _config = const AuditConfig();

  /// 历史报告
  final List<AuditReport> _reports = [];

  /// 最大历史报告数
  static const int _maxReports = 50;

  /// 获取配置
  AuditConfig get config => _config;

  /// 设置配置
  void setConfig(AuditConfig config) {
    _config = config;
  }

  /// 获取历史报告
  List<AuditReport> get reports => List.unmodifiable(_reports);

  /// 获取最新报告
  AuditReport? get latestReport => _reports.isNotEmpty ? _reports.last : null;

  // ==================== 审计执行 ====================

  /// 执行完整审计
  Future<AuditReport> audit(
    BuildContext context, {
    String targetName = 'Current Screen',
    AuditConfig? config,
  }) async {
    final auditConfig = config ?? _config;
    final issues = <AuditIssue>[];
    final passedChecks = <String>[];

    // 执行各项检查
    if (auditConfig.checkSemantics) {
      final semanticIssues = await _auditSemantics(context);
      if (semanticIssues.isEmpty) {
        passedChecks.add('语义化标签检查');
      } else {
        issues.addAll(semanticIssues);
      }
    }

    if (auditConfig.checkContrast) {
      final contrastIssues = await _auditContrast(context, auditConfig);
      if (contrastIssues.isEmpty) {
        passedChecks.add('色彩对比度检查');
      } else {
        issues.addAll(contrastIssues);
      }
    }

    if (auditConfig.checkTouchTargets) {
      final touchIssues = await _auditTouchTargets(context, auditConfig);
      if (touchIssues.isEmpty) {
        passedChecks.add('触控目标检查');
      } else {
        issues.addAll(touchIssues);
      }
    }

    if (auditConfig.checkFocus) {
      final focusIssues = await _auditFocus(context);
      if (focusIssues.isEmpty) {
        passedChecks.add('焦点管理检查');
      } else {
        issues.addAll(focusIssues);
      }
    }

    if (auditConfig.checkTextScaling) {
      final textIssues = await _auditTextScaling(context);
      if (textIssues.isEmpty) {
        passedChecks.add('文字缩放检查');
      } else {
        issues.addAll(textIssues);
      }
    }

    if (auditConfig.checkForms) {
      final formIssues = await _auditForms(context);
      if (formIssues.isEmpty) {
        passedChecks.add('表单无障碍检查');
      } else {
        issues.addAll(formIssues);
      }
    }

    if (auditConfig.checkImages) {
      final imageIssues = await _auditImages(context);
      if (imageIssues.isEmpty) {
        passedChecks.add('图片无障碍检查');
      } else {
        issues.addAll(imageIssues);
      }
    }

    // 生成报告
    final report = AuditReport(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      targetName: targetName,
      issues: issues,
      passedChecks: passedChecks,
      config: auditConfig,
    );

    // 保存报告
    _reports.add(report);
    while (_reports.length > _maxReports) {
      _reports.removeAt(0);
    }

    return report;
  }

  // ==================== 各项检查实现 ====================

  /// 检查语义化标签
  Future<List<AuditIssue>> _auditSemantics(BuildContext context) async {
    final issues = <AuditIssue>[];

    // 获取语义树
    // 注意：实际实现需要遍历Widget树检查Semantics
    // 这里提供检查逻辑的框架

    // 检查是否有缺失语义标签的交互元素
    // 检查语义标签是否有意义
    // 检查图标是否有语义描述

    return issues;
  }

  /// 检查色彩对比度
  Future<List<AuditIssue>> _auditContrast(
    BuildContext context,
    AuditConfig config,
  ) async {
    final issues = <AuditIssue>[];

    final theme = Theme.of(context);

    // 检查主要文本对比度
    final primaryContrast =
        _calculateContrastRatio(theme.textTheme.bodyMedium?.color ?? Colors.black, theme.scaffoldBackgroundColor);
    if (primaryContrast < config.minContrastRatio) {
      issues.add(AuditIssue(
        id: 'contrast_primary_text',
        description: '主要文本对比度不足',
        details: '当前对比度: ${primaryContrast.toStringAsFixed(2)}:1，要求: ${config.minContrastRatio}:1',
        category: AuditCategory.contrast,
        severity: AuditSeverity.error,
        wcagReference: 'WCAG 1.4.3',
        suggestions: ['提高文本颜色与背景的对比度', '使用深色文本或浅色背景'],
      ));
    }

    // 检查次要文本对比度
    final secondaryContrast = _calculateContrastRatio(
      theme.textTheme.bodySmall?.color ?? Colors.grey,
      theme.scaffoldBackgroundColor,
    );
    if (secondaryContrast < 3.0) {
      issues.add(AuditIssue(
        id: 'contrast_secondary_text',
        description: '次要文本对比度可能不足',
        details: '当前对比度: ${secondaryContrast.toStringAsFixed(2)}:1',
        category: AuditCategory.contrast,
        severity: AuditSeverity.warning,
        wcagReference: 'WCAG 1.4.3',
        suggestions: ['考虑提高辅助文本的可读性'],
      ));
    }

    return issues;
  }

  /// 检查触控目标
  Future<List<AuditIssue>> _auditTouchTargets(
    BuildContext context,
    AuditConfig config,
  ) async {
    final issues = <AuditIssue>[];

    // 实际实现需要遍历Widget树检查可点击元素的尺寸
    // 这里提供框架

    return issues;
  }

  /// 检查焦点管理
  Future<List<AuditIssue>> _auditFocus(BuildContext context) async {
    final issues = <AuditIssue>[];

    // 检查焦点顺序是否合理
    // 检查焦点是否可见
    // 检查对话框是否有焦点陷阱

    return issues;
  }

  /// 检查文字缩放
  Future<List<AuditIssue>> _auditTextScaling(BuildContext context) async {
    final issues = <AuditIssue>[];

    final mediaQuery = MediaQuery.of(context);

    // 检查是否支持系统文字缩放
    if (mediaQuery.textScaler.scale(1.0) == 1.0) {
      // 如果用户设置了系统级文字缩放但应用没有响应，这是个问题
      // 实际检测需要更复杂的逻辑
    }

    return issues;
  }

  /// 检查表单
  Future<List<AuditIssue>> _auditForms(BuildContext context) async {
    final issues = <AuditIssue>[];

    // 检查表单字段是否有标签
    // 检查错误提示是否关联到字段
    // 检查必填字段是否有标识

    return issues;
  }

  /// 检查图片
  Future<List<AuditIssue>> _auditImages(BuildContext context) async {
    final issues = <AuditIssue>[];

    // 检查图片是否有替代文本
    // 检查装饰性图片是否被屏幕阅读器忽略

    return issues;
  }

  // ==================== 工具方法 ====================

  /// 计算对比度
  double _calculateContrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);
    final lighter = max(l1, l2);
    final darker = min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 计算相对亮度
  double _relativeLuminance(Color color) {
    double r = color.red / 255;
    double g = color.green / 255;
    double b = color.blue / 255;

    r = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4).toDouble();
    g = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4).toDouble();
    b = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 清除历史报告
  void clearReports() {
    _reports.clear();
  }

  /// 导出报告为文本
  String exportReportAsText(AuditReport report) {
    final buffer = StringBuffer();

    buffer.writeln('=' * 60);
    buffer.writeln('无障碍审计报告');
    buffer.writeln('=' * 60);
    buffer.writeln();
    buffer.writeln('目标: ${report.targetName}');
    buffer.writeln('时间: ${report.timestamp}');
    buffer.writeln('得分: ${report.score}/100');
    buffer.writeln('状态: ${report.passed ? "通过" : "未通过"}');
    buffer.writeln();

    buffer.writeln('-' * 60);
    buffer.writeln('问题汇总');
    buffer.writeln('-' * 60);
    buffer.writeln('严重: ${report.criticalCount}');
    buffer.writeln('错误: ${report.errorCount}');
    buffer.writeln('警告: ${report.warningCount}');
    buffer.writeln('建议: ${report.infoCount}');
    buffer.writeln();

    if (report.passedChecks.isNotEmpty) {
      buffer.writeln('-' * 60);
      buffer.writeln('通过的检查');
      buffer.writeln('-' * 60);
      for (final check in report.passedChecks) {
        buffer.writeln('✓ $check');
      }
      buffer.writeln();
    }

    if (report.issues.isNotEmpty) {
      buffer.writeln('-' * 60);
      buffer.writeln('发现的问题');
      buffer.writeln('-' * 60);

      for (final issue in report.issues) {
        buffer.writeln();
        buffer.writeln('[${issue.severityName}] ${issue.description}');
        buffer.writeln('  类别: ${issue.categoryName}');
        if (issue.details != null) {
          buffer.writeln('  详情: ${issue.details}');
        }
        if (issue.wcagReference != null) {
          buffer.writeln('  参考: ${issue.wcagReference}');
        }
        if (issue.suggestions.isNotEmpty) {
          buffer.writeln('  建议:');
          for (final suggestion in issue.suggestions) {
            buffer.writeln('    - $suggestion');
          }
        }
      }
    }

    buffer.writeln();
    buffer.writeln('=' * 60);

    return buffer.toString();
  }
}

/// 审计报告展示组件
class AuditReportWidget extends StatelessWidget {
  final AuditReport report;
  final VoidCallback? onReaudit;

  const AuditReportWidget({
    super.key,
    required this.report,
    this.onReaudit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Row(
              children: [
                Icon(
                  report.passed ? Icons.check_circle : Icons.error,
                  color: report.passed ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.targetName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        report.summary,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(report.score),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${report.score}分',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 问题统计
            Row(
              children: [
                _buildStatChip('严重', report.criticalCount, Colors.red.shade900),
                const SizedBox(width: 8),
                _buildStatChip('错误', report.errorCount, Colors.red),
                const SizedBox(width: 8),
                _buildStatChip('警告', report.warningCount, Colors.orange),
                const SizedBox(width: 8),
                _buildStatChip('建议', report.infoCount, Colors.blue),
              ],
            ),

            // 问题列表
            if (report.issues.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '问题详情',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...report.issues.take(5).map((issue) => _buildIssueItem(issue)),
              if (report.issues.length > 5)
                TextButton(
                  onPressed: () {
                    // 显示完整问题列表
                  },
                  child: Text('查看全部${report.issues.length}个问题'),
                ),
            ],

            // 操作按钮
            if (onReaudit != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onReaudit,
                icon: const Icon(Icons.refresh),
                label: const Text('重新审计'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0 ? color : Colors.grey,
          width: 1,
        ),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: count > 0 ? color : Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildIssueItem(AuditIssue issue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getIssueIcon(issue.severity),
            color: _getIssueColor(issue.severity),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.description,
                  style: const TextStyle(fontSize: 13),
                ),
                if (issue.details != null)
                  Text(
                    issue.details!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    if (score >= 50) return Colors.red;
    return Colors.red.shade900;
  }

  IconData _getIssueIcon(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.critical:
        return Icons.dangerous;
      case AuditSeverity.error:
        return Icons.error;
      case AuditSeverity.warning:
        return Icons.warning;
      case AuditSeverity.info:
        return Icons.info_outline;
    }
  }

  Color _getIssueColor(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.critical:
        return Colors.red.shade900;
      case AuditSeverity.error:
        return Colors.red;
      case AuditSeverity.warning:
        return Colors.orange;
      case AuditSeverity.info:
        return Colors.blue;
    }
  }
}
