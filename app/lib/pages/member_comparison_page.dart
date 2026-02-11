import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../providers/member_statistics_provider.dart';
import '../providers/member_provider.dart';
import '../services/category_localization_service.dart';

class MemberComparisonPage extends ConsumerStatefulWidget {
  final String ledgerId;
  final String ledgerName;

  const MemberComparisonPage({
    super.key,
    required this.ledgerId,
    required this.ledgerName,
  });

  @override
  ConsumerState<MemberComparisonPage> createState() => _MemberComparisonPageState();
}

class _MemberComparisonPageState extends ConsumerState<MemberComparisonPage> {
  @override
  void initState() {
    super.initState();
    // 初始化统计数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memberStatisticsProvider.notifier).setLedger(widget.ledgerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberStatisticsProvider);
    final memberState = ref.watch(memberProvider);
    final members = memberState.members
        .where((m) => m.ledgerId == widget.ledgerId && m.isActive)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ledgerName} - 成员对比'),
        actions: [
          IconButton(
            onPressed: () => ref.read(memberStatisticsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: members.isEmpty
          ? _buildEmptyState()
          : state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(state),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无成员数据',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '请先邀请成员加入账本',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MemberStatisticsState state) {
    final data = state.comparisonData;
    if (data == null) {
      return const Center(child: Text('无数据'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间范围选择
          _buildPeriodSelector(state),
          const SizedBox(height: 16),

          // 总览卡片
          _buildOverviewCard(data),
          const SizedBox(height: 16),

          // 成员消费对比图表
          _buildExpenseComparisonChart(data),
          const SizedBox(height: 16),

          // 成员排名
          _buildMemberRanking(data),
          const SizedBox(height: 16),

          // 分类消费对比
          _buildCategoryComparison(data),
          const SizedBox(height: 16),

          // 预算执行对比
          _buildBudgetComparison(data),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(MemberStatisticsState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '统计周期',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ComparisonPeriod.values
                    .where((p) => p != ComparisonPeriod.custom)
                    .map((period) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(period.displayName),
                            selected: state.period == period,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(memberStatisticsProvider.notifier)
                                    .setPeriod(period);
                              }
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(MemberComparisonData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '整体概览',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_formatDate(data.startDate)} - ${_formatDate(data.endDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '成员数',
                    '${data.memberStats.length}',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总支出',
                    '¥${_formatAmount(data.totalGroupExpense)}',
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '人均支出',
                    '¥${_formatAmount(data.averageExpensePerMember)}',
                    Icons.person,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_upward,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          const Text('最高消费'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.topSpender,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_downward,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          const Text('最节省'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.topSaver,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildExpenseComparisonChart(MemberComparisonData data) {
    final maxExpense = data.memberStats.isEmpty
        ? 1.0
        : data.memberStats
            .map((s) => s.totalExpense)
            .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  '消费对比',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.memberStats.map((stats) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: stats.role.color.withValues(alpha:0.2),
                            child: Text(
                              stats.memberName.isNotEmpty
                                  ? stats.memberName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 12,
                                color: stats.role.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stats.memberName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '¥${_formatAmount(stats.totalExpense)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stats.totalExpense / maxExpense,
                          backgroundColor: Colors.grey.withValues(alpha:0.2),
                          valueColor: AlwaysStoppedAnimation(stats.role.color),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRanking(MemberComparisonData data) {
    final sortedStats = List<MemberSpendingStats>.from(data.memberStats)
      ..sort((a, b) => b.totalExpense.compareTo(a.totalExpense));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  '消费排名',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedStats.asMap().entries.map((entry) {
              final index = entry.key;
              final stats = entry.value;
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? Colors.amber
                        : index == 1
                            ? Colors.grey[400]
                            : index == 2
                                ? Colors.brown[300]
                                : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index < 3 ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text(stats.memberName),
                subtitle: Text(
                  '${stats.transactionCount}笔交易 · 日均¥${_formatAmount(stats.averageExpense)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${_formatAmount(stats.totalExpense)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '占比 ${(stats.totalExpense / data.totalGroupExpense * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryComparison(MemberComparisonData data) {
    final sortedCategories = data.groupCategoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  '分类消费统计',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final percent = category.value / data.totalGroupExpense * 100;
              final color = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(category.key.localizedCategoryName)),
                    Text(
                      '¥${_formatAmount(category.value)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${percent.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetComparison(MemberComparisonData data) {
    final membersWithBudget =
        data.memberStats.where((s) => s.budgetLimit > 0).toList();

    if (membersWithBudget.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    '预算执行对比',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                '暂无成员设置预算',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  '预算执行对比',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...membersWithBudget.map((stats) {
              final isOver = stats.isOverBudget;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stats.memberName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOver
                                ? Colors.red.withValues(alpha:0.1)
                                : Colors.green.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOver ? '超支' : '正常',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOver ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (stats.budgetPercent / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.withValues(alpha:0.2),
                              valueColor: AlwaysStoppedAnimation(
                                isOver
                                    ? Colors.red
                                    : stats.budgetPercent > 80
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${stats.budgetPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isOver ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${_formatAmount(stats.totalExpense)} / ¥${_formatAmount(stats.budgetLimit)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }
}
