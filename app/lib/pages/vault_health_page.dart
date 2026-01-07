import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// 预算健康状态页面
/// 原型设计 3.06：状态警告
/// - 整体健康评分
/// - 超支警告列表
/// - 即将用完警告
/// - 健康状态小金库
/// - AI调整建议
class VaultHealthPage extends ConsumerWidget {
  const VaultHealthPage({super.key});

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
                    _buildHealthScore(context, theme),
                    _buildOverspentSection(context, theme),
                    _buildAlmostEmptySection(context, theme),
                    _buildHealthySection(context, theme),
                    _buildAISuggestion(context, theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
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
              '预算健康状态',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 健康评分卡片
  Widget _buildHealthScore(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '72',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
          Text(
            '预算健康指数',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '2个小金库需要关注',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 超支警告
  Widget _buildOverspentSection(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                '超支警告',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWarningItem(
            context,
            theme,
            icon: Icons.restaurant,
            iconColor: Colors.white,
            iconBgColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)],
            name: '餐饮',
            status: '超支 ¥320',
            statusColor: AppColors.error,
            amount: '-¥320',
            budget: '预算 ¥2,000',
          ),
        ],
      ),
    );
  }

  /// 即将用完
  Widget _buildAlmostEmptySection(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Color(0xFFF9A825), size: 20),
              const SizedBox(width: 8),
              const Text(
                '即将用完',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF9A825),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWarningItem(
            context,
            theme,
            icon: Icons.local_cafe,
            iconColor: Colors.white,
            iconBgColors: [const Color(0xFFFFC107), const Color(0xFFFFD54F)],
            name: '娱乐',
            status: '仅剩 8%',
            statusColor: const Color(0xFFF9A825),
            amount: '¥80',
            budget: '预算 ¥1,000',
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required List<Color> iconBgColors,
    required String name,
    required String status,
    required Color statusColor,
    required String amount,
    required String budget,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: iconBgColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
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
                  status,
                  style: TextStyle(fontSize: 11, color: statusColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              Text(
                budget,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 健康状态
  Widget _buildHealthySection(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                '健康',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '3个小金库',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHealthyChip(context, theme, '房租', '100%'),
              const SizedBox(width: 8),
              _buildHealthyChip(context, theme, '交通', '65%'),
              const SizedBox(width: 8),
              _buildHealthyChip(context, theme, '储蓄', '50%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyChip(
    BuildContext context,
    ThemeData theme,
    String name,
    String percent,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              percent,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AI建议
  Widget _buildAISuggestion(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEBF3FF), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF6495ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '调整建议',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '建议从"交通"小金库调拨¥200到"餐饮"，或减少本月餐饮外出次数。',
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
}
