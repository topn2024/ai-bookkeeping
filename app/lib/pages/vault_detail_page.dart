import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_vault.dart';
import 'vault_create_page.dart';
import 'transaction_list_page.dart';

/// 小金库详情页面
///
/// 对应原型设计 3.02 小金库详情
/// 单屏布局，展示进度环、里程碑、统计数据和最近动态
class VaultDetailPage extends ConsumerStatefulWidget {
  final BudgetVault vault;

  const VaultDetailPage({
    super.key,
    required this.vault,
  });

  @override
  ConsumerState<VaultDetailPage> createState() => _VaultDetailPageState();
}

class _VaultDetailPageState extends ConsumerState<VaultDetailPage> {
  // 模拟动态数据
  final List<VaultTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadMockTransactions();
  }

  void _loadMockTransactions() {
    _transactions.addAll([
      VaultTransaction(
        id: '1',
        type: VaultTransactionType.deposit,
        amount: 500,
        date: DateTime.now(),
        description: '存入',
      ),
      VaultTransaction(
        id: '2',
        type: VaultTransactionType.deposit,
        amount: 1000,
        date: DateTime.now().subtract(const Duration(days: 1)),
        description: '自动存入',
      ),
      VaultTransaction(
        id: '3',
        type: VaultTransactionType.withdraw,
        amount: 200,
        date: DateTime.now().subtract(const Duration(days: 3)),
        description: '紧急支出',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final vault = widget.vault;
    final progress = vault.targetAmount > 0
        ? (vault.allocatedAmount / vault.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining = vault.targetAmount - vault.allocatedAmount;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getVaultEmoji(vault.type)),
            const SizedBox(width: 8),
            Text(vault.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showVaultOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 核心数据区：进度环 + 金额
          _ProgressSection(
            progress: progress,
            currentAmount: vault.allocatedAmount,
            targetAmount: vault.targetAmount,
            remaining: remaining,
            color: vault.color,
          ),

          // 里程碑进度
          _MilestoneSection(progress: progress),

          // 统计数据行
          _StatsSection(vault: vault),

          // 最近动态
          Expanded(
            child: _RecentActivitySection(transactions: _transactions),
          ),

          // 黄金区：操作按钮
          _ActionButtons(
            onDeposit: () => _showDepositDialog(context),
            onWithdraw: () => _showWithdrawDialog(context),
          ),
        ],
      ),
    );
  }

  String _getVaultEmoji(VaultType type) {
    switch (type) {
      case VaultType.fixed:
        return '🏠';
      case VaultType.flexible:
        return '🍽️';
      case VaultType.savings:
        return '✈️';
      case VaultType.debt:
        return '💳';
    }
  }

  void _showVaultOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑小金库'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VaultCreatePage(vault: widget.vault),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('查看全部记录'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionListPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('转入其他小金库'),
              onTap: () {
                Navigator.pop(context);
                _showTransferDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red[400]),
              title: Text('删除小金库', style: TextStyle(color: Colors.red[400])),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${widget.vault.name}"小金库吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('小金库已删除')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final amountController = TextEditingController();
    String? selectedVaultId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('转入其他小金库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '目标小金库',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '1', child: Text('生活开支')),
                DropdownMenuItem(value: '2', child: Text('旅行基金')),
                DropdownMenuItem(value: '3', child: Text('应急储备')),
              ],
              onChanged: (value) {
                selectedVaultId = value;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '转账金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('转账成功')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('存入'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '金额',
            prefixText: '¥ ',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入存入金额')),
                );
                return;
              }

              final amount = double.tryParse(text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的金额')),
                );
                return;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已存入 ¥${amount.toStringAsFixed(2)}')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                border: const OutlineInputBorder(),
                helperText: '可用余额: ¥${widget.vault.available.toStringAsFixed(2)}',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入取出金额')),
                );
                return;
              }

              final amount = double.tryParse(text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的金额')),
                );
                return;
              }

              if (amount > widget.vault.available) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('余额不足，当前可用余额: ¥${widget.vault.available.toStringAsFixed(2)}'),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已取出 ¥${amount.toStringAsFixed(2)}')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 进度环区域
class _ProgressSection extends StatelessWidget {
  final double progress;
  final double currentAmount;
  final double targetAmount;
  final double remaining;
  final Color color;

  const _ProgressSection({
    required this.progress,
    required this.currentAmount,
    required this.targetAmount,
    required this.remaining,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 进度环
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 金额信息
          Text(
            '¥${currentAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '目标 ¥${targetAmount.toStringAsFixed(0)} · 还差 ¥${remaining.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 里程碑区域
class _MilestoneSection extends StatelessWidget {
  final double progress;

  const _MilestoneSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    final milestones = [0.25, 0.50, 0.75, 1.0];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: milestones.map((milestone) {
          final achieved = progress >= milestone;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: achieved
                    ? Colors.green[50]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    achieved
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: achieved ? Colors.green : Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(milestone * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: achieved ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 统计数据区域
class _StatsSection extends StatelessWidget {
  final BudgetVault vault;

  const _StatsSection({required this.vault});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard(
            label: '本月存入',
            value: '+¥1,500',
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: '累计存入',
            value: '¥${vault.allocatedAmount.toStringAsFixed(0)}',
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: '预计达成',
            value: '2月',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 最近动态区域
class _RecentActivitySection extends StatelessWidget {
  final List<VaultTransaction> transactions;

  const _RecentActivitySection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最近动态',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('查看全部 →'),
              ),
            ],
          ),
          Expanded(
            child: ListView.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return _TransactionTile(transaction: tx);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final VaultTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.type == VaultTransactionType.deposit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            isDeposit ? Icons.add_circle : Icons.remove_circle,
            color: isDeposit ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  _formatDate(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isDeposit ? '+' : '-'}¥${transaction.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDeposit ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}

/// 操作按钮区域
class _ActionButtons extends StatelessWidget {
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _ActionButtons({
    required this.onDeposit,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onDeposit,
                icon: const Icon(Icons.add),
                label: const Text('存入'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.remove),
                label: const Text('取出'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 小金库交易记录
class VaultTransaction {
  final String id;
  final VaultTransactionType type;
  final double amount;
  final DateTime date;
  final String description;

  VaultTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
  });
}

enum VaultTransactionType {
  deposit,
  withdraw,
}
