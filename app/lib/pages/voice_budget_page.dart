import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';

/// 6.14 语音预算查询页面
class VoiceBudgetPage extends ConsumerStatefulWidget {
  const VoiceBudgetPage({super.key});

  @override
  ConsumerState<VoiceBudgetPage> createState() => _VoiceBudgetPageState();
}

class _VoiceBudgetPageState extends ConsumerState<VoiceBudgetPage> {
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEBF3FF), Color(0xFFFAFBFC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部栏
              _buildTopBar(l10n),
              // 对话区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // 用户问题
                      _buildUserBubble('我的预算还剩多少？'),
                      const SizedBox(height: 12),
                      // AI回复
                      _buildAssistantBubble(),
                    ],
                  ),
                ),
              ),
              // 快捷问题
              _buildQuickQuestions(l10n),
              // 输入区域
              _buildInputArea(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            l10n.budgetQuery,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String content) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble() {
    final budgets = ref.watch(budgetProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    final transactions = ref.watch(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 计算总预算（如果用户设置了预算，使用预算；否则使用收入）
    final enabledBudgets = budgets.where((b) => b.isEnabled).toList();
    final totalBudget = enabledBudgets.fold<double>(0, (sum, b) => sum + b.amount);
    final hasBudget = totalBudget > 0;

    // 使用收入作为基准计算剩余金额，确保与首页一致
    final remaining = monthlyIncome - monthlyExpense;
    final usagePercent = monthlyIncome > 0 ? monthlyExpense / monthlyIncome : 0.0;

    // 计算剩余天数
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day + 1;

    // 按分类计算支出
    final monthlyTransactions = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(monthStart.subtract(const Duration(days: 1)))).toList();

    final categorySpent = <String, double>{};
    for (final t in monthlyTransactions) {
      categorySpent[t.category] = (categorySpent[t.category] ?? 0) + t.amount;
    }

    // 生成分类预算数据
    final categoryBudgets = <_CategoryBudgetData>[];
    String? warningMessage;
    double maxOverspentPercent = 0;
    String? maxOverspentCategory;

    for (final budget in enabledBudgets.take(4)) {
      final categoryId = budget.categoryId;
      if (categoryId == null) continue; // Skip total budget

      final spent = categorySpent[categoryId] ?? 0;
      final budgetRemaining = budget.amount - spent;
      final percent = budget.amount > 0 ? spent / budget.amount : 0.0;

      final category = DefaultCategories.findById(categoryId);
      final emoji = _getCategoryEmoji(categoryId);
      final name = category?.localizedName ?? categoryId;

      Color color;
      if (percent > 0.8) {
        color = AppTheme.errorColor;
        if (percent > maxOverspentPercent) {
          maxOverspentPercent = percent;
          maxOverspentCategory = name;
        }
      } else if (percent > 0.6) {
        color = AppTheme.warningColor;
      } else {
        color = AppTheme.successColor;
      }

      categoryBudgets.add(_CategoryBudgetData(
        name: '$emoji $name',
        total: budget.amount,
        remaining: budgetRemaining > 0 ? budgetRemaining : 0,
        color: color,
      ));
    }

    if (maxOverspentCategory != null) {
      warningMessage = '$maxOverspentCategory预算已用${(maxOverspentPercent * 100).round()}%，建议本月减少相关支出';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '本月预算概况',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 预算总览卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasBudget ? '总预算' : '本月收入',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '¥${(hasBudget ? totalBudget : monthlyIncome).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '本月结余',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '¥${remaining > 0 ? remaining.toStringAsFixed(2) : '0.00'}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: remaining > 0 ? AppTheme.successColor : AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 进度条
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: usagePercent.clamp(0.0, 1.0),
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              usagePercent > 0.8 ? AppTheme.errorColor : AppTheme.primaryColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              hasBudget
                                  ? '已使用 ${(usagePercent * 100).toStringAsFixed(1)}%'
                                  : '已支出 ¥${monthlyExpense.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            Text(
                              '还剩 $remainingDays 天',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            if (categoryBudgets.isNotEmpty) ...[
              const SizedBox(height: 16),
              // 分类预算
              const Text(
                '各分类剩余',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ...categoryBudgets.map((data) => _buildCategoryBudget(
                    data.name,
                    data.total,
                    data.remaining,
                    data.color,
                  )),
            ],
            if (warningMessage != null) ...[
              const SizedBox(height: 16),
              // AI建议
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.warningColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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

  Widget _buildCategoryBudget(
    String name,
    double total,
    double remaining,
    Color color,
  ) {
    final used = total - remaining;
    final percentage = used / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              name,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppTheme.surfaceVariantColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              '¥${remaining.toInt()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions(AppLocalizations l10n) {
    final questions = [
      '餐饮还能花多少？',
      '这个月超支了吗？',
      '设置预算提醒',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.youCanAsk,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questions.map((q) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('快捷提问功能开发中')),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      q,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                l10n.continueAsking,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _isRecording = !_isRecording;
              });
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF5A85DD),
                    AppTheme.primaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class for category budget data
class _CategoryBudgetData {
  final String name;
  final double total;
  final double remaining;
  final Color color;

  _CategoryBudgetData({
    required this.name,
    required this.total,
    required this.remaining,
    required this.color,
  });
}
