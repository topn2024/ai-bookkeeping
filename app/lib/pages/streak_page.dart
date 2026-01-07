import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 连续打卡页面
///
/// 对应原型设计 10.07 连续打卡
/// 展示用户连续记账天数和打卡激励
class StreakPage extends ConsumerWidget {
  const StreakPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 模拟数据
    const currentStreak = 23;
    const longestStreak = 45;
    const totalDays = 156;

    return Scaffold(
      appBar: AppBar(
        title: const Text('连续打卡'),
      ),
      body: ListView(
        children: [
          // 连续天数卡片
          _StreakCard(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
          ),

          // 本周打卡日历
          _WeekCalendar(),

          // 统计数据
          _StatsSection(
            totalDays: totalDays,
            longestStreak: longestStreak,
            currentStreak: currentStreak,
          ),

          // 打卡奖励
          _RewardSection(currentStreak: currentStreak),

          // 激励语
          _MotivationCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 连续天数卡片
class _StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const _StreakCard({
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.red[400]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            '$currentStreak',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '连续记账天数',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '历史最高 $longestStreak 天',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 本周打卡日历
class _WeekCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    // 模拟打卡数据：前几天都打卡了
    final checkedDays = {0, 1, 2, 3, 4}; // 周一到周五已打卡

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            '本周打卡',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isToday = index == today.weekday - 1;
              final isChecked = checkedDays.contains(index);
              final isFuture = index > today.weekday - 1;

              return Column(
                children: [
                  Text(
                    weekDays[index],
                    style: TextStyle(
                      fontSize: 12,
                      color: isToday ? Colors.orange : Colors.grey[600],
                      fontWeight: isToday ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isChecked
                          ? Colors.orange
                          : isToday
                              ? Colors.orange[100]
                              : Colors.grey[100],
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isChecked
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : isFuture
                              ? null
                              : isToday
                                  ? const Icon(Icons.edit,
                                      color: Colors.orange, size: 16)
                                  : null,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 统计数据区域
class _StatsSection extends StatelessWidget {
  final int totalDays;
  final int longestStreak;
  final int currentStreak;

  const _StatsSection({
    required this.totalDays,
    required this.longestStreak,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.calendar_today,
            label: '累计记账',
            value: '$totalDays天',
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: Icons.emoji_events,
            label: '最长连续',
            value: '$longestStreak天',
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: Icons.trending_up,
            label: '本月记账',
            value: '${currentStreak}天',
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 打卡奖励区域
class _RewardSection extends StatelessWidget {
  final int currentStreak;

  const _RewardSection({required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    final rewards = [
      _Reward(days: 7, name: '坚持一周', icon: '🌟', achieved: currentStreak >= 7),
      _Reward(days: 14, name: '两周达人', icon: '🏅', achieved: currentStreak >= 14),
      _Reward(days: 30, name: '月度冠军', icon: '🏆', achieved: currentStreak >= 30),
      _Reward(days: 60, name: '习惯养成', icon: '💎', achieved: currentStreak >= 60),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '打卡奖励',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: rewards.map((r) {
              final isNext = !r.achieved &&
                  rewards
                      .where((x) => !x.achieved)
                      .firstOrNull
                      ?.days ==
                      r.days;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: r.achieved
                        ? Colors.amber[50]
                        : isNext
                            ? Colors.blue[50]
                            : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: isNext
                        ? Border.all(color: Colors.blue, width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        r.icon,
                        style: TextStyle(
                          fontSize: 24,
                          color: r.achieved ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: r.achieved ? Colors.amber[800] : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${r.days}天',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
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

class _Reward {
  final int days;
  final String name;
  final String icon;
  final bool achieved;

  _Reward({
    required this.days,
    required this.name,
    required this.icon,
    required this.achieved,
  });
}

/// 激励语卡片
class _MotivationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[100]!, Colors.blue[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('💪', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '再坚持7天就能解锁「月度冠军」！',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '好习惯需要21天养成，你已经成功一半了！',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
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
