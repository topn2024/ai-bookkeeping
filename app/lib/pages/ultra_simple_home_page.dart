import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_mode_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../services/tts_service.dart';
import 'ultra_simple_settings_page.dart';
import 'ultra_simple_budget_page.dart';

/// 超简易模式主页
///
/// 设计原则：
/// 1. 只有3个大按钮
/// 2. 每个按钮都有图标+颜色+语音
/// 3. 一键完成操作
/// 4. 立即反馈
class UltraSimpleHomePage extends ConsumerStatefulWidget {
  const UltraSimpleHomePage({super.key});

  @override
  ConsumerState<UltraSimpleHomePage> createState() => _UltraSimpleHomePageState();
}

class _UltraSimpleHomePageState extends ConsumerState<UltraSimpleHomePage> {
  final TTSService _tts = TTSService();
  String _currentAmount = '';

  @override
  void initState() {
    super.initState();
    // 启动时语音欢迎
    _tts.speak('欢迎使用记账');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = (screenHeight - 200) / 3; // 3个按钮平分屏幕

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        toolbarHeight: 80,
        title: const Text(
          'AI记账',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart, size: 44, color: Colors.white),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _tts.speak('预算');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UltraSimpleBudgetPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 44, color: Colors.white),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _tts.speak('设置');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UltraSimpleSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：当前输入的金额（超大显示）
            Container(
              height: 100,
              alignment: Alignment.center,
              child: _currentAmount.isEmpty
                  ? const Text(
                      '按下面的按钮',
                      style: TextStyle(fontSize: 32, color: Colors.grey),
                    )
                  : Text(
                      '¥$_currentAmount',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
            ),

            // 三个超大按钮
            Expanded(
              child: Column(
                children: [
                  // 花钱按钮（红色）
                  _buildMegaButton(
                    height: buttonHeight,
                    color: const Color(0xFFFF5252),
                    icon: Icons.remove_circle,
                    text: '花钱',
                    onTap: () => _handleExpense(),
                  ),

                  const Divider(height: 1, thickness: 2),

                  // 收钱按钮（绿色）
                  _buildMegaButton(
                    height: buttonHeight,
                    color: const Color(0xFF4CAF50),
                    icon: Icons.add_circle,
                    text: '收钱',
                    onTap: () => _handleIncome(),
                  ),

                  const Divider(height: 1, thickness: 2),

                  // 查看按钮（蓝色）
                  _buildMegaButton(
                    height: buttonHeight,
                    color: const Color(0xFF2196F3),
                    icon: Icons.visibility,
                    text: '查看',
                    onTap: () => _handleView(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMegaButton({
    required double height,
    required Color color,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          // 触觉反馈
          HapticFeedback.heavyImpact();
          // 语音反馈
          _tts.speak(text);
          onTap();
        },
        child: Container(
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 120, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理花钱
  void _handleExpense() async {
    // 显示数字键盘
    final amount = await _showNumberPad(context, '花了多少钱？');
    if (amount != null && amount > 0) {
      // 立即保存
      await _saveTransaction(TransactionType.expense, amount);

      // 大大的成功提示
      if (mounted) {
        await _showSuccessDialog('花钱 ¥$amount', '已记录');
      }
    }
  }

  /// 处理收钱
  void _handleIncome() async {
    final amount = await _showNumberPad(context, '收了多少钱？');
    if (amount != null && amount > 0) {
      await _saveTransaction(TransactionType.income, amount);

      if (mounted) {
        await _showSuccessDialog('收钱 ¥$amount', '已记录');
      }
    }
  }

  /// 处理查看
  void _handleView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UltraSimpleViewPage(),
      ),
    );
  }

  /// 保存交易
  Future<void> _saveTransaction(TransactionType type, double amount) async {
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      amount: amount,
      category: 'other',
      note: type == TransactionType.expense ? '花钱' : '收钱',
      date: DateTime.now(),
      accountId: 'cash',
      source: TransactionSource.manual,
    );

    await ref.read(transactionProvider.notifier).addTransaction(transaction);
  }

  /// 显示数字键盘
  Future<double?> _showNumberPad(BuildContext context, String title) async {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NumberPadDialog(title: title),
    );
  }

  /// 显示成功对话框
  Future<void> _showSuccessDialog(String title, String subtitle) async {
    // 语音播报
    await _tts.speak('$title，$subtitle');

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 超大的对勾
              const Icon(
                Icons.check_circle,
                size: 150,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              // 超大的关闭按钮
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '好的',
                    style: TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 超大数字键盘对话框
class _NumberPadDialog extends StatefulWidget {
  final String title;

  const _NumberPadDialog({required this.title});

  @override
  State<_NumberPadDialog> createState() => _NumberPadDialogState();
}

class _NumberPadDialogState extends State<_NumberPadDialog> {
  String _amount = '';
  final TTSService _tts = TTSService();

  @override
  void initState() {
    super.initState();
    _tts.speak(widget.title);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              widget.title,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 显示当前输入
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _amount.isEmpty ? '0' : _amount,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 数字键盘（3x4布局）
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                ...List.generate(9, (index) {
                  final number = index + 1;
                  return _buildNumberButton(number.toString());
                }),
                _buildNumberButton('0'),
                _buildNumberButton('.'),
                _buildActionButton(
                  '删除',
                  Icons.backspace,
                  Colors.orange,
                  () {
                    if (_amount.isNotEmpty) {
                      setState(() {
                        _amount = _amount.substring(0, _amount.length - 1);
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 确认和取消按钮
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(fontSize: 28, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(_amount);
                        Navigator.pop(context, amount);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(fontSize: 28, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        _tts.speak(number);
        setState(() {
          _amount += number;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        number,
        style: const TextStyle(fontSize: 40, color: Colors.white),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        _tts.speak(text);
        onPressed();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Icon(icon, size: 40, color: Colors.white),
    );
  }
}

/// 超简易查看页面
class UltraSimpleViewPage extends ConsumerWidget {
  const UltraSimpleViewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final today = DateTime.now();
    final todayTransactions = transactions.where((t) {
      return t.date.year == today.year &&
          t.date.month == today.month &&
          t.date.day == today.day;
    }).toList();

    // 计算今日总计
    double todayExpense = 0;
    double todayIncome = 0;
    for (final t in todayTransactions) {
      if (t.type == TransactionType.expense) {
        todayExpense += t.amount;
      } else if (t.type == TransactionType.income) {
        todayIncome += t.amount;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 40, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '今天的记录',
          style: TextStyle(fontSize: 32, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // 今日汇总（超大显示）
          Container(
            padding: const EdgeInsets.all(32),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCard(
                      '花钱',
                      todayExpense,
                      Colors.red,
                      Icons.remove_circle,
                    ),
                    _buildSummaryCard(
                      '收钱',
                      todayIncome,
                      Colors.green,
                      Icons.add_circle,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 记录列表（超大字体）
          Expanded(
            child: todayTransactions.isEmpty
                ? const Center(
                    child: Text(
                      '今天还没有记录',
                      style: TextStyle(fontSize: 32, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: todayTransactions.length,
                    itemBuilder: (context, index) {
                      final t = todayTransactions[index];
                      return _buildTransactionItem(t);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 3),
      ),
      child: Column(
        children: [
          Icon(icon, size: 60, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction t) {
    final isExpense = t.type == TransactionType.expense;
    final color = isExpense ? Colors.red : Colors.green;
    final icon = isExpense ? Icons.remove_circle : Icons.add_circle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 60, color: color),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpense ? '花钱' : '收钱',
                  style: TextStyle(fontSize: 28, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(t.date),
                  style: const TextStyle(fontSize: 20, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '¥${t.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
