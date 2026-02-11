import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/category_localization_service.dart';
import 'reports/monthly_report_page.dart';

class AnnualReportPage extends ConsumerStatefulWidget {
  const AnnualReportPage({super.key});

  @override
  ConsumerState<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends ConsumerState<AnnualReportPage> {
  late int _selectedYear;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionProvider);
    final yearTransactions = _getYearTransactions(allTransactions);
    final report = _generateReport(yearTransactions);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: GestureDetector(
          onTap: () => _showYearPicker(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_selectedYear年度报告',
                style: const TextStyle(color: Colors.white),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: yearTransactions.isEmpty
          ? _buildEmptyState()
          : PageView(
              controller: _pageController,
              children: [
                _buildOverviewPage(report),
                _buildIncomePage(report),
                _buildExpensePage(report),
                _buildMonthlyTrendPage(report),
                _buildHighlightsPage(report),
              ],
            ),
    );
  }

  List<Transaction> _getYearTransactions(List<Transaction> all) {
    return all.where((t) => t.date.year == _selectedYear).toList();
  }

  AnnualReport _generateReport(List<Transaction> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;
    final monthlyIncome = List.filled(12, 0.0);
    final monthlyExpense = List.filled(12, 0.0);
    final categoryExpenses = <String, double>{};
    final categoryIncomes = <String, double>{};
    int transactionCount = 0;

    for (final t in transactions) {
      transactionCount++;
      final month = t.date.month - 1;

      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
        monthlyIncome[month] += t.amount;
        categoryIncomes[t.category] = (categoryIncomes[t.category] ?? 0) + t.amount;
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
        monthlyExpense[month] += t.amount;
        categoryExpenses[t.category] = (categoryExpenses[t.category] ?? 0) + t.amount;
      }
    }

    // Sort categories by amount
    final sortedExpenses = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedIncomes = categoryIncomes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Find best and worst months
    int bestMonth = 0;
    int worstMonth = 0;
    double maxSavings = double.negativeInfinity;
    double minSavings = double.infinity;

    for (int i = 0; i < 12; i++) {
      final savings = monthlyIncome[i] - monthlyExpense[i];
      if (savings > maxSavings) {
        maxSavings = savings;
        bestMonth = i;
      }
      if (monthlyExpense[i] > 0 && savings < minSavings) {
        minSavings = savings;
        worstMonth = i;
      }
    }

    return AnnualReport(
      year: _selectedYear,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: totalIncome - totalExpense,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      topExpenseCategories: sortedExpenses.take(5).toList(),
      topIncomeCategories: sortedIncomes.take(5).toList(),
      transactionCount: transactionCount,
      bestMonth: bestMonth + 1,
      worstMonth: worstMonth + 1,
      avgMonthlyExpense: totalExpense / 12,
      avgMonthlyIncome: totalIncome / 12,
      savingsRate: totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome : 0,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined, size: 80, color: Colors.white.withValues(alpha:0.5)),
          const SizedBox(height: 16),
          Text(
            '$_selectedYear年暂无数据',
            style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha:0.7)),
          ),
          const SizedBox(height: 8),
          Text(
            '开始记账后查看年度报告',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha:0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPage(AnnualReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildReportCard(
            child: Column(
              children: [
                Text(
                  '$_selectedYear',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  '年度财务报告',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('记账笔数', '${report.transactionCount}笔', Icons.receipt),
                    _buildStatItem('记账天数', '${_calculateDays(report)}天', Icons.calendar_today),
                  ],
                ),
              ],
            ),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha:0.8),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildReportCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '年度收支概览',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildOverviewRow('总收入', report.totalIncome, Colors.green),
                const SizedBox(height: 12),
                _buildOverviewRow('总支出', report.totalExpense, Colors.red),
                const Divider(height: 32),
                _buildOverviewRow(
                  '净结余',
                  report.netSavings,
                  report.netSavings >= 0 ? Colors.green : Colors.red,
                  highlight: true,
                ),
                const SizedBox(height: 16),
                _buildSavingsRateIndicator(report.savingsRate),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPageIndicator(0),
        ],
      ),
    );
  }

  Widget _buildIncomePage(AnnualReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildReportCard(
            child: Column(
              children: [
                const Icon(Icons.trending_up, size: 48, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  '年度总收入',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${report.totalIncome.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '月均 ¥${report.avgMonthlyIncome.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (report.topIncomeCategories.isNotEmpty)
            _buildReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '收入来源',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...report.topIncomeCategories.map((e) => _buildCategoryRow(
                    e.key,
                    e.value,
                    report.totalIncome,
                    Colors.green,
                  )),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _buildPageIndicator(1),
        ],
      ),
    );
  }

  Widget _buildExpensePage(AnnualReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildReportCard(
            child: Column(
              children: [
                const Icon(Icons.trending_down, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  '年度总支出',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${report.totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '月均 ¥${report.avgMonthlyExpense.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (report.topExpenseCategories.isNotEmpty)
            _buildReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '支出分布',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...report.topExpenseCategories.map((e) => _buildCategoryRow(
                    e.key,
                    e.value,
                    report.totalExpense,
                    Colors.red,
                  )),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _buildPageIndicator(2),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendPage(AnnualReport report) {
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    final allValues = [...report.monthlyIncome, ...report.monthlyExpense];
    final maxValue = allValues.isEmpty ? 1.0 : allValues.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildReportCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '月度趋势',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildLegend('收入', Colors.green),
                    const SizedBox(width: 16),
                    _buildLegend('支出', Colors.red),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(12, (i) {
                      final incomeHeight = maxValue > 0
                          ? (report.monthlyIncome[i] / maxValue * 160)
                          : 0.0;
                      final expenseHeight = maxValue > 0
                          ? (report.monthlyExpense[i] / maxValue * 160)
                          : 0.0;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MonthlyReportPage(
                                initialDate: DateTime(_selectedYear, i + 1),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: incomeHeight.clamp(2.0, 160.0),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Container(
                                      width: 8,
                                      height: expenseHeight.clamp(2.0, 160.0),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  months[i].substring(0, months[i].length - 1),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniCard(
                  '收入最高月',
                  _getHighestIncomeMonth(report),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniCard(
                  '支出最高月',
                  _getHighestExpenseMonth(report),
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPageIndicator(3),
        ],
      ),
    );
  }

  Widget _buildHighlightsPage(AnnualReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildReportCard(
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  '年度亮点',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildHighlightItem(
                  Icons.savings,
                  '储蓄成就',
                  report.netSavings >= 0
                      ? '成功存下 ¥${report.netSavings.toStringAsFixed(0)}'
                      : '超支 ¥${(-report.netSavings).toStringAsFixed(0)}',
                  report.netSavings >= 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 16),
                _buildHighlightItem(
                  Icons.percent,
                  '储蓄率',
                  '${(report.savingsRate * 100).toStringAsFixed(1)}%',
                  _getSavingsRateColor(report.savingsRate),
                ),
                const SizedBox(height: 16),
                _buildHighlightItem(
                  Icons.star,
                  '最佳月份',
                  '${report.bestMonth}月',
                  Colors.amber,
                ),
                const SizedBox(height: 16),
                if (report.topExpenseCategories.isNotEmpty)
                  _buildHighlightItem(
                    Icons.shopping_cart,
                    '最大支出',
                    report.topExpenseCategories.first.key.localizedCategoryName,
                    Colors.orange,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildReportCard(
            child: Column(
              children: [
                const Text(
                  '财务建议',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._generateAdvice(report).map((advice) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          advice,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPageIndicator(4),
        ],
      ),
    );
  }

  Widget _buildReportCard({required Widget child, Gradient? gradient}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildOverviewRow(String label, double amount, Color color, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: highlight ? 18 : 16,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: highlight ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsRateIndicator(double rate) {
    final displayRate = (rate * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('储蓄率'),
            Text(
              '${displayRate.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getSavingsRateColor(rate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate.clamp(0, 1),
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getSavingsRateColor(rate)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getSavingsRateComment(rate),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(String category, double amount, double total, Color color) {
    final percent = total > 0 ? amount / total : 0.0;
    final displayName = category.localizedCategoryName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(displayName),
              Text(
                '¥${amount.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha:0.7)),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(percent * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMiniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
      ],
    );
  }

  Widget _buildPageIndicator(int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == currentPage
                ? Colors.white
                : Colors.white.withValues(alpha:0.3),
          ),
        );
      }),
    );
  }

  void _showYearPicker() {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (i) => currentYear - i);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择年份',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...years.map((year) => ListTile(
              title: Text('$year年'),
              trailing: year == _selectedYear
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                setState(() => _selectedYear = year);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  int _calculateDays(AnnualReport report) {
    // Simplified calculation
    return report.transactionCount > 0
        ? (report.transactionCount / 3).round().clamp(1, 365)
        : 0;
  }

  String _getHighestIncomeMonth(AnnualReport report) {
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    int maxIndex = 0;
    double maxValue = 0;
    for (int i = 0; i < 12; i++) {
      if (report.monthlyIncome[i] > maxValue) {
        maxValue = report.monthlyIncome[i];
        maxIndex = i;
      }
    }
    return '${months[maxIndex]} ¥${maxValue.toStringAsFixed(0)}';
  }

  String _getHighestExpenseMonth(AnnualReport report) {
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    int maxIndex = 0;
    double maxValue = 0;
    for (int i = 0; i < 12; i++) {
      if (report.monthlyExpense[i] > maxValue) {
        maxValue = report.monthlyExpense[i];
        maxIndex = i;
      }
    }
    return '${months[maxIndex]} ¥${maxValue.toStringAsFixed(0)}';
  }

  Color _getSavingsRateColor(double rate) {
    if (rate >= 0.3) return Colors.green;
    if (rate >= 0.1) return Colors.orange;
    return Colors.red;
  }

  String _getSavingsRateComment(double rate) {
    if (rate >= 0.3) return '储蓄习惯良好，继续保持！';
    if (rate >= 0.1) return '还不错，但还有提升空间';
    if (rate >= 0) return '储蓄率偏低，建议控制开支';
    return '支出超过收入，需要调整消费习惯';
  }

  List<String> _generateAdvice(AnnualReport report) {
    final advice = <String>[];

    if (report.savingsRate < 0.1) {
      advice.add('建议将储蓄率提升到10%以上，可以从减少非必要支出开始');
    } else if (report.savingsRate >= 0.3) {
      advice.add('储蓄率超过30%，财务状况非常健康！考虑进行一些投资');
    }

    if (report.topExpenseCategories.isNotEmpty) {
      final topCategory = report.topExpenseCategories.first;
      final topPercent = report.totalExpense > 0
          ? (topCategory.value / report.totalExpense * 100)
          : 0;
      if (topPercent > 30) {
        advice.add('${topCategory.key.localizedCategoryName}支出占比${topPercent.toStringAsFixed(0)}%，建议关注这方面的开支');
      }
    }

    if (report.avgMonthlyExpense > report.avgMonthlyIncome) {
      advice.add('月均支出超过月均收入，建议制定预算计划');
    }

    if (advice.isEmpty) {
      advice.add('财务状况良好，建议继续保持记账习惯，定期回顾财务状况');
    }

    return advice;
  }
}

class AnnualReport {
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final List<double> monthlyIncome;
  final List<double> monthlyExpense;
  final List<MapEntry<String, double>> topExpenseCategories;
  final List<MapEntry<String, double>> topIncomeCategories;
  final int transactionCount;
  final int bestMonth;
  final int worstMonth;
  final double avgMonthlyExpense;
  final double avgMonthlyIncome;
  final double savingsRate;

  AnnualReport({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.topExpenseCategories,
    required this.topIncomeCategories,
    required this.transactionCount,
    required this.bestMonth,
    required this.worstMonth,
    required this.avgMonthlyExpense,
    required this.avgMonthlyIncome,
    required this.savingsRate,
  });
}
