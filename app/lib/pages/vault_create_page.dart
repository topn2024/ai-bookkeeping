import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget_vault.dart';
import '../services/vault_repository.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../providers/ledger_context_provider.dart';
import '../providers/budget_vault_provider.dart';
import 'package:uuid/uuid.dart';

/// 创建/编辑小金库页面
/// 原型设计 3.04：创建小金库
/// - 名称和图标设置
/// - 小金库类型选择（固定支出/弹性支出/储蓄目标/债务还款）
/// - 分配策略选择（固定金额/按百分比/补齐目标/分配剩余）
/// - 金额设置（每月分配/目标金额）
class VaultCreatePage extends ConsumerStatefulWidget {
  final BudgetVault? vault; // 如果提供，则为编辑模式

  const VaultCreatePage({super.key, this.vault});

  @override
  ConsumerState<VaultCreatePage> createState() => _VaultCreatePageState();
}

class _VaultCreatePageState extends ConsumerState<VaultCreatePage> {
  final _nameController = TextEditingController(text: '应急储备金');
  final _monthlyController = TextEditingController(text: '1,000');
  final _targetController = TextEditingController(text: '50,000');

  int _selectedTypeIndex = 0;
  int _selectedStrategyIndex = 0;

  final List<_VaultTypeOption> _vaultTypes = [
    _VaultTypeOption(
      icon: Icons.lock,
      name: '固定支出',
      description: '房租、水电',
      color: AppTheme.primaryColor,
    ),
    _VaultTypeOption(
      icon: Icons.tune,
      name: '弹性支出',
      description: '餐饮、娱乐',
      color: Colors.grey,
    ),
    _VaultTypeOption(
      icon: Icons.savings,
      name: '储蓄目标',
      description: '旅行、购物',
      color: Colors.grey,
    ),
    _VaultTypeOption(
      icon: Icons.credit_card,
      name: '债务还款',
      description: '信用卡、贷款',
      color: Colors.grey,
    ),
  ];

  final List<_AllocationStrategy> _strategies = [
    _AllocationStrategy(
      icon: Icons.payments,
      name: '固定金额',
      description: '每月分配固定金额',
    ),
    _AllocationStrategy(
      icon: Icons.percent,
      name: '按百分比',
      description: '按收入比例分配',
    ),
    _AllocationStrategy(
      icon: Icons.vertical_align_top,
      name: '补齐到目标',
      description: '自动补足到目标金额',
    ),
    _AllocationStrategy(
      icon: Icons.all_inclusive,
      name: '分配剩余',
      description: '分配其他小金库后的剩余',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 如果是编辑模式，预填充数据
    if (widget.vault != null) {
      _nameController.text = widget.vault!.name;
      _monthlyController.text = widget.vault!.targetAllocation?.toStringAsFixed(0) ?? '0';
      _targetController.text = widget.vault!.targetAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _monthlyController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.vault != null;

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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameAndIcon(context, theme),
                    const SizedBox(height: 12),
                    _buildVaultTypeSection(context, theme),
                    const SizedBox(height: 12),
                    _buildAllocationStrategy(context, theme),
                    const SizedBox(height: 12),
                    _buildAmountSettings(context, theme),
                    const SizedBox(height: 20),
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
          Expanded(
            child: Text(
              _isEditMode ? '编辑小金库' : '新建小金库',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _saveVault,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                '保存',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 名称和图标
  Widget _buildNameAndIcon(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.savings, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '小金库名称',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击更换图标和颜色',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 小金库类型
  Widget _buildVaultTypeSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '小金库类型',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: List.generate(_vaultTypes.length, (index) {
            final type = _vaultTypes[index];
            final isSelected = index == _selectedTypeIndex;

            return GestureDetector(
              onTap: () => setState(() => _selectedTypeIndex = index),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type.icon,
                      size: 24,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      type.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? Colors.white70
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 分配策略
  Widget _buildAllocationStrategy(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '分配策略',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        ...List.generate(_strategies.length, (index) {
          final strategy = _strategies[index];
          final isSelected = index == _selectedStrategyIndex;

          return GestureDetector(
            onTap: () => setState(() => _selectedStrategyIndex = index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEBF3FF)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    strategy.icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strategy.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          strategy.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 金额设置
  Widget _buildAmountSettings(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '金额设置',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '每月分配',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _monthlyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '目标金额',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _targetController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
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
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveVault() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入小金库名称')),
      );
      return;
    }

    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到当前账本')),
      );
      return;
    }

    final monthlyText = _monthlyController.text.replaceAll(',', '').trim();
    final targetText = _targetController.text.replaceAll(',', '').trim();

    double monthlyAmount = 0;
    if (monthlyText.isNotEmpty) {
      final parsed = double.tryParse(monthlyText);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的月度金额')),
        );
        return;
      }
      monthlyAmount = parsed;
    }

    double targetAmount = 0;
    if (targetText.isNotEmpty) {
      final parsed = double.tryParse(targetText);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的目标金额')),
        );
        return;
      }
      targetAmount = parsed;
    }

    final vaultType = VaultType.values[_selectedTypeIndex];
    final allocationType = AllocationType.values[_selectedStrategyIndex];

    final vault = BudgetVault(
      id: _isEditMode ? widget.vault!.id : const Uuid().v4(),
      name: name,
      icon: vaultType.defaultIcon,
      color: vaultType.defaultColor,
      type: vaultType,
      targetAmount: targetAmount,
      ledgerId: ledgerId,
      allocationType: allocationType,
      targetAllocation: monthlyAmount,
    );

    try {
      final db = await sl<IDatabaseService>().database;
      final repository = VaultRepository(db);
      await repository.create(vault);

      // 刷新provider状态
      if (mounted) {
        await ref.read(budgetVaultProvider.notifier).refresh();
      }

      if (mounted) {
        // 先显示成功消息，再关闭页面
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('小金库 "$name" ${_isEditMode ? '更新' : '创建'}成功')),
        );
        // 延迟一小段时间让SnackBar显示，然后关闭页面
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}

class _VaultTypeOption {
  final IconData icon;
  final String name;
  final String description;
  final Color color;

  _VaultTypeOption({
    required this.icon,
    required this.name,
    required this.description,
    required this.color,
  });
}

class _AllocationStrategy {
  final IconData icon;
  final String name;
  final String description;

  _AllocationStrategy({
    required this.icon,
    required this.name,
    required this.description,
  });
}
