import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 添加周期性收入页面
/// 原型设计 13.08：添加周期性收入
/// - 收入类型选择（工资、奖金、投资收益、租金、兼职、其他）
/// - 收入名称
/// - 收入金额
/// - 周期设置（重复周期、到账日、结束日期）
/// - 账户设置（收款账户、自动记账开关）
class PeriodicIncomePage extends ConsumerStatefulWidget {
  const PeriodicIncomePage({super.key});

  @override
  ConsumerState<PeriodicIncomePage> createState() => _PeriodicIncomePageState();
}

class _PeriodicIncomePageState extends ConsumerState<PeriodicIncomePage> {
  int _selectedIncomeType = 0;
  final _nameController = TextEditingController(text: '每月工资');
  final _amountController = TextEditingController(text: '15000');
  bool _isFixedAmount = true;
  String _repeatCycle = '每月';
  int _dayOfMonth = 5;
  String _endDate = '永不结束';
  String _account = '工资卡';
  bool _autoRecord = true;

  final List<Map<String, dynamic>> _incomeTypes = [
    {'icon': '💰', 'label': '工资'},
    {'icon': '🎁', 'label': '奖金'},
    {'icon': '📈', 'label': '投资收益'},
    {'icon': '🏠', 'label': '租金'},
    {'icon': '💼', 'label': '兼职'},
    {'icon': '📦', 'label': '其他'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIncomeTypeSection(theme),
                    const SizedBox(height: 20),
                    _buildIncomeNameCard(theme),
                    const SizedBox(height: 16),
                    _buildAmountCard(theme),
                    const SizedBox(height: 20),
                    _buildCycleSettingsSection(theme),
                    const SizedBox(height: 20),
                    _buildAccountSettingsSection(theme),
                    const SizedBox(height: 20),
                    _buildTipCard(theme),
                  ],
                ),
              ),
            ),
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
              '添加周期性收入',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _saveIncome(context),
            child: Text(
              '保存',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 收入类型选择
  Widget _buildIncomeTypeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '收入类型',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_incomeTypes.length, (index) {
            final type = _incomeTypes[index];
            final isSelected = _selectedIncomeType == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedIncomeType = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${type['icon']} ${type['label']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 收入名称卡片
  Widget _buildIncomeNameCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          '收入名称',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: TextField(
          controller: _nameController,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        trailing: Icon(
          Icons.edit,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }

  /// 金额卡片
  Widget _buildAmountCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收入金额',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        '¥',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '固定金额',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Switch(
                  value: _isFixedAmount,
                  onChanged: (v) => setState(() => _isFixedAmount = v),
                  activeTrackColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 周期设置
  Widget _buildCycleSettingsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '周期设置',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingItem(
                theme,
                Icons.repeat,
                '重复周期',
                _repeatCycle,
                const Color(0xFF4CAF50),
                () => _showRepeatCycleSheet(context),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              _buildSettingItem(
                theme,
                Icons.event,
                '到账日',
                '每月$_dayOfMonth号',
                const Color(0xFF4CAF50),
                () => _showDayOfMonthSheet(context),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              _buildSettingItem(
                theme,
                Icons.date_range,
                '结束日期',
                _endDate,
                const Color(0xFF4CAF50),
                () => _showEndDateSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 账户设置
  Widget _buildAccountSettingsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账户设置',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingItem(
                theme,
                Icons.account_balance,
                '收款账户',
                _account,
                const Color(0xFF4CAF50),
                () => _showAccountSheet(context),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.autorenew,
                      color: const Color(0xFF4CAF50),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '自动记账',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '到账日自动创建收入记录',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoRecord,
                      onChanged: (v) => setState(() => _autoRecord = v),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    ThemeData theme,
    IconData icon,
    String title,
    String value,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 提示卡片
  Widget _buildTipCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates,
            color: Color(0xFF4CAF50),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '设置周期性收入后，系统会在到账日自动记录，并更新可支配预算',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF2E7D32),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRepeatCycleSheet(BuildContext context) {
    final options = ['每日', '每周', '每月', '每年'];
    _showOptionsSheet(context, '选择重复周期', options, (value) {
      setState(() => _repeatCycle = value);
    });
  }

  void _showDayOfMonthSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '选择到账日',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(28, (index) {
                final day = index + 1;
                final isSelected = _dayOfMonth == day;
                return GestureDetector(
                  onTap: () {
                    setState(() => _dayOfMonth = day);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEndDateSheet(BuildContext context) {
    final options = ['永不结束', '1年后', '2年后', '自定义'];
    _showOptionsSheet(context, '选择结束日期', options, (value) {
      setState(() => _endDate = value);
    });
  }

  void _showAccountSheet(BuildContext context) {
    final options = ['工资卡', '储蓄卡', '支付宝', '微信'];
    _showOptionsSheet(context, '选择收款账户', options, (value) {
      setState(() => _account = value);
    });
  }

  void _showOptionsSheet(
    BuildContext context,
    String title,
    List<String> options,
    Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...options.map((option) => ListTile(
                  title: Text(option),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    onSelect(option);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _saveIncome(BuildContext context) {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入收入名称')),
      );
      return;
    }
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入收入金额')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('周期性收入已添加')),
    );
    Navigator.pop(context, true);
  }
}
