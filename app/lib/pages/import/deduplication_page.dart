import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
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

  // 模拟去重检测结果
  int _totalRecords = 156;
  int _newRecords = 142;
  int _suspectedDuplicates = 8;
  int _confirmedDuplicates = 6;

  // 三层去重结果
  int _exactMatches = 6;
  int _featureMatches = 5;
  int _semanticMatches = 3;

  // 疑似重复记录
  final List<SuspectedDuplicate> _suspectedList = [
    SuspectedDuplicate(
      description: '美团外卖',
      amount: -35.00,
      matchType: '特征匹配',
      matchPercentage: 85,
      similarDate: '12月28日',
    ),
    SuspectedDuplicate(
      description: '滴滴出行',
      amount: -15.00,
      matchType: 'AI语义',
      matchPercentage: 72,
      similarDate: '12月27日',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startDeduplication();
  }

  Future<void> _startDeduplication() async {
    // 模拟去重检测过程
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
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
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '去重检测',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
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
          ..._suspectedList.map((item) => _buildSuspectedItem(theme, item)),
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
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
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
              '处理疑似重复（${_suspectedDuplicates}条）',
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
