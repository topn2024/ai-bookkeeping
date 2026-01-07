import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// 家庭成员分配页面
/// 原型设计 5.18：家庭成员分配
/// - 家庭账本模式提示
/// - 分配方式选择（全部分配给我/其他成员/逐条分配）
/// - 家庭成员列表
/// - AI自动识别选项
/// - 继续导入按钮
class FamilyMemberAssignmentPage extends ConsumerStatefulWidget {
  final int transactionCount;
  final String fileName;

  const FamilyMemberAssignmentPage({
    super.key,
    required this.transactionCount,
    required this.fileName,
  });

  @override
  ConsumerState<FamilyMemberAssignmentPage> createState() =>
      _FamilyMemberAssignmentPageState();
}

class _FamilyMemberAssignmentPageState
    extends ConsumerState<FamilyMemberAssignmentPage> {
  String _selectedAssignment = 'me';
  bool _enableAIRecognition = true;

  // 模拟家庭成员数据
  final List<FamilyMember> _members = [
    FamilyMember(
      id: 'me',
      name: '张三',
      avatar: '我',
      isMe: true,
    ),
    FamilyMember(
      id: 'member1',
      name: '小美',
      avatar: '👩',
      isMe: false,
    ),
    FamilyMember(
      id: 'member2',
      name: '小宝',
      avatar: '👶',
      isMe: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFamilyModeHint(theme),
                    _buildAssignmentOptions(theme),
                    _buildMemberList(theme),
                    _buildAIRecognitionOption(theme),
                  ],
                ),
              ),
            ),
            _buildBottomButton(context, theme),
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
              '分配给成员',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _skipAssignment(context),
            child: Text(
              '跳过',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 家庭账本模式提示
  Widget _buildFamilyModeHint(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.family_restroom,
            color: Color(0xFF1976D2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '家庭账本模式',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1976D2),
                  ),
                ),
                Text(
                  '可将导入的账单分配给不同家庭成员',
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
    );
  }

  /// 分配方式选择
  Widget _buildAssignmentOptions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分配方式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // 全部分配给我
          _buildAssignmentOption(
            theme,
            'me',
            '全部分配给我',
            '${widget.transactionCount}条记录都归属我的名下',
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '我',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 分配给其他成员
          _buildAssignmentOption(
            theme,
            'member1',
            '全部分配给小美',
            '这是小美的账单',
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('👩', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 逐条分配
          _buildAssignmentOption(
            theme,
            'manual',
            '逐条分配',
            '在预览页面为每笔交易选择成员',
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: Color(0xFFFF9800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentOption(
    ThemeData theme,
    String value,
    String title,
    String subtitle,
    Widget avatar,
  ) {
    final isSelected = _selectedAssignment == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedAssignment = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedAssignment,
              onChanged: (v) => setState(() => _selectedAssignment = v!),
            ),
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
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
    );
  }

  /// 家庭成员列表
  Widget _buildMemberList(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '家庭成员',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._members.map((member) => _buildMemberChip(theme, member)),
              _buildAddMemberButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberChip(ThemeData theme, FamilyMember member) {
    final isSelected = _selectedAssignment == member.id ||
        (_selectedAssignment == 'me' && member.isMe);

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: member.isMe
                ? null
                : (member.avatar == '👩'
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0)),
            gradient: member.isMe
                ? LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: Center(
            child: member.isMe
                ? const Text(
                    '我',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    member.avatar,
                    style: const TextStyle(fontSize: 20),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          member.name,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAddMemberButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => _addMember(context),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '添加',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// AI自动识别选项
  Widget _buildAIRecognitionOption(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI可根据交易备注自动识别成员归属',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Switch(
              value: _enableAIRecognition,
              onChanged: (v) => setState(() => _enableAIRecognition = v),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部按钮
  Widget _buildBottomButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _continueImport(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '继续导入',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  void _skipAssignment(BuildContext context) {
    Navigator.pop(context, null);
  }

  void _addMember(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('添加家庭成员...')),
    );
  }

  void _continueImport(BuildContext context) {
    final assignedMember = _members.firstWhere(
      (m) => m.id == _selectedAssignment || (m.isMe && _selectedAssignment == 'me'),
      orElse: () => _members.first,
    );

    Navigator.pop(context, AssignmentResult(
      assignmentType: _selectedAssignment,
      assignedMember: _selectedAssignment == 'manual' ? null : assignedMember,
      enableAIRecognition: _enableAIRecognition,
    ));
  }
}

/// 家庭成员
class FamilyMember {
  final String id;
  final String name;
  final String avatar;
  final bool isMe;

  FamilyMember({
    required this.id,
    required this.name,
    required this.avatar,
    required this.isMe,
  });
}

/// 分配结果
class AssignmentResult {
  final String assignmentType;
  final FamilyMember? assignedMember;
  final bool enableAIRecognition;

  AssignmentResult({
    required this.assignmentType,
    this.assignedMember,
    required this.enableAIRecognition,
  });
}
