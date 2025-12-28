import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

class AccountManagementPage extends ConsumerWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountProvider);
    final totalBalance = ref.watch(totalBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTotalBalanceCard(totalBalance),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _buildAccountCard(context, ref, account);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard(double totalBalance) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '总资产',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, WidgetRef ref, Account account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: account.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(account.icon, color: account.color),
        ),
        title: Row(
          children: [
            Text(
              account.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (account.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
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
          ],
        ),
        subtitle: Text(
          _getAccountTypeName(account.type),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${account.balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: account.balance >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditAccountDialog(context, ref, account);
                    break;
                  case 'default':
                    ref.read(accountProvider.notifier).setDefaultAccount(account.id);
                    break;
                  case 'delete':
                    _showDeleteConfirmDialog(context, ref, account);
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
                if (!account.isDefault)
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
                if (!account.isDefault)
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
    );
  }

  String _getAccountTypeName(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return '现金';
      case AccountType.bankCard:
        return '银行卡';
      case AccountType.creditCard:
        return '信用卡';
      case AccountType.eWallet:
        return '电子钱包';
      case AccountType.investment:
        return '投资账户';
    }
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    _showAccountDialog(context, ref, null);
  }

  void _showEditAccountDialog(BuildContext context, WidgetRef ref, Account account) {
    _showAccountDialog(context, ref, account);
  }

  void _showAccountDialog(BuildContext context, WidgetRef ref, Account? account) {
    final isEdit = account != null;
    final nameController = TextEditingController(text: account?.name ?? '');
    final balanceController = TextEditingController(
      text: account?.balance.toStringAsFixed(2) ?? '0.00',
    );
    AccountType selectedType = account?.type ?? AccountType.cash;
    Color selectedColor = account?.color ?? const Color(0xFF4CAF50);
    IconData selectedIcon = account?.icon ?? Icons.account_balance_wallet;

    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
    ];

    final icons = [
      Icons.account_balance_wallet,
      Icons.credit_card,
      Icons.savings,
      Icons.account_balance,
      Icons.chat,
      Icons.payment,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑账户' : '添加账户'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '账户名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '初始余额',
                        prefixText: '¥ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('账户类型', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AccountType.values.map((type) {
                        final isSelected = type == selectedType;
                        return ChoiceChip(
                          label: Text(_getAccountTypeName(type)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => selectedType = type);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('图标颜色', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('图标', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: icons.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = icon),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? selectedColor.withOpacity(0.2) : AppColors.background,
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
                        const SnackBar(content: Text('请输入账户名称')),
                      );
                      return;
                    }

                    final balance = double.tryParse(balanceController.text) ?? 0;
                    final newAccount = Account(
                      id: account?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      type: selectedType,
                      balance: balance,
                      icon: selectedIcon,
                      color: selectedColor,
                      isDefault: account?.isDefault ?? false,
                      createdAt: account?.createdAt ?? DateTime.now(),
                    );

                    if (isEdit) {
                      ref.read(accountProvider.notifier).updateAccount(newAccount);
                    } else {
                      ref.read(accountProvider.notifier).addAccount(newAccount);
                    }

                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? '保存' : '添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除账户'),
          content: Text('确定要删除"${account.name}"吗？此操作不可恢复。'),
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
                ref.read(accountProvider.notifier).deleteAccount(account.id);
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
