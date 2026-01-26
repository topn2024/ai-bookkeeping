import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/peer_comparison_provider.dart';
import '../services/social_comparison_service.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';

/// 同类用户对比页面
///
/// 对应原型设计 10.12 同类用户对比
/// 与相似背景用户进行匿名消费对比
class PeerComparisonPage extends ConsumerWidget {
  const PeerComparisonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(peerComparisonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同类用户对比'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(peerComparisonProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildErrorView(context, state.error!, ref)
              : _buildContent(context, state),
    );
  }

  Widget _buildErrorView(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(peerComparisonProvider.notifier).refresh(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, PeerComparisonState state) {
    // 检查是否有足够的数据
    final hasEnoughData = (state.totalExpense ?? 0) > 0 || (state.totalIncome ?? 0) > 0;

    if (!hasEnoughData) {
      return _buildNoDataView(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // 需要通过 ref 调用 refresh，这里使用 Consumer
      },
      child: ListView(
        children: [
          // 用户画像卡片
          _UserProfileCard(
            userProfile: state.userProfile,
            spendingLevel: state.spendingLevel,
          ),

          // 总体对比
          _OverallComparisonCard(
            mySpending: state.totalExpense ?? 0,
            peerAverage: state.benchmark?.avgMonthlyExpense ?? 0,
          ),

          // 分类对比
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '分类消费对比',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 动态生成分类对比卡片
          ..._buildCategoryCards(state),

          // 财务习惯对比
          _HabitComparisonSection(
            moneyAge: state.moneyAge ?? 0,
            peerMoneyAge: state.benchmark?.avgMoneyAge ?? 0,
            savingsRate: state.savingsRate ?? 0,
            peerSavingsRate: state.benchmark?.avgSavingsRate ?? 0,
            recordingDays: state.recordingDays ?? 0,
          ),

          // 提升建议
          _SuggestionCard(insights: state.insights),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNoDataView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '暂无数据',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '记录更多交易后即可查看同类对比',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryCards(PeerComparisonState state) {
    final cards = <Widget>[];
    final categoryExpenses = state.categoryExpenses ?? {};
    final benchmarkCategories = state.benchmark?.categoryBenchmarks ?? {};

    // 主要对比的分类
    final mainCategories = ['food', 'shopping', 'transport', 'entertainment'];

    for (final categoryId in mainCategories) {
      final myAmount = _getCategoryTotal(categoryExpenses, categoryId);
      final peerAmount = benchmarkCategories[categoryId] ?? 0;

      // 只显示有数据的分类
      if (myAmount > 0 || peerAmount > 0) {
        final category = DefaultCategories.findById(categoryId);
        cards.add(_CategoryComparisonCard(
          category: category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(categoryId),
          emoji: _getCategoryEmoji(categoryId),
          myAmount: myAmount,
          peerAmount: peerAmount,
        ));
      }
    }

    // 如果没有任何分类数据，显示提示
    if (cards.isEmpty) {
      cards.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '暂无分类消费数据',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return cards;
  }

  /// 获取某个分类及其子分类的总支出
  double _getCategoryTotal(Map<String, double> expenses, String parentId) {
    double total = expenses[parentId] ?? 0;
    // 累加子分类
    for (final entry in expenses.entries) {
      if (entry.key.startsWith('${parentId}_')) {
        total += entry.value;
      }
    }
    return total;
  }

  String _getCategoryEmoji(String categoryId) {
    const emojis = {
      'food': '🍽️',
      'transport': '🚗',
      'shopping': '🛍️',
      'entertainment': '🎮',
      'housing': '🏠',
      'medical': '🏥',
      'education': '📚',
      'communication': '📱',
    };
    return emojis[categoryId] ?? '📊';
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于同类对比'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('我们根据以下条件匹配相似用户：'),
            SizedBox(height: 12),
            Text('• 年龄段相近'),
            Text('• 所在城市级别相同'),
            Text('• 收入水平相近'),
            SizedBox(height: 12),
            Text('所有数据均为匿名统计，保护用户隐私。'),
            SizedBox(height: 12),
            Text(
              '注：基准数据基于行业统计平均值，仅供参考。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
}

/// 用户画像卡片
class _UserProfileCard extends StatelessWidget {
  final UserProfileTag? userProfile;
  final SpendingLevel? spendingLevel;

  const _UserProfileCard({
    this.userProfile,
    this.spendingLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '您的对比群体',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _ProfileChip(label: userProfile?.displayName ?? '未知'),
                    _ProfileChip(label: '一线城市'),
                    if (spendingLevel != null)
                      _ProfileChip(label: spendingLevel!.displayName),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;

  const _ProfileChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue[700],
        ),
      ),
    );
  }
}

/// 总体对比卡片
class _OverallComparisonCard extends StatelessWidget {
  final double mySpending;
  final double peerAverage;

  const _OverallComparisonCard({
    required this.mySpending,
    required this.peerAverage,
  });

  @override
  Widget build(BuildContext context) {
    final diff = peerAverage > 0 ? mySpending - peerAverage : 0.0;
    final diffPercent = peerAverage > 0 ? (diff / peerAverage * 100).abs() : 0.0;
    final isHigher = diff > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '本月消费对比',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      '我的消费',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${mySpending.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (peerAverage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHigher ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHigher ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: isHigher ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${diffPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isHigher ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      '同类平均',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      peerAverage > 0 ? '¥${peerAverage.toStringAsFixed(0)}' : '--',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (peerAverage > 0)
            Text(
              isHigher
                  ? '您的消费比同类用户高 ${diffPercent.toStringAsFixed(0)}%'
                  : '您的消费比同类用户低 ${diffPercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 13,
                color: isHigher ? Colors.red : Colors.green,
              ),
            ),
        ],
      ),
    );
  }
}

/// 分类对比卡片
class _CategoryComparisonCard extends StatelessWidget {
  final String category;
  final String emoji;
  final double myAmount;
  final double peerAmount;

  const _CategoryComparisonCard({
    required this.category,
    required this.emoji,
    required this.myAmount,
    required this.peerAmount,
  });

  @override
  Widget build(BuildContext context) {
    final maxAmount = (myAmount > peerAmount ? myAmount : peerAmount) * 1.2;
    final myProgress = maxAmount > 0 ? myAmount / maxAmount : 0.0;
    final peerProgress = maxAmount > 0 ? peerAmount / maxAmount : 0.0;
    final isHigher = myAmount > peerAmount && peerAmount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isHigher)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '偏高',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 我的消费
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  '我',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: myProgress.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '¥${myAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 同类平均
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  '同类',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: peerProgress.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  peerAmount > 0 ? '¥${peerAmount.toStringAsFixed(0)}' : '--',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 财务习惯对比
class _HabitComparisonSection extends StatelessWidget {
  final double moneyAge;
  final double peerMoneyAge;
  final double savingsRate;
  final double peerSavingsRate;
  final int recordingDays;

  const _HabitComparisonSection({
    required this.moneyAge,
    required this.peerMoneyAge,
    required this.savingsRate,
    required this.peerSavingsRate,
    required this.recordingDays,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '财务习惯对比',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HabitCard(
                icon: Icons.schedule,
                label: '钱龄',
                myValue: moneyAge > 0 ? '${moneyAge.toStringAsFixed(0)}天' : '--',
                peerValue: peerMoneyAge > 0 ? '${peerMoneyAge.toStringAsFixed(0)}天' : '--',
                isBetter: moneyAge > peerMoneyAge && moneyAge > 0,
              ),
              const SizedBox(width: 8),
              _HabitCard(
                icon: Icons.savings,
                label: '储蓄率',
                myValue: '${(savingsRate * 100).toStringAsFixed(0)}%',
                peerValue: peerSavingsRate > 0 ? '${(peerSavingsRate * 100).toStringAsFixed(0)}%' : '--',
                isBetter: savingsRate > peerSavingsRate,
              ),
              const SizedBox(width: 8),
              _HabitCard(
                icon: Icons.local_fire_department,
                label: '本月记账',
                myValue: '$recordingDays天',
                peerValue: '15天',
                isBetter: recordingDays > 15,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String myValue;
  final String peerValue;
  final bool isBetter;

  const _HabitCard({
    required this.icon,
    required this.label,
    required this.myValue,
    required this.peerValue,
    required this.isBetter,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBetter ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isBetter ? Colors.green : Colors.grey, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              myValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isBetter ? Colors.green : Colors.black,
              ),
            ),
            Text(
              '同类 $peerValue',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 建议卡片
class _SuggestionCard extends StatelessWidget {
  final List<ComparisonInsight> insights;

  const _SuggestionCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    // 获取需要改进的建议
    final suggestions = insights
        .where((i) => !i.isPositive)
        .map((i) => i.suggestion)
        .take(3)
        .toList();

    // 如果没有改进建议，显示鼓励
    if (suggestions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  '表现不错',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '您的消费习惯整体良好，继续保持！',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                '优化建议',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            suggestions.map((s) => '• $s').join('\n'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
