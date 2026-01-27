import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';
import '../services/voice/query/query_models.dart';
import '../services/voice/query/query_executor.dart';
import '../services/voice/query/query_result_router.dart';
import '../services/voice/query/query_complexity_analyzer.dart';
import '../services/voice/smart_intent_recognizer.dart';
import '../widgets/voice/lightweight_query_card.dart';
import '../widgets/voice/interactive_query_chart.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

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

  // 查询系统组件
  late final QueryExecutor _queryExecutor;
  late final QueryResultRouter _queryRouter;
  late final SmartIntentRecognizer _intentRecognizer;

  @override
  void initState() {
    super.initState();
    _initializeQuerySystem();
    _initializeChat();
  }

  void _initializeQuerySystem() {
    final databaseService = sl<IDatabaseService>();
    _queryExecutor = QueryExecutor(databaseService: databaseService);
    _queryRouter = QueryResultRouter(
      analyzer: QueryComplexityAnalyzer(),
    );
    _intentRecognizer = SmartIntentRecognizer();
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
    Future.delayed(const Duration(milliseconds: 1000), () async {
      // 检查是否是查询类型，需要显示卡片或图表
      Widget? widget;
      String response;

      // 尝试执行真实查询
      final queryResult = await _tryExecuteQuery(text);

      if (queryResult != null) {
        // 使用真实查询结果
        response = queryResult['response'] as String;
        widget = queryResult['widget'] as Widget?;
      }
      // Level 2: 轻量卡片（演示数据作为兜底）
      else if (text.contains('占比') || text.contains('百分比')) {
        response = '餐饮最多，占48.7%，总计2180元';
        widget = LightweightQueryCard(
          cardData: QueryCardData(
            primaryValue: 2180.0,
            percentage: 0.487,
            cardType: CardType.percentage,
          ),
          onDismiss: () {},
        );
      } else if (text.contains('预算') && (text.contains('使用') || text.contains('进度'))) {
        response = '本月预算已使用87.2%，还剩320元';
        widget = LightweightQueryCard(
          cardData: QueryCardData(
            primaryValue: 2180.0,
            secondaryValue: 2500.0,
            progress: 0.872,
            cardType: CardType.progress,
          ),
          onDismiss: () {},
        );
      } else if (text.contains('对比') || text.contains('比较')) {
        response = '本月支出8400元，比上月减少14.3%';
        widget = LightweightQueryCard(
          cardData: QueryCardData(
            primaryValue: 8400.0,
            comparison: ComparisonData(
              currentValue: 8400.0,
              previousValue: 9800.0,
              changePercentage: -14.3,
              isIncrease: false,
            ),
            cardType: CardType.comparison,
          ),
          onDismiss: () {},
        );
      }
      // Level 3: 交互图表（演示数据作为兜底）
      else if (text.contains('趋势') || text.contains('变化')) {
        response = '最近三个月消费趋势：整体比较平稳，2月最高9500元，3月最低7500元';
        widget = InteractiveQueryChart(
          chartData: QueryChartData(
            chartType: ChartType.line,
            title: '最近三个月消费趋势',
            dataPoints: [
              DataPoint(label: '1月', value: 8000.0),
              DataPoint(label: '2月', value: 9500.0),
              DataPoint(label: '3月', value: 7500.0),
            ],
            xLabels: ['1月', '2月', '3月'],
            yLabel: '金额（元）',
          ),
          onDismiss: () {},
        );
      } else if (text.contains('分类') && text.contains('对比')) {
        response = '各分类支出对比：餐饮2180元，交通800元，购物1500元';
        widget = InteractiveQueryChart(
          chartData: QueryChartData(
            chartType: ChartType.bar,
            title: '各分类支出对比',
            dataPoints: [
              DataPoint(label: '餐饮', value: 2180.0),
              DataPoint(label: '交通', value: 800.0),
              DataPoint(label: '购物', value: 1500.0),
              DataPoint(label: '娱乐', value: 600.0),
            ],
            xLabels: ['餐饮', '交通', '购物', '娱乐'],
            yLabel: '金额（元）',
          ),
          onDismiss: () {},
        );
      } else if (text.contains('分布')) {
        response = '本月支出分布：餐饮占比最高43.6%，其次是购物30.0%';
        widget = InteractiveQueryChart(
          chartData: QueryChartData(
            chartType: ChartType.pie,
            title: '本月分类占比',
            dataPoints: [
              DataPoint(label: '餐饮', value: 2180.0),
              DataPoint(label: '交通', value: 800.0),
              DataPoint(label: '购物', value: 1500.0),
              DataPoint(label: '娱乐', value: 600.0),
            ],
            xLabels: ['餐饮', '交通', '购物', '娱乐'],
            yLabel: '金额（元）',
          ),
          onDismiss: () {},
        );
      } else {
        response = _generateResponse(text);
      }

      _addAssistantMessage(response, widget: widget);
    });
  }

  /// 尝试执行真实查询（使用LLM意图识别）
  Future<Map<String, dynamic>?> _tryExecuteQuery(String input) async {
    try {
      // 使用SmartIntentRecognizer进行意图识别
      final recognitionResult = await _intentRecognizer.recognizeMultiOperation(
        input,
        pageContext: 'voice_assistant',
      );

      // 只处理查询操作
      if (!recognitionResult.hasOperations) {
        return null;
      }

      // 查找第一个查询操作
      final queryOperation = recognitionResult.operations.firstWhere(
        (op) => op.type == OperationType.query,
        orElse: () => recognitionResult.operations.first,
      );

      if (queryOperation.type != OperationType.query) {
        return null;
      }

      // 从params中提取查询参数
      final params = queryOperation.params;

      // 解析查询类型
      final queryTypeStr = params['queryType'] as String?;
      if (queryTypeStr == null) return null;

      final queryType = _parseQueryType(queryTypeStr);
      if (queryType == null) return null;

      // 解析时间范围
      final timeStr = params['time'] as String?;
      final timeRange = _parseTimeRange(timeStr);
      if (timeRange == null) return null;

      // 解析分类（可选）
      final category = params['category'] as String?;

      // 解析分组维度（可选）
      final groupByStr = params['groupBy'] as String?;
      final groupBy = groupByStr != null ? [_parseGroupByDimension(groupByStr)] : null;

      // 构建查询请求
      final request = QueryRequest(
        queryType: queryType,
        timeRange: timeRange,
        category: category,
        groupBy: groupBy?.whereType<GroupByDimension>().toList(),
      );

      // 执行查询
      final result = await _queryExecutor.execute(request);

      // 生成响应
      final queryResponse = await _queryRouter.route(request, result);

      // 创建widget
      Widget? widget;
      if (queryResponse.level == QueryLevel.medium && queryResponse.cardData != null) {
        widget = LightweightQueryCard(
          cardData: queryResponse.cardData!,
          onDismiss: () {},
        );
      } else if (queryResponse.level == QueryLevel.complex && queryResponse.chartData != null) {
        widget = InteractiveQueryChart(
          chartData: queryResponse.chartData!,
          onDismiss: () {},
        );
      }

      return {
        'response': queryResponse.voiceText,
        'widget': widget,
      };
    } catch (e) {
      debugPrint('[VoiceAssistant] 查询执行失败: $e');
      return null;
    }
  }

  /// 解析查询类型字符串到枚举
  QueryType? _parseQueryType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'summary':
        return QueryType.summary;
      case 'recent':
        return QueryType.recent;
      case 'trend':
        return QueryType.trend;
      case 'distribution':
        return QueryType.distribution;
      case 'comparison':
        return QueryType.comparison;
      default:
        return null;
    }
  }

  /// 解析时间范围字符串到TimeRange对象
  TimeRange? _parseTimeRange(String? timeStr) {
    if (timeStr == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (timeStr) {
      case '今天':
      case '本日':
        return TimeRange(
          startDate: today,
          endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
          periodText: '今天',
        );

      case '昨天':
        final yesterday = today.subtract(const Duration(days: 1));
        return TimeRange(
          startDate: yesterday,
          endDate: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
          periodText: '昨天',
        );

      case '本周':
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        return TimeRange(
          startDate: weekStart,
          endDate: now,
          periodText: '本周',
        );

      case '本月':
      case '这个月':
        return TimeRange(
          startDate: DateTime(now.year, now.month, 1),
          endDate: now,
          periodText: '本月',
        );

      case '上月':
      case '上个月':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        return TimeRange(
          startDate: lastMonth,
          endDate: lastMonthEnd,
          periodText: '上月',
        );

      default:
        // 尝试解析"最近N天"或"最近N个月"
        final daysMatch = RegExp(r'最近(\d+)天').firstMatch(timeStr);
        if (daysMatch != null) {
          final days = int.tryParse(daysMatch.group(1)!) ?? 7;
          return TimeRange(
            startDate: today.subtract(Duration(days: days - 1)),
            endDate: now,
            periodText: '最近$days天',
          );
        }

        final monthsMatch = RegExp(r'最近(\d+)个?月').firstMatch(timeStr);
        if (monthsMatch != null) {
          final months = int.tryParse(monthsMatch.group(1)!) ?? 3;
          return TimeRange(
            startDate: DateTime(now.year, now.month - months, now.day),
            endDate: now,
            periodText: '最近$months个月',
          );
        }

        return null;
    }
  }

  /// 解析分组维度字符串到枚举
  GroupByDimension? _parseGroupByDimension(String dimensionStr) {
    switch (dimensionStr.toLowerCase()) {
      case 'date':
      case 'day':
        return GroupByDimension.date;
      case 'month':
        return GroupByDimension.month;
      case 'category':
        return GroupByDimension.category;
      case 'source':
        return GroupByDimension.source;
      case 'account':
        return GroupByDimension.account;
      default:
        return null;
    }
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

    // 按分类汇总
    final categoryTotals = <String, double>{};
    for (final t in todayExpenses) {
      // 跳过转账和无效分类
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;

      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // 计算总支出
    final totalSpent = categoryTotals.values.fold<double>(0, (sum, v) => sum + v);

    // 按金额排序，取前3个分类
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(3);

    // 生成分类明细
    final categoryDetails = topCategories.map((entry) {
      final category = DefaultCategories.findById(entry.key);
      final emoji = _getCategoryEmoji(entry.key);
      final name = category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key);
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

    // 按分类汇总支出
    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      // 跳过转账和无效分类
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;

      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    final totalExpense = categoryTotals.values.fold<double>(0, (sum, v) => sum + v);
    final totalIncome = incomes.fold<double>(0, (sum, t) => sum + t.amount);

    if (totalExpense == 0 && totalIncome == 0) {
      return '📊 本月消费统计\n\n本月暂无交易记录\n\n开始记录您的第一笔账吧！';
    }

    // 按金额排序，取前5个分类
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5);

    // 生成分类明细
    final categoryDetails = topCategories.map((entry) {
      final category = DefaultCategories.findById(entry.key);
      final emoji = _getCategoryEmoji(entry.key);
      final name = category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key);
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
      // 跳过转账和无效分类
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;

      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // 找出支出最高的分类
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedCategories.isNotEmpty) {
      final topCategory = sortedCategories.first;
      final category = DefaultCategories.findById(topCategory.key);
      final name = category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(topCategory.key);
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
        final name = category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(categoryId);
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
