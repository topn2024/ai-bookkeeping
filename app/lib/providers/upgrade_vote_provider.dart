import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/upgrade_vote_page.dart';
import 'member_provider.dart';

final upgradeVoteProvider = Provider<List<VoteMember>>((ref) {
  final memberState = ref.watch(memberProvider);
  final members = memberState.members;

  // Convert LedgerMembers to VoteMembers
  // In a real implementation, vote status would be stored in database
  return members.asMap().entries.map((entry) {
    final index = entry.key;
    final member = entry.value;

    // Generate color based on index
    final colors = [
      const Color(0xFF42A5F5),
      const Color(0xFFE91E63),
      const Color(0xFF66BB6A),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
    ];

    return VoteMember(
      id: member.id,
      name: member.nickname ?? member.userName,
      emoji: '👤', // Default emoji, could be customized per member
      color: colors[index % colors.length],
      status: VoteStatus.pending, // Default to pending
      voteTime: null,
    );
  }).toList();
});
