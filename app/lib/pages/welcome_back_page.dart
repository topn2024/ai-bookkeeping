import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 欢迎回来页面
///
/// 对应原型设计 10.11 欢迎回来
/// 用户中断后回归时的激励页面
class WelcomeBackPage extends ConsumerWidget {
  final int daysAway;
  final int previousStreak;

  const WelcomeBackPage({
    super.key,
    required this.daysAway,
    this.previousStreak = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // 欢迎图标
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👋', style: TextStyle(fontSize: 60)),
                ),
              ),

              const SizedBox(height: 32),

              // 欢迎文字
              const Text(
                '欢迎回来！',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '我们想念你了，已经 $daysAway 天没见了',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 32),

              // 状态卡片
              _StatusCard(
                daysAway: daysAway,
                previousStreak: previousStreak,
              ),

              const SizedBox(height: 24),

              // 激励语
              _MotivationCard(),

              const Spacer(),

              // 开始按钮
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  '重新开始记账',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('稍后再说'),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 状态卡片
class _StatusCard extends StatelessWidget {
  final int daysAway;
  final int previousStreak;

  const _StatusCard({
    required this.daysAway,
    required this.previousStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatusItem(
                  icon: Icons.calendar_today,
                  iconColor: Colors.blue,
                  label: '离开天数',
                  value: '$daysAway 天',
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _StatusItem(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  label: '之前连续',
                  value: '$previousStreak 天',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    previousStreak > 0
                        ? '你曾经连续记账 $previousStreak 天，我们相信你能做到！'
                        : '每个人都有重新开始的机会，今天就是新的起点！',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green[800],
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
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatusItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// 激励语卡片
class _MotivationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final motivations = [
      '「千里之行，始于足下」',
      '「不要因为走得太慢而放弃，只要在走就是进步」',
      '「重新开始需要勇气，你已经迈出了第一步」',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[100]!, Colors.blue[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('💪', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              motivations[DateTime.now().day % motivations.length],
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
