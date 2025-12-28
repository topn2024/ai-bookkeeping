import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../providers/member_provider.dart';

class MemberBudgetPage extends ConsumerStatefulWidget {
  final String ledgerId;
  final String ledgerName;

  const MemberBudgetPage({
    super.key,
    required this.ledgerId,
    required this.ledgerName,
  });

  @override
  ConsumerState<MemberBudgetPage> createState() => _MemberBudgetPageState();
}

class _MemberBudgetPageState extends ConsumerState<MemberBudgetPage> {
  @override
  Widget build(BuildContext context) {
    final memberState = ref.watch(memberProvider);
    final members = memberState.members.where((m) =>
      m.ledgerId == widget.ledgerId && m.isActive
    ).toList();
    final budgets = memberState.budgets.where((b) =>
      b.ledgerId == widget.ledgerId
    ).toList();
    final summary = ref.watch(memberBudgetSummaryProvider(widget.ledgerId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ledgerName} - 成员预算'),
        actions: [
          IconButton(
            onPressed: _showHelpDialog,
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          // 汇总卡片
          _buildSummaryCard(summary),
          // 成员预算列表
          Expanded(
            child: members.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final budget = budgets.where((b) =>
                        b.memberId == member.id
                      ).firstOrNull;
                      return _MemberBudgetCard(
                        member: member,
                        budget: budget,
                        onEdit: () => _showEditBudgetDialog(member, budget),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(MemberBudgetSummary summary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('成员数', '${summary.totalMembers}'),
              _buildSummaryItem('已设预算', '${summary.membersWithBudget}'),
              _buildSummaryItem('超额人数', '${summary.overBudgetCount}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '总预算使用',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${summary.totalSpent.toStringAsFixed(0)} / ¥${summary.totalBudget.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: summary.overallUsagePercent.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation(
                        summary.overallUsagePercent > 0.8 ? Colors.red : Colors.white,
                      ),
                      strokeWidth: 6,
                    ),
                    Text(
                      '${(summary.overallUsagePercent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
            '请先邀请成员加入账本',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showEditBudgetDialog(LedgerMember member, MemberBudget? budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditBudgetSheet(
        ledgerId: widget.ledgerId,
        member: member,
        existingBudget: budget,
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成员预算说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• 为每个成员设置月度预算上限'),
            SizedBox(height: 8),
            Text('• 可设置单笔消费审批阈值'),
            SizedBox(height: 8),
            Text('• 开启超额审批后，超出预算需要管理员批准'),
            SizedBox(height: 8),
            Text('• 每月初预算自动重置'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解了'),
          ),
        ],
      ),
    );
  }
}

class _MemberBudgetCard extends StatelessWidget {
  final LedgerMember member;
  final MemberBudget? budget;
  final VoidCallback onEdit;

  const _MemberBudgetCard({
    required this.member,
    required this.budget,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = budget != null;
    final progress = hasBudget ? budget!.usagePercent : 0.0;
    final isOverBudget = hasBudget && budget!.isOverBudget;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: member.role.color.withOpacity(0.2),
                    child: Text(
                      member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                      style: TextStyle(color: member.role.color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          member.role.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: member.role.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasBudget) ...[
                    if (budget!.requireApproval)
                      Tooltip(
                        message: '需要审批',
                        child: Icon(
                          Icons.approval,
                          size: 20,
                          color: Colors.orange[400],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ] else
                    TextButton(
                      onPressed: onEdit,
                      child: const Text('设置预算'),
                    ),
                ],
              ),
              if (hasBudget) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '¥${budget!.currentSpent.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget ? Colors.red : null,
                                ),
                              ),
                              Text(
                                ' / ¥${budget!.monthlyLimit.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOverBudget
                                ? '超出 ¥${(budget!.currentSpent - budget!.monthlyLimit).toStringAsFixed(0)}'
                                : '剩余 ¥${budget!.remaining.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOverBudget ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation(
                              isOverBudget
                                  ? Colors.red
                                  : progress > 0.8
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                            strokeWidth: 4,
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOverBudget ? Colors.red : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(
                      isOverBudget
                          ? Colors.red
                          : progress > 0.8
                              ? Colors.orange
                              : Colors.green,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditBudgetSheet extends ConsumerStatefulWidget {
  final String ledgerId;
  final LedgerMember member;
  final MemberBudget? existingBudget;

  const _EditBudgetSheet({
    required this.ledgerId,
    required this.member,
    this.existingBudget,
  });

  @override
  ConsumerState<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends ConsumerState<_EditBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _limitController;
  late TextEditingController _thresholdController;
  late bool _requireApproval;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
      text: widget.existingBudget?.monthlyLimit.toStringAsFixed(0) ?? '',
    );
    _thresholdController = TextEditingController(
      text: widget.existingBudget?.approvalThreshold.toStringAsFixed(0) ?? '',
    );
    _requireApproval = widget.existingBudget?.requireApproval ?? false;
  }

  @override
  void dispose() {
    _limitController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.member.role.color.withOpacity(0.2),
                    child: Text(
                      widget.member.userName.isNotEmpty
                          ? widget.member.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: widget.member.role.color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.member.userName} 的预算设置',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.existingBudget != null)
                    IconButton(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _limitController,
                decoration: const InputDecoration(
                  labelText: '月度预算上限',
                  prefixText: '¥ ',
                  helperText: '设置该成员每月可支出的最大金额',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入预算金额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return '请输入有效金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('超额需要审批'),
                subtitle: const Text('开启后，超出预算的消费需要管理员批准'),
                value: _requireApproval,
                onChanged: (value) {
                  setState(() => _requireApproval = value);
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _thresholdController,
                decoration: const InputDecoration(
                  labelText: '单笔审批阈值（可选）',
                  prefixText: '¥ ',
                  helperText: '超过此金额的单笔消费需要审批，0表示不限制',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.parse(_limitController.text);
    final threshold = double.tryParse(_thresholdController.text) ?? 0;
    final now = DateTime.now();

    final budget = MemberBudget(
      id: widget.existingBudget?.id ?? now.millisecondsSinceEpoch.toString(),
      ledgerId: widget.ledgerId,
      memberId: widget.member.id,
      memberName: widget.member.userName,
      monthlyLimit: limit,
      currentSpent: widget.existingBudget?.currentSpent ?? 0,
      requireApproval: _requireApproval,
      approvalThreshold: threshold,
      createdAt: widget.existingBudget?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.read(memberProvider.notifier).setMemberBudget(budget);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预算设置已保存')),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预算'),
        content: Text('确定要删除 ${widget.member.userName} 的预算设置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (widget.existingBudget != null) {
                await ref.read(memberProvider.notifier).deleteMemberBudget(
                  widget.existingBudget!.id,
                );
              }
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('预算已删除')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
