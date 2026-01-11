import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/currency.dart';
import '../providers/account_provider.dart';
import '../providers/currency_provider.dart';

/// 多币种报表页面
class MultiCurrencyReportPage extends ConsumerWidget {
  const MultiCurrencyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyProvider);
    final balanceByCurrency = ref.watch(balanceByCurrencyProvider);
    final convertedTotal = ref.watch(convertedTotalBalanceProvider);
    final accounts = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('多币种报表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            tooltip: '汇率设置',
            onPressed: () => _showExchangeRatesDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总资产卡片（转换后）
          _buildTotalAssetsCard(context, ref, convertedTotal, currencyState),
          const SizedBox(height: 16),

          // 按货币分组的资产
          _buildSectionTitle(context, '各币种资产'),
          const SizedBox(height: 8),
          _buildCurrencyBreakdown(context, ref, balanceByCurrency, currencyState),
          const SizedBox(height: 24),

          // 各币种账户明细
          _buildSectionTitle(context, '账户明细'),
          const SizedBox(height: 8),
          _buildAccountsByCurrency(context, ref, accounts, balanceByCurrency),
          const SizedBox(height: 24),

          // 汇率信息
          _buildSectionTitle(context, '当前汇率'),
          const SizedBox(height: 8),
          _buildExchangeRatesCard(context, ref),
        ],
      ),
    );
  }

  Widget _buildTotalAssetsCard(
    BuildContext context,
    WidgetRef ref,
    double convertedTotal,
    CurrencyState currencyState,
  ) {
    final defaultCurrency = currencyState.currency;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '总资产（${defaultCurrency.name}）',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        defaultCurrency.format(convertedTotal),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '已按当前汇率折算为${defaultCurrency.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildCurrencyBreakdown(
    BuildContext context,
    WidgetRef ref,
    Map<CurrencyType, double> balanceByCurrency,
    CurrencyState currencyState,
  ) {
    if (balanceByCurrency.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              '暂无资产数据',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
        ),
      );
    }

    final currencyNotifier = ref.read(currencyProvider.notifier);
    final defaultCurrency = currencyState.defaultCurrency;

    // 按转换后金额排序
    final sortedEntries = balanceByCurrency.entries.toList()
      ..sort((a, b) {
        final aConverted = currencyNotifier.convertAmount(a.value, a.key, defaultCurrency);
        final bConverted = currencyNotifier.convertAmount(b.value, b.key, defaultCurrency);
        return bConverted.compareTo(aConverted);
      });

    // 计算总额用于占比
    final totalConverted = sortedEntries.fold<double>(0, (sum, e) {
      return sum + currencyNotifier.convertAmount(e.value, e.key, defaultCurrency);
    });

    return Card(
      child: Column(
        children: sortedEntries.map((entry) {
          final currencyInfo = Currencies.get(entry.key);
          final balance = entry.value;
          final convertedBalance = currencyNotifier.convertAmount(
            balance,
            entry.key,
            defaultCurrency,
          );
          final percentage = totalConverted > 0
              ? (convertedBalance / totalConverted * 100)
              : 0.0;

          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getCurrencyColor(entry.key).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      currencyInfo.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(currencyInfo.name),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currencyInfo.code,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '占比 ${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyInfo.format(balance),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (entry.key != defaultCurrency)
                      Text(
                        '≈ ${Currencies.get(defaultCurrency).format(convertedBalance)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(_getCurrencyColor(entry.key)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccountsByCurrency(
    BuildContext context,
    WidgetRef ref,
    List accounts,
    Map<CurrencyType, double> balanceByCurrency,
  ) {
    if (balanceByCurrency.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: balanceByCurrency.keys.map((currency) {
        final currencyInfo = Currencies.get(currency);
        final currencyAccounts = accounts.where((a) => a.currency == currency).toList();

        if (currencyAccounts.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Text(
              currencyInfo.flag,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text('${currencyInfo.name}账户'),
            subtitle: Text('${currencyAccounts.length}个账户'),
            children: currencyAccounts.map<Widget>((account) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: account.color.withValues(alpha:0.1),
                  child: Icon(
                    account.icon,
                    color: account.color,
                    size: 20,
                  ),
                ),
                title: Text(account.localizedName),
                trailing: Text(
                  account.formattedBalance,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExchangeRatesCard(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(exchangeRatesProvider);
    final currencyState = ref.watch(currencyProvider);
    final defaultCurrency = currencyState.defaultCurrency;
    final defaultInfo = Currencies.get(defaultCurrency);

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('基准货币: ${defaultInfo.name} ${defaultInfo.flag}'),
            subtitle: currencyState.ratesUpdatedAt != null
                ? Text('更新时间: ${_formatDateTime(currencyState.ratesUpdatedAt!)}')
                : null,
            trailing: TextButton(
              onPressed: () => _showExchangeRatesDialog(context, ref),
              child: const Text('编辑汇率'),
            ),
          ),
          const Divider(height: 1),
          ...rates.map((rate) {
            final toInfo = Currencies.get(rate.toCurrency);
            return ListTile(
              leading: Text(toInfo.flag, style: const TextStyle(fontSize: 20)),
              title: Text(toInfo.name),
              subtitle: Text(toInfo.code),
              trailing: Text(
                '1 ${defaultInfo.code} = ${rate.rate.toStringAsFixed(4)} ${toInfo.code}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showExchangeRatesDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ExchangeRatesEditor(
          scrollController: scrollController,
        ),
      ),
    );
  }

  Color _getCurrencyColor(CurrencyType currency) {
    switch (currency) {
      case CurrencyType.cny:
        return Colors.red;
      case CurrencyType.usd:
        return Colors.green;
      case CurrencyType.eur:
        return Colors.blue;
      case CurrencyType.hkd:
        return Colors.purple;
      case CurrencyType.jpy:
        return Colors.pink;
      case CurrencyType.gbp:
        return Colors.indigo;
      case CurrencyType.krw:
        return Colors.teal;
      case CurrencyType.twd:
        return Colors.orange;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 汇率编辑器
class ExchangeRatesEditor extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const ExchangeRatesEditor({
    super.key,
    required this.scrollController,
  });

  @override
  ConsumerState<ExchangeRatesEditor> createState() => _ExchangeRatesEditorState();
}

class _ExchangeRatesEditorState extends ConsumerState<ExchangeRatesEditor> {
  final Map<CurrencyType, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final rates = ref.read(exchangeRatesProvider);
    for (final rate in rates) {
      _controllers[rate.toCurrency] = TextEditingController(
        text: rate.rate.toStringAsFixed(4),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyState = ref.watch(currencyProvider);
    final defaultCurrency = currencyState.defaultCurrency;
    final defaultInfo = Currencies.get(defaultCurrency);
    final rates = ref.watch(exchangeRatesProvider);

    return Column(
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '编辑汇率',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(currencyProvider.notifier).resetToDefaultRates();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已重置为默认汇率')),
                    );
                  }
                },
                child: const Text('重置默认'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saveRates,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
        // 基准货币提示
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(defaultInfo.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '基准货币: ${defaultInfo.name}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '以下汇率均为 1 ${defaultInfo.code} = X 目标货币',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 汇率列表
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: rates.length,
            itemBuilder: (context, index) {
              final rate = rates[index];
              final toInfo = Currencies.get(rate.toCurrency);
              final controller = _controllers[rate.toCurrency];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(toInfo.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(toInfo.name),
                  subtitle: Text('1 ${defaultInfo.code} →'),
                  trailing: SizedBox(
                    width: 120,
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        suffixText: toInfo.code,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveRates() async {
    try {
      final currencyNotifier = ref.read(currencyProvider.notifier);
      final defaultCurrency = ref.read(currencyProvider).defaultCurrency;

      for (final entry in _controllers.entries) {
        final value = double.tryParse(entry.value.text);
        if (value != null && value > 0) {
          await currencyNotifier.setExchangeRate(
            defaultCurrency,
            entry.key,
            value,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('汇率已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存汇率失败: $e')),
        );
      }
    }
  }
}
