import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 消费趋势预测页面
///
/// 对应原型设计 14.03 消费趋势预测
/// 展示本月预计支出和分类预测
class SpendingPredictionPage extends ConsumerWidget {
  const SpendingPredictionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('趋势预测'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          // 本月预测卡片
          _MonthlyPredictionCard(),

          // 分类预测
          _CategoryPredictionSection(),

          // 预测说明
          _PredictionExplanation(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 本月预测卡片
class _MonthlyPredictionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple[400]!, Colors.blue[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本月预计支出',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '¥8,650',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '±¥320',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '已支出 ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Text(
                '¥5,280',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '预测剩余 ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Text(
                '¥3,370',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 0.61,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '进度 61%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '剩余12天',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分类预测区域
class _CategoryPredictionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final predictions = [
      _PredictionData(
        emoji: '🍜',
        category: '餐饮',
        predicted: 2400,
        spent: 1800,
        budget: 2500,
        trend: -8,
      ),
      _PredictionData(
        emoji: '🚗',
        category: '交通',
        predicted: 850,
        spent: 680,
        budget: 800,
        trend: 15,
      ),
      _PredictionData(
        emoji: '🛒',
        category: '购物',
        predicted: 1200,
        spent: 720,
        budget: 1500,
        trend: -22,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分类预测',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...predictions.map((p) => _CategoryPredictionCard(data: p)),
        ],
      ),
    );
  }
}

class _PredictionData {
  final String emoji;
  final String category;
  final double predicted;
  final double spent;
  final double budget;
  final int trend; // 正数为上升，负数为下降

  _PredictionData({
    required this.emoji,
    required this.category,
    required this.predicted,
    required this.spent,
    required this.budget,
    required this.trend,
  });
}

class _CategoryPredictionCard extends StatelessWidget {
  final _PredictionData data;

  const _CategoryPredictionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = data.spent / data.budget;
    final isOverBudget = progress > 0.8;
    final progressColor = isOverBudget
        ? Colors.red
        : (data.trend < 0 ? Colors.green : Colors.orange);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              Text(data.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.category,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${data.predicted.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${data.trend > 0 ? '↑' : '↓'}${data.trend.abs()}% 较上月',
                    style: TextStyle(
                      fontSize: 11,
                      color: data.trend > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已消费 ¥${data.spent.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '预算 ¥${data.budget.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
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

/// 预测说明
class _PredictionExplanation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '基于过去6个月消费数据 + 周期性因素分析',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
