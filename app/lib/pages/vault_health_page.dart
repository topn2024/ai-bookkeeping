import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/budget_vault_provider.dart';
import '../models/budget_vault.dart';
import '../theme/app_theme.dart';
import 'vault_detail_page.dart';

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
    final vaultState = ref.watch(budgetVaultProvider);
    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();

    // 分类小金库状态
    final overspentVaults = <_VaultData>[];
    final almostEmptyVaults = <_VaultData>[];
    final healthyVaults = <_VaultData>[];

    for (final vault in vaults) {
      final remaining = vault.targetAmount - vault.allocatedAmount;
      final progress = vault.targetAmount > 0
          ? (vault.allocatedAmount / vault.targetAmount).clamp(0.0, 2.0)
          : 0.0;
      final remainingPercent = vault.targetAmount > 0
          ? ((remaining / vault.targetAmount) * 100).round()
          : 100;

      final data = _VaultData(
        vault: vault,
        name: vault.name,
        remaining: remaining,
        targetAmount: vault.targetAmount,
        progress: progress,
        remainingPercent: remainingPercent,
      );

      if (remaining < 0) {
        overspentVaults.add(data);
      } else if (remainingPercent <= 20 && remainingPercent > 0) {
        almostEmptyVaults.add(data);
      } else {
        healthyVaults.add(data);
      }
    }

    // 计算健康评分
    final totalVaults = vaults.length;
    final problemVaults = overspentVaults.length + almostEmptyVaults.length;
    final healthScore = totalVaults > 0
        ? ((totalVaults - problemVaults * 1.5) / totalVaults * 100).round().clamp(0, 100)
        : 100;

    // 生成建议
    String suggestion = '您的预算状态良好，继续保持！';
    if (overspentVaults.isNotEmpty) {
      suggestion = '建议关注${overspentVaults.first.name}的支出，适当调整预算分配。';
    } else if (almostEmptyVaults.isNotEmpty) {
      suggestion = '${almostEmptyVaults.first.name}预算即将用完，请注意控制支出。';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHealthScore(context, theme, healthScore, problemVaults),
                    if (overspentVaults.isNotEmpty)
                      _buildOverspentSection(context, theme, overspentVaults),
                    if (almostEmptyVaults.isNotEmpty)
                      _buildAlmostEmptySection(context, theme, almostEmptyVaults),
                    if (healthyVaults.isNotEmpty)
                      _buildHealthySection(context, theme, healthyVaults),
                    _buildAISuggestion(context, theme, suggestion),
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
  Widget _buildHealthScore(BuildContext context, ThemeData theme, int score, int problemCount) {
    Color scoreColor;
    if (score >= 80) {
      scoreColor = AppColors.success;
    } else if (score >= 60) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

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
            '$score',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: scoreColor,
            ),
          ),
          Text(
            '预算健康指数',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            problemCount > 0 ? '$problemCount个小金库需要关注' : '所有小金库状态良好',
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
  Widget _buildOverspentSection(BuildContext context, ThemeData theme, List<_VaultData> vaults) {
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
          ...vaults.map((v) => _buildWarningItem(
            context,
            theme,
            vault: v.vault,
            icon: _getVaultIcon(v.name),
            iconColor: Colors.white,
            iconBgColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)],
            name: v.name,
            status: '超支 ¥${(-v.remaining).toStringAsFixed(0)}',
            statusColor: AppColors.error,
            amount: '-¥${(-v.remaining).toStringAsFixed(0)}',
            budget: '预算 ¥${v.targetAmount.toStringAsFixed(0)}',
          )),
        ],
      ),
    );
  }

  /// 即将用完
  Widget _buildAlmostEmptySection(BuildContext context, ThemeData theme, List<_VaultData> vaults) {
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
          const Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFF9A825), size: 20),
              SizedBox(width: 8),
              Text(
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
          ...vaults.map((v) => _buildWarningItem(
            context,
            theme,
            vault: v.vault,
            icon: _getVaultIcon(v.name),
            iconColor: Colors.white,
            iconBgColors: [const Color(0xFFFFC107), const Color(0xFFFFD54F)],
            name: v.name,
            status: '仅剩 ${v.remainingPercent}%',
            statusColor: const Color(0xFFF9A825),
            amount: '¥${v.remaining.toStringAsFixed(0)}',
            budget: '预算 ¥${v.targetAmount.toStringAsFixed(0)}',
          )),
        ],
      ),
    );
  }

  IconData _getVaultIcon(String name) {
    if (name.contains('餐') || name.contains('食')) return Icons.restaurant;
    if (name.contains('交通')) return Icons.directions_car;
    if (name.contains('娱乐')) return Icons.local_cafe;
    if (name.contains('购物')) return Icons.shopping_bag;
    if (name.contains('房') || name.contains('租')) return Icons.home;
    if (name.contains('储蓄') || name.contains('存')) return Icons.savings;
    return Icons.account_balance_wallet;
  }

  Widget _buildWarningItem(
    BuildContext context,
    ThemeData theme, {
    required BudgetVault vault,
    required IconData icon,
    required Color iconColor,
    required List<Color> iconBgColors,
    required String name,
    required String status,
    required Color statusColor,
    required String amount,
    required String budget,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VaultDetailPage(vault: vault),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
      ),
    );
  }

  /// 健康状态
  Widget _buildHealthySection(BuildContext context, ThemeData theme, List<_VaultData> vaults) {
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
                '${vaults.length}个小金库',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: vaults.take(3).map((v) =>
              _buildHealthyChip(context, theme, v.name, '${(v.progress * 100).toInt()}%')
            ).toList(),
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
              overflow: TextOverflow.ellipsis,
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
  Widget _buildAISuggestion(BuildContext context, ThemeData theme, String suggestion) {
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
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
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
                  suggestion,
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

class _VaultData {
  final BudgetVault vault;
  final String name;
  final double remaining;
  final double targetAmount;
  final double progress;
  final int remainingPercent;

  _VaultData({
    required this.vault,
    required this.name,
    required this.remaining,
    required this.targetAmount,
    required this.progress,
    required this.remainingPercent,
  });
}
