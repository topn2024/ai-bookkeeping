import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 异常交易详情页面
///
/// 对应原型设计 14.05 异常交易详情
/// 展示异常交易的详细信息和处理选项
class AnomalyTransactionDetailPage extends ConsumerWidget {
  final String? transactionId;

  const AnomalyTransactionDetailPage({
    super.key,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[50],
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.red[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '异常交易',
          style: TextStyle(color: Colors.red[800]),
        ),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // 异常标记
          _AnomalyWarningCard(),

          // 交易详情
          _TransactionDetailCard(),

          // AI分析
          _AIAnalysisCard(),

          // 操作按钮
          _ActionButtons(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 异常警告卡片
class _AnomalyWarningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning,
              size: 32,
              color: Colors.red[800],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '检测到金额异常',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '该笔消费超过日均消费的 5.2 倍',
            style: TextStyle(
              fontSize: 11,
              color: Colors.red[900],
            ),
          ),
        ],
      ),
    );
  }
}

/// 交易详情卡片
class _TransactionDetailCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // 商户信息
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🛍️', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apple Store',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '购物 · 今天 14:30',
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

          // 金额
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '¥8,999',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '支付宝',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // 统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: '日均消费', value: '¥173'),
              _StatItem(label: '本月累计', value: '¥5,280'),
              _StatItem(
                label: '异常倍数',
                value: '5.2x',
                valueColor: Colors.red[800],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// AI分析卡片
class _AIAnalysisCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI 分析',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '检测到这是一笔大额数码产品消费，可能是购买电子设备。'
            '建议确认是否为计划内消费，可标记为"计划性大额支出"避免后续误报。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮
class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已标记为计划消费')),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('确认正常，标记为计划消费'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已标记为可疑交易')),
              );
            },
            icon: const Icon(Icons.flag),
            label: const Text('标记为可疑，需要核实'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }
}
