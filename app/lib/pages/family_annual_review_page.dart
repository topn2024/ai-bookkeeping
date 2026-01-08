import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 15.12 家庭年度回顾页面
/// 展示家庭全年记账数据和温馨时刻回顾
class FamilyAnnualReviewPage extends ConsumerWidget {
  final String familyName;
  final int year;
  final Map<String, dynamic> reviewData;

  const FamilyAnnualReviewPage({
    super.key,
    required this.familyName,
    required this.year,
    required this.reviewData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment(0, 0.3),
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 头部
                _buildHeader(),
                // 主要数据卡片
                _buildMainDataCard(l10n),
                // 分享按钮
                _buildShareButtons(l10n),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '👨‍👩‍👧 $familyName',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$year 年度回顾',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDataCard(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 核心数据
          _buildCoreStats(l10n),
          const Divider(height: 32),
          // 温馨时刻
          _buildWarmMoments(l10n),
          const SizedBox(height: 16),
          // 成员贡献
          _buildMemberContributions(l10n),
          const SizedBox(height: 20),
          // 新年寄语
          _buildNewYearMessage(),
        ],
      ),
    );
  }

  Widget _buildCoreStats(AppLocalizations l10n) {
    final stats = [
      {
        'value': reviewData['daysRecording'] ?? 365,
        'label': l10n.daysRecording,
        'color': AppTheme.primaryColor,
      },
      {
        'value': reviewData['familyDinners'] ?? 156,
        'label': l10n.familyDinners,
        'color': AppTheme.successColor,
      },
      {
        'value': reviewData['trips'] ?? 23,
        'label': l10n.tripsCount,
        'color': const Color(0xFFFF9800),
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: stats.map((stat) {
        return Column(
          children: [
            Text(
              '${stat['value']}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: stat['color'] as Color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stat['label'] as String,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildWarmMoments(AppLocalizations l10n) {
    final moments = [
      {
        'emoji': '🏖️',
        'title': l10n.warmestMoment,
        'description': reviewData['warmestMoment'] ?? '暑假全家三亚旅行',
        'color': const Color(0xFFE8F5E9),
      },
      {
        'emoji': '🚗',
        'title': l10n.biggestGoal,
        'description': reviewData['biggestGoal'] ?? '一起攒钱买了新车',
        'color': const Color(0xFFFFF3E0),
      },
      {
        'emoji': '🎬',
        'title': l10n.sharedTime,
        'description': '${reviewData['movieNights'] ?? 12}个电影之夜',
        'color': const Color(0xFFE3F2FD),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.yearlyWarmMoments,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...moments.map((moment) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: moment['color'] as Color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    moment['emoji'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moment['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        moment['description'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildMemberContributions(AppLocalizations l10n) {
    final members = [
      {
        'emoji': '👨',
        'name': reviewData['member1Name'] ?? '爸爸',
        'title': reviewData['member1Title'] ?? '记账王',
      },
      {
        'emoji': '👩',
        'name': reviewData['member2Name'] ?? '妈妈',
        'title': reviewData['member2Title'] ?? '省钱达人',
      },
      {
        'emoji': '👧',
        'name': reviewData['member3Name'] ?? '女儿',
        'title': reviewData['member3Title'] ?? '储蓄新星',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.familyContributions,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: members.map((member) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    member['emoji'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member['name'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    member['title'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNewYearMessage() {
    return Text(
      '${year + 1}，继续创造更多美好回忆 ❤️',
      style: const TextStyle(
        fontSize: 15,
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildShareButtons(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save_alt, size: 18),
              label: Text(l10n.saveImage),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share, size: 18),
              label: Text(l10n.shareToFamily),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
