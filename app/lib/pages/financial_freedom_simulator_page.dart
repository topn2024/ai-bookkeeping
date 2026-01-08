import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 10.19 财务自由模拟器页面
/// 模拟和规划达成财务自由的进度
class FinancialFreedomSimulatorPage extends ConsumerStatefulWidget {
  const FinancialFreedomSimulatorPage({super.key});

  @override
  ConsumerState<FinancialFreedomSimulatorPage> createState() =>
      _FinancialFreedomSimulatorPageState();
}

class _FinancialFreedomSimulatorPageState
    extends ConsumerState<FinancialFreedomSimulatorPage> {
  // 参数
  double _monthlySavings = 3000;
  double _annualReturn = 5;
  double _targetPassiveIncome = 10000;

  // 计算结果
  int _yearsToFreedom = 18;
  double _currentProgress = 0.05;

  @override
  void initState() {
    super.initState();
    _calculateFreedom();
  }

  void _calculateFreedom() {
    // 简化的财务自由计算
    // 目标本金 = 目标被动收入 * 12 / 年化收益率
    final targetPrincipal = _targetPassiveIncome * 12 / (_annualReturn / 100);
    // 每年储蓄
    final yearlySavings = _monthlySavings * 12;
    // 需要的年数（简化计算，未考虑复利）
    final years = targetPrincipal / yearlySavings;

    setState(() {
      _yearsToFreedom = years.ceil();
      // 假设当前已有5%进度
      _currentProgress = 0.05;
    });
  }

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
          l10n.financialFreedomSimulator,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppTheme.textSecondaryColor),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 进度可视化
            _buildProgressVisualization(l10n),
            // 优化建议
            _buildOptimizationTip(l10n),
            // 参数调整
            _buildParameterSection(l10n),
            // 免责声明
            _buildDisclaimer(l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressVisualization(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏝️', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(
                l10n.yourFinancialFreedomJourney,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 进度轨道
          _buildProgressTrack(),
          const SizedBox(height: 20),
          // 结果显示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer, color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1565C0),
                    ),
                    children: [
                      TextSpan(text: l10n.estimatedTime),
                      TextSpan(
                        text: '$_yearsToFreedom年',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(text: l10n.toAchieveFreedom),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTrack() {
    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          // 进度轨道背景
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFC8E6C9),
                    Color(0xFFFFF9C4),
                    Color(0xFFFFCCBC),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // 当前位置
          Positioned(
            top: 12,
            left: MediaQuery.of(context).size.width * 0.05 * _currentProgress - 32,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('👤', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_currentProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          // 里程碑点
          ..._buildMilestones(),
          // 终点
          Positioned(
            top: 12,
            right: 0,
            child: Column(
              children: const [
                Text('🏝️', style: TextStyle(fontSize: 28)),
                SizedBox(height: 2),
                Text(
                  '自由',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMilestones() {
    final milestones = [
      {'position': 0.25, 'label': '3年'},
      {'position': 0.5, 'label': '5年'},
      {'position': 0.75, 'label': '10年'},
    ];

    return milestones.map((milestone) {
      final position = milestone['position'] as double;
      return Positioned(
        top: 20,
        left: (MediaQuery.of(context).size.width - 64) * position,
        child: Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB74D), width: 2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              milestone['label'] as String,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildOptimizationTip(AppLocalizations l10n) {
    final extraSavings = 500;
    final yearsReduced = 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: const Color(0xFFF57C00), size: 22),
              const SizedBox(width: 10),
              Text(
                l10n.accelerateTip,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFF57C00),
                height: 1.5,
              ),
              children: [
                const TextSpan(text: '每月多存 '),
                TextSpan(
                  text: '¥$extraSavings',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '，可以提前 '),
                TextSpan(
                  text: '$yearsReduced年',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' 达成目标'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSection(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adjustParameters,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 月储蓄额
                _buildSliderParameter(
                  label: l10n.monthlySavings,
                  value: _monthlySavings,
                  min: 1000,
                  max: 10000,
                  format: '¥${_monthlySavings.toStringAsFixed(0)}',
                  color: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _monthlySavings = value;
                      _calculateFreedom();
                    });
                  },
                ),
                const SizedBox(height: 24),
                // 年化收益率
                _buildSliderParameter(
                  label: l10n.annualReturn,
                  value: _annualReturn,
                  min: 2,
                  max: 10,
                  format: '${_annualReturn.toStringAsFixed(0)}%',
                  color: const Color(0xFFFF9800),
                  onChanged: (value) {
                    setState(() {
                      _annualReturn = value;
                      _calculateFreedom();
                    });
                  },
                ),
                const SizedBox(height: 24),
                // 目标被动收入
                _buildSliderParameter(
                  label: l10n.targetPassiveIncome,
                  value: _targetPassiveIncome,
                  min: 5000,
                  max: 30000,
                  format: '¥${_targetPassiveIncome.toStringAsFixed(0)}/月',
                  color: const Color(0xFF4CAF50),
                  onChanged: (value) {
                    setState(() {
                      _targetPassiveIncome = value;
                      _calculateFreedom();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderParameter({
    required String label,
    required double value,
    required double min,
    required double max,
    required String format,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            Text(
              format,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: AppTheme.surfaceVariantColor,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 2,
            ),
            trackHeight: 6,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              min == 5000 || min == 1000
                  ? '¥${min.toStringAsFixed(0)}'
                  : '${min.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            Text(
              max == 30000 || max == 10000
                  ? '¥${max.toStringAsFixed(0)}'
                  : '${max.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisclaimer(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info,
            size: 14,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.disclaimer,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('关于财务自由'),
          ],
        ),
        content: const Text(
          '财务自由是指被动收入能够覆盖日常开支，无需主动工作即可维持生活。\n\n'
          '本模拟器基于以下假设：\n'
          '• 储蓄率保持稳定\n'
          '• 年化收益率恒定\n'
          '• 未考虑通货膨胀\n\n'
          '实际情况可能有所不同，建议咨询专业理财顾问。',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}
