import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// 功能介绍引导页
///
/// 对应原型设计 10.15 功能介绍引导
/// 向新用户介绍应用的主要功能
class OnboardingFeaturesPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const OnboardingFeaturesPage({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<OnboardingFeaturesPage> createState() => _OnboardingFeaturesPageState();
}

class _OnboardingFeaturesPageState extends State<OnboardingFeaturesPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<_FeatureData> _getFeatures(S l10n) {
    return [
      _FeatureData(
        icon: Icons.camera_alt,
        emoji: '📸',
        title: l10n.onboardingFeaturePhotoTitle,
        description: l10n.onboardingFeaturePhotoDesc,
        color: Colors.blue,
      ),
      _FeatureData(
        icon: Icons.mic,
        emoji: '🎤',
        title: l10n.onboardingFeatureVoiceTitle,
        description: l10n.onboardingFeatureVoiceDesc,
        color: Colors.purple,
      ),
      _FeatureData(
        icon: Icons.pie_chart,
        emoji: '📊',
        title: l10n.onboardingFeatureAnalysisTitle,
        description: l10n.onboardingFeatureAnalysisDesc,
        color: Colors.orange,
      ),
      _FeatureData(
        icon: Icons.savings,
        emoji: '🎯',
        title: l10n.onboardingFeatureSavingsTitle,
        description: l10n.onboardingFeatureSavingsDesc,
        color: Colors.green,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final features = _getFeatures(l10n);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onSkip,
                child: Text(l10n.onboardingSkip),
              ),
            ),

            // 功能展示
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: features.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _FeaturePage(feature: features[index]);
                },
              ),
            ),

            // 页面指示器
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                features.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? features[index].color
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 下一步/开始按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage < features.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    widget.onNext();
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: features[_currentPage].color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _currentPage < features.length - 1 ? l10n.onboardingNextStep : l10n.onboardingStartUsing,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  final _FeatureData feature;

  const _FeaturePage({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 功能图标
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                feature.emoji,
                style: const TextStyle(fontSize: 70),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // 标题
          Text(
            feature.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: feature.color,
            ),
          ),

          const SizedBox(height: 16),

          // 描述
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String emoji;
  final String title;
  final String description;
  final Color color;

  _FeatureData({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}
