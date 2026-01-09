import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/investment_account.dart';
import '../providers/investment_provider.dart';

class InvestmentPage extends ConsumerWidget {
  const InvestmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments = ref.watch(investmentProvider);
    final summary = ref.watch(investmentSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('投资账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddInvestmentDialog(context, ref),
          ),
        ],
      ),
      body: investments.isEmpty
          ? _buildEmptyState(context, ref)
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildSummaryCard(summary),
                  const SizedBox(height: 16),
                  _buildInvestmentList(context, ref, investments),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无投资账户',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加您的投资账户开始追踪收益',
            style: TextStyle(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddInvestmentDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加投资账户'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(InvestmentSummary summary) {
    final isProfitable = summary.totalProfit >= 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfitable
              ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
              : [const Color(0xFFE53935), const Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isProfitable ? Colors.green : Colors.red).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  '投资总览',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${summary.accountCount}个账户',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '总市值',
                  '¥${_formatAmount(summary.totalCurrentValue)}',
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white24,
              ),
              Expanded(
                child: _buildSummaryItem(
                  '总本金',
                  '¥${_formatAmount(summary.totalPrincipal)}',
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isProfitable ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '${isProfitable ? '+' : ''}¥${_formatAmount(summary.totalProfit)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${isProfitable ? '+' : ''}${summary.totalProfitRate.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInvestmentList(
    BuildContext context,
    WidgetRef ref,
    List<InvestmentAccount> investments,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的投资',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...investments.map((investment) => _buildInvestmentCard(
                context,
                ref,
                investment,
              )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(
    BuildContext context,
    WidgetRef ref,
    InvestmentAccount investment,
  ) {
    final typeColor = InvestmentTypeUtils.getColor(investment.type);
    final isProfitable = investment.isProfitable;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showInvestmentDetail(context, ref, investment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      InvestmentTypeUtils.getIcon(investment.type),
                      color: typeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          investment.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${InvestmentTypeUtils.getName(investment.type)}${investment.platform != null ? ' · ${investment.platform}' : ''}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${_formatAmount(investment.currentValue)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isProfitable ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            color: isProfitable ? AppColors.income : AppColors.expense,
                            size: 20,
                          ),
                          Text(
                            '${isProfitable ? '+' : ''}${investment.profitRate.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isProfitable ? AppColors.income : AppColors.expense,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem('本金', '¥${_formatAmount(investment.principal)}'),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      '收益',
                      '${isProfitable ? '+' : ''}¥${_formatAmount(investment.profit)}',
                      valueColor: isProfitable ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showAddInvestmentDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddInvestmentSheet(ref: ref),
    );
  }

  void _showInvestmentDetail(
    BuildContext context,
    WidgetRef ref,
    InvestmentAccount investment,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InvestmentDetailSheet(
        ref: ref,
        investment: investment,
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 10000) {
      return '${(amount / 10000).toStringAsFixed(2)}万';
    }
    return amount.toStringAsFixed(2);
  }
}

class _AddInvestmentSheet extends StatefulWidget {
  final WidgetRef ref;
  final InvestmentAccount? investment;

  const _AddInvestmentSheet({required this.ref, this.investment});

  @override
  State<_AddInvestmentSheet> createState() => _AddInvestmentSheetState();
}

class _AddInvestmentSheetState extends State<_AddInvestmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _principalController = TextEditingController();
  final _currentValueController = TextEditingController();
  final _platformController = TextEditingController();
  final _codeController = TextEditingController();
  final _noteController = TextEditingController();

  InvestmentType _selectedType = InvestmentType.fund;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.investment != null) {
      _isEditing = true;
      _nameController.text = widget.investment!.name;
      _principalController.text = widget.investment!.principal.toString();
      _currentValueController.text = widget.investment!.currentValue.toString();
      _platformController.text = widget.investment!.platform ?? '';
      _codeController.text = widget.investment!.code ?? '';
      _noteController.text = widget.investment!.note ?? '';
      _selectedType = widget.investment!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _currentValueController.dispose();
    _platformController.dispose();
    _codeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _isEditing ? '编辑投资' : '添加投资',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Investment type selector
                const Text('投资类型', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: InvestmentType.values.map((type) {
                    final isSelected = _selectedType == type;
                    final color = InvestmentTypeUtils.getColor(type);
                    return ChoiceChip(
                      label: Text(InvestmentTypeUtils.getName(type)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedType = type);
                      },
                      selectedColor: color.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? color : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      avatar: Icon(
                        InvestmentTypeUtils.getIcon(type),
                        size: 18,
                        color: isSelected ? color : AppColors.textSecondary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '投资名称',
                    hintText: '如：招商中证白酒',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入投资名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Principal and current value
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _principalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '本金',
                          prefixText: '¥ ',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入本金';
                          }
                          if (double.tryParse(value) == null) {
                            return '请输入有效金额';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _currentValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '当前市值',
                          prefixText: '¥ ',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入市值';
                          }
                          if (double.tryParse(value) == null) {
                            return '请输入有效金额';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Platform and code
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _platformController,
                        decoration: const InputDecoration(
                          labelText: '平台（选填）',
                          hintText: '如：支付宝',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: '代码（选填）',
                          hintText: '如：161725',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Note
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注（选填）',
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isEditing ? '保存修改' : '添加',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final investment = InvestmentAccount(
      id: widget.investment?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      type: _selectedType,
      principal: double.parse(_principalController.text),
      currentValue: double.parse(_currentValueController.text),
      platform: _platformController.text.trim().isNotEmpty
          ? _platformController.text.trim()
          : null,
      code: _codeController.text.trim().isNotEmpty
          ? _codeController.text.trim()
          : null,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      createdAt: widget.investment?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isEditing) {
      widget.ref.read(investmentProvider.notifier).updateInvestment(investment);
    } else {
      widget.ref.read(investmentProvider.notifier).addInvestment(investment);
    }

    Navigator.pop(context);
  }
}

class _InvestmentDetailSheet extends StatelessWidget {
  final WidgetRef ref;
  final InvestmentAccount investment;

  const _InvestmentDetailSheet({
    required this.ref,
    required this.investment,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = InvestmentTypeUtils.getColor(investment.type);
    final isProfitable = investment.isProfitable;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    InvestmentTypeUtils.getIcon(investment.type),
                    color: typeColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        investment.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        InvestmentTypeUtils.getName(investment.type),
                        style: TextStyle(
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Values
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        '当前市值',
                        '¥${investment.currentValue.toStringAsFixed(2)}',
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        '投入本金',
                        '¥${investment.principal.toStringAsFixed(2)}',
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        '累计收益',
                        '${isProfitable ? '+' : ''}¥${investment.profit.toStringAsFixed(2)}',
                        isProfitable ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        '收益率',
                        '${isProfitable ? '+' : ''}${investment.profitRate.toStringAsFixed(2)}%',
                        isProfitable ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),

                if (investment.platform != null || investment.code != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (investment.platform != null) ...[
                          const Icon(Icons.business, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(investment.platform!),
                          const SizedBox(width: 16),
                        ],
                        if (investment.code != null) ...[
                          const Icon(Icons.tag, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(investment.code!),
                        ],
                      ],
                    ),
                  ),
                ],

                if (investment.note != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      investment.note!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateValue(context),
                        icon: const Icon(Icons.edit),
                        label: const Text('更新市值'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editInvestment(context),
                        icon: const Icon(Icons.settings),
                        label: const Text('编辑'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _deleteInvestment(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _updateValue(BuildContext context) {
    final controller = TextEditingController(
      text: investment.currentValue.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更新市值'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '当前市值',
            prefixText: '¥ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入市值')),
                );
                return;
              }

              final newValue = double.tryParse(text);
              if (newValue == null || newValue < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的市值')),
                );
                return;
              }

              ref.read(investmentProvider.notifier).updateValue(
                investment.id,
                newValue,
              );
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close detail sheet
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _editInvestment(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddInvestmentSheet(
        ref: ref,
        investment: investment,
      ),
    );
  }

  void _deleteInvestment(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${investment.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(investmentProvider.notifier).deleteInvestment(investment.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close detail sheet
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
