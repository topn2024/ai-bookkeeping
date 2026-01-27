import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 投票成员数据
class VoteMember {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final VoteStatus status;
  final DateTime? voteTime;

  VoteMember({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.status,
    this.voteTime,
  });
}

enum VoteStatus {
  pending,
  approved,
  rejected,
}

/// 15.16 升级投票流程页面
/// 家庭成员投票决定是否升级模式
class UpgradeVotePage extends ConsumerStatefulWidget {
  const UpgradeVotePage({super.key});

  @override
  ConsumerState<UpgradeVotePage> createState() => _UpgradeVotePageState();
}

class _UpgradeVotePageState extends ConsumerState<UpgradeVotePage> {
  late List<VoteMember> _members;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    _members = [
      VoteMember(
        id: '1',
        name: '小明（我）',
        emoji: '👨',
        color: const Color(0xFF42A5F5),
        status: VoteStatus.approved,
        voteTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      VoteMember(
        id: '2',
        name: '小红',
        emoji: '👩',
        color: const Color(0xFFE91E63),
        status: VoteStatus.pending,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final approvedCount = _members.where((m) => m.status == VoteStatus.approved).length;
    final totalCount = _members.length;

    return Scaffold(
      
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.upgradeVote,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 投票进度卡片
                  _buildVoteProgressCard(approvedCount, totalCount, l10n),
                  const SizedBox(height: 24),
                  // 成员投票状态
                  _buildMemberVoteSection(l10n),
                  const SizedBox(height: 24),
                  // 投票说明
                  _buildVoteInfo(l10n),
                ],
              ),
            ),
          ),
          // 底部操作
          _buildBottomAction(l10n),
        ],
      ),
    );
  }

  Widget _buildVoteProgressCard(int approved, int total, AppLocalizations l10n) {
    final progress = approved / total;
    final allApproved = approved == total;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allApproved
              ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
              : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (allApproved ? const Color(0xFF4CAF50) : AppTheme.primaryColor)
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            allApproved ? Icons.check_circle : Icons.how_to_vote,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            allApproved
                ? (l10n.voteComplete)
                : (l10n.waitingForVotes),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$approved / $total 成员已同意',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberVoteSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.memberVoteStatus,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: _members.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final isLast = index == _members.length - 1;

              return Column(
                children: [
                  _buildMemberVoteItem(member),
                  if (!isLast)
                    Divider(height: 1, indent: 72, color: AppTheme.dividerColor),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberVoteItem(VoteMember member) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (member.status) {
      case VoteStatus.approved:
        statusText = '已同意';
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case VoteStatus.rejected:
        statusText = '已拒绝';
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        break;
      case VoteStatus.pending:
        statusText = '等待中';
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_empty;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [member.color, member.color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                member.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (member.voteTime != null)
                  Text(
                    _formatTime(member.voteTime!),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteInfo(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                l10n.voteRules,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• 需要所有成员同意才能升级\n• 投票有效期为7天\n• 任意成员拒绝则升级取消\n• 升级后数据会完整保留',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(AppLocalizations l10n) {
    final allApproved = _members.every((m) => m.status == VoteStatus.approved);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: allApproved
            ? ElevatedButton(
                onPressed: _completeUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.completeUpgrade),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sendReminder,
                      icon: const Icon(Icons.notifications, size: 18),
                      label: Text(l10n.remind),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  void _sendReminder() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已发送投票提醒'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _completeUpgrade() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Color(0xFFFFD700)),
            SizedBox(width: 8),
            Text('升级成功！'),
          ],
        ),
        content: const Text('恭喜！您的家庭账本已成功升级到完整模式，现在可以使用所有高级功能了。'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('开始体验'),
          ),
        ],
      ),
    );
  }
}
