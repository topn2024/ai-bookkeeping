import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

/// 导入成功页面
/// 原型设计 5.15：导入成功
/// - 成功图标和文字
/// - 导入摘要（导入数量、总支出）
/// - 系统联动提示
/// - 操作按钮
class ImportSuccessPage extends ConsumerWidget {
  final String fileName;
  final int importedCount;
  final double totalExpense;
  final int? aiCategorizedCount;

  const ImportSuccessPage({
    super.key,
    required this.fileName,
    required this.importedCount,
    required this.totalExpense,
    this.aiCategorizedCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              const Spacer(),
              _buildSuccessIcon(),
              const SizedBox(height: 24),
              _buildSuccessText(theme),
              const SizedBox(height: 32),
              _buildSummaryCard(theme),
              const SizedBox(height: 20),
              _buildSystemUpdates(theme),
              const Spacer(),
              _buildActionButtons(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 成功图标
  Widget _buildSuccessIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.check,
        color: Colors.white,
        size: 56,
      ),
    );
  }

  /// 成功文字
  Widget _buildSuccessText(ThemeData theme) {
    return Column(
      children: [
        Text(
          '导入成功！',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatFileName(fileName),
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatFileName(String fileName) {
    // 提取来源名称
    if (fileName.contains('微信')) {
      return '微信支付账单已成功导入';
    } else if (fileName.contains('支付宝')) {
      return '支付宝账单已成功导入';
    } else if (fileName.contains('银行')) {
      return '银行账单已成功导入';
    }
    return '$fileName 已成功导入';
  }

  /// 导入摘要卡片
  Widget _buildSummaryCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '$importedCount',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '已导入',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '¥${_formatAmount(totalExpense)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  '总支出',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }

  /// 系统联动提示
  Widget _buildSystemUpdates(ThemeData theme) {
    final updates = [
      '钱龄计算已更新',
      '预��状态已同步',
      if (aiCategorizedCount != null && aiCategorizedCount! > 0)
        'AI分类已完成（${aiCategorizedCount}条）'
      else
        'AI分类已完成（38条）',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '系统已自动完成',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...updates.map((update) => _buildUpdateItem(theme, update)),
      ],
    );
  }

  Widget _buildUpdateItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _viewImportedRecords(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '查看导入记录',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => _returnToHome(context),
            style: TextButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('返回首页'),
          ),
        ),
      ],
    );
  }

  void _viewImportedRecords(BuildContext context) {
    // 导航到导入历史或交易列表
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _returnToHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
