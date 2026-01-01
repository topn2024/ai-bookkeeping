import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../providers/member_provider.dart';
import '../providers/auth_provider.dart';

class JoinInvitePage extends ConsumerStatefulWidget {
  const JoinInvitePage({super.key});

  @override
  ConsumerState<JoinInvitePage> createState() => _JoinInvitePageState();
}

class _JoinInvitePageState extends ConsumerState<JoinInvitePage> {
  final _codeController = TextEditingController();
  MemberInvite? _foundInvite;
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('加入账本'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题和说明
            Icon(
              Icons.group_add,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '输入邀请码',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '请输入他人分享给你的8位邀请码',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 邀请码输入
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: '邀请码',
                hintText: '请输入8位邀请码',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: _codeController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _codeController.clear();
                          setState(() {
                            _foundInvite = null;
                            _errorMessage = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              onChanged: (value) {
                setState(() {
                  _errorMessage = null;
                  _foundInvite = null;
                });
                if (value.length == 8) {
                  _searchInvite(value);
                }
              },
            ),
            const SizedBox(height: 16),

            // 搜索按钮
            if (_foundInvite == null && !_isSearching)
              FilledButton.icon(
                onPressed: _codeController.text.length == 8
                    ? () => _searchInvite(_codeController.text)
                    : null,
                icon: const Icon(Icons.search),
                label: const Text('查找邀请'),
              ),

            // 加载中
            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),

            // 找到的邀请
            if (_foundInvite != null) ...[
              const SizedBox(height: 24),
              _InvitePreviewCard(
                invite: _foundInvite!,
                onAccept: _acceptInvite,
                onDecline: () {
                  setState(() {
                    _foundInvite = null;
                    _codeController.clear();
                  });
                },
              ),
            ],

            const SizedBox(height: 32),

            // 帮助信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '如何获取邀请码？',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 请联系账本管理员获取邀请码\n'
                    '• 邀请码由8位字母和数字组成\n'
                    '• 每个邀请码有有效期限制',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.5,
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

  Future<void> _searchInvite(String code) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    // 模拟搜索延迟
    await Future.delayed(const Duration(milliseconds: 500));

    final invite = ref.read(memberProvider.notifier).findInviteByCode(code.toUpperCase());

    setState(() {
      _isSearching = false;
      if (invite != null) {
        _foundInvite = invite;
      } else {
        _errorMessage = '未找到该邀请码，请检查后重试';
      }
    });
  }

  Future<void> _acceptInvite() async {
    if (_foundInvite == null) return;

    final currentUser = ref.read(authProvider).user;
    try {
      await ref.read(memberProvider.notifier).acceptInvite(
        _foundInvite!.id,
        currentUser?.id ?? '',
        currentUser?.displayName ?? '我',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功加入 ${_foundInvite!.ledgerName}'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _InvitePreviewCard extends StatelessWidget {
  final MemberInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitePreviewCard({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 账本图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.book,
                size: 32,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),

            // 账本名称
            Text(
              invite.ledgerName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 邀请人
            Text(
              '${invite.inviterName} 邀请你加入',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // 角色信息
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: invite.role.color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(invite.role.icon, size: 18, color: invite.role.color),
                  const SizedBox(width: 8),
                  Text(
                    '你将成为: ${invite.role.displayName}',
                    style: TextStyle(
                      color: invite.role.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 角色权限说明
            Text(
              invite.role.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 过期时间
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '有效期至 ${_formatDate(invite.expiresAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('加入'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}
