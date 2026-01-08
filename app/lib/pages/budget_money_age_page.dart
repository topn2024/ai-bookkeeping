import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 预算钱龄联动页面
///
/// 对应原型设计 3.07 预算钱龄联动
/// 展示预算分配对钱龄的影响预测
class BudgetMoneyAgePage extends ConsumerWidget {
  const BudgetMoneyAgePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预算与钱龄'),
      ),
      body: Column(
        children: [
          // 钱龄影响预测卡片
          _MoneyAgeImpactCard(
            currentAge: 42,
            predictedAge: 48,
            improvement: 6,
          ),

          // 分配方案对钱龄的影响
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '分配方案对钱龄的影响',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // 储蓄类 - 正面影响
                _ImpactItem(
                  name: '应急金储备',
                  icon: Icons.savings,
                  iconColor: Colors.green,
                  type: '储蓄',
                  amount: 3000,
                  impact: 8,
                  isPositive: true,
                  hint: '储蓄相当于延迟消费，会显著提升钱龄',
                ),

                // 固定支出 - 中性
                _ImpactItem(
                  name: '房租',
                  icon: Icons.home,
                  iconColor: Colors.grey,
                  type: '固定',
                  amount: 4000,
                  impact: 0,
                  isPositive: null,
                  hint: null,
                ),

                // 弹性支出 - 负面影响
                _ImpactItem(
                  name: '餐饮',
                  icon: Icons.restaurant,
                  iconColor: Colors.orange,
                  type: '弹性',
                  amount: 2500,
                  impact: -2,
                  isPositive: false,
                  hint: null,
                ),

                const SizedBox(height: 16),

                // 优化建议
                _OptimizationSuggestion(
                  suggestion: '将储蓄比例从20%提升到25%（+¥750），可额外提升钱龄3天，达到51天（优秀）',
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _BottomActionBar(
        onApply: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('优化方案已应用')),
          );
        },
      ),
    );
  }
}

/// 钱龄影响预测卡片
class _MoneyAgeImpactCard extends StatelessWidget {
  final int currentAge;
  final int predictedAge;
  final int improvement;

  const _MoneyAgeImpactCard({
    required this.currentAge,
    required this.predictedAge,
    required this.improvement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '本次分配预计提升钱龄',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    '$currentAge天',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Icon(
                  Icons.trending_up,
                  size: 40,
                  color: Colors.green[600],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$predictedAge天',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                  Text(
                    '+$improvement天',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
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
}

/// 影响项
class _ImpactItem extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color iconColor;
  final String type;
  final double amount;
  final int impact;
  final bool? isPositive;
  final String? hint;

  const _ImpactItem({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.type,
    required this.amount,
    required this.impact,
    required this.isPositive,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor, iconColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$type ¥${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _ImpactBadge(impact: impact, isPositive: isPositive),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
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

class _ImpactBadge extends StatelessWidget {
  final int impact;
  final bool? isPositive;

  const _ImpactBadge({required this.impact, this.isPositive});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    if (isPositive == true) {
      bgColor = Colors.green[100]!;
      textColor = Colors.green[700]!;
      text = '+$impact天';
    } else if (isPositive == false) {
      bgColor = Colors.red[100]!;
      textColor = Colors.red[700]!;
      text = '$impact天';
    } else {
      bgColor = Colors.grey[200]!;
      textColor = Colors.grey[600]!;
      text = '$impact天';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

/// 优化建议
class _OptimizationSuggestion extends StatelessWidget {
  final String suggestion;

  const _OptimizationSuggestion({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb, color: Colors.orange[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '提升建议',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
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

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  final VoidCallback onApply;

  const _BottomActionBar({required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: onApply,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: const Text('应用优化方案'),
        ),
      ),
    );
  }
}
