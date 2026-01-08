import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 交易卡片 Widget 测试
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== Mock 交易模型 ====================

enum TransactionType { income, expense, transfer }

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String description;
  final DateTime date;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });
}

// ==================== 交易卡片组件 ====================

/// 交易卡片组件
class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDate;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 分类图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getCategoryColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(),
                  color: _getCategoryColor(),
                  key: const Key('category_icon'),
                ),
              ),
              const SizedBox(width: 12),
              // 交易信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      key: const Key('category_text'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      key: const Key('description_text'),
                    ),
                    if (showDate) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(transaction.date),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                        key: const Key('date_text'),
                      ),
                    ],
                  ],
                ),
              ),
              // 金额
              Text(
                '${_getAmountPrefix()}¥${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _getAmountColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                key: const Key('amount_text'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (transaction.category) {
      case '餐饮':
        return Icons.restaurant;
      case '交通':
        return Icons.directions_car;
      case '购物':
        return Icons.shopping_bag;
      case '工资':
        return Icons.account_balance_wallet;
      case '转账':
        return Icons.swap_horiz;
      default:
        return Icons.attach_money;
    }
  }

  Color _getCategoryColor() {
    switch (transaction.type) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.transfer:
        return Colors.blue;
    }
  }

  Color _getAmountColor() {
    switch (transaction.type) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.transfer:
        return Colors.blue;
    }
  }

  String _getAmountPrefix() {
    switch (transaction.type) {
      case TransactionType.income:
        return '+';
      case TransactionType.expense:
        return '-';
      case TransactionType.transfer:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}

// ==================== 交易列表组件 ====================

/// 交易列表组件
class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(Transaction)? onItemTap;
  final Function(Transaction)? onItemLongPress;
  final bool isLoading;
  final String emptyMessage;

  const TransactionList({
    super.key,
    required this.transactions,
    this.onItemTap,
    this.onItemLongPress,
    this.isLoading = false,
    this.emptyMessage = '暂无交易记录',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('loading_indicator'),
        ),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey[400],
              key: const Key('empty_icon'),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              key: const Key('empty_message'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const Key('transaction_list'),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return TransactionCard(
          key: Key('transaction_${transaction.id}'),
          transaction: transaction,
          onTap: onItemTap != null ? () => onItemTap!(transaction) : null,
          onLongPress: onItemLongPress != null
              ? () => onItemLongPress!(transaction)
              : null,
        );
      },
    );
  }
}

// ==================== 测试用例 ====================

void main() {
  group('TransactionCard Widget 测试', () {
    testWidgets('显示支出交易信息', (tester) async {
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.expense,
        amount: 128.50,
        category: '餐饮',
        description: '和朋友聚餐',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(transaction: transaction),
        ),
      ));

      // 验证分类显示
      expect(find.text('餐饮'), findsOneWidget);
      // 验证描述显示
      expect(find.text('和朋友聚餐'), findsOneWidget);
      // 验证金额显示（支出带负号）
      expect(find.text('-¥128.50'), findsOneWidget);
      // 验证图标显示
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('显示收入交易信息', (tester) async {
      final transaction = Transaction(
        id: 'tx_2',
        type: TransactionType.income,
        amount: 5000.00,
        category: '工资',
        description: '11月工资',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(transaction: transaction),
        ),
      ));

      // 验证金额显示（收入带正号）
      expect(find.text('+¥5000.00'), findsOneWidget);
      expect(find.text('工资'), findsOneWidget);
    });

    testWidgets('显示转账交易信息', (tester) async {
      final transaction = Transaction(
        id: 'tx_3',
        type: TransactionType.transfer,
        amount: 1000.00,
        category: '转账',
        description: '转入储蓄账户',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(transaction: transaction),
        ),
      ));

      // 验证转账金额显示（无符号）
      expect(find.text('¥1000.00'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('点击事件触发', (tester) async {
      bool tapped = false;
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.expense,
        amount: 100,
        category: '餐饮',
        description: '午餐',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(
            transaction: transaction,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(TransactionCard));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('长按事件触发', (tester) async {
      bool longPressed = false;
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.expense,
        amount: 100,
        category: '餐饮',
        description: '午餐',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(
            transaction: transaction,
            onLongPress: () => longPressed = true,
          ),
        ),
      ));

      await tester.longPress(find.byType(TransactionCard));
      await tester.pump();

      expect(longPressed, true);
    });

    testWidgets('隐藏日期显示', (tester) async {
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.expense,
        amount: 100,
        category: '餐饮',
        description: '午餐',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(
            transaction: transaction,
            showDate: false,
          ),
        ),
      ));

      expect(find.byKey(const Key('date_text')), findsNothing);
    });

    testWidgets('显示今天日期格式', (tester) async {
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.expense,
        amount: 100,
        category: '餐饮',
        description: '午餐',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(transaction: transaction),
        ),
      ));

      expect(find.textContaining('今天'), findsOneWidget);
    });
  });

  group('TransactionList Widget 测试', () {
    testWidgets('显示交易列表', (tester) async {
      final transactions = [
        Transaction(
          id: 'tx_1',
          type: TransactionType.expense,
          amount: 100,
          category: '餐饮',
          description: '早餐',
          date: DateTime.now(),
        ),
        Transaction(
          id: 'tx_2',
          type: TransactionType.expense,
          amount: 200,
          category: '交通',
          description: '打车',
          date: DateTime.now(),
        ),
        Transaction(
          id: 'tx_3',
          type: TransactionType.income,
          amount: 5000,
          category: '工资',
          description: '工资',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionList(transactions: transactions),
        ),
      ));

      expect(find.byType(TransactionCard), findsNWidgets(3));
      expect(find.text('早餐'), findsOneWidget);
      expect(find.text('打车'), findsOneWidget);
      expect(find.text('工资'), findsNWidgets(2)); // 分类和描述
    });

    testWidgets('显示空状态', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TransactionList(
            transactions: [],
            emptyMessage: '暂无交易记录',
          ),
        ),
      ));

      expect(find.text('暂无交易记录'), findsOneWidget);
      expect(find.byKey(const Key('empty_icon')), findsOneWidget);
    });

    testWidgets('显示自定义空状态消息', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TransactionList(
            transactions: [],
            emptyMessage: '本月还没有支出哦',
          ),
        ),
      ));

      expect(find.text('本月还没有支出哦'), findsOneWidget);
    });

    testWidgets('显示加载状态', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TransactionList(
            transactions: [],
            isLoading: true,
          ),
        ),
      ));

      expect(find.byKey(const Key('loading_indicator')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('列表项点击回调', (tester) async {
      Transaction? tappedTransaction;
      final transactions = [
        Transaction(
          id: 'tx_1',
          type: TransactionType.expense,
          amount: 100,
          category: '餐饮',
          description: '午餐',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionList(
            transactions: transactions,
            onItemTap: (tx) => tappedTransaction = tx,
          ),
        ),
      ));

      await tester.tap(find.byType(TransactionCard));
      await tester.pump();

      expect(tappedTransaction, isNotNull);
      expect(tappedTransaction!.id, 'tx_1');
    });

    testWidgets('列表滚动', (tester) async {
      final transactions = List.generate(
        20,
        (index) => Transaction(
          id: 'tx_$index',
          type: TransactionType.expense,
          amount: 100 + index.toDouble(),
          category: '餐饮',
          description: '交易 $index',
          date: DateTime.now(),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionList(transactions: transactions),
        ),
      ));

      // 验证可以滚动
      expect(find.text('交易 0'), findsOneWidget);

      // 滚动到底部
      await tester.drag(
        find.byType(ListView),
        const Offset(0, -1000),
      );
      await tester.pump();

      // 底部的项目应该可见
      expect(find.text('交易 19'), findsOneWidget);
    });
  });

  group('交易金额颜色测试', () {
    testWidgets('支出显示红色', (tester) async {
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.expense,
        amount: 100,
        category: '餐饮',
        description: '午餐',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(transaction: transaction),
        ),
      ));

      final amountText = tester.widget<Text>(find.byKey(const Key('amount_text')));
      expect(amountText.style?.color, Colors.red);
    });

    testWidgets('收入显示绿色', (tester) async {
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.income,
        amount: 5000,
        category: '工资',
        description: '工资',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(transaction: transaction),
        ),
      ));

      final amountText = tester.widget<Text>(find.byKey(const Key('amount_text')));
      expect(amountText.style?.color, Colors.green);
    });

    testWidgets('转账显示蓝色', (tester) async {
      final transaction = Transaction(
        id: 'tx_1',
        type: TransactionType.transfer,
        amount: 1000,
        category: '转账',
        description: '转账',
        date: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionCard(transaction: transaction),
        ),
      ));

      final amountText = tester.widget<Text>(find.byKey(const Key('amount_text')));
      expect(amountText.style?.color, Colors.blue);
    });
  });
}
