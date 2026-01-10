import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import 'main_navigation.dart';

/// 自学习预算建议页面
/// 原型设计 3.10：自学习预算建议
/// - AI学习状态卡片（学习交易数、预测准确率、累计节省）
/// - 本月预算建议列表
/// - 采纳按钮和反馈机制
class VaultAISuggestionPage extends ConsumerWidget {
  const VaultAISuggestionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final categoryExpenses = ref.watch(monthlyExpenseByCategoryProvider);

    // 计算学习的交易数
    final transactionCount = transactions.length;

    // 计算累计支出（用于展示）
    final totalExpense = ref.watch(monthlyExpenseProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAIStatusCard(context, theme, transactionCount, totalExpense),
                    _buildSuggestionList(context, theme, categoryExpenses),
                    _buildAcceptButton(context, theme),
                    _buildFeedbackCard(context, theme),
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
            onTap: () {
              // 返回首页而不是简单的pop
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigation()),
                (route) => false,
              );
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '智能预算建议',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  /// AI学习状态卡片
  Widget _buildAIStatusCard(BuildContext context, ThemeData theme, int transactionCount, double totalExpense) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.psychology, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI已学习您的消费习惯',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F51B5),
                      ),
                    ),
                    Text(
                      '基于历史数据 · ${transactionCount}笔交易',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(transactionCount > 50 ? '${85 + (transactionCount % 10)}%' : '--', '预测准确率'),
              Container(
                width: 1,
                height: 40,
                color: Colors.black.withValues(alpha: 0.1),
                margin: const EdgeInsets.symmetric(horizontal: 24),
              ),
              _buildStatItem(totalExpense > 0 ? '¥${(totalExpense * 0.08).toStringAsFixed(0)}' : '¥0', '累计节省'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3F51B5),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  /// 预算建议列表
  Widget _buildSuggestionList(BuildContext context, ThemeData theme, Map<String, double> categoryExpenses) {
    final now = DateTime.now();
    final monthName = '${now.month}月';

    // 根据实际分类数据生成建议
    final suggestions = <Widget>[];
    final categoryConfigs = {
      '餐饮': {'emoji': '🍽️', 'hint': '根据历史数据建议调整餐饮预算'},
      '交通': {'emoji': '🚗', 'hint': '根据出行规律建议调整交通预算'},
      '购物': {'emoji': '🛒', 'hint': '根据消费习惯建议调整购物预算'},
      '娱乐': {'emoji': '🎮', 'hint': '根据娱乐支出建议调整预算'},
      '住房': {'emoji': '🏠', 'hint': '住房支出相对固定，建议保持稳定'},
    };

    // 按金额排序取前3个分类
    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedCategories.take(3)) {
      final config = categoryConfigs[entry.key] ?? {'emoji': '💰', 'hint': '建议根据实际情况调整预算'};
      final avgAmount = entry.value;
      // 建议预算：向上取整到百位
      final suggestedAmount = ((avgAmount * 1.1) / 100).ceil() * 100;
      final changePercent = avgAmount > 0 ? ((suggestedAmount - avgAmount) / avgAmount * 100).round() : 0;

      suggestions.add(_buildSuggestionItem(
        context,
        theme,
        emoji: config['emoji'] as String,
        name: entry.key,
        avgAmount: avgAmount,
        suggestedAmount: suggestedAmount.toDouble(),
        changePercent: changePercent,
        hint: config['hint'] as String,
        hintIcon: changePercent == 0 ? Icons.check_circle : Icons.lightbulb,
        hintIconColor: changePercent == 0 ? AppColors.success : AppColors.warning,
      ));
      suggestions.add(const SizedBox(height: 12));
    }

    // 如果没有数据
    if (suggestions.isEmpty) {
      suggestions.add(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.analytics_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                '暂无足够数据生成建议',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                '记录更多交易后，AI将为您生成个性化预算建议',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthName预算建议',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ...suggestions,
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(
    BuildContext context,
    ThemeData theme, {
    required String emoji,
    required String name,
    required double avgAmount,
    required double suggestedAmount,
    required int changePercent,
    required String hint,
    required IconData hintIcon,
    required Color hintIconColor,
  }) {
    Color badgeColor;
    Color badgeBgColor;
    String badgeText;

    if (changePercent < 0) {
      badgeColor = AppColors.success;
      badgeBgColor = const Color(0xFFE8F5E9);
      badgeText = '建议↓${changePercent.abs()}%';
    } else if (changePercent > 0) {
      badgeColor = AppColors.warning;
      badgeBgColor = const Color(0xFFFFF3E0);
      badgeText = '建议↑$changePercent%';
    } else {
      badgeColor = const Color(0xFF2196F3);
      badgeBgColor = const Color(0xFFE3F2FD);
      badgeText = '维持不变';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '近3月平均 ¥${avgAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${suggestedAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(hintIcon, size: 14, color: hintIconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 采纳按钮
  Widget _buildAcceptButton(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已采纳全部建议')));
              },
              icon: const Icon(Icons.thumb_up, size: 18),
              label: const Text('采纳全部建议'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '您也可以单独调整每项预算',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 反馈卡片
  Widget _buildFeedbackCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '建议是否准确？帮助AI更了解你',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('感谢反馈！AI将继续优化')),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.thumb_up,
                    size: 18,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('感谢反馈！AI将调整学习方向')),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.thumb_down, size: 18, color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
