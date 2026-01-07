import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'deduplication_page.dart';

/// 字段映射配置页面
/// 原型设计 5.10：字段映射配置
/// - 提示信息
/// - 字段映射列表（日期、金额、描述、分类、交易对方）
/// - 保存模板选项
/// - 确认按钮
class FieldMappingPage extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;

  const FieldMappingPage({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  ConsumerState<FieldMappingPage> createState() => _FieldMappingPageState();
}

class _FieldMappingPageState extends ConsumerState<FieldMappingPage> {
  // 模拟检测到的字段列表
  final List<String> _detectedColumns = [
    '交易时间',
    '记账日期',
    '创建时间',
    '金额(元)',
    '交易金额',
    '实付金额',
    '商品名称',
    '交易对方',
    '备注',
    '交易类型',
    '类目',
    '收款方',
    '商户名',
  ];

  // 字段映射配置
  final Map<String, String?> _fieldMappings = {
    'date': '交易时间',
    'amount': '金额(元)',
    'description': '商品名称',
    'category': '交易类型',
    'merchant': '交易对方',
  };

  bool _saveAsTemplate = false;

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
                    _buildHintCard(context, theme),
                    _buildMappingList(context, theme),
                    _buildSaveTemplateOption(context, theme),
                  ],
                ),
              ),
            ),
            _buildConfirmButton(context, theme),
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
              '字段映射',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _resetMappings,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                '重置',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '检测到自定义CSV格式，请配置字段映射',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingList(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '将文件列映射到系统字段',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildMappingItem(
            context,
            theme,
            fieldKey: 'date',
            label: '日期',
            description: '交易发生日期',
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildMappingItem(
            context,
            theme,
            fieldKey: 'amount',
            label: '金额',
            description: '交易金额',
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildMappingItem(
            context,
            theme,
            fieldKey: 'description',
            label: '描述',
            description: '交易备注',
            isRequired: false,
          ),
          const SizedBox(height: 12),
          _buildMappingItem(
            context,
            theme,
            fieldKey: 'category',
            label: '分类',
            description: '交易分类',
            isRequired: false,
          ),
          const SizedBox(height: 12),
          _buildMappingItem(
            context,
            theme,
            fieldKey: 'merchant',
            label: '交易对方',
            description: '商户名称',
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMappingItem(
    BuildContext context,
    ThemeData theme, {
    required String fieldKey,
    required String label,
    required String description,
    required bool isRequired,
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isRequired)
                      Text(
                        '*',
                        style: TextStyle(color: AppColors.error),
                      ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _fieldMappings[fieldKey],
              underline: const SizedBox.shrink(),
              icon: Icon(
                Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              items: [
                if (!isRequired)
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      '不映射',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (fieldKey == 'category')
                  DropdownMenuItem<String>(
                    value: 'ai_classify',
                    child: Text(
                      '（AI智能分类）',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ..._detectedColumns.map((col) => DropdownMenuItem<String>(
                      value: col,
                      child: Text(
                        col,
                        style: const TextStyle(fontSize: 14),
                      ),
                    )),
              ],
              onChanged: (value) {
                setState(() => _fieldMappings[fieldKey] = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveTemplateOption(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _saveAsTemplate,
            onChanged: (v) => setState(() => _saveAsTemplate = v ?? false),
          ),
          Expanded(
            child: Text(
              '保存为模板，下次自动使用',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context, ThemeData theme) {
    final isValid = _fieldMappings['date'] != null && _fieldMappings['amount'] != null;

    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isValid ? _confirmMapping : null,
            icon: const Icon(Icons.check),
            label: const Text(
              '确认映射',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetMappings() {
    setState(() {
      _fieldMappings['date'] = '交易时间';
      _fieldMappings['amount'] = '金额(元)';
      _fieldMappings['description'] = '商品名称';
      _fieldMappings['category'] = '交易类型';
      _fieldMappings['merchant'] = '交易对方';
    });
  }

  void _confirmMapping() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeduplicationPage(
          filePath: widget.filePath,
          fileName: widget.fileName,
          detectedSource: '自定义格式',
          fieldMappings: _fieldMappings,
        ),
      ),
    );
  }
}
