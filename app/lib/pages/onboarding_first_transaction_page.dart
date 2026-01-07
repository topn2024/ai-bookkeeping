import 'package:flutter/material.dart';

/// 首笔记账引导页
///
/// 对应原型设计 10.16 首笔记账引导
/// 引导新用户完成第一笔记账
class OnboardingFirstTransactionPage extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const OnboardingFirstTransactionPage({
    super.key,
    required this.onComplete,
    this.onSkip,
  });

  @override
  State<OnboardingFirstTransactionPage> createState() =>
      _OnboardingFirstTransactionPageState();
}

class _OnboardingFirstTransactionPageState
    extends State<OnboardingFirstTransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedCategory;

  final List<_QuickCategory> _categories = [
    _QuickCategory(emoji: '🍽️', name: '餐饮', color: Colors.orange),
    _QuickCategory(emoji: '🚗', name: '交通', color: Colors.blue),
    _QuickCategory(emoji: '🛒', name: '购物', color: Colors.pink),
    _QuickCategory(emoji: '🎮', name: '娱乐', color: Colors.purple),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _amountController.text.isNotEmpty && _selectedCategory != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 进度条
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        value: 1.0,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '3/3',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  const Text(
                    '记下你的第一笔账',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '试试看，记账就是这么简单',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 记账卡片
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 引导箭头
                    Icon(
                      Icons.arrow_downward,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(height: 8),

                    // 记账表单卡片
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 金额输入
                          Text(
                            '消费金额',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '¥',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '0.00',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 分类选择
                          Text(
                            '选择分类',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((category) {
                              final isSelected =
                                  _selectedCategory == category.name;
                              return GestureDetector(
                                onTap: () {
                                  setState(
                                      () => _selectedCategory = category.name);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        category.emoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        category.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                          // 备注
                          TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              hintText: '添加备注（选填）',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 提示文字
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.green[600],
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '输入金额，选择分类即可完成',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 保存按钮
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _canSave ? _saveTransaction : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '保存我的第一笔账',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTransaction() {
    // 这里可以保存交易记录
    // 暂时直接调用完成回调
    widget.onComplete();
  }
}

class _QuickCategory {
  final String emoji;
  final String name;
  final Color color;

  _QuickCategory({
    required this.emoji,
    required this.name,
    required this.color,
  });
}
