import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 15.11 家庭生日祝福页面
/// 展示家庭成员生日庆祝和年度投入统计
class FamilyBirthdayPage extends ConsumerWidget {
  final String memberName;
  final Map<String, double> yearlyInvestments;

  const FamilyBirthdayPage({
    super.key,
    required this.memberName,
    required this.yearlyInvestments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 关闭按钮
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              // 生日庆祝
              _buildCelebration(),
              // 家庭投入统计
              _buildInvestmentStats(l10n),
              // 温情寄语
              _buildWarmMessage(),
              const Spacer(),
              // 操作按钮
              _buildActionButton(context, l10n),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 蛋糕动画
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFECB3), Color(0xFFFFD54F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🎂',
                style: TextStyle(fontSize: 60),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '今天是$memberName的生日！',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF57F17),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '祝生日快乐，健康成长 🎉',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFFFA000),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentStats(AppLocalizations l10n) {
    final investments = [
      {
        'icon': '📚',
        'label': l10n.education,
        'amount': yearlyInvestments['education'] ?? 12000,
        'color': const Color(0xFFE3F2FD),
        'textColor': const Color(0xFF1565C0),
      },
      {
        'icon': '🎮',
        'label': l10n.hobbies,
        'amount': yearlyInvestments['hobbies'] ?? 3500,
        'color': const Color(0xFFF3E5F5),
        'textColor': const Color(0xFF7B1FA2),
      },
      {
        'icon': '👕',
        'label': l10n.growth,
        'amount': yearlyInvestments['growth'] ?? 5200,
        'color': const Color(0xFFE8F5E9),
        'textColor': const Color(0xFF2E7D32),
      },
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '这一年，家人们为$memberName投入了',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...investments.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item['color'] as Color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          item['icon'] as String,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      '¥${(item['amount'] as double).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: item['textColor'] as Color,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWarmMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text(
            '💝',
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(height: 8),
          Text(
            '每一分钱，都是满满的爱',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFE65100),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l10n.generateBirthdayCard}功能开发中')),
            );
          },
          icon: const Icon(Icons.card_giftcard, size: 18),
          label: Text(l10n.generateBirthdayCard),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
