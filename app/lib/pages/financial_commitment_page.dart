import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 财务承诺页面
///
/// 对应原型设计 10.13 财务承诺
/// 帮助用户设定并追踪财务承诺
class FinancialCommitmentPage extends ConsumerStatefulWidget {
  const FinancialCommitmentPage({super.key});

  @override
  ConsumerState<FinancialCommitmentPage> createState() =>
      _FinancialCommitmentPageState();
}

class _FinancialCommitmentPageState
    extends ConsumerState<FinancialCommitmentPage> {
  final List<Commitment> _commitments = [];

  @override
  void initState() {
    super.initState();
    // 不再加载mock数据，显示空状态让用户自己添加承诺
  }

  void _addCommitment(Commitment commitment) {
    setState(() {
      _commitments.add(commitment);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的承诺'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCommitmentDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 承诺说明
          _IntroCard(),

          // 活跃承诺
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '进行中的承诺',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          ..._commitments
              .where((c) => c.isActive)
              .map((c) => _CommitmentCard(
                    commitment: c,
                    onComplete: () => _completeCommitment(c),
                  )),

          // 承诺宣言
          _PledgeCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showAddCommitmentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddCommitmentSheet(
          onAdd: (commitment) {
            setState(() => _commitments.add(commitment));
          },
        ),
      ),
    );
  }

  void _completeCommitment(Commitment commitment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完成承诺'),
        content: Text('恭喜完成「${commitment.title}」！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续坚持'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎉 太棒了！承诺已完成')),
              );
            },
            child: const Text('结束承诺'),
          ),
        ],
      ),
    );
  }
}

/// 介绍卡片
class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[400]!, Colors.purple[400]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '🎯',
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            '财务承诺',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '给自己一个承诺，坚持下去\n小目标累积成大改变',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 承诺卡片
class _CommitmentCard extends StatelessWidget {
  final Commitment commitment;
  final VoidCallback onComplete;

  const _CommitmentCard({
    required this.commitment,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final daysActive =
        DateTime.now().difference(commitment.startDate).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    commitment.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commitment.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      commitment.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '第$daysActive天',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 进度条
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: commitment.progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      commitment.progress >= 1.0
                          ? Colors.green
                          : Colors.indigo,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(commitment.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (commitment.progress >= 1.0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onComplete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
                child: const Text('🎉 完成承诺'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 承诺宣言卡片
class _PledgeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        children: [
          const Text(
            '📜',
            style: TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 12),
          const Text(
            '我的承诺宣言',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '「我承诺认真对待每一分钱，\n理性消费，积极储蓄，\n为更好的未来努力。」',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '点击编辑你的宣言',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 添加承诺底部弹窗
class _AddCommitmentSheet extends StatelessWidget {
  final Function(Commitment) onAdd;

  const _AddCommitmentSheet({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '添加新承诺',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '选择承诺类型',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CommitmentTypeChip(
                icon: '💰',
                label: '定期存款',
                onTap: () => _addAndClose(context, '定期存款', '💰'),
              ),
              _CommitmentTypeChip(
                icon: '🍽️',
                label: '控制外卖',
                onTap: () => _addAndClose(context, '控制外卖', '🍽️'),
              ),
              _CommitmentTypeChip(
                icon: '☕',
                label: '减少咖啡',
                onTap: () => _addAndClose(context, '减少咖啡', '☕'),
              ),
              _CommitmentTypeChip(
                icon: '📝',
                label: '每日记账',
                onTap: () => _addAndClose(context, '每日记账', '📝'),
              ),
              _CommitmentTypeChip(
                icon: '🛍️',
                label: '控制购物',
                onTap: () => _addAndClose(context, '控制购物', '🛍️'),
              ),
              _CommitmentTypeChip(
                icon: '✨',
                label: '自定义',
                onTap: () => _showCustomDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _addAndClose(BuildContext context, String title, String icon) {
    final commitment = Commitment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: '开始你的承诺之旅',
      icon: icon,
      startDate: DateTime.now(),
      progress: 0,
      isActive: true,
    );
    onAdd(commitment);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加承诺「$title」')),
    );
  }

  void _showCustomDialog(BuildContext context) {
    Navigator.pop(context);
    // 可以在这里添加自定义承诺的对话框
  }
}

class _CommitmentTypeChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _CommitmentTypeChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// 承诺数据模型
class Commitment {
  final String id;
  final String title;
  final String description;
  final String icon;
  final DateTime startDate;
  final double progress;
  final bool isActive;

  Commitment({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.startDate,
    required this.progress,
    required this.isActive,
  });
}
