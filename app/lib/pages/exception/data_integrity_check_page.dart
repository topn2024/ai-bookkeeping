import 'package:flutter/material.dart';

/// 数据完整性检查页面
/// 原型设计 11.03：数据完整性检查
/// - 检查结果概览卡片
/// - 问题列表（孤儿交易、余额不一致、疑似重复交易）
/// - 操作按钮（查看详情、自动修复）
class DataIntegrityCheckPage extends StatefulWidget {
  const DataIntegrityCheckPage({super.key});

  @override
  State<DataIntegrityCheckPage> createState() => _DataIntegrityCheckPageState();
}

class _DataIntegrityCheckPageState extends State<DataIntegrityCheckPage> {
  bool _isChecking = false;
  List<IntegrityIssue> _issues = [];
  int _checkedRecords = 0;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() {
      _isChecking = true;
      _checkedRecords = 0;
    });

    // 模拟检查过程
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isChecking = false;
      _checkedRecords = 1234;
      _issues = [
        IntegrityIssue(
          id: '1',
          type: IssueType.orphanTransaction,
          title: '孤儿交易记录',
          description: '关联的账户已删除',
          canAutoFix: true,
        ),
        IntegrityIssue(
          id: '2',
          type: IssueType.balanceMismatch,
          title: '账户余额不一致',
          description: '招商银行：差额 ¥12.50',
          canAutoFix: true,
        ),
        IntegrityIssue(
          id: '3',
          type: IssueType.duplicateTransaction,
          title: '疑似重复交易',
          description: '发现 2 条可能重复的记录',
          canAutoFix: false,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final autoFixCount = _issues.where((i) => i.canAutoFix).length;
    final manualFixCount = _issues.where((i) => !i.canAutoFix).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCard(theme, autoFixCount, manualFixCount),
                    const SizedBox(height: 16),
                    if (_issues.isNotEmpty) ...[
                      _buildIssuesList(theme),
                      const SizedBox(height: 16),
                      _buildActionButtons(theme, autoFixCount),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '数据完整性检查',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _runCheck,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: _isChecking
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 概览卡片
  Widget _buildOverviewCard(ThemeData theme, int autoFixCount, int manualFixCount) {
    final hasIssues = _issues.isNotEmpty;
    final gradientColors = hasIssues
        ? [const Color(0xFFFFB74D), const Color(0xFFD97706)]
        : [const Color(0xFF66BB6A), const Color(0xFF43A047)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasIssues ? Icons.warning : Icons.check_circle,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasIssues ? '发现 ${_issues.length} 个问题' : '数据完整性良好',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    if (hasIssues)
                      Text(
                        '其中 $autoFixCount 个可自动修复',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('已检查记录', '$_checkedRecords'),
              _buildStatItem('可自动修复', '$autoFixCount'),
              _buildStatItem('需手动处理', '$manualFixCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 问题列表
  Widget _buildIssuesList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '问题详情',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: _issues.map((issue) => _buildIssueItem(theme, issue)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIssueItem(ThemeData theme, IntegrityIssue issue) {
    final iconData = _getIssueIcon(issue.type);
    final iconColor = issue.canAutoFix
        ? const Color(0xFFFFB74D)
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${issue.description} · ${issue.canAutoFix ? "可自动修复" : "需手动确认"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: issue.canAutoFix
                  ? const Color(0xFF4DB6AC).withValues(alpha: 0.15)
                  : theme.colorScheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              issue.canAutoFix ? '可修复' : '需确认',
              style: TextStyle(
                fontSize: 11,
                color: issue.canAutoFix
                    ? const Color(0xFF26A69A)
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIssueIcon(IssueType type) {
    switch (type) {
      case IssueType.orphanTransaction:
        return Icons.link_off;
      case IssueType.balanceMismatch:
        return Icons.calculate;
      case IssueType.duplicateTransaction:
        return Icons.content_copy;
    }
  }

  /// 操作按钮
  Widget _buildActionButtons(ThemeData theme, int autoFixCount) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showDetails(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('查看详情'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: autoFixCount > 0 ? () => _autoFix(context) : null,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('自动修复'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('查看问题详情...')),
    );
  }

  void _autoFix(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在自动修复...')),
    );
  }
}

/// 问题类型
enum IssueType {
  orphanTransaction,    // 孤儿交易
  balanceMismatch,      // 余额不一致
  duplicateTransaction, // 重复交易
}

/// 完整性问题
class IntegrityIssue {
  final String id;
  final IssueType type;
  final String title;
  final String description;
  final bool canAutoFix;

  IntegrityIssue({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.canAutoFix,
  });
}
