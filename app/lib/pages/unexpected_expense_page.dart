import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 突发支出处理页面
///
/// 对应原型设计 10.10 突发支出处理
/// 帮助用户合理处理突发的大额支出
class UnexpectedExpensePage extends ConsumerStatefulWidget {
  final double amount;
  final String description;

  const UnexpectedExpensePage({
    super.key,
    required this.amount,
    this.description = '突发支出',
  });

  @override
  ConsumerState<UnexpectedExpensePage> createState() =>
      _UnexpectedExpensePageState();
}

class _UnexpectedExpensePageState
    extends ConsumerState<UnexpectedExpensePage> {
  FundingSource? _selectedSource;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('突发支出处理'),
      ),
      body: ListView(
        children: [
          // 支出信息卡片
          _ExpenseInfoCard(
            amount: widget.amount,
            description: widget.description,
          ),

          // 资金来源选择
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '选择资金来源',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          _FundingSourceCard(
            source: FundingSource.emergency,
            title: '应急金',
            subtitle: '可用余额 ¥18,000',
            icon: Icons.shield,
            color: Colors.green,
            isSelected: _selectedSource == FundingSource.emergency,
            onTap: () => setState(() => _selectedSource = FundingSource.emergency),
          ),

          _FundingSourceCard(
            source: FundingSource.flexible,
            title: '弹性预算',
            subtitle: '本月剩余 ¥2,500',
            icon: Icons.account_balance_wallet,
            color: Colors.blue,
            isSelected: _selectedSource == FundingSource.flexible,
            onTap: () => setState(() => _selectedSource = FundingSource.flexible),
          ),

          _FundingSourceCard(
            source: FundingSource.savings,
            title: '储蓄目标',
            subtitle: '旅行基金 ¥12,000',
            icon: Icons.savings,
            color: Colors.orange,
            isSelected: _selectedSource == FundingSource.savings,
            onTap: () => setState(() => _selectedSource = FundingSource.savings),
          ),

          _FundingSourceCard(
            source: FundingSource.installment,
            title: '分期支付',
            subtitle: '分3期，每期 ¥${(widget.amount / 3).toStringAsFixed(0)}',
            icon: Icons.calendar_today,
            color: Colors.purple,
            isSelected: _selectedSource == FundingSource.installment,
            onTap: () => setState(() => _selectedSource = FundingSource.installment),
          ),

          // 影响分析
          if (_selectedSource != null)
            _ImpactAnalysisCard(
              source: _selectedSource!,
              amount: widget.amount,
            ),

          // 建议提示
          _SuggestionCard(),

          const SizedBox(height: 100),
        ],
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _selectedSource != null
                ? () => _confirmFunding(context)
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('确认资金来源'),
          ),
        ),
      ),
    );
  }

  void _confirmFunding(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认处理'),
        content: Text(
          '将从「${_getSourceName(_selectedSource!)}」支出 ¥${widget.amount.toStringAsFixed(0)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, _selectedSource);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('突发支出已处理')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  String _getSourceName(FundingSource source) {
    switch (source) {
      case FundingSource.emergency:
        return '应急金';
      case FundingSource.flexible:
        return '弹性预算';
      case FundingSource.savings:
        return '储蓄目标';
      case FundingSource.installment:
        return '分期支付';
    }
  }
}

/// 支出信息卡片
class _ExpenseInfoCard extends StatelessWidget {
  final double amount;
  final String description;

  const _ExpenseInfoCard({
    required this.amount,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[400]!, Colors.orange[400]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            '突发支出',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 资金来源卡片
class _FundingSourceCard extends StatelessWidget {
  final FundingSource source;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FundingSourceCard({
    required this.source,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

/// 影响分析卡片
class _ImpactAnalysisCard extends StatelessWidget {
  final FundingSource source;
  final double amount;

  const _ImpactAnalysisCard({
    required this.source,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    String impact;
    Color impactColor;

    switch (source) {
      case FundingSource.emergency:
        impact = '应急金覆盖月数将从 3.6 个月降至 2.8 个月';
        impactColor = Colors.orange;
        break;
      case FundingSource.flexible:
        impact = '本月弹性预算将不足，可能影响日常消费';
        impactColor = Colors.red;
        break;
      case FundingSource.savings:
        impact = '旅行计划可能延迟 1-2 个月';
        impactColor = Colors.blue;
        break;
      case FundingSource.installment:
        impact = '未来3个月每月需额外支出 ¥${(amount / 3).toStringAsFixed(0)}';
        impactColor = Colors.purple;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: impactColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: impactColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: impactColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '影响分析',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: impactColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  impact,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 建议卡片
class _SuggestionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                '理财建议',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 优先使用应急金，这正是它存在的意义\n'
            '• 处理完成后，制定计划补充应急金\n'
            '• 考虑是否可以申请保险理赔',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

enum FundingSource {
  emergency,
  flexible,
  savings,
  installment,
}
