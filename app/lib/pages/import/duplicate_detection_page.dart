import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'transaction_comparison_page.dart';

/// 去重检测页面
/// 原型设计 5.02：去重检测
/// - 进度步骤指示器
/// - 统计摘要（新交易、疑似重复、确定重复）
/// - 标签页切换
/// - 重复项列表
/// - 底部操作按钮
class DuplicateDetectionPage extends ConsumerStatefulWidget {
  final List<ImportedTransaction> transactions;
  final String fileName;

  const DuplicateDetectionPage({
    super.key,
    required this.transactions,
    required this.fileName,
  });

  @override
  ConsumerState<DuplicateDetectionPage> createState() => _DuplicateDetectionPageState();
}

class _DuplicateDetectionPageState extends ConsumerState<DuplicateDetectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 模拟数据
  late int _newCount;
  late int _suspectedCount;
  late int _confirmedCount;
  late List<DuplicateItem> _suspectedDuplicates;
  late List<DuplicateItem> _confirmedDuplicates;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _initializeData();
  }

  void _initializeData() {
    // 模拟去重检测结果
    final total = widget.transactions.length;
    _confirmedCount = (total * 0.08).round();
    _suspectedCount = (total * 0.12).round();
    _newCount = total - _confirmedCount - _suspectedCount;

    // 模拟疑似重复数据
    _suspectedDuplicates = [
      DuplicateItem(
        merchant: '星巴克',
        amount: 38.00,
        date: DateTime.now().subtract(const Duration(days: 1)),
        similarity: 92,
        existingMerchant: '星巴克',
        existingAmount: 38.00,
        existingDate: DateTime.now().subtract(const Duration(days: 1, minutes: 2)),
      ),
      DuplicateItem(
        merchant: '美团外卖',
        amount: 45.50,
        date: DateTime.now().subtract(const Duration(days: 2)),
        similarity: 75,
        existingMerchant: '美团外卖-午餐',
        existingAmount: 45.50,
        existingDate: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      ),
      DuplicateItem(
        merchant: '滴滴出行',
        amount: 23.00,
        date: DateTime.now().subtract(const Duration(days: 3)),
        similarity: 60,
        existingMerchant: '滴滴打车',
        existingAmount: 23.00,
        existingDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    _confirmedDuplicates = [
      DuplicateItem(
        merchant: '微信转账',
        amount: 100.00,
        date: DateTime.now().subtract(const Duration(days: 1)),
        similarity: 100,
        existingMerchant: '微信转账',
        existingAmount: 100.00,
        existingDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.transactions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('去重检测'),
      ),
      body: Column(
        children: [
          _buildProgressSteps(theme),
          _buildSummaryCards(theme),
          _buildTabBar(theme, total),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllList(theme),
                _buildSuspectedList(theme),
                _buildConfirmedList(theme),
              ],
            ),
          ),
          _buildBottomActions(context, theme),
        ],
      ),
    );
  }

  /// 进度步骤
  Widget _buildProgressSteps(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStep(theme, 1, true, true),
          _buildStepLine(theme, true),
          _buildStep(theme, 2, true, true),
          _buildStepLine(theme, true),
          _buildStep(theme, 3, true, false),
          _buildStepLine(theme, false),
          _buildStep(theme, 4, false, false),
        ],
      ),
    );
  }

  Widget _buildStep(ThemeData theme, int number, bool isCompleted, bool isPast) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCompleted
            ? theme.colorScheme.primary
            : (isPast ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isPast && isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '$number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.white : theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }

  Widget _buildStepLine(ThemeData theme, bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  /// 统计摘要卡片
  Widget _buildSummaryCards(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              theme,
              _newCount,
              '新交易',
              AppColors.success,
              const Color(0xFFE8F5E9),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              theme,
              _suspectedCount,
              '疑似重复',
              Colors.orange,
              const Color(0xFFFFF3E0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              theme,
              _confirmedCount,
              '确定重复',
              AppColors.error,
              const Color(0xFFFFEBEE),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    int value,
    String label,
    Color valueColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 标签页
  Widget _buildTabBar(ThemeData theme, int total) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        tabs: [
          Tab(text: '全部($total)'),
          Tab(text: '疑似重复($_suspectedCount)'),
          Tab(text: '确定重复($_confirmedCount)'),
        ],
      ),
    );
  }

  /// 全部列表（简略显示）
  Widget _buildAllList(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.list_alt,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '共 ${widget.transactions.length} 条待导入',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '请先处理疑似重复和确定重复的交易',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 疑似重复列表
  Widget _buildSuspectedList(ThemeData theme) {
    if (_suspectedDuplicates.isEmpty) {
      return _buildEmptyState(theme, '没有疑似重复的交易');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suspectedDuplicates.length,
      itemBuilder: (context, index) {
        return _buildDuplicateItem(theme, _suspectedDuplicates[index]);
      },
    );
  }

  /// 确定重复列表
  Widget _buildConfirmedList(ThemeData theme) {
    if (_confirmedDuplicates.isEmpty) {
      return _buildEmptyState(theme, '没有确定重复的交易');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _confirmedDuplicates.length,
      itemBuilder: (context, index) {
        return _buildDuplicateItem(theme, _confirmedDuplicates[index]);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.success.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateItem(ThemeData theme, DuplicateItem item) {
    final similarityColor = item.similarity >= 90
        ? AppColors.error
        : (item.similarity >= 70 ? Colors.orange : Colors.grey);

    return GestureDetector(
      onTap: () => _showComparison(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: similarityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.similarity}% 相似',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: similarityColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.merchant,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '¥${item.amount.toStringAsFixed(2)} · ${_formatDate(item.date)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.expand_more,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 底部操作按钮
  Widget _buildBottomActions(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _skipAllDuplicates(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('跳过全部重复'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _confirmImport(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('确认导入'),
            ),
          ),
        ],
      ),
    );
  }

  void _showComparison(BuildContext context, DuplicateItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionComparisonPage(
          newTransaction: ComparisonTransaction(
            merchant: item.merchant,
            amount: item.amount,
            date: item.date,
            paymentMethod: '微信支付',
          ),
          existingTransaction: ComparisonTransaction(
            merchant: item.existingMerchant,
            amount: item.existingAmount,
            date: item.existingDate,
            paymentMethod: '微信',
          ),
          similarity: item.similarity,
        ),
      ),
    );
  }

  void _skipAllDuplicates(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已跳过所有重复交易')),
    );
  }

  void _confirmImport(BuildContext context) {
    // 导航到导入进度页面
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('开始导入 $_newCount 条新交易'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }
}

/// 导入的交易数据
class ImportedTransaction {
  final String id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String? category;

  ImportedTransaction({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    this.category,
  });
}

/// 重复项
class DuplicateItem {
  final String merchant;
  final double amount;
  final DateTime date;
  final int similarity;
  final String existingMerchant;
  final double existingAmount;
  final DateTime existingDate;

  DuplicateItem({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.similarity,
    required this.existingMerchant,
    required this.existingAmount,
    required this.existingDate,
  });
}
