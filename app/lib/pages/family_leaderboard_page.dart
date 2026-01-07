import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 家庭成员排名数据
class MemberRanking {
  final String memberId;
  final String memberName;
  final String memberEmoji;
  final Color memberColor;
  final int recordCount;
  final int score;
  final int streak;
  final double savingsRate;
  final double savedAmount;
  final List<Badge> badges;

  MemberRanking({
    required this.memberId,
    required this.memberName,
    required this.memberEmoji,
    required this.memberColor,
    required this.recordCount,
    required this.score,
    required this.streak,
    required this.savingsRate,
    required this.savedAmount,
    required this.badges,
  });
}

class Badge {
  final String emoji;
  final String name;
  final Color color;

  Badge({
    required this.emoji,
    required this.name,
    required this.color,
  });
}

/// 15.10 家庭排行榜与激励页面
class FamilyLeaderboardPage extends ConsumerStatefulWidget {
  const FamilyLeaderboardPage({super.key});

  @override
  ConsumerState<FamilyLeaderboardPage> createState() => _FamilyLeaderboardPageState();
}

class _FamilyLeaderboardPageState extends ConsumerState<FamilyLeaderboardPage> {
  String _selectedPeriod = '本周';
  late List<MemberRanking> _rankings;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    _rankings = [
      MemberRanking(
        memberId: '1',
        memberName: '妈妈',
        memberEmoji: '妈',
        memberColor: const Color(0xFFA8E6CF),
        recordCount: 28,
        score: 98,
        streak: 7,
        savingsRate: 0.18,
        savedAmount: 360,
        badges: [
          Badge(emoji: '⭐', name: '记账之星', color: const Color(0xFFFFD700)),
          Badge(emoji: '🔥', name: '连续打卡30天', color: const Color(0xFFE91E63)),
          Badge(emoji: '💎', name: '预算管家', color: const Color(0xFF2196F3)),
          Badge(emoji: '🏅', name: '储蓄冠军', color: const Color(0xFF4CAF50)),
          Badge(emoji: '👑', name: '账本贡献者', color: const Color(0xFF9C27B0)),
        ],
      ),
      MemberRanking(
        memberId: '2',
        memberName: '爸爸',
        memberEmoji: '爸',
        memberColor: const Color(0xFFFF6B6B),
        recordCount: 21,
        score: 85,
        streak: 3,
        savingsRate: 0.05,
        savedAmount: 150,
        badges: [
          Badge(emoji: '📝', name: '记账新手', color: const Color(0xFF607D8B)),
          Badge(emoji: '🎯', name: '连续打卡7天', color: const Color(0xFFFF9800)),
          Badge(emoji: '💪', name: '家庭支柱', color: const Color(0xFF00BCD4)),
        ],
      ),
      MemberRanking(
        memberId: '3',
        memberName: '女儿',
        memberEmoji: '女',
        memberColor: const Color(0xFFDDA0DD),
        recordCount: 15,
        score: 72,
        streak: 5,
        savingsRate: 0.32,
        savedAmount: 480,
        badges: [
          Badge(emoji: '🌱', name: '节俭小能手', color: const Color(0xFF8BC34A)),
          Badge(emoji: '🎀', name: '零花钱管理师', color: const Color(0xFFFF5722)),
          Badge(emoji: '✨', name: '储蓄新星', color: const Color(0xFF673AB7)),
          Badge(emoji: '🌟', name: '好习惯养成', color: const Color(0xFFFFC107)),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n?.familyLeaderboard ?? '家庭排行榜',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间周期选择
            _buildPeriodSelector(),
            // 记账排行榜
            _buildRecordRanking(l10n),
            // 节俭排行榜
            _buildSavingsRanking(l10n),
            // 贡献勋章墙
            _buildBadgesWall(l10n),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['本周', '本月', '本年'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecordRanking(AppLocalizations? l10n) {
    final sortedByRecord = List<MemberRanking>.from(_rankings)
      ..sort((a, b) => b.recordCount.compareTo(a.recordCount));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 8),
              Text(
                l10n?.recordLeaderboard ?? '记账达人榜',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 第一名
                _buildTopRanker(sortedByRecord[0], 1, true),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                // 其他排名
                ...sortedByRecord.skip(1).toList().asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRanker(entry.value, entry.key + 2),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRanker(MemberRanking member, int rank, bool isRecordRank) {
    final medals = ['🥇', '🥈', '🥉'];
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [member.memberColor, member.memberColor.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFFFD700), width: 3),
              ),
              child: Center(
                child: Text(
                  member.memberEmoji,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: Text(
                medals[rank - 1],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.memberName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                isRecordRank
                    ? '$_selectedPeriod记账 ${member.recordCount} 笔'
                    : '预算节省率 ${(member.savingsRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isRecordRank ? '${member.score}分' : '省了¥${member.savedAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isRecordRank ? const Color(0xFFFF6B00) : AppTheme.successColor,
              ),
            ),
            if (isRecordRank)
              Text(
                '连续${member.streak}天',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRanker(MemberRanking member, int rank) {
    final medals = ['🥇', '🥈', '🥉'];
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [member.memberColor, member.memberColor.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  member.memberEmoji,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (rank <= 3)
              Positioned(
                top: -4,
                right: -4,
                child: Text(
                  medals[rank - 1],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.memberName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '记账 ${member.recordCount} 笔',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${member.score}分',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF78909C),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsRanking(AppLocalizations? l10n) {
    final sortedBySavings = List<MemberRanking>.from(_rankings)
      ..sort((a, b) => b.savingsRate.compareTo(a.savingsRate));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings, color: AppTheme.successColor, size: 22),
              const SizedBox(width: 8),
              Text(
                l10n?.savingsLeaderboard ?? '节俭达人榜',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
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
                // 第一名
                _buildSavingsTopRanker(sortedBySavings[0]),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: const Color(0xFF81C784).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                // 其他排名
                ...sortedBySavings.skip(1).map((member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildSavingsRanker(member),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsTopRanker(MemberRanking member) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [member.memberColor, member.memberColor.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.successColor, width: 2),
              ),
              child: Center(
                child: Text(
                  member.memberEmoji,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const Positioned(
              top: -6,
              right: -6,
              child: Text('🏆', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.memberName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '预算节省率 ${(member.savingsRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          '省了¥${member.savedAmount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.successColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsRanker(MemberRanking member) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [member.memberColor, member.memberColor.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              member.memberEmoji,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Text(
                member.memberName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Text(
                '节省率 ${(member.savingsRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          '省了¥${member.savedAmount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.successColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesWall(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech, color: Color(0xFF9C27B0), size: 22),
              const SizedBox(width: 8),
              Text(
                l10n?.badgesWall ?? '贡献勋章墙',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _rankings.map((member) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildMemberBadges(member),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBadges(MemberRanking member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [member.memberColor, member.memberColor.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  member.memberEmoji,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              member.memberName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Text(
              '共获得 ${member.badges.length} 枚勋章',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: member.badges.map((badge) {
            return Tooltip(
              message: badge.name,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [badge.color, badge.color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    badge.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
