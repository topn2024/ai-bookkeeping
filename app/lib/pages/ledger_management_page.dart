import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/ledger.dart';
import '../providers/ledger_provider.dart';

class LedgerManagementPage extends ConsumerWidget {
  const LedgerManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgerProvider);
    final currentLedgerId = ref.watch(ledgerProvider.notifier).currentLedgerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账本管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddLedgerDialog(context, ref),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ledgers.length,
        itemBuilder: (context, index) {
          final ledger = ledgers[index];
          final isCurrent = ledger.id == currentLedgerId;
          return _buildLedgerCard(context, ref, ledger, isCurrent);
        },
      ),
    );
  }

  Widget _buildLedgerCard(
      BuildContext context, WidgetRef ref, Ledger ledger, bool isCurrent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? BorderSide(color: ledger.color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          ref.read(ledgerProvider.notifier).setCurrentLedger(ledger.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已切换到"${ledger.name}"'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ledger.color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ledger.icon, color: ledger.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ledger.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (ledger.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '默认',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.income,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (ledger.description != null &&
                        ledger.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ledger.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '成员: ${ledger.memberIds.isEmpty ? "仅自己" : "${ledger.memberIds.length + 1}人"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditLedgerDialog(context, ref, ledger);
                      break;
                    case 'default':
                      ref.read(ledgerProvider.notifier).setDefaultLedger(ledger.id);
                      break;
                    case 'share':
                      _showShareDialog(context, ledger);
                      break;
                    case 'delete':
                      _showDeleteConfirmDialog(context, ref, ledger);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  if (!ledger.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 20),
                          SizedBox(width: 8),
                          Text('设为默认'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 8),
                        Text('邀请成员'),
                      ],
                    ),
                  ),
                  if (!ledger.isDefault)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: AppColors.expense),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: AppColors.expense)),
                        ],
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

  void _showAddLedgerDialog(BuildContext context, WidgetRef ref) {
    _showLedgerDialog(context, ref, null);
  }

  void _showEditLedgerDialog(
      BuildContext context, WidgetRef ref, Ledger ledger) {
    _showLedgerDialog(context, ref, ledger);
  }

  void _showLedgerDialog(BuildContext context, WidgetRef ref, Ledger? ledger) {
    final isEdit = ledger != null;
    final nameController = TextEditingController(text: ledger?.name ?? '');
    final descController =
        TextEditingController(text: ledger?.description ?? '');
    Color selectedColor = ledger?.color ?? const Color(0xFF2196F3);
    IconData selectedIcon = ledger?.icon ?? Icons.book;

    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFE91E63),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];

    final icons = [
      Icons.book,
      Icons.home,
      Icons.work,
      Icons.shopping_bag,
      Icons.flight,
      Icons.favorite,
      Icons.sports_esports,
      Icons.school,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑账本' : '新建账本'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '账本名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: '账本描述（可选）',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Text('封面颜色',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colors.map((color) {
                        final isSelected = color == selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('封面图标',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: icons.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = icon),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor.withValues(alpha:0.2)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: selectedColor, width: 2)
                                  : null,
                            ),
                            child: Icon(icon, color: selectedColor),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入账本名称')),
                      );
                      return;
                    }

                    final newLedger = Ledger(
                      id: ledger?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      description: descController.text.trim().isEmpty
                          ? null
                          : descController.text.trim(),
                      icon: selectedIcon,
                      color: selectedColor,
                      isDefault: ledger?.isDefault ?? false,
                      createdAt: ledger?.createdAt ?? DateTime.now(),
                      memberIds: ledger?.memberIds ?? [],
                    );

                    if (isEdit) {
                      ref.read(ledgerProvider.notifier).updateLedger(newLedger);
                    } else {
                      ref.read(ledgerProvider.notifier).addLedger(newLedger);
                    }

                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? '保存' : '创建'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showShareDialog(BuildContext context, Ledger ledger) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('邀请成员'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code, size: 100, color: ledger.color),
                    const SizedBox(height: 16),
                    const Text(
                      '扫描二维码加入账本',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '此功能需要登录后使用',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, WidgetRef ref, Ledger ledger) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除账本'),
          content: Text('确定要删除"${ledger.name}"吗？账本下的所有记录都会被删除，此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
              ),
              onPressed: () {
                ref.read(ledgerProvider.notifier).deleteLedger(ledger.id);
                Navigator.pop(context);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}
