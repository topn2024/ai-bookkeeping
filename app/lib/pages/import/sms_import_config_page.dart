import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'sms_import_progress_page.dart';

/// 短信导入配置页面
/// 用户选择时间范围和其他配置
class SmsImportConfigPage extends StatefulWidget {
  const SmsImportConfigPage({super.key});

  @override
  State<SmsImportConfigPage> createState() => _SmsImportConfigPageState();
}

class _SmsImportConfigPageState extends State<SmsImportConfigPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _useSenderFilter = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('短信导入配置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildDateRangeSection(),
            const SizedBox(height: 20),
            _buildFilterSection(),
            const SizedBox(height: 20),
            _buildWarningSection(),
            const SizedBox(height: 32),
            _buildStartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sms,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '短信导入',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '自动读取支付短信，智能识别交易记录',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '时间范围',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDateSelector(
            label: '开始日期',
            date: _startDate,
            onTap: () => _selectDate(true),
          ),
          const SizedBox(height: 12),
          _buildDateSelector(
            label: '结束日期',
            date: _endDate,
            onTap: () => _selectDate(false),
          ),
          const SizedBox(height: 16),
          _buildQuickDateButtons(),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateButtons() {
    return Wrap(
      spacing: 8,
      children: [
        _buildQuickDateButton('最近7天', 7),
        _buildQuickDateButton('最近30天', 30),
        _buildQuickDateButton('最近90天', 90),
      ],
    );
  }

  Widget _buildQuickDateButton(String label, int days) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _endDate = DateTime.now();
          _startDate = _endDate.subtract(Duration(days: days));
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.orange.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.orange.shade700,
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '过滤选项',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _useSenderFilter,
            onChanged: (value) {
              setState(() {
                _useSenderFilter = value;
              });
            },
            title: const Text('仅读取支付相关短信'),
            subtitle: Text(
              _useSenderFilter
                  ? '只读取银行、支付宝、微信等支付平台的短信'
                  : '读取所有短信（可能包含大量无关内容）',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            activeTrackColor: Colors.orange.shade200,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildWarningSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '隐私说明',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWarningItem('短信内容仅在本地处理，不会永久存储'),
          _buildWarningItem('使用AI解析短信内容，需要网络连接'),
          _buildWarningItem('首次使用需要授予短信读取权限'),
          _buildWarningItem('建议选择较短的时间范围以提高处理速度'),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final daysDiff = _endDate.difference(_startDate).inDays;
    final isLongRange = daysDiff > 90;

    return Column(
      children: [
        if (isLongRange)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '时间范围较长，处理可能需要较多时间',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startImport,
            icon: const Icon(Icons.play_arrow),
            label: Text('开始导入 (${daysDiff + 1}天)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade700,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // 确保开始日期不晚于结束日期
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // 确保结束日期不早于开始日期
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _startImport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmsImportProgressPage(
          startDate: _startDate,
          endDate: _endDate,
          useSenderFilter: _useSenderFilter,
        ),
      ),
    );
  }
}
