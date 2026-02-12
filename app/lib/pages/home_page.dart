import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../providers/transaction_provider.dart';
import '../providers/auth_provider.dart';
import '../models/budget.dart' show MoneyAge;
import '../providers/budget_provider.dart';
import '../providers/budget_vault_provider.dart';
import '../providers/gamification_provider.dart';
import '../providers/home_page_text_provider.dart';
import '../models/transaction.dart';
import '../widgets/budget_alert_widget.dart';
import '../widgets/swipeable_transaction_item.dart';
import 'transaction_list_page.dart';
import 'transaction_detail_page.dart';
import 'add_transaction_page.dart';
import 'today_allowance_page.dart';
import 'money_age_page.dart';
import 'budget_center_page.dart';
import 'zero_based_budget_page.dart';
import 'import/smart_import_page.dart';
import 'vault_detail_page.dart';
import '../services/feature_guide_service.dart';
import '../services/share_receiver_service.dart';
import '../services/payment_notification_service.dart';
import '../models/guide_step.dart';
import '../providers/feature_guide_provider.dart';
import 'main_navigation.dart';

/// 仪表盘首页
/// 原型设计 1.01：仪表盘 Dashboard
/// - 伙伴化设计：温暖问候语（根据时间动态变化）
/// - 本月结余显示（带趋势指示）
/// - 成就庆祝卡片（连续记账达成）
/// - 钱龄卡片
/// - 快速统计（本月收入/支出）
/// - 预算概览
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _activeItemId;

  // GlobalKey for feature guide
  final GlobalKey appContentKey = GlobalKey();
  StreamSubscription<PaymentNotificationEvent>? _paymentSubscription;

  @override
  void initState() {
    super.initState();

    // 注册文件分享回调
    ShareReceiverService().onFilesReceived = _handleSharedFiles;

    // 监听支付通知
    _paymentSubscription =
        PaymentNotificationService().onPaymentDetected.listen(_handlePaymentNotification);

    // 页面加载完成后检查是否需要显示引导 + 检查初始分享
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowGuide();
      _checkInitialSharedFiles();
    });
  }

  @override
  void dispose() {
    ShareReceiverService().onFilesReceived = null;
    _paymentSubscription?.cancel();
    super.dispose();
  }

  /// 检查启动时是否有待处理的分享文件
  void _checkInitialSharedFiles() {
    final service = ShareReceiverService();
    if (service.pendingFiles.isNotEmpty) {
      _handleSharedFiles(service.pendingFiles);
    }
  }

  /// 处理从微信等应用分享过来的账单文件
  void _handleSharedFiles(List<String> filePaths) {
    if (!mounted || filePaths.isEmpty) return;

    // 消费掉待处理文件
    ShareReceiverService().consumePendingFiles();

    final filePath = filePaths.first;
    final fileName = filePath.split('/').last.toLowerCase();

    // 检查是否是支持的账单文件格式
    if (fileName.endsWith('.csv') ||
        fileName.endsWith('.xlsx') ||
        fileName.endsWith('.xls')) {
      // 跳转到智能导入页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SmartImportPage(initialFilePath: filePath),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('不支持的文件格式: $fileName\n支持 CSV、Excel 格式的账单文件'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 处理支付通知事件，弹出快速记账确认
  void _handlePaymentNotification(PaymentNotificationEvent event) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentNotificationSheet(
        event: event,
        onConfirm: (amount, category, note) {
          _savePaymentTransaction(amount, category, note, event.app);
          Navigator.pop(ctx);
        },
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }

  /// 保存支付通知为交易记录
  void _savePaymentTransaction(
      double amount, String category, String note, String source) {
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TransactionType.expense,
      amount: amount,
      category: category,
      note: note.isNotEmpty ? note : '来自$source通知',
      date: DateTime.now(),
      accountId: 'default',
    );

    ref.read(transactionProvider.notifier).addTransaction(transaction);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录 ¥${amount.toStringAsFixed(2)}'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            ref.read(transactionProvider.notifier)
                .deleteTransaction(transaction.id);
          },
        ),
      ),
    );
  }

  /// 检查并显示功能引导
  void _checkAndShowGuide() {
    final shouldShow = ref.read(featureGuideProvider.notifier).shouldShowHomeGuide();

    if (shouldShow && mounted) {
      // 延迟一段时间，确保页面完全渲染
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;

        _showFeatureGuide();
      });
    }
  }

  /// 下拉刷新数据
  Future<void> _refreshData() async {
    try {
      // 刷新交易数据
      await ref.read(transactionProvider.notifier).refresh();

      // 刷新小金库数据（会自动同步支出）
      await ref.read(budgetVaultProvider.notifier).refresh();
    } catch (e) {
      // 刷新失败不影响用户使用
    }
  }

  /// 显示功能引导（3步）
  void _showFeatureGuide() {
    final steps = [
      // 第1步：数据下钻
      GuideStep(
        id: 'home_guide',
        targetKey: appContentKey,
        title: '💡 数据下钻',
        description: '首页展示的所有汇总数据都支持下钻\n\n点击任意数据卡片，即可查看详细信息和历史记录',
        position: GuidePosition.center,
      ),
      // 第2步：语音操控
      GuideStep(
        id: 'voice_control',
        targetKey: MainNavigation.fabKey,
        title: '🎤 语音操控',
        description: '语音是最强大的功能！\n\n• 语音记账："午餐花了50块"\n• 语音查询："这个月餐饮花了多少"\n• 语音导航："打开预算管理"\n\n长按此按钮即可开始',
        position: GuidePosition.top,
      ),
      // 第3步：白记助手
      GuideStep(
        id: 'xiaoji_assistant',
        targetKey: MainNavigation.xiaojiNavKey,
        title: '🐾 白记助手',
        description: '所有操作都会记录在白记中\n\n白记会帮你：\n• 记住你说过的话\n• 追踪账目变化\n• 提供智能建议\n\n随时点击查看对话历史',
        position: GuidePosition.top,
      ),
    ];

    FeatureGuideService.instance.showGuide(
      context: context,
      steps: steps,
      onComplete: () {
        debugPrint('[HomePage] Feature guide completed');
        ref.read(featureGuideProvider.notifier).markHomeGuideShown();
      },
      onSkip: () {
        debugPrint('[HomePage] Feature guide skipped');
        ref.read(featureGuideProvider.notifier).markHomeGuideShown();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    final colors = ref.themeColors;
    final balance = monthlyIncome - monthlyExpense;

    // 获取用户ID并更新文案Provider
    final authState = ref.watch(authProvider);
    final userId = authState.user?.id;

    // 计算数据并更新文案上下文
    final lastMonthBalance = ref.watch(lastMonthBalanceProvider);
    // 修复：只要上月结余不为0就计算增长率，允许负数结余的对比
    // 同时限制增长率在合理范围内（-999% 到 999%），避免异常显示
    double growth = lastMonthBalance != 0
        ? ((balance - lastMonthBalance) / lastMonthBalance * 100)
        : 0.0;
    // 处理NaN和Infinity，并限制范围
    if (growth.isNaN || growth.isInfinite) {
      growth = 0.0;
    } else {
      growth = growth.clamp(-999.0, 999.0);
    }
    final streakStats = ref.watch(gamificationProvider);
    final moneyAgeData = ref.watch(moneyAgeProvider);
    final trendDays = moneyAgeData.trend == 'up' ? 5 : (moneyAgeData.trend == 'down' ? -5 : 0);

    // 更新文案Provider的上下文（支持千人千面和定期刷新）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homePageTextProvider.notifier).setUserId(userId);
      ref.read(homePageTextProvider.notifier).updateContext(
        growth: growth,
        streakDays: streakStats.currentStreak,
        trendDays: trendDays,
        trend: moneyAgeData.trend ?? 'stable',
        moneyAgeDays: moneyAgeData.days,
      );
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Container(
          key: appContentKey,  // Add key for feature guide
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderGradient(context, theme, balance, colors),
              const BudgetAlertBanner(),
              _buildTodayAllowanceCard(context, theme, monthlyIncome, monthlyExpense),
              _buildCelebrationCard(context, theme),
              _buildMoneyAgeCard(context, theme, ref, moneyAgeData),
              _buildQuickStats(context, theme, monthlyIncome, monthlyExpense, colors),
              _buildBudgetOverview(context, theme),
              _buildRecentTransactions(context, theme, transactions, colors),
              const SizedBox(height: 100), // 底部导航栏留白
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// 头部渐变区域
  /// 原型设计：温暖问候语 + 本月结余
  Widget _buildHeaderGradient(
    BuildContext context,
    ThemeData theme,
    double balance,
    ThemeColors colors,
  ) {
    // 从Provider获取动态文案（支持千人千面和定期刷新）
    final textState = ref.watch(homePageTextProvider);
    final greeting = textState.greeting;
    final balanceGrowthText = textState.balanceGrowthText;

    final authState = ref.watch(authProvider);
    final userName = authState.user?.nickname ?? authState.user?.email?.split('@').first ?? '';

    // 计算同比增长（仅用于图标显示）
    final lastMonthBalance = ref.watch(lastMonthBalanceProvider);
    // 修复：只要上月结余不为0就计算增长率，允许负数结余的对比
    // 同时限制增长率在合理范围内，避免异常显示
    double growth = lastMonthBalance != 0
        ? ((balance - lastMonthBalance) / lastMonthBalance * 100)
        : 0.0;
    // 处理NaN和Infinity
    if (growth.isNaN || growth.isInfinite) {
      growth = 0.0;
    }
    final isPositiveGrowth = growth >= 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            HSLColor.fromColor(theme.colorScheme.primary)
                .withLightness(0.35)
                .toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 伙伴化问候语
              Row(
                children: [
                  Text(
                    greeting.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    greeting.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$userName，${greeting.motivation}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // 本月结余 - 点击可查看本月交易明细
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionListPage()),
                  );
                },
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        '本月结余',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${balance.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 趋势指示
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPositiveGrowth
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            balanceGrowthText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 今日可支出卡片
  /// 原型设计 1.06：快速入口到今日可支出页面
  Widget _buildTodayAllowanceCard(
    BuildContext context,
    ThemeData theme,
    double monthlyIncome,
    double monthlyExpense,
  ) {
    // 计算今日可支出
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = lastDay.day - now.day + 1;
    final budgetRemaining = monthlyIncome - monthlyExpense;
    // 修复：添加daysRemaining > 0的检查，避免除以零
    final dailyAllowance = budgetRemaining > 0 && daysRemaining > 0
        ? budgetRemaining / daysRemaining
        : 0.0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TodayAllowancePage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.today,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日可支出',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${dailyAllowance.toStringAsFixed(0)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 成就庆祝卡片
  /// 原型设计：伙伴化设计 - 连续记账达成时显示
  Widget _buildCelebrationCard(BuildContext context, ThemeData theme) {
    final streakStats = ref.watch(gamificationProvider);
    final consecutiveDays = streakStats.currentStreak;

    // 如果没有连续记账，不显示卡片
    if (consecutiveDays == 0) {
      return const SizedBox.shrink();
    }

    // 从Provider获取动态文案（支持千人千面和定期刷新）
    final textState = ref.watch(homePageTextProvider);

    return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFF8E1),
                const Color(0xFFFFECB3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textState.streakCelebrationText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textState.streakEncouragementText,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  /// 钱龄卡片
  /// 原型设计：钱龄数值、等级、趋势
  Widget _buildMoneyAgeCard(BuildContext context, ThemeData theme, WidgetRef ref, MoneyAge moneyAgeData) {
    final moneyAge = moneyAgeData.days;

    // 根据钱龄天数确定等级
    String level;
    if (moneyAge >= 90) {
      level = '卓越';
    } else if (moneyAge >= 60) {
      level = '优秀';
    } else if (moneyAge >= 30) {
      level = '良好';
    } else if (moneyAge >= 14) {
      level = '及格';
    } else {
      level = '需改善';
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MoneyAgePage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '钱龄',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        level,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$moneyAge',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    // 负值显示红色，正值显示绿色
                    color: moneyAge < 0 ? AppColors.expense : AppColors.success,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '天',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              moneyAgeData.description,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 快速统计卡片
  /// 原型设计：本月收入/支出双列显示
  Widget _buildQuickStats(
    BuildContext context,
    ThemeData theme,
    double income,
    double expense,
    ThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月收入',
              value: '¥${income.toStringAsFixed(0)}',
              valueColor: colors.income,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月支出',
              value: '¥${expense.toStringAsFixed(0)}',
              valueColor: colors.expense,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 预算概览
  /// 原型设计：预算类目进度条列表
  /// 数据来源：budgetProvider（预算设置）+ monthlyExpenseByCategoryProvider（本月分类支出）
  Widget _buildBudgetOverview(BuildContext context, ThemeData theme) {
    final vaultState = ref.watch(budgetVaultProvider);
    final vaults = vaultState.vaults;

    // 过滤出已启用的小金库，并按使用率排序（高的在前）
    final activeVaults = vaults
        .where((v) => v.isEnabled && v.allocatedAmount > 0)
        .map((v) {
          final spent = v.spentAmount;
          final allocated = v.allocatedAmount;
          final percent = (spent / allocated * 100).clamp(0, 999).toInt();
          return (vault: v, spent: spent, allocated: allocated, percent: percent);
        })
        .toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));

    // 最多显示3个小金库
    final displayVaults = activeVaults.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '小金库概览',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BudgetCenterPage()),
                  );
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (displayVaults.isEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ZeroBasedBudgetPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '配置零基预算，让每一分钱都有去处',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '去配置',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayVaults.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final vault = item.vault;

              return Padding(
                padding: EdgeInsets.only(top: index > 0 ? 12 : 0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VaultDetailPage(vault: vault),
                      ),
                    );
                  },
                  child: _buildBudgetItem(
                    context,
                    theme,
                    name: vault.name,
                    icon: vault.icon,
                    iconColor: vault.color,
                    spent: item.spent,
                    budget: item.allocated,
                    percent: item.percent,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    ThemeData theme, {
    required String name,
    required IconData icon,
    required Color iconColor,
    required double spent,
    required double budget,
    required int percent,
  }) {
    Color progressColor;
    if (percent >= 80) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '¥${spent.toStringAsFixed(0)} / ¥${budget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 最近交易列表
  Widget _buildRecentTransactions(
    BuildContext context,
    ThemeData theme,
    List<Transaction> transactions,
    ThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.recentTransactions,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SmartImportPage()),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('智能导入'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionListPage()),
                    ),
                    child: Text(context.l10n.viewAll),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.noData,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...transactions.take(5).map((tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SwipeableTransactionItem(
                    key: ValueKey(tx.id),
                    transaction: tx,
                    isActive: _activeItemId == tx.id,
                    themeColors: colors,
                    onLongPress: () => setState(() => _activeItemId = tx.id),
                    onEdit: () => _handleEdit(tx),
                    onDelete: () => _confirmDelete(tx),
                    onTap: () => _showTransactionDetail(tx),
                    onDismiss: () => setState(() => _activeItemId = null),
                  ),
                )),
        ],
      ),
    );
  }

  /// 查看交易详情
  void _showTransactionDetail(Transaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailPage(transaction: transaction),
      ),
    );
  }

  /// 编辑交易
  void _handleEdit(Transaction transaction) {
    setState(() => _activeItemId = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(transaction: transaction),
      ),
    );
  }

  /// 确认删除交易
  void _confirmDelete(Transaction transaction) {
    setState(() => _activeItemId = null);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这笔记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(transactionProvider.notifier).deleteTransaction(transaction.id);
              Navigator.pop(dialogContext);
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}

/// 支付通知快速记账底部弹窗
class _PaymentNotificationSheet extends StatefulWidget {
  final PaymentNotificationEvent event;
  final void Function(double amount, String category, String note) onConfirm;
  final VoidCallback onDismiss;

  const _PaymentNotificationSheet({
    required this.event,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<_PaymentNotificationSheet> createState() =>
      _PaymentNotificationSheetState();
}

class _PaymentNotificationSheetState extends State<_PaymentNotificationSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  String _selectedCategory = 'other_expense';

  static const _quickCategories = [
    ('food', '餐饮', '🍜'),
    ('transport', '交通', '🚗'),
    ('shopping', '购物', '🛒'),
    ('entertainment', '娱乐', '🎮'),
    ('medical', '医疗', '💊'),
    ('other_expense', '其他', '📋'),
  ];

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.event.amount.toStringAsFixed(2));
    _noteController = TextEditingController(
        text: widget.event.merchant ?? widget.event.title ?? '');

    // 根据通知内容猜测分类
    _selectedCategory = _guessCategory(
        widget.event.merchant ?? widget.event.title ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _guessCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('餐') || t.contains('饭') || t.contains('食') ||
        t.contains('外卖') || t.contains('美团') || t.contains('饿了么')) {
      return 'food';
    }
    if (t.contains('打车') || t.contains('滴滴') || t.contains('出行') ||
        t.contains('地铁') || t.contains('公交')) {
      return 'transport';
    }
    if (t.contains('淘宝') || t.contains('京东') || t.contains('拼多多') ||
        t.contains('购物')) {
      return 'shopping';
    }
    return 'other_expense';
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.event.app;
    final sourceIcon = source.contains('微信')
        ? '💬'
        : source.contains('支付宝')
            ? '🔵'
            : '📱';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Text(sourceIcon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '$source支付通知',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 金额输入
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              prefixText: '¥ ',
              prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),

          // 快速分类选择
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickCategories.map((cat) {
              final isSelected = _selectedCategory == cat.$1;
              return ChoiceChip(
                label: Text('${cat.$3} ${cat.$2}'),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _selectedCategory = cat.$1),
                selectedColor: Colors.blue[100],
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.blue[800] : Colors.grey[700],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // 备注
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: '备注',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onDismiss,
                  child: const Text('忽略'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    final amount =
                        double.tryParse(_amountController.text) ?? 0;
                    if (amount > 0) {
                      widget.onConfirm(
                        amount,
                        _selectedCategory,
                        _noteController.text,
                      );
                    }
                  },
                  child: const Text('记一笔'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
