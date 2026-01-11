import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/resource_pool.dart';
import '../models/transaction.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../providers/transaction_provider.dart';

/// 资源池Provider - 从数据库获取真实数据
final resourcePoolsProvider = FutureProvider<List<ResourcePool>>((ref) async {
  final db = sl<IDatabaseService>();
  return await db.getAllResourcePools();
});

/// FIFO资源池页面
/// 原型设计 2.07：FIFO资源池
/// - 说明卡片：FIFO原则解释
/// - 资源池列表：已消耗完、部分消耗、当前消费中、待使用
/// - 总结卡片：可用资金、平均钱龄、活跃资源池数
/// 数据来源：resource_pools表 + transactions表
class MoneyAgeResourcePoolPage extends ConsumerWidget {
  const MoneyAgeResourcePoolPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resourcePoolsAsync = ref.watch(resourcePoolsProvider);
    final transactions = ref.watch(transactionProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: resourcePoolsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('加载失败: $error'),
                ),
                data: (pools) {
                  if (pools.isEmpty) {
                    return _buildEmptyState(context, theme);
                  }
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildInfoCard(context, theme),
                        _buildResourcePoolList(context, theme, pools, transactions),
                        _buildSummaryCard(context, theme, pools),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无资金池数据',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加收入后将自动创建资金池',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
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
            child: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              '资金池状态',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _showHelpDialog(context),
            child: Icon(
              Icons.help_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('什么是FIFO资金池？'),
        content: const Text(
          'FIFO（先进先出）是一种资金追踪原则：\n\n'
          '• 每笔收入创建一个资金池\n'
          '• 支出时优先消耗最早的资金池\n'
          '• 这样可以准确追踪每笔支出的资金来源\n\n'
          '通过FIFO原则，您可以了解：\n'
          '1. 当前花的钱是什么时候赚的\n'
          '2. 哪些收入已经被花完\n'
          '3. 还有多少储备资金',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEBF3FF), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '资金池按先进先出(FIFO)原则消耗，越早的收入越先被花掉',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcePoolList(
    BuildContext context,
    ThemeData theme,
    List<ResourcePool> pools,
    List<Transaction> transactions,
  ) {
    // 根据状态分组
    final consumedPools = pools.where((p) => p.isFullyConsumed).toList();
    final partialPools = pools.where((p) => !p.isFullyConsumed && p.consumptionRate > 0).toList();
    final pendingPools = pools.where((p) => !p.isFullyConsumed && p.consumptionRate == 0).toList();

    // 按创建时间排序
    consumedPools.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    partialPools.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    pendingPools.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // 查找对应的收入交易获取名称
    String getPoolName(ResourcePool pool) {
      final income = transactions.firstWhere(
        (t) => t.id == pool.incomeTransactionId,
        orElse: () => Transaction(
          id: '',
          amount: pool.originalAmount,
          type: TransactionType.income,
          category: '收入',
          date: pool.createdAt,
          accountId: '',
        ),
      );
      return income.note?.isNotEmpty == true ? income.note! : income.category;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前消费中的资金池
          if (partialPools.isNotEmpty) ...[
            _buildSectionHeader(theme, '消费中', partialPools.length),
            ...partialPools.map((pool) => _buildPoolItem(
              context,
              theme,
              name: getPoolName(pool),
              date: DateFormat('M月d日').format(pool.createdAt),
              amount: pool.originalAmount,
              remaining: pool.remainingAmount,
              status: PoolStatus.current,
              ageInDays: pool.ageInDays,
            )),
            const SizedBox(height: 16),
          ],

          // 待使用的资金池
          if (pendingPools.isNotEmpty) ...[
            _buildSectionHeader(theme, '待使用', pendingPools.length),
            ...pendingPools.map((pool) => _buildPoolItem(
              context,
              theme,
              name: getPoolName(pool),
              date: DateFormat('M月d日').format(pool.createdAt),
              amount: pool.originalAmount,
              remaining: pool.remainingAmount,
              status: PoolStatus.pending,
              ageInDays: pool.ageInDays,
            )),
            const SizedBox(height: 16),
          ],

          // 已消耗完的资金池（最多显示5个）
          if (consumedPools.isNotEmpty) ...[
            _buildSectionHeader(theme, '已消耗', consumedPools.length),
            ...consumedPools.take(5).map((pool) => _buildPoolItem(
              context,
              theme,
              name: getPoolName(pool),
              date: DateFormat('M月d日').format(pool.createdAt),
              amount: pool.originalAmount,
              remaining: 0,
              status: PoolStatus.consumed,
              ageInDays: pool.ageInDays,
            )),
            if (consumedPools.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '还有 ${consumedPools.length - 5} 个已消耗的资金池',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
          ],

          // 空状态
          if (partialPools.isEmpty && pendingPools.isEmpty && consumedPools.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '暂无资金池数据',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolItem(
    BuildContext context,
    ThemeData theme, {
    required String name,
    required String date,
    required double amount,
    required double remaining,
    required PoolStatus status,
    required int ageInDays,
  }) {
    Color borderColor;
    Color bgColor;
    Widget statusIcon;
    String statusText;
    late Color progressColor;

    switch (status) {
      case PoolStatus.consumed:
        borderColor = theme.colorScheme.outline;
        bgColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        );
        statusText = '已消耗';
        progressColor = theme.colorScheme.outline;
        break;
      case PoolStatus.partial:
        borderColor = Colors.orange;
        bgColor = Colors.orange.shade50;
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.trending_down, color: Colors.orange, size: 16),
        );
        statusText = '部分消耗';
        progressColor = Colors.orange;
        break;
      case PoolStatus.current:
        borderColor = theme.colorScheme.primary;
        bgColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow, color: theme.colorScheme.primary, size: 16),
        );
        statusText = '消费中';
        progressColor = theme.colorScheme.primary;
        break;
      case PoolStatus.pending:
        borderColor = Colors.green;
        bgColor = Colors.green.shade50;
        statusIcon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule, color: Colors.green, size: 16),
        );
        statusText = '待使用';
        progressColor = Colors.green;
        break;
    }

    final consumptionRate = amount > 0 ? (amount - remaining) / amount : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              statusIcon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: status == PoolStatus.consumed
                                ? theme.colorScheme.outline
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: progressColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              color: progressColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date · $ageInDays天前',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: consumptionRate,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '剩余 ¥${remaining.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: status == PoolStatus.consumed
                      ? theme.colorScheme.outline
                      : progressColor,
                ),
              ),
              Text(
                '原 ¥${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ThemeData theme, List<ResourcePool> pools) {
    // 计算统计数据
    final activePools = pools.where((p) => !p.isFullyConsumed).toList();
    final totalRemaining = activePools.fold<double>(0, (sum, p) => sum + p.remainingAmount);
    final avgAge = activePools.isEmpty
        ? 0
        : activePools.fold<int>(0, (sum, p) => sum + p.ageInDays) ~/ activePools.length;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '资金池总览',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                theme,
                label: '可用资金',
                value: '¥${totalRemaining.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet,
              ),
              _buildSummaryItem(
                theme,
                label: '平均钱龄',
                value: '$avgAge天',
                icon: Icons.schedule,
              ),
              _buildSummaryItem(
                theme,
                label: '活跃池数',
                value: '${activePools.length}',
                icon: Icons.layers,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

enum PoolStatus {
  consumed,  // 已消耗完
  partial,   // 部分消耗
  current,   // 当前消费中
  pending,   // 待使用
}
