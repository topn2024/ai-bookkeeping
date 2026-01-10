import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/simple_mode_scaffold.dart';
import '../services/tts_service.dart';
import '../services/simple_budget_service.dart';

/// 超简易预算页面
///
/// 智能默认预算，无需复杂配置
/// 只问一个问题："一个月能花多少钱？"
class UltraSimpleBudgetPage extends ConsumerWidget {
  const UltraSimpleBudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetService = ref.watch(simpleBudgetServiceProvider);

    return FutureBuilder<SimpleBudgetStatus>(
      future: budgetService.getBudgetStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SimpleModeScaffold(
            title: '预算',
            body: Center(
              child: CircularProgressIndicator(strokeWidth: 8),
            ),
          );
        }

        final status = snapshot.data!;
        return _buildBudgetPage(context, ref, status);
      },
    );
  }

  Widget _buildBudgetPage(
    BuildContext context,
    WidgetRef ref,
    SimpleBudgetStatus status,
  ) {
    final monthlyBudget = status.budget;
    final spent = status.spent;
    final remaining = status.remaining;
    final progress = status.progress;

    final tts = TTSService();

    return SimpleModeScaffold(
      title: '预算',
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // 本月预算
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.blue, width: 4),
              ),
              child: Column(
                children: [
                  const Text(
                    '本月预算',
                    style: TextStyle(fontSize: 32, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¥${monthlyBudget.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 超大进度条
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(40),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.9 ? Colors.red : Colors.green,
                  ),
                  minHeight: 80,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 已花费和剩余
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '已花费',
                    spent,
                    Colors.red,
                    Icons.remove_circle,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildStatCard(
                    '剩余',
                    remaining,
                    Colors.green,
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // 设置预算按钮
            SizedBox(
              width: double.infinity,
              height: 100,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  tts.speak('设置预算');
                  _showSetBudgetDialog(context, ref, status.budget);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit, size: 48, color: Colors.white),
                    const SizedBox(width: 16),
                    const Text(
                      '设置预算',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 3),
      ),
      child: Column(
        children: [
          Icon(icon, size: 60, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontSize: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.toStringAsFixed(0)}',
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

  void _showSetBudgetDialog(BuildContext context, WidgetRef ref, double currentBudget) {
    showDialog(
      context: context,
      builder: (context) => _SetBudgetDialog(
        currentBudget: currentBudget,
        onSave: (amount) async {
          final service = ref.read(simpleBudgetServiceProvider);
          await service.setSimpleBudget(amount);
        },
      ),
    );
  }
}

/// 设置预算对话框
///
/// 只问一个问题："一个月能花多少钱？"
/// 提供智能建议值
class _SetBudgetDialog extends StatefulWidget {
  final double currentBudget;
  final Function(double) onSave;

  const _SetBudgetDialog({
    required this.currentBudget,
    required this.onSave,
  });

  @override
  State<_SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends State<_SetBudgetDialog> {
  String _amount = '';
  final TTSService _tts = TTSService();

  @override
  void initState() {
    super.initState();
    // 预填充当前预算
    _amount = widget.currentBudget.toInt().toString();
    _tts.speak('一个月能花多少钱？');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '一个月能花多少钱？',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '建议：${widget.currentBudget.toInt()}元',
              style: const TextStyle(fontSize: 20, color: Colors.grey),
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

            // 数字键盘
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
                _buildActionButton(
                  '清空',
                  Icons.clear,
                  Colors.orange,
                  () => setState(() => _amount = ''),
                ),
                _buildActionButton(
                  '删除',
                  Icons.backspace,
                  Colors.red,
                  () {
                    if (_amount.isNotEmpty) {
                      setState(() => _amount = _amount.substring(0, _amount.length - 1));
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
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
                      onPressed: () async {
                        final amount = double.tryParse(_amount);
                        if (amount != null && amount > 0) {
                          await widget.onSave(amount);
                          _tts.speak('预算已设置为${amount.toInt()}元');
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
        setState(() => _amount += number);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Icon(icon, size: 40, color: Colors.white),
    );
  }
}
