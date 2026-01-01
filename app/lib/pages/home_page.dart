import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../widgets/budget_alert_widget.dart';
import '../widgets/source_image_viewer.dart';
import '../widgets/source_audio_player.dart';
import '../widgets/swipeable_transaction_item.dart';
import 'quick_entry_page.dart';
import 'image_recognition_page.dart';
import 'voice_recognition_page.dart';
import 'statistics_page.dart';
import 'transaction_list_page.dart';
import 'add_transaction_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // 当前展开操作按钮的条目ID
  String? _activeItemId;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    // 获取主题颜色（监听主题变化）
    final colors = ref.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aiSmartBookkeeping),
        actions: const [
          BudgetAlertIconButton(),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // 滚动时收起展开的操作按钮
          if (_activeItemId != null && notification is ScrollUpdateNotification) {
            setState(() => _activeItemId = null);
          }
          return false;
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(context, monthlyIncome, monthlyExpense, colors),
              const BudgetAlertBanner(),
              _buildQuickActions(context, colors),
              _buildRecentTransactions(context, transactions, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, double income, double expense, ThemeColors colors) {
    final balance = income - expense;
    final now = DateTime.now();
    final monthName = DateFormat('yyyy/MM').format(now);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, HSLColor.fromColor(colors.primary).withLightness(0.35).toColor()],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
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
              GestureDetector(
                onTap: () => _navigateToStatistics(context),
                child: Row(
                  children: [
                    Text(
                      monthName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToStatistics(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.thisMonthLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.analytics, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.balance,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.income,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${income.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.expense,
                            style:
                                const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${expense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            context,
            icon: Icons.flash_on,
            label: context.l10n.quickRecord,
            color: colors.transfer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuickEntryPage()),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.camera_alt,
            label: context.l10n.photoRecord,
            color: colors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImageRecognitionPage()),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.mic,
            label: context.l10n.voiceRecord,
            color: colors.income,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VoiceRecognitionPage()),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.analytics,
            label: context.l10n.reportAnalysis,
            color: colors.expense,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context, List<Transaction> transactions, ThemeColors colors) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.recentTransactions,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TransactionListPage()),
                  );
                },
                child: Text(context.l10n.viewAll),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length > 5 ? 5 : transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return _buildTransactionItem(context, transaction, colors);
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction, ThemeColors colors) {
    final theme = Theme.of(context);
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SwipeableTransactionItem(
          transaction: transaction,
          isActive: _activeItemId == transaction.id,
          themeColors: colors,
          onLongPress: () {
            setState(() => _activeItemId = transaction.id);
          },
          onEdit: () => _handleEdit(transaction),
          onDelete: () => _confirmDelete(transaction),
          onTap: () => _showTransactionDetail(context, transaction, colors),
          onDismiss: () => setState(() => _activeItemId = null),
          contentBuilder: (tx, themeColors) => Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  category?.icon ?? Icons.help_outline,
                  color: category?.color ?? Colors.grey,
                  size: 24,
                ),
              ),
              title: Text(
                category?.localizedName ?? tx.category,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                tx.note ?? DateFormat('MM/dd HH:mm').format(tx.date),
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 12,
                ),
              ),
              trailing: Text(
                '${isExpense ? '-' : '+'}¥${tx.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isExpense ? themeColors.expense : themeColors.income,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 跳转到统计分析页面
  void _navigateToStatistics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StatisticsPage()),
    );
  }

  /// 编辑交易
  void _handleEdit(Transaction transaction) {
    // 先收起按钮
    setState(() => _activeItemId = null);

    // 跳转到编辑页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(transaction: transaction),
      ),
    ).then((_) {
      // 返回后刷新列表
      ref.read(transactionProvider.notifier).refresh();
    });
  }

  /// 确认删除交易
  Future<void> _confirmDelete(Transaction transaction) async {
    final colors = ref.themeColors;
    // 先收起按钮
    setState(() => _activeItemId = null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.confirmDelete),
        content: Text(context.l10n.confirmDeleteRecord),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.delete, style: TextStyle(color: colors.expense)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(transactionProvider.notifier).deleteTransaction(transaction.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deleted)),
      );
    }
  }

  void _showTransactionDetail(BuildContext context, Transaction transaction, ThemeColors colors) {
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;

    // 如果当前有展开的条目，先收起
    if (_activeItemId != null) {
      setState(() => _activeItemId = null);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            category?.icon ?? Icons.help_outline,
                            color: category?.color ?? Colors.grey,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    category?.localizedName ?? transaction.category,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (transaction.source != TransactionSource.manual) ...[
                                    const SizedBox(width: 8),
                                    _buildSourceBadge(transaction.source),
                                  ],
                                ],
                              ),
                              Text(
                                DateFormat('yyyy年MM月dd日 HH:mm').format(transaction.date),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isExpense ? '-' : (isIncome ? '+' : '')}¥${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isExpense ? colors.expense : (isIncome ? colors.income : colors.transfer),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    // 详情信息
                    if (transaction.note != null && transaction.note!.isNotEmpty)
                      _buildDetailRow(context.l10n.noteLabel, transaction.note!),
                    _buildDetailRow(context.l10n.typeLabel, isExpense ? context.l10n.expense : (isIncome ? context.l10n.income : context.l10n.transfer)),
                    _buildDetailRow(context.l10n.accountLabel, transaction.accountId),
                    if (transaction.aiConfidence != null)
                      _buildDetailRow(context.l10n.aiConfidenceLabel, '${(transaction.aiConfidence! * 100).toStringAsFixed(0)}%'),

                    // Source data section
                    if (transaction.source == TransactionSource.image &&
                        transaction.sourceFileLocalPath != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.originalImage,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSourceImageSection(context, transaction),
                    ],

                    if (transaction.source == TransactionSource.voice &&
                        transaction.sourceFileLocalPath != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      SourceAudioPlayer(
                        audioPath: transaction.sourceFileLocalPath!,
                        expiresAt: transaction.sourceFileExpiresAt,
                        fileSize: transaction.sourceFileSize,
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSourceBadge(TransactionSource source) {
    String label;
    IconData icon;
    Color color;

    switch (source) {
      case TransactionSource.image:
        label = context.l10n.sourcePhoto;
        icon = Icons.camera_alt;
        color = Colors.blue;
        break;
      case TransactionSource.voice:
        label = context.l10n.sourceVoice;
        icon = Icons.mic;
        color = Colors.green;
        break;
      case TransactionSource.email:
        label = context.l10n.sourceEmail;
        icon = Icons.email;
        color = Colors.orange;
        break;
      case TransactionSource.manual:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceImageSection(BuildContext context, Transaction transaction) {
    return Row(
      children: [
        SourceImageThumbnail(
          imagePath: transaction.sourceFileLocalPath!,
          size: 80,
          expiresAt: transaction.sourceFileExpiresAt,
          onTap: () {
            Navigator.pop(context);
            SourceImageViewer.show(
              context,
              imagePath: transaction.sourceFileLocalPath!,
              expiresAt: transaction.sourceFileExpiresAt,
              fileSize: transaction.sourceFileSize,
            );
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (transaction.sourceFileSize != null)
                Text(
                  _formatFileSize(transaction.sourceFileSize!),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              if (transaction.sourceFileExpiresAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _getExpiryText(transaction.sourceFileExpiresAt!),
                  style: TextStyle(
                    color: transaction.isSourceFileExpired ? AppColors.expense : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (!transaction.isSourceFileExpired)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    SourceImageViewer.show(
                      context,
                      imagePath: transaction.sourceFileLocalPath!,
                      expiresAt: transaction.sourceFileExpiresAt,
                      fileSize: transaction.sourceFileSize,
                    );
                  },
                  icon: const Icon(Icons.fullscreen, size: 16),
                  label: Text(context.l10n.viewLargeImage),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getExpiryText(DateTime expiresAt) {
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) {
      return context.l10n.expired;
    }
    final diff = expiresAt.difference(now);
    if (diff.inDays > 0) {
      return context.l10n.expiresInDays(diff.inDays);
    }
    if (diff.inHours > 0) {
      return context.l10n.expiresInHours(diff.inHours);
    }
    return context.l10n.expiringSoon;
  }
}
