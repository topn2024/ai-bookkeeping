import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 本地化预算推荐页面
///
/// 对应原型设计 3.12 本地化预算推荐
/// 基于用户所在城市的消费水平提供预算建议
class LocalizedBudgetPage extends ConsumerStatefulWidget {
  const LocalizedBudgetPage({super.key});

  @override
  ConsumerState<LocalizedBudgetPage> createState() => _LocalizedBudgetPageState();
}

class _LocalizedBudgetPageState extends ConsumerState<LocalizedBudgetPage> {
  CityTier _currentCity = CityTier.tier1;
  String _cityName = '上海市';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地化预算推荐'),
        actions: [
          IconButton(
            icon: Icon(Icons.location_on, color: Theme.of(context).primaryColor),
            onPressed: () => _showCitySelector(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 当前城市检测卡片
          _LocationCard(
            cityName: _cityName,
            cityTier: _currentCity,
            onChangeCity: () => _showCitySelector(context),
          ),

          // 城市级别说明
          _CityCharacteristicsCard(cityTier: _currentCity),

          // 推荐预算类目
          _RecommendedBudgetSection(
            cityTier: _currentCity,
            cityName: _cityName,
          ),

          // 城市对比
          _CityComparisonCard(currentTier: _currentCity),

          const SizedBox(height: 24),

          // 应用推荐按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _applyRecommendation,
              icon: const Icon(Icons.check_circle),
              label: const Text('应用推荐预算'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCitySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择城市',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Text('🏙️', style: TextStyle(fontSize: 24)),
              title: const Text('一线城市'),
              subtitle: const Text('上海、北京、深圳、广州'),
              trailing: _currentCity == CityTier.tier1
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () {
                setState(() {
                  _currentCity = CityTier.tier1;
                  _cityName = '上海市';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🌆', style: TextStyle(fontSize: 24)),
              title: const Text('新一线城市'),
              subtitle: const Text('杭州、成都、武汉、南京'),
              trailing: _currentCity == CityTier.newTier1
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () {
                setState(() {
                  _currentCity = CityTier.newTier1;
                  _cityName = '杭州市';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🏘️', style: TextStyle(fontSize: 24)),
              title: const Text('二线城市'),
              subtitle: const Text('长沙、郑州、济南、福州'),
              trailing: _currentCity == CityTier.tier2
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () {
                setState(() {
                  _currentCity = CityTier.tier2;
                  _cityName = '长沙市';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🏡', style: TextStyle(fontSize: 24)),
              title: const Text('三线及以下'),
              subtitle: const Text('其他城市'),
              trailing: _currentCity == CityTier.tier3
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () {
                setState(() {
                  _currentCity = CityTier.tier3;
                  _cityName = '本地';
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _applyRecommendation() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已应用本地化预算推荐')),
    );
  }
}

/// 位置检测卡片
class _LocationCard extends StatelessWidget {
  final String cityName;
  final CityTier cityTier;
  final VoidCallback onChangeCity;

  const _LocationCard({
    required this.cityName,
    required this.cityTier,
    required this.onChangeCity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[400]!, Colors.purple[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                '基于您的位置智能推荐',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onChangeCity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_location, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '切换',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_getTierLabel(cityTier)} · 消费水平指数 ${_getCostIndex(cityTier)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTierLabel(CityTier tier) {
    switch (tier) {
      case CityTier.tier1:
        return '一线城市';
      case CityTier.newTier1:
        return '新一线城市';
      case CityTier.tier2:
        return '二线城市';
      case CityTier.tier3:
        return '三线及以下';
    }
  }

  String _getCostIndex(CityTier tier) {
    switch (tier) {
      case CityTier.tier1:
        return '1.35';
      case CityTier.newTier1:
        return '1.15';
      case CityTier.tier2:
        return '0.95';
      case CityTier.tier3:
        return '0.75';
    }
  }
}

/// 城市特点卡片
class _CityCharacteristicsCard extends StatelessWidget {
  final CityTier cityTier;

  const _CityCharacteristicsCard({required this.cityTier});

  @override
  Widget build(BuildContext context) {
    final characteristics = _getCharacteristics(cityTier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 18, color: Theme.of(context).primaryColor),
              const SizedBox(width: 6),
              Text(
                '${_getTierLabel(cityTier)}预算特点',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: characteristics
                  .map((c) => _CharacteristicChip(
                        emoji: c['emoji']!,
                        label: c['label']!,
                        color: Color(int.parse(c['color']!)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getTierLabel(CityTier tier) {
    switch (tier) {
      case CityTier.tier1:
        return '一线城市';
      case CityTier.newTier1:
        return '新一线城市';
      case CityTier.tier2:
        return '二线城市';
      case CityTier.tier3:
        return '三线及以下';
    }
  }

  List<Map<String, String>> _getCharacteristics(CityTier tier) {
    switch (tier) {
      case CityTier.tier1:
        return [
          {'emoji': '🏠', 'label': '房租占比高', 'color': '0xFFE3F2FD'},
          {'emoji': '🚇', 'label': '通勤成本大', 'color': '0xFFFFF3E0'},
          {'emoji': '🍽️', 'label': '外卖价格高', 'color': '0xFFF3E5F5'},
          {'emoji': '💰', 'label': '收入水平高', 'color': '0xFFE8F5E9'},
        ];
      case CityTier.newTier1:
        return [
          {'emoji': '🏠', 'label': '房租较高', 'color': '0xFFE3F2FD'},
          {'emoji': '🚗', 'label': '交通便利', 'color': '0xFFFFF3E0'},
          {'emoji': '🍜', 'label': '餐饮适中', 'color': '0xFFF3E5F5'},
          {'emoji': '📈', 'label': '发展潜力大', 'color': '0xFFE8F5E9'},
        ];
      case CityTier.tier2:
        return [
          {'emoji': '🏠', 'label': '房租适中', 'color': '0xFFE3F2FD'},
          {'emoji': '🚌', 'label': '交通成本低', 'color': '0xFFFFF3E0'},
          {'emoji': '🍲', 'label': '餐饮实惠', 'color': '0xFFF3E5F5'},
          {'emoji': '😊', 'label': '生活舒适', 'color': '0xFFE8F5E9'},
        ];
      case CityTier.tier3:
        return [
          {'emoji': '🏠', 'label': '房租低廉', 'color': '0xFFE3F2FD'},
          {'emoji': '🚶', 'label': '出行简单', 'color': '0xFFFFF3E0'},
          {'emoji': '🍚', 'label': '餐饮便宜', 'color': '0xFFF3E5F5'},
          {'emoji': '🌿', 'label': '生活节奏慢', 'color': '0xFFE8F5E9'},
        ];
    }
  }
}

class _CharacteristicChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _CharacteristicChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 12,
          color: HSLColor.fromColor(color).withLightness(0.3).toColor(),
        ),
      ),
    );
  }
}

/// 推荐预算类目区域
class _RecommendedBudgetSection extends StatelessWidget {
  final CityTier cityTier;
  final String cityName;

  const _RecommendedBudgetSection({
    required this.cityTier,
    required this.cityName,
  });

  @override
  Widget build(BuildContext context) {
    final budgets = _getBudgets(cityTier);

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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '基于$cityName消费水平',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...budgets.map((b) => _BudgetCategoryCard(budget: b)),
        ],
      ),
    );
  }

  List<BudgetRecommendation> _getBudgets(CityTier tier) {
    switch (tier) {
      case CityTier.tier1:
        return [
          BudgetRecommendation(
            emoji: '🏠',
            name: '房租/房贷',
            amount: 4500,
            description: '上海平均租房 ¥4,200-5,500/月',
            tip: '占收入建议比例',
            tipValue: '30-35%',
            tipColor: Colors.orange,
            gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
          ),
          BudgetRecommendation(
            emoji: '🚇',
            name: '交通通勤',
            amount: 800,
            description: '地铁月票 + 偶尔打车',
            tip: '省钱建议',
            tipValue: '地铁日票¥18，比打车省60%',
            tipColor: Colors.green,
            gradientColors: [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
          ),
          BudgetRecommendation(
            emoji: '🍽️',
            name: '餐饮',
            amount: 2200,
            description: '上海外卖均价 ¥35-45/餐',
            tip: '省钱建议',
            tipValue: '食堂就餐可省40%+',
            tipColor: Colors.green,
            gradientColors: [const Color(0xFFFFD93D), const Color(0xFFFF9500)],
          ),
          BudgetRecommendation(
            emoji: '🛍️',
            name: '购物娱乐',
            amount: 1500,
            description: '商圈消费、电影、健身等',
            gradientColors: [const Color(0xFFA855F7), const Color(0xFF7C3AED)],
          ),
        ];
      case CityTier.newTier1:
        return [
          BudgetRecommendation(
            emoji: '🏠',
            name: '房租/房贷',
            amount: 3000,
            description: '新一线平均租房 ¥2,500-3,500/月',
            tip: '占收入建议比例',
            tipValue: '25-30%',
            tipColor: Colors.orange,
            gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
          ),
          BudgetRecommendation(
            emoji: '🚗',
            name: '交通通勤',
            amount: 500,
            description: '公交地铁 + 共享单车',
            gradientColors: [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
          ),
          BudgetRecommendation(
            emoji: '🍽️',
            name: '餐饮',
            amount: 1800,
            description: '外卖均价 ¥25-35/餐',
            gradientColors: [const Color(0xFFFFD93D), const Color(0xFFFF9500)],
          ),
          BudgetRecommendation(
            emoji: '🛍️',
            name: '购物娱乐',
            amount: 1200,
            description: '日常消费、娱乐活动',
            gradientColors: [const Color(0xFFA855F7), const Color(0xFF7C3AED)],
          ),
        ];
      case CityTier.tier2:
        return [
          BudgetRecommendation(
            emoji: '🏠',
            name: '房租/房贷',
            amount: 2000,
            description: '二线城市平均租房 ¥1,500-2,500/月',
            tip: '占收入建议比例',
            tipValue: '20-25%',
            tipColor: Colors.orange,
            gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
          ),
          BudgetRecommendation(
            emoji: '🚌',
            name: '交通通勤',
            amount: 300,
            description: '公交为主',
            gradientColors: [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
          ),
          BudgetRecommendation(
            emoji: '🍽️',
            name: '餐饮',
            amount: 1500,
            description: '外卖均价 ¥20-30/餐',
            gradientColors: [const Color(0xFFFFD93D), const Color(0xFFFF9500)],
          ),
          BudgetRecommendation(
            emoji: '🛍️',
            name: '购物娱乐',
            amount: 1000,
            description: '日常消费',
            gradientColors: [const Color(0xFFA855F7), const Color(0xFF7C3AED)],
          ),
        ];
      case CityTier.tier3:
        return [
          BudgetRecommendation(
            emoji: '🏠',
            name: '房租/房贷',
            amount: 1000,
            description: '三线城市平均租房 ¥800-1,500/月',
            tip: '占收入建议比例',
            tipValue: '15-20%',
            tipColor: Colors.orange,
            gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
          ),
          BudgetRecommendation(
            emoji: '🚶',
            name: '交通通勤',
            amount: 150,
            description: '步行/电动车为主',
            gradientColors: [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
          ),
          BudgetRecommendation(
            emoji: '🍽️',
            name: '餐饮',
            amount: 1000,
            description: '外卖均价 ¥15-25/餐',
            gradientColors: [const Color(0xFFFFD93D), const Color(0xFFFF9500)],
          ),
          BudgetRecommendation(
            emoji: '🛍️',
            name: '购物娱乐',
            amount: 600,
            description: '日常消费',
            gradientColors: [const Color(0xFFA855F7), const Color(0xFF7C3AED)],
          ),
        ];
    }
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  final BudgetRecommendation budget;

  const _BudgetCategoryCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: budget.gradientColors),
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
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      budget.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (budget.tip != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[200]!,
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
                        budget.tipColor == Colors.green
                            ? Icons.lightbulb
                            : Icons.analytics,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        budget.tip!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    budget.tipValue!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: budget.tipColor,
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
}

/// 城市对比卡片
class _CityComparisonCard extends StatelessWidget {
  final CityTier currentTier;

  const _CityComparisonCard({required this.currentTier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '不同城市预算对比',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _ComparisonItem(
                      label: '一线城市',
                      amount: 12000,
                      examples: '上海/北京',
                      color: Colors.red,
                      isSelected: currentTier == CityTier.tier1,
                    ),
                    _VerticalDivider(),
                    _ComparisonItem(
                      label: '新一线',
                      amount: 8000,
                      examples: '杭州/成都',
                      color: Colors.orange,
                      isSelected: currentTier == CityTier.newTier1,
                    ),
                    _VerticalDivider(),
                    _ComparisonItem(
                      label: '二线城市',
                      amount: 5500,
                      examples: '长沙/郑州',
                      color: Colors.blue,
                      isSelected: currentTier == CityTier.tier2,
                    ),
                    _VerticalDivider(),
                    _ComparisonItem(
                      label: '三线及以下',
                      amount: 3500,
                      examples: '其他',
                      color: Colors.green,
                      isSelected: currentTier == CityTier.tier3,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '以上数据基于各城市生活成本指数计算，仅供参考',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
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

class _ComparisonItem extends StatelessWidget {
  final String label;
  final double amount;
  final String examples;
  final Color color;
  final bool isSelected;

  const _ComparisonItem({
    required this.label,
    required this.amount,
    required this.examples,
    required this.color,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              )
            : null,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              examples,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey[300],
    );
  }
}

/// 预算推荐数据模型
class BudgetRecommendation {
  final String emoji;
  final String name;
  final double amount;
  final String description;
  final String? tip;
  final String? tipValue;
  final Color? tipColor;
  final List<Color> gradientColors;

  BudgetRecommendation({
    required this.emoji,
    required this.name,
    required this.amount,
    required this.description,
    this.tip,
    this.tipValue,
    this.tipColor,
    required this.gradientColors,
  });
}

/// 城市级别枚举
enum CityTier {
  tier1,     // 一线城市
  newTier1,  // 新一线城市
  tier2,     // 二线城市
  tier3,     // 三线及以下
}
