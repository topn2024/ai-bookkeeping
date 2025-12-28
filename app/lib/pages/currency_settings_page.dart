import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/currency_provider.dart';
import '../providers/locale_provider.dart';
import '../models/currency.dart';

class CurrencySettingsPage extends ConsumerWidget {
  const CurrencySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyProvider);
    final currencyNotifier = ref.read(currencyProvider.notifier);
    final l10n = ref.watch(localeProvider.notifier).l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.currencySettings),
      ),
      body: ListView(
        children: [
          // 设置说明
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '选择默认货币后，所有新建账目将使用此货币',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // 货币列表
          ...Currencies.list.map((currency) => RadioListTile<CurrencyType>(
            title: Row(
              children: [
                Text(currency.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text(currency.name),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    currency.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text('${currency.code} - ${currency.nameEn}'),
            value: currency.type,
            groupValue: currencyState.defaultCurrency,
            onChanged: (value) {
              if (value != null) {
                currencyNotifier.setDefaultCurrency(value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已切换为${currency.name} (${currency.symbol})'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          )),

          const Divider(height: 32),

          // 显示设置
          SwitchListTile(
            title: Text(l10n.showCurrencySymbol),
            subtitle: Text(currencyState.showCurrencySymbol
                ? '金额显示为 ${currencyState.currency.symbol}1,234.56'
                : '金额显示为 1,234.56'),
            value: currencyState.showCurrencySymbol,
            onChanged: (value) {
              currencyNotifier.setShowCurrencySymbol(value);
            },
          ),

          SwitchListTile(
            title: const Text('紧凑显示大数字'),
            subtitle: Text(currencyState.useCompactFormat
                ? '大额显示为 ${currencyState.currency.formatCompact(12345678)}'
                : '显示完整数字'),
            value: currencyState.useCompactFormat,
            onChanged: (value) {
              currencyNotifier.setUseCompactFormat(value);
            },
          ),

          const SizedBox(height: 24),

          // 示例展示
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '金额显示示例',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildExampleRow('小额', currencyState.format(123.45)),
                _buildExampleRow('中额', currencyState.format(12345.67)),
                _buildExampleRow('大额', currencyState.format(1234567.89)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExampleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
