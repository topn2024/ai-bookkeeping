import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';

/// 6.20 语音智能客服页面
/// 提供全方位的语音交互帮助，解答用户关于记账、预算、钱龄等问题
class VoiceAssistantPage extends ConsumerStatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  ConsumerState<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends ConsumerState<VoiceAssistantPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _messages.add({
      'type': 'assistant',
      'content': '您好！我是您的智能记账助手 🤖\n\n我可以帮您：\n• 快速记账\n• 查询消费统计\n• 分析财务状况\n• 提供省钱建议\n\n有什么我可以帮您的吗？',
      'time': DateTime.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.voiceAssistant,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.online,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          // 功能快捷入口
          _buildQuickActions(l10n),
          // 输入区域
          _buildInputArea(l10n),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'],
                    style: TextStyle(
                      color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  // 如果有附加组件
                  if (message['widget'] != null) ...[
                    const SizedBox(height: 12),
                    message['widget'],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations l10n) {
    final actions = [
      {
        'icon': Icons.add_circle_outline,
        'label': l10n.quickBookkeep,
        'color': AppTheme.primaryColor,
      },
      {
        'icon': Icons.pie_chart_outline,
        'label': l10n.viewStats,
        'color': AppTheme.successColor,
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'label': l10n.budgetQuery,
        'color': AppTheme.warningColor,
      },
      {
        'icon': Icons.lightbulb_outline,
        'label': l10n.getSuggestion,
        'color': AppTheme.infoColor,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: actions.map((action) {
            return Container(
              margin: const EdgeInsets.only(right: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleQuickAction(action['label'] as String),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          action['icon'] as IconData,
                          size: 18,
                          color: action['color'] as Color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          action['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: action['color'] as Color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 文字输入
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.askAnything,
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 语音按钮
            GestureDetector(
              onTapDown: (_) => _startRecording(),
              onTapUp: (_) => _stopRecording(),
              onTapCancel: () => _stopRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isRecording ? 56 : 48,
                height: _isRecording ? 56 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isRecording
                        ? [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.8)]
                        : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(_isRecording ? 28 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? AppTheme.errorColor : AppTheme.primaryColor)
                          .withValues(alpha: 0.4),
                      blurRadius: _isRecording ? 16 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: _isRecording ? 26 : 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickAction(String action) {
    final l10n = AppLocalizations.of(context);
    _addUserMessage(action);

    Future.delayed(const Duration(milliseconds: 800), () {
      String response;
      if (action == l10n.quickBookkeep) {
        response = '好的，请告诉我您要记录的消费内容。\n\n比如："午餐花了35块"或者"打车去公司20元"';
      } else if (action == l10n.viewStats) {
        response = _generateStatsResponse();
      } else if (action == l10n.budgetQuery) {
        response = _generateBudgetResponse();
      } else if (action == l10n.getSuggestion) {
        response = _generateSuggestionResponse();
      } else {
        response = '好的，我来帮您处理这个问题。';
      }

      _addAssistantMessage(response);
    });
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;

    _addUserMessage(text);

    // 模拟AI回复
    Future.delayed(const Duration(milliseconds: 1000), () {
      _addAssistantMessage(_generateResponse(text));
    });
  }

  String _generateResponse(String input) {
    // 简单的关键词匹配 - 使用真实数据
    if (input.contains('多少') || input.contains('花了')) {
      return _generateSpendingResponse();
    }

    if (input.contains('预算') || input.contains('还剩')) {
      return _generateBudgetResponse();
    }

    if (input.contains('帮') || input.contains('记')) {
      return '好的，请告诉我消费金额和类别，我帮您记录。\n\n比如："午餐35块"';
    }

    return '好的，我已经收到您的问题。\n\n请问您是想要：\n1. 记一笔账\n2. 查看消费统计\n3. 获取省钱建议\n\n请告诉我您的需求~';
  }

  /// 生成今日支出回复 - 使用真实数据
  String _generateSpendingResponse() {
    final transactions = ref.read(transactionProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 过滤今日支出
    final todayExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == today.year &&
        t.date.month == today.month &&
        t.date.day == today.day).toList();

    if (todayExpenses.isEmpty) {
      return '让我帮您查一下...\n\n今天您还没有消费记录 🎉\n\n继续保持节俭的习惯！';
    }

    // 计算总支出
    final totalSpent = todayExpenses.fold<double>(0, (sum, t) => sum + t.amount);

    // 按分类汇总
    final categoryTotals = <String, double>{};
    for (final t in todayExpenses) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // 按金额排序，取前3个分类
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(3);

    // 生成分类明细
    final categoryDetails = topCategories.map((entry) {
      final category = DefaultCategories.findById(entry.key);
      final emoji = _getCategoryEmoji(entry.key);
      final name = category?.localizedName ?? entry.key;
      return '$emoji $name ¥${entry.value.toStringAsFixed(2)}';
    }).join('\n');

    return '让我帮您查一下...\n\n今天您一共花了 ¥${totalSpent.toStringAsFixed(2)}\n\n包括：\n$categoryDetails';
  }

  /// 生成预算回复 - 使用真实数据
  String _generateBudgetResponse() {
    final budgets = ref.read(budgetProvider);
    final monthlyExpense = ref.read(monthlyExpenseProvider);

    // 计算总预算
    final totalBudget = budgets
        .where((b) => b.isEnabled)
        .fold<double>(0, (sum, b) => sum + b.amount);

    if (totalBudget == 0) {
      return '您还没有设置预算 📝\n\n建议您设置月度预算，更好地管理消费哦！';
    }

    final remaining = totalBudget - monthlyExpense;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day + 1;
    final dailyAllowance = remaining > 0 ? remaining / remainingDays : 0;

    String advice;
    if (remaining <= 0) {
      advice = '本月预算已超支，建议控制消费 ⚠️';
    } else if (remaining < totalBudget * 0.2) {
      advice = '预算剩余不多，请注意控制开支 💡';
    } else {
      advice = '按照目前的消费速度，到月底预算充足 ✨';
    }

    return '本月预算还剩 ¥${remaining.toStringAsFixed(2)}\n\n每日可用约 ¥${dailyAllowance.toStringAsFixed(0)}\n\n$advice';
  }

  /// 生成本月统计回复 - 使用真实数据
  String _generateStatsResponse() {
    final transactions = ref.read(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 过滤本月交易
    final monthlyTransactions = transactions.where((t) =>
        t.date.isAfter(monthStart.subtract(const Duration(days: 1)))).toList();

    final expenses = monthlyTransactions.where((t) => t.type == TransactionType.expense);
    final incomes = monthlyTransactions.where((t) => t.type == TransactionType.income);

    final totalExpense = expenses.fold<double>(0, (sum, t) => sum + t.amount);
    final totalIncome = incomes.fold<double>(0, (sum, t) => sum + t.amount);

    if (totalExpense == 0 && totalIncome == 0) {
      return '📊 本月消费统计\n\n本月暂无交易记录\n\n开始记录您的第一笔账吧！';
    }

    // 按分类汇总支出
    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // 按金额排序，取前5个分类
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5);

    // 生成分类明细
    final categoryDetails = topCategories.map((entry) {
      final category = DefaultCategories.findById(entry.key);
      final emoji = _getCategoryEmoji(entry.key);
      final name = category?.localizedName ?? entry.key;
      final percent = totalExpense > 0 ? (entry.value / totalExpense * 100).round() : 0;
      return '$emoji $name $percent%';
    }).join('\n');

    return '📊 本月消费统计\n\n总支出：¥${totalExpense.toStringAsFixed(2)}\n总收入：¥${totalIncome.toStringAsFixed(2)}\n\n支出分布：\n$categoryDetails';
  }

  /// 生成建议回复 - 基于真实消费数据
  String _generateSuggestionResponse() {
    final transactions = ref.read(transactionProvider);
    final budgets = ref.read(budgetProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 过滤本月支出
    final monthlyExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(monthStart.subtract(const Duration(days: 1)))).toList();

    if (monthlyExpenses.isEmpty) {
      return '💡 您本月还没有消费记录\n\n建议：\n1. 开始记录日常消费\n2. 设置月度预算目标\n3. 养成记账习惯';
    }

    final suggestions = <String>[];

    // 按分类汇总
    final categoryTotals = <String, double>{};
    for (final t in monthlyExpenses) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // 找出支出最高的分类
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedCategories.isNotEmpty) {
      final topCategory = sortedCategories.first;
      final category = DefaultCategories.findById(topCategory.key);
      final name = category?.localizedName ?? topCategory.key;
      suggestions.add('$name支出较高（¥${topCategory.value.toStringAsFixed(0)}），可以关注一下');
    }

    // 检查预算使用情况
    for (final budget in budgets.where((b) => b.isEnabled)) {
      final categoryId = budget.categoryId;
      if (categoryId == null) continue;

      final spent = categoryTotals[categoryId] ?? 0;
      final percent = budget.amount > 0 ? spent / budget.amount : 0;
      if (percent > 0.8) {
        final category = DefaultCategories.findById(categoryId);
        final name = category?.localizedName ?? categoryId;
        suggestions.add('$name预算已用${(percent * 100).round()}%，建议控制');
      }
    }

    // 通用建议
    if (suggestions.length < 3) {
      suggestions.add('坚持记账，了解消费习惯');
    }

    final numberedSuggestions = suggestions.asMap().entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    return '💡 根据您的消费习惯，我有以下建议：\n\n$numberedSuggestions';
  }

  /// 获取分类对应的emoji
  String _getCategoryEmoji(String categoryId) {
    const emojiMap = {
      'food': '🍜',
      'transport': '🚗',
      'shopping': '🛒',
      'entertainment': '🎬',
      'housing': '🏠',
      'medical': '🏥',
      'education': '📚',
      'travel': '✈️',
      'utilities': '💡',
      'clothing': '👔',
    };
    return emojiMap[categoryId] ?? '📝';
  }

  void _addUserMessage(String content) {
    setState(() {
      _messages.add({
        'type': 'user',
        'content': content,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _addAssistantMessage(String content, {Widget? widget}) {
    setState(() {
      _messages.add({
        'type': 'assistant',
        'content': content,
        'time': DateTime.now(),
        'widget': widget,
      });
    });
    _scrollToBottom();
  }

  void _startRecording() {
    setState(() => _isRecording = true);
  }

  void _stopRecording() {
    if (!_isRecording) return;
    setState(() => _isRecording = false);

    // 在模拟器上提示用户输入文字
    _addAssistantMessage('语音识别需要真机环境。\n\n请在下方输入框中输入您的问题，或使用快捷问题按钮。');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('对话历史'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/voice-history');
              },
            ),
            // TODO: Implement these pages
            // ListTile(
            //   leading: const Icon(Icons.edit_note),
            //   title: const Text('编辑记录'),
            //   subtitle: const Text('查看语音编辑历史'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const VoiceEditRecordPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.undo),
            //   title: const Text('撤销操作'),
            //   subtitle: const Text('语音撤销最近的操作'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const VoiceUndoPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.timer),
            //   title: const Text('记录时间统计'),
            //   subtitle: const Text('查看语音记账效率'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const RecordingTimeStatsPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.gesture),
            //   title: const Text('手写输入'),
            //   subtitle: const Text('切换到手写记账'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const HandwritingRecognitionPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.input),
            //   title: const Text('多模态输入'),
            //   subtitle: const Text('语音/手写/拍照/键盘'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const MultimodalInputPage()),
            //     );
            //   },
            // ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清空对话'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _messages.clear();
                  _initializeChat();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('助手设置'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
