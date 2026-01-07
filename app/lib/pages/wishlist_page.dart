import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 消费规划/愿望清单页面
///
/// 对应原型设计 10.09 消费规划
/// 管理用户的愿望清单，计划性消费
class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  final List<WishItem> _wishlist = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  void _loadWishlist() {
    _wishlist.addAll([
      WishItem(
        id: '1',
        name: 'AirPods Pro 2',
        price: 1899,
        emoji: '🎧',
        addedDate: DateTime.now().subtract(const Duration(days: 15)),
        savedAmount: 1200,
        priority: WishPriority.high,
      ),
      WishItem(
        id: '2',
        name: '任天堂Switch',
        price: 2099,
        emoji: '🎮',
        addedDate: DateTime.now().subtract(const Duration(days: 30)),
        savedAmount: 800,
        priority: WishPriority.medium,
      ),
      WishItem(
        id: '3',
        name: '机械键盘',
        price: 599,
        emoji: '⌨️',
        addedDate: DateTime.now().subtract(const Duration(days: 7)),
        savedAmount: 0,
        priority: WishPriority.low,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final totalTarget = _wishlist.fold(0.0, (sum, w) => sum + w.price);
    final totalSaved = _wishlist.fold(0.0, (sum, w) => sum + w.savedAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('愿望清单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWishDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 总览卡片
          _OverviewCard(
            totalTarget: totalTarget,
            totalSaved: totalSaved,
            itemCount: _wishlist.length,
          ),

          // 愿望清单
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '我的愿望',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          ..._wishlist.map((w) => _WishItemCard(
                wish: w,
                onSave: () => _showSaveDialog(context, w),
                onBuy: () => _buyItem(w),
                onDelete: () => _deleteItem(w),
              )),

          // 理性消费提示
          _RationalConsumptionTip(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showAddWishDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加愿望'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '物品名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '价格',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('愿望已添加')),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showSaveDialog(BuildContext context, WishItem wish) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('为「${wish.name}」存钱'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '存入金额',
            prefixText: '¥ ',
            border: const OutlineInputBorder(),
            helperText: '还需 ¥${(wish.price - wish.savedAmount).toStringAsFixed(0)}',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已为「${wish.name}」存入 ¥${controller.text}')),
              );
            },
            child: const Text('确认存入'),
          ),
        ],
      ),
    );
  }

  void _buyItem(WishItem wish) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认购买'),
        content: Text('确定要购买「${wish.name}」吗？\n已存金额将用于支付。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('再想想'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _wishlist.remove(wish));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('恭喜购买「${wish.name}」！')),
              );
            },
            child: const Text('确认购买'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(WishItem wish) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除愿望'),
        content: Text('确定要删除「${wish.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _wishlist.remove(wish));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('愿望已删除')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 总览卡片
class _OverviewCard extends StatelessWidget {
  final double totalTarget;
  final double totalSaved;
  final int itemCount;

  const _OverviewCard({
    required this.totalTarget,
    required this.totalSaved,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalTarget > 0 ? totalSaved / totalTarget : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.pink[400]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '🎁',
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 8),
          Text(
            '$itemCount 个愿望等你实现',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    '目标总额',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '¥${totalTarget.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white30,
              ),
              Column(
                children: [
                  const Text(
                    '已存金额',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '¥${totalSaved.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '总体进度 ${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 愿望项卡片
class _WishItemCard extends StatelessWidget {
  final WishItem wish;
  final VoidCallback onSave;
  final VoidCallback onBuy;
  final VoidCallback onDelete;

  const _WishItemCard({
    required this.wish,
    required this.onSave,
    required this.onBuy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = wish.price > 0 ? wish.savedAmount / wish.price : 0.0;
    final remaining = wish.price - wish.savedAmount;
    final daysAdded = DateTime.now().difference(wish.addedDate).inDays;
    final canBuy = wish.savedAmount >= wish.price;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getPriorityColor(wish.priority).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(wish.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          wish.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PriorityBadge(priority: wish.priority),
                      ],
                    ),
                    Text(
                      '加入清单 $daysAdded 天',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${wish.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!canBuy)
                    Text(
                      '还差 ¥${remaining.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                canBuy ? Colors.green : _getPriorityColor(wish.priority),
              ),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 12),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSave,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('存钱'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: canBuy ? onBuy : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: canBuy ? Colors.green : null,
                  ),
                  child: Text(canBuy ? '购买' : '攒钱中'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(WishPriority priority) {
    switch (priority) {
      case WishPriority.high:
        return Colors.red;
      case WishPriority.medium:
        return Colors.orange;
      case WishPriority.low:
        return Colors.blue;
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  final WishPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (priority) {
      case WishPriority.high:
        label = '很想要';
        color = Colors.red;
        break;
      case WishPriority.medium:
        label = '想要';
        color = Colors.orange;
        break;
      case WishPriority.low:
        label = '可有可无';
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 理性消费提示
class _RationalConsumptionTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '理性消费小贴士',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '把想买的东西加入愿望清单，等待至少7天再决定是否购买，可以有效减少冲动消费。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
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

/// 愿望项数据模型
class WishItem {
  final String id;
  final String name;
  final double price;
  final String emoji;
  final DateTime addedDate;
  final double savedAmount;
  final WishPriority priority;

  WishItem({
    required this.id,
    required this.name,
    required this.price,
    required this.emoji,
    required this.addedDate,
    required this.savedAmount,
    required this.priority,
  });
}

enum WishPriority {
  high,
  medium,
  low,
}
