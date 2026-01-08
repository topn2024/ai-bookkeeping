import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 智能功能推荐数据
class FeatureRecommendation {
  final String id;
  final String title;
  final String description;
  final String trigger;
  final IconData icon;
  final Color color;
  final List<FeaturePreview> previews;

  FeatureRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.trigger,
    required this.icon,
    required this.color,
    this.previews = const [],
  });
}

class FeaturePreview {
  final String label;
  final String value;

  FeaturePreview({required this.label, required this.value});
}

/// 10.18 智能功能推荐页面
/// 根据用户行为智能推荐新功能
class SmartFeatureRecommendationPage extends ConsumerStatefulWidget {
  const SmartFeatureRecommendationPage({super.key});

  @override
  ConsumerState<SmartFeatureRecommendationPage> createState() =>
      _SmartFeatureRecommendationPageState();
}

class _SmartFeatureRecommendationPageState
    extends ConsumerState<SmartFeatureRecommendationPage> {
  late List<FeatureRecommendation> _recommendations;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    _recommendations = [
      FeatureRecommendation(
        id: '1',
        title: '预算功能',
        description: '你已经连续记账7天啦！试试设置预算，让我帮你更好地控制开支？每月花多少、哪里花得多，一目了然。',
        trigger: '连续记账7天',
        icon: Icons.pie_chart,
        color: const Color(0xFF4CAF50),
        previews: [
          FeaturePreview(label: '月度预算', value: '¥10,000'),
          FeaturePreview(label: '分类预算', value: '6个'),
          FeaturePreview(label: '超支提醒', value: '智能'),
        ],
      ),
      FeatureRecommendation(
        id: '2',
        title: '钱龄追踪',
        description: '看起来你的消费习惯很规律！试试钱龄功能，看看你的钱平均能存多久？',
        trigger: '消费规律',
        icon: Icons.schedule,
        color: const Color(0xFF2196F3),
        previews: [
          FeaturePreview(label: '当前钱龄', value: '12天'),
          FeaturePreview(label: '目标钱龄', value: '15天'),
          FeaturePreview(label: '等级', value: '稳健型'),
        ],
      ),
      FeatureRecommendation(
        id: '3',
        title: '储蓄目标',
        description: '你的收入稳定，可以尝试设置储蓄目标，让我帮你规划存钱计划！',
        trigger: '收入稳定',
        icon: Icons.savings,
        color: const Color(0xFFFF9800),
        previews: [
          FeaturePreview(label: '月存金额', value: '¥2,000'),
          FeaturePreview(label: '年度目标', value: '¥24,000'),
          FeaturePreview(label: '进度追踪', value: '可视化'),
        ],
      ),
    ];
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
          l10n.smartRecommendation,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: _recommendations.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildRecommendationCard(_recommendations[index], l10n);
              },
            ),
          ),
          // 页面指示器
          _buildPageIndicator(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
      FeatureRecommendation recommendation, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 推荐卡片
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // 头部
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        recommendation.color.withValues(alpha: 0.15),
                        recommendation.color.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          recommendation.icon,
                          size: 36,
                          color: recommendation.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.discoverNewFeature,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: recommendation.color,
                        ),
                      ),
                    ],
                  ),
                ),
                // 内容
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 触发条件
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: recommendation.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 16,
                              color: recommendation.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              recommendation.trigger,
                              style: TextStyle(
                                fontSize: 12,
                                color: recommendation.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 描述
                      Text(
                        recommendation.description,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondaryColor,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 功能预览
                      if (recommendation.previews.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariantColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    recommendation.icon,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${recommendation.title}预览',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: recommendation.previews.map((preview) {
                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            preview.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            preview.value,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      // 操作按钮
                      ElevatedButton.icon(
                        onPressed: () => _enableFeature(recommendation),
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: Text('启用${recommendation.title}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: recommendation.color,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            l10n.laterRemind,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_recommendations.length, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? _recommendations[_currentIndex].color
                : AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  void _enableFeature(FeatureRecommendation recommendation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${recommendation.title}已启用'),
        backgroundColor: AppTheme.successColor,
      ),
    );
    Navigator.pop(context);
  }
}

/// 智能功能推荐对话框（可在任意页面弹出）
class SmartFeatureRecommendationDialog extends StatelessWidget {
  final String featureTitle;
  final String description;
  final String trigger;
  final IconData icon;
  final Color color;
  final VoidCallback? onEnable;
  final VoidCallback? onDismiss;

  const SmartFeatureRecommendationDialog({
    super.key,
    required this.featureTitle,
    required this.description,
    required this.trigger,
    required this.icon,
    required this.color,
    this.onEnable,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE8F5E9),
                  const Color(0xFFC8E6C9),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '发现新功能',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: '你已经'),
                      TextSpan(
                        text: trigger,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const TextSpan(text: '！'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEnable?.call();
                  },
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: Text('启用$featureTitle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDismiss?.call();
                  },
                  child: Text(
                    '以后再说',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 显示推荐对话框
  static void show(
    BuildContext context, {
    required String featureTitle,
    required String description,
    required String trigger,
    required IconData icon,
    Color color = const Color(0xFF4CAF50),
    VoidCallback? onEnable,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (context) => SmartFeatureRecommendationDialog(
        featureTitle: featureTitle,
        description: description,
        trigger: trigger,
        icon: icon,
        color: color,
        onEnable: onEnable,
        onDismiss: onDismiss,
      ),
    );
  }
}
