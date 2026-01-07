import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 本地化预算推荐页面
/// 原型设计 3.12：本地化预算推荐
/// - 当前城市检测卡片
/// - 城市级别说明标签
/// - 推荐预算类目列表
/// - 城市对比
/// - 应用按钮
class VaultLocalizedPage extends ConsumerWidget {
  final String cityName;
  final String cityLevel;
  final double costIndex;

  const VaultLocalizedPage({
    super.key,
    this.cityName = '上海市',
    this.cityLevel = '一线城市',
    this.costIndex = 1.35,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    _buildLocationCard(context, theme),
                    _buildCityFeatures(context, theme),
                    _buildRecommendedBudgets(context, theme),
                    _buildCityComparison(context, theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildApplyButton(context, theme),
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
              '本地化预算推荐',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.location_on, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  /// 当前城市检测卡片
  Widget _buildLocationCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.my_location, color: Colors.white),
              SizedBox(width: 10),
              Text(
                '基于您的位置智能推荐',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🏙️', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cityName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$cityLevel · 消费水平指数 $costIndex',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 城市级别说明
  Widget _buildCityFeatures(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                '一线城市预算特点',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFeatureChip('🏠 房租占比高', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                _buildFeatureChip('🚇 通勤成本大', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                _buildFeatureChip('🍽️ 外卖价格高', const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
                _buildFeatureChip('💰 收入水平高', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }

  /// 推荐预算类目
  Widget _buildRecommendedBudgets(BuildContext context, ThemeData theme) {
    final budgets = [
      _LocalizedBudget(
        emoji: '🏠',
        name: '房租/房贷',
        amount: 4500,
        description: '上海平均租房 ¥4,200-5,500/月',
        gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
        suggestion: '占收入建议比例',
        suggestionValue: '30-35%',
        suggestionColor: const Color(0xFFE65100),
      ),
      _LocalizedBudget(
        emoji: '🚇',
        name: '交通通勤',
        amount: 800,
        description: '地铁月票 + 偶尔打车',
        gradientColors: [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
        suggestion: '省钱建议',
        suggestionValue: '地铁日票¥18，比打车省60%',
        suggestionColor: const Color(0xFF2E7D32),
      ),
      _LocalizedBudget(
        emoji: '🍽️',
        name: '餐饮',
        amount: 2200,
        description: '上海外卖均价 ¥35-45/餐',
        gradientColors: [const Color(0xFFFFD93D), const Color(0xFFFF9500)],
        suggestion: '省钱建议',
        suggestionValue: '食堂就餐可省40%+',
        suggestionColor: const Color(0xFF2E7D32),
      ),
      _LocalizedBudget(
        emoji: '🛍️',
        name: '购物娱乐',
        amount: 1500,
        description: '商圈消费、电影、健身等',
        gradientColors: [const Color(0xFFA855F7), const Color(0xFF7C3AED)],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '为您推荐的预算类目',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '基于上海消费水平',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...budgets.map((budget) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildBudgetCard(context, theme, budget),
          )),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    ThemeData theme,
    _LocalizedBudget budget,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: budget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(budget.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          budget.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '¥${budget.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      budget.description,
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
          if (budget.suggestion != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        budget.suggestion!.contains('省钱')
                            ? Icons.lightbulb
                            : Icons.insert_chart,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        budget.suggestion!,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    budget.suggestionValue!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: budget.suggestionColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 城市对比
  Widget _buildCityComparison(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '不同城市预算对比',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildCityCompareItem(
                      '一线城市',
                      '¥12,000',
                      '上海/北京',
                      const Color(0xFFE53935),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    _buildCityCompareItem(
                      '二线城市',
                      '¥8,000',
                      '杭州/成都',
                      const Color(0xFFFF9800),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    _buildCityCompareItem(
                      '三线城市',
                      '¥5,000',
                      '洛阳/绵阳',
                      const Color(0xFF4CAF50),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '预算建议基于各城市平均消费水平测算',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityCompareItem(
    String level,
    String amount,
    String cities,
    Color amountColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            level,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
          Text(
            cities,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  /// 应用按钮
  Widget _buildApplyButton(BuildContext context, ThemeData theme) {
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
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('本地化预算方案已应用')),
                  );
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('应用本地化预算方案'),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '或',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    // 切换城市
                  },
                  child: Text(
                    '切换到其他城市',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalizedBudget {
  final String emoji;
  final String name;
  final double amount;
  final String description;
  final List<Color> gradientColors;
  final String? suggestion;
  final String? suggestionValue;
  final Color? suggestionColor;

  _LocalizedBudget({
    required this.emoji,
    required this.name,
    required this.amount,
    required this.description,
    required this.gradientColors,
    this.suggestion,
    this.suggestionValue,
    this.suggestionColor,
  });
}
