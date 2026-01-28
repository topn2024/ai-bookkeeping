import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:convert';

import '../../theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../services/duplicate_detection_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';
import 'import_preview_confirm_page.dart';

/// 三层去重详情页面
/// 原型设计 5.11：三层去重详情
/// - 检测摘要卡片（待导入、新记录、疑似重复、确认重复）
/// - 三层去重机制说明
/// - 疑似重复记录列表
/// - 处理按钮
class DeduplicationPage extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;
  final String? detectedSource;
  final Map<String, String?>? fieldMappings;

  const DeduplicationPage({
    super.key,
    required this.filePath,
    required this.fileName,
    this.detectedSource,
    this.fieldMappings,
  });

  @override
  ConsumerState<DeduplicationPage> createState() => _DeduplicationPageState();
}

class _DeduplicationPageState extends ConsumerState<DeduplicationPage> {
  bool _isProcessing = true;

  // 真实检测数据
  int _totalRecords = 0;
  int _newRecords = 0;
  int _suspectedDuplicates = 0;
  int _confirmedDuplicates = 0;

  // 三层去重结果
  int _exactMatches = 0;
  int _featureMatches = 0;
  int _semanticMatches = 0;

  // 疑似重复记录
  List<SuspectedDuplicate> _suspectedList = [];

  // 导入的交易列表
  List<ImportedTransaction> _importedTransactions = [];

  @override
  void initState() {
    super.initState();
    _startDeduplication();
  }

  Future<void> _startDeduplication() async {
    try {
      // 1. 读取并解析文件
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在');
      }

      final content = await file.readAsString();
      final lines = const LineSplitter().convert(content);

      if (lines.isEmpty) {
        throw Exception('文件内容为空');
      }

      // 2. 解析CSV (简化版，假设是标准格式)
      _importedTransactions = _parseCSV(lines);
      _totalRecords = _importedTransactions.length;

      // 3. 执行真实的去重检测
      final db = sl<IDatabaseService>();
      final existingTransactions = await db.getTransactions();

      final suspectedList = <SuspectedDuplicate>[];
      int exactCount = 0;
      int featureCount = 0;
      int semanticCount = 0;

      // 对每笔导入的交易进行去重检测
      for (final imported in _importedTransactions) {
        // 转换为Transaction对象
        final newTransaction = Transaction(
          id: const Uuid().v4(),
          type: imported.amount > 0 ? TransactionType.income : TransactionType.expense,
          amount: imported.amount.abs(),
          category: imported.category ?? 'other',
          accountId: 'temp_account',
          date: imported.date,
          note: imported.merchant,
          createdAt: DateTime.now(),
        );

        // 执行去重检测
        final result = DuplicateDetectionService.checkDuplicate(
          newTransaction,
          existingTransactions,
        );

        if (result.hasPotentialDuplicate && result.potentialDuplicates.isNotEmpty) {
          final existing = result.potentialDuplicates.first;
          final similarity = result.similarityScore;

          // 根据相似度分类
          if (similarity >= 95) {
            // 95分以上 - 精确匹配
            exactCount++;
          } else if (similarity >= 85) {
            // 85-94分 - 确定重复
            exactCount++;
          } else if (similarity >= 75) {
            // 75-84分 - 特征匹配
            featureCount++;
            suspectedList.add(SuspectedDuplicate(
              description: imported.merchant,
              amount: imported.amount,
              matchType: '特征匹配',
              matchPercentage: similarity,
              similarDate: _formatDate(existing.date),
            ));
          } else if (similarity >= 55) {
            // 55-74分 - 语义匹配
            semanticCount++;
            suspectedList.add(SuspectedDuplicate(
              description: imported.merchant,
              amount: imported.amount,
              matchType: 'AI语义',
              matchPercentage: similarity,
              similarDate: _formatDate(existing.date),
            ));
          }
        }
      }

      setState(() {
        _exactMatches = exactCount;
        _featureMatches = featureCount;
        _semanticMatches = semanticCount;
        _confirmedDuplicates = exactCount;
        _suspectedDuplicates = featureCount + semanticCount;
        _newRecords = _totalRecords - _confirmedDuplicates - _suspectedDuplicates;
        _suspectedList = suspectedList;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('去重检测失败: $e');
      setState(() {
        // 如果解析失败，至少设置总记录数
        _newRecords = _totalRecords;
        _isProcessing = false;
      });
    }
  }

  /// 简单的CSV解析
  List<ImportedTransaction> _parseCSV(List<String> lines) {
    final transactions = <ImportedTransaction>[];

    // 跳过表头
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final fields = line.split(',');
        if (fields.length >= 3) {
          transactions.add(ImportedTransaction(
            id: const Uuid().v4(),
            merchant: fields[0].trim(),
            amount: double.tryParse(fields[1].trim()) ?? 0.0,
            date: DateTime.tryParse(fields[2].trim()) ?? DateTime.now(),
            category: fields.length > 3 ? fields[3].trim() : null,
          ));
        }
      } catch (e) {
        debugPrint('解析行失败: $line, 错误: $e');
      }
    }

    return transactions;
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('去重检测'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isProcessing
                ? _buildProcessingView(theme)
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(context, theme),
                        _buildDeduplicationLayers(context, theme),
                        _buildSuspectedList(context, theme),
                      ],
                    ),
                  ),
          ),
          if (!_isProcessing) _buildActionButton(context, theme),
        ],
      ),
    );
  }

  Widget _buildProcessingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '正在进行去重检测...',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 主数字
          Text(
            '$_totalRecords',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Text(
            '待导入记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          // 分项统计
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('$_newRecords', '新记录'),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                _buildStatItem('$_suspectedDuplicates', '疑似重复'),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                _buildStatItem('$_confirmedDuplicates', '确认重复'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildDeduplicationLayers(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '三层去重机制',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // 第一层：精确匹配
          _buildLayerCard(
            theme,
            icon: Icons.verified,
            iconColor: AppColors.success,
            borderColor: AppColors.success,
            title: '精确匹配',
            description: '金额+日期+描述完全相同',
            count: _exactMatches,
            status: '已排除',
            statusColor: AppColors.error,
          ),
          const SizedBox(height: 8),
          // 第二层：特征匹配
          _buildLayerCard(
            theme,
            icon: Icons.help,
            iconColor: Colors.orange,
            borderColor: Colors.orange,
            title: '特征匹配',
            description: '金额相同+日期相近+描述相似',
            count: _featureMatches,
            status: '待确认',
            statusColor: Colors.orange,
          ),
          const SizedBox(height: 8),
          // 第三层：语义匹配
          _buildLayerCard(
            theme,
            icon: Icons.psychology,
            iconColor: Colors.blue,
            borderColor: Colors.blue,
            title: 'AI语义匹配',
            description: 'AI判断是否为同一笔交易',
            count: _semanticMatches,
            status: '待确认',
            statusColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildLayerCard(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required String title,
    required String description,
    required int count,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuspectedList(BuildContext context, ThemeData theme) {
    if (_suspectedList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '疑似重复记录（点击查看详情）',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ..._suspectedList.take(5).map((item) => _buildSuspectedItem(theme, item)),
          if (_suspectedList.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '还有 ${_suspectedList.length - 5} 条记录...',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuspectedItem(ThemeData theme, SuspectedDuplicate item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.amount > 0 ? "+" : ""}¥${item.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: item.amount < 0 ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.matchType} ${item.matchPercentage}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '与${item.similarDate}记录相似',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _goToPreview,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              _suspectedDuplicates > 0
                  ? '处理疑似重复（$_suspectedDuplicates条）'
                  : '继续导入（$_newRecords条）',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPreviewConfirmPage(
          filePath: widget.filePath,
          fileName: widget.fileName,
          newRecords: _newRecords,
          processedSuspected: _featureMatches + _semanticMatches,
          excludedDuplicates: _confirmedDuplicates,
        ),
      ),
    );
  }
}

/// 疑似重复记录
class SuspectedDuplicate {
  final String description;
  final double amount;
  final String matchType;
  final int matchPercentage;
  final String similarDate;

  SuspectedDuplicate({
    required this.description,
    required this.amount,
    required this.matchType,
    required this.matchPercentage,
    required this.similarDate,
  });
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
