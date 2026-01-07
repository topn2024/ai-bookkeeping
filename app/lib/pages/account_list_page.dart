import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

/// 账户列表页面
/// 原型设计 4.01：账户列表
/// - 渐变总资产卡片（总资产、净资产、负债）
/// - 账户分组显示（储蓄账户、信用卡）
/// - 账户详情项（图标、名称、余额、卡号后四位）
class AccountListPage extends ConsumerWidget {
  const AccountListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountProvider);

    // 按类型分组
    final savingsAccounts = accounts
        .where((a) =>
            a.type == AccountType.cash ||
            a.type == AccountType.bankCard ||
            a.type == AccountType.eWallet ||
            a.type == AccountType.investment)
        .toList();
    final creditCards =
        accounts.where((a) => a.type == AccountType.creditCard).toList();

    // 计算总资产、净资产、负债
    final savingsTotal =
        savingsAccounts.fold(0.0, (sum, a) => sum + a.balance);
    final creditTotal = creditCards.fold(
        0.0, (sum, a) => sum + (a.balance < 0 ? a.balance.abs() : 0));
    final totalAssets = savingsTotal;
    final netAssets = savingsTotal - creditTotal;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme, ref),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // 刷新账户数据
                  ref.invalidate(accountProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildTotalAssetsCard(
                          context, theme, totalAssets, netAssets, creditTotal),
                      if (savingsAccounts.isNotEmpty)
                        _buildAccountGroup(
                          context,
                          theme,
                          title: context.l10n.savingsAccount,
                          accounts: savingsAccounts,
                          totalBalance: savingsTotal,
                          isCredit: false,
                          ref: ref,
                        ),
                      if (creditCards.isNotEmpty)
                        _buildAccountGroup(
                          context,
                          theme,
                          title: context.l10n.creditCard,
                          accounts: creditCards,
                          totalBalance: creditTotal,
                          isCredit: true,
                          ref: ref,
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme, WidgetRef ref) {
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
          Expanded(
            child: const Text(
              '我的账户',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _showAddAccountDialog(context, ref),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(Icons.add, color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// 总资产卡片
  Widget _buildTotalAssetsCard(
    BuildContext context,
    ThemeData theme,
    double totalAssets,
    double netAssets,
    double liabilities,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF5A85DD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.totalAssets,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${totalAssets.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(context.l10n.netAssets, '¥${netAssets.toStringAsFixed(0)}'),
              const SizedBox(width: 24),
              _buildStatItem('负债', '¥${liabilities.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 账户分组
  Widget _buildAccountGroup(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required List<Account> accounts,
    required double totalBalance,
    required bool isCredit,
    required WidgetRef ref,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isCredit
                      ? '-¥${totalBalance.toStringAsFixed(0)}'
                      : '¥${totalBalance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCredit ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          ...accounts.map((account) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAccountCard(context, theme, account, isCredit, ref),
              )),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    ThemeData theme,
    Account account,
    bool isCredit,
    WidgetRef ref,
  ) {
    final displayBalance =
        isCredit && account.balance < 0 ? account.balance : account.balance;
    final cardNumber = account.id.length >= 4
        ? '**** ${account.id.substring(account.id.length - 4)}'
        : null;

    return GestureDetector(
      onTap: () => _showAccountOptions(context, ref, account),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
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
            // 图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: account.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(account.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        account.localizedName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (account.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.l10n.defaultAccount,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (cardNumber != null || isCredit) ...[
                    const SizedBox(height: 2),
                    Text(
                      isCredit
                          ? '额度 ¥50,000 · 还款日 25号'
                          : (cardNumber ?? ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 余额
            Text(
              isCredit && displayBalance < 0
                  ? '-¥${displayBalance.abs().toStringAsFixed(0)}'
                  : '¥${displayBalance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isCredit && displayBalance < 0 ? AppColors.error : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountOptions(BuildContext context, WidgetRef ref, Account account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _showEditAccountDialog(context, ref, account);
              },
            ),
            if (!account.isDefault)
              ListTile(
                leading: const Icon(Icons.star),
                title: Text(context.l10n.setAsDefault),
                onTap: () {
                  ref.read(accountProvider.notifier).setDefaultAccount(account.id);
                  Navigator.pop(context);
                },
              ),
            if (!account.isDefault)
              ListTile(
                leading: Icon(Icons.delete, color: AppColors.error),
                title: Text(context.l10n.delete, style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(context, ref, account);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
              title: Text(isEdit ? context.l10n.editAccount : context.l10n.addAccount),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.accountName,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.l10n.initialBalance,
                        prefixText: '¥ ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.accountType,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AccountType.values.map((type) {
                        final isSelected = type == selectedType;
                        return ChoiceChip(
                          label: Text(_getAccountTypeName(context, type)),
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
                    Text(context.l10n.iconColor,
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
                    Text(context.l10n.iconText,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
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
                              color: isSelected
                                  ? selectedColor.withValues(alpha: 0.2)
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
                  child: Text(context.l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.pleaseEnter)),
                      );
                      return;
                    }

                    final balance =
                        double.tryParse(balanceController.text) ?? 0;
                    final newAccount = Account(
                      id: account?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
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
                  child: Text(isEdit ? context.l10n.save : context.l10n.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.deleteAccount),
          content: Text(context.l10n.confirmDeleteAccount(account.localizedName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () {
                ref.read(accountProvider.notifier).deleteAccount(account.id);
                Navigator.pop(context);
              },
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
  }

  String _getAccountTypeName(BuildContext context, AccountType type) {
    switch (type) {
      case AccountType.cash:
        return context.l10n.cash;
      case AccountType.bankCard:
        return context.l10n.bankCard;
      case AccountType.creditCard:
        return context.l10n.creditCard;
      case AccountType.eWallet:
        return context.l10n.eWallet;
      case AccountType.investment:
        return context.l10n.investmentAccount;
    }
  }
}
