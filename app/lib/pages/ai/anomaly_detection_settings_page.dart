import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 异常检测设置页面
///
/// 对应原型设计 14.04 异常检测设置
/// 配置异常交易检测规则
class AnomalyDetectionSettingsPage extends ConsumerStatefulWidget {
  const AnomalyDetectionSettingsPage({super.key});

  @override
  ConsumerState<AnomalyDetectionSettingsPage> createState() =>
      _AnomalyDetectionSettingsPageState();
}

class _AnomalyDetectionSettingsPageState
    extends ConsumerState<AnomalyDetectionSettingsPage> {
  bool _enabled = true;
  bool _amountAnomaly = true;
  bool _timeAnomaly = true;
  bool _frequencyAnomaly = true;
  bool _duplicateDetection = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('异常检测'),
      ),
      body: ListView(
        children: [
          // 总开关卡片
          _MainSwitchCard(
            enabled: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),

          // 检测维度
          if (_enabled) ...[
            _DetectionDimensionsSection(
              amountAnomaly: _amountAnomaly,
              timeAnomaly: _timeAnomaly,
              frequencyAnomaly: _frequencyAnomaly,
              duplicateDetection: _duplicateDetection,
              onAmountChanged: (v) => setState(() => _amountAnomaly = v),
              onTimeChanged: (v) => setState(() => _timeAnomaly = v),
              onFrequencyChanged: (v) => setState(() => _frequencyAnomaly = v),
              onDuplicateChanged: (v) => setState(() => _duplicateDetection = v),
            ),
          ],

          // 查看历史按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.history),
              label: const Text('查看异常历史记录'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 总开关卡片
class _MainSwitchCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _MainSwitchCard({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.security, color: Colors.red[400]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '智能异常检测',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '自动识别异常消费',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '本月已检测到 ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[400],
                    ),
                  ),
                  Text(
                    ' 笔异常交易',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 检测维度设置
class _DetectionDimensionsSection extends StatelessWidget {
  final bool amountAnomaly;
  final bool timeAnomaly;
  final bool frequencyAnomaly;
  final bool duplicateDetection;
  final ValueChanged<bool> onAmountChanged;
  final ValueChanged<bool> onTimeChanged;
  final ValueChanged<bool> onFrequencyChanged;
  final ValueChanged<bool> onDuplicateChanged;

  const _DetectionDimensionsSection({
    required this.amountAnomaly,
    required this.timeAnomaly,
    required this.frequencyAnomaly,
    required this.duplicateDetection,
    required this.onAmountChanged,
    required this.onTimeChanged,
    required this.onFrequencyChanged,
    required this.onDuplicateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '检测维度',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _DimensionItem(
            icon: Icons.attach_money,
            iconColor: Colors.orange,
            title: '金额异常',
            description: '超过日均3倍触发',
            enabled: amountAnomaly,
            onChanged: onAmountChanged,
          ),
          const SizedBox(height: 8),
          _DimensionItem(
            icon: Icons.schedule,
            iconColor: Colors.purple,
            title: '时间异常',
            description: '深夜消费提醒',
            enabled: timeAnomaly,
            onChanged: onTimeChanged,
          ),
          const SizedBox(height: 8),
          _DimensionItem(
            icon: Icons.repeat,
            iconColor: Colors.blue,
            title: '频率异常',
            description: '短时间内多次消费',
            enabled: frequencyAnomaly,
            onChanged: onFrequencyChanged,
          ),
          const SizedBox(height: 8),
          _DimensionItem(
            icon: Icons.content_copy,
            iconColor: Colors.green,
            title: '重复检测',
            description: '相似交易去重',
            enabled: duplicateDetection,
            onChanged: onDuplicateChanged,
          ),
        ],
      ),
    );
  }
}

class _DimensionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _DimensionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
