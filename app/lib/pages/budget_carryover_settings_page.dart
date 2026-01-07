import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 预算结转设置页面
///
/// 对应原型设计 3.11 预算结转设置
/// 配置月底未用完预算的结转规则
class BudgetCarryoverSettingsPage extends ConsumerStatefulWidget {
  const BudgetCarryoverSettingsPage({super.key});

  @override
  ConsumerState<BudgetCarryoverSettingsPage> createState() =>
      _BudgetCarryoverSettingsPageState();
}

class _BudgetCarryoverSettingsPageState
    extends ConsumerState<BudgetCarryoverSettingsPage> {
  CarryoverRule _defaultRule = CarryoverRule.full;
  final Map<String, CarryoverRule?> _categoryOverrides = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预算结转设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 结转说明卡片
          _ExplanationCard(),

          const SizedBox(height: 20),

          // 默认结转规则
          const Text(
            '默认结转规则',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          _RuleOptionsCard(
            selectedRule: _defaultRule,
            onRuleChanged: (rule) {
              setState(() => _defaultRule = rule);
            },
          ),

          const SizedBox(height: 24),

          // 分类结转设置
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '分类结转设置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '覆盖默认规则',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 分类列表
          _CategorySettingCard(
            emoji: '🍽️',
            name: '餐饮',
            currentRule: _categoryOverrides['food'],
            defaultRule: _defaultRule,
            onRuleChanged: (rule) {
              setState(() => _categoryOverrides['food'] = rule);
            },
          ),

          _CategorySettingCard(
            emoji: '🚗',
            name: '交通',
            currentRule: _categoryOverrides['transport'],
            defaultRule: _defaultRule,
            onRuleChanged: (rule) {
              setState(() => _categoryOverrides['transport'] = rule);
            },
          ),

          _CategorySettingCard(
            emoji: '🎮',
            name: '娱乐',
            currentRule: _categoryOverrides['entertainment'],
            defaultRule: _defaultRule,
            onRuleChanged: (rule) {
              setState(() => _categoryOverrides['entertainment'] = rule);
            },
          ),

          _CategorySettingCard(
            emoji: '🛒',
            name: '购物',
            currentRule: _categoryOverrides['shopping'],
            defaultRule: _defaultRule,
            onRuleChanged: (rule) {
              setState(() => _categoryOverrides['shopping'] = rule);
            },
          ),

          const SizedBox(height: 24),

          // 保存按钮
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('保存设置'),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('什么是预算结转？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月底时，未用完的预算有三种处理方式���'),
            SizedBox(height: 12),
            Text('• 全额结转：剩余金额全部转入下月'),
            Text('• 部分结转：最多结转50%到下月'),
            Text('• 清零重置：每月预算从头开始'),
            SizedBox(height: 12),
            Text('您可以为不同分类设置不同的结转规则。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('结转设置已保存')),
    );
  }
}

/// 结转说明卡片
class _ExplanationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.orange[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '什么是预算结转？',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '月底时，未用完的预算可以结转到下月继续使用，或者清零重新开始。您可以为每个分类设置不同的结转规则。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
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
}

/// 结转规则选项卡片
class _RuleOptionsCard extends StatelessWidget {
  final CarryoverRule selectedRule;
  final ValueChanged<CarryoverRule> onRuleChanged;

  const _RuleOptionsCard({
    required this.selectedRule,
    required this.onRuleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: CarryoverRule.values.asMap().entries.map((entry) {
          final index = entry.key;
          final rule = entry.value;
          final isLast = index == CarryoverRule.values.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () => onRuleChanged(rule),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getRuleName(rule),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getRuleDescription(rule),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<CarryoverRule>(
                        value: rule,
                        groupValue: selectedRule,
                        onChanged: (value) {
                          if (value != null) onRuleChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: Colors.grey[200]),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _getRuleName(CarryoverRule rule) {
    switch (rule) {
      case CarryoverRule.full:
        return '全额结转';
      case CarryoverRule.partial:
        return '部分结转';
      case CarryoverRule.reset:
        return '清零重置';
    }
  }

  String _getRuleDescription(CarryoverRule rule) {
    switch (rule) {
      case CarryoverRule.full:
        return '剩余金额全部转入下月';
      case CarryoverRule.partial:
        return '最多结转50%到下月';
      case CarryoverRule.reset:
        return '每月预算从头开始';
    }
  }
}

/// 分类设置卡片
class _CategorySettingCard extends StatelessWidget {
  final String emoji;
  final String name;
  final CarryoverRule? currentRule;
  final CarryoverRule defaultRule;
  final ValueChanged<CarryoverRule?> onRuleChanged;

  const _CategorySettingCard({
    required this.emoji,
    required this.name,
    required this.currentRule,
    required this.defaultRule,
    required this.onRuleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRule = currentRule ?? defaultRule;
    final isOverridden = currentRule != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isOverridden ? '自定义规则' : '使用默认规则',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverridden
                        ? Theme.of(context).primaryColor
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<CarryoverRule?>(
            initialValue: currentRule,
            onSelected: onRuleChanged,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getRuleShortName(effectiveRule),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('使用默认'),
              ),
              const PopupMenuDivider(),
              ...CarryoverRule.values.map((rule) => PopupMenuItem(
                    value: rule,
                    child: Text(_getRuleShortName(rule)),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  String _getRuleShortName(CarryoverRule rule) {
    switch (rule) {
      case CarryoverRule.full:
        return '全额结转';
      case CarryoverRule.partial:
        return '50%结转';
      case CarryoverRule.reset:
        return '清零';
    }
  }
}

enum CarryoverRule {
  full,
  partial,
  reset,
}
