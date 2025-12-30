import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/debt.dart';
import '../providers/debt_provider.dart';

class DebtSimulatorPage extends ConsumerStatefulWidget {
  const DebtSimulatorPage({super.key});

  @override
  ConsumerState<DebtSimulatorPage> createState() => _DebtSimulatorPageState();
}

class _DebtSimulatorPageState extends ConsumerState<DebtSimulatorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _extraPaymentController = TextEditingController(text: '0');
  double _extraPayment = 0;
  RepaymentSimulation? _snowballResult;
  RepaymentSimulation? _avalancheResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSimulation());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _extraPaymentController.dispose();
    super.dispose();
  }

  void _runSimulation() {
    final notifier = ref.read(debtProvider.notifier);
    setState(() {
      _snowballResult = notifier.simulateRepayment(
        strategy: RepaymentStrategy.snowball,
        extraPayment: _extraPayment,
      );
      _avalancheResult = notifier.simulateRepayment(
        strategy: RepaymentStrategy.avalanche,
        extraPayment: _extraPayment,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtProvider);
    final activeDebts = debts.where((d) => !d.isCompleted).toList();
    final summary = ref.watch(debtSummaryProvider);
    final theme = Theme.of(context);

    if (activeDebts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('还款模拟器')),
        body: const Center(child: Text('没有进行中的债务')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('还款模拟器'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '策略对比'),
            Tab(text: '还款计划'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildComparisonTab(context, theme, summary),
          _buildPlanTab(context, theme),
        ],
      ),
    );
  }

  Widget _buildComparisonTab(BuildContext context, ThemeData theme, DebtSummary summary) {
    final interestSaved = (_snowballResult?.totalInterest ?? 0) -
        (_avalancheResult?.totalInterest ?? 0);
    final monthsSaved = (_snowballResult?.totalMonths ?? 0) -
        (_avalancheResult?.totalMonths ?? 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 额外还款设置
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每月额外还款',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '除了最低还款外，每月可额外用于还债的金额',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _extraPaymentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: '¥ ',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _extraPayment = double.tryParse(value) ?? 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _runSimulation,
                      child: const Text('模拟'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [100.0, 500.0, 1000.0, 2000.0].map((amount) {
                    return ActionChip(
                      label: Text('+¥${amount.toInt()}'),
                      onPressed: () {
                        _extraPaymentController.text = amount.toString();
                        setState(() => _extraPayment = amount);
                        _runSimulation();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 当前债务汇总
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前债务汇总',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('总债务余额', '¥${summary.totalBalance.toStringAsFixed(0)}'),
                _buildInfoRow('月最低还款', '¥${summary.totalMinimumPayment.toStringAsFixed(0)}'),
                _buildInfoRow('月利息支出', '¥${summary.totalMonthlyInterest.toStringAsFixed(0)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 策略对比
        if (_snowballResult != null && _avalancheResult != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildStrategyCard(
                  context,
                  '雪球法',
                  Icons.ac_unit,
                  Colors.blue,
                  _snowballResult!,
                  isRecommended: monthsSaved > 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStrategyCard(
                  context,
                  '雪崩法',
                  Icons.trending_down,
                  Colors.orange,
                  _avalancheResult!,
                  isRecommended: interestSaved > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 节省对比
          Card(
            color: Colors.green.withValues(alpha:0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.savings, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '使用雪崩法可节省',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${interestSaved.abs().toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    interestSaved > 0
                        ? '利息支出 · 提前 ${monthsSaved.abs()} 个月还清'
                        : '两种策略结果相同',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStrategyCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    RepaymentSimulation result, {
    bool isRecommended = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (isRecommended) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '推荐',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _buildResultItem('还清时间', '${result.totalMonths}个月'),
            _buildResultItem('总利息', '¥${result.totalInterest.toStringAsFixed(0)}'),
            _buildResultItem('总还款', '¥${result.totalPaid.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text(
              '${result.payoffDate.year}年${result.payoffDate.month}月还清',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPlanTab(BuildContext context, ThemeData theme) {
    if (_avalancheResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = _avalancheResult!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 优先级列表
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_list_numbered, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      '还款优先级（雪崩法）',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '按利率从高到低排序，优先还清高利率债务',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ...result.plans.asMap().entries.map((entry) {
                  final index = entry.key;
                  final plan = entry.value;
                  return _buildPriorityItem(
                    index + 1,
                    plan.debt,
                    plan.payoffMonth,
                    plan.totalInterest,
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 详细还款计划
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '详细还款计划',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...result.plans.map((plan) => _buildDebtPlanSection(plan)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityItem(int priority, Debt debt, int payoffMonth, double interest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getPriorityColor(priority),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$priority',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '利率 ${debt.interestRateDisplay} · 余额 ¥${debt.currentBalance.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$payoffMonth个月',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '利息 ¥${interest.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDebtPlanSection(DebtRepaymentPlan plan) {
    return ExpansionTile(
      title: Text(plan.debt.name),
      subtitle: Text(
        '${plan.payoffMonth}个月还清 · 总利息 ¥${plan.totalInterest.toStringAsFixed(0)}',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: plan.debt.color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(plan.debt.icon, color: plan.debt.color, size: 20),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 表头
              Row(
                children: [
                  const Expanded(flex: 2, child: Text('月份', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('还款', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('本金', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('利息', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('余额', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(),
              // 显示前6个月和最后2个月
              ...plan.items.take(6).map((item) => _buildPlanRow(item)),
              if (plan.items.length > 8) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '... 省略 ${plan.items.length - 8} 个月 ...',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
                ...plan.items.skip(plan.items.length - 2).map((item) => _buildPlanRow(item)),
              ] else if (plan.items.length > 6) ...[
                ...plan.items.skip(6).map((item) => _buildPlanRow(item)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanRow(RepaymentPlanItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '第${item.month}月',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '¥${item.payment.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '¥${item.principal.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '¥${item.interest.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '¥${item.balanceAfter.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
