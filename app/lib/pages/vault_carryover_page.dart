import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 预算结转设置页面
/// 原型设计 3.11：预算结转设置
/// - 结转说明卡片
/// - 默认结转规则选择（全额结转/部分结转/清零重置）
/// - 分类结转设置
/// - 上月结转情况
class VaultCarryoverPage extends ConsumerStatefulWidget {
  const VaultCarryoverPage({super.key});

  @override
  ConsumerState<VaultCarryoverPage> createState() => _VaultCarryoverPageState();
}

class _VaultCarryoverPageState extends ConsumerState<VaultCarryoverPage> {
  int _selectedRuleIndex = 0;

  final List<_CarryoverRule> _rules = [
    _CarryoverRule(
      name: '全额结转',
      description: '剩余金额全部转入下月',
    ),
    _CarryoverRule(
      name: '部分结转',
      description: '最多结转50%到下月',
    ),
    _CarryoverRule(
      name: '清零重置',
      description: '每月预算从头开始',
    ),
  ];

  final List<_CategoryCarryover> _categories = [
    _CategoryCarryover(
      emoji: '🍽️',
      name: '餐饮',
      rule: '使用默认规则',
      isCustom: false,
    ),
    _CategoryCarryover(
      emoji: '🚗',
      name: '交通',
      rule: '自定义：清零重置',
      isCustom: true,
      customColor: const Color(0xFF6495ED),
    ),
    _CategoryCarryover(
      emoji: '🛒',
      name: '购物',
      rule: '使用默认规则',
      isCustom: false,
    ),
    _CategoryCarryover(
      emoji: '💰',
      name: '储蓄',
      rule: '自定义：全额累积',
      isCustom: true,
      customColor: const Color(0xFF4CAF50),
    ),
  ];

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
                child: Column(
                  children: [
                    _buildInfoCard(context, theme),
                    _buildDefaultRules(context, theme),
                    _buildCategorySettings(context, theme),
                    _buildLastMonthCarryover(context, theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildSaveButton(context, theme),
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
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '预算结转设置',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.help_outline, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  /// 结转说明卡片
  Widget _buildInfoCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Color(0xFFFF8F00), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '什么是预算结转？',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF8F00),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '月底时，未用完的预算可以结转到下月继续使用，或者清零重新开始。您可以为每个分类设置不同的结转规则。',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 默认结转规则
  Widget _buildDefaultRules(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '默认结转规则',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _rules.asMap().entries.map((entry) {
                final index = entry.key;
                final rule = entry.value;
                final isSelected = index == _selectedRuleIndex;
                final isLast = index == _rules.length - 1;

                return GestureDetector(
                  onTap: () => setState(() => _selectedRuleIndex = index),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rule.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                rule.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 分类结转设置
  Widget _buildCategorySettings(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '分类结转设置',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '覆盖默认规则',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_categories.length, (index) {
            final category = _categories[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: category.isCustom
                      ? Border.all(color: category.customColor!)
                      : null,
                ),
                child: Row(
                  children: [
                    Text(category.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            category.rule,
                            style: TextStyle(
                              fontSize: 11,
                              color: category.isCustom
                                  ? category.customColor
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: category.isCustom
                          ? category.customColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 上月结转情况
  Widget _buildLastMonthCarryover(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '上月结转情况',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '12月结转到1月',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Text(
                      '+¥1,280',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCarryoverChip('餐饮 +¥320'),
                    _buildCarryoverChip('购物 +¥560'),
                    _buildCarryoverChip('储蓄 +¥400'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarryoverChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }

  /// 保存按钮
  Widget _buildSaveButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('设置已保存')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('保存设置'),
          ),
        ),
      ),
    );
  }
}

class _CarryoverRule {
  final String name;
  final String description;

  _CarryoverRule({required this.name, required this.description});
}

class _CategoryCarryover {
  final String emoji;
  final String name;
  final String rule;
  final bool isCustom;
  final Color? customColor;

  _CategoryCarryover({
    required this.emoji,
    required this.name,
    required this.rule,
    required this.isCustom,
    this.customColor,
  });
}
