import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 预算健康状态页面
///
/// 对应原型设计 3.06 状态警告
/// 展示预算健康指数、超支警告、即将用完和健康状态的小金库
class BudgetHealthPage extends ConsumerWidget {
  const BudgetHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预算健康状态'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 整体健康评分
          _HealthScoreCard(score: 72),

          const SizedBox(height: 16),

          // 超支状态
          _StatusSection(
            title: '超支警告',
            icon: Icons.error,
            color: Colors.red,
            backgroundColor: Colors.red[50]!,
            items: [
              _VaultStatusItem(
                name: '餐饮',
                icon: Icons.restaurant,
                iconColor: Colors.red,
                status: '超支 ¥320',
                statusColor: Colors.red,
                amount: '-¥320',
                budget: '预算 ¥2,000',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 即将用完
          _StatusSection(
            title: '即将用完',
            icon: Icons.warning,
            color: Colors.orange,
            backgroundColor: Colors.orange[50]!,
            items: [
              _VaultStatusItem(
                name: '娱乐',
                icon: Icons.local_cafe,
                iconColor: Colors.orange,
                status: '仅剩 8%',
                statusColor: Colors.orange,
                amount: '¥80',
                budget: '预算 ¥1,000',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 健康状态
          _HealthySection(
            vaults: [
              _HealthyVault(name: '房租', progress: 1.0),
              _HealthyVault(name: '交通', progress: 0.65),
              _HealthyVault(name: '储蓄', progress: 0.50),
            ],
          ),

          const SizedBox(height: 16),

          // AI建议
          _AISuggestionCard(
            suggestion: '建议从"交通"小金库调拨¥200到"餐饮"，或减少本月餐饮外出次数。',
          ),
        ],
      ),
    );
  }
}

/// 健康评分卡片
class _HealthScoreCard extends StatelessWidget {
  final int score;

  const _HealthScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    Color scoreColor;

    if (score >= 80) {
      scoreColor = Colors.green;
    } else if (score >= 60) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[50]!,
            Colors.orange[100]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),
          Text(
            '预算健康指数',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '2个小金库需要关注',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态分区
class _StatusSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final List<_VaultStatusItem> items;

  const _StatusSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildItemCard(_VaultStatusItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [item.iconColor, item.iconColor.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: item.statusColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.amount,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: item.statusColor,
                ),
              ),
              Text(
                item.budget,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VaultStatusItem {
  final String name;
  final IconData icon;
  final Color iconColor;
  final String status;
  final Color statusColor;
  final String amount;
  final String budget;

  _VaultStatusItem({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.status,
    required this.statusColor,
    required this.amount,
    required this.budget,
  });
}

/// 健康状态分区
class _HealthySection extends StatelessWidget {
  final List<_HealthyVault> vaults;

  const _HealthySection({required this.vaults});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '健康',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${vaults.length}个小金库',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: vaults.map((vault) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        vault.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(vault.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HealthyVault {
  final String name;
  final double progress;

  _HealthyVault({required this.name, required this.progress});
}

/// AI建议卡片
class _AISuggestionCard extends StatelessWidget {
  final String suggestion;

  const _AISuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue[400],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '调整建议',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
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
