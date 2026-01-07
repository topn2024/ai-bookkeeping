import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// 位置智能钱龄分析页面
/// 原型设计 2.09：位置智能钱龄
/// - 综合钱龄 vs 日常钱龄对比
/// - 分场景钱龄列表
/// - 位置洞察建议
class MoneyAgeLocationPage extends ConsumerWidget {
  const MoneyAgeLocationPage({super.key});

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
                    _buildComparisonCard(context, theme),
                    _buildSceneList(context, theme),
                    _buildLocationInsight(context, theme),
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
              '位置智能钱龄',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.my_location,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 综合钱龄 vs 日常钱龄对比卡片
  Widget _buildComparisonCard(BuildContext context, ThemeData theme) {
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
          // 钱龄对比
          Row(
            children: [
              // 综合钱龄
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '综合钱龄',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '42',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        '天',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '良好',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 日常钱龄
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '日常钱龄',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '48',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      Text(
                        '天',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '优秀',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 说明
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '日常钱龄排除了旅行/出差消费，更准确反映日常财务状态',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 分场景钱龄列表
  Widget _buildSceneList(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.place,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                '分场景钱龄',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 家附近
          _buildSceneItem(
            context,
            theme,
            icon: Icons.home,
            iconColor: const Color(0xFF4CAF50),
            iconBgColor: const Color(0xFFE8F5E9),
            borderColor: const Color(0xFF4CAF50),
            name: '家附近',
            stats: '本月32笔 · ¥2,860',
            age: 52,
            ageColor: const Color(0xFF4CAF50),
            label: '最健康',
          ),
          const SizedBox(height: 8),
          // 公司周边
          _buildSceneItem(
            context,
            theme,
            icon: Icons.business,
            iconColor: const Color(0xFF1976D2),
            iconBgColor: const Color(0xFFE3F2FD),
            borderColor: const Color(0xFF64B5F6),
            name: '公司周边',
            stats: '本月28笔 · ¥1,580',
            age: 45,
            ageColor: const Color(0xFF1976D2),
            label: '良好',
          ),
          const SizedBox(height: 8),
          // 商圈购物
          _buildSceneItem(
            context,
            theme,
            icon: Icons.shopping_bag,
            iconColor: const Color(0xFFF57C00),
            iconBgColor: const Color(0xFFFFF3E0),
            borderColor: const Color(0xFFFFB74D),
            name: '商圈购物',
            stats: '本月8笔 · ¥3,200',
            age: 28,
            ageColor: const Color(0xFFF57C00),
            label: '需关注',
          ),
          const SizedBox(height: 8),
          // 旅行/出差
          _buildTravelSceneItem(context, theme),
        ],
      ),
    );
  }

  Widget _buildSceneItem(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Color borderColor,
    required String name,
    required String stats,
    required int age,
    required Color ageColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
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
                  stats,
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
                '$age天',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ageColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTravelSceneItem(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
            left: BorderSide(color: Color(0xFF9575CD), width: 4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flight,
                    color: Color(0xFF7E57C2), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '旅行/出差',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '本月5笔 · ¥4,800',
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
                  const Text(
                    '18天',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7E57C2),
                    ),
                  ),
                  Text(
                    '临时消费',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 说明
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info,
                  size: 12,
                  color: Color(0xFF5E35B1),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '临时消费已从日常钱龄中分离，不影响日常财务评估',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF5E35B1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 位置洞察建议
  Widget _buildLocationInsight(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              const Text(
                '位置洞察',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '商圈消费钱龄较低',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '周末商圈购物拉低了整体钱龄。建议：',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '- 设置商圈消费预算上限 800元/周',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '- 开启进入商圈时的预算提醒',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '- 预计可提升日常钱龄 3-5天',
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
          ),
        ],
      ),
    );
  }
}
