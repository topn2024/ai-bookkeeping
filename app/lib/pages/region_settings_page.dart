import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.05 区域设置页面
/// 日期格式、时间格式、每周起始日、数字格式
class RegionSettingsPage extends ConsumerStatefulWidget {
  const RegionSettingsPage({super.key});

  @override
  ConsumerState<RegionSettingsPage> createState() => _RegionSettingsPageState();
}

class _RegionSettingsPageState extends ConsumerState<RegionSettingsPage> {
  String _dateFormat = 'yyyy年MM月dd日';
  String _timeFormat = '24h';
  String _weekStart = 'monday';
  String _numberFormat = 'comma_dot';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.regionSettings,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.dateFormat),
            _buildDateFormatSection(),
            const SizedBox(height: 24),
            _buildSectionTitle(l10n.timeFormat),
            _buildTimeFormatSection(),
            const SizedBox(height: 24),
            _buildSectionTitle(l10n.weekStartDay),
            _buildWeekStartSection(),
            const SizedBox(height: 24),
            _buildSectionTitle(l10n.numberFormat),
            _buildNumberFormatSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildDateFormatSection() {
    final formats = [
      {'value': 'yyyy年MM月dd日', 'example': '2024年12月31日'},
      {'value': 'yyyy/MM/dd', 'example': '2024/12/31'},
      {'value': 'MM/dd/yyyy', 'example': '12/31/2024'},
      {'value': 'dd/MM/yyyy', 'example': '31/12/2024'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: formats.asMap().entries.map((entry) {
          final index = entry.key;
          final format = entry.value;
          final isLast = index == formats.length - 1;
          final isSelected = _dateFormat == format['value'];

          return _buildOptionItem(
            title: format['value']!,
            subtitle: '示例：${format['example']}',
            isSelected: isSelected,
            showDivider: !isLast,
            onTap: () => setState(() => _dateFormat = format['value']!),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeFormatSection() {
    final formats = [
      {'value': '24h', 'title': '24小时制', 'example': '14:30'},
      {'value': '12h', 'title': '12小时制', 'example': '2:30 PM'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: formats.asMap().entries.map((entry) {
          final index = entry.key;
          final format = entry.value;
          final isLast = index == formats.length - 1;
          final isSelected = _timeFormat == format['value'];

          return _buildOptionItem(
            title: format['title']!,
            subtitle: '示例：${format['example']}',
            isSelected: isSelected,
            showDivider: !isLast,
            onTap: () => setState(() => _timeFormat = format['value']!),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekStartSection() {
    final options = [
      {'value': 'monday', 'title': '周一'},
      {'value': 'sunday', 'title': '周日'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isLast = index == options.length - 1;
          final isSelected = _weekStart == option['value'];

          return _buildOptionItem(
            title: option['title']!,
            isSelected: isSelected,
            showDivider: !isLast,
            onTap: () => setState(() => _weekStart = option['value']!),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNumberFormatSection() {
    final formats = [
      {'value': 'comma_dot', 'title': '1,234.56', 'subtitle': '千位逗号，小数点'},
      {'value': 'dot_comma', 'title': '1.234,56', 'subtitle': '千位点号，小数逗号'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: formats.asMap().entries.map((entry) {
          final index = entry.key;
          final format = entry.value;
          final isLast = index == formats.length - 1;
          final isSelected = _numberFormat == format['value'];

          return _buildOptionItem(
            title: format['title']!,
            subtitle: format['subtitle'],
            isSelected: isSelected,
            showDivider: !isLast,
            onTap: () => setState(() => _numberFormat = format['value']!),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOptionItem({
    required String title,
    String? subtitle,
    required bool isSelected,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: AppTheme.dividerColor,
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: AppTheme.primaryColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
