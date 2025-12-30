import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../models/investment_account.dart';
import '../providers/account_provider.dart';
import '../providers/credit_card_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/investment_provider.dart';
import '../providers/debt_provider.dart';
import '../models/transaction.dart';

class AssetOverviewPage extends ConsumerStatefulWidget {
  const AssetOverviewPage({super.key});

  @override
  ConsumerState<AssetOverviewPage> createState() => _AssetOverviewPageState();
}

class _AssetOverviewPageState extends ConsumerState<AssetOverviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider);
    final creditCardSummary = ref.watch(creditCardSummaryProvider);
    final investmentSummary = ref.watch(investmentSummaryProvider);
    final investments = ref.watch(investmentProvider);
    final debtSummary = ref.watch(debtSummaryProvider);

    // Calculate totals including investments
    final assetAccounts = accounts.where((a) =>
        a.type != AccountType.creditCard && a.balance >= 0).toList();
    final accountAssets = assetAccounts.fold(0.0, (sum, a) => sum + a.balance);
    final investmentAssets = investmentSummary.totalCurrentValue;
    final totalAssets = accountAssets + investmentAssets;

    // Calculate liabilities including debts
    final creditCardLiabilities = creditCardSummary.totalUsed;
    final debtLiabilities = debtSummary.totalBalance;
    final totalLiabilities = creditCardLiabilities + debtLiabilities;
    final netWorth = totalAssets - totalLiabilities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产概览'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '净资产'),
            Tab(text: '资产趋势'),
            Tab(text: '资产分布'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNetWorthTab(
            totalAssets,
            totalLiabilities,
            netWorth,
            accounts,
            creditCardSummary,
            investmentSummary: investmentSummary,
            investments: investments,
            debtSummary: debtSummary,
          ),
          _buildTrendTab(),
          _buildDistributionTab(accounts, creditCardSummary, investmentSummary: investmentSummary, investments: investments),
        ],
      ),
    );
  }

  Widget _buildNetWorthTab(
    double totalAssets,
    double totalLiabilities,
    double netWorth,
    List<Account> accounts,
    CreditCardSummary creditCardSummary, {
    InvestmentSummary? investmentSummary,
    List<InvestmentAccount>? investments,
    DebtSummary? debtSummary,
  }) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Net worth card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha:0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha:0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  '净资产',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${netWorth.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildNetWorthItem(
                        '总资产',
                        totalAssets,
                        Icons.account_balance_wallet,
                        Colors.green,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white24,
                    ),
                    Expanded(
                      child: _buildNetWorthItem(
                        '总负债',
                        totalLiabilities,
                        Icons.credit_card,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Assets section - Accounts
          _buildSectionHeader('现金账户', accounts.where((a) => a.type != AccountType.creditCard && a.balance >= 0).fold(0.0, (sum, a) => sum + a.balance)),
          const SizedBox(height: 12),
          ...accounts
              .where((a) => a.type != AccountType.creditCard && a.balance >= 0)
              .map((account) => _buildAccountCard(account)),
          // Investment section
          if (investments != null && investments.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('投资资产', investmentSummary?.totalCurrentValue ?? 0),
            const SizedBox(height: 12),
            ...investments.map((investment) => _buildInvestmentCard(investment)),
            // Investment summary
            if (investmentSummary != null && investmentSummary.totalProfit != 0)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (investmentSummary.totalProfit >= 0 ? Colors.green : Colors.red).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('投资收益'),
                    Text(
                      '${investmentSummary.totalProfit >= 0 ? '+' : ''}¥${investmentSummary.totalProfit.toStringAsFixed(2)} (${investmentSummary.totalProfitRate.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        color: investmentSummary.totalProfit >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          // Liabilities section
          _buildSectionHeader('负债账户', totalLiabilities),
          const SizedBox(height: 12),
          if (creditCardSummary.totalUsed > 0)
            _buildLiabilityCard(
              '信用卡欠款',
              creditCardSummary.totalUsed,
              Icons.credit_card,
              Colors.red,
              '${creditCardSummary.cardCount}张卡',
            ),
          if (debtSummary != null && debtSummary.totalBalance > 0)
            _buildLiabilityCard(
              '贷款负债',
              debtSummary.totalBalance,
              Icons.account_balance,
              Colors.orange,
              '${debtSummary.activeCount}笔贷款',
            ),
          if (totalLiabilities == 0)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Text(
                    '恭喜！您目前没有负债',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Financial health indicator
          _buildHealthIndicator(netWorth, totalAssets, totalLiabilities),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(InvestmentAccount investment) {
    final profit = investment.currentValue - investment.principal;
    final profitRate = investment.principal > 0 ? (profit / investment.principal * 100) : 0.0;
    final isProfit = profit >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getInvestmentIcon(investment.type), color: Colors.purple),
        ),
        title: Text(investment.name),
        subtitle: Row(
          children: [
            Text(_getInvestmentTypeName(investment.type)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isProfit ? Colors.green : Colors.red).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${isProfit ? '+' : ''}${profitRate.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isProfit ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${investment.currentValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${isProfit ? '+' : ''}¥${profit.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: isProfit ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getInvestmentIcon(InvestmentType type) {
    switch (type) {
      case InvestmentType.stock:
        return Icons.show_chart;
      case InvestmentType.fund:
        return Icons.pie_chart;
      case InvestmentType.bond:
        return Icons.account_balance;
      case InvestmentType.deposit:
        return Icons.savings;
      case InvestmentType.crypto:
        return Icons.currency_bitcoin;
      case InvestmentType.gold:
        return Icons.diamond;
      case InvestmentType.realEstate:
        return Icons.home;
      case InvestmentType.other:
        return Icons.trending_up;
    }
  }

  String _getInvestmentTypeName(InvestmentType type) {
    switch (type) {
      case InvestmentType.stock:
        return '股票';
      case InvestmentType.fund:
        return '基金';
      case InvestmentType.bond:
        return '债券';
      case InvestmentType.deposit:
        return '定期存款';
      case InvestmentType.crypto:
        return '加密货币';
      case InvestmentType.gold:
        return '黄金';
      case InvestmentType.realEstate:
        return '房产';
      case InvestmentType.other:
        return '其他投资';
    }
  }

  Widget _buildNetWorthItem(String label, double amount, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          '¥${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, double total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '¥${total.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(Account account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: account.color.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(account.icon, color: account.color),
        ),
        title: Text(account.name),
        subtitle: Text(_getAccountTypeName(account.type)),
        trailing: Text(
          '¥${account.balance.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: account.balance >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildLiabilityCard(
    String name,
    double amount,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: Text(
          '-¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(double netWorth, double assets, double liabilities) {
    final debtToAssetRatio = assets > 0 ? liabilities / assets : 0.0;
    String healthStatus;
    Color healthColor;
    IconData healthIcon;
    String healthAdvice;

    if (debtToAssetRatio == 0) {
      healthStatus = '优秀';
      healthColor = Colors.green;
      healthIcon = Icons.sentiment_very_satisfied;
      healthAdvice = '无负债，财务状况非常健康！';
    } else if (debtToAssetRatio < 0.3) {
      healthStatus = '良好';
      healthColor = Colors.green;
      healthIcon = Icons.sentiment_satisfied;
      healthAdvice = '负债比例较低，继续保持良好习惯';
    } else if (debtToAssetRatio < 0.5) {
      healthStatus = '中等';
      healthColor = Colors.orange;
      healthIcon = Icons.sentiment_neutral;
      healthAdvice = '负债比例适中，建议逐步减少负债';
    } else {
      healthStatus = '需关注';
      healthColor = Colors.red;
      healthIcon = Icons.sentiment_dissatisfied;
      healthAdvice = '负债比例较高，建议优先偿还债务';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '财务健康度',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(healthIcon, color: healthColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        healthStatus,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: healthColor,
                        ),
                      ),
                      Text(
                        healthAdvice,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('负债/资产比', style: TextStyle(color: Colors.grey[600])),
                Text(
                  '${(debtToAssetRatio * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: healthColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: debtToAssetRatio.clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(healthColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendTab() {
    final transactions = ref.watch(transactionProvider);
    final trendData = _calculateMonthlyNetWorth(transactions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        '净资产变化趋势',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '近6个月',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _buildTrendChart(trendData),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '月度变化明细',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...trendData.reversed.map((data) => _buildTrendItem(data)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MonthlyNetWorth> _calculateMonthlyNetWorth(List<Transaction> transactions) {
    final now = DateTime.now();
    final result = <MonthlyNetWorth>[];
    double runningTotal = 0;

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthTransactions = transactions.where((t) =>
          t.date.year == month.year && t.date.month == month.month).toList();

      double income = 0;
      double expense = 0;

      for (final t in monthTransactions) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else if (t.type == TransactionType.expense) {
          expense += t.amount;
        }
      }

      final netChange = income - expense;
      runningTotal += netChange;

      result.add(MonthlyNetWorth(
        month: month,
        income: income,
        expense: expense,
        netChange: netChange,
        totalNetWorth: runningTotal,
      ));
    }

    return result;
  }

  Widget _buildTrendChart(List<MonthlyNetWorth> data) {
    if (data.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxValue = data.map((d) => d.totalNetWorth.abs()).reduce((a, b) => a > b ? a : b);
    final minValue = data.map((d) => d.totalNetWorth).reduce((a, b) => a < b ? a : b);
    final range = maxValue - (minValue < 0 ? minValue : 0);
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.asMap().entries.map((entry) {
        final item = entry.value;
        final height = range > 0
            ? ((item.totalNetWorth - (minValue < 0 ? minValue : 0)) / range * 160).clamp(10.0, 160.0)
            : 80.0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(item.totalNetWorth),
                  style: TextStyle(
                    fontSize: 9,
                    color: item.totalNetWorth >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: item.totalNetWorth >= 0
                        ? Colors.green.withValues(alpha:0.7)
                        : Colors.red.withValues(alpha:0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  months[item.month.month - 1],
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrendItem(MonthlyNetWorth data) {
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    final isPositive = data.netChange >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '${data.month.year}年${months[data.month.month - 1]}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}¥${data.netChange.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '收入 ¥${data.income.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Text(
            '支出 ¥${data.expense.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionTab(
    List<Account> accounts,
    CreditCardSummary creditCardSummary, {
    InvestmentSummary? investmentSummary,
    List<InvestmentAccount>? investments,
  }) {
    final assetAccounts = accounts.where((a) =>
        a.type != AccountType.creditCard && a.balance > 0).toList();
    final accountAssets = assetAccounts.fold(0.0, (sum, a) => sum + a.balance);
    final investmentAssets = investmentSummary?.totalCurrentValue ?? 0;
    final totalAssets = accountAssets + investmentAssets;

    // Group by type including investments
    final assetsByType = <String, double>{};
    for (final account in assetAccounts) {
      final typeName = _getAccountTypeName(account.type);
      assetsByType[typeName] = (assetsByType[typeName] ?? 0) + account.balance;
    }

    // Add investments by type
    if (investments != null) {
      for (final investment in investments) {
        final typeName = '投资-${_getInvestmentTypeName(investment.type)}';
        assetsByType[typeName] = (assetsByType[typeName] ?? 0) + investment.currentValue;
      }
    }

    final sortedTypes = assetsByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie chart card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        '资产分布',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (sortedTypes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('暂无资产数据'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Simple pie chart representation
                        SizedBox(
                          height: 200,
                          child: _buildSimplePieChartString(sortedTypes, totalAssets, colors),
                        ),
                        const SizedBox(height: 24),
                        // Legend
                        ...sortedTypes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final percent = totalAssets > 0 ? item.value / totalAssets * 100 : 0.0;
                          return _buildDistributionItem(
                            item.key,
                            item.value,
                            percent.toDouble(),
                            colors[index % colors.length],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Account details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '账户明细',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...assetAccounts.map((account) => _buildAccountDetailItem(account, totalAssets)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePieChartString(
    List<MapEntry<String, double>> data,
    double total,
    List<Color> colors,
  ) {
    if (data.isEmpty || total == 0) {
      return const Center(child: Text('暂无数据'));
    }

    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: CustomPaint(
          painter: _PieChartPainter(
            data.map((e) => e.value / total).toList(),
            colors,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('总资产', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  '¥${total.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionItem(String name, double amount, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name)),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Container(
            width: 50,
            alignment: Alignment.centerRight,
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailItem(Account account, double total) {
    final percent = total > 0 ? account.balance / total * 100 : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: account.color.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(account.icon, color: account.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      _getAccountTypeName(account.type),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${account.balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(account.color.withValues(alpha:0.7)),
            ),
          ),
        ],
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

  String _formatAmount(double amount) {
    if (amount.abs() >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }
}

class MonthlyNetWorth {
  final DateTime month;
  final double income;
  final double expense;
  final double netChange;
  final double totalNetWorth;

  MonthlyNetWorth({
    required this.month,
    required this.income,
    required this.expense,
    required this.netChange,
    required this.totalNetWorth,
  });
}

class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _PieChartPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final innerRadius = radius * 0.6;

    double startAngle = -90 * 3.14159 / 180;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = values[i] * 2 * 3.14159;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius - innerRadius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
