import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.30 批量训练AI页面
/// 快速批量校正AI分类，加速准确率提升
class BatchAITrainingPage extends ConsumerStatefulWidget {
  const BatchAITrainingPage({super.key});

  @override
  ConsumerState<BatchAITrainingPage> createState() => _BatchAITrainingPageState();
}

class _BatchAITrainingPageState extends ConsumerState<BatchAITrainingPage> {
  final List<_TrainingItem> _pendingItems = [
    _TrainingItem(
      id: '1',
      merchant: '美团外卖',
      amount: 45.00,
      suggestedCategory: '餐饮',
      suggestedIcon: Icons.restaurant,
      confidence: 0.85,
    ),
    _TrainingItem(
      id: '2',
      merchant: '滴滴出行',
      amount: 28.50,
      suggestedCategory: '交通',
      suggestedIcon: Icons.directions_car,
      confidence: 0.92,
    ),
    _TrainingItem(
      id: '3',
      merchant: '京东商城',
      amount: 199.00,
      suggestedCategory: '购物',
      suggestedIcon: Icons.shopping_bag,
      confidence: 0.78,
    ),
    _TrainingItem(
      id: '4',
      merchant: '星巴克',
      amount: 38.00,
      suggestedCategory: '餐饮',
      suggestedIcon: Icons.local_cafe,
      confidence: 0.95,
    ),
    _TrainingItem(
      id: '5',
      merchant: '中国移动',
      amount: 128.00,
      suggestedCategory: '通讯',
      suggestedIcon: Icons.phone_android,
      confidence: 0.88,
    ),
  ];

  int _currentIndex = 0;
  int _confirmedCount = 0;
  int _correctedCount = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n?.batchTrainAI ?? '快速训练AI',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _currentIndex < _pendingItems.length
          ? _buildTrainingContent()
          : _buildCompletionContent(),
    );
  }

  Widget _buildTrainingContent() {
    return Column(
      children: [
        _buildInfoCard(),
        _buildProgressIndicator(),
        Expanded(child: _buildCurrentItem()),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.psychology, color: AppColors.success, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '批量确认分类',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  '快速校正可大幅提升AI准确率',
                  style: TextStyle(fontSize: 12, color: Color(0xFF388E3C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${_pendingItems.length}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  Text(' $_confirmedCount', style: TextStyle(fontSize: 12, color: AppColors.success)),
                  const SizedBox(width: 12),
                  Icon(Icons.edit, size: 14, color: AppColors.primary),
                  Text(' $_correctedCount', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _pendingItems.length,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentItem() {
    final item = _pendingItems[_currentIndex];
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¥${item.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(item.merchant, style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.suggestedIcon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI建议分类', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(item.suggestedCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(item.confidence),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(item.confidence * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return AppColors.success;
    if (confidence >= 0.8) return AppColors.primary;
    return const Color(0xFFFF9800);
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showCategoryPicker,
                icon: const Icon(Icons.edit),
                label: const Text('修正'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _confirmCategory,
                icon: const Icon(Icons.check),
                label: const Text('确认正确'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(0, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionContent() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration, size: 40, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            const Text('训练完成！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('AI准确率预计提升 2%', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildResultStat('$_confirmedCount', '确认', AppColors.success),
                const SizedBox(width: 32),
                _buildResultStat('$_correctedCount', '修正', AppColors.primary),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(200, 48),
              ),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  void _confirmCategory() {
    setState(() {
      _confirmedCount++;
      _currentIndex++;
    });
  }

  void _showCategoryPicker() {
    final categories = [
      {'name': '餐饮', 'icon': Icons.restaurant},
      {'name': '交通', 'icon': Icons.directions_car},
      {'name': '购物', 'icon': Icons.shopping_bag},
      {'name': '娱乐', 'icon': Icons.movie},
      {'name': '通讯', 'icon': Icons.phone_android},
      {'name': '居住', 'icon': Icons.home},
      {'name': '医疗', 'icon': Icons.local_hospital},
      {'name': '教育', 'icon': Icons.school},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择正确分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: categories.map((cat) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _correctedCount++;
                      _currentIndex++;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat['icon'] as IconData, color: AppColors.primary),
                        const SizedBox(height: 4),
                        Text(cat['name'] as String, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TrainingItem {
  final String id;
  final String merchant;
  final double amount;
  final String suggestedCategory;
  final IconData suggestedIcon;
  final double confidence;

  _TrainingItem({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.suggestedCategory,
    required this.suggestedIcon,
    required this.confidence,
  });
}
