import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 智能账单建议页面
/// 原型设计 13.05：智能账单建议
/// - AI分析卡片
/// - 发现的定期消费列表
/// - 优化建议列表
class SmartBillSuggestionPage extends ConsumerStatefulWidget {
  const SmartBillSuggestionPage({super.key});

  @override
  ConsumerState<SmartBillSuggestionPage> createState() => _SmartBillSuggestionPageState();
}

class _SmartBillSuggestionPageState extends ConsumerState<SmartBillSuggestionPage> {
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
                    _buildAIAnalysisCard(theme),
                    const SizedBox(height: 20),
                    _buildDiscoveredRecurringSection(theme),
                    const SizedBox(height: 20),
                    _buildOptimizationSuggestions(theme),
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
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '智能建议',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// AI分析卡片
  Widget _buildAIAnalysisCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6495ED), Color(0xFF9370DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 10),
              const Text(
                'AI账单分析',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '本月更新',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '根据您的消费记录，AI发现了3个可能遗漏的定期账单和2个优化建议。',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 发现的定期消费
  Widget _buildDiscoveredRecurringSection(ThemeData theme) {
    final discoveries = [
      {
        'icon': Icons.fitness_center,
        'name': '健身房月卡',
        'description': '检测到每月10号有¥299支出',
        'color': const Color(0xFF6495ED),
      },
      {
        'icon': Icons.subscriptions,
        'name': '视频会员',
        'description': '检测到每月15号有¥25支出',
        'color': const Color(0xFF9370DB),
      },
      {
        'icon': Icons.cloud,
        'name': '云存储服务',
        'description': '检测到每月1号有¥6支出',
        'color': const Color(0xFF66BB6A),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '发现的定期消费',
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
            children: List.generate(discoveries.length, (index) {
              final item = discoveries[index];
              return Column(
                children: [
                  _buildDiscoveryItem(
                    theme,
                    item['icon'] as IconData,
                    item['name'] as String,
                    item['description'] as String,
                    item['color'] as Color,
                  ),
                  if (index < discoveries.length - 1)
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryItem(
    ThemeData theme,
    IconData icon,
    String name,
    String description,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _addToBillReminder(name),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('添加', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// 优化建议
  Widget _buildOptimizationSuggestions(ThemeData theme) {
    final suggestions = [
      {
        'icon': Icons.savings,
        'title': '年付省钱',
        'subtitle': '视频会员年付可省¥60/年',
        'color': const Color(0xFF66BB6A),
      },
      {
        'icon': Icons.schedule,
        'title': '还款日优化',
        'subtitle': '调整信用卡还款日至发薪日后3天',
        'color': const Color(0xFFFFB74D),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '优化建议',
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
            children: List.generate(suggestions.length, (index) {
              final item = suggestions[index];
              return Column(
                children: [
                  _buildSuggestionItem(
                    theme,
                    item['icon'] as IconData,
                    item['title'] as String,
                    item['subtitle'] as String,
                    item['color'] as Color,
                  ),
                  if (index < suggestions.length - 1)
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionItem(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return InkWell(
      onTap: () => _showSuggestionDetail(title),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _addToBillReminder(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加"$name"到账单提醒')),
    );
  }

  void _showSuggestionDetail(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('查看"$title"详情...')),
    );
  }
}
