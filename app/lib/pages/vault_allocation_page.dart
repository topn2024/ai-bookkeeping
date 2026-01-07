import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// 资金分配页面
/// 原型设计 3.03：资金分配
/// - 待分配金额展示
/// - 分配方案列表
/// - 已分配/剩余金额汇总
/// - 确认分配按钮
class VaultAllocationPage extends ConsumerStatefulWidget {
  final double amountToAllocate;
  final String source;

  const VaultAllocationPage({
    super.key,
    this.amountToAllocate = 3500,
    this.source = '本月工资收入',
  });

  @override
  ConsumerState<VaultAllocationPage> createState() =>
      _VaultAllocationPageState();
}

class _VaultAllocationPageState extends ConsumerState<VaultAllocationPage> {
  final List<_AllocationItem> _allocations = [];

  @override
  void initState() {
    super.initState();
    _loadMockAllocations();
  }

  void _loadMockAllocations() {
    _allocations.addAll([
      _AllocationItem(
        name: '应急金储备',
        icon: Icons.savings,
        gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)],
        strategy: '固定 ¥1,000/月',
        amount: 1000,
        percent: 28.6,
      ),
      _AllocationItem(
        name: '旅行基金',
        icon: Icons.flight,
        gradientColors: [const Color(0xFF4CAF50), const Color(0xFF81C784)],
        strategy: '补足到 ¥10,000',
        amount: 1500,
        percent: 42.9,
      ),
      _AllocationItem(
        name: '数码基金',
        icon: Icons.computer,
        gradientColors: [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
        strategy: '剩余金额',
        amount: 1000,
        percent: 28.5,
      ),
    ]);
  }

  double get _totalAllocated =>
      _allocations.fold(0.0, (sum, a) => sum + a.amount);
  double get _remaining => widget.amountToAllocate - _totalAllocated;

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
                  children: [
                    _buildAmountCard(context, theme),
                    _buildAllocationList(context, theme),
                    _buildSummaryCard(context, theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildConfirmButton(context, theme),
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
              child: const Icon(Icons.close),
            ),
          ),
          const Expanded(
            child: Text(
              '分配收入',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _saveAllocation,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                '保存',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 待分配金额卡片
  Widget _buildAmountCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '待分配金额',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${widget.amountToAllocate.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '来自${widget.source}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  /// 分配方案列表
  Widget _buildAllocationList(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '分配方案',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                '智能推荐',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._allocations.map((allocation) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAllocationItemCard(context, theme, allocation),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllocationItemCard(
    BuildContext context,
    ThemeData theme,
    _AllocationItem allocation,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: allocation.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(allocation.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allocation.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  allocation.strategy,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${allocation.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${allocation.percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 汇总卡片
  Widget _buildSummaryCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('已分配'),
              Text(
                '¥${_totalAllocated.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('剩余'),
              Text(
                '¥${_remaining.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _remaining == 0
                      ? AppColors.success
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 确认按钮
  Widget _buildConfirmButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _confirmAllocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '确认分配',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  void _saveAllocation() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分配方案已保存')),
    );
  }

  void _confirmAllocation() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已分配 ¥${_totalAllocated.toStringAsFixed(0)}')),
    );
  }
}

class _AllocationItem {
  final String name;
  final IconData icon;
  final List<Color> gradientColors;
  final String strategy;
  final double amount;
  final double percent;

  _AllocationItem({
    required this.name,
    required this.icon,
    required this.gradientColors,
    required this.strategy,
    required this.amount,
    required this.percent,
  });
}
