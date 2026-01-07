import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 语音配置中心页面
///
/// 对应原型设计 14.08 语音配置中心
/// 配置语音交互系统的各项功能
class VoiceConfigPage extends ConsumerStatefulWidget {
  const VoiceConfigPage({super.key});

  @override
  ConsumerState<VoiceConfigPage> createState() => _VoiceConfigPageState();
}

class _VoiceConfigPageState extends ConsumerState<VoiceConfigPage> {
  bool _voiceBookkeeping = true;
  bool _voiceConfig = true;
  bool _voiceNavigation = true;
  bool _voiceQuery = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 语音功能概览
          _VoiceOverviewCard(),

          // 功能开关
          _FunctionSwitchesSection(
            voiceBookkeeping: _voiceBookkeeping,
            voiceConfig: _voiceConfig,
            voiceNavigation: _voiceNavigation,
            voiceQuery: _voiceQuery,
            onBookkeepingChanged: (v) => setState(() => _voiceBookkeeping = v),
            onConfigChanged: (v) => setState(() => _voiceConfig = v),
            onNavigationChanged: (v) => setState(() => _voiceNavigation = v),
            onQueryChanged: (v) => setState(() => _voiceQuery = v),
          ),

          // 适配性统计
          _AdaptabilityStatsSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('语音功能说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('语音交互系统包含4大功能模块：'),
            SizedBox(height: 8),
            Text('• 语音记账：说话即可完成记账'),
            Text('• 语音配置：语音修改应用设置'),
            Text('• 语音导航：语音跳转页面'),
            Text('• 语音查询：语音查询账单数据'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 语音功能概览卡片
class _VoiceOverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.purple[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.record_voice_over,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '语音交互系统',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '4大功能模块',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _FeatureIcon(icon: Icons.mic, label: '记账'),
              _FeatureIcon(icon: Icons.settings_voice, label: '配置'),
              _FeatureIcon(icon: Icons.navigation, label: '导航'),
              _FeatureIcon(icon: Icons.search, label: '查询'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureIcon({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 功能开关区域
class _FunctionSwitchesSection extends StatelessWidget {
  final bool voiceBookkeeping;
  final bool voiceConfig;
  final bool voiceNavigation;
  final bool voiceQuery;
  final ValueChanged<bool> onBookkeepingChanged;
  final ValueChanged<bool> onConfigChanged;
  final ValueChanged<bool> onNavigationChanged;
  final ValueChanged<bool> onQueryChanged;

  const _FunctionSwitchesSection({
    required this.voiceBookkeeping,
    required this.voiceConfig,
    required this.voiceNavigation,
    required this.voiceQuery,
    required this.onBookkeepingChanged,
    required this.onConfigChanged,
    required this.onNavigationChanged,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '功能开关',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
            child: Column(
              children: [
                _FunctionSwitch(
                  title: '语音记账',
                  description: '说话即可完成记账',
                  enabled: voiceBookkeeping,
                  onChanged: onBookkeepingChanged,
                  showDivider: true,
                ),
                _FunctionSwitch(
                  title: '语音配置',
                  description: '语音修改应用设置',
                  enabled: voiceConfig,
                  onChanged: onConfigChanged,
                  showDivider: true,
                ),
                _FunctionSwitch(
                  title: '语音导航',
                  description: '语音跳转页面',
                  enabled: voiceNavigation,
                  onChanged: onNavigationChanged,
                  showDivider: true,
                ),
                _FunctionSwitch(
                  title: '语音查询',
                  description: '语音查询账单数据',
                  enabled: voiceQuery,
                  onChanged: onQueryChanged,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FunctionSwitch extends StatelessWidget {
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _FunctionSwitch({
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
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
                      style: const TextStyle(
                        fontSize: 14,
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
        ),
        if (showDivider)
          Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }
}

/// 适配性统计
class _AdaptabilityStatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '语音配置适配性',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AdaptabilityCard(
                  value: 60,
                  label: '高适配项',
                  percentage: '30%',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AdaptabilityCard(
                  value: 50,
                  label: '中适配项',
                  percentage: '25%',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AdaptabilityCard(
                  value: 90,
                  label: '不适配项',
                  percentage: '45%',
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdaptabilityCard extends StatelessWidget {
  final int value;
  final String label;
  final String percentage;
  final Color color;

  const _AdaptabilityCard({
    required this.value,
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
