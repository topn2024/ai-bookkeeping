import 'package:flutter/material.dart';

/// 冲动消费确认弹窗
///
/// 对应原型设计 10.04 冲动消费确认
/// 当用户进行大额非必要消费时弹出确认
class ImpulseSpendingDialog extends StatefulWidget {
  final String itemName;
  final double amount;
  final String category;

  const ImpulseSpendingDialog({
    super.key,
    required this.itemName,
    required this.amount,
    required this.category,
  });

  static Future<ImpulseSpendingResult?> show(
    BuildContext context, {
    required String itemName,
    required double amount,
    required String category,
  }) {
    return showModalBottomSheet<ImpulseSpendingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImpulseSpendingDialog(
        itemName: itemName,
        amount: amount,
        category: category,
      ),
    );
  }

  @override
  State<ImpulseSpendingDialog> createState() => _ImpulseSpendingDialogState();
}

class _ImpulseSpendingDialogState extends State<ImpulseSpendingDialog> {
  int _countdown = 10;
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _countdown > 0) {
        setState(() => _countdown--);
        if (_countdown > 0) {
          _startCountdown();
        } else {
          setState(() => _canProceed = true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动条
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 警告图标
          Container(
            margin: const EdgeInsets.only(top: 20),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_circle_filled,
              color: Colors.orange,
              size: 40,
            ),
          ),

          const SizedBox(height: 16),

          // 标题
          const Text(
            '冷静一下',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // 说明
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '这笔消费属于非必要支出，建议您考虑清楚',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 20),

          // 消费详情卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🛍️', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.category,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '¥${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 思考问题
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                      '问问自己',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _QuestionItem(text: '这是"想要"还是"需要"？'),
                _QuestionItem(text: '一周后还会想买吗？'),
                _QuestionItem(text: '这笔钱有更好的用途吗？'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 倒计时提示
          if (!_canProceed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '请冷静思考 $_countdown 秒',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 操作按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, ImpulseSpendingResult.cancel),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    child: const Text('放弃购买'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed
                        ? () => Navigator.pop(
                            context, ImpulseSpendingResult.proceed)
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor:
                          _canProceed ? Colors.orange : Colors.grey[300],
                    ),
                    child: Text(_canProceed ? '仍然购买' : '等待中...'),
                  ),
                ),
              ],
            ),
          ),

          // 加入心愿单选项
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.pop(context, ImpulseSpendingResult.addToWishlist),
              icon: const Icon(Icons.favorite_border, size: 20),
              label: const Text('加入心愿单，以后再买'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionItem extends StatelessWidget {
  final String text;

  const _QuestionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: Colors.orange[700]),
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

enum ImpulseSpendingResult {
  cancel,
  proceed,
  addToWishlist,
}
