import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// 钱龄预算联动页面
/// 原型设计 2.08：钱龄 × 预算
/// - 钱龄影响预测卡片
/// - 各预算项对钱龄的影响分析
/// - AI建议提升钱龄
/// - 调整预算操作按钮
class MoneyAgeBudgetPage extends ConsumerWidget {
  const MoneyAgeBudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPredictionCard(context, theme),
                    _buildBudgetImpactList(context, theme),
                    _buildAISuggestion(context, theme),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildActionButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
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
              '钱龄 × 预算',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 钱龄影响预测卡片
  Widget _buildPredictionCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 标题说明
          Column(
            children: [
              Text(
                '按当前预算执行',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '月末预计钱龄',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 钱龄对比
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 当前
              Column(
                children: [
                  const Text(
                    '42天',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.arrow_forward,
                  color: AppColors.success,
                ),
              ),
              // 预计
              Column(
                children: [
                  Text(
                    '48天',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    '+6天 ↑',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 各预算项对钱龄的影响分析
  Widget _buildBudgetImpactList(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '各预算项对钱龄的影响',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // 餐饮预算
          _buildBudgetImpactItem(
            context,
            theme,
            emoji: '🍜',
            name: '餐饮预算',
            current: 1800,
            budget: 2500,
            impact: -8,
            isPositive: false,
            progressPercent: 0.72,
            progressColor: AppColors.warning,
          ),
          const SizedBox(height: 8),
          // 交通预算
          _buildBudgetImpactItem(
            context,
            theme,
            emoji: '🚗',
            name: '交通预算',
            current: 320,
            budget: 600,
            impact: -2,
            isPositive: false,
            progressPercent: 0.53,
            progressColor: AppColors.success,
          ),
          const SizedBox(height: 8),
          // 储蓄计划
          _buildBudgetImpactItem(
            context,
            theme,
            emoji: '💰',
            name: '储蓄计划',
            current: 3000,
            budget: 3000,
            impact: 16,
            isPositive: true,
            progressPercent: 1.0,
            progressColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetImpactItem(
    BuildContext context,
    ThemeData theme, {
    required String emoji,
    required String name,
    required double current,
    required double budget,
    required int impact,
    required bool isPositive,
    required double progressPercent,
    required Color progressColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '¥${current.toStringAsFixed(0)} / ¥${budget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}$impact天',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text(
                    isPositive ? '贡献' : '影响',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercent,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI建议
  Widget _buildAISuggestion(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '提升钱龄建议',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '将餐饮预算从¥2,500降至¥2,000，每月可额外储蓄¥500，预计可将钱龄��升至52天（+10天）',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              // 调整预算以提升钱龄
            },
            icon: const Icon(Icons.tune),
            label: const Text('调整预算以提升钱龄'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
