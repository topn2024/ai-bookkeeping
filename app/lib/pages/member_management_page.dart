import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../providers/member_provider.dart';

class MemberManagementPage extends ConsumerStatefulWidget {
  final String ledgerId;
  final String ledgerName;

  const MemberManagementPage({
    super.key,
    required this.ledgerId,
    required this.ledgerName,
  });

  @override
  ConsumerState<MemberManagementPage> createState() => _MemberManagementPageState();
}

class _MemberManagementPageState extends ConsumerState<MemberManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberState = ref.watch(memberProvider);
    final members = memberState.members.where((m) => m.ledgerId == widget.ledgerId).toList();
    final invites = memberState.invites.where((i) => i.ledgerId == widget.ledgerId).toList();
    final pendingApprovals = memberState.approvals.where(
      (a) => a.ledgerId == widget.ledgerId && a.status == ApprovalStatus.pending
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ledgerName} - 成员管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${members.length}'),
                isLabelVisible: members.isNotEmpty,
                child: const Icon(Icons.people),
              ),
              text: '成员',
            ),
            Tab(
              icon: Badge(
                label: Text('${invites.where((i) => i.isPending).length}'),
                isLabelVisible: invites.where((i) => i.isPending).isNotEmpty,
                child: const Icon(Icons.mail),
              ),
              text: '邀请',
            ),
            Tab(
              icon: Badge(
                label: Text('${pendingApprovals.length}'),
                isLabelVisible: pendingApprovals.isNotEmpty,
                child: const Icon(Icons.approval),
              ),
              text: '审批',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MemberListTab(
            ledgerId: widget.ledgerId,
            members: members,
          ),
          _InviteListTab(
            ledgerId: widget.ledgerId,
            ledgerName: widget.ledgerName,
            invites: invites,
          ),
          _ApprovalListTab(
            ledgerId: widget.ledgerId,
            approvals: memberState.approvals.where((a) => a.ledgerId == widget.ledgerId).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('邀请成员'),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InviteMemberDialog(
        ledgerId: widget.ledgerId,
        ledgerName: widget.ledgerName,
      ),
    );
  }
}

class _MemberListTab extends ConsumerWidget {
  final String ledgerId;
  final List<LedgerMember> members;

  const _MemberListTab({
    required this.ledgerId,
    required this.members,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无成员',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮邀请成员加入',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 按角色分组
    final groupedMembers = <MemberRole, List<LedgerMember>>{};
    for (final member in members) {
      groupedMembers.putIfAbsent(member.role, () => []).add(member);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final role in MemberRole.values)
          if (groupedMembers.containsKey(role)) ...[
            _buildRoleHeader(role, groupedMembers[role]!.length),
            ...groupedMembers[role]!.map((member) => _MemberCard(
              member: member,
              onEdit: () => _showEditMemberDialog(context, ref, member),
              onRemove: () => _confirmRemoveMember(context, ref, member),
            )),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  Widget _buildRoleHeader(MemberRole role, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(role.icon, size: 20, color: role.color),
          const SizedBox(width: 8),
          Text(
            '${role.displayName} ($count)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: role.color,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(BuildContext context, WidgetRef ref, LedgerMember member) {
    showDialog(
      context: context,
      builder: (context) => _EditMemberDialog(member: member),
    );
  }

  void _confirmRemoveMember(BuildContext context, WidgetRef ref, LedgerMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要移除 ${member.userName} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(memberProvider.notifier).removeMember(member.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已移除 ${member.userName}')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final LedgerMember member;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.role.color.withValues(alpha:0.2),
          backgroundImage: member.userAvatar != null
              ? NetworkImage(member.userAvatar!)
              : null,
          child: member.userAvatar == null
              ? Text(
                  member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                  style: TextStyle(color: member.role.color),
                )
              : null,
        ),
        title: Row(
          children: [
            Text(member.userName),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: member.role.color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(member.role.icon, size: 12, color: member.role.color),
                  const SizedBox(width: 4),
                  Text(
                    member.role.displayName,
                    style: TextStyle(fontSize: 12, color: member.role.color),
                  ),
                ],
              ),
            ),
            if (!member.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '已停用',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.userEmail != null)
              Text(member.userEmail!, style: const TextStyle(fontSize: 12)),
            Text(
              '加入于 ${_formatDate(member.joinedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: member.role != MemberRole.owner
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'remove') {
                    onRemove();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑权限')),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('移除成员', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _InviteListTab extends ConsumerWidget {
  final String ledgerId;
  final String ledgerName;
  final List<MemberInvite> invites;

  const _InviteListTab({
    required this.ledgerId,
    required this.ledgerName,
    required this.invites,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无邀请记录',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final pending = invites.where((i) => i.isPending).toList();
    final responded = invites.where((i) => !i.isPending).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          Text(
            '待接受 (${pending.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...pending.map((invite) => _InviteCard(
            invite: invite,
            onCancel: () => _cancelInvite(context, ref, invite),
            onCopyCode: () => _copyInviteCode(context, invite),
          )),
          const SizedBox(height: 16),
        ],
        if (responded.isNotEmpty) ...[
          Text(
            '历史记录 (${responded.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...responded.map((invite) => _InviteCard(
            invite: invite,
            showActions: false,
          )),
        ],
      ],
    );
  }

  void _cancelInvite(BuildContext context, WidgetRef ref, MemberInvite invite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消邀请'),
        content: const Text('确定要取消这个邀请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(memberProvider.notifier).cancelInvite(invite.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('邀请已取消')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _copyInviteCode(BuildContext context, MemberInvite invite) {
    if (invite.inviteCode != null) {
      Clipboard.setData(ClipboardData(text: invite.inviteCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邀请码已复制')),
      );
    }
  }
}

class _InviteCard extends StatelessWidget {
  final MemberInvite invite;
  final VoidCallback? onCancel;
  final VoidCallback? onCopyCode;
  final bool showActions;

  const _InviteCard({
    required this.invite,
    this.onCancel,
    this.onCopyCode,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: invite.role.color.withValues(alpha:0.2),
                  child: Icon(invite.role.icon, color: invite.role.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.inviteeEmail ?? '邀请码: ${invite.inviteCode}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Text(
                            '角色: ${invite.role.displayName}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: invite.status.color.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              invite.status.displayName,
                              style: TextStyle(fontSize: 10, color: invite.status.color),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  invite.isExpired
                      ? '已过期'
                      : '${_formatDate(invite.expiresAt)} 过期',
                  style: TextStyle(
                    fontSize: 12,
                    color: invite.isExpired ? Colors.red : Colors.grey[500],
                  ),
                ),
                const Spacer(),
                if (showActions && invite.isPending) ...[
                  TextButton.icon(
                    onPressed: onCopyCode,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('复制邀请码'),
                  ),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('取消', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}

class _ApprovalListTab extends ConsumerWidget {
  final String ledgerId;
  final List<ExpenseApproval> approvals;

  const _ApprovalListTab({
    required this.ledgerId,
    required this.approvals,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (approvals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.approval, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无审批记录',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final pending = approvals.where((a) => a.status == ApprovalStatus.pending).toList();
    final processed = approvals.where((a) => a.status != ApprovalStatus.pending).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          Text(
            '待审批 (${pending.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          ...pending.map((approval) => _ApprovalCard(
            approval: approval,
            onApprove: () => _handleApprove(context, ref, approval),
            onReject: () => _handleReject(context, ref, approval),
          )),
          const SizedBox(height: 16),
        ],
        if (processed.isNotEmpty) ...[
          Text(
            '已处理 (${processed.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...processed.map((approval) => _ApprovalCard(
            approval: approval,
            showActions: false,
          )),
        ],
      ],
    );
  }

  void _handleApprove(BuildContext context, WidgetRef ref, ExpenseApproval approval) {
    showDialog(
      context: context,
      builder: (context) => _ApprovalActionDialog(
        approval: approval,
        isApprove: true,
      ),
    );
  }

  void _handleReject(BuildContext context, WidgetRef ref, ExpenseApproval approval) {
    showDialog(
      context: context,
      builder: (context) => _ApprovalActionDialog(
        approval: approval,
        isApprove: false,
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final ExpenseApproval approval;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool showActions;

  const _ApprovalCard({
    required this.approval,
    this.onApprove,
    this.onReject,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: approval.status.color.withValues(alpha:0.2),
                  child: Icon(approval.status.icon, color: approval.status.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¥${approval.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${approval.requesterName} · ${approval.category}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: approval.status.color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    approval.status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: approval.status.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (approval.note != null && approval.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '备注: ${approval.note}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            if (approval.approverComment != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${approval.approverName}: ${approval.approverComment}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(approval.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const Spacer(),
                if (showActions && approval.isPending) ...[
                  TextButton(
                    onPressed: onReject,
                    child: const Text('拒绝', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onApprove,
                    child: const Text('批准'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}月${date.day}日 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InviteMemberDialog extends ConsumerStatefulWidget {
  final String ledgerId;
  final String ledgerName;

  const _InviteMemberDialog({
    required this.ledgerId,
    required this.ledgerName,
  });

  @override
  ConsumerState<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  final _emailController = TextEditingController();
  MemberRole _selectedRole = MemberRole.editor;
  bool _useInviteCode = true;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('邀请成员'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 邀请方式选择
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('邀请码')),
                ButtonSegment(value: false, label: Text('邮箱')),
              ],
              selected: {_useInviteCode},
              onSelectionChanged: (value) {
                setState(() => _useInviteCode = value.first);
              },
            ),
            const SizedBox(height: 16),
            if (!_useInviteCode) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '邮箱地址',
                  hintText: '输入被邀请人的邮箱',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
            ],
            // 角色选择
            const Text('选择角色', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...MemberRole.values.where((r) => r != MemberRole.owner).map((role) =>
              RadioListTile<MemberRole>(
                title: Row(
                  children: [
                    Icon(role.icon, size: 20, color: role.color),
                    const SizedBox(width: 8),
                    Text(role.displayName),
                  ],
                ),
                subtitle: Text(role.description, style: const TextStyle(fontSize: 12)),
                value: role,
                groupValue: _selectedRole,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _createInvite,
          child: const Text('创建邀请'),
        ),
      ],
    );
  }

  Future<void> _createInvite() async {
    final invite = await ref.read(memberProvider.notifier).createInvite(
      ledgerId: widget.ledgerId,
      ledgerName: widget.ledgerName,
      inviterId: 'current_user_id', // TODO: 替换为实际用户ID
      inviterName: '我', // TODO: 替换为实际用户名
      inviteeEmail: _useInviteCode ? null : _emailController.text.trim(),
      role: _selectedRole,
    );

    if (mounted) {
      Navigator.pop(context);

      if (_useInviteCode && invite.inviteCode != null) {
        // 显示邀请码
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('邀请创建成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('请将以下邀请码发送给被邀请人：'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        invite.inviteCode!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: invite.inviteCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('邀请码已复制')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '有效期至 ${_formatDate(invite.expiresAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('邀请已发送')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

class _EditMemberDialog extends ConsumerStatefulWidget {
  final LedgerMember member;

  const _EditMemberDialog({required this.member});

  @override
  ConsumerState<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<_EditMemberDialog> {
  late MemberRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('编辑 ${widget.member.userName} 的权限'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...MemberRole.values.where((r) => r != MemberRole.owner).map((role) =>
            RadioListTile<MemberRole>(
              title: Row(
                children: [
                  Icon(role.icon, size: 20, color: role.color),
                  const SizedBox(width: 8),
                  Text(role.displayName),
                ],
              ),
              subtitle: Text(role.description, style: const TextStyle(fontSize: 12)),
              value: role,
              groupValue: _selectedRole,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(memberProvider.notifier).updateMemberRole(
              widget.member.id,
              _selectedRole,
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('权限已更新')),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _ApprovalActionDialog extends ConsumerStatefulWidget {
  final ExpenseApproval approval;
  final bool isApprove;

  const _ApprovalActionDialog({
    required this.approval,
    required this.isApprove,
  });

  @override
  ConsumerState<_ApprovalActionDialog> createState() => _ApprovalActionDialogState();
}

class _ApprovalActionDialogState extends ConsumerState<_ApprovalActionDialog> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isApprove ? '批准请求' : '拒绝请求'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '金额: ¥${widget.approval.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text('申请人: ${widget.approval.requesterName}'),
          Text('分类: ${widget.approval.category}'),
          if (widget.approval.note != null)
            Text('备注: ${widget.approval.note}'),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              labelText: '审批意见（可选）',
              hintText: widget.isApprove ? '添加批准说明...' : '添加拒绝原因...',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: widget.isApprove ? Colors.green : Colors.red,
          ),
          child: Text(widget.isApprove ? '批准' : '拒绝'),
        ),
      ],
    );
  }

  void _submit() {
    final comment = _commentController.text.trim();

    if (widget.isApprove) {
      ref.read(memberProvider.notifier).approveRequest(
        widget.approval.id,
        'current_user_id', // TODO: 替换为实际用户ID
        '我', // TODO: 替换为实际用户名
        comment: comment.isEmpty ? null : comment,
      );
    } else {
      ref.read(memberProvider.notifier).rejectRequest(
        widget.approval.id,
        'current_user_id', // TODO: 替换为实际用户ID
        '我', // TODO: 替换为实际用户名
        comment: comment.isEmpty ? null : comment,
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isApprove ? '已批准' : '已拒绝'),
      ),
    );
  }
}
