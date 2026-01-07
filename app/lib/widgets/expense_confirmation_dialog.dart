import 'package:flutter/material.dart';
import 'dart:async';

import '../services/impulse_spending_interceptor.dart';

/// 消费确认弹窗
///
/// 在检测到冲动消费风险时显示，帮助用户做出理性决策
/// 支持多种风险等级的展示和交互
class ExpenseConfirmationDialog extends StatefulWidget {
  /// 消费金额
  final double amount;

  /// 商户名称
  final String? merchantName;

  /// 分类名称
  final String? categoryName;

  /// 拦截结果
  final InterceptionResult interceptionResult;

  /// 确认继续消费回调
  final VoidCallback? onConfirm;

  /// 取消消费回调
  final VoidCallback? onCancel;

  /// 延迟消费回调（添加到愿望清单）
  final VoidCallback? onDelay;

  const ExpenseConfirmationDialog({
    super.key,
    required this.amount,
    this.merchantName,
    this.categoryName,
    required this.interceptionResult,
    this.onConfirm,
    this.onCancel,
    this.onDelay,
  });

  /// 显示确认弹窗
  static Future<ConfirmationResult?> show({
    required BuildContext context,
    required double amount,
    String? merchantName,
    String? categoryName,
    required InterceptionResult interceptionResult,
  }) {
    return showModalBottomSheet<ConfirmationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseConfirmationDialog(
        amount: amount,
        merchantName: merchantName,
        categoryName: categoryName,
        interceptionResult: interceptionResult,
        onConfirm: () => Navigator.of(context).pop(ConfirmationResult.confirm),
        onCancel: () => Navigator.of(context).pop(ConfirmationResult.cancel),
        onDelay: () => Navigator.of(context).pop(ConfirmationResult.delay),
      ),
    );
  }

  @override
  State<ExpenseConfirmationDialog> createState() =>
      _ExpenseConfirmationDialogState();
}

class _ExpenseConfirmationDialogState extends State<ExpenseConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // 冷静期倒计时
  Timer? _cooldownTimer;
  int _remainingSeconds = 0;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _animationController.forward();

    // 根据风险等级设置冷静期
    _initCooldown();
  }

  void _initCooldown() {
    final decision = widget.interceptionResult.decision;

    // 根据决策类型设置冷静时间
    switch (decision) {
      case InterceptionDecision.stronglyDissuade:
        _remainingSeconds = 10; // 10秒冷静期
        break;
      case InterceptionDecision.suggestDelay:
        _remainingSeconds = 5; // 5秒冷静期
        break;
      case InterceptionDecision.warn:
        _remainingSeconds = 3; // 3秒冷静期
        break;
      case InterceptionDecision.allow:
        _canConfirm = true;
        return;
    }

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _canConfirm = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decision = widget.interceptionResult.decision;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 警告图标和标题
            _buildHeader(theme, decision),

            // 消费信息
            _buildExpenseInfo(theme),

            // 风险原因列表
            _buildRiskReasons(theme),

            // 建议列表
            if (widget.interceptionResult.suggestions.isNotEmpty)
              _buildSuggestions(theme),

            // 等待建议
            if (widget.interceptionResult.waitingSuggestion != null)
              _buildWaitingSuggestion(theme),

            // 操作按钮
            _buildActions(theme, decision),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, InterceptionDecision decision) {
    final color = _getDecisionColor(decision);
    final icon = _getDecisionIcon(decision);
    final title = _getDecisionTitle(decision);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 图标
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: color,
            ),
          ),
          const SizedBox(height: 16),

          // 标题
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),

          // 风险分数
          if (widget.interceptionResult.riskScore > 0) ...[
            const SizedBox(height: 8),
            _buildRiskScoreIndicator(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskScoreIndicator(ThemeData theme) {
    final score = widget.interceptionResult.riskScore;
    final color = _getRiskColor(score);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '风险指数',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 6,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: score / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${score.toStringAsFixed(0)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseInfo(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 金额
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '消费金额',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${widget.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),

          // 商户/分类
          if (widget.merchantName != null || widget.categoryName != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.merchantName != null) ...[
                    Text(
                      widget.merchantName!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                  if (widget.categoryName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.categoryName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskReasons(ThemeData theme) {
    final reasons = widget.interceptionResult.reasons;
    if (reasons.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '风险提示',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...reasons.map((reason) => _buildReasonItem(theme, reason)),
        ],
      ),
    );
  }

  Widget _buildReasonItem(ThemeData theme, InterceptionReason reason) {
    final color = _getSeverityColor(reason.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getReasonIcon(reason.code),
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '建议',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.interceptionResult.suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingSuggestion(ThemeData theme) {
    final suggestion = widget.interceptionResult.waitingSuggestion!;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 32,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.reason,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '等待后约${(suggestion.expectedSavingsRate * 100).toStringAsFixed(0)}%的用户会取消消费',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, InterceptionDecision decision) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 取消按钮（推荐）
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close),
              label: const Text('取消这笔消费'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 延迟按钮
          if (widget.onDelay != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onDelay,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('加入愿望清单'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 继续按钮（需要冷静期）
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _canConfirm ? widget.onConfirm : null,
              child: Text(
                _canConfirm
                    ? '我已仔细考虑，继续消费'
                    : '请冷静 $_remainingSeconds 秒...',
                style: TextStyle(
                  color: _canConfirm
                      ? theme.colorScheme.error
                      : theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDecisionColor(InterceptionDecision decision) {
    switch (decision) {
      case InterceptionDecision.stronglyDissuade:
        return Colors.red;
      case InterceptionDecision.suggestDelay:
        return Colors.orange;
      case InterceptionDecision.warn:
        return Colors.amber;
      case InterceptionDecision.allow:
        return Colors.green;
    }
  }

  IconData _getDecisionIcon(InterceptionDecision decision) {
    switch (decision) {
      case InterceptionDecision.stronglyDissuade:
        return Icons.warning_rounded;
      case InterceptionDecision.suggestDelay:
        return Icons.schedule;
      case InterceptionDecision.warn:
        return Icons.info_outline;
      case InterceptionDecision.allow:
        return Icons.check_circle_outline;
    }
  }

  String _getDecisionTitle(InterceptionDecision decision) {
    switch (decision) {
      case InterceptionDecision.stronglyDissuade:
        return '强烈建议取消';
      case InterceptionDecision.suggestDelay:
        return '建议延迟决定';
      case InterceptionDecision.warn:
        return '消费提醒';
      case InterceptionDecision.allow:
        return '确认消费';
    }
  }

  Color _getRiskColor(double score) {
    if (score >= 70) return Colors.red;
    if (score >= 50) return Colors.orange;
    if (score >= 30) return Colors.amber;
    return Colors.green;
  }

  Color _getSeverityColor(double severity) {
    if (severity >= 0.8) return Colors.red;
    if (severity >= 0.6) return Colors.orange;
    if (severity >= 0.4) return Colors.amber;
    return Colors.blue;
  }

  IconData _getReasonIcon(String code) {
    switch (code) {
      case 'VAULT_OVERSPENT':
      case 'VAULT_LOW_BALANCE':
        return Icons.account_balance_wallet;
      case 'LARGE_EXPENSE_ABSOLUTE':
      case 'LARGE_EXPENSE_RELATIVE':
        return Icons.attach_money;
      case 'MONEY_AGE_DANGER':
        return Icons.hourglass_empty;
      case 'LATE_NIGHT':
        return Icons.nightlight_round;
      case 'HIGH_FREQUENCY':
        return Icons.repeat;
      case 'LARGE_BUDGET_PORTION':
        return Icons.pie_chart;
      case 'EARLY_MONTH_LARGE':
        return Icons.calendar_today;
      case 'OPTIONAL_EXPENSE':
        return Icons.shopping_bag;
      default:
        return Icons.warning_amber;
    }
  }
}

/// 确认结果
enum ConfirmationResult {
  /// 确认继续消费
  confirm,

  /// 取消消费
  cancel,

  /// 延迟决定（加入愿望清单）
  delay,
}
