import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

/// 导出高级配置页面
/// 原型设计 5.14：导出高级配置
/// - 导出格式选择（Excel/CSV/PDF）
/// - 导出字段选择
/// - Excel特有选项
/// - 底部预计导出和操作按钮
class ExportAdvancedConfigPage extends ConsumerStatefulWidget {
  final int transactionCount;
  final DateTime? startDate;
  final DateTime? endDate;

  const ExportAdvancedConfigPage({
    super.key,
    this.transactionCount = 856,
    this.startDate,
    this.endDate,
  });

  @override
  ConsumerState<ExportAdvancedConfigPage> createState() => _ExportAdvancedConfigPageState();
}

class _ExportAdvancedConfigPageState extends ConsumerState<ExportAdvancedConfigPage> {
  String _selectedFormat = 'excel';

  // 导出字段
  bool _includeDate = true;
  bool _includeAmount = true;
  bool _includeCategory = true;
  bool _includeNote = true;
  bool _includeAccount = true;
  bool _includeMoneyAge = false;
  bool _includeTags = false;

  // Excel特有选项
  bool _includeCategorySummary = true;
  bool _includeMonthlyTrend = false;
  bool _includeMoneyAgeAnalysis = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormatSelector(theme),
                    _buildFieldSelector(theme),
                    if (_selectedFormat == 'excel') _buildExcelOptions(theme),
                  ],
                ),
              ),
            ),
            _buildBottomSection(context, theme),
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
              '高级导出',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 导出格式选择
  Widget _buildFormatSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导出格式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFormatOption(
                  theme,
                  'excel',
                  'Excel',
                  Icons.table_chart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormatOption(
                  theme,
                  'csv',
                  'CSV',
                  Icons.description,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormatOption(
                  theme,
                  'pdf',
                  'PDF',
                  Icons.picture_as_pdf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(
    ThemeData theme,
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedFormat == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 导出字段选择
  Widget _buildFieldSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导出字段',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
              children: [
                _buildFieldSwitch(theme, '日期', _includeDate,
                    (v) => setState(() => _includeDate = v), true),
                _buildFieldSwitch(theme, '金额', _includeAmount,
                    (v) => setState(() => _includeAmount = v), true),
                _buildFieldSwitch(theme, '分类', _includeCategory,
                    (v) => setState(() => _includeCategory = v), true),
                _buildFieldSwitch(theme, '描述/备注', _includeNote,
                    (v) => setState(() => _includeNote = v), true),
                _buildFieldSwitch(theme, '账户', _includeAccount,
                    (v) => setState(() => _includeAccount = v), true),
                _buildFieldSwitch(theme, '钱龄（天）', _includeMoneyAge,
                    (v) => setState(() => _includeMoneyAge = v), true),
                _buildFieldSwitch(theme, '标签', _includeTags,
                    (v) => setState(() => _includeTags = v), false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldSwitch(
    ThemeData theme,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    bool showDivider,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(
                width: 40,
                height: 24,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }

  /// Excel特有选项
  Widget _buildExcelOptions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Excel选项',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
              children: [
                _buildExcelOption(
                  theme,
                  '包含分类汇总表',
                  '按分类统计的单独Sheet',
                  _includeCategorySummary,
                  (v) => setState(() => _includeCategorySummary = v),
                  true,
                ),
                _buildExcelOption(
                  theme,
                  '包含月度趋势图',
                  '自动生成图表',
                  _includeMonthlyTrend,
                  (v) => setState(() => _includeMonthlyTrend = v),
                  true,
                ),
                _buildExcelOption(
                  theme,
                  '包含钱龄分析表',
                  '资金流动分析Sheet',
                  _includeMoneyAgeAnalysis,
                  (v) => setState(() => _includeMoneyAgeAnalysis = v),
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelOption(
    ThemeData theme,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    bool showDivider,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                height: 24,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }

  /// 底部区域
  Widget _buildBottomSection(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '预计导出',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${widget.transactionCount} 条交易',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _startExport(context),
              icon: const Icon(Icons.file_download),
              label: const Text(
                '生成并导出',
                style: TextStyle(fontSize: 16),
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
        ],
      ),
    );
  }

  void _startExport(BuildContext context) {
    // 显示导出进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在生成${_getFormatName()}文件...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    // 模拟导出过程
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // 关闭进度对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getFormatName()}文件已生成，正在分享...'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context); // 返回上一页
    });
  }

  String _getFormatName() {
    switch (_selectedFormat) {
      case 'excel':
        return 'Excel';
      case 'csv':
        return 'CSV';
      case 'pdf':
        return 'PDF';
      default:
        return '';
    }
  }
}
