import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../providers/template_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/duplicate_transaction_dialog.dart';
import 'template_management_page.dart';

class QuickEntryPage extends ConsumerStatefulWidget {
  const QuickEntryPage({super.key});

  @override
  ConsumerState<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends ConsumerState<QuickEntryPage> {
  // 缓存主题颜色供回调使用
  late ThemeColors _themeColors;

  @override
  void dispose() {
    // 清除 SnackBar，避免返回首页后继续显示
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(templateProvider);
    final frequentlyUsed = ref.watch(templateProvider.notifier).getFrequentlyUsed();
    final theme = Theme.of(context);
    // 获取主题颜色（监听变化）
    _themeColors = ref.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('快速记账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TemplateManagementPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flash_on,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无记账模板',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TemplateManagementPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('创建模板'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick action grid
                  if (frequentlyUsed.isNotEmpty) ...[
                    Text(
                      '常用模板',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: frequentlyUsed.length,
                      itemBuilder: (context, index) {
                        return _buildTemplateCard(frequentlyUsed[index]);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // All templates list
                  Text(
                    '全部模板',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      return _buildTemplateListItem(templates[index]);
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTemplateCard(TransactionTemplate template) {
    return Card(
      child: InkWell(
        onTap: () => _useTemplate(template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                flex: 2,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: template.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    template.icon,
                    color: template.color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                flex: 1,
                child: Text(
                  template.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (template.amount != null)
                Flexible(
                  flex: 1,
                  child: Text(
                    '¥${template.amount!.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: template.type == TransactionType.income
                          ? _themeColors.income
                          : _themeColors.expense,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateListItem(TransactionTemplate template) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: template.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(template.icon, color: template.color),
        ),
        title: Text(template.name),
        subtitle: Text(
          '${template.typeName} · ${template.category}',
          style: TextStyle(color: theme.colorScheme.outline),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (template.amount != null)
              Text(
                '¥${template.amount!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: template.type == TransactionType.income
                      ? _themeColors.income
                      : _themeColors.expense,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.flash_on),
              color: theme.primaryColor,
              onPressed: () => _useTemplate(template),
            ),
          ],
        ),
        onTap: () => _useTemplate(template),
      ),
    );
  }

  void _useTemplate(TransactionTemplate template) {
    if (template.amount != null) {
      // Has preset amount, directly create transaction
      _createTransaction(template, template.amount!);
    } else {
      // Need to input amount
      _showAmountDialog(template);
    }
  }

  void _showAmountDialog(TransactionTemplate template) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('输入金额 - ${template.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '金额',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                _createTransaction(template, amount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效金额')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _createTransaction(TransactionTemplate template, double amount) async {
    final transaction = template.toTransaction(overrideAmount: amount);

    // 先获取 notifier 引用，确保在回调中可用
    final transactionNotifier = ref.read(transactionProvider.notifier);
    final templateNotifier = ref.read(templateProvider.notifier);
    final transactionId = transaction.id;

    // 检查重复
    final checkResult = transactionNotifier.checkDuplicate(transaction);

    if (checkResult.hasPotentialDuplicate) {
      // 显示重复确认对话框
      final confirmed = await DuplicateTransactionDialog.show(
        context,
        newTransaction: transaction,
        checkResult: checkResult,
      );

      if (confirmed != true) {
        return; // 用户取消
      }
    }

    await transactionNotifier.forceAddTransaction(transaction);
    await templateNotifier.useTemplate(template.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已记录: ${template.name} ¥${amount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4), // 延长显示时间
          action: SnackBarAction(
            label: '撤销',
            textColor: Colors.white,
            onPressed: () {
              // 使用预先捕获的 notifier 和 ID
              transactionNotifier.deleteTransaction(transactionId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('已撤销'),
                  backgroundColor: _themeColors.transfer,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    }
  }
}
