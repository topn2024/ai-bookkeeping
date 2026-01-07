import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// 预算钱龄联动页面
/// 原型设计 3.07：预算钱龄联动
/// - 展示分配方案对钱龄的提升预测
/// - 各小金库对钱龄的影响（正面/中性/负面）
/// - 提升建议
class VaultBudgetAgePage extends ConsumerWidget {
  const VaultBudgetAgePage({super.key});

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
                    _buildAgePredictionCard(context, theme),
                    _buildImpactList(context, theme),
                    _buildOptimizationSuggestion(context, theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildApplyButton(context, theme),
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
              '预算钱龄联动',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 钱龄提升预测卡片
  Widget _buildAgePredictionCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '本次分配预计提升钱龄',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  const Text(
                    '42天',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    '当前',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Icon(Icons.trending_up, size: 32, color: AppColors.success),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    '48天',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    '+6天',
                    style: TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 各小金库对钱龄的影响
  Widget _buildImpactList(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '分配方案对钱龄的影响',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          // 储蓄类 - 正面影响
          _buildImpactItem(
            context,
            theme,
            icon: Icons.savings,
            iconBgColors: [const Color(0xFF4CAF50), const Color(0xFF81C784)],
            name: '应急金储备',
            subtitle: '储蓄 ¥3,000',
            impactDays: '+8天',
            impactColor: AppColors.success,
            impactBgColor: const Color(0xFFE8F5E9),
            hint: '储蓄相当于延迟消费，会显著提升钱龄',
            hintBgColor: const Color(0xFFE8F5E9),
          ),
          const SizedBox(height: 8),
          // 固定支出 - 中性
          _buildImpactItem(
            context,
            theme,
            icon: Icons.home,
            iconBgColors: [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)],
            name: '房租',
            subtitle: '固定 ¥4,000',
            impactDays: '0天',
            impactColor: theme.colorScheme.onSurfaceVariant,
            impactBgColor: const Color(0xFFF5F5F5),
          ),
          const SizedBox(height: 8),
          // 弹性支出 - 负面影响
          _buildImpactItem(
            context,
            theme,
            icon: Icons.restaurant,
            iconBgColors: [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
            name: '餐饮',
            subtitle: '弹性 ¥2,500',
            impactDays: '-2天',
            impactColor: AppColors.error,
            impactBgColor: const Color(0xFFFFEBEE),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactItem(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required List<Color> iconBgColors,
    required String name,
    required String subtitle,
    required String impactDays,
    required Color impactColor,
    required Color impactBgColor,
    String? hint,
    Color? hintBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconBgColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: impactBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  impactDays,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: impactColor,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hintBgColor ?? const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 14, color: impactColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(fontSize: 11, color: impactColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 优化建议
  Widget _buildOptimizationSuggestion(BuildContext context, ThemeData theme) {
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
          Icon(Icons.lightbulb, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '提升建议',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '将储蓄比例从20%提升到25%（+¥750），可额外提升钱龄3天，达到51天（优秀）',
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

  /// 应用按钮
  Widget _buildApplyButton(BuildContext context, ThemeData theme) {
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
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('优化方案已应用')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('应用优化方案'),
          ),
        ),
      ),
    );
  }
}
