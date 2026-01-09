import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/budget_provider.dart';

/// 钱龄进阶页面
///
/// 对应原型设计 10.06 钱龄进阶
/// 展示用户钱龄等级和进阶路径
class MoneyAgeProgressPage extends ConsumerWidget {
  const MoneyAgeProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moneyAge = ref.watch(moneyAgeProvider);
    final currentDays = moneyAge.days;
    final currentLevel = _calculateLevel(currentDays);
    final nextLevelDays = _getNextLevelDays(currentLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('钱龄进阶'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 当前等级卡片
          _CurrentLevelCard(
            currentDays: currentDays,
            currentLevel: currentLevel,
            nextLevelDays: nextLevelDays,
          ),

          // 等级进度
          _LevelProgressSection(
            currentLevel: currentLevel,
            currentDays: currentDays,
          ),

          // 成就徽章
          _AchievementSection(),

          // 提升建议
          _ImprovementSuggestionCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('什么是钱龄？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('钱龄是指您的资金平均持有天数。'),
            SizedBox(height: 12),
            Text('钱龄越高，说明您的资金流动性越好，财务状况越健康。'),
            SizedBox(height: 12),
            Text('提升钱龄的方法：'),
            Text('• 减少冲动消费'),
            Text('• 增加长期储蓄'),
            Text('• 合理规划支出'),
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

/// 当前等级卡片
class _CurrentLevelCard extends StatelessWidget {
  final int currentDays;
  final int currentLevel;
  final int nextLevelDays;

  const _CurrentLevelCard({
    required this.currentDays,
    required this.currentLevel,
    required this.nextLevelDays,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentDays / nextLevelDays;
    final levelInfo = _getLevelInfo(currentLevel);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: levelInfo.gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // 等级图标
          Text(
            levelInfo.icon,
            style: const TextStyle(fontSize: 48),
          ),

          const SizedBox(height: 12),

          // 等级名称
          Text(
            levelInfo.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // 当前钱龄
          Text(
            '当前钱龄 $currentDays 天',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 20),

          // 进度条
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lv.$currentLevel',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Lv.${currentLevel + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '再坚持 ${nextLevelDays - currentDays} 天升级',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _LevelInfo _getLevelInfo(int level) {
    switch (level) {
      case 1:
        return _LevelInfo(
          name: '钱龄新手',
          icon: '🌱',
          gradientColors: [Colors.grey[400]!, Colors.grey[300]!],
        );
      case 2:
        return _LevelInfo(
          name: '钱龄学徒',
          icon: '🌿',
          gradientColors: [Colors.green[400]!, Colors.green[300]!],
        );
      case 3:
        return _LevelInfo(
          name: '钱龄达人',
          icon: '🌳',
          gradientColors: [Colors.blue[400]!, Colors.blue[300]!],
        );
      case 4:
        return _LevelInfo(
          name: '钱龄专家',
          icon: '💎',
          gradientColors: [Colors.purple[400]!, Colors.purple[300]!],
        );
      case 5:
        return _LevelInfo(
          name: '钱龄大师',
          icon: '👑',
          gradientColors: [Colors.orange[400]!, Colors.orange[300]!],
        );
      default:
        return _LevelInfo(
          name: '钱龄新手',
          icon: '🌱',
          gradientColors: [Colors.grey[400]!, Colors.grey[300]!],
        );
    }
  }
}

class _LevelInfo {
  final String name;
  final String icon;
  final List<Color> gradientColors;

  _LevelInfo({
    required this.name,
    required this.icon,
    required this.gradientColors,
  });
}

/// 等级进度区域
class _LevelProgressSection extends StatelessWidget {
  final int currentLevel;
  final int currentDays;

  const _LevelProgressSection({
    required this.currentLevel,
    required this.currentDays,
  });

  @override
  Widget build(BuildContext context) {
    final levels = [
      _Level(level: 1, name: '新手', days: 7, icon: '🌱'),
      _Level(level: 2, name: '学徒', days: 21, icon: '🌿'),
      _Level(level: 3, name: '达人', days: 42, icon: '🌳'),
      _Level(level: 4, name: '专家', days: 60, icon: '💎'),
      _Level(level: 5, name: '大师', days: 90, icon: '👑'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '等级进度',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...levels.map((l) {
            final achieved = currentLevel >= l.level;
            final current = currentLevel == l.level;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: current
                    ? Colors.blue[50]
                    : achieved
                        ? Colors.green[50]
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: current
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Text(l.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lv.${l.level} ${l.name}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: achieved ? Colors.black : Colors.grey,
                          ),
                        ),
                        Text(
                          '钱龄 ≥ ${l.days}天',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (achieved)
                    const Icon(Icons.check_circle, color: Colors.green),
                  if (current)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '当前',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Level {
  final int level;
  final String name;
  final int days;
  final String icon;

  _Level({
    required this.level,
    required this.name,
    required this.days,
    required this.icon,
  });
}

/// 成就徽章区域
class _AchievementSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final achievements = [
      _Achievement(icon: '🎯', name: '首次突破7天', achieved: true),
      _Achievement(icon: '🔥', name: '连续30天记账', achieved: true),
      _Achievement(icon: '💰', name: '存款超1万', achieved: true),
      _Achievement(icon: '📈', name: '钱龄60天', achieved: false),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '成就徽章',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: achievements.map((a) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: a.achieved ? Colors.amber[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        a.icon,
                        style: TextStyle(
                          fontSize: 24,
                          color: a.achieved ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: a.achieved ? Colors.black : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
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

class _Achievement {
  final String icon;
  final String name;
  final bool achieved;

  _Achievement({
    required this.icon,
    required this.name,
    required this.achieved,
  });
}

/// 提升建议卡片
class _ImprovementSuggestionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
                '提升钱龄的小技巧',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TipItem(text: '设置每周固定存款日'),
          _TipItem(text: '减少不必要的订阅服务'),
          _TipItem(text: '使用冲动消费冷静期'),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;

  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// 根据钱龄天数计算等级
int _calculateLevel(int days) {
  if (days >= 90) return 5;
  if (days >= 60) return 4;
  if (days >= 30) return 3;
  if (days >= 14) return 2;
  return 1;
}

/// 获取下一等级所需天数
int _getNextLevelDays(int currentLevel) {
  const levelDays = [14, 30, 60, 90, 120];
  if (currentLevel >= levelDays.length) return levelDays.last;
  return levelDays[currentLevel];
}
